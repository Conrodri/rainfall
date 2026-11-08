"""Dedicated planted Vigie flare. Four validated PNGs, no resource or normal writes."""
import sys,math,json,hashlib,os,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.dont_write_bytecode=True
W=ROOT/'art/blender/cel/feel2/vigie_flare'
O=ROOT/'art/renders/feel_sorts2'
D=ROOT/'game/assets/sprites/characters/vigie/flare'
S={'default.png':(768,192,85000),'end.png':(512,192,44000),'default_e.png':(384,96,22000),'end_e.png':(256,96,9000)}
if '--build' not in sys.argv:
    from PIL import Image
    import numpy as np
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def outside():
    result={}
    for folder,dirs,files in os.walk(ROOT.parents[2]):
        dirs[:]=[d for d in dirs if d not in ('.git','.claude','node_modules','.godot')]
        for name in files:
            p=Path(folder)/name;s=p.stat();result[str(p)]=[s.st_size,s.st_mtime_ns]
    return result
def contact(images,path):
    board=Image.new('RGBA',(768,384),(58,62,70,255))
    for y,k in enumerate(('default.png','end.png')):board.alpha_composite(images[k],(0,y*192))
    board.convert('RGB').save(path,optimize=True)
def prepare():
    W.mkdir(parents=True,exist_ok=True);O.mkdir(parents=True,exist_ok=True)
    stats={};images={}
    for k in S:
        raw=subprocess.check_output(['git','show','HEAD:'+str((D/k).relative_to(ROOT)).replace('\\','/')],cwd=ROOT)
        (W/('before_'+k)).write_bytes(raw);im=Image.open(W/('before_'+k)).convert('RGBA');images[k]=im
        stats[k]={'size':list(im.size),'bytes':len(raw)}
    a=np.array(images['default.png'])[:,:128,3]
    foot=np.argwhere(a>32);bottom=int(foot[:,0].max());x=float(np.where(a[bottom]>32)[0].mean())
    contact(images,O/'before_vfx_flare_vigie.png')
    (W/'before.json').write_text(json.dumps({'stats':stats,'pivot':[x,bottom],'protected':{str(p):digest(p) for p in D.glob('*') if p.name not in S},'outside':outside()}))
    print('BASELINE PASS '+json.dumps({'pivot':[x,bottom],'stats':stats}))
def build():
    import bpy
    from mathutils import Vector
    sys.path[:0]=[str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/night')]
    import cel_style as cel
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/vigie_fx_flare.blend'))
    (W/'source_inspection.json').write_text(json.dumps({'objects':[(o.name,o.type) for o in bpy.data.objects]}))
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    s=bpy.context.scene;s.use_nodes=False
    if hasattr(s,'compositing_node_group'):s.compositing_node_group=None
    cel.install('vfx',normals=False);cel.setup_scene(samples=8)
    for vl in s.view_layers:vl.use_pass_normal=False
    s.render.resolution_x=256;s.render.resolution_y=384;s.render.resolution_percentage=100
    s.world.color=(.16,.16,.16);s.view_settings.view_transform='Standard';s.render.image_settings.color_depth='8'
    def mat(name,color,glow=False):
        m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
        def lin(c):return c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4
        rgb=tuple(lin(int(color[i:i+2],16)/255) for i in (0,2,4))+(1,)
        p.inputs['Base Color'].default_value=rgb
        if glow:p.inputs['Emission Color'].default_value=rgb;p.inputs['Emission Strength'].default_value=1;m['rainfall_emissive']=True
        m['flare_glow']=glow;return m
    steel=mat('Charred steel','343B45');brass=mat('Brass collar','C28D51');earth=mat('Planted soil','57463F')
    smoke=mat('Dark crimson smoke','692B3D');lit=mat('Smoke lit planes','903344')
    red=mat('FF3A4F red flame','FF3A4F',True);pink=mat('Pink flame','FF889A',True);core=mat('White rose heart','FFE5E9',True);halo=mat('Discrete ground red','692B37',True)
    black=bpy.data.materials.new('Emission occluder');black.use_nodes=True;ns=black.node_tree.nodes;ns.clear();e=ns.new('ShaderNodeEmission');e.inputs[0].default_value=(0,0,0,1);out=ns.new('ShaderNodeOutputMaterial');black.node_tree.links.new(e.outputs[0],out.inputs[0]);black['cel_done']=True
    def mesh(name,vs,fs,m):
        data=bpy.data.meshes.new(name);data.from_pydata(vs,[],fs);data.update();ob=bpy.data.objects.new(name,data);s.collection.objects.link(ob);ob.data.materials.append(m);return ob
    def cylinder(name,r,depth,z,m):
        bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=r,depth=depth,location=(0,0,z));ob=bpy.context.object;ob.name=name;ob.data.materials.append(m);return ob
    def puff(name,loc,scale,m):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=loc);ob=bpy.context.object;ob.name=name;ob.scale=scale;ob.data.materials.append(m);return ob
    bpy.ops.object.camera_add(location=(5,-8.660254,5.773503));cam=bpy.context.object
    cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.35
    up=cam.rotation_euler.to_quaternion()@Vector((0,1,0));right=cam.rotation_euler.to_quaternion()@Vector((1,0,0))
    pivot=json.loads((W/'pivot.json').read_text())
    cam.location+=up*(3.35*(pivot[1]/192-.5))+right*(3.35/192*(64-pivot[0]))
    s.camera=cam
    bpy.ops.object.light_add(type='AREA',location=(-3,-4,7));bpy.context.object.data.energy=650;bpy.context.object.data.size=4
    static=set(bpy.data.objects)
    def tongue(name,base,h,r,phase,m):
        vs=[];n=7
        for j in range(5):
            t=j/4;cx=base[0]+.10*math.sin(phase+t*4)*t;cy=base[1]+.065*math.cos(phase+t*5)*t
            rr=r*(1-t)**.72*(1+.20*math.sin(t*9+phase)) if j<4 else .003
            for k in range(n):
                a=k*math.tau/n;vs.append((cx+rr*math.cos(a),cy+rr*math.sin(a),base[2]+h*t))
        fs=[tuple(range(n-1,-1,-1))]+[(j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k) for j in range(4) for k in range(n)]
        return mesh(name,vs,fs,m)
    for anim,n in [('default',6),('end',4)]:
        for f in range(n):
            for ob in list(bpy.data.objects):
                if ob not in static:bpy.data.objects.remove(ob,do_unlink=True)
            phase=f*math.tau/6;strength=1 if anim=='default' else [.72,.38,.12,0][f]
            if anim=='default' or f<3:
                cylinder('Upright steel barrel',.067,.98,.49,steel);cylinder('Brass band',.079,.12,.65,brass);cylinder('Nozzle rim',.084,.09,.95,brass)
                puff('Small earth mound',(0,0,.09),(.20,.14,.05),earth)
                for j in range(3):
                    a=j*math.tau/3;v=Vector((math.cos(a),math.sin(a),0));side=Vector((-v.y,v.x,0))*.018
                    ps=[v*.055+Vector((0,0,.34)),v*.15+Vector((0,0,.07)),v*.06+Vector((0,0,.07))]
                    mesh('Planted stabilizer fin',[tuple(p+t) for t in (-side,side) for p in ps],[(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(2,5,3,0)],brass)
            if strength:
                puff('Ground ember halo',(0,0,.12),(.30*strength,.20*strength,.008),halo)
                tongue('Main serrated red flame',(0,0,.98),.92*strength,.155*strength,phase,red)
                for j in range(7):
                    a=j*math.tau/7;h=(.40+.29*(.5+.5*math.sin(phase+j*2.4)))*strength
                    tongue('Dancing tongue',(.115*math.cos(a),.10*math.sin(a),.98),h,.075*strength,phase+j,red)
                tongue('Pink interior',(.025,-.06,1),.60*strength,.087*strength,phase+.8,pink)
                tongue('White pink ignition',(.03,-.105,1),.38*strength,.05*strength,phase,core)
            for j in range(12):
                t=j/11;a=t*5+.20*math.sin(phase);z=1.55+t*1.37+(f*.08 if anim=='end' else 0)
                width=(.10+.085*t)*(1 if anim=='default' else [1,.95,.75,.38][f])
                puff('Coiling smoke',(.14*math.sin(a)+.14*t,.10*math.cos(a),z),(width*(1+.22*math.sin(j*2+phase)),width*.8,.14),smoke if j%3 else lit)
            if strength:
                for j in range(15):
                    t=(j/15+f/6)%1;a=j*2.399+.15*math.sin(phase)
                    puff('Rising spark',(.11*math.cos(a)+.19*t*math.sin(a),.10*math.sin(a),1.18+t*1.40),(.012,.012,.025+.025*t),pink if j%4 else core)
            elif anim=='end':
                puff('Last rising ember',(.28,-.15,2.25),(.023,.023,.035),red)
            cel.toon_materials('vfx');s.render.filepath=str(W/f'{anim}_{f}.png');bpy.ops.render.render(write_still=True)
            swapped=[]
            for ob in bpy.data.objects:
                if ob.type!='MESH':continue
                for idx,m in enumerate(ob.data.materials):
                    if not m.get('flare_glow'):swapped.append((ob,idx,m));ob.data.materials[idx]=black
            s.render.filepath=str(W/f'{anim}_{f}_e.png');bpy.ops.render.render(write_still=True)
            for ob,idx,m in swapped:ob.data.materials[idx]=m
    bpy.context.preferences.filepaths.save_version=0
    blend=W/'vigie_flare_work.blend';version=1
    while blend.exists():
        version+=1;blend=W/f'vigie_flare_work_{version:02}.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    print('FLARE RENDER PASS 20 frames normals=False')
def deliver():
    stats={};images={}
    for anim,n in [('default',6),('end',4)]:
        for suffix in ('','_e'):
            cell=(64,96) if suffix else (128,192);atlas=Image.new('RGBA',(cell[0]*n,cell[1]));hashes=[]
            for f in range(n):
                im=Image.open(W/f'{anim}_{f}{suffix}.png').convert('RGBA').resize(cell,Image.Resampling.LANCZOS);a=np.array(im)
                if suffix:a[:,:,3]=np.minimum(a[:,:,3],a[:,:,:3].max(axis=2));im=Image.fromarray(a)
                assert im.getbbox(),(anim,f,suffix,'empty');hashes.append(hashlib.sha256(im.tobytes()).hexdigest())
                if anim=='default' and not suffix:
                    body=a[142:180,54:68];visible=(body[:,:,3]>180)&(body[:,:,:3].max(axis=2)<160)
                    assert visible.sum()>50,('barrel invisible',f,int(visible.sum()))
                atlas.paste(im,(cell[0]*f,0))
            assert len(set(hashes))==n,('duplicate frames',anim,suffix)
            name=anim+suffix+'.png';p=W/name;atlas.quantize(colors=32 if suffix else 64,method=Image.Quantize.FASTOCTREE).save(p,optimize=True)
            im=Image.open(p).convert('RGBA');a=np.array(im);w,h,limit=S[name]
            assert im.size==(w,h) and p.stat().st_size<=limit,(name,im.size,p.stat().st_size)
            assert a[:,:,3].max()>0 and a[:,:,:3].max()>100
            if suffix:assert ((a[:,:,0]>150)&(a[:,:,3]>30)).sum()>20
            finalhashes=[hashlib.sha256(im.crop((i*cell[0],0,(i+1)*cell[0],cell[1])).tobytes()).hexdigest() for i in range(n)]
            assert len(set(finalhashes))==n
            frames=[]
            for i in range(n):
                frame=a[:,i*cell[0]:(i+1)*cell[0]];frames.append(frame)
                assert (frame[:,:,3]>3).any(),('final empty frame',name,i)
                if suffix:assert ((frame[:,:,0]>60)&(frame[:,:,3]>3)).any(),('final empty emission',name,i)
                else:
                    opaque=frame[:,:,3]>128
                    assert np.ptp(frame[:,:,:3][opaque].astype(float).mean(axis=1))>15,('contrast',name,i)
                    if anim=='default':
                        coords=np.argwhere(frame[:,:,3]>32);bottom=int(coords[:,0].max());footx=float(np.where(frame[bottom,:,3]>32)[0].mean())
                        assert bottom in (190,191) and abs(footx-60)<=5,('pivot support',i,footx,bottom)
                        assert (frame[188:191,58:63,3]>32).any(),('planted foot missing',i)
            if anim=='default':
                delta=[float(np.abs(frames[(i+1)%n].astype(float)-frames[i].astype(float)).mean()) for i in range(n)]
                assert delta[-1]<=max(delta[:-1])*1.5,('loop discontinuity',delta)
            images[name]=im;stats[name]={'size':list(im.size),'bytes':p.stat().st_size,'distinct':n}
    before=json.loads((W/'before.json').read_text());assert all(digest(Path(p))==v for p,v in before['protected'].items()),'protected modified'
    changed=[p for p,v in outside().items() if p not in before['outside'] or v!=before['outside'][p]]
    assert not changed,('outside changes',changed[:3])
    contact(images,O/'after_vfx_flare_vigie.png')
    (W/'verification.json').write_text(json.dumps({'before':before['stats'],'after':stats,'pivot':before['pivot'],'outside_changes':changed,'barrel':'PASS','protected':'PASS','normal_outputs':[]},indent=2))
    for k in S:shutil.copyfile(W/k,D/k)
    print('FLARE CONTRACT PASS '+json.dumps(stats))
if __name__=='__main__':{'--prepare':prepare,'--build':build,'--deliver':deliver}[sys.argv[-1]]()
