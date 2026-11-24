# 独立审查与修复记录

按实施计划中的 executing-plans 工作流执行一次独立只读审查，后续在同一审查者上下文中复核重要修复；审查者未改文件、未启动游戏。

| 发现 | 修正及证据 |
| --- | --- |
| 来源账本阻止同种子吐出物再次吸入 | 吸取尊重 released 输出身份；再次吸入/价格充能测试通过 |
| 空底座 SubType 0 可能走新道具生成 | 排除空底座，运输 Morph 忽略替换修饰；固定输出测试通过 |
| 可移动 TNT 漏掉 | 原生 ENTITY_MOVABLE_TNT 接入 TNT 弹药 |
| 固定前端圆漏掉驴腮骨两侧挥动 | 使用原生 Null 五点扫掠，每敌人一次；25px 侧向测试 RED exit 1 → GREEN exit 0；独立复核闭合 |
| TryOpenChest 不承诺忽略解锁条件 | 优先原生 TryThrow 落地开箱；fallback 失败归还；原生锁箱仍须实机核对 |
| Schoolbag Ctrl 交换后可能使用另一主动 | MC_PRE_USE_ITEM 对副槽 Blinky 截获组合键；测试 RED exit 1 → GREEN exit 0；真实输入顺序另验 |
| 延迟 TryThrow 改 subtype 后神圣箱一次标记失效 | 一次开启身份改为 room+InitSeed+variant，临时与持久双重查询；deferred+清临时数据+Continue 测试 RED exit 1 → GREEN exit 0 |

最终独立复核重跑 `lua tests/blinky_behavior_test.lua`：15 组通过，退出 0；针对延迟神圣箱修复未发现新的确定错误。审查结果不构成真实游戏验收。
