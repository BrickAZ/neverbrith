# 框架约束与本地包验证

本页补充[检查入口](testing.md)。自动化分别证明静态加载约束、模拟行为和本地产物完整性，不把它们写成原生或人工验收。

## 架构约束

运行 `python tools/architecture_check.py --report reports/<任务>/architecture.json`，并用 `python tests/architecture_check_test.py` 检查反例。Python 需要可用的标准库；项目既有 Lua 和 PowerShell 检查继续按 testing.md 执行。

检查器从真实 main.lua 追踪静态字面量 include/require，验证路径存在与大小写、runtime 不反向加载玩法、直接 TestAPI 成员读取、主入口不再传无限制的 persistence.GetRoot、停用角色登记以及临时原生探针残留。遇到动态加载或不支持的字面量时报告覆盖不完整并退出 1，不将漏扫当成通过。XML 格式正确性由既有通用和严格验证器负责，这个检查只识别 players.xml 的原生 player 登记。

唯一显式兼容例外是 big_dog_bark 返回自身旧 TestAPI 视图；主入口丢弃返回值，它不是正式业务消费者依赖。其他模块直接读取 TestAPI 仍失败。别名调用、跨变量的数据流和条件实际执行不由此词法检查证明；完整入口安装、回滚、分区接线及注册顺序对照负责对应的动态证据。

## 本地候选包

运行 `python tools/package_mod.py --output reports/<任务>/package-01`。输出目录必须尚不存在，工具不会覆盖旧候选。生成 neverbrith.zip、SHA256 文件清单和从实际 ZIP 展开的 extracted 目录。ZIP 按固定顺序和固定时间戳生成；每个展开文件逐个核对哈希，然后重新运行架构检查。

打包范围为根目录 Lua、scripts、generated、content、resources* 及实际存在的元数据/许可/用户说明；不含 reports、测试、开发工具、工作树和 Git 文件。保留停用角色的惰性源码/资源，不为打包重新启用它们。必要字面量模块未包含、指向工作区外的链接或覆盖不完整时停止。运行 `python tests/package_mod_test.py` 验证漏模块会阻止打包、测试/报告不混入运行包，以及旧输出不会被覆盖。

后续必须将真实入口夹具指向 extracted，而非源码目录，并对 extracted 运行通用/严格资源检查，必要时显式传入实际游戏资源目录。严格检查使用 `-RegistryGenerator tools/generate-neverbirth-collectibles.ps1` 明确指定开发检查器；它的 `-Root` 仍指向包，只比较包内 XML 与生成登记，不从源码目录补运行文件。测试支持代码可以来自仓库，所有生产 Lua 与资源必须来自包。真实引擎加载、性能和人工体验另记实际对象及证据。本地包创建不代表提交、推送或创意工坊发布。

## 最终记录

记录每条实际命令、退出码、源码/包标识、基线差异与未覆盖场景。玩法、内容登记、资源和存档格式保持原决定；控制取消/异常清理若修复原有冲突，须单独列明触发条件与新旧结果，不能混入“全部行为相同”的结论。
