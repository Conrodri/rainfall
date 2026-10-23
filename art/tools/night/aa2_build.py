"""AA2 — Avare: minted gold, ransom seal, weapon sweep and portrait.
Background Blender only. --resume / --effects [--only=name] / --portrait / --verify.
Reuses AA1 geometry and icons; Pillow only assembles/resizes/checks renders.
"""
import sys, math, json, hashlib, random, subprocess, tempfile
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/night'))
import aa1_build as aa1
import bpy
from mathutils import Vector
from PIL import Image
iso=aa1.iso_rig; cd=aa1.cd
OUT=aa1.DEST; SRC=ROOT/'art/blender/characters'; RAW=SRC/'avare_aa2_frames'
# name: cell, frames, rows, rig, loop. CREA uses R=90.51; TOP uses 128 px/u.
SPECS={'coin_burst':(512,6,1,'CREA',False),
       'ransom_ring':(256,4,1,'TOP',False),
       'coin_projectile':(48,4,1,'CREA',True),
       'coin_pickup':(48,8,1,'CREA',True),
       'gold_bleed':(192,6,1,'CREA',False),
       'coffre_arc':(192,4,8,'CREA',False)}

def setup(rig,cell,feet_pivot=False):
    s=iso.create_rig(rig,cell);s.eevee.taa_render_samples=12
    if feet_pivot:s.camera.data.shift_y=.21
    s.render.threads_mode='FIXED';s.render.threads=8
    s.render.resolution_percentage=50;s.render.dither_intensity=0
    s.view_layers[0].use_pass_normal=True;s.view_layers[0].use_pass_emit=True
    global metal,iron,hot,stone
    metal=aa1.worn('AA2 worn struck monetary brass','483A22','B09A60',1,.34)
    iron=aa1.worn('AA2 blackened treasury iron','131719','51524A',1,.48)
    stone=aa1.worn('AA2 fractured wet terrace slate','111619','4B4B42',0,.88)
    hot=cd.emit('AA2 sole accent gold F2C14E','F2C14E',1.8)
    return s

def coin(root,p,scale=1,rot=(0,0,0),glow=True):
    c=cd.empty('Clipped hand struck coin');c.parent=root;c.location=p;c.rotation_euler=rot
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.095,depth=.023)
    o=bpy.context.object;o.name='Pitted brass flan';o.parent=c;o.location=(0,0,0);o.data.materials.append(metal)
    b=o.modifiers.new('Irregular worn bevel','BEVEL');b.width=.006;b.segments=2;o.modifiers.new('Weighted specular normals','WEIGHTED_NORMAL')
    for z in (-.013,.013):
        cd.torus('Raised milled rim',(0,0,z),.078,.004,metal,c)
        cd.tube('Embossed usurer mint mark',[(-.028,-.042,z),(0,.043,z),(.028,-.042,z)],.006,hot if glow else metal,c)
        cd.tube('Mint crossbar',[(-.020,-.014,z),(.020,-.014,z)],.004,metal,c)
    for j in range(8):
        a=j*math.tau/8;cd.cube('Rim notch',(.09*math.cos(a),.09*math.sin(a),0),(.012,.012,.025),iron,c,.002)
    c.scale=(scale,)*3
    return c

def arc(root,r,a,b,z,width,mat,phase=0):
    pts=[]
    for j in range(20):
        t=a+(b-a)*j/19;rr=r*(1+.012*math.sin(19*t+phase))
        pts.append((rr*math.cos(t),rr*math.sin(t),z+.006*math.sin(11*t)))
    cd.tube('Broken raised pressure seam',pts,width,mat,root)

def geometry(name,f,n):
    r=cd.empty('AA2 '+name);t=f/(n-1);rng=random.Random(904)
    if name in ('coin_projectile','coin_pickup'):
        if name=='coin_projectile':
            coin(r,(.08,0,0),1.25,(.6,f*math.tau/n,math.pi/2))
            for k in range(3):
                cd.tube('Gold shavings wake',[(-.21,-.04+k*.04,-.025),(-.10,-.025+k*.025,0),(-.02,0,.015)],.005,hot,r)
        else:
            coin(r,(0,0,.025),1.45,(math.pi/2,0,f*math.tau/n))
            arc(r,.16,.25,2.4,.001,.005,hot,f)
    elif name in ('coin_burst','gold_bleed'):
        big=name=='coin_burst';count=28 if big else 9
        radius=(.35+1.95*t) if big else (.10+.62*t)
        for j in range(count):
            a=j*math.tau/count+rng.uniform(-.15,.15);rr=radius*rng.uniform(.38,1)
            z=(.08+(.65 if big else .30)*math.sin(math.pi*(.06+.88*t)))*rng.uniform(.5,1)
            coin(r,(rr*math.cos(a),rr*math.sin(a),z),rng.uniform(.55,1.05),(t*7+j*.4,t*5+j*.7,a))
            if j%3==0:
                cd.tube('Thin precious metal splinter',[(rr*.72*math.cos(a),rr*.72*math.sin(a),z*.65),(rr*math.cos(a),rr*math.sin(a),z)],.006,hot,r)
        if big:
            for j in range(7):arc(r,radius*.83,j*math.tau/7+.05,j*math.tau/7+.44,.018,.009,hot,f)
    elif name=='ransom_ring':
        radius=.37+.52*t
        for j in range(12):
            a=j*math.tau/12
            arc(r,radius,a+.03,a+.41,.018,.014,iron,f)
            arc(r,radius*.97,a+.06,a+.36,.038,.008,hot,f)
            cd.cube('Ransom tally',(radius*.83*math.cos(a),radius*.83*math.sin(a),.028),(.018,.09,.028),metal,r,.004).rotation_euler.z=a-math.pi/2
        for j in range(7):
            a=j*math.tau/7;pts=[(.16*math.cos(a),.16*math.sin(a),.012),(.44*math.cos(a+.13),.44*math.sin(a+.13),.014),((radius+.025)*math.cos(a),(radius+.025)*math.sin(a),.012)]
            cd.tube('Impact fissure iron lip',pts,.018,stone,r);cd.tube('Gold in cracked slate',[(x,y,z+.014) for x,y,z in pts],.005,hot,r)
        coin(r,(0,0,.018),1.15,(0,0,.18))
    else:
        # Radial blade of forged links: local south, rotated by the official direction table.
        a=-math.pi/2-.85+t*1.7
        for k in range(3):arc(r,.64+k*.085,a-.55,a+.16,.14+k*.02,.006 if k else .013,hot if k<2 else iron,f)
        for j in range(8):
            q=a-.6+j*.10
            cd.torus('Trailing weapon chain',(.72*math.cos(q),.72*math.sin(q),.16),.027,.008,iron,r,(0,(j%2)*math.pi/2,q),(1.2,.8,1))
        for j in range(4):
            q=a-.35+j*.15;coin(r,(.78*math.cos(q),.78*math.sin(q),.12+j*.01),.48,(.5,j,q))
    return r

def resource(name):
    cell,n,rows,rig,loop=SPECS[name];folder=OUT/'effects'/name
    base='res://assets/sprites/characters/avare/effects/'+name+'/'+name
    for emission in (False,True):
        dest=folder/(name+('_emission' if emission else '')+'.tres')
        if dest.exists():continue
        lines=['[gd_resource type="SpriteFrames" format=3]',f'[ext_resource type="Texture2D" path="{base}{"_e" if emission else ""}.png" id="1"]']
        if not emission:lines += [f'[ext_resource type="Texture2D" path="{base}_n.png" id="2"]','[sub_resource type="CanvasTexture" id="ct"]\ndiffuse_texture = ExtResource("1")\nnormal_texture = ExtResource("2")']
        anims=[]
        for row,d in enumerate(list(iso.DIRECTIONS)[:rows]):
            frames=[]
            for f in range(n):
                ident=f'f{row}_{f}';atlas='ExtResource("1")' if emission else 'SubResource("ct")'
                lines.append(f'[sub_resource type="AtlasTexture" id="{ident}"]\natlas = {atlas}\nregion = Rect2({f*cell}, {row*cell}, {cell}, {cell})')
                frames.append('{"duration": 1.0, "texture": SubResource("'+ident+'")}')
            anim=name+'_'+d if rows==8 else 'default'
            anims.append('{"frames": ['+', '.join(frames)+f'], "loop": {str(loop).lower()}, "name": &"{anim}", "speed": 12.0'+'}')
        lines+=['[resource]','animations = ['+',\n'.join(anims)+']'];dest.write_text('\n\n'.join(lines)+'\n',encoding='utf8')

def effects():
    for name,(cell,n,rows,rig,loop) in SPECS.items():
        selected=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--only=')),None)
        if selected and name!=selected:continue
        folder=OUT/'effects'/name;folder.mkdir(parents=True,exist_ok=True)
        if '--resume' in sys.argv and all((folder/(name+s+'.png')).exists() for s in ('','_n','_e')):resource(name);continue
        feet_pivot=name in ('coffre_arc','gold_bleed')
        s=setup(rig,cell,feet_pivot);sheets={su:Image.new('RGBA',(cell*n,cell*rows)) for su in ('','_n','_e')}
        for f in range(n):
            root=geometry(name,f,n);iso.bake_ao_shadows(root)
            for row,(d,angle) in enumerate(list(iso.DIRECTIONS.items())[:rows]):
                root.rotation_euler.z=angle if rows==8 else 0
                if f==n//2 and row==0:
                    s['AA2_contract']=json.dumps({'name':name,'cell':cell,'frames':n,'rows':rows,'rig':rig,'pivot':[cell/2,cell*(.71 if feet_pivot else .5)],'accent':'F2C14E','native_ppu':128 if rig=='TOP' else iso.R})
                    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(SRC/('avare_'+name+'.blend')))
                path=RAW/name/f'{d}_{f:02}.png';iso.render_frame(path)
                for su in sheets:
                    with Image.open(path.with_name(path.stem+su+'.png')) as im:sheets[su].alpha_composite(im.convert('RGBA'),(f*cell,row*cell))
            for ob in [*root.children_recursive,root]:bpy.data.objects.remove(ob,do_unlink=True)
        for su,im in sheets.items():im.save(folder/(name+su+'.png'),optimize=True,compress_level=9)
        resource(name);print('AA2 EFFECT PASS '+name,flush=True)

def portrait():
    bpy.ops.wm.open_mainfile(filepath=str(aa1.SOURCE));s=bpy.context.scene;s.frame_set(1)
    root=bpy.data.objects['Avare'];root.rotation_euler.z=-.22
    cam=s.camera;cam.data.shift_y=0;cam.data.ortho_scale=1.06
    target=Vector((0,0,1.17));cam.location=(.40,-5,2.3);cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    s['iso_frame']=[256,256];s.render.resolution_x=s.render.resolution_y=512;s.render.resolution_percentage=100;s.eevee.taa_render_samples=16
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'avare_portrait.blend'))
    iso.render_frame(OUT/'portrait.png');print('AA2 PORTRAIT PASS',flush=True)

def contact():
    board=Image.new('RGBA',(1600,1600),(20,24,28,255))
    refs=['art/tools/characters/_cd_avare.png','art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/ui/_i2_contact.png']
    for i,p in enumerate(refs):
        with Image.open(ROOT/p) as src:
            im=src.convert('RGBA');im.thumbnail((310,165));board.alpha_composite(im,(i*320,0))
    with Image.open(OUT/'portrait.png') as im:board.alpha_composite(im,(0,175))
    with Image.open(OUT/'idle.png') as im:
        for i in range(6):board.alpha_composite(im.crop((0,i*192,192,(i+1)*192)),(300+i*205,190))
    for i,f in enumerate((0,2,5)):
        with Image.open(OUT/'effects/coin_burst/coin_burst.png') as im:board.alpha_composite(im.crop((f*512,0,(f+1)*512,512)),(i*530,450))
    for i in range(4):
        with Image.open(OUT/'effects/ransom_ring/ransom_ring.png') as im:board.alpha_composite(im.crop((i*256,0,(i+1)*256,256)),(i*260,980))
    with Image.open(OUT/'effects/coffre_arc/coffre_arc.png') as im:
        for i in range(2):board.alpha_composite(im.crop((2*192,(i+1)*192,3*192,(i+2)*192)),(1080+i*230,1030))
    for i,name in enumerate(('coin_projectile','coin_pickup','gold_bleed')):
        with Image.open(OUT/f'effects/{name}/{name}.png') as im:
            tile=im.convert('RGBA');tile.thumbnail((490,110));board.alpha_composite(tile,(i*530,1240))
    frame=Image.open(ROOT/'game/assets/sprites/ui/spell_frame.png').convert('RGBA')
    for col,(name,ardent) in enumerate(zip(('coup_de_coffre','poignee_de_pieces','rancon','faillite'),('eclat_de_braise','cendres','brasier','nova_ardente'))):
        for row,size in enumerate((128,64)):
            for k,stem in enumerate(('avare_'+name,ardent)):
                tile=Image.new('RGBA',(size,size))
                with Image.open(aa1.ICONS/(stem+'.png')) as src:
                    icon=src.convert('RGBA');icon.thumbnail((int(size*.78),)*2,Image.Resampling.LANCZOS);tile.alpha_composite(icon,((size-icon.width)//2,(size-icon.height)//2))
                tile.alpha_composite(frame.resize((size,size),Image.Resampling.LANCZOS));board.alpha_composite(tile,(col*400+40+k*160,1370+row*140))
    board.save(ROOT/'art/tools/night/_aa2_contact.png',optimize=True)

def verify():
    report={'effects':{},'frames':0,'clipped':[],'icons':'AA1 approved bevelled PBR geometry retained','portrait':256}
    for name,(cell,n,rows,rig,loop) in SPECS.items():
        folder=OUT/'effects'/name
        for su in ('','_n','_e'):
            with Image.open(folder/(name+su+'.png')) as im:
                assert max(im.size)<=4096,(name,su,'mobile texture limit')
                assert im.mode=='RGBA' and im.size==(cell*n,cell*rows),(name,su,im.size)
                assert max(im.size)<=4096,(name,'texture budget',im.size)
                if su=='_e':assert max(im.getchannel(c).getextrema()[1] for c in 'RGB')>10
                if su=='':
                    for row in range(rows):
                        hashes=set()
                        for f in range(n):
                            tile=im.crop((f*cell,row*cell,(f+1)*cell,(row+1)*cell));b=tile.getchannel('A').point(lambda x:255 if x>8 else 0).getbbox();assert b,(name,f,'empty')
                            if min(b[:2])<2 or max(b[2:])>cell-2:report['clipped'].append([name,row,f,b])
                            hashes.add(hashlib.sha256(tile.tobytes()).hexdigest());report['frames']+=1
                        assert len(hashes)==n,(name,'static')
        report['effects'][name]={'cell':cell,'frames':n,'directions':rows,'rig':rig,'loop':loop}
    assert not report['clipped'],report['clipped'][:5]
    for name in ('coup_de_coffre','poignee_de_pieces','rancon','faillite'):
        with Image.open(aa1.ICONS/('avare_'+name+'.png')) as im:assert im.size==(128,128)
    with Image.open(OUT/'portrait.png') as im:assert im.size==(256,256) and im.getchannel('A').getbbox()
    (OUT/'aa2_verification.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    contact();print('AA2 PIXEL PASS / '+str(report['frames'])+' VFX frames',flush=True)

def godot():
    exe=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
    paths=['res://'+str(p.relative_to(ROOT/'game')).replace('\\','/') for p in OUT.rglob('*.tres')]
    code='extends SceneTree\nfunc _initialize():\n'
    for i,p in enumerate(paths):
        code+=f'    var r{i} = load("{p}")\n    assert(r{i} is SpriteFrames)\n'
        code+=f'    for a in r{i}.get_animation_names():\n        for f in range(r{i}.get_frame_count(a)):\n            var t = r{i}.get_frame_texture(a, f)\n            assert(t is AtlasTexture and t.atlas != null)\n'
    code+='    print("AA2 LOAD RESULT: OK")\n    quit()\n'
    with tempfile.TemporaryDirectory(prefix='rainfall_aa2_') as tmp:
        check=Path(tmp)/'check.tres';check.write_text('[gd_resource type="GDScript" format=3]\n[resource]\nscript/source = '+json.dumps(code)+'\n',encoding='utf8')
        for label,args in [('import',['--editor','--import','--quit']),('load',['--script',str(check)]),('sprites_test',['res://tests/sprites_test.tscn'])]:
            p=subprocess.run([exe,'--headless','--path',str(ROOT/'game')]+args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf8',errors='replace',timeout=240)
            (OUT/f'aa2_{label}.log').write_text(p.stdout,encoding='utf8')
            errors=[x for x in p.stdout.splitlines() if 'ERROR:' in x or 'SCRIPT ERROR' in x]
            assert p.returncode==0,(label,p.returncode)
            if label=='load':assert not errors and 'AA2 LOAD RESULT: OK' in p.stdout,errors[:3]
            if label=='sprites_test':assert 'RESULT: OK' in p.stdout,p.stdout[-1200:]
            print('AA2 GODOT '+label+' PASS / errors='+str(len(errors)),flush=True)

if __name__=='__main__':
    if '--verify' in sys.argv:verify();godot()
    elif '--portrait' in sys.argv:portrait()
    elif '--effects' in sys.argv:effects()
    else:effects();portrait();verify();godot()
