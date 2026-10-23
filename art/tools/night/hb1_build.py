"""HB1: iron reliquaries, cel UI. Blender --background --python this.py;
python this.py --finish. Pillow only crops, assembles, resizes and verifies.
All shading, tint previews and labels are rendered by Blender. No normals.
"""
from pathlib import Path
import sys, math, json
ROOT = Path(__file__).resolve().parents[3]
WORK = ROOT / 'art/tools/night'
RAW = WORK / '_hb1_raw'
OUT = ROOT / 'game/assets/sprites/ui/hp_bars'
sys.path.insert(0, str(ROOT / 'art/tools/cel'))
import cel_style as cel
SIZES = {**{n:(512,64) for n in ('boss_frame','mini_frame')},
         'elite_frame':(256,24), 'boss_fill':(256,32),
         'notch':(16,48),'notch_broken':(16,48),'shard':(64,16),
         **{'status_'+n:(64,64) for n in ('burn','poison','frost','stun','imprisoned')},
         **{'fx_'+n:(256,32) for n in ('burn','poison','frost')}}
EMIT = ('boss_frame','boss_fill','status_burn')

def finish():
    from PIL import Image, ImageChops
    OUT.mkdir(parents=True, exist_ok=True)
    checks = {}
    for name,(w,h) in SIZES.items():
        im=Image.open(RAW/(name+'.png')).convert('RGBA').resize((w,h),Image.Resampling.LANCZOS)
        # Assemble four cropped rails around an exactly empty contractual window.
        if name.endswith('frame'):
            x,y=(8,8) if name=='elite_frame' else (24,22)
            clean=Image.new('RGBA',(w,h))
            for box in ((0,0,w,y),(0,h-y,w,h),(0,y,x,h-y),(w-x,y,w,h-y)):
                clean.paste(im.crop(box),box[:2])
            im=clean
            assert not im.crop((x,y,w-x,h-y)).getbbox()
        im.save(OUT/(name+'.png'),optimize=True,compress_level=9)
        checks[name]={'size':[w,h],'alpha_bbox':im.getchannel('A').getbbox()}
        if name in EMIT:
            ep=next(RAW.glob(name+'_e__*.png'))
            e=Image.open(ep).convert('RGBA').resize((w,h),Image.Resampling.LANCZOS)
            e.putalpha(im.getchannel('A'))
            e.save(OUT/(name+'_e.png'),optimize=True,compress_level=9)
    for name in ('boss_fill','boss_fill_e','fx_burn','fx_poison','fx_frost'):
        im=Image.open(OUT/(name+'.png')).convert('RGBA')
        assert ImageChops.difference(im.crop((0,0,1,32)),im.crop((255,0,256,32))).getbbox(alpha_only=False) is None, name+' seam'
        assert all(r==g==b for r,g,b,a in im.getdata() if a==255),name+' tint'
    for name in ('burn','poison','frost','stun','imprisoned'):
        im=Image.open(OUT/('status_'+name+'.png')).convert('RGBA')
        assert all((x-31.5)**2+(y-31.5)**2<=23**2 for y in range(64) for x in range(64) if im.getpixel((x,y))[3]>16),name+' circle'
    board=Image.new('RGBA',(1100,850),(11,9,7,255))
    ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    for y in range(0,850,ground.height):
        for x in range(0,1100,ground.width):board.alpha_composite(ground,(x,y))
    def paste(im,x,y):board.alpha_composite(im,(int(x),int(y)))
    def label(i,x,y):
        im=Image.open(RAW/('label_'+str(i)+'.png')).convert('RGBA').resize((1000,24),Image.Resampling.LANCZOS)
        paste(im,x,y)
    def nine(name,w,h,k):
        im=Image.open(OUT/(name+'.png')).convert('RGBA'); sw,sh=im.size
        mx,my=(8,8) if name=='elite_frame' else (32,24)
        xs=[0,round(mx*k),w-round(mx*k),w];ys=[0,round(my*k),h-round(my*k),h]
        us=[0,mx,sw-mx,sw];vs=[0,my,sh-my,sh]; dest=Image.new('RGBA',(w,h))
        for iy in range(3):
            for ix in range(3):
                piece=im.crop((us[ix],vs[iy],us[ix+1],vs[iy+1]))
                size=(xs[ix+1]-xs[ix],ys[iy+1]-ys[iy])
                if min(size)>0:dest.alpha_composite(piece.resize(size,Image.Resampling.LANCZOS),(xs[ix],ys[iy]))
        return dest
    def bar(name,w,h,x,y,phase=0,notches=False):
        k=h/(8 if name=='elite_frame' else 20); fx=round((8 if name=='elite_frame' else 24)*k);fy=round((8 if name=='elite_frame' else 22)*k)
        fill=Image.open(RAW/('preview_'+str(phase)+'.png')).convert('RGBA').resize((w,h),Image.Resampling.LANCZOS)
        paste(fill,x+fx,y+fy);paste(nine(name,w+2*fx,h+2*fy,k),x,y)
        if notches:
            for fraction,n in ((.7,'notch'),(.35,'notch_broken')):
                im=Image.open(OUT/(n+'.png')).convert('RGBA').resize((max(3,round(16*k)),round(48*k)),Image.Resampling.LANCZOS)
                paste(im,x+fx+w*fraction-im.width/2,y+fy+h/2-im.height/2)
    label(0,30,12)
    for i in range(3):bar('boss_frame',880,16,40,51+i*57,i,True)
    label(1,30,225);bar('boss_frame',560,18,40,257,1,True)
    label(2,30,320);bar('mini_frame',650,18,40,352,0)
    label(3,30,415);bar('elite_frame',100,8,40,447,0)
    for i,n in enumerate(('burn','poison','frost','stun','imprisoned')):
        im=Image.open(OUT/('status_'+n+'.png')).convert('RGBA')
        paste(im.resize((22,22),Image.Resampling.LANCZOS),280+i*52,445)
        paste(im.resize((12,12),Image.Resampling.LANCZOS),284+i*52,481)
    label(4,30,522)
    for i in range(3):
        im=Image.open(RAW/('preview_fx_'+str(i)+'.png')).convert('RGBA').resize((256,32),Image.Resampling.LANCZOS)
        paste(im,40+i*345,562)
    # Source swatches and references stay on the single final contact sheet.
    for i,n in enumerate(('boss_frame','mini_frame','elite_frame')):
        im=Image.open(OUT/(n+'.png')).convert('RGBA')
        paste(im.resize((im.width//2,im.height//2),Image.Resampling.LANCZOS),40+i*345,620)
    label(5,30,666)
    refs=['art/tools/night/_cs1_contact.png','art/tools/night/_u1_contact.png','art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png']
    for i,rel in enumerate(refs):
        p=ROOT/rel
        if p.exists():
            im=Image.open(p).convert('RGBA')
            if i==0:im=im.crop((im.width//2,0,im.width,im.height))
            im.thumbnail((250,135));paste(im,30+i*270,705)
    board.convert('RGB').save(WORK/'_hb1_contact.png',optimize=True)
    (WORK/'_hb1_verification.json').write_text(json.dumps({'result':'PASS','assets':checks,'nine_patch':{'boss_mini':[32,24],'elite':[8,8]},'windows':{'boss_mini':[24,22,464,20],'elite':[8,8,240,8]},'seams':'RGBA exact, five tileable maps','preview':'880x16,560x18,650x18,100x8; icons 22/12'},indent=2))
    print('PASS 18 PNG RGBA; exact windows; five seamless maps; neutral tint; icons inside 46px circle; contact 1100x850')

if '--finish' in sys.argv:
    finish();raise SystemExit

import bpy
from mathutils import Vector
RAW.mkdir(parents=True,exist_ok=True)
if OUT.exists():cel.archive_folder('ui/hp_bars')

def linear(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def mat(name,h,glow=False):
    m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
    c=tuple(linear(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
    p.inputs['Base Color'].default_value=c;p.inputs['Metallic'].default_value=.65;p.inputs['Roughness'].default_value=.65
    if glow:p.inputs['Emission Color'].default_value=c;p.inputs['Emission Strength'].default_value=1;m['rainfall_emissive']=True
    return m

def scene(w,h):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    s=bpy.context.scene;s.compositing_node_group=None
    cel.setup_scene(s);s.render.resolution_x=w*2;s.render.resolution_y=h*2;s.render.resolution_percentage=100
    s.render.image_settings.color_depth='8';s.world.color=(.06,.06,.06)
    cam=bpy.data.cameras.new('Front orthographic');o=bpy.data.objects.new('Front orthographic',cam);s.collection.objects.link(o)
    o.location=(w/2,h/2,1000);cam.type='ORTHO';cam.ortho_scale=w;s.camera=o
    for name,loc,energy in [('Upper left',(-300,500,900),2.5),('Fill',(500,100,700),.5)]:
        d=bpy.data.lights.new(name,'SUN');d.energy=energy;d.angle=.15;o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.rotation_euler=(Vector((w/2,h/2,0))-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    return s

def poly(pts,m,z=0,bevel=0):
    # Mesh faces in screen XY; front orthographic, physical thin forged slabs.
    mesh=bpy.data.meshes.new('Forged silhouette');mesh.from_pydata([(x,y,z) for x,y in pts],[],[tuple(range(len(pts)))]);mesh.materials.append(m)
    ob=bpy.data.objects.new('Forged silhouette',mesh);bpy.context.scene.collection.objects.link(ob)
    if bevel:
        so=ob.modifiers.new('Thickness','SOLIDIFY');so.thickness=1.5
        be=ob.modifiers.new('Worn chamfer','BEVEL');be.width=bevel;be.segments=1
    return ob
def rect(x,y,w,h,m,z=0):return poly([(x,y),(x+w,y),(x+w,y+h),(x,y+h)],m,z)
def disk(x,y,r,m,z=0):return poly([(x+math.cos(i*math.tau/8)*r,y+math.sin(i*math.tau/8)*r) for i in range(8)],m,z)
def stroke(points,width,m,z=0):
    for (x,y),(a,b) in zip(points,points[1:]):
        dx,dy=a-x,b-y;length=math.hypot(dx,dy);nx,ny=-dy/length*width/2,dx/length*width/2
        poly([(x+nx,y+ny),(x-nx,y-ny),(a-nx,b-ny),(a+nx,b+ny)],m,z)
def render(name,w,h,emission=False,ink=True):
    cel.toon_materials('ui');p=RAW/(name+'.png');cel.cel_passes(p,'ui' if ink else dict(cel.profile('ui'),ink_px=0))
    tree=bpy.context.scene.compositing_node_group
    for n in list(tree.nodes):
        if n.bl_idname=='CompositorNodeOutputFile' and (not emission or '_n__' in n.file_name):tree.nodes.remove(n)
    bpy.context.scene.render.filepath=str(p);bpy.ops.render.render(write_still=True)

iron=mat('Forged iron 2A2623','4A423C');edge=mat('Polished wear','796B5B');rust=mat('Rust in joints','3E2419');dark=mat('Deep recess','181210');grey=mat('Neutral clear face','C8C8C8');ember=mat('Only ember accent','F07A2A',True)
for name,w,h in [('boss_frame',512,64),('mini_frame',512,64),('elite_frame',256,24)]:
    scene(w,h);small=name=='elite_frame';left,bot=(8,8) if small else (24,22)
    if small:
        for y in (4,16):rect(7,y,w-14,4,iron)
        for x in (0,w-9):poly([(x,12),(x+7,3),(x+9,8),(x+9,16),(x+7,21)],iron)
        rect(8,18,240,1.5,edge,2)
    else:
        # No central medallion: the plaque is an unbroken, repeatable upper rail.
        for y in (9,42):rect(24,y,464,13,iron)
        rect(26,53,460,2,edge,2);rect(25,43,462,1.4,rust,2)
        rect(24,20,464,2,edge,2)
        for flip in (False,True):
            def cap(pts,m,z=0):poly([(w-x if flip else x,y) for x,y in pts],m,z,0)
            if name=='boss_frame':
                cap([(1,32),(13,17),(23,12),(31,14),(31,50),(23,52),(13,47)],iron)
                cap([(3,32),(16,39),(22,49),(24,43),(15,32),(24,21),(22,15),(16,25)],edge,2)
                cap([(16,32),(23,25),(23,39)],rust,3)
            else:cap([(5,20),(13,11),(31,11),(31,53),(13,53),(5,44)],iron)
            for yy in (17,47):
                xx=w-26 if flip else 26;disk(xx,yy,2.8,edge,3);stroke([(xx-1.2,yy+.4),(xx+1.2,yy-.4)],.8,dark,4)
                if name=='mini_frame':
                    xx=w-17 if flip else 17;disk(xx,yy,2.4,edge,3);stroke([(xx-1,yy+.3),(xx+1,yy-.3)],.8,dark,4)
        if name=='boss_frame':rect(25,21,462,.65,ember,4)
    render(name,w,h,name=='boss_frame')

scene(256,32);rect(-4,-4,264,40,grey);render('boss_fill',256,32,False,False)
# A separate neutral emission pass: sparse veins, never baked into the diffuse.
black=mat('Unlit emission support','000000',True);white=mat('Tintable vein emission','B0B0B0',True)
scene(256,32);rect(-4,-4,264,40,black)
for x in range(-64,321,64):stroke([(x-4,8),(x+4,8),(x+16,12),(x+32,9),(x+48,16),(x+60,8),(x+68,8)],1,white,1)
render('fill_veins',256,32,True,False)
import shutil
for f in RAW.glob('fill_veins_e__*.png'):shutil.copyfile(f,RAW/('boss_fill_e__0001.png'))

for broken in (False,True):
    scene(16,48)
    if not broken:poly([(8,1),(12,9),(10,39),(8,47),(4,38),(5,9)],iron);stroke([(7,9),(7,38)],1.8,edge,2)
    else:
        poly([(8,1),(12,9),(11,21),(8,19),(5,23),(5,9)],iron)
        poly([(5,28),(8,30),(10,26),(10,39),(8,47),(4,38)],iron)
        stroke([(5,23),(8,19),(11,21)],1,rust,2);stroke([(6,30),(6,38)],1.5,edge,2)
    render('notch_broken' if broken else 'notch',16,48)
scene(64,16)
for i in range(4):
    x=i*16;poly([(x+3,5),(x+6,2),(x+13,7),(x+9,14),(x+5,11)],iron);stroke([(x+4,5),(x+6,3),(x+12,7)],1.5,edge,2)
render('shard',64,16)

for name,color in [('burn','F07A2A'),('poison','8DAA3C'),('frost','9CC3D2'),('stun','D8C47A'),('imprisoned','9A948C')]:
    scene(64,64);m=mat('Status '+name,color,name=='burn')
    if name=='burn':poly([(32,11),(21,14),(15,24),(17,34),(23,40),(24,31),(31,49),(36,42),(45,34),(47,23),(41,14)],m)
    elif name=='poison':poly([(32,53),(43,34),(47,24),(44,16),(37,11),(27,11),(19,16),(17,24),(21,34)],m)
    elif name=='frost':
        for a in range(3):
            t=a*math.pi/3;dx,dy=math.cos(t),math.sin(t);stroke([(32-20*dx,32-20*dy),(32+20*dx,32+20*dy)],5,m)
        poly([(32,42),(40,32),(32,22),(24,32)],m,1)
    elif name=='stun':poly([(32,54),(38,38),(53,32),(38,26),(32,10),(26,26),(11,32),(26,38)],m)
    else:
        # Two open, angular links, large enough to survive the 12px reduction.
        for dx,dy in [(-7,-7),(7,7)]:stroke([(32+dx,19+dy),(40+dx,27+dy),(40+dx,33+dy),(30+dx,43+dy),(24+dx,43+dy),(18+dx,37+dy),(18+dx,31+dy),(28+dx,21+dy),(32+dx,19+dy)],5,m)
        for ob in bpy.context.scene.objects:
            if ob.type=='MESH':
                for v in ob.data.vertices:
                    v.co.x=32+(v.co.x-32)*.86;v.co.y=32+(v.co.y-32)*.86
    render('status_'+name,64,64,name=='burn')

for name in ('burn','poison','frost'):
    scene(256,32)
    for x in range(-32,289,32):
        if name=='burn':poly([(x-4,2),(x+36,2),(x+36,6),(x+27,6),(x+24,10),(x+18,13),(x+21,25),(x+12,18),(x+7,8),(x+4,6),(x-4,6)],grey)
        elif name=='poison':poly([(x-4,27),(x+36,27),(x+36,23),(x+28,23),(x+22,21),(x+19,7),(x+14,3),(x+10,8),(x+10,20),(x+4,23),(x-4,23)],grey)
        else:
            for yy,sign in ((0,1),(32,-1)):poly([(x-4,yy),(x+36,yy),(x+36,yy+sign*4),(x+27,yy+sign*4),(x+20,yy+sign*6),(x+16,yy+sign*14),(x+11,yy+sign*5),(x+7,yy+sign*9),(x+4,yy+sign*4),(x-4,yy+sign*4)],grey)
    render('fx_'+name,256,32,False,False)

# Render tinted check strips by using delivered geometry silhouettes as Blender textures.
def textured_preview(source,color,name):
    scene(256,32);im=bpy.data.images.load(str(RAW/(source+'.png')),check_existing=True)
    m=bpy.data.materials.new('Preview tint');m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;n.clear()
    tex=n.new('ShaderNodeTexImage');tex.image=im;tex.extension='REPEAT'
    mul=n.new('ShaderNodeMixRGB');mul.blend_type='MULTIPLY';mul.inputs[0].default_value=1
    mul.inputs[2].default_value=tuple(linear(int(color[i:i+2],16)/255) for i in (0,2,4))+(1,);l.new(tex.outputs['Color'],mul.inputs[1])
    e=n.new('ShaderNodeEmission');l.new(mul.outputs[0],e.inputs[0]);tr=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader');l.new(tex.outputs['Alpha'],mix.inputs[0]);l.new(tr.outputs[0],mix.inputs[1]);l.new(e.outputs[0],mix.inputs[2]);o=n.new('ShaderNodeOutputMaterial');l.new(mix.outputs[0],o.inputs[0])
    ob=rect(0,0,256,32,m);uv=ob.data.uv_layers.new()
    for loop in ob.data.loops:
        v=ob.data.vertices[loop.vertex_index].co;uv.data[loop.index].uv=(v.x/256,v.y/32)
    render(name,256,32,False,False)
for i,c in enumerate(('B8321E','D2461C','EE6422')):textured_preview('boss_fill',c,'preview_'+str(i))
for i,(n,c) in enumerate((('burn','F07A2A'),('poison','8DAA3C'),('frost','9CC3D2'))):textured_preview('fx_'+n,c,'preview_fx_'+str(i))
labels=['HB1 / FER FORGE / CEL UI - 3 PHASES / 880 x 16', 'BOSS / 560 x 18 / SEUILS 70% ET 35%', 'MINI-BOSS / 650 x 18 / DOUBLE RIVET', 'ELITE / 100 x 8     STATUTS / 22 PX PUIS 12 PX', 'MASQUES FX TEINTES / BRAISE - SUINTEMENT - GIVRE', 'SOURCES / CS1 CEL (DROITE), KIT UI, ARDENT, RICTUS']
for i,text in enumerate(labels):
    scene(1000,24);bpy.ops.object.text_add(location=(0,5,0));ob=bpy.context.object;ob.data.body=text;ob.data.size=15;ob.data.materials.append(mat('Label','BAADA0',True));render('label_'+str(i),1000,24,False,False)
print('HB1 RENDER PASS')
