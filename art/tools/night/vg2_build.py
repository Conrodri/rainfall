"""VG2: Blender-only geometry; shared VG1 rig/CEL. Pillow packs/crops/checks only.
Blender --background --python vg2_build.py -- --render; Python --finish/--verify.
Raw pairs resume in TEMP/Rainfall_VG2; no normal output is ever configured.
"""
import sys, math, json, tempfile, hashlib
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
DEST=ROOT/'game/assets/sprites/characters'
RAW=Path(tempfile.gettempdir())/'Rainfall_VG2'
SOURCE=ROOT/'art/blender/characters'
sys.path[:0]=[str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel')]
TAU=math.tau
SPECS={
 'arrow':((96,32),{'default':(4,True,12)},'CREA',64*math.sqrt(2)),
 'arrow_charged':((160,48),{'default':(4,True,12)},'CREA',64*math.sqrt(2)),
 'flare_arrow':((128,48),{'default':(4,True,12)},'CREA',64*math.sqrt(2)),
 'net_arrow':((128,48),{'default':(4,True,12)},'CREA',64*math.sqrt(2)),
 'flare':((128,192),{'default':(6,True,12),'end':(4,False,10)},'CREA',64*math.sqrt(2)),
 'net_burst':((640,640),{'default':(6,False,12)},'TOP',96),
 'hail_zone':((640,640),{'default':(8,True,12),'end':(4,False,10)},'TOP',64),
}

def pages(n,w):
    cols=min(n,4 if w==640 else n)
    return cols,math.ceil(n/cols)

def resource(folder,name):
    size,anims,_,_=SPECS[name];w,h=size;ex=[];subs=[];animations=[];idx=0
    for ai,(a,(n,loop,fps)) in enumerate(anims.items()):
        ex.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/characters/{folder.parent.name}/{name}/{a}.png" id="{ai+1}"]')
        cols,_=pages(n,w);frames=[]
        for f in range(n):
            idx+=1
            subs.append(f'[sub_resource type="AtlasTexture" id="a{idx}"]\natlas = ExtResource("{ai+1}")\nregion = Rect2({f%cols*w}, {f//cols*h}, {w}, {h})')
            frames.append('{"duration": 1.0, "texture": SubResource("a'+str(idx)+'")}')
        animations.append('{"frames": ['+', '.join(frames)+'], "loop": '+str(loop).lower()+', "name": &"'+a+'", "speed": '+str(fps)+'.0}')
    p=folder/(name+'.tres')
    text=f'[gd_resource type="SpriteFrames" load_steps={len(ex)+len(subs)+1} format=3]\n\n'+'\n\n'.join(ex+subs)+'\n\n[resource]\nanimations = ['+',\n'.join(animations)+']\n'
    if not p.exists() or p.read_text(encoding='utf8')!=text:p.write_text(text,encoding='utf8')

def finish():
    from PIL import Image
    for name,(size,anims,rig,ppu) in SPECS.items():
        w,h=size
        for a,(n,loop,fps) in anims.items():
            cols,rows=pages(n,w)
            for suffix in ('','_e'):
                sheet=Image.new('RGBA',(w*cols,h*rows))
                for f in range(n):
                    with Image.open(RAW/f'{name}_{a}_{f:02d}{suffix}.png') as im:
                        assert im.size==size
                        sheet.paste(im,(f%cols*w,f//cols*h))
                if suffix:
                    if max(c.getextrema()[1] for c in sheet.split()[:3])<2:continue
                    sheet=sheet.resize(((sheet.width+1)//2,(sheet.height+1)//2),Image.Resampling.LANCZOS)
                for style in ('vigie','vigie_cel'):
                    folder=DEST/style/name;folder.mkdir(parents=True,exist_ok=True)
                    sheet.save(folder/(a+suffix+'.png'),optimize=True,compress_level=9)
        for style in ('vigie','vigie_cel'):resource(DEST/style/name,name)
    with Image.open(RAW/'portrait.png') as im:
        im.save(DEST/'vigie/portrait.png',optimize=True)
    with Image.open(RAW/'portrait_e.png') as im:
        im.resize((128,128),Image.Resampling.LANCZOS).save(DEST/'vigie/portrait_e.png',optimize=True)
    contact();verify()

def contact():
    from PIL import Image
    # Native frame scale; game floor, crops and assembly only.
    canvas=Image.new('RGBA',(1920,2304),(17,23,28,255))
    with Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png') as im:tile=im.convert('RGBA')
    for y in range(0,canvas.height,tile.height//2):
        for x in range(0,canvas.width,tile.width):canvas.alpha_composite(tile,(x,y))
    canvas.alpha_composite(Image.new('RGBA',canvas.size,(4,8,12,155)))
    for row,name in enumerate(SPECS):
        size,anims,_,_=SPECS[name];w,h=size
        y=row*192 if row<5 else 960+(row-5)*640
        with Image.open(DEST/'vigie'/name/'default.png') as im:
            n=anims['default'][0];cols,_=pages(n,w)
            for j,f in enumerate((0,n//2,n-1)):
                fr=im.crop((f%cols*w,f//cols*h,(f%cols+1)*w,(f//cols+1)*h))
                canvas.alpha_composite(fr,(j*640+(640-w)//2,y+(192-h)//2 if row<5 else y))
    with Image.open(DEST/'vigie/portrait.png') as im:canvas.alpha_composite(im,(1664,32))
    # Icons belong to group 17; read only when available.
    for i,key in enumerate(('trait','fusee','filet','grele')):
        p=ROOT/f'game/assets/sprites/icons/spells/vigie_{key}.png'
        if p.exists():
            with Image.open(p) as im:canvas.alpha_composite(im.convert('RGBA'),(1664,320+i*144))
    canvas.convert('RGB').save(HERE/'_vg2_contact.png',optimize=True)

def verify():
    from PIL import Image
    import cel_style as cel
    stats=[]
    for name,(size,anims,rig,ppu) in SPECS.items():
        w,h=size
        for style in ('vigie','vigie_cel'):
            folder=DEST/style/name
            assert not list(folder.glob('*_n.png'))
            tres=(folder/(name+'.tres')).read_text()
            assert 'CanvasTexture' not in tres and 'normal_texture' not in tres
            for a,(n,loop,fps) in anims.items():
                cols,rows=pages(n,w);p=folder/(a+'.png');e=folder/(a+'_e.png')
                cel.check_sheet(str(p.relative_to(ROOT/'game/assets/sprites')).replace('\\','/'),normals=False,emission=e.exists())
                with Image.open(p) as im:
                    assert im.size==(cols*w,rows*h) and max(im.size)<=4096
                    hashes=set();boxes=[]
                    for f in range(n):
                        fr=im.crop((f%cols*w,f//cols*h,(f%cols+1)*w,(f//cols+1)*h))
                        b=fr.getchannel('A').point(lambda x:255 if x>12 else 0).getbbox()
                        assert b,(name,a,f,'EMPTY');boxes.append(b)
                        if name=='flare':assert b[0]>=2 and b[2]<=w-2 and b[1]>=2,(name,a,f,b)
                        else:assert min(b[:2])>=2 and b[2]<=w-2 and b[3]<=h-2,(name,a,f,b)
                        hashes.add(hashlib.sha256(fr.tobytes()).hexdigest())
                    assert len(hashes)==n,(name,a,'DUPLICATE FRAMES')
                    if e.exists():
                        with Image.open(e) as em:
                            assert em.size==((im.width+1)//2,(im.height+1)//2)
                            assert max(c.getextrema()[1] for c in em.split()[:3])>2
                    if style=='vigie':stats.append(dict(asset=name,animation=a,frames=n,size=im.size,boxes=boxes,emission=e.exists()))
                for p in folder.glob(a+'*.png'):
                    other=DEST/('vigie_cel' if style=='vigie' else 'vigie')/name/p.name
                    assert p.read_bytes()==other.read_bytes(),str(p)
    with Image.open(DEST/'vigie/portrait.png') as im,Image.open(DEST/'averse/portrait.png') as ref:assert im.size==ref.size==(256,256)
    (HERE/'_vg2_verification.json').write_text(json.dumps(stats,indent=2),encoding='utf8')
    print('VG2 VERIFY PASS: 44 FX frames + portrait; 7 resources/style; no normals; half emission',flush=True)

def render_all():
    import bpy,random
    import iso_rig,cel_style as cel
    from mathutils import Vector
    from PIL import Image
    common=iso_rig.common
    RAW.mkdir(exist_ok=True,parents=True)
    # Shared CEL compositor/AOV implementation, adapted from VG1 accent_base.
    def passes(path):
        tree=bpy.data.node_groups.new('VG2 accent only','CompositorNodeTree');s.compositing_node_group=tree
        tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
        nodes=tree.nodes;links=tree.links;r=nodes.new('CompositorNodeRLayers');out=nodes.new('NodeGroupOutput');links.new(r.outputs['Image'],out.inputs['Image'])
        file=nodes.new('CompositorNodeOutputFile');file.directory=str(path.parent);file.file_name=path.stem+'_e__';file.file_output_items.new('RGBA','Image')
        file.format.media_type='IMAGE';file.format.file_format='PNG';file.format.color_mode='RGBA';file.format.color_depth='8'
        links.new(r.outputs[cel.AOV],file.inputs[0])
    def render_pair(stem,size,prof):
        target=RAW/(stem+'.png');ep=RAW/(stem+'_e.png')
        if '--rebuild' not in sys.argv and target.exists() and ep.exists():return
        out=RAW/'current.png';cel.cel_passes(out,prof,base_configure=passes,normals=False)
        s.render.filepath=str(out);bpy.ops.render.render(write_still=True)
        files=list(RAW.glob('current_e__*.png'));assert len(files)==1
        for src,dest in ((out,target),(files[0],ep)):
            with Image.open(src) as im:final=im.convert('RGBA').resize(size,Image.Resampling.LANCZOS)
            final.save(dest,compress_level=3);src.unlink()
    def color(h):
        rgb=[int(h[i:i+2],16)/255 for i in (1,3,5)]
        return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb)
    # Geometry batching: rods, ribbons and faceted smoke all remain real Blender meshes.
    class Geo:
        def __init__(self):self.groups={}
        def mesh(self,m,vs,fs,alpha=None):
            v,f,aa=self.groups.setdefault(m,([],[],[]));off=len(v);v.extend([tuple(x) for x in vs]);f.extend([tuple(off+i for i in face) for face in fs]);aa.extend(alpha if alpha is not None else [1.0]*len(vs))
        def rod(self,a,b,r,m,sides=6,r2=None):
            a,b=Vector(a),Vector(b);d=(b-a).normalized();u=d.cross(Vector((0,0,1)))
            if u.length<.01:u=d.cross(Vector((0,1,0)))
            u.normalize();v=d.cross(u);verts=[]
            for p,rr in ((a,r),(b,r if r2 is None else r2)):
                verts.extend([p+rr*(u*math.cos(j*TAU/sides)+v*math.sin(j*TAU/sides)) for j in range(sides)])
            fs=[tuple(range(sides-1,-1,-1)),tuple(range(sides,2*sides))]+[(j,(j+1)%sides,(j+1)%sides+sides,j+sides) for j in range(sides)]
            self.mesh(m,verts,fs)
        def line(self,points,r,m):
            for a,b in zip(points,points[1:]):self.rod(a,b,r,m)
        def shard(self,p,scale,m,angle=0):
            p=Vector(p);sx,sy,sz=scale;vs=[]
            for x,y,z in ((-sx,0,0),(sx,0,0),(0,-sy,0),(0,sy,0),(0,0,-sz),(0,0,sz)):
                vs.append(p+Vector((x*math.cos(angle)-y*math.sin(angle),x*math.sin(angle)+y*math.cos(angle),z)))
            self.mesh(m,vs,[(0,2,4),(2,1,4),(1,3,4),(3,0,4),(0,5,2),(2,5,1),(1,5,3),(3,5,0)])
        def ribbon(self,points,width,m,opacity=1):
            vs=[];aa=[]
            for j,p in enumerate(points):
                t=j/(len(points)-1);ww=width*math.sin(math.pi*t)**.7
                tangent=Vector(points[min(j+1,len(points)-1)])-Vector(points[max(j-1,0)])
                side=Vector((-tangent.y,tangent.x,0)).normalized()
                vs.extend([Vector(p)-side*ww,Vector(p)+side*ww])
                aa.extend([opacity*math.sin(math.pi*t)**.4]*2)
            self.mesh(m,vs,[(2*j,2*j+1,2*j+3,2*j+2) for j in range(len(points)-1)],aa)
        def halo(self,p,rx,ry,m):
            x,y,z=p;vs=[p];aa=[.52];fs=[];n=48
            for radius,alpha in ((.4,.23),(.75,.06),(1,0)):
                for j in range(n):
                    t=j*TAU/n;vs.append((x+rx*radius*math.cos(t),y+ry*radius*math.sin(t),z));aa.append(alpha)
            fs.extend((0,1+j,1+(j+1)%n) for j in range(n))
            for k in range(2):
                a=1+k*n;b=a+n;fs.extend((a+j,a+(j+1)%n,b+(j+1)%n,b+j) for j in range(n))
            self.mesh(m,vs,fs,aa)
        def commit(self,frame,transform):
            objects=[]
            for mat,(vs,fs,aa) in self.groups.items():
                data=bpy.data.meshes.new(f'VG2_{frame}_{mat.name}');data.from_pydata([transform(Vector(v)) for v in vs],[],fs);data.update()
                ob=bpy.data.objects.new(data.name,data);s.collection.objects.link(ob);data.materials.append(mat)
                if mat.get('soft'):
                    attr=data.color_attributes.new(name='Feather',type='FLOAT_COLOR',domain='POINT')
                    for i,a in enumerate(aa):attr.data[i].color=(1,1,1,a)
                for time,hide in ((0,True),(frame,False),(frame+1,True)):
                    ob.hide_render=hide;ob.hide_viewport=hide;ob.keyframe_insert('hide_render',frame=time);ob.keyframe_insert('hide_viewport',frame=time)
                objects.append(ob)
            return objects
    def materials():
        palette={'wood':'#2A2522','copper':'#4F6B5E','rope':'#77715B','tar':'#34352F','lead':'#6A7073','feather':'#738080','water':'#8B9B9E','smoke':'#777A80','soot':'#484C54','red':'#FF3A4F','dim':'#FF3A4F','cool1':'#FF3A4F','cool2':'#FF3A4F','cold':'#593C3F','core':'#FFE3EB','halo':'#FF3A4F','ink':'#211A19'}
        mats={}
        for key,h in palette.items():
            strength={'red':1,'dim':.30,'cool1':.13,'cool2':.045,'core':1.15,'halo':.7}.get(key,0)
            m=common.material('VG2_'+key,color(h),.65 if key in ('lead','copper') else 0,.88,strength,grain=not strength)
            if strength:m['rainfall_emissive']=True
            if key in ('halo','smoke','soot'):m['soft']=True
            mats[key]=m
        return mats
    def feather_material(m):
        # Same per-vertex opacity wrapper as the existing M5FX renderer.
        n=m.node_tree.nodes;l=m.node_tree.links;out=next(x for x in n if x.type=='OUTPUT_MATERIAL')
        src=out.inputs['Surface'].links[0].from_socket
        a=n.new('ShaderNodeVertexColor');a.layer_name='Feather'
        transparent=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader')
        l.new(a.outputs['Alpha'],mix.inputs[0]);l.new(transparent.outputs[0],mix.inputs[1]);l.new(src,mix.inputs[2]);l.new(mix.outputs[0],out.inputs['Surface'])
        aov=next(x for x in n if x.type=='OUTPUT_AOV')
        if max(aov.inputs['Color'].default_value[:3])>0:
            v=n.new('ShaderNodeVectorMath');v.operation='SCALE';v.inputs[0].default_value=aov.inputs['Color'].default_value[:3]
            l.new(a.outputs['Alpha'],v.inputs['Scale']);l.new(v.outputs[0],aov.inputs['Color'])
    def arrow(g,tail,tip,kind='arrow',phase=0,scale=1):
        a,b=Vector(tail),Vector(tip);d=(b-a).normalized();length=(b-a).length
        side=Vector((-d.y,d.x,0));r=.013*scale
        g.rod(a,b-d*.12*scale,r,M['wood'])
        # Barbed copper ferrule, split broadhead, tarred fletchings.
        g.rod(b-d*.18*scale,b-d*.08*scale,.025*scale,M['copper'])
        g.mesh(M['lead'],[b,b-d*.16*scale+side*.05*scale,b-d*.12*scale,b-d*.16*scale-side*.05*scale,b+Vector((0,0,.023*scale))-d*.11*scale],[(0,1,4),(0,4,3),(1,2,4),(2,3,4)])
        g.rod(b-d*.055*scale,b,.013*scale,M['dim'])
        for sign in (-1,1):
            q=a+d*.04*scale
            g.mesh(M['feather'],[q,q+d*.17*scale,q+d*.11*scale+side*(sign*.055*scale),q-side*(sign*.015*scale)],[(0,1,2,3)])
        for t in (.06,.09,.12):g.rod(a+d*t*scale-side*.022*scale,a+d*t*scale+side*.022*scale,.005*scale,M['rope'])
        if kind=='net_arrow':
            for k in range(7):
                x=a+d*(.06+k*.025)
                g.rod(x-side*.075,x+side*.075,.018,M['tar'])
                g.rod(x-side*.072,x+side*.072,.006,M['rope'])
            for sign in (-1,1):
                pts=[a-d*(.04+j*.04)+side*(sign*(.03+.02*math.sin(j+phase))) for j in range(5)]
                g.line(pts,.008,M['rope']);g.shard(pts[-1],(.024,.033,.024),M['lead'])
    def sparks(g,origin,phase,n,extent):
        rng=random.Random(912)
        for k in range(n):
            age=(rng.random()+phase/TAU)%1;ang=rng.uniform(-1.1,1.1)
            p=Vector(origin)+Vector((math.sin(ang)*extent*age,.08+math.cos(ang)*extent*age,0))
            trail=Vector((math.sin(ang)*.055,.06+age*.04,0))
            g.rod(p-trail,p,.005+(.008*(1-age)),M['red'] if k%4 else M['core'],r2=.001)
    def flame(g,origin,phase,strength=1):
        x,y,z=origin
        g.halo((x,y+.18*strength,z-.2),.23*strength,.38*strength,M['halo'])
        # Torn tongues, varying in width and height; a magnesium heart under crimson scales.
        for i in range(7):
            base=x+(i-3)*.027;h=(.40+.15*math.sin(phase+i*1.7))*strength
            pts=[Vector((base+.04*math.sin(phase*2+j*.7+i)*j/8,y+h*j/8,z+.012*i)) for j in range(9)]
            g.ribbon(pts,.035*strength,M['red'])
        for i in range(3):
            h=(.20+.06*math.cos(phase+i))*strength
            pts=[Vector((x+(i-1)*.025+.018*math.sin(j+phase)*j/7,y+j*h/7,z+.15)) for j in range(8)]
            g.ribbon(pts,.022*strength,M['core'])
    def smoke(g,phase,end=False):
        # Angular spiral curls, never cotton balls; three shaded grey planes per fold.
        for k in range(9):
            t=((k/9+phase/TAU*.32)%1)
            y=.73+t*.87;cx=.06+(.025+.15*t)*math.sin(6*t+phase)
            pts=[Vector((cx+(.035+.075*t)*math.sin(j*.5+phase+k),y+j*.025,-.08-.02*k)) for j in range(11)]
            g.ribbon(pts,.025+.065*t,M['smoke'] if k%3 else M['soot'],.45+.25*(1-t))
    sources=[]
    bpy.context.preferences.filepaths.save_version=0
    for name,(size,anims,rig,ppu) in SPECS.items():
        if '--only' in sys.argv and name!=sys.argv[sys.argv.index('--only')+1]:continue
        # setup_scene.select_all cannot select objects hidden by a previous frame's keys.
        for ob in list(bpy.data.objects):bpy.data.objects.remove(ob,do_unlink=True)
        s=iso_rig.create_rig(rig,size,target=(0,0,0));s.camera.data.ortho_scale=size[0]/ppu;s.camera.data.shift_y=0
        s.render.threads_mode='FIXED';s.render.threads=6;cel.setup_scene(s,samples=16);cel.install('prop',normals=False)
        M=materials();cel.toon_materials('prop');s.render.fps=12
        for m in M.values():
            if m.get('soft'):feather_material(m)
        # Fine ropes/arrow shafts occupy 1-3px: preserve their lit interior under the shared ink.
        prof=cel.profile('prop');prof.update(ink_px=.35 if rig=='TOP' else .6,creases=False)
        # Use CREA camera basis so tips are exactly screen +X, with real 3D cylindrical shading.
        basis=s.camera.rotation_euler.to_matrix()
        if rig=='CREA':
            def transform(v):return basis@Vector((v.x,v.y,v.z))
        else:
            def transform(v):return v
        frame=0;renderlist=[]
        for a,(n,loop,fps) in anims.items():
            for f in range(n):
                frame+=1;phase=TAU*f/n;g=Geo();rng=random.Random(8912)
                if name in ('arrow','arrow_charged','flare_arrow','net_arrow'):
                    cy=.012*math.sin(phase)+.006*math.cos(phase)
                    left,right=(-.45,.45) if name=='arrow' else ((-.18,.66) if name=='arrow_charged' else (-.38,.57))
                    arrow(g,(left,cy,0),(right,cy,0),name,phase,1.18 if name=='arrow_charged' else 1)
                    if name=='arrow_charged':
                        for k in range(4):
                            pts=[Vector((-.82+j*.11,cy+(k-1.5)*.018+.018*math.sin(phase+j*.8+k),-.02-k*.01)) for j in range(12)]
                            g.ribbon(pts,.008 if k else .015,M['red'] if k else M['core'])
                        for k in range(10):
                            t=(k/10+phase/TAU)%1;p=Vector((-.70+t*.6,(.08 if k%2 else -.08)*(1-t),.03))
                            g.shard(p,(.027,.007,.008),M['water'])
                    if name=='flare_arrow':
                        g.rod((.30,cy,0),(.47,cy,0),.035,M['copper'])
                        for k in range(13):
                            t=(k/13+phase/TAU)%1
                            p=Vector((.3-.92*t,cy+math.sin(k*2.4+phase)*.14*t,.025))
                            g.rod(p+Vector((.04,0,0)),p,.008*(1-t)+.002,M['red'] if k%4 else M['core'])
                        g.line([(.3,cy,0),(.26,cy+.08,0),(.20,cy+.09,0)],.012,M['red'])
                elif name=='flare':
                    # Bottom-centre point of impact, no baked ground or range circle.
                    off=-size[1]/(2*ppu)
                    g.rod((-.04,off+.015,0),(.035,off+.54,0),.033,M['wood'])
                    g.rod((-.01,off+.24,0),(.035,off+.54,0),.058,M['copper'])
                    for y in (.28,.34,.46):g.rod((-.01,off+y,0),(.0,off+y+.025,0),.064,M['lead'])
                    fade=1 if a=='default' else (1-f/(n-1))**1.4
                    if fade>0:
                        flame(g,(.035,off+.51,.03),phase,fade)
                        sparks(g,(.035,off+.52,.10),phase,25 if a=='default' else 8,.60*fade)
                    smoke(g,phase,a=='end')
                    # Smoke uses local height above the ignition point.
                    for mat,(vs,fs,aa) in list(g.groups.items()):
                        if mat in (M['smoke'],M['soot']):g.groups[mat]=([(x,y+off,z) for x,y,z in vs],fs,aa)
                    if a=='end' and f==n-1:g.shard((.035,off+.53,.05),(.018,.012,.015),M['dim'])
                elif name=='net_burst':
                    spread=(.22,.55,.85,1,1,.98)[f]*(1-.016/3);radius=3*spread
                    def netpoint(x,y):
                        r=math.hypot(x,y);ang=math.atan2(y,x)
                        return Vector((x*spread,y*spread,.08+(.32 if f<4 else .08)*(1-min(1,r/3))+.04*math.sin(5*ang+phase)*(r/3)))
                    # Diamond mesh cut by circle, continuous perimeter, lead sinkers, twisted highlights.
                    spacing=.245
                    for axis in (0,1):
                        for j in range(-16,17):
                            c=j*spacing;limit=math.sqrt(18-c*c) if abs(c)<math.sqrt(18) else 0
                            pts=[]
                            for k in range(49):
                                t=-limit+2*limit*k/48
                                x=(c+t)/math.sqrt(2);y=(c-t)/math.sqrt(2)
                                if axis:x,y=-y,x
                                if x*x+y*y<=9.001:pts.append(netpoint(x,y))
                            if len(pts)>1:
                                g.line(pts,.0085,M['tar'])
                                g.line([p+Vector((0,0,.008)) for p in pts],.0038,M['rope'])
                    pts=[netpoint(3*math.cos(j*TAU/128),3*math.sin(j*TAU/128)) for j in range(129)]
                    g.line(pts,.016,M['rope'])
                    for k in range(32):
                        ang=k*TAU/32;p=netpoint(2.97*math.cos(ang),2.97*math.sin(ang))
                        g.shard(p,(.032,.045,.025),M['lead'],ang)
                        if k%4==0:g.shard(p+Vector((0,0,.03)),(.015,.02,.012),M['dim'])
                    for k in range(17):
                        ang=k*2.4;r=radius*(.3+.65*rng.random());p=Vector((r*math.cos(ang),r*math.sin(ang),.1))
                        g.shard(p,(.012,.035,.015),M['water'],ang)
                else:
                    # Ground footprint 4.5u; scattered slanted shafts, red descending wakes and wet impacts.
                    fade=1 if a=='default' else (1-f/(n-1))
                    original_dim=M['dim']
                    if a=='end':M['dim']=(original_dim,M['cool1'],M['cool2'],M['cold'])[f]
                    for k in range(42):
                        ang=rng.random()*TAU;r=math.sqrt(rng.random())*4.12
                        p=Vector((math.cos(ang)*r,math.sin(ang)*r,.04))
                        age=(k*.6180339+f/8)%1
                        if a=='end':age=.7+.3*f/3
                        d=Vector((-.20,-.36,0));lift=(max(0,.5-age)*2.2 if a=='default' else 0)
                        tip=p+Vector((.1*lift,.2*lift,lift));tail=tip+d*(.7+lift)
                        arrow(g,tail,tip,'arrow',phase,.66)
                        if age<.48 and fade>0:
                            pts=[tail+d*(j*.1)+Vector((.01*math.sin(j+phase),0,-.01)) for j in range(6)]
                            g.ribbon(pts,.014*fade,M['red'])
                        if .45<age<.83 and fade>0:
                            rad=(age-.45)*.36
                            for q in range(7):
                                theta=q*TAU/7+k;v=Vector((math.cos(theta),math.sin(theta),0))
                                g.rod(p+v*rad,p+v*(rad+.04*fade)+Vector((0,0,.025)),.009*fade,M['water'],r2=.002)
                            g.shard(p+Vector((0,0,.03)),(.018*fade,.035*fade,.015),M['red'])
                    # Broken perimeter flecks follow the exact contractual radius, never a solid disk.
                    for k in range(48):
                        ang=k*TAU/48;rr=4.48;p=Vector((rr*math.cos(ang),rr*math.sin(ang),.02))
                        g.shard(p,(.014,.025,.01),M['dim'] if k%3==0 and fade else M['water'],ang)
                    M['dim']=original_dim
                g.commit(frame,transform);renderlist.append((frame,f'{name}_{a}_{f:02d}'))
        s.frame_start=1;s.frame_end=frame;s['VG2_spec']=json.dumps({'asset':name,'cell':size,'rig':rig,'px_per_unit':ppu,'accent':'#FF3A4F','normal_maps':False,'animations':anims})
        s.frame_set(1);bpy.context.view_layer.update()
        source=SOURCE/f'vigie_fx_{name}.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source));sources.append(str(source))
        for frame,stem in renderlist:
            s.frame_set(frame);bpy.context.view_layer.update();render_pair(stem,size,prof)
        print('VG2 COMPLETE '+name+' '+str(len(renderlist)),flush=True)
    if '--only' not in sys.argv:
        # Original VG1 character, unchanged model: bust, tired eyes, woven reed shoulders.
        bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'vigie.blend'));s=bpy.context.scene;s.frame_set(1)
        bpy.data.objects['Vigie_facing_8_directions'].rotation_euler.z=math.radians(12)
        for ob in bpy.data.objects['Longbow_hand_socket'].children_recursive:ob.hide_render=True
        # Match Averse's transparent square bust: hood near top, shoulders fill the lower frame.
        cam=s.camera;cam.rotation_euler=(math.radians(79),0,0);target=Vector((0,-.035,1.194))
        cam.location=target+cam.rotation_euler.to_matrix()@Vector((0,0,12));cam.data.ortho_scale=.94;cam.data.shift_y=0
        s.render.resolution_x=512;s.render.resolution_y=512;s.render.resolution_percentage=100
        cel.setup_scene(s,samples=24);cel.install('creature',normals=False)
        s.render.threads_mode='FIXED';s.render.threads=6
        bpy.context.view_layer.update();bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'vigie_fx_portrait.blend'))
        render_pair('portrait',(256,256),'creature')
        finish()

if __name__=='__main__':
    if '--render' in sys.argv:render_all()
    elif '--finish' in sys.argv:finish()
    elif '--verify' in sys.argv:verify()
    elif '--contact' in sys.argv:contact()
