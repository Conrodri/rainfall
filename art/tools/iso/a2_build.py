"""A2: extend the validated C4 source, render Eevee actions and physical fire.
Pillow only packs/crops/resizes; all visual content comes from Blender.
Existing VFX sheet dimensions are preserved; unused legacy columns stay clear.
"""
import sys, math, json, random, hashlib, re, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
sys.dont_write_bytecode=True
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/characters'),str(ROOT/'art/tools/monsters'),str(ROOT/'art/tools/bosses')]
if '--background' in sys.argv:sys.path[:0]=[str(HERE/'_deps'),str(Path.home()/'AppData/Local/RainfallIsoDeps')]
from PIL import Image
DIRS=['e','se','s','sw','w','nw','n','ne']
CHAR=ROOT/'game/assets/sprites/characters/ardent'
RAW=ROOT/'art/blender/characters/ardent_action_frames'
SPECS={'attack':(5,2,41),'cast':(6,2,61),'cast_ult':(8,4,81)}
F60={'attack':[4,4,2,4,4],'cast':[5,5,5,6,6,5],'cast_ult':[5,5,5,5,10,10,9,9]}
FX={'ardent_nova':(512,14,10,2.08),'ardent_ashes':(384,8,8,1.72),'ardent_brasier':(640,18,12,2.48)}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def inventory():
    p=HERE/'_a2_inventory.json'
    if not p.exists():
        data={}
        for d in [CHAR]+[ROOT/'game/assets/sprites/vfx'/k for k in FX]:
            data[str(d.relative_to(ROOT))]={f.name:{'sha256':sha(f),**({'size':list(Image.open(f).size)} if f.suffix=='.png' else {})} for f in d.iterdir() if f.suffix in ('.png','.tres')}
        p.write_text(json.dumps(data,indent=2))
    base=HERE/'_a2_baseline.json'
    if not base.exists():base.write_text(json.dumps({f.name:sha(f) for f in CHAR.iterdir() if f.name.startswith(('idle','run'))},indent=2))

def render_actions():
    import bpy, iso_rig, inspect
    sys.path.insert(0,str(ROOT/'art/tools/cel'))
    import cel_style as cel
    src=inspect.getsource(iso_rig.render_frame).replace("(('_e',) if not passes else ('_n','_e'))","('_e',)")
    exec(compile(src,inspect.getsourcefile(iso_rig.render_frame),'exec'),iso_rig.__dict__)
    cel.install('creature',normals=False)
    from mathutils import Vector
    from bpy_extras.object_utils import world_to_camera_view
    from ardent_iso_build import rings
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/ardent_iso.blend'))
    s=bpy.context.scene;s.frame_set(1)
    # Retain idle/run curves in the original source and key the new actions beyond them.
    root=bpy.data.objects['Ardent_Root'];body=bpy.data.objects['Torso']
    arm=next(o for o in body.children if o.get('side')==1)
    off=next(o for o in body.children if o.get('side')==-1)
    fore=next(o for o in arm.children if o.name.startswith('Forearm'))
    torch=bpy.data.objects['Torch']
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in root.children_recursive}
    fire=bpy.data.materials.get('Flame hot heart same orange')
    extra=[]
    for j in range(9):
        o=rings('A2 ultimate crawling sleeve flame',[(0,.018,.014,0),(.045,.032,.022,.01),(.12,.019,.012,-.016),(.23,.001,.001,.035)],fire,root,7)
        o.location=(.82*math.cos(j*math.tau/9),.82*math.sin(j*math.tau/9),.45+.20*math.sin(j*2.4))
        extra.append(o)
    ghost=[]
    for j in range(2):
        g=rings('A2 converging ghost',[(0,.018,.014,0),(.045,.032,.022,.01),(.12,.019,.012,-.016),(.23,.001,.001,.035)],fire,root,7)
        g.location=(.015,-.16-j*.035,.34+j*.16);ghost.append(g)
    cel.toon_materials('creature')
    accents=[(n.inputs['Color'],tuple(n.inputs['Color'].default_value)) for m in bpy.data.materials if m.use_nodes for n in m.node_tree.nodes if n.type=='OUTPUT_AOV' and max(n.inputs['Color'].default_value[:3])>0]
    for anim,(count,impact,start) in SPECS.items():
        s.timeline_markers.new('A2 '+anim+' impact '+str(impact),frame=start+impact)
        for i in range(count):
            f=start+i;s.frame_set(f)
            for socket,color in accents:
                boost=(2.5 if anim=='cast_ult' else 2) if i==impact else 1
                socket.default_value=tuple(c*boost for c in color[:3])+(1,)
                socket.keyframe_insert('default_value',frame=f)
            for o,(loc,rot,scale) in rest.items():o.location=loc;o.rotation_euler=rot;o.scale=scale
            if anim=='attack':
                # anticipation, draw, full extension at frame 2, recoil, settle
                ax=[-.22,-.48,-1.25,-.62,-.04][i]
                body.rotation_euler=(.02,.03,[-.10,-.22,.18,.09,0][i])
                arm.rotation_euler=(ax,[-.19,-.19,-1.15,-.30,0][i],[.04,.18,-.48,-.08,0][i])
                fore.rotation_euler.x=[-.05,-.12,-.25,-.12,0][i]
                torch.rotation_euler.x=[-.18,-.38,-1.18,-.60,0][i]
                off.rotation_euler.x=[.08,.22,.40,.18,0][i]
            elif anim=='cast':
                body.location.z += [-.15,-.20,.06,.02,-.04,0][i]
                body.rotation_euler.x=[-.24,-.32,-.14,-.08,.10,.035][i]
                arm.rotation_euler=([-.8,-1.15,0,-.20,-.15,0][i],[0,0,-1.55,-1.0,-.4,0][i],0)
                off.rotation_euler=([-.8,-1.15,0,-.20,-.15,0][i],[0,0,1.55,1.0,.4,0][i],0)
                fore.rotation_euler.x=[-1.0,-1.25,-.10,-.12,-.08,0][i]
            else:
                body.location.z += [-.12,-.08,-.03,.02,.12,.07,.02,0][i]
                body.rotation_euler.x=[-.15,-.10,-.06,-.08,-.20,-.15,-.08,.035][i]
                lift=[-.35,-.65,-1.0,-1.3,-2.15,-1.4,-.65,0][i]
                arm.rotation_euler=(lift,[0,-.1,-.2,-.3,-.95,-.55,-.2,0][i],0)
                off.rotation_euler=(lift,[0,.1,.2,.3,.95,.55,.2,0][i],0)
                fore.rotation_euler.x=[-.1,-.2,-.3,-.3,-.10,-.12,-.06,0][i]
            torch.scale*=.62
            if anim=='attack' and i==1:body.scale*=.94
            if anim=='cast_ult' and i==impact:
                arm.rotation_euler=(-.10,-2.15,0);off.rotation_euler=(-.10,2.15,0)
                torch.scale*=.4
            if i==impact:
                body.scale.x*=1.12;body.scale.y*=1.12
            # Keep the hand-held staff oriented in world space, compensating its
            # shoulder/elbow parents. Pose limits keep C4's fixed 192px framing.
            target=([-.22,-.35,.92,.20,0][i] if anim=='attack' else [.15,.40,.65,.25,.02,0][i] if anim=='cast' else [.1,.25,.40,.55,.85,.50,.15,0][i])
            arm.rotation_euler.x=max(-2.25,arm.rotation_euler.x)
            fore.rotation_euler.x=max(-.40,fore.rotation_euler.x)
            def orient_staff():
                torch.rotation_euler.x=target-arm.rotation_euler.x-fore.rotation_euler.x-body.rotation_euler.x
                torch.rotation_euler.y=-arm.rotation_euler.y-body.rotation_euler.y
            def projected_bounds():
                coords=[]
                for angle in iso_rig.DIRECTIONS.values():
                    root.rotation_euler.z=angle;bpy.context.view_layer.update()
                    for ob in root.children_recursive:
                        if ob.type!='MESH' or ob in extra:continue
                        for corner in ob.bound_box:
                            q=world_to_camera_view(s,s.camera,ob.matrix_world@Vector(corner));coords.append((q.x*192,(1-q.y)*192))
                return min(v[0] for v in coords),min(v[1] for v in coords),max(v[0] for v in coords),max(v[1] for v in coords)
            orient_staff();bb=projected_bounds()
            for attempt in range(60):
                if bb[0]<7 or bb[2]>185 or bb[3]-bb[1]>174:
                    torch.scale*=.90
                    if attempt>15:body.scale*=.98
                elif bb[1]<9:body.location.z-=(9-bb[1])/(iso_rig.R*math.cos(math.pi/6))
                elif bb[3]>184:body.location.z+=(bb[3]-184)/(iso_rig.R*math.cos(math.pi/6))
                else:break
                bb=projected_bounds()
            assert bb[0]>=6 and bb[1]>=7 and bb[2]<=186 and bb[3]<=186,(anim,i,bb)
            root.rotation_euler.z=0
            for g in ghost:
                g.scale=(.001,.001,.001)
            if (anim=='cast_ult' and i in (1,2,3)) or (anim=='cast' and i==1):
                amt={1:.75,2:1.1,3:1.4}[i]
                for j,g in enumerate(ghost):g.scale=(amt,amt,amt);g.location.x=(-1 if j==0 else 1)*(.65-.12*i)
            for j,o in enumerate(extra):
                radius=.82 if i==impact else .25
                o.location=(radius*math.cos(j*math.tau/9),radius*math.sin(j*math.tau/9),.45+.20*math.sin(j*2.4))
                amount=([.001,.001,.001,.001,2.5,1.6,.55,.08][i] if anim=='cast_ult' else [0,.001,2,.18,.04,.001][i] if anim=='cast' else (.8 if i==impact else .001))
                o.scale=(amount,amount,amount*(.8+.3*math.sin(i+j)))
            for j,o in enumerate(root.children_recursive):
                if o.name.startswith('Living flame tongue'):
                    strength=.90+.07*math.sin(i*2+j)
                    o.scale=(1,1,strength)
                if o.name.startswith('Coat panel hinge'):
                    coat=[-.12,-.20,.32,.20,.10,0][i] if anim=='cast' else [-.05,-.10,-.15,-.20,.32,.20,.10,0][i] if anim=='cast_ult' else [.04,.15,.32,.12,0][i]
                    o.rotation_euler.x=coat*(.65+.35*math.sin(j*1.7))
                    o.scale.z=1.25 if anim=='cast' and i==impact else 1.0
                if o.type in ('EMPTY','MESH'):
                    for prop in ('location','rotation_euler','scale'):o.keyframe_insert(prop,frame=f)
    s.frame_end=88;s['A2_action_contract']=json.dumps(SPECS);s.eevee.taa_render_samples=8
    s.render.threads_mode='FIXED';s.render.threads=8
    bpy.context.preferences.filepaths.save_version=0
    s.frame_set(41);root.rotation_euler.z=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/characters/ardent_a2.blend'))
    if '--build-only' in sys.argv:return
    for anim,(count,impact,start) in SPECS.items():
        for d,angle in iso_rig.DIRECTIONS.items():
            for i in range(count):
                if '--refine' in sys.argv and not ((anim=='attack' and i==1) or i==impact):continue
                p=RAW/anim/(d+'_%02d.png'%i)
                if '--force-actions' not in sys.argv and p.exists() and p.with_name(p.stem+'_e.png').exists():continue
                s.frame_set(start+i);root.rotation_euler.z=angle
                iso_rig.render_frame(p,passes=True)
            print('A2 ACTION '+anim+' '+d,flush=True)

def fire_material(name,color,strength,smoke=False):
    import bpy
    m=bpy.data.materials.new(name);m.use_nodes=True
    n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.92
    p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=(.75 if strength else 0)
    noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=7 if smoke else 18;noise.inputs['Detail'].default_value=4
    ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.22;ramp.color_ramp.elements[0].color=(.007,.003,.002,1)
    ramp.color_ramp.elements[1].position=.73;ramp.color_ramp.elements[1].color=(*color,1)
    if strength and 'charcoal' not in name:
        ramp.color_ramp.elements[0].position=.16;ramp.color_ramp.elements[0].color=(.022,.001,.0002,1)
        ramp.color_ramp.elements[1].position=.87;ramp.color_ramp.elements[1].color=(1,.64,.20,1) if 'core' in name else (1,.22,.014,1)
        middle=ramp.color_ramp.elements.new(.48);middle.color=(.28,.018,.001,1)
        middle=ramp.color_ramp.elements.new(.67);middle.color=(.95,.13,.006,1)
    l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color'])
    if strength:l.new(ramp.outputs[0],p.inputs['Emission Color'])
    bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.6;bump.inputs['Distance'].default_value=.045
    l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
    if smoke or (strength and 'charcoal' not in name):
        # Fractal, eroded smoke wisps rather than opaque round particles.
        tr=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader');out=n.get('Material Output')
        opacity=n.new('ShaderNodeValToRGB');opacity.color_ramp.elements[0].position=.25;opacity.color_ramp.elements[0].color=(.015,.015,.015,1)
        opacity.color_ramp.elements[1].position=.8;opacity.color_ramp.elements[1].color=((.42,.42,.42,1) if smoke else (.82,.82,.82,1))
        l.new(noise.outputs['Fac'],opacity.inputs[0]);l.new(opacity.outputs[0],mix.inputs[0]);l.new(tr.outputs[0],mix.inputs[1]);l.new(p.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs[0])
        m.surface_render_method='DITHERED'
    if strength:
        m['rainfall_emissive']=True
        p.inputs['Emission Strength'].default_value=.85
    return m

def tongue(name,x,y,height,width,phase,mat,seed):
    import bpy
    rng=random.Random(seed);verts=[];faces=[];sides=7;levels=8
    for k in range(levels):
        t=k/(levels-1);radius=width*(math.sin(math.pi*(t*.85+.12))**.65)*(1-t)**.65+.0004
        cx=x+width*1.3*math.sin(t*7+phase)*t;cy=y+width*.6*math.cos(t*9+phase)*t
        for j in range(sides):
            a=j*math.tau/sides;r=radius*rng.uniform(.65,1.22)
            verts.append((cx+math.cos(a)*r,cy+math.sin(a)*r,height*t))
    for k in range(levels-1):
        for j in range(sides):faces.append((k*sides+j,k*sides+(j+1)%sides,(k+1)*sides+(j+1)%sides,(k+1)*sides+j))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(mat)
    o=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(o)
    for p in mesh.polygons:p.use_smooth=True
    return o

def particles_mesh(name,points,mat):
    import bpy
    verts=[];faces=[]
    for x,y,z,r,h in points:
        k=len(verts);verts.extend([(x-r,y,z),(x,y-r,z),(x+r,y,z),(x,y+r,z),(x+r*.4,y,z+h),(x,y+r*.4,z+h)])
        faces.extend([(k,k+1,k+4),(k+1,k+2,k+4),(k+2,k+3,k+5,k+4),(k+3,k,k+4,k+5)])
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.materials.append(mat)
    ob=bpy.data.objects.new(name,me);bpy.context.scene.collection.objects.link(ob);return ob

def jagged_wall(name,radius,env,mat,phase,seed):
    """Broken annular curtain with tall teeth, projected on the established bed radius."""
    import bpy
    rng=random.Random(seed);n=112;levels=9;verts=[];faces=[]
    for k in range(levels):
        z=k/(levels-1)
        for j in range(n):
            a=j*math.tau/n
            teeth=(.08+.92*max(0,math.sin(j*.43+phase))**3) if k else .92+rng.random()*.16
            rr=radius*(.83+.09*math.sin(j*.19+phase)+rng.uniform(-.025,.025))
            zz=(z*(.45+2.1*teeth) if k else .025)*env
            verts.append((rr*math.cos(a),rr*math.sin(a),zz))
    for k in range(levels-1):
        for j in range(n):
            if rng.random()>.035: faces.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.materials.append(mat)
    ob=bpy.data.objects.new(name,me);bpy.context.scene.collection.objects.link(ob)
    for p in me.polygons:p.use_smooth=True
    return ob

def cracked_bed(radius,env,coal,hot,kind):
    import bpy
    rng=random.Random(871);verts=[];faces=[];indices=[]
    step=radius/5;grid={}
    for x in range(-6,7):
        for y in range(-6,7):grid[x,y]=((x+rng.uniform(-.27,.27))*step,(y+rng.uniform(-.27,.27))*step)
    for x in range(-5,5):
        for y in range(-5,5):
            corners=[grid[x,y],grid[x+1,y],grid[x+1,y+1],grid[x,y+1]]
            cx=sum(v[0] for v in corners)/4;cy=sum(v[1] for v in corners)/4
            boundary=radius*(.91+.065*math.sin(math.atan2(cy,cx)*7)+.02*math.cos(x*3+y))
            if any(math.hypot(a,b)>boundary for a,b in corners):continue
            z=rng.uniform(.018,.065)
            k=len(verts)
            verts.extend([(a,b,.009) for a,b in corners]);faces.append(tuple(range(k,k+4)));indices.append(1)
            k=len(verts)
            verts.extend([(cx+(a-cx)*.86,cy+(b-cy)*.86,z+rng.uniform(-.008,.008)) for a,b in corners])
            faces.append(tuple(range(k,k+4)));indices.append(0)
            for j in range(4):
                a=verts[k+j];b=verts[k+(j+1)%4];v=len(verts)
                verts.extend([a,b,(b[0],b[1],.01),(a[0],a[1],.01)])
                faces.append(tuple(range(v,v+4)));indices.append(0)
    me=bpy.data.meshes.new('Organic cracked cinder crust');me.from_pydata(verts,[],faces)
    me.materials.append(coal);me.materials.append(hot)
    for poly,idx in zip(me.polygons,indices):poly.material_index=idx
    ob=bpy.data.objects.new('Organic cracked cinder crust',me);bpy.context.scene.collection.objects.link(ob)
    ob.scale=(1,1,max(.01,env))
    if env==0:ob.hide_render=True
    return [ob]

def render_vfx():
    import bpy, iso_rig, inspect
    sys.path.insert(0,str(ROOT/'art/tools/cel'))
    import cel_style as cel
    src=inspect.getsource(iso_rig.render_frame).replace("(('_e',) if not passes else ('_n','_e'))","('_e',)")
    exec(compile(src,inspect.getsourcefile(iso_rig.render_frame),'exec'),iso_rig.__dict__)
    cel.install('vfx',normals=False)
    for kind,(size,slots,count,radius) in FX.items():
        s=iso_rig.create_rig('CREA',size);s.eevee.taa_render_samples=8
        s.render.threads_mode='FIXED';s.render.threads=8
        hot=fire_material('V2 orange white core',(1,.27,.035),2.0)
        flame=fire_material('Torch orange combustion',(1,.085,.006),1.5)
        coal=fire_material('V2 porous glowing charcoal',(.26,.022,.003),.8)
        smoke=fire_material('Soot and turbulent smoke',(.09,.078,.065),0,True)
        objects=[]
        total=count+(4 if kind=='ardent_ashes' else 0)
        for f in range(total):
            label='end' if f>=count else 'default';i=f-count if f>=count else f
            p=ROOT/'art/blender/vfx/ardent_spell_frames'/kind/label/('%02d.png'%i)
            for o in objects:bpy.data.objects.remove(o,do_unlink=True)
            objects=[];rng=random.Random(1205+f*73);t=i/max(1,count-1)
            if kind=='ardent_ashes':
                decay=(1-(i+1)/4)**1.2 if label=='end' else 1
                env=.7*decay;r=radius
            else:
                env=math.sin(math.pi*(.055+.91*t))**.8
                env=(1-t)**1.15*.96+.04 if kind in ('ardent_nova','ardent_brasier') else env
                r=radius*.88
            # Broad, irregular bed of fractured embers. Circular world footprint projects 2:1.
            pts=[]
            for j in range(470 if kind=='ardent_ashes' else 330):
                a=rng.random()*math.tau
                rr=r*(math.sqrt(rng.random()) if kind=='ardent_ashes' else math.sqrt(rng.random()))
                pts.append((math.cos(a)*rr,math.sin(a)*rr,.008,rng.uniform(.012,.04)*max(.1,env),rng.uniform(.01,.04)*max(.1,env)))
            if kind=='ardent_ashes':
                # Uneven polygonal crust, with dark gaps opening into glowing fissures.
                for j in range(58):
                    a=j*math.tau/58+rng.uniform(-.035,.035);rr=radius*math.sqrt(rng.uniform(.035,.98))
                    pts.append((math.cos(a)*rr,math.sin(a)*rr,.012,rng.uniform(.018,.052),rng.uniform(.025,.08)))
            objects.append(particles_mesh('Fractured incandescent coal bed',pts,coal))
            if kind!='ardent_nova': objects.extend(cracked_bed(radius,env,coal,hot,kind))
            if kind=='ardent_brasier':
                objects.append(jagged_wall('Rising broken ring of fire',radius,env,flame,t*6, f+902))
            n=52 if kind=='ardent_nova' else (46 if kind=='ardent_ashes' else 28)
            for j in range(n):
                a=j*math.tau/n+rng.uniform(-.065,.065)
                rr=(r*rng.uniform(.15,1) if kind=='ardent_nova' else r*(rng.uniform(.82,1) if kind=='ardent_brasier' else math.sqrt(rng.uniform(.02,1))))
                x,y=rr*math.cos(a),rr*math.sin(a)
                h=(rng.uniform(.95,2.35) if kind=='ardent_nova' else rng.uniform(.18,.52) if kind=='ardent_ashes' else rng.uniform(1.55,3.4))*env
                w=rng.uniform(.065,.15) if kind!='ardent_brasier' else rng.uniform(.065,.16)
                phase=f*1.7+j*2.3
                outer=tongue('Turbulent rising combustion',x,y,h,w,phase,flame,j*17+f)
                inner=tongue('Incandescent torn inner core',x,y,h*.69,w*.49,phase,hot,j*17+f)
                if kind=='ardent_nova':
                    for ob in (outer,inner):
                        for v in ob.data.vertices:
                            q=v.co.z/max(h,.001);v.co.x+=math.cos(a)*q*.62*env;v.co.y+=math.sin(a)*q*.62*env
                objects.extend([outer,inner])
            # Wind-sheared smoke columns use irregular meshes and fractal transparency.
            for j in range(17 if kind!='ardent_ashes' else 11):
                a=rng.random()*math.tau;rr=r*math.sqrt(rng.random());x,y=math.cos(a)*rr,math.sin(a)*rr
                h=rng.uniform(.4,1.0) if kind!='ardent_brasier' else rng.uniform(1.5,2.9)
                o=tongue('Eroded soot plume',x,y,h*max(.2,env),rng.uniform(.08,.23),f+j,smoke,j+f*20)
                o.location.z=.1;objects.append(o)
            sparks=[]
            for j in range(120 if kind=='ardent_brasier' else 65):
                a=rng.random()*math.tau;rr=r*rng.uniform(.12,.94);z=rng.uniform(.04,1.65 if kind!='ardent_brasier' else 3.5)*env
                sparks.append((math.cos(a)*rr,math.sin(a)*rr,z,rng.uniform(.004,.012)*max(.12,env),rng.uniform(.02,.11)*env))
            objects.append(particles_mesh('Ballistic sparks and drifting embers',sparks,hot))
            from bpy_extras.object_utils import world_to_camera_view
            for ob in objects:
                for v in ob.data.vertices:
                    q=ob.matrix_world @ v.co
                    top=(1-world_to_camera_view(s,s.camera,q).y)*size
                    if top<8:v.co.z-=(8-top)/(iso_rig.R*math.cos(math.pi/6))
            # Key the actual generated geometry for a fully reproducible animated source.
            frame=f+1
            for o in objects:
                for at,hidden in [(max(0,frame-1),True),(frame,False),(frame+1,True)]:
                    o.hide_render=(hidden or (kind=='ardent_ashes' and label=='end' and i==3));o.keyframe_insert('hide_render',frame=at)
            s.frame_set(frame)
            # Retain all frame geometry in the blend, but remove its Python deletion list.
            if f==0:source_objects=[]
            source_objects.extend(objects)
            cel.toon_materials('vfx')
            for mat in (hot,flame,coal):
                for node in mat.node_tree.nodes:
                    if node.type=='EMISSION':
                        node.inputs['Strength'].default_value=.85*env
                        node.inputs['Strength'].keyframe_insert('default_value',frame=frame)
                        glow=tuple(node.inputs['Color'].default_value)
                for node in mat.node_tree.nodes:
                    if node.type=='OUTPUT_AOV':
                        node.inputs['Color'].default_value=tuple(c*.85*env for c in glow[:3])+(1,)
                        node.inputs['Color'].keyframe_insert('default_value',frame=frame)
            iso_rig.render_frame(p,passes=True)
            objects=[]

        s.frame_start=1;s.frame_end=total;s['A2_floor_radius_u']=radius;s['A2_floor_aspect']=.5
        s['A2_active_frames']=count;s['A2_preserved_atlas_columns']=slots
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/vfx'/('a2_'+kind+'.blend')))

def resource_actions():
    p=CHAR/'ardent.tres';text=p.read_text()
    def retime(m):
        block=m.group(0)
        name=re.search(r'"name": &"([^" ]+)"',block)
        if not name:return block
        anim=next((a for a in SPECS if name[1] in [a+'_'+d for d in DIRS]),None)
        if not anim:return block
        durations=iter(F60[anim]);speed=11 if anim=='cast_ult' else 12
        return re.sub(r'"duration": [0-9.]+',lambda _: '"duration": '+str(next(durations)*speed/60),block)
    text=re.sub(r'\{\s*"frames": \[.*?"speed": [0-9.]+\s*\}',retime,text,flags=re.S)
    assert 'CanvasTexture' not in text and 'normal_texture' not in text
    p.write_text(text)

def resource_fx(kind,count,ending=False):
    folder=ROOT/'game/assets/sprites/vfx'/kind;p=folder/(kind+'.tres');text=p.read_text()
    if kind=='ardent_ashes' and '"end"' in text:return
    # Keep all existing frame subresources; change the active list only where required.
    line='"frames": ['+', '.join('{"duration": 1.0, "texture": SubResource("a'+str(i+1)+'")}' for i in range(count))+'],'
    text=re.sub(r'"frames": \[[^\n]*\],',lambda m:line,text,count=1)
    if ending:
        at=text.index('[sub_resource');text=text[:at]+'[ext_resource type="Texture2D" path="res://assets/sprites/vfx/ardent_ashes/end.png" id="a2_end"]\n\n'+text[at:]
        parts=[]
        for i in range(4):parts.append('[sub_resource type="AtlasTexture" id="a2_end_'+str(i)+'"]\natlas = ExtResource("a2_end")\nregion = Rect2('+str(i*384)+', 0, 384, 384)\n')
        at=text.index('[resource]');text=text[:at]+'\n'.join(parts)+'\n'+text[at:]
        anim='{\n"frames": ['+', '.join('{"duration": 1.0, "texture": SubResource("a2_end_'+str(i)+'")}' for i in range(4))+'],\n"loop": false,\n"name": &"end",\n"speed": 10.0\n}'
        at=text.rfind('}]');text=text[:at+1]+', '+anim+text[at+1:]
        text=re.sub(r'load_steps=(\d+)',lambda m:'load_steps='+str(int(m[1])+5),text,count=1)
    p.write_text(text)

def pack():
    import numpy as np
    for anim,(count,impact,start) in SPECS.items():
        sheets={su:Image.new('RGBA',(count*192,1536)) for su in ('','_e')}
        for row,d in enumerate(DIRS):
            for i in range(count):
                for su,atlas in sheets.items():
                    im=Image.open(RAW/anim/(d+'_%02d'%i+su+'.png')).convert('RGBA')
                    atlas.paste(im,(i*192,row*192))
        for su,atlas in sheets.items():
            if su=='_e':
                arr=np.asarray(atlas);atlas=Image.fromarray(arr.reshape(arr.shape[0]//2,2,arr.shape[1]//2,2,4).max(axis=(1,3)))
            atlas.save(CHAR/(anim+su+'.png'),optimize=True,compress_level=9)
    # Palette optimization preserves cel flats and the mobile texture budget.
    import subprocess
    optimizer=ROOT/'art/blender/characters/ardent_pngquant/pngquant/pngquant.exe'
    target=CHAR/'cast_ult.png'
    if target.stat().st_size+(CHAR/'cast_ult_e.png').stat().st_size>742903*1.3:
        subprocess.run([str(optimizer),'--quality=85-100','--speed','1','--force','--ext','.png',str(target)],check=True,capture_output=True)
    resource_actions()
    print('A2 PACK PASS',flush=True)

def contact_verify():
    import numpy as np
    canvas=Image.new('RGBA',(9*112,3*112),(26,28,31,255))
    idle=Image.open(CHAR/'idle.png').convert('RGBA')
    for row,(anim,(count,impact,start)) in enumerate(SPECS.items()):
        im=Image.open(CHAR/(anim+'.png')).convert('RGBA');em=Image.open(CHAR/(anim+'_e.png')).convert('RGBA')
        assert im.size==(count*192,1536) and em.size==(count*96,768)
        assert max(em.getextrema()[c][1] for c in range(3))>0
        for d in range(8):
            cells=[im.crop((i*192,d*192,(i+1)*192,(d+1)*192)) for i in range(count)]
            assert len({sha256.tobytes() for sha256 in cells})==count
            boxes=[c.getchannel('A').getbbox() for c in cells]
            assert all(b and b[0]>0 and b[1]>0 and b[2]<192 and b[3]<192 for b in boxes),(anim,d,boxes)
            areas=[(b[2]-b[0])*(b[3]-b[1]) for b in boxes]
            assert areas[impact]==max(areas),(anim,d,areas)
            assert all(np.ptp(np.asarray(c)[:,:,:3][np.asarray(c)[:,:,3]>128])>40 for c in cells)
            assert all(np.asarray(c)[:,:,3].min()==0 for c in cells)
        budget={'attack':854075,'cast':1013453,'cast_ult':742903}
        assert sum((CHAR/(anim+su+'.png')).stat().st_size for su in ('','_e'))<=budget[anim]*1.3
        assert not (CHAR/(anim+'_n.png')).exists()
        canvas.alpha_composite(idle.crop((0,192,192,384)).resize((112,112)),(0,row*112))
        for f in range(count):canvas.alpha_composite(im.crop((f*192,192,(f+1)*192,384)).resize((112,112)),((f+1)*112,row*112))
    canvas.save(ROOT/'art/blender/characters/ardent_actions_contact.png')
    print('PASS 5/6/8 frames; 8 directions; 192; alpha; distinct; contrast; largest impact 2/2/4; half emission; budget')

def measure():
    import bpy
    from mathutils import Vector
    from bpy_extras.object_utils import world_to_camera_view
    data={}
    for kind,(size,slots,count,radius) in FX.items():
        bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/vfx'/('a2_'+kind+'.blend')))
        import iso_rig
        s=bpy.context.scene;frames=[];repaired=[]
        # Constrain only stray high particles to the existing frame margins.
        if kind=='ardent_brasier':
            for f in range(1,count+1):
                s.frame_set(f);bpy.context.view_layer.update();changed=False
                for o in s.objects:
                    if o.type!='MESH' or o.hide_render:continue
                    for v in o.data.vertices:
                        q=o.matrix_world@v.co;p=world_to_camera_view(s,s.camera,q)
                        if (1-p.y)*size<7.9:
                            q.z-= (8-(1-p.y)*size)/(90.50966799187809*math.cos(math.pi/6))
                            v.co=o.matrix_world.inverted()@q;changed=True
                if changed:
                    iso_rig.render_frame(RAW/kind/'default'/('%02d.png'%(f-1)),passes=False);repaired.append(f-1)
        if kind=='ardent_ashes':
            # The final extinction frame must leave no residual smoke or coals.
            s.frame_set(count+4)
            for o in s.objects:
                if o.type=='MESH':o.hide_render=True;o.keyframe_insert('hide_render',frame=count+4)
            iso_rig.render_frame(RAW/kind/'end'/'03.png',passes=False)
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/vfx'/('a2_'+kind+'.blend')))
        for f in range(1,count+1):
            s.frame_set(f);bpy.context.view_layer.update();xy=[]
            for o in s.objects:
                if o.type!='MESH' or o.hide_render or not o.name.startswith('Fractured incandescent'):continue
                for v in o.data.vertices:
                    q=o.matrix_world@v.co;q.z=0
                    p=world_to_camera_view(s,s.camera,q);xy.append((p.x*size,(1-p.y)*size))
            if xy:
                xs,ys=zip(*xy);frames.append((max(xs)-min(xs),max(ys)-min(ys),f))
        w,h,f=max(frames)
        data[kind]={'radius_px':round(w/2,2),'floor_aspect':round(h/w,4),'measurement':'projected z=0 incandescent bed mesh bounding box','measured_frame_0_index':f-1}
    (HERE/'_a2_geometry.json').write_text(json.dumps(data,indent=2));print('A2 MEASUREMENT PASS '+json.dumps(data))

if __name__=='__main__':
    # Action-only: preserve unrelated inventories.
    if '--measure' in sys.argv:measure()
    elif '--finish' in sys.argv:pack();contact_verify()
    elif '--verify' in sys.argv:contact_verify()
    else:
        if '--vfx-only' not in sys.argv:render_actions()
        if '--build-only' in sys.argv:sys.exit()
        if '--actions-only' not in sys.argv:render_vfx()
        pack();contact_verify()
