# 已重构道具消费者清单

范围为第一至第九批 38 件。共同能力编号见目标架构第 12.2 节；单纯独立规则不制造无消费者的通用框架。新调用经过实际加载链；公共模块均无顶层回调登记。无状态函数允许多次 include；costume cache 归各表现所有、盒子 Ledger 归各 Store 所有、run_section 每次访问 live Store、new_run_reset 由回调所有者创建。

| 道具 | 入口 | 已有共同实现 | 本轮切换 | 保留独立的具体依据 |
| --- | --- | --- | --- | --- |
| 风油精 | [essential_balm.lua](../../../scripts/features/essential_balm.lua) | 属性回调、装配事务 | 无新增共同算法 | 直接线性属性；没有私有生命周期或通用机制副本 |
| 芜湖 | [wuhu.lua](../../../scripts/features/wuhu.lua) | 属性回调、装配事务 | 无新增共同算法 | 发射间隔直接置零，与射速加法不同 |
| 八音盒 | [musicbox/init.lua](../../../scripts/features/musicbox/init.lua) | persistence、incoming_damage、反馈适配 | 核对保留 | 债务按玩家/局种子保存；跨重载倒计时与死亡执行不能用新局清零流程替代 |
| 高蛋白肉条 | [protein_strip.lua](../../../scripts/features/protein_strip.lua) | dog_food_acquisition、collectible_stats | 核对保留（Stats.Count） | 本件只提供加伤规则；获取记账仍是一份 |
| 活力狗饼干 | [energy_kibble.lua](../../../scripts/features/energy_kibble.lua) | dog_food_acquisition、collectible_stats | H | 每份 0.15 射速规则留在道具 |
| 轻盈低脂罐头 | [lean_can.lua](../../../scripts/features/lean_can.lua) | dog_food_acquisition、collectible_stats | 核对保留（Stats.Count） | 移速规则留在道具 |
| DHA鱼油 | [dha_fish_oil.lua](../../../scripts/features/dha_fish_oil.lua) | dog_food_acquisition、collectible_stats | 核对保留（Stats.Count） | 射程规则留在道具 |
| 护齿磨牙骨 | [dental_chew.lua](../../../scripts/features/dental_chew.lua) | dog_food_acquisition、collectible_stats | G | 只承认泪弹直接 SpawnerEntity；击退冷却/目标合法性属于本件 |
| 幸运肝粒 | [lucky_liver_bites.lua](../../../scripts/features/lucky_liver_bites.lua) | dog_food_acquisition、collectible_stats | 核对保留（Stats.Count） | 幸运规则留在道具 |
| 羊奶布丁 | [goat_milk_pudding.lua](../../../scripts/features/goat_milk_pudding.lua) | dog_food_acquisition、collectible_stats | 核对保留（Stats.Count） | 加心与健康兼容政策由已有获取服务执行 |
| 春药 | [chunyao.lua](../../../scripts/features/chunyao.lua) | GetPlayers、安装事务 | 核对保留 | 续局重施魅惑、新局解除魅惑；disposed/running 状态不能只用 fresh-run reset |
| 美工刀 | [utility_knife.lua](../../../scripts/features/utility_knife.lua) | persistence、GetPlayers | A | 拾取参数支持 userdata 并保护成员读取；不同于普通实体转换 |
| 虚空针尖 | [needletick.lua](../../../scripts/features/needletick.lua) | 安装事务 | E、F、G | Float 优先、缺 Float 才用 Int；目标合法性与击杀属于本件 |
| 绝育证明 | [sterilization_certificate.lua](../../../scripts/features/sterilization_certificate.lua) | GetPlayers、安装事务 | C、K | 怪物生成溯源、阻止生成与反噬不等于伤害接受记录 |
| 剪碎的塔罗 | [shredded_tarot.lua](../../../scripts/features/shredded_tarot.lua) | GetPlayers、安装事务 | C、D、K | 支付、跃层和层内剩余份数独立 |
| 血颅蛊 | [blood_skull_gu.lua](../../../scripts/features/blood_skull_gu.lua) | 向脐带/空摇篮提供只读反噬查询 | C、D、E、G、K | 反噬深度在同步伤害执行中归本件所有 |
| 未剪断的脐带 | [uncut_cord.lua](../../../scripts/features/uncut_cord.lua) | GetPlayers、反噬查询 | C、E | 接收伤害尝试并取消/记债；清房结算，不是实际扣血统计 |
| 空摇篮 | [empty_cradle.lua](../../../scripts/features/empty_cradle.lua) | GetPlayers、反噬查询 | C、E、G、K | 支付伤害排除、红/魂/黑心分类与每层资格独立 |
| 老大的指令 | [boss_order.lua](../../../scripts/features/boss_order.lua) | 装配事务 | C、E、I | 卡牌范围在安装时捕获；怪物分段、冠军及死亡奖励去重独立 |
| 生死一念间 | [between_death_and_life.lua](../../../scripts/features/between_death_and_life.lua) | persistence | C、G、K | run/floor/room 激活边界、房间改造及奖励政策独立 |
| 天使盒 | [boxes/angelbox.lua](../../../scripts/features/boxes/angelbox.lua) | 盒子充能、奖励选择、加心去重 | C、D、J、K | +0.5 旧概率、品质4天使池、魂心，独立 Store |
| 恶魔盒 | [boxes/devilbox.lua](../../../scripts/features/boxes/devilbox.lua) | 盒子充能、奖励选择、加心去重 | C、D、J、K | -0.5 旧概率、品质3恶魔池、黑心，独立 Store |
| 小皮鞋 | [little_leather_shoes/init.lua](../../../scripts/features/little_leather_shoes/init.lua) | 交通奖励/表现服务、persistence | 核对保留 | 怪物返回链和 floorSerial 含维度身份；不换成普通房间键 |
| 流量开箱 | [traffic_unboxing.lua](../../../scripts/features/traffic_unboxing.lua) | 交通获取收据、表现完成后奖励 | 核对保留 | 仅一条箱子生成规则；不增加单 API 转发抽象 |
| 流量曝光 | [traffic_exposure.lua](../../../scripts/features/traffic_exposure.lua) | 交通获取收据、SpawnPedestal | 核对保留 | 当前房间池消耗抽取；与盒子不消耗池且限定品质的循环不同 |
| 流量热度 | [traffic_heat.lua](../../../scripts/features/traffic_heat.lua) | 交通获取收据、persistence | H | 整数层数每层0.5射速；延后一帧刷新政策不改 |
| 黑太岁 | [black_taisui.lua](../../../scripts/features/black_taisui.lua) | folk 世界/视觉、寄生状态、incoming_damage、生存冷却 | A、C、F、K（经共享依赖） | 容器与治疗采样、成熟/净化/假死规则独立 |
| 肉块 | [meat_lump.lua](../../../scripts/features/meat_lump.lua) | 寄生存档、生存冷却、incoming_damage | A（经寄生状态） | 生命账本与黑太岁保命恢复血量公式不同 |
| 净化迷幻菇 | [cleansed_wavy_cap.lua](../../../scripts/features/cleansed_wavy_cap.lua) | 寄生状态、folk 世界 | A、C、F（经共享依赖） | 暂时抑制层数和残留增益独立，直接减少间隔不是加射速 |
| 铜钱剑 | [coin_sewn_sword.lua](../../../scripts/features/coin_sewn_sword.lua) | folk 世界、输入/攻击协同查询 | C、F（经共享依赖） | 攻击付费顺序、剑气几何、命中去重、按键所有权独立 |
| 铜钱面具 | [coin_faced_mask.lua](../../../scripts/features/coin_faced_mask.lua) | folk 世界 | B、C、F、G、K | 三个外观状态；缺查询 API 时重试，破损/消耗规则独立 |
| 强力泻药 | [strong_laxative.lua](../../../scripts/features/strong_laxative.lua) | folk 世界、通天塔清除查询、协同快照 | B、C、E、F、G | 单件负缓存不随房间重置；毒液节奏和便便房间预算独立 |
| 通天塔 | [tower_of_babel.lua](../../../scripts/features/tower_of_babel.lua) | folk 持有查询；与泻药显式清除接口 | F | 扩大后的毒液清除清单是本件规则，不强行与泻药清单相同 |
| 巴比伦好女孩 | [good_girl_of_babylon.lua](../../../scripts/features/good_girl_of_babylon.lua) | folk 世界/视觉、卡牌算法 | B、C、E、F、I、K | 不接受 EID 名字兜底；红心受伤破损/余韵150更新独立 |
| 月色真美 | [the_moon_is_beautiful.lua](../../../scripts/features/the_moon_is_beautiful.lua) | folk 世界、卡牌算法 | C、E、F、G、I、L | 接受 EID 名字兜底；全队静默窗口、敌人标记和波纹递归防护独立 |
| 避孕套 | [condom.lua](../../../scripts/features/condom.lua) | persistence、宝宝标签/所有权查询 | A | 封禁、20次池重选、Morph guard 和既有价格行为独立 |
| 疯狂的椰子 | [crazy_coconut.lua](../../../scripts/features/crazy_coconut.lua) | persistence | A | 拾取前后自然伤害快照、确认后2更新、同批候选共用采样独立 |
| 鸿运齐天蛊 | [fortune_rivalling_heaven_gu.lua](../../../scripts/features/fortune_rivalling_heaven_gu.lua) | GetPlayers、装配事务 | 核对保留 | 审计表是幸运阈值声明；GetData 身份、dirty/flushing 与 CustomCache 顺序当前无第二个同合同消费者 |

## 状态、时序与伤害记录边界

- 监测事实已复用 world_queries、collectible_stats、combat_source、incoming_damage；源实体解包不增加递归归属搜索，不把回调尝试视为扣血成功。取消、延迟结算、支付反噬、NPC 死亡去重仍由道具决定。
- 新局专用流程供两盒/心奖励、血颅蛊、剪碎的塔罗、空摇篮、绝育证明、生死一念间和 folk 三件清理协调使用；各原生回调仍各自登记，不合成一个总事件回调。续局重建、沙漏、换层、换房、卸载和道具丢失采用各自已测试政策。
- 获取系统存在三个不同合同：狗粮按库存与碰撞延迟确认健康奖励；流量按 PendingContentState 收据保留物理来源并即时消耗本件；椰子需要获取前后伤害快照及批次采样。这些不是同一个账本的复制，未改为统一结算时刻。
- 玩家键的简单 InitSeed 字符串表达式保留既有缺省值（空字符串或 0）；Fortune 的 GetData 表身份和小皮鞋的含维度房间身份不同。一次字段转换和原生 API 转发不另建无实质逻辑的包装层。
- 游戏世界查询分为可选受保护查询和必须传播异常的直接调用；后者继续直接调用。EmptyCradle 楼层键保护 GetStage 并使用问号，与盒子/生死一念间的 run:stage:stageType 不合并。
- 视觉表现共有安全 costume 操作、状态差分、folk 实体服务和 render offset；Moon 的手工 Sprite、GoodGirl 的跟随实体、剑气的碰撞实体及 Musicbox 的 HUD/音频不是同一类生命周期对象。
- 新的公共模块不负责 ACE 的审计处罚状态机；ACE 和焚尽郁结均不在此次 38 件范围内。也不迁移尚未完成本轮重构的调试遥控器、菜刀、未诞生证明、房子与大象、千变万化。

## 旧实现退出与验收

- 对应旧算法已改成共同实现调用；保留的旧函数名仅为本件的薄适配/兼容入口，不含第二份算法。
- 真实消费者、模块导入、逐函数改写清单见 migration-functions.json、reward-migration-functions.json、remaining-migration-functions.json；源码扫描 functions.json 为候选辅助，不能单独证明语义一致。
- 同名文件不能替代验证。完整证据及实际限制见 [delivery.md](delivery.md)。没有对未迁移的全 Mod 宣布整体重构完成。
