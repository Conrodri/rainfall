"""P0 (a) : lumieres, halos, vignette, ciels, gouttes, etincelles, glint, mote, trainees, impacts.
Blender 5.2 --background --python p0a_sprites.py"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parents[1] / 'ambiance'))
sys.path.insert(0, str(Path(__file__).parents[1] / 'cel'))
sys.path.insert(0, str(Path(__file__).parents[1] / 'iso'))
from amb_lib import *
import numpy as np
from mathutils import Vector
setup()
# Seules les sorties de ce lot sont écrites.
O = Path(__file__).parents[3] / 'game/assets/sprites/ambiance'
O.mkdir(parents=True, exist_ok=True)

def rad(e): return hyp(e.x, e.y)

# ------------------------------------------------------------- lumieres (gris/blanc sur alpha)
run('light_soft', O / 'light_soft_256.png', 256, 256,
    lambda e: (None, expn(-(rad(e) ** 2) * 5.0) * smooth(1.0, 0.8, rad(e))))
run('light_hard', O / 'light_hard_256.png', 256, 256,
    lambda e: (None, smooth(1.0, 0.75, rad(e))))
run('halo_soft', O / 'halo_soft_256.png', 256, 256,
    lambda e: (None, expn(-(rad(e) ** 2) * 2.2) * smooth(1.0, 0.72, rad(e))))

def ring1(e):
    r = rad(e)
    return None, smooth(0.66, 0.78, r) * smooth(1.0, 0.88, r)
run('light_ring', O / 'light_ring_256.png', 256, 256, ring1)

def ring2(e):  # anneau bicolore : moitie haute (180 deg) pleine, moitie basse a 40 %
    r = rad(e); ring = smooth(0.66, 0.74, r) * smooth(1.0, 0.92, r)
    half = smooth(-0.12, 0.12, e.y)
    return None, ring * (0.4 + 0.6 * half)
run('light_ring_2', O / 'light_ring_256_2.png', 256, 256, ring2)

# ------------------------------------------------------------- vignette (noir, alpha = assombrissement)
def vig(e):
    r = rad(e)
    return 0.0, 0.88 * smooth(0.42, 1.38, r) ** 1.35
run('vignette', O / 'vignette_1024.png', 1024, 1024, vig)

# ------------------------------------------------------------- ciels (colores, opaques)
def mix3(c0, c1, t): return tuple(lerp(a, b, t) for a, b in zip(c0, c1))
def grad(t, stops):
    col = srgb(stops[0][1])
    for i in range(1, len(stops)):
        col = mix3(col, srgb(stops[i][1]), smooth(stops[i - 1][0], stops[i][0], t))
    return col
def sky(stops, wob=0.015):
    def b(e):
        t = e.v + wob * sin(e.v * 38.0) - 0.01
        # t decroit vers le bas : stops donnes du haut (v=1) vers le bas (v=0)
        return grad(1.0 - t, stops), 1.0
    return b
H = lambda s: tuple(int(s[i:i + 2], 16) / 255 for i in (1, 3, 5))
# Paramètres repris de sky_dawn_256x64 et adaptés au ciel nocturne.
run('sky_nuit_de_lanternes', O / 'sky_nuit_de_lanternes_256x64.png', 256, 64,
    sky([(0.0, H('#090F20')), (0.34, H('#101D38')), (0.69, H('#1E3150')), (0.84, H('#273956')), (1.0, H('#19283F'))], 0.004), raw=True)
seam_path=O/'sky_nuit_de_lanternes_256x64.png'
seam_img=bpy.data.images.load(str(seam_path), check_existing=False)
seam_px=np.empty(256*64*4,dtype=np.float32); seam_img.pixels.foreach_get(seam_px); seam_px=seam_px.reshape(64,256,4)
seam_avg=(seam_px[:,0,:]+seam_px[:,-1,:])*0.5; seam_px[:,0,:]=seam_avg; seam_px[:,-1,:]=seam_avg
seam_img.pixels.foreach_set(seam_px.reshape(-1)); seam_img.filepath_raw=str(seam_path); seam_img.file_format='PNG'; seam_img.save(); bpy.data.images.remove(seam_img)

# Halo gris sur alpha, centrÃ©, chaud par teinteur runtime.
def lantern(e):
    r = rad(e)
    return None, smooth(1.0, 0.96, r) * expn(-(r * r) * 4.6)
run('lantern_glow', O / 'lantern_glow_64.png', 64, 64, lantern, raw=True)
# Symétrie stricte et gris neutre, coeur blanc opaque, bord noir transparent.
glow_path=O/'lantern_glow_64.png'
glow_img=bpy.data.images.load(str(glow_path), check_existing=False)
glow_px=np.empty(64*64*4,dtype=np.float32); glow_img.pixels.foreach_get(glow_px); glow_px=glow_px.reshape(64,64,4)
alpha=glow_px[...,3].copy(); alpha=(alpha+alpha[::-1,:]+alpha[:,::-1]+alpha[::-1,::-1])*0.25
alpha[0,0]=0.0; alpha[0,-1]=0.0; alpha[-1,0]=0.0; alpha[-1,-1]=0.0; alpha[31,31]=1.0; alpha[31,32]=1.0; alpha[32,31]=1.0; alpha[32,32]=1.0
glow_px[...,:3]=alpha[...,None]; glow_px[...,3]=1.0-alpha
glow_img.pixels.foreach_set(glow_px.reshape(-1)); glow_img.filepath_raw=str(glow_path); glow_img.file_format='PNG'; glow_img.save(); bpy.data.images.remove(glow_img)

def save_blend():
    dst = Path(__file__).parents[2] / 'blender/cel/cosmetics/ciel_nuit_de_lanternes.blend'
    dst.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(dst))

def material(name, color, emission=0):
    m = bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=.86
    p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=emission
    return m

def preview():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc=bpy.context.scene; sc.render.engine='BLENDER_EEVEE'
    sc.eevee.taa_render_samples=16
    sc.render.resolution_x=sc.render.resolution_y=256; sc.render.resolution_percentage=100
    sc.render.image_settings.file_format='PNG'; sc.render.image_settings.color_mode='RGBA'; sc.render.image_settings.color_depth='8'; sc.render.image_settings.compression=25
    sc.view_settings.view_transform='Standard'; sc.view_settings.look='None'; sc.render.film_transparent=False
    world=bpy.data.worlds.new('Nuit de lanternes'); world.use_nodes=True
    world.node_tree.nodes['Background'].inputs['Color'].default_value=(.012,.021,.048,1); world.node_tree.nodes['Background'].inputs['Strength'].default_value=.8; sc.world=world
    water=material('Eau nocturne',(.028,.075,.12)); stone=material('Pierre bleue',(.12,.17,.22)); rice=material('RiziÃ¨re',(.10,.20,.13)); wood=material('Bois',(.16,.09,.045)); gold=material('Lanterne',(.9,.39,.10),2.2); moon=material('Lune voilÃ©e',(.43,.53,.72),.5)
    def cube(name, loc, scale, mat, bevel=0):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o=bpy.context.object; o.name=name; o.dimensions=scale; bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); o.data.materials.append(mat)
        if bevel: b=o.modifiers.new('Soft edges','BEVEL'); b.width=bevel; b.segments=2
        return o
    cube('Terrace water',(0,0,0),(4,3,.12),water,.04)
    for x in [-1.25,0,1.25]:
        cube('Stone terrace rim',(x,-.1,.13),(.16,2.65,.22),stone,.04)
        for y in [-1.1,-.45,.2,.85]: cube('Cool water reflection',(x,y,.245),(.10,.27,.012),material('Reflection '+str(x)+str(y),(.12,.31,.47),.22))
    cube('Raised rice terrace',(.95,.86,.36),(1.45,.75,.54),rice,.06)
    for x in [-1.45,1.25]:
        cube('Lantern post',(x,-.35,.72),(.06,.06,.9),wood,.018)
        cube('Lantern frame',(x,-.35,1.18),(.27,.24,.28),wood,.025)
        cube('Lantern light',(x,-.35,1.18),(.17,.15,.18),gold,.02)
        ld=bpy.data.lights.new('Warm lantern','POINT'); ld.energy=20; ld.color=(1,.32,.08); ld.shadow_soft_size=.7
        ob=bpy.data.objects.new('Warm lantern',ld); bpy.context.collection.objects.link(ob); ob.location=(x,-.35,1.2)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=(-1.05,1.42,2.5)); bpy.context.object.name='Low veiled moon'; bpy.context.object.scale=(.22,.035,.22); bpy.context.object.data.materials.append(moon)
    for x,y,z,r in [(-1.05,1.38,2.5,.34),(-.72,1.4,2.55,.18),(-1.4,1.4,2.43,.14)]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=(x,y,z)); o=bpy.context.object; o.name='Moon veil cloud'; o.scale=(r,.025,r*.28); o.data.materials.append(material('Cloud '+str(x),(.07,.10,.16),.03))
    ld=bpy.data.lights.new('Moon fill','AREA'); ld.energy=70; ld.color=(.36,.52,.85); ld.shape='DISK'; ld.size=5
    ob=bpy.data.objects.new('Moon fill',ld); bpy.context.collection.objects.link(ob); ob.location=(-2,-3,5)
    camd=bpy.data.cameras.new('Preview iso'); cam=bpy.data.objects.new('Preview iso',camd); bpy.context.collection.objects.link(cam); cam.location=(4,-6,5); target=Vector((0,0,.5)); cam.rotation_euler=(target-Vector(cam.location)).to_track_quat('-Z','Y').to_euler(); camd.type='ORTHO'; camd.ortho_scale=4.65; sc.camera=cam
    preview_path=Path(__file__).parents[3]/'game/assets/sprites/cosmetics/previews/nuit_de_lanternes.png'
    preview_path.parent.mkdir(parents=True, exist_ok=True)
    sc.render.filepath=str(preview_path)
    bpy.ops.render.render(write_still=True)
    save_blend()

preview()
print('BILAN nuit_de_lanternes: ciel, halo, aperçu écrits', flush=True)







