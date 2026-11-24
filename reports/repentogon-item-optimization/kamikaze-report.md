# 神风特攻队修复报告（2026-09-05）

## 结论

已实施并离线验证：稳定实体身份恢复计时、有效目标持续锁定、爆炸预检与一次失败隔离。游戏内生成、寻路/爱心表现以及原版爆炸等价性仍未验证；不能把本报告理解为完整玩法验收通过。

仅修改 `kamikaze_squad.lua`、`tests/kamikaze_squad_behavior_test.lua` 与本报告。没有改 main.lua、诛、注册、美术或其他生产模块，没有启动/升级游戏，没有提交。按主任务确认，目标是忏悔龙（非忏悔龙＋），磁盘版本 1.0.12a。

## 实际改动

- owner、seen、GetState/GetLiveCount、hostileSet、NPC 移除统一使用 GetPtrHash + InitSeed 的临时身份键。没有 ControllerIndex 或对象键回退。当前玩家包装每帧刷新，NPC owner 标签增加同一身份键。房间/新局清空，身份不写存档。
- 仍有效的目标继续锁定；死亡、移除、友好等失效条件才选择最近目标。保留原版 Mulliboom 16.2.0、AddCharmed、FRIENDLY 与 FindGridPath；没有复制 NPC AI。
- 保留 90 帧、每持有者 2 只、上限暂停、无敌人不新增、清房引爆、过门/失效 owner 静默清理。
- 爆炸执行前检查 BombExplosionEffects、有效玩家 Source，并通过 Vector/Color 原生构造器准备参数。准备失败保留单位、标记失败且不重试；成功准备后 Remove 一次并调用爆炸一次；调用抛错被隔离并只记录同类错误一次，不补第二次爆炸。移除后引擎调用抛错仍可能没有爆炸，本实现只保证不无声、不无限重试，不声称能够事务性回滚引擎爆炸。
- 固定派发伤害 40 和 RadiusMult=2 没有变更；删除把 40 断言为已验证原版值的注释。原测试命名改为参数派发回归，不再借名称暗示 native 等价性证明。
- 诊断默认关闭。模块上下文 DiagnosticsEnabled=true 或 Neverbirth.KamikazeSquadDiagnosticsEnabled=true 时，现有 DebugLog 输出初始化、识别 owner、timer 1/89/90、生成尝试、owner 清理及一次错误。若运行后才开开关，初始化事件不会追溯输出。

## 状态合同

有效持有者/有敌人 → 计时 → 90 帧尝试召唤 → 追踪有效目标 → 近距离/无敌人爆炸；目标失效才重选。上限暂停计时。准备失败单位进入不可重试状态，仍留在 owner 计数里，换房或 owner 清理时移除。外部致死仅清跟踪，不另加手动爆炸。

## TDD 红绿证据

| 轮次 | 修改前实际红灯 | 修改后实际结果 |
|---|---|---|
| 稳定身份 | fresh wrappers frame 90 coop: expected 2, got 0 | 完整定向测试通过；新包装与稳定包装均覆盖，89/90/180 帧、coop 2+2、fresh NPC remove |
| 目标锁定 | valid target must remain locked: 原目标与更近目标不相等 | 完整定向测试通过；友好、移除、死亡后重选 |
| 爆炸边界 | missing explosion API must not silently remove unit: expected false, got true | 完整定向测试通过；缺 API、Color 构造失败、调用抛错、无重试、过门清理 |

第三轮第一次绿灯尝试还出现 Color 对象引用相等断言失败：实现改用等义原生构造器后该断言不再成立，测试改为构造器类型语义后通过。未把它当作 native 效果证明。

另补回归：Isaac.Spawn→ToNPC 返回新 NPC 包装；严格 Vector/Color/Source 派发桩；natural Mulliboom 不受影响；fresh hostile 去重；外部死亡/重复死亡/移除只释放计数且不补手动爆炸；默认诊断关闭。这些是 Lua 模拟 API，不执行 C++ AI/伤害结算。

## 验证

- Lua 5.4.6：`C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe tests/kamikaze_squad_behavior_test.lua` → `kamikaze_squad_behavior_test: ok`，exit 0。
- 同目录 luac.exe `-p kamikaze_squad.lua` → exit 0。
- 限定神风模块/测试的 `git diff --check` → exit 0；仅既有 Git 行尾转换提示 LF will be replaced by CRLF，没有空白错误。
- 全项目验证由主代理统一运行，本子任务没有据此宣称全项目通过。
- 普通读取/普通 apply_patch 受 sandbox helper deny-read ACL 故障影响；只读与同一 codex --codex-run-as-apply-patch 引擎使用 require_escalated，写入目标仍严格限定上述三个文件。

## API 依据与未完成边界

本机 `E:\Isaac - Repentance\resources\scripts\main.lua:526-529` 核对了 BombExplosionEffects 包装及参数顺序；[GetPtrHash 文档](https://wofsauge.github.io/IsaacDocs/rep/GlobalFunctions.html#getptrhash)用于实体身份依据，[BombExplosionEffects 文档](https://wofsauge.github.io/IsaacDocs/rep/Game.html#bombexplosioneffects)用于完整爆炸 API 依据。

以下仍未验证/未完成：

1. 无运行游戏，未执行同一玩家多包装的 GetPtrHash native 探针；代码通过离线反例不代表游戏中已观察 NPC 生成。
2. 原生 Mulliboom 的爆炸伤害是否为 40、实际作用半径是否与通用 RadiusMult=2 对应原版半径 ×2，没有基线测量。
3. 外部致死依然交给原版死亡行为，未统一到单次双倍范围；没有冒用本机缺失的 MC_PRE_BOMB_DAMAGE/MC_PRE_UPDATE。
4. 真实寻路是否被 native AI 覆盖、爱心视觉、玩家/coop 承伤、免爆/护盾/无敌帧、清房与过门实际回调顺序未验证。
5. 长期跟踪仍保留原模块实体引用并检查 Exists/IsDead；本次统一了引用身份比较，没有增加 EntityPtr 封装。native 包装生命周期仍需实际游戏验证。

因此交付状态是“已完成可安全实施的逻辑修复及离线验证，原版爆炸完整合同仍待 native 证据”，不是“全部功能已游戏验收通过”。
