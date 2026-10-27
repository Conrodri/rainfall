"""Bois flotte: material-only source copy, original SA1 poses/render/assembly; --resume."""
import sys, json, shutil, subprocess, hashlib, inspect
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
BASE=ROOT/'game/assets/sprites/characters/morfil'
OUT=BASE/'skins/morfil_skin1'
WORK=ROOT/'art/blender/cel/skins/morfil_skin1_work'
COPY=WORK.parent/'morfil_skin1.blend'
SOURCE=ROOT/'art/blender/characters/morfil.blend'
BLENDER=r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
GODOT=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso')]
sys.dont_write_bytecode=True
import cel_style as cel
ANIMS=dict(idle=8,run=8,cut_circle=6,thrust=6,crescent=8,sharpen=8,twin_draw=8,dodge=5,hurt=3,death=8,idle_dual=8,run_dual=8,cut_circle_dual=6,thrust_dual=6,crescent_dual=8)

def materials():
    import bpy
    def linear(h):
        rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
        return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
    palette={'bark':('8F8678',.8,0),'wood':('5E6060',.65,0),'cloth':('141214',.9,0),'fold':('100F11',.9,0),'lacquer':('141214',.13,.25),'chip':('292524',.35,.1),'rope':('B3A791',.85,0),'moss':('AEA995',.95,0),'rust':('575958',.3,.85),'reed':('2A2420',.85,0),'reedlight':('393029',.8,0)}
    for name,(h,rough,metal) in palette.items():
        m=bpy.data.materials[name]
        p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        p.inputs['Base Color'].default_value=linear(h)
        p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
        m.diffuse_color=linear(h)
    # Existing sode plates: bleached wood, identical vertices and material boundaries.
    for name in ('Right cedar arm_sculpt','Left branch arm_sculpt'):
        ob=bpy.data.objects[name]
        for i,m in enumerate(ob.data.materials):
            if m and m.name in ('lacquer','chip'):ob.data.materials[i]=bpy.data.materials['bark']
    # Separate existing disconnected lace islands in the merged torso; no geometry edits.
    gold=bpy.data.materials['rope'].copy();gold.name='Tarnished gold do laces 8A7342'
    p=next(n for n in gold.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=linear('8A7342');p.inputs['Roughness'].default_value=.45;p.inputs['Metallic'].default_value=.75
    ob=bpy.data.objects['Hollow cedar_sculpt'];mesh=ob.data
    mesh.materials.append(gold);gold_idx=len(mesh.materials)-1
    parent=list(range(len(mesh.vertices)))
    def find(i):
        while parent[i]!=i:
            parent[i]=parent[parent[i]];i=parent[i]
        return i
    for e in mesh.edges:parent[find(e.vertices[0])]=find(e.vertices[1])
    groups={}
    for v in mesh.vertices:groups.setdefault(find(v.index),[]).append(v.co.copy())
    laces=set()
    for k,vs in groups.items():
        lo=[min(v[j] for v in vs) for j in range(3)];hi=[max(v[j] for v in vs) for j in range(3)]
        if hi[0]-lo[0]<.025 and hi[1]-lo[1]<.014 and .035<hi[2]-lo[2]<.055 and abs((lo[0]+hi[0])/2)>.11:
            laces.add(k)
    changed=0
    for face in mesh.polygons:
        if mesh.materials[face.material_index].name=='rope' and find(face.vertices[0]) in laces:
            face.material_index=gold_idx;changed+=1
    assert changed>0,'Do laces not found'
    return {'gold_lace_faces':changed,'palette':palette}

def render():
    import bpy,sa1_build as sa,random
    WORK.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    shutil.copy2(SOURCE,COPY)
    bpy.ops.wm.open_mainfile(filepath=str(COPY))
    design=materials();random.seed(4617)
    bpy.context.scene.cycles.seed=4617
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(COPY))
    ob=bpy.data.objects
    rig={k:ob[v] for k,v in dict(root='Taliant',body='Hollow cedar',head='Bark face',hat='Oversized inverted basket bowl',leftfore='Left twig forearm',stone='Whetstone',sheath='Hollow branch scabbard',drops='Hat rain drops').items()}
    rig.update(legs=[ob['Root leg -1'],ob['Root leg 1']],arms=[ob['Right cedar arm'],ob['Left branch arm']],blades=[ob['Living katana'],ob['Growing second katana']])
    for node in rig['root'].children_recursive:node.animation_data_clear()
    sa.P['edge']=bpy.data.materials['Isolated sharpenable sap edge CDEB6E']
    sa.P['sap']=bpy.data.materials['Unique sap CEL Accent CDEB6E']
    sa.build=lambda:rig;sa.key_source=lambda r:None
    sa.OUT=WORK/'raw';sa.DEST=OUT;sa.resources=lambda:None
    original_sheet=sa.sheet
    def sheet(anim,n):
        original_sheet(anim,n)
        # Emission geometry/materials are unchanged. Preserve approved downsampling exactly.
        shutil.copy2(BASE/f'{anim}_e.png',OUT/f'{anim}_e.png')
        verify([anim],contact=False)
    sa.sheet=sheet
    selected=[a for a in ANIMS if not ('--resume' in sys.argv and (OUT/f'{a}.png').exists() and (OUT/f'{a}_e.png').exists())]
    if '--only' in sys.argv:selected=[a for a in selected if a==sys.argv[sys.argv.index('--only')+1]]
    sys.argv+=['--anims',','.join(selected)]
    cel.install('creature',normals=False)
    if selected:sa.character('all','--resume' in sys.argv)
    if '--only' not in sys.argv and not ('--resume' in sys.argv and (OUT/'portrait.png').exists()):
        bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/morfil_portrait.blend'))
        cel.install('creature',normals=False)
        sa.render(WORK/'portrait_source_check.png',256)
        cel.uninstall()
        bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/morfil_portrait.blend'))
        materials();bpy.context.scene.cycles.seed=4617
        cel.install('creature',normals=False)
        sa.render(WORK/'portrait.png',256)
        shutil.copy2(WORK/'portrait.png',OUT/'portrait.png')
    text=(BASE/'morfil.tres').read_text(encoding='utf-8')
    for a in ANIMS:
        text=text.replace(f'res://assets/sprites/characters/morfil/{a}.png',f'res://assets/sprites/characters/morfil/skins/morfil_skin1/{a}.png')
    assert 'CanvasTexture' not in text and 'normal_texture' not in text
    (OUT/'morfil_skin1.tres').write_text(text,encoding='utf-8')
    (WORK/'design.json').write_text(json.dumps(design,indent=2))
    print('RENDER PASS',flush=True)

def verify(names=None,contact=True):
    import numpy as np
    from PIL import Image,ImageFilter
    report_path=HERE/'_skin_morfil_verification.json'
    report=json.loads(report_path.read_text()) if report_path.exists() else {'sheets':{},'complete':False}
    for name in names or [*ANIMS,'portrait']:
        p=OUT/f'{name}.png'
        if not p.exists():continue
        portrait=name=='portrait';cell=256 if portrait else 192;frames=1 if portrait else ANIMS[name];rows=1 if portrait else 8
        ref=ROOT/'game/assets/sprites/ui/portraits/morfil.png' if portrait else BASE/p.name
        r=cel.check_sheet(p.relative_to(cel.GAME_SPRITES).as_posix(),cell=cell,frames=frames,rows=rows,normals=False)
        aa=np.asarray(Image.open(ref).convert('RGBA'));bb=np.asarray(Image.open(p).convert('RGBA'));assert aa.shape==bb.shape
        ious=[];overflow=[];accents=[];rendered_accents=[]
        for y in range(rows):
            for x in range(frames):
                sl=np.s_[y*cell:(y+1)*cell,x*cell:(x+1)*cell]
                a=aa[sl][:,:,3]>128;b=bb[sl][:,:,3]>128
                ious.append(float((a&b).sum()/max(1,(a|b).sum())))
                dilated=np.array(Image.fromarray(a.astype('uint8')*255).filter(ImageFilter.MaxFilter(5)))>0
                overflow.append(int((b&~dilated).sum()))
        if not portrait:
            ae=np.array(Image.open(BASE/f'{name}_e.png').convert('RGBA'));be=np.array(Image.open(OUT/f'{name}_e.png').convert('RGBA'))
            assert ae.shape==be.shape and ae.shape[:2]==(bb.shape[0]//2,bb.shape[1]//2)
            for y in range(rows):
                for x in range(frames):
                    sl=np.s_[y*96:(y+1)*96,x*96:(x+1)*96]
                    a=(ae[sl][:,:,:3].max(2)>100)&(ae[sl][:,:,3]>128);b=(be[sl][:,:,:3].max(2)>100)&(be[sl][:,:,3]>128)
                    accents.append(float((a&b).sum()/max(1,(a|b).sum())) if (a|b).any() else 1.)
                    raw=WORK/'raw'/name/f'{("e","se","s","sw","w","nw","n","ne")[y]}_{x:02}_e.png'
                    if raw.exists():
                        with Image.open(raw) as im:re=np.array(im.convert('RGBA').resize((96,96),Image.Resampling.LANCZOS))
                        rb=(re[:,:,:3].max(2)>100)&(re[:,:,3]>128)
                        rendered_accents.append(float((a&rb).sum()/max(1,(a|rb).sum())) if (a|rb).any() else 1.)
            assert np.any((be[:,:,:3].max(2)>2)&(be[:,:,3]>2)),'Empty emission'
        r.update(alpha_iou_cells=ious,accent_iou_cells=accents,rendered_accent_iou_cells=rendered_accents,overflow_2px=overflow)
        if portrait:
            # The supplied portrait scene itself differs slightly from the approved PNG.
            # Require exact alpha against an unmodified render of that very same scene.
            source=np.asarray(Image.open(WORK/'portrait_source_check.png').convert('RGBA'))
            r['source_alpha_equal']=bool(np.array_equal(source[:,:,3],bb[:,:,3]))
            assert r['source_alpha_equal'],'Portrait source geometry mismatch'
        report['sheets'][name]=r
        report_path.write_text(json.dumps(report,indent=2))
        assert min(ious)>.95 and (max(overflow)==0 or (portrait and r['source_alpha_equal'])),(name,'alpha',min(ious),max(overflow))
        assert not accents or min(accents)>.90,(name,'accent',min(accents))
        assert not rendered_accents or min(rendered_accents)>.90,(name,'rendered accent',min(rendered_accents))
    expected={f'{a}{s}.png' for a in ANIMS for s in ('','_e')}|{'portrait.png','morfil_skin1.tres'}
    actual={p.name for p in OUT.iterdir() if p.suffix!='.import'}
    report['complete']=actual==expected and len(report['sheets'])==16
    report['missing']=sorted(expected-actual);report['extra']=sorted(actual-expected)
    assert not report['extra'],report['extra']
    report_path.write_text(json.dumps(report,indent=2))
    if contact:
        stage=WORK/'contact_default'
        samples=[]
        for line in [['idle','run'],['cut_circle','twin_draw'],['portrait']]:
            row=[]
            for a in line:
                if not (OUT/f'{a}.png').exists():continue
                rel=f'characters/morfil/skins/morfil_skin1/{a}.png';target=stage/rel;target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(ROOT/'game/assets/sprites/ui/portraits/morfil.png' if a=='portrait' else BASE/f'{a}.png',target)
                row.append((rel,256 if a=='portrait' else 192,0 if a=='portrait' else 2,0 if a=='portrait' else 2))
            if row:samples.append(row)
        previous=cel.ARCHIVE;cel.ARCHIVE=stage
        cel.contact_pair(samples,HERE/'_skin_morfil_contact.png',size=(1200,1000));cel.ARCHIVE=previous
    print('VERIFY','COMPLETE' if report['complete'] else 'PARTIAL',len(report['sheets']),flush=True)

def checks():
    # Reuse the established skin validation, including an external temporary Godot script.
    import skin_bourbe_build as previous
    code=inspect.getsource(previous.checks).replace('bourbe','morfil')
    exec(compile(code,str(Path(previous.__file__)),'exec'),globals())
    return globals()['checks']()

def protected():
    files=list(BASE.glob('*'))+[SOURCE,ROOT/'art/blender/characters/morfil_portrait.blend',ROOT/'game/assets/sprites/ui/portraits/morfil.png']
    return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files if p.is_file()}

def driver():
    WORK.mkdir(parents=True,exist_ok=True)
    baseline=HERE/'_skin_morfil_budget_before.json'
    if not baseline.exists():
        with (HERE/'_skin_morfil_budget_before.txt').open('w') as log:subprocess.run([sys.executable,str(ROOT/'art/tools/texture_budget.py'),'--top','0','--json',str(baseline)],cwd=ROOT,stdout=log,check=True)
    before=protected()
    if '--verify' not in sys.argv:
        args=[BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']
        if '--resume' in sys.argv:args.append('--resume')
        if '--only' in sys.argv:args+=['--only',sys.argv[sys.argv.index('--only')+1]]
        with (HERE/'_skin_morfil_render.log').open('w') as log:result=subprocess.run(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
        assert result.returncode==0,'Blender failure: _skin_morfil_render.log'
    assert before==protected(),'Protected source changed'
    verify()
    if '--only' not in sys.argv:checks()
    assert before==protected(),'Protected source changed during checks'

if __name__=='__main__':
    render() if '--render' in sys.argv else driver()
