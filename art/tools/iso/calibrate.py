import sys, math, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/iso'))
# Pillow from the host Python, pure Python package with matching CPython wheels if needed.
sys.path.append(str(Path.home()/'AppData/Local/Programs/Python/Python313/Lib/site-packages'))
import bpy
import iso_rig as iso
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=ROOT/'art/renders/iso_calib'
results={}
def check(name,obj,expected,axes=(0,1)):
    s=bpy.context.scene;bpy.context.view_layer.update()
    pts=[world_to_camera_view(s,s.camera,obj.matrix_world@Vector(v)) for v in obj.bound_box]
    frame=s['iso_frame'];measure=[(max(p[i] for p in pts)-min(p[i] for p in pts))*frame[i] for i in axes]
    results[name]={'measured_px':measure,'expected_px':expected,'tolerance_px':1,'pass':all(abs(a-b)<=1 for a,b in zip(measure,expected))}
    iso.render_frame(OUT/(name+'.png'))
def main():
    iso.create_rig('MAP',(544,288))
    dark=iso.material('Worn dark stone',(.16,.18,.17),grain=True)
    pale=iso.material('Worn limestone',(.32,.30,.25),grain=True)
    for x in range(4):
        for y in range(4):
            bpy.ops.mesh.primitive_plane_add(size=1,location=(x-1.5,y-1.5,0));o=bpy.context.object;o.data.materials.append(dark if (x+y)%2 else pale)
    # Combined bounds for the actual checker mesh.
    bpy.ops.object.select_all(action='DESELECT')
    for ob in bpy.context.scene.objects:
        if ob.type=='MESH': ob.select_set(True);bpy.context.view_layer.objects.active=ob
    bpy.ops.object.join();check('checker',bpy.context.object,[512,256])
    iso.create_rig('MAP',(320,320),target=(0,0,.625))
    cube=iso.common.box('cube',(0,0,.625),(2,2,1.25),iso.material('Worn iron',(.17,.165,.16),metallic=.6,grain=True),bevel=0)
    iso.bake_ao_shadows(cube);check('cube',cube,[256,256]);iso.render_shadow_decal(cube,OUT/'cube.png')
    iso.create_rig('CREA',(128,128),target=(0,0,.5))
    # A very thin physical pole; thickness adds <0.2px to projected height.
    pole=iso.common.box('pole',(0,0,.5),(.06,.002,1),iso.material('Iron',(.25,.23,.2)),bevel=0)
    check('pole',pole,[78.4],axes=(1,))
    iso.create_rig('TOP',(288,288))
    bpy.ops.mesh.primitive_circle_add(vertices=128,radius=1,fill_type='NGON');disc=bpy.context.object;disc.data.materials.append(iso.material('Disc',(.25,.27,.24),grain=True));check('disc_top',disc,[256,256])
    # Store all three reusable cameras in a clean studio file.
    iso.create_rig('MAP',(512,512))
    iso.create_rig('CREA',(512,512),reset=False)
    iso.create_rig('TOP',(512,512),reset=False)
    iso.create_rig('MAP',(512,512),reset=False)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/iso_rig.blend'))
    results['notes']={'measurement':'projected geometric bounds; alpha>=128 raster bounds recorded separately','cube_expected_exact_height':128+1.25*iso.R*math.cos(math.pi/6),'cube_spec_conflict':'At R=64*sqrt(2), height=128+1.25*R*cos(30)=225.98; 256 requires height=1.632993 u, not 1.25.', 'black_emission':'omitted','shadow':'directional sun silhouette; same framing; alpha 0.55'}
    (OUT/'calib.json').write_text(json.dumps(results,indent=2),encoding='utf8')
    from PIL import Image
    canvas=Image.new('RGBA',(1088,640),(48,48,48,255))
    for name,xy in zip(['checker','cube','pole','disc_top','cube_shadow'],[(0,0),(544,0),(864,0),(0,320),(320,320)]):
        with Image.open(OUT/(name+'.png')) as image:
            canvas.alpha_composite(image,xy)
            if name in results:
                threshold=128 if name=='pole' else 64
                b=image.getchannel('A').point(lambda a:255 if a>=threshold else 0).getbbox()
                size=[b[2]-b[0],b[3]-b[1]] if b else [0,0]
                results[name]['raster_alpha_threshold']=threshold
                results[name]['raster_px']=size
                axes=[1] if name=='pole' else [0,1]
                results[name]['raster_pass']=all(abs(size[i]-e)<=1 for i,e in zip(axes,results[name]['expected_px']))
    canvas.convert('RGB').save(ROOT/'art/tools/iso/_c0_contact.png',optimize=True)
    (OUT/'calib.json').write_text(json.dumps(results,indent=2),encoding='utf8')
    print('CALIB', 'PASS' if all(v['pass'] for v in results.values() if 'pass' in v) else 'FAIL')
main()
