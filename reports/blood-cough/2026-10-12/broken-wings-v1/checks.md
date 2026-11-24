# 折翼资源 v1：本轮检查

执行日期：2026-10-12。执行目录：`E:\Isaac - Repentance\mods\neverbrith`。

## 资源生成、结构与离线预览

实际命令：

```powershell
& 'C:\Users\Anton\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'reports/blood-cough/2026-10-12/broken-wings-v1/build_resources.py'
```

退出码：`0`。

```text
PASS: 8 animations, 350 frame keys, 35 unique in-bounds nonempty crops.
PASS: copied wing PNG SHA-256 matches vanilla: 677c8dd4ecf309249ee457f25f5ae054b912da46c32807dcd0acddae5f65c61c
PASS: four-direction first-frame continuity; all break layers end invisible.
Offline previews generated. Game runtime: NOT_RUN.
PASS: both GIF previews decode; full preview 4.6 seconds, slow break preview 2.4 seconds.
```

## 独立 ANM2 裁切清单

实际命令：

```powershell
& 'C:\Program Files (x86)\PowerShell\7\pwsh.exe' -NoProfile -Command "& 'C:\Users\Anton\.codex\skills\isaac-anm2-visuals\scripts\build-anm2-crop-manifest.ps1' -Path 'resources/gfx/Effects/BrokenAzazelWings/broken_azazel_wings_v1.anm2' -Json | Set-Content -LiteralPath 'reports/blood-cough/2026-10-12/broken-wings-v1/anm2-crop-manifest.json' -Encoding utf8"
```

退出码：`0`。清单写入 `anm2-crop-manifest.json`。该脚本用于独立读取动画、图层、裁切、pivot、位置与可见性，不验证游戏内渲染。最终交付前另核对清单的条目数与图集路径解析。

## 目视检查

已查看四向关键帧、原尺寸与 4× 最近邻预览，以及全部 35 种裁切的棋盘底、白底、房间色底预览。正常翅膀、弯折、分离与结束状态均可辨认；图集外侧透明区没有被替换成不透明底板。

本次未启动 Isaac，实机状态为 `NOT_RUN`。没有把资源检查、GIF 或离线角色合成当作实机效果证明。


## 最终文件核对

实际命令：

```powershell
@'
from pathlib import Path
import json
import re
import xml.etree.ElementTree as ET

root=Path(r"E:\Isaac - Repentance\mods\neverbrith")
out=root/"reports/blood-cough/2026-10-12/broken-wings-v1"
manifest=json.loads((out/"anm2-crop-manifest.json").read_text(encoding="utf-8-sig"))
checks=json.loads((out/"resource-checks.json").read_text(encoding="utf-8"))
actor_path=root/"resources/gfx/Effects/BrokenAzazelWings/broken_azazel_wings_v1.anm2"
actor=ET.parse(actor_path).getroot()
assert len(manifest["crops"])==checks["frame_keys_checked"]==350
assert manifest["defaultAnimation"]=="WalkDown"
for sheet in actor.findall("./Content/Spritesheets/Spritesheet"):
    path=actor_path.parent/sheet.get("Path")
    assert path.is_file()
    assert path.name in [entry.name for entry in path.parent.iterdir()]
link_count=0
for path in [out/"README.md",out/"checks.md",root/"docs/superpowers/specs/2026-10-12-azazel-broken-wings-active-item-design.md"]:
    body=path.read_text(encoding="utf-8")
    assert all(line==line.rstrip() for line in body.splitlines()),path
    for target in re.findall(r"!?\[[^\]]*\]\(([^)]+)\)",body):
        target=target.strip().strip("<>").split("#",1)[0]
        if not target or re.match(r"\w+:",target):
            continue
        assert (path.parent/target).resolve().exists(),(path,target)
        link_count+=1
print(f"PASS: independent manifest has 350 frame keys; all sheet paths resolve with exact filename casing; {link_count} local document links resolve.")
for path in [actor_path,actor_path.with_name("azazel_wings_vanilla.png"),out/"preview_four_directions.gif",out/"preview_break_slow.gif"]:
    print(f"{path.relative_to(root)}: {path.stat().st_size} bytes")
'@ | & 'C:\Users\Anton\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -
```

退出码：`0`。

```text
PASS: independent manifest has 350 frame keys; all sheet paths resolve with exact filename casing; 20 local document links resolve.
resources\gfx\Effects\BrokenAzazelWings\broken_azazel_wings_v1.anm2: 117459 bytes
resources\gfx\Effects\BrokenAzazelWings\azazel_wings_vanilla.png: 7232 bytes
reports\blood-cough\2026-10-12\broken-wings-v1\preview_four_directions.gif: 1011902 bytes
reports\blood-cough\2026-10-12\broken-wings-v1\preview_break_slow.gif: 302259 bytes
```

另外执行以下只读搜索，退出码为 `1`、无匹配输出，表示当前 Lua／登记 XML 没有引用这份新资源：

```powershell
rg -n 'BrokenAzazelWings|broken_azazel_wings_v1' -g '*.lua' -g '*.xml' -g '!worktrees/**' -g '!release/**' .
```

