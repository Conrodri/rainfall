"""Gresille A: Blender Eevee geometry at delivery resolution; Python --pack verifies.

Dimetric camera/setup adapted from art/tools/averse_vfx/burst_build.py.
All strokes are polygonal meshes, including sharp mitered lightning cores.
"""
import math
import random
import sys
from pathlib import Path

ROOT = Path(r'C:\Users\const\Documents\Rainfall\.claude\worktrees\agent-a989f232cfdebff08')
RAW = ROOT / 'art/renders/gresille_vfx'
OUT = ROOT / 'game/assets/sprites/vfx/gresille'
SPECS = {'arc_tile': (256, 48, 4, 4), 'static_crawl': (64, 64, 4, 1),
         'zap_flash': (96, 96, 3, 1), 'discharge_burst': (192, 192, 6, 1),
         'bolt_strike': (192, 384, 6, 1)}
EMISSION = {'arc_tile', 'bolt_strike'}


def render():
    import bpy
    from mathutils import Vector
    sys.path.insert(0, str(ROOT / 'art/tools/cel'))
    import cel_style as cel
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    cel.setup_scene(s, 16)
    cel.install('vfx', normals=False)
    for layer in s.view_layers:
        layer.use_pass_normal = False
    s.render.resolution_percentage = 100
    s.render.image_settings.color_depth = '8'
    s.render.image_settings.compression = 100
    s.world = bpy.data.worlds.new('Transparent ambient')
    cam = bpy.data.cameras.new('Dimetric 2:1')
    ob = bpy.data.objects.new('Camera', cam)
    s.collection.objects.link(ob)
    ob.location = (0, -10 * math.cos(math.pi / 6), 5)
    ob.rotation_euler = (-ob.location).to_track_quat('-Z', 'Y').to_euler()
    cam.type = 'ORTHO'
    s.camera = ob
    right = Vector((1, 0, 0))
    up = Vector((0, .5, math.sqrt(3)/2))
    front = ob.location.normalized()
    light = bpy.data.lights.new('Upper left', 'SUN')
    light.energy = 3.6
    sun = bpy.data.objects.new('Upper left', light)
    s.collection.objects.link(sun)
    sun.rotation_euler = Vector((3, 4, -7)).to_track_quat('-Z', 'Y').to_euler()
    cache = {}
    count = 0

    def material(rgb, alpha):
        key = (rgb, round(alpha, 3))
        if key in cache:
            return cache[key]
        m = bpy.data.materials.new('Arc %s %s' % key)
        m.use_nodes = True
        m.surface_render_method = 'DITHERED'
        tree = m.node_tree
        tree.nodes.clear()
        out = tree.nodes.new('ShaderNodeOutputMaterial')
        glow = tree.nodes.new('ShaderNodeEmission')
        glow.inputs['Color'].default_value = tuple(((v/255+.055)/1.055)**2.4 for v in rgb) + (1,)
        transparent = tree.nodes.new('ShaderNodeBsdfTransparent')
        mix = tree.nodes.new('ShaderNodeMixShader')
        mix.inputs[0].default_value = alpha
        tree.links.new(transparent.outputs[0], mix.inputs[1])
        tree.links.new(glow.outputs[0], mix.inputs[2])
        tree.links.new(mix.outputs[0], out.inputs[0])
        cache[key] = m
        return m

    def mesh(points, faces, rgb, alpha, depth):
        verts = [tuple(right*(x-w/2) + up*(h/2-y) + front*depth) for x,y in points]
        data = bpy.data.meshes.new('Sharp arc geometry')
        data.from_pydata(verts, [], faces)
        data.materials.append(material(rgb, alpha))
        obj = bpy.data.objects.new('Arc', data)
        s.collection.objects.link(obj)
        generated.append(obj)

    def ribbon(points, width, rgb, alpha, depth):
        verts = []
        for i,p in enumerate(points):
            a = points[max(0,i-1)]
            b = points[min(len(points)-1,i+1)]
            dx,dy = b[0]-a[0],b[1]-a[1]
            length = max(.001, math.hypot(dx,dy))
            # Taper secondary tips; endpoints of tile stay anchored and equal.
            radius = width/2
            verts.extend([(p[0]-dy/length*radius,p[1]+dx/length*radius),
                          (p[0]+dy/length*radius,p[1]-dx/length*radius)])
        mesh(verts, [(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(points)-1)], rgb, alpha, depth)

    def arc(points, width=3, alpha=1):
        if name == 'arc_tile':
            points = [(x, min(h-4, max(4, y))) for x,y in points]
        ribbon(points, width, (185,166,255), alpha, .1)
        ribbon(points, max(.65,width*.30), (242,238,255), alpha, .3)

    def jagged(start, end, width, alpha, forks=0, jitter=7):
        dx,dy = end[0]-start[0],end[1]-start[1]
        length = max(1,math.hypot(dx,dy))
        pts=[start]
        for i in range(1,7):
            t=i/7
            off=rng.uniform(.35,1)*jitter * (-1 if i%2 else 1)
            pts.append((start[0]+dx*t-dy/length*off, start[1]+dy*t+dx/length*off))
        pts.append(end)
        arc(pts,width,alpha)
        for k in range(forks):
            p=pts[2+k%4]
            sign=(-1 if k%2 else 1)
            q=(p[0]+dx*.11-dy/length*sign*jitter*1.4,
               p[1]+dy*.11+dx/length*sign*jitter*1.4)
            r=(q[0]+dx*.10+dy/length*sign*jitter*.5,
               q[1]+dy*.10-dx/length*sign*jitter*.5)
            arc([p,q,r], max(.8,width*.48),alpha*.82)

    def core(x,y,r,alpha):
        points=[(x,y-r),(x+r*.35,y-r*.28),(x+r,y),
                (x+r*.28,y+r*.3),(x,y+r),(x-r*.32,y+r*.24),
                (x-r,y),(x-r*.3,y-r*.3)]
        mesh(points,[tuple(range(8))],(242,238,255),alpha,.5)

    def ring(x,y,r,width,alpha,phase=0):
        for k in range(7):
            a=phase+k*math.tau/7
            pts=[(x+r*math.cos(a+j*.10),y+r*.5*math.sin(a+j*.10)) for j in range(7)]
            arc(pts,width,alpha)

    RAW.mkdir(parents=True,exist_ok=True)
    for name,(w,h,cols,rows) in SPECS.items():
        cam.ortho_scale = max(w,h)
        for row in range(rows):
            for f in range(cols):
                generated=[]
                rng=random.Random(801+row*71+f*19+list(SPECS).index(name)*701)
                if name=='arc_tile':
                    jagged((-3,24),(259,24),3.3,1,3,8+row*.8)
                elif name=='static_crawl':
                    for k in range(3):
                        a=(f*.9+k*math.tau/3)
                        p=(32+20*math.cos(a),32+21*math.sin(a))
                        q=(32+20*math.cos(a+.62),32+21*math.sin(a+.62))
                        jagged(p,q,1.8,.88,0,2.8)
                elif name=='zap_flash':
                    radius=(22,39,33)[f]
                    alpha=(.80,1,.34)[f]
                    for k in range(6):
                        a=k*math.tau/6+.11*f
                        r=radius*rng.uniform(.74,1)
                        jagged((48,48),(48+r*math.cos(a),48+r*math.sin(a)),(2.5,4,1.6)[f],alpha,0,3)
                    core(48,48,(5,11,2)[f],alpha)
                elif name=='discharge_burst':
                    radius=(24,47,67,79,84,86)[f]
                    alpha=(.75,1,.95,.68,.35,.13)[f]
                    for k in range(8):
                        a=k*math.tau/8-.14
                        r=radius*rng.uniform(.83,1)
                        start=(96,104) if f<4 else (96+r*.46*math.cos(a),104+r*.46*math.sin(a))
                        jagged(start,(96+r*math.cos(a),104+r*math.sin(a)),(2.5,4.2,3.4,2.4,1.5,1)[f],alpha,1 if f<4 else 0,5)
                    ring(96,116,radius,2.6 if f<4 else 1.2,alpha,.12*f)
                    if f<5: core(96,104,(6,14,11,7,3)[f],alpha)
                else:
                    alpha=(.66,1,1,.65,.32,.12)[f]
                    width=(1.8,10,12,6,3,1.2)[f]
                    jagged((96,6),(96,325),width,alpha,3,20)
                    ring(96,329,(28,56,72,80,83,85)[f],(1.5,4,4,2.5,1.5,1)[f],alpha,.12*f)
                    for k in range(5):
                        a=k*math.tau/5+.2
                        r=(12,34,42,37,24,18)[f]
                        jagged((96,325),(96+r*math.cos(a),325+r*.52*math.sin(a)),max(1,width*.35),alpha,0,3)
                    core(96,325,(3,16,20,10,5,2)[f],alpha)
                s.render.resolution_x=w
                s.render.resolution_y=h
                s.render.filepath=str(RAW/('%s_%d_%d.png'%(name,row,f)))
                bpy.ops.render.render(write_still=True)
                count+=1
                if name in EMISSION:
                    s.render.resolution_x=w//2
                    s.render.resolution_y=h//2
                    s.render.filepath=str(RAW/('%s_%d_%d_e.png'%(name,row,f)))
                    bpy.ops.render.render(write_still=True)
                for obj in generated:
                    data=obj.data
                    bpy.data.objects.remove(obj,do_unlink=True)
                    bpy.data.meshes.remove(data)
    cel.uninstall()
    print('PASS render: %d frames, Eevee 16, no normal maps'%count)


def pack():
    from PIL import Image
    import hashlib
    import numpy as np
    total=0
    contact=Image.new('RGBA',(768,1800),(26,23,34,255))
    contact_y=8
    for name,(w,h,cols,rows) in SPECS.items():
        target=OUT/name
        target.mkdir(parents=True,exist_ok=True)
        images=[]
        for suffix in ('','_e') if name in EMISSION else ('',):
            factor=2 if suffix else 1
            tw,th=w//factor,h//factor
            sheet=Image.new('RGBA',(tw*cols,th*rows))
            hashes=set()
            for row in range(rows):
                for f in range(cols):
                    with Image.open(RAW/('%s_%d_%d%s.png'%(name,row,f,suffix))) as src:
                        tile=src.convert('RGBA')
                    assert tile.size==(tw,th),(name,tile.size)
                    a=np.asarray(tile)
                    assert a[:,:,3].max()>20 and a[:,:,3].min()==0,name
                    assert (a[:,:,3]>0).sum()>8,name
                    visible=a[a[:,:,3]>64,:3]
                    assert visible.size and visible.max()-visible.min()>8,name
                    if not suffix:
                        box=tile.getbbox()
                        assert box[1]>=2 and box[3]<=h-2,(name,box)
                        if name!='arc_tile':
                            assert box[0]>=2 and box[2]<=w-2,(name,box)
                        else:
                            assert a[24,0,3]>100 and a[24,-1,3]>100,'tile anchors'
                        images.append(tile.copy())
                    hashes.add(hashlib.sha256(tile.tobytes()).digest())
                    sheet.paste(tile,(f*tw,row*th))
            assert len(hashes)==cols*rows,(name,'duplicate frames')
            path=target/(name+suffix+'.png')
            sheet.save(path,optimize=True,compress_level=9)
            total+=path.stat().st_size
        per_row=768//w
        for i,tile in enumerate(images):
            contact.alpha_composite(tile,((i%per_row)*w,contact_y+(i//per_row)*h))
        contact_y+=math.ceil(len(images)/per_row)*h+12
    assert total<=1200000,total
    assert not any(p for name in SPECS for p in (OUT/name).glob('*_n.png'))
    contact.crop((0,0,768,contact_y)).save(RAW/'controle_a.png',optimize=True)
    print('PASS dimensions alpha contrast distinct frames: 35; PNG: 7; bytes: %d; contact: 768x%d'%(total,contact_y))


if __name__=='__main__':
    pack() if '--pack' in sys.argv else render()
