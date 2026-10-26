"""MB1: C5 planted shooting anticipation; eight frames, final column held by Godot.
Contact label 8 means terminal pose (column 7), not a ninth frame.
"""
import sys, math, inspect, re, hashlib, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/monsters'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools')]
DIRS=['e','se','s','sw','w','nw','n','ne']
WORK=ROOT/'art/blender/cel/mb1'
SPR=ROOT/'game/assets/sprites/monsters'
NAMES=['leaper_tier2','leaper_tier2_moss','leaper_tier2_rust']
def patch_tres(folder):
    p=folder/(folder.name+'.tres');s=p.read_text();assert 'CanvasTexture' not in s and 'normal_texture' not in s
    if '&"attack_e"' in s:return
    old=s
    s=re.sub(r'load_steps=(\d+)',lambda m:'load_steps='+str(int(m[1])+65),s,count=1)
    pos=s.index('[sub_resource')
    s=s[:pos]+'[ext_resource type="Texture2D" path="res://assets/sprites/monsters/'+folder.name+'/attack.png" id="mb1"]\n\n'+s[pos:]
    subs=''
    anim=[]
    for row,d in enumerate(DIRS):
        refs=[]
        for f in range(8):
            ident=f'mb1_{row}_{f}'
            subs+=f'[sub_resource type="AtlasTexture" id="{ident}"]\natlas = ExtResource("mb1")\nregion = Rect2({f*112}, {row*112}, 112, 112)\n\n'
            refs.append('{"duration": 1.0, "texture": SubResource("'+ident+'")}')
        anim.append('{\n"frames": ['+', '.join(refs)+'],\n"loop": false,\n"name": &"attack_'+d+'",\n"speed": 12.0\n}')
    s=s.replace('[resource]',subs+'[resource]',1)
    end=s.rfind('}]');assert end>0
    s=s[:end+1]+', '+', '.join(anim)+s[end+1:]
    # Existing atlas definitions and animation objects stay byte-identical.
    for block in re.findall(r'\[sub_resource.*?(?=\[)',old,re.S):assert block in s
    p.write_bytes(s.replace("\n","\r\n").encode())
def render():
    import bpy, iso_rig, cel_style as cel
    from PIL import Image
    import halve_emission
    source=inspect.getsource(iso_rig.render_frame)
    ns=dict(iso_rig.__dict__);exec(source.replace("for suffix in ('_n','_e'):","for suffix in ('_e',):"),ns)
    render_frame=ns['render_frame']
    for name,prefix in zip(NAMES,['','n2e_','n3e_']):
        folder=SPR/name;temp=WORK/name;temp.mkdir(parents=True,exist_ok=True)
        if '--resume' in sys.argv and (temp/'done').exists():continue
        src=ROOT/'art/blender/monsters'/(prefix+'leaper_tier2'+('_iso' if not prefix else '')+'.blend')
        bpy.ops.wm.open_mainfile(filepath=str(src))
        scene=bpy.context.scene;scene.render.threads_mode='FIXED';scene.render.threads=8
        root=bpy.data.objects['leaper_tier2'];body=bpy.data.objects['Body']
        scene.frame_set(1)
        for ob in root.children_recursive:
            if ob.animation_data:ob.animation_data_clear()
            if ob.type=='EMPTY' and ob!=body:ob.rotation_euler=(0,0,0)
        body.location=(0,0,0);body.rotation_euler=(0,0,0)
        # Upper body deforms smoothly; every tendon, claw and paw stays planted at ground.
        deforms=[]
        for ob in root.children_recursive:
            if ob.type=='MESH':deforms.append((ob,[v.co.copy() for v in ob.data.vertices]))
        from ash_lord_build import rod
        glow=next(m for m in bpy.data.materials if m.get('rainfall_emissive') or (m.use_nodes and any(n.type=='BSDF_PRINCIPLED' and n.inputs['Emission Strength'].default_value>0 for n in m.node_tree.nodes)))
        before=set(bpy.data.objects)
        rod('MB1 spit release',[(0,-.57,.37),(0,-.72,.37),(0,-.87,.36)],.012,glow,body)
        spit=[o for o in bpy.data.objects if o not in before]
        cel.install('creature',normals=False);cel.toon_materials('creature')
        accents=[]
        for mat in bpy.data.materials:
            if not mat.use_nodes:continue
            for node in mat.node_tree.nodes:
                if node.type=='OUTPUT_AOV' and node.aov_name==cel.AOV and max(node.inputs['Color'].default_value[:3])>0:
                    accents.append((node,tuple(node.inputs['Color'].default_value)))
        sheets={s:Image.new('RGBA',(896,896)) for s in ('','_e')}
        for row,d in enumerate(DIRS):
            root.rotation_euler.z=math.radians(90-45*row)
            for f in range(8):
                recoil=[0,.06,.13,.20,.23,.12,-.18,0][f]
                crouch=[0,.01,.035,.065,.085,.025,-.025,0][f]
                for ob,verts in deforms:
                    for v,base in zip(ob.data.vertices,verts):
                        v.co=base
                        weight=max(0,min(1,(base.z-.07)/.42))
                        v.co.y+=recoil*weight;v.co.z-=crouch*weight
                    ob.data.update()
                for ob in spit:ob.hide_render=f!=6
                gain=[.20,.27,.36,.48,.63,.80,1,.28][f]
                for node,col in accents:node.inputs['Color'].default_value=tuple(v*gain for v in col[:3])+(1,)
                render_frame(temp/f'{d}_{f}.png')
                for suf,im in sheets.items():
                    with Image.open(temp/f'{d}_{f}{suf}.png') as frame:im.paste(frame,(f*112,row*112))
            print('PASS',name,d,flush=True)
        sheets[''].save(folder/'attack.png',optimize=True)
        half=halve_emission.downscale(sheets['_e']);assert max(c.getextrema()[1] for c in half.split()[:3])>2
        half.save(folder/'attack_e.png',optimize=True)
        patch_tres(folder);(temp/'done').write_text('PASS');cel.uninstall()
    contact()
def contact():
    from PIL import Image
    board=Image.new('RGBA',(560,1008),(28,33,36,255))
    for biome,name in enumerate(NAMES):
        run=Image.open(SPR/name/'run.png');attack=Image.open(SPR/name/'attack.png')
        for j,row in enumerate([0,2,6]):
            y=(biome*3+j)*112
            board.alpha_composite(run.crop((0,row*112,112,(row+1)*112)),(0,y))
            for col,f in enumerate([0,3,6,7],1):board.alpha_composite(attack.crop((f*112,row*112,(f+1)*112,(row+1)*112)),(col*112,y))
    board.convert('RGB').save(ROOT/'art/tools/night/_mb1_contact.png')
if __name__=='__main__':render()
