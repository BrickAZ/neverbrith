"""Convert extracted original SF6 SA assets and GUI keys into an Isaac HUD.
No image generation, gameplay changes, SF6 writes or desktop automation.
"""
from pathlib import Path
from io import BytesIO
import argparse,hashlib,importlib.util,json,math,struct,xml.etree.ElementTree as ET
from PIL import Image,ImageChops
ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'reports/motion-sa-hud/2026-10-25/v1'
RAW=REPORT/'work/re_chunk_000/natives/stm/product/gui'
OUT=ROOT/'resources/gfx/UI/MotionSA/v1'
spec=importlib.util.spec_from_file_location('sf6_native',REPORT/'read_native.py')
reader=importlib.util.module_from_spec(spec);spec.loader.exec_module(reader)
layout=reader.read_gui(RAW/'es/ui30000/ui30012/ui30012.gui.530035')
rows={r['name']:r for r in layout}
uvs={str(p.relative_to(RAW)).replace('\\','/').lower():reader.read_uv(p)for p in RAW.rglob('*.uvs.7')if 'ui30012'not in str(p)or 'uvs_number' in p.name}
images={};output={};crops=[]
def props(panel,name):return next(c['properties']for c in rows[panel]['children']if c['name']==name)
def values(panel,name):return {k:v['value']for k,v in props(panel,name).items()}
def clip(panel,name):return next(c for c in rows[panel]['clips']if c['name']==name)
def channel(c,node,prop,child=None):
    p=next(p for n in c['nodes']if n['name']==node for p in n['properties']if p['name']==prop)
    return next(k['keys']for k in p['children']if k['name']==child)if child else p['keys']
def sample(keys,t):
    if t<=keys[0]['t']:return keys[0]['value']
    for a,b in zip(keys,keys[1:]):
        if t<b['t']:
            assert a['interpolation']in (1,2),'unimplemented native interpolation'
            return a['value']if a['interpolation']==1 else a['value']+(b['value']-a['value'])*(t-a['t'])/(b['t']-a['t'])
    return keys[-1]['value']
def decode(path):
    name=path.split('/')[-1].lower()
    if name not in images:
        p=next(RAW.rglob(name+'.241101895'));raw=p.read_bytes();w,h=struct.unpack_from('<HH',raw,8)
        dds=p.with_name(p.name.split('.tex.')[0]+'.dds');b=bytearray(dds.read_bytes())
        assert len(b)-148==math.ceil(w/4)*math.ceil(h/4)*16
        struct.pack_into('<II',b,12,h,w) # Correct old REtool's SF6 row-pitch/width confusion.
        i=Image.open(BytesIO(b));i.load();images[name]=i.convert('RGBA')
    return images[name]
def png(path,image):
    b=BytesIO();image.save(b,format='PNG');output[path]=b.getvalue()
def uv(path,seq,pattern):
    table=uvs[path.lower().removeprefix('product/gui/')+'.7'];count,first=table['sequences'][seq]
    assert pattern<count
    p=table['patterns'][first+pattern];image=decode(table['textures'][p['texture']])
    box=tuple(round(v*s)for v,s in zip(p['uv'],(image.width,image.height,image.width,image.height)))
    crop=image.crop(box);f=p['flags']
    transforms={1:Image.Transpose.ROTATE_270,2:Image.Transpose.ROTATE_180,3:Image.Transpose.ROTATE_90,
                4:Image.Transpose.FLIP_LEFT_RIGHT,5:Image.Transpose.TRANSPOSE,6:Image.Transpose.FLIP_TOP_BOTTOM,7:Image.Transpose.TRANSVERSE}
    if f:crop=crop.transpose(transforms[f])
    crops.append({'uv':path,'sequence':seq,'pattern':pattern,'source_box':box,'flags':f})
    return crop
def nine(path,seq,w,h):
    cells=[uv(path,seq,i)for i in range(9)]
    l=min(cells[0].width,w//2);r=min(cells[2].width,w//2);t=min(cells[0].height,h//2);bot=min(cells[6].height,h//2)
    xx=(0,l,w-r,w);yy=(0,t,h-bot,h);result=Image.new('RGBA',(w,h))
    for i,c in enumerate(cells):
        x,y=i%3,i//3;size=(xx[x+1]-xx[x],yy[y+1]-yy[y])
        if min(size)>0:result.alpha_composite(c.resize(size,Image.Resampling.BILINEAR),(xx[x],yy[y]))
    return result
def tint(image,color):
    return Image.merge('RGBA',[c.point(lambda x,v=v:round(x*v/255))for c,v in zip(image.split(),color)])
def canvas(image,x=0,y=0):
    result=Image.new('RGBA',(640,320));result.alpha_composite(image,(round(320+x-image.width/2),round(160+y-image.height/2)));return result
def element_image(p):
    im=uv(p['UVSequence'],p.get('UVSequenceNo',0),p.get('UVPatternNo',0))
    w,h=p['Size'];im=im.resize((round(abs(w)),round(abs(h))),Image.Resampling.BILINEAR)
    if w<0:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    if h<0:im=im.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    cp=p['ControlPoint'];fx=0 if cp.startswith('Left')else 1 if cp.startswith('Right')else .5
    fy=0 if cp.endswith('Top')else 1 if cp.endswith('Bottom')else .5
    x,y=p['Position'][:2];left=min(x-fx*w,x+(1-fx)*w);top=min(y-fy*h,y+(1-fy)*h)
    result=Image.new('RGBA',(640,320));result.alpha_composite(tint(im,p['Color']),(round(320+left),round(160+top)))
    angle=math.degrees(2*math.atan2(p['Rotation'][2],p['Rotation'][3]))
    if abs(angle)>.01:result=result.rotate(-angle,resample=Image.Resampling.BICUBIC,center=(320+x,160+y))
    return result
def lut_gradient(left,right):
    im=Image.new('RGBA',(280,50));im.putdata([tuple(round(a+(b-a)*x/279)for a,b in zip(left,right))+(255,)for _ in range(50)for x in range(280)]);return im
def lua(v):
    if isinstance(v,dict):return '{'+','.join('['+json.dumps(k)+']='+lua(x)for k,x in v.items())+'}'
    if isinstance(v,list):return '{'+','.join(map(lua,v))+'}'
    if isinstance(v,str):return json.dumps(v)
    return str(v).lower()if isinstance(v,bool)else str(v)
def build():
    OUT.mkdir(parents=True,exist_ok=True)
    numbers=decode('tex_spcombo_num_iam.tex');png('sa_numbers.png',numbers)
    frame=Image.new('RGBA',(640,320))
    for c in rows['c_frame']['children']:frame=Image.alpha_composite(frame,element_image(values('c_frame',c['name'])))
    png('sa_frame.png',frame)
    baseMask=nine('Product/GUI/es/lib/part/uv_Vital_Bg.uvs',0,410,120)
    rect=values('c_gauge','e_rect_base');fill=values('c_gauge','e_rect_gauge')
    nativeGauge=clip('c_gauge','GAUGE');left1=[sample(channel(nativeGauge,'e_rect_gauge','ColorLeft',k),100)for k in 'rgb']
    right1=[sample(channel(nativeGauge,'e_rect_gauge','ColorRight',k),100)for k in 'rgb']
    palettes={'P1':(left1,right1,[159,0,63,128],rect['Color']),
              'P2':(fill['ColorLeft'][:3],fill['ColorRight'][:3],[0,21,110,128],[13,21,54,179])}
    base=Image.new('RGBA',(1280,320));gradient=Image.new('RGBA',(280,100))
    for idx,(side,(l,r,bg,inside))in enumerate(palettes.items()):
        im=canvas(tint(baseMask,bg));im=Image.alpha_composite(im,canvas(Image.new('RGBA',(280,50),tuple(inside))))
        base.alpha_composite(im,(idx*640,0));gradient.alpha_composite(lut_gradient(l,r),(0,idx*50))
    png('sa_base.png',base);png('sa_fill.png',gradient)
    glow=nine('Product/GUI/cmn/lib/part/uv_cmn_9grid.uvs',0,455,135);png('sa_loop.png',glow)
    light=nine('Product/GUI/cmn/lib/part/uv_cmn_9grid.uvs',0,284,50);png('sa_light.png',light)
    full=clip('c_gauge','FULL');fullAtlas=Image.new('RGBA',(2560,1280))
    for t in range(14):
        w,h=[round(sample(channel(full,'e_s9g_ef','Size',k),t))for k in ('w','h')]
        fullAtlas.alpha_composite(canvas(nine('Product/GUI/cmn/lib/part/uv_cmn_9grid.uvs',0,w,h)),((t%4)*640,(t//4)*320))
    png('sa_full.png',fullAtlas)
    sheets=['sa_base.png','sa_frame.png','sa_fill.png','sa_numbers.png','sa_numbers.png','sa_full.png','sa_loop.png','sa_light.png','sa_fill.png','sa_numbers.png']
    actor=ET.Element('AnimatedActor');ET.SubElement(actor,'Info',CreatedBy='SF6 native asset converter',Fps='60',Version='104')
    content=ET.SubElement(actor,'Content');ss=ET.SubElement(content,'Spritesheets');ll=ET.SubElement(content,'Layers')
    for i,path in enumerate(sheets):ET.SubElement(ss,'Spritesheet',Id=str(i),Path=path);ET.SubElement(ll,'Layer',Id=str(i),Name=('base','frame','fill','counter','marker','full','loop','light','spent_fill','spent_counter')[i],SpritesheetId=str(i))
    ET.SubElement(content,'Nulls');ET.SubElement(content,'Events');anims=ET.SubElement(actor,'Animations',DefaultAnimation='BaseP1')
    def f(crop,pos=(0,0),pivot=None,scale=(100,100),color=(255,255,255,255),visible=True):
        x,y,w,h=crop;px,py=pivot or(w/2,h/2)
        return dict(XPosition=pos[0],YPosition=pos[1],XPivot=px,YPivot=py,XCrop=x,YCrop=y,Width=w,Height=h,
                    XScale=scale[0],YScale=scale[1],Delay=1,Visible=str(visible).lower(),RedTint=color[0],GreenTint=color[1],BlueTint=color[2],AlphaTint=color[3],
                    RedOffset=0,GreenOffset=0,BlueOffset=0,Rotation=0,Interpolated='false')
    def anim(name,tracks,loop=False):
        count=len(next(iter(tracks.values())));a=ET.SubElement(anims,'Animation',Name=name,FrameNum=str(count),Loop=str(loop).lower())
        root=ET.SubElement(a,'RootAnimation');ET.SubElement(root,'Frame',**{k:str(v)for k,v in f((0,0,1,1)).items()if k not in ('XCrop','YCrop','Width','Height','XPivot','YPivot')})
        root[0].set('Delay',str(count));ls=ET.SubElement(a,'LayerAnimations')
        for layer,frames in tracks.items():
            tr=ET.SubElement(ls,'LayerAnimation',LayerId=str(layer),Visible='true')
            for row in frames:ET.SubElement(tr,'Frame',**{k:str(round(v,6)if isinstance(v,float)else v)for k,v in row.items()})
        ET.SubElement(a,'NullAnimations');ET.SubElement(a,'Triggers')
    fullAlpha=channel(full,'e_s9g_ef','Color','a');nativeLoop=clip('c_gauge','LOOP');fade=channel(clip('c_main','FADE_OUT'),'c_hud','ColorScale','w')
    for idx,side in enumerate(('P1','P2')):
        sign=1 if side=='P1'else -1;row=idx*108
        anim('Base'+side,{0:[f((idx*640,0,640,320))]},True);anim('Frame'+side,{1:[f((0,0,640,320))]},True)
        anim('Fill'+side,{2:[f((0,idx*50,max(1,round(p*2.8)),50),(-140*sign,0),(0,25),(100*sign,100),visible=p>0)for p in range(101)]})
        anim('Counter'+side,{3:[f((level*70,row,70,108),(-156*sign,-9))for level in range(4)]})
        for level in (1,2,3):
            c=clip('c_num_1P','GAUGE_'+str(level)+'_IN')
            anim('Gain'+str(level)+side,{3:[f((level*70,row,70,108),(-156*sign,-12+sample(channel(c,'e_texture_number','Position','y'),t)),scale=(sample(channel(c,'e_texture_number','Size','w'),t)/70*100,sample(channel(c,'e_texture_number','Size','h'),t)/108*100))for t in range(11)]})
        color=(255,34,152)if idx==0 else(57,149,255)
        anim('FullEnter'+side,{5:[f(((t%4)*640,(t//4)*320,640,320),color=color+(round(sample(fullAlpha,t)),))for t in range(14)]})
        color=(224,6,122)if idx==0 else(57,94,255)
        anim('FullLoop'+side,{6:[f((0,0,455,135),color=color+(round(sample(channel(nativeLoop,'e_s9g_glow','Color','a'),t)),))for t in range(26)],
                             7:[f((0,0,284,50),color=(255,212,244,round(sample(channel(nativeLoop,'e_s9g_loopLight','Color','a'),t))))for t in range(26)]},True)
        anim('Spend'+side,{8:[f((0,idx*50,280,50),(-140*sign,0),(0,25),(sign*100,100),color=(255,255,255,round(sample(fade,t)*255)))for t in range(6)],
                          9:[f((210,row,70,108),(-156*sign,-9),color=(255,255,255,round(sample(fade,t)*255)))for t in range(6)]})
        anim('Marker'+side,{4:[f((380+idx*16,0,16,108),((-140+p*2.8)*sign,0),scale=(100,50/108*100))for p in range(101)]})
    ET.indent(actor,space='  ');output['sa_gauge.anm2']=ET.tostring(actor,encoding='utf-8',xml_declaration=True)
    meta={'path':'gfx/UI/MotionSA/v1/sa_gauge.anm2','source_fps':60,'logic_fps':30,'gain_frames':10,'full_frames':13,'loop_frames':25,'spend_frames':5,'scale':.20,'gauge_width':280,'additive_layers':[1,4,5,6,7]}
    output['source.lua']=('-- Generated native SF6 SA HUD timing/layout contract.\nreturn '+lua(meta)+'\n').encode()
    return meta
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args();meta=build()
    for name,data in output.items():
        path=ROOT/'generated/motion_sa_hud.lua'if name=='source.lua'else OUT/name
        if args.check:assert path.read_bytes()==data,'asset stale: '+name
        else:path.write_bytes(data)
    files=[{'path':str(p.relative_to(ROOT)).replace('\\','/'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}for p in sorted(RAW.rglob('*'))if p.is_file()and '.dds'not in p.name]
    ledger={'source':'local Street Fighter 6 original pak','source_pak':'F:/SteamLibrary/steamapps/common/Street Fighter 6/re_chunk_000.pak','gui_version':530035,'clip_version':53,'original_fps':60,'isaac_logic_fps':30,'files':files,'uv_crops':crops,'conversion':'Original RGBA BC7 textures, native UVs, native gradient colors/geometry, native linear/discrete keys; additive layers retained. Isaac owns read-only visual transitions only.','format_reference':'https://github.com/alphazolam/RE-Engine-010-Templates'}
    if not args.check:(REPORT/'provenance.json').write_text(json.dumps(ledger,indent=2),encoding='utf-8')
    print('SA HUD native conversion checked'if args.check else 'Built original SA HUD: '+str(len(output))+' files; '+str(len(files))+' source resources')
