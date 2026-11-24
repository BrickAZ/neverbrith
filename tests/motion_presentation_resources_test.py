"""Approved source selection, texture/crop/audio chain and regenerated data parity."""
from pathlib import Path
import hashlib,json,subprocess,sys,xml.etree.ElementTree as ET
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
sources=json.loads((ROOT/'reports/motion-runtime/2026-10-23/integration-v1/asset-sources.json').read_text(encoding='utf-8'))
assert {s['key']:s['version'] for s in sources}=={'wave':'v7','dp':'v7','circle_360':'v7','circle_720':'v9'}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
approval=json.loads((ROOT/'reports/motion-art/2026-10-23/v9/visual-acceptance.json').read_text(encoding='utf-8'))
assert approval['status']=='APPROVED'
assert sha(ROOT/approval['files'][0]['path'])==approval['files'][0]['sha256']
sounds=ET.parse(ROOT/'content/sounds.xml').getroot()
soundmap={s.get('name'):s for s in sounds.findall('sound')}
counts={'assets':0,'animations':0,'visible_crop_keys':0,'audio_events':0}
for row in sources:
    path=ROOT/row['path'];assert sha(path)==row['sha256']
    if row['key']!='circle_720':assert sha(path)==sha(ROOT/'resources/gfx/Effects/MotionShowcase/v8'/path.name)
    root=ET.parse(path).getroot();assert root.find('Info').get('Fps')=='30'
    manifest=json.loads((ROOT/'reports/motion-art/2026-10-23'/row['version']/'manifest.json').read_text(encoding='utf-8'))
    asset=next(a for a in manifest['assets'] if a['key']==row['key'])
    assert set(asset['variants'])==({'normal'} if row['key']in('wave','circle_720')else{'normal','od'})
    sheets={int(s.get('Id')):path.parent/s.get('Path') for s in root.findall('./Content/Spritesheets/Spritesheet')}
    images={sid:Image.open(p).convert('RGBA') for sid,p in sheets.items()}
    layers={int(l.get('Id')):(l.get('Name'),int(l.get('SpritesheetId'))) for l in root.findall('./Content/Layers/Layer')}
    assert not any(n.startswith('arm_') for n,_ in layers.values())
    for texture in manifest['textures']:assert sha(path.parent/texture['copy'])==texture['sha256']
    for names in asset['variants'].values():
        for name in names:
            animation=root.find(f"./Animations/Animation[@Name='{name}']")
            assert int(animation.get('FrameNum'))==asset['frames']
            for track in animation.findall('./LayerAnimations/LayerAnimation'):
                _,sid=layers[int(track.get('LayerId'))];im=images[sid]
                assert sum(int(f.get('Delay')) for f in track.findall('Frame'))==asset['frames']
                for f in track.findall('Frame'):
                    x,y,w,h=(int(f.get(k)) for k in('XCrop','YCrop','Width','Height'))
                    assert 0<=x<x+w<=im.width and 0<=y<y+h<=im.height
                    if f.get('Visible')=='true':
                        assert im.crop((x,y,x+w,y+h)).getchannel('A').getbbox()
                        counts['visible_crop_keys']+=1
            counts['animations']+=1
    for event in manifest.get('audio',{}).get(row['key'],{}).get('timeline',[]):
        assert not event['key'].endswith('_eng')
        sound=soundmap['Zangief V2 '+event['key']]
        assert all((ROOT/'resources/sfx'/sample.get('path')).is_file() for sample in sound.findall('sample'))
        counts['audio_events']+=1
    counts['assets']+=1
assert counts['animations']==12

# All gameplay copies are FX-only. Players/demo opponents and their sheet refs
# are absent; retained tracks remain identical to the approved offline source.
for row in sources:
    path=ROOT/row['path'];original=ET.parse(path).getroot()
    projected=ET.parse(path.with_name(path.stem+'_runtime.anm2')).getroot()
    old_layers={int(l.get('Id')):l for l in original.findall('./Content/Layers/Layer')}
    new_layers=projected.findall('./Content/Layers/Layer')
    removed={'native_body','native_head','backdrop','ghost','player','bar_top','bar_bottom','flash','shadow'}
    kept=[i for i,l in old_layers.items() if not l.get('Name').startswith(('od_rim_','od_wash_','target_')) and l.get('Name')not in removed]
    mapping={i:n for n,i in enumerate(kept)}
    assert len(new_layers)==len(kept)<=64
    assert all(not l.get('Name').startswith('target_') for l in new_layers)
    assert all(l.get('Name')not in ('native_body','native_head')for l in new_layers),'runtime must not contain a baked player'
    used={int(old_layers[i].get('SpritesheetId')) for i in kept}
    sheet_map={old:n for n,old in enumerate(sorted(used))}
    old_sheets={int(s.get('Id')):s.get('Path') for s in original.findall('./Content/Spritesheets/Spritesheet')}
    new_sheets={int(s.get('Id')):s.get('Path') for s in projected.findall('./Content/Spritesheets/Spritesheet')}
    assert new_sheets=={sheet_map[i]:old_sheets[i] for i in used}
    assert all(not p.startswith('target_') for p in new_sheets.values())
    assert all('isaac_vanilla'not in p.lower()for p in new_sheets.values()),'runtime still references demonstration Isaac art'
    for old,new in zip(kept,new_layers):
        attrs=dict(old_layers[old].attrib);attrs['Id']=str(mapping[old]);attrs['SpritesheetId']=str(sheet_map[int(attrs['SpritesheetId'])]);assert new.attrib==attrs
    for anim in original.findall('./Animations/Animation'):
        native=projected.find(f"./Animations/Animation[@Name='{anim.get('Name')}']")
        assert native.attrib==anim.attrib
        native_tracks=native.find('LayerAnimations');assert len(native_tracks)==len(kept)
        for track in anim.findall('./LayerAnimations/LayerAnimation'):
            old=int(track.get('LayerId'))
            if old not in mapping:continue
            counterpart=native_tracks.find(f"LayerAnimation[@LayerId='{mapping[old]}']")
            attrs=dict(track.attrib);attrs['LayerId']=str(mapping[old]);assert counterpart.attrib==attrs
            assert [f.attrib for f in counterpart]==[f.attrib for f in track]
deleted=json.loads((ROOT/'reports/motion-art/2026-10-23/v7/removed-assets.json').read_text(encoding='utf-8-sig'))
assert len(deleted)==129 and all(not(ROOT/r['path']).exists() for r in deleted)
subprocess.run([sys.executable,str(ROOT/'tools/build-motion-presentation.py'),'--check'],cwd=ROOT,check=True)
runtime=(ROOT/'motion_presentation.lua').read_text(encoding='utf-8')
assert all(token not in runtime for token in (':TakeDamage(',':SaveData(',':SetCanShoot(',':AddCollectible(',':AddCharge('))
print('motion_presentation_resources: PASS '+json.dumps(counts))
print('Four FX-only gameplay copies verified: no player/demo opponents, their textures or cinema shell; retained FX timing/crops/transforms unchanged.')
