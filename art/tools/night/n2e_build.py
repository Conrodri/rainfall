"""N2E: material-only moss variants of the contractual C5 creatures.
Blender background: --python n2e_build.py [-- --name NAME]
System Python: n2e_build.py --verify / --contact. No geometry/animation edits.
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
    dst=SPRITES/(name+'_moss')
    for source in (SPRITES/name).glob('*.png.import'):
        target=dst/source.name
        if target.exists():continue
        params=source.read_text(encoding='utf-8').split('[params]',1)[1]
        target.write_text('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]'+params,encoding='utf-8')

def verify():
    from PIL import Image, ImageChops
    total = 0
    for name,(size,anims) in CFG.items():
        src=SPRITES/name;dst=SPRITES/(name+'_moss')
        original=(src/(name+'.tres')).read_text(encoding='utf-8')
        variant=(dst/(name+'_moss.tres')).read_text(encoding='utf-8')
        assert variant == original.replace('/'+name+'/', '/'+name+'_moss/'), name+' tres contract'
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
        report=json.loads((SOURCES/('n2e_'+name+'.json')).read_text())
        assert report['source_sha256']==digest(SOURCES/(name+'_iso.blend')),name+' source changed'
        assert report['original_tres_sha256']==digest(src/(name+'.tres')),name+' tres changed'
        print('PASS',name+'_moss',size,'px',len(anims)*64,'frames')
    print('PASS N2E',total,'frames; identical grids, animation contracts, aligned passes, <=4096')

def contact():
    from PIL import Image
    # Assembly/cropping only: all picture content comes from Blender renders.
    board=Image.new('RGBA',(1100,920),(24,29,29,255))
    refs=['art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png']
    for col,ref in enumerate(refs):
        with Image.open(ROOT/ref) as im:
            im=im.convert('RGBA');im.thumbnail((350,215));board.alpha_composite(im,(col*365,0))
    for row,(name,(size,anims)) in enumerate(CFG.items()):
        y=225+row*170
        # Each row: original / moss south run / moss action / moss east / moss back.
        cases=[(name,'run',2,0),(name+'_moss','run',2,0),
               (name+'_moss',anims[-1],2,5),(name+'_moss','run',0,2),(name+'_moss','run',6,3)]
        for col,(folder,anim,d,f) in enumerate(cases):
            with Image.open(SPRITES/folder/(anim+'.png')) as im:
                frame=im.convert('RGBA').crop((f*size,d*size,(f+1)*size,(d+1)*size))
            board.alpha_composite(frame,(col*215+(160-size)//2,y+(160-size)//2))
    board.save(HERE/'_n2e_contact.png',optimize=True,compress_level=9)
    print('PASS contact: reference strip; rows swarm/shooter/leaper/brute; columns original/moss/action/east/back')

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
    def moss(old):
        mat=bpy.data.materials.new('N2E / '+old.name);mat.use_nodes=True
        n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF')
        mat['rainfall_emissive']=False
        tex=n.new('ShaderNodeTexCoord')
        # Coordinates attached to the body retain the same infestation across views.
        tex.object=bpy.data.objects.get('Body') or root
        def noise(scale,detail=3):
            node=n.new('ShaderNodeTexNoise');node.inputs['Scale'].default_value=scale
            node.inputs['Detail'].default_value=detail;node.inputs['Roughness'].default_value=.72
            l.new(tex.outputs['Object'],node.inputs['Vector']);return node
        macro=noise(8);micro=noise(115,2);patch=noise(23,2)
        ramp=n.new('ShaderNodeValToRGB');r=ramp.color_ramp
        woody=any(w in old.name.lower() for w in ('iron','binding','linen'))
        palette=[(.17,'111A18'),(.36,'29352D'),(.47,'3D4F39'),(.57,'647158'),(.72,'8E9A7C')]
        if woody: palette=[(.17,'101714'),(.36,'242B24'),(.47,'384A33'),(.57,'5D7051'),(.72,'89977B')]
        r.elements.remove(r.elements[1]);r.elements[0].position=palette[0][0];r.elements[0].color=linear(palette[0][1])
        for pos,col in palette[1:]:r.elements.new(pos).color=linear(col)
        l.new(macro.outputs['Fac'],ramp.inputs[0])
        # Fine pale lichen forms broken colonies rather than uniform green paint.
        threshold=n.new('ShaderNodeMapRange');threshold.clamp=True
        threshold.inputs['From Min'].default_value=.61;threshold.inputs['From Max'].default_value=.74
        threshold.inputs['To Max'].default_value=.60;l.new(patch.outputs['Fac'],threshold.inputs['Value'])
        mix=n.new('ShaderNodeMixRGB');l.new(threshold.outputs[0],mix.inputs[0]);l.new(ramp.outputs[0],mix.inputs[1]);mix.inputs[2].default_value=linear('A0AA8C')
        # Weathered longitudinal fibres remain visible through the moss carpet.
        mapping=n.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=(12,12,1.4)
        l.new(tex.outputs['Object'],mapping.inputs[0])
        grain=n.new('ShaderNodeTexNoise');grain.inputs['Scale'].default_value=9;grain.inputs['Detail'].default_value=2;l.new(mapping.outputs[0],grain.inputs['Vector'])
        coarse=n.new('ShaderNodeBump');coarse.inputs['Strength'].default_value=.30;coarse.inputs['Distance'].default_value=.014;l.new(macro.outputs['Fac'],coarse.inputs['Height'])
        bark=n.new('ShaderNodeBump');bark.inputs['Strength'].default_value=.24;bark.inputs['Distance'].default_value=.009;l.new(grain.outputs['Fac'],bark.inputs['Height']);l.new(coarse.outputs[0],bark.inputs['Normal'])
        fine=n.new('ShaderNodeBump');fine.inputs['Strength'].default_value=.26;fine.inputs['Distance'].default_value=.006;l.new(micro.outputs['Fac'],fine.inputs['Height']);l.new(bark.outputs[0],fine.inputs['Normal']);l.new(fine.outputs[0],p.inputs['Normal'])
        # Cold, restrained grazing veil: surface mist, without changing silhouettes.
        facing=n.new('ShaderNodeLayerWeight');facing.inputs['Blend'].default_value=.3
        mist=n.new('ShaderNodeMath');mist.operation='MULTIPLY';mist.inputs[1].default_value=.13;l.new(facing.outputs['Fresnel'],mist.inputs[0])
        veil=n.new('ShaderNodeMixRGB');l.new(mist.outputs[0],veil.inputs[0]);l.new(mix.outputs[0],veil.inputs[1]);veil.inputs[2].default_value=linear('879C92');l.new(veil.outputs[0],p.inputs['Base Color'])
        rough=n.new('ShaderNodeMapRange');rough.inputs['To Min'].default_value=.59;rough.inputs['To Max'].default_value=.96;l.new(micro.outputs['Fac'],rough.inputs['Value']);l.new(rough.outputs[0],p.inputs['Roughness'])
        p.inputs['Metallic'].default_value=.035;p.inputs['Specular IOR Level'].default_value=.3
        return mat
    materials={}
    geometry=[(o.name,len(o.data.vertices),len(o.data.polygons)) for o in root.children_recursive if o.type=='MESH']
    for obj in root.children_recursive:
        if obj.type!='MESH':continue
        for slot in obj.material_slots:
            old=slot.material
            if not old:continue
            if old.name not in materials:
                if old.get('rainfall_emissive',False) or 'emission' in old.name.lower():
                    new=old.copy();new.name='N2E / cold green will-o-wisp'
                    p=new.node_tree.nodes.get('Principled BSDF')
                    p.inputs['Base Color'].default_value=linear('80BFA1')
                    p.inputs['Emission Color'].default_value=linear('80E1BA')
                    p.inputs['Emission Strength'].default_value=2.8;new['rainfall_emissive']=True
                else:new=moss(old)
                materials[old.name]=new
            slot.material=materials[old.name]
    c5.iso_rig.bake_ao_shadows(root)
    scene['n2e_material']='Black waterlogged wood, patchy moss, pale lichen, cold grazing mist, green will-o-wisp'
    scene['n2e_source']=str(original.relative_to(ROOT));scene['n2e_geometry_preserved']=True
    assert geometry==[(o.name,len(o.data.vertices),len(o.data.polygons)) for o in root.children_recursive if o.type=='MESH']
    source=SOURCES/('n2e_'+name+'.blend')
    root.rotation_euler.z=0;scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    dst=SPRITES/(name+'_moss');dst.mkdir(exist_ok=True)
    temp=SOURCES/('n2e_'+name+'_frames');temp.mkdir(exist_ok=True)
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
            print('N2E',name,anim,DIRS[d],'8/8',flush=True)
        for suffix,im in sheets.items():
            filename=anim+suffix+'.png'
            im.save(dst/filename,optimize=True,compress_level=9)
    imports(name)
    src_tres=SPRITES/name/(name+'.tres')
    (dst/(name+'_moss.tres')).write_text(src_tres.read_text(encoding='utf-8').replace('/'+name+'/', '/'+name+'_moss/'),encoding='utf-8',newline='\n')
    report={'source_sha256':original_hash,'original_tres_sha256':digest(src_tres),'size':size,'grid':[8,8],
            'anims':anims,'dirs':DIRS,'geometry_objects':len(geometry),'geometry_preserved':True,
            'ortho_scale':scene.camera.data.ortho_scale,'shift_y':scene.camera.data.shift_y,
            'render_px_per_u':scene.get('render_px_per_u'),'pivot':[size*.5,size*.7],
            'design':scene['n2e_material']}
    (SOURCES/('n2e_'+name+'.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    # Only remove the known files this renderer created, without recursive deletion.
    for p in temp.glob('frame*.png'):p.unlink()
    if not any(temp.iterdir()):temp.rmdir()
    print('PASS N2E complete',name,flush=True)

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ([] if '--background' in sys.argv else sys.argv[1:])
    parser=argparse.ArgumentParser();parser.add_argument('--verify',action='store_true');parser.add_argument('--contact',action='store_true');parser.add_argument('--imports',action='store_true');parser.add_argument('--name',choices=CFG)
    options=parser.parse_args(args)
    if options.verify:verify()
    elif options.contact:contact()
    elif options.imports:
        for name in CFG:imports(name)
        print('PASS N2E inherited mobile import settings')
    else:
        for name in ([options.name] if options.name else CFG):build(name)
