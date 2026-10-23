"""R8a: charred skeletal lord; preserved hierarchical rig and seven timelines.
Background Blender only. C0 CREA, 30 degrees; PBR/AO baked into sprites.
"""
import sys,math,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from boss_pipeline import *
sys.path.insert(0,str(ART/'tools/iso'))
import iso_rig

def worn(name,dark,light,metal=0,rough=.8):
    m=material(name,dark,0);n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=17;noise.inputs['Detail'].default_value=3
    ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.22;ramp.color_ramp.elements[1].position=.78
    def linear(h):
        rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
        return tuple(v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
    ramp.color_ramp.elements[0].color=linear(dark);ramp.color_ramp.elements[1].color=linear(light)
    l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color'])
    fine=n.new('ShaderNodeTexNoise');fine.inputs['Scale'].default_value=95;fine.inputs['Detail'].default_value=2
    bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.24;bump.inputs['Distance'].default_value=.018
    l.new(fine.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
    roughmap=n.new('ShaderNodeMapRange');roughmap.inputs['To Min'].default_value=max(.3,rough-.16);roughmap.inputs['To Max'].default_value=min(.98,rough+.14)
    l.new(noise.outputs['Fac'],roughmap.inputs['Value']);l.new(roughmap.outputs[0],p.inputs['Roughness'])
    return m

def mesh(name,verts,faces,mat,parent,bevel=0):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    ob=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(ob);ob.parent=parent;ob.data.materials.append(mat)
    if bevel:
        mod=ob.modifiers.new('Chipped edges','BEVEL');mod.width=bevel;mod.segments=1
        ob.modifiers.new('Plate normals','WEIGHTED_NORMAL')
    return ob

def plate(name,points,y,thick,mat,parent,bevel=.008):
    n=len(points);v=[(x,y+d,z) for d in (0,thick) for x,z in points]
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
    return mesh(name,v,faces,mat,parent,bevel)

def rod(name,points,r,mat,parent):
    # Six-sided swept bone/iron; no invisible subdivision.
    verts=[]
    for i,p in enumerate(points):
        axis=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        q=axis.to_track_quat('Z','Y')
        rr=r*(.75 if i in (0,len(points)-1) else 1)
        verts += [Vector(p)+q@Vector((rr*math.cos(j*math.tau/6),rr*math.sin(j*math.tau/6),0)) for j in range(6)]
    faces=[tuple(range(5,-1,-1)),tuple(range((len(points)-1)*6,len(points)*6))]
    faces += [(i*6+j,i*6+(j+1)%6,(i+1)*6+(j+1)%6,(i+1)*6+j) for i in range(len(points)-1) for j in range(6)]
    return mesh(name,verts,faces,mat,parent)

def shard(name,loc,scale,mat,parent):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1)
    o=finish(bpy.context.object,name,loc,scale,mat,parent)
    for p in o.data.polygons:p.use_smooth=False
    return o

def build():
    s=iso_rig.create_rig('CREA',170)
    s.eevee.taa_render_samples=16
    s['diffuse_contour_pixels']=0
    # Camera preserved in CREA orientation; frame fitting keeps legacy pivot/grid.
    s['r8a_camera_elevation']=30;s['r8a_height_units']=2.3
    iron=worn('Blackened iron - pitted and oxidised','202123','66645C',.65,.58)
    edge=worn('Worn iron edges','3D3832','8B7860',.65,.6)
    ash=worn('Ash in crevices','282725','6F6A5F')
    rag=worn('Scorched woven shroud','171B1C','4B4941')
    bone=worn('Soot stained old bone','5E584C','C3B796',0,.85)
    black=worn('Empty eye sockets','080909','151714')
    ember=material('Heart - orange ember','FF681D',2.2,True)
    eye=material('Eyes - same ember orange','FF681D',1.8,True)
    flame=material('Fire - same ember orange','FF681D',1.8,True)
    smoke=worn('Ash smoke ribbons','272B2B','55564E')
    root=empty('AshLord');body=empty('Ash lord',parent=root)
    # Exposed spine, separated curved ribs, open chest housing the single heart.
    rod('Scorched spine',[(0,.10,.82),(0,.13,1.2),(0,.1,1.7),(0,.02,1.92)],.047,bone,body)
    for j in range(7):
        z=.94+j*.125
        plate('Vertebra', [(-.06,z-.025),(.065,z-.025),(.05,z+.025),(-.05,z+.035)],.085,.06,bone,body)
    for j in range(5):
        z=1.25+j*.115;w=.20+.07*math.sin(j*.6)
        for sign in (-1,1):
            rod('Curved cage rib',[(sign*.03,.12,z+.04),(sign*w,.06,z+.035),(sign*(w+.02),-.10,z-.015),(sign*.085,-.19,z-.05)],.021,bone,body)
    shard('Heart ember',(0,-.045,1.49),(.105,.09,.15),ember,body)
    for j in range(3):
        rod('Heart iron restraint',[(-.11,-.14,1.4+j*.07),(0,-.15,1.38+j*.07),(.11,-.14,1.4+j*.07)],.012,iron,body)
    for sign in (-1,1):
        plate('Broken hip fauld',[(sign*.02,.98),(sign*.27,1.1),(sign*.32,.84),(sign*.13,.73)],-.055,.14,iron,body)
        rod('Clavicle',[(sign*.03,-.015,1.83),(sign*.22,-.03,1.88),(sign*.36,0,1.8)],.032,bone,body)
        # Narrow, half-hidden dangling legs and pointed sabatons.
        rod('Exposed femur',[(sign*.15,.03,.89),(sign*.18,-.015,.54),(sign*.14,-.04,.36)],.036,bone,body)
        plate('Charred greave',[(sign*.11,.61),(sign*.24,.56),(sign*.19,.17),(sign*.09,.12)],-.07,.12,iron,body)
        shard('Pointed sabaton',(sign*.15,-.10,.13),(.085,.18,.065),iron,body)
    head=empty('Head',(0,-.02,2.01),body)
    # Faceted occipital shell with a constructed skeletal mask, recessed eye slits.
    shard('Cranial vault',(0,.025,.035),(.145,.115,.19),bone,head)
    plate('Dark recessed face',[(-.13,-.04),(-.13,.09),(0,.14),(.13,.09),(.13,-.04),(0,-.14)],-.113,.025,black,head)
    for sign in (-1,1):
        plate('Angular brow',[(sign*.015,.065),(sign*.135,.11),(sign*.145,.055),(sign*.035,.025)],-.15,.04,bone,head)
        plate('Cheek blade',[(sign*.13,.03),(sign*.155,-.035),(sign*.075,-.135),(sign*.065,-.04)],-.135,.04,bone,head)
        plate('Narrow ember eye',[(sign*.035,.028),(sign*.117,.047),(sign*.098,.018),(sign*.038,.006)],-.156,.009,eye,head,0)
    plate('Nasal blade',[(-.017,.035),(.02,.035),(.03,-.045),(0,-.065),(-.027,-.045)],-.16,.022,bone,head)
    for j in range(5):
        x=(j-2)*.022
        plate('Broken tooth',[(x-.008,-.075),(x+.009,-.075),(x+.006,-.119+(j%2)*.01),(x-.006,-.12)],-.15,.022,bone,head,.002)
    rod('Broken jaw',[(-.095,-.08,-.09),(-.07,-.14,-.155),(.055,-.14,-.15),(.11,-.07,-.075)],.019,bone,head)
    for j in range(7):
        a=j*math.tau/7;x=math.sin(a)*.16;y=math.cos(a)*.12
        rod('Iron crown hoop',[(x,y,.14),(math.sin(a+.5)*.16,math.cos(a+.5)*.12,.14),(math.sin(a+math.tau/7)*.16,math.cos(a+math.tau/7)*.12,.14)],.018,iron,head)
        plate('Splintered crown tooth',[(x-.025,.13),(x+.025,.13),(x+.035,.22+(j%3)*.025),(x-.02,.29-(j%2)*.035)],y,.026,iron,head)
    arms=[]
    for sign in (-1,1):
        arm=empty('Long arm',(sign*.36,0,1.8),body);arms.append((arm,sign))
        plate('Jagged layered pauldron',[(-.16,.035),(-.10,.14),(.065,.15),(.21,.035),(.13,-.15),(.015,-.10),(-.12,-.18)],-.09,.20,iron,arm)
        plate('Worn pauldron rim',[(-.16,.035),(-.10,.14),(.065,.15),(.21,.035),(.18,.01),(.05,.115),(-.09,.105)],-.101,.016,edge,arm,.003)
        for j in range(3):
            x=(j-1)*.09
            shard('Armor rivet',(x,-.107,.06),(.015,.012,.015),edge,arm)
        rod('Humerus',[(0,0,-.12),(sign*.055,0,-.35),(sign*.03,-.01,-.5)],.036,bone,arm)
        shard('Elbow',(sign*.03,-.01,-.52),(.057,.049,.054),iron,arm)
        for k in (-1,1):rod('Forearm bone',[(sign*.03+k*.022,-.01,-.55),(sign*.04+k*.017,-.07,-.83)],.017,bone,arm)
        plate('Forearm blade',[(sign*.03-.065,-.56),(sign*.03+.06,-.57),(sign*.03+.05,-.84),(sign*.03-.045,-.91)],-.10,.07,iron,arm)
        shard('Skeletal palm',(sign*.03,-.075,-.95),(.068,.035,.09),bone,arm)
        for k in range(4):
            x=sign*.03+(k-1.5)*.033
            rod('Clawed finger',[(x,-.08,-1.0),(x+(k-1.5)*.012,-.12,-1.10),(x+(k-1.5)*.018,-.18,-1.14)],.012,bone,arm)
        # Low polygon linked chain geometry, reusable mesh for alternating links.
        chain_mesh=None
        for j in range(7 if sign==1 else 4):
            if chain_mesh is None:
                bpy.ops.mesh.primitive_torus_add(major_segments=8,minor_segments=4,major_radius=.034,minor_radius=.009)
                ob=bpy.context.object;ob.name='Black iron chain';ob.parent=arm;ob.data.materials.append(iron);chain_mesh=ob.data
            else:
                ob=bpy.data.objects.new('Black iron chain',chain_mesh);bpy.context.collection.objects.link(ob);ob.parent=arm
            # Pass overrides must stay on objects, preserving the shared mesh.
            ob.material_slots[0].link='OBJECT';ob.material_slots[0].material=iron
            ob.location=(sign*.17+.022*math.sin(j*.5),.01,-.14-j*.055);ob.rotation_euler=(math.pi/2,0,(j%2)*math.pi/2);ob.scale=(.8,1.25,1)
    capes=[];cape=empty('Tattered cape',(0,.12,1.88),body)
    # Each strip is a contoured cloth mesh, with irregular holes between strips.
    for j in range(11):
        x=(j-5)*.087;h=1.24+.24*math.sin(j*1.71);strip=empty('Cape strip',(x,0,0),cape);capes.append((strip,j))
        w=.057;v=[]
        for row in range(6):
            t=row/5
            for side in (-1,1):v.append((side*w*(1+.35*t)+.035*math.sin(j+row),.03+.33*t+.07*math.sin(j+row*.7),-h*t+(side*.07 if row==5 else 0)))
        faces=[(r*2,r*2+1,r*2+3,r*2+2) for r in range(5)]
        ob=mesh('Burned cloth with torn hem',v,faces,rag,strip)
        mod=ob.modifiers.new('Cloth thickness','SOLIDIFY');mod.thickness=.009
        if j in (1,4,8):rod('Smouldering thread',[(v[-2][0],v[-2][1]-.008,v[-2][2]),(v[-2][0]+.025,v[-2][1],v[-2][2]+.06)],.006,ember,strip)
    puffs=[]
    for j in range(5):
        # Thin serpentine smoke wisps rather than rounded cartoon puffs.
        ob=mesh('Smoke wisp',[(-.13,0,0),(.13,0,0),(.3,.05,.65),(.03,.04,.8),(-.2,.05,1.25),(-.12,.04,1.8)],[(0,1,2,3),(3,2,4),(3,4,5)],smoke,body)
        ob.location=(math.sin(j*2.1)*.35,.28,1.85+j*.065);ob.scale=(.12,.12,.1);puffs.append((ob,ob.location.copy()))
    meteors=empty('Meteors',parent=root)
    for j in range(5):
        a=j*math.tau/5;loc=(math.cos(a)*.78,math.sin(a)*.65-.1,2.3+.15*(j%2))
        shard('Cinder meteor',loc,(.11,.10,.15),iron,meteors)
        shard('Meteor ember seam',(loc[0],loc[1]-.065,loc[2]),(.045,.018,.10),flame,meteors)
    wall=empty('Flame wall',(0,-.78,0),root)
    for j in range(7):
        x=(j-3)*.24;h=.75+.2*(j%2)
        plate('Torn flame tongue',[(x-.065,.03),(x-.09,h*.35),(x+.02,h*.65),(x-.015,h),(x+.11,h*.55),(x+.065,.1)],0,.016,flame,wall,0)
    chunks=[]
    for j in range(6):
        ob=shard('Ash fragment',(math.sin(j*2.4)*.22,.08,1.1+j*.12),(.035,.03,.04),ash,body);chunks.append((ob,ob.location.copy()))
    iso_rig.bake_ao_shadows(root)
    s['r8a_mesh_polygons']=sum(len(o.data.polygons) for o in root.children_recursive if o.type=='MESH')
    def animate(a,i,n,f):
        t=i*math.tau/n;p=i/(n-1);run=a=='run';dead=p if a=='death' else 0;sp=p if a=='phase2' else 0
        body.location=(0,0,.04*math.sin(2*t) if run else .05*math.sin(t) if a=='idle' else -.5*dead)
        body.rotation_euler=(.13 if run else (-.15*math.sin(p*math.pi) if a=='cast_a' else .2*math.sin(p*math.pi) if a=='cast_b' else -.6*dead),0,.04*math.sin(t) if run else 0);body.scale=(1,1,1-.1*dead);key(body,f)
        head.rotation_euler.x=-.3*math.sin(p*math.pi) if a=='cast_a' else 0;key(head,f)
        for arm,sign in arms:
            ax=sign*.35*math.sin(t) if run else 0;ay=-sign*(.12+.04*math.sin(t))
            if a=='attack':ax=-[0,.8,1.4,-.9,-.4,0][i] if sign==1 else 0;ay=-sign*.15
            if a=='cast_a':ax=0;ay=-sign*2.5*math.sin(p*math.pi)
            if a=='cast_b':ax=-1.5*math.sin(p*math.pi);ay=-sign*.15
            if a=='phase2':ax=-.4*sp;ay=-sign*(.3+1.8*math.sin(p*math.pi))
            arm.rotation_euler=(ax,ay,0);key(arm,f)
        for s,j in capes:
            s.rotation_euler=(.12+.1*math.sin(t+j*.7)+(.35 if run else 0)+.5*dead+.4*sp*math.sin(p*3+j),0,.05*math.sin(t*2+j));key(s,f)
        for j,(o,loc) in enumerate(puffs):
            k=((i+j)%n)/n;o.location=loc+Vector((.05*math.sin(j+t),0,.3*k));o.scale=(.12*(1-.5*k),.12*(1-.5*k),.1*(1-.5*k));key(o,f)
        on=a=='cast_a' and i>=2;q=(.3+.7*p) if on else .001;meteors.scale=(q,q,q);key(meteors,f)
        on=a=='cast_b' and i>=3;q=(.1+.9*min(1,p*1.5)) if on else .001;wall.scale=(1 if on else .001,1 if on else .001,q);key(wall,f)
        for j,(o,loc) in enumerate(chunks):
            o.location=loc+Vector((math.sin(j*2.4)*dead*.6,0,-dead*loc.z*.5));key(o,f)
        pulse(ember,f,1.6+1.2*math.sin(t) if a!='phase2' else 2+6*p);pulse(eye,f,1.8+.6*math.sin(t))
    export('ash_lord',root,animate)
if __name__=='__main__':build()
