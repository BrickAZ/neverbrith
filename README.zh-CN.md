# 未生 / neverbrith

[English](README.md) | 简体中文

由 **brick（青春啊砖在he边看月亮）** 制作的《以撒的结合：忏悔》道具 Mod。
围绕伤害、交易房、卡牌、跟班和死亡代价，加入持续扩展中的自定义被动与主动道具。

## 运行要求

- **The Binding of Isaac: Repentance**，以及与游戏版本匹配的 **REPENTOGON**。
- **REPENTOGON 是必需前置。** 当前代码要求 `1.0.12a` 或更新的、可识别的稳定版本；缺失、过旧或无法识别的构建会让 Mod 停止初始化，并显示中英双语提示。`1.0.12a` 是本项目的最低版本门槛。
- **External Item Descriptions（EID）可选。** 安装后可以查看本 Mod 已提供的道具说明；核心道具逻辑不依赖 EID。

REPENTOGON 的安装方式、启动方式和支持的游戏版本请查阅[官方安装指南](https://repentogon.com/install.html)。通过本 Mod 的版本检查，不代表已完成所有游戏版本与第三方 Mod 组合的兼容性验证。

## 从 GitHub 安装

1. 先按照 REPENTOGON 官方指南完成安装，并确认能以加载 REPENTOGON 的方式启动游戏。
2. 在本仓库选择 **Code → Download ZIP**，解压后将项目文件放入当前游戏使用的 `mods/neverbrith/` 目录；也可以在 `mods` 目录下执行下面的克隆命令。
3. 确认 `main.lua` 和 `metadata.xml` 直接位于 `mods/neverbrith/` 内，并保留其他 Lua 模块、`generated/`、`content/` 和 `resources/` 的完整目录结构。
4. 在游戏的 Mod 菜单启用 **neverbrith**，然后重新启动游戏。

```powershell
git clone https://github.com/BrickAZ/neverbrith.git neverbrith
```

更新时退出游戏，并保持只启用一份 neverbrith，避免手动安装版与其他副本同时加载。

## 当前状态

- **自定义角色暂时停用。** 仓库保留角色资源与开发文件，但当前版本没有注册可选自定义角色。
- 项目仍在开发和回归验证中；部分内容保留实验状态，例如 `ds4` 的效果尚未实现。

## 语言与道具说明

项目维护简体中文与英文的道具 XML 模板、EID 说明和部分运行时提示。部分新道具目前只提供中文文本，例如健康睡眠；不能据此认为所有内容均已完整翻译。

**原生拾取横幅本地化目前暂停开发。** 仓库中的语言模板与脚本保留作维护工具，不是游玩所必需的启动步骤，也不提供游戏内即时语言切换。

如需手动同步静态道具名称与道具池语言，请先关闭游戏，在 Mod 根目录执行以下命令之一：

```powershell
# 简体中文：只同步文件，不启动游戏
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start-neverbrith.ps1 -Language zh_cn -NoLaunch

# 英文：只同步文件，不启动游戏
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start-neverbrith.ps1 -Language en_us -NoLaunch
```

这会用对应语言模板覆盖 `content/items.xml` 和 `content/itempools.xml`。完成后，仍按你的 REPENTOGON 安装方式启动游戏；修改后的 XML 需要重新启动游戏才会加载。EID 的显示语言由 EID 自身的语言设置决定。

## 为其他 Mod 作者提供的兼容接口

公开接口目前仅覆盖**鸿运齐天蛊的幸运阈值登记**和**骰子套装的自定义骰子主动道具登记**。记忆紊乱没有公开兼容 API。这些接口仍是临时、未版本化的约定，接入前请阅读[简体中文兼容指南](COMPATIBILITY.zh-CN.md)。

## 开发与检查

| 路径 | 用途 |
| --- | --- |
| `main.lua` 与根目录 Lua 模块 | 启动、道具逻辑和兼容接入 |
| `generated/` | 生成的道具登记数据 |
| `content/` | 道具、道具池、实体及其他 XML 登记 |
| `resources/` | 图像、动画和音频 |
| `tests/` | 行为、资源和文档回归检查 |
| `tools/` | 语言同步、资源生成和维护脚本 |

开发检查使用 Lua 5.4 与 PowerShell 7（pwsh），以正确读取 UTF-8 中文脚本。当前仍有未通过的回归项，可在 Mod 根目录按需运行以下检查。它们覆盖各自的静态或模拟场景，不代表整套测试通过或游戏内验收完成。

```powershell
luac -p main.lua
lua tests/repentogon_bootstrap_test.lua
lua tests/localization_test.lua
pwsh -NoProfile -File tests/compatibility_docs_test.ps1
```

## 作者与反馈

- **brick（青春啊砖在he边看月亮）**
- [YouTube: Brickzhou](https://www.youtube.com/@Brickzhou)
- Bilibili：搜索 `青春啊砖在he边看月亮`
- [GitHub 问题反馈](https://github.com/BrickAZ/neverbrith/issues)

反馈问题时，请附上游戏版本、REPENTOGON 版本、涉及的道具、复现步骤，以及使用的其他 Mod。
