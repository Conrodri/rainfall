"""AV3: AV2 geometry/projection preserved, silver foam and cyan crests; 4 compact atlases."""
import sys, re
from pathlib import Path
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
import av2_build as av2
import bpy
from PIL import Image
ROOT=av2.ROOT
FOLDER=av2.DEST/'effects/wave_cone'
WORK=ROOT/'art/renders/averse/av3'
SUFFIXES=('','_n','_e')

def name(page,suffix=''):
    return 'wave_cone'+('' if page==0 else '_atlas'+str(page))+suffix+'.png'

def resources():
    for emission in (False,True):
        path=FOLDER/('wave_cone_emission.tres' if emission else 'wave_cone.tres')
        txt=path.read_text()
        txt=re.sub(r'^\[ext_resource[^\n]+\n','',txt,flags=re.M)
        txt=re.sub(r'\[sub_resource type="CanvasTexture"[^\[]+','',txt)
        ext=[];canvas=[]
        for page in range(4):
            base='res://assets/sprites/characters/averse/effects/wave_cone/'
            ext.append(f'[ext_resource type="Texture2D" path="{base}{name(page,"_e" if emission else "")}" id="d{page}"]')
            if not emission:
                ext.append(f'[ext_resource type="Texture2D" path="{base}{name(page,"_n")}" id="n{page}"]')
                canvas.append(f'[sub_resource type="CanvasTexture" id="ct{page}"]\ndiffuse_texture = ExtResource("d{page}")\nnormal_texture = ExtResource("n{page}")\n')
        def frame(m):
            row,f=int(m[1]),int(m[2]);page=row//2;slot=(row%2)*6+f
            atlas=f'ExtResource("d{page}")' if emission else f'SubResource("ct{page}")'
            return f'[sub_resource type="AtlasTexture" id="a{row}_{f}"]\natlas = {atlas}\nregion = Rect2({slot%4*1024}, {slot//4*1024}, 1024, 1024)'
        txt=re.sub(r'\[sub_resource type="AtlasTexture" id="a(\d+)_(\d+)"\]\natlas = [^\n]+\nregion = Rect2\([^\n]+\)',frame,txt)
        txt=txt.replace('[gd_resource type="SpriteFrames" format=3]', '[gd_resource type="SpriteFrames" format=3]\n'+'\n'.join(ext)+'\n\n'+'\n'.join(canvas))
        path.write_text(txt)

def render():
    scene=av2.iso_rig.create_rig('CREA',1024)
    scene.eevee.taa_render_samples=8
    scene.render.threads_mode='FIXED';scene.render.threads=8
    water,foam,cyan=av2.materials()
    p=foam.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=av2.rgb('BED2CF')
    p.inputs['Emission Color'].default_value=av2.rgb('92BFC3')
    p.inputs['Emission Strength'].default_value=.5
    p=cyan.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Strength'].default_value=3.2
    original=av2.tube
    def crest_tube(label,pts,radius,mat,root):
        if label=='Broken cyan caustic':radius=.032
        if label=='Silt foam crest':radius=.038
        return original(label,pts,radius,mat,root)
    av2.tube=crest_tube
    atlases=[{s:Image.new('RGBA',(4096,3072)) for s in SUFFIXES} for _ in range(4)]
    for f in range(6):
        obj=av2.geometry('wave_cone',f,6,(water,foam,cyan));av2.iso_rig.bake_ao_shadows(obj)
        for row,d in enumerate(av2.iso_rig.DIRECTIONS):
            obj.rotation_euler.z=av2.iso_rig.DIRECTIONS[d]
            path=WORK/(d+'_'+str(f)+'.png')
            av2.iso_rig.set_frame(1024,'CREA');scene.render.resolution_percentage=50
            av2.iso_rig.render_frame(path)
            slot=(row%2)*6+f
            for su in SUFFIXES:
                with Image.open(path.with_name(path.stem+su+'.png')) as im:
                    atlases[row//2][su].alpha_composite(im.convert('RGBA'),(slot%4*1024,slot//4*1024))
        for ob in [*obj.children_recursive,obj]:bpy.data.objects.remove(ob,do_unlink=True)
        print('AV3 FRAME PASS',f,flush=True)
    for page,passes in enumerate(atlases):
        for su,im in passes.items():im.save(FOLDER/name(page,su),optimize=True,compress_level=9)
    resources()
    print('AV3 RENDER PASS',flush=True)

if __name__=='__main__':render()
