# 第 22 批：调试控制器核验收尾

2026-11-27（Europe/Warsaw）。调试控制器现有独立模块已通过本轮结构、行为、生命周期及安装失败核验；本批没有改动生产代码。没有提交、推送或发布。

| 清单字段 | 当前结论 |
| --- | --- |
| 内容 / 入口 | Debug Controller / 本地 ID 17；scripts/features/debug_controller.lua 由 main 实际创建一次 |
| 完整所有权 | 模块私有 states/sprites/actions/layouts、菜单路由、debug 命令、输入边沿、图标表现和 tear 清理；没有专属状态留在 main |
| 正式依赖 | Items.DebugController、IsValidItemId；构造时断言必要依赖，在产生回调副作用之前失败；原生 Input/Isaac/Sprite 查询沿原受保护合同 |
| 状态与生命周期 | 按现有 InitSeed 字符串隔离菜单；无存档字段；失去道具/死亡关闭，换层/新局/Continue 清菜单和 Sprite；退出禁用旧运行实例，重新开局可激活未 disposed 实例；卸载只清自身并不可重新激活 |
| 安装 | 构造不登记回调；main 仅在旧相对位置调用六个 Install 阶段；包括可选退出/卸载共 8 条绑定，回调定义/绑定仍相邻 |
| 公开兼容 | DebugController.IsDirectionPressed 动态查询当前设备，既有具名回调维持；没有将输入、命令或 UI 暴露为跨道具状态容器 |
| 复用结论 | 私有键、死活/持有检查含自己的可选 API、fallback 和异常合同；输入射击方向只驱动菜单，与移动不混用；Sprite 失败/文本回退政策不同。不以普通 API 转发相似为由新增通用库或强改身份键 |
| 旧入口 | 已不存在 main 内的第二份实现；现有模块符合本轮目标，无需再造兼容空壳或拆文件 |
| 状态 | 结构核验与离线验收完成；本批原生/人工 UI 与设备操作未验证 |

## 实际检查

工作目录为 Mod 根；Lua `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`。命令及输出同时纳入[第 19/22 批检查记录](../../refactor-batch19/2026-11-27/checks.json)。

| 命令 | 退出码 / 结果 |
| --- | --- |
| `lua tests/batch22_boundaries_test.lua` | 0；实际模块六阶段/八绑定、玩家隔离、失去道具、死亡、换层、开局/Continue、退出、其他 Mod 卸载、自身重复卸载、重建和缺依赖全部通过 |
| `lua tests/batch22_loading_test.lua` | 0；完整入口唯一安装、缺文件、8 个注册失败点回滚及新实例重建通过 |
| `lua reports/refactor-batch19/2026-11-27/run-behavior.lua baseline tests/debug_controller_behavior_test.lua`，candidate 同命令 | 均 0；旧新命令路由、返回、按键防抖、移动不选菜单、关闭恢复射击和设备编号断言通过 |
| `lua reports/refactor-batch19/2026-11-27/compare-registration.lua` | 0；完整入口 543 条注册顺序/事件/优先级/过滤保持 |
| `python reports/refactor-batch19/2026-11-27/verify-scope.py` | 0；当前 debug_controller.lua 与冻结基线逐字节相同 |

新增测试针对过去普通行为用例未覆盖的退出/卸载和部分安装失败边界。初次完整入口测试漏计绑定源路径及夹具缺事件，已修正测试路径和 MC_POST_FIRE_TEAR；没有改生产行为迁就用例。

没有剩余的本件已确认结构缺陷；真实键盘/手柄、图标可读性及正常游戏中的 debug 命令表现归统一原生/人工验收，不把模拟输入算作实机。无生产变更可回退；只撤回新增两份专项测试和本报告即可撤销本批交付。
