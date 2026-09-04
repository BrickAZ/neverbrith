---
name: isaac-neverbrith-validator-profile
description: Run the neverbrith-specific strict validation profile for Binding of Isaac Repentance changes. Use this only inside the neverbrith repository after generic validation, especially for its entity-to-ANM2 chain, pocket item shape, pool-language parity, owned entity lookups, and Neverbirth callback conventions. 中文触发：neverbirth 严格校验、项目专用校验、实体链检查、卡牌 HUD 校验、道具池语言一致性。
---

# Neverbrith Validator Profile

Use this project overlay only after `isaac-validators` has run its generic
validator. It encodes this repository's actual naming and content conventions;
do not copy it into an unrelated mod.

## Run

From the neverbrith mod root:

```powershell
powershell -ExecutionPolicy Bypass -File docs/skills/isaac-neverbrith-validator-profile/scripts/validate-neverbrith.ps1 -Root .
```

## Coverage

- `entities2.xml` registration through ANM2, spritesheet, and default animation.
- Pocket item id, pickup, and HUD shape.
- Base and project-supported pool language parity.
- Owned entity lookups and direct `Neverbirth:AddCallback` registrations.
- The local skill package's XML/JSON and self-contained-source checks.

## Boundary

- Treat findings as static evidence, not in-game proof.
- Keep unknown third-party entities untouched; validate only neverbrith-owned spawns and replacements.
- Update this profile only when a stable neverbrith convention changes, not to encode a one-off design choice.
