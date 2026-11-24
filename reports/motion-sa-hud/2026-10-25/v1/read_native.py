"""Read-only SF6 GUIR/UVS facts, using alphaZomega's documented structures.
Reference: https://github.com/alphazolam/RE-Engine-010-Templates
Only extracted task-local files are read; output is an inspection ledger.
"""
from pathlib import Path
import struct,json
ROOT=Path(__file__).resolve().parent
GUI=ROOT/'work/re_chunk_000/natives/stm/product/gui'
def readstr(b,p,wide=False):
    if not p:return ''
    if wide:
        end=p
        while b[end:end+2]!=b'\0\0':end+=2
        return b[p:end].decode('utf-16-le')
    return b[p:b.index(0,p)].decode('utf-8',errors='replace')
def read_gui(path):
    b=path.read_bytes();u64=lambda p:struct.unpack_from('<Q',b,p)[0]
    table=u64(8);count=u64(table+16);assert count<1000
    offsets=struct.unpack_from('<'+'Q'*count,b,table+24)
    rows=[]
    for off in offsets:
        name,cls,subtable,clips=struct.unpack_from('<4Q',b,off+16)
        n=u64(subtable);assert n<1000
        subs=[]
        for so in struct.unpack_from('<'+'Q'*n,b,subtable+8):
            sn,sc,attrs,ae=struct.unpack_from('<4Q',b,so+48)
            ac=u64(attrs);assert ac<1000
            props={}
            for i in range(ac):
                p=attrs+8+i*32;typ,_,np,vp,uk=struct.unpack_from('<II3Q',b,p)
                pn=readstr(b,np);at=vp if typ>10 and p+24<vp<len(b) else p+16
                value=None
                if typ in (1,3,4,5,6,7):value=struct.unpack_from('<I',b,at)[0]
                elif typ==10:value={'f32':struct.unpack_from('<f',b,at+4)[0],'f64':struct.unpack_from('<d',b,at)[0]}
                elif typ in (14,43):value=readstr(b,at)
                elif typ in (13,32,34):value=readstr(b,at,True)
                elif typ in (21,31):value=list(struct.unpack_from('<2f' if pn=='Size'else '<3f',b,at))
                elif typ in (22,26,27,28):value=list(struct.unpack_from('<3f'if pn in ('Position','Scale')else '<4f',b,at))
                elif typ==24:value=list(b[at:at+4])
                props[pn]={'type':typ,'value':value,'offset':at,'raw':b[at:at+16].hex()}
            subs.append({'name':readstr(b,sn,True),'class':readstr(b,sc),'properties':props})
        _,cn=struct.unpack_from('<II',b,clips)
        clipOffsets=list(struct.unpack_from('<'+'Q'*cn,b,clips+8))
        rows.append({'name':readstr(b,name,True),'class':readstr(b,cls),'children':subs,'clip_offsets':clipOffsets,
                     'clips':[read_clip(b,o)for o in clipOffsets]})
    return rows
def read_clip(b,off):
    name=readstr(b,struct.unpack_from('<Q',b,off+24)[0],True);start=off+40
    magic,ver,frames,nn,np,nk=struct.unpack_from('<IIfIII',b,start)
    assert magic==0x50494c43,(off,hex(magic))
    vals=struct.unpack_from('<10Q',b,start+24)
    nodes,props,keys,names=vals[:4];asciiBase=vals[5];wideBase=vals[7]
    def prop(index):
        p=start+props+index*56
        nameOffset=struct.unpack_from('<Q',b,p+16)[0];child=struct.unpack_from('<Q',b,p+32)[0]
        count,_,_,typ,_=struct.unpack_from('<HhBBH',b,p+40)
        pn=readstr(b,start+asciiBase+nameOffset)
        out={'name':pn,'type':typ}
        if typ in (0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f):
            out['children']=[prop(i)for i in range(child,child+count)]
        else:
            seq=[]
            for k in range(child,child+count):
                at=start+keys+k*32;t,rate,flags,_=struct.unpack_from('<ffII',b,at)
                value=struct.unpack_from('<d'if typ in (10,11)else '<q',b,at+16)[0]
                if typ in (13,32):value=readstr(b,start+wideBase+value*2,True)
                seq.append({'t':t,'value':value,'interpolation':flags&255,'rate':rate,'extra':b[at+24:at+32].hex()})
            out['keys']=seq
        return out
    tracks=[]
    for i in range(nn):
        at=start+nodes+i*40;nc,pc,typ,hash,n1,n2,first=struct.unpack_from('<HHI4Q',b,at)
        tracks.append({'name':readstr(b,start+wideBase+n1*2,True),'children':nc,'type':typ,
                       'properties':[prop(j)for j in range(first,first+pc)]})
    return {'name':name,'frames':frames,'version':ver,'nodes':tracks}
def read_uv(path):
    b=path.read_bytes();magic,nt,ns,np,attr,_=struct.unpack_from('<6I',b)
    tp,sp,pp,st=struct.unpack_from('<4Q',b,24);textures=[]
    for i in range(nt):
        _,idx=struct.unpack_from('<QQ',b,tp+40*i)
        textures.append(readstr(b,st+idx*2,True))
    patterns=[]
    for i in range(np):
        flags,l,t,r,bot,tex,cuts=struct.unpack_from('<Q4fii',b,pp+i*32)
        assert cuts in (0,-1)
        patterns.append({'uv':[l,t,r,bot],'texture':tex,'flags':flags})
    seq=[list(struct.unpack_from('<II',b,sp+i*8))for i in range(ns)]
    return {'textures':textures,'sequences':seq,'patterns':patterns}
if __name__=='__main__':
    rows=read_gui(GUI/'es/ui30000/ui30012/ui30012.gui.530035')
    (ROOT/'native-layout.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    uvs={str(p.relative_to(GUI)):read_uv(p)for p in GUI.rglob('*.uvs.7')if 'ui30012'not in str(p) or 'uvs_number' in p.name}
    (ROOT/'native-uv.json').write_text(json.dumps(uvs,indent=2),encoding='utf-8')
    for r in rows:
        print(r['name'],r['class'],'clips',r['clip_offsets'])
        for c in r['children']:
            print(' ',c['name'],c['class'],{k:v['value']for k,v in c['properties'].items()if k in ('Position','Size','Scale','Color','ColorScale','ColorOffset','Path','UVSequence','UVPattern','UVSequenceIndex','UVPatternIndex','Width','Height','Texture','Resource','BlendType')})
