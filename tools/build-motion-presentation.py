"""Extract approved ANM2 transforms, without rewriting approved resources."""
from pathlib import Path
import argparse, copy, hashlib, json, math, xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'generated/motion_presentation.lua'
REPORT=ROOT/'reports/motion-runtime/2026-10-23/integration-v1'

def lua(v):
    if isinstance(v,dict):return '{'+','.join('['+json.dumps(str(k),ensure_ascii=False)+']='+lua(x) for k,x in v.items())+'}'
    if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
    if isinstance(v,str):return json.dumps(v,ensure_ascii=False)
    if v is None:return 'nil'
    if isinstance(v,bool):return str(v).lower()
    return format(v,'.6g') if isinstance(v,float) else str(v)

def extract():
    assets={};sources=[];native_files={}
    native=ET.parse(ROOT.parent.parent/'resources/gfx/001.000_player.anm2').getroot()
    native_body={}
    for face in ('Right','Down','Left','Up'):
        tick=0
        for f in native.findall(f"./Animations/Animation[@Name='Walk{face}']/LayerAnimations/LayerAnimation[@LayerId='1']/Frame"):
            native_body.setdefault((face,tuple(f.get(k) for k in ('XCrop','YCrop','Width','Height'))),tick)
            tick+=int(f.get('Delay'))
    for key in ('wave','dp','circle_360','circle_720'):
        version='v9' if key=='circle_720' else 'v7'
        folder=ROOT/'reports/motion-art/2026-10-23'/version
        manifest=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
        record=next(r for r in manifest['assets'] if r['key']==key)
        anchor=json.loads((folder/'anchors.json').read_text(encoding='utf-8'))[key]
        path=ROOT/record['anm2'];tree=ET.parse(path).getroot()
        layers={int(l.get('Id')):l.get('Name') for l in tree.findall('./Content/Layers/Layer')}
        def is_player(name):return name in ('native_body','native_head')
        def is_target(name):return name.startswith(('target_front_','target_back_'))
        def gold(name):return name.startswith(('od_rim_','od_wash_'))
        def demo_shell(name):return name in ('backdrop','ghost','player','bar_top','bar_bottom','flash','shadow')
        row={'path':str(path.relative_to(ROOT/'resources')).replace('\\','/'),'frames':record['frames'],
             'layers':[[i,n] for i,n in layers.items() if not is_target(n) and not gold(n) and not demo_shell(n)],
             'variants':{},'source_version':version,'gold_offsets':manifest['gold_offsets']}
        if len(layers)>64 or any(gold(n) or is_target(n) for n in layers.values()):
            # The approved files remain offline demonstrations. Gameplay loads
            # FX-only copies, with no baked player/opponent layers or textures.
            # Gold rims/wash are independently drawn from the live player.
            projected=copy.deepcopy(tree)
            kept=[i for i,name in layers.items() if not gold(name) and not is_target(name) and not is_player(name) and not demo_shell(name)]
            mapping={i:n for n,i in enumerate(kept)}
            assert len(mapping)<=64
            content_layers=projected.find('./Content/Layers')
            for layer in list(content_layers):
                old=int(layer.get('Id'))
                if old not in mapping:content_layers.remove(layer)
                else:layer.set('Id',str(mapping[old]))
            used_sheets={int(l.get('SpritesheetId')) for l in content_layers}
            sheets=projected.find('./Content/Spritesheets')
            sheet_map={old:n for n,old in enumerate(sorted(used_sheets))}
            for sheet in list(sheets):
                old=int(sheet.get('Id'))
                if old not in sheet_map:sheets.remove(sheet)
                else:sheet.set('Id',str(sheet_map[old]))
            for layer in content_layers:layer.set('SpritesheetId',str(sheet_map[int(layer.get('SpritesheetId'))]))
            for tracks in projected.findall('./Animations/Animation/LayerAnimations'):
                for track in list(tracks):
                    old=int(track.get('LayerId'))
                    if old not in mapping:tracks.remove(track)
                    else:track.set('LayerId',str(mapping[old]))
            native_path=path.with_name(path.stem+'_runtime.anm2')
            native_files[native_path]=ET.tostring(projected,encoding='utf-8',xml_declaration=True)
            row['native_path']=str(native_path.relative_to(ROOT/'resources')).replace('\\','/')
            row['native_layer_map']=mapping
        for variant,(anim,_) in record['variants'].items():
            animation=tree.find(f"./Animations/Animation[@Name='{anim}']");tracks={}
            for track in animation.findall('./LayerAnimations/LayerAnimation'):
                frames=[]
                for f in track.findall('Frame'):frames.extend([dict(f.attrib)]*int(f.get('Delay')))
                tracks[layers[int(track.get('LayerId'))]]=frames
            timeline=[]
            for t,meta in enumerate(anchor[variant]):
                camera=meta['camera'];z=camera[2]
                def pose(name):
                    f=tracks[name][t]
                    return [float(f[k]) for k in ('XPosition','YPosition','XScale','YScale','Rotation')]
                head=tracks['native_head'][t];xc=int(head['XCrop'])
                face='Up' if xc==128 else 'Down' if xc==0 else 'Left' if float(head['XScale'])<0 else 'Right'
                body=tracks['native_body'][t]
                tick=native_body[(face,tuple(body[k] for k in ('XCrop','YCrop','Width','Height')))]
                visible=[[i,float(tracks[n][t]['XPosition']),float(tracks[n][t]['YPosition'])] for i,n in layers.items()
                         if tracks[n][t]['Visible']=='true' and not is_player(n) and not gold(n) and not is_target(n)]
                target_depth='none'
                for n,frames in tracks.items():
                    if is_target(n) and frames[t]['Visible']=='true':
                        target_depth='front' if n.startswith('target_front_') else 'back'
                target=meta['target'];center=[(target['box'][0]+target['box'][2])/2,target['box'][3]]
                timeline.append({'camera':camera,'body':pose('native_body'),'head':pose('native_head'),'face':face,'body_tick':tick,
                    'visible':visible,'target':[center[0],center[1],target['angle'],target['box'][2]-target['box'][0],target['box'][3]-target['box'][1],*target['origin']],
                    'target_visible':meta.get('target_visible',True),'target_depth':target_depth,'cinema':key=='circle_720' and 21<=t<289,
                    'glow':meta.get('super_glow',meta['od_glow']),'feet':meta['player']['feet']})
            row['variants'][variant]={'animation':anim,'timeline':timeline}
        row['audio']=manifest.get('audio',{}).get(key,{}).get('timeline',[])
        row['start_feet']=anchor['normal'][0]['player']['feet'];assets[key]=row
        sources.append({'key':key,'path':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'version':version})
    lines=['-- Generated from approved XML/anchors; run tools/build-motion-presentation.py.','return {']
    for key,row in assets.items():
        timelines={k:v.pop('timeline') for k,v in row['variants'].items()}
        lines.append('['+lua(key)+']='+lua(row)[:-1]+',')
        for variant,frames in timelines.items():
            # Separate frame lines keep this generated ledger reviewable.
            lines.append('['+lua(variant+'_frames')+']={')
            lines.extend(lua(f)+',' for f in frames);lines.append('},')
        lines.append('},')
    lines.append('}')
    return '\n'.join(lines)+'\n',sources,native_files

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    content,sources,native_files=extract()
    if args.check:
        assert OUT.read_text(encoding='utf-8')==content,'generated presentation data stale'
        assert json.loads((REPORT/'asset-sources.json').read_text(encoding='utf-8'))==sources
        for path,data in native_files.items():assert path.read_bytes()==data,'native projection stale: '+str(path)
        print('Approved source hashes and generated runtime transforms match.')
    else:
        OUT.write_text(content,encoding='utf-8');REPORT.mkdir(parents=True,exist_ok=True)
        (REPORT/'asset-sources.json').write_text(json.dumps(sources,ensure_ascii=False,indent=2),encoding='utf-8')
        for path,data in native_files.items():path.write_bytes(data)
        print('Extracted four approved assets, six variants; original resources unchanged.')
