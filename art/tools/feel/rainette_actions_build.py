"""Rainette action retouch: original RA1 source, solver, CREA and cel exporter."""
import sys, inspect, json, shutil, math, warnings, re, subprocess
warnings.filterwarnings('ignore',category=DeprecationWarning)
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.dont_write_bytecode=True
sys.path.insert(0,str(ROOT/'art/blender/cel/rainette_actions/vendor'))
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools')]
import bpy
from mathutils import Vector, Matrix
import numpy as np
from PIL import Image
import ra1_build as ra
import cel_style as cel
from cel_heroes_d_build import adapted
from halve_emission import downscale
WORK=ROOT/'art/blender/cel/rainette_actions'
BASE=ROOT/'game/assets/sprites/characters/rainette'
ANIMS={'attack':7,'spit':6,'belch':7}
F60={'attack':[2,2,3,7,4,5,6],'spit':[6,2,8,4,5,6],'belch':[6,6,2,12,6,7,8]}
HITS={'attack':3,'spit':2,'belch':3}
ALIASES={'cast':'spit','cast_ult':'belch'}
exec((Path(__file__).with_name('rainette_actions_resources.py')).read_text())
original_pose=ra.pose

def pose(anim,i,n,rig,rest,legs):
    original_pose('idle',0,8,rig,rest,legs)
    torso,al,ar,sac,head,jaw=rig[:6]
    power={'attack':[.42,.62,.73,1,.58,.25,0],
           'spit':[.72,.82,1,.58,.26,0],
           'belch':[.64,.76,.80,1,.65,.30,0]}[anim][i]
    anticipation=i<HITS[anim]
    lean={'attack':(-.32 if anticipation else .42),
          'spit':(-.48 if anticipation else .48),
          'belch':-.20}[anim]*power
    # Rotate around the hips instead of sweeping the torso around the ground origin.
    pivot=Vector((0,0,.90))
    torso.rotation_euler.x=lean
    torso.location+=pivot-torso.rotation_euler.to_matrix()@pivot
    torso.location.y+=(-.32 if not anticipation and anim!='belch' else .04)*power
    torso.scale.x*=1+(.83 if anim=='belch' else .65)*power
    if anticipation:torso.scale.x*=1.25 if anim=='belch' else 1.40
    if i==HITS[anim]:torso.scale.x*=1.55
    torso.scale.y*=1+.22*power
    torso.location.z-=.10*power
    if i==HITS[anim]:torso.location.z-=.15
    head.rotation_euler.x=(-.48 if anticipation else -.20)*power
    head.scale*=1+.18*power
    neck=Vector((0,-.06,1.56))
    head.location+=neck-head.rotation_euler.to_matrix()@Vector(tuple(neck[j]*head.scale[j] for j in range(3)))
    if not anticipation:head.location.y-=.18*power
    jaw.rotation_euler.x=(1.18 if anim!='belch' else .85)*power
    jaw.location.z-=.045*power
    for side,arm in [(-1,al),(1,ar)]:
        arm.rotation_euler.x=(.95 if anim!='belch' else -.65)*power
        arm.rotation_euler.y=side*(1.08 if anim=='belch' else .58)*power
        arm.rotation_euler.z=side*.12*power
        arm.scale*=1+.12*power
    swell=(1.50 if anim=='belch' else 1.18)*power
    sac.scale=(1+swell,1+swell,1+swell)
    # Distinct crouched recovery, ending on the exact original idle pose.
    if i>HITS[anim]:
        torso.location.z-=.16*power
        torso.rotation_euler.x+=.24*power

def build(surface=None,destination=None,work=None):
    global WORK, BASE
    if work is not None:WORK=work
    if destination is not None:BASE=destination
    ra.ANIMS=ANIMS;ra.FPS={a:12 for a in ANIMS};ra.pose=pose
    ra.SOURCE=WORK/'rainette.blend';ra.WORK=WORK
    source=inspect.getsource(ra.source).replace('use_pass_normal=True','use_pass_normal=False')
    exec(compile(source,str(__file__),'exec'),ra.__dict__)
    ra.source()
    bpy.ops.wm.open_mainfile(filepath=str(ra.SOURCE))
    s=bpy.context.scene;root=bpy.data.objects['Rainette']
    s.compositing_node_group=None
    if surface is not None:surface()
    cel.toon_materials('creature');bpy.context.view_layer.update()
    original_meshes=[o for o in root.children_recursive if o.type=='MESH']
    manifest=json.loads(s['animation_manifest'])
    basis=s.camera.rotation_euler.to_matrix();unit=192/ra.iso_rig.R
    bounds={};accent_audit={}
    for anim,n in ANIMS.items():
        meshes=[];copies=[]
        for o in original_meshes:o.hide_render=False
        for f in range(n):
            s.frame_set(manifest[anim]['start']+f);root.rotation_euler.z=0
            bpy.context.view_layer.update()
            glob=None
            if anim=='spit' and f<HITS[anim]:
                head=bpy.data.objects['Frog head']
                sac=bpy.data.objects['Inflatable vocal sac']
                mat=next(o.data.materials[0] for o in sac.children_recursive if o.type=='MESH')
                glob=ra.bead('Mouth held mud globule',(0,-.24,1.52),(.085,.07,.065),mat,head)
                bpy.context.view_layer.update()
            data=ra.posed_mesh(root,anim+str(f));meshes.append(data)
            if glob is not None:bpy.data.objects.remove(glob,do_unlink=True)
            if f==HITS[anim]:
                for mi,mat in enumerate(list(data.materials)):
                    if not any(nd.type=='OUTPUT_AOV' and max(nd.inputs['Color'].default_value[:3])>0 for nd in mat.node_tree.nodes):continue
                    mat=mat.copy();data.materials[mi]=mat
                    for nd in mat.node_tree.nodes:
                        if nd.type=='OUTPUT_AOV':
                            c=tuple(nd.inputs['Color'].default_value)
                            nd.inputs['Color'].default_value=tuple(x*2 for x in c[:3])+(c[3],)
                            accent_audit.setdefault(anim,[]).append({'before':c[:3],'after':list(nd.inputs['Color'].default_value[:3])})
            xyz=np.empty(len(data.vertices)*3,dtype=np.float32)
            data.vertices.foreach_get('co',xyz);xyz=xyz.reshape((-1,3))
            for row,(d,angle) in enumerate(ra.DIRS.items()):
                projected=xyz@np.array(Matrix.Rotation(angle,3,'Z')).T@np.array(basis)
                lo=projected.min(0);hi=projected.max(0)
                box=[96+lo[0]*ra.iso_rig.R,136.32-hi[1]*ra.iso_rig.R,96+hi[0]*ra.iso_rig.R,136.32-lo[1]*ra.iso_rig.R]
                bounds[f'{anim}/{f}/{d}']=[round(float(v),2) for v in box]
                ob=bpy.data.objects.new(anim+'_'+d+'_'+str(f),data);s.collection.objects.link(ob)
                ob.rotation_euler.z=angle
                ob.location=basis@Vector(((f-(n-1)/2)*unit,(3.5-row)*unit,0));copies.append(ob)
                if anim!='attack' and f==HITS[anim]-1:
                    # Exactly one smear frame, two translucent silhouettes of the moving body.
                    for k in range(2):
                        ghost=ob.copy();ghost.data=data.copy();s.collection.objects.link(ghost)
                        ghost.data.materials.clear();ghost.data.materials.append(ghost_material(k))
                        ghost.location+=Matrix.Rotation(angle,3,'Z')@Vector((0,(k+1)*.035,0))
                        copies.append(ghost);meshes.append(ghost.data)
        for o in original_meshes:o.hide_render=True
        (WORK/'preflight.json').write_text(json.dumps(bounds))
        if '--preflight' not in sys.argv:
            ra.iso_rig.set_frame((n*192,1536),'CREA');s['iso_frame']=[n*192,1536]
            s.camera.data.shift_y=.21/n;s.eevee.taa_render_samples=12
            path=WORK/(anim+'.png')
            bpy.context.view_layer.update();cel.install('creature',normals=False)
            ra.iso_rig.common.configure_passes(path)
            s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
            with Image.open(path) as im:im.resize((n*192,1536),Image.Resampling.LANCZOS).save(BASE/path.name,optimize=True,compress_level=9)
            candidates=list(WORK.glob(anim+'_e__*.png'));assert len(candidates)==1,candidates
            with Image.open(candidates[0]) as im:
                full=im.resize((n*192,1536),Image.Resampling.LANCZOS)
                downscale(full).save(BASE/(anim+'_e.png'),optimize=True,compress_level=9)
            candidates[0].unlink()
        for o in copies:bpy.data.objects.remove(o,do_unlink=True)
        for data in meshes:bpy.data.meshes.remove(data)
    if '--preflight' not in sys.argv:
        for alias,a in ALIASES.items():
            for suffix in ('','_e'):shutil.copy2(BASE/(a+suffix+'.png'),BASE/(alias+suffix+'.png'))
        if surface is not None:
            print("PASS Rainette skin action render; no normals",flush=True)
            return
        resources()
        (WORK/'accent_audit.json').write_text(json.dumps(accent_audit))
        with (WORK/'optimize.log').open('w') as log:
            subprocess.run(['C:/Users/const/AppData/Local/Python/bin/python.exe',str(Path(__file__).with_name('rainette_actions_optimize.py'))],check=True,stdout=log,stderr=log)
    print('PASS Rainette action build; no normals',flush=True)

def ghost_material(k):
    name='Rainette smear '+str(k)
    mat=bpy.data.materials.get(name)
    if mat:return mat
    mat=bpy.data.materials.new(name);mat.use_nodes=True;mat['cel_done']=True
    ns=mat.node_tree.nodes;ns.clear()
    out=ns.new('ShaderNodeOutputMaterial');mix=ns.new('ShaderNodeMixShader')
    tr=ns.new('ShaderNodeBsdfTransparent');em=ns.new('ShaderNodeEmission')
    em.inputs['Color'].default_value=(.12,.22,.10,1);mix.inputs[0].default_value=.17-k*.045
    mat.node_tree.links.new(tr.outputs[0],mix.inputs[1]);mat.node_tree.links.new(em.outputs[0],mix.inputs[2]);mat.node_tree.links.new(mix.outputs[0],out.inputs[0])
    return mat

if __name__=='__main__':build()
