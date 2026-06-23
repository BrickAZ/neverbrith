# neverbrith

A The Binding of Isaac: Repentance mod by brick.

## Author

- brick (青春啊砖在he边看月亮)
- YouTube: https://www.youtube.com/@Brickzhou
- Bilibili: search for `青春啊砖在he边看月亮`

## About

neverbrith is a local mod project for The Binding of Isaac: Repentance.

## Localization status

Native pickup banner localization is paused. The current XML language-pack and
launcher work is kept as a checkpoint, but it is not the active development
path for now.

Text translation remains maintained: item XML templates and EID descriptions
should stay translated when item text changes.

## Language startup

Native pickup banners are loaded from XML before the mod Lua runs. To keep the
banner language in sync, start the game through the neverbrith launcher script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\start-neverbrith.ps1 -Language zh_cn
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\start-neverbrith.ps1 -Language en_us
```

The launcher synchronizes both `content/items.xml` and `content/itempools.xml`
before starting `isaac-ng.exe`. The lower-level `tools/switch-items-language.ps1`
script is kept for tests and maintenance, but is not the recommended player
entry point.
