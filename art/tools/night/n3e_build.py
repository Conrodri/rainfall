"""N3E: material-only rust variants of the contractual C5 creatures.
Blender background: --python n3e_build.py [-- --name NAME]
System Python: n3e_build.py --verify / --contact. No geometry/animation edits.
"""
import sys, math, json, re, hashlib, argparse
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
SOURCES = ROOT/'art/blender/monsters'
SPRITES = ROOT/'game/assets/sprites/monsters'
CFG = {'swarm_tier1': (96, ['run']), 'shooter_tier2': (112, ['run','attack']),
       'leaper_tier2': (112, ['run','charge']), 'brute_tier3': (160, ['run','attack','cast'])}
DIRS = ['e','se','s','sw','w','nw','n','ne']

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def imports(name):
    dst=SPRITES/(name+'_rust')
    for source in (SPRITES/name).glob('*.png.import'):
        target=dst/source.name
        if target.exists():continue
        params=source.read_text(encoding='utf-8').split('[params]',1)[1]
        target.write_text('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]'+params,encoding='utf-8')

def verify():
    from PIL import Image, ImageChops
    total = 0
    for name,(size,anims) in CFG.items():
        src=SPRITES/name;dst=SPRITES/(name+'_rust')
        original=(src/(name+'.tres')).read_text(encoding='utf-8')
        variant=(dst/(name+'_rust.tres')).read_text(encoding='utf-8')
        assert variant == original.replace('/'+name+'/', '/'+name+'_rust/'), name+' tres contract'
        assert {p.name for p in src.glob('*.png')} == {p.name for p in dst.glob('*.png')},name+' names'
        for anim in anims:
            with Image.open(dst/(anim+'.png')) as image: diffuse=image.convert('RGBA')
            assert diffuse.size == (size*8,size*8) and max(diffuse.size)<=4096
            with Image.open(src/(anim+'.png')) as image: original_alpha=image.getchannel('A')
            assert ImageChops.difference(original_alpha,diffuse.getchannel('A')).getbbox() is None,name+anim+' original silhouette/pivot'
            for suffix in ('_n','_e'):
                with Image.open(dst/(anim+suffix+'.png')) as image: layer=image.convert('RGBA')
                assert layer.size==diffuse.size
                assert ImageChops.difference(layer.getchannel('A'),diffuse.getchannel('A')).getbbox() is None, name+anim+suffix+' alpha'
                if suffix=='_e': assert max(c.getextrema()[1] for c in layer.split()[:3])>0
            seen=set()
            for d in range(8):
                for f in range(8):
                    frame=diffuse.crop((f*size,d*size,(f+1)*size,(d+1)*size))
                    bbox=frame.getchannel('A').getbbox()
                    # C5 already has a two-pixel antialiasing fringe in some cells.
                    # Preserve its exact alpha/pivot rather than recropping a variant.
                    assert bbox and min(bbox[0],bbox[1],size-bbox[2],size-bbox[3])>=1,(name,anim,d,f,bbox)
                    seen.add(hashlib.sha256(frame.tobytes()).hexdigest());total+=1
            assert len(seen)==64,(name,anim,'duplicate frames')
        report=json.loads((SOURCES/('n3e_'+name+'.json')).read_text())
        assert report['source_sha256']==digest(SOURCES/(name+'_iso.blend')),name+' source changed'
        assert report['original_tres_sha256']==digest(src/(name+'.tres')),name+' tres changed'
        print('PASS',name+'_rust',size,'px',len(anims)*64,'frames')
    print('PASS N3E',total,'frames; identical grids, animation contracts, aligned passes, <=4096')

def contact():
    from PIL import Image
    # Assembly/cropping only: all picture content comes from Blender renders.
    board=Image.new('RGBA',(1100,920),(24,29,29,255))
    refs=['art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/night/_f3_contact.png']
    for col,ref in enumerate(refs):
        with Image.open(ROOT/ref) as im:
            im=im.convert('RGBA');im.thumbnail((350,215));board.alpha_composite(im,(col*365,0))
    for row,(name,(size,anims)) in enumerate(CFG.items()):
        y=225+row*170
        # Each row: original / rust south run / rust action / rust east / rust back.
        cases=[(name,'run',2,0),(name+'_rust','run',2,0),
               (name+'_rust',anims[-1],2,5),(name+'_rust','run',0,2),(name+'_rust','run',6,3)]
        for col,(folder,anim,d,f) in enumerate(cases):
            with Image.open(SPRITES/folder/(anim+'.png')) as im:
                frame=im.convert('RGBA').crop((f*size,d*size,(f+1)*size,(d+1)*size))
            board.alpha_composite(frame,(col*215+(160-size)//2,y+(160-size)//2))
    board.save(HERE/'_n3e_contact.png',optimize=True,compress_level=9)
    print('PASS contact: reference strip; rows swarm/shooter/leaper/brute; columns original/rust/action/east/back')

def build(name):
    import bpy
    sys.path.insert(0,str(ROOT/'art/tools/monsters'))
    # Reuse C5 compositor (camera-space normals, emission, exact alpha).
    import iso_monster_build as c5
    from PIL import Image
    size,anims=CFG[name]
    original=SOURCES/(name+'_iso.blend')
    original_hash=digest(original)
    bpy.ops.wm.open_mainfile(filepath=str(original))
    scene=bpy.context.scene
    root=bpy.data.objects[name]
    scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=12
    bpy.context.preferences.filepaths.save_version=0
    scene.render.threads_mode='FIXED';scene.render.threads=6
    def linear(h):
        rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
        return tuple(v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
    def rust(old, obj):
        # Identical C5 geometry: industrial character is carried by layered PBR.
        label=old.name.lower();part=obj.name.lower()
        cloth='linen' in label
        rubber='chitin' in label and any(w in part for w in ('limb','tail','tendon','hock','arm','leg'))
        concrete=name=='brute_tier3' and any(w in part for w in ('torso','maul','gauntlet'))
        kind='spalled concrete' if concrete else 'tarred canvas' if cloth else 'soot cable' if rubber else 'rusted cast iron'
        mat=bpy.data.materials.new('N3E / '+kind+' / '+old.name);mat.use_nodes=True
        n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF')
        mat['rainfall_emissive']=False
        tex=n.new('ShaderNodeTexCoord');tex.object=bpy.data.objects.get('Body') or root
        def noise(scale,detail=3,vector=None):
            node=n.new('ShaderNodeTexNoise');node.inputs['Scale'].default_value=scale
            node.inputs['Detail'].default_value=detail;node.inputs['Roughness'].default_value=.75
            l.new(vector or tex.outputs['Object'],node.inputs['Vector']);return node
        macro=noise(14);micro=noise(145,2)
        stretch=n.new('ShaderNodeVectorMath');stretch.operation='MULTIPLY';stretch.inputs[1].default_value=(18,18,1.1)
        l.new(tex.outputs['Object'],stretch.inputs[0]);streak=noise(5,2,stretch.outputs[0])
        palette=[(.18,'17191A'),(.36,'2B2A29'),(.46,'3E2419'),(.58,'6B3A22'),(.74,'856249')]
        if cloth:palette=[(.18,'101214'),(.36,'202122'),(.46,'2D2B28'),(.58,'414039'),(.74,'656156')]
        if rubber:palette=[(.18,'101213'),(.36,'1A1D1D'),(.46,'252927'),(.58,'393A33'),(.74,'575448')]
        if concrete:palette=[(.18,'202324'),(.36,'383831'),(.46,'535248'),(.58,'767367'),(.74,'9A9281')]
        ramp=n.new('ShaderNodeValToRGB');r=ramp.color_ramp;r.elements.remove(r.elements[1])
        r.elements[0].position=palette[0][0];r.elements[0].color=linear(palette[0][1])
        for pos,col in palette[1:]:r.elements.new(pos).color=linear(col)
        l.new(macro.outputs['Fac'],ramp.inputs[0])
        # Gravity-aligned wet oil rivulets break up the oxide crust.
        wet=n.new('ShaderNodeMapRange');wet.clamp=True;wet.inputs['From Min'].default_value=.57;wet.inputs['From Max'].default_value=.71
        wet.inputs['To Max'].default_value=.78;l.new(streak.outputs['Fac'],wet.inputs['Value'])
        oil=n.new('ShaderNodeMixRGB');l.new(wet.outputs[0],oil.inputs[0]);l.new(ramp.outputs[0],oil.inputs[1]);oil.inputs[2].default_value=linear('111719')
        color=oil.outputs[0]
        # Small round raised fasteners, contained inside the existing plate silhouette.
        vor=n.new('ShaderNodeTexVoronoi');vor.inputs['Scale'].default_value=24 if name=='swarm_tier1' else 14
        vor.inputs['Randomness'].default_value=.32;l.new(tex.outputs['Object'],vor.inputs['Vector'])
        studs=n.new('ShaderNodeMath');studs.operation='LESS_THAN';studs.inputs[1].default_value=.095;l.new(vor.outputs['Distance'],studs.inputs[0])
        if not (cloth or rubber or concrete):
            rivets=n.new('ShaderNodeMixRGB');l.new(studs.outputs[0],rivets.inputs[0]);l.new(color,rivets.inputs[1]);rivets.inputs[2].default_value=linear('80715C');color=rivets.outputs[0]
        if concrete:
            chip=n.new('ShaderNodeMath');chip.operation='GREATER_THAN';chip.inputs[1].default_value=.59;l.new(macro.outputs['Fac'],chip.inputs[0])
            exposed=n.new('ShaderNodeMixRGB');l.new(chip.outputs[0],exposed.inputs[0]);l.new(color,exposed.inputs[1]);exposed.inputs[2].default_value=linear('493022');color=exposed.outputs[0]
        # A thin non-emissive grazing condensation film evokes cold joint vapour.
        facing=n.new('ShaderNodeLayerWeight');facing.inputs['Blend'].default_value=.3
        mist=n.new('ShaderNodeMath');mist.operation='MULTIPLY';mist.inputs[1].default_value=.11 if rubber else .035;l.new(facing.outputs['Fresnel'],mist.inputs[0])
        veil=n.new('ShaderNodeMixRGB');l.new(mist.outputs[0],veil.inputs[0]);l.new(color,veil.inputs[1]);veil.inputs[2].default_value=linear('849091');l.new(veil.outputs[0],p.inputs['Base Color'])
        coarse=n.new('ShaderNodeBump');coarse.inputs['Strength'].default_value=.34;coarse.inputs['Distance'].default_value=.014;l.new(macro.outputs['Fac'],coarse.inputs['Height'])
        fine=n.new('ShaderNodeBump');fine.inputs['Strength'].default_value=.28;fine.inputs['Distance'].default_value=.005;l.new(micro.outputs['Fac'],fine.inputs['Height']);l.new(coarse.outputs[0],fine.inputs['Normal'])
        final=fine.outputs[0]
        if not (cloth or rubber or concrete):
            studs_bump=n.new('ShaderNodeBump');studs_bump.inputs['Strength'].default_value=.65;studs_bump.inputs['Distance'].default_value=.009
            l.new(studs.outputs[0],studs_bump.inputs['Height']);l.new(final,studs_bump.inputs['Normal']);final=studs_bump.outputs[0]
        l.new(final,p.inputs['Normal'])
        rough=n.new('ShaderNodeMapRange');rough.inputs['To Min'].default_value=.57;rough.inputs['To Max'].default_value=.91;l.new(micro.outputs['Fac'],rough.inputs['Value'])
        slick=n.new('ShaderNodeMixRGB');l.new(wet.outputs[0],slick.inputs[0]);l.new(rough.outputs[0],slick.inputs[1]);slick.inputs[2].default_value=(.24,.24,.24,1);l.new(slick.outputs[0],p.inputs['Roughness'])
        p.inputs['Metallic'].default_value=.04 if cloth or rubber or concrete else .62
        p.inputs['Specular IOR Level'].default_value=.38
        return mat
    materials={}
    geometry=[(o.name,len(o.data.vertices),len(o.data.polygons)) for o in root.children_recursive if o.type=='MESH']
    for obj in root.children_recursive:
        if obj.type!='MESH':continue
        for slot in obj.material_slots:
            old=slot.material
            if not old:continue
            key=(old.name,obj.name)
            if key not in materials:
                if old.get('rainfall_emissive',False) or 'emission' in old.name.lower():
                    new=old.copy();new.name='N3E / sodium lantern FF9A3C'
                    p=new.node_tree.nodes.get('Principled BSDF')
                    p.inputs['Base Color'].default_value=linear('FF9A3C')
                    p.inputs['Emission Color'].default_value=linear('FF9A3C')
                    p.inputs['Emission Strength'].default_value=1.0;new['rainfall_emissive']=True
                else:new=rust(old,obj)
                materials[key]=new
            slot.material=materials[key]
    c5.iso_rig.bake_ao_shadows(root)
    scene['n3e_material']='Pitted sheet and cast iron, raised rivets, tar canvas hood, soot cables, spalled concrete boiler worker, oil rivulets, cold non-emissive condensation; sodium FF9A3C only'
    scene['n3e_source']=str(original.relative_to(ROOT));scene['n3e_geometry_preserved']=True
    assert geometry==[(o.name,len(o.data.vertices),len(o.data.polygons)) for o in root.children_recursive if o.type=='MESH']
    source=SOURCES/('n3e_'+name+'.blend')
    root.rotation_euler.z=0;scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    dst=SPRITES/(name+'_rust');dst.mkdir(exist_ok=True)
    temp=SOURCES/('n3e_'+name+'_frames');temp.mkdir(exist_ok=True)
    for j,anim in enumerate(anims):
        sheets={suffix:Image.new('RGBA',(size*8,size*8)) for suffix in ('','_n','_e')}
        for d in range(8):
            root.rotation_euler.z=math.radians(90-45*d)
            for f in range(8):
                scene.frame_set(j*16+f+1)
                path=temp/'frame.png';c5.iso_rig.render_frame(path)
                for suffix in sheets:
                    p=path.with_stem(path.stem+suffix)
                    with Image.open(p) as im:sheets[suffix].paste(im,(f*size,d*size))
            print('N3E',name,anim,DIRS[d],'8/8',flush=True)
        for suffix,im in sheets.items():
            filename=anim+suffix+'.png'
            im.save(dst/filename,optimize=True,compress_level=9)
    imports(name)
    src_tres=SPRITES/name/(name+'.tres')
    (dst/(name+'_rust.tres')).write_text(src_tres.read_text(encoding='utf-8').replace('/'+name+'/', '/'+name+'_rust/'),encoding='utf-8',newline='\n')
    report={'source_sha256':original_hash,'original_tres_sha256':digest(src_tres),'size':size,'grid':[8,8],
            'anims':anims,'dirs':DIRS,'geometry_objects':len(geometry),'geometry_preserved':True,
            'ortho_scale':scene.camera.data.ortho_scale,'shift_y':scene.camera.data.shift_y,
            'render_px_per_u':scene.get('render_px_per_u'),'pivot':[size*.5,size*.7],
            'design':scene['n3e_material']}
    (SOURCES/('n3e_'+name+'.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    # Only remove the known files this renderer created, without recursive deletion.
    for p in temp.glob('frame*.png'):p.unlink()
    if not any(temp.iterdir()):temp.rmdir()
    print('PASS N3E complete',name,flush=True)

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ([] if '--background' in sys.argv else sys.argv[1:])
    parser=argparse.ArgumentParser();parser.add_argument('--verify',action='store_true');parser.add_argument('--contact',action='store_true');parser.add_argument('--imports',action='store_true');parser.add_argument('--name',choices=CFG)
    options=parser.parse_args(args)
    if options.verify:verify()
    elif options.contact:contact()
    elif options.imports:
        for name in CFG:imports(name)
        print('PASS N3E inherited mobile import settings')
    else:
        for name in ([options.name] if options.name else CFG):build(name)
