# Create a Domain Skill

Read [core principles](../references/core-principles.md), [recommended structure](../references/recommended-structure.md), and [verification](verify-skill.md).

Define the domain and supported lifecycle from the user's request. Cover the complete chosen scope without promising every library or possible task in the domain. Reuse existing domain owners and native tools.

## Research

Identify current architecture, build, debugging, test, performance, and distribution requirements for the chosen platforms. Verify fragile APIs against released packages and primary documentation. Compare alternatives only where the choice matters; explain when the default does not fit. Do not classify a stable library as abandoned solely from commit frequency or use a fixed search count as proof of completeness.

## Build

1. Choose one valid skill name, such as `build-game-tools`, and use that exact directory name. Install as a directly discoverable skill under the verified root; do not invent a nested `expertise` loader convention.
2. Route the supported user intents to actual workflows. Infer the selected route from the request; ask only for ambiguity.
3. Put shared constraints in the entrypoint and reference knowledge by domain concern.
4. Each workflow supplies implementation steps, required references, error/recovery behavior, and observable verification.
5. Each technical reference supplies compatibility limits, decision criteria, a tested example or labelled fragment, and primary sources.
6. Follow [create-new-skill.md](create-new-skill.md) for initialization and validation.

## Verify

Exercise each declared workflow using a suitable fixture. Include direct invocation and reference-only consumption if both are supported. Build/run checks are distinct from publishing, signing, account acceptance, and physical-device behavior. Mark unavailable checks explicitly.

Update another skill's discovery table only if that file exists and the requested integration needs it. Do not create or edit a presumed `create-plans` skill. Complete when the declared workflows work within their tested environments and remaining limits are explicit.
