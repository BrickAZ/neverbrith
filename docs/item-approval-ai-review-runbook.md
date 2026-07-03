# neverbrith Item Approval AI Review Runbook

## Online Workbook

- Human-facing link: `https://1drv.ms/x/c/7ba8541e2c23cc59/IQDOdMZ7vkf1QbrI-zAlJE0iAepZTrlscRLNOS-L2qh8GLc?e=x5zgjI`
- Preferred connector target after the SharePoint/OneDrive connector is authorized:
  - `type`: `drive_item`
  - `drive_id`: `7BA8541E2C23CC59`
  - `item_id`: `7BA8541E2C23CC59!s7bc674ce47be41f5bac8fb3025244d22`
- Fallback connector-facing Graph shares URL, only useful while the anonymous share link exists:
  `https://graph.microsoft.com/v1.0/shares/u!aHR0cHM6Ly9vbmVkcml2ZS5saXZlLmNvbS86eDovZy9wZXJzb25hbC83QkE4NTQxRTJDMjNDQzU5L0lRRE9kTVo3dmtmMVFickktekFsSkUwaUFlcFpUcmxzY1JMTk9TLUwycWg4R0xjP3Jlc2lkPTdCQTg1NDFFMkMyM0NDNTkhczdiYzY3NGNlNDdiZTQxZjViYWM4ZmIzMDI1MjQ0ZDIyJml0aGludD1maWxlJTJjeGxzeCZlPXg1emdqSSZtaWdyYXRlZHRvc3BvPXRydWUmcmVkZWVtPWFIUjBjSE02THk4eFpISjJMbTF6TDNndll5ODNZbUU0TlRReFpUSmpNak5qWXpVNUwwbFJSRTlrVFZvM2RtdG1NVkZpY2trdGVrRnNTa1V3YVVGbGNGcFVjbXh6WTFKTVRrOVRMVXd5Y1dnNFIweGpQMlU5ZURWNloycEo/driveItem`
- Workbook title observed by connector: `neverbirth 在线合作.xlsx`
- Main sheet: `道具审批`

## Columns

- `A` / `序号`: formula-driven visible row number. Do not rely on it for matching.
- `C` / `英文名`: stable item key for row matching.
- `D` / `中文名`: acceptable item key when `英文名` is blank.
- `B` / `类型`: required human input. Usually `主动` or `被动`.
- `L` / `道具池/权重`: merged item-pool field. It may contain English pool ids, Chinese pool names, or both. If a pool is present without a weight and the item is approved, normalize it to weight `1（AI自动补充）`.
- `M` / `英文描述`: optional item description.
- `N` / `中文描述`: optional item description.
- `O` / `道具效果（自然语言）`: required core design input. The AI must use this as the primary source for judging theme fit and mechanics.
- `P` / `贴图`: for new rows, player-facing art source selector. Allowed values are `无` and `已有`; existing legacy rows may still contain sprite filenames.
- `Q` / `设计者联系方式`: optional contact method. Required when `贴图` is `已有`.
- `R` / `审查状态`: one of `待审查`, `已通过`, `需要补充`.
- `S` / `AI回复`: AI review text.

The automation must match rows by `英文名` when present, otherwise by `中文名`; never match by visible row number because the workbook is sortable.

## Normal Run

1. Fetch the OneDrive workbook through the Microsoft SharePoint connector with `download_raw_file=true`.
2. Read sheet `道具审批`.
3. Select only rows where `审查状态` is exactly `待审查`.
4. For each selected item, write a concise design review covering:
   - whether required input is sufficient
   - theme fit for `neverbrith`
   - mechanics clarity
   - implementation risk
   - art direction notes
   - code notes
   - test focus
5. Generate a dated Markdown report under `outputs/item-approval/ai-reviews/`.
6. Generate a dated pending sync JSON under `outputs/item-approval/pending-sync/`.
7. If the item is approved, normalize missing approved-row fields before writeback:
   - If `英文名` is blank but `中文名` is present, generate a concise English name and append `（AI自动补充）`.
   - If `中文名` is blank but `英文名` is present, generate a concise Chinese name and append `（AI自动补充）`.
   - If `道具池/权重` contains a pool name but no explicit weight, add weight `1（AI自动补充）`.
   - If `英文描述` is blank but `中文描述` is present, translate/summarize into English and append `（AI自动补充）`.
   - If `中文描述` is blank but `英文描述` is present, translate/summarize into Chinese and append `（AI自动补充）`.
   - If `贴图` is blank for a new approved row, set it to `无`.
   - If `贴图` is `已有` and `设计者联系方式` is blank, use `需要补充` instead of `已通过` and ask for contact information.
8. Attempt to sync the review text back into the workbook:
   - set `AI回复` to the review text
   - set `审查状态` to `已通过` or `需要补充`

## Lock Handling

OneDrive may reject file replacement with `423 resourceLocked` when the workbook is open in Excel Online, desktop Excel, or syncing.

If that happens:

- Do not treat the run as failed.
- Keep the dated Markdown report.
- Keep the dated pending sync JSON.
- Do not retry more than once in the same run.
- The next automation run may re-attempt sync from the pending JSON.

## Review Policy

Use `已通过` only when the item is thematically coherent, mechanically legible, and implementable without unresolved state-machine ambiguity.

Use `需要补充` when the item is promising but missing required information or has an unresolved edge case.

An item has enough information for review when it includes:

- `类型`
- at least one name: `英文名` or `中文名`
- `道具池/权重`
- at least one description: `英文描述` or `中文描述`
- `道具效果（自然语言）`
- for active items, `充能`

For new rows, `贴图` must be either `无` or `已有`. `无` means art automation may generate a sprite later. `已有` means the player claims an existing art asset and must provide `设计者联系方式`; art automation must not generate for that row.

If `道具效果（自然语言）` is blank, default to `需要补充`; do not infer the full effect from flavor text alone.

Keep `neverbrith` anchored in missing life, canceled fate, family remnants, and Isaac-adjacent item logic. Avoid drifting into generic dark fantasy.

For conditional-use mechanics, explicitly separate attempted use, failed attempt, successful use, and floor/room expiry.
