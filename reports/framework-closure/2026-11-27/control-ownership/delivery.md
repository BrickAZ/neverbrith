# 控制占用收尾

日期：2026-11-27（Europe/Warsaw）。本子任务完成 CanShoot 实际同合同组的所有者句柄迁移；根代理负责 main 接线、总索引和最终原生运行。未启动游戏、未注入入口、未提交或发布。

## 改动与范围

- 新 `control_ownership` 服务，由正式 main 每安装创建一次，以运行期实体键及明确失效查询区分身体和代次。每件只持有、阻止、释放自己发行的句柄，无全局清锁接口。
- `shooting_scope.ForOwner` 将原 Block/Restore 形状适配到共享服务。神性过载、炸弹套装及拳套实际消费；未传服务的独立旧工厂保留此前合同。
- 正常三层 PRE/POST 注册顺序及原生 setter/read 轨迹保持；各件的规则、RNG、计时、存档和资源不变。
- 具体修复：外层先结束不再解除尚在禁火的其他 owner；拳套失效实体清理不遗留句柄；正式拳套 setter 抛错时先解绑后传播，旧代码该路径在 setter 成功之后才清除 bool。此失败清理差异明确记为修复，不写成逐语句无变化。
- 选择器、搓招攻击门禁/目标租约、拳套冻结、阿瓦达武器重建、复活/睡眠等不同合同保持独立，实际协调关系及保证边界见[API](../../../../docs/api/control-ownership.md)。本服务不声称协调第三方任意 setter 写入。

## 实际检查

命令在 Mod 根执行：`python reports/framework-closure/2026-11-27/control-ownership/run-checks.py`，退出 0。Lua 解释器为 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`。每次完整参数、退出码及日志见 [checks.json](checks.json)。

| 检查 | 结果 |
| --- | --- |
| GodComplex / BombSuit / DriveGlove 冻结旧版原行为 | 3 次退出 0 |
| 同三件当前版本，真实工厂强制消费共享服务 | 3 次退出 0；三组输出与对应基线逐字一致 |
| control_ownership_test | 0；正常 setter/read 逐项对照、原 false、任意顺序、失效/同 key 替换、重复释放、异主句柄、异常与重入 |
| control_release_order_test | 0；实际 God/Bomb state/lifecycle、Drive weapons 在正常/提前取消、true/false 四组合清理正确 |
| control_ownership_consumers_test | 0；真实 main 的同一服务、三个实际 owner、缺模块回滚 |
| shooting_scope_test | 0；旧独立快照合同保持 |
| batch16_loading / batch21_loading | 2 次退出 0；完整安装与失败回滚 |
| 三件未注入新服务的 standalone 原测试 | 3 次退出 0 |

上述 15 次 Lua 命令全部退出 0；另有 3 项旧新输出一致性校验。初次强制共享的拳套专项因旧夹具只支持斜线 include 路径失败；将本次新增私有 include 改为该模块已有的斜线路径风格后通过，没有弱化行为断言。完整项目回归、性能、包验证由根代理负责。

交叉审查另补两项失败反例并修复：①原生 setter 在重入新 owner 后写 true 再抛错；②修复分支的 Exists 查询同步释放最后一个 owner。当前实现一次受保护修复、保留原错，在有效性查询之后重读活跃句柄并核对代次；没有用重试循环掩盖错误。上述 15 次命令在这些修复后重新完整执行，全部 0。正常路径对照包括三层申请及内层重复 PRE：旧新均 3 次 CanShoot 读取、7 次 setter；前六次 false，最后一次精确还原初始 bool。

后续自审增加成功 setter 内释放最后一个 owner 的反例，覆盖普通恢复与错误修复两条路径；补成功/失败 setter 内身体代次更换，以及持续反复改变 owner 的有界失败。现在同一私有写入步骤统一在有效性查询后、setter 后重新计算状态：普通恢复最多原写入加一次校正；异常时最多一轮同样有界的修复并保留原错。反复变化不能在有限次数内稳定时明确报错，不能报告成功。正常无重入轨迹仍完全一致。

## 原生边界与撤回

主代理随后统一执行同一探针：冻结基线 28 通过/2 失败，候选包 30 通过/0 失败，共 4 场景；两项旧版失败精确为提前释放导致的错误解锁与最终错误禁火，其他已通过观测逐条保留。见[原生比较](../control-native-comparison.json)。两侧入口/状态恢复和正常退出均通过。原基线运行器保留 TIMEOUT/退出 2 的原始分类；完整 SUMMARY 与 DONE 在正常关闭后刷出，实际是完整的两项失败诊断，不计为通过。候选运行器退出 0。

本子任务不启动游戏；控制真实 PRE/POST、提前结束和三件叠加的[原生探针](native-probe.lua)与[只读加载观察器](native-observer.lua)已交根代理统一运行，[方法](native-method.md)说明原生动作、预期旧版缺陷和覆盖边界。两份脚本 `loadfile` 解析退出 0，尚不在本子任务中声明原生通过。离线成功不扩大为所有第三方组合、真实多人或人工体验通过。

撤回仅按本轮 baseline 对应文件恢复，并移除 main 的共享实例接线及本次新增模块引用；不可整目录覆盖其他代理修改。无新增存档字段，回退不涉及存档格式迁移。
