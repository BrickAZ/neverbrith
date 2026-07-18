---
name: isaac-validators
description: Run or extend static validators for the Binding of Isaac Repentance `neverbrith` mod. Use this whenever the user asks to verify, check, validate, sanity-check, catch broken XML, duplicate ids, missing assets, missing translations, blank cards, broken anm2/png paths, skill directory consistency, or whether a coding agent's Isaac mod changes are safe before in-game testing. This skill provides deterministic checks instead of relying only on plausible-looking code review.
---

# Isaac Validators

Use this skill after Isaac mod edits, before claiming work is done, and whenever the user reports broken loading, blank cards, missing icons, missing text, or assets that do not show.

The goal is to catch static mistakes early. This does not replace in-game testing, but it should stop many XML/path/id/localization mistakes before Isaac is launched.

## First Move

Before reviewing by eye, run the bundled validator when possible:

```powershell
powershell -ExecutionPolicy Bypass -File docs/skills/isaac-validators/scripts/validate-neverbrith.ps1
```

If the task is only a handoff prompt, include this command in the required verification section.

## What The Validator Checks

The first version checks:

- XML files under `content/` can be parsed.
- Duplicate `id` and `name` attributes inside the same XML file.
- Obvious missing asset paths referenced from XML values ending in `.anm2`, `.png`, `.wav`, `.ogg`, `.mp3`, `.fs`, or `.fsh`.
- `docs/skills/*/SKILL.md` exists.
- `docs/skills/*/evals/evals.json` parses when present.
- Basic language-file shape across `items.xml`, `items.en_us.xml`, and `items.zh_cn.xml`.

Read `references/static-checks.md` before extending the validator. Read `references/validation-reporting.md` before reporting results to the user.

## Hard Rules

- Do not call static validation "game verified." Static checks prove only that files are internally plausible.
- If a validator failure points at unrelated dirty work, report it separately and do not silently fix it unless the user asked.
- Prefer adding a deterministic validator for repeated mistakes instead of writing the same manual checklist again.
- Keep validators conservative. A false positive that blocks every run will teach future agents to ignore the tool.
- When a validator cannot know Isaac runtime behavior, mark the result as a warning or manual-check item.

## When To Extend

Extend this skill or its script when a mistake repeats:

- Blank or abnormal card generation.
- Missing card HUD/pickup art.
- Missing EID or localization entry.
- `.anm2` references a spritesheet that is absent.
- XML id/name duplicates.
- Challenge rule leaks into normal runs.
- A coding agent forgets to run behavior tests.

## Final Review

Before saying validation is complete, report:

- Validator command run.
- Pass/fail summary.
- Any failures that belong to the current task.
- Any failures that appear pre-existing or unrelated.
- Manual in-game checks still required.
