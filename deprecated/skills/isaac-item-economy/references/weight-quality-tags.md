> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-item-economy/references/weight-quality-tags.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Weight, Quality, Tags, And Depletion

## Separate The Variables

- **Quality**: expected impact and consistency once acquired.
- **Pool**: where the item belongs in the run's acquisition story.
- **Weight**: relative likelihood inside that pool before depletion.
- **DecreaseBy / RemoveOn**: how repeated draws change availability.
- **Tags**: mechanical/category metadata that should match actual behavior.

Do not use one field to compensate for an unresolved decision in another.

## Advice, Not Authority

When the user omits a value, a comparison with local items can support a recommendation, not determine a final answer. Label the recommendation and its trade-off. When the user supplies a value, treat it as locked unless they ask for review or revision.

## Weight Contract

When writing a pool entry, specify all three values together:

```xml
<Item Name="Internal Name" Weight="..." DecreaseBy="..." RemoveOn="..." />
```

Explain whether the item is meant to be a normal draw, a scarce surprise, or a limited pool resident. Use existing items in the same pool as comparison points, not as automatic numeric defaults.

## Tags

Tags should describe actual item behavior or ecosystem role. If the tag changes interactions, transformations, or other systems, include that in the Mechanic Contract and tests.
