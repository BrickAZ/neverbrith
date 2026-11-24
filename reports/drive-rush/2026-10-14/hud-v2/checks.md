# HUD v2 制作与检查记录

日期：2026-10-14。检查范围为 `resources/gfx/UI/DriveGauge/v2/` 和本版报告、相关设计文档导航。未编写或接入玩法 Lua，未修改道具注册、启动加载、既有绿冲 v3 动画，也未提交、推送或发布。

## 实际执行命令

以下路径均在本机实际执行，工作目录为 `E:\Isaac - Repentance\mods\neverbrith`。

```powershell
$env:DRIVE_HUD_NODE_MODULES='C:\Users\Anton\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules'
& 'C:\Users\Anton\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe' 'reports/drive-rush/2026-10-14/hud-v2/build_assets.cjs'
```

退出码 0：204 个 60×8 槽体／反馈裁切；4 份 ANM2、2 张 atlas、7 张独立原尺寸 PNG。使用已采用的 v1 原图整理绿色／褐色与标记；新生成源图只用于灰白力竭皮肤。手工固定原尺寸一像素灰框，独立文字加暗色描边。

```powershell
& 'C:\Users\Anton\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'reports/drive-rush/2026-10-14/hud-v2/validate_preview.py'
```

最终退出码 0：`PASS: 26 animations, 211 unique crops, 2254 assertions; native body 60x8; 6f feedback; no gameplay integration.`

- 所有 PNG 引用按实际大小写解析；所有裁切在边界内，所有可见裁切有有效 Alpha。
- 60×8 为实际裁切尺寸；100% 原始缩放；根位置与旋转为零。
- 每条轨道的 Delay 总和与 FrameNum 一致；动画名称唯一、默认动画存在。
- `Spend`／`Gain`／`Refill` 均为不循环 6f；透明遮罩最后一帧 Alpha=0。
- 回满最后一帧与满绿槽逐字节一致；扣费末帧与扣除后的 2.5 格褐色槽一致；红色残留不越过损失区间。
- 力竭 0～60 的所有进度帧均为低饱和灰白色，包括恢复超过 3 格的帧。
- 填充查表每条 61 帧，不自动循环；动画没有触发事件。
- v1 已采用原图 SHA-256 未变。
- 两份 GIF 均重新解码检查了动画有效性和总时长。

```powershell
$manifestTool='C:\Users\Anton\.codex\skills\isaac-anm2-visuals\scripts\build-anm2-crop-manifest.ps1'
Get-ChildItem -LiteralPath 'resources/gfx/UI/DriveGauge/v2' -Filter '*.anm2' | ForEach-Object {
    $manifest = & $manifestTool -Path $_.FullName -Json
    if (-not $?) { throw 'Crop manifest failed' }
    $manifest | Set-Content -LiteralPath ('reports/drive-rush/2026-10-14/hud-v2/crop_manifest_' + $_.BaseName + '.json') -Encoding utf8
    Write-Output ('Manifest OK: ' + $_.Name)
}
```

退出码 0：4 份 ANM2 均生成独立裁切清单。

```powershell
pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1
```

退出码 0：`Agent navigation passed: 5 wiki pages reachable; 85 local links resolve.` 这是导航完整性检查，不代表设计语义或游戏逻辑已经实现。

## 视觉复核

对保存后的 ANM2 进行了离线重渲染；检查六状态原尺寸／6倍图、扣费／回满／力竭关键帧，以及全部独立裁切的棋盘、纯白、房间底色对照。修整了降采样后力竭框边缘与浅背景中文字对比度；绿色／褐色保留六格与半格刻度，力竭灰白条无普通分隔线。

`EMPTY` 为18f视觉提示；演示恢复段被压缩以便浏览。普通恢复与20秒自然解除力竭没有在资源中实现，更没有用演示长度替换玩法规则。

## 证据边界

本次完成本地资源整理、ANM2 静态检查与离线预览。尚未加载到以撒游戏，也没有引擎动画验收、多人生命 HUD 布局、事件触发、暂停／隐藏、离身冻结或读档行为的实机证据。用户对本版原尺寸资源及动画的视觉验收仍待后续反馈。

后续确认：2026-10-14用户明确“可以，就用这版HUD”，本版原尺寸与反馈动画已获采用；上段记录的是制作交付时的状态，游戏内接入与验收仍未完成。

## 采纳状态与剩余清单维护检查（2026-10-14）

本次仅更新设计与README等文档：记录HUD采用，整理第16节未定表现、正式内容字段、资源缺口与技术验证项。

- 实际执行 `pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1`，退出码0：5个知识页可达、85个本地链接有效。
- 用 `Get-FileHash -Algorithm SHA256` 对照 `resource_checks.json` 的PNG／ANM2条目，退出码0：`HUD binary resources unchanged: 13 PNG/ANM2 files`。
- 资源目录README补记了用户采用状态；旧检查JSON中的README哈希属于制作检查当时的文档版本。13个PNG／ANM2本体均与已采用版本一致，没有重做或改动HUD图像与动画。
