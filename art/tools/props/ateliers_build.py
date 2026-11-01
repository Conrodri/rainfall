import bpy, sys, math, json, hashlib
from bpy_extras.object_utils import world_to_camera_view
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/bosses')]
import iso_rig, cel_style as cel, boss_common as bc
from PIL import Image
OUT=ROOT/'game/assets/sprites/props/stations'
BLENDS=ROOT/'art/blender/props'
LOG=ROOT/'art/tools/props/_log_ateliers.txt'
PROPS=('fondoir','matrice','alambic','enclume')

def build(p):
    scene=bc.setup_scene(3.4); cel.install('prop',normals=False)
    iso_rig.create_rig('MAP',(192,192),target=(0,0,.85),reset=False)
    iso_rig.set_frame((192,192),'MAP')
    mats={k:bc.material(k,c,metallic=m,roughness=.78) for k,c,m in [
      ('stone',(.105,.115,.12),.15),('bronze',(.19,.115,.062),.72),('dark',(.055,.061,.064),.68),
      ('copper',(.18,.25,.22),.7),('accent',(1,.12,.005),.1),('ember',(1,.12,.005),.1)]}
    accent=mats['accent']; pmat=mats['stone']
    color=(.005,.8,.44) if p=='alambic' else (1,.095,.002)
    for key in ('accent','ember'):
        bs=mats[key].node_tree.nodes.get('Principled BSDF')
        bs.inputs['Base Color'].default_value=(*color,1)
        bs.inputs['Emission Color'].default_value=(*color,1)
        bs.inputs['Emission Strength'].default_value=1.3
    def box(n,l,s,ma,b=.04): bc.box(n,l,s,ma,bevel=b)
    def cyl(n,l,r,d,ma,v=8):
        bpy.ops.mesh.primitive_cylinder_add(vertices=v,radius=r,depth=d,location=l); o=bpy.context.object; o.data.materials.append(ma)
        bevel=o.modifiers.new('Usure','BEVEL');bevel.width=.025;bevel.segments=2;o.modifiers.new('Normales','WEIGHTED_NORMAL')
    def rod(n,a,b,r,ma): bc.rod(n,a,b,r,ma)
    if p=='fondoir':
        for a in range(3):
            t=a*math.tau/3; rod('Pied',(math.cos(t)*.62,math.sin(t)*.62,.08),(math.cos(t)*.38,math.sin(t)*.38,.75),.085,mats['dark'])
        # Hollow, deep faceted vessel: outer wall, thick lip, inner wall, bottom.
        verts=[]; rings=[(.46,.68),(.74,1.43),(.73,1.57),(.58,1.57),(.53,1.01)]
        for r,z in rings:
            verts.extend((r*math.cos(i*math.tau/12),r*math.sin(i*math.tau/12),z) for i in range(12))
        faces=[]
        for j in range(4):
            faces.extend((j*12+i,j*12+(i+1)%12,(j+1)*12+(i+1)%12,(j+1)*12+i) for i in range(12))
        faces.append(tuple(range(48,60)))
        mesh=bpy.data.meshes.new('Cuve creuse');mesh.from_pydata(verts,[],faces)
        ob=bpy.data.objects.new('Cuve bronze fendue',mesh);scene.collection.objects.link(ob);ob.data.materials.append(mats['bronze'])
        for t in [-2.3,-1.45,-.6]:
            pts=[(r*math.cos(t+d),r*math.sin(t+d),z) for r,z,d in [(.50,.79,0),(.59,1.04,.10),(.67,1.28,-.04),(.745,1.48,.02)]]
            bc.tube('Fissure lumineuse',pts,.023,accent)
        for i in range(7):
            t=i*2.4;box('Braise',(.30*math.cos(t),.30*math.sin(t),1.04),(.17,.13,.07),accent,.01)
        for i in range(12):
            t=i*math.tau/12;box('Rivet',( .755*math.cos(t),.755*math.sin(t),1.45),(.055,.055,.065),mats['dark'],.01)
    elif p=='matrice':
        box('Socle',(0,0,.18),(1.38,1.08,.36),mats['stone']);box('Plateau',(0,0,.47),(1.13,.86,.2),mats['bronze'])
        for x in [-.42,.42]:
            box('Colonne',(x,0,1.04),(.16,.2,1.0),mats['dark']);box('Piston',(x,0,1.58),(.34,.3,.18),mats['bronze'])
        box('Moule creux',(0,-.02,.61),(.58,.46,.035),mats['dark'],.01)
        for x in [-.25,0,.25]: rod('Filet',(x,-.22,.64),(x,.18,.65),.014,accent)
    elif p=='alambic':
        cyl('Foyer',(0,0,.25),.53,.45,mats['dark']);cyl('Chaudière',(0,0,.9),.46,.78,mats['copper'],10)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=.47,location=(0,0,1.22));bpy.context.object.scale=(1,1,.58);bpy.context.object.data.materials.append(mats['copper'])
        bc.tube('Serpentin',[(0,0,1.42),(.45,0,1.52),(.5,0,1.75),(.28,0,1.9),(.48,0,2.06),(.52,0,2.28)],.045,accent)
        for x in [-.55,0,.55]:
            rod('Fiolle',(x,-.33,1.03),(x,-.33,1.27),.10,mats['copper']);cyl('Bouchon',(x,-.33,1.3),.075,.07,mats['bronze'])
    else:
        cyl('Souche',(0,0,.35),.62,.7,mats['stone'],7);box('Enclume',(0,0,.84),(1.28,.66,.28),mats['dark'])
        box('Talon',(0,0,1.05),(.68,.56,.18),mats['bronze']);box('Fer rouge',(0,-.02,1.19),(.62,.25,.07),accent)
        rod('Marteau',(.20,.16,1.14),(.38,.20,1.93),.065,mats['bronze']);box('Tête',(.38,.20,1.93),(.48,.24,.2),mats['dark'])
    # Taller forge press and dead hearth details, without adding luminous accents.
    if p=='matrice':
        box('Traverse',(0,.04,1.68),(1.18,.38,.18),mats['bronze'])
        rod('Vis centrale',(0,.12,.86),(0,.12,1.69),.09,mats['dark'])
        for x in [-.37,.37]:box('Rebord moule',(x,-.08,.64),(.10,.62,.13),mats['bronze'])
    if p=='alambic':
        rod('Crochet',(-.56,-.31,1.40),(.56,-.31,1.40),.025,mats['dark'])
        for x in [-.55,0,.55]:rod('Attache fiole',(x,-.33,1.3),(x,-.31,1.4),.018,mats['bronze'])
    sparkmat=bc.material('Accent etincelles',color,emission=1.5)
    sparks=[]
    for i in range(9):
        rod('Etincelle',(0,0,1.2),(.03,0,1.3),.015,sparkmat);sparks.append(bpy.context.object);bpy.context.object.hide_render=True
    body=[o for o in scene.objects if o.type in {'MESH','CURVE'} and o not in sparks]
    # MAP orientation, explicit requested 35 degrees; feet anchored at [96,170].
    scene.camera.rotation_euler.x=math.radians(55)
    scene.camera.data.ortho_scale=3.35
    basis=scene.camera.rotation_euler.to_matrix()
    bpy.context.view_layer.update()
    corners=[basis.transposed()@(ob.matrix_world@Vector(c)) for ob in body for c in ob.bound_box]
    low=min(c.y for c in corners);mid=(min(c.x for c in corners)+max(c.x for c in corners))/2
    scene.camera.location=basis@Vector((mid,low+3.35*(170/192-.5),12))
    scene.eevee.taa_render_samples=16
    folder=OUT/p;folder.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    # cel conversion occurs once, retaining direct controls on the accent shader.
    cel.toon_materials('prop')
    emissive=[]
    for mat in (accent,mats['ember'],sparkmat):
        em=next((n for n in mat.node_tree.nodes if n.type=='EMISSION'),None)
        if em:emissive.append(em)
    # Physical projected shadow of this prop, generated once and reused per state.
    parent=bc.empty('Atelier shadow root')
    for ob in body:
        ob.parent=parent
    shadow=folder/'closed_shadow.png'
    iso_rig.render_shadow_decal(parent,shadow)
    states=('closed',)+tuple(f'work_{i}' for i in range(8))+('open',)
    for state in states:
        work=state.startswith('work'); exhausted=state=='open'; frame=int(state[-1]) if work else 0
        for i,ob in enumerate(sparks):
            ob.hide_render=not work
            t=i*2.399+frame*.49;h=.12+((i*.137+frame*.093)%.55)
            origin=Vector((.18*math.cos(t),-.14,1.26))
            direction=Vector((math.cos(t)*.11,math.sin(t)*.11,h*.23))
            ob.location=origin+Vector((math.cos(t)*h*.6,math.sin(t)*h*.5,h))
            ob.rotation_euler=direction.to_track_quat('Z','Y').to_euler()
        for em in emissive:
            em.inputs['Color'].default_value=(*((.055,.065,.07) if exhausted else color),1)
            em.inputs['Strength'].default_value=.65 if exhausted else (1.8+.65*math.sin(frame*math.tau/8) if work else 1.25)
        path=folder/f'{state}.png'
        bc.configure_passes(path)
        if exhausted:
            tree=getattr(scene,'node_tree',None) or scene.compositing_node_group
            for node in list(tree.nodes):
                if node.bl_idname=='CompositorNodeOutputFile':tree.nodes.remove(node)
        scene.eevee.taa_render_samples=16
        scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        # Only the accent AOV, never the beauty/silhouette. Remove black background alpha.
        for suffix in ('_e',):
            candidates=list(folder.glob(state+suffix+'__*.png'))
            for source in candidates:
                if not exhausted:
                    with Image.open(source) as raw:
                        im=raw.convert('RGBA').resize((96,96),Image.Resampling.LANCZOS)
                    im.putdata([(255,250,237,min(a,max(r,g,b))) if max(r,g,b)>12 else (0,0,0,0) for r,g,b,a in im.getdata()])
                    im.save(folder/f'{state}_e.png',optimize=True,compress_level=9)
                source.unlink()
        if exhausted:(folder/'open_e.png').unlink(missing_ok=True)
        with Image.open(path) as raw:im=raw.convert('RGBA').resize((192,192),Image.Resampling.LANCZOS)
        im.save(path,optimize=True,compress_level=9)
        if state!='closed':(folder/f'{state}_shadow.png').write_bytes(shadow.read_bytes())
    # Source opens ready, with no sparks and a luminous accent.
    for ob in sparks:ob.hide_render=True
    for em in emissive:
        em.inputs['Color'].default_value=(*color,1);em.inputs['Strength'].default_value=1.25
    bpy.ops.wm.save_as_mainfile(filepath=str(BLENDS/f'ateliers_{p}.blend'))
    tex=[];frames=[]
    for name in ('closed',)+tuple(f'work_{i}' for i in range(8))+('open',):
        tex.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/props/stations/{p}/{name}.png" id="{len(tex)+1}"]')
        frames.append(f'[sub_resource type="AtlasTexture" id="t{len(frames)}"]\natlas = ExtResource("{len(frames)+1}")\nregion = Rect2(0, 0, 192, 192)')
    tres='[gd_resource type="SpriteFrames" load_steps=23 format=3]\n\n'+'\n'.join(tex)+'\n\n'+'\n\n'.join(frames)+'\n\n[resource]\nanimations = [{\n"frames": [{"duration": 1.0, "texture": SubResource("t0")}],\n"loop": false,\n"name": &"closed",\n"speed": 1.0\n}, {\n"frames": ['+','.join('{"duration": 0.0833333333, "texture": SubResource("t%d")}'%(i+1) for i in range(8))+'],\n"loop": false,\n"name": &"work",\n"speed": 12.0\n}, {\n"frames": [{"duration": 1.0, "texture": SubResource("t9")}],\n"loop": false,\n"name": &"open",\n"speed": 1.0\n}]\n'
    if not (folder/f'{p}.tres').exists(): (folder/f'{p}.tres').write_text(tres,encoding='utf-8')
    (folder/f'{p}.json').write_text(json.dumps({'foot':[96,170]},separators=(',',':')),encoding='utf-8')

def verify():
    rows=[];report=[];shadow_hashes=[]
    for p in PROPS:
        folder=OUT/p;works=[];ratios=[];row=[]
        for state in ('closed',)+tuple(f'work_{i}' for i in range(8))+('open',):
            im=Image.open(folder/f'{state}.png').convert('RGBA');assert im.size==(192,192)
            bbox=im.getchannel('A').point(lambda x:255 if x>12 else 0).getbbox()
            assert bbox and min(bbox[0],bbox[1],192-bbox[2],192-bbox[3])>=4,(p,state,bbox)
            opaque=sum(a>32 for a in im.getchannel('A').getdata())
            assert opaque>800 and max(hi-lo for lo,hi in im.convert('RGB').getextrema())>50
            digest=hashlib.sha256(im.tobytes()).hexdigest()
            if state.startswith('work'):works.append(digest)
            if state=='closed':closed=digest
            if state=='open':assert digest!=closed and not (folder/'open_e.png').exists()
            else:
                e=Image.open(folder/f'{state}_e.png').convert('RGBA');assert e.size==(96,96)
                ratio=4*sum(a>24 for a in e.getchannel('A').getdata())/opaque
                assert .002<ratio<.15,(p,state,ratio)
                ratios.append(ratio)
            sh=Image.open(folder/f'{state}_shadow.png').convert('RGBA')
            assert sh.size==(192,192) and 0<sh.getchannel('A').getextrema()[1]<=153
            if state=='closed':shadow_hashes.append(hashlib.sha256(sh.tobytes()).hexdigest())
            if state in ('closed','work_2','open'):row.append(im.copy())
        assert len(set(works))==8,p
        assert not list(folder.glob('*_n.png'))
        report.append(f'{p}: PASS emission={min(ratios):.3%}..{max(ratios):.3%} work=8 distinct bbox_margin>=4')
        rows.append(row)
    assert len(set(shadow_hashes))==4
    contact=Image.new('RGBA',(576,768),(0,0,0,255))
    for y,row in enumerate(rows):
        for x,im in enumerate(row):contact.alpha_composite(im,(x*192,y*192))
    contact.save(ROOT/'art/tools/props/_ateliers_contact.png',optimize=True)
    LOG.write_text('\n'.join(report)+'\nPASS shadows=4 alpha<=153 normals=0\n',encoding='utf-8')

if __name__=='__main__':
    if '--verify' not in sys.argv:
        for prop in PROPS: build(prop)
    verify()
    print('PASS ateliers 4 props')
