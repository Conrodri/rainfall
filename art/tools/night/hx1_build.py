"""HX1: top-down neutral cel VFX; Blender background only, Pillow assembly only."""
import sys, math
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/cel'))
import tempfile
sys.path.insert(0,str(Path(tempfile.gettempdir())/'rainfall_hx1_deps'))
import bpy
import cel_style as cel
from PIL import Image
import numpy as np
OUT=ROOT/'game/assets/sprites/fx/hitbox'

def material():
    m=bpy.data.materials.new('HX1 neutral white, two tones, no ink');m.use_nodes=True
    m.surface_render_method='BLENDED'
    n=m.node_tree.nodes;n.clear();l=m.node_tree.links
    col=n.new('ShaderNodeVertexColor');col.layer_name='Tint'
    emit=n.new('ShaderNodeEmission');l.new(col.outputs['Color'],emit.inputs['Color'])
    transparent=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader')
    l.new(col.outputs['Alpha'],mix.inputs[0]);l.new(transparent.outputs[0],mix.inputs[1]);l.new(emit.outputs[0],mix.inputs[2])
    output=n.new('ShaderNodeOutputMaterial');l.new(mix.outputs[0],output.inputs['Surface'])
    return m

def mesh(name,verts,faces,colors,mat):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    a=me.color_attributes.new(name='Tint',type='FLOAT_COLOR',domain='POINT')
    for v,c in zip(a.data,colors):v.color=c
    obj=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(obj);me.materials.append(mat)
    return obj

def band(arc,mat):
    verts=[];faces=[];colors=[]
    radii=[92+i*.25 for i in range(73)] if not arc else [89+i*.25 for i in range(113)]
    steps=720 if not arc else 280
    for r in radii:
        d=r-96.6
        if arc:a=max(0,1-abs(d)/10) if d<0 else math.exp(-.5*(d/6.0)**2)
        else:a=max(0,1+d/4) if d<0 else math.exp(-.5*(d/3.4)**2)
        if r==radii[0] or r==radii[-1]:a=0
        for j in range(steps+1):
            t=(-35+70*j/steps)*math.pi/180 if arc else 2*math.pi*j/steps
            taper=math.cos(t/(35*math.pi/180)*math.pi/2)**.65 if arc else 1
            verts.append((r*math.cos(t),r*math.sin(t),0))
            tone=1 if abs(d)<(5 if arc else 3) else .82
            colors.append((tone,tone,tone,a*max(0,taper)))
    for i in range(len(radii)-1):
        for j in range(steps):
            k=i*(steps+1)+j;faces.append((k,k+1,k+steps+2,k+steps+1))
    objs=[mesh('Impact arc' if arc else 'Uniform ring',verts,faces,colors,mat)]
    if arc:
        for deg,r,length,width in [(-26,111,7,2.2),(-9,115,6,1.8),(13,112,8,2.3),(29,109,6,1.7)]:
            t=math.radians(deg);c,s=math.cos(t),math.sin(t)
            pts=[(r-length/2,0),(r,-width/2),(r+length/2,0),(r,width/2),(r,0)]
            vv=[(x*c-y*s,x*s+y*c,.01) for x,y in pts]
            objs.append(mesh('Outward tapered scale',vv,[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],[(1,1,1,a) for a in [0,.55,0,.55,.95]],mat))
    return objs

def contact():
    ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    bg=Image.new('RGBA',(360,110),(20,25,30,255))
    ground.thumbnail((180,100))
    for x in (0,90,180,270):bg.alpha_composite(ground,(x,5))
    ring=Image.open(OUT/'hitbox_ring.png').convert('RGBA');arc=Image.open(OUT/'hitbox_arc.png').convert('RGBA')
    def tint(im,color,opacity):
        a=im.getchannel('A').point(lambda p:round(p*opacity));o=Image.new('RGBA',im.size,color);o.putalpha(a);return o
    for i,angle in enumerate([None,0,135,270]):
        tile=tint(ring,(235,240,245),.2)
        if angle is not None:tile.alpha_composite(tint(arc.rotate(angle,resample=Image.Resampling.BICUBIC),(255,154,80),1))
        tile=tile.resize((60,30),Image.Resampling.LANCZOS);bg.alpha_composite(tile,(15+90*i,40))
    bg.convert('RGB').save(ROOT/'art/tools/night/_hx1_contact.png',optimize=True)

bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
s=bpy.context.scene;s.render.engine='BLENDER_EEVEE'
s.eevee.taa_render_samples=8;s.render.resolution_x=512;s.render.resolution_y=512;s.render.resolution_percentage=100
s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.dither_intensity=0
s.view_settings.view_transform='Standard';s.view_settings.look='None';s.world.color=(0,0,0)
bpy.ops.object.camera_add(location=(0,0,500));s.camera=bpy.context.object;s.camera.data.type='ORTHO';s.camera.data.ortho_scale=256
cel.install('vfx',normals=False)
mat=material();OUT.mkdir(parents=True,exist_ok=True)
for arc,name in [(False,'hitbox_ring'),(True,'hitbox_arc')]:
    objs=band(arc,mat);cel.toon_materials('vfx')
    path=OUT/(name+'.png');s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    im=Image.open(path).convert('RGBA').resize((256,256),Image.Resampling.LANCZOS);im.save(path,optimize=True,compress_level=9)
    for obj in objs:bpy.data.objects.remove(obj,do_unlink=True)
contact()
a=np.asarray(Image.open(OUT/'hitbox_ring.png'))[:,:,3];yy,xx=np.indices(a.shape);rr=np.hypot(xx-127.5,yy-127.5)
profile=np.array([a[(rr>=r-.5)&(rr<r+.5)].mean() for r in range(88,112)])
peak=int(np.argmax(profile))+88;half=np.where(profile>=profile.max()/2)[0]+88
arc=np.asarray(Image.open(OUT/'hitbox_arc.png'))[:,:,3];line=arc[127:129].mean(axis=0);sel=np.where(line>=line.max()/2)[0]
assert peak==97,(peak,profile)
assert not list(OUT.glob('*_n.png'))
assert all(Image.open(OUT/(name+'.png')).size==(256,256) for name in ['hitbox_ring','hitbox_arc'])
print('HX1 PASS peak=%dpx ring_FWHM=%dpx arc_FWHM=%dpx PNG=%d bytes'%(peak,half[-1]-half[0]+1,sel[-1]-sel[0]+1,sum(p.stat().st_size for p in OUT.glob('*.png'))))
