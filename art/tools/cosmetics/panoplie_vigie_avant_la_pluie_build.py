"""Guetteuse de beau temps: original VG1 build/poses/accent compositor, isolated outputs; --resume."""
import sys, json, inspect, shutil, subprocess, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso')]
import vg1_build as vg
import cel_style as cel
BASE=ROOT/'game/assets/sprites/characters/vigie'
OUT=BASE/'skins/vigie_avant_la_pluie'
WORK=ROOT/'art/blender/cel/skins/vigie_avant_la_pluie_frames'
SOURCE=ROOT/'art/blender/cel/skins/vigie_avant_la_pluie.blend'
BLENDER=r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
GODOT=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
HERE=Path(__file__).parent

def materials():
    import bpy
    # Surface substitutions only; geometry and animated accent materials stay intact.
    palette={'waterlogged_reed':'5A5B5E','reed_splits':'5A5B5E','reed_knots':'5A5B5E','oilskin':'2F3A4C','worn_oilskin_edges':'2F3A4C','verdigris_bindings':'B4733A','dented_brass':'B4733A','brass_scratches':'A8946E','wet_leather':'8A5A36','silt':'8A5A36','dried_silt':'8A5A36','soaked_hemp':'B8AE9A'}
    def linear(h):
        return tuple((v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4) for v in [int(h[i:i+2],16)/255 for i in (0,2,4)])+(1,)
    def recolor(m,h,metal=0,rough=.4):
        m['palette_srgb']='#'+h
        bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        for link in list(bs.inputs['Base Color'].links):m.node_tree.links.remove(link)
        for n in list(m.node_tree.nodes):
            if n.type=='VALTORGB':m.node_tree.nodes.remove(n)
        bs.inputs['Base Color'].default_value=linear(h)
        bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
    for name,h in palette.items():recolor(bpy.data.materials['Vigie_'+name],h,.65 if 'brass' in name or 'bindings' in name else 0)
    def variant(source,name,h,metal=0,rough=.84):
        m=bpy.data.materials[source].copy();m.name=name;recolor(m,h,metal,rough);return m
    yew=variant('Vigie_black_dike_wood','Guetteuse_varnished_yew','8A6A3C',rough=.28)
    leather=bpy.data.materials['Vigie_wet_leather']
    grey=variant('Vigie_oilskin','Guetteuse_grey_canvas','5A5B5E')
    copper=bpy.data.materials['Vigie_dented_brass']
    for ob in bpy.data.objects:
        p=ob;anc=[]
        while p:anc.append(p.name);p=p.parent
        if ob.type not in ('MESH','CURVE'):continue
        for slot in ob.material_slots:
            if not slot.material:continue
            if 'Longbow_hand_socket' in anc and slot.material.name=='Vigie_black_dike_wood':slot.material=yew
            if ob.name.startswith('Dented_tube'):slot.material=leather
            if '_oilskin_trouser' in ob.name:slot.material=grey
    # Retain the lower hood as a close wool neck collar. The crown becomes a
    # fitted beret; its outer contour stays within the original pointed crown.
    hood=bpy.data.objects['Slate_hood_open_face'];hood.name='Guetteuse_beret_and_wool_collar'
    for v in hood.data.vertices:
        if v.co.z>.20:
            v.co.x=v.co.x*1.8+.004;v.co.y=.031+(v.co.y-.031)*1.42;v.co.z=.19
    bpy.data.objects['Hood_front_worn_hem'].name='Guetteuse_beret_fitted_band'
    def stud(name,parent,loc,scale):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,location=(0,0,0))
        ob=bpy.context.object;ob.name=name;ob.parent=parent;ob.location=loc;ob.scale=scale;ob.data.materials.append(copper)
    # Small wool cabillou keeps the original skull height.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6)
    tuft=bpy.context.object;tuft.name='Guetteuse_beret_wool_cabillou';tuft.parent=bpy.data.objects['Watchers_neck'];tuft.location=(.004,.031,.201);tuft.scale=(.014,.018,.014);tuft.data.materials.append(bpy.data.materials['Vigie_oilskin'])
    stud('Guetteuse_copper_badge',bpy.data.objects['Watchers_neck'],(.036,-.079,.153),(.012,.005,.009))
    for x in (-.025,.061):
        for z in (.07,.14,.21):stud('Guetteuse_double_breasted_button',bpy.data.objects['Stooped_spine'],(x,-.132,z),(.009,.006,.009))


def render():
    import bpy
    SOURCE.parent.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    if not SOURCE.exists():shutil.copy2(vg.SOURCE,SOURCE)
    vg.SOURCE=SOURCE;vg.RAW=WORK
    # Reuse the original nested pose() and accent_base() without copying them.
    src=inspect.getsource(vg.build).split('    # Validate projected geometry')[0]
    src=src.replace("    cel.install('creature',normals=False)","    skin_materials()\n    cel.install('creature',normals=False)")
    vg.skin_materials=materials
    exec(compile(src,str(vg.__file__),'exec'),vg.__dict__);vg.build()
    s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=8
    s.render.image_settings.compression=35
    facing=bpy.data.objects['Vigie_facing_8_directions']
    for ai,(a,n) in enumerate(vg.ANIMS.items()):
        if '--only' in sys.argv and a!=sys.argv[sys.argv.index('--only')+1]:continue
        for row,d in enumerate(vg.DIRS):
            for f in range(n):
                p=WORK/f'{a}_{d}_{f:02d}.png'
                if '--resume' in sys.argv and p.exists():continue
                s.frame_set(ai*20+1+f);facing.rotation_euler.z=__import__('iso_rig').common.DIRECTIONS[d]
                bpy.context.view_layer.update();s.render.filepath=str(WORK/'current.png');bpy.ops.render.render(write_still=True)
                from PIL import Image
                with Image.open(WORK/'current.png') as im:im.convert('RGBA').resize((192,192),Image.Resampling.LANCZOS).save(p,optimize=True,compress_level=9)
                for q in WORK.glob('current_e__*.png'):q.unlink()
        assemble(a)
        pass
    if '--only' in sys.argv:return
    from mathutils import Vector
    s.frame_set(1);facing.rotation_euler.z=math.radians(12)
    for ob in bpy.data.objects['Longbow_hand_socket'].children_recursive:ob.hide_render=True
    cam=s.camera;cam.rotation_euler=(math.radians(79),0,0);target=Vector((0,-.035,1.194));cam.location=target+cam.rotation_euler.to_matrix()@Vector((0,0,12));cam.data.ortho_scale=.94;cam.data.shift_y=0
    s.render.resolution_x=512;s.render.resolution_y=512;s.render.resolution_percentage=100
    cel.setup_scene(s,samples=8);cel.install('creature',normals=False)
    s.render.filepath=str(WORK/'current.png');bpy.ops.render.render(write_still=True)
    from PIL import Image
    with Image.open(WORK/'current.png') as im:im.convert('RGBA').resize((256,256),Image.Resampling.LANCZOS).save(OUT/'portrait.png',optimize=True,compress_level=9)
    shutil.copy2(BASE/'portrait_e.png',OUT/'portrait_e.png')
    for q in WORK.glob('current_e__*.png'):q.unlink()

def assemble(a):
    from PIL import Image
    n=vg.ANIMS[a];OUT.mkdir(parents=True,exist_ok=True)
    sheet=Image.new('RGBA',(n*192,1536))
    for row,d in enumerate(vg.DIRS):
        for f in range(n):
            with Image.open(WORK/f'{a}_{d}_{f:02d}.png') as im:sheet.paste(im,(192*f,192*row))
    sheet.save(OUT/(a+'.png'),optimize=True,compress_level=9)
    # Exact original accent masks: unchanged emitters, tension and positions.
    shutil.copy2(BASE/(a+'_e.png'),OUT/(a+'_e.png'))

def verify():
    import numpy as np
    from PIL import Image
    report={'sheets':[],'errors':[],'godot':'skipped by orchestrator','texture_budget':'external sequential check; see _panoplie_vigie_budget_after.json'}
    assert not list(OUT.glob('*_n.png'))
    assert not any(k in (OUT/'vigie_avant_la_pluie.tres').read_text() for k in ('CanvasTexture','normal_texture'))
    for a in [*vg.ANIMS,'portrait']:
        if not (OUT/(a+'.png')).exists():continue
        n=vg.ANIMS.get(a,1);cell=192 if a!='portrait' else 256;rows=8 if a!='portrait' else 1
        r=cel.check_sheet('characters/vigie/skins/vigie_avant_la_pluie/'+a+'.png',cell=cell,frames=n,rows=rows,normals=False)
        ref=np.asarray(Image.open(BASE/(a+'.png')).convert('RGBA'));im=np.asarray(Image.open(OUT/(a+'.png')).convert('RGBA'));assert ref.shape==im.shape
        ious=[];overflow=[]
        for y in range(rows):
            for x in range(n):
                aa=ref[y*cell:(y+1)*cell,x*cell:(x+1)*cell,3]>128;bb=im[y*cell:(y+1)*cell,x*cell:(x+1)*cell,3]>128
                ious.append(float((aa&bb).sum()/max(1,(aa|bb).sum())))
                padded=np.pad(aa,2)
                expanded=np.logical_or.reduce([padded[dy:dy+cell,dx:dx+cell] for dy in range(5) for dx in range(5)])
                overflow.append(int((bb&~expanded).sum()))
        assert max(overflow)==0,(a,'accessory exceeds silhouette by >2px')
        ep=OUT/(a+'_e.png')
        with Image.open(ep) as e:
            assert e.size==((im.shape[1]+1)//2,(im.shape[0]+1)//2)
            ea=np.asarray(e.convert('RGBA')).astype(float)
            assert (ea[:,:,:3].max(axis=2)*ea[:,:,3]/255).max()>2
        assert ep.read_bytes()==(BASE/ep.name).read_bytes()
        opaque=im[:,:,3]>128
        rgb=im[:,:,:3][opaque].astype(float)
        r['opaque_rgb_std']=float(rgb.std());assert r['opaque_rgb_std']>5
        r['alpha_iou_cells']=ious;r['outside_2px_cells']=overflow;r['accent_iou']=1.;report['sheets'].append(r)
        if min(ious)<=.95:report['errors'].append([a,min(ious)])
    import re
    animations=lambda p:re.findall(r'"name": &"([^"]+)"',p.read_text())
    assert animations(OUT/'vigie_avant_la_pluie.tres')==animations(BASE/'vigie.tres')
    report['animation_names']=animations(OUT/'vigie_avant_la_pluie.tres')
    report['png_bytes_added']=sum(p.stat().st_size for p in OUT.glob('*.png'))
    report['uncompressed_astc4x4_mib']=sum(((Image.open(p).width+3)//4)*((Image.open(p).height+3)//4)*16 for p in OUT.glob('*.png'))/1048576
    (HERE/'_panoplie_vigie_avant_la_pluie_verification.json').write_text(json.dumps(report,indent=2))
    assert not report['errors'],report['errors']
    if len(report['sheets'])==10:
        expected={a+s+'.png' for a in [*vg.ANIMS,'portrait'] for s in ('','_e')}|{'vigie_avant_la_pluie.tres'}
        assert {p.name for p in OUT.iterdir() if p.suffix!='.import'}==expected
        assert (OUT/'vigie_avant_la_pluie.tres').read_text()==(BASE/'vigie.tres').read_text().replace('res://assets/sprites/characters/vigie/','res://assets/sprites/characters/vigie/skins/vigie_avant_la_pluie/')
    # contact_pair maps each skin path back to the default through an isolated archive tree.
    archive=WORK/'reference';rel=Path('characters/vigie/skins/vigie_avant_la_pluie');(archive/rel).mkdir(parents=True,exist_ok=True)
    samples=[]
    for a in ('idle','run','draw','portrait'):
        if (OUT/(a+'.png')).exists():
            shutil.copy2(BASE/(a+'.png'),archive/rel/(a+'.png'));samples.append([(str(rel/(a+'.png')),256 if a=='portrait' else 192,0,0 if a=='portrait' else 2)])
    cel.ARCHIVE=archive;cel.contact_pair(samples,HERE/'_panoplie_vigie_avant_la_pluie_contact.png',size=(768,1024))
    print('VERIFY '+('PASS' if not report['errors'] else 'FAIL '+str(report['errors'])))

def driver():
    log=HERE/'_logpanoplie_vigie.txt'
    with log.open('w') as f:code=subprocess.call([BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']+[a for a in sys.argv[1:] if a!='--verify'],stdout=f,stderr=subprocess.STDOUT,cwd=ROOT)
    if code:raise RuntimeError('Blender exit '+str(code)+'; '+str(log))
    if all((OUT/(a+'.png')).exists() for a in [*vg.ANIMS,'portrait']):
        text=(BASE/'vigie.tres').read_text();text=text.replace('res://assets/sprites/characters/vigie/','res://assets/sprites/characters/vigie/skins/vigie_avant_la_pluie/');(OUT/'vigie_avant_la_pluie.tres').write_text(text)
    verify()

if __name__=='__main__':
    if '--render' in sys.argv:render()
    elif '--verify' in sys.argv:verify()
    else:driver()
