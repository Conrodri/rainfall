"""V3 store icon; reuse store construction helpers, read-only boss source."""
from pathlib import Path
import sys, math, random, shutil, json, hashlib
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).parent))
import build_store as old
"""Procedural Cycles treatment of the existing store composition; no source edits."""
def apply(bpy, s, root, fg, bg, cam, black, edge, white, stone, silver, feather, cover, water, cyan, red):
    import math, random
    from mathutils import Vector
    rng=random.Random(4106)
    def pbr(mat, color, metal, rough, scale, relief):
        mat.use_nodes=True; n=mat.node_tree.nodes; n.clear(); l=mat.node_tree.links
        out=n.new('ShaderNodeOutputMaterial'); bs=n.new('ShaderNodeBsdfPrincipled'); l.new(bs.outputs[0],out.inputs['Surface'])
        bs.inputs['Base Color'].default_value=(*color,1); bs.inputs['Metallic'].default_value=metal
        tex=n.new('ShaderNodeTexNoise'); tex.inputs['Scale'].default_value=scale;tex.inputs['Detail'].default_value=4
        ramp=n.new('ShaderNodeMapRange'); ramp.inputs['To Min'].default_value=rough[0];ramp.inputs['To Max'].default_value=rough[1]
        l.new(tex.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],bs.inputs['Roughness'])
        bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.28;bump.inputs['Distance'].default_value=relief
        l.new(tex.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],bs.inputs['Normal'])
        return n,l,bs,tex,bump
    for mat,color in ((black,(.055,.042,.028)),(edge,(.11,.105,.08))):
        n,l,bs,tex,bump=pbr(mat,color,1,(.25,.6),48,.016)
        ao=n.new('ShaderNodeAmbientOcclusion');ao.inputs['Distance'].default_value=.14
        mix=n.new('ShaderNodeMixRGB');mix.inputs[1].default_value=(.012,.052,.041,1);mix.inputs[2].default_value=(*color,1)
        l.new(ao.outputs['AO'],mix.inputs[0]);l.new(mix.outputs[0],bs.inputs['Base Color'])
        wave=n.new('ShaderNodeTexWave');wave.inputs['Scale'].default_value=180;wave.inputs['Distortion'].default_value=6
        scratch=n.new('ShaderNodeBump');scratch.inputs['Distance'].default_value=.001;scratch.inputs['Strength'].default_value=.18
        l.new(wave.outputs['Color'],scratch.inputs['Height']);l.new(bump.outputs[0],scratch.inputs['Normal']);l.new(scratch.outputs[0],bs.inputs['Normal'])
        bs.inputs['Coat Weight'].default_value=.45;bs.inputs['Coat Roughness'].default_value=.16
    for mat,color in ((stone,(.048,.060,.065)),(silver,(.10,.12,.13))):
        n,l,bs,tex,bump=pbr(mat,color,0,(.55,.88),21,.045)
        vor=n.new('ShaderNodeTexVoronoi');vor.inputs['Scale'].default_value=95
        grain=n.new('ShaderNodeBump');grain.inputs['Distance'].default_value=.009;grain.inputs['Strength'].default_value=.35
        l.new(vor.outputs['Distance'],grain.inputs['Height']);l.new(bump.outputs[0],grain.inputs['Normal']);l.new(grain.outputs[0],bs.inputs['Normal'])
        mix=n.new('ShaderNodeMixRGB');mix.inputs[1].default_value=(.008,.022,.016,1);mix.inputs[2].default_value=(*color,1)
        l.new(tex.outputs['Fac'],mix.inputs[0]);l.new(mix.outputs[0],bs.inputs['Base Color'])
    cloth=bpy.data.materials.new('V4 soaked funeral cloth')
    n,l,bs,tex,bump=pbr(cloth,(.015,.020,.023),0,(.38,.68),125,.008)
    bs.inputs['Sheen Weight'].default_value=.42
    wave=n.new('ShaderNodeTexWave');wave.inputs['Scale'].default_value=240;wave.inputs['Distortion'].default_value=3
    l.new(wave.outputs['Color'],bump.inputs['Height'])
    for mat,color in ((feather,(.022,.029,.036)),(cover,(.032,.039,.045))):
        n,l,bs,tex,bump=pbr(mat,color,0,(.3,.58),75,.003)
        bs.inputs['Sheen Weight'].default_value=.6;bs.inputs['Subsurface Weight'].default_value=.07
        coord=n.new('ShaderNodeTexCoord');mapping=n.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=(6,1,70)
        l.new(coord.outputs['Generated'],mapping.inputs[0]);l.new(mapping.outputs[0],tex.inputs['Vector'])
        wave=n.new('ShaderNodeTexWave');wave.bands_direction='Z';wave.inputs['Scale'].default_value=48;wave.inputs['Distortion'].default_value=2
        l.new(mapping.outputs[0],wave.inputs['Vector']);l.new(wave.outputs['Color'],bump.inputs['Height'])
        alpha=n.new('ShaderNodeMapRange');alpha.inputs['To Min'].default_value=.72;alpha.inputs['To Max'].default_value=1
        l.new(wave.outputs['Fac'],alpha.inputs[0]);l.new(alpha.outputs[0],bs.inputs['Alpha'])
    rust=bpy.data.materials.new('V4 wet rusted iron')
    n,l,bs,tex,bump=pbr(rust,(.065,.037,.022),.88,(.23,.6),55,.009)
    mix=n.new('ShaderNodeMixRGB');mix.inputs[1].default_value=(.016,.022,.025,1);mix.inputs[2].default_value=(.17,.045,.012,1)
    l.new(tex.outputs['Fac'],mix.inputs[0]);l.new(mix.outputs[0],bs.inputs['Base Color'])
    n,l,bs,tex,bump=pbr(white,(.8,.94,1),0,(.025,.07),120,.0003)
    bs.inputs['Transmission Weight'].default_value=1;bs.inputs['IOR'].default_value=1.46
    bs.inputs['Emission Color'].default_value=(.75,.93,1,1);bs.inputs['Emission Strength'].default_value=3.5
    # Keep a luminous inner core inside the refracting crystal shell.
    crystals=[o for o in root.children_recursive if o.type=='MESH' and not o.hide_render and any(k in o.name for k in ('Heart first','Crystal shaded'))]
    for ob in crystals[:1]:
        ob.data=ob.data.copy(); core=ob.copy();core.data=ob.data.copy();bpy.context.collection.objects.link(core);core.name='V4 inner white crystal core';core.scale*=.68
        coremat=bpy.data.materials.new('V4 crystal inner radiance');coremat.use_nodes=True
        cb=coremat.node_tree.nodes.get('Principled BSDF');cb.inputs['Base Color'].default_value=(1,1,1,1);cb.inputs['Emission Color'].default_value=(.85,.97,1,1);cb.inputs['Emission Strength'].default_value=22
        core.data.materials.clear();core.data.materials.append(coremat);fg.append(core)
    for ob in list(s.objects):
        if ob.type not in ('MESH','CURVE') or ob.hide_render:continue
        name=ob.name.lower()
        if any(k in name for k in ('outline','inverted hull','cel hull')):ob.hide_render=True;continue
        if any(k in name for k in ('blood mist','ember ripple','suspended lit dust','descending rose volumetric ray')):ob.hide_render=True;continue
        if ob in root.children_recursive and any(k in name for k in ('robe','cloth','skirt','mantle','hood','shroud','drape')):
            ob.data=ob.data.copy();ob.data.materials.clear();ob.data.materials.append(cloth)
        if any(k in name for k in ('chain','shackle')):
            ob.data=ob.data.copy();ob.data.materials.clear();ob.data.materials.append(rust)
        if ob.type=='MESH':
            for poly in ob.data.polygons:poly.use_smooth=True
            for mod in list(ob.modifiers):
                if mod.type=='SOLIDIFY' and mod.thickness<0:ob.modifiers.remove(mod)
            if any(k in name for k in ('secondary','primary','covert','feather','robe','hood','mantle')):
                sub=ob.modifiers.new('V4 organic curvature','SUBSURF');sub.levels=1;sub.render_levels=2
                texd=bpy.data.textures.new('V4 subtle worn surface','CLOUDS');texd.noise_scale=.09
                dis=ob.modifiers.new('V4 wet irregularity','DISPLACE');dis.texture=texd;dis.strength=.009 if 'feather' not in name else .003
            elif ob in root.children_recursive:
                bevel=ob.modifiers.new('V4 cast rounded edges','BEVEL');bevel.width=.008;bevel.segments=3
        elif ob.type=='CURVE':ob.data.bevel_resolution=max(ob.data.bevel_resolution,3)
    n,l,bs,tex,bump=pbr(water,(.008,.012,.015),.25,(.065,.15),7,.018)
    bs.inputs['Coat Weight'].default_value=.65
    # A single true scattering volume; shafts are cast by rose spotlights.
    fog=bpy.data.materials.new('V4 real atmospheric scattering');fog.use_nodes=True
    ns=fog.node_tree.nodes;ns.clear();out=ns.new('ShaderNodeOutputMaterial');scatter=ns.new('ShaderNodeVolumeScatter')
    scatter.inputs['Density'].default_value=.016;scatter.inputs['Anisotropy'].default_value=.38
    fog.node_tree.links.new(scatter.outputs[0],out.inputs['Volume'])
    bpy.ops.mesh.primitive_cube_add(size=1,location=(0,1,3));o=bpy.context.object;o.name='V4 atmospheric volume';o.scale=(13,7,9);o.data.materials.append(fog);bg.append(o)
    for j in range(7):
        d=bpy.data.lights.new('V4 rose shaft','SPOT');d.energy=110;d.color=(.48,.7,1);d.spot_size=.10;d.spot_blend=.5;d.shadow_soft_size=.025
        o=bpy.data.objects.new('V4 rose shaft',d);s.collection.objects.link(o);o.location=(-.42+j*.14,1.95,5.48)
        o.rotation_euler=(Vector((-2.5+j*.83,-.1,.6))-o.location).to_track_quat('-Z','Y').to_euler()
    for o in s.objects:
        if o.type=='LIGHT' and not o.hide_render:
            if 'blood' in o.name or 'red rear' in o.name:o.data.energy*=.28
            if 'frontal' in o.name:o.data.energy=170
            if 'heart spill' in o.name:o.data.energy=65
    # Small wet beads on the exposed bronze; instanced mesh, deterministic placement.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=6,radius=1)
    bead=bpy.context.object;bead.name='V4 rain bead';bead.data.materials.append(white);bead.hide_render=True
    for j in range(32):
        ob=bead.copy();ob.data=bead.data;s.collection.objects.link(ob);ob.hide_render=False
        ob.location=(rng.uniform(-.4,.4),-.43,rng.uniform(1.45,3.65));ob.scale=(.004,.004,.009);fg.append(ob)
    # No stylized edge passes; physically traced reflections and indirect light.
    s.render.engine='CYCLES';s.cycles.samples=128;s.cycles.use_adaptive_sampling=True;s.cycles.adaptive_threshold=.035
    s.cycles.use_denoising=True;s.cycles.denoiser='OPENIMAGEDENOISE';s.cycles.max_bounces=8;s.cycles.volume_bounces=2;s.cycles.transparent_max_bounces=8
    device='CPU'
    try:
        pref=bpy.context.preferences.addons['cycles'].preferences
        for kind in ('OPTIX','CUDA','HIP','ONEAPI'):
            try:
                pref.compute_device_type=kind;pref.get_devices();gpu=[d for d in pref.devices if d.type!='CPU']
                if gpu:
                    for d in pref.devices:d.use=d.type!='CPU'
                    s.cycles.device='GPU';device=kind;break
            except Exception:pass
    except Exception:pass
    for ob in s.objects:
        if 'diagonal rain' in ob.name:
            start=ob.location.copy()
            ob.location=start+Vector((-.035,0,-.18));ob.keyframe_insert(data_path='location',frame=0)
            ob.location=start+Vector((.035,0,.18));ob.keyframe_insert(data_path='location',frame=2)
    s.frame_set(1)
    s.render.use_freestyle=False;s.render.use_motion_blur=True;s.render.motion_blur_shutter=.3
    cam.data.dof.use_dof=True;cam.data.dof.focus_distance=12.3;cam.data.dof.aperture_fstop=5.6
    s.view_settings.exposure=-.65
    s['v4_device']=device;s['v4_style']='Procedural PBR / Cycles / OIDN / no cel or normals'

W=old.WORK; random.seed(61126)
if not (W/'icon_v3a_backup.png').exists():shutil.copy2(W/'icon_master.png',W/'icon_v3a_backup.png')
root=old.load_boss();s=bpy.context.scene
for o in s.objects:
    if o.type in ('MESH','CURVE'):o.hide_render=o not in root.children_recursive
for o in root.children_recursive:
    if o.type in ('MESH','CURVE'):
        o.hide_render=any(k in o.name for k in ('induction arc','runoff','rivulet','Rain-polished'))
black=old.material('V3 blackened bronze',(.006,.008,.010),.18)
edge=old.material('V3 worn silver bronze',(.012,.018,.024),.18)
white=old.material('V3 white crystal',(.85,.97,1),.2,16)
for o in root.children_recursive:
    if o.type not in ('MESH','CURVE'):continue
    o.data.materials.clear()
    o.data.materials.append(white if any(k in o.name for k in ('Heart first','Crystal shaded')) else edge if any(k in o.name for k in ('arris','shackle','arm chain')) else black)
stone=old.material('V3 ruined basalt',(.025,.032,.040),.0)
silver=old.material('V3 cold stone edges',(.045,.060,.075),.0)
cyan=old.flat('V3 halo cyan',(.42,.86,1.3))
red=old.flat('V3 ember',(.85,.018,.007))
fg=[];bg=[]
def tube(name,pts,r,mat,group=fg):
    o=old.common.tube(name,pts,r,mat);group.append(o);return o
def mesh(name,vs,fs,mat,group=bg):
    o=old.mesh(name,vs,fs,mat);group.append(o);return o
def arc(name,cx,y,cz,rx,rz,a,b,r,mat,group=fg):
    return tube(name,[(cx+rx*math.cos(t),y,cz+rz*math.sin(t)) for t in [a+(b-a)*i/40 for i in range(41)]],r,mat,group)
# Carved basalt: rough mineral surface, block voussoirs and nested mouldings.
for mat in (stone,silver):
    ns=mat.node_tree.nodes; bs=next(n for n in ns if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Roughness'].default_value=.91
    noise=ns.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=19
    bump=ns.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.48;bump.inputs['Distance'].default_value=.055
    mat.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']);mat.node_tree.links.new(bump.outputs['Normal'],bs.inputs['Normal'])
def ogive(width,base,spring,peak,y):
    return [(-width,y,base),(-width,y,spring)]+[(-width*(1-t)**.70,y,spring+(peak-spring)*t) for t in [i/32 for i in range(1,33)]]+[(width*t**.70,y,peak-(peak-spring)*t) for t in [i/32 for i in range(1,33)]]+[(width,y,base)]
def masonry(name,pts,width,depth,mat):
    for a,b in zip(pts,pts[1:]):
        a,b=Vector(a),Vector(b);t=(b-a).normalized();n=Vector((t.z,0,-t.x));a+=t*.008;b-=t*.008
        vs=[tuple(c+n*width*u+Vector((0,depth*v,0))) for c in (a,b) for u,v in ((-1,-1),(1,-1),(1,1),(-1,1))]
        o=mesh(name,vs,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],mat,fg)
        bevel=o.modifiers.new('Eroded arris','BEVEL');bevel.width=.018;bevel.segments=2
for i in range(3):
    masonry('V3 carved ogival voussoir',ogive(2.10+i*.16,.08,3.55,5.64+i*.13,1.25+i*.07),.082,.15,stone if i!=1 else silver)
for side in (-1,1):
    for x in (2.02,2.20,2.38):
        tube('V3 basalt colonette',[(side*x,1.04,.12),(side*x,1.04,3.54)],.068,stone)
        for z in (.22,.40,3.36,3.51):
            o=old.common.box('V3 sculpted capital',(side*x,1.04,z),(.20,.29,.115),stone,bevel=.027);fg.append(o)
    for z in (.68,1.51,2.28,3.05):
        tube('V3 stone fracture',[(side*2.46,.98,z+.15),(side*2.31,.97,z+.07),(side*2.34,.97,z),(side*2.15,.97,z-.10)],.012,black)
    for j in range(7):
        t=(j+1)/9;x=side*(2.44*(1-t)**.70);z=3.55+2.37*t
        mesh('V3 carved acanthus crocket',[(x,1.24,z-.10),(x+side*.22,1.23,z+.03),(x+side*.25,1.25,z+.22),(x+side*.10,1.08,z+.14),(x,1.13,z+.17)],[(0,1,3),(1,2,3),(2,4,3),(4,0,3)],stone,fg)
for z,w in ((5.98,.13),(6.17,.085)):
    mesh('V3 stone finial',[(-w,1.25,z),(0,1.13,z+.26),(w,1.25,z),(0,1.4,z-.1)],[(0,1,2),(0,3,1),(1,3,2)],silver,fg)
# Thick stone rose, recessed foils; reads as the hood's cold aureole.
for r in (.72,.88):arc('V3 carved rose rim',0,1.6,4.62,r,r,0,math.tau,.068,stone)
for j in range(8):
    a=math.tau*j/8
    arc('V3 rose stone foil',.45*math.cos(a),1.56,4.62+.45*math.sin(a),.26,.26,0,math.tau,.045,silver)
    tube('V3 stone mullion',[(.18*math.cos(a),1.55,4.62+.18*math.sin(a)),(.81*math.cos(a),1.55,4.62+.81*math.sin(a))],.033,stone)
# Fractured aureole; interrupted arcs remain readable at small sizes.
for r in (.69,.83):
    for a,b in ((.08,1.35),(1.58,2.77),(3.03,4.33),(4.65,6.03)):
        arc('V3 broken halo',0,.55,3.96,r,r,a,b,.017 if r<.8 else .009,cyan)
# Fallen angel anatomy: bent humerus, elbow, wrist and overlapping feather fans.
feather=old.material('V3 charcoal flight feathers',(.024,.031,.042),.025)
cover=old.material('V3 soft covert feathers',(.037,.048,.060),.02)
def plume(name,start,end,width,mat,seed):
    rng=random.Random(seed);a=Vector(start);b=Vector(end);d=b-a
    n=Vector((-d.z,0,d.x)).normalized();vs=[]
    # Curved vanes, uneven barb notches and a fine pointed tip.
    for k in range(13):
        t=k/12;center=a+d*t+n*(math.sin(t*math.pi)*width*.32)
        center.y-=math.sin(t*math.pi)*.055
        w=width*(math.sin(math.pi*(t*.94+.035))**.75)*(1-t*.52)
        for sign in (-1,1):
            notch=.43 if k in (7+seed%3,10) and sign==(-1 if seed%2 else 1) else 1
            vs.append(tuple(center+n*sign*w*notch))
    vs.extend([tuple(b)])
    faces=[(2*k,2*k+1,2*k+3,2*k+2) for k in range(12)]+[(24,25,26)]
    o=mesh(name,vs,faces,mat,fg)
    tube('V3 tapered feather rachis',[tuple(a+d*t+n*(math.sin(t*math.pi)*width*.32)-Vector((0,.012,0))) for t in (0,.25,.5,.75,.91)],.005,edge)
    return o
for side in (-1,1):
    bones=[(side*.42,.73,3.24),(side*.98,.78,3.72),(side*1.22,.82,4.30),(side*2.04,.87,4.78)]
    tube('V3 wing humerus elbow wrist',bones,.065,black)
    tube('V3 cyan upper bone rim',[(x,y-.035,z+.035) for x,y,z in bones],.022,edge)
    # Secondaries spread in a rounded lower fan, rather than parallel slats.
    for j in range(8):
        t=j/7
        plume('V3 overlapping secondary',(side*(.62+.67*t),.78,3.47+.80*t),(side*(.87+1.03*t),.69,2.65+.54*t),.135,feather,j+20)
    # Long primaries radiate from wrist/phalanges; two torn gaps replaced by chain.
    for j in range(10):
        t=j/9;start=(side*(1.27+.75*t),.84,4.29+.47*t)
        end=(side*(1.52+1.10*t),.66,2.94+1.33*t)
        if j in ((3,7) if side<0 else (5,)):
            for k in range(9):
                f=k/9;x=start[0]+(end[0]-start[0])*f;z=start[2]+(end[2]-start[2])*f
                arc('V3 chain replacing missing primary',x,.70,z,.032 if k%2 else .051,.065,0,math.tau,.010,edge)
            continue
        plume('V3 torn long primary',start,end,.135,feather,40+j)
    # Shingled short coverts conceal the bases with organic overlapping rows.
    for row in range(3):
        for j in range(12):
            t=j/11;x=.62+1.40*t;z=3.47+1.28*t-row*.105
            plume('V3 layered short covert',(side*x,.60-row*.035,z),(side*(x+.09+.13*t),.54-row*.035,z-.27-.15*t),.073,cover,80+row*12+j)
    for j in range(3):
        x=side*(1.55+.34*j);z=2.52-.51*j
        plume('V3 falling torn feather',(x,.24,z),(x+side*(.16-.10*j),.20,z-.37),.067,feather,140+j)
# Lighting: cold behind shoulders, blood-red underneath, almost no frontal fill.
for o in s.objects:
    if o.type=='LIGHT':o.hide_render=True
s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.008,.014,.023,1)
s.world.node_tree.nodes['Background'].inputs[1].default_value=.12
def light(name,pos,target,power,color,size):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=color;d.shape='DISK';d.size=size
    o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
light('V3 divine rim',(-.5,1.1,5.7),(0,0,3),300,(.70,.89,1),1.5)
light('V3 cold side rim',(2,.5,4.4),(0,0,3),220,(.54,.80,1),1.2)
light('V3 blood uplight',(0,-.45,.06),(0,.6,2.1),2600,(1,.012,.025),2.2)
light('V3 dim frontal fill',(-2,-4,4),(0,0,2.8),65,(.42,.58,.68),4)
light('V3 heart spill',(0,-1,2.8),(0,0,2.7),28,(.76,.94,1),.35)
light('V3 red rear flood',(0,1.15,.12),(0,1.3,3.0),2100,(1,.025,.012),2.6)
light('V3 white hood rim',(0,.8,4.9),(0,0,3.7),220,(.8,.94,1),.85)
ICON_SCALE=5.75
cam=old.camera((0,-12,3.10),(0,.3,2.80),ICON_SCALE)
# Background night, rendered planes of rays, diagonal rainfall and flooded floor.
for i in range(32):
    z=-2+i*.30;v=max(0,1-abs(z-4.8)/6)
    mat=old.flat('V3 night gradient',(.002+.010*v,.004+.028*v,.008+.046*v))
    mesh('V3 night', [(-9,4,z),(9,4,z),(9,4,z+.31),(-9,4,z+.31)],[(0,1,2,3)],mat)
# Smooth participating volumes: shafts originate above/behind the rose.
vol=bpy.data.materials.new('V3 soft rose light volume');vol.use_nodes=True
ns=vol.node_tree.nodes;ns.clear();links=vol.node_tree.links
out=ns.new('ShaderNodeOutputMaterial');v=ns.new('ShaderNodeVolumePrincipled')
v.inputs['Color'].default_value=(.57,.80,1,1);v.inputs['Anisotropy'].default_value=.25
v.inputs['Emission Color'].default_value=(.55,.84,1,1)
tex=ns.new('ShaderNodeTexCoord');sub=ns.new('ShaderNodeVectorMath');sub.operation='SUBTRACT';sub.inputs[1].default_value=(.5,.5,0)
links.new(tex.outputs['Generated'],sub.inputs[0])
mul=ns.new('ShaderNodeVectorMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=(1,1,0);links.new(sub.outputs['Vector'],mul.inputs[0])
length=ns.new('ShaderNodeVectorMath');length.operation='LENGTH';links.new(mul.outputs['Vector'],length.inputs[0])
rad=ns.new('ShaderNodeMapRange');rad.interpolation_type='SMOOTHERSTEP';rad.inputs['From Min'].default_value=.12;rad.inputs['From Max'].default_value=.50;rad.inputs['To Min'].default_value=1;rad.inputs['To Max'].default_value=0;links.new(length.outputs['Value'],rad.inputs['Value'])
sep=ns.new('ShaderNodeSeparateXYZ');links.new(tex.outputs['Generated'],sep.inputs[0])
fade=ns.new('ShaderNodeMapRange');fade.interpolation_type='SMOOTHERSTEP';fade.inputs['From Min'].default_value=.02;fade.inputs['From Max'].default_value=.48;links.new(sep.outputs['Z'],fade.inputs['Value'])
factor=ns.new('ShaderNodeMath');factor.operation='MULTIPLY';links.new(rad.outputs[0],factor.inputs[0]);links.new(fade.outputs[0],factor.inputs[1])
for socket,strength in (('Density',.055),('Emission Strength',.43)):
    gain=ns.new('ShaderNodeMath');gain.operation='MULTIPLY';gain.inputs[1].default_value=strength;links.new(factor.outputs[0],gain.inputs[0]);links.new(gain.outputs[0],v.inputs[socket])
links.new(v.outputs['Volume'],out.inputs['Volume'])
for j in range(7):
    a=Vector((-.42+j*.14,2.05,5.58));b=Vector((-2.65+j*.88,.10,1.40));d=a-b
    bpy.ops.mesh.primitive_cone_add(vertices=32,radius1=.32 if j%2 else .42,radius2=.055,depth=d.length,location=(a+b)/2)
    o=bpy.context.object;o.name='V3 descending rose volumetric ray';o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(vol);bg.append(o)
water=old.material('V3 black flood',(.035,.001,.003),.55, .12)
ns=water.node_tree.nodes;bs=next(n for n in ns if n.type=='BSDF_PRINCIPLED');bs.inputs['Roughness'].default_value=.19
pos=ns.new('ShaderNodeNewGeometry');stretch=ns.new('ShaderNodeVectorMath');stretch.operation='MULTIPLY';stretch.inputs[1].default_value=(1.4,12,1)
noise=ns.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=1.8;noise.inputs['Detail'].default_value=2
ramp=ns.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.33;ramp.color_ramp.elements[0].color=(.003,.00005,.0002,1);ramp.color_ramp.elements[1].position=.72;ramp.color_ramp.elements[1].color=(.12,.0005,.004,1)
water.node_tree.links.new(pos.outputs['Position'],stretch.inputs[0]);water.node_tree.links.new(stretch.outputs[0],noise.inputs['Vector']);water.node_tree.links.new(noise.outputs['Fac'],ramp.inputs[0]);water.node_tree.links.new(ramp.outputs[0],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=.85
mesh('V3 flooded floor',[(-100,-100,-.08),(100,-100,-.08),(100,4,-.08),(-100,4,-.08)],[(0,1,2,3)],water)
for i in range(32):
    z=i*.085;fade=(1-i/32)**1.8
    mat=old.flat('V3 blood mist',(.29*fade+.008,.005+.017*i/32,.014+.024*i/32))
    mesh('V3 rising blood glow',[(-6,2.4,z),(6,2.4,z),(6,2.4,z+.086),(-6,2.4,z+.086)],[(0,1,2,3)],mat)
for j in range(170):
    z=random.uniform(-.02,.018);x=random.uniform(-3,3);y=random.uniform(-14,2.6)
    w=random.uniform(.03,.33)*(1 if abs(x)>1.3 else .7)
    mat=old.flat('V3 red water reflection',(.08+random.random()*.26,.002,.008))
    mesh('V3 ember ripple',[(x-w,y,z),(x+w,y,z),(x+w*.8,y+.018,z),(x-w*.8,y+.018,z)],[(0,1,2,3)],mat)
for j in range(18):
    x=random.uniform(-2.2,2.2);y=random.uniform(-1.2,2.0);r=random.uniform(.06,.24)
    tube('V3 rain ring on black water',[(x+r*math.cos(t),y+r*math.sin(t),-.048) for t in [math.tau*k/32 for k in range(33)]],.0035,red,bg)
s.eevee.use_raytracing=True
for j in range(220):
    x=random.uniform(-4,4);z=random.uniform(-.2,7);y=random.choice((-.95,2.1))
    length=random.uniform(.055,.22);w=random.uniform(.002,.006)
    mat=old.flat('V3 lit raindrop',(.12,.25,.32) if z>2 else (.8,.016,.025))
    mesh('V3 diagonal rain',[(x,y,z),(x+w,y,z),(x+w+.045,y,z+length),(x+.045,y,z+length)],[(0,1,2,3)],mat)
for j in range(95):
    x=random.uniform(-2.25,2.25);z=random.uniform(.15,2.65);y=random.uniform(-.7,1.8);w=random.uniform(.008,.019)
    mesh('V3 rising blood ember',[(x-w,y,z),(x+w,y,z+.018),(x+.018,y,z+random.uniform(.035,.09))],[(0,1,2)],red)
for j in range(95):
    x=random.uniform(-1.4,1.4);z=random.uniform(2.5,4.9);y=1.88;w=random.uniform(.003,.010)
    mesh('V3 suspended lit dust',[(x-w,y,z),(x+w,y,z),(x,y,z+w*3)],[(0,1,2)],cyan)
fg.extend(o for o in root.children_recursive if o.type in ('MESH','CURVE') and not o.hide_render)
apply(bpy,s,root,fg,bg,cam,black,edge,white,stone,silver,feather,cover,water,cyan,red)
# Remove obsolete graphic layers from both adaptive collections.
fg[:]=[o for o in fg if not o.hide_render]
bg[:]=[o for o in bg if not o.hide_render]
s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.image_settings.color_depth='8'
s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast'
old.base_compositor(None)
tree=s.compositing_node_group;output=next(n for n in tree.nodes if n.type=='GROUP_OUTPUT');sock=output.inputs['Image'].links[0].from_socket
g=tree.nodes.new('CompositorNodeGlare');g.inputs['Type'].default_value='Fog Glow';g.inputs['Quality'].default_value='Medium';g.inputs['Threshold'].default_value=1.1
# Fine procedural film grain and a restrained soft lens vignette.
grain=tree.nodes.new('ShaderNodeTexNoise');grain.inputs['Scale'].default_value=1024;grain.inputs['Detail'].default_value=0
grainmix=tree.nodes.new('ShaderNodeMix');grainmix.data_type='RGBA';grainmix.blend_type='OVERLAY';grainmix.inputs[0].default_value=.012
tree.links.new(sock,grainmix.inputs[6]);tree.links.new(grain.outputs['Color'],grainmix.inputs[7])
ellipse=tree.nodes.new('CompositorNodeEllipseMask');ellipse.inputs['Position'].default_value=(.5,.5);ellipse.inputs['Size'].default_value=(.83,.88)
blur=tree.nodes.new('CompositorNodeBlur');blur.inputs['Size'].default_value=(190,190)
tree.links.new(ellipse.outputs[0],blur.inputs[0])
vignette=tree.nodes.new('ShaderNodeMix');vignette.data_type='RGBA';vignette.blend_type='MULTIPLY';vignette.inputs[0].default_value=.18
tree.links.new(grainmix.outputs[2],vignette.inputs[6]);tree.links.new(blur.outputs[0],vignette.inputs[7])
tree.links.new(vignette.outputs[2],g.inputs['Image']);tree.links.new(g.outputs['Image'],output.inputs['Image'])
def render(name,size,transparent=False):
    s.render.resolution_x=s.render.resolution_y=size;s.render.resolution_percentage=100
    s.render.film_transparent=transparent;s.render.filepath=str(W/(name+'.png'));bpy.ops.render.render(write_still=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(W/'rain_sower_icon_v4.blend'))
render('icon_master',1024)
# Fit the complete adaptive subject to a conservative 124 px geometric radius.
for o in bg:o.hide_render=True
bpy.context.view_layer.update();inv=cam.matrix_world.inverted();pts=[]
deps=bpy.context.evaluated_depsgraph_get()
for o in fg:
    ob=o.evaluated_get(deps)
    if ob.type in ('MESH','CURVE'):
        me=ob.to_mesh();pts.extend(inv@(ob.matrix_world@v.co) for v in me.vertices);ob.to_mesh_clear()
radius=max(math.hypot(p.x,p.y) for p in pts)
cam.data.ortho_scale=2*radius*432/240
# No bloom on alpha: prevents invisible glow pixels from escaping the safe circle.
tree.links.new(sock,output.inputs['Image'])
render('icon_foreground_432',864,True)
for o in fg:o.hide_render=True
for o in bg:o.hide_render=False
tree.links.new(g.outputs['Image'],output.inputs['Image'])
cam.data.ortho_scale=ICON_SCALE
render('icon_background_432',864)
print('PASS icon_v4: Cycles 128 OIDN '+s['v4_device']+'; 3 renders; no normals',flush=True)
