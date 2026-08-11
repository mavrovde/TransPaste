---
name: add-provider
description: Add a new AI translation provider to TransPaste's TranslationService. Use when asked to support a new LLM API.
---

# Add a translation provider

All provider logic lives in `Sources/TranslationService.swift`. First check
whether the API is OpenAI-compatible — if so, the built-in **Custom** provider
(configurable endpoint + model + optional token) may already cover it with
zero code.

For a genuinely new wire format:

1. **Enum case** in `TranslationProvider` + entries in every switch:
   `displayName`, `model`, `environmentVariable`, `defaultsKey`, `apiKeyURL`,
   and `requiresAPIKey` (false only for key-less local endpoints).
2. **Wire structs**: `XxxRequest` / `XxxResponse` Codable pairs next to the
   existing ones. Response fields must be optional wherever the API can omit
   them (safety blocks, refusals, error envelopes).
3. **`makeRequest`**: endpoint + auth header. **API keys go in headers, never
   URLs** (proxies log URLs). Add any required version headers.
4. **`parse`**: handle the provider's error envelope first, then extract the
   text. Watch for reasoning/thinking blocks before the answer (Claude) and
   refusal stop reasons — never blindly take the first content element.
5. **Tests** in `Tests/TranslationServiceTests.swift`: request construction
   (headers, endpoint, body via decoding the encoded body), response parsing
   (success, API error, malformed JSON), and an end-to-end `translate()` case
   through `MockURLProtocol`. Register nothing — the file's `run...Tests()` is
   already called from TestMain.
6. **Menu**: nothing to do — the Provider submenu, key pasting, and key-URL
   items derive from `TranslationProvider.allCases`.
7. **Docs**: README (features, key setup, model table), CLAUDE.md
   (architecture bullet), `.env.example` (new env var).
8. Run `/ship`.
