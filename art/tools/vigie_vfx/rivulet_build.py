"""Build rivulet tile and burst sprite sheets with Blender cel materials."""
import math, os, random, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'game/assets/sprites/characters/averse/variants'
WORK = ROOT / 'art/blender/rivulet'
sys.path.insert(0, str(ROOT / 'art/tools/cel'))

def render():
    import bpy, cel_style as cel
    from mathutils import Vector
    from pathlib import Path
    sys.path.insert(0, str(ROOT / 'art/tools/bosses'))
    import boss_common as common
    for name, w, h, count in [('rivulet_tile',128,128,8),('rivulet_burst',768,256,7)]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        s=bpy.context.scene; cel.setup_scene(s,8)
        s.render.resolution_x=w*2; s.render.resolution_y=h*2; s.render.resolution_percentage=100
        cam=bpy.data.cameras.new('Orthographic'); ob=bpy.data.objects.new('Camera',cam); s.collection.objects.link(ob); s.camera=ob
        ob.location=(0,0,2000); cam.type='ORTHO'; cam.ortho_scale=h; cam.clip_end=4000
        cam.lens=50
        s.render.resolution_x=w*2; s.render.resolution_y=h*2
        light=bpy.data.lights.new('studio','SUN'); light.energy=2.5; lo=bpy.data.objects.new('studio',light); s.collection.objects.link(lo); lo.rotation_euler=(.4,-.5,-.5)
        mats=[common.material('deep',(.035,.075,.09)), common.material('water',(.07,.17,.20)), common.material('foam',(.54,.7,.73)), common.material('cyan',tuple(((v/255+.055)/1.055)**2.4 for v in (95,212,232)),emission=1)]
        def compositor(path):
            tree=bpy.data.node_groups.new('Rivulet emission','CompositorNodeTree'); s.compositing_node_group=tree
            tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
            nodes=tree.nodes; links=tree.links; rl=nodes.new('CompositorNodeRLayers'); out=nodes.new('NodeGroupOutput'); links.new(rl.outputs['Image'],out.inputs['Image'])
            f=nodes.new('CompositorNodeOutputFile'); f.directory=str(path.parent); f.file_name=path.stem+'_e__'; f.file_output_items.new('RGBA','Image'); f.format.media_type='IMAGE'; f.format.file_format='PNG'; f.format.color_mode='RGBA'; f.format.color_depth='8'; links.new(rl.outputs['Image'],f.inputs[0])
        common.configure_passes=compositor; configure=cel.install('vfx',normals=False)
        for frame in range(count):
            for obj in list(s.objects):
                if obj.type=='MESH': bpy.data.objects.remove(obj,do_unlink=True)
            batch=[([],[]) for _ in mats]
            def poly(points,mat,z):
                verts,faces=batch[mat]; start=len(verts); verts.extend([(x,y,z) for x,y in points]); faces.append(tuple(range(start,start+len(points))))
            def stroke(points,width,mat,z):
                for a,b in zip(points,points[1:]):
                    dx=b[0]-a[0]; dy=b[1]-a[1]; ln=math.hypot(dx,dy) or 1; x=-dy/ln*width/2; y=dx/ln*width/2
                    poly([(a[0]+x,a[1]+y),(a[0]-x,a[1]-y),(b[0]-x,b[1]-y),(b[0]+x,b[1]+y)],mat,z)
            def ellipse(x,y,rx,ry,mat,z):
                poly([(x+rx*math.cos(j*math.tau/32),y+ry*math.sin(j*math.tau/32)) for j in range(33)],mat,z)
            if name=='rivulet_tile':
                full=frame>=4; phase=math.tau*(frame%4)/4
                # Dark stone channel and edge gutters, precisely periodic at the atlas seam.
                poly([(-64,-64),(64,-64),(64,64),(-64,64)],0,0)
                for y in (-56,56): stroke([(-64,y),(64,y)],5,1,1)
                if not full:
                    for x,y in [(-47,-25),(21,30),(52,-41),(-8,48)]:
                        ellipse(x+4*math.sin(phase),y,2,3,2,2)
                    stroke([(-64,3*math.sin(phase)),(0,2*math.sin(phase+1)),(64,3*math.sin(phase))],1.6,2,2)
                else:
                    for k in range(7):
                        y=-40+k*13; pts=[(x, y+4*math.sin(x/17+phase+k*.7)) for x in range(-64,65,2)]
                        stroke(pts,4 if k%2 else 6,1,2); stroke(pts,1.5,2,3)
                    for y in (-55,55):
                        pts=[(x,y+2*math.sin(x/12+phase)) for x in range(-64,65,2)]
                        stroke(pts,2,2,3); stroke(pts,1.2,3,4)
            else:
                # Six-unit trough with a left-to-right surge, narrowing on the last frame.
                t=frame/6; front=-370+760*t; width=80 if frame<6 else 42
                poly([(-384,-26),(384,-26),(384,26),(-384,26)],1,0)
                for x in range(-372,373,32): stroke([(x,-24),(x,24)],1,0,1)
                rng=random.Random(991+frame)
                for k in range(15):
                    x=-360+k*48
                    if x <= front:
                        y=math.sin(k*2.1+frame)*width*.22
                        pts=[(x+j*5,y+6*math.sin(j*.32+k+frame*.7)) for j in range(10)]
                        stroke(pts,7,1,2); stroke(pts,2.4,2,3)
                if frame<6:
                    for j in range(7):
                        y=(j-3)*width/4
                        x=front+8*math.sin(j*2+frame)
                        stroke([(x-46,y-4),(x-24,y+5),(x,y),(x+18,y+8)],5 if j%2 else 8,2 if j%2 else 3,4)
                    for k in range(16):
                        x=front+rng.uniform(-58,34); y=rng.choice([-1,1])*rng.uniform(18,112)
                        ellipse(x,y,2,4,2 if k%3 else 3,4)
                else:
                    stroke([(x,24+3*math.sin(x/18)) for x in range(-384,385,4)],2,2,3)
            for idx,(verts,faces) in enumerate(batch):
                if faces:
                    mesh=bpy.data.meshes.new('water facets'); mesh.from_pydata(verts,[],faces); mesh.materials.append(mats[idx]); obj=bpy.data.objects.new('water facets',mesh); s.collection.objects.link(obj)
            target=WORK/name/f'{frame:02d}.png'; target.parent.mkdir(parents=True,exist_ok=True)
            configure(target); s.render.filepath=str(target); bpy.ops.render.render(write_still=True)
        cel.uninstall()
    print('RIVULET RENDER PASS',flush=True)

def pack():
    from PIL import Image
    specs=[('rivulet_tile',128,128,8,1024,128),('rivulet_burst',768,256,7,3072,512)]
    for name,w,h,count,sw,sh in specs:
        dest=OUT/name; dest.mkdir(parents=True,exist_ok=True)
        diffuse=Image.new('RGBA',(sw,sh)); emission=Image.new('RGBA',(sw//2,sh//2))
        cols=8 if name.endswith('tile') else 4
        for f in range(count):
            src=Image.open(WORK/name/f'{f:02d}.png').convert('RGBA').resize((w,h),Image.Resampling.LANCZOS)
            ep=next((WORK/name).glob(f'{f:02d}_e__*.png')); glow=Image.open(ep).convert('RGBA').resize((w//2,h//2),Image.Resampling.LANCZOS)
            if name=='rivulet_tile':
                src.paste(src.crop((0,0,1,h)),(w-1,0)); glow.paste(glow.crop((0,0,1,h//2)),(w//2-1,0))
            x=(f%cols)*w; y=(f//cols)*h; diffuse.paste(src,(x,y)); emission.paste(glow,(x//2,y//2))
        diffuse.save(dest/f'{name}.png',optimize=True); emission.save(dest/f'{name}_e.png',optimize=True)
        frames=[]
        for f in range(count):
            x=(f%cols)*w; y=(f//cols)*h
            frames.append(f'[sub_resource type="AtlasTexture" id="f{f}"]\natlas = ExtResource("0")\nregion = Rect2({x}, {y}, {w}, {h})')
        ext=f'[ext_resource type="Texture2D" path="res://assets/sprites/characters/averse/variants/{name}/{name}.png" id="0"]'
        def anim(label,ids,loop,fps):
            fs=', '.join(f'{{"duration": 1.0, "texture": SubResource("f{i}")}}' for i in ids)
            return f'{{"frames": [{fs}], "loop": {str(loop).lower()}, "name": &"{label}", "speed": {fps}}}'
        if name=='rivulet_tile': animations=[anim('empty',range(4),True,10),anim('full',range(4,8),True,10),anim('default',range(4,8),True,10)]
        else: animations=[anim('default',range(7),False,22)]
        text='[gd_resource type="SpriteFrames" format=3]\n\n'+ext+'\n\n'+'\n\n'.join(frames)+'\n\n[resource]\nanimations = ['+', '.join(animations)+']\n'
        (dest/f'{name}.tres').write_text(text,encoding='utf-8')
        if name=='rivulet_tile':
            # Keep compatibility resource synchronized with new animations.
            (dest/f'{name}_emission.tres').write_text(text.replace(f'{name}.png',f'{name}_e.png'),encoding='utf-8')
    print('RIVULET PACK PASS',flush=True)

if __name__=='__main__':
    if '--pack' in sys.argv: pack()
    else: render()
