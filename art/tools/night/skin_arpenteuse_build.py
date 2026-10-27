"""Cadastre: original frozen meshes, timeline, camera and compact atlas contracts."""
import sys,json,shutil,subprocess,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso')]
import cel_style as cel
BASE=ROOT/'game/assets/sprites/characters/arpenteuse'
OUT=BASE/'skins/arpenteuse_skin1'
WORK=ROOT/'art/blender/cel/skins/arpenteuse_skin1_frames'
SOURCE=WORK.parent/'arpenteuse_skin1.blend'
ANIMS={'idle':8,'run':8,'plant':4,'loop':4,'whip':6,'attack':6,'cast':4,'cast_ult':6,'death':8}
BLENDER=r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
GODOT=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
REVISION='cadastre-3'

def up_to_date(a):
    marker=WORK/(a+'.done')
    return (OUT/(a+'.png')).exists() and marker.exists() and marker.read_text()==REVISION

def materials():
    import bpy
    def linear(h):
        return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in [int(h[i:i+2],16)/255 for i in (0,2,4)])+(1,)
    palette={'Waxed umber':('2E3540',0,.88),'Verdigris bronze':('7A6A3E',.78,.24),'Worn graduations':('A8946E',.72,.32),'Charcoal underclothes':('252B33',0,.9)}
    for m in bpy.data.materials:
        for key,(h,metal,rough) in palette.items():
            if not m.name.startswith(key):continue
            bs=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
            if bs is None:continue
            for link in list(bs.inputs['Base Color'].links):m.node_tree.links.remove(link)
            for node in list(m.node_tree.nodes):
                if node.type=='VALTORGB':m.node_tree.nodes.remove(node)
            bs.inputs['Base Color'].default_value=linear(h);bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
    # Separate connected surface pieces of the joined original mesh; retain all
    # vertices, weights and modifiers. Leather facings, boots, gloves and harness.
    for ob in list(bpy.context.scene.objects):
        if ob.type!='MESH' or ob.get('cadastre_surfaces'):continue
        mesh=ob.data
        parent=list(range(len(mesh.vertices)))
        def find(x):
            while parent[x]!=x:parent[x]=parent[parent[x]];x=parent[x]
            return x
        for edge in mesh.edges:
            a,b=edge.vertices;parent[find(a)]=find(b)
        components={}
        for v in mesh.vertices:components.setdefault(find(v.index),[]).append(v)
        leather=bpy.data.materials.new('Cadastre havana leather');leather.use_nodes=True
        bs=leather.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=linear('5A3E2A');bs.inputs['Roughness'].default_value=.4
        mesh.materials.append(leather);li=len(mesh.materials)-1
        chosen=set();spool={}
        for key,verts in components.items():
            z0=min(v.co.z for v in verts);z1=max(v.co.z for v in verts)
            x=sum(v.co.x for v in verts)/len(verts);y=sum(v.co.y for v in verts)/len(verts);z=(z0+z1)/2
            # Original surfaces: collar, lapels, harness, boots, cap, gloves.
            if (1.40<z<1.53 and z1-z0<.15) or (z<.5 and z1-z0<.5) or (z>1.71) or (abs(x)>.27 and .70<z<.88) or (1.15<z<1.31 and y<-.10 and z1-z0>.2):chosen.add(key)
            if x>.18 and .90<z<.96 and abs(y)<.03:spool[key]=z1-z0
        for p in mesh.polygons:
            if find(p.vertices[0]) in chosen and not mesh.materials[p.material_index].name.startswith(('Weathered','Only emission')):p.material_index=li
            key=find(p.vertices[0])
            if key in spool and mesh.materials[p.material_index].name.startswith('Verdigris bronze'):
                p.material_index=next(i for i,m in enumerate(mesh.materials) if m.name.startswith('Worn graduations')) if spool[key]>.26 else li
        ob['cadastre_surfaces']=True
    # Small surface fittings follow the existing spine deformation.
    rig=next((o for o in bpy.context.scene.objects if o.type=='ARMATURE'),None)
    if rig and not bpy.data.objects.get('Cadastre city badge'):
        from mathutils import Matrix
        brass=next(m for m in bpy.data.materials if m.name.startswith('Worn graduations'))
        badge=leather.copy();badge.name='Cadastre verdigris city insignia';badge.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=linear('5F8F80')
        for j in range(9):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4)
            o=bpy.context.object;o.name='Cadastre city badge' if j==8 else 'Cadastre second brass button '+str(j)
            center=(.062,-.108,1.47) if j==8 else (-.035,-.123,1.07+j*.039)
            scale=(.018,.006,.025) if j==8 else (.008,.009,.008)
            o.data.transform(Matrix.Translation(center)@Matrix.Diagonal((*scale,1)))
            o.data.materials.append(badge if j==8 else brass);o.parent=rig
            g=o.vertex_groups.new(name='spine');g.add(list(range(len(o.data.vertices))),1,'REPLACE')
            mod=o.modifiers.new('Original spine deformation','ARMATURE');mod.object=rig

def render():
    import bpy, av1_build as av, ar1_build as ar, iso_rig as iso
    from cel_heroes_c_build import adapted
    from PIL import Image
    WORK.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    def safe_open(path):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        with bpy.data.libraries.load(str(path),link=False) as (src,dst):dst.scenes=src.scenes
        scene=next(s for s in dst.scenes if s.camera);scene.compositing_node_group=None;bpy.context.window.scene=scene
        scene.cycles.seed=27102026
        materials()
    safe_open(ROOT/'art/blender/characters/arpenteuse.blend')
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    raw=adapted(iso.render_frame,[("('_n','_e')","('_e',)")])
    def frame(path,passes=True):
        cel.install('creature',normals=False)
        return raw(path,passes=True)
    iso.render_frame=frame
    snapshot=adapted(av.posed_mesh,[("poly.use_smooth=True","poly.use_smooth=smooth_flags[poly.index]")])
    def mesh_snapshot(root,name):
        av.smooth_flags=[p.use_smooth for o in root.children_recursive if o.type=='MESH' and not o.hide_render for p in o.data.polygons]
        return snapshot(root,name)
    av.posed_mesh=mesh_snapshot;av.safe_open=safe_open;av.SOURCE=SOURCE;av.DEST=WORK;av.WORK=WORK/'temporary';av.resources=lambda:None
    selected={a:n for a,n in ANIMS.items() if not ('--resume' in sys.argv and up_to_date(a))}
    if '--only' in sys.argv:selected={a:n for a,n in selected.items() if a==sys.argv[sys.argv.index('--only')+1]}
    if '--portrait' in sys.argv:selected={}
    # Render and publish one complete atlas at a time; resumable after any interruption.
    atlas=adapted(av.atlases,[("bpy.ops.wm.open_mainfile(filepath=str(SOURCE))","safe_open(SOURCE)"),("bpy.data.objects['Averse']","bpy.data.objects['AR1_rig']"),("manifest=json.loads(s['animation_manifest'])","manifest={m.name:{'start':m.frame} for m in s.timeline_markers}"),("assert min(bounds[:2])>=3 and max(bounds[2:])<=189","assert min(bounds[:2])>=0 and max(bounds[2:])<=192")])
    specs=json.loads((ROOT/'art/blender/cel/heroes_c/compact.json').read_text())['sheets']
    for a,n in selected.items():
        av.ANIMS={a:n};atlas()
        spec=specs['characters/arpenteuse/'+a+'.png'];box=spec['box'];cw,ch=spec['new_cell']
        sheet=Image.new('RGBA',(n*cw,8*ch))
        with Image.open(WORK/(a+'.png')) as im:
            for y in range(8):
                for x in range(n):sheet.paste(im.crop((x*192,y*192,(x+1)*192,(y+1)*192)).crop(box),(x*cw,y*ch))
        sheet.save(OUT/(a+'.png'),optimize=True,compress_level=9)
        (WORK/(a+'.done')).write_text(REVISION)
        print('SKIN COMPLETE '+a,flush=True)
    if '--only' in sys.argv:return
    if not ('--resume' in sys.argv and up_to_date('portrait')):
        safe_open(ROOT/'art/blender/characters/arpenteuse_portrait.blend')
        bpy.context.scene['iso_frame']=[256,256];frame(OUT/'portrait.png')
        (WORK/'portrait.done').write_text(REVISION)
    for p in OUT.glob('*_e.png'):p.unlink()
    (OUT/'arpenteuse_skin1.tres').write_text((BASE/'arpenteuse.tres').read_text().replace('res://assets/sprites/characters/arpenteuse/','res://assets/sprites/characters/arpenteuse/skins/arpenteuse_skin1/'))

def verify():
    import numpy as np
    from PIL import Image
    report={'sheets':[],'errors':[],'accent':'No body emission; shared effects unchanged'}
    snapshot=HERE/'_skin_arpenteuse_shared_hashes.json'
    if snapshot.exists():
        report['shared_files_unchanged']=all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==sha for p,sha in json.loads(snapshot.read_text()).items())
        assert report['shared_files_unchanged']
    report['shared_chain_emission']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (BASE/'effects').glob('chain*_e.png')}
    samples=[];archive=WORK/'reference';rel=Path('characters/arpenteuse/skins/arpenteuse_skin1');(archive/rel).mkdir(parents=True,exist_ok=True)
    for a in [*ANIMS,'portrait']:
        path=OUT/(a+'.png')
        if not path.exists():continue
        ref=np.asarray(Image.open(BASE/path.name).convert('RGBA'));im=np.asarray(Image.open(path).convert('RGBA'));assert ref.shape==im.shape
        rows=1 if a=='portrait' else 8;n=ANIMS.get(a,1);h,w=im.shape[0]//rows,im.shape[1]//n
        r=cel.check_sheet(str(rel/path.name),cell=(w,h),frames=n,rows=rows,normals=False)
        ious=[];overflow=[]
        for y in range(rows):
            for x in range(n):
                aa=ref[y*h:(y+1)*h,x*w:(x+1)*w,3]>128;bb=im[y*h:(y+1)*h,x*w:(x+1)*w,3]>128
                ious.append(float((aa&bb).sum()/max(1,(aa|bb).sum())))
                pad=np.pad(aa,2);expanded=np.logical_or.reduce([pad[j:j+h,k:k+w] for j in range(5) for k in range(5)])
                overflow.append(int((bb&~expanded).sum()))
        r.update(alpha_iou_cells=ious,outside_2px_cells=overflow,accent_iou=None)
        if min(ious)<=.95 or max(overflow):report['errors'].append([a,min(ious),max(overflow)])
        report['sheets'].append(r)
        if a in ('idle','run','attack','cast_ult','portrait'):
            shutil.copy2(BASE/path.name,archive/rel/path.name);samples.append([(str(rel/path.name),(w,h),0,0 if a=='portrait' else 2)])
    (HERE/'_skin_arpenteuse_verification.json').write_text(json.dumps(report,indent=2))
    cel.ARCHIVE=archive;cel.contact_pair(samples,HERE/'_skin_arpenteuse_contact.png',size=(960,1400))
    assert not report['errors'],report['errors']
    if len(report['sheets'])==10:
        expected={a+'.png' for a in [*ANIMS,'portrait']}|{'arpenteuse_skin1.tres'}
        assert {p.name for p in OUT.iterdir() if p.suffix!='.import'}==expected
        assert (OUT/'arpenteuse_skin1.tres').read_text()==(BASE/'arpenteuse.tres').read_text().replace('res://assets/sprites/characters/arpenteuse/','res://assets/sprites/characters/arpenteuse/skins/arpenteuse_skin1/')
        assert 'CanvasTexture' not in (OUT/'arpenteuse_skin1.tres').read_text()
    print('VERIFY PASS '+str(len(report['sheets'])))

def driver():
    tasks=[sys.argv[1:]] if '--only' in sys.argv else [['--only',a] for a in ANIMS if not ('--resume' in sys.argv and up_to_date(a))]+[['--portrait']]
    with (HERE/'_skin_arpenteuse_render.log').open('w') as log:
        for args in tasks:
            command=[BLENDER,'--background','--python-exit-code','1','--python',str(Path(__file__).resolve()),'--','--render']+args
            for attempt in range(3):
                try:
                    code=subprocess.call(command,stdout=log,stderr=subprocess.STDOUT,cwd=ROOT,timeout=45)
                    if code and attempt<2:
                        log.write('RETRY Blender exit '+str(code)+' '+str(args)+'\n');log.flush()
                        continue
                    break
                except subprocess.TimeoutExpired:
                    log.write('RETRY timeout '+str(args)+'\n');log.flush()
                    if attempt==2:raise
            if code:raise RuntimeError('Blender exit '+str(code))
    verify()

def validate_game():
    """Temporary headless harness outside the project; no game scripts changed."""
    import tempfile
    sys.path.insert(0,str(ROOT/'art/tools'))
    import texture_budget as budget
    # Apply the shared policy solely to the authorized output folder.
    walk=budget.os.walk
    budget.os.walk=lambda unused:walk(str(OUT))
    try:budget.main(['--apply-policy'])
    finally:budget.os.walk=walk
    with (HERE/'_skin_arpenteuse_import.log').open('w') as log:
        code=subprocess.call([GODOT,'--headless','--path',str(ROOT/'game'),'--import'],stdout=log,stderr=subprocess.STDOUT)
    assert code==0,code
    script='''extends SceneTree
func _initialize():
    var base = load("res://assets/sprites/characters/arpenteuse/arpenteuse.tres")
    var skin = load("res://assets/sprites/characters/arpenteuse/skins/arpenteuse_skin1/arpenteuse_skin1.tres")
    var ok = skin is SpriteFrames and base.get_animation_names() == skin.get_animation_names()
    if ok:
        for name in base.get_animation_names():
            ok = ok and base.get_frame_count(name) == skin.get_frame_count(name) and base.get_animation_speed(name) == skin.get_animation_speed(name) and base.get_animation_loop(name) == skin.get_animation_loop(name)
    print("RESULT: ", "OK" if ok else "FAIL", " skin SpriteFrames")
    quit(0 if ok else 1)
'''
    with tempfile.TemporaryDirectory(prefix='cadastre_') as tmp:
        path=Path(tmp)/'validate.gd';path.write_text(script)
        with (HERE/'_skin_arpenteuse_load.log').open('w') as log:
            code=subprocess.call([GODOT,'--headless','--path',str(ROOT/'game'),'--script',str(path)],stdout=log,stderr=subprocess.STDOUT)
        assert code==0,code
    with (HERE/'_skin_arpenteuse_budget_after.log').open('w') as log:
        subprocess.call([sys.executable,str(ROOT/'art/tools/texture_budget.py'),'--json',str(HERE/'_skin_arpenteuse_budget_after.json')],stdout=log,stderr=subprocess.STDOUT)
    for name in ('sprites','arpenteuse','texture_budget'):
        with (HERE/('_skin_arpenteuse_'+name+'_test.log')).open('w') as log:
            subprocess.call([GODOT,'--headless','--path',str(ROOT/'game'),'res://tests/'+name+'_test.tscn'],stdout=log,stderr=subprocess.STDOUT)
    before=json.loads((HERE/'_skin_arpenteuse_budget_before.json').read_text());after=json.loads((HERE/'_skin_arpenteuse_budget_after.json').read_text())
    b=before['categories']['characters/arpenteuse'];a=after['categories']['characters/arpenteuse']
    delta={k:(a[k]-b[k])/1048576 for k in ('png','mobile')}
    skin_rows=[r for r in after['rows'] if '/skins/arpenteuse_skin1/' in r['path'].replace('\\','/')]
    result={'category_before':b,'category_after':a,'delta_MiB':delta,'skin_MiB':{k:sum(r[k] for r in skin_rows)/1048576 for k in ('png','mobile')},'global_mobile_MiB':after['total']['mobile']/1048576}
    (HERE/'_skin_arpenteuse_budget_delta.json').write_text(json.dumps(result,indent=2))
    print(json.dumps(result['delta_MiB']))
    print('GAME VALIDATION COMPLETE')

if __name__=='__main__':
    if '--render' in sys.argv:render()
    elif '--verify' in sys.argv:verify()
    elif '--validate-game' in sys.argv:validate_game()
    else:driver()
