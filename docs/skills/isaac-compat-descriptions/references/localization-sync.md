# Localization Synchronization

Use this when item text, metadata, EID text, config labels, wiki text, or translations change.

## Surfaces

- `content/items.xml`
- `content/items.en_us.xml`
- `content/items.zh_cn.xml`
- `content/itempools*.xml` when pool names or pool text are involved
- EID description blocks or language files
- MCM display text and info text
- Encyclopedia/wiki entries
- `metadata.xml` when workshop-facing text changes

## Hard Rules

- Do not update only one language variant when matching variants exist.
- English surfaces should contain English copy.
- Chinese surfaces should contain Chinese copy.
- If a surface is intentionally not updated, say why in the final report.
- Keep mechanical numbers consistent across languages.

## Text Review

Check:

- Item name.
- Pickup line.
- Long EID description.
- Charge/use instructions.
- Button prompts.
- Special limitations and edge cases.
- Icon tags and formatting markers.

