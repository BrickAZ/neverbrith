"""Original SF6 pixels/layout provenance and zero gameplay/economy drift."""
from pathlib import Path
import hashlib,json,xml.etree.ElementTree as ET
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'reports/motion-sa-hud/2026-10-25/v1'
ASSET=ROOT/'resources/gfx/UI/MotionSA/v1'
assert (ASSET/'sa_gauge.anm2').is_file(),'original SA HUD ANM2 is missing'
tree=ET.parse(ASSET/'sa_gauge.anm2').getroot()
animations={a.get('Name'):a for a in tree.findall('./Animations/Animation')}
for side in ('P1','P2'):
    for name in ('Base','Frame','Fill','Counter','Gain1','Gain2','Gain3','FullEnter','FullLoop','Spend','Marker'):
        assert name+side in animations,name+side
assert animations['FillP1'].get('FrameNum')=='101'
assert animations['CounterP1'].get('FrameNum')=='4'
assert animations['Gain3P1'].get('FrameNum')=='11'
assert animations['FullEnterP1'].get('FrameNum')=='14'
assert animations['FullLoopP1'].get('FrameNum')=='26'
assert animations['SpendP1'].get('FrameNum')=='6'
sheets={s.get('Id'):Image.open(ASSET/s.get('Path')).convert('RGBA')for s in tree.findall('./Content/Spritesheets/Spritesheet')}
layers={l.get('Id'):l.get('SpritesheetId')for l in tree.findall('./Content/Layers/Layer')}
assert len(layers)<64
keys=0
for track in tree.findall('./Animations/Animation/LayerAnimations/LayerAnimation'):
    image=sheets[layers[track.get('LayerId')]]
    for f in track:
        x,y,w,h=(int(f.get(k))for k in ('XCrop','YCrop','Width','Height'))
        assert min(x,y)>=0 and min(w,h)>0 and x+w<=image.width and y+h<=image.height
        keys+=1
ledger=json.loads((REPORT/'provenance.json').read_text(encoding='utf-8'))
assert ledger['source']=='local Street Fighter 6 original pak'
assert ledger['gui_version']==530035 and ledger['clip_version']==53
assert ledger['original_fps']==60 and ledger['isaac_logic_fps']==30
for r in ledger['files']:
    p=ROOT/r['path'];assert hashlib.sha256(p.read_bytes()).hexdigest()==r['sha256']
# Input/presentation received the separately approved 2026-10-25 grab/OD/body
# repair and user-approved slower 360. Keep all other values byte invariants.
core=(ROOT/'motion_combat_core.lua').read_text(encoding='utf-8')
core=core.replace('duration=54,sourceFrames=108,reach=16,grab=6,slam=42,release=44', 'duration=36,sourceFrames=108,reach=16,grab=6,slam=24,release=26')
core=core.replace('normal={{0,5,0,17},{6,39,18,65},{40,42,66,73},{43,43,78,78},{44,53,79,107}},od={{0,5,0,17},{6,29,18,65},{30,34,66,73},{35,35,78,78},{36,47,79,107}}',
                  'normal={{0,5,0,17},{6,21,18,65},{22,25,66,78},{26,35,79,107}},od={{0,5,0,17},{6,29,18,65},{30,35,66,78},{36,47,79,107}}')
assert core==(REPORT/'before/motion_combat_core.lua').read_text(encoding='utf-8'),'combat drift beyond approved 360 timing'
for relative in ('main.lua',
                 'content/items.xml','content/items.en_us.xml','content/items.zh_cn.xml',
                 'content/itempools.xml','content/itempools.en_us.xml','content/itempools.zh_cn.xml'):
    assert (ROOT/relative).read_bytes()==(REPORT/'before'/relative).read_bytes(),relative+' changed'
assert "'[#]'"not in (ROOT/'motion_combat.lua').read_text(encoding='utf-8'),'temporary SA characters remain'
hud = (ROOT/'motion_sa_hud.lua').read_text(encoding='utf-8')
assert all(token not in hud for token in (':TakeDamage(',':SaveData(',':AddCollectible(',':AddCharge(','C.Gain(')),'HUD must remain read-only'
print(f'motion_sa_hud_resources: PASS ({len(animations)} animations, {keys} crop keys; original sources and gameplay/economy preserved)')
