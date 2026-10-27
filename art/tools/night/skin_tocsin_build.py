"""Carillon: material-only Tocsin re-render, immutable rigs and contractual atlases.

System driver; Blender -- --render. --resume commits complete, verified sheets.
--only idle (or another animation) permits a bounded continuation.
"""
from pathlib import Path
import sys, json, shutil, subprocess, inspect, textwrap, re, hashlib, time

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent
sys.path[:0] = [str(HERE), str(ROOT/'art/tools/cel'), str(ROOT/'art/tools/iso'),
               str(ROOT/'art/tools'), str(ROOT/'art/tools/tocsin')]
import cel_style as cel
BASE = cel.GAME_SPRITES/'characters/tocsin'
OUT = BASE/'skins/tocsin_skin1'
WORK = ROOT/'art/blender/cel/skins/tocsin_skin1_work'
STAGE = WORK/'sheets'
BLEND = WORK.parent/'tocsin_skin1.blend'
REPORT = HERE/'_skin_tocsin_verification.json'
BLENDER = r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
GODOT = r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
PARTS = ['torso','head','neck_steam','arm_l','arm_r','leg_l','leg_r']
DIRS = ['e','se','s','sw','w','nw','n','ne']
BODY = ['idle','walk','hop_l','hop_r','handwalk','crawl_l','crawl_r','roll','fall',
        'attack','cast','cast_ult','death','throw_arm_l','throw_arm_r',
        'throw_leg_l','throw_leg_r','throw_head','neck_steam']
DETACHED = ['arm_clamp','arm_fly','arm_ground','leg_fly','leg_ground','head_fly']
PREFIX = 'res://assets/sprites/characters/tocsin/'
VERSION = 'Carillon-3'

def selected():
    return sys.argv[sys.argv.index('--only')+1].split(',') if '--only' in sys.argv else BODY+DETACHED+['portrait','portrait_headless']

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def inventory():
    resources = ['tocsin','tocsin_emission','tocsin_parts','tocsin_parts_emission']
    resources += ['tocsin_'+p+s for p in PARTS+DETACHED for s in ('','_emission')]
    png = {a+'.png' for a in BODY+DETACHED+['portrait','portrait_headless']}
    png |= {p.relative_to(BASE).as_posix() for p in BASE.glob('layers/*/packed/*.png') if not p.stem.endswith('_n')}
    png |= {str(Path(p).with_name(Path(p).stem+'_e.png')).replace('\\','/') for p in list(png)
            if (BASE/Path(p).with_name(Path(p).stem+'_e.png')).exists() and not Path(p).stem.endswith('_e')}
    return sorted(png), [r+'.tres' for r in resources if (BASE/(r+'.tres')).exists()]

def materials():
    """Change only original source colors/PBR sockets; preserve alpha and emission."""
    import bpy
    colors = {'Pitted black iron':('2B2F3A',.9,.22),
              'Verdigris bloom on cast bronze':('7A6A3E',.9,.24),
              'Bell bronze weathered to pale green':('A8946E',.9,.23),
              'Worn brass rivet heads':('8E8E86',.95,.19),
              'Rust leaking from joints':('6E3A2A',.85,.26),
              'Cracked wet harness leather':('5A3E2A',0,.44),
              'Soot deep in openings':('5A4A28',.7,.38),
              'Moss lodged in seams':('6E3A2A',.85,.26),
              'TOCP1 forged iron':('2B2F3A',.9,.22),
              'TOCP1 worn verdigris bronze':('7A6A3E',.9,.24),
              'TOCP1 dark copper windings':('6E3A2A',.85,.26),
              'TOCP1 worn brass':('8E8E86',.95,.19),
              'TOCP1 recess':('5A4A28',.7,.38)}
    def tint(mat,h,metal,rough):
        rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
        rgb=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
        for n in mat.node_tree.nodes:
            if n.type=='BSDF_PRINCIPLED':
                n.inputs['Base Color'].default_value=rgb
                n.inputs['Metallic'].default_value=metal
                n.inputs['Roughness'].default_value=rough
            elif n.type=='VALTORGB':
                for e in n.color_ramp.elements:e.color=rgb
        mat.diffuse_color=rgb
    for mat in bpy.data.materials:
        if not mat.use_nodes:continue
        for name,params in colors.items():
            if mat.name.startswith(name):tint(mat,*params);break
        # The current TOCP1 pillar has blue arcs. Preserve their coverage and
        # strength while giving the skin its contractual single furnace accent.
        if mat.name.startswith('TOCP1 arc 8FD9FF'):
            tint(mat,'FF7A1F',0,.5)
            for node in mat.node_tree.nodes:
                if node.type=='BSDF_PRINCIPLED':
                    node.inputs['Emission Color'].default_value=mat.diffuse_color
    # Existing surface fittings keep exactly the same vertices and occlusion.
    bronze=next((m for m in bpy.data.materials if m.name=='Verdigris bloom on cast bronze'),None)
    iron=next((m for m in bpy.data.materials if m.name=='Pitted black iron'),None)
    if bronze:
        gold=bronze.copy();gold.name='Carillon golden lightning rod';tint(gold,'A8946E',.95,.19)
        copper=bronze.copy();copper.name='Carillon red copper bands';tint(copper,'6E3A2A',.9,.23)
        for ob in bpy.context.scene.objects:
            if ob.type not in ('MESH','CURVE'):continue
            name=ob.name.lower()
            target=bronze if name.startswith('riveted boiler shell') else gold if 'lightning' in name or 'paratonnerre' in name else copper if any(k in name for k in ('boiler hoop','boiler band','retaining band','bronze retaining hoop','tube collar')) else iron if any(k in name for k in ('hoof','boot','cable','sabaton')) else None
            if target:
                for slot in ob.material_slots:
                    if slot.material and not slot.material.get('rainfall_emissive'):
                        bs=next((n for n in slot.material.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
                        if bs and bs.inputs['Emission Strength'].default_value==0:slot.material=target

def setup_render():
    import bpy, iso_rig as iso, t2_build as t2
    import cel_heroes_tocsin_build as original
    WORK.mkdir(parents=True,exist_ok=True);STAGE.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    version=WORK/'materials_version.txt'
    if not BLEND.exists() or not version.exists() or version.read_text()!=VERSION:
        shutil.copy2(ROOT/'art/blender/characters/tocsin.blend',BLEND)
        # A material revision invalidates only this skin's intermediate renders.
        for marker in WORK.rglob('*.done'):marker.unlink()
        for image in WORK.rglob('*.png'):image.unlink()
        version.write_text(VERSION)
    # Reuse the approved Tocsin compositor, including animated source alpha.
    original.WORK=WORK;original.GAME=STAGE
    original.adapt(original.render,"    if '--top-only'")()
    source=textwrap.dedent(inspect.getsource(t2.configure)).replace(
        "'art/blender/characters/tocsin.blend'","'art/blender/cel/skins/tocsin_skin1.blend'")
    exec(compile(source,t2.__file__,'exec'),t2.__dict__)
    configure=t2.configure
    def configured():
        configure();materials()
        bpy.context.scene.cycles.seed=1701
        bpy.context.scene.eevee.taa_render_samples=8
    t2.configure=configured
    if '--torso-only' in sys.argv:
        # Keep the approved per-module tile caches; re-render only the shell's
        # module in the original seven-slot camera, then reuse both assemblers.
        import ast
        source=textwrap.dedent(inspect.getsource(t2.render_tiles))
        source=source.replace('visible(ob,k in active(anim))',"visible(ob,k in active(anim) and k=='torso')")
        source=source.replace('if k not in active(anim): continue',"if k not in active(anim) or k!='torso': continue")
        tree=ast.fix_missing_locations(original.Adapt().visit(ast.parse(source)))
        exec(compile(tree,t2.__file__,'exec'),t2.__dict__)
    else:original.adapt(t2.render_tiles)
    t2.GAME=STAGE
    shutil.copy2(BASE/'layers_order.json',STAGE/'layers_order.json')
    t2.OUT=WORK/'t2';t2.configure()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    return original

def render():
    import bpy, t2_build as t2, t3_build as t3, t4_build as t4
    original=setup_render()
    if '--audit-source' in sys.argv:
        audit={ob.name:[m.name for m in ob.data.materials] for ob in bpy.context.scene.objects
               if ob.type in ('MESH','CURVE') and any(s in ob.name.lower() for s in ('boiler shell','retaining hoop','lightning','cable'))}
        (HERE/'_skin_tocsin_materials.json').write_text(json.dumps(audit,indent=2))
        assert all(any('Carillon red copper bands' in m for m in names) for name,names in audit.items() if 'retaining hoop' in name.lower())
        assert all(any('Carillon golden lightning rod' in m for m in names) for name,names in audit.items() if 'lightning' in name.lower())
        print('PASS material audit',len(audit),flush=True);return
    import iso_rig as iso
    jobs=selected()
    # T3 replaces these T2 clips; TOCP3 subsequently replaces cast and both arms.
    old_anims=dict(t2.ANIMS); new_anims=dict(t3.NEW)
    for lot,anims in [('t2',{a:n for a,n in old_anims.items() if a not in new_anims}),('t3',new_anims)]:
        if lot=='t3':t3.OUT=WORK/'t3';t3.GAME=STAGE;t3.setup()
        t2.OUT=WORK/lot
        if lot=='t2':t2.ANIMS=old_anims
        for anim,n in anims.items():
            if anim not in jobs or anim in ('cast','throw_arm_l','throw_arm_r'):continue
            if '--resume' in sys.argv and (WORK/(anim+'.sheet.done')).exists():continue
            for d in DIRS:
                for i in range(n):
                    done=t2.OUT/anim/d/f'{i:02d}.done'
                    if '--resume' in sys.argv and done.exists():continue
                    t2.render_tiles(anim,d,i);done.write_text('PASS')
            if lot=='t2':
                saved=t2.ANIMS;t2.ANIMS={anim:n}
                original.adapt(t2.assemble,"    resource(GAME/'tocsin.tres')")(json.loads((BASE/'layers_order.json').read_text())['orders'])
                t2.ANIMS=saved
            else:
                saved=t3.NEW;t3.NEW={anim:n}
                original.adapt(t3.assemble,'    # Existing resources')()
                t3.NEW=saved
            finish_sheet(anim)
            print('PASS sheet '+anim,flush=True)
    if any(a in jobs for a in ('cast','throw_arm_l','throw_arm_r')):
        # Execute the existing TOCP3 pose setup, excluding its renderer/icons.
        # It starts from T2's idle pose, not T3's scene-local fired-rivet object.
        t2.pose=t3.old_pose;t2.active=t3.old_active;t2.ANIMS=old_anims
        import tocp3_build as p3
        p3.WORK=WORK/'tocp3';p3.GAME=STAGE
        src=textwrap.dedent(inspect.getsource(p3.render))
        src=src[:src.index('    for fn in (iso.render_frame,base.render_tiles):')]+src[src.index('    # Cel replaces Principled'):]
        src=src[:src.index('    for anim,n in ANIMS.items():')]
        exec(compile(src,p3.__file__,'exec'),p3.__dict__);p3.render()
        for anim,n in p3.ANIMS.items():
            if anim not in jobs:continue
            if '--resume' in sys.argv and (WORK/(anim+'.sheet.done')).exists():continue
            for d in DIRS:
                for i in range(n):
                    done=p3.WORK/anim/d/f'{i:02d}.done'
                    if '--resume' in sys.argv and done.exists():continue
                    t2.render_tiles(anim,d,i);done.write_text('PASS')
            # T3 assembly permits the deliberately absent released-arm cells.
            saved=t3.NEW;t3.NEW={anim:n};t3.OUT=p3.WORK
            original.adapt(t3.assemble,'    # Existing resources')()
            t3.NEW=saved;finish_sheet(anim)
            print('PASS sheet '+anim,flush=True)
    # Restore T2 before the detached-parts studio.
    t2.pose=t3.old_pose;t2.active=t3.old_active;t2.ANIMS=old_anims
    t4.OUT=WORK/'t4';t4.GAME=STAGE;t4.SUFFIXES=('','_e');t4.resource=lambda *a,**k:None
    if any(a in jobs for a in ('leg_fly','leg_ground','head_fly')):
        t4.setup();cel.install('creature',normals=False)
        for anim in ('leg_fly','leg_ground','head_fly'):
            if anim not in jobs:continue
            if '--resume' in sys.argv and (WORK/(anim+'.sheet.done')).exists():continue
            for d in DIRS:
                for i in range(t4.ANIMS[anim]):
                    path=t4.OUT/anim/d/f'{i:02d}.png'
                    if '--resume' in sys.argv and path.exists():continue
                    t4.part_pose(anim,i,d);t4.tile(f'{anim}/{d}/{i:02d}')
            t4.assemble(anim,t4.ANIMS[anim],DIRS);finish_sheet(anim)
    if any(a in jobs for a in ('arm_fly','arm_clamp','arm_ground')):
        import tocp1_build as p1
        p1.WORK=WORK/'tocp1';p1.GAME=STAGE
        # Keep approved pillar geometry, timing and transforms; use common cel frame wrapper.
        p1.ANIMS={a:n for a,n in p1.ANIMS.items() if a in jobs and not ('--resume' in sys.argv and (WORK/(a+'.sheet.done')).exists())}
        if p1.ANIMS:
            src=textwrap.dedent(inspect.getsource(p1.render))
            start=src.index('    # Reuse the renderer with only its obsolete normal-pass')
            end=src.index("    scene.render.threads_mode='FIXED'",start)
            src=src[:start]+src[end:]
            src=src.replace("    cel.install('creature',normals=False)","    __import__('skin_tocsin_build').materials()\n    cel.install('creature',normals=False)")
            exec(compile(src,p1.__file__,'exec'),p1.__dict__);p1.render()
            from PIL import Image
            for anim,n in p1.ANIMS.items():
                sheet=Image.new('RGBA',(192*n,1536))
                for row,d in enumerate(DIRS):
                    for i in range(n):
                        with Image.open(p1.WORK/anim/d/f'{i:02d}.png') as im:sheet.paste(im,(i*192,row*192))
                sheet.save(STAGE/(anim+'.png'),optimize=True,compress_level=9)
                finish_sheet(anim)
    if any(a.startswith('portrait') for a in jobs):
        # Original studio, camera and source seed; no spell icons or source saves.
        t4.random.seed(404);t4.SPELLS=[]
        original.adapt(t4.ui)()
        for anim in ('portrait','portrait_headless'):
            if anim in jobs:finish_sheet(anim)

def crop_spec(anim):
    if anim in ('portrait','portrait_headless'):return None
    # Read the current SpriteFrames regions: TOCP1/TOCP3 supersede historic crop data.
    resource=BASE/('tocsin_'+anim+'.tres' if anim in DETACHED else 'tocsin.tres')
    text=resource.read_text(encoding='utf-8')
    ext=re.search(r'\[ext_resource[^\n]*path="'+re.escape(PREFIX+anim+'.png')+r'" id="([^"]+)"',text)
    assert ext,anim
    block=re.search(r'\[sub_resource[^\n]*\]\natlas = ExtResource\("'+re.escape(ext[1])+r'"\)(.*?)(?=\n\[|\Z)',text,re.S)[1]
    region=[int(float(x)) for x in re.search(r'region = Rect2\(([^)]+)\)',block)[1].split(',')]
    margin=[int(float(x)) for x in re.search(r'margin = Rect2\(([^)]+)\)',block)[1].split(',')]
    from PIL import Image
    with Image.open(BASE/(anim+'.png')) as im:w,h=im.size
    return {'cell':192,'box':[margin[0],margin[1],margin[0]+region[2],margin[1]+region[3]],'grid':[w//region[2],h//region[3]]}

def actual_layout(layer,anim):
    """Runtime module regions are authoritative when TOCP3 supersedes T5's JSON."""
    from PIL import Image
    rel=f'layers/{layer}/packed/{anim}.png'
    text=(BASE/('tocsin_'+layer+'.tres')).read_text(encoding='utf-8')
    ext=re.search(r'\[ext_resource[^\n]*path="'+re.escape(PREFIX+rel)+r'" id="([^"]+)"',text)
    assert ext,rel
    blocks={}
    for match in re.finditer(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\](.*?)(?=\n\[|\Z)',text,re.S):
        block=match[2]
        if 'atlas = ExtResource("'+ext[1]+'")' not in block:continue
        region=[int(float(v)) for v in re.search(r'region = Rect2\(([^)]+)\)',block)[1].split(',')]
        margin=re.search(r'margin = Rect2\(([^)]+)\)',block)
        margin=[int(float(v)) for v in margin[1].split(',')] if margin else [0,0,0,0]
        blocks[match[1]]={'region':region,'crop':[margin[0],margin[1],margin[0]+region[2],margin[1]+region[3]]}
    frames=[]
    for match in re.finditer(r'\{\s*"frames":\s*\[(.*?)\],\s*"loop":\s*(?:true|false),\s*"name":\s*&"([^"]+)"',text,re.S):
        if match[2] not in [anim+'_'+d for d in DIRS]:continue
        direction=match[2][len(anim)+1:]
        for i,sid in enumerate(re.findall(r'"texture":\s*SubResource\("([^"]+)"\)',match[1])):
            assert sid in blocks,(rel,sid)
            frames.append(dict(blocks[sid],frame=i,direction=direction))
    assert frames,(rel,'no runtime frames')
    with Image.open(BASE/rel) as im:size=list(im.size)
    return {'size':size,'frames':frames}

def finish_sheet(anim):
    from PIL import Image
    import t5_build as t5
    import cel_heroes_tocsin_crop as crop
    OUT.mkdir(parents=True,exist_ok=True)
    source=STAGE/(anim+'.png');dest=OUT/(anim+'.png')
    with Image.open(source) as im:
        spec=crop_spec(anim)
        result=crop.transform(im,spec) if spec else im.copy()
        assert result.size==Image.open(BASE/dest.name).size,(anim,result.size)
        result.save(dest,optimize=True,compress_level=9)
    # Retain exact approved subpixel accent coverage and radiance.
    for name in [anim+'_e.png']:
        if (BASE/name).exists():shutil.copy2(BASE/name,OUT/name)
    layout=json.loads((BASE/'atlas_manifest.json').read_text())
    t5.GAME=STAGE;t5.PASSES=['']
    for key,value in layout.items():
        layer,a=key.split('/')
        if a!=anim:continue
        folder=STAGE/'layers'/layer/'packed';folder.mkdir(parents=True,exist_ok=True)
        t5.pack(layer,anim,layout=actual_layout(layer,anim))
        for suffix in ('','_e'):
            rel=f'layers/{layer}/packed/{anim}{suffix}.png'
            if not (BASE/rel).exists():continue
            target=OUT/rel;target.parent.mkdir(parents=True,exist_ok=True)
            src=STAGE/rel if not suffix and layer!='neck_steam' else BASE/rel
            shutil.copy2(src,target)
    verify_sheet(anim)
    (WORK/(anim+'.sheet.done')).write_text('PASS')

def iou(a,b):
    return float((a&b).sum()/max(1,(a|b).sum())) if (a|b).any() else 1.0

def verify_sheet(anim):
    from PIL import Image
    import numpy as np
    files,_=inventory();results=[]
    for rel in files:
        if Path(rel).stem!=anim or not (OUT/rel).exists():continue
        aa=np.asarray(Image.open(BASE/rel).convert('RGBA'))
        bb=np.asarray(Image.open(OUT/rel).convert('RGBA'))
        assert aa.shape==bb.shape,(rel,'size')
        r=cel.check_sheet('characters/tocsin/skins/tocsin_skin1/'+rel,normals=False)
        spec=crop_spec(anim) if '/packed/' not in rel else None
        cells=[]
        if '/packed/' in rel:
            layout=actual_layout(rel.split('/')[1],anim)
            cells=[f['region'] for f in layout['frames']]
        elif spec:
            cw=aa.shape[1]//spec['grid'][0];ch=aa.shape[0]//spec['grid'][1]
            cells=[[x*cw,y*ch,cw,ch] for y in range(spec['grid'][1]) for x in range(spec['grid'][0])]
        else:cells=[[0,0,aa.shape[1],aa.shape[0]]]
        values=[]
        for x,y,w,h in cells:
            a=aa[y:y+h,x:x+w,3]>128;b=bb[y:y+h,x:x+w,3]>128
            assert a.any()==b.any(),(rel,'empty cell',x,y)
            v=iou(a,b);values.append(v)
            assert v>.95,(rel,'alpha IoU',x,y,v)
        r['alpha_iou_min']=min(values);r['cells']=len(cells)
        ep=OUT/Path(rel).with_name(Path(rel).stem+'_e.png')
        if ep.exists():
            e=np.asarray(Image.open(ep).convert('RGBA'));ref=np.asarray(Image.open(BASE/ep.relative_to(OUT)).convert('RGBA'))
            assert e.shape[:2]==((bb.shape[0]+1)//2,(bb.shape[1]+1)//2),(rel,'emission size')
            assert (e[...,:3].max(axis=2)*e[...,3].astype(float)/255).max()>2,(rel,'black emission')
            r['accent_iou']=iou((e[...,:3].max(axis=2)>100)&(e[...,3]>128),(ref[...,:3].max(axis=2)>100)&(ref[...,3]>128))
            assert r['accent_iou']>.90,(rel,'accent IoU')
            accent_values=[]
            for x,y,w,h in cells:
                ee=e[y//2:(y+h+1)//2,x//2:(x+w+1)//2]
                rr=ref[y//2:(y+h+1)//2,x//2:(x+w+1)//2]
                a=(ee[...,:3].max(axis=2)>100)&(ee[...,3]>128)
                b=(rr[...,:3].max(axis=2)>100)&(rr[...,3]>128)
                accent_values.append(iou(a,b))
            r['accent_iou_min']=min(accent_values)
            assert r['accent_iou_min']>.90,(rel,'cell accent IoU',r['accent_iou_min'])
            bright=(e[...,:3].max(axis=2)>100)&(e[...,3]>128)
            r['blue_accent_pixels']=int(((e[...,2]>e[...,0])&bright).sum())
        results.append(r)
    report=json.loads(REPORT.read_text()) if REPORT.exists() else {'sheets':{},'status':'partial'}
    report['sheets'][anim]=results
    report['complete_sheets']=sorted(p.stem.replace('.sheet','') for p in WORK.glob('*.sheet.done'))
    report['complete_sheets']=sorted(set(report['complete_sheets']+[anim]))
    REPORT.write_text(json.dumps(report,indent=2))

def resources():
    files,res=inventory();allowed=set(files)
    for name in res:
        text=(BASE/name).read_text(encoding='utf-8')
        def replace(m):
            rel=m[1]
            return 'path="'+PREFIX+('skins/tocsin_skin1/' if rel in allowed else '')+rel+'"'
        text=re.sub(r'path="'+re.escape(PREFIX)+r'([^"\n]+)"',replace,text)
        # TOCP1 removed the black arm_ground mask; the legacy aggregate still
        # references it. Empty AtlasTextures retain the existing frame contract.
        missing=[]
        for line in text.splitlines():
            ext=re.match(r'\[ext_resource[^\n]*path="(res://[^"\n]+)" id="([^"]+)"\]',line)
            if ext and not (ROOT/'game'/ext[1][6:]).exists():
                assert ext[1].endswith('/arm_ground_e.png'),ext[1]
                missing.append(ext[2]);text=text.replace(line+'\n','')
        for ident in missing:text=text.replace('atlas = ExtResource("'+ident+'")','atlas = null')
        assert 'CanvasTexture' not in text and 'normal_texture' not in text and '_n.png' not in text,name
        dest=OUT/('tocsin_skin1.tres' if name=='tocsin.tres' else name)
        dest.write_text(text,encoding='utf-8')
    for name in ('layers_order.json','atlas_manifest.json'):shutil.copy2(BASE/name,OUT/name)

def pillar_emission():
    """Assemble Blender's orange pillar accent; never recolor bitmap pixels."""
    from PIL import Image
    from halve_emission import downscale
    import cel_heroes_tocsin_crop as crop
    anim='arm_clamp';spec=crop_spec(anim);n=spec['grid'][0]
    sheet=Image.new('RGBA',(n*192,1536))
    for row,d in enumerate(DIRS):
        for i in range(n):
            with Image.open(WORK/'tocp1'/anim/d/f'{i:02d}_e.png') as im:
                sheet.paste(im,(i*192,row*192))
    downscale(crop.transform(sheet,spec)).save(OUT/(anim+'_e.png'),optimize=True,compress_level=9)

def optimize():
    from PIL import Image
    for p in OUT.rglob('*.png'):
        with Image.open(p) as im:im.save(p,optimize=True,compress_level=9)

def checks():
    import texture_budget as budget
    tests={}
    def run(name,args,test=False):
        log=HERE/('_skin_tocsin_'+name+'.log')
        with log.open('w') as stream:
            p=subprocess.run(args,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,
                             timeout=600,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        output=log.read_text(errors='replace')
        ok=p.returncode==0 and ('RESULT: OK' in output if test else 'ERROR:' not in output)
        tests[name]={'ok':ok,'exit':p.returncode,'log':str(log.relative_to(ROOT)),
                     'result_lines':[s for s in output.splitlines() if 'RESULT:' in s or 'mobile' in s and ('Mo' in s or 'budget' in s)]}
        print(name, 'PASS' if ok else 'FAIL',flush=True)
    run('policy',[sys.executable,str(ROOT/'art/tools/texture_budget.py'),'--apply-policy'])
    run('import',[GODOT,'--headless','--path',str(ROOT/'game'),'--import'])
    for name in ('sprites','tocsin','texture_budget'):
        run(name,[GODOT,'--headless','--path',str(ROOT/'game'),'res://tests/'+name+'_test.tscn'],True)
    code='''extends SceneTree
func _initialize():
    var original = load("res://assets/sprites/characters/tocsin/tocsin.tres")
    var skin = load("res://assets/sprites/characters/tocsin/skins/tocsin_skin1/tocsin_skin1.tres")
    if not (original is SpriteFrames) or not (skin is SpriteFrames):
        print("RESULT: FAIL SpriteFrames")
        quit(1)
        return
    if original.get_animation_names() != skin.get_animation_names():
        print("RESULT: FAIL animations")
        quit(1)
        return
    for anim in original.get_animation_names():
        if original.get_frame_count(anim) != skin.get_frame_count(anim) or original.get_animation_speed(anim) != skin.get_animation_speed(anim) or original.get_animation_loop(anim) != skin.get_animation_loop(anim):
            print("RESULT: FAIL frame contract")
            quit(1)
            return
'''
    _,res=inventory()
    for name in res:
        name='tocsin_skin1.tres' if name=='tocsin.tres' else name
        code+='    if not load('+json.dumps(PREFIX+'skins/tocsin_skin1/'+name)+') is SpriteFrames:\n        print("RESULT: FAIL module")\n        quit(1)\n        return\n'
    code+='    print("RESULT: OK")\n    quit(0)\n'
    script=HERE/'_skin_tocsin_load.tres'
    script.write_text('[gd_resource type="GDScript" format=3]\n\n[resource]\nscript/source = '+json.dumps(code)+'\n')
    run('load',[GODOT,'--headless','--path',str(ROOT/'game'),'--script',str(script)],True)
    run('budget',[sys.executable,str(ROOT/'art/tools/texture_budget.py'),'--top','0','--json',str(HERE/'_skin_tocsin_budget_after.json')])
    rows=budget.scan();skin=[r for r in rows if '/tocsin/skins/tocsin_skin1/' in r['path']]
    category=[r for r in rows if r['cat']=='characters/tocsin']
    report=json.loads(REPORT.read_text())
    report['tests']=tests
    report['budget']={'skin_added':{k:sum(r[k] for r in skin)/budget.MB for k in ('png','mobile')},
        'characters/tocsin_after':{k:sum(r[k] for r in category)/budget.MB for k in ('png','mobile')},
        'global_mobile_after':sum(r['mobile'] for r in rows)/budget.MB,
        'global_mobile_limit':180,'target_mobile':95,'before_log':'_skin_tocsin_budget_before.txt'}
    report['budget']['characters/tocsin_before']={k:report['budget']['characters/tocsin_after'][k]-report['budget']['skin_added'][k] for k in ('png','mobile')}
    expected_png,expected_res=inventory()
    expected=set(expected_png+['tocsin_skin1.tres' if r=='tocsin.tres' else r for r in expected_res]+['atlas_manifest.json','layers_order.json'])
    actual={p.relative_to(OUT).as_posix() for p in OUT.rglob('*') if p.is_file() and not p.name.endswith(('.import','.uid'))}
    assert actual==expected,{'extra':sorted(actual-expected),'missing':sorted(expected-actual)}
    baseline=json.loads((HERE/'_skin_tocsin_default_hashes.json').read_text())
    changed=[p for p,h in baseline.items() if digest(BASE/p)!=h]
    assert not changed,changed
    sources=json.loads((HERE/'_skin_tocsin_sources.json').read_text())
    assert all(digest(ROOT/'art/blender/characters'/p)==h for p,h in sources.items())
    report['default_files_unchanged']=len(baseline);report['source_blends_unchanged']=sources
    report['inventory']={'png':len(expected_png),'tres':len(expected_res),'json':2,'unexpected':[]}
    skin_prefix=PREFIX+'skins/tocsin_skin1/'
    assert (OUT/'tocsin_skin1.tres').read_text(encoding='utf-8').replace(skin_prefix,PREFIX)==(BASE/'tocsin.tres').read_text(encoding='utf-8')
    for name in ('atlas_manifest.json','layers_order.json'):assert digest(OUT/name)==digest(BASE/name)
    results=[r for group in report['sheets'].values() for r in group]
    report['quality']={'alpha_iou_min':min(r['alpha_iou_min'] for r in results),
        'accent_iou_min':min(r.get('accent_iou_min',1) for r in results),
        'blue_accent_pixels':sum(r.get('blue_accent_pixels',0) for r in results)}
    assert report['quality']['blue_accent_pixels']==0,report['quality']
    report['deviations']=['TOCP1 arm_clamp: existing blue arc recolored in Blender to furnace orange; unchanged accent zones.',
        'Legacy tocsin_parts_emission.tres referenced absent arm_ground_e.png; skin aggregate uses empty AtlasTextures for these frames.']
    report['status']='PASS' if all(tests[n]['ok'] for n in ('policy','import','sprites','tocsin','load')) else 'FAIL'
    REPORT.write_text(json.dumps(report,indent=2))
    assert report['status']=='PASS',tests

def contact():
    # Map cel's archive lookup onto the current default without copying sprites.
    class Reference:
        def __truediv__(self,rel):return BASE/str(rel).split('tocsin_skin1/',1)[-1]
    saved=cel.ARCHIVE;cel.ARCHIVE=Reference()
    samples=[]
    for names in [('idle','walk'),('attack','cast_ult'),('portrait',)]:
        row=[]
        for anim in names:
            if not (OUT/(anim+'.png')).exists():continue
            from PIL import Image
            spec=crop_spec(anim)
            with Image.open(OUT/(anim+'.png')) as im:w,h=im.size
            cell=(w//spec['grid'][0],h//spec['grid'][1]) if spec else (w,h)
            col=3 if anim in ('attack','cast_ult') else 2 if anim=='walk' else 0
            row.append(('characters/tocsin/skins/tocsin_skin1/'+anim+'.png',cell,col,2 if spec else 0))
        if row:samples.append(row)
    try:cel.contact_pair(samples,HERE/'_skin_tocsin_contact.png',size=(1440,900))
    finally:cel.ARCHIVE=saved

def driver():
    WORK.mkdir(parents=True,exist_ok=True)
    hashes=HERE/'_skin_tocsin_default_hashes.json'
    if not hashes.exists():
        hashes.write_text(json.dumps({p.relative_to(BASE).as_posix():digest(p) for p in BASE.rglob('*')
            if p.is_file() and 'skins' not in p.relative_to(BASE).parts and p.suffix in ('.png','.tres','.json')}))
    sources=HERE/'_skin_tocsin_sources.json'
    if not sources.exists():
        names=['tocsin','tocsin_t2','tocsin_t3','tocsin_t3_regen','tocsin_t4','tocsin_t4_portraits']
        sources.write_text(json.dumps({n+'.blend':digest(ROOT/'art/blender/characters'/(n+'.blend')) for n in names}))
    before=HERE/'_skin_tocsin_budget_before.txt'
    if not before.exists():
        with before.open('w') as stream:
            subprocess.run([sys.executable,str(ROOT/'art/tools/texture_budget.py'),'--top','0'],cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,check=True)
    args=[BLENDER,'--background','--python-exit-code','1','--python',str(Path(__file__).resolve()),'--','--render']
    if '--torso-only' in sys.argv:
        for anim in selected():
            (WORK/(anim+'.sheet.done')).unlink(missing_ok=True)
        for lot in ('t2','t3','tocp3'):
            for marker in (WORK/lot).rglob('*.done'):marker.unlink()
    for opt in ('--resume','--torso-only'):
        if opt in sys.argv:args.append(opt)
    if '--only' in sys.argv:args+=['--only',sys.argv[sys.argv.index('--only')+1]]
    with (HERE/'_skin_tocsin_render.log').open('a' if '--resume' in sys.argv else 'w') as log:
        result=subprocess.run(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
    if result.returncode:raise RuntimeError('Blender failed; see art/tools/night/_skin_tocsin_render.log')
    files,_=inventory()
    complete=all((OUT/p).exists() for p in files)
    if complete:
        pillar_emission();resources();optimize()
        for a in BODY+DETACHED+['portrait','portrait_headless']:verify_sheet(a)
    contact()
    report=json.loads(REPORT.read_text());report['status']='PASS' if complete else 'partial'
    report['missing']=[p for p in files if not (OUT/p).exists()]
    REPORT.write_text(json.dumps(report,indent=2))
    if complete:checks()
    print('PASS complete' if complete else 'PASS partial; resume: python art/tools/night/skin_tocsin_build.py --resume')

if __name__=='__main__':
    if '--render' in sys.argv:render()
    elif '--checks' in sys.argv:checks()
    elif '--finalize' in sys.argv:
        pillar_emission();resources();optimize()
        for a in BODY+DETACHED+['portrait','portrait_headless']:verify_sheet(a)
        contact();checks()
    elif '--verify' in sys.argv:
        for a in selected():
            if (OUT/(a+'.png')).exists():verify_sheet(a)
        contact();print('PASS verification')
    else:driver()
