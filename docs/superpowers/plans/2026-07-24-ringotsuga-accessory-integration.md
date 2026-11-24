# RingoTsuga 三配饰游戏接入实施计划

> **执行方式：** 当前任务内直接实施；先测试、再改实现、最后做静态验证。

**目标：** 将已经生成的 RingoTsuga 苹果外壳、脸部和连帽衫图集接入《千变万化》，由三个独立 Null Costume 共同组成完整包裹观感，不再替换玩家整套 ANM2，也不再压制其他道具外观。

**保留边界：**

- 保留 `full` 样式槽位、玩家 ANM2 加载/恢复与漂移修复等通用完整样式框架，供未来其他完整样式使用。
- 仅移除旧 Ringo 整皮所需的“扫描、移除、延迟重复移除、离开后恢复其他道具外观”逻辑及其运行时字段。
- 旧 Ringo 整皮文件留在资源目录中作为历史资产，但不再由《千变万化》注册或加载。

## 任务 1：锁定三配饰行为

- 更新 `tests/everchanging_behavior_test.lua`：
  - Ringo 样式声明 `head + face + body`，`full = false`。
  - 三个资源分别解析为 Costume ID `17498`、`17499`、`17500`。
  - 获得 Ringo 时按顺序添加三个 Null Costume，不加载玩家 ANM2。
  - 拿到其他道具后不调用 `RemoveCostume` 或 `TryRemoveCollectibleCostume`。
  - 切换/失去样式时只移除这三个 Null Costume。
- 更新 `tests/everchanging_full_anm2_contract_test.lua`：
  - 断言 Ringo 不再注册完整玩家 ANM2。
  - 仍断言通用 `full` 样式加载框架存在。
- 新增 `tests/ringotsuga_accessory_anm2_visual_test.ps1`：
  - 校验三份 ANM2 的 spritesheet、层名、动画名、裁切尺寸、方向行和 Costume XML 注册。
- 先运行测试，确认因 ANM2/注册/实现尚未接入而失败。

## 任务 2：接入三个 Null Costume

- 新增：
  - `resources/gfx/characters/costume_ringotsuga_apple_shell.anm2`
  - `resources/gfx/characters/costume_ringotsuga_face.anm2`
  - `resources/gfx/characters/costume_ringotsuga_hoodie.anm2`
- 在 `content/costumes2.xml` 追加：
  - `17498` 苹果外壳，`head4`
  - `17499` 脸部，`head2`
  - `17500` 连帽衫，`body0`
- 头部和脸部沿用已验证的四方向 Head 动画契约；连帽衫使用四方向 Walk 动画，每方向十帧、每帧延迟 2。

## 任务 3：切换《千变万化》的 Ringo 样式

- 将 `ringotsuga_apple_storyteller` 改为：
  - `slots = { "head", "face", "body" }`
  - 三个独立 Costume 资源
  - `full = false`
- 删除 Ringo 专属的收藏品外观扫描、抑制、重复抑制、恢复函数和运行时字段。
- 保持通用样式选择、保存、联机玩家独立状态、Null Costume 添加/移除以及完整样式通用框架不变。

## 任务 4：验证

- 运行 Lua 行为测试。
- 运行三配饰 ANM2/PNG/XML 静态合约测试。
- 运行现有香蕉皮、Tokarev 和《千变万化》相关回归测试。
- 解析 XML 并运行可用的 neverbrith/Isaac 验证器。
- 最终明确区分静态验证与需要用户进游戏确认的方向、拾取/移除、道具叠加观感。
