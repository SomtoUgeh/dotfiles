# SSH identities and commit signing

One GitHub identity uses two Ed25519 keys, and the AltSchool VM uses one RSA
key. All three are held in 1Password. No private key material exists on this
machine as a file.

| Key | Vault | Account | Role |
|---|---|---|---|
| `somto_auth_ed25519` | Personal | `SomtoUgeh` | authentication |
| `somto_sign_ed25519` | Personal | `SomtoUgeh` | commit signing |
| `AltSchool VM SSH Key` | Personal | `altschool` VM | authentication |

Identity is folder-driven by `includeIf` in `git/.gitconfig`:
`~/code/personal/`, `~/code/TalentQL/`, and the agent worktree dirs get the
personal identity. `user.useConfigOnly = true` makes a commit in an unmapped
directory fail loudly rather than pick a wrong identity.

`github.com` and the `github-personal` alias both use the personal
authentication key. The personal gitconfig rewrites GitHub URLs onto
`github-personal`. The dotfiles checkout also stores that rewrite in
`.git/config`, and the agent git guard blocks `https://github.com` / gist
URLs, so skipping `~/.gitconfig` is not enough to push over HTTPS.

Rebuild on a new machine: `scripts/setup_ssh_from_1password.sh`

## Signing details

**No key passphrase.** Keys were generated inside 1Password
(`op item create --ssh-generate-key`), so the private half has never existed
as a file. Protection is the vault plus per-application agent approval.

**Public keys are kept in `~/.ssh`.** Private keys never existed here, and the
`.pub` files are required: to pin which agent identity is offered per host
(`IdentityFile`), and to build `allowed_signers`. Public keys are not secret.

**`User git` in `~/.ssh/config`.** GitHub SSH always authenticates as `git`.

**`allowed_signers` principal is the commit email.** Git matches the principal
against the commit's email, with `namespaces="git"`. A username principal
yields "No principal matched" on verify.

**`signingkey` is the signing public key,** `somto_sign_ed25519.pub`, not the
authentication key. Pointing it at the auth key produces `unknown_key` on
GitHub.

**`agent.toml`.** `~/.config/1Password/ssh/agent.toml` serves the Personal
vault. Without it the agent can omit a key and `op-ssh-sign` fails with
"No SSH private key found for the specified public key". Template:
`templates/1password-agent.toml.template`.

Do not click 1Password's "Edit automatically" for the SSH agent. That button
rewrites `agent.toml` with item-scoped entries and drops vault scoping.

## History note

Commits `eacada85` and `820328b0` (Aug 2026) are permanently `unverified`
with reason `unknown_key`. They carry a valid signature from
`SHA256:KknGjlvmRCI1F20xidOUwmEFeHy38azKS6XmbvDKzv8`, a key that was never
uploaded to GitHub as a Signing key and no longer exists. Everything before
and after verifies. Not worth rewriting history over.
