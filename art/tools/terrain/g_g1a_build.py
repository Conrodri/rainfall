"""G1a grotto fallback tiles; derived from F2 MAP geometry and CEL tile renderer."""
from pathlib import Path
import sys, math
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/iso/_deps'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/terrain'),str(ROOT/'art/tools/monsters'),str(ROOT/'art/tools/cel')]
import bpy
from mathutils import Vector
import iso_rig as rig
import cel_style as cel
OUT=ROOT/'game/assets/sprites/terrain/fog_forest/iso'
SRC=ROOT/'art/blender/terrain'
SPECS={f'ground_{c}':((512,256),(256,128)) for c in 'abcd'}

def build_ground(name,root):
    """Bake periodic mineral colour directly; no lighting rim or texture loss in cel."""
    idx='abcd'.index(name[-1])
    m=bpy.data.materials.new(name+' baked procedural clay');m.use_nodes=True;m['cel_done']=True
    n=m.node_tree.nodes;l=m.node_tree.links;n.clear()
    def node(kind):return n.new('ShaderNode'+kind)
    def link(value,socket):
        if isinstance(value,(int,float,tuple)):socket.default_value=value
        else:l.new(value,socket)
    def op(kind,a,b=0):
        q=node('Math');q.operation=kind;link(a,q.inputs[0]);link(b,q.inputs[1]);return q.outputs[0]
    def rgb(h):
        v=[int(h[i:i+2],16)/255 for i in (0,2,4)]
        return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in v)+(1,)
    def mix(a,b,f):
        q=node('MixRGB');link(f,q.inputs[0]);link(a,q.inputs[1]);link(b,q.inputs[2]);return q.outputs[0]
    tc=node('TexCoord');sep=node('SeparateXYZ');l.new(tc.outputs['Object'],sep.inputs[0])
    # Smooth toroidal coordinates: equal values AND derivatives at opposite tile edges.
    x=op('MULTIPLY',sep.outputs['X'],math.tau/4);y=op('MULTIPLY',sep.outputs['Y'],math.tau/4)
    v=node('CombineXYZ')
    for i,s in enumerate((op('SINE',x),op('COSINE',x),op('SINE',y))):link(s,v.inputs[i])
    fourth=op('COSINE',y)
    def noise(scale,coords=None):
        q=node('TexNoise');q.noise_dimensions='4D';link(fourth,q.inputs['W']);q.inputs['Scale'].default_value=scale;q.inputs['Detail'].default_value=3
        l.new(coords if coords is not None else v.outputs[0],q.inputs['Vector']);return q
    warp=noise(2.3);vm=node('VectorMath');vm.operation='SCALE';link(warp.outputs['Color'],vm.inputs[0]);vm.inputs[3].default_value=.48
    va=node('VectorMath');va.operation='ADD';link(v.outputs[0],va.inputs[0]);link(vm.outputs[0],va.inputs[1])
    def vor(scale,feature='DISTANCE_TO_EDGE'):
        q=node('TexVoronoi');q.voronoi_dimensions='4D';q.feature=feature;link(fourth,q.inputs['W']);q.inputs['Scale'].default_value=scale;link(va.outputs[0],q.inputs['Vector']);return q
    coarse=noise(5.2).outputs['Fac'];fine=noise(135).outputs['Fac']
    field=op('ADD',op('MULTIPLY',coarse,.78),op('MULTIPLY',fine,.22))
    if idx==0:
        stones=vor(24,'F1');edge=vor(24).outputs['Distance']
        field=op('ADD',op('MULTIPLY',field,.55),op('MULTIPLY',stones.outputs['Distance'],.56))
        field=op('SUBTRACT',field,op('MULTIPLY',op('LESS_THAN',edge,.025),.08))
    ramp=node('ValToRGB');r=ramp.color_ramp;r.interpolation='CONSTANT'
    tones=('30261F','4A3A30','5C4A3A') if idx!=1 else ('302F32','3B3A3C','49474A')
    for e,h,t in zip(r.elements,tones[:2],(0,.36 if idx==0 else .40)):e.position=t;e.color=rgb(h)
    r.elements.new(.67 if idx==0 else .60).color=rgb(tones[2]);link(field,ramp.inputs[0]);color=ramp.outputs[0]
    glow=(0,0,0,1)
    if idx==1:
        fissure=op('LESS_THAN',vor(5.5).outputs['Distance'],.010)
        color=mix(color,rgb('29282B'),op('MULTIPLY',fissure,.55))
        for px,py,rx,ry in ((-.72,.37,.34,.19),(.65,-.52,.27,.16),(.34,.98,.19,.12)):
            dx=op('DIVIDE',op('SUBTRACT',sep.outputs['X'],px),rx)
            dy=op('DIVIDE',op('SUBTRACT',sep.outputs['Y'],py),ry)
            radius=op('ADD',op('MULTIPLY',dx,dx),op('MULTIPLY',dy,dy))
            pool=op('LESS_THAN',op('ADD',radius,op('MULTIPLY',coarse,.28)),1)
            sheen=mix(rgb('202024'),rgb('565257'),op('MULTIPLY',op('GREATER_THAN',fine,.57),.40))
            color=mix(color,sheen,pool)
    if idx==2:
        patches=vor(5,'F1');dist=patches.outputs['Distance']
        crust=op('LESS_THAN',op('ADD',dist,op('MULTIPLY',noise(36).outputs['Fac'],.16)),.60)
        mineral=mix(rgb('756751'),rgb('8A7A62'),op('GREATER_THAN',fine,.41))
        color=mix(color,mineral,crust)
    if idx==3:
        edges=vor(2.1).outputs['Distance']
        cracks=op('LESS_THAN',edges,.040);color=mix(color,rgb('25201E'),cracks)
        threads=op('MULTIPLY',op('LESS_THAN',edges,.006),op('GREATER_THAN',noise(12).outputs['Fac'],.43))
        glow=mix((0,0,0,1),rgb('C27BFF'),threads)
        color=mix(color,rgb('C27BFF'),threads)
    emit=node('Emission');link(color,emit.inputs['Color']);out=node('OutputMaterial');link(emit.outputs[0],out.inputs['Surface'])
    aov=node('OutputAOV');aov.aov_name=cel.AOV;link(glow,aov.inputs['Color'])
    mask=op('MULTIPLY',op('LESS_THAN',op('ABSOLUTE',sep.outputs['X']),2),op('LESS_THAN',op('ABSOLUTE',sep.outputs['Y']),2))
    aov=node('OutputAOV');aov.aov_name='G1aMask';link(mask,aov.inputs['Color'])
    bpy.ops.mesh.primitive_plane_add(size=12,location=(0,0,0));p=bpy.context.object;p.name='Seamless baked mineral surface';p.parent=root;p.data.materials.append(m)
    return m

def main():
    from PIL import Image
    old_board=ROOT/'art/renders/grotte/g1a_avant_apres.png'
    baseline=ROOT/'art/archive_3d/sprites/terrain/fog_forest/iso'
    before={name:Image.open(baseline/(name+'.png')).convert('RGBA') if (baseline/(name+'.png')).exists() else Image.open(old_board).convert('RGBA').crop((0,i*128,256,(i+1)*128)) for i,name in enumerate(SPECS)}
    OUT.mkdir(parents=True,exist_ok=True);SRC.mkdir(parents=True,exist_ok=True)
    for name,(size,pivot) in SPECS.items():
        s=rig.create_rig('MAP',size);s.eevee.taa_render_samples=16
        s.render.use_file_extension=True
        s.render.resolution_percentage=100
        s.render.resolution_x=size[0];s.render.resolution_y=size[1]
        s.view_layers[0].aovs.add().name='G1aMask'
        bpy.ops.object.empty_add();root=bpy.context.object;root.name=name
        build_ground(name,root)
        s['iso_frame']=list(size)
        qcam=s.camera
        qcam.location+=qcam.rotation_euler.to_matrix()@Vector((0,(pivot[1]-size[1]/2)/rig.R,0))
        cel.install(dict(cel.profile('tile'),creases=False),normals=False,keep_black_emission=False)
        configure=rig.common.configure_passes
        def hard_tile(path):
            configure(path)
            tree=bpy.context.scene.compositing_node_group;n=tree.nodes;l=tree.links
            rl=next(q for q in n if q.bl_idname=='CompositorNodeRLayers')
            out=next(q for q in n if q.bl_idname=='NodeGroupOutput')
            threshold=n.new('ShaderNodeMath');threshold.operation='GREATER_THAN';threshold.inputs[1].default_value=.5
            l.new(rl.outputs['G1aMask'],threshold.inputs[0])
            alpha=n.new('CompositorNodeSetAlpha');alpha.inputs['Type'].default_value='Replace Alpha'
            l.new(rl.outputs['Image'],alpha.inputs['Image']);l.new(threshold.outputs[0],alpha.inputs['Alpha']);l.new(alpha.outputs[0],out.inputs['Image'])
            for f in [q for q in n if q.bl_idname=='CompositorNodeOutputFile']:
                ealpha=n.new('CompositorNodeSetAlpha');ealpha.inputs['Type'].default_value='Replace Alpha'
                l.new(rl.outputs[cel.AOV],ealpha.inputs['Image']);l.new(threshold.outputs[0],ealpha.inputs['Alpha']);l.new(ealpha.outputs[0],f.inputs[0])
        rig.common.configure_passes=hard_tile
        # F2's renderer and alpha contract, with only the _e pass retained.
        import inspect
        code=inspect.getsource(rig.render_frame).replace("for suffix in (('_e',) if not passes else ('_n','_e')):","for suffix in ('_e',):")
        exec(compile(code,str(Path(rig.__file__)),'exec'),rig.__dict__)
        path=OUT/(name+'.png');rig.render_frame(path)
        cel.uninstall()
        ep=OUT/(name+'_e.png')
        if ep.exists():
            from PIL import Image
            with Image.open(ep) as src:
                half=src.convert('RGBA').resize(((size[0]+1)//2,(size[1]+1)//2),Image.Resampling.LANCZOS)
            half.save(ep,optimize=True,compress_level=9)
        bpy.ops.wm.save_as_mainfile(filepath=str(SRC/('g_'+name+'.blend')))
        for temp in OUT.glob(name+'_e__*.png'): temp.unlink(missing_ok=True)
    board=Image.new('RGBA',(1024,512),(24,23,22,255))
    for i,name in enumerate(SPECS):
        after=Image.open(OUT/(name+'.png')).convert('RGBA')
        for j,im in enumerate((before[name],after)):
            board.alpha_composite(im.resize((256,128),Image.Resampling.LANCZOS),(j*256,i*128))
        # Four independent 3x3 joins, with original alpha preserved.
        tile=after.resize((80,40),Image.Resampling.LANCZOS)
        ox=512+(i%2)*256;oy=(i//2)*256
        for a in range(3):
            for b in range(3):board.alpha_composite(tile,(ox+88+(a-b)*40,oy+48+(a+b)*20))
    board.convert('RGB').save(ROOT/'art/renders/grotte/g1a_avant_apres.png',optimize=True)
    for name in SPECS:
        for suffix in ('','_e'):
            p=OUT/(name+suffix+'.png')
            if p.exists():p.with_suffix('.delivery').write_bytes(p.read_bytes())
    print('PASS G1a: 4 diffuse 512x256; emission 256x128; contact 1024x512',flush=True)

if __name__=='__main__':main()
