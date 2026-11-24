from pathlib import Path
import hashlib,xml.etree.ElementTree as E
from PIL import Image
R=Path(__file__).resolve().parents[1]
p=R/'resources/gfx/Effects/MotionShowcase/cinematic_v1'
source=R.parent.parent/'resources/gfx/ui/stage/bgblack.png'
assert hashlib.sha256((p/'native_bgblack.png').read_bytes()).digest()==hashlib.sha256(source.read_bytes()).digest()
r=E.parse(p/'scene.anm2').getroot();a=r.find('./Animations/Animation');assert a.get('Name')=='Fill'
f=a.find('./LayerAnimations/LayerAnimation/Frame');assert (f.get('Width'),f.get('Height'))==('1','1')
im=Image.open(p/'native_bgblack.png');assert im.getpixel((0,0))[:3]==(0,0,0)
assert len(r.findall('./Content/Layers/Layer'))==1
print('motion_cinematic_resources: PASS (one native opaque fill crop; original pixels; no actor art)')
