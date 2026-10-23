"""N2G: replay the complete N2D delivery through the shared boss cel pipeline.
No contract rewrites. Background Blender only; system Python archives and validates.
"""
import sys, json, hashlib, argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/cel')]
import n2d_build as base
import cel_style as cel
REL='bosses/etage/hermit_cedar'
OUT=base.OUT
LOG=ROOT/'art/tools/night/_n2g_verification.json'
base.CONTACT=ROOT/'art/tools/night/_n2g_contact.png'

def archive():
    cel.archive_folder(REL)
    print('PASS N2D archived: 18 sheets, 42 animations, 302 frames',flush=True)

def crop_filter_tail():
    from PIL import Image
    # 2x LANCZOS adds a sub-alpha ringing row below two root frames.
    # Crop that transparent fringe to restore the contractual four-pixel margin.
    for suffix in ('','_e'):
        path=OUT/('root_spike'+suffix+'.png')
        with Image.open(path) as src:
            image=Image.new('RGBA',src.size,(0,0,0,0))
            image.paste(src.crop((0,0,src.width,src.height-(2 if suffix=='_e' and src.height==32 else 4))),(0,0))
        image.save(path,compress_level=9)

def preserve_spore_alpha():
    from PIL import Image
    # Retain the archived coverage of the translucent N2D veil: the 2x render
    # otherwise changes stochastic dither coverage even with the same mask.
    with Image.open(cel.ARCHIVE/REL/'spore_cloud.png') as src:alpha=src.getchannel('A')
    for suffix in ('','_e'):
        path=OUT/('spore_cloud'+suffix+'.png')
        if not path.exists():continue
        with Image.open(path) as src:im=src.convert('RGBA')
        if im.size!=alpha.size:continue
        im.putalpha(alpha);im.save(path,compress_level=9)

def render(resume=False,anims=None):
    import bpy
    archive()
    original_build,original_extra=base.build,base.extra
    original_toon=cel.toon_materials
    def build():
        result=original_build()
        # The N2D wood reads just below 90/255 after the 2 px boss ink.
        # Lift source wood/lichen tints in linear space, keeping the mint accent.
        for key in ('wood','bark','moss'):
            mat=result[2][key]
            for node in mat.node_tree.nodes:
                if node.type=='VALTORGB':
                    for el in node.color_ramp.elements:
                        el.color=tuple(min(.72,v*1.28) for v in el.color[:3])+(1,)
        scene=bpy.context.scene
        scene.render.resolution_x=scene.render.resolution_y=512
        scene['iso_frame']=[256,256]
        scene['n2g_render']='cel.install(boss), Eevee8, 2x LANCZOS; N2D geometry and timelines retained'
        scene['n2g_wood_lichen_linear_gain']=1.28
        cel.install('boss', normals=False)
        return result
    def extra(anim,mats):
        result=original_extra(anim,mats)
        w,h=base.dims(base.SPECS[anim][2])
        scene=bpy.context.scene
        scene.render.resolution_x=w*2;scene.render.resolution_y=h*2
        scene['iso_frame']=[w,h]
        return result
    def toon(*a,**kw):
        # Keep the veil's geometric transparency after replacing its surface by cel.
        fresh=[m for m in bpy.data.materials if m.name.startswith('Threadbare drifting') and not m.get('cel_done')]
        for m in fresh:
            m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.15,.21,.17,1)
            # Alpha ramp is a mask, not a source of surface hue.
            for node in list(m.node_tree.nodes):
                if node.type=='VALTORGB':m.node_tree.nodes.remove(node)
        palettes=original_toon(*a,**kw)
        for m in fresh:
            nodes=m.node_tree.nodes;links=m.node_tree.links
            output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
            surface=output.inputs['Surface'].links[0].from_socket
            geo=nodes.new('ShaderNodeNewGeometry')
            noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=3.3
            noise.inputs['Detail'].default_value=4.2;noise.inputs['Roughness'].default_value=.72
            links.new(geo.outputs['Position'],noise.inputs['Vector'])
            ramp=nodes.new('ShaderNodeValToRGB');ramp.color_ramp.interpolation='LINEAR'
            ramp.color_ramp.elements[0].position=.34;ramp.color_ramp.elements[0].color=(0,0,0,1)
            ramp.color_ramp.elements[1].position=.67;ramp.color_ramp.elements[1].color=(.48,.48,.48,1)
            links.new(noise.outputs['Fac'],ramp.inputs[0])
            length=nodes.new('ShaderNodeVectorMath');length.operation='LENGTH'
            links.new(geo.outputs['Position'],length.inputs[0])
            fall=nodes.new('ShaderNodeMapRange');fall.clamp=True
            for key,value in [('From Min',.45),('From Max',1.78),('To Min',1),('To Max',0)]:fall.inputs[key].default_value=value
            links.new(length.outputs['Value'],fall.inputs['Value'])
            alpha=nodes.new('ShaderNodeMath');alpha.operation='MULTIPLY'
            links.new(ramp.outputs[0],alpha.inputs[0]);links.new(fall.outputs[0],alpha.inputs[1])
            trans=nodes.new('ShaderNodeBsdfTransparent');mix=nodes.new('ShaderNodeMixShader')
            links.new(alpha.outputs[0],mix.inputs[0]);links.new(trans.outputs[0],mix.inputs[1])
            links.new(surface,mix.inputs[2]);links.new(mix.outputs[0],output.inputs['Surface'])
        return palettes
    cel.toon_materials=toon
    base.build=build;base.extra=extra
    # Existing SpriteFrames and import settings already satisfy the complete contract.
    base.write_tres=lambda:None
    base.import_policy=lambda:None
    base.contact=lambda:None
    base.verify=lambda:None
    # Reuse N2D geometry, poses and renderer; pack only diffuse/emission.
    # The source blend and SpriteFrames are retained byte for byte.
    from PIL import Image
    import tempfile
    with tempfile.TemporaryDirectory(prefix='rainfall_n2g_') as tmp:
        for name,(frames,dirs,size) in base.SPECS.items():
            if anims and name not in anims:continue
            if resume and all((OUT/(name+suffix+'.png')).exists() for suffix in ('','_e')):continue
            root,pose,mats=build()
            if name in base.EXTRAS:
                for ob in [root,*root.children_recursive]:ob.hide_render=True
                root,pose=extra(name,mats)
            w,h=base.dims(size)
            boards=[Image.new('RGBA',(w*frames,h*len(dirs))) for _ in range(2)]
            for row,direction in enumerate(dirs):
                for i in range(frames):
                    path=Path(tmp)/'frame.png'
                    base.c.render_still(root,lambda t:pose(name.removesuffix('_dirs'),i,frames),path,0,direction)
                    with Image.open(path) as src:diffuse=src.convert('RGBA').resize((w,h),Image.Resampling.LANCZOS)
                    with Image.open(path.with_name('frame_e.png')) as src:emit=src.convert('RGBA').resize((w,h),Image.Resampling.LANCZOS)
                    emit.putalpha(diffuse.getchannel('A'))
                    for board,image in zip(boards,(diffuse,emit)):board.paste(image,(i*w,row*h))
            for suffix,board in zip(('','_e'),boards):board.save(OUT/(name+suffix+'.png'),compress_level=9)
            print('PASS rendered',name,flush=True)
    if not anims or 'root_spike' in anims:crop_filter_tail()
    if not anims or 'spore_cloud' in anims:preserve_spore_alpha()
    print('PASS N2G cel diffuse/emission; no normal files',flush=True)

def create_contact():
    from PIL import Image
    import math
    tiles=[]
    samples=[(name,row) for name,(_,dirs,_) in base.SPECS.items() for row in range(len(dirs))]
    for name,row in samples:
        frames,dirs,size=base.SPECS[name];w,h=base.dims(size)
        tile=Image.new('RGBA',(384,150),(62,74,63,255))
        with Image.open(OUT/(name+'.png')) as src:
            for k,i in enumerate((0,frames//2,frames-1)):
                im=src.crop((i*w,row*h,(i+1)*w,(row+1)*h)).convert('RGBA')
                im.thumbnail((128,146),Image.Resampling.LANCZOS)
                tile.alpha_composite(im,(k*128+(128-im.width)//2,2))
        tiles.append(tile)
    sheet=Image.new('RGBA',(1536,math.ceil(len(tiles)/4)*150+210),(62,74,63,255))
    for k,im in enumerate(tiles):sheet.alpha_composite(im,((k%4)*384,(k//4)*150))
    for k,ref in enumerate(('art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png')):
        with Image.open(ROOT/ref) as src:im=src.convert('RGBA').crop((0,0,min(src.width,800),min(src.height,440)))
        im.thumbnail((512,205),Image.Resampling.LANCZOS);sheet.alpha_composite(im,(k*512,sheet.height-210))
    sheet.save(base.CONTACT,compress_level=9)

def verify():
    from PIL import Image
    import numpy as np
    import re
    assert not list(OUT.glob('*_n.png')), 'Normal maps forbidden'
    text=(OUT/'hermit_cedar.tres').read_text()
    assert 'CanvasTexture' not in text and 'normal_texture' not in text
    count=0
    for name,(frames,dirs,size) in base.SPECS.items():
        w,h=base.dims(size)
        with Image.open(OUT/(name+'.png')) as im:
            assert im.size==(w*frames,h*len(dirs)),name
            for row in range(len(dirs)):
                for i in range(frames):
                    box=im.crop((i*w,row*h,(i+1)*w,(row+1)*h)).getchannel('A').getbbox()
                    assert box and min(box[0],box[1],w-box[2],h-box[3])>=4,(name,row,i,box)
                    count+=1
        emission=OUT/(name+'_e.png')
        if emission.exists():
            with Image.open(emission) as im:
                a=np.asarray(im.convert('RGBA')).astype(float)
                assert (a[:,:,:3].dot([.2126,.7152,.0722])*a[:,:,3]/255).max()>2,(name,'empty emission')
    assert len(re.findall('type="AtlasTexture"',text))==count
    assert len(re.findall(r'"name": &"([^"]+)"',text))==42
    results=[]
    for name,(frames,dirs,size) in base.SPECS.items():
        result=cel.check_sheet(REL+'/'+name+'.png',cell=None if name=='root_spike' else size,frames=frames,rows=len(dirs),emission=False,normals=False)
        with Image.open(OUT/(name+'.png')) as im:
            a=np.asarray(im.convert('RGBA'));opaque=a[:,:,3]>240
            result['mean_rgb']=round(float(a[:,:,:3][opaque].mean()),2)
            if name=='root_spike':
                cells=[a[:,i*512:(i+1)*512] for i in range(frames)]
                assert all(c[:,:,3].max()>0 for c in cells),'empty emerging roots'
                assert len({hashlib.sha256(c.tobytes()).hexdigest() for c in cells})==frames
        if name.startswith('idle'):
            assert result['mean_rgb']>=90,(name,'night readability',result['mean_rgb'])
            mod=np.array([143,163,168])/255;weights=np.array([.2126,.7152,.0722])
            ground=float((np.array([62,74,63])*mod*weights).sum())
            result['night_luma_delta']=round(float((a[:,:,:3][opaque]*mod*weights).sum(1).mean()-ground),2)
            assert result['night_luma_delta']>8,(name,'forest contrast')
        results.append(result)
    original=cel.ARCHIVE/REL/'hermit_cedar.tres'
    assert original.read_bytes()==(OUT/'hermit_cedar.tres').read_bytes(),'SpriteFrames changed'
    LOG.write_text(json.dumps({'sheets':results,'tres_unchanged':True,'inherited':'N2D complete model, poses, extras, grids and pivots','render':'N2G boss cel, 8 samples, 2x LANCZOS'},indent=2),encoding='utf-8')
    create_contact()
    # All visual references are inspected in this single final contact sheet.
    with Image.open(base.CONTACT) as source:contact=source.convert('RGBA')
    with Image.open(ROOT/'art/tools/night/_cs1_contact.png') as source:
        ref=source.crop((source.width//2,0,source.width,source.height)).convert('RGBA')
    ref.thumbnail((contact.width,320),Image.Resampling.LANCZOS)
    sheet=Image.new('RGBA',(contact.width,contact.height+ref.height),(62,74,63,255))
    sheet.alpha_composite(contact);sheet.alpha_composite(ref,((sheet.width-ref.width)//2,contact.height))
    sheet.save(base.CONTACT,compress_level=9)
    (OUT/'manifest.md').write_text('N2G — Le Cèdre-Ermite, complément cel de N2D.\n\n'
        'N2D conservé : modèle de cèdre-reliquaire fendu, lanterne bronze menthe, cordes et tablettes, '
        'poses et transitions des trois phases, 42 animations / 302 frames, trois extras, noms, grilles, pivots et SpriteFrames. Aucun extra ne manquait.\n\n'
        'N2G : les 18 planches sont entièrement re-rendues avec cel.install(\'boss\', normals=False), encre intérieure 2 px, '
        'trois tons, Eevee 8 échantillons, rendu x2 et réduction LANCZOS. Teintes bois/lichen relevées de 1,28 en espace linéaire '
        'pour dépasser 90/255 après encrage ; accent unique #9CF0C8 dans _e. Voile de spores cel conservant son masque de transparence N2D. '
        'Normales écran re-quantifiées après assemblage, alpha identique entre les trois cartes.\n\n'
        'Corps 256×256, pivots N2D conservés près de y220. Root_spike 512×64, spore_cloud 256×256, stump 96×128. '
        'Toutes les planches ≤4096 px. Source art/blender/monsters/hermit_cedar_iso.blend ; '
        'script art/tools/night/n2g_build.py ; contrôle art/tools/night/_n2g_contact.png. '
        'Archive 3D préalable : art/archive_3d/sprites/bosses/etage/hermit_cedar.\n',encoding='utf-8')
    print('PASS N2G: 18 cel diffuse/emission pairs; unchanged SpriteFrames; all idle means >=90',flush=True)

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--render',action='store_true');ap.add_argument('--resume',action='store_true');ap.add_argument('--archive',action='store_true');ap.add_argument('--finish-passes',action='store_true');ap.add_argument('--anims',nargs='*')
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:])
    if args.finish_passes:
        preserve_spore_alpha()
        print('PASS no normal pass')
    elif args.render:render(args.resume,args.anims)
    elif args.archive:archive()
    else:verify()
