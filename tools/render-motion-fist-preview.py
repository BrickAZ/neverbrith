"""Render the packaged ANM2 crop at native scale beside the native Isaac sprite.
This is an offline placement/alpha preview, not a game screenshot.
"""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,math,xml.etree.ElementTree as E
R=Path(__file__).resolve().parents[1];folder=R/'resources/gfx/Effects/MotionShowcase/v7'
tree=E.parse(folder/'dp.anm2').getroot();layers={l.get('Name'):l.get('Id')for l in tree.findall('./Content/Layers/Layer')}
manifest=json.loads((R/'reports/motion-art/2026-10-23/v7/manifest.json').read_text(encoding='utf8'))
record=next(a for a in manifest['assets']if a['key']=='dp');name=record['variants']['normal'][0]
anim=tree.find(f'./Animations/Animation[@Name="{name}"]')
skin=Image.open(folder/'isaac_vanilla.png').convert('RGBA');actor=Image.new('RGBA',(192,192));ground=(96,160)
anchors=json.loads((R/'reports/motion-art/2026-10-23/v7/anchors.json').read_text(encoding='utf8'))['dp']
start=anchors['normal'][0]['player']['feet']
for part in ['native_body','native_head']:
 f=anim.find(f'./LayerAnimations/LayerAnimation[@LayerId="{layers[part]}"]/Frame');x,y,w,h=[int(f.get(k))for k in ['XCrop','YCrop','Width','Height']]
 cel=skin.crop((x,y,x+w,y+h));pos=(round(ground[0]+float(f.get('XPosition'))-start[0]-float(f.get('XPivot'))),round(ground[1]+float(f.get('YPosition'))-start[1]-float(f.get('YPivot'))))
 actor.alpha_composite(cel,pos)
fistTree=E.parse(R/'resources/gfx/Effects/MotionShowcase/additions_v1/dragon_fist.anm2').getroot();f=fistTree.find('./Animations/Animation/LayerAnimations/LayerAnimation/Frame')
fist=Image.open(R/'resources/gfx/Effects/MotionShowcase/additions_v1/dragon_fist.png').convert('RGBA')
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18);board=Image.new('RGB',(1152,480),(24,24,29));bd=ImageDraw.Draw(board)
for panel,(variant,t,stage,label)in enumerate([('normal',30,1,'普通升龙'),('od',23,1,'OD 第一段'),('od',45,2,'OD 第二段')]):
 canvas=Image.new('RGBA',(192,192),(64,46,36,255));d=ImageDraw.Draw(canvas)
 for y in range(0,192,16):d.line([(0,y),(192,y)],fill=(80,59,46),width=1)
 height=anchors[variant][t]['player']['feet'][1]-start[1]
 canvas.alpha_composite(actor,(0,round(height)))
 a,b=(18,44)if variant=='normal'else((18,29)if stage==1 else(38,53));u=(t-a)/(b-a)
 scale=.038*(1.1 if stage==2 else 1);angle=math.radians(-12);c,s=math.cos(angle),math.sin(angle)
 px=ground[0]+13+5*u;py=ground[1]+height-12-6*u;xp,yp=float(f.get('XPivot')),float(f.get('YPivot'))
 v=(c/scale,s/scale,xp-(c*px+s*py)/scale,-s/scale,c/scale,yp+(s*px-c*py)/scale)
 rendered=fist.transform((192,192),Image.Transform.AFFINE,v,resample=Image.Resampling.NEAREST)
 alpha=.6*min(1,(u+.15)*4)*min(1,(1-u)*3);rendered.putalpha(rendered.getchannel('A').point(lambda x:round(x*alpha)))
 canvas.alpha_composite(rendered);board.paste(canvas.resize((384,384),Image.Resampling.NEAREST),(panel*384,48));bd.text((panel*384+12,10),label,font=font,fill='white')
bd.text((12,442),'ANM2 原比例定位示意 · 两倍放大 · 非游戏截图',font=font,fill=(210,210,220))
out=R/'reports/motion-items/2026-10-25/fist-spd-shortcut-v1/fist-placement.png';board.save(out);print(out)
# Review the one unique ANM2 crop on three mattes without altering the texture.
checks=Image.new('RGB',(768,280));fd=ImageDraw.Draw(checks)
for i,bg in enumerate([(210,210,210),(255,255,255),(65,45,31)]):
 cell=Image.new('RGBA',(256,256),bg+(255,));mini=fist.resize((256,256),Image.Resampling.NEAREST);cell.alpha_composite(mini);checks.paste(cell,(i*256,24));fd.text((i*256+5,4),['grey','white','room'][i],fill='black')
checks.save(out.with_name('fist-alpha-review.png'))

