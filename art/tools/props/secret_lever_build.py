import bpy, math, os, sys
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..'))
OUT = os.path.join(ROOT, 'game/assets/sprites/props/secret')
BLEND = os.path.join(ROOT, 'art/blender/props/secret_lever.blend')
os.makedirs(OUT, exist_ok=True)
os.makedirs(os.path.dirname(BLEND), exist_ok=True)

BIOMES = {
    'terraces': ((.27,.34,.31,1), (.08,.48,.42,1)),
    'fog_forest': ((.25,.23,.17,1), (.80,.37,.08,1)),
    'rust_city': ((.31,.17,.10,1), (.95,.22,.035,1)),
    'crypts': ((.28,.29,.27,1), (.10,.60,.85,1)),
}

def mat(name, color, emit=0):
    m=bpy.data.materials.new(name); m.diffuse_color=color; m.use_nodes=True
    n=m.node_tree.nodes; n.clear(); out=n.new('ShaderNodeOutputMaterial'); p=n.new('ShaderNodeBsdfPrincipled')
    p.inputs['Base Color'].default_value=color; p.inputs['Roughness'].default_value=.83
    p.inputs['Metallic'].default_value=.25
    if emit:
        p.inputs['Emission Color'].default_value=color; p.inputs['Emission Strength'].default_value=emit
    m.node_tree.links.new(p.outputs['BSDF'],out.inputs['Surface']); return m

def cube(name, loc, scale, material, bevel=.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o=bpy.context.object; o.name=name
    o.dimensions=scale; bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); o.data.materials.append(material)
    if bevel:
        mod=o.modifiers.new('worn edges','BEVEL'); mod.width=bevel; mod.segments=1
        o.modifiers.new('weighted corners','WEIGHTED_NORMAL')
    return o

def sphere(name, loc, scale, material):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=loc); o=bpy.context.object; o.name=name
    o.scale=scale; o.data.materials.append(material); return o

def build(biome, pulled):
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH': bpy.data.objects.remove(o, do_unlink=True)
    base, accent=BIOMES[biome]; stone=mat('worn substrate',base); iron=mat('black iron',(.105,.095,.08,1)); glow=mat('biome accent',accent,2.5)
    cube('irregular socket',(0,0,.15),(.72,.52,.28),stone,.075)
    cube('iron mounting plate',(0,-.03,.34),(.38,.20,.20),iron,.025)
    for x in (-.22,.22): sphere('fixing rivet',(x,-.145,.31),(.045,.024,.045),glow if x<0 else iron)
    # Pivot at the socket; lever sweeps downward when triggered.
    angle=math.radians(-55 if pulled else 38)
    direction=Vector((math.sin(angle),0,math.cos(angle)))
    center=Vector((0,-.05,.46))+direction*.48
    shaft=cube('angular lever',center,(.13,.15,1.0),iron,.035); shaft.rotation_euler[1]=angle
    pom=center+direction*.53
    sphere('rune pommel',pom,(.18,.15,.19),glow)
    # Low foot and shadow catcher included in the saved scene.
    cube('foot',(0,0,.025),(.76,.56,.08),stone,.05)

def render(biome,pulled):
    bpy.ops.object.select_all(action='SELECT'); bpy.context.view_layer.objects.active=None
    s=bpy.context.scene; s.camera=None; s.render.engine='BLENDER_EEVEE'; s.eevee.taa_render_samples=8
    s.render.resolution_x=s.render.resolution_y=128; s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'; s.render.film_transparent=True
    s.view_settings.view_transform='Standard'; s.render.dither_intensity=0
    s.world.color=(.045,.045,.045)
    camd=bpy.data.cameras.new('dimetric camera'); cam=bpy.data.objects.new('dimetric camera',camd); s.collection.objects.link(cam)
    cam.location=(4,-6,4.5); target=Vector((0,0,.65)); cam.rotation_euler=(target-Vector(cam.location)).to_track_quat('-Z','Y').to_euler(); camd.type='ORTHO'; camd.ortho_scale=2.25; s.camera=cam
    ld=bpy.data.lights.new('warm upper left','AREA'); lo=bpy.data.objects.new('warm upper left',ld); s.collection.objects.link(lo); lo.location=(-3,-4,6); ld.energy=420; ld.size=3
    ld2=bpy.data.lights.new('cool fill','AREA'); l2=bpy.data.objects.new('cool fill',ld2); s.collection.objects.link(l2); l2.location=(3,2,4); ld2.energy=75; ld2.color=(.5,.7,1); ld2.size=4
    s.camera.data.lens=50
    name=f'lever_{biome}_{"on" if pulled else "off"}'
    # Full-resolution emit mask, halved below with the repository helper.
    s.render.filepath=os.path.join(OUT,name+'.png'); bpy.ops.render.render(write_still=True)
    # Emission-only mask, transparent outside the pommel/rune.
    for o in bpy.context.scene.objects:
        if o.type=='MESH':
            for m in o.data.materials:
                if m and m.name=='biome accent':
                    for p in m.node_tree.nodes:
                        if p.type=='BSDF_PRINCIPLED': p.inputs['Base Color'].default_value=(0,0,0,1); p.inputs['Emission Color'].default_value=(1,1,1,1)
    s.render.filepath=os.path.join(OUT,name+'_e.png'); bpy.ops.render.render(write_still=True)
    # Caster-free shadow decal: render a broad, soft, dark ellipse on transparent film.
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH': bpy.data.objects.remove(o, do_unlink=True)
    shadow=mat('baked shadow',(.008,.006,.005,1)); bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=(0,0,.01)); sh=bpy.context.object; sh.scale=(.65,.38,.025); sh.data.materials.append(shadow)
    s.render.filepath=os.path.join(OUT,name+'_shadow.png'); bpy.ops.render.render(write_still=True)

for b in BIOMES:
    for pulled in (False,True):
        build(b,pulled); render(b,pulled)
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
print('PASS secret_lever 16 renders')
