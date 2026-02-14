---
name: lint-judge
description: Evaluate review findings and propose deterministic lint rules that permanently catch the same patterns. Use after code review to turn recurring issues into automated checks. Triggers on "lint rule", "automate this check", "make this permanent", "add lint rule for".
allowed-tools: Read Grep Glob Bash
---

# Lint Judge

Turn review findings into permanent lint rules. The goal: every pattern caught by a reviewer should be caught by a linter next time, so the reviewer never has to flag it again.

The bar is high. Only propose a rule when you can guarantee it catches the exact pattern through AST structure, not heuristics.

## Step 1: Detect the Linter Stack

Before evaluating any findings, determine what linter system(s) the project uses. Check in priority order:

| Config file | Linter | Custom rules? |
|-------------|--------|---------------|
| `biome.json` / `biome.jsonc` | biome | No — built-in rules only |
| `.oxlintrc.json` / `oxlint.json` | oxlint | Yes (plugins) |
| `.eslintrc.*` / `eslint.config.*` | eslint | Yes (local plugins) |
| `.grit/grit.yaml` | GritQL | Yes — full custom patterns |
| `clippy.toml` / `.clippy.toml` | clippy | Limited (lints) |
| `ruff.toml` / `pyproject.toml [tool.ruff]` | ruff | No — built-in rules only |
| `.pylintrc` / `pyproject.toml [tool.pylint]` | pylint | Yes (checkers) |
| `.golangci.yml` | golangci-lint | Limited |

**Also check for GritQL** even if another linter exists — `.grit/grit.yaml` or `grit` in devDependencies. GritQL fills the custom-rule gap for linters that don't support plugins (biome, ruff).

Also check:
- Whether custom rules already exist — read them before proposing duplicates
- If the project has no linter AND no GritQL, stop. Cannot propose rules for a tool that doesn't exist.

## Step 2: Evaluate Findings

For each review finding, ask: **can this exact pattern be caught by a deterministic AST check?**

### Deterministic means:

- Matches a specific syntactic pattern (node type, property name, call signature)
- Zero or near-zero false positives — if the AST matches, the code is wrong
- No guessing about intent, data flow, variable contents, or runtime behavior

**Examples of deterministic patterns:**
- Banning `eval()` calls
- Requiring `===` over `==`
- Disallowing `execSync` with template literal arguments
- Flagging `new Function()` calls
- Banning `console.log` in production code
- Requiring explicit return types on exported functions

**NOT deterministic (skip silently):**
- "This variable might contain user input" (data flow)
- "This function name suggests it handles sensitive data" (naming heuristic)
- "This pattern is usually a bug" (probabilistic)
- Anything requiring runtime knowledge or cross-file context

### Only report if ALL true:

1. You can identify a specific existing rule by name, OR write a complete working custom rule
2. The rule is deterministic: AST structure, not heuristics
3. The project's linter or GritQL supports this

### Skip silently:

- Patterns needing type information the linter can't access
- Patterns needing cross-file context
- Cases where you're not confident the rule is correct and complete

Returning nothing is the expected common case. Most review findings are too nuanced for lint rules.

## Step 3: Propose Rules

Pick the right tool for each finding. Prefer built-in rules, then GritQL, then custom plugins.

### Decision tree:

```
Finding is deterministic?
├─ No → skip
└─ Yes → linter has built-in rule for this?
   ├─ Yes → enable it (Step 3a)
   └─ No → project has GritQL?
      ├─ Yes → write GritQL pattern (Step 3b)
      └─ No → linter supports custom plugins?
         ├─ Yes → write plugin rule (Step 3c)
         └─ No → suggest adding GritQL to the project
```

---

### Step 3a: Enable existing linter rule

#### Biome

Biome organizes rules into groups with enforced severity conventions:

| Group | Default severity | Purpose |
|-------|-----------------|---------|
| `correctness` | `error` | Catches bugs |
| `security` | `error` | Security vulnerabilities |
| `a11y` | `error` | Accessibility |
| `suspicious` | `warn` | Likely bugs, less certain |
| `style` | `info` | Code style preferences |
| `complexity` | `info` | Unnecessary complexity |
| `performance` | `warn` | Performance issues |
| `nursery` | off | Incubating rules |

**Config format (`biome.json`):**

```json
{
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true,
      "suspicious": {
        "noExplicitAny": "error"
      },
      "complexity": {
        "noForEach": "warn"
      },
      "style": {
        "noDefaultExport": {
          "level": "error"
        }
      }
    }
  }
}
```

**Overrides for specific paths:**

```json
{
  "overrides": [
    {
      "include": ["tests/**"],
      "linter": {
        "rules": {
          "suspicious": {
            "noExplicitAny": "off"
          }
        }
      }
    }
  ]
}
```

**CLI for quick testing:** `biome lint --only=style/useNamingConvention`

#### ESLint

```json
{
  "rules": {
    "no-eval": "error",
    "no-implied-eval": "error",
    "eqeqeq": ["error", "always"]
  }
}
```

#### oxlint

oxlint uses eslint-compatible rule names. Config in `.oxlintrc.json`:

```json
{
  "rules": {
    "no-eval": "error",
    "no-debugger": "error"
  }
}
```

---

### Step 3b: GritQL custom pattern

GritQL is the universal escape hatch — works alongside any linter to catch patterns they can't express natively. Patterns live in `.grit/grit.yaml` and enforce via `grit check`.

**Syntax essentials:**

| Concept | Syntax | Example |
|---------|--------|---------|
| Match code | `` `code` `` | `` `console.log($msg)` `` |
| Metavariable | `$name` | `$fn`, `$args`, `$_` (anonymous) |
| Rewrite | `=>` | `` `var $x` => `const $x` `` |
| Condition | `where { }` | `where { $x <: not "safe" }` |
| Delete | `=> .` | `` `debugger` => . `` |
| Negation | `<: not` | `$msg <: not within \`def test_$_\`` |

**Config format (`.grit/grit.yaml`):**

```yaml
version: 0.0.1
patterns:
  # Import standard library patterns
  - name: github.com/getgrit/stdlib#*

  # Enable specific stdlib pattern
  - name: github.com/getgrit/stdlib#no_console_log

  # Custom pattern — ban eval with template literals
  - name: no_eval_template
    level: error
    body: |
      `eval($arg)` where {
        $arg <: `\`$_\``
      }

  # Custom pattern — ban execSync with interpolation
  - name: no_execsync_interpolation
    level: error
    body: |
      `execSync($cmd)` where {
        $cmd <: `\`$_\``
      }

  # Composite pattern using or
  - name: security_checks
    level: error
    body: |
      or {
        `eval($__)`,
        `new Function($__)`,
        `innerHTML = $__`
      }
```

**Enforce:** `grit check` (CI) or `grit apply` (autofix)

**GritQL standard library** has 200+ patterns. Import before writing custom:
- `no_console_log`, `no_eval`, `no_inner_html`
- `no_var_declaration`, `prefer_const`
- Security patterns, framework-specific migrations

**When to use GritQL vs native linter rules:**
- Biome/ruff don't support custom rules → use GritQL
- Pattern spans multiple node types → GritQL `or { }` blocks
- Need rewrite/autofix alongside detection → GritQL `=>`
- Cross-language pattern (same check in JS + Python) → GritQL with `language` directive

---

### Step 3c: Custom plugin rule (eslint/oxlint)

For eslint, write a local plugin rule:

```javascript
// eslint-local-rules/no-execsync-interpolation.js
module.exports = {
  meta: {
    type: "problem",
    docs: { description: "Disallow execSync with template literals" },
    schema: [],
  },
  create(context) {
    return {
      CallExpression(node) {
        if (
          node.callee.name === "execSync" &&
          node.arguments[0]?.type === "TemplateLiteral"
        ) {
          context.report({ node, message: "Use execSync with static strings only" });
        }
      },
    };
  },
};
```

Wire into config:
```json
{
  "plugins": ["eslint-local-rules"],
  "rules": {
    "local-rules/no-execsync-interpolation": "error"
  }
}
```

## Proposal Format

For each qualifying finding:

```markdown
### `[rule-name]`

**Finding:** [original review finding]
**Pattern:** [what AST structure is matched]
**Deterministic:** Yes — [why zero false positives]
**Tool:** [biome | eslint | oxlint | gritql]

[Config diff or pattern definition]
```

## Integration with /workflows:review

When loaded during a review workflow:

1. Receive findings from review agents (security-sentinel, code-simplicity-reviewer, etc.)
2. Filter for deterministic-pattern candidates
3. Propose rules using the decision tree (built-in → GritQL → plugin)
4. Present proposals as a separate "Automation Opportunities" section

This is **not** a replacement for review — it's a feedback loop that makes the linter smarter over time.

## Principles

- **Determinism over coverage** — one precise rule beats ten noisy ones
- **Existing rules first** — enable a built-in rule before writing a custom one
- **GritQL for the gaps** — when the linter can't express it, GritQL can
- **Match project conventions** — custom rules follow the style of existing custom rules
- **Empty output is fine** — most findings don't qualify, and that's expected
- **Use Context7** — when unsure whether a biome/eslint rule exists, query docs first
