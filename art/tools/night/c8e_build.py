"""C8E: wake-only revision; reuses C8D TOP rig and cel frame renderer."""
import sys, math, json, hashlib, tempfile
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import c8d_build as source
sys.path.insert(0,str(HERE.parents[1]/'blender/c8e_dependencies'))
from PIL import Image
ROOT=source.ROOT
DST=source.DST

def digest():
    return {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in DST.iterdir() if p.is_file()}

def linear(h):
    return tuple(((int(h[k:k+2],16)/255+.055)/1.055)**2.4 for k in (0,2,4))

def build():
    import bpy, boss_common as c
    from ash_lord_build import mesh
    before=digest()
    inventory=HERE/'_c8e_before.json'
    if not inventory.exists():inventory.write_text(json.dumps(before,indent=2))
    assert Image.open(DST/'wake.png').size==(768,128)
    root,_=source.extra('wake')
    for ob in list(root.children):bpy.data.objects.remove(ob,do_unlink=True)
    def mat(name,color,emission=0):
        m=c.material(name,linear(color),0,.6,emission)
        if emission:m['rainfall_emissive']=True
        return m
    foam=mat('C8E foam DDEBEF','DDEBEF')
    crest=mat('C8E crest DDEBEF','DDEBEF')
    cyan=mat('C8E sole cyan accent BFF4FF','BFF4FF',1)
    animated=[]
    def ribbon(name,points,widths,material):
        vs=[]
        for j,p in enumerate(points):
            a=points[max(0,j-1)];b=points[min(len(points)-1,j+1)]
            dx=b[0]-a[0];dy=b[1]-a[1];d=max(.00001,math.hypot(dx,dy))
            for sign in (-1,1):vs.append((p[0]-sign*dy/d*widths[j]/2,p[1]+sign*dx/d*widths[j]/2,p[2]))
        return mesh(name,vs,[(2*j,2*j+1,2*j+3,2*j+2) for j in range(len(points)-1)],material,root)
    def arm(u,side):
        return (.78-1.62*u,side*(.75*u+.022*math.sin(u*math.pi*3)),.025)
    def pose(i):
        for ob in animated:bpy.data.objects.remove(ob,do_unlink=True)
        animated.clear()
        phase=i/6
        for side in (-1,1):
            pts=[arm(j/48,side) for j in range(49)]
            widths=[.009+.092*math.sin(math.pi*j/48)**.55 for j in range(49)]
            animated.append(ribbon('Tapered V foam arm',pts,widths,foam))
            # Traveling scalloped crests wrap at tapered endpoints: six unique loop samples.
            for k in range(5):
                u=((k+phase)/5)%1
                envelope=math.sin(math.pi*u)**.7
                pts=[]
                for j in range(11):
                    t=j/10;x,y,z=arm(min(.999,u+.066*t),side)
                    pts.append((x-.042*t*envelope,y+side*.088*math.sin(math.pi*t)*envelope,z+.003))
                widths=[.038*math.sin(math.pi*j/10)**.6*envelope+.001 for j in range(11)]
                animated.append(ribbon('Advecting foam crest',pts,widths,crest))
        pulse=.78+.22*math.cos(math.tau*phase)
        pts=[(.65-1.33*j/32,.012*math.sin(j/32*math.pi*2+math.tau*phase)*math.sin(math.pi*j/32),.04) for j in range(33)]
        widths=[.062*pulse*math.sin(math.pi*j/32)**.8+.001 for j in range(33)]
        animated.append(ribbon('Pulsing submerged axial trail',pts,widths,cyan))
    source.cel.install('boss',normals=False)
    # The requested pale foam lip replaces the boss brown ink color, keeping boss cel passes.
    original=source.water_tones
    def foam_lip():
        original()
        for node in bpy.context.scene.compositing_node_group.nodes:
            if node.bl_idname=='ShaderNodeVectorMath' and node.operation=='MULTIPLY_ADD':
                node.inputs[1].default_value=linear('9FB4BA')
    source.water_tones=foam_lip
    s=bpy.context.scene;s['iso_frame']=[128,128]
    s.render.resolution_x=256;s.render.resolution_y=256
    sheets=[Image.new('RGBA',(768,128)) for _ in range(2)]
    with tempfile.TemporaryDirectory(prefix='rainfall_c8e_') as td:
        for i in range(6):
            pose(i);bpy.context.view_layer.update()
            path=Path(td)/f'wake_{i}.png'
            source.render_frame(path)
            for sheet,suffix in zip(sheets,('','_e')):
                with Image.open(path.with_name(path.stem+suffix+'.png')) as im:sheet.paste(im,(128*i,0))
    sheets[0].save(DST/'wake.png',compress_level=9)
    sys.path.insert(0,str(ROOT/'art/tools'))
    from halve_emission import downscale
    downscale(sheets[1]).save(DST/'wake_e.png',compress_level=9)
    orphan=DST/'black_pool_e.png.import'
    assert not (DST/'black_pool_e.png').exists()
    if orphan.exists():orphan.unlink()
    after=digest();changed={n for n in before.keys()|after.keys() if before.get(n)!=after.get(n)}
    assert changed<={'wake.png','wake_e.png','black_pool_e.png.import'},changed
    print('PASS C8E render: 6 frames, 768x128 + 384x64; scope verified',flush=True)

if __name__=='__main__':build()
