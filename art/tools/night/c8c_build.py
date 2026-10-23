"""C8c / Mère-Cristal. Background Blender, shared C7/cel pipeline; resumable by sheet.
Run with Blender --background --python this_file. --only comma,separated,sheets.
Python this_file --verify assembles the sole contact sheet and checks contracts.
"""
import sys, math, json, hashlib, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
DST=ROOT/'game/assets/sprites/bosses/etage/crystal_mother'
sys.path[:0]=[str(ROOT/'art/tools'/p) for p in ('cel','iso','monsters','bosses')]
import cel_style as cel
SPECS={**{f'{a}_p{p}':(6 if a=='idle' else 8,(256,256),('e','s','w','n'),True) for a in ('idle','walk') for p in (1,2,3)},
 'auto':(6,(256,256),('e','s','w','n'),False),
 'spell_a':(8,(256,256),('e','s','w','n'),False),'spell_b':(8,(256,256),('e','s','w','n'),False),
 'trans_p2':(8,(256,256),('s',),False),'trans_p3':(8,(256,256),('s',),False),'death':(10,(256,256),('s',),False),
 'crystal_block':(6,(128,192),('s',),True),'stalactite':(6,(128,384),('s',),False),
 'shard':(4,(64,32),('s',),True),'prism_beam':(6,(1024,96),('s',),True),
 'orbit_shard':(8,(64,96),('s',),True),'lamp_glow':(8,(256,256),('s',),True),
 'reflect_burst':(6,(192,384),('s',),False)}
EXTRAS={'crystal_block','stalactite','shard','prism_beam','orbit_shard','lamp_glow','reflect_burst'}

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
    txt+='\n'.join(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/crystal_mother/{a}.png" id="{a}"]' for a in sheets)+'\n\n'
    txt+='\n'.join(frames)+'\n[resource]\nanimations = ['+',\n'.join(anims)+']\n'
    target=DST/'crystal_mother.tres'
    if not target.exists() or target.read_text(encoding='utf-8')!=txt:
        target.write_text(txt,encoding='utf-8')


def palette():
    import boss_common as c
    def mat(n,h,emit=0):
        rgb=tuple((v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4) for v in [int(h[i:i+2],16)/255 for i in (0,2,4)])
        m=c.material(n,rgb,0,.64,emit)
        if emit:m['rainfall_emissive']=True
        return m
    return [mat('Milk salt 9AA6AC','9AA6AC'),mat('Pearl salt C9D3D6','C9D3D6'),mat('Cold cleavage edge','D8E9ED'),mat('Salt-entombed bone','B9B6AB'),mat('ONLY cyan geode','BFF4FF',1.6)]


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


def build():
    import bpy, boss_common as c, iso_rig
    from mathutils import Vector
    from ash_lord_build import mesh
    s=iso_rig.create_rig('CREA',256);s.camera.data.ortho_scale=4.75
    s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,4.75*(196.5/256-.5),0))
    s['c8c_height_u']=3.4;s['c8c_hem_pivot']=[128,215]
    cold_rim(s)
    milk,pearl,edge,bone,glow=palette()
    root=c.empty('CRYSTAL_MOTHER_3_4U');body=c.empty('Hollow salt reliquary',parent=root)
    panels=[];veins=[];crown=[];arms=[];veil=[];lamps=[]
    # A hollow skirt: each great crystal is separately rigged. Phase three opens real holes.
    for j in range(13):
        a=j*math.tau/13
        r=.63+.07*math.sin(j*4.7);h=1.65+.24*math.sin(j*2.7)
        p=prism('Great milk-salt skirt prism',(.73*math.sin(a),.57*math.cos(a),h/2+.065),.25,h,pearl if j%3 else milk,body,(-.26*math.sin(a),-.19*math.cos(a)),j)
        panels.append((p,a))
        v=c.tube('Light trapped in long cleavage',[(.76*math.sin(a),.61*math.cos(a),.22),(.66*math.sin(a+.07),.55*math.cos(a+.07),.65),(.59*math.sin(a-.03),.49*math.cos(a-.03),1.18),(.45*math.sin(a),.37*math.cos(a),1.65)],.017,glow,p.parent)
        veins.append(v)
        if j in (2,6,10):
            lamps.append(prism('Internally lit salt lamp',(.63*math.sin(a),.56*math.cos(a),.86),.095,1.20,glow,body,seed=j))
    # Sternum and rib cage are striated salt; the front stays a jagged open geode.
    for side in (-1,1):
        prism('Waisted salt flank',(side*.30,.08,1.97),.22,.94,milk,body,(side*.10,0),side)
        prism('Shoulder cleavage',(side*.48,.02,2.46),.26,.46,pearl,body,(side*.10,0),2+side)
        for j in range(5):
            c.tube('Striated mineral rib',[(side*.05,-.03,2.53-j*.095),(side*.24,-.20,2.49-j*.10),(side*.41,-.05,2.42-j*.11)],.026,edge if j%2 else milk,body)
    prism('Spinal salt column',(0,.20,2.15),.18,1.12,pearl,body,seed=5)
    heart=c.empty('White cyan heart geode',(0,-.25,2.14),body)
    prism('Luminous heart cavity',(0,0,0),.25,.59,glow,heart,seed=3)
    inner=prism('Pendant heart visible through shattered skirt',(0,.25,-.64),.14,1.12,glow,heart,seed=7)
    for j in range(7):
        a=j*math.tau/7
        prism('Heart geode teeth',(.25*math.sin(a),-.015,.31*math.cos(a)),.065,.24,edge,heart,(.03*math.sin(a),0),j)
    # Opaque milky front slivers veil the heart in phase one, then part.
    for j in range(3):veil.append(prism('Milky sternum veil',((j-1)*.115,-.49,2.17),.10,.73,pearl,body,seed=j))
    for j in range(9):
        a=j*math.tau/9
        h=.49+.20*(.5+.5*math.sin(j*2.2))
        crown.append(prism('Faceless cleft crown',(.24*math.sin(a),.19*math.cos(a),2.72+h/2),.105,h,pearl if j%2 else milk,body,(.10*math.sin(a),.08*math.cos(a)),j))
    # No head sphere, face, hands or legs. Six serrated stalactite arms hang from shoulders.
    for side in (-1,1):
        for j in range(3):
            ar=c.empty('Stalactite shoulder '+str((side,j)),(side*(.61+.18*j),.19-j*.22,2.48-.07*j),body);arms.append(ar)
            ob=prism('Long translucent stalactite arm',(side*.25,-.045,-.70),.12,1.34+.10*j,pearl if j%2 else milk,ar,(0,0),j)
            ob.rotation_euler.y=-side*.18;ob.rotation_euler.x=math.pi
            c.tube('Transmitted cold arm edge',[(side*.12,-.10,-.12),(side*.25,-.11,-.70),(side*.36,-.06,-1.35)],.018,edge,ar)
            prism('Transmitted arm inclusion',(side*.25,-.10,-.68),.026,.78,glow,ar,seed=j)
    # A thin black puddle, preserved below the cel shadow floor; pale mineral waterline.
    water=bpy.data.materials.new('Black drowned water');water.use_nodes=True
    nd=water.node_tree.nodes;nd.clear();o=nd.new('ShaderNodeOutputMaterial');e=nd.new('ShaderNodeEmission');e.inputs[0].default_value=(.010,.016,.019,1);water.node_tree.links.new(e.outputs[0],o.inputs[0])
    verts=[(0,0,.012)]+[(.70*math.sin(j*math.tau/48),.70*math.cos(j*math.tau/48),.012) for j in range(48)]
    mesh('Black water under salt',verts,[(0,1+j,1+(j+1)%48) for j in range(48)],water,root)
    c.tube('Pale crystal reflection on waterline',[(.70*math.sin(j*math.tau/48),.70*math.cos(j*math.tau/48),.015) for j in range(49)],.014,edge,root)
    for j in range(9):
        a=j*2.4;x=.67*math.sin(a);y=.51*math.cos(a)
        c.rod('Bone sealed into salt',(x-.10,y,.065),(x+.11,y+.04,.14),.033,bone,body)
        sh=prism('Calcified shell',(x,y-.06,.09),.10,.13,bone,body,seed=j);sh.rotation_euler.x=1.1
        for k in range(2):c.tube('Shell growth ridge',[(x-.07,y-.09+k*.025,.08),(x,y-.11+k*.025,.16),(x+.06,y-.08+k*.025,.08)],.012,edge,body)
    # Fracture light is a discontinuous line, opened through the central heart in death.
    crack=c.tube('Heart fatal fissure',[(-.08,-.525,2.40),(.035,-.54,2.28),(-.04,-.55,2.15),(.06,-.53,1.96)],.025,glow,body)
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in root.children_recursive}
    def pose(a,i,n):
        for o,(l,r,sc) in rest.items():o.location=l;o.rotation_euler=r;o.scale=sc;o.hide_render=False
        u=i/max(1,n-1);t=i/n;wave=math.sin(t*math.tau)
        ph=3 if a.endswith('p3') or a=='death' else 2 if a.endswith('p2') or a in ('spell_a','spell_b') else 1
        if a=='trans_p2':ph=1+u
        if a=='trans_p3':ph=2+u
        light=max(.001,min(1,ph-1));opening=max(0,ph-2)
        inner.scale=(max(.001,opening),)*3
        for v in veins+lamps:v.scale=(light,)*3
        for j,v in enumerate(veil):v.location.x+=(j-1)*(.11*(ph-1)+.15*opening);v.scale.x=max(.18,1-.6*(ph-1))
        heart.scale=(1+.28*(ph-1)+.035*wave,)*3
        for p,theta in panels:
            gap=opening*(.28+.04*wave)
            p.location.x+=gap*math.sin(theta);p.location.y+=gap*.8*math.cos(theta)
            p.rotation_euler.y=opening*.12*math.sin(theta)
        for j,o in enumerate(crown):
            o.location.x+=opening*.11*math.sin(j*math.tau/9);o.rotation_euler.y=opening*.24*math.sin(j*math.tau/9)
        for j,ar in enumerate(arms):ar.rotation_euler.x=.035*math.sin(t*math.tau+j*.55)
        body.location.z+=.018*wave
        if a.startswith('walk'):
            body.location.y=.07*wave;body.rotation_euler.z=.025*wave
            for j,(p,theta) in enumerate(panels):p.rotation_euler.x+=.045*math.sin(t*math.tau+j*.6)
        if a=='auto':
            arms[3].rotation_euler.x=[0,-.30,-.80,-1.72,-.55,0][i]
            arms[3].rotation_euler.y=[0,.08,.18,.48,.16,0][i];body.rotation_euler.z=[0,-.05,-.09,.15,.06,0][i]
        if a=='spell_a':
            q=[0,-.5,-1.30,-2.25,.48,.20,.07,0][i]
            for j,ar in enumerate(arms):ar.rotation_euler.x=q;ar.rotation_euler.y=(-1 if j<3 else 1)*abs(q)*.15
            body.location.z+=[0,.02,.06,.09,-.12,-.06,-.02,0][i]
        if a=='spell_b':
            pulse=[1,.88,.68,.50,1.75,1.35,1.08,1][i];heart.scale=tuple(v*pulse for v in heart.scale)
            for j,ar in enumerate(arms):ar.rotation_euler.x=-[0,.15,.30,.50,1.10,.6,.2,0][i]
            body.rotation_euler.x=[0,-.04,-.09,-.13,.16,.08,.02,0][i]
        crack.scale=(.001,)*3
        if a=='death':
            crack.scale=(min(1,.15+u*3),)*3
            for j,(p,theta) in enumerate(panels):
                f=max(0,(u-.08)/.92);p.location.x+=.34*f*math.sin(theta);p.location.y+=.28*f*math.cos(theta);p.location.z=max(.10,p.location.z-1.15*f);p.rotation_euler.y+=f*.95*math.sin(theta)
            for j,ar in enumerate(arms):ar.rotation_euler.y=(-1 if j<3 else 1)*u*.65;ar.location.z-=u*1.3
            for j,o in enumerate(crown):o.location.z-=u*u*2.1;o.location.x+=math.sin(j*2.4)*u*.55;o.rotation_euler.y+=u*1.8
            heart.location.z-=u*.76
            for o in heart.children_recursive:o.hide_render=i==n-1
            for ob in body.children:
                if ob.name.startswith(('Waisted','Shoulder cleavage','Striated mineral rib','Spinal','Milky sternum')):
                    ob.location.z-=u*1.85;ob.rotation_euler.y+=u*.55
            crack.hide_render=i==n-1
            for v in veins+lamps:v.hide_render=u>.65
            for ar in arms:
                for ob in ar.children:
                    if ob.name.startswith('Transmitted arm inclusion'):ob.hide_render=u>.65
    return root,pose


def extra(a):
    import bpy, boss_common as c, iso_rig
    from mathutils import Vector
    from ash_lord_build import mesh
    n,(w,h),_,_=SPECS[a];ground=a in ('shard','prism_beam','lamp_glow')
    s=iso_rig.create_rig('TOP' if ground else 'CREA',(w,h));s.camera.data.ortho_scale=w/(64 if ground else 90.5)
    if not ground:s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(h/2-7)/90.5,0))
    if a=='prism_beam':s.camera.location.x=8
    milk,pearl,edge,bone,glow=palette();cold_rim(s)
    root=c.empty('Crystal mother '+a);moving=[];debris=[]
    if a=='crystal_block':
        moving.append(prism('One unit salt block',(0,0,.64),.50,1.28,pearl,root,seed=3))
        prism('Light in block',(0,-.32,.65),.15,.72,glow,root,seed=4)
        for j in range(4):prism('Block splinter',((j-1.5)*.22,.10,.34),.13,.62,milk,root,seed=j)
    elif a=='stalactite':
        ob=prism('Falling pointed stalactite',(0,0,1.0),.29,1.7,pearl,root,seed=2);ob.rotation_euler.x=math.pi;moving.append(ob)
        prism('Cyan ice needle',(0,-.16,1.0),.06,1.38,glow,ob,seed=3).location.z=0
        for j in range(7):
            th=j*2.4;debris.append(prism('Impact salt chips',(.42*math.sin(th),.30*math.cos(th),.12),.07,.30,edge,root,seed=j))
    elif a=='orbit_shard':
        pivot=c.empty('Spinning shard',(0,0,.47),root);moving.append(pivot)
        prism('Orbit salt shard',(0,0,0),.20,.84,pearl,pivot,seed=2)
        prism('Orbit luminous interior',(0,-.13,0),.04,.60,glow,pivot,seed=4)
    elif a=='reflect_burst':
        for j in range(13):
            th=j*2.4;hh=3.9 if j==0 else 1.2+(j%4)*.54
            ob=prism('Erupting crystalline spear',(.0 if j==0 else .60*math.sin(th),.0 if j==0 else .32*math.cos(th),hh/2),.16,hh,glow if j%4==0 else pearl,root,(.14*math.sin(th),.08*math.cos(th)),j);moving.append(ob)
    elif a=='shard':
        ob=prism('Projectile salt blade',(.18,0,.06),.13,.60,pearl,root,seed=1);ob.rotation_euler.y=math.pi/2;moving.append(ob)
        for j in range(3):
            ob=prism('Cyan projectile wake',(-.12-j*.1,(j-1)*.055,.025),.025,.30-j*.06,glow,root,seed=j);ob.rotation_euler.y=math.pi/2;moving.append(ob)
    elif a=='prism_beam':
        for j in range(7):
            verts=[]
            for k in range(65):
                x=k*.25;wid=.018+.020*math.sin(k*.7+j)**2;yy=(j-3)*.12+.033*math.sin(k*.9+j)
                verts.extend(((x,yy-wid,.02+j*.002),(x,yy+wid,.02+j*.002)))
            moving.append(mesh('Straight refractive ray filament',verts,[(2*k,2*k+1,2*k+3,2*k+2) for k in range(64)],glow,root))
        for j in range(30):
            ob=prism('Ray crystalline caustic',(.2+j*.53,0,.03),.095,.24,edge if j%3 else glow,root,seed=j);ob.rotation_euler.y=math.pi/2
    elif a=='lamp_glow':
        # Radial alpha generated in Blender geometry/shader, never painted in PIL.
        mat=bpy.data.materials.new('Soft radial white cyan lamp');mat.use_nodes=True
        nd=mat.node_tree.nodes;nd.clear();ln=mat.node_tree.links
        out=nd.new('ShaderNodeOutputMaterial');em=nd.new('ShaderNodeEmission');em.inputs[0].default_value=(.52,.90,1,1)
        trans=nd.new('ShaderNodeBsdfTransparent');mix=nd.new('ShaderNodeMixShader');attr=nd.new('ShaderNodeVertexColor');attr.layer_name='Lamp radial alpha'
        ln.new(attr.outputs['Alpha'],mix.inputs[0]);ln.new(trans.outputs[0],mix.inputs[1]);ln.new(em.outputs[0],mix.inputs[2]);ln.new(mix.outputs[0],out.inputs[0])
        aov=nd.new('ShaderNodeOutputAOV');aov.aov_name=cel.AOV
        lamp_aov=nd.new('ShaderNodeVectorMath');lamp_aov.operation='SCALE';ln.new(attr.outputs['Color'],lamp_aov.inputs[0]);ln.new(lamp_aov.outputs[0],aov.inputs['Color'])
        verts=[]
        for k in range(25):
            for j in range(64):th=j*math.tau/64;r=1.97*k/24;verts.append((r*math.cos(th),r*math.sin(th),.01))
        ob=mesh('Soft circular lamp disc',verts,[(k*64+j,k*64+(j+1)%64,(k+1)*64+(j+1)%64,(k+1)*64+j) for k in range(24) for j in range(64)],mat,root);moving.append(ob)
        col=ob.data.color_attributes.new(name='Lamp radial alpha',type='FLOAT_COLOR',domain='POINT')
        for k in range(25):
            alpha=.24*(1-(k/24)**1.4)**2
            for j in range(64):col.data[k*64+j].color=(.52,.90,1,alpha)
    rest={o:(o.location.copy(),o.scale.copy(),o.rotation_euler.copy()) for o in moving}
    def pose(anim,i,n):
        u=i/max(1,n-1);t=i/n
        for o,(l,sc,r) in rest.items():o.location=l;o.scale=sc;o.rotation_euler=r
        for j,o in enumerate(moving):
            if a=='stalactite':o.location.z=4.0-3.08*min(1,u*1.7);o.rotation_euler.z=.05*math.sin(t*math.tau)
            elif a=='orbit_shard':o.rotation_euler.z=t*math.tau;o.rotation_euler.y=.18*math.sin(t*math.tau);o.location.z+=.02*math.sin(t*math.tau)
            elif a=='reflect_burst':
                q=[.08,.36,.78,1,.72,.35][i];o.scale.z=q;o.location.z=rest[o][0].z*q;o.rotation_euler.y=(j%3-1)*u*.32
            elif a=='prism_beam':o.location.y=.025*math.sin(t*math.tau+j*.7)
            elif a=='lamp_glow':
                o.scale=(1-.012*(1-math.cos(t*math.tau)),)*3
                pulse=.9+.1*math.sin(t*math.tau);em.inputs['Strength'].default_value=pulse;lamp_aov.inputs['Scale'].default_value=pulse
            elif a=='shard':o.location.y+=.012*math.sin(t*math.tau+j);o.rotation_euler.x+=.13*math.sin(t*math.tau+j)
            else:
                o.rotation_euler.z=.025*math.sin(t*math.tau);o.scale.x=1+.025*math.cos(t*math.tau)
        for j,o in enumerate(debris):o.scale=(max(.001,(u-.5)*2),)*3;o.rotation_euler.y=u*(j%3-1)
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
    inv=DST/'inventory.json'
    if not inv.exists():
        inv.write_text(json.dumps({p.name:{'size':Image.open(p).size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in DST.glob('*.png')},indent=2))
    root,pose=build()
    cel.install('boss', normals=False)
    cel.setup_scene();cel.toon_materials('boss')
    bpy.context.preferences.filepaths.save_version=0
    source=ROOT/'art/blender/bosses/crystal_mother_iso.blend';source.parent.mkdir(parents=True,exist_ok=True)
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
    with tempfile.TemporaryDirectory(prefix='rainfall_c8c_') as td:
        tmp=Path(td)
        for a in selected:
            n,(w,h),dirs,loop=SPECS[a]
            if a in EXTRAS:root,pose=extra(a)
            elif bpy.context.scene.get('iso_rig')!='CREA' or root.name!='CRYSTAL_MOTHER_3_4U':root,pose=build()
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
                print('C8C DONE '+name,flush=True)
    resource()

def verify():
    from PIL import Image
    import numpy as np
    report={}
    for a,(n,(w,h),dirs,_) in SPECS.items():
        for part,start in enumerate(range(0,n,4096//w)):
            count=min(4096//w,n-start);name=a if part==0 else a+'_'+str(part+1)
            ims=[Image.open(DST/f'{name}.png').convert('RGBA')]
            d=np.asarray(ims[0])
            assert ims[0].size==(count*w,len(dirs)*h) and max(ims[0].size)<=4096,name
            assert not (DST/f'{name}_n.png').exists(),name+' forbidden normal'
            ep=DST/f'{name}_e.png'
            if ep.exists():
                with Image.open(ep) as em:
                    assert em.size==((ims[0].width+1)//2,(ims[0].height+1)//2),name+' emission size'
                    ea=np.asarray(em.convert('RGBA'),dtype=float)
                    assert (ea[:,:,:3].max(axis=2)*ea[:,:,3]/255).max()>2,name+' empty emission'
            hashes=[]
            for row in range(len(dirs)):
                for i in range(count):
                    cell=d[row*h:(row+1)*h,i*w:(i+1)*w];assert cell[:,:,3].max()>8,(name,row,i,'empty')
                    hashes.append(hashlib.sha256(cell.tobytes()).hexdigest())
            assert len(hashes)==len(set(hashes)),(name,'duplicate')
            report[name]={'size':ims[0].size,'emission':ep.exists(),'unique_cells':len(hashes)}
    body=np.asarray(Image.open(DST/'idle_p1.png').convert('RGBA'));mask=body[:,:,3]>250
    mean=float(body[:,:,:3][mask].mean());assert mean>=90,mean
    # One final board only. Real-size sprites, shared background, Reclus same 256px cell.
    board=Image.new('RGBA',(1536,1856),'#2E3238')
    spots=[('idle_p1',0,1),('idle_p1',1,2),('idle_p1',2,3),('idle_p1',3,4),('idle_p2',1,2),('idle_p3',1,2),('auto',1,2),('auto',1,3),('spell_a',1,3),('spell_a',1,4),('spell_b',1,3),('spell_b',1,4),('trans_p2',0,4),('trans_p3',0,5),('death',0,5),('death',0,9)]
    for idx,(a,r,i) in enumerate(spots):
        im=Image.open(DST/f'{a}.png').convert('RGBA').crop((i*256,r*256,(i+1)*256,(r+1)*256));board.alpha_composite(im,((idx%6)*256,(idx//6)*256))
    rp=ROOT/'game/assets/sprites/bosses/etage/recluse/idle_p1.png'
    if rp.exists():board.alpha_composite(Image.open(rp).convert('RGBA').crop((256,256,512,512)),(1024,512))
    for idx,a in enumerate(('crystal_block','stalactite','orbit_shard','reflect_burst','lamp_glow','shard')):
        w,h=SPECS[a][1];i=3 if a!='orbit_shard' else 2
        im=Image.open(DST/f'{a}.png').convert('RGBA').crop((i*w,0,(i+1)*w,h));board.alpha_composite(im,(idx*256+(256-w)//2,768))
    board.alpha_composite(Image.open(DST/'prism_beam.png').convert('RGBA').crop((1024,0,2048,96)),(256,1160))
    for idx,rel in enumerate(('art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/night/_cs1_contact.png')):
        im=Image.open(ROOT/rel).convert('RGBA')
        if idx==3:im=im.crop((im.width//2,0,im.width,im.height))
        im.thumbnail((368,480),Image.Resampling.LANCZOS);board.alpha_composite(im,(idx*384,1300))
    board.convert('RGB').save(HERE/'_c8c_contact.png',compress_level=9)
    report['body_mean_srgb']=round(mean,2)
    (DST/'verification.json').write_text(json.dumps(report,indent=2))
    print('PASS C8c',len(report)-1,'atlases; grids/emission/no normals/unique frames; body mean',round(mean,1))

if __name__=='__main__':
    if '--verify' in sys.argv:verify()
    else:main()
