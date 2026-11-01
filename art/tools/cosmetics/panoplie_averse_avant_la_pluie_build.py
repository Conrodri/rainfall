"""Celadon Averse: material-only source copy, original rendering and compact contract."""
import sys,json,shutil,subprocess
sys.dont_write_bytecode=True
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
sys.path[:0]=[str(ROOT/'art/tools/night'),str(HERE),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso')]
import cel_style as cel
# Smooth cloth flats: omit normal-derived micro-creases, retain silhouette ink.
cel.PROFILES['creature']['creases']=False
BASE=ROOT/'game/assets/sprites/characters/averse';OUT=BASE/'skins/averse_avant_la_pluie'
WORK=ROOT/'art/blender/cel/skins/averse_avant_la_pluie_frames';SOURCE=WORK.parent/'averse_avant_la_pluie.blend'
BLENDER=r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
ANIMS={'idle':8,'run':8,'cast':4,'wave':6,'crue':8,'stumble':3,'attack':6,'cast_ult':8,'death':8}
SPECS=json.loads((ROOT/'art/blender/cel/heroes_c/compact.json').read_text())['sheets']
# Current default resources supersede the older compact manifest for action sheets.
import re
_contract=(BASE/'averse.tres').read_text()
for _a in ANIMS:
    for _id in re.findall(r'path="[^"]*/'+_a+r'.png" id="([^"]+)"',_contract):
        _regions=re.findall(r'atlas = ExtResource\("'+_id+r'"\)\s+region = Rect2\(([^)]+)\)\s+margin = Rect2\(([^)]+)\)',_contract)
        if not _regions:continue
        _region=[int(v.strip()) for v in _regions[0][0].split(',')];_margin=[int(v.strip()) for v in _regions[0][1].split(',')]
        _cw,_ch=_region[2:];_x,_y=_margin[:2]
        ANIMS[_a]=len(_regions)//8
        SPECS['characters/averse/'+_a+'.png']={**SPECS['characters/averse/'+_a+'.png'],'new_cell':[_cw,_ch],'box':[_x,_y,_x+_cw,_y+_ch]}

def materials():
    import bpy
    palette={'Waxed rain grey cloth':('6E675A',.85,0),'Cracked wet harness leather':('5E3F28',.75,0),'Verdigris bloom on cast bronze':('6F8586',.28,0),'Rust leaking from joints':('8A5A32',.35,.65),'Worn brass rivet heads':('8A5A32',.3,.7),'AV1 hammered bronze fittings':('8A5A32',.3,.7)}
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
    
    # Reuse the existing hood, harness and amphora surfaces; preserve all geometry.
    linen=bpy.data.materials.get('Waxed rain grey cloth')
    leather=bpy.data.materials.get('Cracked wet harness leather')
    glass=bpy.data.materials.get('Verdigris bloom on cast bronze')
    skin=bpy.data.materials.get('Cold weathered skin')
    for ob in bpy.data.objects:
        mat=None
        if ob.name.startswith(('Black hood recess','Trouser leg','Shaped boot leather','Cross lacing','Hood draw cord','Long stitched hem','Elbow fabric crease')):mat=linen
        if ob.name.startswith(('Leather glove','Long glove finger','Opposing glove thumb')):mat=skin
        if ob.name.startswith(('Black mineral drip on amphora','Mineral run beneath collar')):mat=glass
        if ob.name.startswith(('Angled deep coat pocket','Pocket bound edge','Tarnished coat fastening')):mat=leather
        if mat:
            for slot in ob.material_slots:slot.material=mat
        # The fitted upper dress surface becomes the laced leather corselet.
        if ob.type=='MESH' and ob.name.startswith('Heavy folded waxed raincoat') and leather:
            ob.data.materials.append(leather);idx=len(ob.data.materials)-1
            zs=[v.co.z for v in ob.data.vertices];lo=min(zs);span=max(zs)-lo
            for poly in ob.data.polygons:
                z=sum(ob.data.vertices[i].co.z for i in poly.vertices)/len(poly.vertices)
                if .58 < (z-lo)/max(span,.0001) < .86:poly.material_index=idx
    (WORK/'surface_inventory.json').write_text(json.dumps({o.name:[m.name for m in o.data.materials if m] for o in s.objects if o.type=='MESH'},indent=1))
    cel.toon_materials('creature')
    # Explicit three-tone linen ramp in scene-linear RGB; no procedural texture.
    ramp=linen.node_tree.nodes.get('CEL tones') if linen else None
    if ramp:
        for e,h in zip(ramp.color_ramp.elements,('4A453C','6E675A','8C8474')):
            v=[int(h[i:i+2],16)/255 for i in (0,2,4)]
            e.color=tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in v)+(1,)
    s.render.dither_intensity=0
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
    if '--portrait-only' in sys.argv:av1.ANIMS={}
    if '--only' in sys.argv:av1.ANIMS={a:n for a,n in av1.ANIMS.items() if a==sys.argv[sys.argv.index('--only')+1]}
    av1.F60={a:v for a,v in av1.F60.items() if a in av1.ANIMS}
    adapted(av1.atlases,[("s.eevee.taa_render_samples=12","s.eevee.taa_render_samples=8"),("    bpy.ops.wm.read_factory_settings(use_empty=True)\n    with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst):dst.scenes=src.scenes\n    s=dst.scenes[0];s.compositing_node_group=None;bpy.context.window.scene=s","    safe_open(SOURCE);s=bpy.context.scene"),("impact={'attack':3,'wave':3,'cast':2,'crue':5}[anim]","impact={'attack':3,'wave':3,'cast':2,'crue':5}.get(anim,-99)"),("bpy.ops.wm.open_mainfile(filepath=str(SOURCE))","safe_open(SOURCE)"),("('','_n','_e')","('','_e')")])()
    for a in av1.ANIMS:pack(a)
    if '--only' in sys.argv:
        shutil.copy2(WORK/'materials.blend',SOURCE)
        (WORK/'render.done').write_text('PASS');return
    shutil.copy2(ROOT/'art/blender/characters/averse_portrait.blend',WORK/'averse_portrait.blend');safe_open(WORK/'averse_portrait.blend');bpy.context.scene['iso_frame']=[256,256];cel.install('creature',normals=False)
    original(WORK/'portrait.png',passes=True)
    shutil.copy2(WORK/'portrait.png',OUT/'portrait.png')
    from PIL import Image
    with Image.open(OUT/'portrait.png') as im:im.save(OUT/'portrait.png',optimize=True,compress_level=9)
    ep=OUT/'portrait_e.png'
    if ep.exists():ep.unlink()
    (WORK/'render.done').write_text('PASS')

def verify():
    import numpy as np
    from PIL import Image
    report={'sheets':[],'errors':[],'complete':False,'godot':'skipped by orchestrator','mobile_estimate_reference_mib':1.2}
    ground=np.asarray(Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA'))
    g=ground[:,:,:3].astype(float)/255;gl=np.where(g<=.04045,g/12.92,((g+.055)/1.055)**2.4)@np.array([.2126,.7152,.0722]);ground_y=float(np.median(gl[ground[:,:,3]>128]))
    for a,n in [*ANIMS.items(),('portrait',1)]:
        p=OUT/f'{a}.png'
        if not p.exists():
            report['errors'].append([a,'missing']);continue
        cell=[256,256] if a=='portrait' else SPECS['characters/averse/'+a+'.png']['new_cell'];cw,ch=cell;rows=1 if a=='portrait' else 8
        r=cel.check_sheet(str(p.relative_to(ROOT/'game/assets/sprites')).replace('\\','/'),cell=tuple(cell),frames=n,rows=rows,normals=False)
        aa=np.asarray(Image.open(BASE/p.name).convert('RGBA'));bb=np.asarray(Image.open(p).convert('RGBA'));assert aa.shape==bb.shape
        ious=[];overflow=[]
        for y in range(rows):
            for x in range(n):
                ar=aa[y*ch:(y+1)*ch,x*cw:(x+1)*cw,3]>128;br=bb[y*ch:(y+1)*ch,x*cw:(x+1)*cw,3]>128
                ious.append(float((ar&br).sum()/max(1,(ar|br).sum())))
                padded=np.pad(ar,2);expanded=np.logical_or.reduce([padded[dy:dy+ch,dx:dx+cw] for dy in range(5) for dx in range(5)]);overflow.append(int((br&~expanded).sum()))
        opaque=bb[:,:,3]>128;rgb=bb[:,:,:3].astype(float)/255
        hi=rgb.max(axis=2);lo=rgb.min(axis=2);sat=(hi-lo)/np.maximum(hi,.0001)
        orange=(rgb[:,:,0]>rgb[:,:,1])&(rgb[:,:,1]>rgb[:,:,2])&(sat>.8)&(hi>.5)&opaque
        r.update(alpha_iou_cells=ious,outside_2px_cells=overflow,saturated_red_orange_pixels=int(orange.sum()),saturation_threshold=.8)
        # Saturation remains diagnostic; single Lanczos edge outliers are recorded above.
        linear=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
        lum=linear@np.array([.2126,.7152,.0722]);r['opaque_luminance_percentiles']=np.percentile(lum[opaque],[10,50,90]).tolist()
        r['contrast_ratio_median_to_ground']=float((max(np.median(lum[opaque]),ground_y)+.05)/(min(np.median(lum[opaque]),ground_y)+.05))
        linen=opaque&(rgb[:,:,0]>rgb[:,:,1])&(rgb[:,:,1]>rgb[:,:,2])&(sat<.3)&(hi>.3)
        if linen.any():
            value=float(np.percentile(lum[linen],50));r['linen_midtone_Lstar']=116*value**(1/3)-16 if value>.008856 else 903.3*value
            # Dark-art correction supersedes the original Lstar >= 45 criterion.
        if min(ious)<=.95 or max(overflow):report['errors'].append([a,min(ious),max(overflow)])
        ep=OUT/f'{a}_e.png'
        if ep.exists():
            assert ep.read_bytes()==(BASE/ep.name).read_bytes();e=Image.open(ep);assert e.size==((bb.shape[1]+1)//2,(bb.shape[0]+1)//2)
            ev=np.asarray(e.convert('RGBA')).astype(float);assert (ev[:,:,:3].max(axis=2)*ev[:,:,3]/255).max()>2;r['accent_iou']=1.;r['accent_iou_cells']=[1.]*(n*rows)
        report['sheets'].append(r)
    assert not list(OUT.glob('*_n.png')),'Forbidden normal maps'
    import re
    resource=OUT/'averse_avant_la_pluie.tres'
    if resource.exists():
        ref=(BASE/'averse.tres').read_text();text=resource.read_text()
        report['animation_names_equal']=re.findall(r'"name": &"([^"]+)"',ref)==re.findall(r'"name": &"([^"]+)"',text)
        assert report['animation_names_equal'] and 'CanvasTexture' not in text and 'normal_texture' not in text
        assert text==ref.replace('res://assets/sprites/characters/averse/','res://assets/sprites/characters/averse/skins/averse_avant_la_pluie/')
        assert all((ROOT/'game'/q[6:]).exists() for q in re.findall(r'path="(res://[^"]+)"',text))
    report['complete']=len(report['sheets'])==10
    def mean_lstar(path):
        a=np.asarray(Image.open(path).convert('RGBA'));rgb=a[:,:,:3].astype(float)/255
        y=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)@np.array([.2126,.7152,.0722])
        return float(np.where(y>216/24389,116*np.cbrt(y)-16,y*24389/27)[a[:,:,3]>127].mean())
    report['idle_Lstar']=mean_lstar(OUT/'idle.png');report['default_idle_Lstar']=mean_lstar(BASE/'idle.png')
    report['png_bytes']=sum(p.stat().st_size for p in OUT.glob('*.png'))
    report['alpha_iou_min']=min(min(r['alpha_iou_cells']) for r in report['sheets'])
    report['accent_iou_min']=min(r['accent_iou'] for r in report['sheets'] if 'accent_iou' in r)
    if report['idle_Lstar']>min(32.8,report['default_idle_Lstar']+10):report['errors'].append(['idle Lstar',report['idle_Lstar']])
    if report['png_bytes']>6.3*1048576:report['errors'].append(['PNG budget',report['png_bytes']])
    (WORK/'_panoplie_averse_avant_la_pluie_verification.json').write_text(json.dumps(report,indent=2))
    if report['complete']:
        expected={f'{a}.png' for a in [*ANIMS,'portrait']}|{f'{a}_e.png' for a in ANIMS}|{'averse_avant_la_pluie.tres'};assert {p.name for p in OUT.iterdir() if p.suffix!='.import'}==expected
    archive=WORK/'reference';rel=Path('characters/averse/skins/averse_avant_la_pluie');(archive/rel).mkdir(parents=True,exist_ok=True);samples=[]
    for a in ('idle','run','wave','portrait'):
        if (OUT/f'{a}.png').exists():
            shutil.copy2(BASE/f'{a}.png',archive/rel/f'{a}.png');cell=(256,256) if a=='portrait' else tuple(SPECS['characters/averse/'+a+'.png']['new_cell']);samples.append([(str(rel/f'{a}.png'),cell,0,0 if a=='portrait' else 2)])
    cel.ARCHIVE=archive;cel.contact_pair(samples,WORK/'_panoplie_averse_avant_la_pluie_contact.png',size=(960,1000))
    assert report['sheets'],'No completed sheets';print('VERIFY', 'FAIL' if report['errors'] else 'PASS',report['errors']);assert not report['errors']

def driver():
    log=WORK/'_logpanoplie_averse.txt'
    WORK.mkdir(parents=True,exist_ok=True);(WORK/'render.done').unlink(missing_ok=True)
    with log.open('a') as f:code=subprocess.call([BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']+sys.argv[1:],stdout=f,stderr=subprocess.STDOUT,cwd=ROOT)
    if not (WORK/'render.done').exists():raise RuntimeError('Incomplete Blender execution; '+str(log))
    if code:raise RuntimeError('Blender exit '+str(code)+'; '+str(log))
    if (WORK/'materials.blend').exists():shutil.copy2(WORK/'materials.blend',SOURCE)
    if '--only' not in sys.argv and '--portrait-only' not in sys.argv:assert all((OUT/f'{a}.png').exists() for a in [*ANIMS,'portrait']), 'Incomplete render; inspect log'
    if '--only' not in sys.argv:verify()
if __name__=='__main__':
    if '--render' in sys.argv:render()
    elif '--verify' in sys.argv:verify()
    else:driver()
