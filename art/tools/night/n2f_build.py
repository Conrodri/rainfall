"""N2F: targeted extension of N2C geometry; background Eevee, shared boss cel.
System: --prepare, --verify, --contact. Blender: -- [--resume] [--anims ...].
Pillow is restricted to packing/resampling and contact assembly/inspection.
"""
import sys, math, json, re, tempfile, argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/cel')]
if '--background' in sys.argv:sys.path.insert(0,str(ROOT/'art/tools/iso/_deps'))
import n2c_build as old
import cel_style as cel
OUT=old.OUT
CONTACT=ROOT/'art/tools/night/_n2f_contact.png'
SPECS={**{f'idle_p{p}':(6,['e','s','w','n'],256) for p in (1,2,3)},
       **{f'walk_p{p}':(8,['e','s','w','n'],256) for p in (1,2,3)},
       **{a:(n,['s'],256) for a,n in [('auto',6),('spell_a',8),('spell_b',8),('ascend',8),('drop',8),('lay',8),('trans_p2',8),('trans_p3',8),('death',10)]},
       **{a+'_dirs':(n,['e','w','n'],256) for a,n in [('auto',6),('spell_a',8),('spell_b',8)]},
       'thread':(4,['s'],(768,64)), 'cocoon':(6,['s'],(96,160)),
       'drop_dust':(6,['s'],192),'web':(4,['s'],768),
       'ground_silk':(6,['s'],136)}
EXTRAS={'thread','cocoon','drop_dust','web','ground_silk'}

def emission_visible(image):
    import numpy as np
    pixels=np.asarray(image.convert('RGBA'),dtype=np.float32)/255
    return float(((pixels[:,:,:3] @ np.array([.2126,.7152,.0722]))*pixels[:,:,3]).max())>2/255


def prepare():
    cel.archive_folder('bosses/etage/weaver')
    print('PASS archive N2C preserved',flush=True)

def build():
    # Reuse the delivered articulated N2C model, correcting only its material/concept mismatches.
    text=(ROOT/'art/tools/night/n2c_build.py').read_text(encoding='utf-8')
    src=text[text.index('def build():'):text.index('\ndef extra(')]
    replacements={
        "s.eevee.taa_render_samples=12":"s.eevee.taa_render_samples=8",
        "'151B19','4F5141'":"'514B3D','A99A7B'",
        "'303E36','899382'":"'666B59','C7C6A3'",
        "'121919','424F48'":"'3E554C','8DBBA8'",
        "'363E37','A4AA91'":"'737F78','B8C8C0'",
        "'1B241B','4C5840'":"'46513E','7F896D'",
        "(.25,.57,.39)":"(.33245,.87137,.57758)",
        "'Waterlogged split yew'":"'Polished cedar heartwood'",
        "'Lichen stained ceramic reliquary'":"'Torn oiled votive paper'",
        "'Corroded iron braces'":"'Verdigris bronze collars'",
        "'Cracked ceramic shutter":"'Torn sanctuary paper panel",
        "'Ceramic thickness'":"'Paper thickness'",
        "thickness=.035":"thickness=.012",
        "'Forged lantern rib'":"'Cedar lantern rib'",
        "],.028,iron,abd)":"],.028,wood,abd)",
        "'Overlapping thoracic scute'":"'Cedar altar step'",
        "(.35-k*.035,.18,.15),bone,body)":"(.35-k*.035,.18,.15),wood,body)",
        "],bone,head,.015)":"],wood,head,.015)",
        "],iron,abd,.012)": "],wood,abd,.012)",
        "(.12,.16,.18),silk,body)":"(.12,.16,.18),glow,body)",
        "    iso.bake_ao_shadows(root)":"    # Cel replaces procedural grain/AO shading.",
        "        glow.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value=1.1+.5*(ph-1)+.13*math.sin(cy)":"        pass # emission animated by the N2F wrapper after toon conversion",
    }
    for a,b in replacements.items():src=src.replace(a,b)
    # Existing jaw rig and all eight leg hierarchies remain intact.
    exec(compile(src,str(Path(__file__)), 'exec'),old.__dict__)
    root,basepose,mats=old.build()
    bpy=old.bpy;c=old.c;V=old.Vector;s=bpy.context.scene
    body=bpy.data.objects['Thorax'];abd=bpy.data.objects['Lantern abdomen'];head=bpy.data.objects['Narrow death mask']
    for side in (-1,1):
        old.rod('Additional mint eye slit',[(side*.055,-.253,-.045),(side*.11,-.227,-.030)],.014,mats['glow'],head)
    # Phase 2 taut spinnerets; phase 3 broken paper, escaping flame and dragging leg.
    taut=[];rags=[];leaks=[]
    for j in range(9):
        a=j*math.tau/9
        taut.append(old.rod('Taut spinneret silk',[(0,.99,.94),(1.20*math.cos(a),.45+1.05*math.sin(a),.04)],.009,mats['silk'],body))
    for j in range(7):
        a=j*2.399
        x,y=.58*math.cos(a),.70*math.sin(a)
        rags.append(old.mesh('Burst votive paper',[(x,y,.22),(x*1.25,y*1.25,.44),(x*1.31-.08,y*1.32,.57),(x-.10,y,.31)],[(0,1,2,3)],mats['bone'],abd,.002))
        leaks.append(old.rod('Escaping foxfire tongue',[(x*.30,y*.4,.10),(x*.8,y*.8,.47),(x,y,.73),(x+.04,y,.88)],.035,mats['glow'],abd))
    jets=[]
    for side in (-1,0,1):
        jets.append(old.rod('Three thrown silk streams',[(0,.83,1.17),(side*.34,.20,1.38),(side*.62,-.76,1.24),(side*.84,-1.20,.83)],.013,mats['silk'],body))
    suspension=old.rod('Canopy suspension silk',[(0,.6,1.6),(0,.6,7)],.012,mats['silk'],root)
    dust=[]
    for j in range(22):
        a=j*2.399
        ob=c.sphere('Landing mist and torn silk',(1.1*math.cos(a),1.1*math.sin(a),.03),(.095,.032,.022),mats['silk'],root)
        ob.rotation_euler.z=a;dust.append(ob)
    # Cold high-left silhouette light and mint bounce from inside the lantern.
    for name,pos,color,energy,size in [('Cold silhouette',(-3,-1,5),(.57,.76,1),500,3),('Mint lantern bounce',(0,.45,.57),(.33,.87,.58),32,1)]:
        data=bpy.data.lights.new(name,'AREA' if size>1 else 'POINT');data.energy=energy;data.color=color
        if data.type=='AREA':data.shape='DISK';data.size=size
        ob=bpy.data.objects.new(name,data);s.collection.objects.link(ob);ob.location=pos
        if data.type=='AREA':ob.rotation_euler=(V((0,0,.7))-ob.location).to_track_quat('-Z','Y').to_euler()
    # Fixed camera scale across all directions, feet at the declared bottom=210.
    basepose('idle_p1',0,6);root.rotation_euler.z=0
    for ob in [*taut,*rags,*leaks,*jets,*dust,suspension]:ob.hide_render=True
    bpy.context.view_layer.update()
    basis=s.camera.rotation_euler.to_matrix();inverse=basis.transposed()
    camframes={};maxdim=0
    for d in ('e','s','w','n'):
        root.rotation_euler.z=c.DIRECTIONS[d];bpy.context.view_layer.update()
        points=[inverse@(ob.matrix_world@v.co) for ob in root.children_recursive if ob.type=='MESH' and not ob.hide_render for v in ob.data.vertices]
        lo=min(p.y for p in points);hi=max(p.y for p in points)
        left=min(p.x for p in points);right=max(p.x for p in points)
        camframes[d]=((left+right)/2,lo);maxdim=max(maxdim,right-left,hi-lo)
    scale=maxdim*256/180
    s.camera.data.ortho_scale=scale;s['iso_frame']=[256,256]
    s.render.resolution_x=s.render.resolution_y=512
    s['ground_pivot']=[128,210];s['n2f_contract']=json.dumps(SPECS);s['render_style']='cel boss'
    legs=[ob for ob in root.children_recursive if ob.name.startswith('Leg ')]
    lower=bpy.data.objects.get('Patella.007')
    def emission(strength):
        nodes=mats['glow'].node_tree.nodes
        for node in nodes:
            if node.type=='EMISSION':node.inputs['Strength'].default_value=strength
            if node.type=='OUTPUT_AOV':node.inputs['Color'].default_value=tuple(v*strength for v in (.33245,.87137,.57758))+(1,)
        p=nodes.get('Principled BSDF')
        if p:p.inputs['Emission Strength'].default_value=strength
    def pose(a,i,n):
        t=i/max(1,n-1);cy=i/n*math.tau
        ph=int(a[-1]) if a.startswith(('idle_p','walk_p')) else (2 if a=='trans_p2' else 3 if a in ('trans_p3','lay','death') else 1)
        basepose(a,i,n)
        root.scale=(1,1,1)
        # Exact integer impact indices: 3/6 and 4/8, zero-based as EnemyVisual.
        impact=3 if a=='auto' else 4
        peak=max(0,1-abs(i-impact)/(impact if i<=impact else max(1,n-1-impact)))
        for ob in taut:ob.hide_render=ph<2
        for ob in [*rags,*leaks]:ob.hide_render=ph<3
        for ob in jets:ob.hide_render=a!='spell_a' or i not in (3,4,5)
        for ob in dust:
            ob.hide_render=a!='drop' or i not in (4,5,6)
            factor=1-.24*max(0,i-4)
            ob.scale=(.095*factor,.032*factor,.022*factor)
        suspension.hide_render=a not in ('ascend','spell_b')
        for ob in leaks:ob.scale=(1,1,.8+.2*math.sin(cy))
        for ob in legs:
            if ph==3 and ob.name.startswith('Leg 1 3'):
                ob.rotation_euler.y=.62;ob.rotation_euler.z=-.18
        if lower and ph==3:lower.rotation_euler.y=-.85
        if a=='auto':
            body.location.z=.20*peak;body.location.y=-.30*peak
            head.rotation_euler.x=-.50*peak
            for ob in legs:
                if ob.name.endswith(' 0'):ob.rotation_euler.x=-.46*peak
            for ob in head.children:
                if ob.name.startswith('Hooked mandible'):ob.rotation_euler.z=(1 if ob.location.x>0 else -1)*(-.65*peak)
        if a=='spell_a':abd.rotation_euler.x=-.68*peak;body.location.z=.10*peak
        if a in ('ascend','spell_b'):
            heights=([0,-.12,-.18,-.10,.22,.70,1.65,2.4] if a=='spell_b' else [0,.12,.35,.70,1.2,1.8,2.5,4.4])
            body.location.z=heights[i];root.scale=(1,1,1) if not(a=='ascend' and i==7) else (0,0,0)
        if a=='drop':
            body.location.z=[4.0,2.5,1.5,.65,-.16,-.07,.02,0][i]
            for ob in legs:ob.rotation_euler.y=(-1 if ob.location.x>0 else 1)*.30*peak
        if a=='lay':abd.location.z=1.15-.62*peak;abd.rotation_euler.x=.27*peak
        else:abd.location.z=1.15
        if a=='trans_p2':
            for ob in taut:ob.hide_render=i<2;ob.scale=(.4+.6*peak,)*3
        else:
            for ob in taut:ob.scale=(1,1,1)
        if a=='trans_p3':
            for ob in [*rags,*leaks]:ob.hide_render=i<3
        strength=(.55+.4*(ph-1))*(1+.09*math.sin(cy))
        if a=='death':strength*=1 if i<6 else max(0,(9-i)/3)
        emission(strength)
    def camera(d):
        x,lo=camframes[d]
        s.camera.location=basis@V((x,lo+82/256*scale,12))
    return root,pose,mats,camera,emission

def extra(a,mats):
    bpy=old.bpy;c=old.c;s=bpy.context.scene;V=old.Vector
    root=c.empty('N2F_'+a);w,h=old.dims(SPECS[a][2]);s['iso_frame']=[w,h]
    s.render.resolution_x=w*2;s.render.resolution_y=h*2
    s.camera.data.ortho_scale=w/64;s.camera.location=(0,0,12);s.camera.rotation_euler=(0,0,0)
    moving=[]
    if a in ('thread','ground_silk'):
        half=6 if a=='thread' else 1
        for k in range(5):
            pts=[(-half+2*half*j/32,(k-2)*.035+.023*math.sin(j*.7+k),.02) for j in range(33)]
            moving.append(old.rod('Spun silk strand',pts,.011,mats['silk'],root))
        for k in range(16 if a=='thread' else 4):
            x=-half+.09+(2*half-.18)*k/(15 if a=='thread' else 3)
            c.sphere('Mint dew bead',(x,.045*math.sin(k),.05),(.026,.033,.026),mats['glow'],root)
    elif a=='web':
        # Chord opening 3.6 units on the outer 6-unit radius, centered on +/-X.
        gap=math.asin(1.8/6)
        for r in (4.75,5.12,5.48,5.83,5.96):
            for start,end in ((gap,math.pi-gap),(math.pi+gap,math.tau-gap)):
                pts=[(r*math.cos(start+(end-start)*j/96),r*math.sin(start+(end-start)*j/96),.02) for j in range(97)]
                old.rod('Breach web concentric silk',pts,.019 if r>5.8 else .011,mats['silk'],root)
        for j in range(80):
            angle=j*math.tau/80
            if abs(math.sin(angle))<math.sin(gap):continue
            old.rod('Web radial tension',[(r*math.cos(angle+.006*math.sin(r*9)),r*math.sin(angle+.006*math.sin(r*9)),.02) for r in (4.7,5.1,5.5,5.97)],.012,mats['silk'],root)
            if j%3==0:c.sphere('Web dew knot',(5.84*math.cos(angle),5.84*math.sin(angle),.035),(.027,.027,.025),mats['glow'],root)
    elif a=='cocoon':
        s.camera.rotation_euler=(math.pi/3,0,0);basis=s.camera.rotation_euler.to_matrix()
        s.camera.data.ortho_scale=w/90.5
        s.camera.location=basis@V((0,(h/2-5)/90.5,12))
        c.sphere('Translucent mint brood heart',(0,0,.77),(.20,.19,.51),mats['glow'],root)
        for j in range(18):
            aa=j*math.tau/18
            pts=[]
            for k in range(21):
                z=.03+k*.078;r=.36*math.sin(k/20*math.pi)**.65;angle=aa+z*2.9
                pts.append((r*math.cos(angle),r*math.sin(angle),z))
            old.rod('Cocoon spiral wrap',pts,.019,mats['silk'],root)
        for k in range(13):
            z=.10+k*.11;r=.365*math.sin((z-.03)/1.56*math.pi)**.65
            old.rod('Cocoon binding',[(r*math.cos(j*math.tau/36),r*math.sin(j*math.tau/36),z+.015*math.sin(j)) for j in range(37)],.010,mats['silk'],root)
    elif a=='drop_dust':
        for j in range(38):
            angle=j*2.399
            ob=c.sphere('Mist dust splinter',(0,0,0),(.11,.045,.025),mats['silk'] if j%3 else mats['wood'],root)
            ob.rotation_euler.z=angle;moving.append((ob,angle,j))
        for j in range(14):
            angle=j*math.tau/14
            pts=[(r*math.cos(angle+.08*math.sin(r*12)),r*math.sin(angle+.08*math.sin(r*12)),.02) for r in (.25,.50,.8,1.05)]
            ob=old.rod('Dispersing torn silk',pts,.012,mats['silk'],root);moving.append((ob,angle,j+40))
    def pose(_,i,n):
        cy=i/n*math.tau;t=i/max(1,n-1);wave=math.sin(cy+.35)
        root.scale=(1,1,1);root.rotation_euler.z=0
        if a in ('thread','ground_silk'):root.scale.y=1+.09*wave
        if a=='web':root.scale=(1-.0015*(1+wave),)*3
        if a=='cocoon':root.scale=(1+.024*wave,1+.024*wave,1-.012*wave)
        if a=='drop_dust':
            for ob,angle,j in moving:
                if j<40:
                    r=.20+1.15*t;ob.location=(r*math.cos(angle),r*math.sin(angle),.01)
                    factor=max(.10,1-t);ob.scale=(.11*factor,.045*factor,.025*factor)
                else:ob.scale=(.30+.95*t,)*3
            if i==n-1:root.scale=(0,0,0)
    return root,pose

def render(args):
    from PIL import Image
    prepare()
    root,pose,mats,camera,emit=build();bpy=old.bpy;c=old.c;s=bpy.context.scene
    cel.install('boss', normals=False)
    # Save the corrected source only under art/blender, with all body animation keys.
    if not args.resume:
        f=1
        for a,(n,ds,size) in SPECS.items():
            if a in EXTRAS or a.endswith('_dirs'):continue
            s.timeline_markers.new(a,frame=f)
            for i in range(n):
                pose(a,i,n)
                for ob in [root,*root.children_recursive]:
                    for prop in ('location','rotation_euler','scale','hide_render'):ob.keyframe_insert(prop,frame=f+i)
            f+=n+2
        s.frame_end=f;pose('idle_p1',0,6);root.rotation_euler.z=0;camera('s')
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(old.SOURCE),check_existing=False)
        for ob in [root,*root.children_recursive]:ob.animation_data_clear()
    bodyroot=root;bodypose=pose
    with tempfile.TemporaryDirectory(prefix='rainfall_n2f_') as tmp:
        for a,(n,ds,size) in SPECS.items():
            if args.anims and a not in args.anims:continue
            if args.resume and (OUT/(a+'.n2f.done')).exists():continue
            # Silk VFX use the same boss tones; no silhouette erosion on
            # sub-2px fibers (STYLE_cel VFX rule). Solid cocoon keeps boss ink.
            cel.install(dict(cel.profile('boss'),ink_px=0,creases=False) if a in EXTRAS-{'cocoon'} else 'boss', normals=False)
            w,h=old.dims(size)
            # Original filenames are retained; contract corrections are necessary for N2C extras.
            boards=[Image.new('RGBA',(w*n,h*len(ds)),(0,0,0,0)) for _ in range(2)]
            if a in EXTRAS:
                for ob in [bodyroot,*bodyroot.children_recursive]:ob.hide_render=True
                root,pose=extra(a,mats)
            else:root,pose=bodyroot,bodypose
            for row,d in enumerate(ds):
                for i in range(n):
                    if a not in EXTRAS:
                        s['iso_frame']=[256,256];s.render.resolution_x=s.render.resolution_y=512
                        s.camera.rotation_euler=(math.pi/3,0,0);s.camera.data.ortho_scale=s.get('n2f_camera_scale',s.camera.data.ortho_scale)
                        camera(d)
                    path=Path(tmp)/'frame.png'
                    def apply(_):
                        pose(a.removesuffix('_dirs'),i,n)
                        if a=='drop' and i>=4:
                            # Spreading the legs lifts the tips: lower the body so
                            # impact frame 4 actually touches the same ground line.
                            old.bpy.context.view_layer.update()
                            inv=s.camera.rotation_euler.to_matrix().transposed()
                            lo=min((inv@(ob.matrix_world@v.co)).y for ob in root.children_recursive if ob.type=='MESH' and not ob.hide_render and ob.name.startswith('Tapered tibia') for v in ob.data.vertices)
                            target=(inv@s.camera.location).y-82/256*s.camera.data.ortho_scale
                            old.bpy.data.objects['Thorax'].location.z+=(target-lo)/math.cos(math.pi/6)
                        if a in EXTRAS:emit(.60+.15*math.sin(i/n*math.tau))
                    c.render_still(root,apply,path,0,d)
                    ims=[]
                    for suf in ('','_e'):
                        with Image.open(path.with_name('frame'+suf+'.png')) as im:ims.append(im.convert('RGBA').resize((w,h),Image.Resampling.LANCZOS))
                    alpha=ims[0].getchannel('A')
                    for k,im in enumerate(ims):im.putalpha(alpha);boards[k].paste(im,(i*w,row*h))
            for suf,im in zip(('','_e'),boards):
                if suf and not emission_visible(im):
                    (OUT/(a+suf+'.png')).unlink(missing_ok=True)
                    (OUT/(a+suf+'.png.import')).unlink(missing_ok=True)
                    continue
                im.save(OUT/(a+suf+'.png'),compress_level=9)
            (OUT/(a+'.n2f.done')).write_text('cel boss 2x, N2F')
            if a in EXTRAS:
                for ob in [root,*root.children_recursive]:ob.hide_render=True
            print('N2F DONE '+a,flush=True)
    if all((OUT/(a+'.n2f.done')).exists() for a in SPECS):
        finish()

def contact():
    from PIL import Image
    rows=[]
    for p in (1,2,3):rows.append([(f'idle_p{p}',d,0) for d in range(4)])
    rows.append([('auto',0,3),('spell_a',0,4),('spell_b',0,4),('drop',0,4)])
    rows.append([('ascend',0,5),('lay',0,4),('trans_p3',0,4),('death',0,9)])
    board=Image.new('RGBA',(1152,1664),'#3E4A3F')
    for row,samples in enumerate(rows):
        for col,(a,d,i) in enumerate(samples):
            with Image.open(OUT/(a+'.png')) as im:
                cell=im.crop((i*256,d*256,(i+1)*256,(d+1)*256))
                board.alpha_composite(cell,(col*288+16,row*240))
    for a,x,y,frame in [('web',0,1210,1),('thread',395,1220,1),('cocoon',480,1330,2),('drop_dust',690,1370,2),('ground_silk',930,1380,2)]:
        n,ds,size=SPECS[a];w,h=old.dims(size)
        with Image.open(OUT/(a+'.png')) as im:cell=im.crop((frame*w,0,(frame+1)*w,h))
        if a=='web':cell.thumbnail((384,384),Image.Resampling.LANCZOS)
        if a=='thread':cell.thumbnail((740,64),Image.Resampling.LANCZOS)
        board.alpha_composite(cell,(x,y))
    board.convert('RGB').save(CONTACT,compress_level=9)
    print('PASS contact',flush=True)

def verify():
    from PIL import Image
    import numpy as np
    fails=[];stats={}
    for a,(n,ds,size) in SPECS.items():
        w,h=old.dims(size)
        im=Image.open(OUT/(a+'.png')).convert('RGBA')
        if im.size!=(n*w,len(ds)*h) or max(im.size)>4096:fails.append(a+':size')
        arrays=[np.asarray(im)];alpha=arrays[0][:,:,3]
        ep=OUT/(a+'_e.png')
        if ep.exists():
            with Image.open(ep) as emission:
                if emission.size not in (im.size,((im.width+1)//2,(im.height+1)//2)):fails.append(a+':emission size')
                if not emission_visible(emission):fails.append(a+':black emission')
        elif a!='drop_dust':fails.append(a+':missing accent')
        if a.startswith('idle'):
            mask=alpha>250
            mean=float(arrays[0][:,:,:3][mask].mean());stats[a]=round(mean,1)
            if mean<90:fails.append(a+':luma')
        if a=='ascend' and alpha[:,-256:].max()>0:fails.append('ascend:last not empty')
        for row in range(len(ds)):
            for i in range(n):
                frame=alpha[row*h:(row+1)*h,i*w:(i+1)*w]
                if not frame.any() and not(a=='ascend' and i==7 or a=='drop' and i==0 or a=='drop_dust' and i==n-1):fails.append(f'{a}:{row}:{i} empty')
    if list(OUT.glob('*_n.png')):fails.append('forbidden normal maps')
    tres=(OUT/'weaver.tres').read_text(encoding='utf-8')
    if 'CanvasTexture' in tres or 'normal_texture' in tres:fails.append('normal references in tres')
    data={'result':'FAIL' if fails else 'PASS','failures':fails,'body_rgb_mean':stats,'sheets':len(SPECS),'frames':sum(n*len(ds) for n,ds,size in SPECS.values())}
    (OUT/'n2f_verification.json').write_text(json.dumps(data,indent=2))
    print(json.dumps(data),flush=True)
    if fails:raise RuntimeError('N2F validation failed')

def finish():
    # Correct frame counts fit in one atlas; the two obsolete overflow pages have
    # no AtlasTexture references in the new SpriteFrames.
    for name in ('thread_2','web_2'):
        for suffix in ('','_e'):
            for ending in ('.png','.png.import'):
                path=OUT/(name+suffix+ending)
                if path.exists():path.unlink()
    old.SPECS=SPECS;old.write_tres();old.write_imports()
    contact();verify()
    (OUT/'manifest.md').write_text(
        'N2F — La Tisseuse, cel boss\n\n'
        'N2C conserved: articulated eight-leg geometry, sanctuary roof, lantern cage, jaw and leg rigs. '
        'All sheets previously re-rendered with shared boss cel, Eevee8, transparent 2x/LANCZOS. No normal maps; emission at half resolution. '
        'Cedar altar and ribs, oiled torn paper, verdigris collars; four mint eyes, cold upper-left rim. '
        'Phase2 taut spinnerets; phase3 paper shards, escaping mint flame, brood and dragging broken leg. '
        'Idle and walk four directions e,s,w,n; body 256px, dim180, solid feet bottom210. '
        'Impacts at zero-based auto3/6 and spells4/8, drop4/8. Ascend last frame empty; lay added. '
        'Extras corrected: thread768x64/4, cocoon96x160/6 billboard90.5px/u, dust192/6, web768/4 top64px/u; '
        'web radius6, two3.6u breaches on +/-X. ground_silk retained. '
        'Necessary SpriteFrames edits add missing directions/lay and correct extra regions/counts; obsolete overflow atlas pages retired. '
        'Original N2C preserved by cel.archive_folder in art/archive_3d. '
        'Source art/blender/monsters/weaver_iso.blend; script art/tools/night/n2f_build.py; '
        'contact art/tools/night/_n2f_contact.png; quantitative checks n2f_verification.json.\n',encoding='utf-8')
    print('PASS finish',flush=True)

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--prepare',action='store_true');ap.add_argument('--verify',action='store_true');ap.add_argument('--contact',action='store_true');ap.add_argument('--finish',action='store_true');ap.add_argument('--resume',action='store_true');ap.add_argument('--anims',nargs='*')
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ([] if '--background' in sys.argv else sys.argv[1:]))
    if args.prepare:prepare()
    elif args.verify:verify()
    elif args.contact:contact()
    elif args.finish:finish()
    else:render(args)
