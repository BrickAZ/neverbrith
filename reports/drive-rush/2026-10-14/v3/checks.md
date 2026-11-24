# 蓝防转绿冲 v3 检查记录

日期：2026-10-14。工作目录：`E:/Isaac - Repentance/mods/neverbrith`。

## 生成、解析和离线预览

实际命令：

```powershell
& 'C:/Users/Anton/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' 'reports/drive-rush/2026-10-14/v3/build_resources.py'
```

退出码0。43个动画、5,680个图层帧条目、16种唯一裁切通过。四张PNG与原版来源字节相同；组件与演示XML重新解析，帧长及裁切有效。转场5f且此前没有演示位移，移动结束立即停止，旧残影保持出生时位置和姿势。两份GIF重新解码成功。

目视检查发现第一轮循环会重播起冲强绿光，交付前已把Launch 3f一次性姿态与Rush 6f循环分开，并重新生成与检查。

## 独立清单、导航与资源包

实际命令：

```powershell
foreach ($rushFile in @('drive_parry_rush_v3','drive_pose_isaac_v3','drive_afterimage_isaac_v3','drive_parry_rush_demo_v3')) {
  $rushData = & 'C:/Users/Anton/.codex/skills/isaac-anm2-visuals/scripts/build-anm2-crop-manifest.ps1' -Path ('resources/gfx/Effects/DriveRush/v3/' + $rushFile + '.anm2') -Json
  $rushData | Set-Content -LiteralPath ('reports/drive-rush/2026-10-14/v3/' + $rushFile + '-crop-manifest.json') -Encoding utf8
}
```

退出码0。四份独立裁切使用清单分别含860、1,080、320、3,420条记录。

```powershell
pwsh -NoProfile -File 'tests/agent_wiki_navigation_test.ps1'
Compress-Archive -Path 'resources/gfx/Effects/DriveRush/v3/*' -DestinationPath 'reports/drive-rush/2026-10-14/v3/drive-rush-v3-assets.zip' -Force
```

上述命令分别执行，退出码均为0。导航检查5个知识页、84个本地链接通过；资源包含9个文件。随后通过Python标准库zipfile逐字节核对资源包与磁盘文件，检查说明文档本地链接与行末空白，并独立检查Launch不循环、Rush循环期间颜色和透明度固定，退出码0。

## 证据范围

已查看实际关键帧、原尺寸、最近邻4倍、四朝向姿态的三底色合成及全部唯一裁切的三底色对照。PNG像素未重绘，角色压低与前倾由ANM2图层变换实现。

当前是离线原型；没有修改玩法Lua、实体／服装／道具登记，没有进入Isaac验证，也没有使用外部动画编辑器。转向示意曲线不等同实时控制或已确认灵敏度。
