"""P1: approved C4 Ardent, T4/T1 studio portrait camera, no animation edits."""
from pathlib import Path
import sys, math
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/iso'))
import iso_rig
from PIL import Image
OUT=ROOT/'game/assets/sprites/characters/ardent'

def build():
    # T1/T2 reports lead to the final T4 portrait camera, preserved verbatim.
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/tocsin_t4_portraits.blend'))
    ref=bpy.context.scene
    camera_matrix=ref.camera.matrix_world.copy()
    scale=ref.camera.data.ortho_scale
    lights=[(o.name,o.matrix_world.copy(),o.data.energy,tuple(o.data.color)) for o in ref.objects if o.type=='LIGHT' and o.data.type in ('SUN','AREA')]
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/ardent_iso.blend'))
    s=bpy.context.scene;s.frame_set(1)
    root=bpy.data.objects['Ardent_Root']
    for ob in [root,*root.children_recursive]:
        ob.animation_data_clear()
    root.rotation_euler.z=-.16
    # Same bust scale and view; translate the target to the human shoulder line.
    s.camera.matrix_world=camera_matrix
    s.camera.location.z+=.32
    s.camera.data.ortho_scale=scale;s.camera.data.shift_x=.055;s.camera.data.shift_y=0
    for name,matrix,energy,color in lights:
        ob=bpy.data.objects.get(name)
        if ob:
            ob.matrix_world=matrix;ob.data.energy=energy;ob.data.color=color
    s.render.engine='BLENDER_EEVEE';s.render.film_transparent=True
    s.render.resolution_x=s.render.resolution_y=512;s.render.resolution_percentage=100
    s.eevee.taa_render_samples=24;s['iso_frame']=[256,256]
    s.view_settings.view_transform='Standard'
    iso_rig.render_frame(OUT/'portrait.png',passes=True)
    for suffix in ('','_n','_e'):
        with Image.open(OUT/('portrait'+suffix+'.png')) as im:
            assert im.size==(256,256) and im.mode=='RGBA'
            assert im.getchannel('A').getbbox()
    board=Image.new('RGBA',(1024,512),(22,26,31,255))
    for i,name in enumerate(('ardent','tocsin','averse','arpenteuse')):
        p=ROOT/'game/assets/sprites/characters'/name/'portrait.png'
        with Image.open(p) as im:board.alpha_composite(im.convert('RGBA'),(i*256,0))
    for i,suffix in enumerate(('','_n','_e')):
        with Image.open(OUT/('portrait'+suffix+'.png')) as im:board.alpha_composite(im,(i*256,256))
    for i,p in enumerate((ROOT/'art/tools/iso/_c4_contact.png',ROOT/'art/tools/characters/_m2_contact.png',ROOT/'art/tools/iso/_c1_contact.png')):
        with Image.open(p) as im:
            thumb=im.convert('RGBA');thumb.thumbnail((84,256));board.alpha_composite(thumb,(768+i*85,256))
    board.save(ROOT/'art/tools/night/_p1_contact.png',optimize=True)
    print('P1 PASS: 3 RGBA 256px; original camera scale',scale,flush=True)

if __name__=='__main__':build()

