# neverbrith

English | [简体中文](README.zh-CN.md)

A mod for The Binding of Isaac: Repentance by brick.
**neverbrith**, titled **未生** in Chinese, adds a growing collection of passive and active items built around damage, deal rooms, cards, familiars, and the cost of death.

## Requirements and installation

- **The game and REPENTOGON must be a matching pair.** The current official installation guide targets **Repentance+**; an older **Repentance** installation needs a compatible legacy REPENTOGON release.
- **REPENTOGON is required.** The bootstrap accepts `1.0.12a` or a newer recognized stable release. Missing, outdated, or unrecognized builds stop all gameplay initialization. A warning above each player in the starting room of each floor explains the requirement and asks them to install/update REPENTOGON and restart. It follows the game's Chinese/English language setting. This is a minimum startup check, not a recommended or verified game-and-loader combination.
- **External Item Descriptions (EID) is optional.** It displays the descriptions supplied by this mod; core item behavior does not require EID.

When the dependency check fails, only the vanilla-safe warning and drop blocker load. Mod collectibles and the slot-seal trinket are removed from the pools. Any remaining spawned/morphed mod collectibles become Breakfast; slot-seal trinkets become Paper Clip (preserving golden status), and Wind Charge Potion resolves to Bad Gas. Vanilla and other mods' drops are left alone. Existing held items are not stripped from saves. To preserve `1.0.12a` compatibility, the engine still reads the packaged XML/resources; this guard disables gameplay and drops rather than unloading those engine registrations.

Follow the [official REPENTOGON installation guide](https://repentogon.com/install.html) for its currently supported game versions and launch instructions. Do not apply the current Repentance+ launcher instructions to an older Repentance installation without checking the matching release instructions.

This repository does not currently document a verified game-and-REPENTOGON version pair. Automated behavior tests use simulated game APIs, including a `1.0.12a` REPENTOGON fixture; they do not verify an installed game, the current launcher, or third-party mod combinations.

Download this repository with **Code → Download ZIP**, then place its contents in the `mods/neverbrith/` folder used by your game. Alternatively, run `git clone https://github.com/BrickAZ/neverbrith.git neverbrith` from that `mods` directory. Keep `main.lua`, `metadata.xml`, the other Lua modules, and the `generated/`, `content/`, and `resources/` directories together. Enable **neverbrith** in the Mods menu and restart the game using your REPENTOGON setup. Keep only one copy of the mod enabled, and close the game before updating its files.

## Current status

**Custom characters are temporarily disabled.** Character assets and development files remain in the repository, but no selectable custom characters are currently registered. Development and regression checks are ongoing; some entries remain experimental or unfinished, including `ds4`, whose effect is not implemented.

## Localization

Simplified Chinese and English item XML templates, EID descriptions, and selected runtime messages are maintained. Check the text for the affected item when reporting a translation issue; these resources do not establish complete bilingual coverage of every runtime message.

**Native pickup banner localization is paused.** The XML language tools remain available for maintenance, but they are not a required launch step and do not provide in-game language switching.

To synchronize static item names and item-pool entries, close the game and run one of these commands from the mod root:

```powershell
# English: synchronize files without launching the game
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start-neverbrith.ps1 -Language en_us -NoLaunch

# Simplified Chinese: synchronize files without launching the game
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start-neverbrith.ps1 -Language zh_cn -NoLaunch
```

This overwrites `content/items.xml` and `content/itempools.xml` with the chosen templates without launching the game. Then launch through your REPENTOGON setup. XML changes require a game restart; EID uses its own language setting.

## Compatibility guides

- [English compatibility guide](COMPATIBILITY.md)

Compatibility covers Fortune Rivalling Heaven Gu Luck thresholds, Dice Set custom dice active items, and custom character registration for Memory Disorder's random identity pool.

These interfaces are provisional and unversioned. Read the guides before integrating another mod.

## Development and checks

| Path | Purpose |
| --- | --- |
| `main.lua` and root Lua modules | Bootstrap, item behavior, and integrations |
| `generated/` | Generated collectible registration data |
| `content/` | Item, pool, entity, and other XML registrations |
| `resources/` | Graphics, animations, and audio |
| `tests/` | Behavior, asset, and documentation checks |
| `tools/` | Language, asset generation, and maintenance scripts |

Use Lua 5.4 and PowerShell 7 (pwsh) for development checks so UTF-8 scripts are read correctly. Run the following commands as needed from the mod root; each covers its own static or simulated scenarios and does not establish a passing full suite or in-game acceptance. README checks can run independently of compatibility-guide checks.

```powershell
luac -p main.lua
lua tests/repentogon_bootstrap_test.lua
lua tests/repentogon_dependency_guard_test.lua
lua tests/localization_test.lua
lua tests/fortune_custom_cache_behavior_test.lua
lua tests/dice_set_behavior_test.lua
pwsh -NoProfile -File tests/compatibility_docs_test.ps1 -ReadmeOnly
pwsh -NoProfile -File tests/compatibility_docs_test.ps1
```

## Author and feedback

- **brick**
- [YouTube: Brickzhou](https://www.youtube.com/@Brickzhou)
- Bilibili: search for `青春啊砖在he边看月亮`
- [GitHub Issues](https://github.com/BrickAZ/neverbrith/issues)

When reporting an issue, include your game and REPENTOGON versions, affected items, reproduction steps, and other enabled mods.
