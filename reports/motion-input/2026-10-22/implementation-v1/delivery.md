# 通用搓招共享模块第一版交付

日期：2026-10-22。范围：用户已批准的共享输入识别、主动栏适配、全部原生攻击限制与道具招式来源接口。

共享模块已写入当前安装目录，并由 `main.lua` 加载。正式道具注册表为空；本轮没有设定具体道具 ID、伤害、气槽、资源、美术或道具池。自动检查证明共享逻辑和模拟回调契约，尚未运行本模块的真实游戏验收。

## 实现与操作

| 文件 | 职责 |
| --- | --- |
| [motion_input_core.lua](../../../../motion_input_core.lua) | 不含引擎对象的输入状态机、方向归一化、朝向锁定、计时、容错、重新监听和单条缓存 |
| [motion_input_shooting.lua](../../../../motion_input_shooting.lua) | 持有关系、攻击实体拦截、伤害来源追踪、招式及其派生攻击放行、可选精确持续伤害归属 |
| [motion_input.lua](../../../../motion_input.lua) | 原始输入采样、主／口袋主动栏、注册与执行接口、诊断、多人及生命周期清理 |
| [main.lua](../../../../main.lua) | `MOTION_INPUT_BEGIN/END` 中唯一一处共享模块接入 |

全部指令先按住主动键。单波动为一次新的射击方向键按下，双波动为同方向两次独立按下，间隔最多 1.2 秒。长按和松开不生成额外点击，双波动第一击不执行单波动。

WASD 指令包括反波动 214／24／14、升龙 623／626／323、后蓄前，以及四主方向的 360、连续八主方向的 720。反波动和升龙为 0.6 秒；后蓄 0.5 秒，转前窗口 0.2 秒；360 为 0.8 秒，720 为 1.5 秒。自然斜向过渡、短回中与两帧回弹受到容错；错误斜向和乱序不能删掉后拼成成功。

普通指令起手锁定射击朝向。未射击时取本局最近明确射击朝向，本局从未射击时随当前头朝向更新。朝向记忆跨绑定切换和换房保留，未完成指令和缓存会清空；不把移动方向当作朝向。完成后 WASD 回中 0.1 秒可再搓；仅收招能缓存一条 0.2 秒指令，资源不足、目标不符和执行失败都不重试。

## 攻击限制与原生合同

持有任一注册道具即限制该玩家原生射击和炸弹输入，书包未选中仍计入持有。原始输入读取有独立作用域，因此识别器仍能读到射击方向。原生泪弹、炸弹、激光、刀和弹幕实体在初始化／更新路径拦截，其他可归属该玩家的非招式伤害在伤害入口拦截。跟班与攻击派生沿来源链解析；环境或确实无从归属的来源不猜测持有者。玩家自身扣血不由这个攻击限制取消。

模块不写 `CanShoot`，解除时也不调用 `SetCanShoot(true)`，从而不会恢复其他系统已禁止的射击。实际持有关系在输入、实体和伤害检查时重新确认，失去最后一件立即解除本模块限制。

本机 `resources/scripts/main_ex.lua` 的 `boolCallbacks` 和 `resources/scripts/enums.lua` 的 `MC_PRE_USE_ITEM` 注释确认：当前安装的 1.0.12a 分支以布尔 `true` 取消原生使用。适配层采用该合同，避免持有主动键意外触发原生使用／耗能；没有使用较新文档中的返回表合同。

精确毒／火／流血归属按当前运行时探测 `Isaac.GetStatusAttributionAPIVersion()==1` 及 `Isaac.GetCurrentDotDamageKind`；具备能力时消费 `REPENTOGON_POST_DOT_APPLIED/COPY`。接口维护位置见[既有原生归属交付](../../../drive-rush/2026-10-15/dot-ownership/delivery.md)。`service.Capabilities.exactDot` 明确报告本次运行能力。缺失该接口时，具有实体来源的攻击仍受限制，但无法从原生无实体 DOT 推断归属；不宣称该环境下完整封锁无来源持续伤害。本轮没有更换 DLL。

这些是实现入口与本机合同依据；硫磺火、科技、妈刀、骨棒等各形态的生成／松键／持续命中仍须按[实机卡](game-acceptance.md)逐项确认，不能用同类实体模拟代替原生能力证明。

## 后续道具接入

由获得授权的具体道具模块调用 `Neverbirth.MotionInput:RegisterOwner(ownerKey, binding)`。`binding` 必须提供运行时 `collectibleId`、一种 `profile`、`has(player)`、`execute(player, command)`；可提供 `availability(player)`，返回 `ready/recovery/resource/target`。每个 ID 只允许一个注册；不会给玩家添加任何道具。

`execute` 在命令作用域中同步运行，返回 `{ok=true}` 或 `{ok=false, reason=...}`。`command` 提供 `profile/facing/serial`，同一玩家的完成序号跨道具和换房不重复。同步生成的攻击以及可确认来源的派生攻击会自动保留命令归属；作用域结束后玩家本人不会永久获得放行标记。

延迟生成或直接伤害必须用 `service:WithCommand(player, command, function() ... end)` 包住整个执行段，再在其中创建攻击。不得先在作用域外生成，再补 `MarkAttack`：实体初始化回调可能已经删除未标记攻击。`MarkAttack(player, entity, serial)` 只用于仍存在的、归属正确且已有发出序号的实体；不能凭任意编号伪造本系列来源。

`GetState(player)` 提供当前模式、锁定朝向、进度、缓存、最近结果及执行错误，`GetDiagnosticText(player)` 区分输入未完成、暂存、条件不足和已释放。正式 HUD 的位置、美术及音效未在本轮定稿。

## 检查证据

三个专项测试已实际运行：

| 命令 | 退出码 | 覆盖 |
| --- | --- | --- |
| `lua tests/motion_input_core_test.lua` | 0 | 90 条断言；全部指令、窗口边界、相反键、斜向、失败重起、朝向记忆、蓄力、缓存、重新监听 |
| `lua tests/motion_input_shooting_test.lua` | 0 | 55 条断言；实体类别、直接／跟班／派生来源、命令作用域、状态复制、多人和解除 |
| `lua tests/motion_input_behavior_test.lua` | 0 | 61 条断言；原始读取、单击／双击、原生使用取消、书包／口袋栏、多人、条件失败、死亡／换房和序号隔离 |

统一回归命令为 `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/motion-input/2026-10-22/implementation-v1/final-checks.json`，退出 0：**83 项通过，0 失败，0 阻塞／未运行，6 条警告**。警告均来自既有通用资源解析；严格验证器、My Stuff、README 与知识导航检查通过。独立运行 `pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1` 也退出 0，5 个知识页可达、99 个本地链接有效。

原始结果见 [final-checks.json](final-checks.json) 和 [final-checks.log](final-checks.log)。修复前失败、静态发现和执行裁定保存在 [progress.md](progress.md)；第一次集成检查也保留在 [integration.json](integration.json)。最终范围核对 [final-integrity.json](final-integrity.json) 确认：移除共享接入块及其分隔空行后，`main.lua` 与任务开始快照逐字一致；内容登记、道具池、实体、声音 XML 与生成登记的 SHA-256 均未变。

独立只读复核在修复后运行了三个目标测试，另验证 360／720、四起点、双旋向的 16 组自然斜向序列，以及相反斜向反例。最终没有报告仍需阻塞交付的正确性问题。该复核仍属于源码与模拟检查。

## 当前边界

代码已在当前安装目录接入；没有默认绑定，因此当前不会把现有任何道具改成搓招道具。具体波动、双波动或摔技的攻击效果仍需各自确认后注册。没有启动游戏、增加玩家存档字段、修改原生 DLL、提交、推送或发布。本轮保留原有工作区改动；逐类武器、手感、真实继续和第三方组合仍为待验收。
