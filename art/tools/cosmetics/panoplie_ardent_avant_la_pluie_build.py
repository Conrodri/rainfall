"""Allumeur de reverberes: system driver and Blender -- --render. Original geometry/exporters retained."""
from pathlib import Path
import sys,json,subprocess,shutil,inspect,textwrap,hashlib
ROOT=Path(__file__).resolve().parents[3]; HERE=Path(__file__).parent
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/night'),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools')]
import cel_style as cel
import cs1_build as cs
BASE=cel.GAME_SPRITES/'characters/ardent'; OUT=BASE/'skins/ardent_avant_la_pluie'
WORK=ROOT/'art/blender/cel/skins'; RAW=WORK/'ardent_avant_la_pluie_frames'
NAMES={'idle':8,'run':8,'attack':5,'cast':6,'cast_ult':8,'portrait':1}

def materials():
 import bpy
 def linear(h):
  rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
  return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
 mapping={'Frayed rain cloak woven umber':('8A8070',.9,0),'Oiled charcoal leather':('5E3F28',.82,0),'Patinated bronze plates':('8A8070',.9,0),'Black forged iron':('5A5B5E',.85,0),'Charred torch haft':('B4733A',.24,.7),'Deep hood interior':('5A5B5E',.9,0),'Worn brass edges and rivets':('B4733A',.3,.65)}
 for m in bpy.data.materials:
  if m.name not in mapping or not m.use_nodes:continue
  if any(n.type=='BSDF_PRINCIPLED' and (n.inputs['Emission Strength'].default_value>.01 or m.get('rainfall_emissive')) for n in m.node_tree.nodes):
   m['cel_done']=True
   continue
  h,r,metal=mapping[m.name]; b=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
  if not b:continue
  col=linear(h);m.diffuse_color=col;b.inputs['Base Color'].default_value=col;b.inputs['Roughness'].default_value=r;b.inputs['Metallic'].default_value=metal
  for n in m.node_tree.nodes:
   if n.type=='VALTORGB':
    scales=(.5,.72,.9) if m.get('cel_done') else (1,1,1)
    for i,e in enumerate(n.color_ramp.elements):e.color=tuple(c*scales[min(i,2)] for c in col[:3])+(1,)
 # Restore the approved ember orange (sRGB #FF8C33) independently of the cel palette.
 ember=linear('FF8C33')
 for name in ('Flame hot heart same orange','Single emissive accent - ash lord orange'):
  m=bpy.data.materials.get(name)
  if not m or not m.use_nodes:continue
  for n in m.node_tree.nodes:
   if n.type=='BSDF_PRINCIPLED':n.inputs['Emission Color'].default_value=ember
   elif n.type=='EMISSION':n.inputs['Color'].default_value=ember
 if bpy.context.scene.get('allumeur_surface'):return
 bpy.context.scene['allumeur_surface']=True
 wool=bpy.data.materials['Frayed rain cloak woven umber'];leather=bpy.data.materials['Oiled charcoal leather'];copper=bpy.data.materials['Worn brass edges and rivets']
 def assign(o,m):
  o.data.materials.clear();o.data.materials.append(m)
 # Reuse all contour vertices: upper hood becomes leather cap, lower drape wool collar.
 hood=bpy.data.objects['Draped open rain hood'];assign(hood,wool);hood.data.materials.append(leather)
 for f in hood.data.polygons:
  f.material_index=int(sum(hood.data.vertices[i].co.z for i in f.vertices)/len(f.vertices)>.17)
 hood.name='Leather cap crown and wool collar'
 for o in list(bpy.context.scene.objects):
  if o.type!='MESH':continue
  if o.name.startswith('Rolled hood opening'):assign(o,wool)
  if o.name.startswith(('Coat raised seam','Fitted cuirass')):assign(o,wool)
  if o.name.startswith(('Soft travel satchel','Satchel folded flap')):assign(o,copper);o.name='Copper oil can '+o.name
 def cube(name,parent,loc,scale,mat,bevel=.005):
  bpy.ops.mesh.primitive_cube_add(size=1)
  o=bpy.context.object;o.name=name;o.parent=parent;o.location=loc;o.scale=scale
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);assign(o,mat)
  if bevel:
   mod=o.modifiers.new('Rounded surface edges','BEVEL');mod.width=bevel;mod.segments=2;o.modifiers.new('Surface normals','WEIGHTED_NORMAL')
  return o
 head=bpy.data.objects['Hood and face'];torch=bpy.data.objects['Torch'];torso=bpy.data.objects['Torso']
 cube('Short leather cap peak',head,(0,-.092,.188),(.17,.045,.013),leather,.006)
 cube('Oil can screw cap',torso,(-.2,.055,.081),(.043,.04,.014),copper,.004)
 # Recolor the existing flame volume as a readable three-tone lantern ember.
 ember=bpy.data.materials.new('Lantern ember orange #FF8C33');ember.use_nodes=True;ember['cel_done']=True;ember['rainfall_emissive']=True
 en=ember.node_tree.nodes.get('Principled BSDF');en.inputs['Base Color'].default_value=linear('FF8C33');en.inputs['Emission Color'].default_value=linear('FF8C33');en.inputs['Emission Strength'].default_value=1.4
 # One small hot core gives the center the approved #FFC878 highlight.
 coremat=bpy.data.materials.new('Lantern ember hot core #FFC878');coremat.use_nodes=True;coremat['cel_done']=True;coremat['rainfall_emissive']=True
 cn=coremat.node_tree.nodes.get('Principled BSDF');cn.inputs['Base Color'].default_value=linear('FFC878');cn.inputs['Emission Color'].default_value=linear('FFC878');cn.inputs['Emission Strength'].default_value=1.8
 glass=bpy.data.materials.new('Clear lantern glass #E8D9C8');glass.use_nodes=True;glass['cel_done']=True
 nodes=glass.node_tree.nodes;nodes.clear();out=nodes.new('ShaderNodeOutputMaterial');mix=nodes.new('ShaderNodeMixShader');mix.inputs[0].default_value=.01
 transparent=nodes.new('ShaderNodeBsdfTransparent');bs=nodes.new('ShaderNodeBsdfPrincipled');bs.inputs['Base Color'].default_value=linear('E8D9C8');bs.inputs['Roughness'].default_value=.15
 links=glass.node_tree.links;links.new(transparent.outputs[0],mix.inputs[1]);links.new(bs.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],out.inputs[0])
 leading=glass.copy();leading.name='Transparent copper lantern leading'
 for node in leading.node_tree.nodes:
  if node.type=='BSDF_PRINCIPLED':node.inputs['Base Color'].default_value=linear('B4733A')
  if node.type=='MIX_SHADER':node.inputs[0].default_value=.06
 for o in list(bpy.context.scene.objects):
  if o.name.startswith('Living flame tongue'):
   assign(o,ember)
   for face in o.data.polygons:face.material_index=int(face.index%7==0);o.data.materials.append(coremat) if len(o.data.materials)<2 else None
   shell=o.copy();shell.data=o.data.copy();bpy.context.collection.objects.link(shell);shell.name='Lantern glass pane';shell.scale*=1.001;assign(shell,glass);shell.data.materials.append(leading)
   for face in shell.data.polygons:face.material_index=int(face.index%43==0)
 # Copper leading uses the pane faces, so animated fire cannot expose an external cage.


def limit_outside():
 # Blender compositor removes inherited isolated source specks beyond the approved contour.
 # Pillow only crops and reassembles cells; all alpha editing is performed by Blender.
 import bpy,numpy as np
 from PIL import Image
 changed=[]
 for name,n in NAMES.items():
  cell=256 if name=='portrait' else 192;rows=1 if name=='portrait' else 8
  sheet=Image.open(OUT/(name+'.png')).convert('RGBA');ref=Image.open(BASE/(name+'.png')).convert('RGBA')
  for y in range(rows):
   for x in range(n):
    box=(x*cell,y*cell,(x+1)*cell,(y+1)*cell);source=sheet.crop(box);reference=ref.crop(box)
    aa=np.asarray(reference)[...,3]>128;bb=np.asarray(source)[...,3]>128;inside=np.argwhere(aa)
    if not any(((inside-v)**2).sum(1).min()>4 for v in np.argwhere(bb&~aa)):continue
    work=RAW/'contour';work.mkdir(parents=True,exist_ok=True);src=work/f'{name}_{y}_{x}_source.png';mask=work/f'{name}_{y}_{x}_reference.png';dest=work/f'{name}_{y}_{x}_bounded.png'
    source.save(src);reference.save(mask)
    scene=bpy.data.scenes.new('Approved contour boundary');scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=1
    camera=bpy.data.objects.new('Contour camera',bpy.data.cameras.new('Contour camera'));scene.collection.objects.link(camera);scene.camera=camera
    scene.render.resolution_x=scene.render.resolution_y=cell;scene.render.resolution_percentage=100;scene.render.film_transparent=True
    scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
    tree=bpy.data.node_groups.new('Approved alpha envelope','CompositorNodeTree');tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor');scene.compositing_node_group=tree
    nodes=tree.nodes;links=tree.links
    image=nodes.new('CompositorNodeImage');image.image=bpy.data.images.load(str(src),check_existing=False)
    baseline=nodes.new('CompositorNodeImage');baseline.image=bpy.data.images.load(str(mask),check_existing=False)
    threshold=nodes.new('ShaderNodeMath');threshold.operation='GREATER_THAN';threshold.inputs[1].default_value=128.5/255;links.new(baseline.outputs['Alpha'],threshold.inputs[0])
    dilate=nodes.new('CompositorNodeDilateErode');dilate.inputs['Type'].default_value='Distance';dilate.inputs['Size'].default_value=1;links.new(threshold.outputs[0],dilate.inputs['Mask'])
    minimum=nodes.new('ShaderNodeMath');minimum.operation='MINIMUM';links.new(dilate.outputs[0],minimum.inputs[0]);links.new(image.outputs['Alpha'],minimum.inputs[1])
    alpha=nodes.new('CompositorNodeSetAlpha');alpha.inputs['Type'].default_value='Replace Alpha';links.new(image.outputs['Image'],alpha.inputs['Image']);links.new(minimum.outputs[0],alpha.inputs['Alpha'])
    output=nodes.new('NodeGroupOutput');links.new(alpha.outputs[0],output.inputs['Image']);scene.render.filepath=str(dest)
    bpy.ops.render.render(scene=scene.name,write_still=True)
    with Image.open(dest) as im:sheet.paste(im.convert('RGBA'),(x*cell,y*cell))
    changed.append([name,y,x]);bpy.data.scenes.remove(scene);bpy.data.objects.remove(camera,do_unlink=True)
  sheet.save(OUT/(name+'.png'),optimize=True,compress_level=9)
 (RAW/'contour_corrections.json').write_text(json.dumps(changed))

def render():
 import bpy,iso_rig as iso
 if '--clip-only' in sys.argv:limit_outside();print('PASS contour boundary',flush=True);return
 cel.TONE_SCALES=(.5,.72,.9)
 def install_surface():
  configure=cel.install('creature',normals=False)
  # Keep flame, ember, and illuminated glass materials out of recoloring.
  for m in bpy.data.materials:
   if m.use_nodes and any(n.type=='BSDF_PRINCIPLED' and (n.inputs['Emission Strength'].default_value>.01 or m.get('rainfall_emissive')) for n in m.node_tree.nodes):m['cel_done']=True
  cel.toon_materials('creature',only_new=True)
  def accent_surface(path):
   configure(path)
   scene=bpy.context.scene;tree=getattr(scene,'node_tree',None) or scene.compositing_node_group;nodes=tree.nodes;links=tree.links
   layer=next(n for n in nodes if n.bl_idname=='CompositorNodeRLayers');output=next(n for n in nodes if n.bl_idname=='NodeGroupOutput');previous=output.inputs['Image'].links[0].from_socket
   # Transparent glass must not turn the unchanged ember into normal-pass crease ink.
   dot=nodes.new('ShaderNodeVectorMath');dot.operation='DOT_PRODUCT';dot.inputs[1].default_value=(.333,.333,.333);links.new(layer.outputs[cel.AOV],dot.inputs[0])
   mask=nodes.new('ShaderNodeMath');mask.operation='GREATER_THAN';mask.inputs[1].default_value=.001;links.new(dot.outputs['Value'],mask.inputs[0])
   erode=next(n for n in nodes if n.bl_idname=='CompositorNodeDilateErode')
   core=nodes.new('ShaderNodeMath');core.operation='MULTIPLY';links.new(mask.outputs[0],core.inputs[0]);links.new(erode.outputs[0],core.inputs[1])
   inverse=nodes.new('ShaderNodeMath');inverse.operation='SUBTRACT';inverse.inputs[0].default_value=1;links.new(core.outputs[0],inverse.inputs[1])
   body=nodes.new('ShaderNodeVectorMath');body.operation='MULTIPLY';links.new(previous,body.inputs[0]);links.new(inverse.outputs[0],body.inputs[1])
   glow=nodes.new('ShaderNodeVectorMath');glow.operation='MULTIPLY_ADD';links.new(layer.outputs[cel.AOV],glow.inputs[0]);links.new(core.outputs[0],glow.inputs[1]);links.new(body.outputs[0],glow.inputs[2])
   alpha=nodes.new('CompositorNodeSetAlpha');alpha.inputs['Type'].default_value='Replace Alpha';links.new(glow.outputs[0],alpha.inputs['Image']);links.new(layer.outputs['Alpha'],alpha.inputs['Alpha']);links.new(alpha.outputs[0],output.inputs['Image'])
  iso.common.configure_passes=accent_surface
 from PIL import Image
 import cel_heroes_a_build as legacy,p1_build as p1
 WORK.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
 bpy.context.preferences.filepaths.save_version=0
 src=textwrap.dedent(inspect.getsource(iso.render_frame)).replace("('_n','_e')","('_e',)")
 exec(compile(src,inspect.getsourcefile(iso.render_frame),'exec'),iso.__dict__)
 iso.optimize_png=lambda *a,**k:None
 original=iso.render_frame
 for source,anims in cs.SPECS['ardent']['sources']:
  if '--portrait-only' in sys.argv:continue
  bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender'/source));materials();install_surface();bpy.context.scene.eevee.taa_render_samples=16
  bpy.ops.wm.save_as_mainfile(filepath=str(WORK/('ardent_avant_la_pluie.blend' if 'iso' in source else 'ardent_avant_la_pluie_actions.blend')))
  s=bpy.context.scene;root=bpy.data.objects['Ardent_Root']
  for anim,(start,count) in anims.items():
   if '--resume' in sys.argv and (OUT/(anim+'.png')).exists():continue
   sheet=Image.new('RGBA',(count*192,1536))
   for row,d in enumerate(cs.DIRS):
    root.rotation_euler.z=iso.DIRECTIONS[d]
    for i in range(count):
     s.frame_set(start+i);p=RAW/anim/f'{d}_{i:02}.png'
     if not ('--resume' in sys.argv and p.exists()):original(p)
     with Image.open(p) as im:sheet.paste(im,(i*192,row*192))
   sheet.save(OUT/(anim+'.png'),optimize=True,compress_level=9)
   shutil.copy2(BASE/(anim+'_e.png'),OUT/(anim+'_e.png'))

 if '--portrait-only' in sys.argv or not ('--resume' in sys.argv and (OUT/'portrait.png').exists()):
  def portrait_frame(path,passes=True):
   materials();install_surface();bpy.context.scene.eevee.taa_render_samples=16;return original(path,passes)
  iso.render_frame=portrait_frame;p1.OUT=OUT;legacy.adapt(p1.build,trim=True)()
  RAW.mkdir(parents=True,exist_ok=True);shutil.copy2(OUT/'portrait_e.png',RAW/'portrait_e.png')
  shutil.copy2(BASE/'portrait_e.png',OUT/'portrait_e.png')
 limit_outside()
 print('PASS render allumeur',flush=True)

def verify():
 import numpy as np
 from PIL import Image
 results=[]
 for name,n in NAMES.items():
  cell=256 if name=='portrait' else 192;rows=1 if name=='portrait' else 8
  rel=(OUT/(name+'.png')).relative_to(cel.GAME_SPRITES).as_posix()
  r=cel.check_sheet(rel,cell=cell,frames=n,rows=rows,normals=False)
  a=np.asarray(Image.open(BASE/(name+'.png')).convert('RGBA'));b=np.asarray(Image.open(OUT/(name+'.png')).convert('RGBA'))
  assert a.shape==b.shape
  vals=[]
  for y in range(rows):
   for x in range(n):
    aa=a[y*cell:(y+1)*cell,x*cell:(x+1)*cell,3]>128;bb=b[y*cell:(y+1)*cell,x*cell:(x+1)*cell,3]>128
    v=float((aa&bb).sum()/max(1,(aa|bb).sum()));vals.append(v);assert v>.95,(name,y,x,v)
  e=np.asarray(Image.open(OUT/(name+'_e.png')).convert('RGBA'));ref=np.asarray(Image.open(BASE/(name+'_e.png')).convert('RGBA'))
  assert np.array_equal(e,ref) and (e[...,:3].max(2)*e[...,3].astype(float)/255).max()>2
  assert e.shape[:2]==((b.shape[0]+1)//2,(b.shape[1]+1)//2)
  def outside_distance(aa,bb):
   added=np.argwhere(bb & ~aa);inside=np.argwhere(aa)
   return max((float(np.sqrt(((inside-v)**2).sum(1).min())) for v in added),default=0.)
  distances=[];contrasts=[]
  for y in range(rows):
   for x in range(n):
    ca=a[y*cell:(y+1)*cell,x*cell:(x+1)*cell];cb=b[y*cell:(y+1)*cell,x*cell:(x+1)*cell]
    aa=ca[...,3]>128;bb=cb[...,3]>128
    distance=outside_distance(aa,bb);distances.append(distance);assert distance<=2,(name,y,x,'outside',distance)
    rgb=cb[...,:3][bb].astype(float)/255;rgb=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
    lum=rgb@np.array([.2126,.7152,.0722]);lab=116*np.cbrt(np.maximum(lum,.008856))-16
    contrasts.append(float(np.median(lab)))
  rendered=[]
  for y in range(rows):
   for x in range(n):
    q=(RAW/'portrait_e.png') if name=='portrait' else RAW/name/f'{cs.DIRS[y]}_{x:02}_e.png'
    if not q.exists():continue
    ec=cell//2;rr=ref[y*ec:(y+1)*ec,x*ec:(x+1)*ec]
    actual=np.asarray(Image.open(q).convert('RGBA').resize((ec,ec),Image.Resampling.LANCZOS))
    aa=(rr[...,:3].max(2)>100)&(rr[...,3]>128);bb=(actual[...,:3].max(2)>100)&(actual[...,3]>128)
    v=float((aa&bb).sum()/(aa|bb).sum()) if (aa|bb).any() else 1.;rendered.append(v)
  r.update(alpha_iou_cells=vals,accent_iou=1.0,source_render_vs_approved_accent_iou_min=min(rendered) if rendered else None,outside_px_max=max(distances),median_Lstar_min=min(contrasts));results.append(r)
 assert not list(OUT.rglob('*_n.png'))
 import re
 original=(BASE/'ardent.tres').read_text();resource=(OUT/'ardent_avant_la_pluie.tres').read_text()
 assert re.findall(r'\"name\": &\"([^\"]+)',original)==re.findall(r'\"name\": &\"([^\"]+)',resource)
 assert 'CanvasTexture' not in resource and 'normal_texture' not in resource
 assert resource==original.replace('res://assets/sprites/characters/ardent/','res://assets/sprites/characters/ardent/skins/ardent_avant_la_pluie/')
 idle=np.asarray(Image.open(OUT/'idle.png').convert('RGBA'));valid=idle[...,3]>128;rgb=idle[...,:3][valid].astype(float)/255;lin=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4);lum=lin@np.array([.2126,.7152,.0722]);mean_L=float((116*np.cbrt(np.maximum(lum,.008856))-16).mean())
 ref=np.asarray(Image.open(BASE/'idle.png').convert('RGBA'));valid0=ref[...,3]>128;rgb0=ref[...,:3][valid0].astype(float)/255;lin0=np.where(rgb0<=.04045,rgb0/12.92,((rgb0+.055)/1.055)**2.4);lum0=lin0@np.array([.2126,.7152,.0722]);old_L=float((116*np.cbrt(np.maximum(lum0,.008856))-16).mean())
 hsv=idle[...,:3].astype(float)/255;mx=hsv.max(2);mn=hsv.min(2);sat=np.divide(mx-mn,mx,out=np.zeros_like(mx),where=mx>0);hue=np.zeros_like(mx);d=mx-mn;r0,g0,b0=np.moveaxis(hsv,-1,0);sel=(d>0)&(mx==r0);hue[sel]=((g0[sel]-b0[sel])/d[sel])%6;sel=(d>0)&(mx==g0);hue[sel]=(b0[sel]-r0[sel])/d[sel]+2;sel=(d>0)&(mx==b0);hue[sel]=(r0[sel]-g0[sel])/d[sel]+4;hue*=60
 accent=np.asarray(Image.open(OUT/'idle_e.png').convert('RGBA').resize((idle.shape[1],idle.shape[0]),Image.Resampling.NEAREST));zone=(accent[...,3]>0)&valid;orange=zone&(hue>=15)&(hue<=40)&(sat>.5);orange_share=float(orange.sum()/max(1,zone.sum()));blue=zone&(hue>=170)&(hue<=260)&(sat>.25);assert orange_share>=.55,orange_share;assert not blue.any(),int(blue.sum());assert mean_L<=34,mean_L
 png_bytes=sum(p.stat().st_size for p in OUT.glob('*.png'))
 (HERE/'_panoplie_ardent_avant_la_pluie_verification.json').write_text(json.dumps({'checks':results,'animation_names':re.findall(r'"name": &"([^"]+)',resource),'idle_mean_Lstar_before':old_L,'idle_mean_Lstar_after':mean_L,'lantern_orange_share':orange_share,'lantern_blue_pixels':int(blue.sum()),'png_bytes':png_bytes,'emission':'Original approved masks retained verbatim.'},indent=2)) # contact_pair uses separate roots; map left side to default via a tiny path adapter.
 class DefaultRoot:
  def __truediv__(self,rel):return BASE/Path(rel).name
 old=cel.ARCHIVE;cel.ARCHIVE=DefaultRoot()
 samples=[[(str((OUT/(name+'.png')).relative_to(cel.GAME_SPRITES)),256 if name=='portrait' else 192,col,row) for name,col,row in line] for line in [[('idle',2,2),('run',4,1),('attack',2,2)],[('cast_ult',4,3),('portrait',0,0)]]]
 cel.contact_pair(samples,HERE/'_panoplie_ardent_avant_la_pluie_contact.png',size=(1024,640));cel.ARCHIVE=old
 expected={name+s+'.png' for name in NAMES for s in ('','_e')}|{'ardent_avant_la_pluie.tres'}
 assert {p.name for p in OUT.iterdir() if p.suffix!='.import'}==expected
 print('PASS verification',flush=True)

def driver():
 OUT.mkdir(parents=True,exist_ok=True)
 if '--verify-only' not in sys.argv:
  with (HERE/'_logpanoplie_ardent.txt').open('w') as log:
   subprocess.run([cel.BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']+[v for v in ('--resume','--portrait-only','--clip-only') if v in sys.argv],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
 text=(BASE/'ardent.tres').read_text();old='res://assets/sprites/characters/ardent/'
 (OUT/'ardent_avant_la_pluie.tres').write_text(text.replace(old,old+'skins/ardent_avant_la_pluie/'),encoding='utf-8')
 verify()
if __name__=='__main__':
 if '--render' in sys.argv:render()
 else:driver()
