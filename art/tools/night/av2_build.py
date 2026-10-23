"""AV2: sculpted water VFX, original CD portrait, AV1 PBR emblems.
No gameplay edits. --resume skips complete effects; --verify assembles one contact.
Wave: CREA 30 deg R=90.5097, 1024 cells, eight directions. Zones: native TOP 128 px/u.
"""
import sys, math, json, hashlib, random
from pathlib import Path
sys.dont_write_bytecode=True
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/characters'),str(ROOT/'art/tools/iso')]
import av1_build as av1
import iso_rig
from ardent_iso_build import worn, mesh, bead, empty
from cd_cd1_common import tube, rgb
from PIL import Image
DEST=av1.DEST
SRC=ROOT/'art/blender/characters'
WORK=SRC/'averse_av2_frames'
SPECS={'wave_cone':('CREA',1024,6,8,False),'puddle_mirror':('TOP',768,6,1,True),'crue_ring':('TOP',1664,8,1,False),'goutte_lame':('CREA',128,4,1,True)}

def materials():
    water=worn('AV2 black rainwater wet relief','08191E','29454D',.32,.21)
    p=water.node_tree.nodes.get('Principled BSDF');p.inputs['Coat Weight'].default_value=.65;p.inputs['Coat Roughness'].default_value=.13
    foam=worn('AV2 sediment silver foam','253D41','779397',.22,.38)
    cyan=worn('AV2 cyan refracted water veins','17414C','5FD4E8',.4,.24)
    p=cyan.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=rgb('5FD4E8');p.inputs['Emission Strength'].default_value=.75
    return water,foam,cyan

def crest(root,radius,start,end,height,water,foam,cyan,phase=0):
    # Rolled continuous sheet with an undercut lip; asymmetry is modelled, never drawn.
    count=max(36,int((end-start)*radius*20));verts=[]
    for j in range(count+1):
        a=start+(end-start)*j/count
        wob=.024*math.sin(a*19+phase)+.014*math.sin(a*37-phase)
        for k in range(7):
            t=k/6;rr=radius-.20+.30*t+.09*math.sin(t*math.pi)
            z=.025+height*(math.sin(t*math.pi*.73)**1.25)*(1+.17*math.sin(a*11+phase))
            verts.append(((rr+wob)*math.cos(a),(rr+wob)*math.sin(a),z))
    faces=[(j*7+k,(j+1)*7+k,(j+1)*7+k+1,j*7+k+1) for j in range(count) for k in range(6)]
    ob=mesh('Undercut rainwater crest',verts,faces,water,root)
    for p in ob.data.polygons:p.use_smooth=True
    sol=ob.modifiers.new('Water sheet thickness','SOLIDIFY');sol.thickness=.018
    for band in range(2):
        pts=[]
        for j in range(count+1):
            a=start+(end-start)*j/count;rr=radius+.07+band*.035+.025*math.sin(a*19+phase)
            z=.025+height*(.91-band*.15)*(1+.17*math.sin(a*11+phase))
            pts.append((rr*math.cos(a),rr*math.sin(a),z))
        tube('Broken cyan caustic' if band==0 else 'Silt foam crest',pts,.012 if band==0 else .021,cyan if band==0 else foam,root)
    rng=random.Random(int(radius*1000)+43)
    for j in range(max(8,int((end-start)*radius*6))):
        a=rng.uniform(start,end);rr=radius+rng.uniform(.08,.33);z=height*rng.uniform(.9,1.5)+.05
        ob=bead('Sharp thrown rain splinter',(rr*math.cos(a),rr*math.sin(a),z),(.018,.018,rng.uniform(.04,.10)),foam if j%3 else cyan,root)
        ob.rotation_euler=(.25*math.sin(a),.3*math.cos(a),a)

def geometry(key,f,n,mats):
    water,foam,cyan=mats;t=f/(n-1);phase=f*math.tau/n;r=empty(key+' frame '+str(f))
    if key=='wave_cone':
        rad=.72+3.98*t;h=.25+.55*math.sin(math.pi*(.12+.78*t))
        # Model faces south like the character; direction e is obtained by the CREA rotation.
        for lane in range(2):crest(r,rad-lane*.28,-math.pi/2-.53,-math.pi/2+.53,h*(1-lane*.55),water,foam,cyan,phase+lane)
        for j in range(9):
            a=-math.pi/2-.48+j*.12
            tube('Dragged water wake',[(q*rad*math.cos(a),q*rad*math.sin(a),.023+.012*math.sin(q*12+phase)) for q in (.18,.28,.4,.55,.7,.85)],.014,water,r)
    elif key=='puddle_mirror':
        seg=128;verts=[(0,0,.018)]
        for j in range(seg):
            a=j*math.tau/seg;rad=2.28+.09*math.sin(a*7)+.055*math.sin(a*13+phase)*.35
            verts.append((rad*math.cos(a),rad*math.sin(a),.018+.007*math.sin(a*9+phase)))
        ob=mesh('Black mirror puddle',verts,[(0,1+j,1+(j+1)%seg) for j in range(seg)],water,r)
        for k in range(3):
            rad=.48+k*.69+.035*math.sin(phase+k)
            pts=[((rad+.014*math.sin(a*9+phase))*math.cos(a),(rad+.014*math.sin(a*9+phase))*math.sin(a),.027+.004*math.sin(a*6+phase)) for a in [j*math.tau/128 for j in range(129)]]
            tube('Mirror ripple reflected cyan' if k==2 else 'Mirror raised meniscus',pts,.010 if k==2 else .017,cyan if k==2 else foam,r)
        for k in range(7):
            a=k*.9+.2;pts=[((2.22+.03*math.sin(j))*math.cos(a+j*.03),(2.22+.03*math.sin(j))*math.sin(a+j*.03),.028) for j in range(14)]
            tube('Broken reflective bank',pts,.023,water,r)
    elif key=='crue_ring':
        rad=.62+5.13*t;h=.08+.40*math.sin(math.pi*(.12+t*.84))
        for k in range(7):
            a=k*math.tau/7+.015*math.sin(phase+k)
            crest(r,rad,a,a+math.tau/7-.035,h*(.8+.2*math.sin(k+phase)),water,foam,cyan,phase+k)
        if f>1:
            rad2=rad*.72
            tube('Inner receding flood reflection',[(rad2*math.cos(a),rad2*math.sin(a),.018) for a in [j*math.tau/192 for j in range(193)]],.015,water,r)
    else:
        # Razor drop: asymmetric liquid blade and torn trailing filaments, points to screen east.
        pts=[(.49,0,.09),(-.12,-.11,.09),(-.42,-.045,.09),(-.30,0,.16),(-.42,.045,.09),(-.12,.11,.09),(0,0,.20)]
        ob=mesh('Forged liquid razor',pts,[(j,(j+1)%6,6) for j in range(6)],water,r,.009)
        tube('Cyan cutting ridge',[(-.32,0,.16),(0,0,.20),(.45,0,.105)],.014,cyan,r)
        for j in range(3):
            tube('Shredded rain trail',[(-.59-.025*math.sin(phase+j),-.065+j*.065,.06),(-.38,-.04+j*.04,.10),(-.20,0,.13)],.012,foam if j%2 else water,r)
    return r

def resource(key,cell,n,dirs,loop):
    base='res://assets/sprites/characters/averse/effects/'+key
    folder=DEST/'effects'/key;lines=[];anims=[]
    for em in (False,True):
        ext=f'[ext_resource type="Texture2D" path="{base}/{key}{"_e" if em else ""}.png" id="1"]\n'
        subs=[]
        if not em:
            ext+=f'[ext_resource type="Texture2D" path="{base}/{key}_n.png" id="2"]\n'
            subs.append('[sub_resource type="CanvasTexture" id="ct"]\ndiffuse_texture = ExtResource("1")\nnormal_texture = ExtResource("2")')
        anims=[]
        for row,d in enumerate(dirs):
            frames=[]
            for f in range(n):
                ident=f'a{row}_{f}';atlas='ExtResource("1")' if em else 'SubResource("ct")'
                subs.append(f'[sub_resource type="AtlasTexture" id="{ident}"]\natlas = {atlas}\nregion = Rect2({f*cell}, {row*cell}, {cell}, {cell})')
                frames.append('{"duration": 1.0, "texture": SubResource("'+ident+'")}')
            name=key+'_'+d if len(dirs)>1 else 'default'
            anims.append('{"frames": ['+', '.join(frames)+f'], "loop": {str(loop).lower()}, "name": &"{name}", "speed": 12.0'+'}')
        path=folder/(key+('_emission' if em else '')+'.tres')
        if not path.exists():path.write_text('[gd_resource type="SpriteFrames" format=3]\n'+ext+'\n\n'+'\n\n'.join(subs)+'\n\n[resource]\nanimations = ['+',\n'.join(anims)+']\n')

def effects():
    for key,(rig,cell,n,nd,loop) in SPECS.items():
        folder=DEST/'effects'/key;folder.mkdir(parents=True,exist_ok=True)
        if '--resume' in sys.argv and not (key=='goutte_lame' and '--refresh-projectile' in sys.argv) and all((folder/(key+su+'.png')).exists() for su in ('','_n','_e')):continue
        s=iso_rig.create_rig(rig,cell);s.eevee.taa_render_samples=12
        s.render.threads_mode='FIXED';s.render.threads=8
        mats=materials();basis=s.camera.rotation_euler.to_matrix();ppu=128 if rig=='TOP' else iso_rig.R
        dirs=list(iso_rig.DIRECTIONS) if nd==8 else ['e' if key=='goutte_lame' else 'default']
        atlases={su:Image.new('RGBA',(cell*n,cell*nd)) for su in ('','_n','_e')}
        for f in range(n):
            r=geometry(key,f,n,mats)
            iso_rig.bake_ao_shadows(r)
            if f==n//2:
                s['AV2_effect']=key;s['AV2_frames']=n;s['AV2_native_px_per_u']=ppu;s['AV2_direction_order']=','.join(dirs)
                s['AV2_contact_frame']=f;s['AV2_pivot']=[cell/2,cell/2]
                bpy.context.preferences.filepaths.save_version=0
                bpy.ops.wm.save_as_mainfile(filepath=str(SRC/('averse_'+key+'.blend')))
            for row,d in enumerate(dirs):
                r.rotation_euler.z=iso_rig.DIRECTIONS[d] if nd==8 else 0
                path=WORK/key/(d+'_'+str(f)+'.png')
                # Native-resolution Eevee, 12 samples; preserve exact rig projection.
                iso_rig.set_frame(cell,rig);s.render.resolution_percentage=50
                iso_rig.render_frame(path)
                for su in atlases:
                    p=path.with_name(path.stem+su+'.png')
                    assert p.exists(),(key,f,su)
                    with Image.open(p) as im:atlases[su].alpha_composite(im.convert('RGBA'),(f*cell,row*cell))
            for ob in [*r.children_recursive,r]:bpy.data.objects.remove(ob,do_unlink=True)
        for su,im in atlases.items():im.save(folder/(key+su+'.png'),optimize=True,compress_level=9)
        resource(key,cell,n,dirs,loop)
        print('AV2 EFFECT PASS '+key,flush=True)

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
    board=Image.new('RGBA',(1840,1960),(19,24,28,255));result={}
    for anim,n in av1.ANIMS.items():
        for su in ('','_n','_e'):
            with Image.open(DEST/(anim+su+'.png')) as im:assert im.size==(192*n,1536),(anim,su,im.size)
    for row,(key,(rig,cell,n,nd,loop)) in enumerate(SPECS.items()):
        folder=DEST/'effects'/key
        hashes=[]
        for su in ('','_n','_e'):
            with Image.open(folder/(key+su+'.png')) as raw:
                assert raw.size==(cell*n,cell*nd),(key,su,raw.size)
                for d in range(nd):
                    unique=[]
                    for f in range(n):
                        tile=raw.crop((f*cell,d*cell,(f+1)*cell,(d+1)*cell));bb=tile.getchannel('A').getbbox()
                        assert bb and min(bb[:2])>=3 and max(bb[2:])<=cell-3,(key,d,f,bb)
                        unique.append(hashlib.sha256(tile.tobytes()).hexdigest())
                        if not su and d==0:
                            tile.thumbnail((220,220),Image.Resampling.LANCZOS);board.alpha_composite(tile,(f*230,row*230))
                    assert len(set(unique))==n,(key,d,su,'duplicate')
        result[key]={'rig':rig,'cell':cell,'frames':n,'directions':nd,'pivot':[cell/2,cell/2],'px_per_u':128 if rig=='TOP' else iso_rig.R,'loop':loop}
    portrait=Image.open(DEST/'portrait.png').convert('RGBA');assert portrait.size==(256,256);board.alpha_composite(portrait,(1248,680))
    frame=Image.open(ROOT/'game/assets/sprites/ui/spell_frame.png').convert('RGBA')
    keys=['averse_goutte_lame','averse_vague','averse_flaque_miroir','averse_crue','eclat_de_braise','nova_ardente','cendres','brasier']
    for j,key in enumerate(keys):
        path=av1.ICONS/(key+'.png')
        if not path.exists():continue
        im=Image.open(path).convert('RGBA');assert im.size==(128,128),(key,im.size)
        for size,y in [(128,940),(64,1080)]:
            tile=im.resize((size,size),Image.Resampling.LANCZOS);tile.alpha_composite(frame.resize((size,size),Image.Resampling.LANCZOS));board.alpha_composite(tile,(j*192+(192-size)//2,y))
    refs=['art/tools/characters/_cd_averse.png','art/tools/ui/_i2_contact.png','art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png']
    for j,ref in enumerate(refs):
        im=Image.open(ROOT/ref).convert('RGBA');im.thumbnail((300,280),Image.Resampling.LANCZOS);board.alpha_composite(im,(j*305,1160))
    for row,su in enumerate(('','_n','_e')):
        with Image.open(DEST/'effects/wave_cone'/('wave_cone'+su+'.png')) as im:
            for d in range(8):
                tile=im.crop((3072,d*1024,4096,(d+1)*1024));tile.thumbnail((155,155),Image.Resampling.LANCZOS)
                board.alpha_composite(tile,(d*192,1470+row*160))
    board.save(ROOT/'art/tools/night/_av2_contact.png',optimize=True)
    result['portrait']='portrait.png, 256px, original AV1 geometry';result['icons']='AV1 four bevelled bronze emblems, 128px; shared studio / cyan water';result['integration']='CREA cone eight rows e,se,s,sw,w,nw,n,ne; TOP zones centered; projectile points east; animate at 12fps; TOP projected by game ground transform'
    (DEST/'av2_manifest.json').write_text(json.dumps(result,indent=2))
    prior=json.loads((DEST/'averse_manifest.json').read_text());prior['lot_2_remaining']=[];prior['lot_2_manifest']='av2_manifest.json'
    (DEST/'averse_manifest.json').write_text(json.dumps(prior,indent=2))
    print('AV2 VERIFY PASS: 66 VFX frames, diffuse/normal/emission, portrait, four icons',flush=True)

if __name__=='__main__':
    WORK.mkdir(parents=True,exist_ok=True)
    if '--verify' in sys.argv:verify()
    else:
        effects();portrait()
        if '--keep-icons' not in sys.argv:av1.icons()
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
