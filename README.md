# neverbrith

English | [简体中文](README.zh-CN.md)

A mod for The Binding of Isaac: Repentance by brick.
**neverbrith**, titled **未生** in Chinese, adds a growing collection of passive and active items built around damage, deal rooms, cards, familiars, and the cost of death.

## Requirements and installation

- **The Binding of Isaac: Repentance** with a matching **REPENTOGON** installation.
- **REPENTOGON is required.** The current bootstrap requires `1.0.12a` or a newer recognized stable release. Missing, outdated, or unrecognized builds stop initialization with a bilingual message. This is the project's minimum version requirement.
- **External Item Descriptions (EID) is optional.** It displays the descriptions supplied by this mod; core item behavior does not require EID.

Follow the [official REPENTOGON installation guide](https://repentogon.com/install.html) for supported game versions and launch instructions. Passing the mod's version check does not establish compatibility with every game version or combination of mods.

Download this repository with **Code → Download ZIP**, then place its contents in the `mods/neverbrith/` folder used by your game. Alternatively, run `git clone https://github.com/BrickAZ/neverbrith.git neverbrith` from that `mods` directory. Keep `main.lua`, `metadata.xml`, the other Lua modules, and the `generated/`, `content/`, and `resources/` directories together. Enable **neverbrith** in the Mods menu and restart the game using your REPENTOGON setup. Keep only one copy of the mod enabled, and close the game before updating its files.

## Current status

**Custom characters are temporarily disabled.** Character assets and development files remain in the repository, but no selectable custom characters are currently registered. Development and regression checks are ongoing; some entries remain experimental or unfinished, including `ds4`, whose effect is not implemented.

## Localization

Simplified Chinese and English item XML templates, EID descriptions, and selected runtime messages are maintained. Translation coverage varies by item; some recent additions currently have Chinese text only.

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

The public compatibility scope covers only Fortune Rivalling Heaven Gu Luck thresholds and Dice Set custom dice active items. Memory Disorder has no public compatibility API.

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

Use Lua 5.4 and PowerShell 7 (pwsh) for development checks so UTF-8 scripts are read correctly. Some regression checks currently fail. Run the following commands as needed from the mod root; each covers its own static or simulated scenarios and does not establish a passing full suite or in-game acceptance.

```powershell
luac -p main.lua
lua tests/repentogon_bootstrap_test.lua
lua tests/localization_test.lua
pwsh -NoProfile -File tests/compatibility_docs_test.ps1
```

## Author and feedback

- **brick**
- [YouTube: Brickzhou](https://www.youtube.com/@Brickzhou)
- Bilibili: search for `青春啊砖在he边看月亮`
- [GitHub Issues](https://github.com/BrickAZ/neverbrith/issues)

When reporting an issue, include your game and REPENTOGON versions, affected items, reproduction steps, and other enabled mods.
