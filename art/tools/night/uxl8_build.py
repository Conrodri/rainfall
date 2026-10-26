"""UXL8: front orthographic Eevee geometry; UI cel, no normal maps.
Blender --background --python art/tools/night/uxl8_build.py
"""
import sys, math, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
import uxa11y_build as kit
import bpy
import cel_style as cel
OUT=ROOT/'game/assets/sprites/ui/interact'
FILES=[]
cel.install('ui',normals=False)
cel.setup_scene(samples=8)
# All outlines are explicit geometry: contractual 2/5px strokes, no compositor expansion.
cel.PROFILES['ui']['ink_px']=0

def mat(h,alpha=1,toon=False):
    m=kit.material('UXL8 '+h,h,toon)
    if toon:
        b=m.node_tree.nodes.get('Principled BSDF')
        c=b.inputs['Base Color'].default_value
        b.inputs['Base Color'].default_value=tuple(v/cel.TONE_SCALES[2] for v in c[:3])+(1,)
        cel.toon_materials('ui')
        # Contract palette overrides the generic shadow floor for these exact UI swatches.
        rgba=tuple(kit.linear(int(h[i:i+2],16)) for i in (1,3,5))+(1,)
        for node in m.node_tree.nodes:
            if node.type=='VALTORGB':node.color_ramp.elements[-1].color=rgba
    if alpha<1:
        n=m.node_tree.nodes; l=m.node_tree.links; out=n.get('Material Output')
        src=out.inputs['Surface'].links[0].from_socket
        tr=n.new('ShaderNodeBsdfTransparent'); mix=n.new('ShaderNodeMixShader')
        mix.inputs[0].default_value=alpha
        l.new(tr.outputs[0],mix.inputs[1]); l.new(src,mix.inputs[2]); l.new(mix.outputs[0],out.inputs['Surface'])
        m.surface_render_method='BLENDED'
    return m

def reset(w,h):
    kit.reset(w)
    s=bpy.context.scene
    s.camera.location=(w/2,-h/2,200)
    s.render.resolution_x=w*3; s.render.resolution_y=h*3
    s.view_settings.look='None'
    s.render.image_settings.color_depth='8'
    s.render.use_compositing=False
    s.view_layers[0].use_pass_normal=False

def rr(x,y,w,h,r,m,z=0):
    p=[]
    for cx,cy,start in ((x+w-r,y+r,-90),(x+w-r,y+h-r,0),(x+r,y+h-r,90),(x+r,y+r,180)):
        for i in range(25):
            a=math.radians(start+i*90/24);p.append((cx+r*math.cos(a),cy+r*math.sin(a)))
    kit.poly(p,m,z)

def border_rr(w,h,r,width,m):
    loops=[]
    for d in (0,width):
        pts=[]
        for cx,cy,start in ((w-r,r,-90),(w-r,h-r,0),(r,h-r,90),(r,r,180)):
            for i in range(25):
                a=math.radians(start+i*90/24)
                pts.append((cx+(r-d)*math.cos(a),-(cy+(r-d)*math.sin(a)),0))
        loops.append(pts)
    n=len(loops[0]);mesh=bpy.data.meshes.new('Nine slice border')
    mesh.from_pydata(loops[0]+loops[1],[],[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)])
    ob=bpy.data.objects.new('Nine slice border',mesh);bpy.context.collection.objects.link(ob);mesh.materials.append(m)

def arc(cx,cy,rx,ry,a,b,width,m,z=0):
    n=max(12,int(abs(b-a)*1.5)); points=[]
    for radiusx,radiusy,steps in ((rx,ry,range(n+1)),(rx-width,ry-width,range(n,-1,-1))):
        for i in steps:
            t=math.radians(a+(b-a)*i/n); points.append((cx+radiusx*math.sin(t),cy-radiusy*math.cos(t)))
    kit.poly(points,m,z)

def save(name,w,h):
    p=OUT/(name+'.png'); bpy.context.scene.render.filepath=str(p)
    bpy.ops.render.render(write_still=True)
    subprocess.run(['python','-c','from PIL import Image; import sys; p=sys.argv[1]; im=Image.open(p).convert("RGBA"); im.resize((int(sys.argv[2]),int(sys.argv[3])),Image.Resampling.LANCZOS).save(p,optimize=True,compress_level=9)',str(p),str(w),str(h)],check=True)
    FILES.append(name)

OUT.mkdir(parents=True,exist_ok=True)
for state,fill,border,alpha in [('normal','#1F6B34','#B4F0BE',.9),('pressed','#164D26','#8FD49A',1),('disabled','#38383D','#7F7F88',.85)]:
    reset(400,140)
    # 40px radius, perimeter contained in 48/40 slice margins; perfectly flat center.
    border_rr(400,140,40,5,mat(border))
    rr(5,5,390,130,35,mat(fill,alpha,toon=True),.1)
    if state=='pressed':
        # Inset top edge, restricted to top slice; no center gradient.
        rr(12,7,376,4,2,mat('#103D1D'),.2)
    save('interact_bar_'+state,400,140)

for bg in (False,True):
    reset(112,112); dark=mat('#0B0907',.3 if bg else 1); white=mat('#FFFFFF',.3 if bg else 1)
    for i in range(8):
        a=i*45-19.5;b=i*45+19.5
        arc(56,56,53,53,a,b,2,dark)
        arc(56,56,39,39,a,b,2,dark)
        arc(56,56,51,51,a,a+2.55,12,dark)
        arc(56,56,51,51,b-2.55,b,12,dark)
        # Inset along both radial edges as well as the inner/outer circles.
        arc(56,56,51,51,a+2.55,b-2.55,12,white,.1)
    save('interact_hold_ring_bg' if bg else 'interact_hold_ring',112,112)
    if not bg:
        reset(112,112)
        for i in range(8):arc(56,56,51,51,i*45-16.95,i*45+16.95,12,mat('#FFFFFF'))
        save('interact_hold_ring_e',56,56)

for name in ('chest','coin','pillar','portal'):
    reset(64,64); dark=mat('#0B0907'); pale=mat('#F2EEE4'); gold=mat('#F5C24F')
    if name=='chest':
        # Open grasping hand: four separated curled fingers, palm and opposed thumb.
        points=[(17,57),(15,46),(7,36),(7,30),(11,28),(21,37),(18,22),(19,10),(23,8),(26,11),(26,28),(28,6),(32,5),(35,8),(35,28),(38,10),(42,9),(45,12),(43,31),(47,20),(51,19),(54,23),(50,40),(44,49),(43,57)]
        kit.poly(kit.offset(points,2),dark);kit.poly(points,pale,.1)
    elif name=='coin':
        kit.circle(32,32,26,dark);kit.circle(32,32,24,gold,.1)
        arc(32,32,19,19,0,360,2,dark,.2)
        # Bold minted diamond, geometric rather than lettering.
        kit.poly([(32,18),(40,32),(32,46),(24,32)],dark,.3)
        kit.poly([(32,23),(36,32),(32,41),(28,32)],gold,.4)
    elif name=='pillar':
        p=[(32,5),(15,34),(28,34),(24,59),(49,26),(35,26),(43,5)]
        kit.poly(kit.offset(p,2),dark);kit.poly(p,pale,.1)
    else:
        for rx,ry in ((26,28),(18,21),(10,14)):
            arc(32,32,rx,ry,-157,157,7,dark)
            arc(32,32,rx-2,ry-2,-153,153,3,pale,.1)
    save('icon_act_'+name,64,64)
    if name=='portal':
        reset(64,64)
        for rx,ry in ((26,28),(18,21),(10,14)):
            arc(32,32,rx-2,ry-2,-153,153,3,mat('#FFFFFF'))
        save('icon_act_portal_e',32,32)

# Pillow is used only for resampling, assembling, optimization and verification.
subprocess.run(['python','-c',r'''
from PIL import Image
from pathlib import Path
import math
root=Path(__import__('sys').argv[1]); out=root/'game/assets/sprites/ui/interact'
canvas=Image.new('RGBA',(1100,1380),'#0B0907')
for row,bg in enumerate(('#0B0907','#2B3340','#8C8370')):
 panel=Image.new('RGBA',(1100,460),bg)
 for i,state in enumerate(('normal','pressed','disabled')):
  bar=Image.open(out/('interact_bar_'+state+'.png')).convert('RGBA')
  icon=Image.open(out/'icon_act_chest.png').convert('RGBA')
  bar.alpha_composite(icon,(22,38)); panel.alpha_composite(bar,(10,8+i*150))
  small=bar.resize((240,84),Image.Resampling.LANCZOS); panel.alpha_composite(small,(425,18+i*150))
 track=Image.open(out/'interact_hold_ring_bg.png').convert('RGBA')
 ring=Image.open(out/'interact_hold_ring.png').convert('RGBA')
 for j,count in enumerate((0,3,8)):
  r=track.copy(); active=ring.copy(); px=active.load()
  for y in range(112):
   for x in range(112):
    a=math.degrees(math.atan2(x-55.5,55.5-y))%360
    seg=int(((a+22.5)%360)//45)
    if seg>=count:px[x,y]=(0,0,0,0)
  r.alpha_composite(active);panel.alpha_composite(r,(690+j*130,35))
 for j,n in enumerate(('chest','coin','pillar','portal')):
  im=Image.open(out/('icon_act_'+n+'.png')).resize((40,40),Image.Resampling.LANCZOS)
  panel.alpha_composite(im,(700+j*88,225))
 canvas.alpha_composite(panel,(0,row*460))
canvas.convert('RGB').save(root/'art/tools/night/_uxl8_contact.png',optimize=True)
names=['interact_bar_'+s for s in ('normal','pressed','disabled')]+['interact_hold_ring','interact_hold_ring_bg']+['icon_act_'+s for s in ('chest','coin','pillar','portal')]+['interact_hold_ring_e','icon_act_portal_e']
for n in names:
 im=Image.open(out/(n+'.png')); expected=(400,140) if 'bar_' in n else ((56,56) if n=='interact_hold_ring_e' else ((32,32) if n=='icon_act_portal_e' else ((112,112) if 'ring' in n else (64,64))))
 assert im.mode=='RGBA' and im.size==expected and im.getbbox(),n
 if n.endswith('_e'):assert max(im.convert('RGB').getextrema()[0])>0
assert not list(out.glob('*_n.png'))
print('PASS UXL8: 11 RGBA, dimensions, emission, no normals; contact assembled')
''',str(ROOT)],check=True)
print('PASS UXL8 build')
