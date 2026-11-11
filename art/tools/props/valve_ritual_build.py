import bpy, math, os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..'))
OUT = os.path.join(ROOT, 'game/assets/sprites/props/secret')
BLEND = os.path.join(ROOT, 'art/blender/props/valve_ritual.blend')
os.makedirs(OUT, exist_ok=True)
os.makedirs(os.path.dirname(BLEND), exist_ok=True)

BIOMES = {
    'terraces': ((.27,.34,.31,1), (.08,.48,.42,1)),
    'rust_city': ((.31,.17,.10,1), (.95,.22,.035,1)),
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

def cylinder(name, loc, radius, depth, material, vertices=16, rotation=(0,0,0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rotation)
    o=bpy.context.object; o.name=name; o.data.materials.append(material)
    mod=o.modifiers.new('worn edges','BEVEL'); mod.width=.018; mod.segments=1
    o.modifiers.new('weighted corners','WEIGHTED_NORMAL'); return o

def build(biome, closed):
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH': bpy.data.objects.remove(o, do_unlink=True)
    base, accent=BIOMES[biome]
    body=mat('aged bronze verdigris' if biome=='terraces' else 'worn cast iron',base)
    iron=mat('dark iron',(.09,.085,.075,1)); oak=mat('weathered oak',(.31,.20,.10,1))
    glow=mat('biome accent',accent,2.5 if closed else .25)
    # Pivot and low base stay at 80% of the image height.
    cube('valve plinth',(0,0,.17),(.78,.50,.30),body,.07)
    for x in (-.28,.28): cylinder('mounting bolt',(x,-.22,.20),.045,.035,iron,12,(math.pi/2,0,0))
    cylinder('short pipe',(0,0,.48),.19,.62,body,16)
    cylinder('pipe collar',(0,-.01,.68),.24,.09,iron,16)
    cylinder('valve stem',(0,-.02,.83),.055,.30,iron,12)
    # Volant lies in the image plane; open state is turned, closed state aligned.
    z=1.00; angle=math.radians(22 if not closed else 0)
    bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=8, location=(0,-.07,z), major_radius=.29, minor_radius=.045, rotation=(math.pi/2,0,angle))
    rim=bpy.context.object; rim.name='handwheel rim'; rim.data.materials.append(oak if biome=='terraces' else iron)
    for i in range(4):
        a=angle+i*math.pi/2
        direction=Vector((math.cos(a),0,math.sin(a)))
        start=Vector((0,-.07,z)); end=start+direction*.27
        spoke=cube('handwheel spoke',(end+start)/2,(.055,.065,.30),oak if biome=='terraces' else iron,.018)
        spoke.rotation_euler[1]=-a
    cylinder('handwheel hub',(0,-.09,z),.095,.12,glow if closed else iron,12,(math.pi/2,0,0))
    if not closed:
        # Small bright drip stream signals the open leak.
        for i in range(3):
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=(.29,-.12,.48-i*.10))
            drip=bpy.context.object; drip.name='leaking water'; drip.scale=(.055,.035,.075); drip.data.materials.append(glow)
    cube('foot',(0,0,.025),(.82,.56,.08),body,.05)

def render(biome, closed):
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
    name=f'valve_{biome}_{"on" if closed else "off"}'
    s.render.filepath=os.path.join(OUT,name+'.png'); bpy.ops.render.render(write_still=True)
    for o in bpy.context.scene.objects:
        if o.type=='MESH':
            for m in o.data.materials:
                if m and m.name=='biome accent':
                    for p in m.node_tree.nodes:
                        if p.type=='BSDF_PRINCIPLED': p.inputs['Base Color'].default_value=(1,1,1,1); p.inputs['Emission Color'].default_value=(1,1,1,1); p.inputs['Emission Strength'].default_value=2.5
    s.render.filepath=os.path.join(OUT,name+'_e.png'); bpy.ops.render.render(write_still=True)
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH': bpy.data.objects.remove(o, do_unlink=True)
    shadow=mat('baked shadow',(.008,.006,.005,1)); bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=(0,0,.01)); sh=bpy.context.object; sh.scale=(.65,.38,.025); sh.data.materials.append(shadow)
    s.render.filepath=os.path.join(OUT,name+'_shadow.png'); bpy.ops.render.render(write_still=True)

for b in ('terraces','rust_city'):
    for closed in (False,True):
        build(b,closed); render(b,closed)
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
print('PASS valve_ritual 12 renders')
