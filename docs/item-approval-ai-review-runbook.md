# neverbrith Item Approval AI Review Runbook

## Workbook configuration example

This public runbook contains placeholders only. Before running the workflow, configure a workbook you are authorized to use through your authenticated OneDrive/SharePoint connector. Resolve its current drive and item IDs from that connector; do not infer them from a workbook title.

```json
{
  "workbook_url": "<YOUR_WORKBOOK_URL>",
  "target": {
    "type": "drive_item",
    "drive_id": "<YOUR_DRIVE_ID>",
    "item_id": "<YOUR_ITEM_ID>"
  },
  "workbook_title": "<YOUR_WORKBOOK_TITLE>.xlsx",
  "sheet": "道具审批"
}
```

This is a configuration example, not a file automatically loaded by the mod. Keep actual values in your local or automation configuration outside the public repository. Share links and Graph shares URLs can carry access tokens; do not publish them here. Reading this runbook does not authorize workbook access or writeback: use only the target and actions authorized for your workflow.

The column names below describe the expected sheet schema. Confirm them against your configured workbook before running a review or writeback.

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
