# turnstile-spin (skill)

End-to-end setup skill for Cloudflare Turnstile. Loads when an agent is asked to add Turnstile, set up CAPTCHA, or protect a form from bots.

`SKILL.md` defines this locally maintained bundle's behavior. The hosted prompt at [`developers.cloudflare.com/turnstile/spin/prompt.md`](https://developers.cloudflare.com/turnstile/spin/prompt.md) is the upstream reference and may not contain these local fixes. Product requirements come from the [Turnstile documentation](https://developers.cloudflare.com/turnstile/).

## Layout

| File                              | Purpose                                                                |
| --------------------------------- | ---------------------------------------------------------------------- |
| `SKILL.md`                        | Main wizard instructions for the agent                                 |
| `scripts/auth-probe.sh`           | Probes the customer's Cloudflare API token for Turnstile scope         |
| `scripts/widget-create.sh`        | Creates the Turnstile widget via the Cloudflare API                    |
| `scripts/validate.sh`             | Dummy-siteverify + hostname check at the end of the wizard             |
| `scripts/persist-skill.sh`        | Copies this locally maintained skill bundle into the user's repo               |
| `references/vanilla-html.md`      | Code snippet for static / vanilla HTML projects                        |
| `references/nextjs-app.md`        | Code snippet for Next.js App Router projects                           |
| `references/nextjs-pages.md`      | Code snippet for Next.js Pages Router projects                         |
| `references/astro.md`             | Code snippet for Astro projects                                        |
| `references/sveltekit.md`         | Code snippet for SvelteKit projects                                    |
| `references/hugo.md`              | Code snippet for Hugo projects                                         |
| `tests/validation.md`             | Validation cases matching the assertions in the PRD                    |
| `templates/verify-turnstile.ts` | Shared server-only verification implementation |
| `tests/siteverify.test.ts` | Isolated Siteverify contract tests |
| `tests/test_auth_probe.py`        | Offline mock-curl regressions for probe and cleanup outcomes            |

## How agents load it

The dotfiles installer exposes this bundle through the shared skill library and each supported agent's native discovery path. Use that installed bundle to preserve local fixes. To save this same bundle in a confirmed project location, run its installed `scripts/persist-skill.sh --path .agents/skills/turnstile-spin/SKILL.md` from the project root. The target must be absent or empty. The helper copies the current bundle locally and reports failure if the copy cannot finish; it does not clone or download an upstream replacement.

File-oriented rules should point to the installed bundle rather than copy a hosted prompt that lacks local fixes. Check the active runtime's actual discovery paths.

## Maintaining local fixes

Keep local script contracts, `SKILL.md`, and the offline regression tests aligned. Upstream updates to `cloudflare/skills` or `public/turnstile/spin/prompt.md` in `cloudflare-docs` are separate publication work and require the user's authorization. Do not overwrite this bundle with an upstream download when persisting it.

## Related

- [Canonical docs page](https://developers.cloudflare.com/turnstile/spin/)
- [`cloudflare/skills`](https://github.com/cloudflare/skills) — root index for all Cloudflare agent skills
- [Turnstile server-side validation](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/) — canonical siteverify reference
