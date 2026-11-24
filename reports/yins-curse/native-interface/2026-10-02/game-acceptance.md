# 阴的诅咒原生实机验收卡

当前：修正版候选已安装，真实 API 为 `1`；核心 19/19、进阶 8/10、生命周期 3/4。完整验收尚未闭合。实际命令、失败与修复、日志、玩家/种子和状态恢复见 [runtime-results.md](runtime-results.md) 与[交付记录](delivery.md)。本卡不把模拟 Lua、EXE 扫描或 x86 stub 执行当作真实 Isaac 游戏。

## 开始前和日志

用户已授权并完成本机安装。追加人工验收仍采用新测试局；每次记录 EXE/DLL hash、种子、玩家类型/InitSeed、启用 Mod 清单和候选版本。先在游戏控制台查询：

```lua
print(Isaac.GetPlayerExplosionImmunityAPIVersion()) -- 应为 1；否则停止此项验收
print(Isaac.GetItemIdByName("Yin's Curse")) -- 用真实运行 ID，不固定写 779
```

控制台 Lua 入口依实际游戏配置使用 `lua <表达式>`。开启诊断：

```lua
NEVERBIRTH_YIN_EXPLOSION_DIAGNOSTICS=true
include("diagnostics/yin_explosion_immunity_acceptance")(Neverbirth)
```

重复加载诊断不会重复注册。关闭：

```lua
Neverbirth.YinExplosionDiagnostics.Disable()
```

正常游戏不自动加载本脚本。它只观察免疫事件、治疗尝试/返回和 post-damage，不扣血、不补伤、不变更持有道具。原生调试同时记录 callId/玩家/sourceKey/siteKey/最终 allowed，分派记录每个监听器的返回与累积 veto；监听器异常/非法类型另走既有错误日志。治疗日志没有伪造 callId，按日志顺序、玩家、种子和单次测试关联；嵌套测试必须另外记录内外调用。

保存游戏原生日志 `log.txt`、`repentogon.log`、`zhl.log`（实际存在的文件），并记录关键画面。纵火狂缺血场景逐次分离 `heal-attempt`、`heal-return`、免疫否决和 `post-damage`，不能只看最终血量。

## 第一轮操作

1. 新测试局未取得诅咒，持纵火狂/宿主帽分别承受真实爆炸；记录正常免疫，再取得诅咒重测。经典收藏品：纵火狂 223、宿主帽 375、黑蜡烛 260；阴的诅咒使用本局查出的 ID。
2. 诅咒激活后，对同一实际玩家做黑蜡烛有/无 × 原免爆来源有/无四组合。无来源时黑蜡烛不产生免爆；有来源且无黑蜡烛时应走同一次原伤害流程，仍可能被其他原生保护挡住。
3. 纵火狂满血和缺血分别测；缺血需观察原治疗仅一次，随后否决免爆。再测纯火焰和混合 fire+explosion 原始标志，记录保护原因与命中是否进入接口。
4. 宿主帽免爆否决不出现伪成功反馈；另用普通投射物检查其原阻挡能力。纵火狂+宿主帽同时持有时，前一来源否决后仍须到后一来源。
5. 再进入下表其余场景。吐根限定炸弹/刀和合作宝宝原生资格需真实触发；未触发资格不能因为“没有扣血/没有日志”就判通过。

## 完整矩阵

| 场景 | 预期与必须记录 | 状态 |
| --- | --- | --- |
| 四种黑蜡烛/免爆来源组合 | 本次实际玩家条件，黑蜡烛不新增免疫 | passed_runtime：core-3 |
| 诅咒未激活/接口无订阅者 | 未激活保留免爆；无订阅者快路径保留免爆；尚无官方构建逐项实机 A/B | partial：core-3、advanced-2 |
| 纵火狂满血 | full-health site 可否决，无额外治疗 | passed_runtime：core-3 |
| 纵火狂缺血 | 原治疗次数/条件/顺序保留，after-heal site 可否决，伤害另记 | passed_runtime：一次治疗、一次伤害；core-3 |
| 纯火焰/混合标志 | 原火焰防护保留，仅明确免爆资格进接口 | passed_runtime：core-3 flags 2/6 |
| 宿主帽爆炸/投射物 | 爆炸可否决；成功反馈画面和普通投射物仍需人工检查 | partial：爆炸 core-3；画面/投射物 not_run |
| 多个免爆来源 | 每个实际资格依序处理，没有早跳扣血漏过来源 | passed_runtime：纵火狂→宿主帽；core-3 |
| 吐根限定炸弹/刀 | 限定炸弹资格实际触发；真实刀对象未满足限定资格 | partial：bomb passed，knife qualification_not_observed |
| 合作宝宝皮肤 20 | Variant 1/Subtype 20/BabySkin 20 原生对象有记录，未进入该免疫站点 | qualification_not_observed：控制器断开/即时命中无接口日志 |
| 圣光斗篷/通用无敌帧 | 斗篷消耗与原无敌帧保留；纵火狂第二次治疗仍执行，无强迫第二次扣血 | passed_runtime：advanced-2 |
| 普通伤害取消/修改链 | 两个旧 false 入口均取消；实际伤害/flags/countdown 修改有效 | passed_runtime：core-3、advanced-2 |
| 新接口多监听器 | false 后 true/nil/异常/非法返回不恢复免爆；顺序正确 | passed_runtime：core-3；快照 advanced-2 |
| 合作/双角色/嵌套 | 不同实际目标与 callId、返回恢复父上下文 | passed_runtime：真实合作玩家、Jacob/Esau、nested；控制器 UI 未验收 |
| 黑蜡烛取得/失去 | 下一次资格使用当前状态，不改已锁定 Q4 路线 | passed_runtime：core-3、advanced-2 |
| 致死/复活/续局/沙漏 | 死亡、九命猫复活、实际房间沙漏回溯通过；关闭后继续未测 | partial：lifecycle-1；真实 continue not_run |
| 不支持构建/脚本混装/卸载 | 分派版本 0 时能力 0、保留免爆，再恢复 1；正常无订阅者已测 | partial：真实 API 0/1 passed；跨 EXE/卸载后启动未实机测 |

种子、玩家、启用 Mod 清单、候选 DLL hash、真实 API 值及日志已登记在各 runtime attempt；完整图像与人工确认没有提供，因此未标注 user_approved。测试后的原续局、Mod 数据及设置已恢复并校验，见 [state-restoration.json](state-restoration.json)。
