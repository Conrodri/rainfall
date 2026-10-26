"""UXA11Y: front-facing Eevee geometry, no normal maps, no raster drawing.
Run with Blender --background --python art/tools/night/uxa11y_build.py.
"""
import math
import sys
import subprocess
from pathlib import Path
if '--finish' not in sys.argv:
    import bpy
    from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'art/tools/cel'))
import cel_style as cel

OUT = ROOT / 'game/assets/sprites'
TMP = ROOT / 'art/tools/night'
FILES = []

def linear(v):
    v = v / 255
    return v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4

def material(name, color, toon=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    n = m.node_tree.nodes
    b = n.get('Principled BSDF')
    c = tuple(linear(int(color[i:i+2], 16)) for i in (1,3,5)) + (1,)
    if toon:
        b.inputs['Base Color'].default_value = c
    else:
        n.remove(b)
        e = n.new('ShaderNodeEmission')
        e.inputs['Color'].default_value = c
        m.node_tree.links.new(e.outputs[0], n.get('Material Output').inputs['Surface'])
    return m

def poly(points, mat, z=0):
    mesh = bpy.data.meshes.new('ui_polygon')
    mesh.from_pydata([(x, -y, z) for x,y in points], [], [list(range(len(points)))])
    mesh.update()
    ob = bpy.data.objects.new('ui_geometry', mesh)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob

def stroke(a, b, width, mat, z=0):
    d = Vector(b) - Vector(a)
    p = Vector((-d.y, d.x)).normalized() * width / 2
    poly([Vector(a)+p,Vector(b)+p,Vector(b)-p,Vector(a)-p], mat, z)

def circle(x,y,r,mat,z=0):
    poly([(x+r*math.cos(i*math.tau/64),y+r*math.sin(i*math.tau/64)) for i in range(64)],mat,z)

def offset(points, amount):
    # Mitered offset, preserving angular silhouettes and the exact ink width.
    area = sum(a[0]*b[1]-a[1]*b[0] for a,b in zip(points,points[1:]+points[:1]))
    result=[]
    for i,p in enumerate(points):
        a,b,c=Vector(points[i-1]),Vector(p),Vector(points[(i+1)%len(points)])
        u=(b-a).normalized(); v=(c-b).normalized()
        n1=Vector((u.y,-u.x)) * (1 if area>0 else -1)
        n2=Vector((v.y,-v.x)) * (1 if area>0 else -1)
        bis=n1+n2
        result.append(b+bis*(amount/max(.12,1+n1.dot(n2))))
    return result

def reset(size):
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    s=bpy.context.scene
    cam=bpy.data.cameras.new('Front orthographic')
    ob=bpy.data.objects.new('Camera',cam); s.collection.objects.link(ob)
    ob.location=(size/2,-size/2,200); cam.type='ORTHO'; cam.ortho_scale=size
    s.camera=ob
    s.render.resolution_x=s.render.resolution_y=size*4
    s.render.resolution_percentage=100
    sun=bpy.data.lights.new('Cel key','SUN'); sun.energy=2.5
    lamp=bpy.data.objects.new('Cel key',sun); s.collection.objects.link(lamp)
    lamp.rotation_euler=(.35,-.4,0)

def render(relative,size):
    path=OUT/relative; path.parent.mkdir(parents=True,exist_ok=True)
    cel.toon_materials('ui')
    s=bpy.context.scene
    s.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    subprocess.run(['python','-c',
        'from PIL import Image; import sys; p=sys.argv[1]; n=int(sys.argv[2]); '
        'im=Image.open(p).convert("RGBA").resize((n,n),Image.Resampling.LANCZOS); '
        'box=(3,3,29,29) if "status_mono_" in p else (0,0,n,n); '
        'tile=im.crop(box); out=Image.new("RGBA",(n,n)); out.paste(tile,box[:2]); '
        'out.save(p,optimize=True,compress_level=9)',
        str(path),str(size)],check=True)
    FILES.append(path)

def pictos():
    for name in ('burn','poison','frost','stun','imprisoned'):
        reset(32)
        if name=='burn':
            p=[(18,3),(17,12),(24,7),(29,19),(25,26),(16,29),(7,25),(3,18),(10,8),(11,17),(14,12)]
            poly(p,INK); poly(offset(p,-2),WHITE,.1)
        elif name=='poison':
            for x,y,r in [(11,20,5.5),(22,11,4),(9,7,2)]:
                circle(x,y,r+2,INK); circle(x,y,r,WHITE,.1)
        elif name=='frost':
            for w,m,z in [(6,INK,0),(2,WHITE,.1)]:
                for i in range(3):
                    a=i*math.pi/3
                    d=Vector((math.cos(a),math.sin(a)))*10
                    stroke(Vector((16,16))-d,Vector((16,16))+d,w,m,z)
        elif name=='stun':
            p=[(16,3),(20,12),(29,16),(20,20),(16,29),(12,20),(3,16),(12,12)]
            poly(p,INK); poly(offset(p,-2),WHITE,.1)
        else:
            lines=[((6,6),(26,6)),((6,26),(26,26)),((6,6),(6,26)),((26,6),(26,26))]
            lines += [((x,6),(x,26)) for x in (11,16,21)]
            for w,m,z in [(6,INK,0),(2,WHITE,.1)]:
                for a,b in lines: stroke(a,b,w,m,z)
        render('ui/hp_bars/status_mono_'+name+'.png',32)

def shapes():
    for name,n in [('diamond_dashed',4),('hexagon',6)]:
        reset(128)
        pts=[Vector((64+51*math.cos(i*math.tau/n),64+51*math.sin(i*math.tau/n))) for i in range(n)]
        for a,b in zip(pts,pts[1:]+pts[:1]):
            for lo,hi in ([(.10,.42),(.58,.90)] if n==4 else [(0,1)]):
                stroke(a.lerp(b,lo),a.lerp(b,hi),3,WHITE)
        # Miter joins make a continuous hexagon perimeter, no fill or glow.
        if n==6:
            outer=offset([tuple(p) for p in pts],1.5)
            inner=offset([tuple(p) for p in pts],-1.5)
            for i in range(n): poly([outer[i],outer[(i+1)%n],inner[(i+1)%n],inner[i]],WHITE)
        render('ui/shapes/'+name+'.png',128)

def frames():
    colors=['#7C8898','#5FA85B','#538BCD','#FF8C38']
    for rank,quality in enumerate(('commun','peu_commun','rare','legendaire')):
        for size in (64,128):
            reset(64)
            bpy.context.scene.render.resolution_x=bpy.context.scene.render.resolution_y=size*4
            base=material('rarity_'+quality,colors[rank],True)
            hi=material('edge_'+quality,colors[rank])
            if rank==1:
                outer=[(14,8),(50,8),(56,14),(56,50),(50,56),(14,56),(8,50),(8,14)]
            else:
                outer=[(8,8),(56,8),(56,8),(56,56),(56,56),(8,56),(8,56),(8,8)]
            inner=[(12,12),(52,12),(52,12),(52,52),(52,52),(12,52),(12,52),(12,12)]
            for i in range(8):
                p=[outer[i],outer[(i+1)%8],inner[(i+1)%8],inner[i]]
                if len(set(p))>=3: poly(p,base)
            for a,b in [((12,12),(52,12)),((52,12),(52,52)),((52,52),(12,52)),((12,52),(12,12))]:
                stroke(a,b,.8,hi,.1)
            if rank>=2:
                for sx in (-1,1):
                    for sy in (-1,1):
                        def corner(p): return [(32+sx*(x-32),32+sy*(y-32)) for x,y in p]
                        p=[(52,8),(61,3),(56,16),(52,12)] if rank==2 else [(48,8),(52,3),(54,8),(61,3),(57,11),(61,14),(56,16),(52,12)]
                        poly(corner(p),base,.05)
            if rank==3:
                for a,b in [((8,6),(56,6)),((58,8),(58,56)),((56,58),(8,58)),((6,56),(6,8))]:
                    stroke(a,b,1,hi,.1)
            gems=[]
            for j in range(rank):
                x=32+(j-(rank-1)/2)*9
                p=[(x,3),(x+3.2,7),(x,11),(x-3.2,7)]
                poly(offset(p,.8),INK,.15)
                poly(p,hi,.2)
                poly([(x,3),(x,10),(x-3.2,7)],WHITE,.25)
                gems.append(p)
            suffix='_128' if size==128 else ''
            rel='icons/frame_'+quality+suffix+'.png'
            render(rel,size)
            if rank==3:
                reset(64)
                bpy.context.scene.render.resolution_x=bpy.context.scene.render.resolution_y=size*2
                for p in gems: poly(p,hi)
                render('icons/frame_'+quality+suffix+'_e.png',size//2)

def contact_and_check():
    from PIL import Image, ImageOps
    sys.path.insert(0,str(ROOT/'art/tools'))
    import texture_budget
    budget=texture_budget.load_budget()
    for path in FILES:
        ip=Path(str(path)+'.import')
        if not ip.exists():
            params=texture_budget.expected_params(path.relative_to(ROOT/'game').as_posix(),budget)
            ip.write_text('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'+
                          ''.join(k+'='+texture_budget._fmt(v)+'\n' for k,v in params.items()),encoding='utf-8')
    # Pillow only assembles, resizes, converts to grayscale, and verifies.
    rows=[]
    for path in FILES:
        with Image.open(path) as im:
            im=im.convert('RGBA')
            assert im.getbbox(), path
            assert im.getpixel((0,0))[3]==0, path
            expected = ((32,32) if 'status_mono_' in path.name else
                        (128,128) if path.parent.name=='shapes' or '_128' in path.stem else (64,64))
            if path.stem.endswith('_e'):
                expected=tuple(v//2 for v in expected)
            assert im.size==expected, (path,im.size,expected)
            if 'status_mono_' in path.name:
                x0,y0,x1,y1=im.getbbox()
                assert min(x0,y0)>=3 and max(x1,y1)<=29, path
                assert (255,255,255,255) in im.getdata(), path
            if path.stem.endswith('_e'):
                assert max(sum(px[:3])*px[3] for px in im.getdata())>0, path
            if path.parent.name=='shapes':
                active={(x,y) for y in range(im.height) for x in range(im.width) if im.getpixel((x,y))[3]>127}
                components=0
                while active:
                    components+=1; stack=[active.pop()]
                    while stack:
                        x,y=stack.pop()
                        for q in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                            if q in active: active.remove(q); stack.append(q)
                assert components==(8 if path.stem=='diamond_dashed' else 1),(path,components)
            rows.append((path,im.copy()))
    sheet=Image.new('RGB',(6*160,len(rows)*152))
    for r,(path,im) in enumerate(rows):
        for b,bg in enumerate(('#14110C','#2B3340','#B9AE98')):
            for gray in range(2):
                tile=Image.new('RGBA',(160,152),bg)
                src=ImageOps.grayscale(im).convert('RGBA') if gray else im.copy()
                src.putalpha(im.getchannel('A'))
                tile.alpha_composite(src,(0,0))
                tile.alpha_composite(src.resize((16,16),Image.Resampling.LANCZOS),(140,132))
                sheet.paste(tile.convert('RGB'),((b*2+gray)*160,r*152))
    sheet.save(TMP/'_uxa11y_contact.png',optimize=True,compress_level=9)
    print('PASS UXA11Y: %d PNG; RGBA; transparent; no normal maps; contact color/grayscale x 3 backgrounds' % len(rows))

if __name__=='__main__':
    if '--finish' in sys.argv:
        FILES=[OUT/p for p in sys.argv[sys.argv.index('--finish')+1:]]
        contact_and_check()
        sys.exit(0)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cel.install('ui',normals=False)
    cel.setup_scene(samples=8)
    bpy.context.scene.view_settings.look='None'
    WHITE=material('Pure white glyph','#FFFFFF')
    INK=material('Integrated ink','#0B0907')
    pictos(); shapes(); frames()
    subprocess.run(['python',str(Path(__file__).resolve()),'--finish']+
                   [str(p.relative_to(OUT)) for p in FILES],check=True)
