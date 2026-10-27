"""Store artwork. Source .blend read only; all construction stays in store/."""
from pathlib import Path
import bpy, sys, math, random, json, hashlib
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
WORK=Path(__file__).parent
OUT=ROOT/'game/assets/store'; OUT.mkdir(parents=True,exist_ok=True)
sys.path[:0]=[str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/bosses')]
import cel_style as cel
import boss_common as common
random.seed(281026)

def material(name,color,metal=.0,emission=0):
    return common.material(name,color,metal,.55,emission)

def flat(name,color):
    m=bpy.data.materials.new(name);m.use_nodes=True
    ns=m.node_tree.nodes;ns.clear()
    e=ns.new('ShaderNodeEmission');e.inputs[0].default_value=(*color,1)
    o=ns.new('ShaderNodeOutputMaterial');m.node_tree.links.new(e.outputs[0],o.inputs[0])
    return m

def mesh(name,verts,faces,mat):
    d=bpy.data.meshes.new(name);d.from_pydata(verts,[],faces);d.update()
    o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o)
    d.materials.append(mat);return o

def base_compositor(path):
    s=bpy.context.scene
    tree=bpy.data.node_groups.new('Store cel compositor','CompositorNodeTree')
    s.compositing_node_group=tree
    tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
    a=tree.nodes.new('CompositorNodeRLayers');b=tree.nodes.new('NodeGroupOutput')
    tree.links.new(a.outputs['Image'],b.inputs['Image'])

def camera(pos,target,scale):
    s=bpy.context.scene
    d=bpy.data.cameras.new('Store camera');o=bpy.data.objects.new('Store camera',d)
    s.collection.objects.link(o);o.location=pos
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    d.type='ORTHO';d.ortho_scale=scale;d.lens=55;s.camera=o
    bpy.context.view_layer.update();return o

def lighting():
    s=bpy.context.scene
    for o in s.objects:
        if o.type=='LIGHT':o.hide_render=True
    if s.world is None:s.world=bpy.data.worlds.new('Night')
    s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.07,.09,.11,1)
    s.world.node_tree.nodes['Background'].inputs[1].default_value=.35
    for name,pos,power,color,size in [('Rain worn left rim',(-3,-4,7),540,(.82,.89,1),4),('Cold right fill',(4,-1,4),170,(.57,.73,.85),3)]:
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=color;d.shape='DISK';d.size=size
        o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=pos
        o.rotation_euler=(Vector((0,0,3))-o.location).to_track_quat('-Z','Y').to_euler()

def render(name,w,h,transparent=False,glow=True):
    s=bpy.context.scene
    cel.setup_scene(samples=8);cel.toon_materials('boss')
    cel.install('boss',normals=False)
    cel.cel_passes(WORK/name,'boss',base_configure=base_compositor,normals=False)
    tree=s.compositing_node_group
    if glow:
        output=next(n for n in tree.nodes if n.type=='GROUP_OUTPUT')
        sock=output.inputs['Image'].links[0].from_socket
        g=tree.nodes.new('CompositorNodeGlare')
        if hasattr(g,'glare_type'):g.glare_type='FOG_GLOW';g.quality='HIGH'
        else:g.inputs['Type'].default_value='Fog Glow';g.inputs['Quality'].default_value='High'
        if 'Threshold' in g.inputs:g.inputs['Threshold'].default_value=1.05
        tree.links.new(sock,g.inputs['Image']);tree.links.new(g.outputs['Image'],output.inputs['Image'])
    s.render.resolution_x=w*2;s.render.resolution_y=h*2;s.render.resolution_percentage=100
    s.render.film_transparent=transparent;s.render.image_settings.compression=100
    s.render.filepath=str(WORK/(name+'.png'))
    bpy.ops.render.render(write_still=True)
    print('STORE RENDER PASS',name,flush=True)

def load_boss():
    bpy.ops.wm.open_mainfile(filepath=str(WORK/'rain_sower_store.blend'))
    s=bpy.context.scene;s.frame_set(1)
    for o in s.objects:
        o.animation_data_clear()
    root=bpy.data.objects['RAIN_SOWER_4_5U'];root.rotation_euler=(0,0,0)
    root.location=(0,0,0);root.scale=(1,1,1)
    # The sprite's lifted bronze is subdued for large, front-facing store artwork.
    # Source materials retained; only this working scene receives the wet black patina.
    def patina(c):
        l=sum(c[i]*w for i,w in enumerate((.2126,.7152,.0722)))
        return tuple((v*.5+l*.5)*.38 for v in c[:3])+(c[3],)
    for m in bpy.data.materials:
        if not m.use_nodes or not any(k in m.name.lower() for k in ('bronze','verdigris','arris')):continue
        for n in m.node_tree.nodes:
            if n.type=='BSDF_PRINCIPLED':n.inputs['Base Color'].default_value=patina(n.inputs['Base Color'].default_value)
            elif n.type=='VALTORGB':
                for el in n.color_ramp.elements:el.color=patina(el.color)
    lighting();return root

def rain_panel(cam,width,height,depth,density,background=True):
    """Meshes in camera plane; no raster drawing or downloaded textures."""
    basis=cam.rotation_euler.to_matrix();right=basis@Vector((1,0,0));up=basis@Vector((0,1,0));back=basis@Vector((0,0,1))
    center=cam.location-back*depth
    def p(x,y):return center+right*x+up*y
    objects=[]
    if background:
        # A faceted night sky, subtly lighter around the hood and falling column.
        levels=[flat('Night rain band '+str(i),(.005+i*.0014,.009+i*.002,.013+i*.0028)) for i in range(7)]
        for i in range(28):
            x=-width/2+width*i/28;xx=x+width/28+.001
            k=round(6*(1-abs((i-13.5)/14))**2)
            objects.append(mesh('Faceted rain darkness',[p(x,-height/2),p(xx,-height/2),p(xx,height/2),p(x,height/2)],[(0,1,2,3)],levels[k]))
    colors=[flat('Rain silver '+str(i),(.025+i*.014,.035+i*.017,.043+i*.020)) for i in range(5)]
    groups=[([],[]) for i in colors]
    for i in range(density):
        x=random.uniform(-width/2,width/2);y=random.uniform(-height/2,height/2)
        length=random.uniform(.035,.23)*width/2;thick=random.uniform(.0005,.0013)*width
        a,b=groups[random.randrange(5)];n=len(a)
        a.extend([p(x,y),p(x+thick,y),p(x+thick+.10*length,y+length),p(x+.10*length,y+length)])
        b.append((n,n+1,n+2,n+3))
    for (vs,fs),m in zip(groups,colors):objects.append(mesh('Falling rain engraving',vs,fs,m))
    return objects

def icon_scene():
    root=load_boss();s=bpy.context.scene
    keep=('Pointed hollow lightning cowl','Dark empty cowl well','Worn pointed cowl arris','Lightning conductor peak','Heart first rain drop','Crystal shaded internal facet')
    for o in root.children_recursive:
        if o.type in ('MESH','CURVE'):o.hide_render=not o.name.startswith(keep)
    heart=bpy.data.objects['Exposed white crystal heart'];heart.location=(0,-.40,3.69);heart.scale=(.40,.40,.40)
    # Only the crystal is luminous. The recess has no face or eyes.
    well=bpy.data.objects['Dark empty cowl well'];well.data.materials.clear();well.data.materials.append(flat('Unlit hollow',(.0025,.004,.005)))
    wet=material('Hood silver rivulets',(.24,.29,.29),.6)
    bronze=bpy.data.objects['Pointed hollow lightning cowl']
    # Follow the sloping front surface of the source hood, outside its real opening.
    for side in (-1,1):
        for j in range(5):
            z=3.59+j*.145;x=side*(.46-(z-3.59)*.43)
            pts=[(x,-.365,z+.08),(x+side*.013,-.39,z),(x+side*.020,-.405,z-.08)]
            common.tube('Water coursing over cowl',pts,.004 if j%2 else .0055,wet)
    cam=camera((0,-7,3.92),(0,0,3.92),1.47)
    bg=rain_panel(cam,1.6,1.6,9,110)
    render('icon_master',512,512)
    # Same identity, enough breathing space for Android's circular mask.
    cam.data.ortho_scale=2.92
    for o in bg:o.hide_render=True
    render('icon_foreground_432',432,432,True)
    for o in list(s.objects):
        if o.type in ('MESH','CURVE'):o.hide_render=True
    rain_panel(cam,3.1,3.1,9,150)
    render('icon_background_432',432,432)

def text_object(name,width,center,zbase,y,mat):
    d=bpy.data.curves.new(name,'FONT');d.body='Rainfall'
    d.font=bpy.data.fonts.load(str(ROOT/'game/assets/fonts/cinzel/Cinzel-Variable.ttf'))
    d.size=1;d.align_x='CENTER';d.extrude=.014;d.bevel_depth=.004;d.bevel_resolution=1;d.resolution_u=8
    o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o)
    o.rotation_euler=(math.pi/2,0,0);o.location=(center,y,zbase);d.materials.append(mat)
    bpy.context.view_layer.update();factor=width/o.dimensions.x;o.scale=(factor,)*3
    bpy.context.view_layer.update()
    # Engraved cuts are actual mesh booleans, kept small enough to preserve lettering.
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    cutters=[]
    for i in range(24):
        x=center+random.uniform(-width*.47,width*.47)
        z=zbase+random.uniform(.07,.60)*factor
        cut=common.box('Worn serif engraving',(x,y-.014*factor,z),(.008*factor,.045*factor,random.uniform(.025,.08)*factor),None,bevel=0)
        cut.rotation_euler.y=random.uniform(-.8,.8);cutters.append(cut)
    bpy.ops.object.select_all(action='DESELECT')
    for cut in cutters:cut.select_set(True)
    bpy.context.view_layer.objects.active=cutters[0];bpy.ops.object.join();cutter=cutters[0]
    mod=o.modifiers.new('Rain eroded lettering','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
    return o

def append_ardent():
    before=set(bpy.data.objects)
    with bpy.data.libraries.load(str(ROOT/'art/blender/characters/ardent_iso.blend'),link=False) as (src,dst):
        dst.objects=[n for n in src.objects]
    objects=[o for o in dst.objects if o and o.type not in ('LIGHT','CAMERA')]
    for o in objects:bpy.context.collection.objects.link(o);o.animation_data_clear()
    group=common.empty('Ardent confronting the Source')
    for o in objects:
        if o.parent not in objects:o.parent=group
    bpy.context.view_layer.update()
    pts=[o.matrix_world@Vector(v) for o in objects if o.type=='MESH' and not o.hide_render for v in o.bound_box]
    lo=min(p.z for p in pts);hi=max(p.z for p in pts)
    scale=.73/(hi-lo);group.scale=(scale,)*3;group.rotation_euler.z=math.pi
    group.location=(1.10,-.12,.025-lo*scale)

def feature_scene():
    root=load_boss();root.scale=(.82,)*3;root.location=(2.55,.75,.06)
    # All source chains, folded bronze and chest crystal retained.
    stone=material('Wet slate basalt',(.035,.049,.057),.3)
    rim=material('Worn pool ring',(.075,.095,.100),.4)
    water=material('Cold lake',(.028,.045,.052),.5)
    for radius,depth,z,mat in [(13,.22,-.19,stone),(3.1,.08,-.02,rim),(2.9,.025,.031,water)]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=96,radius=radius,depth=depth,location=(2.2,.8,z))
        o=bpy.context.object;o.name='Source shallow circular basin';o.data.materials.append(mat)
    for r in (1.5,2,2.55,2.85):
        pts=[(2.2+r*math.cos(i*math.tau/96),.8+r*math.sin(i*math.tau/96),.048) for i in range(97)]
        common.tube('Pale ripples in Source',pts,.010,rim)
    # Drowned circular stonework and the cavern's eight surviving columns.
    for i in range(8):
        a=i*math.tau/8;xx=2.2+4.6*math.cos(a);yy=.8+4.6*math.sin(a)
        if yy<-1:continue
        common.box('Drowned basalt column',(xx,yy,1.5),(.45,.55,3),stone,bevel=.045)
        common.box('Worn column capital',(xx,yy,3.02),(.66,.74,.18),rim,bevel=.03)
    for i in range(22):
        a=i*math.tau/22;r=3.5
        ob=common.box('Broken stone ring',(2.2+r*math.cos(a),.8+r*math.sin(a),.005),(.65,.48,.08),stone,bevel=.02)
        ob.rotation_euler.z=a
    append_ardent()
    cam=camera((0,-15,8.5),(0,0,2.05),11.9)
    rain_panel(cam,13,7,24,400)
    # Foreground streaks sparse; the falling rain column stays around the boss.
    rain_panel(cam,11.9,5.81,11,45,False)
    silver=material('Title rain worn pewter',(.39,.44,.45),.5)
    text_object('Rainfall title',4.35,-2.05,1.91,-3.4,silver)
    render('feature_1024x500',1024,500)

def logo_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True);lighting()
    pewter=material('Engraved silver title',(.43,.48,.48),.65)
    title=text_object('Rainfall standalone title',13.1,0,0,0,pewter)
    bpy.context.view_layer.update()
    pts=[title.matrix_world@Vector(v) for v in title.bound_box]
    mid=(min(p.z for p in pts)+max(p.z for p in pts))/2
    cam=camera((0,-12,mid),(0,0,mid),15.0)
    # A few pale bevel facets provide the discreet white crystal accent.
    accent=material('Discreet white crystal serif',(.62,.70,.72),.2,1.12)
    accent['rainfall_emissive']=True;title.data.materials.append(accent)
    for poly in title.data.polygons:
        if poly.normal.z>.15 and poly.normal.z<.9 and poly.center.x>-.3 and poly.center.x<.3:
            poly.material_index=1
    render('logo_title',1600,480,True)

if __name__=='__main__':
    if '--feature-only' in sys.argv:feature_scene()
    else:icon_scene();feature_scene();logo_scene()
    print('STORE ALL RENDERS PASS',flush=True)
