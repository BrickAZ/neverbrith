# AZ 折翼咳血设计文档：检查记录

日期：2026-10-12（Europe/Warsaw）。

检查对象为[设计文档](../../../docs/superpowers/specs/2026-10-12-azazel-broken-wings-active-item-design.md)、项目知识索引新增入口及旧动画草案的替代说明。

本次仅做文档与原版资源读取核对；没有制作游戏资源、接入 Lua 或运行游戏。执行目录为 `E:\Isaac - Repentance\mods\neverbrith`。

## 1. 项目知识索引导航

实际命令：

```powershell
& 'C:\Program Files (x86)\PowerShell\7\pwsh.exe' -NoProfile -File 'tests/agent_wiki_navigation_test.ps1' -Root 'E:\Isaac - Repentance\mods\neverbrith'
```

退出码：`0`。

实际输出：

```text
Agent navigation passed: 5 wiki pages reachable; 82 local links resolve. Content freshness and source semantics still require review.
```

## 2. 本次四份 Markdown 的链接与文本检查

检查设计文档、知识索引、旧草案替代说明与本检查记录；逐个解析 UTF-8 文本，检查相对链接目标和行尾空白。此为文档检查，不是玩法自动测试。

实际命令：

```powershell
@'
from pathlib import Path
import re

root = Path(r"E:\Isaac - Repentance\mods\neverbrith")
files = [
    root / "docs/superpowers/specs/2026-10-12-azazel-broken-wings-active-item-design.md",
    root / "docs/agent/index.md",
    root / "reports/blood-cough/2026-10-10/animation-design-v1.md",
    root / "reports/blood-cough/2026-10-12/design-document-checks.md",
]
errors = []
link_count = 0
for path in files:
    body = path.read_text(encoding="utf-8")
    for n, line in enumerate(body.splitlines(), 1):
        if line.rstrip() != line:
            errors.append(f"{path.relative_to(root)}:{n}: trailing whitespace")
    for target in re.findall(r"!?\[[^\]]*\]\(([^)]+)\)", body):
        target = target.strip().strip("<>")
        if target.startswith(("http:", "https:", "mailto:", "#", "app:", "codex:")):
            continue
        target = target.split("#", 1)[0]
        if not target:
            continue
        link_count += 1
        if not (path.parent / target).resolve().exists():
            errors.append(f"{path.relative_to(root)}: missing link {target}")
if errors:
    raise SystemExit("\n".join(errors))
print(f"PASS: {len(files)} UTF-8 documents; {link_count} local links resolve; no trailing whitespace.")
'@ | & 'C:\Users\Anton\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -
```

退出码：`0`。

实际输出：

```text
PASS: 4 UTF-8 documents; 28 local links resolve; no trailing whitespace.
```

## 3. 原版资源只读核对

实际命令：

```powershell
@'
from pathlib import Path
import xml.etree.ElementTree as ET
from PIL import Image

base = Path(r"E:\Isaac - Repentance")
players = ET.parse(base / "resources-dlc3/players.xml").getroot()
for node in players:
    if node.get("id") == "7":
        print("Normal Azazel registration:", node.attrib)
costumes = ET.parse(base / "resources-dlc3/costumes2.xml").getroot()
for node in costumes:
    if node.get("id") == "11":
        print("Azazel costume 11:", node.attrib)
paths = [
    "resources/gfx/characters/character_008_azazelhead.anm2",
    "resources/gfx/characters/082_lord of the pit.anm2",
    "resources-dlc3/gfx/characters/n_hemoptysis.anm2",
    "resources/gfx/001.000_player.anm2",
]
for rel in paths:
    tree = ET.parse(base / rel).getroot()
    print(rel)
    if "001.000_player" not in rel:
        print("  Sheets:", [node.attrib for node in tree.findall("./Content/Spritesheets/Spritesheet")])
        print("  Layers:", [node.attrib for node in tree.findall("./Content/Layers/Layer")])
    for animation in tree.findall("./Animations/Animation"):
        name = animation.get("Name", "")
        if name.startswith("Walk") or (name.startswith("Head") and name.endswith("Shoot")) or name == "Death":
            print("  Animation:", animation.attrib)
        if name == "Death":
            ghost_ids = {node.get("Id") for node in tree.findall("./Content/Layers/Layer") if node.get("Name") == "ghost"}
            for layer in animation.findall("./LayerAnimations/LayerAnimation"):
                if layer.get("LayerId") in ghost_ids:
                    cursor = 0
                    for frame in layer.findall("Frame"):
                        if frame.get("Visible") == "true":
                            print("  Ghost first visible timeline index:", cursor)
                            break
                        cursor += int(frame.get("Delay", "1"))
with Image.open(base / "resources/gfx/characters/costumes/costume_082_lord of the pit.png") as image:
    print("Wing PNG:", image.size, image.mode)
'@ | & 'C:\Users\Anton\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -
```

退出码：`0`。

输出确认：普通 AZ 的玩家 ID 为 7，登记 costume 11；该服装指向 `Character_008_AzazelHead.anm2`。AZ 的翅膀图层引用 Lord of the Pit 图集；独立翅膀动画包含四向 12 帧循环。翅膀 PNG 解码为 352×144 RGBA。原版咳血有四向 12 帧 `Head…Shoot`；玩家 `Death` 为 57 帧，灵魂图层首次可见的时间轴索引为 22（从 0 计数）。

以上仅证明这些原版文件存在且结构与记录一致；没有证明假死播放、角色合成、三秒状态恢复、扣心或联机伤害已在游戏中实现。后续实机验收项目保持未执行。

