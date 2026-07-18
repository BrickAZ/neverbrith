---
name: isaac-audio-render-feedback
description: Add, review, or write handoff prompts for audiovisual feedback in Binding of Isaac Repentance mods, especially neverbrith. Use this whenever a task mentions sounds.xml, SFX, music.xml, shaders.xml, MC_GET_SHADER_PARAMS, MC_POST_RENDER, overlays, screen-space rendering, world-space rendering, input blocking, black-screen risk, render layers, or feedback effects that are not just anm2 hookup. Also use isaac-state-lifecycle when feedback has enable/disable state, timers, cached sprites, or input-lock release conditions.
---

# Isaac Audio Render Feedback

Use this skill for SFX, shader, render, overlay, and input-blocking feedback.

The goal is to keep feedback effects from being wired as the wrong kind of asset. `.anm2` visuals are handled by `isaac-anm2-visuals`; this skill handles the surrounding audio, shader, render timing, screen/world coordinates, and input interception.

## First Move

Before editing or writing a prompt:

1. Decide whether the request is SFX, music, shader, screen-space render, world-space render, input interception, or a combination.
2. If `.anm2` paths or sprite animation names are involved, also use `isaac-anm2-visuals`.
3. If the feedback belongs to a complex active item, also use `isaac-active-item-mechanics`.
4. If feedback state persists beyond one frame, also use `isaac-state-lifecycle`.
5. Inspect local examples before inventing callback names or path conventions.

## Route The Feedback

- **SFX / music**: `content/sounds.xml`, `content/music.xml`, `resources/sfx`, `resources/music`, `SFXManager`, or music manager behavior. Read `references/sfx-music.md`.
- **Shader params**: `content/shaders.xml`, `MC_GET_SHADER_PARAMS`, shader names, enable/disable state, black-screen risk. Read `references/shader-params.md`.
- **Render / overlay**: `MC_POST_RENDER`, player/entity render callbacks, screen-space versus world-space, cached sprites, draw order. Read `references/render-overlay.md`.
- **Input interception**: `MC_INPUT_ACTION`, blocking controls during popups/menus/selection, restoring control safely. Read `references/input-interception.md`.
- **Feedback review**: when reviewing or prompting another agent, read `references/feedback-review-checklist.md`.

## Hard Rules

- Do not use shader changes for a simple sprite flash unless the design really needs a screen/post-process effect.
- Do not create sprites every frame in render callbacks; cache or own them in explicit state.
- Do not mutate core gameplay state in render callbacks unless there is no better callback and the repo already uses that pattern.
- Do not block input without a clear release condition.
- Do not assume shader safety. If a shader can black-screen or obscure gameplay, state fallback and verification.
- Keep screen-space and world-space coordinates distinct.
- Register sounds/shaders in XML and verify the referenced asset path exists.

## Reference Mods

- YSD sound/shader/render/input: `E:/Isaac - Repentance/ysd/content/sounds.xml`, `E:/Isaac - Repentance/ysd/content/shaders.xml`, `E:/Isaac - Repentance/ysd/scripts/unlock_popup_renderer.lua`, `E:/Isaac - Repentance/ysd/scripts/items/untuned_piano.lua`.
- Reverie broad examples: `E:/Isaac - Repentance/reverie/content/sounds.xml`, `E:/Isaac - Repentance/reverie/content/music.xml`, `E:/Isaac - Repentance/reverie/content/shaders.xml`, and render-heavy item scripts under `E:/Isaac - Repentance/reverie/scripts/items/`.

## Handoff Prompt Template

```markdown
## Audio/Render Feedback Spec

- Feedback type:
- Trigger:
- Lifetime:
- SFX/music assets:
- Shader name and params:
- Render callback:
- Coordinate space:
- Input interception:
- Related anm2 assets:
- Fallback if optional/unsafe:
- Existing examples to read:
- Required manual verification:
```

## Final Review

Before saying the feedback is complete, report:

- Which feedback routes were used.
- Every XML and asset path touched.
- Callback names used.
- Coordinate space and render owner.
- Input blocking and release condition.
- Shader/SFX behavior that still needs in-game verification.
