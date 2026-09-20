# Localization Token Research

> **Historical research / archived workflow.** Native pickup banner localization is paused. This page records earlier experiments, not current installation instructions or verified runtime support. Use the [current README](../README.md) ([简体中文](../README.zh-CN.md)) for requirements and launch guidance. The current mod requires REPENTOGON.

## v2 stringtable attempt

The v2 experiment changed mod item names and pickup descriptions in
`content/items.xml` to `#NEVERBIRTH_*` tokens and added
`resources/stringtable.sta` using the official stringtable structure.

In game, the pickup banner showed raw values such as
`#NEVERBIRTH_ANGELBOX_NAME` and `#NEVERBIRTH_ANGELBOX_DESCRIPTION`. This means
the mod-local `resources/stringtable.sta` was not loaded by Isaac for custom
item XML pickup text.

## v2.1 decision

Playable builds should not ship `#NEVERBIRTH_*` tokens in `content/items.xml`.
Until a working mod API or loader path is proven in game, item pickup text uses
English fallback strings in XML, while EID handles explicit `en_us` and `zh_cn`
descriptions.

Future token experiments should happen outside playable builds and test one
loader path at a time, including `resources/stringtable.sta`, root
`stringtable.sta`, `content/stringtable.sta`, `translations.xml`, and possible
REPENTOGON-only APIs.

## v3 language template switch

The v3 experiment used explicit XML templates instead of inactive
stringtable tokens. The initial v3 attempt copied only
`content/items.en_us.xml` or `content/items.zh_cn.xml` to `content/items.xml`
before the game started.

This is not runtime language switching. Isaac reads `content/items.xml` when the
mod content is loaded, so any XML synchronization must happen before launching
or after quitting the game.

## v3.1 complete XML language packs

The v3 template switch was not enough for native pickup banners because the
pickup title comes from the item XML `name`, not from EID. Changing only
`description` leaves titles such as `Angelbox` and `Musicbox` in the banner.

The v3.1 experiment switched both `content/items.xml` and
`content/itempools.xml`. Chinese item templates use Chinese pickup names, and
the matching Chinese item pool template uses the same names so item pool
references stay valid. Lua item ID lookup must therefore try both English and
Chinese candidate names for each mod item.

This remains a startup-time language pack switch, not automatic runtime
language switching.

## v3.2 synchronized launcher

The v3.2 experiment introduced `tools/start-neverbrith.ps1` to synchronize XML
files before directly launching `isaac-ng.exe`. That direct launch path is not
the current REPENTOGON launch recommendation. Tests and manual edits can leave
the active XML files different from either language template.

`tools/check-items-language.ps1` reports the current playable XML state as
`en_us`, `zh_cn`, `mixed`, or `unknown`. The launcher copies the requested
language pack, runs the check, and refuses to launch the game if the playable
XML files do not match the requested language.

Matching XML files only confirms file synchronization; it does not prove native
pickup banner rendering or that REPENTOGON was loaded. For current maintenance,
close the game and use `-Language en_us -NoLaunch` or `-Language zh_cn -NoLaunch`
with this script, then launch through the appropriate REPENTOGON setup described
in the README. The old experiment is not evidence that the current mod runs
without REPENTOGON.

## Pause notice

Native pickup banner localization is paused after v3.2. Keep the v3.2 branch as
a documented checkpoint, but do not continue iterating on banner synchronization
unless this work is explicitly reopened.

This pause does not apply to translation maintenance. Item XML language
templates and EID descriptions should continue to be updated together whenever
mod item text changes.
