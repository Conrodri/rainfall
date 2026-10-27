"""RAID_KIT: geometric Eevee VFX; cel, 2x render, contractual atlases."""
import sys, math, random, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.dont_write_bytecode=True
sys.path[:0]=[str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel')]
OUT=ROOT/'game/assets/sprites/vfx/raid'
SPECS=[('raid_orb',96,96,8),('raid_orb_pickup',128,192,6),('shield_bubble',320,352,8),('shield_crack',320,352,12),('shield_burst',384,384,6),('soak_zone',320,320,6),('soak_fill',320,320,8),('soak_burst',640,640,6),('safe_sector',1152,1152,8),('danger_sheet',1152,1152,6),('sector_arrow',128,128,4),('fixate_mark',160,160,12),('fixate_link',512,32,4),('weak_point',96,96,12),('weak_point_break',160,160,6),('shelter_shadow',128,384,6),('raid_progress_pip',48,48,2),('enrage_aura',352,352,8)]
CY='BFF4FF'; RED='E0463C'; WHITE='FFFFFF'

def build():
 import bpy, iso_rig, cel_style as cel
 from mathutils import Vector
 from PIL import Image
 OUT.mkdir(parents=True,exist_ok=True)
 tmp=Path(tempfile.mkdtemp(prefix='rainfall_raid_'))
 bpy.context.preferences.filepaths.save_version=0
 resources=[]; atlases=[]; anims=[]; samples=[]
 for name,w,h,count in SPECS:
  top=name in ['soak_zone','soak_fill','soak_burst','safe_sector','danger_sheet','sector_arrow','fixate_mark','fixate_link','shelter_shadow','raid_progress_pip']
  s=iso_rig.create_rig('TOP' if top else 'CREA',(w,h))
  s.camera.data.ortho_scale=w/64
  s.render.engine='BLENDER_EEVEE'; s.render.film_transparent=True
  s.render.threads_mode='FIXED';s.render.threads=8
  if hasattr(s,'eevee'): s.eevee.taa_render_samples=8
  basis=s.camera.rotation_euler.to_matrix()
  cel.install('icon' if name=='raid_progress_pip' else 'vfx',normals=False)
  cols=min(count,4096//w); rows=math.ceil(count/cols)
  pages={}; frames=[]; ends=[]
  for f in range(count):
   for ob in list(s.objects):
    if ob.type=='MESH': bpy.data.objects.remove(ob,do_unlink=True)
   for mat in list(bpy.data.materials):
    if mat.users==0:bpy.data.materials.remove(mat)
   mats=[]; layer=[0]
   def mat(color=CY,alpha=1,emit=0):
    m=bpy.data.materials.new('Raid '+color);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    c=tuple(((int(color[i:i+2],16)/255+.055)/1.055)**2.4 if int(color[i:i+2],16)/255>.04045 else int(color[i:i+2],16)/255/12.92 for i in (0,2,4))+(1,)
    p.inputs['Base Color'].default_value=c
    if emit:p.inputs['Emission Color'].default_value=c;p.inputs['Emission Strength'].default_value=emit;m['rainfall_emissive']=True
    mats.append((m,alpha));return m
   cyan=mat(); glow=mat(emit=1); red=mat(RED); white=mat(WHITE); glass=mat(alpha=.15); gray=mat('6C777D')
   def mesh(points,faces,m):
    layer[0]+=.0004
    verts=[tuple(basis@Vector((x/64,y/64,layer[0]))) for x,y in points]
    me=bpy.data.meshes.new('Raid geometry');me.from_pydata(verts,[],faces);me.update()
    ob=bpy.data.objects.new('Raid '+name,me);s.collection.objects.link(ob);me.materials.append(m);return ob
   def poly(p,m):return mesh(p,[tuple(range(len(p)))],m)
   def line(p,t,m):
    for a,b in zip(p,p[1:]):
     dx=b[0]-a[0];dy=b[1]-a[1];d=max(.001,math.hypot(dx,dy));nx=-dy*t/2/d;ny=dx*t/2/d
     poly([(a[0]+nx,a[1]+ny),(a[0]-nx,a[1]-ny),(b[0]-nx,b[1]-ny),(b[0]+nx,b[1]+ny)],m)
   def arc(r,t,m,a=0,b=math.tau,c=(0,0),sy=1):
    n=max(2,int(abs(b-a)*r/5));ps=[]
    for j in range(n+1):
     q=a+(b-a)*j/n
     ps.extend([(c[0]+(r-t/2)*math.cos(q),c[1]+(r-t/2)*math.sin(q)*sy),(c[0]+(r+t/2)*math.cos(q),c[1]+(r+t/2)*math.sin(q)*sy)])
    mesh(ps,[(2*j,2*j+1,2*j+3,2*j+2) for j in range(n)],m)
   def disk(r,m,c=(0,0),a=0,b=math.tau,sy=1):
    n=96;p=[c]+[(c[0]+r*math.cos(a+(b-a)*j/n),c[1]+r*math.sin(a+(b-a)*j/n)*sy) for j in range(n+1)]
    mesh(p,[(0,j+1,j+2) for j in range(n)],m)
   phase=math.tau*f/count;pulse=math.sin(phase);t=f/max(1,count-1)
   if name=='raid_orb':
    c=(0,-h/2+29)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=25/64,location=basis@Vector((0,c[1]/64,-26/64)))
    bpy.context.object.data.materials.append(glass)
    arc(25,2,cyan,c=c);arc(21,1,cyan,a=.2,b=2.6,c=c,sy=.72);disk(10+2*pulse,glow,c)
    for k in range(7):
     a=k*math.tau/7;line([(c[0]+24*math.cos(a),c[1]+24*math.sin(a)),(c[0]+15*math.cos(a+.2),c[1]+15*math.sin(a+.2)),(c[0]+11*math.cos(a-.1),c[1]+11*math.sin(a-.1))],1.3,white)
   elif name=='raid_orb_pickup':
    y=-h/2+12+t*(h-32);line([(0,max(-h/2+2,y-72)),(0,y)],max(1,7*(1-t)),glow);disk(6*(1-t)+2,glow,(0,y))
    for k in range(4):line([((k-1.5)*12,y-32-k*7),((k-1.5)*12,y-18-k*7)],1,cyan)
   elif name in ('shield_bubble','shield_crack'):
    c=(0,-7);r=150
    if name=='shield_bubble':
     disk(r,glass,c,sy=1.08);arc(r,2,glow,c=c,sy=1.08)
     for yy in range(-120,130,28):
      for xx in range(-126,127,32):
       x=xx+(16 if (yy//28)%2 else 0);y=yy+4*math.sin(phase)
       if (x/140)**2+(y/155)**2<.82:
        p=[(x+17*math.cos(k*math.tau/6),y+17*math.sin(k*math.tau/6)) for k in range(7)];line(p,1,cyan)
    else:
     rng=random.Random(51)
     for k in range(3+f//4*4):
      a=k*2.399;x=math.cos(a)*132;y=math.sin(a)*145-7
      line([(x,y),(x*.75+8,y*.7),(x*.46-6,y*.4),(x*.2,y*.18)],1.6+(f%4)*.3,glow)
   elif name in ('shield_burst','weak_point_break'):
    r=(35 if name=='shield_burst' else 12)+t*(145 if name=='shield_burst' else 58)
    for k in range(16):
     a=k*2.399;cx=r*math.cos(a);cy=r*math.sin(a);d=(10 if name=='shield_burst' else 5)*(1-t*.7)
     poly([(cx-d,cy-d),(cx+d,cy),(cx,cy+d*2)],glow if k%3 else white)
    arc(r,2,cyan,a=t,b=t+math.pi*1.4)
   elif name=='soak_zone':
    disk(157,mat(alpha=.06));arc(157,3+pulse,glow);arc(133,2,cyan)
    for k in range(8):a=k*math.tau/8;line([(146*math.cos(a),146*math.sin(a)),(154*math.cos(a),154*math.sin(a))],3,white)
   elif name=='soak_fill':arc(134,11,glow,a=math.pi/2,b=math.pi/2+max(.004,t*math.tau))
   elif name=='soak_burst':
    r=64+t*253;arc(r,5+8*(1-t),red);arc(max(2,r-13),2,mat(RED,alpha=.4))
   elif name=='safe_sector':
    disk(572,mat(alpha=.35),a=-math.pi/4,b=math.pi/4);arc(572,3+pulse,glow,a=-math.pi/4,b=math.pi/4)
    for a in [-math.pi/4,math.pi/4]:line([(0,0),(572*math.cos(a),572*math.sin(a))],3,cyan)
   elif name=='danger_sheet':
    disk(574,mat(RED,alpha=.25));arc(574,2,red)
    for k in range(65):
     a=k*2.399+phase*.03;r=math.sqrt((k+.5)/65)*550;x=r*math.cos(a);y=r*math.sin(a);line([(x-3,y),(x+3,y+1)],1,mat(RED,alpha=.12))
   elif name=='sector_arrow':
    a=.4+phase*.05;b=5.4+phase*.05;arc(43,7,white,a,b);x=43*math.cos(b);y=43*math.sin(b);poly([(x-14,y+6),(x+7,y-15),(x+12,y+10)],white)
   elif name=='fixate_mark':
    m=white if f<6 else red;a=f*math.tau/6 if f<6 else 0
    arc(70,3,m)
    for q in [a+math.pi/4,a+3*math.pi/4]:line([(-45*math.cos(q),-45*math.sin(q)),(45*math.cos(q),45*math.sin(q))],6,m)
   elif name=='fixate_link':
    for x in range(-280,280,40):line([(max(-256,x+f*10),0),(min(256,x+f*10+21),0)],3,white) if -256<x+f*10<235 else None
   elif name=='weak_point':
    c=(0,-h/2+29)
    if f<6:
     arc(26,3,glow,c=c);poly([(-11,c[1]),(0,c[1]+21),(12,c[1]),(0,c[1]-21)],cyan);poly([(0,c[1]+21),(12,c[1]),(0,c[1]-9)],glow)
    else:
     for k in range(10):arc(26,2,gray,k*math.tau/10,(k+.55)*math.tau/10,c=c)
   elif name=='shelter_shadow':
    poly([(-31,-191),(31,-191),(31,191),(-31,191)],mat(alpha=.22));line([(-31,-191),(-31,191)],2,cyan);line([(31,-191),(31,191)],2,cyan)
    for y in range(-170,190,48):line([(-9,y+pulse*3),(0,y+10+pulse*3),(9,y+pulse*3)],2,cyan)
   elif name=='raid_progress_pip':
    arc(18,3,cyan)
    if f:disk(13,glow)
   elif name=='enrage_aura':
    arc(164,3+2*(1+pulse),red,c=(0,-2),sy=1.02)
    for k in range(18):
     a=k*math.tau/18;r=156+4*math.sin(phase+k);line([(r*math.cos(a),r*math.sin(a)),((r+10)*math.cos(a+.025),(r+10)*math.sin(a+.025))],3,red)
   raw=tmp/'frame.png';iso_rig.common.configure_passes(raw)
   for m,alpha in mats:
    if alpha<1:
     nt=m.node_tree;out=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL');src=out.inputs['Surface'].links[0].from_socket
     tr=nt.nodes.new('ShaderNodeBsdfTransparent');mix=nt.nodes.new('ShaderNodeMixShader');mix.inputs[0].default_value=alpha
     nt.links.new(tr.outputs[0],mix.inputs[1]);nt.links.new(src,mix.inputs[2]);nt.links.new(mix.outputs[0],out.inputs['Surface'])
   s.render.filepath=str(raw);bpy.ops.render.render(write_still=True)
   for suffix in ['', '_e']:
    p=raw if not suffix else raw.with_name(raw.stem+'_e__Image.png')
    if not p.exists():continue
    im=Image.open(p).convert('RGBA').resize((w,h),Image.Resampling.LANCZOS)
    if suffix=='_e' and name not in ['raid_orb','shield_bubble','weak_point']:continue
    if suffix not in pages:pages[suffix]=Image.new('RGBA',(cols*w,rows*h))
    pages[suffix].paste(im,((f%cols)*w,(f//cols)*h))
    if not suffix and f in (0,count-1):ends.append(im.copy())
   frames.append((f%cols*w,f//cols*h))
  for suffix,im in pages.items():
   if suffix:im=im.resize(((im.width+1)//2,(im.height+1)//2),Image.Resampling.LANCZOS)
   im.save(OUT/(name+suffix+'.png'),optimize=True)
  rid='t_'+name;resources.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/vfx/raid/{name}.png" id="{rid}"]')
  ids=[]
  for f,(x,y) in enumerate(frames):
   aid=f'a_{name}_{f}';ids.append(aid);atlases.append(f'[sub_resource type="AtlasTexture" id="{aid}"]\natlas = ExtResource("{rid}")\nregion = Rect2({x}, {y}, {w}, {h})')
  loop=name not in ['raid_orb_pickup','shield_crack','shield_burst','soak_fill','soak_burst','weak_point_break','raid_progress_pip']
  anims.append('{"frames": ['+', '.join('{"duration": 1.0, "texture": SubResource("'+i+'")}' for i in ids)+'], "loop": '+str(loop).lower()+', "name": &"'+name+'", "speed": 8.0}')
  samples.append((name,ends));print('RAID PASS '+name,flush=True)
  if name=='shield_bubble':
   dest=ROOT/'art/blender/vfx/raid_kit.blend';dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest))
 (OUT/'raid.tres').write_text('[gd_resource type="SpriteFrames" load_steps='+str(1+len(resources)+len(atlases))+' format=3]\n\n'+'\n\n'.join(resources+atlases)+'\n\n[resource]\nanimations = ['+',\n'.join(anims)+']\n',encoding='utf-8')
 contact=Image.new('RGB',(768,len(samples)*142),'#2E3238')
 for j,(name,ims) in enumerate(samples):
  for k,im in enumerate(ims):
   im.thumbnail((330,132),Image.Resampling.LANCZOS);contact.paste(im,(k*384+(384-im.width)//2,j*142+(142-im.height)//2),im)
 contact.save(Path(__file__).with_name('_raid_kit_contact.png'))
 print(f'RAID_KIT PASS {len(SPECS)} animations {sum(x[3] for x in SPECS)} frames',flush=True)
if __name__=='__main__':build()

