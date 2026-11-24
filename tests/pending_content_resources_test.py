from pathlib import Path
from PIL import Image, ImageChops
import xml.etree.ElementTree as ET

root=Path(__file__).resolve().parents[1]
for suffix in ('','.en_us','.zh_cn'):
    items=ET.parse(root/f'content/items{suffix}.xml').getroot()
    by_id={int(e.get('id')):e for e in items if e.tag in ('active','passive','familiar')}
    assert 61 in by_id and 62 in by_id, 'missing two new collectible registrations'
    assert by_id[61].tag=='active' and by_id[61].get('quality')=='4' and by_id[61].get('maxcharges')=='3'
    assert set(by_id[61].get('tags').split())=={'offensive','nocantrip'}
    assert by_id[62].tag=='familiar' and by_id[62].get('quality')=='3'
    assert set(by_id[62].get('tags').split())=={'baby','offensive','lazarussharedglobal'}
    low=[e for e in items if e.tag=='trinket' and e.get('id')=='2']
    assert len(low)==1 and low[0].get('cache')=='damage firedelay range'
    pools=ET.parse(root/f'content/itempools{suffix}.xml').getroot()
    entries=[(p.get('Name'),e.get('Weight')) for p in pools for e in p if e.get('Name')==by_id[61].get('name')]
    assert entries==[('devil','1')],entries
    entries=[(p.get('Name'),e.get('Weight')) for p in pools for e in p if e.get('Name')==by_id[62].get('name')]
    assert entries==[('secret','0.5')],entries
for folder,name in [('Collectibles','divine_left_hand'),('Collectibles','echo_baby'),('Trinkets','low_grade')]:
    im=Image.open(root/f'resources/gfx/Items/{folder}/{name}.png')
    assert im.mode=='RGBA' and im.size==(32,32)
    alpha=im.getchannel('A')
    assert alpha.getbbox() and alpha.getextrema()[0]==0
    assert all(alpha.getpixel(p)==0 for p in ((0,0),(31,0),(0,31),(31,31))),name
actor_path=root/'resources/gfx/003.3000_echo_baby.anm2'
actor=ET.parse(actor_path).getroot()
sheet_path=actor_path.parent/actor.find('Content/Spritesheets/Spritesheet').get('Path')
assert sheet_path.is_file(), 'registered animation must resolve its own spritesheet'
template=ET.parse(root/'reports/batch-completion/brother-bobby-native-template.anm2').getroot()
assert ET.tostring(actor.find('Animations'))==ET.tostring(template.find('Animations')), 'native animations must retain geometry/timing'
sheet=Image.open(root/'resources/gfx/Familiars/EchoBaby/echo_baby_sheet.png')
assert sheet.size==(192,32) and sheet.mode=='RGBA'
for i in range(6):
    crop=sheet.crop((i*32,0,(i+1)*32,32));assert crop.getchannel('A').getbbox(),i
before=Image.open(root/'reports/batch-completion/source-before/resources__gfx__UI__NeverbirthDeathItems.png').convert('RGBA')
after=Image.open(root/'resources/gfx/UI/NeverbirthDeathItems.png').convert('RGBA')
assert before.size==after.size
changed=set()
for y in range(after.height):
    for x in range(after.width):
        cell=(y//16)*20+x//16
        # Later append-only items have their own resource-contract tests.
        if cell<=62 and before.getpixel((x,y))!=after.getpixel((x,y)):changed.add(cell)
assert changed=={61,62},changed
print('PASS pending metadata / pools / RGBA icons / native animations / six crops / only atlas cells 61,62')
