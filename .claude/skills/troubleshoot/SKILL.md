---
name: troubleshoot
description: Diagnose TransPaste runtime problems — hotkey not firing, nothing pasted, provider/API errors, permission issues. Use when the app misbehaves for a user.
---

# Troubleshoot TransPaste

Start with the log — every subsystem writes there:
`tail -50 ~/translator.log`

## Symptom → cause map

| Log/symptom | Cause | Fix |
|---|---|---|
| No "Carbon Hotkey Detected" on keypress | Input Monitoring not granted, or hotkey registration failed at launch | "Setup Assistant…" in the menu; else `./automated_setup.sh` |
| "AX Failed ... -25211" | Accessibility permission missing/stale (kAXErrorAPIDisabled) | Re-grant Accessibility; stale grants after rebuild → `./automated_setup.sh` (TCC is signing-identity-bound) |
| "Clipboard empty or invalid after retries" | Cmd+C simulation blocked (Accessibility) or the target app has no selection and blocks Cmd+A | Re-grant Accessibility; test in TextEdit to isolate the app |
| "API Error: ..." | Provider rejected the request — bad key, quota, wrong model | Check the selected provider's key (menu or env var); check the model in `~/.transpaste/providers.json` still exists |
| `noAPIKey` | Selected provider has no key configured | Menu → "Paste <Provider> API Key" (Ollama/Custom need none) |
| "Invalid provider config" | `~/.transpaste/providers.json` broken JSON (comments are fine, JSON syntax is not) | Fix or delete the file — it regenerates from defaults |
| Connection refused on localhost | Ollama/custom server not running | `ollama serve` / start the server; verify endpoint in config |
| Claude "declined this request" | Safety classifier refusal on the captured text | Expected behavior — switch provider for that text |
| Pastes into the wrong app | Focus changed between confirm and paste | Don't click other windows during the 0.5s paste-back window |
| Translation flow fires twice | Duplicate hotkey registration (fixed by idempotent `start()`) | Update to current build |

## Escalation
- Reproducible with clear log evidence of a code defect → file it and fix via the `ship` skill.
- Permission weirdness that survives `automated_setup.sh` → `tccutil reset` both services for `com.mavrovde.transpaste`, reboot, re-grant.
- New learnings go into `.claude/KNOWLEDGE.md`.
