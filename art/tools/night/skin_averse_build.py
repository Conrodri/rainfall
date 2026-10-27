"""Celadon Averse: material-only source copy, original rendering and compact contract."""
import sys,json,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso')]
import cel_style as cel
BASE=ROOT/'game/assets/sprites/characters/averse';OUT=BASE/'skins/averse_skin1'
WORK=ROOT/'art/blender/cel/skins/averse_skin1_frames';SOURCE=WORK.parent/'averse_skin1.blend'
BLENDER=r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
ANIMS={'idle':8,'run':8,'cast':4,'wave':6,'crue':8,'stumble':3,'attack':6,'cast_ult':8,'death':8}
SPECS=json.loads((ROOT/'art/blender/cel/heroes_c/compact.json').read_text())['sheets']
def materials():
    import bpy
    palette={'Waxed rain grey cloth':('1C2230',.18,.25),'Cracked wet harness leather':('3A3328',.55,0),'Verdigris bloom on cast bronze':('6F8F7E',.23,.05),'Rust leaking from joints':('283D35',.65,0),'Worn brass rivet heads':('8E8E86',.28,.8),'AV1 hammered bronze fittings':('8E8E86',.25,.8)}
    for m in bpy.data.materials:
        if not m.use_nodes:continue
        for b in m.node_tree.nodes:
            if b.type=='BSDF_PRINCIPLED' and b.inputs['Emission Strength'].default_value>.01:m['rainfall_emissive']=True
        if m.name not in palette:continue
        h,rough,metal=palette[m.name];v=[int(h[i:i+2],16)/255 for i in (0,2,4)];color=tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in v)+(1,)
        b=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        for l in list(b.inputs['Base Color'].links):m.node_tree.links.remove(l)
        for n in list(m.node_tree.nodes):
            if n.type=='VALTORGB':m.node_tree.nodes.remove(n)
        b.inputs['Base Color'].default_value=color;b.inputs['Roughness'].default_value=rough;b.inputs['Metallic'].default_value=metal;m.diffuse_color=color

def safe_open(path):
    import bpy
    bpy.ops.wm.read_factory_settings(use_empty=True)
    with bpy.data.libraries.load(str(path),link=False) as (a,b):b.scenes=a.scenes
    s=b.scenes[0];s.compositing_node_group=None;bpy.context.window.scene=s
    materials();bpy.context.preferences.filepaths.save_version=0
    if Path(path)==SOURCE:bpy.ops.wm.save_as_mainfile(filepath=str(WORK/"materials.blend"))
    # Silver hood lining uses the existing recessed surface, without new geometry.
    silver=bpy.data.materials.get('Worn brass rivet heads')
    for ob in bpy.data.objects:
        if ob.name.startswith('Black hood recess') and silver:
            for slot in ob.material_slots:slot.material=silver
    cel.toon_materials('creature')
    # Fine dark crazing is a surface shader on the celadon shell only.
    m=bpy.data.materials.get('Verdigris bloom on cast bronze')
    if m:
        nodes=m.node_tree.nodes;links=m.node_tree.links
        emit=next(n for n in nodes if n.type=='EMISSION');old=emit.inputs['Color'].links[0].from_socket
        tex=nodes.new('ShaderNodeTexCoord');vor=nodes.new('ShaderNodeTexVoronoi');vor.feature='DISTANCE_TO_EDGE';vor.inputs['Scale'].default_value=17
        links.new(tex.outputs['Generated'],vor.inputs['Vector'])
        edge=nodes.new('ShaderNodeMapRange');edge.clamp=True;edge.inputs['From Min'].default_value=.004;edge.inputs['From Max'].default_value=.018;edge.inputs['To Min'].default_value=.16;edge.inputs['To Max'].default_value=1
        links.new(vor.outputs['Distance'],edge.inputs['Value']);mul=nodes.new('ShaderNodeVectorMath');mul.operation='SCALE';links.new(old,mul.inputs[0]);links.new(edge.outputs['Result'],mul.inputs['Scale']);links.new(mul.outputs[0],emit.inputs['Color'])
    if Path(path)==SOURCE:bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'materials.blend'))

def pack(a):
    from PIL import Image
    spec=SPECS['characters/averse/'+a+'.png'];box=spec['box'];cw,ch=spec['new_cell'];n=ANIMS[a]
    with Image.open(WORK/'raw'/f'{a}.png') as im:
        sheet=Image.new('RGBA',(cw*n,ch*8))
        for y in range(8):
            for x in range(n):sheet.paste(im.crop((192*x+box[0],192*y+box[1],192*x+box[2],192*y+box[3])),(cw*x,ch*y))
        assert sheet.size==Image.open(BASE/f'{a}.png').size
        sheet.save(OUT/f'{a}.png',optimize=True,compress_level=9)
    shutil.copy2(BASE/f'{a}_e.png',OUT/f'{a}_e.png')

def render():
    import bpy,iso_rig as iso,av1_build as av1
    from cel_heroes_c_build import adapted
    WORK.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/'art/blender/characters/averse.blend',SOURCE)
    iso.render_frame=adapted(iso.render_frame,[("('_n','_e')","('_e',)")]);original=iso.render_frame
    def frame(path,passes=True):
        cel.install('creature',normals=False);bpy.context.scene.eevee.taa_render_samples=8
        original(path,passes=True)
        pack(Path(path).stem)
    iso.render_frame=frame;av1.safe_open=safe_open;av1.SOURCE=SOURCE;av1.DEST=WORK/'raw';av1.WORK=WORK;av1.resources=lambda:None
    av1.ANIMS={a:n for a,n in ANIMS.items() if not ('--resume' in sys.argv and (OUT/f'{a}.png').exists())}
    if '--only' in sys.argv:av1.ANIMS={a:n for a,n in av1.ANIMS.items() if a==sys.argv[sys.argv.index('--only')+1]}
    adapted(av1.atlases,[("bpy.ops.wm.open_mainfile(filepath=str(SOURCE))","safe_open(SOURCE)"),("('','_n','_e')","('','_e')")])()
    if '--only' in sys.argv:
        (WORK/'render.done').write_text('PASS');return
    safe_open(ROOT/'art/blender/characters/averse_portrait.blend');bpy.context.scene['iso_frame']=[256,256];cel.install('creature',normals=False)
    original(OUT/'portrait.png',passes=True)
    from PIL import Image
    with Image.open(OUT/'portrait.png') as im:im.save(OUT/'portrait.png',optimize=True,compress_level=9)
    ep=OUT/'portrait_e.png'
    if ep.exists():ep.unlink()
    (WORK/'render.done').write_text('PASS')

def verify():
    import numpy as np
    from PIL import Image
    report={'sheets':[],'errors':[],'complete':False}
    for a,n in [*ANIMS.items(),('portrait',1)]:
        p=OUT/f'{a}.png'
        if not p.exists():continue
        cell=[256,256] if a=='portrait' else SPECS['characters/averse/'+a+'.png']['new_cell'];cw,ch=cell;rows=1 if a=='portrait' else 8
        r=cel.check_sheet(str(p.relative_to(ROOT/'game/assets/sprites')).replace('\\','/'),cell=tuple(cell),frames=n,rows=rows,normals=False)
        aa=np.asarray(Image.open(BASE/p.name).convert('RGBA'));bb=np.asarray(Image.open(p).convert('RGBA'));assert aa.shape==bb.shape
        ious=[];overflow=[]
        for y in range(rows):
            for x in range(n):
                ar=aa[y*ch:(y+1)*ch,x*cw:(x+1)*cw,3]>128;br=bb[y*ch:(y+1)*ch,x*cw:(x+1)*cw,3]>128
                ious.append(float((ar&br).sum()/max(1,(ar|br).sum())))
                padded=np.pad(ar,2);expanded=np.logical_or.reduce([padded[dy:dy+ch,dx:dx+cw] for dy in range(5) for dx in range(5)]);overflow.append(int((br&~expanded).sum()))
        r.update(alpha_iou_cells=ious,outside_2px_cells=overflow)
        if min(ious)<=.95 or max(overflow):report['errors'].append([a,min(ious),max(overflow)])
        ep=OUT/f'{a}_e.png'
        if ep.exists():
            assert ep.read_bytes()==(BASE/ep.name).read_bytes();e=Image.open(ep);assert e.size==((bb.shape[1]+1)//2,(bb.shape[0]+1)//2)
            ev=np.asarray(e.convert('RGBA')).astype(float);assert (ev[:,:,:3].max(axis=2)*ev[:,:,3]/255).max()>2;r['accent_iou']=1.
        report['sheets'].append(r)
    report['complete']=len(report['sheets'])==10
    (HERE/'_skin_averse_verification.json').write_text(json.dumps(report,indent=2))
    if report['complete']:
        expected={p.name for p in BASE.glob('*.png')}|{'averse_skin1.tres'};assert {p.name for p in OUT.iterdir() if p.suffix!='.import'}==expected
    archive=WORK/'reference';rel=Path('characters/averse/skins/averse_skin1');(archive/rel).mkdir(parents=True,exist_ok=True);samples=[]
    for a in ('idle','run','attack','cast_ult','portrait'):
        if (OUT/f'{a}.png').exists():
            shutil.copy2(BASE/f'{a}.png',archive/rel/f'{a}.png');cell=(256,256) if a=='portrait' else tuple(SPECS['characters/averse/'+a+'.png']['new_cell']);samples.append([(str(rel/f'{a}.png'),cell,0,0 if a=='portrait' else 2)])
    cel.ARCHIVE=archive;cel.contact_pair(samples,HERE/'_skin_averse_contact.png',size=(960,1400))
    assert report['sheets'],'No completed sheets';print('VERIFY', 'FAIL' if report['errors'] else 'PASS',report['errors']);assert not report['errors']

def driver():
    log=HERE/'_skin_averse_render.log'
    WORK.mkdir(parents=True,exist_ok=True);(WORK/'render.done').unlink(missing_ok=True)
    with log.open('w') as f:code=subprocess.call([BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']+sys.argv[1:],stdout=f,stderr=subprocess.STDOUT,cwd=ROOT)
    if not (WORK/'render.done').exists():raise RuntimeError('Incomplete Blender execution; '+str(log))
    if code:raise RuntimeError('Blender exit '+str(code)+'; '+str(log))
    if all((OUT/f'{a}.png').exists() for a in [*ANIMS,'portrait']):(OUT/'averse_skin1.tres').write_text((BASE/'averse.tres').read_text().replace('res://assets/sprites/characters/averse/','res://assets/sprites/characters/averse/skins/averse_skin1/'))
    if (WORK/'materials.blend').exists():shutil.copy2(WORK/'materials.blend',SOURCE)
    if '--only' not in sys.argv:assert all((OUT/f'{a}.png').exists() for a in [*ANIMS,'portrait']), 'Incomplete render; inspect log'
    verify()
if __name__=='__main__':
    if '--render' in sys.argv:render()
    elif '--verify' in sys.argv:verify()
    else:driver()
