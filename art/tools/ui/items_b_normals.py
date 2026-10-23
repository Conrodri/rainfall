"""Normal maps en espace camera, calculees depuis les volumes Blender."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from ui_lib import *
def normals():
    for s in bpy.data.scenes:
        bpy.context.window.scene=s
        m=bpy.data.materials.new('Normal camera');m.use_nodes=True
        n=m.node_tree.nodes;n.clear();links=m.node_tree.links
        geo=n.new('ShaderNodeNewGeometry');trans=n.new('ShaderNodeVectorTransform');trans.vector_type='NORMAL';trans.convert_from='WORLD';trans.convert_to='CAMERA'
        links.new(geo.outputs['Normal'],trans.inputs['Vector'])
        mul=n.new('ShaderNodeVectorMath');mul.operation='MULTIPLY_ADD';mul.inputs[1].default_value=(.5,.5,.5);mul.inputs[2].default_value=(.5,.5,.5)
        links.new(trans.outputs['Vector'],mul.inputs[0])
        em=n.new('ShaderNodeEmission');links.new(mul.outputs['Vector'],em.inputs['Color']);out=n.new('ShaderNodeOutputMaterial');links.new(em.outputs[0],out.inputs['Surface'])
        s.view_layers[0].material_override=m;s.view_settings.view_transform='Raw'
        raw=ROOT/'art/renders/ui/items'/f'{s.name}_n.png'
        render_to(raw);finalize(raw,ROOT/'game/assets/sprites/icons/items'/f'{s.name}_n.png')
        s.view_layers[0].material_override=None;s.view_settings.view_transform='Standard'
        s.render.filepath=str(ROOT/'art/renders/ui/items'/f'{s.name}.png')
        print('NORMAL_OK',s.name,flush=True)
if __name__=='__main__':normals()
