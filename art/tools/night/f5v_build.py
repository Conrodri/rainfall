"""F5V: periodic cold rain curtain. Blender background; no painted pixels.

Blender: --background --python art/tools/night/f5v_build.py
System Python: f5v_build.py --assemble
Exact contract: 12 x 256x1024, CREA 30 degrees, 90.5097 px/u,
ground pivot (128,942.08). No floor, bloom, or projected illumination.
"""
from pathlib import Path
import sys, math, random, json

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'art/blender/vfx'
WORK = SOURCE / 'f5v_frames'
DEST = ROOT / 'game/assets/sprites/vfx/source'
TAU = math.tau


def assemble():
    from PIL import Image, ImageChops, ImageStat
    DEST.mkdir(parents=True, exist_ok=True)
    stats = {}
    for suffix in ('', '_n', '_e'):
        sheet = Image.new('RGBA', (3072, 1024))
        for f in range(12):
            with Image.open(WORK / f'rain_{f:02d}{suffix}.png') as im:
                assert im.size == (256, 1024)
                sheet.paste(im, (f * 256, 0))
        sheet.save(DEST / f'rain_column{suffix}.png', compress_level=9)
    diffuse = Image.open(DEST / 'rain_column.png').convert('RGBA')
    normal = Image.open(DEST / 'rain_column_n.png').convert('RGBA')
    emission = Image.open(DEST / 'rain_column_e.png').convert('RGBA')
    assert ImageChops.difference(diffuse.getchannel('A'), normal.getchannel('A')).getbbox() is None
    assert ImageChops.difference(diffuse.getchannel('A'), emission.getchannel('A')).getbbox() is None
    colors = {p[:3] for p in normal.get_flattened_data() if p[3] == 255}
    assert len(colors) <= 27, len(colors)
    frames = [diffuse.crop((f*256, 0, (f+1)*256, 1024)) for f in range(12)]
    assert len({f.tobytes() for f in frames}) == 12
    differences = [sum(ImageStat.Stat(ImageChops.difference(frames[f], frames[(f+1)%12])).mean) for f in range(12)]
    assert differences[-1] < max(differences[:-1])*1.5
    # One contact, including the required approved references; no drawing.
    contact = Image.new('RGB', (1536, 1376), (18, 24, 31))
    ground = Image.open(ROOT / 'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    for y in range(0, 1376, ground.height):
        for x in range(0, 1536, ground.width):
            contact.paste(ground, (x,y), ground)
    for i, f in enumerate((0,2,4,6,8,10)):
        contact.paste(frames[f], (i*256,0), frames[f])
    for i, name in enumerate(('art/tools/iso/_c4_contact.png', 'art/tools/characters/_m2_contact.png',
                              'art/tools/iso/_c1_contact.png', 'art/tools/night/_cs1_contact.png')):
        with Image.open(ROOT/name) as ref:
            if i == 3:
                ref = ref.crop((ref.width//2,0,ref.width,ref.height))
            ref.thumbnail((384,320))
            contact.paste(ref, (i*384,1040))
    contact.save(ROOT/'art/tools/night/_f5v_contact.png', compress_level=9)
    stats.update(dimensions=[3072,1024], frames=12, fps=12, pivot=[128,942.08],
                 normal_colors=len(colors), alpha_equal=True, unique_frames=True,
                 adjacent_differences=differences, source='f5v_rain.blend',
                 design='Broken cylindrical silver filaments, needle spray, fragmented impact crown, rising slate mist; single cold accent; no floor light.')
    (SOURCE/'f5v_verification.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
    print('PASS: atlas, alpha, 26-direction normals, unique frames, loop boundary, contact')


def build():
    import bpy
    from mathutils import Vector
    sys.path[:0] = [str(ROOT/'art/tools/iso'), str(ROOT/'art/tools/cel')]
    import iso_rig
    import cel_style as cel
    WORK.mkdir(parents=True, exist_ok=True)
    # The strict lot scope overrides the generic archive destination.
    # Existing originals, if any, stay under this lot's Blender source prefix.
    backup = SOURCE/'f5v_originals'
    if not backup.exists() and (DEST/'rain_column.png').exists():
        import shutil
        backup.mkdir()
        for p in DEST.glob('rain_column*.png'):
            shutil.copy2(p,backup/p.name)
    scene = iso_rig.create_rig('CREA',(256,1024),target=(0,0,5.4869))
    cel.setup_scene()
    scene.render.fps=12
    scene.frame_start=1; scene.frame_end=12
    p = cel.profile('vfx')
    p.update(keep_normals=True,quantize_normals=True)
    mats=[]
    def material(name, color, glow=0, alpha=1):
        m=bpy.data.materials.new(name);m.use_nodes=True
        bs=m.node_tree.nodes.get('Principled BSDF')
        bs.inputs['Base Color'].default_value=(*color,1)
        bs.inputs['Roughness'].default_value=.38
        if glow:
            m['rainfall_emissive']=True
            bs.inputs['Emission Color'].default_value=(*color,1)
            bs.inputs['Emission Strength'].default_value=glow
        cel.toon_materials(p)
        if alpha<1:
            nodes=m.node_tree.nodes;links=m.node_tree.links
            out=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
            shader=out.inputs['Surface'].links[0].from_socket
            mix=nodes.new('ShaderNodeMixShader');mix.inputs[0].default_value=alpha
            tr=nodes.new('ShaderNodeBsdfTransparent')
            links.new(tr.outputs[0],mix.inputs[1]);links.new(shader,mix.inputs[2]);links.new(mix.outputs[0],out.inputs[0])
            m.surface_render_method='DITHERED'
        mats.append(m)
        return len(mats)-1
    body=material('F5V rain - slate silver two tones',(.20,.29,.36))
    pale=material('F5V rain - glacial facets two tones',(.43,.53,.60))
    core=material('F5V single accent E6F4FF',(.7913,.9047,1.0),.95)
    glint=material('F5V refracted cold accent',(.46,.64,.77),.55)
    mist=material('F5V cold rising mist two tones',(.16,.23,.29),alpha=.11)
    mist2=material('F5V thin spray veil two tones',(.26,.35,.40),alpha=.065)
    rng=random.Random(50812)
    lanes=[(rng.uniform(0,TAU),math.sqrt(rng.random())*1.0,rng.random(),rng.uniform(.008,.020),rng.randrange(1,4)) for _ in range(170)]
    drops=[(rng.uniform(0,TAU),math.sqrt(rng.random())*1.03,rng.random(),rng.uniform(.18,.7),rng.uniform(.008,.018)) for _ in range(460)]
    spray=[(rng.uniform(0,TAU),rng.random(),rng.uniform(.5,1.1),rng.uniform(.25,.9)) for _ in range(105)]
    def geometry(t):
        verts=[];faces=[];indices=[]
        def strip(points,widths,mat):
            base=len(verts)
            for pt,w in zip(points,widths):
                verts.extend(((pt[0]-w,pt[1],pt[2]),(pt[0]+w,pt[1],pt[2])))
            for j in range(len(points)-1):
                faces.append((base+j*2,base+j*2+1,base+j*2+3,base+j*2+2));indices.append(mat)
        for k,(a,r,phase,w,speed) in enumerate(lanes):
            x,y=r*math.cos(a),r*math.sin(a)
            pts=[];ww=[]
            for j in range(57):
                z=.12+j*11.65/56
                wave=math.sin(z*2.8+phase*TAU+t*TAU*speed)
                pts.append((x+.018*wave,y+.015*math.cos(z*2+phase*TAU+t*TAU),z))
                modulation=.18+.82*max(0,math.sin(z*4.1+phase*TAU+t*TAU*speed))**2
                ww.append(w*modulation*min(1,z*3,(11.83-z)*5))
            strip(pts,ww, core if r<.38 and k%3==0 else (glint if k%9==0 else pale if k%3==0 else body))
        for k,(a,r,phase,length,w) in enumerate(drops):
            z=.06+((phase-t*(1+k%3))%1)*11.8
            x,y=r*math.cos(a),r*math.sin(a)
            length=min(length,z,11.88-z)
            strip([(x,y,z-length*.55),(x+.008,y,z-length*.2),(x,y,z+length*.45)],
                  [0,w,0],core if k%8==0 else pale if k%2==0 else body)
        # Fragmented expanding crown: actual water only, never a lit ground disc.
        for ring in range(4):
            age=(t+ring/4)%1
            radius=.45+.78*age
            for sector in range(15):
                aa=sector*TAU/15+.05*math.sin(sector*8)
                pts=[];ww=[]
                for j in range(8):
                    a=aa+j*.025
                    rr=radius+.016*math.sin(a*19+ring)
                    pts.append((rr*math.cos(a),rr*math.sin(a),.025+.02*math.sin(a*11)**2))
                    ww.append(.012*math.sin(math.pi*j/7)*math.sin(math.pi*age)**.6)
                strip(pts,ww,core if ring%2 else glint)
        for k,(a,phase,v,h) in enumerate(spray):
            age=(phase+t*2)%1
            def point(q):
                r=.35+v*q
                return (r*math.cos(a),r*math.sin(a),.04+4*h*q*(1-q))
            q0=max(0,age-.075);q1=min(1,age+.025)
            strip([point(q0),point(age),point(q1)],[0,.008*math.sin(math.pi*age),0], core if k%3==0 else pale)
        # Narrow rising ribbons; negative space keeps the spray readable.
        for k in range(22):
            a=k*2.39996
            age=(k/22+t)%1
            points=[];widths=[]
            for j in range(13):
                u=j/12
                z=.10+age*1.7+u*.8
                r=.55+age*.4+u*.15
                xx=r*math.cos(a)+.10*math.sin(u*5+TAU*t+a)
                points.append((xx,r*math.sin(a),z))
                widths.append(.09*math.sin(math.pi*u)**1.5*math.sin(math.pi*age))
            strip(points,widths,mist if k%2 else mist2)
        return verts,faces,indices
    cel.install(p)
    previous=None
    for f in range(12):
        if previous:
            mesh=previous.data;bpy.data.objects.remove(previous,do_unlink=True);bpy.data.meshes.remove(mesh)
        v,faces,mi=geometry(f/12)
        mesh=bpy.data.meshes.new('F5V resolved periodic rain');mesh.from_pydata(v,[],faces);mesh.update()
        ob=bpy.data.objects.new('F5V falling filaments - impact - rising mist',mesh);scene.collection.objects.link(ob)
        for m in mats:mesh.materials.append(m)
        for face,index in zip(mesh.polygons,mi):face.material_index=index
        previous=ob
        scene.frame_set(f+1)
        if f==0:
            text=bpy.data.texts.new('f5v_build.py');text.write(Path(__file__).read_text(encoding='utf-8'))
            scene['F5V_contract']='12 fps; one-second periodic geometry; no floor; vfx cel two tones; pivot 128,942.08'
            bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'f5v_rain.blend'))
        iso_rig.render_frame(WORK/f'rain_{f:02d}.png')
        print(f'F5V frame {f+1}/12',flush=True)
    # The shared helper deliberately caches its input: discard only this lot's
    # intermediate normal backups when regenerating the animation.
    normal_work=SOURCE/'f5v_normal_work'
    if normal_work.exists():
        for old in normal_work.glob('*rain_*_n.png'):old.unlink()
    cel.quantize_normal_files(sorted(WORK.glob('rain_*_n.png')),work=normal_work)
    print('PASS: F5V render complete',flush=True)


if __name__=='__main__':
    if '--assemble' in sys.argv:assemble()
    else:build()
