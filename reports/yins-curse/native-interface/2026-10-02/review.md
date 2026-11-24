# 独立只读审查结论

审查者：`/root/yin_native_review`，GPT-6-astra，按 executing-plans / requesting-code-review 技能要求的新上下文单人审查。没有修改文件、Git、安装目录或启动游戏，没有再派审查代理。

结论：可作为待审批本地候选，最终没有未闭合的 Critical、Important 或具体 Minor。不是实机玩法验收通过，也没有提交或合并授权。

## 已检查的关联

- 六处分支与固定 EXE 相符；纵火狂否决后保持爆炸位、继续下一个来源；宿主帽否决先于成功反馈。火焰与普通投射物分支未接入。
- 实际 this 与栈顶 callId 绑定，EBP `+08/+0C/+14/+18` 读取当次参数；不补第二次伤害、不操作持有量或直接改健康。
- stub 先复现原资格分支；GP、EFLAGS、x87/XMM/MXCSR 的保存/恢复以及 stdcall 三参数匹配。
- 每个监听器的 hit/immunity/EntityRef 值副本、全部监听器执行、false 累积、旧伤害取消链保留。
- 完整能力查询、Yin 实际目标与当前黑蜡烛、固定定制版本启动分支、只读校验与备份/恢复边界。

## 本轮发现与闭合

Important：诊断曾重复定义 healed，重复注册 post-player-add-hearts，导致一次原生治疗输出两条 heal-return，干扰“原治疗仅一次”的验收。已删除重复，新增实际脚本夹具 RED：got 2 / exit 1；GREEN：opt-in、重复加载唯一、一次事件一条返回日志、关闭清空、重开唯一 / exit 0。审查者独立运行确认 exit 0。

执行者另外发现并修复启动门禁拒绝定制版本、patch 用 CRLF 写入导致新 LF 文件反向检查失败。17 个入口 case GREEN 和两份 patch reverse check 均由审查者复核通过；执行者另完成固定 commit 受影响文件的 forward apply / 19 文件 round-trip。

## 审查者实际重跑

| 检查 | 结果 |
| --- | --- |
| Native context EXE | exit 0 |
| 实际 EXE sites EXE | exit 0 |
| 实际 callback 核心 dispatcher Lua | exit 0，7 项 |
| Yin 新专项 Lua | exit 0，5 项 |
| 诊断唯一性 Lua | exit 0 |
| Bootstrap Lua | exit 0，17 个 case、重复加载 |
| Native/ANTLR 两份 patch reverse check | exit 0 |
| install-yin-native.ps1 -Mode Verify | exit 0，23 个计划变化，无安装写入 |

初次 sandbox Lua 启动被系统拒绝，之后只读执行权限重跑成功；结论来自成功重跑。编译、96 条执行 stub、LuaAll、恢复夹具沿用执行者保留的实际证据，审查者没有冒充为自己重跑。

## Declined to judge 及边界

1. 真实加载/运行时 API1：未安装未启动，继续 not_run。
2. 治疗/反馈、混合标志、吐根资格、合作宝宝、死亡/复活/续局：静态可核对，真实表现仍需完整矩阵。
3. 未产生命中的拆弹/碰撞规避及第三方独立 false：规格明确排除，不要求撤销。
4. 其他 EXE/REPENTOGON 分支/任意第三方原生组合：限定固定 EXE hash 与 1.0.12a，不推导跨版本可用。
5. 上游 ASMPatcher 系统级内存保护失败/资源耗尽：未做原生失败注入，不声称所有失败路径已实测。
6. 断电/进程强杀的半写入恢复：夹具仅证明正常安装/回滚/损坏拒绝，不扩大故障保证。
7. 全新目录取源、应用 patch 后完整重编译：未做整轮 clean rebuild，现有源真实编译及两份可逆 patch 不替代它。
8. 根仓库此前批次其他玩法/池/资源/历史门禁：依审查包保留，不扩大此次审查范围。
9. 提交/合并/推送/创意工坊/上游贡献：当前未授权，未执行。

执行者对每条边界的裁决与成本记录在 [execution-decisions.md](execution-decisions.md)。

## 安装后栈修复的限定复核

首启实机证明能力查询留下 5 个栈元素，LuaStackProtector::~LuaStackProtector 只检查并 abort，不自动恢复。修复新增 ExplosionImmunityLua.h，以作用域恢复查询前栈顶，能力/调试查询都覆盖提前返回；保留原 protector。LuaResults 先弹真实结果，外层 protector 后检查。

同一审查者只读复核本次修复，独立直接执行 CTest 注册的 Release explosion_immunity_lua_stack_test.exe，exit 0：6 种状态 × 10000 对能力/调试查询、父栈高度和哨兵均保留。没有未闭合 Critical/Important；没有将查询 helper 的离线执行当作整个游戏桥接验证。真实复验和部分伤害矩阵随后由主线程执行，见 runtime-results.md。
