# GitHub repository rulesets

Server-side push rules. These are the only control here that holds when an
attacker has a **valid** credential — every other layer assumes the token is
trustworthy. The git-worm incident force-pushed 112 times across 42 repos;
`non_fast_forward` turns each of those into an error.

Apply with `apply_github_rulesets.sh` (symlinked into `~/bin` by install.sh).

## Files

| File | Rules | When |
|---|---|---|
| `default-branch.json` | `non_fast_forward`, `deletion` | now |
| `signed-commits.json` | `required_signatures` | **only after SSH signing works** |

## Order matters

Apply `default-branch.json` first and freely.

Do **not** apply `signed-commits.json` until `git commit` produces a verified
signature locally. Enabling it while signing is broken locks you out of your
own default branch. Verify first:

    git commit --allow-empty -S -m "signing test"
    git log --show-signature -1

## Target

`~DEFAULT_BRANCH` is deliberate — it resolves per repo. Some repos here
default to `master` and others to `main`; naming a branch explicitly gets it
wrong on the ones that differ.

## Bypass actors

`deletion` blocks deleting the default branch, and will also block routine
branch cleanup. To exempt yourself, add a bypass actor. The `bypass_actors`
field takes a numeric `actor_id` for a `RepositoryRole`, and the ID values are
not stable knowledge worth hardcoding — set it in the web UI instead
(Ruleset → Bypass list → Add → Repository admin), which writes the correct ID.

## Verify what is live

    gh api repos/OWNER/REPO/rulesets
    gh api repos/OWNER/REPO/rulesets/RULESET_ID
