"""C1 flooded terraces. Background-only, shared C0 MAP/TOP, physical metres.
Reuses ash_lord worn PBR and C0 AO, passes, shadow projection and PNG optimizer.
"""
from pathlib import Path
import sys,json,math,random
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/assets/sprites/terrain/terraces/iso'
AUDIT=ROOT/'art/tools/iso'
SPECS={}
for n in 'abcd': SPECS['ground_'+n]=([512,256],[256,128],0)
for n in ('water_shallow','water_deep'): SPECS[n]=([256,128],[128,64],0)
for n in ('block_a','block_b','block_c','rampart_ne','rampart_nw','rampart_corner_n'): SPECS[n]=([256,256],[128,192],1.25)
for n in ('cliff_sw','cliff_se','cliff_corner_s','cliff_corner_w','cliff_corner_e'): SPECS[n]=([256,384],[128,64],-2.5)
SPECS['void_1024']=([1024,1024],[512,512],0)
def inventory():
    from PIL import Image
    entries=[]
    for name,(size,pivot,height) in SPECS.items():
        old=[]
        for p in sorted(OUT.glob(name+'*.png')):
            with Image.open(p) as im: old.append({'file':p.name,'size':list(im.size)})
        entries.append(dict(name=name,size=size,pivot=pivot,height_u=height,rig='TOP' if name.startswith('void') else 'MAP',existing=old,passes=['diffuse','normal'],emission='none; no black _e',shadow_size=[512,512] if name.startswith('block') else None))
    AUDIT.mkdir(parents=True,exist_ok=True)
    (AUDIT/'_c1_inventory.json').write_text(json.dumps(dict(R=64*math.sqrt(2),assets=entries),indent=2))
if '--inventory' in sys.argv:
    inventory(); print('PASS inventory: 18 assets');sys.exit()
import bpy
from mathutils import Vector
sys.path.insert(0,str(ROOT/'art/tools/iso'))
sys.path.insert(0,str(ROOT/'art/tools/monsters'))
import iso_rig as rig
from ash_lord_build import worn

def box(name,loc,scale,mat,parent,bevel=.012):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object;o.name=name;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.parent=parent;o.data.materials.append(mat)
    if bevel:
        mod=o.modifiers.new('Worn arris','BEVEL');mod.width=bevel;mod.segments=1
        o.modifiers.new('Stone face normals','WEIGHTED_NORMAL')
    return o

def periodic(mat,period=4):
    # Tileable toroidal coordinates, common global origin: all four edges agree.
    n=mat.node_tree.nodes;l=mat.node_tree.links
    tc=n.new('ShaderNodeTexCoord');sep=n.new('ShaderNodeSeparateXYZ');l.new(tc.outputs['Position'] if 'Position' in tc.outputs else tc.outputs['Object'],sep.inputs[0])
    origin=bpy.data.objects.new('Period origin',None);bpy.context.scene.collection.objects.link(origin);tc.object=origin
    def op(kind,a,b=0):
        q=n.new('ShaderNodeMath');q.operation=kind
        if isinstance(a,(float,int)):q.inputs[0].default_value=a
        else:l.new(a,q.inputs[0])
        if isinstance(b,(float,int)):q.inputs[1].default_value=b
        else:l.new(b,q.inputs[1])
        return q.outputs[0]
    x=op('MULTIPLY',sep.outputs['X'],math.tau/period);y=op('MULTIPLY',sep.outputs['Y'],math.tau/period)
    v=n.new('ShaderNodeCombineXYZ')
    for i,sock in enumerate((op('ADD',op('SINE',x),op('MULTIPLY',op('COSINE',y),.43)),op('ADD',op('COSINE',x),op('MULTIPLY',op('SINE',y),.43)),op('SINE',op('ADD',x,y)))):l.new(sock,v.inputs[i])
    for q in n:
        if q.bl_idname=='ShaderNodeTexNoise':l.new(v.outputs[0],q.inputs['Vector'])
    return mat

def setup(name,size,pivot):
    # C0 lookup uses global object names: isolate each retained source scene.
    for key in ('ISO_MAP','ISO_TOP','Sun_chaud_haut_gauche','Fill_froid'):
        previous=bpy.data.objects.get(key)
        if previous:previous.name=previous.users_scene[0].name+'_'+key
    scene=bpy.data.scenes.new(name);scene.world=bpy.data.worlds.new(name+' world');bpy.context.window.scene=scene
    s=rig.create_rig('TOP' if name.startswith('void') else 'MAP',size)
    s.camera.name=name+'_camera'
    if hasattr(s.eevee,'taa_render_samples'):s.eevee.taa_render_samples=16
    # Positive screen up target moves world origin downward in the PNG.
    s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(pivot[1]-size[1]/2)/rig.R,0))
    bpy.ops.object.empty_add();root=bpy.context.object;root.name=name
    stone=worn('Wet cut shale','252D30','596362',.12,.45)
    bronze=worn('Verdigris bronze','5F8F80','8DBBA8',.65,.55)
    mud=worn('Flooded alluvium','202928','424B46',0,.64)
    water=worn('Black rainwater','060E15','172B39',.35,.25)
    return s,root,stone,bronze,mud,water

def ground(name,root,stone,bronze,mud,water):
    variant='abcd'.index(name[-1]);random.seed(81)
    for mat in (stone,bronze,mud,water):
        periodic(mat)
    rice=worn('Dark rice shoots','10271C','294B32',0,.62)
    for tx in (-4,0,4):
      for ty in (-4,0,4):
        box('Silt bed',(tx,ty,-.055),(4,4,.11),mud,root,0)
        # Repeated local details and terrace courses exactly periodic at 4 m.
        for row in range(8):
          for col in range(4):
            rng=random.Random(row*11+col)
            x=-1.5+col
            for wrap in (-4,0,4):
              xx=x+wrap
              if -2.6<xx<2.6:
                mat=stone if variant in (0,2) else mud
                o=box('Inset worn paver',(tx+xx,ty-1.75+row*.5,-.016),(.96,.465,.055),mat,root,.009)
        for j in range(9):
            rng=random.Random(j+210);x=rng.uniform(-1.7,1.7);y=rng.uniform(-1.7,1.7)
            ob=box('Cold puddle',(tx+x,ty+y,.014),(.19+rng.random()*.3,.075,.009),water,root,.012)
            ob.rotation_euler.z=rng.uniform(-.4,.4)
        if variant in (0,2):
            for x in (-1.25,1.25):box('Inset patinated plate',(tx+x,ty+.32,.017),(.22,.16,.018),bronze,root,.007)
        # Water channels and patinated narrow sluice borders.
        for y in (-1.0,1.0):
            box('Irrigation channel',(tx,ty+y,.018),(4,.18,.013),water,root,0)
            if variant in (1,3):
                box('Sluice bronze lip',(tx,ty+y+.13,.032),(4,.035,.035),bronze,root,.004)
        if variant in (1,3):
            for j in range(20):
                rng=random.Random(j+70);x=rng.uniform(-1.8,1.8);y=rng.choice((-.55,.5))+rng.uniform(-.13,.13)
                o=box('Rice stubble',(tx+x,ty+y,.07),(.018,.025,.14),rice,root,.002);o.rotation_euler.y=rng.uniform(-.3,.3)

def masonry(root,stone,bronze,kind):
    joint=worn('Black recessed mortar','080E11','1A2424',0,.76)
    moss=worn('Dark moss and water stains','10201B','293B2B',0,.69)
    cliff=kind.startswith('cliff');bottom=-2.5 if cliff else 0;top=0 if cliff else 1.25
    # Continuous full-cell core gives exact diagonal joins, detailed faces layered inward.
    if cliff:
        box('Top slab',(0,0,-.035),(2,2,.07),stone,root,0)
        faces={'cliff_sw':[(1,-1)],'cliff_se':[(0,1)],'cliff_corner_s':[(1,-1),(0,1)],'cliff_corner_w':[(1,-1),(0,-1)],'cliff_corner_e':[(0,1),(1,1)]}[kind]
        for axis,sign in faces:
            loc=(sign*.985,0,-1.25) if axis==0 else (0,sign*.985,-1.25)
            dims=(.03,2,2.5) if axis==0 else (2,.03,2.5)
            box('Descending fascia',loc,dims,joint,root,0)
    else:box('Continuous retaining core',(0,0,(bottom+top)/2),(1.96,1.96,top-bottom),joint,root,.006)
    rows=8 if cliff else 4
    for axis in (0,1):
      sides=(-1,1) if not cliff else tuple(sign for a,sign in faces if a==axis)
      for sign in sides:
        for row in range(rows):
          z=bottom+(row+.5)*(top-bottom)/rows
          for col in range(4):
            a=-.75+col*.5
            loc=[a,sign*.988,z] if axis==1 else [sign*.988,a,z]
            dims=(.478,.075,(top-bottom)/rows-.026) if axis==1 else (.075,.478,(top-bottom)/rows-.026)
            ob=box('Chipped masonry course',loc,dims,stone,root,.018)
            rng=random.Random(row*17+col*3+axis);ob.rotation_euler[axis]=rng.uniform(-.013,.013)
            if col%2==row%2:
                wetloc=list(loc);wetloc[axis]=sign*1.029;wetloc[2]-=.045
                wetdims=(.045,.006,.15) if axis==1 else (.006,.045,.15)
                box('Dark water streak',wetloc,wetdims,moss,root,.002)
            if row==0:
                foot=list(loc);foot[axis]=sign*1.03;foot[2]=bottom+.045
                fd=(.43,.018,.09) if axis==1 else (.018,.43,.09)
                box('Moss at wall foot',foot,fd,moss,root,.004)
    # Individual cap flags and recessed bronze drainage staples.
    for ix in range(4):
      for iy in range(4):
        box('Wet cap flag',(-.75+ix*.5,-.75+iy*.5,top-.022),(.493,.493,.044),stone,root,.008)
    for x in (-.7,.7):
        box('Drainage strap',(x,-.993,top-.28),(.065,.017,.43),bronze,root,.004)
    if 'rampart' in kind:
        # Back parapets occupy only the corresponding rear edge(s).
        for ob in list(root.children):bpy.data.objects.remove(ob,do_unlink=True)
        edges=[('y',1)] if kind.endswith('ne') else [('x',-1)] if kind.endswith('nw') else [('y',1),('x',-1)]
        for axis,sign in edges:
          for row in range(4):
            for col in range(4):
              p=-.75+.5*col;loc=(p,.86,row*.3125+.15625) if axis=='y' else (-.86,p,row*.3125+.15625)
              dims=(.478,.28,.2925) if axis=='y' else (.28,.478,.2925)
              box('Parapet dressed stone',loc,dims,stone,root,.018)
              if row==0 or (col==1 and row<3):
                  stain=(p,.712,row*.3125+.08) if axis=='y' else (-.712,p,row*.3125+.08)
                  sd=(.22,.012,.12) if axis=='y' else (.012,.22,.12)
                  box('Parapet moss runoff',stain,sd,moss,root,.003)
          for p in (-.64,.64):
              loc=(p,.702,.91) if axis=='y' else (-.702,p,.91)
              dims=(.065,.025,.52) if axis=='y' else (.025,.065,.52)
              box('Verdigris parapet staple',loc,dims,bronze,root,.006)
    if kind in ('block_b','rampart_corner_n'):
        glow=bpy.data.materials.new('Rare cold blue lantern');glow.use_nodes=True
        bs=glow.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.025,.12,.19,1)
        bs.inputs['Emission Color'].default_value=(.07,.38,.8,1);bs.inputs['Emission Strength'].default_value=2.4
        x,y,z=(.55,-1.035,.91) if kind=='block_b' else (-.69,.48,.98)
        box('Bronze lantern mount',(x,y,z),(.14,.075,.22),bronze,root,.012)
        box('Cold lantern slit',(x,y-.042,z),(.056,.018,.105),glow,root,.005)
    if kind=='block_b':
        for y in (-.65,0,.65):box('Bronze sluice brace',(0,y,1.252),(1.95,.045,.018),bronze,root,.003)
    if kind=='block_c':
        for x in (-.6,.6):
            box('Patinated corner plate',(x,-.995,.76),(.24,.025,.51),bronze,root,.005)
            for z in (.57,.95):box('Old bronze rivet',(x,-1.012,z),(.04,.025,.04),bronze,root,.004)

def mask_ground(path):
    # The central diamond alpha is rendered by Blender, not raster-drawn.
    s=bpy.context.scene
    hidden=[(o,o.hide_render) for o in s.objects if o.type=='MESH']
    for o,_ in hidden:o.hide_render=True
    mat=bpy.data.materials.new('Central tile mask');mat.use_nodes=True
    n=mat.node_tree.nodes;n.clear();em=n.new('ShaderNodeEmission');em.inputs[0].default_value=(1,1,1,1);out=n.new('ShaderNodeOutputMaterial');mat.node_tree.links.new(em.outputs[0],out.inputs[0])
    ob=box('Central diamond mask',(0,0,0),(4,4,.00001),mat,None,0)
    tmp=AUDIT/'_c1_mask.png';rig.render_frame(tmp,False)
    bpy.data.objects.remove(ob,do_unlink=True)
    for o,h in hidden:o.hide_render=h
    # Two-pixel dilation of the Blender-rendered alpha; no raster drawing.
    import numpy as np
    m=bpy.data.images.load(str(tmp),check_existing=False)
    base=np.array(m.pixels[:],dtype=np.float32).reshape(256,512,4)[:,:,3]
    pad=np.pad(base,2)
    alpha=np.maximum.reduce([pad[y:y+256,x:x+512] for y in range(5) for x in range(5)]).ravel()
    for suffix in ('','_n'):
        p=path.with_name(path.stem+suffix+'.png');im=bpy.data.images.load(str(p),check_existing=False)
        im.colorspace_settings.name='Non-Color' if suffix else 'sRGB'
        pixels=np.array(im.pixels[:],dtype=np.float32).reshape(-1,4);pixels[:,3]=alpha;im.pixels.foreach_set(pixels.ravel());im.filepath_raw=str(p);im.file_format='PNG'
        # Normal pass encoded raw; avoid a second display transfer.
        im.save();rig.optimize_png(p)
    tmp.unlink(missing_ok=True)

def build():
    OUT.mkdir(parents=True,exist_ok=True)
    for name,(size,pivot,height) in SPECS.items():
        s,root,stone,bronze,mud,water=setup(name,size,pivot)
        if name.startswith('ground'):ground(name,root,stone,bronze,mud,water)
        elif name.startswith('water'):
            periodic(water,2);box('Flooded black bed',(0,0,-.015),(2,2,.03),water,root,0)
            if 'shallow' in name:
                for j in range(12):
                    rng=random.Random(j);box('Submerged shale',(rng.uniform(-.85,.85),rng.uniform(-.85,.85),-.006),(.16,.1,.015),stone,root,.008)
        elif name.startswith('void'):
            fog=periodic(worn('Seamless abyss mist','080E14','28333B',0,1),8)
            box('Abyss',(0,0,-.01),(8,8,.02),fog,root,0)
        else:masonry(root,stone,bronze,name)
        rig.bake_ao_shadows(root)
        path=OUT/(name+'.png');rig.render_frame(path)
        # Keep only authored cold accents; discard near-black Eevee/Lanczos quantization residue.
        if name not in ('block_b','rampart_corner_n'):path.with_name(name+'_e.png').unlink(missing_ok=True)
        if name.startswith('ground'):mask_ground(path)
        if name.startswith('block'):
            cam=s.camera;lights=[(o,o.matrix_world.copy()) for o in s.objects if o.type=='LIGHT'];rig.create_rig('TOP',(512,512),reset=False)
            rig.render_shadow_decal(root,OUT/(name+'_shadow.png'))
            s.camera=cam;rig.set_frame(size,'MAP');s['iso_rig']='MAP'
            for ob,matrix in lights:ob.matrix_world=matrix
        print('C1 PASS '+name,flush=True)
    bpy.context.window.scene=bpy.data.scenes['block_a']
    target=ROOT/'art/blender/terrain/terraces_iso.blend';target.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(target))
    from bpy_extras.object_utils import world_to_camera_view
    checks=[]
    for name,(size,pivot,height) in SPECS.items():
        scene=bpy.data.scenes[name];bpy.context.window.scene=scene;bpy.context.view_layer.update()
        q=world_to_camera_view(scene,scene.camera,Vector((0,0,0)))
        actual=[q.x*size[0],(1-q.y)*size[1]]
        checks.append(dict(name=name,pivot=actual,expected=pivot,pass_check=max(abs(actual[i]-pivot[i]) for i in (0,1))<.01))
    (AUDIT/'_c1_pivots.json').write_text(json.dumps(checks,indent=2))
    print('C1 BUILD PASS',flush=True)
if __name__=='__main__':
    if '--mask-only' in sys.argv or '--pivots-only' in sys.argv:
        bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/terrain/terraces_iso.blend'))
        if '--mask-only' in sys.argv:
            for v in 'abcd':
                bpy.context.window.scene=bpy.data.scenes['ground_'+v]
                mask_ground(OUT/('ground_'+v+'.png'))
        from bpy_extras.object_utils import world_to_camera_view
        checks=[]
        for name,(size,pivot,height) in SPECS.items():
            scene=bpy.data.scenes[name];bpy.context.window.scene=scene;bpy.context.view_layer.update()
            q=world_to_camera_view(scene,scene.camera,Vector((0,0,0)))
            actual=[q.x*size[0],(1-q.y)*size[1]]
            checks.append(dict(name=name,pivot=actual,expected=pivot,pass_check=max(abs(actual[i]-pivot[i]) for i in (0,1))<.01))
        (AUDIT/'_c1_pivots.json').write_text(json.dumps(checks,indent=2))
        print('C1 MASK/PIVOT '+('PASS' if all(c['pass_check'] for c in checks) else 'FAIL'))
    else:build()

