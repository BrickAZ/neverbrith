# Card Descriptions And Icons

Use this when adding EID text, inline icons, card/pill icons, or localized descriptions for custom pocket items.

## Surfaces

- `content/pocketitems.xml` description.
- EID `addCard` or equivalent description file.
- EID icon registration.
- HUD/card icon art.
- English and Chinese language files, if they exist.

## Hard Rules

- EID text does not replace `pocketitems.xml` registration.
- Inline EID icons do not replace pickup/HUD art.
- Keep English and Chinese descriptions separate.
- Use `isaac-anm2-visuals` for `.anm2` icon assets.
- Use `isaac-compat-descriptions` for optional EID guards and language sync.

## Review Checklist

- EID guard exists if EID is optional.
- Card id is resolved with `Isaac.GetCardIdByName`.
- Icon art and text formatting are checked.
- Languages are aligned.

