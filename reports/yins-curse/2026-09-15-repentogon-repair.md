# 阴的诅咒：REPENTOGON 检查与修复（2026-09-15）

> 历史报告：下文“黑蜡烛直接免爆”及其 8 项测试代表 2026-09-15 的旧实现。用户于 2026-09-16 明确“黑蜡烛只解除封锁，仍需原有防爆来源”；旧免爆回调已移除。当前结果及未完成项见[规则修正报告](2026-09-16-black-candle-contract.md)，不能用本报告的旧免爆测试验收新规则。

## 结论

已修复拾取激活时序、首次四品质道具结算的假成功，以及失败的额外生成反复刷物品风险。黑蜡烛免爆的现有提前回调保留并通过回归。

**“失去所有防爆”仍未实现。** 宿主帽、纵火狂和第三方防爆仍可能阻止伤害。这是当前代码的明确功能缺口，不能以测试通过宣称整个原设计已经完成。中英文 EID 已同步说明当前实际行为；原设计要求在此保留。

## 现场证据与边界

- 当前工程已要求 REPENTOGON 1.0.12a 或更高可识别稳定版。
- 本机最新游戏日志包含 REPENTOGON 1.0.12a，以及阴的诅咒成功加入玩家的记录；运行时道具 ID 在该次启动中为 779。
- 该次记录中，玩家先得到黑蜡烛，再得到阴的诅咒。因此该局的既定四品质分支应为“保留原道具，在旁边额外生成吐根酊”。
- 日志后续已经开始另一局。读到的新局存档 yinCurseActive=false 不能证明上一局拾取后没有激活。
- 未操作游戏窗口、未改玩家存档、未执行游戏内伤害或生成测试。本报告中的新增通过结果属于 Lua 模拟测试及静态检查。

## 原因和修改

### 1. 激活只依赖下一次 POST_UPDATE

原实现靠碰撞前快照和逐帧道具数量差激活。实际加入到下一次更新之间，其他回调可能移除道具或改变黑蜡烛，导致永久效果漏激活或选错分支。

增加 MC_POST_ADD_COLLECTIBLE：
- 完整参数：mod, itemId, charge, firstTime, slot, varData, player。
- 按阴的诅咒运行时 ID 筛选。
- 确认真实持有数量后立即记录激活。
- 正常基座保留碰撞前黑蜡烛快照。
- 原有更新与开局恢复继续作为兜底，统一通过 recordFirstAcquisition 防止重复结算。
- 道具数量查询只计真实道具，避免道具魂火激活永久诅咒。

### 2. 调用 Morph 不报错被当作成功

REPENTOGON 的 MC_PRE_PICKUP_MORPH 可取消或替换变形而不抛 Lua 异常。原实现仅凭 pcall 成功便永久消耗首次机会。

现在检查实际结果：
- 实体仍存在；
- Type/Variant 仍为道具基座；
- SubType 确实为吐根酊。
满足条件后才设置成功状态和生成标记。额外生成分支也核查真实结果。

额外生成失败时，同一房间同一基座同一子类型不逐帧重复尝试；换房或换成另一候选后可以重试。一次机会仍保留，不删除第三方生成结果。

### 3. 全面禁防爆缺口

decideExplosionDamage 在没有黑蜡烛时返回 nil，因此保留引擎原本的伤害处理，包括原生防爆。已有提前回调只实现了黑蜡烛免疫优先于圣光斗篷。

核对 1.0.12a 官方实现，MC_PRE_PLAYER_TAKE_DMG 只处理 false 取消；其他返回值继续原生 TakeDamage。该入口不能靠 true 或伤害修改表强迫原生免疫失效。

未采用整体屏蔽道具、移除道具、直接扣血或重放第二次伤害等改变其他功能的办法。本轮没有找到经验证的单独禁用所有防爆的方案。

## 文件

- yins_curse.lua：实际加入事件、成功核验、失败生成去重和生命周期清理。
- main.lua：仅本条道具的中英文 EID 文案。
- tests/localization_test.lua：相应文案预期。
- tests/yins_curse_repentogon_test.lua：新增实际注册回调与状态测试。

不修改该道具的品质、道具池、贴图、四品质奖励规则、黑蜡烛分支或存档结构。原有大量未提交改动保留。

## 已执行验证

新增测试首先在旧代码上得到 1 通过 / 9 失败，证明能覆盖激活延迟与结算假成功。最终扩展为 13 项，全部通过：

- 实际加入时立即激活及立即移除后仍有效；
- 同帧黑蜡烛变化及碰撞前快照；
- 其他道具、取消拾取不激活；
- 同房已有四品质道具立即处理、全局只处理一次；
- Morph 被否决、改写、实体移除不消耗机会；
- 额外生成结果校验、失败不逐帧刷物品、重进房可重试；
- 退出继续与新局重置；
- 道具魂火排除；
- 实际额外生成函数、构造器参数、同步回调重入、独立二选一编号；
- 不可见或等待中的基座延后处理。

执行命令：
- lua tests/yins_curse_repentogon_test.lua：13 通过，0 失败。
- lua tests/yins_curse_behavior_test.lua：通过，包含主入口加载与本地化。
- lua tests/yins_curse_damage_order_test.lua：8 通过，0 失败。
- lua tests/repentogon_bootstrap_test.lua：14 用例通过。
- lua tests/repentogon_damage_dispatch_test.lua：通过。
- lua tests/repentogon_damage_order_test.lua：12 用例通过。
- luac -p：main.lua、yins_curse.lua、两份变更测试均通过。
- git diff --check：本轮涉及代码/测试文件通过。
- 通用模组静态检查：0 失败，15 警告。警告为现有早餐贴图原版回退引用（3）、其他逻辑的高频资源加载提示（11）和玩家 0 使用提示（1）；不属于本轮阴的诅咒修改。

## 尚缺的游戏内验证

重启加载新 Lua 后，在独立测试局核对普通基座实际交互、额外吐根酊位置、黑蜡烛与圣光斗篷的真实护盾顺序、退出继续。已有旧存档若错误消耗了首次机会，无法从一个布尔值自动还原；本轮未擅自重置它。

## 版本对应依据

- [REPENTOGON 1.0.12a 原生回调实现](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/LuaInterfaces/CustomCallbacks.cpp)：AddCollectible 第 26–92 行；提前受伤第 447–469 行；Pickup Morph 第 1026–1095 行。
- [REPENTOGON 1.0.12a 回调文档](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/docs/docs/enums/ModCallbacks.md)。
