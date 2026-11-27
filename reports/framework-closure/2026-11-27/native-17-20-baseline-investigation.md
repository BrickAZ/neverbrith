# 第 17 / 20 批基线原生失败调查

原始证据：[lifecycle-baseline-01/game-log.txt](native/lifecycle-baseline-01/game-log.txt)，统一前缀结果 26 PASS / 3 FAIL / 3 cases，无 Lua 错误。runner [result.json](native/lifecycle-baseline-01/result.json) 中 `stateRestored=true`、`mainRestored=true`、`cleanShutdown=true`；其中 status 为 TIMEOUT，不能只根据检查行重写 launcher 状态。本调查没有修改生产代码。

## 1. 复活已活但表现锁定

原探针组合断言为 `not IsDead()`、`Visible=false`、`ControlsEnabled=false`、`EntityCollisionClass=ENTCOLL_NONE`，采样位于 POST_RENDER 中第一次观察到死亡 callback/triggered/item removal 成功后。日志 285–286 行仅输出组合失败，**没有输出四个分量，不能从该日志还原具体哪个值失败**。

可确认的后续原始状态：日志 287 行生产代码记录 `Revive animation complete; visible=true; controls=true`；探针观察到实际 IsFinished，最后红心 2、魂心 0、最大红心 6，效果与额外生命效果清理，triggered 存档成功。故不是“没有复活”或“watchdog 假装动画完成”。

既有代码在死亡处理内设置三种锁；随后 PRE_PLAYER_UPDATE 持续恢复控制/可见、归零速度并返回 true 跳过原生 player update，但不重复设置 collision。引擎从原生死亡处理返回后是否覆盖其中字段，或仅首个渲染时机还未进入下一次 player update，本次日志不足以区分。v2 保留原断言并输出具体分量，同时记录 effect 更新前每次字段变化和最后动画帧；**没有用等待或放宽比较把当前失败改为通过**。

## 2. 永久主动槽恢复

原始槽位：primary `{item=34,charge=3,battery=0}`（彼列之书），secondary/pocket active 均 0。切换和移除后的 primary 均 `{item=788,charge=0,battery=0}`。

日志 313–321 行记录：加入彼列之书 34 → 加入 Memory Disorder 787 → `item queue flush` → 原生加入 Ring of the Seven Curses 788 → 换房 → 加入槽位封印饰品 190 → `[Seven Curses] run contract activated`。这证明 v1 接触了未隔离的起始房七咒底座。七咒 `runtime.SpawnStartingPedestal` 本来在新局生成底座；其库存合同 `EnsureRingInPrimary` 会保护主槽，记忆障碍 `updatePermanentSlots` 对没有临时主动标记的当前主槽吸收为永久变化。

因此，取得记忆障碍之后又实际取得七咒，再要求回退到更早的彼列之书，是探针错误的隔离和比较前提。不能据此认定框架引入了主动槽恢复回归，也不能修改生产代码去取消新增永久取得。v2 在开始场景时移除 collectible 底座实体作为测试环境隔离，保留所有生产 callback，并在换房前后断言没有七咒；加入持有后/换房前 permanentSlots 快照。永久主动仍比较原始彼列之书，不降低断言。

## 3. 永久口袋恢复

原始口袋 `card0=18`（星星）、`card1=0,pill0=0,pill1=0`；换房切换和移除后四者均 0。本次自然 profile 是 `isaac`，`temporary=[]`，switch frame 15、清理 frame 30，序号加 1；所以本次没有“临时卡牌覆盖”的已观察证据。

生产 `memory_disorder/inventory.lua` 的 removeTemporaryComponents 最后依次执行 `SetCard(slot,savedCard)` 和 `SetPill(slot,savedPill or 0)`；离线夹具将 cards 与 pills 当两个独立 table 写入。原生 API 的签名均接受同一 SlotId，公开 [EntityPlayer API 文档](https://wofsauge.github.io/IsaacDocs/rep/EntityPlayer.html) 没有给出“零药丸是否覆盖既有卡牌”的完整语义，故文档不足以确认因果。目前最具体的待验证解释是 SetPill(0,0) 清掉刚恢复的 card，而离线模拟不能复现。

v2 在取得记忆障碍前用原生 `SetCard(0,18)` → 读两个 getter → `SetPill(0,0)` → 再读两个 getter，随后只用 `SetCard(0,18)` 恢复测试前提；记录记忆持有后/换房前永久口袋、换房后永久口袋和实际卡药槽。v2 **保留原始口袋恢复断言**。若隔离七咒后仍失败且 native setter 对照确认清空，则按旧版真实缺陷记录，不能把预期改成空口袋来“通过”。

## v2 运行入口

旧 `native-17-20-probe.lua` 原样保留。新文件为 `native-17-20-probe-v2.lua`，相同 factory/prefix/70 秒内部上限/85 秒外部建议。只新增隔离 collectible 底座和诊断观察，未改任何生产文件。

```lua
include('reports/framework-closure/2026-11-27/native-17-20-probe-v2')(Neverbirth, {Attempt='lifecycle-baseline-02'})
```

准备执行 `& 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' -e "assert(type(assert(loadfile('reports/framework-closure/2026-11-27/native-17-20-probe-v2.lua'))()) == 'function'); print('native probe v2 syntax/load passed')"`，退出码 **0**。原生重跑由主代理统一执行，本调查不宣称 v2 已通过。

## v2 基线结果与当前归因

主代理已运行 [lifecycle-baseline-v2/game-log.txt](native/lifecycle-baseline-v2/game-log.txt)，结果 **27 PASS / 2 FAIL / 3 cases**。runner [result.json](native/lifecycle-baseline-v2/result.json) 的 mainRestored、stateRestored、cleanShutdown 均 true，restoreErrors 和 unresolvedNewFiles 均空；status 仍为 TIMEOUT，exitCode 0。以下为读取实际结果后的更新，替代上文尚待验证的推测；本代理没有执行游戏或改变生产实现。

### 复活：首帧交接过渡与持续碰撞字段问题必须分开

| 观察位置 | IsDead | Visible | ControlsEnabled | EntityCollisionClass | 证据 |
| --- | --- | --- | --- | --- | --- |
| 道具已消耗后的首个 render，gameFrame 58 | false | true | true | 4 | 日志 287–288 |
| 首次效果更新，gameFrame 59 / 动画 frame 1 | false | false | false | 4 | 日志 289 |
| 动画完成前的效果更新，gameFrame 106 / 动画 frame 47 | false | false | false | 4 | 日志 290 |
| 自然动画完成之后 | false | true | true | 已恢复生前值，原断言通过 | 日志 291–297 |

探针还输出 `ENTCOLL_NONE=0`。effect 观察器每次调用读取这些字段，仅在字段组合变化或动画完成时写日志；因此中间没有另一次被观察到的字段变化，不是仅凭两个孤立截图推测一直相同。

**控制/可见部分属于首帧交接时机问题**：原断言在 native death callback 的存档/道具结果已经可见、下一次 PRE_PLAYER_UPDATE 尚未维持锁时就要求控制与可见字段都已经 false。下一 gameFrame 到自然动画完成之前，效果更新处实际观察到它们均为 false。不能用 frame 58 的组合失败声称整个复活动画都没有锁控制。源码明确在 PRE_PLAYER_UPDATE 重设两字段并返回 true；该行为与 v2 时序一致。

**碰撞字段部分不是简单延后采样就会消失的误报**：ENTCOLL_NONE 只在 death handler 写一次，随后一直观察到 4；PRE_PLAYER_UPDATE 没有重新写该字段。旧实现对“动画期间持续保存碰撞类 0”的意图在这个真实引擎环境下未成立，属于已有原生交接/维持缺口。它与死亡处理后原生重新设置存活状态相符，但当前探针未跟踪每个 setter 的 native 调用栈，不能把具体覆写者或准确机器指令当作已证明事实。拆分前 [第 17 批旧入口](../../refactor-batch17/2026-11-26/baseline/revive_my_love.lua) 第 164–178、239–241 行已有相同“持续控制/可见，但碰撞只写一次”的代码，故不是本轮新增框架回归。

**不能从 collision=4 推出“已验证可受伤/可射击”**：本场景没有攻击者，没有注入射击或使用动作，也没有尝试撞击。旧实现另有 MC_PRE_PLAYER_TAKE_DMG：序列存在时直接返回 false（拆分前第 254–260 行）；PRE_PLAYER_UPDATE 的 true 还跳过原生 player update。离线测试覆盖了这两个回调返回值，但本次 native smoke 未单独验证攻击/输入交互。准确结论仅是“首 render 仍用存活默认标志，后续控制/可见锁生效，碰撞字段未保持 0；死亡→一次消费→自然动画→恢复血量/控制链路通过”。是否需要改变原有交接表现或额外维持碰撞，应作为后续玩法修复议题；本轮保留生产行为和失败记录。

### 主动槽：v1 测试污染已确认消除

v2 日志 278 明确移除了底座 `[788]`。持有记忆障碍后、换房前、切换后和移除后的 primary 都是 `item=34,charge=3,battery=0`，其他主动槽为空；permanentSlots 也一致（日志 321、332、339）。日志 335 恢复断言通过。该项归类为 **v1 测试环境污染，不是旧实现缺陷**。

### 口袋：原生同槽 setter 缺陷已确认

v2 日志 318–319 的直接原生对照：`SetCard(0,18)` 后 `card0=18,pill0=0`；紧接着 `SetPill(0,0)` 后两者均 0。随后探针重新 SetCard 恢复原始前提。取得记忆障碍后，实际 card0 和 permanentPockets.cards[0] 都为 18（日志 321）；frame 15 自然抽中 isaac，temporary 为空；换房结束后实际与永久卡牌记录都成 0（日志 332）；移除后仍为 0（日志 336、339）。

结合生产源码可以给出具体原因：removeTemporaryComponents 用 SetCard 恢复星星，紧接的 SetPill(0) 把同一个槽清空；后续 ownership update 又把当前空槽吸收进 permanentPockets，故最终移除无法恢复原卡牌。拆分前 [第 20 批旧入口](../../refactor-batch20/2026-11-26/baseline/memory_disorder.lua) 第 745–746 行已有相同两次 setter，当前离线夹具分别写 cards/pills table，遗漏了原生同槽覆盖。该项归类为 **确认的旧版卡牌恢复缺陷**，本轮框架保持现有玩法语义，不顺带修复。还不能将这一单例扩大为“所有药丸或所有角色均会丢失”。

候选已完成相同 v2 探针，基线与候选均为 **27 PASS / 2 FAIL / 3 cases**，失败项同为 `revival alive but presentation locked` 和 `memory restores permanent pockets`。已读取 [lifecycle-native-comparison.json](lifecycle-native-comparison.json)：`diagnosticComparisonEqual=true`、`acceptancePassed=false`；比较命令由主代理执行，退出码 0。复活字段序列、自然动画完成、主动槽恢复、卡牌清空与永久记录变化等诊断分量一致。真实睡眠 elapsed 为基线 2.032 秒、候选 2.031 秒；elapsed 与 bedSeed 只排除字面相等判定。elapsed 原值另存于对照 JSON 的 sleepWallClockElapsed，两者的全部原值均留在各次完整日志中，没有改写实测数据。

最终结论是 **本轮候选保持了已观察到的旧行为，没有在这三个场景中引入新的诊断差异；复活交接/持续碰撞字段缺口和旧版卡牌恢复缺陷仍未关闭**。对照通过不等于原生玩法验收全部通过，不能将两个失败豁免或将总验收改为通过。此次更新仅修改本调查文档，生产代码保持冻结。
