# 鸿运齐天蛊实施计划

> **执行说明：** 逐步实施；每步先补行为测试，再写最小实现。除 `main.lua`、本物品的 XML/语言文件和对应测试外，不改动无关系统。

## 1. 建立测试夹具与物品元数据断言

**文件：** `tests/condom_utility_knife_behavior_test.lua`、`tests/localization_test.lua`（如需）、`content/items.xml`、`content/items.en_us.xml`、`content/items.zh_cn.xml`、三份 `content/itempools*.xml`。

1. 扩展现有 Lua stub，使其可模拟幸运缓存、Pickup 首次更新、实体数据和随机判定。
2. 写失败测试：质量 4、双语名称/副标题、全部现有池权重和衰减字段。
3. 仅在图标资源实际交付后登记 `gfx`、物品定义和池条目；资源未到位时，测试将把这个项目明确标为待接入而非写悬空路径。

## 2. 实现收藏品幸运阈值 API

**文件：** `main.lua`、`tests/condom_utility_knife_behavior_test.lua`。

1. 增加有限的 Collectible 幸运阈值注册表和两个公开 API。
2. 登记有可验证满概率阈值的原版 Collectible；动态条目使用 resolver。
3. 写 `CACHE_LUCK` 回调：只在拥有蛊时，对本玩家已拥有的登记项取最大阈值并使用 `max` 补足。
4. 测试固定阈值、动态 resolver、不会降低已有幸运、重复 EvaluateItems 幂等、合作隔离。

## 3. 实现事件账本与双喜临门

**文件：** `main.lua`、`tests/condom_utility_knife_behavior_test.lua`。

1. 定义只覆盖已确认原生来源的短时奖励事件账本和外部来源注册 API。
2. 在来源开始处建账，在相关 Pickup 的首次可观察生命周期归集原奖励；不扫描整个房间。
3. 原奖励完成后，针对每位持有者只掷一次 10%，复制本事件的非 pedestal Pickup，并给复制结果加禁止再触发标记。
4. 测试一次事件只掷一次、多蛊不增加掷骰、多人独立、原奖励保留、复制结果不递归、未知来源不退化为全局池。

## 4. 实现来源池底座链与幸运币链

**文件：** `main.lua`、`tests/condom_utility_knife_behavior_test.lua`。

1. 建立可靠的原生 pedestal 来源池解析和外部显式登记接口。
2. collectible pedestal 首次更新仅检查自身一次；一次 1% 成功后从同一来源池生成第二底座，不设防链标记。
3. coin 首次更新仅检查自身一次；一次固定 5% 成功后保留原币并在附近生成 Lucky Penny，不设防链标记。
4. 测试重复帧不重复、同池、真实双底座、1% 链、镍币/角币/金硬币不被改写、Lucky Penny 链。

## 5. 视觉钩子与资源交接

**文件：** `main.lua`，资源到位后的 `content/entities2.xml` 和 `resources/`。

1. 先定义四个安全空视觉钩子，并在“拾取/阈值提高/双喜/额外底座/额外币”时调用。
2. 不注册任何缺失的 `.anm2` 或图标路径。
3. 收到 icon 和四个 anm2 后再接入实际效果实体与动画，不改变前四步的机制测试。

## 6. 回归验证

运行：

```powershell
C:\\Users\\Anton\\AppData\\Local\\Programs\\Lua\\bin\\luac.exe -p main.lua
C:\\Users\\Anton\\AppData\\Local\\Programs\\Lua\\bin\\lua.exe tests\\condom_utility_knife_behavior_test.lua
C:\\Users\\Anton\\AppData\\Local\\Programs\\Lua\\bin\\lua.exe tests\\localization_test.lua
# 解析 content\\*.xml
powershell -ExecutionPolicy Bypass -File docs\\skills\\isaac-validators\\scripts\\validate-isaac-mod.ps1 -Root . -ModObjectName Neverbirth
git diff --check
```

报告静态通过项与仍需实机确认的回调时序/原生来源映射边界；不把静态结果声称为实机验证。
