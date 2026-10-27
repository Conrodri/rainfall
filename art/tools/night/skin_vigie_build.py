"""Cormoran: original VG1 build/poses/accent compositor, isolated outputs; --resume."""
import sys, json, inspect, shutil, subprocess, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso')]
import vg1_build as vg
import cel_style as cel
BASE=ROOT/'game/assets/sprites/characters/vigie'
OUT=BASE/'skins/vigie_skin1'
WORK=ROOT/'art/blender/cel/skins/vigie_skin1_frames'
SOURCE=ROOT/'art/blender/cel/skins/vigie_skin1.blend'
BLENDER=r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
GODOT=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
HERE=Path(__file__).parent

def materials():
    import bpy
    # Surface substitutions only; geometry and animated accent materials stay intact.
    palette={'waterlogged_reed':'16201C','reed_splits':'24352B','reed_knots':'111B17','oilskin':'1E2226','worn_oilskin_edges':'454B50','verdigris_bindings':'4A4D4F','dented_brass':'4A4D4F','brass_scratches':'92979C'}
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
    ash=bpy.data.materials['Vigie_black_dike_wood'].copy();ash.name='Cormoran_pale_ash';recolor(ash,'9A8C74',0,.55)
    copper=bpy.data.materials['Vigie_dented_brass'].copy();copper.name='Cormoran_polished_copper';recolor(copper,'A47B60',.7,.24)
    for ob in bpy.data.objects:
        p=ob;anc=[]
        while p:anc.append(p.name);p=p.parent
        if ob.type not in ('MESH','CURVE'):continue
        for slot in ob.material_slots:
            if not slot.material:continue
            if 'Longbow_hand_socket' in anc and slot.material.name=='Vigie_black_dike_wood':slot.material=ash
            if 'Battered_telescope' in anc and not slot.material.get('rainfall_emissive') and any(k in slot.material.name for k in ('brass','bindings')):slot.material=copper

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
    s=bpy.context.scene;s.render.engine='BLENDER_EEVEE'
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
        print('SKIN COMPLETE '+a,flush=True)
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
    report={'sheets':[],'errors':[]}
    for a in [*vg.ANIMS,'portrait']:
        if not (OUT/(a+'.png')).exists():continue
        n=vg.ANIMS.get(a,1);cell=192 if a!='portrait' else 256;rows=8 if a!='portrait' else 1
        r=cel.check_sheet('characters/vigie/skins/vigie_skin1/'+a+'.png',cell=cell,frames=n,rows=rows,normals=False)
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
        r['alpha_iou_cells']=ious;r['outside_2px_cells']=overflow;r['accent_iou']=1.;report['sheets'].append(r)
        if min(ious)<=.95:report['errors'].append([a,min(ious)])
    (HERE/'_skin_vigie_verification.json').write_text(json.dumps(report,indent=2))
    assert not report['errors'],report['errors']
    if len(report['sheets'])==10:
        expected={a+s+'.png' for a in [*vg.ANIMS,'portrait'] for s in ('','_e')}|{'vigie_skin1.tres'}
        assert {p.name for p in OUT.iterdir() if p.suffix!='.import'}==expected
        assert (OUT/'vigie_skin1.tres').read_text()==(BASE/'vigie.tres').read_text().replace('res://assets/sprites/characters/vigie/','res://assets/sprites/characters/vigie/skins/vigie_skin1/')
    # contact_pair maps each skin path back to the default through an isolated archive tree.
    archive=WORK/'reference';rel=Path('characters/vigie/skins/vigie_skin1');(archive/rel).mkdir(parents=True,exist_ok=True)
    samples=[]
    for a in ('idle','run','attack','volley','portrait'):
        if (OUT/(a+'.png')).exists():
            shutil.copy2(BASE/(a+'.png'),archive/rel/(a+'.png'));samples.append([(str(rel/(a+'.png')),256 if a=='portrait' else 192,0,0 if a=='portrait' else 2)])
    cel.ARCHIVE=archive;cel.contact_pair(samples,HERE/'_skin_vigie_contact.png',size=(960,1400))
    print('VERIFY '+('PASS' if not report['errors'] else 'FAIL '+str(report['errors'])))

def driver():
    log=HERE/'_skin_vigie_render.log'
    with log.open('w') as f:code=subprocess.call([BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']+[a for a in sys.argv[1:] if a!='--verify'],stdout=f,stderr=subprocess.STDOUT,cwd=ROOT)
    if code:raise RuntimeError('Blender exit '+str(code)+'; '+str(log))
    if all((OUT/(a+'.png')).exists() for a in [*vg.ANIMS,'portrait']):
        text=(BASE/'vigie.tres').read_text();text=text.replace('res://assets/sprites/characters/vigie/','res://assets/sprites/characters/vigie/skins/vigie_skin1/');(OUT/'vigie_skin1.tres').write_text(text)
    verify()

if __name__=='__main__':
    if '--render' in sys.argv:render()
    elif '--verify' in sys.argv:verify()
    else:driver()
