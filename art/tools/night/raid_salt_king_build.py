"""C8c / Mère-Cristal. Background Blender, shared C7/cel pipeline; resumable by sheet.
Run with Blender --background --python this_file. --only comma,separated,sheets.
Python this_file --verify assembles the sole contact sheet and checks contracts.
"""
import sys, math, json, hashlib, tempfile, warnings
warnings.filterwarnings("ignore",category=DeprecationWarning)
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
DST=ROOT/'game/assets/sprites/bosses/etage/salt_king'
sys.path[:0]=[str(ROOT/'art/tools'/p) for p in ('cel','iso','monsters','bosses')]
import cel_style as cel
SPECS={**{f'{a}_p{p}':(6 if a=='idle' else 8,(256,256),('e','s','w','n'),True) for a in ('idle','walk') for p in (1,2,3)},
'auto':(6,(256,256),('e','s','w','n'),False),
**{a:(8,(256,256),('e','s','w','n'),False) for a in ('spell_a','spell_b')},
**{a:(6 if a=='stun' else 10 if a=='death' else 8,(256,256),('s',),a in ('shield','stun')) for a in ('edict','shield','crack','stun','trans_p2','trans_p3','death')},
'salt_crust':(18,(288,352),('s',),True),'crust_burst':(6,(384,384),('s',),False),
'stele':(12,(128,224),('s',),True),'stele_rise':(6,(128,256),('s',),False),
 'tide_sheet':(8,(1152,1152),('s',),True),'dry_nave':(8,(1152,1152),('s',),True),
 'tide_front':(6,(256,128),('s',),True),'crown':(8,(96,96),('s',),True),
 'crown_guarded':(4,(96,96),('s',),True),'crown_break':(6,(160,160),('s',),False),
 'throne':(6,(320,384),('s',),True),'throne_rise':(8,(320,448),('s',),False),
 'edict_ring':(6,(1024,1024),('s',),False),'tear_drop':(6,(96,128),('s',),False)}
SPECS['walk_p3']=(6,(256,256),('e','s','w','n'),True)
EXTRAS=set(SPECS)-{f'{a}_p{p}' for a in ('idle','walk') for p in (1,2,3)}-{'auto','spell_a','spell_b','edict','shield','crack','stun','trans_p2','trans_p3','death'}

def resource():
    """Text SpriteFrames; split the 16u beam into 4+2 frame atlases."""
    sheets=[];frames=[];anims=[]
    for a,(n,(w,h),dirs,loop) in SPECS.items():
        for part in range(math.ceil(n/(4096//w))):
            name=a if part==0 else a+'_'+str(part+1)
            sheets.append(name)
        for row,d in enumerate(dirs):
            ids=[]
            for i in range(n):
                part=i//(4096//w);col=i%(4096//w);name=a if part==0 else a+'_'+str(part+1)
                ident=f'{a}_{d}_{i}';ids.append(ident)
                frames.append(f'[sub_resource type="AtlasTexture" id="{ident}"]\natlas = ExtResource("{name}")\nregion = Rect2({col*w}, {row*h}, {w}, {h})\n')
            label=a if a in EXTRAS else a+'_'+d
            sequence=', '.join('{"duration": 1.0, "texture": SubResource("'+v+'")}' for v in ids)
            anims.append('{"frames": ['+sequence+'], "loop": '+str(loop).lower()+', "name": &"'+label+'", "speed": '+str(14.0 if a.startswith('walk') else 12.0)+'}')
    txt='[gd_resource type="SpriteFrames" load_steps='+str(1+len(sheets)+len(frames))+' format=3]\n\n'
    txt+='\n'.join(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/salt_king/{a}.png" id="{a}"]' for a in sheets)+'\n\n'
    txt+='\n'.join(frames)+'\n[resource]\nanimations = ['+',\n'.join(anims)+']\n'
    target=DST/'salt_king.tres'
    if not target.exists() or target.read_text(encoding='utf-8')!=txt:
        target.write_text(txt,encoding='utf-8')


def palette():
    import boss_common as c
    def mat(n,h,emit=0):
        rgb=tuple((v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4) for v in [int(h[i:i+2],16)/255 for i in (0,2,4)])
        m=c.material(n,rgb,0,.64,emit)
        if emit:m['rainfall_emissive']=True
        return m
    return [mat('Pearl grey salt 98A2A6','98A2A6'),mat('Pearl salt C9D3D6','C9D3D6'),mat('Cold cleavage edge','D8E9ED'),mat('Salt-entombed bone','B9B6AB'),mat('ONLY cyan geode','BFF4FF',1.6)]


def prism(name,loc,radius,height,mat,parent,lean=(0,0),seed=0):
    """Asymmetric six-sided geological habit, broad cleavage planes and two broken terminations."""
    from ash_lord_build import mesh
    verts=[]
    for k,(z,r) in enumerate(((-height*.5,.30),(-height*.36,1),(height*.25,.85),(height*.5,.035))):
        for j in range(6):
            a=j*math.tau/6+.17*seed
            rr=radius*r*(1+.09*math.sin(j*7+seed))
            verts.append((rr*math.cos(a)+lean[0]*(z/height+.5),rr*.80*math.sin(a)+lean[1]*(z/height+.5),z))
    faces=[tuple(range(5,-1,-1)),tuple(range(18,24))]+[(k*6+j,k*6+(j+1)%6,(k+1)*6+(j+1)%6,(k+1)*6+j) for k in range(3) for j in range(6)]
    ob=mesh(name,verts,faces,mat,parent);ob.location=loc
    return ob


def cold_rim(scene):
    import bpy
    from mathutils import Vector
    d=bpy.data.lights.new('Cold upper left silhouette','AREA');d.energy=420;d.color=(.65,.84,1);d.shape='DISK';d.size=5
    ob=bpy.data.objects.new(d.name,d);scene.collection.objects.link(ob);ob.location=(-3,1,5)
    ob.rotation_euler=(Vector((0,0,1.6))-ob.location).to_track_quat('-Z','Y').to_euler()


def crown(parent,mats,loc=(0,0,0),guard=False):
    import boss_common as c
    milk,pearl,edge,bone,glow=mats
    pivot=c.empty('Detached funeral diadem',loc,parent)
    for j in range(9):
        th=j*math.tau/9
        prism('Crown broken crystalline tooth',(.37*math.cos(th),.29*math.sin(th),.13),.065,.38+(j%3)*.12, milk if guard else glow,pivot,seed=j)
        if not guard:c.rod('Crown band',(.37*math.cos(th),.29*math.sin(th),0),(.37*math.cos(th+.7),.29*math.sin(th+.7),0),.035,pearl,pivot)
    return pivot

def throne(parent,mats):
    import boss_common as c
    milk,pearl,edge,bone,glow=mats
    pivot=c.empty('Empty sovereign salt throne',parent=parent)
    c.box('Throne angular seat',(0,.12,.85),(1.75,1.15,.33),pearl,pivot,.04)
    for side in (-1,1):
        prism('Throne buttress',(side*.8,.30,1.40),.28,2.8,milk,pivot,(side*.05,.12),int(side))
        c.box('Funeral armrest',(side*.70,-.25,1.3),(.26,1.15,.22),pearl,pivot,.025)
    for j in range(7):
        h=2.35+.65*(1-abs(j-3)/3)
        prism('High throne salt pipe',((j-3)*.22,.65,h/2),.18,h,pearl if j%2 else milk,pivot,seed=j)
    return pivot

def build():
    import bpy, boss_common as c, iso_rig
    from mathutils import Vector
    s=iso_rig.create_rig('CREA',256);s.camera.data.ortho_scale=4.95
    s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,4.95*(196.5/256-.5),0))
    cold_rim(s);mats=palette();milk,pearl,edge,bone,glow=mats
    root=c.empty('SALT_KING_3_8U');root.scale=(.80,)*3;body=c.empty('Hunched drowned monarch',parent=root)
    cloak=[];veins=[]
    # Layered mineral lamellae form a closed, humped mantle and a 1.5u rear train.
    for j in range(17):
        th=j*math.tau/17;back=max(0,math.cos(th));h=2.15+.30*math.sin(j*2.1)
        x=.79*math.sin(th);y=.53*math.cos(th)+.62*back
        ob=prism('Great dragging salt mantle slab',(x,y,h/2+.04),.32,h,pearl if j%3 else milk,body,(-x*.36,-y*.38),j);cloak.append(ob)
        if j%2==0:
            veins.append(c.tube('Cyan split through salt',[(x*1.04,y*1.04,.18),(x*.97+.025,y*.97,.64),(x*.81-.03,y*.81,1.15),(x*.65,y*.65,1.80)],.019,glow,body))
        if back>.2:
            ob=prism('Salt encrusted trailing train',(x,1.0+.72*back,.19),.39,.35,pearl,body,(.1,.20),j);cloak.append(ob)
    for j in range(11):
        x=.65*math.sin(j*2.4);y=.7+.95*(j%4)/3
        ob=prism('Shell and bone trapped in train',(x,y,.21),.09,.25,bone,body,seed=j);ob.rotation_euler.y=.9
    # Long thin torso, sloping shoulders, blank eyeless ossuary mask.
    prism('Wasted sternum',(0,-.05,2.40),.20,.98,bone,body,(-.02,-.18),4)
    for side in (-1,1):
        c.rod('Sloping clavicle',(0,-.12,2.90),(side*.63,-.04,2.60),.095,bone,body)
        for j in range(5):
            c.tube('Exposed narrow drowned rib',[(side*.05,-.22,2.75-j*.105),(side*.25,-.29,2.69-j*.105),(side*.35,-.02,2.59-j*.105)],.031,bone,body)
        prism('Salt epaulette',(side*.56,.07,2.61),.30,.62,pearl,body,(side*.22,0),int(side))
    head=c.empty('Bent eyeless funeral mask',(0,-.36,3.03),body)
    prism('Smooth featureless bone face',(0,-.08,.13),.215,.56,bone,head,(0,-.09),2)
    prism('Funeral mask long nasal blade',(0,-.25,.07),.045,.32,edge,head,seed=1)
    for side in (-1,1):prism('Hollow hanging cheek',(side*.14,-.19,-.04),.055,.34,bone,head,seed=2)
    diadem=crown(body,mats[:4]+[edge],(0,-.34,3.43))
    arm=c.empty('Scepter shoulder',(.57,-.13,2.58),body)
    c.rod('Bare upper arm',(0,0,0),(.25,-.12,-.50),.075,bone,arm)
    c.rod('Wasted forearm',(.25,-.12,-.50),(.32,-.47,-.86),.057,bone,arm)
    staff=c.empty('Ossified eel spine',(.32,-.47,-.86),arm)
    for j in range(15):
        z=-1.45+j*.20;x=.055*math.sin(j*.53)
        prism('Eel vertebra',(x,0,z),.071,.19,bone,staff,seed=j)
        c.rod('Eel neural spine',(x,0,z),(x+.14,0,z+.045),.02,pearl,staff)
    skull=prism('Fish skull scepter finial',(.03,-.035,1.49),.20,.43,bone,staff,(.06,-.13),2)
    for side in (-1,1):
        c.rod('Fish skeletal mandible',(side*.12,-.03,1.45),(side*.065,-.25,1.26),.033,bone,staff)
        for j in range(3):prism('Fish tooth',(side*.07,-.20,1.28+j*.06),.017,.065,pearl,staff,seed=j)
    c.rod('Left lowered arm',(-.52,-.05,2.55),(-.70,-.32,1.67),.078,bone,body)
    chips=[prism('Disintegrating salt flake',(.9*math.sin(j*2.4),1.0*math.cos(j*2.4),.20+(j%4)*.22),.085,.23,pearl,root,seed=j) for j in range(12)]
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in root.children_recursive}
    def pose(a,i,n):
        for o,(l,r,sc) in rest.items():o.location=l;o.rotation_euler=r;o.scale=sc;o.hide_render=False
        u=i/max(1,n-1);t=i/n;wave=math.sin(t*math.tau)
        p=3 if 'p3' in a or a=='edict' else 2 if 'p2' in a or a in ('stun','crack') else 1
        for v in veins:v.hide_render=p==1
        for o in [diadem]+list(diadem.children_recursive):o.hide_render=p>=2 or a=='stun'
        body.rotation_euler.x=.035*wave;body.location.z=.018*wave
        if a.startswith('walk') and p!=3:
            body.rotation_euler.y=.035*wave;arm.rotation_euler.x=.09*wave
            for j,o in enumerate(cloak):o.rotation_euler.x+=.035*math.sin(t*math.tau+j*.5)
        if p==3:
            body.location.z=-.70;body.rotation_euler.x=-.08
            for j,o in enumerate(cloak):
                o.scale.z=.38;o.scale.x=1.32;o.location.z*=.38;o.location.y*=1.3
        peak=max(0,1-abs(i-n//2)/(n/2))
        if a=='auto':arm.rotation_euler.x=-.25+1.10*peak;arm.rotation_euler.z=-.65*peak;staff.rotation_euler.y=-.75*peak
        if a=='spell_a':arm.rotation_euler.x=-1.55*peak;arm.rotation_euler.y=-.42*peak
        if a=='spell_b':arm.rotation_euler.x=-.60*(1-peak);staff.location.z-=.55*peak;body.rotation_euler.x=.20*peak
        if a=='edict':arm.rotation_euler.z=-1.0*peak;staff.rotation_euler.y=-.6*peak
        if a in ('shield','crack','trans_p2','trans_p3'):
            body.location.z-=.73 if a in ('shield','crack') else .65*math.sin(u*math.pi)
            body.rotation_euler.x=.20;head.rotation_euler.x=.24
        if a=='trans_p2':
            for j,v in enumerate(veins):v.hide_render=u<(j+1)/(len(veins)+3)
            diadem.location.z+=u*.8
            for ob in [diadem]+list(diadem.children_recursive):ob.hide_render=u>.5
        if a=='trans_p3':
            body.location.z=-.70*u;body.rotation_euler.x=-.08*u
            for ob in cloak:
                loc=rest[ob][0];ob.scale.z=1-.62*u;ob.scale.x=1+.32*u
                ob.location.z=loc.z*(1-.62*u);ob.location.y=loc.y*(1+.3*u)
        if a=='stun':body.rotation_euler.x=.14+.06*wave;head.rotation_euler.y=.10*wave;arm.rotation_euler.z=.18
        if a=='death':
            body.scale.z=max(.06,1-u*.94);body.location.z=-.10*u
            diadem.location.y-=1.6*u;diadem.location.z-=3.35*u;diadem.rotation_euler.x=math.tau*u
        for j,o in enumerate(chips):
            o.hide_render=a not in ('crack','death','trans_p3')
            q=peak if a=='crack' else u;o.location.x*=1+q;o.location.z+=q*(.7+(j%3)*.2);o.rotation_euler.y=q*(j-5)*.35
    return root,pose

def flat_material(name,color,alpha):
    import bpy
    m=bpy.data.materials.new(name);m.use_nodes=True;nd=m.node_tree.nodes;nd.clear();ln=m.node_tree.links
    out=nd.new('ShaderNodeOutputMaterial');em=nd.new('ShaderNodeEmission');em.inputs[0].default_value=(*color,1)
    tr=nd.new('ShaderNodeBsdfTransparent');mix=nd.new('ShaderNodeMixShader');mix.inputs[0].default_value=alpha
    ln.new(tr.outputs[0],mix.inputs[1]);ln.new(em.outputs[0],mix.inputs[2]);ln.new(mix.outputs[0],out.inputs[0]);m['cel_done']=True
    return m

def extra(a):
    import bpy, boss_common as c, iso_rig
    from mathutils import Vector
    from ash_lord_build import mesh
    n,(w,h),_,_=SPECS[a];ground=a in ('tide_sheet','dry_nave','tide_front','edict_ring')
    s=iso_rig.create_rig('TOP' if ground else 'CREA',(w,h));s.camera.data.ortho_scale=w/(64 if ground else 90.5)
    if not ground:s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(h/2-7)/90.5,0))
    mats=palette();milk,pearl,edge,bone,glow=mats;cold_rim(s);root=c.empty('Salt king '+a);moving=[];fissures=[]
    if a.startswith('crown'):
        ob=crown(root,mats,(0,0,.48 if a!='crown_break' else .64),a=='crown_guarded');moving=[ob]
    elif a.startswith('throne'):moving=[throne(root,mats)]
    elif a.startswith('stele'):
        ob=prism('Eroded royal salt stele',(0,0,.94),.45,1.85,pearl,root,seed=3);moving=[ob]
        for j in range(3):fissures.append(c.tube('Stele luminous inscription',[(-.19,-.31,.48+j*.37),(.08,-.37,.60+j*.37),(.20,-.31,.72+j*.37)],.017,glow,root))
        for j in range(5):prism('Stele foot broken salt',(.34*math.sin(j*2.4),.26*math.cos(j*2.4),.12),.14,.23,milk,root,seed=j)
    elif a=='salt_crust':
        for j in range(19):
            th=j*2.4;r=.67+.36*(j%3)/2;hh=1.2+(j%5)*.32
            ob=prism('Kneeling king mineral cocoon',(r*math.sin(th),r*.65*math.cos(th),hh/2),.34,hh,pearl if j%2 else milk,root,(-.2*math.sin(th),0),j);moving.append(ob)
            if j%2==0:fissures.append(c.tube('Crust luminous fault',[(r*math.sin(th),r*.68*math.cos(th),.2),(r*.9*math.sin(th),r*.7*math.cos(th),.8),(r*.7*math.sin(th),r*.7*math.cos(th),hh)],.021,glow,root))
    elif a in ('crust_burst','tear_drop'):
        for j in range(18 if a=='crust_burst' else 1):
            th=j*2.4;moving.append(prism('Salt tear' if a=='tear_drop' else 'Burst mineral shard',(.65*math.sin(th),.45*math.cos(th),.55+(j%4)*.25),.13 if a=='crust_burst' else .12,.45 if a=='crust_burst' else .55,pearl,root,seed=j))
    elif ground:
        red=flat_material('Translucent red danger tide',(.55,.045,.035),.27)
        cyan=flat_material('Translucent cyan dry nave',(.52,.90,1),.12)
        foam=flat_material('Pearl salt foam',(.65,.74,.77),.5)
        def band(name,r0,r1,lo,hi,z,mat,steps=128):
            vs=[]
            for k in range(steps+1):
                th=lo+(hi-lo)*k/steps
                for r in (r0,r1):vs.append((r*math.cos(th),r*math.sin(th),z))
            return mesh(name,vs,[(k*2,k*2+1,k*2+3,k*2+2) for k in range(steps)],mat,root)
        if a=='tide_sheet':
            moving.append(band('Nine unit tide disc',0,8.96,0,math.tau,.01,red))
            for j in range(7):moving.append(band('Saline tidal contour',2+j*.94,2.04+j*.94,0,math.tau,.02,foam))
        if a=='dry_nave':
            moving.append(band('Ninety degree dry sector',0,8.96,-math.pi/4,math.pi/4,.01,cyan))
            moving.append(band('Dry sector crystalline edge',8.91,8.98,-math.pi/4,math.pi/4,.02,glow))
            for th in (-math.pi/4,math.pi/4):c.rod('Dry nave straight luminous boundary',(0,0,.025),(8.97*math.cos(th),8.97*math.sin(th),.025),.018,glow,root)
        if a=='edict_ring':moving.append(band('Royal edict forty eight pixel ring',7.22,7.97,0,math.tau,.01,pearl))
        if a=='tide_front':
            for j in range(17):
                ob=prism('Salt foam advancing positive X',(.25+.24*math.sin(j*2.4),(j-8)*.105,.08),.10,.20,pearl,root,seed=j);ob.rotation_euler.y=math.pi/2;moving.append(ob)
    rest={o:(o.location.copy(),o.scale.copy(),o.rotation_euler.copy()) for o in root.children_recursive}
    def pose(anim,i,n):
        u=i/max(1,n-1);t=i/n;wave=math.sin(t*math.tau)
        for o,(l,sc,r) in rest.items():o.location=l;o.scale=sc;o.rotation_euler=r;o.hide_render=False
        for j,o in enumerate(moving):
            if a=='salt_crust':o.scale=(1+.018*math.sin((i%6)*math.tau/6),)*3;o.rotation_euler.y+=(i//6)*.025*math.sin(j)
            elif a=='stele':o.scale.z=1 if i<6 else .80;o.rotation_euler.y=.018*math.sin(t*math.tau)
            elif a.endswith('_rise'):o.scale.z=max(.02,u);o.location.z*=max(.02,u)
            elif a=='crown':o.location.z+=.07*wave;o.rotation_euler.z=t*math.tau
            elif a=='crown_guarded':o.rotation_euler.z=t*math.tau*.25
            elif a=='crown_break':
                for k,ch in enumerate(o.children):ch.location.x*=1+u*1.8;ch.location.z+=math.sin(u*math.pi)*.3-u*.45;ch.rotation_euler.y=u*(k-4)*.3
            elif a=='crust_burst':o.location.x*=1+2*u;o.location.y*=1+2*u;o.location.z+=math.sin(u*math.pi)*1.5;o.rotation_euler.y=u*(j-8)*.25;o.scale=(1-.65*u,)*3
            elif a=='tear_drop':o.location.z=1.1-u*.86;o.scale.z=1+.25*math.sin(u*math.pi)
            elif a=='edict_ring':o.scale=(.14+.86*u,)*3
            elif a=='tide_front':o.location.x+=.16*wave
            elif ground:o.scale=(1-.003*(1-wave),)*3
        for o in fissures:o.hide_render=a=='salt_crust' and i<6
    if not ground:
        # Fit the complete animated envelope, keeping one stable billboard pivot.
        up=s.camera.rotation_euler.to_matrix()@Vector((0,1,0));right=s.camera.rotation_euler.to_matrix()@Vector((1,0,0))
        low=left=1e6;high=rightmost=-1e6
        for i in range(n):
            pose(a,i,n);bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
            for ob in root.children_recursive:
                if ob.hide_render or ob.type not in ('MESH','CURVE'):continue
                ev=ob.evaluated_get(deps);me=ev.to_mesh()
                for v in me.vertices:
                    pt=ev.matrix_world@v.co;yy=up.dot(pt);xx=right.dot(pt)
                    low=min(low,yy);high=max(high,yy);left=min(left,xx);rightmost=max(rightmost,xx)
                ev.to_mesh_clear()
        fac=min(1,(w-12)/90.5/(rightmost-left),(h-14)/90.5/(high-low))
        root.scale=(fac,)*3;root.location=up*(-low*fac)+right*(-(left+rightmost)*.5*fac)
        pose(a,0,n)
    return root,pose

def fit_hem(root):
    """Keep the visible foremost salt/water contact on the contractual y=215 in all directions."""
    import bpy
    from mathutils import Vector
    s=bpy.context.scene;root.location=(0,0,0);bpy.context.view_layer.update()
    up=s.camera.rotation_euler.to_matrix()@Vector((0,1,0))
    low=1e6
    deps=bpy.context.evaluated_depsgraph_get()
    for ob in root.children_recursive:
        if ob.hide_render or ob.type not in ('MESH','CURVE'):continue
        ev=ob.evaluated_get(deps);me=ev.to_mesh()
        if me.vertices:low=min(low,min(up.dot(ev.matrix_world@v.co-s.camera.location) for v in me.vertices))
        ev.to_mesh_clear()
    target=(.5-215/256)*s.camera.data.ortho_scale
    root.location=up*(target-low)


def render_frame(path):
    """C7 render adapter without a normal-file output; normals only feed cel ink."""
    import bpy, boss_common as c
    from PIL import Image
    s=bpy.context.scene
    c.configure_passes(path)
    s.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    candidates=list(path.parent.glob(path.stem+'_e__*.png'))
    assert len(candidates)==1, ('emission pass',path)
    ep=path.with_name(path.stem+'_e.png');candidates[0].replace(ep)
    for p in (path,ep):
        with Image.open(p) as im:
            resized=im.convert('RGBA').resize(tuple(s['iso_frame']),Image.Resampling.LANCZOS)
        resized.save(p,compress_level=6)


def main():
    import bpy, boss_common as c, iso_rig
    from PIL import Image
    DST.mkdir(parents=True,exist_ok=True)
    root,pose=build()
    cel.install('boss', normals=False)
    cel.setup_scene();cel.toon_materials('boss')
    bpy.context.preferences.filepaths.save_version=0
    source=ROOT/'art/blender/bosses/salt_king_iso.blend';source.parent.mkdir(parents=True,exist_ok=True)
    if '--only' not in sys.argv or '--save-source' in sys.argv:
        f=1
        for a,(n,_,dirs,_) in SPECS.items():
            if a in EXTRAS:continue
            bpy.context.scene.timeline_markers.new(a,frame=f)
            for i in range(n):
                pose(a,i,n);fit_hem(root)
                for o in [root]+list(root.children_recursive):
                    for channel in ('location','rotation_euler','scale','hide_render'):o.keyframe_insert(channel,frame=f+i)
            f+=n
        bpy.context.scene.frame_end=f-1;bpy.context.scene.render.fps=12
        bpy.context.scene.frame_set(1)
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
        # Keep editable animation in the source, export using explicit procedural poses.
        for o in [root]+list(root.children_recursive):o.animation_data_clear()
        pose('idle_p1',0,6)
    if '--source-only' in sys.argv:return
    selected=sys.argv[sys.argv.index('--only')+1].split(',') if '--only' in sys.argv else list(SPECS)
    cel.install('boss', normals=False)
    with tempfile.TemporaryDirectory(prefix='rainfall_salt_') as td:
        tmp=Path(td)
        for a in selected:
            n,(w,h),dirs,loop=SPECS[a]
            if a in EXTRAS:root,pose=extra(a)
            elif bpy.context.scene.get('iso_rig')!='CREA' or root.name!='SALT_KING_3_8U':root,pose=build()
            s=bpy.context.scene;s['iso_frame']=[w,h];s.render.resolution_x=w*2;s.render.resolution_y=h*2
            cap=4096//w
            for part,start in enumerate(range(0,n,cap)):
                count=min(cap,n-start);name=a if part==0 else a+'_'+str(part+1)
                boards=[Image.new('RGBA',(count*w,len(dirs)*h)) for _ in range(2)]
                for row,d in enumerate(dirs):
                    for i in range(start,start+count):
                        pose(a,i,n)
                        if a not in EXTRAS:
                            root.rotation_euler.z=c.DIRECTIONS[d]
                            fit_hem(root)
                        bpy.context.view_layer.update();path=tmp/f'{a}_{d}_{i}.png'
                        render_frame(path)
                        for j,suffix in enumerate(('','_e')):
                            with Image.open(path.with_name(path.stem+suffix+'.png')) as im0:im=im0.convert('RGBA')
                            if j==0:alpha=im.getchannel('A')
                            else:im.putalpha(alpha)
                            boards[j].paste(im,((i-start)*w,row*h))
                boards[0].save(DST/f'{name}.png',compress_level=9)
                sys.path.insert(0,str(ROOT/'art/tools'))
                from halve_emission import downscale
                import numpy as np
                e=np.asarray(boards[1],dtype=float)
                if (e[:,:,:3].max(axis=2)*e[:,:,3]/255).max()>2:
                    downscale(boards[1]).save(DST/f'{name}_e.png',compress_level=9)
                else:
                    (DST/f'{name}_e.png').unlink(missing_ok=True)
                print('RAID_SALT_KING DONE '+name,flush=True)
    resource()
    import_policy()

def import_policy():
    sys.path.insert(0,str(ROOT/"art/tools"))
    import texture_budget as budget
    original=budget.os.walk
    try:
        budget.os.walk=lambda path: original(str(DST))
        budget.apply_policy(budget.load_budget())
    finally:
        budget.os.walk=original

def verify():
    from PIL import Image
    import numpy as np
    cells=[];means=[]
    for a,(n,(w,h),dirs,loop) in SPECS.items():
        for part,start in enumerate(range(0,n,4096//w)):
            count=min(4096//w,n-start);name=a if part==0 else a+'_'+str(part+1)
            with Image.open(DST/f'{name}.png') as raw:im=raw.convert('RGBA')
            assert im.size==(count*w,len(dirs)*h) and max(im.size)<=4096,name
            ep=DST/f'{name}_e.png'
            if ep.exists():
                with Image.open(ep) as em:
                    assert em.size==((im.width+1)//2,(im.height+1)//2),name
                    d=np.asarray(em,dtype=float);assert (d[:,:,:3].max(axis=2)*d[:,:,3]/255).max()>2,name
            if a not in EXTRAS and part==0:
                for row in range(len(dirs)):
                    for i in range(count):
                        fr=im.crop((i*w,row*h,(i+1)*w,(row+1)*h));assert fr.getbbox(),(a,row,i)
                for row in range(len(dirs)):
                    for i in range(count):
                        ar=np.asarray(im.crop((i*w,row*h,(i+1)*w,(row+1)*h)));ys,xs=np.where(ar[:,:,3]>128)
                        assert len(xs) and xs.min()>0 and xs.max()<255 and ys.min()>0 and ys.max()<255,(a,row,i,'clipped')
                if a=='idle_p1':
                    for row in range(4):
                        fr=im.crop((0,row*h,w,(row+1)*h));d=np.asarray(fr);mask=d[:,:,3]>128
                        means.append(float(d[:,:,:3][mask].mean()));assert means[-1]>=90,means
                for row in range(len(dirs)):
                    cells.append(im.crop((min(count-1,n//2)*w,row*h,(min(count-1,n//2)+1)*w,(row+1)*h)))
            elif part==0:
                fr=im.crop((0,0,w,h));fr.thumbnail((256,384));cells.append(fr)
    assert not list(DST.glob('*_n.png'))
    with Image.open(ROOT/'game/assets/sprites/bosses/etage/recluse/idle_p1.png') as raw:
        # Reclus uses tightly cropped 140x264 cells plus AtlasTexture margins.
        ref=raw.convert('RGBA').crop((0,264,140,528));ref=ref.crop(ref.getbbox())
        ratio=195/max(ref.size);ref=ref.resize(tuple(round(v*ratio) for v in ref.size),Image.Resampling.LANCZOS)
        compare=Image.new('RGBA',(256,256));compare.alpha_composite(ref,((256-ref.width)//2,215-ref.height));cells.insert(0,compare)
    board=Image.new('RGBA',(2048,math.ceil(len(cells)/8)*384),(46,50,56,255))
    for j,im in enumerate(cells):board.alpha_composite(im,((j%8)*256,(j//8)*384+384-im.height))
    board.convert('RGB').save(HERE/'_raid_salt_king_contact.png')
    print('PASS atlas/emission/normals; body means='+str([round(x,1) for x in means])+'; contact='+str(len(cells)))

if __name__=='__main__':
    if '--policy' in sys.argv:import_policy()
    elif '--verify' in sys.argv:verify()
    else:main()
