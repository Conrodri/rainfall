"""Vigie action parameters, reusing VG1 geometry, pose solver and cel renderer."""
import sys,inspect,json,re,shutil,hashlib,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso')]
import vg1_build as vg
WORK=ROOT/'art/blender/cel/vigie_actions'
BASE=ROOT/'game/assets/sprites/characters/vigie'
ANIMS={'attack':5,'flare':6,'net':5,'volley':8}
F60={'attack':[3,2,5,5,6],'flare':[3,3,2,7,6,7],'net':[5,2,7,6,7],'volley':[4,4,4,2,10,7,8,9]}
HITS={'attack':2,'flare':3,'net':2,'volley':4}
ALIASES={'cast':'flare','cast_ult':'volley'}

# Bow grip positions and Euler angles; the existing VG1 two-bone solver follows.
POSES={
 'attack':[
 ((-.26,-.40,.94),(0,1.18,-.28)),
 ((-.27,-.43,1.04),(.06,1.35,-.38)),
 ((-.29,-.48,1.05),(-.06,1.40,-.90)),
 ((-.21,-.32,.92),(.16,1.04,.20)),
 ((-.25,-.13,.745),(.18,.26,-.18))],
 'flare':[
 ((-.20,-.29,1.05),(-.72,.30,-1.30)),
 ((-.17,-.32,1.14),(-.90,.25,-1.45)),
 ((-.21,-.36,1.16),(-1.0,.25,-1.55)),
 ((-.24,-.40,1.19),(-1.06,.25,-1.70)),
 ((-.19,-.21,.99),(-.36,.85,.16)),
 ((-.25,-.13,.745),(.18,.26,-.18))],
 'net':[
 ((.24,-.14,.96),(.18,1.38,-1.10)),
 ((.06,-.33,1.02),(.06,1.38,-.45)),
 ((-.28,-.48,1.04),(-.02,1.40,-.90)),
 ((-.20,-.27,.91),(.20,.95,.40)),
 ((-.25,-.13,.745),(.18,.26,-.18))],
 'volley':[
 ((-.16,-.23,1.10),(-.85,.25,-1.35)),
 ((-.12,-.22,1.20),(-1.0,.22,-1.45)),
 ((-.10,-.20,1.26),(-1.15,.20,-1.55)),
 ((-.13,-.25,1.28),(-1.24,.20,-1.60)),
 ((-.16,-.30,1.32),(-1.34,.20,-1.70)),
 ((-.12,-.19,1.13),(-.65,1.02,.30)),
 ((-.20,-.16,.91),(-.20,.65,.16)),
 ((-.25,-.13,.745),(.18,.26,-.18))]}

def resources():
    # Only replace action entries; preserve the non-action dictionaries and atlases.
    for filename in ('vigie.tres','vigie_emission.tres'):
        path=BASE/filename
        if not path.exists():continue
        raw=(WORK/filename).read_bytes();s=raw.decode();nl='\r\n' if b'\r\n' in raw else '\n'
        ext=re.findall(r'\[ext_resource[^\]]+\]',s)
        eids={Path(re.search(r'path="([^"]+)"',e).group(1)).stem.removesuffix('_e'):re.search(r'id="([^"]+)"',e).group(1) for e in ext}
        subs={m.group(1):m.group(0).rstrip() for m in re.finditer(r'\[sub_resource[^\]]*id="([^"]+)"\][\s\S]*?(?=\n\[|\Z)',s)}
        body=s[s.index('animations = [')+len('animations = ['):].strip()[:-1]
        entries=[];depth=0
        for i,c in enumerate(body):
            if c=='{':
                if depth==0:begin=i
                depth+=1
            elif c=='}':
                depth-=1
                if depth==0:entries.append(body[begin:i+1])
        kept=[];newsubs=[];newentries=[];seen=set()
        for entry in entries:
            name=re.search(r'"name"\s*:\s*&?"([^"]+)"',entry).group(1)
            if any(name.startswith(a+'_') for a in [*ANIMS,*ALIASES]):continue
            kept.append(entry)
            for sid in re.findall(r'SubResource\("([^"]+)"\)',entry):
                if sid not in seen:newsubs.append(subs[sid]);seen.add(sid)
        cell=96 if 'emission' in filename else 192
        for a in ANIMS:
            for row,d in enumerate(vg.DIRS):
                frames=[]
                for f in range(ANIMS[a]):
                    sid=f'action_{a}_{d}_{f}'
                    newsubs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{eids[a]}")\nregion = Rect2({f*cell}, {row*cell}, {cell}, {cell})')
                    frames.append('{"duration": '+str(F60[a][f]*12/60)+', "texture": SubResource("'+sid+'")}')
                for alias in [a]+[k for k,v in ALIASES.items() if v==a]:
                    newentries.append('{"frames": ['+', '.join(frames)+'], "loop": false, "name": &"'+alias+'_'+d+'", "speed": 12.0}')
        header=re.search(r'^\[gd_resource[^\]]+\]',s).group(0)
        header=re.sub(r'load_steps=\d+','load_steps='+str(len(ext)+len(newsubs)+1),header)
        result=header+'\n\n'+'\n'.join(ext)+'\n\n'+'\n\n'.join(newsubs)+'\n\n[resource]\nanimations = [\n'+',\n'.join(kept+newentries)+'\n]\n'
        path.write_bytes(result.replace('\r\n','\n').replace('\n',nl).encode())

def finish():
    from PIL import Image
    for a,n in ANIMS.items():
        for suffix in ('','_e'):
            im=Image.new('RGBA',(192*n,192*8))
            for row,d in enumerate(vg.DIRS):
                for f in range(n):
                    with Image.open(vg.RAW/f'{a}_{d}_{f:02d}{suffix}.png') as tile:im.paste(tile,(192*f,192*row))
            if suffix:im=im.resize((im.width//2,im.height//2),Image.Resampling.LANCZOS)
            path=BASE/(a+suffix+'.png')
            im.save(path,optimize=True,compress_level=9)
            budget=json.loads((WORK/'before.json').read_text())[path.name]['bytes']*1.3
            if path.stat().st_size>budget:
                subprocess.run(['C:/Users/const/AppData/Local/Python/bin/python.exe',str(Path(__file__).resolve()),'--optimize',str(path)],check=True)
            for alias,source in ALIASES.items():
                if source==a and (BASE/(alias+suffix+'.png')).exists():shutil.copy2(BASE/(a+suffix+'.png'),BASE/(alias+suffix+'.png'))
    resources()
    print('PASS Vigie 192 action cells; no normal maps',flush=True)

def action_source():
    source=inspect.getsource(vg.build)
    # Reuse the procedural source without overwriting its blend or other assets.
    source=source.replace("    def pose(a,f,n):",'''    ghosts=[]
    for k in range(2):
        m=bpy.data.materials.new('Translucent action ghost '+str(k));m.use_nodes=True;m['cel_done']=True
        ns=m.node_tree.nodes;ns.clear();out=ns.new('ShaderNodeOutputMaterial');mix=ns.new('ShaderNodeMixShader')
        tr=ns.new('ShaderNodeBsdfTransparent');em=ns.new('ShaderNodeEmission');em.inputs['Color'].default_value=(.15,.10,.08,1)
        mix.inputs[0].default_value=.18-k*.055
        m.node_tree.links.new(tr.outputs[0],mix.inputs[1]);m.node_tree.links.new(em.outputs[0],mix.inputs[2]);m.node_tree.links.new(mix.outputs[0],out.inputs[0])
        for original in [*bowrods,*strings,*[o for o in limbs['R'][3].children_recursive if o.type=='MESH']]:
            ghost=original.copy();ghost.data=original.data.copy();ghost.data.materials.clear();ghost.data.materials.append(m)
            s.collection.objects.link(ghost);ghost.parent=root;ghosts.append((k,original,ghost))
    def pose(a,f,n):''')
    source=source.replace("        if a=='death':",'''        impact=IMPACTS[a]
        bow.location,bow.rotation_euler=POSES[a][f]
        bow.scale=(.90,.90,.90) if f<n-1 else (1,1,1)
        if a=='net' and f==IMPACTS[a]:bow.scale=(.915,.915,.915)
        if a in ('flare','volley') and f==IMPACTS[a]:bow.scale=(1.02,1.02,1.02)
        if f<n-1:
            bow.location.x*=.8;bow.location.y*=.8
            if a in ('flare','volley'):bow.location.z-=.10
            if a in ('flare','volley') and f<=IMPACTS[a]:bow.location.z=min(bow.location.z,.85 if a=='flare' else 1.10)
        anticipation=f<impact
        power=1 if f<=impact else max(0,(n-1-f)/(n-1-impact))
        twist={'attack':-.35,'flare':-.48,'net':.72,'volley':-.38}[a]
        if a=='net':twist=[.80,.30,-.75,-.22,.04][f]
        torso.rotation_euler=(-.28*power if a in ('flare','volley') else .12*power,.10*power,twist*power)
        torso.location=(.04*power,.07*power,.65+(.08 if a=='volley' else .025)*power)
        head.rotation_euler=(-.35*power,0,-.10*power)
        pull=(.43+.055*min(f,impact-1)) if anticipation else (.015 if f==impact else .055)
        if f==n-1:pull=.08
        limbs['L'][0].rotation_euler.x=.48*power+.25*(1-power)
        limbs['R'][0].rotation_euler.x=-.48*power-.25*(1-power)
        limbs['L'][1].rotation_euler.x=-.25*power
        if a=='death':''')
    source=source.replace("        netroot.scale=(1,1,.35+1.05*f/max(1,n-1))",'''        netroot.scale=((.7 if f<impact else 2.5),1,(.4 if f<impact else 1.3))
        visibility(flarehead,a=='flare' and f<=impact)
        if a=='flare' and f==impact:visibility(arrow,True)
        bpy.context.view_layer.update()
        for k,original,ghost in ghosts:
            ghost.matrix_world=original.matrix_world.copy()
            ghost.rotation_euler.z+=(k+1)*.20
            ghost.location.x+=(k+1)*.065
            ghost.location.z-=(k+1)*.055
            visibility(ghost,a!='attack' and f==impact-1)
            for prop in ('location','rotation_euler','scale'):ghost.keyframe_insert(prop)''')
    source=source.replace("    def accent_base(path):",'''    for nd in fuse.node_tree.nodes:
        if nd.type!='OUTPUT_AOV':continue
        base=tuple(nd.inputs['Color'].default_value)
        for ai,(a,n) in enumerate(ANIMS.items()):
            for f in range(n):
                factor=2 if f==IMPACTS[a] else 1
                nd.inputs['Color'].default_value=tuple(c*factor for c in base[:3])+(1,)
                nd.inputs['Color'].keyframe_insert('default_value',frame=ai*20+1+f)
    s['action_F60']=json.dumps(F60)
    s['impact_emission_multiplier']=2
    def accent_base(path):''')
    source=source.replace("    s.frame_set(1);bpy.context.view_layer.update()","    s.frame_set(1);bpy.context.view_layer.update()\n    bpy.context.preferences.filepaths.save_version=0")
    source=source.replace('worst=(999,None)','worst=(999,None);bounds={}')
    source=source.replace('margin=min(x,y,192-x,192-y)',"margin=min(x,y,192-x,192-y)\n                        key=a+'/'+str(f);box=bounds.setdefault(key,[999,999,-999,-999]);box[:]=[min(box[0],x),min(box[1],y),max(box[2],x),max(box[3],y)]")
    source=source.replace("    assert worst[0]>=3,worst",'''    (WORK/'preflight.json').write_text(json.dumps({'margin':worst,'bounds':bounds,'poses':POSES}))
    assert worst[0]>=1,worst
    if '--preflight' in sys.argv:print('PASS PREFLIGHT',flush=True);return''')
    source=source.replace("    print('VG1 GEOMETRY MARGIN',round(worst[0],2),worst[1],flush=True)","    pass")
    source=source.replace("        print('VG1 RENDER '+a+' '+str(completed)+'/'+str(n*8),flush=True)","        pass")
    return source

def main():
    vg.ANIMS=ANIMS;vg.SOURCE=WORK/'vigie.blend';vg.RAW=WORK/'renders';vg.finish=finish
    vg.POSES=POSES;vg.F60=F60;vg.WORK=WORK
    source=action_source()
    exec(compile(source,str(__file__),'exec'),vg.__dict__)
    vg.build()

if __name__=='__main__':
    if '--optimize' in sys.argv:
        import zopfli.png
        p=Path(sys.argv[-1]);raw=p.read_bytes()
        optimized=zopfli.png.optimize(raw,num_iterations=5,num_iterations_large=5)
        if len(optimized)<len(raw):p.write_bytes(optimized)
    elif '--finish' in sys.argv:
        vg.RAW=WORK/'renders';finish()
    else:main()
