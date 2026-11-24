# 升龙强制移动、OD无敌与720原生特写修复

2026-10-25。修改已写入当前游戏安装目录；未提交、推送或发布。本轮主线为战斗控制与早期伤害取消，原生演出为副线；使用isaac-neverbrith-router、isaac-testing-debugging、isaac-damage-health-contracts、isaac-repentogon-callbacks和isaac-anm2-visuals。

## 本次修正

用户反馈720缺少特写、升龙期间仍能自行移动、OD升龙没有无敌。源码核对发现：正式路径明确排除了V9 cinema；升龙没有参与lockMovement，起跳只存在于绘制偏移；OD保护还要求来源被识别为敌人，因此普通尖刺／爆炸等来源不受保护。

### 升龙移动

普通和OD整招封锁移动输入，按已确认动画脚点的水平轨迹推进：普通累计51、OD累计57个房间单位，左右镜像，真实Y保持起手时位置；起跳高度仍由渲染表现。没有额外编造速度或移动距离。碰墙、岩石及不可走坑时停止；命中停顿期间保持受控位置，结束后解除输入限制。

近战仍用原长度／半径的胶囊扫掠，端点覆盖前移前后位置并保留圆端，避免前移越过贴身目标时额外半平面裁剪吞掉OD第二段。普通仍2倍，OD仍两段2倍＋3倍，每阶段去重不变。

### OD无敌

时段沿用此前确认的起手至第二段结束（逻辑0–32），收招33–49可受伤。保护阶段取消常规伤害，不再依赖伤害来源是否为敌人；怪物、弹幕、普通尖刺／爆炸等走同一早期取消路径。主动生命支付、献祭类支付与DAMAGE_FAKE保留。没有通过补血、改永久碰撞或延长原生伤害冷却模拟无敌。

使用当前安装版本的MC_PRE_PLAYER_TAKE_DMG：`(_, player, damage, flags, source, countdown)`，返回false在原生受伤流程前取消。契约已核对本机匹配的CustomCallbacks.cpp与main_ex，而非只看单测枚举。

### 720镜头

V9原本的21–288帧镜头阶段重新用于正式游戏：聚焦幕覆盖房间画面，按V9构图与缩放绘制**真实玩家实体**，并绘制实际被抓NPC的Sprite；镜头结束或中断即返回房间。使用[Entity.Render(Vector)](https://wofsauge.github.io/IsaacDocs/rep/Entity.html#render)重新绘制当前原生玩家及服饰，不创建以撒替身，不拆头身，不SetFrame玩家。

`motion_cinematic.lua`仅提供屏幕构图和缩放。`motion_presentation.lua`在限定的cinemaPass内临时设置真实玩家整体缩放／旋转，通过原生Vector偏移移到镜头位置；POST_PLAYER_RENDER及外层finally式恢复路径保证退出、取消和异常后归还字段。当前main_ex会累加PRE渲染返回值，镜头返回的是目标根坐标减已有位置／偏移，避免重复位移。

幕层为`cinematic_v1/scene.anm2`的单个Fill动画／单像素裁剪，纹理逐字节复用本机原版`gfx/ui/stage/bgblack.png`。它是刻意的全画面电影幕，不是图标背景；没有角色、敌人或预制战斗贴图。特写中的腾空横转保留V9源脚本217–254帧的`theta=(t-217)*.68`整体宽度投影，不把放大后的横转退化为静态翻面。V9原始资源和生成数据不改，伤害／气量／394帧／唯一版本／两圈及↑↓快捷全部保留。

## 实际检查

| 命令 | 本次结果 |
| --- | --- |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/motion-items/2026-10-25/dp-control-cinema-v1/lua-all.json` | 退出0；91通过、0失败、0阻塞，6条既有通用告警；严格检查0告警0失败 |
| 战斗／演出测试 | 264／3587项断言通过；镜头数学最终补跑5项通过 |
| `python tests/motion_presentation_resources_test.py` | 退出0；四份已确认源资源、12动画、14900裁剪键、15音效事件和生成投影一致 |
| `python tests/motion_cinematic_resources_test.py` | 退出0；原版幕层像素哈希、单像素裁剪、单图层、无角色图像 |
| `python tests/motion_items_resources_test.py` | 退出0；四主动、三语言、其余图集和道具池保持 |
| `python tests/motion_sa_hud_resources_test.py` | 退出0；SA原始资源和规则保持 |
| `lua tests/localization_test.lua` | 退出0；最后同步说明后通过 |
| `pwsh -NoProfile -File tests/motion_native_state_test.ps1` | 退出0；包括并发修改保护、未知新增文件保留、启动时缺失槽的新文件证据和重复恢复 |
| `pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1` | 退出0；导航通过 |

完整Lua检查在控制／免伤与原生特写实现后运行；随后保留了特写中的V9横转投影，并补跑镜头数学、3587项演出测试和专门原生720用例。诊断脚本、恢复助手及说明／文档另作调整，诊断语法和恢复助手分别重新检查。Lua实际为`C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`，Python为`C:/Users/Anton/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`。

修复前失败记录为`control-red.log`（OD来源为空的常规伤害漏过）和`cinema-red.log`。原生结果、完整套件结果均保留在当前目录，未以静态通过替代游戏证据。

## 原生游戏结果

最终命令：`pwsh -NoProfile -File tools/test-motion-native.ps1 -Probe dp_cinema -Attempt control-cinema-2 -TimeLimitSeconds 110`，退出0。**9场景、163项通过，0失败，没有原生Lua运行错误**。见[结果](native/control-cinema-2/result.json)与[游戏日志](native/control-cinema-2/game-log.txt)。

随后针对镜头里的整体横转补跑`pwsh -NoProfile -File tools/test-motion-native.ps1 -Probe dp_cinema -Attempt cinema-final-spin -TimeLimitSeconds 35`，退出0，**1场景24项通过、0失败**。验证特写内确实连续收窄／翻面、540次原生镜头观测、实际伤害／扣气／播放完成与恢复；见[最终720结果](native/cinema-final-spin/result.json)和[逐项日志](native/cinema-final-spin/game-log.txt)。该轮同样正常退出、精确恢复223文件状态，未知新增文件为空。

- 普通／OD向右和向左累计位移分别为51和57（OD实测57.00003，浮点误差）；墙边为0。Y固定；诊断在正式更新前施加的偏移／速度被接管修正。四移动输入的封锁另由回调单测验证，全程没有按用户物理键。
- OD在逻辑1、9、23、31帧使用来源为空的普通尖刺伤害测试，真实生命损失均为0；37、46帧收招测试各损失1。每次先清除测试角色的原生受伤冷却，避免将之前挨打的原生无敌误当成招式无敌；该清除仅存在于诊断，不在生产逻辑。敌人伤害／主动支付排除另有原生用例。
- 三次完整720分别通过原两圈、↑↓快捷及快捷＋Shift触发；每次记录到540次特写原生绘制观测，实际玩家缩放大于房间原尺寸2倍，累积偏移与目标屏幕根坐标一致，未出现玩家Sprite副本。主目标／房内敌人的实际HP、扣气、无自回气、V9播放到底和最终恢复全部通过。
- 720外部移除目标的中断退款及清理通过。普通／OD升龙仍分别造成原2倍／5倍伤害，白拳与原生动作检查保留。

首轮control-cinema-1为163通过、1失败：错误来自将新的第一用例升龙仍按原第一用例波动检查回气10点，实际升龙正确回气20。已改为按招式类型检查并完整重跑；没有为通过测试改回气规则。

首轮还发现启动菜单自动创建了原先不存在的slot1 gamestate。恢复器先保留它，随后结合本次启动日志中明确的“槽1无存档”、新文件创建／写入时间、原有223文件的全部哈希和新文件哈希，仅将该测试文件归档。首次恢复记录原样保留，[补充恢复结果](native/control-cinema-1/reconciliation/result.json)为成功。助手新增了缺失槽＋保存槽＋创建时间的窄范围证据门槛，未将任意新增存档列入清理；第二轮自动恢复成功，未知新增文件为空，main和223文件状态恢复完成。

## 证据边界与保留

两轮均是自有隐藏进程＋游戏回调，没有控制桌面键鼠、焦点或用户游戏进程。隐藏测试窗口没有可用的桌面截图句柄，因此这里的实机证据是实际HP、原生绘制调用、缩放、构图坐标及恢复；不把它标成人工画面观感验收，也未以离线示意图充当游戏截图。

主入口、六份道具／池XML、输入核心、战斗纯数值核心、原始V7／V9、美术和声音源保持。普通360的1.8秒、OD360独立动作、升龙白拳、720获取满三气及唯一版本保留。更新后需完整退出重启游戏加载Lua，单纯换房不更新模块。
