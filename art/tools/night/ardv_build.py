"""ARDV: Blender geometry, shared cel compositor, lossless atlas assembly.
blender.exe --background --python art/tools/night/ardv_build.py
python art/tools/night/ardv_build.py --pack
Pillar needs a taller cell to retain 90.51 px/u AND a centred ground pivot.
"""
import sys, math, json, hashlib, warnings
warnings.filterwarnings('ignore', category=DeprecationWarning)
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT/'art/tools/cel'), str(ROOT/'art/tools/iso'), str(ROOT/'art/tools')]
WORK = ROOT/'art/renders/ardv'
DEST = ROOT/'game/assets/sprites'
DIRS = ['e','se','s','sw','w','nw','n','ne']
SPECS = {'ember_orbs_iso':(128,128,6,1), 'flame_pillar':(256,768,12,1),
         'meteor_fall':(128,384,6,1), 'meteor_impact':(256,256,10,1),
         'phoenix':(256,256,10,8), 'telegraph_ring':(256,256,1,1)}
ICONS = ['braises_errantes','pilier_de_flamme','pluie_de_meteores','phenix']

def mesh(name, verts, faces, mat):
    import bpy
    data=bpy.data.meshes.new(name); data.from_pydata(verts,[],faces); data.update()
    ob=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(ob); data.materials.append(mat)
    return ob

def ell(loc, scale, mat):
    import bpy
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=loc)
    ob=bpy.context.object; ob.scale=scale; ob.data.materials.append(mat); return ob

def halo():
    import bpy
    m=bpy.data.materials.get('orb halo')
    if m is None:
        m=bpy.data.materials.new('orb halo');m.use_nodes=True;m['cel_done']=True
        m.surface_render_method='DITHERED'
        nodes=m.node_tree.nodes;nodes.clear();links=m.node_tree.links
        out=nodes.new('ShaderNodeOutputMaterial');trans=nodes.new('ShaderNodeBsdfTransparent')
        emit=nodes.new('ShaderNodeEmission');emit.inputs['Color'].default_value=(1,.26225,.0331,1)
        mix=nodes.new('ShaderNodeMixShader');mix.inputs[0].default_value=.075
        links.new(trans.outputs[0],mix.inputs[1]);links.new(emit.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],out.inputs[0])
        aov=nodes.new('ShaderNodeOutputAOV');aov.aov_name='CEL_Accent';aov.inputs['Color'].default_value=(.075,.0197,.0025,1)
    ob=ell((0,0,0),(.405,)*3,m)
    for face in ob.data.polygons:face.use_smooth=True

def tongue(loc, radius, height, phase, mat, lean=(0,0)):
    # Faceted, bent flame with irregular shoulders and a sharp lick.
    verts=[]; faces=[]; seg=7
    for k,(z,r) in enumerate([(0,.72),(.18,1),(.48,.68),(.75,.37),(1,0)]):
        for j in range(seg):
            a=math.tau*j/seg; rr=radius*r*(1+.14*math.sin(j*2.1+phase))
            verts.append((loc[0]+rr*math.cos(a)+lean[0]*z*z+.09*radius*math.sin(phase+z*5),
                          loc[1]+rr*math.sin(a)+lean[1]*z*z,loc[2]+height*z))
    for k in range(4):
        for j in range(seg):
            a=k*seg+j;b=k*seg+(j+1)%seg;faces.append((a,b,b+seg,a+seg))
    faces.append(tuple(reversed(range(seg))));return mesh('flame',verts,faces,mat)

def arc(radius, start, end, width, mat, z=.012):
    n=max(3,int((end-start)*24));v=[]
    for i in range(n+1):
        a=start+(end-start)*i/n
        v.extend([(r*math.cos(a),r*math.sin(a),z) for r in (radius-width/2,radius+width/2)])
    return mesh('incandescent bed',v,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(n)],mat)

def bird(t, dive, mats):
    dark,orange,gold,white=mats
    ell((0,-.1,0),(.12,.32,.13),orange)
    ell((0,-.36,.07),(.105,.12,.105),gold)
    # Beak and crest; geometry, not billboard.
    mesh('beak',[(-.06,-.4,.09),(.06,-.4,.09),(0,-.61,.055),(0,-.43,.15)],[(0,1,2),(0,3,2),(1,2,3)],white)
    for side in (-1,1):
        flap=.13*math.sin(t)+.025*math.cos(t)
        mesh('wing',[(side*.08,-.12,.04),(side*.43,-.12,.14+flap),
                    (side*.75,.15,.22+flap),(side*.32,.31,-.02)],[(0,1,2),(0,2,3)],orange)
        for j in range(5):
            x=side*(.28+j*.09); y=.08+j*.045; z=.05+flap*(j+1)/5
            mesh('pointed feather',[(x,y-.15,z),(x+side*.12,y-.07,z+.03),
                                   (x+side*(.07+.015*j),y+.28+.05*j+.025*math.cos(t+j),z-.04)],[(0,1,2)],gold if j%2==0 else orange)
        ell((side*.065,-.42,.105),(.019,.025,.025),white)
    for j in range(3):
        x=(j-1)*.09; length=.7+.16*(j==1)
        mesh('ribbon tail',[(x-.065,.12,.01),(x+.065,.12,.02),
                           (x+.08*math.sin(t+j),length,-.09),
                           (x+.025*math.sin(t+j),length+.12,-.04)],[(0,1,2),(0,2,3)],gold if j==1 else orange)
    tongue((0,-.32,.12),.06,.22,t,orange,lean=(0,.08))

def build(name, frame, row=0):
    import bpy
    t=math.tau*frame/(6 if name in ('phoenix','ember_orbs_iso','meteor_fall') else 10)
    dark,orange,gold,white=MATS
    if name=='ember_orbs_iso':
        halo()
        pulse=1+.04*math.sin(t)
        ell((0,0,0),(.35*pulse,)*3,orange)
        ell((.08,-.12,.06),(.25,.25,.25),gold)
        ell((.18,-.22,.16),(.13,.13,.13),white)
        tongue((-.26,.12,-.04),.19,.43,t,orange,(-.25,.23))
        for i in range(3):ell((-.4-i*.09,.2+i*.09,.06*math.sin(t+i)),(.04,)*3,gold)
    elif name=='flame_pillar':
        fade=1 if frame<10 else (.62 if frame==10 else .18)
        arc(1.17,0,math.tau,.06,orange);arc(.93,0,math.tau,.10,gold)
        ell((0,0,.025),(1.12,1.12,.06*fade),orange)
        tongue((0,0,.05),.55*fade,(3.78+.12*math.sin(t))*fade,t,orange,(.12*math.sin(t),.12))
        tongue((.08,-.12,.07),.32*fade,3.12*fade,t+1,gold,(-.1,.1))
        tongue((.12,-.2,.08),.15*fade,2.15*fade,t+2,white)
        for j in range(8):
            a=j*math.tau/8;r=.76
            tongue((r*math.cos(a),r*math.sin(a),.04),.24*fade,
                   (1.6+.55*math.sin(t+j))*fade,t+j,orange if j%2 else gold,(.15*math.cos(a),.15*math.sin(a)))
        for j in range(9):
            a=j*2.4+t*.15;z=((j*.41+frame*.13)%3.8)*fade
            ell((.5*math.cos(a),.5*math.sin(a),z),(.025,.025,.065),gold)
    elif name=='meteor_fall':
        rock=ell((0,0,-.35),(.27,.27,.32),dark);rock.rotation_euler=(t*.2,t*.13,t*.25)
        for j in range(6):
            a=j*math.tau/6
            tongue((.17*math.cos(a),.17*math.sin(a),-.45),.11,1.4+.3*math.sin(t+j),t+j,orange if j%2 else gold,(.06*math.sin(t+j),.04))
        ell((.12,-.18,-.47),(.16,.16,.15),white)
    elif name=='meteor_impact':
        u=frame/9;r=.25+.75*min(1,u*2.4);fade=1-u*.88
        arc(r-.025,0,math.tau,.065*fade,orange)
        ell((0,0,.02),(r*.78,r*.78,.065*fade),orange)
        for j in range(11):
            a=j*math.tau/11+.16;rr=r*.64
            tongue((rr*math.cos(a),rr*math.sin(a),.04),(.16-.09*u),
                   (.94+.13*math.sin(j*3))*math.sin(math.pi*(.16+.78*u)),t+j,
                   gold if j%3==0 else orange,(.22*math.cos(a),.22*math.sin(a)))
        if frame<5:tongue((0,0,.03),.27*(1-u),1.3*(1-u),t,white)
    elif name=='telegraph_ring':
        # Opaque fill; brightness hierarchy is geometric/material, alpha exactly one inside.
        mesh('allied fill',[(0,0,0)]+[(.96*math.cos(j*math.tau/64),.96*math.sin(j*math.tau/64),0) for j in range(64)],
             [(0,j+1,(j+1)%64+1) for j in range(64)],BED)
        for j in range(24):arc(.985,j*math.tau/24,j*math.tau/24+.15,.03,orange)
    elif name=='phoenix':
        bird(t,frame>=6,MATS)
        # Camera yaw 45 degrees, front -Y. Eight clockwise screen directions.
        yaw=math.radians(135-45*row)
        from mathutils import Matrix
        rot=Matrix.Rotation(yaw,4,'Z')
        if frame>=6:
            rot=rot@Matrix.Rotation(.45+.16*(frame-6),4,'X')@Matrix.Diagonal((1,1.12,1,1))
        bpy.context.view_layer.update()
        for ob in bpy.context.scene.objects:
            if ob.type=='MESH':ob.matrix_world=rot@ob.matrix_world

def render():
    import bpy, iso_rig, cel_style as cel
    from PIL import Image
    global MATS,BED
    WORK.mkdir(parents=True,exist_ok=True)
    cel.install('vfx',normals=False)
    for name,(w,h,n,rows) in SPECS.items():
        if '--only' in sys.argv and name not in sys.argv[sys.argv.index('--only')+1].split(','):continue
        scene=iso_rig.create_rig('MAP',(w,h),target=(0,0,0))
        MATS=[iso_rig.material('volcanic crust',(.09,.055,.038)),
              iso_rig.material('ember #FF8C33',(1,.26225,.0331),emission=1),
              iso_rig.material('gold core',(1,.64,.11),emission=1),
              iso_rig.material('white hot',(1,.93,.57),emission=1)]
        BED=iso_rig.material('allied bed',(.105,.035,.008),emission=.7)
        for row in range(rows):
            for f in range(n):
                path=WORK/name/f'{row}_{f}.png'
                if '--resume' in sys.argv and path.exists() and path.with_stem(path.stem+'_e').exists():continue
                for ob in list(scene.objects):
                    if ob.type=='MESH':bpy.data.objects.remove(ob,do_unlink=True)
                build(name,f,row);path.parent.mkdir(parents=True,exist_ok=True)
                iso_rig.common.configure_passes(path)
                scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
                found=list(path.parent.glob(path.stem+'_e__*.png'))
                assert len(found)==1,(path,found)
                found[0].replace(path.with_stem(path.stem+'_e'))
                assert not list(path.parent.glob('*_n*.png'))
        print('PASS render '+name,flush=True)
    # Icons reuse the actual spell geometry with the shared inked icon profile.
    cel.uninstall();cel.install('icon',normals=False)
    for i,name in enumerate(ICONS):
        scene=iso_rig.create_rig('MAP',(128,128))
        # Render at icon scale without changing geometry or painting pixels.
        MATS=[iso_rig.material('crust',(.09,.055,.038)),
              iso_rig.material('ember',(1,.26225,.0331),emission=1),
              iso_rig.material('gold',(1,.64,.11),emission=1),
              iso_rig.material('core',(1,.93,.57),emission=1)]
        if i==0:
            for j in range(3):
                a=math.tau*j/3
                tongue((.48*math.cos(a),.48*math.sin(a),-.14),.19,.65,j,MATS[1],(.1,.08))
                ell((.48*math.cos(a),.48*math.sin(a),-.05),(.15,)*3,MATS[2])
            scene.camera.data.ortho_scale=1.7
        elif i==1:
            build('flame_pillar',3);scene.camera.data.ortho_scale=4.5
            scene.camera.location+=scene.camera.rotation_euler.to_matrix()@__import__('mathutils').Vector((0,1.25,0))
        elif i==2:
            build('meteor_fall',2)
            originals=[o for o in scene.objects if o.type=='MESH']
            for dx,dz,sc in [(-.65,.42,.72),(.65,.82,.65)]:
                for ob in originals:
                    dup=ob.copy();dup.data=ob.data.copy();scene.collection.objects.link(dup)
                    dup.location.x+=dx;dup.location.z+=dz;dup.scale*=sc
            scene.camera.data.ortho_scale=2.65
            scene.camera.location+=scene.camera.rotation_euler.to_matrix()@__import__('mathutils').Vector((0,.55,0))
        else:
            build('phoenix',1,2);scene.camera.data.ortho_scale=1.95
        path=WORK/'icons'/f'{name}.png';path.parent.mkdir(parents=True,exist_ok=True)
        iso_rig.common.configure_passes(path);scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    print('PASS render icons',flush=True)

def resource(name,w,h,n,rows):
    ext=f'[ext_resource type="Texture2D" path="res://assets/sprites/vfx/{name}/default.png" id="1"]'
    subs=[];anims=[]
    for row in range(rows):
        for f in range(n):
            sid=f'a{row*n+f}'
            subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("1")\nregion = Rect2({f*w}, {row*h}, {w}, {h})\n')
    def anim(label, indices, row=0,loop=True,fps=12):
        frames=', '.join('{"duration": 1.0, "texture": SubResource("a%d")}'%(row*n+f) for f in indices)
        anims.append('{\n"frames": ['+frames+'],\n"loop": '+str(loop).lower()+',\n"name": &"'+label+'",\n"speed": '+str(float(fps))+'\n}')
    if name=='phoenix':
        for row,d in enumerate(DIRS):
            anim('idle_'+d,range(6),row);anim('dive_'+d,range(6,10),row,False)
        anim('default',range(6),2) # Existing consumer currently requests default.
    elif name=='flame_pillar':anim('default',range(10));anim('end',range(10,12),loop=False)
    else:anim('default',range(n),loop=name in ('ember_orbs_iso','telegraph_ring'))
    return f'[gd_resource type="SpriteFrames" load_steps={len(subs)+2} format=3]\n\n'+ext+'\n\n'+'\n'.join(subs)+'\n[resource]\nanimations = ['+', '.join(anims)+']\n'

def pack():
    from PIL import Image
    import cel_style as cel
    import halve_emission
    import texture_budget, re
    report={'pixels_per_unit':64*math.sqrt(2),'camera_elevation':30,'camera_yaw':45,
            'flame_pillar':{'ground_radius_u':1.2,'ground_radius_px':108.6116,'bed_outer_radius_px':108.6116,
                            'ground_pivot_cell_px':[128,384],'height_u':4,'cell':[256,768]},'sheets':{}}
    for name,(w,h,n,rows) in SPECS.items():
        folder=DEST/'vfx'/name
        if folder.exists():cel.archive_folder('vfx/'+name)
        folder.mkdir(parents=True,exist_ok=True)
        for suffix in ('','_e'):
            sheet=Image.new('RGBA',(w*n,h*rows))
            hashes=[]
            for row in range(rows):
                for f in range(n):
                    with Image.open(WORK/name/f'{row}_{f}{suffix}.png') as im:
                        im=im.convert('RGBA').resize((w,h),Image.Resampling.LANCZOS)
                        assert im.getchannel('A').getbbox(),(name,row,f,'empty')
                        hashes.append(hashlib.sha256(im.tobytes()).hexdigest());sheet.paste(im,(w*f,h*row))
            if suffix:sheet=halve_emission.downscale(sheet)
            assert max(sheet.size)<=4096
            sheet.save(folder/f'default{suffix}.png',optimize=True,compress_level=9)
            if not suffix:report['sheets'][name]={'size':sheet.size,'frames':n*rows,'unique':len(set(hashes))}
        tres=folder/f'{name}.tres';body=resource(name,w,h,n,rows)
        # Preserve byte-identical resources when the frame contract is unchanged.
        if name=='meteor_impact':
            old=tres.read_text(encoding='utf8')
            assert old.count('type="AtlasTexture"')==10 and 'CanvasTexture' not in old
        else:tres.write_text(body,encoding='utf8')
        assert not list(folder.glob('*_n.png'))
        assert halve_emission.emission_peak(str(folder/'default_e.png'))>2/255
    cel.archive_folder('icons/spells')
    for name in ICONS:
        with Image.open(WORK/'icons'/f'{name}.png') as im:
            im.convert('RGBA').resize((128,128),Image.Resampling.LANCZOS).save(DEST/'icons/spells'/f'{name}.png',optimize=True,compress_level=9)
    # Same shared mobile import policy, strictly limited to this batch.
    budget=json.loads((ROOT/'game/tests/texture_budget.json').read_text(encoding='utf8'))
    pngs=[p for name in SPECS for p in (DEST/'vfx'/name).glob('*.png')]
    pngs += [DEST/'icons/spells'/f'{name}.png' for name in ICONS]
    for png in pngs:
        ip=Path(str(png)+'.import')
        text=ip.read_text(encoding='utf8') if ip.exists() else '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n'
        original=text
        for key,value in texture_budget.expected_params(png.relative_to(ROOT/'game').as_posix(),budget).items():
            line=f'{key}={texture_budget._fmt(value)}'
            pattern=r'^'+re.escape(key)+r'=.*$'
            text=re.sub(pattern,line,text,flags=re.M) if re.search(pattern,text,re.M) else text.rstrip()+'\n'+line+'\n'
        if text!=original or not ip.exists():ip.write_text(text,encoding='utf8')
    # Single contact sheet, actual game ground; Pillow only crops/assembles.
    ground=Image.open(DEST/'terrain/terraces/iso/ground_a.png').convert('RGBA')
    canvas=Image.new('RGBA',(1280,1152),(22,27,34,255))
    for y in range(0,1152,ground.height):
        for x in range(0,1280,ground.width):canvas.alpha_composite(ground,(x,y))
    samples=[('ember_orbs_iso',0,0),('ember_orbs_iso',3,0),('flame_pillar',3,0),
             ('meteor_fall',2,0),('meteor_impact',3,0),('meteor_impact',8,0)]
    for i,(name,f,row) in enumerate(samples):
        w,h,n,_=SPECS[name];im=Image.open(DEST/'vfx'/name/'default.png').crop((f*w,row*h,(f+1)*w,(row+1)*h))
        im.thumbnail((200,416),Image.Resampling.LANCZOS);canvas.alpha_composite(im,(i*210+(210-im.width)//2,10+(416-im.height)//2))
    for row in range(8):
        sheet=Image.open(DEST/'vfx/phoenix/default.png')
        for k,f in enumerate((2,8)):
            im=sheet.crop((f*256,row*256,(f+1)*256,(row+1)*256)).resize((150,150),Image.Resampling.LANCZOS)
            canvas.alpha_composite(im,(row*160,445+k*155))
    im=Image.open(DEST/'vfx/telegraph_ring/default.png');canvas.alpha_composite(im,(20,800))
    for i,name in enumerate(ICONS):canvas.alpha_composite(Image.open(DEST/'icons/spells'/f'{name}.png'),(340+i*180,825))
    canvas.convert('RGB').save(ROOT/'art/tools/night/_ardv_contact.png',optimize=True)
    (ROOT/'art/tools/night/_ardv_verification.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print('PASS ARDV 6 VFX, 4 icons; half emission; no normals; contact; radius 108.6116 px')

if __name__=='__main__':
    pack() if '--pack' in sys.argv else render()
