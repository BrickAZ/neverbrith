# 第十三批逐件状态与消费者

| 道具 / 本地 ID | 实际入口与消费者 | 共享能力 | 本批状态 |
| --- | --- | --- | --- |
| 大狗叫 / 48 | main.lua 原安装位置 → 根 big_dog_bark.lua → scripts/features/big_dog_bark.lua；入口一次创建实例、保留旧 TestAPI 和回调顺序 | 唯一状态/存档、查询、规则、音效、效果、目标、水迹；输入/蓄力/冲刺/咀嚼/HUD/食物/生命周期各有归属 | 结构重构完成；旧新行为、安装回滚与原生自动对照完成 |
| 蓄风棒 / 49 | scripts/features/wind_charge_rod.lua；Input.useItem 两次实际调用 Rod.IsHeld，分别决定反向和立即发射 | 原 Queries.hasCollectible；通过大狗输入/冲刺实例发射；UpgradePool 保留升级池门控 | 独立身份与持有规则已接入；旧新反向即发对照完成 |
| 回响碎片 / 50 | scripts/features/echo_shard.lua；Dash 调用 createEchoFromDash/spawnEchoEffect，入口安装 updateEcho | 同一 State.Runtime、Queries、Effects、Targets、Trails；独立回响伤害和 hitMap | 独立回响数据/伤害/生成/更新已接入；旧新延迟、独立命中和水迹对照完成 |

三件只在原大狗组内共用能力，没有新增全项目公共库。14 个私有模块的详细接口、副作用、实例生命期、真实消费者和不适用的公共替代能力，见[大狗组接口](../../../docs/api/big-dog-family.md)。食物取得没有改走另一套获取服务；玩家键、队列确认、失败回退和保存时点都沿用原合同。

运行文件精确范围见 owned-files.json（18 个运行文件、4 个本批测试文件）。三件保有独立有效入口，不以一个空壳文件计作独立玩法模块。存档仍由原大狗组区域管理，不新增蓄风棒或回响碎片的存档区域。

本批状态不等于整包集成、真实多人、跨进程 Continue 或人工体验验收完成；完整证据和限制见[交付](delivery.md)。
