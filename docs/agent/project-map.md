# 项目地图

## 运行源码

| 位置 | 当前职责与阅读方式 |
| --- | --- |
| [main.lua](../../main.lua) | 同时承担启动、共享状态、部分道具实现与模块接入；不能当成只含启动代码的薄入口 |
| 根目录 Lua 模块 | 专题实现，例如 [memory_disorder.lua](../../memory_disorder.lua)；从 `main.lua` 的 `include(...)` 和对应 `*_BEGIN` 标记追踪传入依赖及回调归属 |
| [repentogon_dependency_guard.lua](../../repentogon_dependency_guard.lua) | 前置不满足时的诊断与掉落保护；正常玩法启动从 `main.lua` 开头继续追踪 |
| [generated/neverbirth_collectibles.lua](../../generated/neverbirth_collectibles.lua) | 生成的道具登记数据；来源与只检查命令见下文，不手工改生成结果 |
| [content/](../../content/) | 道具、道具池、实体等注册；存在原生资源入口，不能一概认为只有 XML |
| [resources/](../../resources/) | 图像、动画、音频等资源；每种显示表面分别核对消费者和路径 |
| [tests/](../../tests/)、[tools/](../../tools/) | 模拟行为、资源契约及维护工具；维护工具可能写 XML、图片或工作簿，先读参数与副作用 |

定位道具时先搜索英文标识和中文名，再确认实际所有者。例如：

```powershell
rg -n 'MEMORY_DISORDER_BEGIN|initializeMemoryDisorder|GetCollectibleConfigs' main.lua
rg -n 'GetItemConfig|GetCollectibles' tests/dice_set_behavior_test.lua memory_disorder.lua
```

## 注册、语言与资源关联

- 道具注册通常涉及 [items.xml](../../content/items.xml)、[英文模板](../../content/items.en_us.xml)、[中文模板](../../content/items.zh_cn.xml)。原生 XML 本地 ID、运行时道具 ID 和测试模拟 ID 是不同概念。
- 道具池变更同时核对 [基础道具池](../../content/itempools.xml)、[英文道具池](../../content/itempools.en_us.xml)、[中文道具池](../../content/itempools.zh_cn.xml)；不自行补选未确认的池或权重。
- 文本变更沿当前实现寻找 XML、EID 与运行时提示，并阅读 [localization_test.lua](../../tests/localization_test.lua)。语言模板同步会覆盖基础 XML，不能当作无副作用的检查。
- 生成登记数据使用 [generate-neverbirth-collectibles.ps1](../../tools/generate-neverbirth-collectibles.ps1)。`-Check` 仅验证同步；省略它会写生成文件。
- ESC/My Stuff 与死亡图标遵循[现有迁移说明](../mystuff_item_id_migration.md)；底座、举起图标、EID、暂停页和死亡页需要分别核对，不能相互替代验收。

## 开发材料边界

`docs/skills/` 是仓库中的 Skill 与部分工具副本；已安装 Skill 可能是另一版本。使用本项目检查命令时以[检查入口](../../tools/check-neverbrith.ps1)实际调用的仓库脚本为准，不混用只在另一版本存在的参数。

`reports/`、`diagnostics/`、`outputs/` 保存任务产物；`release/`、`worktrees/`、`.worktrees/` 可包含发布包或独立源码副本。它们不是当前模组 Lua 入口的组成部分。寻找当前实现先限定根目录相关模块、`tests/`、`content/` 和 `resources/`，需要历史证据时再单独阅读这些目录。

本页只界定导航范围，不授权清理、移动或删除这些材料。检查前保留工作区已有变更。运行方式与当前声明的依赖边界见 [README](../../README.zh-CN.md)，验证命令见[检查与证据](testing.md)。
