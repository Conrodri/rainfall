"""Build rivulet tile and burst sprite sheets with Blender cel materials.

NOTE (07/11/2026) : rivulet_tile validé ; rivulet_burst REFUSÉ (aplats bleus, pas une vague volumique) et retiré
du jeu. À refaire dans un lot dédié : profil Codex `full`, effort medium, vague d'eau volumique (maillage 3D).
averse_rivulet.gd tolère l'absence du burst (ResourceLoader.exists).
"""
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
        if name=='rivulet_burst':
            from mathutils import Vector
            ob.location=(0,-520,520); ob.rotation_euler=(Vector((0,0,18))-ob.location).to_track_quat('-Z','Y').to_euler()
        else: ob.location=(0,0,2000)
        cam.type='ORTHO'; cam.ortho_scale=h; cam.clip_end=4000
        cam.lens=50
        s.render.resolution_x=w*2; s.render.resolution_y=h*2
        light=bpy.data.lights.new('studio','SUN'); light.energy=2.5; lo=bpy.data.objects.new('studio',light); s.collection.objects.link(lo); lo.rotation_euler=(.4,-.5,-.5)
        mats=[common.material('bronze',(.12,.13,.12)), common.material('stone',(.22,.23,.21)), common.material('deep',(.025,.075,.105)), common.material('water',(.10,.31,.40)), common.material('foam',(.64,.77,.79)), common.material('cyan',tuple(((v/255+.055)/1.055)**2.4 for v in (95,212,232)),emission=.65)]
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
            def quad(x0,y0,x1,y1,mat,z): poly([(x0,y0),(x1,y0),(x1,y1),(x0,y1)],mat,z)
            if name=='rivulet_tile':
                full=frame>=4; phase=math.tau*(frame%4)/4
                # Open channel bed remains translucent; raised worn masonry/bronze lips tile exactly.
                poly([(-64,-25),(64,-25),(64,25),(-64,25)],2,0)
                for y in (-33,33):
                    stroke([(-64,y),(64,y)],15,0,1); stroke([(-64,y-2),(64,y-2)],3,4,2); stroke([(-64,y+4),(64,y+4)],5,1,2)
                    for x in range(-56,64,24):
                        stroke([(x,y-3),(x+10,y-3)],1.2,4,3)
                for x in (-58,58): stroke([(x,-28),(x,28)],2,1,2)
                if not full:
                    stroke([(-64,3*math.sin(phase)),(-32,2*math.sin(phase+1)),(0,2*math.sin(phase+2)),(32,2*math.sin(phase+1)),(64,3*math.sin(phase))],2.3,3,2)
                    for k in range(4):
                        x=-46+k*29+int(5*math.sin(phase+k)); y=5*math.sin(phase*2+k*1.7)
                        ellipse(x,y,3.1,1.3,4,3)
                    stroke([(-64,4+3*math.sin(phase)),(0,4+2*math.sin(phase+1)),(64,4+3*math.sin(phase))],.8,4,3)
                    for x,y in [(-47,-25),(21,30),(52,-41),(-8,48)]: ellipse(x+3*math.sin(phase),y,2,2.5,3,3)
                else:
                    poly([(-64,-24),(64,-24),(64,24),(-64,24)],3,2)
                    for k in range(4):
                        y=-15+k*10; pts=[(x,y+2.2*math.sin(x/19+phase+k*.7)+.8*math.sin(x/7+k)) for x in range(-64,65,4)]
                        stroke(pts,2.4 if k%2 else 3.1,3,3); stroke(pts,.7,4,4)
                    for k in range(6):
                        x=-52+k*20+int(4*math.sin(phase+k)); y=7*math.sin(phase*2+k*1.3)
                        ellipse(x,y,4,1.7,4,4)
                    for y in (-21,21):
                        pts=[(x,y+1.7*math.sin(x/12+phase)) for x in range(-64,65,2)]
                        stroke(pts,1.8,4,4); stroke(pts,.9,5,5)
                    for x in (-40,-9,27,53): ellipse(x+5*math.sin(phase),18*math.sin(x+phase),1.4,2,5,5)
            else:
                # Volumetric traveling surge: subdivided displaced water surface and rounded spray.
                t=frame/6; amp=[.10,.45,.80,1,.65,.35,.12][frame]; front=-130+260*t
                water=common.material('surge water',(.035,.20,.32),roughness=.27)
                foam=common.material('surge foam',(.72,.88,.91),roughness=.34)
                cyan=common.material('surge cyan',(.08,.45,.58),emission=.35,roughness=.3)
                wp=water.node_tree.nodes.get('Principled BSDF'); wp.inputs['Alpha'].default_value=.78
                water.surface_render_method='DITHERED'
                def surface(name, material, offset=0):
                    nx,ny=96,40; verts=[]; faces=[]
                    for j in range(ny+1):
                        y=-82+164*j/ny
                        for i in range(nx+1):
                            x=front-215+430*i/nx; d=x-front
                            envelope=math.exp(-((d/205)**2))
                            width=max(0,1-(y/88)**2); longitudinal=max(0,1-(d/225)**2)
                            z=1+amp*envelope*(34+39*math.exp(-((d/54)**2)))*width
                            z+=amp*longitudinal*width*(4*math.sin(x/25+y/18+frame*.7)+2*math.sin(x/13-y/11))
                            verts.append((x,y,z+offset))
                    for j in range(ny):
                        for i in range(nx):
                            a=j*(nx+1)+i; faces.append((a,a+1,a+nx+2,a+nx+1))
                    for j in range(ny):
                        for i in range(nx):
                            x=front-215+430*(i+.5)/nx; y=-82+164*(j+.5)/ny
                            if ((x-front)/208)**2+(y/77)**2>1: faces[j*nx+i]=None
                    faces=[f for f in faces if f is not None]
                    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.materials.append(material)
                    ob=bpy.data.objects.new(name,me); s.collection.objects.link(ob)
                    for p in me.polygons: p.use_smooth=True
                surface('rounded wave body',water)
                # Foam follows the moving crest as connected, irregular patches on the 3D surface.
                for k in range(7):
                    x=front-72+k*23
                    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=1,location=(x,(-1)**k*20,12+amp*62))
                    ob=bpy.context.object; ob.name='crest foam'; ob.scale=(13,6,2.4+amp*2); ob.data.materials.append(foam)
                rng=random.Random(991+frame)
                if 2<=frame<=4:
                    for k in range(22):
                        x=front+rng.uniform(-115,105); y=rng.uniform(-62,62)
                        z=amp*rng.uniform(26,104)
                        bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=1,location=(x,y,z))
                        ob=bpy.context.object; ob.name='airborne water drop'; ob.scale=(rng.uniform(2.2,4.5),rng.uniform(2,4),rng.uniform(4,8)); ob.data.materials.append(foam if k%4==0 else cyan)
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
