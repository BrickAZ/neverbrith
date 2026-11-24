# 优化执行验收记录

2026-09-05。本轮已完成当前环境可支持部分的代码实现、受控回归及最终独立审查。**整个总计划未全部完成；所有游戏内验收均未验证。**

## 用户决定与环境

- 开发环境是普通 REPENTOGON，不是忏悔龙＋；磁盘 main_ex.lua 与既有启动日志确认版本基线 1.0.12a。
- 肉块继续挡下致命伤，不改为先死亡后复活。P2 真复活迁移不执行；不修改肉块或 Revive My Love 生产逻辑。
- 工作分支 codex/repentogon-item-optimization；无本轮提交、推送、合并、发布、游戏升级或启动参数修改。
- 本轮多次只读进程检查没有发现 isaac-ng；没有启动或操作游戏，没有修改存档或美术资源。
- 初始工作区已有三语XML、角色/RML代码、美术及其它未跟踪改动。全部保留，详见 baseline.md；不能把 git status 中所有改动都算作本轮成果。

## 已落地的代码

| 范围 | 实际修改 | 验证证据 | 游戏内 |
| --- | --- | --- | --- |
| 诛失效修复 | 可调用原生构造器、稳定实体身份、保存key清理owner、视觉失败隔离、正确NPC来源和泪弹归属 | 完整annihilation行为测试及独立审查通过 | 未验证 |
| 神风失效修复 | 每玩家稳定计时/上限、有效目标持续锁定、原生NPC转换、一次爆炸调用预检和异常隔离 | 完整kamikaze测试；抛错前attempts直接计数且后续100update仍1；独立审查通过 | 未验证 |
| P0 前置入口 | 注册和include之前检查真实稳定REPENTOGON与已安装同次伤害分发能力；失败一次清晰提示并停止初始化 | bootstrap 14类、重复加载和严格版本负例通过 | 未验证 |
| P1 ACE＋七咒 | 同次返回Damage表，不重放TakeDamage；两个x2可组合x4；EARLY优先级让本模组挡致命伤者读取放大后金额 | 本机真实Lua分发器＋真实注册排序12组合通过；任一false取消；非伤害字段保持 | 未验证 |
| P4 诛＋c356 | 原生AddActiveCharge主副手各1，按返回实际增加量判断，pocket/超充不动 | 普通/满充/空槽/失败/多人/重复命中等原回归通过 | 未验证 |
| P6 鸿运齐天蛊 | 命名派生缓存、有限数字依赖快照、事件失效、两阶段刷新、incoming更高值保留、异常清flushing并dirty重试、owner清理 | 新cache测试及旧两套鸿运合同适配通过；100次无变化update不排序/不重算；两轮审查通过 | 未验证 |

诛的150帧、75/115半径、每4帧、实时Damage、死亡+9无上限、射程x0.45、频率x0.60、过门清理均保留。神风90帧、每人2只保持。未修改池、品质、图标、ANM2或声音。

**神风的严格边界：** 固定伤害40与RadiusMult=2是保留的当前调用参数，尚不能据此证明等于原版伤害或实机两倍半径；自然外部致死路径的统一双倍范围也未完成原生验证。不能把基础失效修复说成完整原版爆炸合同已验收。

**伤害兼容边界：** 顺序测试覆盖本模组ACE/七咒修改者与肉块/八音盒DEFAULT取消者，不承诺任意第三方更晚优先级改变伤害后的结果；本机Lua分发测试不是C++扣血、护盾、无敌帧或献血机实测。

## 实际修改文件

生产代码仅四个：

- [main.lua](<E:/Isaac - Repentance/mods/neverbrith/main.lua>)：前置、ACE同次倍伤及优先级、鸿运缓存和必要接线。
- [annihilation.lua](<E:/Isaac - Repentance/mods/neverbrith/annihilation.lua>)：诛失效与原生充能。
- [kamikaze_squad.lua](<E:/Isaac - Repentance/mods/neverbrith/kamikaze_squad.lua>)：神风身份、计时、追踪与爆炸失败边界。
- [ring_of_the_seven_curses.lua](<E:/Isaac - Repentance/mods/neverbrith/ring_of_the_seven_curses.lua>)：七咒同次倍伤与优先级，Q4规则未改。

测试：

- 新增 repentogon_bootstrap_test.lua、repentogon_damage_dispatch_test.lua、repentogon_damage_order_test.lua、repentogon_test_fixture.lua、fortune_custom_cache_behavior_test.lua（均在 tests/）。
- 扩展 ACE、七咒、诛、神风对应行为测试。
- 大狗测试只新增显式 --pending-p5 反例，没有改变大狗生产代码。
- 22个直接加载main的旧测试只接入前置fixture；localization另记录priority/AddOrder供真实排序组合测试使用。fixture只属于测试，不成为生产降级或bypass。
- 详细逐文件退出码见 test-results-final.json 和 validation-final.md。既有RML/角色测试修改并非本轮重写；本轮对其保留部分只做回归。

计划与报告：

- 更新三个2026-09-05计划的执行状态（诛、神风、总优化计划）。
- 新增本目录分项brief/report、基线、环境、最终验证、独立审查和游戏清单。差异包是审查候选快照；final-review-result.md明确记录其后续两项修订关闭过程。

## 最终验证结果

- **35套Lua脚本：16通过、19失败。**
- 执行前22套直接main测试为3通过/19失败；最终仍在同一19个旧失败点：16个include加载桩缺失，3个旧XML/英文断言。没有把失败删掉或改游戏设计迎合测试。
- 中途angelbox/musicbox曾在新生命周期注册处提前失败；补公共fixture缺失的真实15/19枚举后已恢复原include失败，最终逐条对比而非只比较总数。
- **38个涉及Lua文件语法通过**，包含本轮36个和两份仅作回归的既有RML脏改文件。
- **通用验证器：19 warning、0 failure，exit0。**
- **Neverbrith专用验证器：273 warning、0 failure，exit0。**
- 与执行前逐条比对没有新增警告。少一条椰子hotpath告警只是扫描归类变化，不能作为椰子优化成果。
- **git diff --check：exit0**，仅LF/CRLF提示，无空白错误。
- P5 opt-in反例仍预期exit1：取消碰撞后同ID代码赠送被误计食物，expected0/got1。默认大狗回归exit0。
- 最终独立审查：Approved（代码层）；Important顺序问题和Minor异常计数缺口均已关闭。不是合并/发布授权。

命令、逐脚本输出及统计：[validation-final.md](<E:/Isaac - Repentance/mods/neverbrith/reports/repentogon-item-optimization/validation-final.md>)、[test-results-final.json](<E:/Isaac - Repentance/mods/neverbrith/reports/repentogon-item-optimization/test-results-final.json>)。收尾另检查34个新增Lua/计划/报告文件，无行尾空白；再次git diff --check退出0，HEAD仍为8b736aa，未产生提交。

## 明确未执行或暂缓

| 阶段 | 状态与原因 |
| --- | --- |
| P2 肉块真复活 | 按用户决定不执行，现有挡伤保留 |
| P3 有效受伤记账 | POST不保证非零HP已提交，缺逐事件原生时序证据；无生产迁移 |
| P5 拾取来源 | 已复现来源误认；缺原生queue flush来源/顺序证据；P5b-d未越序执行 |
| P6 清房/付债 | 不以缓存优化名义改债务；依赖P3确认真正成功承伤 |
| P7 记忆紊乱分组 | 当前版本不具计划所需分组合同 |
| P8 神风原生范围入口 | 当前无MC_PRE_BOMB_DAMAGE，未执行原生来源/范围探针 |
| P9 狗粮XML固定属性 | 未向旧版本写入新版本字段，未证明原生计算阶段等价 |
| P10 禁防爆/安全低频/精确权重 | 没有足够当前API与实机证据，未实施；未新增忙等、CPU负载或强退手段 |

详情：[experiments.md](<E:/Isaac - Repentance/mods/neverbrith/reports/repentogon-item-optimization/experiments.md>)、[inventory-report.md](<E:/Isaac - Repentance/mods/neverbrith/reports/repentogon-item-optimization/inventory-report.md>)、[damage-timing-audit.md](<E:/Isaac - Repentance/mods/neverbrith/reports/repentogon-item-optimization/damage-timing-audit.md>)。

## 下一步：游戏内验收

建议先测诛（空房/射击/过门/c356双槽），再测神风（90帧/每人2只/追击/一次爆炸），随后测ACE＋七咒＋肉块/八音盒，最后测鸿运持有变化、多人和继续游戏。

所有项的真实结果目前均为**未验证**；使用[游戏内清单](<E:/Isaac - Repentance/mods/neverbrith/reports/repentogon-item-optimization/in-game-acceptance.md>)记录，不能把当前静态或Lua通过当成实机证明。
