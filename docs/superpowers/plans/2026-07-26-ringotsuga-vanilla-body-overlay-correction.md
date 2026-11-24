# RingoTsuga Vanilla Body Overlay Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 RingoTsuga 的 `body0` 从完整矩形小人改成依附原版身体的透明灰白服装覆盖层。

**Architecture:** 保留现有 `256x256` 图集、40 帧映射和 `costume_ringotsuga_hoodie.anm2`。测试先约束服装层不得包含皮肤手脚、不得延伸到脚点、必须收窄和区分方向；生成器随后仅重写 `Draw-HoodieFrame`，并给报告预览增加不进入游戏资产的原版身体代理层。

**Tech Stack:** PowerShell 7、System.Drawing、Isaac ANM2/Null Costume、现有 PowerShell 视觉契约。

## Global Constraints

- 不修改头发、脸部、ANM2、Lua 或 costume 注册。
- 不复制或替换原版 `Character_001_Isaac.png`；仅把其轮廓作为服装覆盖层与报告预览的坐标参考。
- 输出继续使用硬像素、透明 RGBA、32x32 单帧和现有四方向十帧映射。
- 不把静态验证表述为游戏内验证。

---

### Task 1: 用视觉契约复现矩形完整身体缺陷

**Files:**
- Modify: `tests/ringotsuga_accessory_atlas_visual_test.ps1`
- Test: `tests/ringotsuga_accessory_atlas_visual_test.ps1`

**Interfaces:**
- Consumes: `costume_ringotsuga_hoodie.png` 的 40 个 `32x32` 必需帧。
- Produces: 对透明衣服层、像素边界、弧形下摆和四向差异的回归契约。

- [ ] **Step 1: 写入失败断言**

把旧的“至少 200 个肤色手臂像素”改为以下约束：

```powershell
if ($skinArms -ne 0) {
    throw "shirt overlay must not paint skin, got $skinArms pixels"
}

foreach ($cell in $atlasSpecs[2].RequiredCells) {
    $origin = Get-CellOrigin -Spec $atlasSpecs[2] -Cell $cell
    $visible = 0
    $pixelsAtOrBelowFeet = 0
    for ($y = 0; $y -lt 32; $y++) {
        for ($x = 0; $x -lt 32; $x++) {
            if ($hoodie.GetPixel($origin.X + $x, $origin.Y + $y).A -eq 0) { continue }
            $visible++
            if ($y -ge 25) { $pixelsAtOrBelowFeet++ }
        }
    }
    if ($visible -lt 70 -or $visible -gt 145) {
        throw "shirt overlay cell $cell has non-native coverage: $visible"
    }
    if ($pixelsAtOrBelowFeet -ne 0) {
        throw "shirt overlay cell $cell paints feet or a platform: $pixelsAtOrBelowFeet"
    }
}
```

同时检查每帧绿色下摆位于两行且底行比上行窄，并检查正面首帧与右侧首帧的 alpha mask 不相同。

- [ ] **Step 2: 运行测试并确认 RED**

Run:

```powershell
pwsh -NoProfile -File tests\ringotsuga_accessory_atlas_visual_test.ps1
```

Expected: FAIL，首先报告旧图集仍含肤色像素、脚点像素或单帧覆盖超过 145。

### Task 2: 把 `body0` 重画为原版身体上的服装层

**Files:**
- Modify: `tools/generate-ringotsuga-accessory-atlases.ps1`
- Modify: `resources/gfx/characters/costumes/costume_ringotsuga_hoodie.png`
- Modify: `reports/ringotsuga_accessory_atlases_preview.png`
- Test: `tests/ringotsuga_accessory_atlas_visual_test.ps1`

**Interfaces:**
- Consumes: `Draw-HoodieFrame(Bitmap, Cell, View, Phase)` 的既有调用和四方向 cell 映射。
- Produces: 无皮肤手脚的 40 帧透明服装层，以及包含原版身体代理层的报告预览。

- [ ] **Step 1: 写最小服装轮廓**

在 `Draw-HoodieFrame` 中移除所有 `$palette.Skin`、手臂矩形和脚部 span。使用以下形状：

```powershell
$frontOutline = @(
    @(14, 12, 19), @(15, 11, 20), @(16, 10, 21),
    @(17, 9, 22), @(18, 9, 22), @(19, 9, 22),
    @(20, 10, 21), @(21, 11, 20), @(22, 12, 19),
    @(23, 13, 18)
)
$rightOutline = @(
    @(14, 13, 18), @(15, 12, 19), @(16, 11, 20),
    @(17, 10, 21), @(18, 10, 21), @(19, 10, 21),
    @(20, 11, 20), @(21, 12, 19), @(22, 13, 18),
    @(23, 14, 17)
)
```

内部灰白填充比轮廓每侧收一像素；绿色下摆覆盖倒数两行且底行再收一像素。正面绘制极简胸前标记，背面仅保留高光，右侧添加一列阴影。

- [ ] **Step 2: 同步十帧原版步态**

使用固定的 phase shift，而不是旧的整体 bob 与脚部动画：

```powershell
$downX = @(0, 0, 1, 0, 0, 0, 0, -1, 0, 0)
$sideX = @(0, -1, -1, 0, 0, -1, -1, 0, 0, 0)
$sideY = @(0, 0, 0, -1, 0, 0, 0, 0, -1, 0)
```

所有坐标变化只作用于服装 span；不得产生 `y >= 25` 的像素。

- [ ] **Step 3: 修正报告预览**

新增 `Draw-VanillaBodyPreview`，只在 `New-CompositeFrame` 的临时 64x64 frame 中先绘制肤色的原版短圆身体代理，再绘制 hoodie。代理层不写入三张交付图集。

- [ ] **Step 4: 生成并确认 GREEN**

Run:

```powershell
pwsh -NoProfile -File tools\generate-ringotsuga-accessory-atlases.ps1
pwsh -NoProfile -File tests\ringotsuga_accessory_atlas_visual_test.ps1
pwsh -NoProfile -File tests\ringotsuga_accessory_anm2_visual_test.ps1
```

Expected: 三条命令 exit 0；图集契约和 ANM2 集成契约通过。

### Task 3: 回归与原尺寸审查

**Files:**
- Verify: `resources/gfx/characters/costumes/costume_ringotsuga_hoodie.png`
- Verify: `reports/ringotsuga_accessory_atlases_preview.png`

**Interfaces:**
- Consumes: 重生成的图集与现有 Ringo costume 路由。
- Produces: 静态验证结果和明确的实机验证边界。

- [ ] **Step 1: 运行相关回归**

```powershell
pwsh -NoProfile -File tests\tokarev_face_visual_test.ps1
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests\everchanging_behavior_test.lua
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests\everchanging_full_anm2_contract_test.lua
pwsh -NoProfile -File docs\skills\isaac-neverbrith-validator-profile\scripts\validate-neverbrith.ps1 -Root .
```

Expected: 测试 exit 0；验证器 0 failures，允许保留项目既有 `players.xml` 三条原版素材路径警告。

- [ ] **Step 2: 原尺寸审查**

在 3x 和 1x 合成预览中确认：身体由原版圆短轮廓提供；服装没有方形手臂、脚或平台横线；正面、右侧、背面、左侧轮廓可区分。

- [ ] **Step 3: 检查修改范围**

```powershell
git diff --check
git status --short -- tools/generate-ringotsuga-accessory-atlases.ps1 tests/ringotsuga_accessory_atlas_visual_test.ps1 resources/gfx/characters/costumes/costume_ringotsuga_hoodie.png reports/ringotsuga_accessory_atlases_preview.png
```

Expected: 无 diff error；只有本计划涉及的生成器、测试、上衣 PNG、预览和设计文档发生变化。
