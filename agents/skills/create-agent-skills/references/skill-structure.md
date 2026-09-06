# Skill Structure

## Metadata

Use the shared [format contract](official-spec.md). The name must match the folder. Write a descriptive trigger, not a claim of universal expertise. Tool permissions and model choices belong to native configuration.

## Body

Use a title and clear Markdown sections for purpose, quick start, procedure, examples, and completion criteria as needed. No special tags are required. Do not remove useful Markdown headings to satisfy an invented XML rule.

## Resources

- `workflows/`: steps for distinct supported tasks.
- `references/`: reusable domain facts and decision guidance.
- `scripts/`: executable helpers with documented inputs, dependencies, failures, and outputs.
- `templates/` or `assets/`: structures and materials used in an output.

Only create folders that have a purpose. Keep essential constraints and a direct resource index in `SKILL.md`. Resolve links relative to the file containing the link; shell commands must resolve from the actual installed skill directory, not an assumed current directory.

## Validation

Parse YAML; check metadata and folder naming; verify local links in all text files, including examples that represent actual bundled resources. Exclude clearly labelled hypothetical paths from existence checks. Render nested Markdown examples with outer fences longer than any inner fence. Run scripts and representative workflows separately: structural validity is not behavioral proof.
