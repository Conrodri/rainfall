"""C8d / Deep eel. Background Blender, shared C7/cel pipeline; resumable by sheet.
Run with Blender --background --python this_file. --only comma,separated,sheets.
Python this_file --verify assembles the sole contact sheet and checks contracts.
"""
import sys, math, json, hashlib, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
DST=ROOT/'game/assets/sprites/bosses/etage/deep_eel'
sys.path[:0]=[str(ROOT/'art/tools'/p) for p in ('cel','iso','monsters','bosses')]
import cel_style as cel
SPECS={**{f'{a}_p{p}':(6 if a=='idle' else 8,(256,256),('e','s','w','n'),True) for a in ('idle','walk') for p in (1,2,3)},
 'auto':(6,(256,256),('e','s','w','n'),False),
 'spell_a':(8,(256,256),('e','s','w','n'),False),'spell_b':(8,(256,256),('e','s','w','n'),False),
 'trans_p2':(8,(256,256),('s',),False),'trans_p3':(8,(256,256),('s',),False),'death':(10,(256,256),('s',),False),
 'black_pool':(8,(896,896),('s',),True),'puddle':(6,(128,128),('s',),True),
 'wake':(6,(128,128),('s',),True),'emerge_splash':(6,(192,384),('s',),False),
 'discharge_ring':(6,(256,256),('s',),False),'whip':(8,(448,77),('s',),True)}
EXTRAS={'black_pool','puddle','wake','emerge_splash','discharge_ring','whip'}

def resource():
    """Text SpriteFrames; split the 14u ray into two four-frame atlases."""
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
    txt+='\n'.join(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/deep_eel/{a}.png" id="{a}"]' for a in sheets)+'\n\n'
    txt+='\n'.join(frames)+'\n[resource]\nanimations = ['+',\n'.join(anims)+']\n'
    (DST/'deep_eel.tres').write_text(txt,encoding='utf-8')


# Geometry is evaluated in Blender. Pillow only assembles/resizes/verifies renders.
def build():
    import bpy, boss_common as c, iso_rig
    from mathutils import Vector
    s=iso_rig.create_rig('CREA',256)
    bpy.data.objects['Sun_chaud_haut_gauche'].data.color=(.72,.86,1.0)
    s.camera.data.ortho_scale=5.72
    # Ground contact of the forward maw sits at y=210; no fauna/code changes.
    s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,5.32*(164/256-.5),0))
    s['c8d_pivot']=[128,210];s['c8d_length_u']=3.8
    root=c.empty('DEEP_EEL_3_8U')
    palette=[('Pearl salt skin','98A2A6'),('Lifted salt scutes','B6C2C5'),
             ('Chalk fracture','C4CCCE'),('Translucent bone blade','AFBDC2'),
             ('Under-skin drowned tissue','667E85'),('Mouth abyss','17242B'),
             ('Ivory needle teeth','D5D9CB'),('Black water','18242B'),
             ('Cold crystal reflection','9DAFB8'),('Only accent BFF4FF','BFF4FF')]
    mats=[]
    for j,(name,h) in enumerate(palette):
        rgb=tuple(((int(h[k:k+2],16)/255+.055)/1.055)**2.4 for k in (0,2,4))
        m=c.material(name,rgb,0,.7,1.25 if j==9 else 0)
        if j==9:m['rainfall_emissive']=True
        mats.append(m)
    data=bpy.data.meshes.new('Swept continuous eel with overlapping salt armour')
    body=bpy.data.objects.new('Anguilla - salt, broken bone and lantern',data)
    bpy.context.collection.objects.link(body);body.parent=root
    for m in mats:data.materials.append(m)

    def geometry(a,i,n):
        if a=='walk_p3':a='idle_p3'
        verts=[];faces=[];indices=[]
        t=i/n;cy=math.sin(math.tau*t);peak=max(0,1-abs(i-n//2)/(n*.44))**1.5
        p=3 if 'p3' in a or a=='death' else 2 if 'p2' in a else 1
        strand=1 if p==3 else 0
        if a=='trans_p3':strand=i/(n-1)
        if a=='death':strand=1
        jaw=.08+(.08*cy if a.startswith('idle') else 0)
        if a=='auto':jaw=.12+1.05*max(0,1-abs(i-2)/2);jaw=.10 if i==3 else jaw
        if a=='spell_a':jaw=.30+.25*peak
        def add(v,f,m):
            k=len(verts);verts.extend(v);faces.extend(tuple(k+j for j in face) for face in f);indices.extend([m]*len(f))
        def tube(points,r,m,sides=6):
            vv=[]
            for k,pt in enumerate(points):
                axis=Vector(points[min(k+1,len(points)-1)])-Vector(points[max(0,k-1)])
                q=axis.to_track_quat('Z','Y')
                vv.extend(tuple(Vector(pt)+q@Vector((r*math.cos(j*math.tau/sides),r*math.sin(j*math.tau/sides),0))) for j in range(sides))
            ff=[tuple(range(sides-1,-1,-1)),tuple(range((len(points)-1)*sides,len(points)*sides))]
            ff += [(k*sides+j,k*sides+(j+1)%sides,(k+1)*sides+(j+1)%sides,(k+1)*sides+j) for k in range(len(points)-1) for j in range(sides)]
            add(vv,ff,m)
        def diamond(pos,xx,yy,zz,m):
            x,y,z=pos
            add([(x-xx,y,z),(x,y-yy,z),(x+xx,y,z),(x,y+yy,z),(x,y,z+zz)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)],m)
        def centre(u):
            # Tail -> head; arch disappears into the entry rings at each end.
            x=(.10+.42*strand)*math.sin(u*math.tau*1.08+.15*math.sin(math.tau*t+u*3))*(math.sin(math.pi*u)**.5)
            y=1.84-3.68*u
            z=.12+(.72+.08*cy)*(math.sin(math.pi*u)**.8)*(1-strand)+(.30+.035*cy)*strand
            if a.startswith('walk') and p!=3:x+=.22*math.sin(u*math.tau*1.5+math.tau*t)
            if a=='auto':y-=.30*peak*u;z+=.12*peak*u
            if a=='spell_a':z=z*(1-peak)+(.85+.12*math.sin(math.pi*u))*peak;y-=.13*peak;x*=1-.8*peak
            if a=='spell_b':x+=.55*peak*math.sin(u*math.tau);y*=1-.25*peak;z+=.15*peak
            if a=='trans_p2':z+=.40*peak*math.sin(math.pi*u)
            if a=='trans_p3':z+=.22*peak*math.sin(math.pi*u)
            if a=='death':x+=.18*math.sin(u*12+i*.8)*(1-t);z*=1-.42*t
            return Vector((x,y,z))
        def radius(u):return .035+.30*math.sin(math.pi*min(1,u*1.12)/2)**.65
        def surf(u,angle,offset=0):
            v=centre(u);r=radius(u)+offset
            return v+Vector((r*math.cos(angle),0,r*.79*math.sin(angle)))
        vv=[];segments=40;sides=16
        for k in range(segments+1):
            u=k/segments
            for j in range(sides):vv.append(tuple(surf(u,math.tau*j/sides)))
        ff=[tuple(range(sides-1,-1,-1)),tuple(range(segments*sides,(segments+1)*sides))]
        ff += [(k*sides+j,k*sides+(j+1)%sides,(k+1)*sides+(j+1)%sides,(k+1)*sides+j) for k in range(segments) for j in range(sides)]
        add(vv,ff,0)
        # Large, staggered, overlapping rhomboid scutes, individually broken in p3.
        for k in range(3,35):
            u=k/38
            for j in range(7):
                ang=-.38+j*.52;off=.012
                missing=(k*7+j*11)%13<3
                mm=4 if p==3 and missing else 1 if (k+j)%3 else 2
                points=[surf(max(.02,u-.030),ang,off),surf(u,ang-.28,off),surf(min(.96,u+.040),ang,off),surf(u,ang+.28,off),surf(u,ang,off+.036)]
                add([tuple(v) for v in points],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],mm)
        # Serrated dorsal comb: thin translucent bone with split tips and cyan root.
        for k in range(4,30,2):
            u=k/36;base=surf(u,math.pi/2,.025);back=surf(u-.055,math.pi/2,.02)
            height=(.18+.20*math.sin(u*math.pi))*(1+.45*strand)
            tip=base+Vector((.01,.13,height));cut=base+Vector((0,.065,height*.47))
            add([tuple(back+Vector((-.026,0,0))),tuple(base+Vector((-.026,0,0))),tuple(tip),tuple(cut),tuple(back+Vector((.026,0,0))),tuple(base+Vector((.026,0,0)))],[(0,1,2,3),(4,3,2,5),(0,4,5,1),(1,5,2)],3)
            # Crystal incrustations cluster asymmetrically, not decorative spikes everywhere.
            if k%4==0:
                v=surf(u,.75,.035);diamond(v,.065,.082,.15+(k%3)*.035,2)
        # Long subdermal lateral nerves, separated by scar tissue; death fades tail-first.
        for side in (-1,1):
            for k in range(2,34):
                u=k/36;angle=.16 if side==1 else math.pi-.16
                active=a!='death' or u>i/(n-1)*1.15
                rr=(.014 if p==1 else .023 if p==2 else .033)
                v1=surf(u,angle,.017);v2=surf((k+1)/36,angle,.017)
                tube([v1,v2],rr,9 if active else 4)
                if p>=2:
                    v3=surf(u+.018,angle+.34,.025)
                    tube([v1,v3],.011,9 if active else 4)
        # Head: flattened spade with no visible paired eyes; the light organ is unpaired.
        h=centre(.985);r=.35
        hx,hy,hz=h
        add([(hx-r,hy+.20,hz+.14),(hx+r,hy+.20,hz+.14),(hx+.31,hy-.30,hz+.10),(hx-.31,hy-.30,hz+.10),
             (hx-.27,hy+.12,hz-.06),(hx+.27,hy+.12,hz-.06),(hx+.25,hy-.34,hz-.035),(hx-.25,hy-.34,hz-.035)],
             [(0,1,2,3),(0,4,5,1),(0,3,7,4),(1,5,6,2),(3,2,6,7)],1)
        # Open black mouth and hinged underjaw, surrounded by backward needle teeth.
        mouthz=hz-.08-jaw*.17
        add([(hx-.27,hy-.33,hz-.03),(hx+.27,hy-.33,hz-.03),(hx+.25,hy-.35,mouthz-.10),(hx-.25,hy-.35,mouthz-.10)],[(0,1,2,3)],5)
        add([(hx-.25,hy+.09,hz-.1),(hx+.25,hy+.09,hz-.1),(hx+.27,hy-.36,mouthz-.13),(hx-.27,hy-.36,mouthz-.13),
             (hx-.22,hy-.36,mouthz-.19),(hx+.22,hy-.36,mouthz-.19)],[(0,1,2,3),(3,2,5,4),(0,3,4),(1,5,2)],0)
        for j in range(7):
            x=hx-.245+j*.081
            diamond((x,hy-.34,hz-.04),.025,.020,-(.075+.045*(j%2)),6)
            diamond((x,hy-.365,mouthz-.12),.023,.020,.065,6)
        diamond((hx,hy-.12,hz+.155),.075,.13,.025,8)
        diamond((hx,hy-.15,hz+.18),.037,.065,.028,9 if a!='death' or i<n-1 else 4)
        # Entry pools and broken crystal rings. Every pose keeps the tail in water.
        for end in (0,.93):
            v=centre(end);rad=.31 if end==0 else .46
            if strand and end>.5:rad=.08
            N=48
            pv=[(v.x,v.y,.006)]+[(v.x+rad*math.cos(j*math.tau/N),v.y+rad*math.sin(j*math.tau/N),.008) for j in range(N)]
            add(pv,[(0,j+1,(j+1)%N+1) for j in range(N)],7)
            for ring in range(2):
                rr=rad*(1+.19*ring+.08*cy)
                pts=[(v.x+rr*math.cos(j*math.tau/32),v.y+rr*math.sin(j*math.tau/32),.018) for j in range(33)]
                tube(pts,.013 if ring else .019,8)
        # Falling water rivulets beneath the cracked p2 arch.
        for k in range(9):
            u=.16+k*.075;v=surf(u,.12 if k%2 else math.pi-.12,.01)
            length=.12+.20*(.5+.5*math.sin(k*2.1+math.tau*t))
            if p==1:length=.012
            tube([v,v+Vector((.015,.02,-length*.6)),v+Vector((.025,.035,-length))],.012,8)
        # Non-periodic discharge arcs are absent visually outside spell_b.
        for j in range(5):
            theta=j*math.tau/5
            rr=(.8+.35*peak) if a=='spell_b' else .001
            pts=[]
            for k in range(7):
                ang=theta+k*.13;rad=rr*(1+.13*math.sin(k*5+i))
                pts.append((rad*math.cos(ang),rad*math.sin(ang),.25+.17*math.sin(k*1.4+i)**2 if a=='spell_b' else -.3))
            tube(pts,.017+.018*peak if a=='spell_b' else .0001,9)
        # Transition wave expands at the impact, using geometry not painted effects.
        rr=.30+1.15*peak if a=='trans_p2' else .001
        tube([(rr*math.cos(j*math.tau/48),rr*math.sin(j*math.tau/48),.045 if a=='trans_p2' else -.4) for j in range(49)],.025 if a=='trans_p2' else .0001,8)
        return verts,faces,indices
    def pose(a,i,n):
        # walk_p3 is the same stranded respiration sampled over eight frames.
        verts,faces,ids=geometry(a,i,n)
        data.clear_geometry();data.from_pydata(verts,[],faces);data.update()
        for poly,idx in zip(data.polygons,ids):poly.material_index=idx
    pose('idle_p1',0,6)
    pose.geometry=geometry;pose.mesh=body
    return root,pose

def save_source(root,pose,path):
    import bpy
    fit_body(root,pose)
    body=pose.mesh
    body.shape_key_add(name='Basis')
    f=1
    # Editable full timelines, preserving exactly the swept mesh topology.
    for a,(n,_,dirs,_) in SPECS.items():
        if a in EXTRAS:continue
        bpy.context.scene.timeline_markers.new(a,frame=f)
        for i in range(n):
            vv,_,_=pose.geometry(a,i,n)
            key=body.shape_key_add(name=f'{a}_{i:02d}')
            for v,co in zip(key.data,vv):v.co=co
            key.value=0;key.keyframe_insert('value',frame=max(0,f+i-1))
            key.value=1;key.keyframe_insert('value',frame=f+i)
            key.value=0;key.keyframe_insert('value',frame=f+i+1)
        f+=n
    bpy.context.scene.frame_end=f-1;bpy.context.scene.render.fps=12
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    body.shape_key_clear();pose('idle_p1',0,6)


def fit_body(root,pose):
    import bpy
    from mathutils import Vector
    s=bpy.context.scene;root.location=(0,0,0)
    bpy.context.view_layer.update()
    camera_space=s.camera.matrix_world.inverted()@root.matrix_world
    bottom=.5+min((camera_space@v.co).y for v in pose.mesh.data.vertices)/s.camera.data.ortho_scale
    root.location=s.camera.rotation_euler.to_matrix()@Vector((0,((256-210)/256-bottom)*s.camera.data.ortho_scale,0))

def extra(a):
    import bpy, boss_common as c, iso_rig, random
    from ash_lord_build import mesh, rod, shard
    from mathutils import Vector
    n,(w,h),_,_=SPECS[a]
    s=iso_rig.create_rig('CREA' if a=='emerge_splash' else 'TOP',(w,h))
    s.camera.data.ortho_scale=w/(90.5 if a=='emerge_splash' else 64)
    if a=='emerge_splash':s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(h/2-5)/90.5,0))
    if a=='whip':s.camera.location.x=3.5
    def mat(name,h,emit=0):
        rgb=tuple(((int(h[k:k+2],16)/255+.055)/1.055)**2.4 for k in (0,2,4))
        m=c.material(name,rgb,0,.6,emit)
        if emit:m['rainfall_emissive']=True
        return m
    water=mat('Black drowned water','101C24');edge=mat('Crystal rim reflected in water','9DAFB8')
    rock=mat('Collapsed wet crypt tiles','626D70');salt=mat('Pearl salt deposits','B5C2C5')
    glow=mat('Only accent BFF4FF','BFF4FF',1.3);bone=mat('Tail blade bone','AFBDC2')
    root=c.empty('Deep eel '+a);moving=[];random.seed(845)
    if a in ('black_pool','puddle'):
        radius=6.96 if a=='black_pool' else .975
        N=128 if a=='black_pool' else 64
        # Circular dark mass with a complete crystalline readable lip.
        vv=[(0,0,.005)]+[(radius*math.cos(j*math.tau/N),radius*math.sin(j*math.tau/N),.005) for j in range(N)]
        mesh('Water surface',vv,[(0,j+1,(j+1)%N+1) for j in range(N)],water,root)
        c.ring('Continuous pale salt meniscus',(0,0,.01),radius-.018,.025,edge,root,rotation=(0,0,0))
        for j in range(56 if a=='black_pool' else 15):
            ang=j*math.tau/(56 if a=='black_pool' else 15);rr=radius-(.18 if a=='black_pool' else .03)
            ob=shard('Collapsed tile and crystalline lip',(rr*math.cos(ang),rr*math.sin(ang),.02),(.12+random.random()*.18,.055+random.random()*.10,.045) if a=='black_pool' else (.04,.025,.018),salt if j%3==0 else rock,root)
            ob.rotation_euler.z=ang;moving.append(ob)
        for j in range(8 if a=='black_pool' else 3):
            rr=radius*(.24+j*.085)
            ob=c.tube('Slow faceted ripple',[(rr*math.cos(k*.13+j*.7),rr*math.sin(k*.13+j*.7),.013) for k in range(14)],.012 if a=='black_pool' else .008,edge,root);moving.append(ob)
    elif a=='wake':
        for side in (-1,1):
            moving.append(rod('V wake towards negative X',[(.60,0,.02),(.18,side*.21,.02),(-.85,side*.77,.02)],.025,edge,root))
            rod('V shadow water ridge',[(.60,.025*side,.01),(.15,side*.25,.01),(-.85,side*.82,.01)],.035,water,root)
        moving.append(shard('Submerged lateral lantern',(-.20,0,.005),(.43,.065,.025),glow,root))
    elif a=='discharge_ring':
        # Outer geometry reaches 124px; jagged, discontinuous electrical arcs.
        for j in range(12):
            pts=[]
            for k in range(9):
                ang=(j+k/10)*math.tau/12;r=1.89+(.025 if k%2 else -.065)
                pts.append((r*math.cos(ang),r*math.sin(ang),.02))
            moving.append(rod('Broken cyan electrical corona',pts,.026,glow,root))
            if j%2==0:
                ang=j*math.tau/12
                moving.append(rod('Branching arc',[(r*math.cos(ang),r*math.sin(ang),.02),(1.55*math.cos(ang+.08),1.55*math.sin(ang+.08),.02),(1.30*math.cos(ang+.02),1.30*math.sin(ang+.02),.02)],.022,glow,root))
    elif a=='emerge_splash':
        # Thin sculpted water sheets with broken crests, plus free droplets.
        for j in range(11):
            ang=j*2.4;hh=3.9 if j==0 else 1.1+(j%5)*.52
            xx=.45*math.cos(ang);yy=.24*math.sin(ang)
            ob=mesh('Torn black water ribbon',[(xx-.08,yy,.04),(xx+.08,yy,.04),(xx+.11,yy,hh*.42),(xx+.32,yy,hh*.88),(xx+.24,yy,hh),(xx+.08,yy,hh*.60)],[(0,1,2,5),(5,2,3,4)],water,root);moving.append(ob)
            ob=rod('Cold water edge',[(xx-.08,yy-.012,.05),(xx+.08,yy-.012,hh*.60),(xx+.24,yy-.012,hh)],.018,edge,root);moving.append(ob)
        for j in range(18):
            ob=shard('Black water droplet with crystal glint',(.82*math.cos(j*2.4),.35*math.sin(j*2.4),.5+(j%7)*.47),(.025,.025,.065),glow if j%4==0 else edge,root);moving.append(ob)
    elif a=='whip':
        pts=[(j*6.9/30,.27*math.sin(j/30*math.tau),.02) for j in range(31)]
        ob=rod('Seven-unit whipping salt tail',pts,.095,salt,root);moving.append(ob)
        rod('Under-skin tail nerve',[(x,y-.07,z+.04) for x,y,z in pts],.020,glow,root)
        for j in range(2,29,2):
            x,y,z=pts[j]
            ob=mesh('Scythe fin blade',[(x-.13,y,.02),(x+.16,y,.02),(x+.32,y+.19,.03),(x+.01,y+.13,.03)],[(0,1,2,3)],bone,root);moving.append(ob)
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in moving}
    def pose(a,i,n):
        t=i/n
        for j,o in enumerate(moving):
            l,r,sc=rest[o];o.location=l;o.rotation_euler=r;o.scale=sc
            if a in ('black_pool','puddle'):
                if 'ripple' in o.name.lower():o.scale=(1+.018*math.sin(math.tau*t+j),)*3
                else:o.location.z+=.005*math.sin(math.tau*t+j)
            elif a=='emerge_splash':
                pulse=[.12,.50,.90,1,.67,.24][i];o.scale.z=pulse;o.location.x+=.08*math.sin(j+t*3)*pulse
            elif a=='discharge_ring':
                o.scale=(.83+.17*math.sin(math.pi*(i+1)/(n+1)),)*3;o.rotation_euler.z=.025*math.sin(i*2+j)
            elif a=='wake':o.scale.y=.87+.13*math.sin(math.tau*t+j)
            elif a=='whip':o.location.y+=.06*math.sin(math.tau*t+j*.6)
    return root,pose

def render_frame(path):
    """Shared cel compositor, emission only; render x2 then Lanczos."""
    import bpy, boss_common as c
    from PIL import Image
    s=bpy.context.scene
    c.configure_passes(path)
    water_tones()
    # Thin luminous nerves/arcs must remain legible through the boss ink.
    # Preserve the shared cel shading, recovering only its isolated accent AOV.
    tree=s.compositing_node_group;nodes=tree.nodes;links=tree.links
    out=next(v for v in nodes if v.bl_idname=='NodeGroupOutput')
    rl=next(v for v in nodes if v.bl_idname=='CompositorNodeRLayers')
    lit=nodes.new('ShaderNodeVectorMath');lit.operation='MAXIMUM'
    links.new(out.inputs['Image'].links[0].from_socket,lit.inputs[0])
    links.new(rl.outputs[cel.AOV],lit.inputs[1])
    alpha=nodes.new('CompositorNodeSetAlpha');alpha.inputs['Type'].default_value='Replace Alpha'
    links.new(lit.outputs[0],alpha.inputs['Image']);links.new(rl.outputs['Alpha'],alpha.inputs['Alpha'])
    links.new(alpha.outputs[0],out.inputs['Image'])
    s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    candidates=list(path.parent.glob(path.stem+'_e__*.png'))
    assert len(candidates)==1, str(path)
    ep=path.with_name(path.stem+'_e.png');candidates[0].replace(ep)
    for p in (path,ep):
        with Image.open(p) as im:
            resized=im.convert('RGBA').resize(tuple(s['iso_frame']),Image.Resampling.LANCZOS)
        resized.save(p,compress_level=6)


def water_tones():
    """Only the water is exempt from the creature shadow floor."""
    import bpy
    for mat in bpy.data.materials:
        if mat.name.split('.')[0] not in ('Black water','Black drowned water'):continue
        ramp=mat.node_tree.nodes.get('CEL tones')
        if ramp:
            base=tuple(((c/255+.055)/1.055)**2.4 for c in (16,28,36))
            for el,scale in zip(ramp.color_ramp.elements,cel.TONE_SCALES):
                el.color=tuple(c*scale for c in base)+(1,)


def main():
    import bpy, boss_common as c, iso_rig
    from PIL import Image
    DST.mkdir(parents=True,exist_ok=True)
    inv=HERE/'_c8d_inventory.json'
    if not inv.exists():
        inv.write_text(json.dumps({p.name:{'size':Image.open(p).size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in DST.glob('*.png')},indent=2))
    # Initial inventory was empty: these are new replacements of code-drawn placeholders.
    root,pose=build()
    cel.install('boss', normals=False)
    cel.setup_scene();cel.toon_materials('boss')
    water_tones()
    bpy.context.preferences.filepaths.save_version=0
    source=ROOT/'art/blender/bosses/deep_eel_iso.blend';source.parent.mkdir(parents=True,exist_ok=True)
    if '--only' not in sys.argv:
        save_source(root,pose,source)
    if '--source-only' in sys.argv:return
    selected=sys.argv[sys.argv.index('--only')+1].split(',') if '--only' in sys.argv else list(SPECS)
    cel.install('boss', normals=False)
    with tempfile.TemporaryDirectory(prefix='rainfall_c8d_') as td:
        tmp=Path(td)
        for a in selected:
            n,(w,h),dirs,loop=SPECS[a]
            if a in EXTRAS:root,pose=extra(a)
            elif bpy.context.scene.get('iso_rig')!='CREA' or root.name!='DEEP_EEL_3_8U':root,pose=build()
            s=bpy.context.scene;s['iso_frame']=[w,h];s.render.resolution_x=w*2;s.render.resolution_y=h*2
            cap=4096//w
            for part,start in enumerate(range(0,n,cap)):
                count=min(cap,n-start);name=a if part==0 else a+'_'+str(part+1)
                boards=[Image.new('RGBA',(count*w,len(dirs)*h),(0,0,0,0)) for j in range(2)]
                for row,d in enumerate(dirs):
                    for i in range(start,start+count):
                        pose(a,i,n)
                        if a not in EXTRAS:
                            root.rotation_euler.z=c.DIRECTIONS[d]
                            fit_body(root,pose)
                        bpy.context.view_layer.update();path=tmp/f'{a}_{d}_{i}.png'
                        render_frame(path)
                        for j,suffix in enumerate(('','_e')):
                            with Image.open(path.with_name(path.stem+suffix+'.png')) as im0:im=im0.convert('RGBA')
                            if j==0:alpha=im.getchannel('A')
                            else:im.putalpha(alpha)
                            boards[j].paste(im,((i-start)*w,row*h))
                for board,suffix in zip(boards,('','_e')):board.save(DST/f'{name}{suffix}.png',compress_level=9)
                print('C8D DONE '+name,flush=True)
    align_body_sheets()
    finish_emission()
    resource()
    import_policy()


def align_body_sheets():
    """Final assembly: place the opaque ground contact exactly on the contract line."""
    from PIL import Image
    import numpy as np
    for a,(n,(w,h),dirs,_) in SPECS.items():
        if a in EXTRAS:continue
        if not (DST/f'{a}.png').exists():continue
        # Already aligned sheets with half-size emission need no further assembly.
        if (DST/f'{a}_e.png').exists() and Image.open(DST/f'{a}_e.png').size!=Image.open(DST/f'{a}.png').size:continue
        suffixes=['']+(['_e'] if (DST/f'{a}_e.png').exists() else [])
        sheets=[Image.open(DST/f'{a}{s}.png').convert('RGBA') for s in suffixes]
        for row in range(len(dirs)):
            for i in range(n):
                box=(i*w,row*h,(i+1)*w,(row+1)*h)
                alpha=np.asarray(sheets[0].crop(box))[:,:,3]
                bottom=int(np.where(alpha>128)[0].max());shift=210-bottom
                if not shift:continue
                for j,im in enumerate(sheets):
                    cell=Image.new('RGBA',(w,h),(0,0,0,0))
                    cell.paste(im.crop(box),(0,shift));im.paste(cell,(i*w,row*h))
        for im,suffix in zip(sheets,suffixes):im.save(DST/f'{a}{suffix}.png',compress_level=9)


def finish_emission():
    from PIL import Image
    import numpy as np
    sys.path.insert(0,str(ROOT/'art/tools'))
    from halve_emission import downscale
    for ep in DST.glob('*_e.png'):
        with Image.open(ep) as src:im=src.convert('RGBA')
        a=np.asarray(im)
        if not (a[:,:,:3].max(axis=2)* (a[:,:,3].astype(float)/255)>2).any():
            ep.unlink();continue
        with Image.open(ep.with_name(ep.name[:-6]+'.png')) as diffuse:ds=diffuse.size
        if im.size==ds:im=downscale(im)
        assert im.size==((ds[0]+1)//2,(ds[1]+1)//2),ep.name
        im.save(ep,compress_level=9)


def import_policy():
    """Apply the existing mobile policy only inside this lot."""
    import re
    sys.path.insert(0,str(ROOT/'art/tools'))
    from texture_budget import load_budget,expected_params,_fmt
    budget=load_budget()
    for p in DST.glob('*.png'):
        ip=p.with_suffix('.png.import')
        txt=ip.read_text(encoding='utf-8') if ip.exists() else '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n'
        want=expected_params(p.relative_to(ROOT/'game').as_posix(),budget)
        old=txt
        for k,v in want.items():
            pattern=r'^'+re.escape(k)+r'=.*$';line=k+'='+_fmt(v)
            txt=re.sub(pattern,line,txt,flags=re.M) if re.search(pattern,txt,re.M) else txt.rstrip()+'\n'+line+'\n'
        if txt!=old or not ip.exists():ip.write_text(txt,encoding='utf-8')


def verify():
    from PIL import Image
    import numpy as np
    align_body_sheets()
    report={};all_cells=0
    for a,(n,(w,h),dirs,_) in SPECS.items():
        for part,start in enumerate(range(0,n,4096//w)):
            count=min(4096//w,n-start);name=a if part==0 else a+'_'+str(part+1)
            im=Image.open(DST/f'{name}.png').convert('RGBA');d=np.asarray(im)
            assert im.size==(count*w,len(dirs)*h),name
            assert max(im.size)<=4096,name
            assert not (DST/f'{name}_n.png').exists(),name+' forbidden normal'
            ep=DST/f'{name}_e.png'
            if ep.exists():
                ei=Image.open(ep).convert('RGBA');e=np.asarray(ei)
                assert ei.size==((im.width+1)//2,(im.height+1)//2),name+' emission size'
                assert (e[:,:,:3].max(axis=2)*(e[:,:,3].astype(float)/255)>2).any(),name+' black emission'
            hashes=[];bounds=[]
            for r in range(len(dirs)):
                for col in range(count):
                    cc=d[r*h:(r+1)*h,col*w:(col+1)*w]
                    assert (cc[:,:,3]>240).any(),(name,r,col,'empty')
                    hashes.append(hashlib.sha256(cc.tobytes()).hexdigest())
                    yy,xx=np.where(cc[:,:,3]>128);bounds.append([int(xx.min()),int(yy.min()),int(xx.max()),int(yy.max())])
                    if a not in EXTRAS:assert int(yy.max())==210,(name,r,col,'pivot',int(yy.max()))
            assert len(hashes)==len(set(hashes)),(name,'duplicate frames')
            report[name]={'size':im.size,'emission':ep.exists(),'cells':len(hashes),'bounds':bounds}
            all_cells+=len(hashes)
    arr=np.asarray(Image.open(DST/'idle_p1.png').convert('RGBA'))
    mask=arr[:,:,3]>250
    mean=float(arr[:,:,:3][mask].mean());assert mean>=90,mean
    report['body_mean_srgb']=round(mean,2)
    # Contact assembled once. Actual-size body cells; Mother uses the same game scale.
    board=Image.new('RGBA',(1792,2048),'#2E3238')
    spots=[('idle_p1',0,1),('idle_p1',1,2),('idle_p1',2,3),('idle_p1',3,4),('idle_p2',1,2),('idle_p3',1,2),
           ('auto',1,2),('auto',1,3),('spell_a',0,3),('spell_a',0,4),('spell_b',1,3),('spell_b',1,4),
           ('trans_p2',0,4),('trans_p3',0,6),('death',0,3),('death',0,9),('walk_p1',0,4),('walk_p3',1,3)]
    for idx,(a,r,i) in enumerate(spots):
        im=Image.open(DST/f'{a}.png').convert('RGBA').crop((i*256,r*256,(i+1)*256,(r+1)*256))
        board.alpha_composite(im,((idx%6)*256,(idx//6)*256))
    mother=ROOT/'game/assets/sprites/bosses/etage/crystal_mother/idle_p1.png'
    assert mother.exists(),'Mother-Crystal reference is not available yet'
    im=Image.open(mother).convert('RGBA').crop((0,256,256,512));board.alpha_composite(im,(1536,0))
    pool=Image.open(DST/'black_pool.png').convert('RGBA').crop((0,0,896,896));board.alpha_composite(pool,(0,768))
    for a,x,y,i in [('puddle',960,800,2),('wake',1120,800,2),('discharge_ring',1280,784,3),('emerge_splash',1536,768,3),('whip',960,1080,4)]:
        w,h=SPECS[a][1];im=Image.open(DST/f'{a}.png').convert('RGBA').crop((i*w,0,(i+1)*w,h));board.alpha_composite(im,(x,y))
    # The only visual read includes all approved DA references in the same board.
    for idx,rel in enumerate(('art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/night/_cs1_contact.png')):
        im=Image.open(ROOT/rel).convert('RGBA')
        if idx==3:im=im.crop((im.width//2,0,im.width,im.height))
        im.thumbnail((432,340),Image.Resampling.LANCZOS);board.alpha_composite(im,(idx*448,1680))
    board.convert('RGB').save(HERE/'_c8d_contact.png',compress_level=9)
    (HERE/'_c8d_verify.json').write_text(json.dumps(report,indent=2))
    print(f'PASS C8D: {len(report)-1} atlases, {all_cells} unique nonempty cells, no normals, half emission; body mean {mean:.1f}')


if __name__=='__main__':
    if '--verify' in sys.argv:verify()
    else:main()
