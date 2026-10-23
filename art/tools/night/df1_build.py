"""DF1 — poincons cel ui. Blender --background --python df1_build.py; python ... --finish.

Choix DA : Impact transforme en poincons etroits (face 32 px, chasse 19),
biseau geometrique mat en deux tons gris issus du profil ui, encre compositee #181210
de 2 px. Usure limitee aux petits desalignements des aretes, aucun grain.
Le code du jeu teinte toute la police ; aucune normale ni emission livree.
Pillow assemble/rogne/verifie uniquement ; teintes de controle rendues Blender.
"""
from pathlib import Path
import sys, json, math
ROOT = Path(__file__).resolve().parents[3]
WORK = ROOT / 'art/tools/night'
OUT = ROOT / 'game/assets/sprites/ui/damage_font'
CHARS = '0123456789+-.,kM!x'
sys.path.insert(0, str(ROOT / 'art/tools/cel'))
import cel_style as cel


def finish():
    from PIL import Image
    raw = Image.open(WORK / '_df1_raw.png').convert('RGBA')
    atlas = raw.resize((512, 64), Image.Resampling.LANCZOS)
    # Canonical transparent pixels; no dark RGB fringe outside alpha.
    px = list(atlas.getdata())
    atlas.putdata([(0, 0, 0, 0) if p[3] < 8 else p for p in px])
    atlas.save(OUT / 'damage_font.png', optimize=True)
    OUT.mkdir(parents=True, exist_ok=True)
    records = json.loads((WORK / '_df1_metrics.json').read_text())
    lines = ['info face="Rainfall Poincon Cel" size=32 bold=1 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=0,0',
             'common lineHeight=38 base=35 scaleW=512 scaleH=64 pages=1 packed=0',
             'page id=0 file="damage_font.png"', 'chars count=18']
    for i, c in enumerate(CHARS):
        cell = atlas.crop((i*28, 0, i*28+28, 48))
        b = cell.getchannel('A').getbbox()
        assert b and b[0] > 0 and b[2] < 28 and b[1] > 0 and b[3] < 48, (c, b)
        x0, y0, x1, y1 = b
        advance = records[c]['advance']
        # y=35 is the shared baseline; punctuation retains its natural placement.
        lines.append(f'char id={ord(c)} x={i*28+x0} y={y0} width={x1-x0} height={y1-y0} xoffset={x0-4} yoffset={y0-5} xadvance={advance} page=0 chnl=15')
        records[c].update(x=i*28+x0, y=y0, width=x1-x0, height=y1-y0,
                          xoffset=x0-4, yoffset=y0-5)
    lines.append('kernings count=0')
    (OUT / 'damage_font.fnt').write_text('\n'.join(lines)+'\n', encoding='utf-8')
    (WORK / '_df1_metrics.json').write_text(json.dumps(records, indent=1))
    assert atlas.size == (512, 64)
    assert all(p[0] < 250 for p in atlas.getdata() if p[3] == 255)
    print('PASS atlas 512x64; 18 glyphes; BMFont baseline/chasses; alpha propre')


def contact():
    from PIL import Image, ImageOps
    board = Image.new('RGBA', (1080, 790), (19, 18, 20, 255))
    capture = Image.open(WORK / '_floor2_captures/foret_sol_f2.png').convert('RGBA')
    # Four real-size columns: dark19, dark27, flames19, flames27.
    for col in range(4):
        bg = ImageOps.fit(capture, (260, 440), centering=(.5, .5))
        if col >= 2:
            fire = Image.open(ROOT / 'game/assets/sprites/vfx/flame_pillar/default.png').convert('RGBA')
            for row in range(4):
                frame = fire.crop((5*256, 0, 6*256, 256)).resize((260, 210), Image.Resampling.LANCZOS)
                bg.alpha_composite(frame, (0, row*110-48))
        board.alpha_composite(bg, (20+col*260, 72))
    layer = Image.open(WORK / '_df1_samples.png').convert('RGBA')
    board.alpha_composite(layer, (20, 72))
    labels = Image.open(WORK / '_df1_labels.png').convert('RGBA')
    board.alpha_composite(labels)
    atlas = Image.open(OUT / 'damage_font.png').convert('RGBA')
    board.alpha_composite(atlas, (30, 545))
    refs = [WORK / '_cs1_contact.png', ROOT/'art/tools/iso/_c4_contact.png',
            ROOT/'game/assets/sprites/ui/spell_frame.png']
    for i, p in enumerate(refs):
        ref = Image.open(p).convert('RGBA')
        if i == 0:
            ref = ref.crop((ref.width//2, 0, ref.width, ref.height))
        ref.thumbnail((310, 155))
        board.alpha_composite(ref, (30+i*350, 625))
    board.save(WORK / '_df1_contact.png', optimize=True)
    print('PASS contact: 4 chaines x 4 teintes x 2 tailles x 2 fonds; references incluses')


if '--finish' in sys.argv:
    finish(); sys.exit()
if '--contact' in sys.argv:
    contact(); sys.exit()

import bpy
from mathutils import Vector
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
OUT.mkdir(parents=True, exist_ok=True)
cel.setup_scene()
s = bpy.context.scene
s.render.resolution_percentage = 100
s.world.color = (.18, .18, .18)
cam_data = bpy.data.cameras.new('DF1 front')
cam = bpy.data.objects.new('DF1 front', cam_data); s.collection.objects.link(cam); s.camera=cam
cam.location=(256,32,400); cam.rotation_euler=(0,0,0); cam_data.type='ORTHO'; cam_data.ortho_scale=512

def srgb(v):
    return v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4

def emission(name, rgb):
    m=bpy.data.materials.new(name); m.use_nodes=True
    n=m.node_tree.nodes; n.clear(); out=n.new('ShaderNodeOutputMaterial'); e=n.new('ShaderNodeEmission')
    e.inputs[0].default_value=(*rgb,1); m.node_tree.links.new(e.outputs[0],out.inputs[0]); return m

ink=emission('Encre cel #181210', tuple(srgb(v/255) for v in (24,18,16)))
face=bpy.data.materials.new('Acier clair a teinter'); face.use_nodes=True
face.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.49,.49,.49,1)
cel.toon_materials('ui')
# Geometry, rather than continuous illumination, chooses the UI ramp's two tones.
bevel=face.copy(); bevel.name='Acier biseau sombre'
for m, value in ((face,1.),(bevel,0.)):
    r=m.node_tree.nodes.get('CEL tones'); links=m.node_tree.links
    for link in list(r.inputs['Fac'].links): links.remove(link)
    r.inputs['Fac'].default_value=value
font=bpy.data.fonts.load('C:/Windows/Fonts/impact.ttf')

def text_curve(c):
    data=bpy.data.curves.new('Poincon '+c,'FONT'); data.body=c; data.font=font
    ob=bpy.data.objects.new('Poincon '+c,data); s.collection.objects.link(ob)
    bpy.context.view_layer.objects.active=ob; ob.select_set(True)
    bpy.ops.object.convert(target='CURVE'); ob.select_set(False)
    return ob

ref=text_curve('0'); points=[p.co for sp in ref.data.splines for p in sp.bezier_points]
lo=min(p.y for p in points); hi=max(p.y for p in points)
sy=30.6/(hi-lo); sx=14.6/(max(p.x for p in points)-min(p.x for p in points))
bpy.data.objects.remove(ref,do_unlink=True)
glyphs={}; metrics={}
for i,c in enumerate(CHARS):
    ob=text_curve(c)
    for sp in ob.data.splines:
        for p in sp.bezier_points:
            p.handle_left_type=p.handle_right_type='FREE'
    for sp in ob.data.splines:
        for j,p in enumerate(sp.bezier_points):
            # Subpixel edge wear: restrained, deterministic; no raster noise.
            wear=.16 if j % 13 == 4 and c not in '.,!' else 0
            coords={a:getattr(p,a).copy() for a in ('co','handle_left','handle_right')}
            p.handle_left_type=p.handle_right_type='FREE'
            for attr,v in coords.items():
                setattr(p,attr,(v.x*sx*(.73 if c=='M' else 1)+wear,(v.y-lo)*sy,v.z))
    points=[p.co.copy() for sp in ob.data.splines for p in sp.bezier_points]
    xmin=min(p.x for p in points); xmax=max(p.x for p in points)
    for sp in ob.data.splines:
        for p in sp.bezier_points:
            coords={a:getattr(p,a).copy() for a in ('co','handle_left','handle_right')}
            for attr,v in coords.items(): setattr(p,attr,(v.x-xmin,v.y,v.z))
    width=xmax-xmin
    advance=19 if c.isdigit() else round(width+4)
    metrics[c]={'advance':advance}
    ob.location=(i*28+5,24.7,0)
    rim=ob.copy(); rim.data=ob.data.copy(); s.collection.objects.link(rim)
    rim.hide_render=True; rim.data.offset=0.; rim.data.materials.clear(); rim.data.materials.append(ink); rim.location.z=-1
    ob.data.bevel_depth=.7; ob.data.bevel_resolution=0; ob.data.extrude=.35
    ob.data.materials.append(face); ob.data.materials.append(bevel)
    bpy.context.view_layer.objects.active=ob; ob.select_set(True); bpy.ops.object.convert(target='MESH'); ob.select_set(False)
    for p in ob.data.polygons: p.material_index=0 if p.normal.z>.99 else 1
    glyphs[c]=(ob,rim)
    if '--debug' in sys.argv:
        bpy.context.view_layer.update()
        print('GLYPH', c, 'width', round(width,2), 'dimensions', tuple(round(v,2) for v in ob.dimensions), 'loc', tuple(ob.location))
if '--samples' not in sys.argv:
    (WORK/'_df1_metrics.json').write_text(json.dumps(metrics))

def render(path,w,h,scale=1):
    cam.location=(w/2,h/2,400); cam.data.ortho_scale=w
    s.render.resolution_x=w*scale; s.render.resolution_y=h*scale
    s.render.filepath=str(path); bpy.ops.render.render(write_still=True)

if '--samples' not in sys.argv:
    # Blender compositor: round distance outline avoids acute serif miter spikes.
    tree=bpy.data.node_groups.new('DF1 encre 2 px','CompositorNodeTree')
    s.compositing_node_group=tree
    n=tree.nodes; l=tree.links
    rl=n.new('CompositorNodeRLayers')
    dil=n.new('CompositorNodeDilateErode'); dil.inputs['Type'].default_value='Distance'; dil.inputs['Size'].default_value=4
    l.new(rl.outputs['Alpha'],dil.inputs['Mask'])
    bg=n.new('CompositorNodeSetAlpha'); bg.inputs['Type'].default_value='Replace Alpha'
    bg.inputs['Image'].default_value=(*[srgb(v/255) for v in (24,18,16)],1)
    l.new(dil.outputs[0],bg.inputs['Alpha'])
    over=n.new('CompositorNodeAlphaOver'); l.new(bg.outputs[0],over.inputs['Background']); l.new(rl.outputs['Image'],over.inputs['Foreground'])
    out=n.new('NodeGroupOutput'); tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor'); l.new(over.outputs[0],out.inputs[0])
    render(WORK/'_df1_raw.png',512,64,2)
else:
    # Display the delivered atlas through Blender, including actual BMFont spacing.
    for pair in glyphs.values():
        for ob in pair: ob.hide_render=True
    atlas=bpy.data.images.load(str(OUT/'damage_font.png')); atlas.colorspace_settings.name='sRGB'
    records=json.loads((WORK/'_df1_metrics.json').read_text())
    colors=['#D5C5A5','#EE933E','#A4BA72','#F17D54']
    for row,color in enumerate(colors):
        rgb=tuple(srgb(int(color[j:j+2],16)/255) for j in (1,3,5))
        m=bpy.data.materials.new(color); m.use_nodes=True; n=m.node_tree.nodes; n.clear()
        out=n.new('ShaderNodeOutputMaterial'); e=n.new('ShaderNodeEmission'); tex=n.new('ShaderNodeTexImage'); tex.image=atlas; tex.interpolation='Linear'
        tint=n.new('ShaderNodeMixRGB'); tint.blend_type='MULTIPLY'; tint.inputs[0].default_value=1; tint.inputs[2].default_value=(*rgb,1)
        trans=n.new('ShaderNodeBsdfTransparent'); mix=n.new('ShaderNodeMixShader'); links=m.node_tree.links
        links.new(tex.outputs['Color'],tint.inputs[1]); links.new(tint.outputs[0],e.inputs[0]); links.new(tex.outputs['Alpha'],mix.inputs[0]); links.new(trans.outputs[0],mix.inputs[1]); links.new(e.outputs[0],mix.inputs[2]); links.new(mix.outputs[0],out.inputs[0])
        for col in range(4):
            size=19 if col%2==0 else 27; ratio=size/32; cursor=col*260+12
            for c in '12 347 1.2k !88':
                if c==' ': cursor+=size*.4; continue
                a=records[c]; x=cursor+a['xoffset']*ratio; top=440-(row*110+35)-a['yoffset']*ratio
                w=a['width']*ratio; h=a['height']*ratio
                mesh=bpy.data.meshes.new('BMFont quad'); mesh.from_pydata([(x,top-h,0),(x+w,top-h,0),(x+w,top,0),(x,top,0)],[],[(0,1,2,3)])
                uv=mesh.uv_layers.new(); u0=a['x']/512; u1=(a['x']+a['width'])/512; v1=1-a['y']/64; v0=v1-a['height']/64
                for loop,xy in zip(uv.data,[(u0,v0),(u1,v0),(u1,v1),(u0,v1)]): loop.uv=xy
                ob=bpy.data.objects.new('Controle '+c,mesh); s.collection.objects.link(ob); mesh.materials.append(m)
                cursor+=a['advance']*ratio
    render(WORK/'_df1_samples.png',1040,440)
    for ob in list(s.objects):
        if ob.type!='CAMERA': ob.hide_render=True
    def label(body,x,y,size=15):
        d=bpy.data.curves.new(body,'FONT'); d.body=body; d.size=size; d.font=font
        ob=bpy.data.objects.new(body,d); s.collection.objects.link(ob); ob.location=(x,790-y,0); d.materials.append(emission(body,(.5,.48,.43)))
    label('DF1 / POINCONS CEL  /  32 PX  /  ENCRE 2 PX',25,30,22)
    for i,title in enumerate(['NUIT / 19 PX','NUIT / 27 PX','FLAMMES / 19 PX','FLAMMES / 27 PX']): label(title,30+i*260,60)
    for i,title in enumerate(['OS CHAUD','FEU','POISON','CRITIQUE']): label(title,30,91+i*110,12)
    label('ATLAS 512 x 64 / 18 GLYPHES / CHASSE CHIFFRES 19 / FACE GRISE 2 TONS',30,535)
    label('REFERENCES : CS1 CEL (DROITE) / ARDENT C4 / CADRE DE SORT',30,612)
    render(WORK/'_df1_labels.png',1080,790)
print('PASS DF1 Blender ui / rendu termine')
