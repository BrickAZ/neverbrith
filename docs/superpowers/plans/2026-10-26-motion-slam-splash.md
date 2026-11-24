# 360落地范围伤害与摔技倍率实施计划

> **For agentic workers**: 使用superpowers:executing-plans在当前会话连续完成；不提交、不推送、不发布。当前安装目录含既有未提交实现，按文件快照保留无关工作，不另从旧HEAD重建。

**Goal**: 普通360主目标3倍、OD360主目标6倍；两者落点半径80内其他敌人3倍；720主目标15倍、全房其他敌人10倍。

**Architecture**: 复用motion_combat.lua的重摔帧、真实NPC、伤害来源、阶段去重与实际扣血回执。motion_combat_core.lua保存确认参数，motion_item_text.lua同步中英文说明；main.lua和原演出资源不动。

**Tech Stack**: 本机REPENTOGON、Lua 5.4、PowerShell隐藏引擎验收。

**Spec**: [已确认战斗合同](../specs/2026-10-24-motion-combat-first-pass-proposal.md)；用户本轮先批准80／3倍范围方案，随后将720最终倍率纠正为15／10，覆盖此前5／5提议。

## Global Constraints

- 普通360仍54帧／1.8秒，OD360仍48帧；抓取、重摔、释放、保护时点保持。
- 720仍唯一V9，三气、获取补满、回气、289帧交还控制和独立FX尾段不变。
- 范围只在成功重摔时发生一次，不对主目标叠加；友方、魅惑、死亡、无敌及其他不可受伤目标继续由原伤害入口排除。
- 360范围伤害沿用原有效伤害回气；720不回自身气，不改规则。
- 品质、道具池、普通／OD升龙、波动和输入不动；不操作用户键鼠或现有游戏进程。

## Review Focus

- 范围中心应为本次真实重摔落点，不能误用玩家中心；普通NPC与现有演出落点一致，Boss使用保持原位的真实位置。
- 半径按目标中心距离≤80结算，边界外不命中；先记录落点再打主目标，致死或伤害回调移除主目标不能丢掉范围伤害。
- 普通／OD主目标分别只吃3／6倍；多敌人和反向落点不能重复结算。
- 伤害被取消、过量击杀及玩家归属仍由原实际扣血回执结算，不凭申请伤害加气。
- 720最终15／10须同步正式说明及所有仍可运行的诊断预期，不能遗留旧30倍或临时5倍。

## Task 1: 真实结算、说明与验证

**Files**: 修改motion_combat_core.lua、motion_combat.lua、motion_item_text.lua；扩展tests/motion_combat_core_test.lua、tests/motion_combat_test.lua、diagnostics/motion_combat_acceptance.lua和tools/test-motion-native.ps1；同步合同与知识入口。

**Interfaces**: 继续使用C.Definition(move,variant)、hit(session,npc,amount,stage)及presentation的现有SetCombatFrame／GetTargetPosition；360参数新增splash=3、splashRadius=80，720保留全房splash=10。

- [ ] 写倍率、边界、左右镜像、主目标不叠加、排除目标、一次结算、致死及归属回气测试，运行并保存修复前失败。
- [ ] 在既有重摔分支记录当前落点，复用hit进行一次范围结算；同步中英文说明及确认合同。
- [ ] 运行两个战斗测试、说明／资源检查及LuaAll；记录命令和退出码。
- [ ] 扩展隐藏游戏用例验证普通／OD360主目标与范围内外敌人的实际HP、720的15／10、无自身回气及正常清理，启动前拒绝已有游戏。
- [ ] 正常结束自己的测试进程，核验存档／配置及main恢复；核对无关文件哈希，写交付证据。

执行记录保存在reports/motion-items/2026-10-26/spd-splash-damage-v1。
