---
name: bump-models
description: Check and update the default provider models/endpoints in the ProviderConfig template. Use periodically or when a provider deprecates a model.
---

# Bump provider models/endpoints

Defaults live in one place: the `ProviderConfig.template` string in
`Sources/TranslationService.swift`. Users' own `~/.transpaste/providers.json`
files are theirs — we only change what new installs (and template fallback) get.

1. For each provider, verify the current default is still the right
   fast/cheap choice:
   - **Gemini** (`gemini-flash-latest` — alias, usually self-updating): check
     Google's model list docs.
   - **OpenAI**: check the models page for the current mini-tier model.
   - **Claude**: use the context7 plugin or the claude-api skill for current
     model IDs — never guess Anthropic model strings; also confirm
     `anthropic-version` header and Messages API shape are current.
   - **Ollama**: check which small model is the current widely-pulled default.
2. Update the template **and** the matching test expectations in
   `Tests/TranslationServiceTests.swift` (model names appear in request tests).
3. If an endpoint changed shape (not just the model name), that's not a bump —
   follow `.claude/skills/add-provider/SKILL.md` step 3–4 and update the wire
   structs.
4. Update the model table in README.md and the models list in CLAUDE.md.
5. Note in the PR description that existing users keep their old defaults
   until they delete their providers.json (by design) — mention editing it.
6. Run `/ship`.
