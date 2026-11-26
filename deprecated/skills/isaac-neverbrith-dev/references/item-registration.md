> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-neverbrith-dev/references/item-registration.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Item Registration Reference

Use this reference when defining a new item or checking whether an item is correctly registered.

Read `item-basic-spec.md` first for new items, item rewrites, handoff prompts, or reviews. Registration should implement the item's already-decided identity; it should not invent quality, pools, tags, art, or localization.

**Required generic contract:** use `isaac-collectible-registration` before this project adapter. Every custom collectible entry must have an explicit, unique, stable local `id`. That XML-local id is not the runtime/global ItemConfig id returned by name lookup and must not be derived from current mod load order. If legacy entries lack local ids, stop the affected registration/death-portrait work and use an append-only migration approved for this project.

## Locate Project Registration

Use the target checkout's `AGENTS.md` and `docs/agent/project-map.md`. Match
entries by declared XML-local ID across `content/items.xml` and its locale
templates. Keep native pool and locale parity when the requested change
touches those surfaces. Discover `gfxroot + gfx` on the actual XML entry.

The repository generator reads `content/items.xml` as its base and joins
localized names by local ID. When those inputs change the rows, regenerate
`generated/neverbirth_collectibles.lua` with the repository tool after the
XML changes. Running it without `-Check` writes the generated file. From the
mod root verify synchronization with:

```powershell
pwsh -NoProfile -File tools/generate-neverbirth-collectibles.ps1 -Root . -Check
```

Never hand-edit generated rows. The generated registry is used by a runtime
consumer loaded from `main.lua`. It neither registers native collectibles nor
provides their runtime IDs. Inspect the actual behavior owner and its test
for live lookup by registered name; retain the project's existing owner and
callback structure.

## XML Shape

Passive item:

```xml
<passive
  id="STABLE_LOCAL_ID"
  name="Item Name"
  cache="damage speed"
  description="Short pickup text"
  gfx="ItemName.png"
  quality="3"
  tags="offensive summonable"
/>
```

Active item:

```xml
<active
  id="STABLE_LOCAL_ID"
  name="Item Name"
  cache="luck"
  maxcharges="3"
  initcharge="3"
  description="Short pickup text"
  gfx="ItemName.png"
  quality="3"
  tags="summonable"
/>
```

Only include `cache` values that are actually handled in `MC_EVALUATE_CACHE`.

## Lua ID Lookup

Follow the existing runtime lookup in the owning module. Keep the runtime
ItemConfig ID separate from the XML-local ID used by registration and native
frame mappings. Confirm the resolved runtime ID and callback filters in the
closest relevant test.

## Callback Registration

All Lua snippets use `Mod` for the current project's existing `RegisterMod`
object. Do not copy a project-specific mod object name into another mod.

Passive stat item:

```lua
function Mod:EvaluateItemName(player, cacheFlag)
    local itemCount = player:GetCollectibleNum(Items.ItemName)
    if itemCount <= 0 then
        return
    end

    if cacheFlag == CacheFlag.CACHE_DAMAGE then
        player.Damage = player.Damage + 1.0 * itemCount
    end
end

Mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Mod.EvaluateItemName)
```

Active item shell:

```lua
function Mod:UseItemName(_, _, player)
    if not player then
        return false
    end

    -- Implement the specific mechanic here.
    return true
end

Mod:AddCallback(ModCallbacks.MC_USE_ITEM, Mod.UseItemName, Items.ItemName)
```

Do not assume every active item needs manual charge handling. In many Isaac callbacks, returning the correct value is enough. If a design needs conditional failure or zero-charge behavior, inspect an existing active item with similar behavior first.

## Localization And EID

For item-facing text, keep these surfaces aligned:

- Current default XML and every discovered locale XML
- EID descriptions only when an existing optional integration owns them
- The discovered bootstrap or compatibility module, not an assumed `main.lua`
- Any tests that assert localized names/descriptions

English entries should not contain Chinese text. Chinese entries should use Chinese display text.

## Pool And Tag Check

Use item pools only when the design says where the item belongs. Do not place every item in treasure by default.

When changing pools, preserve language variants. The user's known mapping includes:

- `treasure`: 宝箱房
- `boss`: 首领房
- `devil`: 恶魔房
- `angel`: 天使房
- `shop`: 商店房
- `secret`: 隐藏房
- `library`: 书房
- `planetarium`: 星象房
- chest and beggar pools when specifically requested

## Registration Review Checklist

- Basic item spec exists, with unresolved fields marked `TBD` instead of guessed.
- XML item type matches design: `passive` or `active`.
- `gfxroot + gfx` resolves to the intended asset in the discovered resource root.
- `cache` attribute matches actual cache flags handled in Lua.
- Lua item lookup uses the same name as XML.
- Callback is registered with the correct item parameter when the callback supports one.
- English, Chinese, and default item files are intentionally aligned.
- Behavior test checks at least ID lookup, XML metadata, and the primary callback when practical.
