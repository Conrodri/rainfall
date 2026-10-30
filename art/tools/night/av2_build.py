"""AV2 water cel: three spells; existing atlas packing/resources preserved. --resume-render reuses final cells."""
import sys, math, json, hashlib, random, warnings
warnings.filterwarnings("ignore",category=DeprecationWarning)
from pathlib import Path
sys.dont_write_bytecode=True
import bpy
import re, inspect, textwrap, subprocess, shutil
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/characters'),str(ROOT/'art/tools/iso')]
import av1_build as av1
import iso_rig
sys.path.insert(0,str(ROOT/'art/tools/cel'))
import cel_style as cel
from ardent_iso_build import worn, mesh, bead, empty
from cd_cd1_common import tube, rgb
from PIL import Image
DEST=av1.DEST
SRC=ROOT/'art/blender/characters'
WORK=SRC/'averse_av2_water_final'
SPECS={'wave_cone':('CREA',1024,6,8,False),'puddle_mirror':('TOP',768,6,1,True),'crue_ring':('TOP',1664,8,1,False),'goutte_lame':('CREA',128,4,1,True)}

def materials():
    def solid(name,color):
        mat=bpy.data.materials.new(name);mat.use_nodes=True
        bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=rgb(color)
        bsdf.inputs['Roughness'].default_value=.30
        return mat
    water=solid('AV2 dark slate water cel','294D59')
    foam=solid('AV2 pale silver white foam cel','BCD0D0')
    cyan=solid('AV2 cyan refracted veins','5FD4E8')
    p=cyan.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=rgb('5FD4E8');p.inputs['Emission Strength'].default_value=.75
    return water,foam,cyan

def crest(root,radius,start,end,height,water,foam,cyan,phase=0):
    count=max(32,int((end-start)*radius*18)); verts=[]; rings=13
    def point(a,t):
        roll=t*math.pi*1.42
        wav=.085*math.sin(a*17+phase)+.048*math.sin(a*31-phase)
        rr=radius-.22+.34*math.sin(roll)+wav
        z=.025+height*(1-math.cos(roll))*.52*(1+.19*math.sin(a*11+phase))
        return (rr*math.cos(a),rr*math.sin(a),z)
    for j in range(count+1):
        a=start+(end-start)*j/count
        for k in range(rings):verts.append(point(a,k/(rings-1)))
    ob=mesh('Hollow breaking water wall',verts,[(j*rings+k,(j+1)*rings+k,(j+1)*rings+k+1,j*rings+k+1) for j in range(count) for k in range(rings-1)],water,root)
    sol=ob.modifiers.new('Liquid thickness','SOLIDIFY');sol.thickness=.025
    for j in range(count):
        a=start+(end-start)*j/count
        if j%5!=4:
            pts=[point(a+(end-start)/count*q,.80+.04*math.sin(j+phase)) for q in (0,.35,.7,1.05)]
            tube('Torn white foam lip',pts,.043+.018*(1+math.sin(j*2)),foam,root)
            if j%3==0:bead('Churning foam tuft',point(a,.82),(.065,.08,.045),foam,root)
        if j%6==0:
            tube('Cyan falling water vein',[point(a,q) for q in (.15,.3,.5,.68)],.013,cyan,root)
    if root.get('peak'):
        for band in (.33,.57):
            for arc in range(4):
                aa=start+(end-start)*arc/4;bb=aa+(end-start)*.21
                tube('Initial breaking cyan caustic',[point(aa+(bb-aa)*j/18,band) for j in range(19)],.023,cyan,root)
    rng=random.Random(43+int(radius*1000))
    for j in range(max(14,int((end-start)*radius*12))):
        a=rng.uniform(start,end);rr=radius+rng.uniform(-.15,.23);z=height*rng.uniform(.75,1.6)+.05
        ob=bead('Thrown spray droplet',(rr*math.cos(a),rr*math.sin(a),z),(.028+rng.random()*.034,.032,rng.uniform(.05,.14)),foam if j%3 else cyan,root)
        ob.rotation_euler=(.5*math.sin(a),.5*math.cos(a),a)

def geometry(key,f,n,mats):
    water,foam,cyan=mats;t=f/(n-1);phase=f*math.tau/n;r=empty(key+' frame '+str(f));r['peak']=f==0
    if key=='wave_cone':
        rad=1.4+3.15*t;h=1.30*(1-.68*t)
        crest(r,rad,-math.pi/2-.53,-math.pi/2+.53,h,water,foam,cyan,phase)
        for j in range(7):
            a=-math.pi/2-.47+j*.157
            pts=[(q*rad*math.cos(a+.035*math.sin(q*15+phase)),q*rad*math.sin(a+.035*math.sin(q*15+phase)),.04+.035*math.sin(q*10+phase)**2) for q in (.28,.4,.55,.7,.85)]
            tube('Broken turbulent wake',pts,.035,foam if j%3==0 else water,r)
    elif key=='puddle_mirror':
        seg=144;verts=[(0,0,.018)]
        for j in range(seg):
            a=j*math.tau/seg;rad=2.15+.12*math.sin(a*7)+.07*math.sin(a*13+phase)+.035*math.sin(a*29)
            verts.append((rad*math.cos(a),rad*math.sin(a),.02+.012*math.sin(a*9+phase)))
        mesh('Irregular dark mirror water',verts,[(0,1+j,1+(j+1)%seg) for j in range(seg)],water,r)
        for k in range(4):
            rad=.25+((k*.46+t*.45)%1.85)
            for arc in range(3):
                pts=[]
                for j in range(36):
                    a=arc*math.tau/3+j*.047;rr=rad+.035*math.sin(a*8+phase)
                    pts.append((rr*math.cos(a),rr*math.sin(a),.045+.015*math.sin(a*7+phase)))
                tube('Pulsing broken concentric reflection',pts,.014 if k%2 else .021,cyan if k%2 else foam,r)
        for j in range(18):
            a=j*2.399;rr=.5+(j%5)*.31;z=.10+.24*(.5+.5*math.sin(phase+j))
            bead('Jumping mirror water',(rr*math.cos(a),rr*math.sin(a),z),(.025,.035,.055),cyan if j%3==0 else foam,r)
        for j in range(7):
            a=j*.87;rr=1.2+.4*math.sin(j)
            tube('Jagged reflected sky',[(rr*math.cos(a)+q,rr*math.sin(a)+.04*math.sin(q*30+phase),.04) for q in (-.18,-.09,0,.08,.15)],.025,foam,r)
    elif key=='crue_ring':
        rad=2.0+3.45*t;h=1.65*(1-.78*t)
        if f<3:
            verts=[(0,0,h*.80)];seg=72;bands=9
            for ring in range(1,bands+1):
                q=ring/bands
                for j in range(seg):
                    a=j*math.tau/seg;rr=rad*q*(.95+.025*math.sin(a*9+phase))
                    verts.append((rr*math.cos(a),rr*math.sin(a),.04+h*.80*math.sqrt(max(0,1-q*q))*(1-.20*f)))
            faces=[(0,1+j,1+(j+1)%seg) for j in range(seg)]
            faces += [(1+ring*seg+j,1+ring*seg+(j+1)%seg,1+(ring+1)*seg+(j+1)%seg,1+(ring+1)*seg+j) for ring in range(bands-1) for j in range(seg)]
            mesh('Rising flood dome collapsing',verts,faces,water,r)
        for k in range(9):
            a=k*math.tau/9
            crest(r,rad,a,a+math.tau/9-.045,h*(.84+.16*math.sin(k+phase)),water,foam,cyan,phase+k)
        for k in range(17):
            a=k*2.399+.12*math.sin(phase);rr=rad*(.50+.38*(k%4)/3)
            pts=[((rr+q)*math.cos(a+.07*math.sin(q*5+phase)),(rr+q)*math.sin(a+.07*math.sin(q*5+phase)),.04+.10*math.sin(q*3+phase)**2) for q in (-.35,-.16,0,.16,.3)]
            tube('Crashing spiral flood current',pts,.035,foam if k%3==0 else water,r)
            ob=bead('Flood carried dark debris',(rr*math.cos(a),rr*math.sin(a),.13+.15*math.sin(phase+k)**2),(.09,.035,.045),water,r);ob.rotation_euler.z=a+phase
    else:
        # Razor drop: asymmetric liquid blade and torn trailing filaments, points to screen east.
        pts=[(.49,0,.09),(-.12,-.11,.09),(-.42,-.045,.09),(-.30,0,.16),(-.42,.045,.09),(-.12,.11,.09),(0,0,.20)]
        ob=mesh('Forged liquid razor',pts,[(j,(j+1)%6,6) for j in range(6)],water,r,.009)
        tube('Cyan cutting ridge',[(-.32,0,.16),(0,0,.20),(.45,0,.105)],.014,cyan,r)
        for j in range(3):
            tube('Shredded rain trail',[(-.59-.025*math.sin(phase+j),-.065+j*.065,.06),(-.38,-.04+j*.04,.10),(-.20,0,.13)],.012,foam if j%2 else water,r)
    return r

def resource(key,cell,n,dirs,loop):
    # Delivered packed resources are authoritative: retain regions, margins and fps.
    for suffix in ('','_emission'):
        data=(DEST/'effects'/key/(key+suffix+'.tres')).read_text()
        assert 'CanvasTexture' not in data and 'normal_texture' not in data
        assert len(re.findall(r'region = Rect2',data))==n*len(dirs)


def effects():
    # Keep the delivered atlas layout and SpriteFrames byte for byte.
    src=textwrap.dedent(inspect.getsource(iso_rig.render_frame)).replace("('_n','_e')","('_e',)")
    exec(compile(src,'<av2-no-normals>','exec'),iso_rig.__dict__)
    baseline={}; report={}; board=Image.new('RGBA',(960,576),(19,24,28,255))
    for line,key in enumerate(('wave_cone','puddle_mirror','crue_ring')):
        folder=DEST/'effects'/key;res=(folder/(key+'.tres')).read_text()
        ext={i:folder/Path(path).name for path,i in re.findall(r'\[ext_resource[^\n]*path="([^"]+)" id="([^"]+)"',res)}
        blocks=re.findall(r'\[sub_resource type="AtlasTexture"[^\]]*\]([^\[]+)',res)
        cells=[]
        for block in blocks:
            aid=re.search(r'ExtResource\("([^"]+)"\)',block)[1]
            rect=tuple(map(int,re.search(r'region = Rect2\(([^)]+)\)',block)[1].split(',')))
            margin=re.search(r'margin = Rect2\(([^)]+)\)',block)
            cells.append((ext[aid],rect,tuple(map(int,margin[1].split(','))) if margin else (0,0,0,0)))
        paths=set(ext.values()); baseline[key]=sum(meta['bytes'] for rel,meta in json.loads((ROOT/'art/blender/av2_baseline.json').read_text()).items() if Path(rel).parts[0]==key and rel.endswith('.png'))
        atlases={p:Image.new('RGBA',Image.open(p).size) for p in paths}; emiss={p:Image.new('RGBA',Image.open(p).size) for p in paths}
        rig,_,n,nd,loop=SPECS[key];cell=1024 if key=='wave_cone' else cells[0][1][2]
        s=iso_rig.create_rig(rig,cell);s.eevee.taa_render_samples=8;s.render.threads_mode='FIXED';s.render.threads=8
        if rig=='TOP':s.camera.data.ortho_scale=cell/65.5
        mats=materials();mats[2]['rainfall_emissive']=True
        cel.install('prop',normals=False)
        dirs=list(iso_rig.DIRECTIONS) if nd==8 else ['default']
        resource(key,cell,n,dirs,loop)
        for f in range(n):
            strength=1.5*(1-.94*f/(n-1))**2
            for node in mats[2].node_tree.nodes:
                if node.type=='BSDF_PRINCIPLED':node.inputs['Emission Strength'].default_value=strength
                elif node.type=='EMISSION':node.inputs['Strength'].default_value=strength
                elif node.type=='OUTPUT_AOV':node.inputs['Color'].default_value=tuple(c*strength for c in rgb('5FD4E8')[:3])+(1,)
            root=geometry(key,f,n,mats)
            for row,d in enumerate(dirs):
                root.rotation_euler.z=iso_rig.DIRECTIONS[d] if nd==8 else 0
                p,rect,margin=cells[row*n+f];x,y,w,h=rect
                path=WORK/key/(d+'_'+str(f)+'.png')
                iso_rig.set_frame(cell,rig)
                if rig=='TOP':s.camera.data.ortho_scale=cell/65.5
                s.render.resolution_percentage=100
                if not ('--resume-render' in sys.argv and path.exists() and path.with_name(path.stem+'_e.png').exists() and Image.open(path).size==(cell,cell) and not ('--refresh-peak' in sys.argv and f==0 and key!='puddle_mirror')):iso_rig.render_frame(path)
                for suffix,target in (('',atlases),('_e',emiss)):
                    im=Image.open(path.with_name(path.stem+suffix+'.png')).convert('RGBA')
                    box=(margin[0],margin[1],margin[0]+w,margin[1]+h)
                    tile=im.crop(box)
                    assert tile.getchannel('A').getbbox(),(key,f,row,'empty')
                    # Assert the established crop still contains the water silhouette.
                    full=im.getchannel('A').getbbox()
                    assert full[0]>=box[0] and full[1]>=box[1] and full[2]<=box[2] and full[3]<=box[3],(key,f,row,full,box)
                    target[p].alpha_composite(tile,(x,y))
                    if not suffix and row==0 and f in (0,n//2,n-1):
                        tile.thumbnail((300,180),Image.Resampling.LANCZOS);board.alpha_composite(tile,((0 if f==0 else 320 if f==n//2 else 640)+(300-tile.width)//2,line*192))
                if f==0 and row==0:
                    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(SRC/('averse_'+key+'.blend')))
            for ob in [*root.children_recursive,root]:bpy.data.objects.remove(ob,do_unlink=True)
        for p,im in atlases.items():
            im.save(p,optimize=True,compress_level=9)
            optimized=WORK/('optimized_'+p.name)
            filters="lutrgb=r='floor(val/16+0.5)*16':g='floor(val/16+0.5)*16':b='floor(val/16+0.5)*16':a='floor(val/32+0.5)*32'"
            with (WORK/'compression.log').open('a') as log:
                subprocess.run([shutil.which('ffmpeg'),'-v','error','-y','-i',str(p),'-vf',filters,'-frames:v','1','-compression_level','9',str(optimized)],stdout=log,stderr=log,check=True)
            optimized.replace(p)
            e=emiss[p].resize(((im.width+1)//2,(im.height+1)//2),Image.Resampling.LANCZOS)
            assert max(e.convert('RGB').getextrema()[i][1] for i in range(3))>8
            ep=p.with_name(p.stem+'_e.png');e.save(ep,optimize=True,compress_level=9)
            ef="lutrgb=r='floor(val/32+0.5)*32':g='floor(val/32+0.5)*32':b='floor(val/32+0.5)*32':a='floor(val/64+0.5)*64'"
            with (WORK/'compression.log').open('a') as log:
                subprocess.run([shutil.which('ffmpeg'),'-v','error','-y','-i',str(ep),'-vf',ef,'-frames:v','1','-compression_level','9',str(optimized)],stdout=log,stderr=log,check=True)
            optimized.replace(ep)
        after=sum(p.stat().st_size+p.with_name(p.stem+'_e.png').stat().st_size for p in paths)
        report[key]={'before':baseline[key],'after':after,'frames':n,'rows':nd,'sizes':{p.name:list(im.size) for p,im in atlases.items()}}
        assert after<=baseline[key]*1.30,(key,'budget',after,baseline[key])
        cel.uninstall()
    board.save(WORK/'control.png',optimize=True)
    (WORK/'report.json').write_text(json.dumps(report,indent=2))

def portrait():
    bpy.ops.wm.open_mainfile(filepath=str(av1.SOURCE));s=bpy.context.scene;s.frame_set(1)
    root=bpy.data.objects['Averse'];root.rotation_euler.z=-.30
    cam=s.camera;cam.data.shift_y=0;cam.data.ortho_scale=1.02
    target=Vector((0,-.03,1.39));cam.rotation_euler=(math.radians(75),0,0);cam.location=target+cam.rotation_euler.to_matrix()@Vector((0,0,12))
    s['iso_frame']=[256,256];s.render.resolution_x=s.render.resolution_y=512;s.render.resolution_percentage=100
    s.eevee.taa_render_samples=16
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'averse_portrait.blend'))
    iso_rig.render_frame(DEST/'portrait.png',passes=True)
    print('AV2 PORTRAIT PASS',flush=True)

def verify():
    import runpy
    runpy.run_path(str(ROOT/'art/blender/av2_check.py'),run_name='__main__')

if __name__=='__main__':
    WORK.mkdir(parents=True,exist_ok=True)
    if '--verify' in sys.argv:verify()
    else:
        effects()
        verify()

def godot_verify():
    import subprocess
    godot=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
    resources=[p for p in DEST.rglob('*.tres')]
    paths=['res://'+p.relative_to(ROOT/'game').as_posix() for p in resources]
    code='''extends SceneTree
func _initialize():
    var paths = %s
    var total = 0
    for path in paths:
        var sf = load(path)
        assert(sf is SpriteFrames, path)
        for anim in sf.get_animation_names():
            assert(sf.get_frame_count(anim) > 0)
            for i in range(sf.get_frame_count(anim)):
                var tex = sf.get_frame_texture(anim, i)
                assert(tex is AtlasTexture, path)
                assert(tex.atlas != null)
                if not path.ends_with("_emission.tres"):
                    assert(tex.atlas is CanvasTexture, path)
                    assert(tex.atlas.diffuse_texture != null and tex.atlas.normal_texture != null)
                total += 1
    print("AV2 RESOURCE RESULT: OK / ", paths.size(), " resources / ", total, " textures")
    quit()
'''%json.dumps(paths)
    check=SRC/'averse_resource_check.tres'
    check.write_text('[gd_resource type="GDScript" format=3]\n\n[resource]\nscript/source = '+json.dumps(code)+'\n',encoding='utf8')
    results={}
    for label,args in [('import',['--editor','--import','--quit']),('resources',['--script',str(check)]),('sprites',['res://tests/sprites_test.tscn'])]:
        p=subprocess.run([godot,'--headless','--path',str(ROOT/'game')]+args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf8',errors='replace',timeout=240)
        (SRC/('averse_av2_'+label+'.log')).write_text(p.stdout,encoding='utf8')
        errors=[line for line in p.stdout.splitlines() if 'ERROR:' in line or 'SCRIPT ERROR' in line]
        results[label]={'returncode':p.returncode,'errors':errors[:12]}
        if label=='resources':assert 'AV2 RESOURCE RESULT: OK' in p.stdout,p.stdout[-2000:]
        if label=='sprites':assert 'RESULT: OK' in p.stdout,p.stdout[-2000:]
        assert p.returncode==0,(label,p.returncode)
        if label!='import':assert not errors,(label,errors[:8])
        print('AV2 GODOT '+label+' PASS',flush=True)
    (DEST/'av2_godot_verification.json').write_text(json.dumps(results,indent=2))
