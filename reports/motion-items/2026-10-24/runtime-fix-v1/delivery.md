# 四件招式不显示与退出崩溃修复

范围：波动、升龙、360、720正式持有后的演出触发／实际绘制，以及游戏退出清理。720继续采用V9，其他已确认动作不改；不接伤害、气量或道具池。

## 根因与修复

1. `Sprite:HasAnimation()`不是当前安装的原生Sprite接口。四招进入`playerArt`时都会失败，返回resource。改用当前REPENTOGON实际提供的`GetAnimationData()`检查动画；服装检测与原生资源探针同步修正。测试对象不再提供虚构接口，先复现失败再修复。
2. 房间实体渲染和屏幕后绘制不在同一RenderMode。原生`MC_POST_RENDER`时模式为`RENDER_NULL=0`，原代码只允许`RENDER_NORMAL=1`和`RENDER_WATER_ABOVE=3`，导致状态推进却没有画面。屏幕后绘制明确接受NULL，玩家／NPC隐藏仍只在正常实体绘制阶段生效，反射等排除；测试改用真实枚举及阶段切换。
3. V9原始ANM2包含68层，原生上限64层。真正开始绘制后，游戏报告invalid layer id 64–67及too many animation layers，随后在RenderLayer崩溃。原V9文件不修改，由生成器产生`circle_720_runtime.anm2`：只移除Lua播放器已经单独处理的18个金光rim/wash重复层，保留其余50层并重映射原层号。全部动作、镜头、贴图、裁切、颜色、时序及394帧保持；运行时加载副本，效果绘制使用映射并检查0–63边界。
4. 卸载绑定时重新枚举Game玩家；该回调可能在原生Game销毁后发生，用户日志有GetNumPlayers→UnregisterOwner→Shutdown崩溃堆栈。攻击限制本来就实时查询绑定所有权，移除绑定已足够，删除了不必要的Game枚举。新增游戏对象不可用时卸载的回归测试。

播放器的`GetState().renderedFrame`只在实际绘制调用成功后更新，后台验收据此计数。仅看到播放状态不再算绘制通过。

## 原生验收

以当前安装的Isaac／`1.0.12a-yin-api1-dev`实际游戏进程运行。探针从正式道具持有、选中主动栏和共享输入进入播放器，不使用`nbmotion arm`。固定指令供给Lua原始输入读取边界，使用真实玩家、Sprite、RenderLayer及回调；没有桌面鼠标／键盘事件或窗口激活。

| 正式道具 | 来源 | 实际绘制终帧 | 绘制回调数 | 结果 |
| --- | --- | ---: | ---: | --- |
| 波动 | 已确认V7 | 65 / 65 | 132 | 通过 |
| 升龙 | 已确认V7普通版 | 77 / 77 | 156 | 通过 |
| 360 | 已确认V7普通版 | 107 / 107 | 216 | 通过 |
| 720 | V9兼容副本，394帧 | 393 / 393 | 788 | 通过，包含特写 |

本轮四招共33项引擎断言通过，每件只执行一次、朝向锁定为right；原生日志确认POST_RENDER实际模式为0，最后正常关闭、退出码0，无图层断言或Lua异常。记录见[native-v9-compatible原始结果](native-v9-compatible/result.json)与[日志](native-v9-compatible/game-log.txt)。

中途退出另用V9第50帧测试：探针保持演出状态直到关闭，退出前记录当前帧及实际已绘制帧，验证原生清理。最终汇总见[native-verification.json](native-verification.json)、[中途退出原始结果](exit-native-v9-compatible/result.json)和[日志](exit-native-v9-compatible/game-log.txt)。

部分尝试的在线日志监听超时，因为引擎输出到退出时才完整可见；保留原始TIMEOUT／pollingTimedOut记录，不改写。最终结论核对关闭后的本次token、SUMMARY、实际绘制终帧、无错误、正常关闭标记及进程退出码。初期只检查播放状态的通过记录不作为实际绘制证据；`final-four-render`明确捕获过0次绘制，`corrected-render-four`捕获过V9越界崩溃，这些失败也保留。

这不是人工观感／真实键盘手感验收。未验证所有人物服装、合作、宽屏观感、实际可听音量或逐类替代武器手感；上述不由后台脚本或模拟测试推定。

## 自动检查

- `lua tests/motion_input_behavior_test.lua`：62条断言，退出码0。
- `lua tests/motion_presentation_test.lua`：3476条断言，退出码0；Sprite不提供HasAnimation、使用真实RenderMode并限制RenderLayer为0–63。
- `tests/motion_presentation_resources_test.py`：确认原4份资产、12动画、14900可见裁切记录和15个日语事件链；V9副本50层的所有保留轨道、贴图及394帧时序与原版一致。
- `tests/motion_items_resources_test.py`：原65注册、三份池、798其他图集格、纯输入核心与攻击限制模块保持。适配器允许本次卸载修复，不再要求其与历史基线字节不变。
- 最终`pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/motion-items/2026-10-24/runtime-fix-v1/final-checks.json`退出码0：84项通过、0失败、0阻塞，保留6条既有通用资源警告。命令与每项输出见[final-checks.json](final-checks.json)。该报告的InGameVerified=false只表示统一运行器不做实机；本次39项后台原生检查独立见[native-verification.json](native-verification.json)。

## 状态保护与安装

测试前保存原文件，临时修改仅包括独立探针加载、跳过片头、允许后台更新。每次结束恢复已有存档、配置与main，并核对哈希。首次后台测试前已有的222份状态文件最终核对一致，用户原第1档和mod状态保留。测试产生、此前不存在的第3档两个活动存档，只在核对最初快照缺失、当前哈希仍属于测试快照后按两个明确文件名归档；不递归移动新文件。归档保留可恢复副本和proof.json。

早先自动审批拒绝过“移动所有测试期间新增文件”的宽泛清理方案，该方案没有执行。后续改为仅备份恢复；最终对两份已证明为测试生成的文件使用受限白名单归档，另有校验依据。没有删除用户新文件。

最终`main.lua`不含临时探针加载，测试进程已关闭。修复和V9运行时副本位于当前安装的mod目录，完整重启游戏后加载。无提交、推送、DLL更换或发布。

普通游玩仍是本轮已批准的“正式道具→演出”阶段；没有真实伤害、抓取或气量结算，品质、标签和道具池继续不填。
