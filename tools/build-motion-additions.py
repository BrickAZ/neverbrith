"""Package the generated transparent fist verbatim; author its ANM2 contract."""
from pathlib import Path
import hashlib,json,shutil,xml.etree.ElementTree as E
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
report=ROOT/'reports/motion-items/2026-10-25/fist-spd-shortcut-v1'
out=ROOT/'resources/gfx/Effects/MotionShowcase/additions_v1';out.mkdir(parents=True,exist_ok=True)
src=report/'fist-source.png';im=Image.open(src);w,h=im.size
assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
shutil.copyfile(src,out/'dragon_fist.png')
r=E.Element('AnimatedActor');E.SubElement(r,'Info',{'CreatedBy':'neverbrith','Version':'1','Fps':'30'})
c=E.SubElement(r,'Content');ss=E.SubElement(c,'Spritesheets');E.SubElement(ss,'Spritesheet',{'Path':'dragon_fist.png','Id':'0'})
l=E.SubElement(c,'Layers');E.SubElement(l,'Layer',{'Name':'white_fist','Id':'0','SpritesheetId':'0'})
E.SubElement(c,'Nulls');E.SubElement(c,'Events')
an=E.SubElement(r,'Animations',{'DefaultAnimation':'Punch'});a=E.SubElement(an,'Animation',{'Name':'Punch','FrameNum':'12','Loop':'false'})
root=E.SubElement(a,'RootAnimation');E.SubElement(root,'Frame',{'XPosition':'0','YPosition':'0','XScale':'100','YScale':'100','Delay':'12','Visible':'true','RedTint':'255','GreenTint':'255','BlueTint':'255','AlphaTint':'255','RedOffset':'0','GreenOffset':'0','BlueOffset':'0','Rotation':'0','Interpolated':'false'})
la=E.SubElement(a,'LayerAnimations');track=E.SubElement(la,'LayerAnimation',{'LayerId':'0','Visible':'true'})
for i in range(12):
 E.SubElement(track,'Frame',{'XCrop':'0','YCrop':'0','Width':str(w),'Height':str(h),'XPivot':str(w//2),'YPivot':str(round(h*.82)),'XPosition':'0','YPosition':'0','XScale':'3.8','YScale':'3.8','Delay':'1','Visible':'true','RedTint':'255','GreenTint':'255','BlueTint':'255','AlphaTint':'255','RedOffset':'0','GreenOffset':'0','BlueOffset':'0','Rotation':'0','Interpolated':'false'})
E.SubElement(a,'NullAnimations');E.SubElement(a,'Triggers');E.indent(r)
E.ElementTree(r).write(out/'dragon_fist.anm2',encoding='utf-8',xml_declaration=True)
meta={'purpose':'translucent uppercut combat VFX only','texture_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'canvas':[w,h],'alpha_bbox':im.getchannel('A').getbbox(),'animation':'Punch','frames':12,'native_scale_percent':3.8,'preserved_source_bytes':True}
(report/'fist-resource.json').write_text(json.dumps(meta,indent=2),encoding='utf8');print('Fist ANM2 packaged; original PNG bytes preserved',meta['canvas'])
