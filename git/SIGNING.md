# Commit signing and SSH identities

Two GitHub identities, four ed25519 keys, all held in 1Password. No private
key material exists on this machine as a file.

| Key | Vault | Account | Role |
|---|---|---|---|
| `somto_auth_ed25519` | Personal | `SomtoUgeh` | authentication |
| `somto_sign_ed25519` | Personal | `SomtoUgeh` | commit signing |
| `swissblock_auth_ed25519` | Swissblock | `somto-swissblock` | authentication |
| `swissblock_sign_ed25519` | Swissblock | `somto-swissblock` | commit signing |

Identity is folder-driven by `includeIf` in `git/.gitconfig`:
`~/code/personal/` and `~/code/TalentQL/` get the personal identity,
`~/code/work/` gets Swissblock. `user.useConfigOnly = true` makes a commit in
an unmapped directory fail loudly rather than pick a wrong identity.

`github.com` resolves to the **work** key. Personal repos use the
`github-personal` alias, and the personal gitconfig rewrites URLs onto it, so
you rarely type it.

Rebuild on a new machine: `scripts/setup_ssh_from_1password.sh`

## Accepted deviations from the Swissblock signing doc

Recorded deliberately, with the reasoning, so this is auditable.

**No key passphrase.** The doc requires a >=32 character passphrase. These keys
were generated *inside* 1Password (`op item create --ssh-generate-key`), so the
private half has never existed as a file and there is nothing on disk for a
passphrase to protect. Protection is the vault plus per-application agent
approval. Reviewed and accepted.

**Work keys in a personal 1Password account.** The `Swissblock` vault lives in
a personal 1Password account rather than a company-managed one. Reviewed and
accepted.

**Public keys are kept in `~/.ssh`.** The doc's final step deletes all key
files. Private keys never existed here, and the `.pub` files are required: to
pin which of four agent identities is offered per host (`IdentityFile`), and to
build `allowed_signers`. Public keys are not secret.

## Where the doc appears to be wrong

**`User <github-username>` in `~/.ssh/config`.** GitHub SSH always
authenticates as `git`. As written, `git clone github.com:org/repo` attempts
`somto-swissblock@github.com` and fails. This setup uses `User git`.

**Username as the `allowed_signers` principal.** The doc writes
`echo "${GITHUB_USER_NAME} $(cat pub)"`. Git matches the principal against the
commit's *email*, so a username principal yields "No principal matched" on
verify. This setup uses emails plus `namespaces="git"`.

**No mention of `agent.toml`.** Without
`~/.config/1Password/ssh/agent.toml` the agent serves only a default subset of
vaults. The Swissblock vault was excluded, and `op-ssh-sign` failed with
"No SSH private key found for the specified public key". Template:
`templates/1password-agent.toml.template`.

## History note

Commits `eacada85` and `820328b0` (Aug 2026) are permanently `unverified`
with reason `unknown_key`. They carry a valid signature from
`SHA256:KknGjlvmRCI1F20xidOUwmEFeHy38azKS6XmbvDKzv8`, a key that was never
uploaded to GitHub as a *Signing* key and no longer exists. Everything before
and after verifies. Not worth rewriting history over.
