"""Dedicated Rainette VFX replacement. Background Blender; four PNG allowlist only."""
import sys, math, json, hashlib, shutil, ast, os, time
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT/'art/renders/feel_sorts2/rainette_vfx_b'
WORK = ROOT/'art/blender/cel/feel2'
DEST = ROOT/'game/assets/sprites/characters/rainette/effects'
SPECS = {'land_ring': (384,4,120000), 'goo': (352,6,157000)}
sys.path[:0] = [str(ROOT/'art/tools/iso'), str(ROOT/'art/tools/cel')]
if 'blender' in sys.executable.lower():sys.path.insert(0,str(ROOT/'art/tools/iso/_deps'))
from PIL import Image, ImageChops, ImageStat

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def outside_files():
    outer = ROOT.parents[2]
    assert outer.name == 'Rainfall', outer
    result = set()
    for folder, dirs, files in os.walk(outer):
        dirs[:] = [d for d in dirs if d not in ('.git','.claude','node_modules','.godot') and not (Path(folder)/d).is_symlink() and not os.path.isjunction(Path(folder)/d) and not (Path(folder)/d).resolve().is_relative_to(ROOT)]
        result.update(str(Path(folder)/f) for f in files)
    return result

def prepare():
    OUT.mkdir(parents=True, exist_ok=True); WORK.mkdir(parents=True, exist_ok=True)
    state = {'files':{}, 'protected':{}, 'outside':sorted(outside_files())}
    for key in SPECS:
        for suffix in ('','_e'):
            p = DEST/key/(key+suffix+'.png')
            shutil.copy2(p, OUT/('before_'+p.name))
            state['files'][p.name] = {'bytes':p.stat().st_size,'sha':sha(p)}
        for p in (DEST/key).glob('*.tres'):
            state['protected'][str(p.relative_to(ROOT))] = sha(p)
    (OUT/'baseline.json').write_text(json.dumps(state))

def mesh(name, vs, fs, mat, parent=None, bevel=0):
    import bpy
    data=bpy.data.meshes.new(name);data.from_pydata(vs,[],fs);data.update()
    ob=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat); ob.parent=parent
    return ob

def bead(name, pos, scale, mat):
    import bpy
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=pos)
    ob=bpy.context.object;ob.name=name;ob.scale=scale;ob.data.materials.append(mat)
    return ob

def tube(name, pts, width, mat):
    import bpy
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=width;cu.bevel_resolution=1
    sp=cu.splines.new('POLY');sp.points.add(len(pts)-1)
    for p,co in zip(sp.points,pts):p.co=(*co,1)
    ob=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(ob);ob.data.materials.append(mat)
    return ob

def mat(name, color, glow=0):
    import bpy
    rgb=tuple(int(color[i:i+2],16)/255 for i in (0,2,4))
    linear=tuple(c/12.92 if c<.04045 else ((c+.055)/1.055)**2.4 for c in rgb)
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*linear,1)
    p.inputs['Roughness'].default_value=.38
    p.inputs['Emission Color'].default_value=(*linear,1);p.inputs['Emission Strength'].default_value=glow
    return m

def polar(r,a,z):return (r*math.cos(a),r*math.sin(a),z)

def surface(key, f, mats):
    mud,wet,jade,foam,dark=mats
    phase=math.tau*f/6; count=120; rings=12; rmax=2.60
    vs=[(0,0,.09)]
    for k in range(1,rings+1):
        t=k/rings
        for j in range(count):
            a=math.tau*j/count
            edge=.95+.027*math.sin(11*a)+.021*math.sin(19*a+.8)+.012*math.sin(31*a)
            z=.05+.075*(1-t)+.055*(1+math.sin(t*25+3*a-phase))*(1-t*.6)
            if key=='land_ring':z*=.45
            vs.append(polar(rmax*t*edge,a,z))
    fs=[(0,1+j,1+(j+1)%count) for j in range(count)]
    fs += [(1+(k-1)*count+j,1+k*count+j,1+k*count+(j+1)%count,1+(k-1)*count+(j+1)%count) for k in range(1,rings) for j in range(count)]
    ob=mesh('Serrated viscous mire body',vs,fs,wet)
    ob.data.materials.append(mud);ob.data.materials.append(dark)
    for poly in ob.data.polygons:
        poly.material_index=1 if poly.index%17<3 else 0
    ob.modifiers.new('Thick liquid meniscus','SOLIDIFY').thickness=.07
    if key=='goo':
        for j in range(25):
            a=j*2.399963; r=.35+1.82*((j*.61803)%1); pos=polar(r,a,.11)
            pulse=.5+.5*math.sin(phase+j*1.7)
            size=.10+.10*((j*.414)%1)
            bead('Swelling adhesive blister',pos,(size*(1+.12*pulse),size,.10+.18*pulse),mud if j%3 else wet)
            # Broken lips and curved inward wakes; no regular rings.
            pts=[(pos[0]+size*math.cos(q*.22),pos[1]+size*math.sin(q*.22),.17+.16*pulse) for q in range(11)]
            tube('Jade wet blister lip',pts,.016,jade if j%3 else foam)
        for j in range(16):
            a=j*2.39996+.3;r=.8+1.48*((j*.618)%1)
            h=.20+.34*(.5+.5*math.sin(phase+j))
            pts=[polar(r-.30*t,a+.13*math.sin(t*math.pi)+.025*math.sin(phase+j),.10+h*math.sin(t*math.pi/2)) for t in [k/10 for k in range(11)]]
            # Reuse only RA2's volumetric ribbon helper, never its exporter.
            ribbon('Upright sticky mire tongue',pts,.08,.035,wet,None)
            tube('Jade ridge on adhesive thread',[(x,y,z+.035) for x,y,z in pts[3:]],.018,jade)
        for j in range(11):
            a=j*2.39996;r=.5+1.5*((j*.382)%1)
            pts=[polar(r+.10*math.sin(t*math.pi),a+.5*t,.16+.025*math.sin(phase+t*5+j)) for t in [k/16 for k in range(17)]]
            tube('Interrupted jade eddy',pts,.023,jade)

def crown(f,mats):
    mud,wet,jade,foam,dark=mats
    height=[1.0,.65,.32,.11][f]
    for j in range(43):
        a=j*math.tau/43
        r=2.36+.08*math.sin(j*7)
        h=height*(.55+.66*(.5+.5*math.sin(j*3.7)))
        # Wide irregular sheets, thick in section, torn crests, radial inward slant.
        pts=[polar(r-.55+.55*t,a+.045*math.sin(t*4+j),.07+h*math.sin(t*math.pi*.57)) for t in [k/10 for k in range(11)]]
        ob=ribbon('Raised torn water and silt crown',pts,.16+.04*math.sin(j*2),.055,wet if j%4 else mud,None)
        tube('Bright broken foam crest',[(x,y,z+.06) for x,y,z in pts[7:]],.035,foam if j%3 else jade)
        if f<3:
            p=polar(r-.08,a,h+.22*height)
            bead('Airborne stretched jade droplet',p,(.045,.045,.09*height+.02),jade if j%4 else foam)
    for j in range(17):
        a=j*2.39996;r=.35+1.30*((j*.618)%1)
        p=polar(r,a,.13+.20*height)
        ob=bead('Uplifted fractured peat slab',p,(.23,.32,.10+.10*height),mud)
        ob.rotation_euler=(.17*math.sin(j),.33*height,a)
        pts=[polar(r+.23*t,a+.1*math.sin(t*6+j),.13+.025*height) for t in [k/9 for k in range(10)]]
        tube('Fracture shadow',pts,.045,dark)
        tube('Wet jade in impact fracture',[(x,y,z+.015) for x,y,z in pts[:6]],.018,jade)
    # Foreground splashes visibly rise above the ground silhouette.
    for j in range(9):
        a=math.pi+(.2+j*.34);r=1.65+.4*math.sin(j*7)**2
        pts=[polar(r+.25*t,a+.10*t,.1+height*.8*math.sin(t*math.pi*.68)) for t in [k/10 for k in range(11)]]
        ribbon('Foreground torn mud splash',pts,.12,.045,wet,None)
        tube('Foreground luminous splash edge',[(x,y,z+.05) for x,y,z in pts[6:]],.026,jade)

def render():
    import bpy, iso_rig, cel_style as cel
    from mathutils import Vector
    global ribbon
    tree=ast.parse((ROOT/'art/tools/night/ra2_build.py').read_text(encoding='utf-8-sig'))
    node=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='ribbon')
    ns={'Vector':Vector,'math':math,'mesh':mesh}
    exec(compile(ast.Module(body=[node],type_ignores=[]),'ra2_ribbon','exec'),ns);ribbon=ns['ribbon']
    for key,(cell,n,limit) in SPECS.items():
        src=ROOT/('art/blender/characters/rainette_'+key+'.blend')
        copy=WORK/(f'rainette_{key}_vfx_b_{time.time_ns()}.blend')
        if src.exists():shutil.copy2(src,copy)
        for f in range(n):
            scene=iso_rig.create_rig('CREA',cell)
            scene.camera.data.ortho_scale=cell/64
            scene.render.resolution_percentage=100
            mats=[mat('Olive silt','677047'),mat('Deep viscous water','304B3F'),mat('Vocal jade #8DBBA8','8DBBA8',1.15),mat('Pale splash foam','D3DFBA',.8),mat('Deep peat fissures','172B28')]
            surface(key,f,mats)
            if key=='land_ring':crown(f,mats)
            path=OUT/(key+f'_{f}.png')
            cel.install('vfx',normals=False)
            iso_rig.common.configure_passes(path)
            scene.eevee.taa_render_samples=8
            scene.render.filepath=str(path)
            if f==0:
                # A new working file, never a source overwrite.
                scene.render.filepath=str(path)
                bpy.context.preferences.filepaths.save_version=0
                target=WORK/(f'rainette_{key}_built_{time.time_ns()}.blend')
                bpy.ops.wm.save_as_mainfile(filepath=str(target))
            bpy.ops.render.render(write_still=True)
            ep=list(OUT.glob(path.stem+'_e__*.png'));assert len(ep)==1,ep
            ep[0].replace(OUT/(path.stem+'_e.png'))
            assert not list(OUT.glob('*_n*.png'))

def assemble():
    for key,(cell,n,limit) in SPECS.items():
        for suffix in ('','_e'):
            step=cell if not suffix else cell//2
            sheet=Image.new('RGBA',(step*n,step))
            for f in range(n):
                im=Image.open(OUT/(key+f'_{f}'+suffix+'.png')).convert('RGBA')
                im=im.resize((step,step),Image.Resampling.LANCZOS)
                if suffix:
                    a=im.getchannel('A');lum=im.convert('RGB').convert('L')
                    im.putalpha(ImageChops.multiply(a,lum.point(lambda v:255 if v>8 else 0)))
                sheet.paste(im,(f*step,0))
            sheet.quantize(colors=64 if not suffix else 32,method=Image.Quantize.FASTOCTREE).save(OUT/(key+suffix+'.png'),optimize=True)

def verify(deliver=False):
    base=json.loads((OUT/'baseline.json').read_text());report={}
    for key,(cell,n,limit) in SPECS.items():
        old=Image.open(OUT/('before_'+key+'.png')).convert('RGBA')
        # Ground radius is defined by horizontal alpha support; iso elevation compresses Y.
        old_width=max(old.crop((j*cell,0,(j+1)*cell,cell)).getchannel('A').getbbox()[2]-old.crop((j*cell,0,(j+1)*cell,cell)).getchannel('A').getbbox()[0] for j in range(n))
        for suffix in ('','_e'):
            p=OUT/(key+suffix+'.png');im=Image.open(p).convert('RGBA');step=cell if not suffix else cell//2
            assert im.size==(step*n,step),(p,im.size)
            budget=limit if not suffix else int(base['files'][p.name]['bytes']*1.3)
            assert p.stat().st_size<=budget,(p,p.stat().st_size,budget)
            hashes=[];boxes=[];masses=[]
            for j in range(n):
                fr=im.crop((j*step,0,(j+1)*step,step));a=fr.getchannel('A');box=a.getbbox();assert box
                assert box[0]>0 and box[1]>0 and box[2]<step and box[3]<step,(p,j,box)
                assert ImageStat.Stat(fr.convert('L'),a).extrema[0][1]>25
                assert ImageStat.Stat(fr.convert('L'),a).stddev[0]>8
                hashes.append(hashlib.sha256(fr.tobytes()).hexdigest());boxes.append(box);masses.append(sum(a.getdata())/255)
            assert len(set(hashes))==n,(p,'identical frames')
            if not suffix:
                width=max(b[2]-b[0] for b in boxes)
                assert abs(width-old_width)<=old_width*.04,(key,width,old_width)
            report[p.name]={'before':base['files'][p.name]['bytes'],'after':p.stat().st_size,'dimensions':im.size,'alpha_boxes':boxes,'alpha_mass':masses,'distinct':len(set(hashes))}
        if key=='goo':
            im=Image.open(OUT/'goo.png').convert('RGBA')
            frames=[im.crop((j*cell,0,(j+1)*cell,cell)) for j in range(n)]
            distances=[sum(ImageStat.Stat(ImageChops.difference(frames[j],frames[(j+1)%n])).mean) for j in range(n)]
            assert distances[-1] < max(distances[:-1])*1.6,distances
            report['goo_loop_delta']=distances
    for rel,digest in base['protected'].items():
        p=ROOT/rel;assert sha(p)==digest,p
        text=p.read_text();assert 'CanvasTexture' not in text and 'normal_texture' not in text,p
    added=outside_files()-set(base['outside']);assert not added,sorted(added)[:5]
    assert not list(OUT.glob('*_n*.png'))
    report['outside_new_files']=len(added)
    (OUT/'verification.json').write_text(json.dumps(report,indent=2))
    # One contact sheet, before and after assembled with Pillow; no drawing.
    board=Image.new('RGB',(1024,768),(58,62,70))
    for row,key in enumerate(SPECS):
        cell,n,_=SPECS[key]
        for j in range(n):
            for before,y in [(True,row*384),(False,row*384+160)]:
                p=OUT/(('before_' if before else '')+key+'.png')
                im=Image.open(p).convert('RGBA').crop((j*cell,0,(j+1)*cell,cell)).resize((160,160),Image.Resampling.LANCZOS)
                board.paste(im,(j*170,y),im)
    board.save(ROOT/'art/renders/feel_sorts2/after_vfx_rainette_b.png',optimize=True)
    if deliver:
        for key in SPECS:
            for suffix in ('','_e'):
                p=OUT/(key+suffix+'.png');dst=DEST/key/p.name
                assert sha(dst)==base['files'][p.name]['sha'],'Concurrent asset change: '+str(dst)
        for key in SPECS:
            for suffix in ('','_e'):
                p=OUT/(key+suffix+'.png');shutil.copy2(p,DEST/key/p.name)
    print('PASS Rainette VFX: 4 PNG; dimensions, budgets, alpha, contrast, distinct frames, footprint, loop, tres, outside paths',flush=True)

if __name__=='__main__':
    if '--prepare' in sys.argv:prepare();print('PASS baseline')
    elif '--verify' in sys.argv:verify('--deliver' in sys.argv)
    else:render();assemble();verify()
