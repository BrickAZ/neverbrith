# RingoTsuga 双挂饰完全重制设计

## 目标

将 RingoTsuga 外观完全重制为两个可独立叠加的原生挂饰：完整 Ringo 苹果头饰与浅灰白 T 恤。保留原版以撒的脸、皮肤、手脚和道具外观。

## 头饰

- 头饰不是小帽子，而是包住头顶、后脑和左右两侧的完整苹果外壳。
- 正面与侧面的中央脸区必须透明，不绘制肤色、眼睛、泪痕、嘴或其他脸部像素。
- 保留红色苹果外壳、深红阴影、棕色枝梗、绿色叶片和少量浅色额发/侧发，形成 Ringo 识别度。
- 背面可以完整显示苹果后脑；正面和侧面必须让原版以撒脸型清楚可见。
- 采用 `head4`，256×64 RGBA 图集，8 个 32×64 帧，覆盖四方向和两相起伏。

## 白色 T 恤

- 重画为浅灰白短袖 T 恤，不沿用当前 hoodie 轮廓。
- 造型包含短袖肩线、透明领口、收窄腰身和弧形衣摆；不得绘制皮肤、手、脚或平台。
- 主色为浅灰白，使用少量冷灰阴影和高光；只允许一像素低饱和绿色缝线作为 Ringo 色彩锚点。
- 采用 `body0`，256×256 RGBA 图集，40 个 32×32 可见动作帧，覆盖四方向各 10 相位。

## 资源与注册

- 新头饰资源：`costume_ringotsuga_headgear.anm2` 与 `costume_ringotsuga_headgear.png`。
- 新 T 恤资源：`costume_ringotsuga_white_tshirt.anm2` 与 `costume_ringotsuga_white_tshirt.png`。
- 千变万化的 Ringo 样式仅保留 `slots = { "head", "body" }`。
- `content/costumes2.xml` 仅注册上述两个 Ringo 挂饰。
- 删除旧 `apple_shell`、`face`、`hoodie` 和未使用的 `apple_storyteller` 实时资源；保留 `_backups` 目录作为可恢复备份。

## 验收

- 两张 PNG 只含 0 或 255 alpha；透明像素 RGB 全为零，不含纯黑或黑红杂边。
- 头饰正面/侧面的原版脸区保持大面积透明，且图集不含肤色、眼睛或泪痕颜色。
- T 恤每帧均有明确领口、短袖和弧形衣摆，不覆盖脚部。
- 两相帧必须有真实像素差异，左右方向严格镜像。
- 旧 face 槽位、旧资源路径和第三个 Ringo costume 注册不再出现在运行链路。
- 千变万化行为、完整 ANM2 契约和 neverbrith 静态验证保持通过；游戏内动态观感另行验证。
