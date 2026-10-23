"""Mini-boss shared timeline/export; geometry and poses live in each build script."""
from common import *
ANIMS={'idle':(1,6),'run':(21,8),'attack':(41,6),'cast_a':(61,8),'cast_b':(81,8),'phase2':(101,8),'death':(121,10)}
DIRECTIONS={a:['e','s','w','n'] if a=='run' else ['s'] for a in ANIMS}
def key(o,f):
    for p in ('location','rotation_euler','scale'):o.keyframe_insert(p,frame=f)
def pulse(mat,f,value):
    socket=mat.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength']
    socket.default_value=value;socket.keyframe_insert('default_value',frame=f)
def ring(name,r,mat,parent):
    bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=8,major_radius=r,minor_radius=.025)
    return finish(bpy.context.object,name,(0,0,.06),(1,1,1),mat,parent)
def export(name,root,animate):
    s=bpy.context.scene
    for anim,(start,count) in ANIMS.items():
        for i in range(count+(1 if anim in ('idle','run') else 0)):
            animate(anim,i,count,start+i)
        s.timeline_markers.new(anim,frame=start)
    s.frame_start=1;s.frame_end=130;s.render.fps=12
    framing=fit_camera(root,ANIMS,170,DIRECTIONS)
    diffuse_compositor(s);pose(root,1,'s')
    path=ART/'blender/monsters'/f'{name}.blend';path.parent.mkdir(parents=True,exist_ok=True)
    s['animation_manifest']=json.dumps({a:{'start':v[0],'frames':v[1],'directions':DIRECTIONS[a],'fps':10 if a=='idle' else 8 if a=='phase2' else 12,'loop':a in ('idle','run')} for a,v in ANIMS.items()})
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    base=ART/'renders/monsters'/name;base.mkdir(parents=True,exist_ok=True)
    (base/'build_report.json').write_text(json.dumps({'framing':framing,'animations':json.loads(s['animation_manifest']),'normal_space':'screen +X right +Y up +Z viewer'},indent=2))
    if '--build-only' not in sys.argv:render_all(name,root,ANIMS,DIRECTIONS,resume='--resume' in sys.argv)
