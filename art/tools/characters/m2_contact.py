"""M2 contact: Pillow assembles only. Blender renders all captions and manifest wires."""
import sys,json,math
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
import m2_build as m
from PIL import Image
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/rictus.blend'))
bpy.context.view_layer.update()
actor=bpy.data.objects['Rictus'];rig=bpy.data.objects['Rictus_Rig']
head=next(o for o in actor.children_recursive if o.name.startswith('Tilted porcelain head'))
from mathutils import Vector
axis=head.matrix_world.to_3x3() @ Vector((0,0,1));angle=math.degrees(axis.angle(Vector((0,0,1))))
assert 19 < angle < 29,('head tilt',angle)
for suffix in ('L','R'):
    arm=rig.pose.bones['upper_arm.'+suffix];fore=rig.pose.bones['forearm.'+suffix]
    assert abs(arm.tail.z-arm.head.z)<.04,('high elbows',suffix)
    assert fore.head.z-fore.tail.z>.15,('hanging forearms',suffix)
print('PASS source pose / head tilt %.2f degrees / high elbows / hanging forearms'%angle,flush=True)
W,H=1820,3200
canvas=Image.new('RGBA',(W,H),(20,25,27,255));wires=[];labels=[]
manifest=json.loads((m.DEST/'rictus/strings.json').read_text())
tile=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
for row in range(9):
    for col in range(7):canvas.alpha_composite(tile,(150+col*260-256,310+row*280-115))
# Each row is an animation; each triplet shows start, impact/middle, recovery.
for row,(anim,n) in enumerate(m.ANIMS['rictus'].items()):
    labels.append((anim.upper(),14,95+row*280,22))
    y=310+row*280
    seq=[('s',0),('s',n//2),('s',n-1),('e',0),('e',n//2),('e',n-1)] if anim!='spin' else [('e',f) for f in (0,2,4,6)]
    for col,(d,f) in enumerate(seq):
        x=150+col*260
        p=(round(x-96),round(y-136.32));g=(p[0]-19,p[1]-129)
        with Image.open(m.OUT/'rictus'/anim/f'{d}_{f:02}.png') as im:canvas.alpha_composite(im,p)
        entry=manifest['animations'][anim][d][f];ma=entry['montreur_animation'];mf=entry['montreur_frame']
        ghost=Image.open(m.OUT/'montreur'/ma/f'{d}_{mf:02}.png').convert('RGBA');ghost.putalpha(ghost.getchannel('A').point(lambda a:round(a*.8)));canvas.alpha_composite(ghost,g)
        for a,b in manifest['format']['pairing'].items():
            u=entry['rictus'][a];v=entry['montreur'][b]
            wires.append(((p[0]+96+u[0],p[1]+136.32+u[1]),(g[0]+96+v[0],g[1]+136.32+v[1])))
        labels.append((f'{d.upper()} / {f}',x-40,y+25,16))
    with Image.open(m.DEST/'ardent/idle.png') as ar:ref=ar.crop((0,384,192,576))
    canvas.alpha_composite(ref,(1625,round(y-136.32)));labels.append(('ARDENT',1655,y+25,16))
# Actual front/profile renders at 3x CREA density: full suspended pose and detail crops.
for i,d in enumerate(('front','profile')):
    im=Image.open(m.OUT/('detail_'+d+'.png')).convert('RGBA');canvas.alpha_composite(im,(80+i*450,2740))
    labels.append((d.upper()+' / 3x',80+i*450,3145,18))
    feet=im.crop((70,290,310,384));canvas.alpha_composite(feet,(1000+i*300,2980))
    head=im.crop((100,0,284,150));canvas.alpha_composite(head,(1000+i*300,2770))
labels += [('RICTUS + LE MONTREUR / M2',24,35,27),('CREA 30 deg / R 90.51 px/u / pivot 96,136.32 / C1 / impact N/2 / fils aux COUDES',24,65,17),('Tete ovale penchee / bonnet trempe / fraise large / pieds articules / coudes hauts, mains pendantes',24,2718,19),('TETE + BONNET + FRAISE / 3x',990,2940,15),('CHEVILLES + PIEDS / 3x',990,3125,15),('Fils 1 px #9FC8C0 alpha .35 / Montreur alpha .8 / sources: strings.json',24,3180,17)]
s=m.base.iso_rig.create_rig('TOP',(W,H));s.eevee.taa_render_samples=8
s.camera.location=(W/2,H/2,12);s.camera.data.ortho_scale=W;s.camera.data.shift_y=0
s.render.resolution_x=W;s.render.resolution_y=H
root=m.base.empty('M2 contact overlay')
silver=m.base.material('Captions','9FC8C0',.15,True)
wire=m.base.material('Strings #9FC8C0 alpha 0.35','9FC8C0',.12,True);wire.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.35
for a,b in wires:m.base.rod('Manifest string',[(a[0],H-a[1],0),(b[0],H-b[1],0)],.50,wire,root)
for label,x,y,size in labels:
    data=bpy.data.curves.new('Caption','FONT');data.body=label;data.size=size
    ob=bpy.data.objects.new('Caption',data);s.collection.objects.link(ob);ob.location=(x,H-y,0);data.materials.append(silver)
m.base.iso_rig.render_frame(m.OUT/'contact_overlay.png',passes=False)
canvas.alpha_composite(Image.open(m.OUT/'contact_overlay.png').convert('RGBA'))
canvas.convert('RGB').save(ROOT/'art/tools/characters/_m2_contact.png',optimize=True)
print('PASS M2 contact',flush=True)
