---
name: isaac-validators
description: "Use when Isaac mod changes need static XML, ID, Lua registration, localization, PNG or ANM2 path checks, or when a project's validator reports broken content. 中文触发：静态校验、XML 报错、重复 ID、贴图路径、翻译缺失、空白卡牌或实体。"
---

# Isaac Validators

## User Decisions and Technical Discovery

Read the [shared decision and evidence policy](../isaac-mod-context/references/tbd-disclosure.md).

Use this skill after Isaac mod edits, before claiming work is done, and whenever the user reports broken loading, blank cards, missing icons, missing text, or assets that do not show.

The goal is to catch static mistakes early. This does not replace in-game testing, but it should stop many XML/path/id/localization mistakes before Isaac is launched.

## First Move

Use `isaac-mod-context` to identify the actual mod root, its own verification
entry point, and the compatible shell. Use the project's documented check
when it has one. In a confirmed neverbrith checkout, consult
`docs/agent/testing.md` and use the repository's `tools/check-neverbrith.ps1`
via `isaac-neverbrith-validator-profile`. It selects the repository versions
of both validators. Record a missing or blocked runner explicitly; don't
substitute an installed copy or override execution policy to report a pass.

If the project has no static check, run the bundled generic validator from
the discovered mod root. Replace `./path/to/isaac-validators` with this
skill's actual directory:

```powershell
pwsh -NoProfile -File "./path/to/isaac-validators/scripts/validate-isaac-mod.ps1" -Root .
```

Supply `-ModObjectName` and `-LuaDirectories` only when discovery calls for
them. Add `-CheckPngTransparency` when reviewing a colored collectible PNG
with this bundled runner. Its warnings flag alpha, matte and low-luminance
patterns for review. Project versions may support different parameters.

For a handoff prompt, include the discovered command and the evidence it can
produce.

## Validation Profiles

- **Generic runner**: accepts any mod root and optional mod object name; discovers `resources/` and versioned `resources-*` roots unless `-ResourceDirectories` is supplied; parses XML, checks duplicate XML keys and asset paths, scans direct callback registrations in `main.lua` plus `scripts/` by default, accepts additional `-LuaDirectories` when a project uses another module root, and can verify a supplied skill package. A resource-only mod does not need Lua or `content/` to pass.

The generic runner is intentionally conservative. A project-specific overlay
may add checks only after that project establishes a stable convention.

## What The Validator Checks

The first version checks:

- XML files under `content/` and discovered resource roots can be parsed.
- A root-level `content/` XML filename that is very close to a known native registration filename receives an `XML_FILENAME` warning; syntactically valid `costymes2.xml` may still be ignored instead of loading as `costumes2.xml`.
- Resource-only layouts are accepted; native-named tables such as resource-root `players.xml` or `costumes2.xml` receive exact-path/load-order warnings rather than a false missing-content failure.
- Unresolved asset references from those broad native tables are summarized per file because they may intentionally fall back to official game resources; the summary still requires target-build and in-game verification.
- Asset references resolve across every discovered resource root, including versioned roots such as `resources-dlc3/`.
- Lua references to ANM2 events are compared with events declared by local ANM2 files. An unbound missing event is a warning; a proven target contract must be reviewed by `isaac-anm2-visuals`.
- High-frequency callbacks that also load/replace spritesheets and uses of `Isaac.GetPlayer(0)` receive conservative runtime/co-op warnings.
- Duplicate `id` and `name` identities inside the same XML file, qualified by discovered discriminator attributes such as `type`, `variant`, `subtype`, and `skinColor` so valid native variants are not collapsed.
- Obvious missing asset paths referenced from XML values ending in `.anm2`, `.png`, `.wav`, `.ogg`, `.mp3`, `.fs`, or `.fsh`.
- When the optional `-CheckPngTransparency` profile is requested, custom collectible `gfx` PNGs are decoded to warn about a missing alpha channel, a uniform opaque corner matte, or a large dense low-luminance rectangle including an inset plate. This is a warning, because intentionally full-frame art must remain a user decision and a generic validator cannot infer the intended subject mask.
- Validate the selected authoritative skill root discovered for the project; do not assume a `docs/skills` mirror is current.
- Each selected package has `SKILL.md`; its `evals/evals.json` parses when present.
- Skills are self-contained: no third-party mod names or absolute local paths appear in their Markdown/JSON instructions.
- Direct callback registrations across Lua modules point at existing handlers and are not duplicated with the same callback/handler/filter tuple when the source uses the supported direct form.

Read `references/static-checks.md` before extending the validator. Read `references/validation-reporting.md` before reporting results to the user.


`-CheckPngTransparency` is a conservative image warning profile, not a proof that arbitrary art is correct. It can catch missing alpha, a uniform opaque outer matte, and a large dense low-luminance rectangle including an inset plate. It cannot infer an author's intended subject mask, decide whether a deliberately dark full-frame object is wrong, or validate ANM2 frame crops without their discovered crop manifest. Pair it with `isaac-anm2-visuals` and the three-background visual review.

## Character-Art Contract Preflight

Before running or extending a character-art profile, read `../isaac-character-art-surfaces/references/source-fact-and-mode-validation.md` and compare the selected surface, art mode, Alpha policy, approved masks, identity requirements, and validator assertions. Treat a contradictory configuration as a blocked contract, not as proof that the candidate is bad.

- `pure-recolor` may require complete source-Alpha equality.
- `original-full-skin` must allow controlled Alpha changes inside approved owning masks.
- `separate-decoration` validates its layer independently from the base.
- UI/name/portrait surfaces use their own measured Alpha policies rather than a project-wide binary rule.

Use `isaac-character-art-surfaces/scripts/inspect-png-surface.ps1`, `isaac-anm2-visuals/scripts/build-anm2-crop-manifest.ps1`, and `isaac-character-art-surfaces/scripts/validate-owned-crops.ps1` for deterministic facts. Their pass result is static evidence only; it cannot prove identity, visual quality, native-scale proportion, or in-game rendering.

## Hard Rules

- Do not call static validation "game verified." Static checks prove only that files are internally plausible.
- Do not fail a confirmed resource-only mod because `main.lua`, `RegisterMod`, or `content/` is absent.
- Do not decide which same-relative-path resource wins across roots or mod load order without runtime/version evidence.
- Treat near-native XML filenames, hot-path asset reload, first-player ownership, broad exact-path override, and unbound ANM2 event results as warnings unless a narrower proven contract justifies failure.
- If a validator failure points at unrelated dirty work, report it separately and do not silently fix it unless the user asked.
- Prefer adding a deterministic validator for repeated mistakes instead of writing the same manual checklist again.
- Keep validators conservative. A false positive that blocks every run will teach future agents to ignore the tool.
- For character hair or head decorations, never require both side edges to contain pixels, impose a high minimum visible-pixel count, or require the silhouette to exceed the vanilla head. Those checks reward filling the crop and are invalid.
- When reviewing whether a proposed validator rule is sound in the abstract, give the conceptual verdict without inventing project-specific TBDs that do not affect that verdict. Crop manifests, alpha thresholds, and paths become active only when the user asks to implement or run the check.
- A project-specific character-art profile may warn about a discovered maximum bounding box, anchor/center drift, abrupt direction/frame size changes, protected-face coverage, dirty alpha, or cross-crop pixels. It must report these separately from the native `1x` visual verdict and must not claim that a passing file is attractive, proportionate, or not a head shell.
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
- A published skill accidentally requires a source mod from the original author's machine.
- A custom entity, card, or pickup can spawn with no meaningful content because its registration or asset chain is incomplete.
- A generated colored collectible PNG is flattened onto black and renders as an opaque square on its pedestal.

## Completion Checks

Review the following where relevant to the change:

- Validator command run.
- Pass/fail summary.
- Any failures that belong to the current task.
- Any failures that appear pre-existing or unrelated.
- Manual in-game checks still required.
