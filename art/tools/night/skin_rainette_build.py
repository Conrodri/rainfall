"""Rainette Écailles noires; original geometry/exporter, isolated material variant."""
from pathlib import Path
import sys, json, subprocess, shutil, inspect
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools')]
import cel_style as cel
BASE=ROOT/'game/assets/sprites/characters/rainette'
OUT=BASE/'skins/rainette_skin1'
WORK=ROOT/'art/blender/cel/skins'
BLEND=WORK/'rainette_skin1.blend'
BLENDER=r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'

def render():
    import bpy, iso_rig as iso, ra1_build as ra, cel_heroes_d_build as hd
    import faulthandler
    faulthandler.dump_traceback_later(60,repeat=True)
    from cd_cd1_common import rgb
    WORK.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    def safe_open(path):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        with bpy.data.libraries.load(str(path),link=False) as (src,dst):dst.scenes=src.scenes
        scene=next((s for s in dst.scenes if 'animation_manifest' in s),None) or next(s for s in dst.scenes if s.camera)
        scene.compositing_node_group=None;bpy.context.window.scene=scene
        scene.cycles.seed=27102026
    if '--audit' in sys.argv:
        import numpy as np,hashlib
        def geometry(path):
            safe_open(path);result={}
            for ob in bpy.context.scene.objects:
                if ob.type!='MESH':continue
                a=np.empty(len(ob.data.vertices)*3,dtype=np.float32);ob.data.vertices.foreach_get('co',a)
                result[ob.name]=hashlib.sha256(a.tobytes()).hexdigest()
            return result
        original=geometry(ra.SOURCE);variant=geometry(BLEND)
        spots=sum(1 for ob in bpy.context.scene.objects if ob.type=='MESH' for p in ob.data.polygons if 'marbling' in ob.data.materials[p.material_index].name)
        silver=[ob.name for ob in bpy.context.scene.objects if ob.type=='MESH' and any('Skin1 silver spear' in m.name for m in ob.data.materials if m)]
        result={'geometry_equal':original==variant,'marbled_faces':spots,'silver_spear_objects':silver}
        (HERE/'_skin_rainette_material_audit.json').write_text(json.dumps(result,indent=2),encoding='utf8')
        print('AUDIT '+json.dumps(result),flush=True)
        return
    if not BLEND.exists() or '--prepare' in sys.argv or '--inspect' in sys.argv:
        bpy.ops.wm.open_mainfile(filepath=str(ra.SOURCE))
        print('MATERIALS '+json.dumps([m.name for m in bpy.data.materials]),flush=True)
        if '--inspect' in sys.argv:return
        for mat in bpy.data.materials:
            if not mat.use_nodes:continue
            bs=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
            if not bs:continue
            if bs.inputs['Emission Strength'].default_value>.01:continue
            name=mat.name.lower()
            color=None;metal=0.;rough=.35
            if any(x in name for x in ('skin','amphib','frog','olive','mottle')):color='232A33';rough=.21
            elif any(x in name for x in ('iron','rust','armor','armour','cuirass','bronze')):color='4A4030';metal=.8;rough=.34
            elif any(x in name for x in ('leather','strap','reed','wood','haft')):color='17191C';rough=.6
            elif any(x in name for x in ('steel','silver','blade','spear','metal')):color='8E8E86';metal=.85
            if color:
                bs.inputs['Base Color'].default_value=rgb(color)
                bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
                for node in mat.node_tree.nodes:
                    if node.type=='VALTORGB':
                        for e in node.color_ramp.elements:e.color=rgb(color)
        # Surface markings only: preserve every vertex, silhouette, rig and pose.
        import math
        for ob in bpy.context.scene.objects:
            if ob.type!='MESH':continue
            if 'spear' in ob.name.lower() and any(x in ob.name.lower() for x in ('head','tip','blade','point')):
                silver=ob.data.materials[0].copy();silver.name='Skin1 silver spear #8E8E86'
                bs=next(n for n in silver.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
                bs.inputs['Base Color'].default_value=rgb('8E8E86');bs.inputs['Metallic'].default_value=.85
                for node in silver.node_tree.nodes:
                    if node.type=='VALTORGB':
                        for e in node.color_ramp.elements:e.color=rgb('8E8E86')
                ob.data.materials[0]=silver
            for index,mat in list(enumerate(ob.data.materials)):
                if not mat or 'amphibian skin' not in mat.name.lower():continue
                pale=mat.copy();pale.name='Skin1 pale grey marbling #7A8078'
                bs=next(n for n in pale.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
                bs.inputs['Base Color'].default_value=rgb('7A8078')
                for node in pale.node_tree.nodes:
                    if node.type=='VALTORGB':
                        for e in node.color_ramp.elements:e.color=rgb('7A8078')
                ob.data.materials.append(pale);slot=len(ob.data.materials)-1
                for p in ob.data.polygons:
                    if p.material_index!=index:continue
                    c=p.center
                    if ('thigh' in ob.name.lower() or 'hip' in ob.name.lower() or c.y>0) and math.sin(c.x*29+math.sin(c.z*17)*2)+math.cos(c.z*31+c.y*12)>1.35:p.material_index=slot
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
        if '--prepare' in sys.argv:return
    ra.SOURCE=BLEND;ra.DEST=OUT;ra.WORK=WORK/'rainette_skin1_frames';ra.resources=lambda:None
    posemesh=ra.posed_mesh
    def traced_mesh(root,name):
        print('POSE '+name,flush=True)
        mesh=posemesh(root,name)
        print('MESH '+name,flush=True)
        return mesh
    ra.posed_mesh=traced_mesh
    hd.adapted(iso.render_frame)
    original=iso.render_frame
    def frame(path,passes=True):
        path=Path(path)
        print('FRAME '+str(path),flush=True)
        marker=WORK/'rainette_skin1_frames'/(path.stem+'.done')
        if '--resume' in sys.argv and marker.exists() and path.exists() and path.with_name(path.stem+'_e.png').exists():return path
        cel.install('creature',normals=False)
        print('INSTALL PASS',flush=True)
        result=original(path,passes=passes)
        from PIL import Image
        from halve_emission import downscale
        ep=path.with_name(path.stem+'_e.png')
        if ep.exists():
            with Image.open(ep) as im,Image.open(path) as diffuse:
                image=downscale(im.convert('RGBA')) if im.size==diffuse.size else im.copy()
                image.save(ep,optimize=True,compress_level=9)
        with Image.open(path) as im:im.save(path,optimize=True,compress_level=9)
        marker.parent.mkdir(parents=True,exist_ok=True);marker.write_text('PASS',encoding='ascii')
        return result
    iso.render_frame=frame
    source=inspect.getsource(ra.common.atlases).replace("['Averse']","['Rainette']").replace('AV1','SKIN_RAINETTE')
    ra.safe_open=safe_open
    source=source.replace('bpy.ops.wm.open_mainfile(filepath=str(SOURCE))','safe_open(SOURCE)')
    source=source.replace("manifest=json.loads(s['animation_manifest'])", "print('OPEN PASS',flush=True);manifest=json.loads(s['animation_manifest'])")
    hd.adapted(source=source,namespace=ra.__dict__)()
    safe_open(ROOT/'art/blender/characters/rainette_portrait.blend')
    # Same materials from the saved variant; preserve portrait camera and pose.
    with bpy.data.libraries.load(str(BLEND),link=False) as (src,dst):
        names=list(src.materials);dst.materials=names
        objects=list(src.objects);dst.objects=objects
    replacements=dict(zip(names,dst.materials));surfaces=dict(zip(objects,dst.objects))
    for ob in bpy.context.scene.objects:
        if ob.type=='MESH':
            ref=surfaces.get(ob.name)
            if ref and ref.type=='MESH' and len(ref.data.polygons)==len(ob.data.polygons):
                ob.data.materials.clear()
                for m in ref.data.materials:ob.data.materials.append(m)
                for p,q in zip(ob.data.polygons,ref.data.polygons):p.material_index=q.material_index
            else:
                for slot in ob.material_slots:
                    if slot.material and slot.material.name in replacements:slot.material=replacements[slot.material.name]
    frame(OUT/'portrait.png')

def driver():
    OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    log=HERE/'_skin_rainette_render.log'
    command=[BLENDER,'--background','--threads','2','--gpu-backend','vulkan','--python-exit-code','1','--python',str(Path(__file__).resolve()),'--','--render']
    with log.open('w',encoding='utf8') as f:
        if '--resume' not in sys.argv and '--inspect' not in sys.argv and '--prepared' not in sys.argv:
            for marker in (WORK/'rainette_skin1_frames').glob('*.done'):marker.unlink()
            rc=subprocess.call(command+['--prepare'],stdout=f,stderr=subprocess.STDOUT)
            if rc:raise SystemExit(rc)
        rc=subprocess.call(command+(['--inspect'] if '--inspect' in sys.argv else ['--resume'] if '--resume' in sys.argv else []),stdout=f,stderr=subprocess.STDOUT)
    print('BLENDER',rc,str(log))
    if rc:raise SystemExit(rc)
    if '--inspect' in sys.argv:return
    # Existing cel hero exporter conserves approved accent masks: unchanged zone/color.
    for ep in BASE.glob('*_e.png'):
        if (OUT/(ep.stem[:-2]+'.png')).exists():shutil.copy2(ep,OUT/ep.name)
    from PIL import Image
    for p in OUT.glob('*.png'):
        with Image.open(p) as im:im.save(p,optimize=True,compress_level=9)
    text=(BASE/'rainette.tres').read_text(encoding='utf8').replace('res://assets/sprites/characters/rainette/','res://assets/sprites/characters/rainette/skins/rainette_skin1/')
    (OUT/'rainette_skin1.tres').write_text(text,encoding='utf8')
    verify()

def verify():
    import numpy as np
    from PIL import Image
    cel.GAME_SPRITES=OUT;cel.ARCHIVE=BASE
    report={'sheets':{},'errors':[]}
    expected={p.name for p in BASE.glob('*.png') if not p.stem.endswith('_n')}
    actual={p.name for p in OUT.glob('*.png')}
    if actual!=expected:report['errors'].append('files: missing='+str(sorted(expected-actual))+' extra='+str(sorted(actual-expected)))
    for p in sorted(BASE.glob('*.png')):
        if p.stem.endswith(('_e','_n')):continue
        if not (OUT/p.name).exists():continue
        with Image.open(p) as im:w,h=im.size
        cell=256 if p.stem=='portrait' else 192
        try:
            result=cel.check_sheet(p.name,cell=cell,frames=w//cell,rows=h//cell,normals=False,min_iou=.95)
            a=np.asarray(Image.open(p).convert('RGBA'))[:,:,3]>128
            b=np.asarray(Image.open(OUT/p.name).convert('RGBA'))[:,:,3]>128
            ious=[]
            for y in range(0,h,cell):
                for x in range(0,w,cell):
                    aa=a[y:y+cell,x:x+cell];bb=b[y:y+cell,x:x+cell]
                    ious.append(float((aa&bb).sum()/max(1,(aa|bb).sum())))
            result['alpha_iou_min_cell']=min(ious);assert min(ious)>.95,('alpha_iou_min_cell',min(ious))
            ep=p.with_name(p.stem+'_e.png');new=OUT/ep.name
            if ep.exists():
                e=np.asarray(Image.open(ep).convert('RGBA'));f=np.asarray(Image.open(new).convert('RGBA'))
                assert e.shape==f.shape and e.shape[:2]==((h+1)//2,(w+1)//2)
                aa=(e[:,:,:3].max(2)>100)&(e[:,:,3]>128);bb=(f[:,:,:3].max(2)>100)&(f[:,:,3]>128)
                ious=[];c=cell//2
                for y in range(0,h//2,c):
                    for x in range(0,w//2,c):
                        u=aa[y:y+c,x:x+c];v=bb[y:y+c,x:x+c]
                        ious.append(float((u&v).sum()/max(1,(u|v).sum())) if (u|v).any() else 1.)
                result['accent_iou_min_cell']=min(ious);assert min(ious)>.90,('accent_iou_min_cell',min(ious))
                assert ((f[:,:,:3].max(2)>2)&(f[:,:,3]>0)).any()
            report['sheets'][p.stem]=result
        except Exception as ex:report['errors'].append(p.name+': '+repr(ex))
    (HERE/'_skin_rainette_verification.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    samples=[[(a+'.png',192,0,r) for a in ('idle','run','attack','cast_ult') if (OUT/(a+'.png')).exists()] for r in (0,2,4)]
    if (OUT/'portrait.png').exists():samples.append([('portrait.png',256,0,0)])
    ground=ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png'
    cel.contact_pair(samples,HERE/'_skin_rainette_contact.png',ground=str(ground),size=(1440,1000))
    print('VERIFY',len(report['sheets']),'errors',len(report['errors']))
    if report['errors']:raise SystemExit(1)

if __name__=='__main__':
    if '--render' in sys.argv:render()
    elif '--verify' in sys.argv:verify()
    else:driver()
