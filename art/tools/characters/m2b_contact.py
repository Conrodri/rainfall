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
assert all(abs(v-1.15)<1e-5 for v in actor.scale),tuple(actor.scale)
pose_report={'scale':list(actor.scale),'pivot':[96,136.32],'head_tilt_degrees':angle,'pendulum_ranges':{}}
for anim in ('idle','run','stagger','lift'):
    ranges={s:[] for s in ('L','R')}
    for f in range(m.ANIMS['rictus'][anim]):
        m.pose('rictus',actor,rig,anim,f,m.ANIMS['rictus'][anim])
        for suffix in ranges:
            bone=rig.pose.bones['forearm.'+suffix];v=bone.tail-bone.head
            ranges[suffix].append(math.degrees(math.atan2(v.y,-v.z)))
    for suffix,angles in ranges.items():
        assert max(angles)-min(angles)>36,(anim,suffix,angles)
    pose_report['pendulum_ranges'][anim]=ranges
m.pose('rictus',actor,rig,'spin',0,8)
for suffix in ('L','R'):
    for name in ('upper_arm.','forearm.','hand.','dagger.'):
        bone=rig.pose.bones[name+suffix];v=(bone.tail-bone.head).normalized()
        assert abs(v.z)<1e-5,('spin horizontal',name,suffix,list(v))
        assert v.dot(rig.pose.bones['upper_arm.'+suffix].vector.normalized())>.9999,('spin straight',name,suffix)
for name in m.ANIMS['rictus']:
    assert bpy.data.actions.get('rictus_'+name),('missing action',name)
(ROOT/'art/tools/characters/_m2b_pose.json').write_text(json.dumps(pose_report,indent=2))
print('PASS M2b scale / pendulums / horizontal spin chain / saved actions',flush=True)
# Reframe the three-times-density head details after the 15 percent enlargement.
for direction,view in [('front',Vector((0,-1,0))),('profile',Vector((1,0,0)))]:
    m.pose('rictus',actor,rig,'idle',0,8);actor.rotation_euler.z=0
    s=bpy.context.scene
    s.camera.rotation_euler=(-view).to_track_quat('-Z','Y').to_euler()
    s.camera.location=Vector((0,0,1.0))+view*12;s.camera.data.shift_y=0
    m.base.iso_rig.set_frame((384,384),'CREA');s.camera.data.ortho_scale=384/(m.base.iso_rig.R*3)
    m.base.iso_rig.render_frame(m.OUT/('detail_'+direction+'.png'))
W,H=2400,3500
canvas=Image.new('RGBA',(W,H),(20,25,27,255));wires=[];labels=[]
manifest=json.loads((m.DEST/'rictus/strings.json').read_text())
tile=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
for row in range(9):
    for col in range(7):canvas.alpha_composite(tile,(150+col*260-256,310+row*280-115))
# Each row is an animation; each triplet shows start, impact/middle, recovery.
for row,(anim,n) in enumerate(m.ANIMS['rictus'].items()):
    labels.append((anim.upper(),14,95+row*280,22))
    y=310+row*280
    seq=([(d,f) for d in ('s','e') for f in (0,2,4,6)] if anim in ('idle','run') else [('s',0),('s',n//2),('s',n-1),('e',0),('e',n//2),('e',n-1)]) if anim!='spin' else [('e',f) for f in range(8)]
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
    canvas.alpha_composite(ref,(2200,round(y-136.32)));labels.append(('ARDENT',2230,y+25,16))
# Actual front/profile renders at 3x CREA density: full suspended pose and detail crops.
for i,d in enumerate(('front','profile')):
    im=Image.open(m.OUT/('detail_'+d+'.png')).convert('RGBA');canvas.alpha_composite(im,(80+i*450,3040))
    labels.append((d.upper()+' / 3x',80+i*450,3445,18))
    head=im.crop((100,0,284,220));canvas.alpha_composite(head,(1000+i*300,3070))
labels += [('RICTUS + LE MONTREUR / M2b',24,35,27),('CREA 30 deg / R 90.51 px/u / pivot 96,136.32 / C1 / impact N/2 / fils aux COUDES',24,65,17),('Tete ovale penchee / bonnet trempe / fraise large / pieds articules / coudes hauts, mains pendantes',24,3018,19),('TETE + BONNET + FRAISE / 3x',990,3310,15),('Fils 1 px #9FC8C0 alpha .35 / Montreur alpha .8 / sources: strings.json',24,3480,17)]
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
canvas.convert('RGB').save(ROOT/'art/tools/characters/_m2b_contact.png',optimize=True)
print('PASS M2 contact',flush=True)
