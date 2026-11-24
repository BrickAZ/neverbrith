from pathlib import Path
from PIL import Image
import xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
for suffix in ('','.en_us','.zh_cn'):
    items=ET.parse(root/f'content/items{suffix}.xml').getroot()
    rows=[e for e in items if e.tag=='active' and e.get('id')=='64']
    assert len(rows)==1
    row=rows[0]
    assert row.get('quality')=='3' and row.get('maxcharges')=='0'
    assert row.get('gfx')=='blinky.png' and set(row.get('tags').split())=={'offensive','nocantrip'}
    pools=ET.parse(root/f'content/itempools{suffix}.xml').getroot()
    matches=[(p.get('Name'),e.get('Weight')) for p in pools for e in p if e.get('Name')==row.get('name')]
    assert matches==[('devil','1')],matches
icon=Image.open(root/'resources/gfx/Items/Collectibles/blinky.png')
assert icon.mode=='RGBA' and icon.size==(32,32)
assert icon.getchannel('A').getbbox() and icon.getchannel('A').getextrema()[0]==0
assert all(icon.getpixel(p)[3]==0 for p in ((0,0),(31,0),(0,31),(31,31)))
before=Image.open(root/'reports/blinky/2026-10-03/atlas-before-blinky.png').convert('RGBA')
after=Image.open(root/'resources/gfx/UI/NeverbirthDeathItems.png').convert('RGBA')
assert before.size==after.size==(320,640)
changed=set()
for y in range(after.height):
    for x in range(after.width):
        if before.getpixel((x,y))!=after.getpixel((x,y)):changed.add(y//16*20+x//16)
# Cell 63 belongs to concurrently developed Bomb Suit and is checked separately.
assert 64 in changed and changed<={63,64},changed
actor_path=root/'resources/gfx/Effects/Blinky/object.anm2'
actor=ET.parse(actor_path).getroot()
assert actor.find('Animations').get('DefaultAnimation')=='Idle'
for sheet in actor.findall('Content/Spritesheets/Spritesheet'):
    assert (actor_path.parent/sheet.get('Path')).resolve().is_file()
entities=ET.parse(root/'content/entities2.xml').getroot()
entity=[e for e in entities if e.get('name')=='Blinky Thrown Object']
assert len(entity)==1 and entity[0].get('id')=='1000' and entity[0].get('variant')=='3025'
assert (root/'resources/gfx'/entity[0].get('anm2path')).is_file()
print('PASS Blinky metadata/pool/icon/append-only cell 64/owned effect and resources')
