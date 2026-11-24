"""Validate the new combat fist's real ANM2 crops and transparency."""
from pathlib import Path
import hashlib,json,xml.etree.ElementTree as E
from PIL import Image
R=Path(__file__).resolve().parents[1]
folder=R/'resources/gfx/Effects/MotionShowcase/additions_v1'
tree=E.parse(folder/'dragon_fist.anm2').getroot()
sheet=tree.find('./Content/Spritesheets/Spritesheet');im=Image.open(folder/sheet.get('Path'))
assert im.mode=='RGBA';alpha=im.getchannel('A');assert alpha.getextrema()==(0,255)
assert all(alpha.getpixel(p)==0 for p in [(0,0),(im.width-1,0),(0,im.height-1),(im.width-1,im.height-1)])
assert hashlib.sha256((folder/sheet.get('Path')).read_bytes()).digest()==hashlib.sha256((R/'reports/motion-items/2026-10-25/fist-spd-shortcut-v1/fist-source.png').read_bytes()).digest()
anim=tree.find('./Animations/Animation');assert anim.get('Name')=='Punch'and anim.get('Loop')=='false'
frames=anim.findall('./LayerAnimations/LayerAnimation/Frame');assert len(frames)==12
for f in frames:
 x,y,w,h=[int(f.get(k))for k in ('XCrop','YCrop','Width','Height')]
 assert 0<=x<x+w<=im.width and 0<=y<y+h<=im.height
 a=alpha.crop((x,y,x+w,y+h));assert a.getbbox()and a.getextrema()[0]==0
 assert 0<=int(f.get('XPivot'))<=w and 0<=int(f.get('YPivot'))<=h
 assert float(f.get('XScale'))==3.8 and float(f.get('YScale'))==3.8
 print(f'Punch frame {len(frames)}: transparent crop and native scale checked')if f is frames[-1]else None
meta=json.loads((R/'reports/motion-items/2026-10-25/fist-spd-shortcut-v1/references/source.json').read_text())
assert meta['frames']==347 and meta['source_media'].endswith('/502.mp4')
print('motion_additions_resources: PASS (12 crops; transparent original PNG; full official SPD reference)')
