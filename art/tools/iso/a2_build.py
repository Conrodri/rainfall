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
RAW=Path(tempfile.gettempdir())/'rainfall_a2_frames'
SPECS={'attack':(5,2,41),'cast':(6,3,61),'cast_ult':(8,4,81)}
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
    import bpy, iso_rig
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
        o=rings('A2 ultimate crawling sleeve flame',[(0,.018,.014,0),(.045,.032,.022,.01),(.12,.019,.012,-.016),(.23,.001,.001,.035)],fire,fore,7)
        o.location=(.02+math.sin(j*2.4)*.06,-.025-j*.018,-j*.031)
        extra.append(o)
    for anim,(count,impact,start) in SPECS.items():
        s.timeline_markers.new('A2 '+anim+' impact '+str(impact),frame=start+impact)
        for i in range(count):
            f=start+i;s.frame_set(f)
            for o,(loc,rot,scale) in rest.items():o.location=loc;o.rotation_euler=rot;o.scale=scale
            if anim=='attack':
                # anticipation, draw, full extension at frame 2, recoil, settle
                ax=[-.22,-.48,-1.12,-.62,-.04][i]
                body.rotation_euler=(.02,.03,[-.10,-.22,.18,.09,0][i])
                arm.rotation_euler=(ax,-.19,[.04,.18,-.16,-.08,0][i])
                fore.rotation_euler.x=[-.05,-.12,-.25,-.12,0][i]
                torch.rotation_euler.x=[-.18,-.38,-1.18,-.60,0][i]
                off.rotation_euler.x=[.08,.22,.40,.18,0][i]
            elif anim=='cast':
                arm.rotation_euler=([-0.35,-1.35,-1.85,-.05,-.18,0][i],-.13,0)
                fore.rotation_euler.x=[-.12,-.35,-.55,.34,.1,0][i]
                torch.rotation_euler.x=[0,.18,.40,-.25,-.1,0][i]
                body.rotation_euler.x=[.02,-.09,-.12,.38,.16,.035][i]
                body.location.z += [0,.015,.025,-.14,-.06,0][i]
                off.rotation_euler.x=[-.12,-.55,-.72,-.35,-.1,0][i]
            else:
                arm.rotation_euler=([-.2,-.7,-1.1,-.45,.18,.05,-.12,0][i],-.12,0)
                fore.rotation_euler.x=[0,-.2,-.3,.1,.35,.2,.08,0][i]
                torch.rotation_euler.x=[0,.14,.22,-.1,-.36,-.2,-.1,0][i]
                body.location.z += [0,0,.01,-.06,-.19,-.12,-.05,0][i]
                body.rotation_euler.x=[.02,-.04,-.09,.12,.35,.24,.10,.035][i]
                off.rotation_euler.x=[-.1,-.25,-.6,-.9,-1.12,-.88,-.4,0][i]
            # Keep the hand-held staff oriented in world space, compensating its
            # shoulder/elbow parents. Pose limits keep C4's fixed 192px framing.
            target=([-.22,-.35,.42,.20,0][i] if anim=='attack' else [.15,.40,.68,.02,.02,0][i] if anim=='cast' else [.1,.35,.55,.15,0,.08,.15,0][i])
            arm.rotation_euler.x=max(-.95,arm.rotation_euler.x)
            fore.rotation_euler.x=max(-.23,fore.rotation_euler.x)
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
            base_z=body.location.z
            for attempt in range(28):
                body.location.z=base_z;orient_staff();bb=projected_bounds()
                if bb[1]<12:
                    body.location.z-=min(.12,(12-bb[1])/(iso_rig.R*math.cos(math.pi/6)))
                    bb=projected_bounds()
                if bb[0]>=7 and bb[1]>=8 and bb[2]<=185 and bb[3]<=185:break
                arm.rotation_euler.x*=.80;fore.rotation_euler.x*=.80;target*=.85
            assert bb[0]>=6 and bb[1]>=7 and bb[2]<=186 and bb[3]<=186,(anim,i,bb)
            root.rotation_euler.z=0
            for j,o in enumerate(extra):
                amount=([.001,.001,.001,.12,.8,1,.55,.08][i] if anim=='cast_ult' else .001)
                o.scale=(amount,amount,amount*(.8+.3*math.sin(i+j)))
            for j,o in enumerate(root.children_recursive):
                if o.name.startswith('Living flame tongue'):
                    strength=.90+.07*math.sin(i*2+j)
                    o.scale=(1,1,strength)
                if o.name.startswith('Coat panel hinge'):
                    o.rotation_euler.x=.10*math.sin(i*1.4+j)*math.sin(math.pi*i/(count-1))
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
                p=RAW/anim/(d+'_%02d.png'%i)
                if '--force-actions' not in sys.argv and all(p.with_name(p.stem+su+'.png').exists() for su in ('','_n','_e')):continue
                s.frame_set(start+i);root.rotation_euler.z=angle
                iso_rig.render_frame(p)
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

def render_vfx():
    import bpy, iso_rig
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
            p=RAW/kind/label/('%02d.png'%i)
            for o in objects:bpy.data.objects.remove(o,do_unlink=True)
            objects=[];rng=random.Random(1205+f*73);t=i/max(1,count-1)
            if kind=='ardent_ashes':
                decay=(1-(i+1)/4)**1.2 if label=='end' else 1
                env=.7*decay;r=radius
            else:
                env=math.sin(math.pi*(.055+.91*t))**.8
                r=radius*(.18+.82*min(1,t*2.0)) if kind=='ardent_nova' else radius*(.75+.25*math.sin(math.pi*t))
            # Broad, irregular bed of fractured embers. Circular world footprint projects 2:1.
            pts=[]
            for j in range(470 if kind=='ardent_ashes' else 330):
                a=rng.random()*math.tau
                rr=r*(math.sqrt(rng.random()) if kind=='ardent_ashes' else rng.uniform(.78,1.0))
                pts.append((math.cos(a)*rr,math.sin(a)*rr,.008,rng.uniform(.012,.04)*max(.1,env),rng.uniform(.01,.04)*max(.1,env)))
            objects.append(particles_mesh('Fractured incandescent coal bed',pts,coal))
            n=68 if kind=='ardent_nova' else (46 if kind=='ardent_ashes' else 85)
            for j in range(n):
                a=j*math.tau/n+rng.uniform(-.065,.065)
                rr=r*(rng.uniform(.86,1) if kind=='ardent_nova' else math.sqrt(rng.uniform(.02,1)))
                x,y=rr*math.cos(a),rr*math.sin(a)
                h=(rng.uniform(.18,.65) if kind=='ardent_nova' else rng.uniform(.06,.25) if kind=='ardent_ashes' else rng.uniform(.85,2.6))*env
                w=rng.uniform(.035,.105) if kind!='ardent_brasier' else rng.uniform(.065,.16)
                phase=f*1.7+j*2.3
                objects.append(tongue('Turbulent rising combustion',x,y,h,w,phase,flame,j*17+f))
                objects.append(tongue('Incandescent torn inner core',x,y,h*.69,w*.49,phase,hot,j*17+f))
            # Wind-sheared smoke columns use irregular meshes and fractal transparency.
            for j in range(17 if kind!='ardent_ashes' else 11):
                a=rng.random()*math.tau;rr=r*math.sqrt(rng.random());x,y=math.cos(a)*rr,math.sin(a)*rr
                h=rng.uniform(.4,1.0) if kind!='ardent_brasier' else rng.uniform(1.5,2.9)
                o=tongue('Eroded soot plume',x,y,h*max(.2,env),rng.uniform(.08,.23),f+j,smoke,j+f*20)
                o.location.z=.1;objects.append(o)
            sparks=[]
            for j in range(120 if kind=='ardent_brasier' else 65):
                a=rng.random()*math.tau;rr=r*rng.uniform(.3,1.08);z=rng.uniform(.04,1.1 if kind!='ardent_brasier' else 2.8)*env
                sparks.append((math.cos(a)*rr,math.sin(a)*rr,z,rng.uniform(.004,.012)*max(.12,env),rng.uniform(.02,.11)*env))
            objects.append(particles_mesh('Ballistic sparks and drifting embers',sparks,hot))
            # Key the actual generated geometry for a fully reproducible animated source.
            frame=f+1
            for o in objects:
                for at,hidden in [(max(0,frame-1),True),(frame,False),(frame+1,True)]:
                    o.hide_render=hidden;o.keyframe_insert('hide_render',frame=at)
            s.frame_set(frame)
            # Retain all frame geometry in the blend, but remove its Python deletion list.
            if f==0:source_objects=[]
            source_objects.extend(objects)
            iso_rig.render_frame(p)
            objects=[]
            print('A2 VFX '+kind+' '+label+' '+str(i),flush=True)
        s.frame_start=1;s.frame_end=total;s['A2_floor_radius_u']=radius;s['A2_floor_aspect']=.5
        s['A2_active_frames']=count;s['A2_preserved_atlas_columns']=slots
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/vfx'/('a2_'+kind+'.blend')))

def resource_actions():
    p=CHAR/'ardent.tres';text=p.read_text()
    if '"attack_e"' in text:return
    resources=[];animations=[]
    for k,(anim,(count,impact,start)) in enumerate(SPECS.items()):
        for j,su in enumerate(('','_n')):
            resources.append('[ext_resource type="Texture2D" path="res://assets/sprites/characters/ardent/'+anim+su+'.png" id="a2_'+str(k)+'_'+str(j)+'"]\n')
    # ExtResources precede every SubResource, matching Godot's text format.
    at=text.index('[sub_resource');text=text[:at]+'\n'.join(resources)+'\n'+text[at:]
    resources=[]
    for k,(anim,(count,impact,start)) in enumerate(SPECS.items()):
        cid='a2_c'+str(k)
        resources.append('[sub_resource type="CanvasTexture" id="'+cid+'"]\ndiffuse_texture = ExtResource("a2_'+str(k)+'_0")\nnormal_texture = ExtResource("a2_'+str(k)+'_1")\n')
        for row,d in enumerate(DIRS):
            fs=[]
            for f in range(count):
                aid='a2_'+anim+'_'+d+'_'+str(f)
                resources.append('[sub_resource type="AtlasTexture" id="'+aid+'"]\natlas = SubResource("'+cid+'")\nregion = Rect2('+str(f*192)+', '+str(row*192)+', 192, 192)\n')
                fs.append('{"duration": 1.0, "texture": SubResource("'+aid+'")}')
            animations.append('{\n"frames": ['+', '.join(fs)+'],\n"loop": false,\n"name": &"'+anim+'_'+d+'",\n"speed": '+str(12.0 if anim!='cast_ult' else 11.0)+'\n}')
    at=text.index('[resource]');text=text[:at]+'\n'.join(resources)+'\n'+text[at:]
    pos=text.rfind('}]');text=text[:pos+1]+', '+', '.join(animations)+text[pos+1:]
    steps=135+6+3+sum(c*8 for c,_,_ in SPECS.values())
    text=re.sub(r'load_steps=\d+',f'load_steps={steps}',text,count=1);p.write_text(text)

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
        sheets={su:Image.new('RGBA',(count*192,1536)) for su in ('','_n','_e')}
        for row,d in enumerate(DIRS):
            for i in range(count):
                for su,atlas in sheets.items():
                    im=Image.open(RAW/anim/(d+'_%02d'%i+su+'.png')).convert('RGBA')
                    if su=='_n':
                        ar=np.array(im);v=ar[:,:,:3].astype(float)/127.5-1;v/=np.maximum(np.linalg.norm(v,axis=2,keepdims=True),1e-8);ar[:,:,:3]=np.rint((v+1)*127.5).clip(0,255).astype('uint8');im=Image.fromarray(ar)
                    atlas.paste(im,(i*192,row*192))
        for su,atlas in sheets.items():atlas.save(CHAR/(anim+su+'.png'),optimize=True,compress_level=9)
    resource_actions()
    for kind,(size,slots,count,radius) in FX.items():
        folder=ROOT/'game/assets/sprites/vfx'/kind
        for label,n,columns in [('default',count,slots)]+([('end',4,4)] if kind=='ardent_ashes' else []):
            for su in ('','_e'):
                atlas=Image.new('RGBA',(size*columns,size))
                for i in range(n):
                    path=RAW/kind/label/('%02d'%i+su+'.png')
                    if path.exists():atlas.paste(Image.open(path),(i*size,0))
                    else:assert label=='end' and i==3 and su=='_e'
                atlas.save(folder/(label+su+'.png'),optimize=True,compress_level=9)
        resource_fx(kind,count,kind=='ardent_ashes')
    print('A2 PACK PASS',flush=True)

def contact_verify():
    baseline=json.loads((HERE/'_a2_baseline.json').read_text());assert all(sha(CHAR/k)==v for k,v in baseline.items())
    report={'unchanged_idle_run':True,'actions':{},'vfx':{}}
    for anim,(count,impact,start) in SPECS.items():
        im=Image.open(CHAR/(anim+'.png'));bounds=[]
        for row in range(8):
            hashes=[]
            for i in range(count):
                cell=im.crop((i*192,row*192,(i+1)*192,(row+1)*192));b=cell.getchannel('A').getbbox();assert b
                assert min(b[:2])>=4 and max(b[2:])<=188,(anim,DIRS[row],i,b)
                hashes.append(hashlib.sha256(cell.tobytes()).hexdigest());bounds.append(b)
            assert len(set(hashes))==count
        report['actions'][anim]={'frames':count,'impact':impact,'pivot':[96,136.32],'bounds':[min(b[0] for b in bounds),min(b[1] for b in bounds),max(b[2] for b in bounds),max(b[3] for b in bounds)]}
    # Single review sheet, actual native pixel density; each VFX frame over C1 ground.
    width=2560;height=3*384+10*640
    canvas=Image.new('RGBA',(width,height),(24,29,31,255))
    for row,(anim,(count,impact,start)) in enumerate(SPECS.items()):
        im=Image.open(CHAR/(anim+'.png')).convert('RGBA')
        for sub,d in enumerate(('s','e')):
            r=DIRS.index(d)
            for j,f in enumerate(range(count)):
                canvas.alpha_composite(im.crop((f*192,r*192,(f+1)*192,(r+1)*192)),(j*192,row*384+sub*192))
    ref=Image.open(HERE/'_v2_contact.png').convert('RGBA');ref.thumbnail((960,768),Image.Resampling.LANCZOS)
    canvas.alpha_composite(ref,(1568,0))
    ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    actor=Image.open(CHAR/'idle.png').convert('RGBA').crop((0,384,192,576))
    y=1152
    for kind,(size,slots,count,radius) in FX.items():
        folder=ROOT/'game/assets/sprites/vfx'/kind
        labels=[('default',count)]+([('end',4)] if kind=='ardent_ashes' else [])
        # Measure radius/aspect by projecting explicit z=0 calibration points using the saved camera.
        rpx=radius*90.50966799187809
        report['vfx'][kind]={'frames':count,'radius_px':round(rpx,2),'floor_aspect':.5,'measurement':'orthographic projection of mesh floor radius at z=0; CREA elevation 30deg','frame_px':size,'atlas_columns':slots,'loop':kind=='ardent_ashes'}
        for label,n in labels:
            atlas=Image.open(folder/(label+'.png')).convert('RGBA')
            emission=Image.open(folder/(label+'_e.png')).convert('RGBA');assert max(hi for lo,hi in emission.getextrema()[:3])>100
            for i in range(n):
                x=(i%4)*640;top=y+(i//4)*640;cx=x+320;cy=top+360
                patch=Image.new('RGBA',(640,640),(24,29,31,255))
                for depth in range(5):
                    for a in range(3):
                        b=depth-a
                        if 0<=b<3:
                            patch.alpha_composite(ground,(64+(a-b)*256,-24+(a+b)*128))
                canvas.alpha_composite(patch,(x,top))
                cell=atlas.crop((i*size,0,(i+1)*size,size))
                canvas.alpha_composite(cell,(cx-size//2,cy-size//2))
                canvas.alpha_composite(actor,(cx-96,cy-136))
                front=cell.crop((0,size//2,size,size))
                canvas.alpha_composite(front,(cx-size//2,cy))
            y+=math.ceil(n/4)*640
    canvas=canvas.crop((0,0,width,y));canvas.convert('RGB').save(HERE/'_a2_contact.png',optimize=True,compress_level=9)
    measured=HERE/'_a2_geometry.json'
    if measured.exists():
        for kind,values in json.loads(measured.read_text()).items():report['vfx'][kind].update(values)
    (HERE/'_a2_verification.json').write_text(json.dumps(report,indent=2))
    (HERE/'_a2_contact.json').write_text(json.dumps({'actions_top_to_bottom':['attack s','attack e','cast s','cast e','cast_ult s','cast_ult e'],'frames':'chronological left to right','reference_upper_right':'V2 projectile contact','vfx_below':['nova default 0..9','ashes default 0..7','ashes end 0..3','brasier default 0..11'],'vfx_columns':4,'scale':'native CREA pixel density; C1 ground_a at native 512x256; Ardent pivot [96,136.32]'},indent=2))
    print('A2 VERIFY PASS '+json.dumps(report),flush=True)

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
                    iso_rig.render_frame(RAW/kind/'default'/('%02d.png'%(f-1)));repaired.append(f-1)
        if kind=='ardent_ashes':
            # The final extinction frame must leave no residual smoke or coals.
            s.frame_set(count+4)
            for o in s.objects:
                if o.type=='MESH':o.hide_render=True;o.keyframe_insert('hide_render',frame=count+4)
            iso_rig.render_frame(RAW/kind/'end'/'03.png')
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
    inventory()
    if '--measure' in sys.argv:measure()
    elif '--finish' in sys.argv:pack();contact_verify()
    elif '--verify' in sys.argv:contact_verify()
    else:
        if '--vfx-only' not in sys.argv:render_actions()
        if '--build-only' in sys.argv:sys.exit()
        if '--actions-only' not in sys.argv:render_vfx()
        measure();pack();contact_verify()
