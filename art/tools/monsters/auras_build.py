"""Blender background only: analytical eight-frame elite aura loops.
All visible geometry and transparency are rendered in Blender. No raster drawing.
"""
import math, sys, json, shutil
from pathlib import Path
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import setup_scene, material, sphere, ART
TAU=2*math.pi

def emissive(name,color,alpha):
    m=material(name,color,1,True)
    t=m.node_tree;t.nodes.clear()
    out=t.nodes.new('ShaderNodeOutputMaterial')
    mix=t.nodes.new('ShaderNodeMixShader');mix.inputs[0].default_value=alpha
    tr=t.nodes.new('ShaderNodeBsdfTransparent')
    em=t.nodes.new('ShaderNodeEmission');em.inputs[0].default_value=m.diffuse_color
    em.inputs[1].default_value=1
    t.links.new(tr.outputs[0],mix.inputs[1]);t.links.new(em.outputs[0],mix.inputs[2]);t.links.new(mix.outputs[0],out.inputs[0])
    m.surface_render_method='DITHERED'
    return m

def tube(name,points,radius,mat):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=radius;c.bevel_resolution=3
    p=c.splines.new('POLY');p.points.add(len(points)-1)
    for v,co in zip(p.points,points):v.co=(*co,1)
    o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);c.materials.append(mat)
    return o

def flame(name,angle,mat):
    verts=[];faces=[]
    for j in range(9):
        u=j/8;w=.15*(1-u)**.8
        for side in (-1,1):
            r=.83+.055*math.sin(u*5+angle)
            a=angle+.16*math.sin(u*4)
            verts.append((r*math.cos(a)+side*w*-math.sin(a),r*math.sin(a)+side*w*math.cos(a),.04+.61*u))
        if j: k=2*j;faces.append((k-2,k-1,k+1,k))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(mat)
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);return o

def build():
    s=setup_scene(160);s.render.fps=12;s.frame_start=1;s.frame_end=8
    s.camera.data.ortho_scale=3.5588870904384518
    bpy.context.view_layer.update();s.camera.data.shift_y=world_to_camera_view(s,s.camera,Vector((0,0,0))).y-.30
    collections={};animated=[]
    palettes={'burn':('FF7A1F','FFB347'),'slow':('5FA8E8','9FD0FF'),'poison':('7FD35A','B6F07A')}
    for kind,colors in palettes.items():
        before=set(bpy.data.objects)
        mats=[emissive(kind+'_body',colors[0],.80),emissive(kind+'_accent',colors[1],.95),emissive(kind+'_haze',colors[0],.32)]
        # Sparse ground arcs leave the center transparent.
        for j in range(6):
            points=[(.86*math.cos(TAU*(j/6+u*.105)),.86*math.sin(TAU*(j/6+u*.105)),.025) for u in [k/20 for k in range(21)]]
            tube(kind+'_ground_arc',points,.04,mats[0])
        if kind=='burn':
            for j in range(14):
                a=TAU*j/14;o=flame('Pointed flame',a,mats[j%2]);animated.append((kind,'flame',o,a))
            for j in range(8):
                a=TAU*j/8;o=sphere('Rising ember',(0,0,0),(.045,.045,.09),mats[1]);animated.append((kind,'ember',o,a))
        elif kind=='slow':
            for j in range(12):
                a=TAU*j/12
                bpy.ops.mesh.primitive_cone_add(vertices=5,radius1=.1,radius2=0,depth=.22+.09*(j%3))
                o=bpy.context.object;o.name='Faceted frost crystal';o.location=(.85*math.cos(a),.85*math.sin(a),.15);o.rotation_euler=(.24*math.cos(a),.24*math.sin(a),a);o.data.materials.append(mats[j%2])
                animated.append((kind,'crystal',o,a))
            for j in range(3):
                a=TAU*j/3
                pts=[(.89*math.cos(a+u*1.3),.89*math.sin(a+u*1.3),.12+.35*u) for u in [k/32 for k in range(33)]]
                o=tube('Rotating cold wisp',pts,.04,mats[2]);animated.append((kind,'swirl',o,a))
        else:
            for j in range(9):
                a=TAU*j/9
                # Hollow emissive bubble shells preserve the underlying monster.
                pts=[(.065*math.cos(TAU*k/32),0,.065*math.sin(TAU*k/32)) for k in range(33)]
                o=tube('Toxic bubble rim',pts,.028,mats[1]);animated.append((kind,'bubble',o,a))
            for j in range(5):
                a=TAU*j/5
                pts=[((.80+.06*math.sin(u*5))*math.cos(a+u),(.80+.06*math.sin(u*5))*math.sin(a+u),.04+.48*u) for u in [k/32 for k in range(33)]]
                o=tube('Toxic spiral',pts,.06,mats[2]);animated.append((kind,'swirl',o,a))
        collections[kind]=list(set(bpy.data.objects)-before)
    def pose(t):
        t=t%TAU
        for kind,mode,o,a in animated:
            if mode=='flame':o.scale.z=.80+.25*math.sin(t+a);o.rotation_euler.z=.045*math.sin(t+a)
            elif mode=='crystal':o.scale.z=1+.12*math.sin(t+a)
            elif mode=='swirl':o.rotation_euler.z=t
            else:
                angle=a+t*.0+.12*math.sin(t+a)
                o.location=(.85*math.cos(angle),.85*math.sin(angle),.13+.40*(.5+.5*math.sin(t+a)))
                o.scale=(.045,.045,.09) if mode=='ember' else (1+.2*math.cos(t+a),)*3
    # Sample analytic periodic motion; key the duplicate endpoint for playback in the source.
    for frame in range(1,10):
        pose(TAU*(frame-1)/8)
        for _,_,o,_ in animated:
            for prop in ('location','rotation_euler','scale'):o.keyframe_insert(data_path=prop,frame=frame)
    for kind in palettes:
        for k,objects in collections.items():
            for o in objects:o.hide_render=k!=kind
        folder=ART/'renders/monsters'/('elite_'+kind)/'default';folder.mkdir(parents=True,exist_ok=True)
        for i in range(8):
            s.frame_set(i+1);pose(TAU*i/8)
            path=folder/f'x_{i:02d}.png';s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
            # Entire diffuse consists of emission, so the exact same Blender render is the emission pass.
            shutil.copyfile(path,path.with_stem(path.stem+'_e'))
        s.frame_set(9);pose(TAU)
        s.render.filepath=str(folder/'_loop_endpoint.png');bpy.ops.render.render(write_still=True)
    for objects in collections.values():
        for o in objects:o.hide_render=False
    s.frame_set(1);pose(0)
    s['aura_notes']='Three additive overlays; separate by name prefix; endpoint frame 9 equals frame 1. Ground diameter 1.8u. Same scale as brute_tier3.'
    dest=ART/'blender/monsters/elite_auras.blend';dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest))

if __name__=='__main__':build()
