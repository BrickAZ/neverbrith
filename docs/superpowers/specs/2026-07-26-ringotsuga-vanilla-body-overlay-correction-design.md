# RingoTsuga 原版身体服装覆盖层修正设计

## 状态

本设计已由用户在确认“`body0` 应只画服装、保留原版身体和四向动作”后，以“那你改一下”批准。

## 目标

把 RingoTsuga 的第三件 Null Costume 从“完整小人身体”改成符合《以撒的结合》原版身体结构的服装覆盖层。头发、脸部、三件 costume 的注册、Lua 生命周期与 ANM2 映射保持不变。

## 资源用途卡

| 字段 | 决定 |
| --- | --- |
| Asset purpose | 玩家身体服装外观 |
| Display surface | 游戏内玩家 `body0` 服装层 |
| Carrier / mapping | `costume_ringotsuga_hoodie.anm2` 的 `body0`，四方向各十帧 |
| Animation need | 必须跟随 `WalkRight/WalkDown/WalkLeft/WalkUp` |
| Not for | 不替换玩家基础皮肤，不承担头部、脸部、手、脚或人物注册 |

## Surface matrix

| Surface | Requested? | Source/reference | Output canvas | Carrier/mapping evidence | Acceptance check |
| --- | --- | --- | --- | --- | --- |
| In-run player skin | 否，保持原版 | `E:\Isaac - Repentance\resources\gfx\characters\costumes\Character_001_Isaac.png` | 不输出 | 原版 `001.000_player.anm2` | 不修改 |
| Character portrait | 否 | 不变 | 不输出 | 不变 | 不修改 |
| Character name image | 否 | 不变 | 不输出 | 不变 | 不修改 |
| Character-select portrait | 否 | 不变 | 不输出 | 不变 | 不修改 |
| Co-op portrait | 否 | 不变 | 不输出 | 不变 | 不修改 |
| Death-screen portrait | 否 | 不变 | 不输出 | 不变 | 不修改 |
| Costume / extra body layer | 是 | 原版四向身体帧轮廓 + Ringo 浅灰白上衣 | `256x256` RGBA | `costume_ringotsuga_hoodie.anm2`, `body0`, 40 个非空 `32x32` 帧 | 透明服装层、无皮肤手脚、四向轮廓不同、下摆收窄 |
| Character-specific HUD | 否 | 不变 | 不输出 | 不变 | 不修改 |

## 像素设计

- 服装只使用深色轮廓、灰白阴影、灰白主体、高光与绿色下摆。
- 不在 `body0` 图集中绘制肤色脖子、手臂或脚；透明区域让原版身体显露。
- 正面和背面采用原版短而收窄的身体比例；侧面更窄并有方向偏移；左侧由右侧逐帧镜像。
- 下摆为两行逐渐收窄的绿色弧形，不再是横向平台。
- 正面保留极简胸前标记；侧面和背面不复制正面标记。
- 十帧只做与原版步态一致的小幅水平/垂直变化，不再整体上下漂浮。

## 预览

项目预览器必须在服装下方绘制一个仅用于报告图的原版以撒身体代理层，再叠加服装、脸和发型。这个代理层不写入游戏资产，也不替换原版素材；它只避免透明服装在预览中看起来像残缺小人。

## 保持不变

- `costume_ringotsuga_apple_shell.png/.anm2`
- `costume_ringotsuga_face.png/.anm2`
- `costume_ringotsuga_hoodie.anm2`
- `content/costumes2.xml`
- `main.lua`
- 三件 costume 的 id、priority、添加与移除逻辑

## 验收

1. 上衣图集仍为 `256x256` RGBA，40 个必需帧非空，保留 24 个空槽。
2. 上衣图集的肤色像素数为 0，且任何帧都不在 `y >= 25` 绘制脚。
3. 每帧可见像素控制在服装覆盖层范围，不能重新形成宽矩形身体。
4. 每帧绿色下摆存在且逐行收窄。
5. 右/左十帧保持精确镜像，正面与侧面轮廓不能相同。
6. 专用图集测试、ANM2 测试及既有 Ringo/千变万化回归测试通过。
7. 最终预览需要在原始游戏像素倍率审查；游戏内动态效果单独标记为待实机验证。
