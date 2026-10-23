import bpy, math, os, json
from mathutils import Vector
from pathlib import Path
BASE=Path(r'C:\Users\const\Documents\Rainfall\art')
BLEND=BASE/'blender/ardent.blend'
DIRS=['e','se','s','sw','w','nw','n','ne']

def material(name,h,emission=0):
    rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    rgb=[v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    m=bpy.data.materials.new(name); m.diffuse_color=(*rgb,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*rgb,1); p.inputs['Roughness'].default_value=.78
    if emission: p.inputs['Emission Color'].default_value=(*rgb,1); p.inputs['Emission Strength'].default_value=emission
    return m

def empty(name,loc=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); o.location=loc; o.parent=parent; return o

def sphere(name,loc,scale,mat,parent):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16)
    o=bpy.context.object; o.name=name; o.parent=parent; o.location=loc; o.scale=scale; o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
    return o

def cone(name,loc,r1,r2,depth,mat,parent,scale=(1,1,1)):
    bpy.ops.mesh.primitive_cone_add(vertices=32,radius1=r1,radius2=r2,depth=depth)
    o=bpy.context.object; o.name=name; o.parent=parent; o.location=loc; o.scale=scale; o.data.materials.append(mat)
    bevel=o.modifiers.new('Soft tailored edges','BEVEL'); bevel.width=.012; bevel.segments=3
    for p in o.data.polygons:p.use_smooth=True
    return o

def build():
    assert Path(bpy.data.filepath)==BLEND, 'Only operate in Rainfall ardent.blend'
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    s=bpy.context.scene; s.render.engine='BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in [x.identifier for x in s.render.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE'
    s.render.resolution_x=s.render.resolution_y=384; s.render.resolution_percentage=100
    s.render.film_transparent=True; s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'; s.render.image_settings.color_depth='8'
    s.view_settings.view_transform='Standard'; s.view_settings.look='None'; s.view_settings.exposure=0; s.view_settings.gamma=1
    if hasattr(s,'eevee'): s.eevee.taa_render_samples=24
    s.world=bpy.data.worlds.new('Rainfall ambient'); s.world.use_nodes=True; s.world.node_tree.nodes['Background'].inputs[0].default_value=(.17,.21,.29,1); s.world.node_tree.nodes['Background'].inputs[1].default_value=.35
    rust=material('Cloth â€¢ #7A3B24','A5502F'); hood=material('Hood â€¢ #3A2A2A','6B5A5E'); dark=material('Contour â€¢ #1a1620','1A1620'); wood=material('Wood â€¢ #3F2B1E','3F2B1E'); leather=material('Leather â€¢ #6B4A32','8A5A38'); skin=material('Skin â€¢ #D9A98A','E0B090'); gold=material('Gold â€¢ #F2C14E','F2C14E'); fire=material('Ember â€¢ #FF7A1F','FF7A1F',.85); core=material('Core â€¢ #FFE9A8','FFE9A8',1.3)
    root=empty('Ardent_Root'); body=empty('Body',(0,0,0),root)
    cone('Robe', (0,0,.38),.235,.14,.43,rust,body, (1,.83,1))
    cone('Hem dark piping',(0,0,.171),.24,.236,.025,hood,body,(1,.83,1))
    cone('Leather belt',(0,0,.46),.194,.182,.055,leather,body,(1,.84,1))
    sphere('Buckle',(0,-.16,.46),(.042,.016,.032),gold,body)
    cape=empty('Cape hinge',(0,.07,.61),body)
    cone('Cape',(0,.07,-.20),.275,.115,.43,hood,cape,(1,.58,1))
    # Hood shell and inset face create a thick dark rim without a boolean.
    sphere('Oversized hood',(0,0,.81),(.258,.226,.277),hood,body)
    sphere('Face shadow',(0,-.184,.79),(.193,.071,.197),dark,body)
    sphere('Face',(0,-.224,.777),(.155,.042,.153),skin,body)
    sphere('Hood brow',(0,-.214,.935),(.179,.045,.059),hood,body)
    for x in [-.061,.061]:
        sphere('Eye',(x,-.267,.804),(.017,.008,.025),dark,body)
        sphere('Eye glint',(x-.004,-.274,.815),(.005,.003,.006),core,body)
    sphere('Nose',(0,-.275,.763),(.024,.021,.027),skin,body)
    for side,x in [('L',-.105),('R',.105)]:
        leg=empty('Leg_'+side,(x,0,.25),body)
        sphere('Boot_'+side,(0,-.037,-.16),(.078,.113,.085),wood,leg)
        cone('Legging_'+side,(0,0,-.063),.058,.064,.17,leather,leg)
    for side,x in [('L',-.205),('R',.205)]:
        arm=empty('Arm_'+side,(x,0,.57),body)
        sleeve=sphere('Sleeve_'+side,(x*.22,-.025,-.095),(.087,.085,.144),rust,arm)
        sphere('Cuff_'+side,(x*.30,-.056,-.19),(.071,.067,.045),hood,arm)
        sphere('Hand_'+side,(x*.30,-.07,-.224),(.057,.052,.055),skin,arm)
    arm=bpy.data.objects['Arm_R']
    staff=empty('Staff',(.08,-.09,-.20),arm)
    cone('Short ash staff',(0,0,.065),.021,.017,.67,wood,staff)
    for z in [.24,.27,.30]: cone('Staff brass binding',(0,0,z),.025,.025,.013,gold,staff)
    ember=sphere('Staff ember',(0,0,.455),(.064,.057,.097),fire,staff)
    sphere('Ember heart',(-.013,-.044,.46),(.026,.022,.049),core,ember.parent)
    for x in [-.047,.047]:
        fork=cone('Ember cradle',(x,0,.37),.013,.009,.12,gold,staff); fork.rotation_euler[1]=x*5
    hand=bpy.data.objects['Arm_L']
    for i,(x,z) in enumerate([(-.07,-.17),(-.11,-.1),(-.025,-.07)]): sphere('Hand spark '+str(i),(x,-.095,z),(.013,.013,.022),fire,hand)
    ld=bpy.data.lights.new('Warm hand glow','POINT'); ld.energy=2; ld.color=(1,.22,.035); ld.shadow_soft_size=.10
    lo=bpy.data.objects.new('Warm hand glow',ld); bpy.context.collection.objects.link(lo); lo.parent=hand; lo.location=(-.065,-.10,-.15)
    for name,loc,power,color,kind in [('Warm upper left',(-3,-4,6),2.4,(1,.76,.53),'SUN'),('Cool fill',(3,1,4),65,(.46,.62,1),'AREA')]:
        ld=bpy.data.lights.new(name,kind); ld.energy=power; ld.color=color
        if kind=='SUN':ld.angle=.15
        else:ld.shape='DISK'; ld.size=4
        o=bpy.data.objects.new(name,ld); bpy.context.collection.objects.link(o); o.location=loc; o.rotation_euler=(Vector((0,0,.45))-o.location).to_track_quat('-Z','Y').to_euler()
    camd=bpy.data.cameras.new('Fixed orthographic 55deg'); cam=bpy.data.objects.new('Camera',camd); bpy.context.collection.objects.link(cam)
    target=Vector((0,0,.47)); cam.location=target+Vector((0,-4*math.cos(math.radians(55)),4*math.sin(math.radians(55))))
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler(); camd.type='ORTHO'; camd.ortho_scale=1.35; s.camera=cam
    # Frames 1..8 idle, 17..24 run, with identical closing keys at 9 and 25.
    for anim,start in [('idle',1),('run',17)]:
        for i in range(9):
            t=2*math.pi*i/8; run=anim=='run'
            body.location=(0,0,(.018*(1-math.cos(2*t)) if run else .006*math.sin(t)))
            body.rotation_euler=(.10 if run else .012*math.sin(t),.035*math.sin(t) if run else .012*math.cos(t),0)
            body.scale=(1,1,1+(.008*math.sin(t) if not run else 0))
            for prop in ['location','rotation_euler','scale']:body.keyframe_insert(prop,frame=start+i)
            cape.rotation_euler=(.12+(.18*math.cos(2*t) if run else .025*math.sin(t)),.025*math.sin(t),.04*math.sin(t)); cape.keyframe_insert('rotation_euler',frame=start+i)
            for side,sign in [('L',1),('R',-1)]:
                leg=bpy.data.objects['Leg_'+side]; leg.rotation_euler[0]=sign*.72*math.sin(t) if run else 0; leg.keyframe_insert('rotation_euler',frame=start+i)
                a=bpy.data.objects['Arm_'+side]; a.rotation_euler[0]=-sign*.40*math.sin(t) if run else .035*math.sin(t+sign); a.keyframe_insert('rotation_euler',frame=start+i)
            ember.scale=(.064*(1+.12*math.sin(t)),.057*(1+.12*math.sin(t)),.097*(1+.16*math.sin(t))); ember.keyframe_insert('scale',frame=start+i)
    s.frame_start=1; s.frame_end=24; s.render.fps=12
    s.timeline_markers.clear()
    for name,f in [('idle',1),('idle loop',9),('run',17),('run loop',25)]:s.timeline_markers.new(name,frame=f)
    revise_visuals()
    s.frame_set(1); root.rotation_euler[2]=0
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))

def revise_visuals():
    # Local forward is -Y: +90 Z is screen east, zero is south.
    import bmesh
    s=bpy.context.scene
    hood=bpy.data.objects['Oversized hood']
    bm=bmesh.new(); bm.from_mesh(hood.data)
    # Open the front hemisphere: expose cheek, eyes and nose in true profile.
    faces=[f for f in bm.faces if f.calc_center_median().y < -.30 and f.calc_center_median().z < .53]
    bmesh.ops.delete(bm,geom=faces,context='FACES'); bm.to_mesh(hood.data); bm.free()
    lining=material('Lining ? #D9783A','D9783A')
    cape=bpy.data.objects['Cape']; cape.data.materials.clear(); cape.data.materials.append(bpy.data.objects['Robe'].data.materials[0])
    bpy.data.objects['Hem dark piping'].data.materials.clear(); bpy.data.objects['Hem dark piping'].data.materials.append(lining)
    bpy.data.objects['Face shadow'].data.materials.clear(); bpy.data.objects['Face shadow'].data.materials.append(bpy.data.objects['Oversized hood'].data.materials[0])
    for name in ['Face','Nose','Eye','Eye.001','Eye glint','Eye glint.001']:
        o=bpy.data.objects.get(name)
        if o: o.location.y-=.035
    # Low diffuse emission keeps shaded cloth readable without washing out its shading.
    for o in s.objects:
        if o.type=='MESH':
            for m in o.data.materials:
                bs=m.node_tree.nodes.get('Principled BSDF') if m.use_nodes else None
                if bs and not m.name.startswith(('Ember','Core','Contour')):
                    bs.inputs['Emission Color'].default_value=bs.inputs['Base Color'].default_value
                    bs.inputs['Emission Strength'].default_value=.32
    ember=bpy.data.objects['Staff ember']
    # Animated scale keys also need enlarging.
    action=ember.animation_data.action
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    if fc.data_path=='scale':
                        for k in fc.keyframe_points:
                            k.co.y*=1.3; k.handle_left.y*=1.3; k.handle_right.y*=1.3
    bpy.data.objects['Ember heart'].scale*=1.3
    for v in ember.data.vertices:
        if v.co.z>0: v.co.x*=1-.45*v.co.z; v.co.y*=1-.45*v.co.z; v.co.z*=1.13
    for name in ['Staff ember','Ember heart']:
        bs=bpy.data.objects[name].data.materials[0].node_tree.nodes.get('Principled BSDF')
        bs.inputs['Specular IOR Level'].default_value=0
    bpy.data.objects['Hood brow'].scale.y*=.7
    bpy.data.objects['Cool fill'].data.energy=220
    bpy.data.objects['Cool fill'].location=(3,-2,4)
    o=bpy.data.objects['Cool fill']; o.rotation_euler=(Vector((0,0,.5))-o.location).to_track_quat('-Z','Y').to_euler()
    ld=bpy.data.lights.new('Cold silhouette rim #9FB8D8','AREA'); ld.energy=330; ld.color=(.624,.722,.847); ld.shape='DISK'; ld.size=2.5
    o=bpy.data.objects.new(ld.name,ld); bpy.context.collection.objects.link(o); o.location=(2,3,4)
    o.rotation_euler=(Vector((0,0,.55))-o.location).to_track_quat('-Z','Y').to_euler()
    s.world.node_tree.nodes['Background'].inputs[1].default_value=.65
    s.camera.data.ortho_scale=1.35/1.15
    # Camera shift fixes the world ground origin at y=70% for every pose.
    s.camera.data.shift_y=0
    from bpy_extras.object_utils import world_to_camera_view
    bpy.context.view_layer.update()
    ground=world_to_camera_view(s,s.camera,Vector((0,0,0)))
    s.camera.data.shift_y=ground.y-.30
    # Fit every animated vertex once, with one shared camera and fixed ground pivot.
    required=s.camera.data.ortho_scale
    for f in list(range(1,9))+list(range(17,25)):
        s.frame_set(f)
        for di in range(8):
            bpy.data.objects['Ardent_Root'].rotation_euler.z=math.radians(90-45*di)
            bpy.context.view_layer.update()
            for o in s.objects:
                if o.type!='MESH': continue
                for v in o.data.vertices:
                    q=world_to_camera_view(s,s.camera,o.matrix_world@v.co)
                    required=max(required,s.camera.data.ortho_scale*max(abs(q.x-.5)/(.5-10/384),(q.y-.3)/(.7-10/384),(.3-q.y)/(.3-10/384)))
    s.camera.data.ortho_scale=required
    s.camera.data.shift_y=0
    bpy.context.view_layer.update()
    s.camera.data.shift_y=world_to_camera_view(s,s.camera,Vector((0,0,0))).y-.30
    s['framing_note']='Maximum common zoom preserving ground at 70% and >=6px margin incl. outline; enlarged ember limits zoom.' 



def fit_union_camera():
    """One evaluated-geometry union for 16 poses x 8 directions, all three passes."""
    s=bpy.context.scene;cam=s.camera;root=bpy.data.objects['Ardent_Root']
    oldscale=cam.data.ortho_scale
    inv=cam.matrix_world.inverted();ground=inv@Vector((0,0,0))
    xmin=ymin=float('inf');xmax=ymax=-float('inf')
    for frame in list(range(1,9))+list(range(17,25)):
        s.frame_set(frame)
        for di in range(8):
            root.rotation_euler.z=math.radians(90-45*di);bpy.context.view_layer.update()
            deps=bpy.context.evaluated_depsgraph_get()
            for obj in s.objects:
                if obj.type!='MESH' or obj.hide_render:continue
                ev=obj.evaluated_get(deps);mesh=ev.to_mesh()
                for v in mesh.vertices:
                    q=inv@(ev.matrix_world@v.co)-ground
                    xmin=min(xmin,q.x);xmax=max(xmax,q.x);ymin=min(ymin,q.y);ymax=max(ymax,q.y)
                ev.to_mesh_clear()
    # Reserve 5px transparent border plus outline and measured halo support.
    # The rendered-alpha audit below measures the actual result.
    margin=9.5/384
    candidates=[]
    for percent in range(700,741):
        pivot=percent/1000
        scale=max((ymax-ymin)/.92,(xmax-xmin)/(1-2*margin),ymax/(pivot-margin),-ymin/(1-pivot-margin))
        candidates.append((scale,percent))
    scale,percent=min(candidates)
    cam.data.ortho_scale=scale;cam.data.shift_x=cam.data.shift_y=0
    from bpy_extras.object_utils import world_to_camera_view
    bpy.context.view_layer.update()
    q=world_to_camera_view(s,cam,Vector((0,0,0)))
    cam.data.shift_y=q.y-(1-percent/1000)
    cam.data.shift_x=(xmin+xmax)/(2*scale)
    report={'union_camera':[xmin,xmax,ymin,ymax],'ortho_scale':scale,'previous_scale':1.3483003377914429,'enlargement_percent':100*(1.3483003377914429/scale-1),'pivot_percent':percent/10,'union_height_percent':100*(ymax-ymin)/scale,'shift_x':cam.data.shift_x,'shift_y':cam.data.shift_y}
    s['framing_note']=json.dumps(report)
    s.frame_set(1);root.rotation_euler.z=0
    return report


def _passes_module():
    import importlib.util
    spec=importlib.util.spec_from_file_location('rainfall_passes',BASE/'tools/passes.py')
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
    return mod


def set_pose(anim,d,i):
    s=bpy.context.scene
    bpy.data.objects['Ardent_Root'].rotation_euler.z=math.radians(90-45*DIRS.index(d))
    s.frame_set((1 if anim=='idle' else 17)+i)
    bpy.context.view_layer.update()


def render_one(anim,d,i,kind='diffuse'):
    assert Path(bpy.data.filepath)==BLEND
    set_pose(anim,d,i);s=bpy.context.scene;p=_passes_module()
    suffix={'diffuse':'','normal':'_n','emission':'_e'}[kind]
    out=BASE/'renders/ardent'/(anim+suffix)/f'{d}_{i:02d}.png';out.parent.mkdir(parents=True,exist_ok=True)
    diffuse=BASE/'renders/ardent'/anim/out.name
    if kind=='normal':p.render_normal_pass(out,diffuse,s)
    elif kind=='emission':p.render_emission_pass(out,diffuse,s)
    else:s.render.filepath=str(out);bpy.ops.render.render(write_still=True)


def prepare_render():
    assert Path(bpy.data.filepath)==BLEND
    s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=16
    s.render.resolution_x=s.render.resolution_y=384;s.render.resolution_percentage=100
    s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.image_settings.color_depth='8'
    s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0;s.view_settings.gamma=1
    p=_passes_module()
    verification=p.validate_normal_convention(BASE/'renders/ardent/verification')
    framing=fit_union_camera();p.setup_diffuse_compositor(s)
    report={'normal_verification':verification,'framing':framing}
    (BASE/'renders/ardent/pass_report.json').write_text(json.dumps(report,indent=2))
    return report


def render_all():
    report=prepare_render()
    for kind in ['diffuse','normal','emission']:
        for anim in ['idle','run']:
            for d in DIRS:
                for i in range(8):render_one(anim,d,i,kind)
    s=bpy.context.scene;s.frame_set(1);bpy.data.objects['Ardent_Root'].rotation_euler.z=0
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    return report


if __name__=='__main__':
    bpy.ops.wm.open_mainfile(filepath=str(BLEND))
    render_all()



