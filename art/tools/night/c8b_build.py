"""C8b / Semeur de pluie. Background Blender, shared C7/cel pipeline; resumable by sheet.
Run with Blender --background --python this_file. --only comma,separated,sheets.
Python this_file --verify assembles the sole contact sheet and checks contracts.
"""
import sys, math, json, hashlib, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
DST=ROOT/'game/assets/sprites/bosses/etage/rain_sower'
sys.path[:0]=[str(ROOT/'art/tools'/p) for p in ('cel','iso','monsters','bosses')]
import cel_style as cel
SPECS={**{f'{a}_p{p}':(6 if a=='idle' else 8,(256,256),('e','s','w','n'),True) for a in ('idle','walk') for p in (1,2,3)},
 'auto':(6,(256,256),('e','s','w','n'),False),
 'spell_a':(8,(256,256),('e','s','w','n'),False),'spell_b':(8,(256,256),('e','s','w','n'),False),
 'intro':(12,(256,256),('s',),False),'trans_p2':(12,(256,256),('s',),False),'trans_p3':(12,(256,256),('s',),False),'death':(10,(256,256),('s',),False),
 'rain_column':(8,(256,1024),('s',),True),'raindrop':(4,(48,256),('s',),True),
 'splash':(6,(128,128),('s',),False),'wave_front':(8,(128,128),('s',),True),
 'flood_water':(4,(896,896),('s',),True),'mist_band':(6,(256,256),('s',),True),
 'lightning':(4,(128,768),('s',),False),'ground_scorch':(4,(128,128),('s',),False),'cross_beam':(8,(832,64),('s',),True)}
EXTRAS={'rain_column','raindrop','splash','wave_front','flood_water','mist_band','lightning','ground_scorch','cross_beam'}

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
    txt+='\n'.join(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/rain_sower/{a}.png" id="{a}"]' for a in sheets)+'\n\n'
    txt+='\n'.join(frames)+'\n[resource]\nanimations = ['+',\n'.join(anims)+']\n'
    (DST/'rain_sower.tres').write_text(txt,encoding='utf-8')



def build():
    import bpy, boss_common as c, iso_rig
    from ash_lord_build import mesh, plate, rod, shard
    from mathutils import Vector
    s=iso_rig.create_rig('CREA',256);s.camera.data.ortho_scale=5.65
    s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,5.65*(204/256-.5),0))
    s['c8b_ground_pivot']=[128,225];s['c8b_height_u']=4.5
    def mat(n,h,metal=0,emit=0):
        rgb=tuple(((int(h[i:i+2],16)/255+.055)/1.055)**2.4 for i in (0,2,4))
        m=c.material(n,rgb,metal,.5,emit)
        if emit:m['rainfall_emissive']=True
        return m
    bronze=mat('Blackened antique bronze lifted for night','8A7A5C',.7)
    shade=mat('Recessed bronze folds 5A4A36','70644E',.7)
    edge=mat('Polished rain-worn bronze arris','B7A17B',.7)
    patina=mat('Verdigris oxidation in the seams','6D8A80',.6)
    dark=mat('Hollow interior','222B2B');water=mat('Deep cold water','728A8E',.3)
    wet=mat('Silvery running water on metal','A9BDC0',.5)
    glow=mat('ONLY accent white crystal E8F8FF','E8F8FF',0,1.45)
    root=c.empty('RAIN_SOWER_4_5U');body=c.empty('Hollow bell mantle',parent=root)
    panels=[]
    # Articulated bronze gores: curved bell profile, not a stack of primitives.
    for j in range(20):
        a=(j+.5)*math.tau/20;verts=[]
        for k,(z,r) in enumerate(((.12,1.02),(.28,1.12),(.67,.99),(1.35,.78),(2.15,.59),(2.94,.48),(3.44,.61))):
            for q in range(3):
                aa=a+(q-1)*math.tau/40;rr=r+(.055 if q==1 else -.025)
                zz=z+(.05*math.sin(j*2.1) if k<2 else .012*math.sin(j+k))
                verts.append((rr*math.sin(aa),rr*.73*math.cos(aa),zz))
        faces=[(k*3+q,k*3+q+1,(k+1)*3+q+1,(k+1)*3+q) for k in range(6) for q in range(2)]
        panel=c.empty('Mantle articulated gore',parent=body);panels.append((panel,a))
        mesh('Bronze bell folded plate',verts,faces,shade if j%4==0 else bronze,panel,.012)
        if j%2==0:
            rod('Rain-polished raised seam',[(r*math.sin(a),r*.73*math.cos(a),z) for z,r in ((.27,1.13),(.70,1.05),(1.5,.79),(2.4,.58),(3.30,.60))],.018,edge,panel)
        for z,r in ((.36,1.10),(2.84,.51),(3.32,.59)):
            shard('Hammered bronze fastening',(r*math.sin(a),r*.73*math.cos(a),z),(.034,.029,.037),edge,panel)
        if j%3==0:
            aa=a+.045
            rod('Cold rivulet down bronze',[(r*math.sin(aa),r*.73*math.cos(aa),z) for z,r in ((.48,1.10),(1.1,.90),(1.7,.71),(2.30,.60))],.010,wet,panel)
            rod('Verdigris runoff seam',[(r*math.sin(a-.08),r*.73*math.cos(a-.08),z) for z,r in ((.7,1.03),(1.4,.79),(2.1,.62))],.023,patina,panel)
    # Chest cavity is an actual opening: front gores separate further in phase 3.
    # Remove their upper faces to expose the drop in every direction through narrow slits.
    for panel,a in panels:
        if math.cos(a)<-.80:
            ob=next(o for o in panel.children if o.name.startswith('Bronze bell folded'))
            for v in ob.data.vertices:
                if 1.6<v.co.z<3.1:v.co.x*=1.55;v.co.y+=.10
    # Independent pointed hood: a real deep opening with a sharp lightning-rod peak.
    outer=[(-.50,3.36),(-.54,3.71),(-.34,4.04),(.04,4.5),(.29,4.10),(.48,3.72),(.40,3.36)]
    inner=[(-.29,3.43),(-.33,3.69),(-.20,3.96),(.02,4.21),(.17,3.98),(.29,3.69),(.25,3.43)]
    verts=[(x,y,z) for y,pts in ((-.25,outer),(-.46,inner),(.27,outer)) for x,z in pts]
    faces=[]
    for j in range(6):faces.extend(((j,j+1,8+j,7+j),(j,14+j,15+j,j+1)))
    faces.append(tuple(range(14,21)))
    mesh('Pointed hollow lightning cowl',verts,faces,bronze,body,.014)
    plate('Dark empty cowl well',inner,-.12,.03,dark,body,0)
    rod('Worn pointed cowl arris',[(-.31,-.47,3.44),(-.35,-.46,3.70),(-.21,-.43,3.98),(.025,-.30,4.24),(.19,-.43,4.0),(.31,-.46,3.70),(.26,-.47,3.44)],.023,edge,body)
    rod('Lightning conductor peak',[(.04,0,4.12),(.04,0,4.49)],.025,patina,body)
    # Broad torn bronze ribs frame a suspended faceted drop, never eyes or a face.
    for side in (-1,1):
        for j in range(3):
            rod('Torn petal of chest reliquary',[(side*.12,-.55,2.15+j*.18),(side*.46,-.54,2.40+j*.17),(side*.40,-.40,2.78+j*.16)],.035,edge,body)
    heart=c.empty('Exposed white crystal heart',(0,-.66,2.69),body)
    # The geometry forms a teardrop: long pointed top, rounded lower facets.
    verts=[(0,0,.55)]
    for z,r in ((.02,.21),(-.18,.19),(-.30,.09)):
        verts.extend((r*math.cos(k*math.tau/8),r*.72*math.sin(k*math.tau/8),z) for k in range(8))
    verts.append((0,0,-.34));faces=[(0,1+k,1+(k+1)%8) for k in range(8)]
    for j in range(2):faces.extend((1+j*8+k,1+j*8+(k+1)%8,9+j*8+(k+1)%8,9+j*8+k) for k in range(8))
    faces.extend((17+k,25,17+(k+1)%8) for k in range(8))
    mesh('Heart first rain drop',verts,faces,glow,heart)
    shard('Crystal shaded internal facet',(.10,-.06,-.10),(.075,.06,.14),wet,heart)
    # Back spine and shoulder clasps give a readable rear silhouette.
    for j in range(7):
        z=1.45+j*.27
        plate('Bronze vertebral rain gutter',[(-.11,z),(.11,z),(.16,z+.13),(0,z+.19),(-.16,z+.13)],.48,.08,patina,body,.006)
    chains=[]
    # Low-poly linked mesh, shared between links: alternating real open loops.
    bpy.ops.mesh.primitive_torus_add(major_segments=12,minor_segments=5,major_radius=.068,minor_radius=.022)
    proto=bpy.context.object;linkmesh=proto.data;linkmesh.materials.append(edge);bpy.data.objects.remove(proto,do_unlink=True)
    for side in (-1,1):
        clasp=c.empty('Massive chain shoulder',(side*.64,0,3.15),body)
        shard('Angular shoulder bronze clasp',(0,0,0),(.27,.28,.26),bronze,clasp)
        c.ring('Verdigris shoulder shackle',(0,-.24,-.05),.17,.037,patina,clasp)
        for strand in range(2):
            for j in range(19):
                ob=bpy.data.objects.new('Linked bronze arm chain',linkmesh);s.collection.objects.link(ob);ob.parent=body
                chains.append((ob,side,strand,j))
    flood=c.empty('Phase two water volutes',parent=root)
    for j in range(4):
        pts=[]
        for k in range(24):
            t=k/23;a=j*1.57+t*2.7;r=1.15-.20*t
            pts.append((r*math.cos(a),r*.72*math.sin(a),.08+t*.64))
        rod('Water curling around the drowned bell',pts,.035 if j%2 else .055,water if j%2 else wet,flood)
    arcs=c.empty('Phase three electrical crown',parent=body)
    for side in (-1,1):
        rod('White crystal induction arc',[(.04,0,4.48),(side*.24,-.03,4.26),(side*.11,-.08,4.16),(side*.40,-.06,3.95),(side*.26,-.10,3.84)],.016,glow,arcs)
    rim=bpy.data.lights.new('Cold upper left rim','AREA');rim.energy=850;rim.color=(.65,.82,1);rim.shape='DISK';rim.size=3
    ob=bpy.data.objects.new('Cold upper left rim',rim);s.collection.objects.link(ob);ob.location=(-3,2,6);ob.rotation_euler=(Vector((0,0,2))-ob.location).to_track_quat('-Z','Y').to_euler()
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in root.children_recursive}
    def pose(a,i,n):
        for o,(l,r,sc) in rest.items():o.location=l;o.rotation_euler=r;o.scale=sc
        t=i/n;u=i/max(1,n-1);wave=math.sin(math.tau*t)
        ph=3 if a.endswith('p3') or a=='death' else 2 if a.endswith('p2') else 1
        if a=='trans_p2':ph=1+u
        if a=='trans_p3':ph=2+u
        opened=max(0,ph-2);drowned=max(0,min(1,ph-1))
        flood.scale=(max(.001,drowned),)*3;flood.rotation_euler.z=.08*wave
        arcs.scale=(max(.001,opened),)*3
        heart.scale=(.86+.10*math.sin(math.tau*t*2)+.12*opened,)*3
        body.location.z=.018*wave*(1-opened);body.rotation_euler.y=.008*math.cos(math.tau*t)
        for j,(o,angle) in enumerate(panels):
            front=max(0,-math.cos(angle))
            o.rotation_euler.y=math.sin(angle)*(.012*wave+.24*opened*front)
            o.location.x=math.sin(angle)*.24*opened*front
            o.location.y=.18*opened*front
            if a.startswith('walk'):o.rotation_euler.x=.018*math.sin(math.tau*t+j*.6)
        if a.startswith('walk'):body.location.z+=.04*abs(wave)*(1-opened)
        hit=([0,.2,.6,1,.38,.06][i] if a=='auto' else [0,.15,.42,.72,1,.60,.25,.05][i] if a in ('spell_a','spell_b') else 0)
        for ob,side,strand,j in chains:
            v=j/18;delay=math.sin(math.tau*t-v*2+side)
            x=side*(.69+.16*v)+strand*.13; y=-.04-strand*.14;z=3.14-3.0*v
            if ph>1:
                # p2 chains rise like two uplifted bony arms; p3 cruciform ground anchors.
                x+=side*drowned*.55*math.sin(math.pi*v)
                z+=drowned*2.4*v
            if opened:
                angle=(.73 if strand else -.73)*side
                x=(1-opened)*x+opened*side*(.70+1.02*v)
                y=(1-opened)*y+opened*math.sin(angle)*1.45*v
                z=(1-opened)*z+opened*(3.14*(1-v)**2+.05*v)
            if a=='auto':
                x+=side*hit*.80*v;y-=hit*1.20*v;z+=hit*.75*math.sin(math.pi*v)
                body.rotation_euler.z=.23*hit
            if a=='spell_a':x+=side*hit*.18*v;z+=hit*4.0*v;y-=.18*hit*v
            if a=='spell_b':y-=hit*1.55*v;x+=side*hit*.20*v;z+=hit*.38*v
            x+=.055*delay*v*(1-opened);y+=.06*math.cos(math.tau*t-v*2)*v
            ob.location=(x,y,z);ob.scale=(.80,1.36,.85);ob.rotation_euler=(math.pi/2,0,j%2*math.pi/2+.12*delay)
        if a=='intro':
            body.location.z+=.34*(1-u);body.rotation_euler.z=.20*(1-u)
            for j,(o,_) in enumerate(panels):o.rotation_euler.y+=.07*(1-u)*math.sin(j)
        if a=='death':
            body.location.z=-.12*u;body.rotation_euler.x=.12*u
            for j,(o,angle) in enumerate(panels):o.rotation_euler.y+=math.sin(angle)*.10*u;o.location.z-=.10*u*(j%3)
            heart.scale*=max(.01,1-u*.99);arcs.scale=(max(.001,1-u),)*3
    return root,pose

def extra(a):
    import bpy, boss_common as c, iso_rig
    from ash_lord_build import mesh, rod, shard
    from mathutils import Vector
    n,(w,h),_,_=SPECS[a];bill=a in ('rain_column','raindrop','lightning')
    s=iso_rig.create_rig('CREA' if bill else 'TOP',(w,h))
    s.camera.data.ortho_scale=w/(90.5 if bill else 64)
    if bill:s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(h/2-4)/90.5,0))
    if a=='cross_beam':s.camera.location.x=6.5
    root=c.empty('Sower '+a)
    if bill:root.rotation_euler=s.camera.rotation_euler
    glow=c.material('ONLY crystal white accent',(.81,.94,1),0,.5,1.2);glow['rainfall_emissive']=True
    water=c.material('Storm slate water',(.10,.17,.20),.3,.25)
    wet=c.material('Cold reflected water',(.29,.43,.46),.3,.25)
    foam=c.material('Silvery white reflected foam',(.56,.67,.68),.1,.5)
    char=c.material('Wet vitrified bronze scorch',(.075,.10,.105),.1,.9)
    moving=[]
    def ribbon(name,points,width,mat):
        verts=[]
        for k,(x,y,z) in enumerate(points):
            ww=width*(.08+.92*math.sin(math.pi*k/max(1,len(points)-1))**.7) if a=='mist_band' else width
            verts.extend(((x,y-ww,z),(x,y+ww,z)))
        return mesh(name,verts,[(k*2,k*2+1,k*2+3,k*2+2) for k in range(len(points)-1)],mat,root)
    if a=='rain_column':
        # Sparse staggered streams preserve transparency behind the boss.
        for j in range(31):
            x=-1.18+2.36*j/30
            for k in range(3):
                y=.10+(j*.381+k*3.65)%10.9;length=.36+(j%5)*.14
                ob=mesh('Vertical falling rain streak',[(x-.030,y,0),(x+.034,y+.02,0),(x+.025,y+length,0),(x-.020,y+length+.08,0)],[(0,1,2,3)],glow if j%5==0 else foam,root)
                moving.append(ob)
        for j in range(4):
            x=(j-1.5)*.6
            ribbon('Broken column foot spray',[(x-.22,.06,0),(x,.18,0),(x+.15,.10,0)],.027,wet)
    elif a=='raindrop':
        verts=[(0,2.70,0),(-.12,.40,0),(-.10,.14,0),(0,.05,0),(.10,.14,0),(.12,.40,0)]
        moving.append(mesh('Long falling crystal drop',verts,[(0,1,2,3,4,5)],glow,root))
        ribbon('Drop cold tail',[(-.04,.3,.01),(-.02,1.4,.01),(0,2.6,.01)],.013,wet)
    elif a=='lightning':
        # Distinct branched jagged full-height lightning, camera facing plane.
        for branch in range(3):
            pts=[]
            for k in range(15):
                y=.055+k*.59; x=.22*math.sin(k*2.5+branch)*(.7 if branch else 1)+(branch-1)*.18
                pts.append((x,y,branch*.004))
            verts=[]
            for x,y,z in pts:verts.extend(((x-.065,y,z),(x+.065,y,z)))
            ob=mesh('Jagged white lightning',verts,[(k*2,k*2+1,k*2+3,k*2+2) for k in range(14)],glow,root);moving.append(ob)
    elif a=='flood_water':
        # Exact 448 px radius including a narrow broken foam fringe.
        verts=[(0,0,0)]+[(6.94*math.cos(j*math.tau/96),6.94*math.sin(j*math.tau/96),0) for j in range(96)]
        mesh('Deep flooded arena disc',verts,[(0,1+j,1+(j+1)%96) for j in range(96)],water,root)
        c.ring('Sharp outer flood foam',(0,0,.018),6.96,.04,foam,root,rotation=(0,0,0))
        for j in range(14):
            radius=1.1+j*.39;pts=[]
            for k in range(23):
                theta=k*.045+j*1.9;rr=radius+.045*math.sin(k*.8+j)
                pts.append((rr*math.cos(theta),rr*math.sin(theta),.03+j*.001))
            ob=rod('Broken water reflection arc',pts,.024 if j%3 else .04,wet if j%3 else foam,root);moving.append(ob)
        for j in range(8):
            x=(j-3.5)*.16
            ob=ribbon('Crystal column reflection',[(x,-2.5,.04),(x+.10,-.9,.04),(x-.07,.6,.04),(x+.08,2.2,.04)],.024,glow if j%3==0 else foam);moving.append(ob)
    elif a=='cross_beam':
        for j in range(5):
            pts=[(.04+k*12.92/48,(j-2)*.072+.045*math.sin(k*1.9+j),.01+j*.002) for k in range(49)]
            moving.append(ribbon('Jagged horizontal storm filament',pts,.055,glow if j%2==0 else wet))
        for k in range(1,26):shard('Cross beam electrical knot',(k*.5,0,.025),(.045,.095,.015),glow,root)
    elif a=='wave_front':
        # +X leading edge at right of the cell: scalloped crescent with trailing ribbons.
        for j in range(4):
            pts=[]
            for k in range(25):
                y=-.90+1.8*k/24;x=.65-j*.19-.28*(abs(y)/.90)**2+.035*math.sin(k*1.4+j)
                pts.append((x,y,.015+j*.004))
            moving.append(rod('Advancing wave crest',pts,.055 if j else .070,foam if j==0 else wet,root))
        for j in range(8):
            y=(j-3.5)*.23
            moving.append(ribbon('Trailing wave flow',[(-.85,y,.01),(-.38,y+.05,.02),(.36,y,.03)],.035,water))
    elif a=='splash':
        for j in range(3):
            ob=c.ring('Impact water ring',(0,0,.015+j*.01),.25+j*.24,.055 if j else .065,foam if j==0 else wet,root,rotation=(0,0,0));moving.append(ob)
        for j in range(10):
            theta=j*math.tau/10
            pts=[(.13*math.cos(theta),.13*math.sin(theta),.08),(.45*math.cos(theta),.45*math.sin(theta),.12),(.77*math.cos(theta),.77*math.sin(theta),.04)]
            moving.append(rod('Radial impact water shard',pts,.032,foam,root))
    elif a=='mist_band':
        # Flattened curling wisps rather than opaque bubbles. Real translucency below.
        for j in range(8):
            pts=[(-1.75+k*.15,(j-3.5)*.38+.16*math.sin(k*.33+j),.01+j*.002) for k in range(24)]
            moving.append(ribbon('Translucent ground mist wisp',pts,.12 if j%2 else .065,wet if j%3 else foam))
    elif a=='ground_scorch':
        verts=[(0,0,0)]+[((.62+.13*math.sin(j*2.9))*math.cos(j*math.tau/24),(.62+.13*math.sin(j*2.9))*math.sin(j*math.tau/24),0) for j in range(24)]
        mesh('Irregular wet vitrified impact',verts,[(0,1+j,1+(j+1)%24) for j in range(24)],char,root)
        for j in range(9):
            theta=j*2.4;rr=.20+j*.045
            moving.append(rod('Branching silver wet fissure',[(.05*math.cos(theta),.05*math.sin(theta),.01),(rr*.5*math.cos(theta+.3),rr*.5*math.sin(theta+.3),.02),(rr*math.cos(theta),rr*math.sin(theta),.02)],.018,wet,root))
    # Keep shared cel shader and AOV, add physical alpha only for wisps and curtain.
    cel.toon_materials('boss')
    if a in ('mist_band','rain_column'):
        for mat in (wet,foam):
            nodes=mat.node_tree.nodes;links=mat.node_tree.links
            out=next(q for q in nodes if q.type=='OUTPUT_MATERIAL');src=out.inputs['Surface'].links[0].from_socket
            mix=nodes.new('ShaderNodeMixShader');tr=nodes.new('ShaderNodeBsdfTransparent')
            mix.inputs[0].default_value=.36 if a=='mist_band' else .65
            links.new(tr.outputs[0],mix.inputs[1]);links.new(src,mix.inputs[2]);links.new(mix.outputs[0],out.inputs['Surface'])
            mat.surface_render_method='DITHERED'
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in moving}
    def pose(a,i,n):
        t=i/n
        for j,o in enumerate(moving):
            l,r,sc=rest[o];o.location=l;o.rotation_euler=r;o.scale=sc
            if a=='rain_column':o.location.y=-.17*math.sin(math.tau*t+j)
            elif a=='raindrop':o.scale.x=.80+.10*i;o.location.y=-.025*i
            elif a=='lightning':o.location.x=.05*math.sin(i*2.7+j*3);o.scale.x=.70+.12*i
            elif a=='splash':o.scale=(.36+.61*i/(n-1),)*3;o.rotation_euler.z=.045*i
            elif a=='flood_water':o.rotation_euler.z=.012*math.sin(math.tau*t+j);o.location.z+=.002*i
            elif a=='wave_front':o.location.x=.03*math.sin(math.tau*t+j);o.scale.y=.94+.05*math.sin(math.tau*t+j)
            elif a=='cross_beam':o.scale.y=.82+.18*math.sin(math.tau*t+j);o.location.y=.018*math.cos(math.tau*t+j)
            elif a=='mist_band':o.location.x=.05*math.sin(math.tau*t+j);o.location.y=.06*math.cos(math.tau*t+j);o.scale.y=.85+.12*math.sin(math.tau*t+j)
            elif a=='ground_scorch':o.rotation_euler.z=.15*i;o.scale=(.85+.05*i,)*3
    return root,pose

def main():
    import bpy, boss_common as c, iso_rig
    from PIL import Image
    DST.mkdir(parents=True,exist_ok=True)
    inv=HERE/'_c8b_inventory.json'
    if not inv.exists():
        inv.write_text(json.dumps({p.name:{'size':Image.open(p).size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in DST.glob('*.png')},indent=2))
    if json.loads(inv.read_text()):cel.archive_folder('bosses/etage/rain_sower')
    root,pose=build()
    source=ROOT/'art/blender/bosses/rain_sower_iso.blend';source.parent.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    if '--only' not in sys.argv:
        f=1
        for a,(n,_,dirs,_) in SPECS.items():
            if a in EXTRAS:continue
            bpy.context.scene.timeline_markers.new(a,frame=f)
            for i in range(n):
                pose(a,i,n)
                for o in [root]+list(root.children_recursive):
                    for channel in ('location','rotation_euler','scale'):o.keyframe_insert(channel,frame=f+i)
            f+=n
        bpy.context.scene.frame_end=f-1;bpy.context.scene.render.fps=12
        bpy.context.scene.frame_set(1)
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
        # Keep editable animation in the source, export using explicit procedural poses.
        for o in [root]+list(root.children_recursive):o.animation_data_clear()
        pose('idle_p1',0,6)
    if '--source-only' in sys.argv:return
    selected=sys.argv[sys.argv.index('--only')+1].split(',') if '--only' in sys.argv else list(SPECS)
    cel.install('boss')
    with tempfile.TemporaryDirectory(prefix='rainfall_c8b_') as td:
        tmp=Path(td)
        for a in selected:
            n,(w,h),dirs,loop=SPECS[a]
            if a in EXTRAS:root,pose=extra(a)
            elif bpy.context.scene.get('iso_rig')!='CREA' or root.name!='RAIN_SOWER_4_5U':root,pose=build()
            s=bpy.context.scene;s['iso_frame']=[w,h];s.render.resolution_x=w*2;s.render.resolution_y=h*2
            cap=4096//w
            for part,start in enumerate(range(0,n,cap)):
                count=min(cap,n-start);name=a if part==0 else a+'_'+str(part+1)
                boards=[Image.new('RGBA',(count*w,len(dirs)*h),(128,128,255,0) if j==1 else (0,0,0,0)) for j in range(3)]
                for row,d in enumerate(dirs):
                    for i in range(start,start+count):
                        pose(a,i,n)
                        if a not in EXTRAS:root.rotation_euler.z=c.DIRECTIONS[d]
                        bpy.context.view_layer.update();path=tmp/f'{a}_{d}_{i}.png'
                        iso_rig.render_frame(path)
                        for j,suffix in enumerate(('','_n','_e')):
                            with Image.open(path.with_name(path.stem+suffix+'.png')) as im0:im=im0.convert('RGBA')
                            if j==0:alpha=im.getchannel('A')
                            else:im.putalpha(alpha)
                            boards[j].paste(im,((i-start)*w,row*h))
                for board,suffix in zip(boards,('','_n','_e')):board.save(DST/f'{name}{suffix}.png',compress_level=9)
                cel.quantize_normal_files([DST/f'{name}_n.png'],work=tmp/'normal_quantize')
                print('C8B DONE '+name,flush=True)
    resource()
    (DST/'lighting.md').write_text('C8b CEL boss: 3 tones, 2px inner ink, folds, quantized screen normals, CEL_Accent. Eevee 8 samples; Standard; 2x Lanczos. CREA 30deg, ortho 5.65, ground pivot (128,225), height 4.5u. Bronze and verdigris robe; cold upper-left rim; single white-crystal accent. Ground extras 64px/u; billboard 90.5px/u. Cross beam split into two atlases. Impact auto=3, spells=4.\n')



def verify():
    from PIL import Image
    import numpy as np
    report={}
    for a,(n,(w,h),dirs,_) in SPECS.items():
        for part,start in enumerate(range(0,n,4096//w)):
            count=min(4096//w,n-start);name=a if part==0 else a+'_'+str(part+1)
            ims=[Image.open(DST/f'{name}{s}.png').convert('RGBA') for s in ('','_n','_e')]
            d,no,e=[np.asarray(im) for im in ims]
            assert ims[0].size==(count*w,len(dirs)*h),name
            assert max(ims[0].size)<=4096,name
            assert np.array_equal(d[:,:,3],no[:,:,3]) and np.array_equal(d[:,:,3],e[:,:,3]),name+' alpha'
            colors=np.unique(no[:,:,:3][no[:,:,3]==255],axis=0)
            assert len(colors)<=27,(name,len(colors))
            if len(colors):assert np.max(np.abs(np.linalg.norm(colors.astype(float)/255*2-1,axis=1)-1))<.015,name
            cells=[];bounds=[]
            for r in range(len(dirs)):
                for i in range(count):
                    cc=d[r*h:(r+1)*h,i*w:(i+1)*w]
                    assert cc[:,:,3].max()>10,(name,r,i,'empty')
                    cells.append(hashlib.sha256(cc.tobytes()).hexdigest())
                    if a not in EXTRAS:
                        ys,xs=np.where(cc[:,:,3]>32);bounds.append([int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max())])
                        assert xs.min()>=3 and xs.max()<w-3 and ys.min()>=3 and ys.max()<h-3,(name,r,i,'clipped',bounds[-1])
            assert len(cells)==len(set(cells)),(name,'duplicate frames')
            report[name]={'size':ims[0].size,'normal_colors':len(colors),'unique_cells':len(cells),'body_bounds':bounds}
    body=np.asarray(Image.open(DST/'idle_p1.png').convert('RGBA'));mask=body[:,:,3]>250
    mean=body[:,:,:3][mask].mean();assert mean>=90,('night readability',mean)
    report['body_mean_srgb']=round(float(mean),2)
    # Sole contact sheet: actual-size cells on game ground, references only reduced.
    contact=Image.new('RGBA',(2048,3072),'#2E3238')
    ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    for y in range(0,1024,ground.height):
        for x in range(0,2048,ground.width):contact.alpha_composite(ground,(x,y))
    spots=[('idle_p1',0,2),('idle_p1',1,2),('idle_p1',2,2),('idle_p1',3,2),('idle_p2',0,2),('idle_p2',1,2),('idle_p3',1,2),('idle_p3',3,2),
           ('auto',1,2),('auto',1,3),('spell_a',1,3),('spell_a',1,4),('spell_b',1,3),('spell_b',1,4),('intro',0,0),('intro',0,11),
           ('trans_p2',0,6),('trans_p2',0,11),('trans_p3',0,6),('trans_p3',0,11),('death',0,0),('death',0,5),('death',0,9),('walk_p3',1,3)]
    for idx,(a,r,i) in enumerate(spots):
        im=Image.open(DST/f'{a}.png').convert('RGBA').crop((i*256,r*256,(i+1)*256,(r+1)*256));contact.alpha_composite(im,((idx%8)*256,(idx//8)*256))
    placements=[('rain_column',1,0,800),('lightning',1,280,800),('raindrop',2,440,800),('splash',3,520,800),('wave_front',3,680,800),('mist_band',2,850,800),('ground_scorch',2,1140,800),('flood_water',2,1152,1152),('cross_beam',2,280,1800)]
    for a,i,x,y in placements:
        w,h=SPECS[a][1];cap=4096//w;part=i//cap;name=a if not part else a+'_'+str(part+1);i%=cap
        im=Image.open(DST/f'{name}.png').convert('RGBA').crop((i*w,0,(i+1)*w,h));contact.alpha_composite(im,(x,y))
    # Body normals / isolated accent and an Ardent crop at original display size.
    for j,suffix in enumerate(('_n','_e')):
        im=Image.open(DST/f'idle_p3{suffix}.png').convert('RGBA').crop((512,256,768,512));contact.alpha_composite(im,(520+j*256,1080))
    im=Image.open(ROOT/'game/assets/sprites/characters/ardent/idle.png').convert('RGBA').crop((0,384,192,576));contact.alpha_composite(im,(520,1410))
    for idx,rel in enumerate(('art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/night/_cs1_contact.png')):
        im=Image.open(ROOT/rel).convert('RGBA')
        if idx==3:im=im.crop((im.width//2,0,im.width,im.height))
        im.thumbnail((496,960),Image.Resampling.LANCZOS);contact.alpha_composite(im,(idx*512,2100))
    contact.convert('RGB').save(HERE/'_c8b_contact.png',compress_level=9)
    (HERE/'_c8b_verify.json').write_text(json.dumps(report,indent=2))
    print('PASS C8b:',len(report)-1,'sheets; alpha / normals / unique frames / bounds; body mean',round(mean,1))

if __name__=='__main__':
    if '--verify' in sys.argv:verify()
    else:main()
