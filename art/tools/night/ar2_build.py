"""AR2: forged survey chain, trap zones, anchor, portrait and shared I2 icons.
Background Blender only. --effects / --portrait / --icons / --verify / --contact.
Pillow only assembles, resizes and verifies Blender renders; no drawn artwork.
"""
import sys, math, json, random, hashlib, subprocess, tempfile, inspect, textwrap, re
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/night'))
sys.path.insert(0,str(ROOT/'art/tools/cel'))
import cel_style as cel
import ar1_build as ar1
import bpy
from mathutils import Vector
from PIL import Image
cd=ar1.cd
iso=ar1.iso_rig
OUT=ar1.OUT
FX=OUT/'effects'
SRC=ROOT/'art/blender/characters'
RAW=SRC/'arpenteuse_ar2_frames'
SPECS={'chain_tile':((128,64),4,1,'TOP',True),
       'peg':((192,192),1,8,'CREA',True),
       'loop_blaze':((256,256),6,1,'TOP',False),
       'chain_snap':((128,64),6,1,'TOP',False),
       'chain_rewind':((128,64),6,1,'TOP',False)}

def setup(kind,size):
    s=iso.create_rig(kind,size)
    s.eevee.taa_render_samples=8
    s.render.threads_mode='FIXED';s.render.threads=8
    s.render.dither_intensity=0
    if kind=='CREA':s.camera.data.shift_y=.21
    s.view_layers[0].use_pass_normal=True;s.view_layers[0].use_pass_emit=True
    s.render.image_settings.color_mode='RGBA'
    global copper,iron,bronze,hot,ash
    copper=cd.worn('Hammered copper, scorched pits','271B16','A77951',1,.39)
    iron=cd.worn('Blackened wrought iron','151B1C','59605B',1,.49)
    bronze=cd.worn('Survey bronze, verdigris recesses','293D35','A99B70',1,.45)
    ash=cd.worn('Burned mineral residue','111518','3B332B',0,.92)
    hot=cd.material('Only accent: incandescent copper FF7A1F','FF7A1F',2.0,True)
    return s

def link(parent,p,i,angle=0,heat=True):
    # Alternating planes physically interlock; elongated, forged oval section.
    o=cd.torus('Hand forged copper link',p,.061,.015,copper,parent,
               (math.pi*.10 if i%2==0 else math.pi*.42,0,angle),(1.54,.80,1))
    if heat:
        for sign in (-1,1):
            q=Vector(p)+Vector((math.cos(angle)*sign*.073,math.sin(angle)*sign*.073,.006))
            cd.torus('Hot weld seam',q,.015,.006,hot,parent,(0,math.pi/2,angle),(1,.8,1))
    return o

def curve(name,points,r,mat,par):return cd.tube(name,points,r,mat,par)

def shard(parent,p,height,angle,mat):
    x,y,z=p;c=math.cos(angle);s=math.sin(angle);w=.022
    verts=[(x-w*c,y-w*s,z),(x+w*c,y+w*s,z),
           (x+.08*s,y-.08*c,z+height*.42),(x+.02*c,y+.02*s,z+height)]
    return cd.mesh('Torn copper ember',verts,[(0,1,2),(0,2,3),(1,3,2)],mat,parent,.001)

def build_chain(name,f,n):
    s=setup('TOP',(128,64));root=cd.empty('AR2_'+name)
    t=f/max(1,n-1);pulse=1-t if name!='chain_tile' else .55+.35*math.cos(f*math.pi/2)
    hot.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=.5+2.8*pulse
    for i in range(-2,12):
        x=-.5+i*.125
        y=.018*math.sin(i*1.6-f*1.1) if name=='chain_tile' else .055*(1-t)*math.sin(i*1.1-f*1.4)
        link(root,(x,0 if name=='chain_tile' else y,.055),i,0 if name=='chain_tile' else .15*math.sin(i-f),heat=(i%4==f if name=='chain_tile' else (i+f)%3!=0))
    if name!='chain_tile':
        front=-.40+.80*t if name=='chain_snap' else .40-.80*t
        for j in range(22-f*3):
            sign=1 if j%2 else -1
            x=front+(random.random()-.5)*(.8-.35*t)
            y=sign*(.07+random.random()*.14)*(1-.4*t)
            shard(root,(x,y,.04),.035+random.random()*.09,j,hot if j%3 else copper)
        for sign in (-1,1):
            pts=[(front-.18+k*.035,sign*(.025+.17*math.sin(k*math.pi/10))*(1-.65*t),.03) for k in range(11)]
            curve('Traveling shock crest',pts,.012*(1-.7*t),hot,root)
        for j in range(max(1,5-f)):
            link(root,(front+(j-2)*.12,(-1 if j%2 else 1)*(.14+.035*t),.08),j,j*.8+f*.5,heat=True)
    return s,root

def build_peg():
    s=setup('CREA',(192,192));root=cd.empty('AR2 directional survey anchor')
    cd.segment('Tapered iron ground spike',(0,0,.02),(0,0,.80),.027,.053,iron,root)
    cd.torus('Hammered bronze striking head',(0,0,.83),.078,.021,bronze,root)
    cd.segment('Square bronze collar',(0,0,.60),(0,0,.74),.082,.067,bronze,root)
    cd.torus('Chain anchorage swivel',(0,-.105,.64),.091,.020,copper,root,(math.pi/2,0,0))
    for i in range(3):
        a=i*math.tau/3+.3
        p=(.24*math.cos(a),.24*math.sin(a),.018)
        cd.segment('Splayed forged stabilizer',p,(0,0,.40),.025,.029,iron,root)
        cd.torus('Bronze foot ferrule',p,.039,.011,bronze,root)
        cd.bead('Flush brass rivet',(.065*math.cos(a),.065*math.sin(a),.69),(.018,.018,.018),bronze,root)
    for i in range(5):link(root,(.02*i,-.12-i*.10,.07 if i>2 else .43-i*.11),i,math.pi/2,heat=i>2)
    for z in (.23,.28,.33,.47,.52):
        cd.torus('Machined depth graduation',(0,0,z),.042,.004,bronze,root)
    for ob in list(s.objects):
        if ob.type=='MESH':iso.bake_ao_shadows(ob)
    return s,root

def build_loop(f,n):
    s=setup('TOP',(256,256));root=cd.empty('AR2 tangled burning chain crown')
    t=f/(n-1)
    hot.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=3.2*(1-t)+.3
    for j in range(46):
        a=j*math.tau/46
        r=.66+.10*math.sin(3*a+.4)+.035*math.sin(7*a)
        if f>=3 and (j*7)%11 < (f-2)*2:continue
        link(root,(r*math.cos(a),r*math.sin(a),.055+.025*math.sin(5*a)),j,a+math.pi/2+.4*math.sin(3*a),heat=(j+f)%4!=0)
    # Loose interwoven bights, never straight polygon edges.
    for j in range(18):
        a=j*math.tau/18+.2;r=.54+.11*math.sin(j*2.3)
        if f>2 and j%3!=0:continue
        link(root,(r*math.cos(a),r*math.sin(a),.10),j,a+.7,heat=True)
    for j in range(44-f*5):
        a=j*2.399+.16*t;r=.61+.13*math.sin(j*1.7)+.05*t
        shard(root,(r*math.cos(a),r*math.sin(a),.04),.07+.12*random.random()*(1-t),a+f,hot if j%4 else copper)
    return s,root

def build_burst(f,n):
    s=setup('TOP',(192,192));root=cd.empty('Peg copper and mineral impact')
    t=f/(n-1)
    for j in range(36-f*5):
        a=j*2.399;r=(.04+.16*random.random())*(.45+t)
        shard(root,(r*math.cos(a),r*math.sin(a),.02),(.12+.35*random.random())*(1-.65*t),a,hot if j%4==0 else iron if j%3 else copper)
    return s,root

def effects():
    # Existing atlas regions and transparent margins are contractual.
    source=textwrap.dedent(inspect.getsource(iso.render_frame)).replace("('_n','_e')","('_e',)")
    exec(compile(source,__file__,'exec'),iso.__dict__)
    baseline={}
    for name in ('chain_snap','chain_rewind','chain_tile','loop_blaze'):
        baseline[name]={q:(FX/(name+q+'.png')).stat().st_size for q in ('','_e')}
    if (SRC/'ar2_fx_baseline.json').exists():baseline=json.loads((SRC/'ar2_fx_baseline.json').read_text())
    SPECS.pop('peg',None)
    SPECS['peg_burst']=((192,192),6,1,'TOP',False)
    for name,(size,n,rows,kind,looping) in SPECS.items():
        if '--tile-only' in sys.argv and name!='chain_tile':continue
        if '--burst-only' in sys.argv and name!='peg_burst':continue
        tres=FX/(name+'.tres')
        if name!='peg_burst':
            txt=tres.read_text();reg=[int(v) for v in re.search(r'region = Rect2\(([^)]+)',txt)[1].split(',')]
            margin=re.search(r'margin = Rect2\(([^)]+)',txt)
            left,top=([int(v) for v in margin[1].split(',')][:2] if margin else [0,0])
            cw,ch=reg[2:]
        else:left=top=0;cw,ch=size
        sheets={q:Image.new('RGBA',(cw*n,ch)) for q in ('','_e')}
        for f in range(n):
            random.seed(220)
            s,root=build_burst(f,n) if name=='peg_burst' else build_loop(f,n) if name=='loop_blaze' else build_chain(name,f,n)
            cel.install('prop',normals=False)
            path=RAW/name/f'e_{f:02}.png'
            if f==0:bpy.ops.wm.save_as_mainfile(filepath=str(SRC/f'arpenteuse_{name}.blend'))
            iso.render_frame(path)
            for q in sheets:
                with Image.open(path.with_name(path.stem+q+'.png')) as im:
                    sheets[q].paste(im.crop((left,top,left+cw,top+ch)),(f*cw,0))
        for q,im in sheets.items():
            if q:im=im.resize(((im.width+1)//2,(im.height+1)//2),Image.Resampling.LANCZOS)
            im.save(FX/(name+q+'.png'),optimize=True,compress_level=9)
        if name=='peg_burst':resource(name)
    (SRC/'ar2_fx_baseline.json').write_text(json.dumps(baseline))
    print('AR2 FX PASS: 5 effects, cel prop, normals=False',flush=True)

def resource(name):
    size,n,rows,kind,looping=SPECS[name]
    lines=['[gd_resource type="SpriteFrames" load_steps='+str(2+n*rows)+' format=3]']
    for i,suffix in enumerate(('',),1):lines.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/characters/arpenteuse/effects/{name}{suffix}.png" id="{i}"]')
    animations=[]
    for row,d in enumerate(list(iso.DIRECTIONS)[:rows]):
        frames=[]
        for f in range(n):
            ident=f'F_{row}_{f}'
            lines += [f'[sub_resource type="AtlasTexture" id="{ident}"]','atlas = ExtResource("1")',f'region = Rect2({f*size[0]}, {row*size[1]}, {size[0]}, {size[1]})']
            frames.append('{"duration": 1.0, "texture": SubResource("'+ident+'")}')
        anim=f'peg_{d}' if rows==8 else 'default'
        animations.append('{"frames": ['+', '.join(frames)+f'], "loop": {str(looping).lower()}, "name": &"{anim}", "speed": {8 if name=="chain_tile" else 24 if name=="peg_burst" else 12}.0'+'}')
    lines+=['[resource]','animations = ['+',\n'.join(animations)+']']
    (FX/f'{name}.tres').write_text('\n\n'.join(lines)+'\n',encoding='utf8')

def portrait():
    bpy.ops.wm.open_mainfile(filepath=str(SRC/'arpenteuse.blend'))
    s=bpy.context.scene;s.frame_set(1)
    for ob in s.objects:
        if ob.type=='ARMATURE':ob.animation_data_clear();ob.rotation_euler.z=-.22
    if hasattr(s,'compositing_node_group'):s.compositing_node_group=None
    if hasattr(s,'use_nodes'):s.use_nodes=False
    # AR1 actor is scaled to 0.8: frame the actual head/shoulders, not unscaled CD.
    s.camera.location=(.45,-6,2.35)
    s.camera.rotation_euler=(Vector((0,0,.98))-s.camera.location).to_track_quat('-Z','Y').to_euler()
    s.camera.data.shift_y=0;s.camera.data.ortho_scale=1.18
    s.render.resolution_x=512;s.render.resolution_y=512;s.render.resolution_percentage=100
    s.eevee.taa_render_samples=24
    s.render.filepath=str(OUT/'portrait.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'arpenteuse_portrait.blend'))
    bpy.ops.render.render(write_still=True)
    with Image.open(OUT/'portrait.png') as im:im.resize((256,256),Image.Resampling.LANCZOS).save(OUT/'portrait.png',optimize=True)
    print('AR2 PORTRAIT PASS',flush=True)

def contact():
    board=Image.new('RGBA',(1600,1250),(22,26,30,255))
    refs=['art/tools/characters/_cd_arpenteuse.png','art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/ui/_i2_contact.png']
    for i,p in enumerate(refs):
        with Image.open(ROOT/p) as src:
            im=src.convert('RGBA');im.thumbnail((310,170));board.alpha_composite(im,(i*320,0))
    with Image.open(OUT/'portrait.png') as im:board.alpha_composite(im,(0,180))
    with Image.open(OUT/'idle.png') as im:
        for i in range(6):board.alpha_composite(im.crop((0,i*192,192,(i+1)*192)),(300+i*205,180))
    with Image.open(FX/'peg.png') as im:
        for i in range(8):board.alpha_composite(im.crop((0,i*192,192,(i+1)*192)),(i*198,430))
    for j,name in enumerate(('chain_tile','chain_snap','chain_rewind')):
        with Image.open(FX/f'{name}.png') as im:board.alpha_composite(im,(15,640+j*72))
    with Image.open(FX/'loop_blaze.png') as im:
        for i in range(3):board.alpha_composite(im.crop((i*2*256,0,(i*2+1)*256,256)),(800+i*260,615))
    frame=Image.open(ROOT/'game/assets/sprites/ui/spell_frame.png').convert('RGBA')
    for col,(name,ardent) in enumerate(zip(('chaine','boucle','piquet','tendeur'),('eclat_de_braise','cendres','brasier','nova_ardente'))):
        for row,size in enumerate((128,64)):
            for k,stem in enumerate(('arpenteuse_'+name,ardent)):
                tile=Image.new('RGBA',(size,size))
                with Image.open(ROOT/f'game/assets/sprites/icons/spells/{stem}.png') as src:
                    im=src.convert('RGBA');im.thumbnail((int(size*.78),int(size*.78)),Image.Resampling.LANCZOS)
                    tile.alpha_composite(im,((size-im.width)//2,(size-im.height)//2))
                tile.alpha_composite(frame.resize((size,size),Image.Resampling.LANCZOS))
                board.alpha_composite(tile,(col*400+40+k*160,915+row*160))
    board.save(ROOT/'art/tools/night/_ar2_contact.png',optimize=True)
    print('AR2 CONTACT PASS',flush=True)

def verify():
    report={'effects':{},'portrait':'PASS','icons':4,'clipped':[]}
    for name,(size,n,rows,kind,looping) in SPECS.items():
        for suffix in ('','_n','_e'):
            with Image.open(FX/f'{name}{suffix}.png') as im:
                assert im.mode=='RGBA' and im.size==(size[0]*n,size[1]*rows),(name,suffix,im.size)
                assert im.getbbox(),(name,suffix,'empty')
                if suffix=='':
                    hashes=set()
                    for r in range(rows):
                        for f in range(n):
                            cell=im.crop((f*size[0],r*size[1],(f+1)*size[0],(r+1)*size[1]))
                            box=cell.getchannel('A').point(lambda x:255 if x>12 else 0).getbbox()
                            assert box,(name,r,f)
                            if name in ('peg','loop_blaze') and (min(box[:2])<3 or box[2]>size[0]-3 or box[3]>size[1]-3):report['clipped'].append([name,r,f,box])
                            hashes.add(hashlib.sha256(cell.tobytes()).hexdigest())
                    assert len(hashes)==n*rows,(name,'duplicate frames')
        report['effects'][name]={'cell':size,'frames':n,'directions':rows,'rig':kind,'loop':looping,'emission':'FF7A1F','normal':True}
    assert not report['clipped'],report['clipped']
    for name in ('chaine','boucle','piquet','tendeur'):
        with Image.open(ROOT/f'game/assets/sprites/icons/spells/arpenteuse_{name}.png') as im:assert im.size==(128,128) and im.mode=='RGBA'
    with Image.open(OUT/'portrait.png') as im:assert im.size==(256,256) and im.mode=='RGBA'
    godot=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
    code='extends SceneTree\nfunc _initialize():\n'
    for path in [OUT/'arpenteuse.tres']+list(FX.rglob('*.tres')):
        rel='res://'+path.relative_to(ROOT/'game').as_posix()
        code+=f'    assert(load("{rel}") is SpriteFrames)\n'
    code+='    print("AR2 LOAD RESULT: OK")\n    quit()\n'
    with tempfile.TemporaryDirectory(prefix='rainfall_ar2_') as tmp:
        p=Path(tmp)/'check.tres';p.write_text('[gd_resource type="GDScript" format=3]\n[resource]\nscript/source = '+json.dumps(code)+'\n',encoding='utf8')
        for label,args in [('import',['--editor','--import','--quit']),('load',['--script',str(p)]),('sprites_test',['res://tests/sprites_test.tscn'])]:
            proc=subprocess.run([godot,'--headless','--path',str(ROOT/'game')]+args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf8',errors='replace',timeout=180)
            (OUT/f'ar2_{label}.log').write_text(proc.stdout,encoding='utf8')
            errors=[x for x in proc.stdout.splitlines() if 'ERROR:' in x or 'SCRIPT ERROR' in x]
            report[label]={'returncode':proc.returncode,'errors':errors[:6]}
            assert proc.returncode==0,(label,proc.returncode)
            if label in ('load','sprites_test'):assert 'RESULT: OK' in proc.stdout and not errors,(label,errors[:6],proc.stdout[-600:])
    report['choices']='Forged interlocking copper links; scorched welds; bronze survey anchor; inward polygon filaments. No projectile in design. Portrait kept inside authorized character directory.'
    (OUT/'ar2_manifest.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print('AR2 VERIFICATION PASS / Godot RESULT: OK',flush=True)

if __name__=='__main__':
    if '--finish' in sys.argv:contact();verify()
    elif '--verify' in sys.argv:verify()
    elif '--contact' in sys.argv:contact()
    elif '--portrait' in sys.argv:portrait()
    elif '--icons' in sys.argv:ar1.icons()
    elif '--effects' in sys.argv or '--tile-only' in sys.argv:effects()
    else:effects();portrait();ar1.icons();contact();verify()
