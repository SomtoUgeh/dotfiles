# GitHub repository rulesets

Server-side repository policy, configured once per repository and revisited
when policy changes. Installing dotfiles on another machine does not require
reapplying these rules. They restrict force pushes, default-branch deletion or
unsigned commits; they do not detect malware or prevent every abuse of a valid
credential.

Preview changes with `apply_github_rulesets.sh --repo REPO`; use `--apply`
only when deliberately updating the repository policy.

## Files

| File | Rules | When |
|---|---|---|
| `default-branch.json` | `non_fast_forward`, `deletion` | default-branch protection |
| `signed-commits.json` | `required_signatures` | **only after SSH signing works** |

## Order matters

Review the dry run and apply `default-branch.json` first.

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

`deletion` blocks deleting the selected default branch; it does not target
ordinary feature-branch cleanup. If policy requires an exemption, add a bypass actor. The `bypass_actors`
field takes a numeric `actor_id` for a `RepositoryRole`, and the ID values are
not stable knowledge worth hardcoding — set it in the web UI instead
(Ruleset → Bypass list → Add → Repository admin), which writes the correct ID.

## Verify what is live

    gh api repos/OWNER/REPO/rulesets
    gh api repos/OWNER/REPO/rulesets/RULESET_ID
