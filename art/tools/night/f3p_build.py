"""F3P: worn industrial MAP props, reusing F2P/C0 and Ash Lord shaders.
Blender --background --python this.py [-- --only name]; Python this.py --verify.
Pillow assembles and checks only. Legacy frame sizes are preserved.
"""
from pathlib import Path
import sys, math, json, random
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'game/assets/sprites/props/rust_city'
SRC=ROOT/'art/blender/props'
SPECS={'crate_se':(128,94),'crate_sw':(128,94),'barrels':(160,122),
       'valve':(128,96),'pipe_stub':(192,148),'debris':(192,108),
       'steam_lamp_se':(256,220),'steam_lamp_sw':(256,220),'tank_large':(320,268),
       'crate':(128,94),'steam_lamp':(128,114),'bell':(192,160),
       'cables':(128,86),'catwalk':(256,160),'tank_small':(192,155),'ticket_booth':(192,162)}
LIMITS={'crate_se':1.2,'crate_sw':1.2,'barrels':1.2,'valve':1.,'pipe_stub':1.5,
        'debris':1.5,'steam_lamp_se':.8,'steam_lamp_sw':.8,'tank_large':1.5}
SHADOWS={'crate_se','crate_sw','barrels','pipe_stub','tank_large','crate','steam_lamp_se','steam_lamp_sw'}
WEIGHTS=[('crate_se',4),('barrels',4),('debris',4),('valve',2),('pipe_stub',2),('tank_large',1)]

def verify():
    from PIL import Image, ImageChops
    errors=[];checks=[]
    for name,(sz,fy) in SPECS.items():
        check=json.loads((SRC/('f3p_'+name+'_check.json')).read_text());checks.append(check)
        if max(check['footprint'])>LIMITS.get(name,2.8)+.002:errors.append('footprint '+name)
        if max(check['envelope'])>LIMITS.get(name,2.8)+.002:errors.append('envelope '+name)
        if max(abs(a-b) for a,b in zip(check['foot'],[sz/2,fy]))>.02:errors.append('foot '+name)
        if name.startswith('steam_lamp_') and abs(check['height_u']-2.2)>.002:errors.append('height '+name)
        if name=='tank_large' and abs(check['height_u']-2.5)>.002:errors.append('height '+name)
        for suffix in ('','_n')+(('_e',) if 'lamp' in name else ())+(('_shadow',) if name in SHADOWS else ()):
            p=OUT/(name+suffix+'.png')
            if not p.exists():errors.append('missing '+p.name);continue
            im=Image.open(p).convert('RGBA')
            if im.size!=((512,512) if suffix=='_shadow' else (sz,sz)):errors.append('size '+p.name)
            bbox=im.getchannel('A').point(lambda a:255 if a>24 else 0).getbbox()
            if not bbox or min(bbox[0],bbox[1],im.width-bbox[2],im.height-bbox[3])<3:errors.append('clipped '+p.name)
            if suffix=='_e' and max(c.getextrema()[1] for c in im.split()[:3])<30:errors.append('emission '+name)
            if suffix=='_n':
                diffuse=Image.open(OUT/(name+'.png')).convert('RGBA')
                if ImageChops.difference(diffuse.getchannel('A'),im.getchannel('A')).getextrema()[1]>3:errors.append('normal alpha '+name)
    manifest=json.loads((OUT/'props.json').read_text())
    if manifest['density']!=.05 or [(p['name'],p['weight']) for p in manifest['props']]!=WEIGHTS:errors.append('manifest')
    for p in manifest['props']:
        if p['foot']!=[SPECS[p['name']][0]//2,SPECS[p['name']][1]] or p['px_per_u']!=90.51:errors.append('manifest pivot')
        if p.get('shadow_rig')!=('top' if p['name'] in SHADOWS else None):errors.append('shadow rig')
    # Single final contact: native MAP scale on F3 ground, then approved references.
    board=Image.new('RGBA',(1920,2080),(19,23,26,255))
    terrain=ROOT/'game/assets/sprites/terrain/rust_city/iso/ground_a.png'
    tile=Image.open(terrain).convert('RGBA')
    for idx,(name,(sz,fy)) in enumerate(SPECS.items()):
        panel=Image.new('RGBA',(480,390),(19,23,26,255));cx,cy=240,315
        panel.alpha_composite(tile,(cx-tile.width//2,cy-tile.height//2))
        panel.alpha_composite(Image.open(OUT/(name+'.png')).convert('RGBA'),(cx-sz//2,cy-fy))
        if name in SHADOWS:
            im=Image.open(OUT/(name+'_shadow.png')).convert('RGBA');im.thumbnail((96,96));panel.alpha_composite(im,(375,270))
        if 'lamp' in name:
            im=Image.open(OUT/(name+'_e.png')).convert('RGBA');im.thumbnail((70,100));panel.alpha_composite(im,(385,35))
        board.alpha_composite(panel,((idx%4)*480,(idx//4)*390))
    refs=['art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/night/_f3_contact.png']
    refs += [str(p.relative_to(ROOT)) for p in sorted((HERE/'_floor3_captures').glob('cite*.png'))[:2]]
    for i,path in enumerate(refs):
        im=Image.open(ROOT/path).convert('RGBA');im.thumbnail((620,245));board.alpha_composite(im,((i%3)*640+(640-im.width)//2,1570+(i//3)*255))
    board.convert('RGB').save(HERE/'_f3p_contact.png',optimize=True,compress_level=9)
    (SRC/'f3p_validation.json').write_text(json.dumps({'status':'FAIL' if errors else 'PASS','errors':errors,'checks':checks},indent=2))
    print('F3P '+('FAIL '+str(errors[:20]) if errors else 'PASS: 16 props, MAP pivots, footprints, heights, TOP shadows, normals, emissions, manifest'))
    return not errors

if __name__=='__main__' and '--verify' in sys.argv:sys.exit(0 if verify() else 1)

sys.path.insert(0,str(HERE))
from f2_build import worn, mesh, root_curve
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
import iso_rig as rig
C=rig.common
# Blender 5.2 defaults Set Alpha to multiplication; the normal combine already
# contains coverage. Replace it to keep identical antialiased pass silhouettes.
_configure_passes=C.configure_passes
def configure_passes(path):
    _configure_passes(path)
    tree=getattr(bpy.context.scene,'compositing_node_group',None) or bpy.context.scene.node_tree
    for node in tree.nodes:
        if node.bl_idname=='CompositorNodeSetAlpha':
            if 'Type' in node.inputs:node.inputs['Type'].default_value='Replace Alpha'
            else:node.mode='REPLACE_ALPHA'
C.configure_passes=configure_passes

def box(n,p,d,m,r,b=.012):return C.box(n,p,d,m,r,b)
def rod(n,a,b,rad,m,r):return C.rod(n,a,b,rad,m,r)
def ring(n,p,rad,t,m,r,rot=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=6,location=p,major_radius=rad,minor_radius=t,rotation=rot)
    return C.finish(bpy.context.object,n,m,r)
def cyl(n,p,rad,h,m,r,vertices=24,r2=None):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=rad,radius2=rad if r2 is None else r2,depth=h,location=p)
    ob=C.finish(bpy.context.object,n,m,r,.006)
    for f in ob.data.polygons:f.use_smooth=len(f.vertices)==4
    return ob
def bolt(p,m,r):return cyl('Hexagonal brass fastener',p,.021,.018,m,r,6)

def materials():
    m={k:worn(label,a,b,metal,rough) for k,label,a,b,metal,rough in [
       ('iron','Blackened hammered iron','1B1D1F','454440',.64,.54),
       ('rust','Flaking oxide and scabbed seams','30221B','70482F',.45,.76),
       ('brass','Tarnished brass edges','514731','A08D66',.72,.49),
       ('oil','Viscous black oil','090D10','242825',.28,.23),
       ('enamel','Sooted municipal enamel','252E2C','59615A',.38,.6),
       ('stone','Wet chipped basalt','20282C','43494A',.05,.75)]}
    g=C.material('Steam amber E8A86C',(0.807,.392,.150),.12,.28,1.45)
    m['glow']=g
    return m

def crate(r,m):
    box('Riveted freight case',(0,0,.39),(.86,.74,.72),m['iron'],r,.025)
    for x in (-.43,.43):
        for y in (-.37,.37):box('Oxidised corner guard',(x,y,.40),(.065,.065,.77),m['rust'],r)
    for x in (-.29,.29):
        box('Brass hoop across lid',(x,0,.765),(.058,.79,.027),m['brass'],r)
        for y in (-.38,.38):
            box('Tarnished hoop',(x,y,.39),(.058,.025,.74),m['brass'],r)
            for z in (.12,.62):rod('Strap rivet',(x,y,z),(x,y+(.016 if y>0 else -.016),z),.016,m['brass'],r)
    for y in (-.28,.28):box('Recessed lid seam',(0,y,.757),(.79,.012,.012),m['oil'],r)
    box('Forged latch',(0,-.398,.47),(.12,.035,.19),m['rust'],r)
    box('Latch brass tongue',(0,-.425,.47),(.032,.022,.11),m['brass'],r)

def drum(r,m,x,y,h,rad,seed):
    rng=random.Random(seed);N=28;verts=[];levels=[0,.04,.15,.46,.78,.95,1]
    for k,t in enumerate(levels):
        for j in range(N):
            a=j*math.tau/N;rr=rad*(1+(.02*rng.uniform(-1,1) if k in (0,1,5,6) else .075*rng.uniform(-1,1)))
            verts.append((x+rr*math.cos(a),y+rr*math.sin(a),.035+h*t))
    faces=[tuple(range(N-1,-1,-1)),tuple(range((len(levels)-1)*N,len(levels)*N))]
    faces += [(k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j) for k in range(len(levels)-1) for j in range(N)]
    mesh('Dented oil drum',verts,faces,m['enamel'],r,.005)
    for z in (.04,.22,.76,.98):ring('Rolled rusty drum hoop',(x,y,.035+h*z),rad,.018,m['rust'],r)
    cyl('Oily barrel lid',(x,y,h+.038),rad*.92,.012,m['iron'],r)
    cyl('Bung',(x+.09,y-.06,h+.05),.045,.022,m['brass'],r,6)
    # Thin tapering oil runs, actual surface geometry.
    for j in range(4):
        a=-math.pi*.75+j*.25;z=h*(.4+j*.12)
        root_curve([(x+rad*math.cos(a),y+rad*math.sin(a),h*.96),(x+(rad+.006)*math.cos(a),y+(rad+.006)*math.sin(a),z)],.009,m['oil'],r,'Black oil seep')

def barrels(r,m):
    drum(r,m,-.25,-.13,.72,.245,2);drum(r,m,.26,.13,.87,.25,6)
    box('Oil soaked packing slat',(0,0,.017),(.99,.72,.032),m['oil'],r)

def wheel(r,m,p,rad=.26):
    x,y,z=p;ring('Cast iron pressure wheel',p,rad,.023,m['rust'],r,(math.pi/2,0,0))
    for i in range(5):
        a=i*math.tau/5;rod('Cast wheel spoke',p,(x+rad*.94*math.cos(a),y,z+rad*.94*math.sin(a)),.014,m['iron'],r)
    rod('Brass wheel hub',(x,y-.035,z),(x,y+.045,z),.046,m['brass'],r)

def flange(r,m,p,rad=.19):
    x,y,z=p;cyl('Bolted pipe flange',p,rad,.055,m['rust'],r)
    for j in range(8):
        a=j*math.tau/8;bolt((x+(rad-.035)*math.cos(a),y+(rad-.035)*math.sin(a),z+.034),m['brass'],r)

def valve(r,m):
    box('Drain mounting shoe',(0,0,.045),(.65,.56,.09),m['iron'],r)
    root_curve([(-.36,0,.15),(-.18,0,.18),(0,0,.28),(.2,0,.20),(.37,0,.16)],.105,m['rust'],r,'Pressure conduit')
    cyl('Valve bonnet',(0,0,.35),.115,.27,m['iron'],r)
    rod('Pressure valve stem',(0,0,.37),(0,-.17,.52),.033,m['brass'],r)
    wheel(r,m,(0,-.18,.53),.24)
    for x in (-.25,.25):
        for y in (-.2,.2):bolt((x,y,.10),m['brass'],r)

def pipe(r,m):
    flange(r,m,(-.25,.08,.06),.25)
    root_curve([(-.25,.08,.08),(-.25,.08,.36),(-.23,.08,.63),(-.08,.08,.78),(.15,.08,.81),(.46,.08,.81)],.145,m['iron'],r,'Split cast iron elbow')
    ob=cyl('Open pipe rusty lip',(.48,.08,.81),.195,.06,m['rust'],r);ob.rotation_euler.y=math.pi/2
    ob=cyl('Dark pipe bore',(.515,.08,.81),.14,.008,m['oil'],r);ob.rotation_euler.y=math.pi/2
    for j in range(6):
        a=j*math.tau/6;rod('Flange end bolt',(.47,.08+.166*math.cos(a),.81+.166*math.sin(a)),(.52,.08+.166*math.cos(a),.81+.166*math.sin(a)),.018,m['brass'],r)
    box('Masonry pipe collar',(-.25,.08,.035),(.66,.64,.07),m['stone'],r)

def debris(r,m):
    rng=random.Random(18)
    for i in range(4):
        x,y=rng.uniform(-.32,.32),rng.uniform(-.28,.28)
        ob=box('Twisted fallen plate',(x,y,.05+i*.025),(.65,.3,.025),m['rust'] if i%2 else m['iron'],r,.004);ob.rotation_euler.z=rng.uniform(-1,1)
    for x,y,a in [(-.1,0,-.55),(.14,.1,.4)]:
        beam=C.empty('Broken I beam',(x,y,.07),r);beam.rotation_euler.z=a
        for z in (0,.12):box('I beam flange',(0,0,z),(1.02,.13,.025),m['iron'],beam,.004)
        box('I beam web',(0,0,.06),(1.02,.022,.12),m['rust'],beam,.003)

def lamp(r,m):
    # Lean, insect-like municipal fixture; caged globe, no baked halo.
    box('Basalt anchor',(0,0,.04),(.37,.33,.08),m['stone'],r,.018)
    box('Bolted iron socket',(0,0,.10),(.29,.25,.05),m['iron'],r)
    for x in (-.10,.10):
        for y in (-.08,.08):bolt((x,y,.137),m['brass'],r)
    cyl('Fluted cast iron foot',(0,0,.27),.105,.31,m['rust'],r,r2=.063)
    cyl('Narrow lamp shaft',(0,0,1.08),.043,1.4,m['iron'],r,12,r2=.035)
    for z in (.46,1.55):ring('Brass collar',(0,0,z),.052,.015,m['brass'],r)
    root_curve([(0,0,1.6),(0,0,1.91),(.13,0,2.08),(.37,0,2.08),(.45,0,1.98)],.032,m['iron'],r,'Crooked swan neck')
    x=.43;z=1.81
    cyl('Amber pressure glass',(x,0,z),.104,.24,m['glow'],r,12,r2=.080)
    cyl('Chimney canopy',(x,0,2.005),.175,.16,m['iron'],r,8,r2=.055)
    cyl('Chimney cap',(x,0,2.16),.055,.08,m['rust'],r,8,r2=.025)
    cyl('Lamp sump',(x,0,1.655),.12,.07,m['brass'],r,12,r2=.09)
    for j in range(6):
        a=j*math.tau/6;rod('Protective lantern cage',(x+.112*math.cos(a),.112*math.sin(a),1.68),(x+.112*math.cos(a),.112*math.sin(a),1.95),.012,m['iron'],r)
    root_curve([(-.06,.03,.48),(-.06,.03,1.50),(.07,.03,1.77)],.012,m['brass'],r,'Steam feed capillary')

def tank(r,m,small=False):
    h=1.45 if small else 2.5;rad=.40 if small else .51
    for x in (-rad*.62,rad*.62):
        for y in (-rad*.62,rad*.62):box('Tank pedestal',(x,y,.12),(.14,.14,.24),m['iron'],r)
    cyl('Riveted pressure vessel',(0,0,(h+.15)/2),rad,h-.35,m['enamel'],r,32)
    cyl('Rusted dished shoulder',(0,0,h-.16),rad,.22,m['rust'],r,32,r2=rad*.62)
    cyl('Inspection manhole',(0,0,h-.035),rad*.52,.07,m['iron'],r,24)
    for z in (.25,h*.46,h-.31):
        ring('Rolled welded seam',(0,0,z),rad+.008,.022,m['rust'],r)
        for j in range(18):
            a=j*math.tau/18;rod('Vessel seam rivet',((rad+.006)*math.cos(a),(rad+.006)*math.sin(a),z+.055),((rad+.025)*math.cos(a),(rad+.025)*math.sin(a),z+.055),.015,m['brass'],r)
    # Side ladder projects to the silhouette, all within 1.5u footprint.
    for x in (-.18,.18):rod('Ladder rail',(x,-rad-.105,.05),(x,-rad-.105,h-.2),.023,m['iron'],r)
    for i in range(int((h-.2)/.20)):rod('Worn ladder rung',(-.19,-rad-.105,.16+i*.2),(.19,-rad-.105,.16+i*.2),.017,m['brass'],r)
    for z in (.45,h-.5):
        for x in (-.18,.18):rod('Ladder stand off',(x,-rad,z),(x,-rad-.105,z),.018,m['rust'],r)
    rod('Pressure gauge neck',(.24,-rad*.7,h-.48),(.24,-rad-.09,h-.48),.025,m['brass'],r)
    ob=cyl('Pressure gauge rim',(.24,-rad-.11,h-.48),.09,.035,m['brass'],r);ob.rotation_euler.x=math.pi/2
    ob=cyl('Pressure gauge face',(.24,-rad-.135,h-.48),.073,.008,m['stone'],r);ob.rotation_euler.x=math.pi/2
    rod('Pressure gauge needle',(.24,-rad-.145,h-.48),(.21,-rad-.145,h-.43),.006,m['brass'],r)
    for j in range(6):
        a=j*.5+.3;root_curve([((rad+.009)*math.cos(a),(rad+.009)*math.sin(a),h-.32),((rad+.012)*math.cos(a),(rad+.012)*math.sin(a),h*(.30+j*.05))],.012,m['rust'],r,'Rain streak')

def legacy(name,r,m):
    if name=='bell':
        for x in (-.45,.45):box('Bell gantry',(x,0,.65),(.09,.11,1.30),m['iron'],r)
        box('Bell crossbar',(0,0,1.30),(1.06,.15,.10),m['rust'],r)
        cyl('Cast bell skirt',(0,0,.60),.35,.42,m['brass'],r,32,r2=.16)
        cyl('Bell crown',(0,0,.94),.16,.27,m['brass'],r,24,r2=.08)
        ring('Bell lip',(0,0,.39),.35,.028,m['rust'],r)
        rod('Bell clapper',(0,0,.69),(0,0,.33),.037,m['iron'],r)
        rod('Bell hanger',(0,0,1.03),(0,0,1.30),.045,m['iron'],r)
    elif name=='cables':
        for j in range(4):
            pts=[(.41*math.cos(i*math.tau/24),.24*math.sin(i*math.tau/24),.035+j*.025) for i in range(25)]
            root_curve(pts,.018,m['oil'],r,'Coiled armoured cable')
        root_curve([(.40,0,.06),(.45,-.24,.035),(.16,-.40,.035),(-.37,-.33,.035)],.026,m['iron'],r,'Severed cable')
    elif name=='catwalk':
        for x in (-.64,.64):box('Catwalk I girder',(x,0,.10),(.09,1.85,.20),m['iron'],r)
        for j in range(22):box('Open tread grating',(0,-.87+j*.083,.22),(1.34,.028,.035),m['rust'],r,.004)
        for x in (-.64,.64):
            for y in (-.85,0,.85):rod('Rail stanchion',(x,y,.20),(x,y,.84),.022,m['iron'],r)
            rod('Hand rail',(x,-.90,.84),(x,.90,.84),.025,m['brass'],r)
    elif name=='ticket_booth':
        box('Municipal toll booth',(0,0,.60),(.88,.70,1.18),m['enamel'],r,.02)
        for x in (-.44,.44):box('Riveted booth post',(x,-.36,.63),(.06,.05,1.25),m['rust'],r)
        box('Tarred booth roof',(0,0,1.28),(1.04,.88,.10),m['iron'],r)
        box('Deep ticket window',(0,-.358,.87),(.60,.015,.44),m['oil'],r,.004)
        for x in (-.25,-.125,0,.125,.25):rod('Window bars',(x,-.38,.66),(x,-.38,1.08),.012,m['brass'],r)
        box('Ticket counter',(0,-.45,.62),(.73,.23,.055),m['brass'],r)
        box('Oxidised service plaque',(0,-.375,.34),(.32,.025,.14),m['rust'],r)

def build():
    OUT.mkdir(parents=True,exist_ok=True);SRC.mkdir(parents=True,exist_ok=True)
    only=sys.argv[sys.argv.index('--only')+1] if '--only' in sys.argv else None
    bpy.context.preferences.filepaths.save_version=0
    for name,(sz,fy) in SPECS.items():
        if only and name!=only:continue
        s=rig.create_rig('MAP',(sz,sz));s.eevee.taa_render_samples=16
        s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(fy-sz/2)/rig.R,0))
        sun=bpy.data.objects['Sun_chaud_haut_gauche'];sun.location=s.camera.rotation_euler.to_matrix()@Vector((-4,9,8));sun.rotation_euler=(-sun.location).to_track_quat('-Z','Y').to_euler()
        r=C.empty(name);m=materials()
        if name.startswith('crate'):crate(r,m)
        elif name=='barrels':barrels(r,m)
        elif name=='valve':valve(r,m)
        elif name=='pipe_stub':pipe(r,m)
        elif name=='debris':debris(r,m)
        elif 'lamp' in name:lamp(r,m)
        elif name.startswith('tank'):tank(r,m,name=='tank_small')
        else:legacy(name,r,m)
        if name.endswith('_se') or name in ('crate','steam_lamp'):r.rotation_euler.z=math.pi/2
        if name=='steam_lamp':r.scale=(.57,.57,.57)
        rig.bake_ao_shadows(r);bpy.context.view_layer.update()
        # Mesh and evaluated curves: measure complete projected and ground envelopes.
        points=[];deps=bpy.context.evaluated_depsgraph_get()
        for ob in r.children_recursive:
            if ob.type not in ('MESH','CURVE'):continue
            ev=ob.evaluated_get(deps);geo=ev.to_mesh();points.extend(ev.matrix_world@v.co for v in geo.vertices);ev.to_mesh_clear()
        ground=[p for p in points if p.z<.16];q=world_to_camera_view(s,s.camera,Vector((0,0,0)))
        globe=world_to_camera_view(s,s.camera,r.matrix_world@Vector((.43,0,1.81)))
        check=dict(name=name,foot=[round(q.x*sz,4),round((1-q.y)*sz,4)],px_per_u=90.51,footprint=[round(max(p[i] for p in ground)-min(p[i] for p in ground),4) for i in (0,1)],envelope=[round(max(p[i] for p in points)-min(p[i] for p in points),4) for i in (0,1)],height_u=round(max(p.z for p in points),4),rig='MAP',yaw=45,elevation=30)
        check['fade']=name in ('steam_lamp_se','steam_lamp_sw','tank_large')
        if 'lamp' in name:check.update(globe_px=[round(globe.x*sz,3),round((1-globe.y)*sz,3)],globe_height_px=round((globe.y-q.y)*sz,3),globe_height_u=round(1.81*(.57 if name=='steam_lamp' else 1),4))
        if name in SHADOWS:check.update(shadow_rig='TOP',shadow_px_per_u=128)
        (SRC/('f3p_'+name+'_check.json')).write_text(json.dumps(check,indent=2))
        rig.render_frame(OUT/(name+'.png'))
        if 'lamp' not in name:(OUT/(name+'_e.png')).unlink(missing_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(SRC/('f3p_'+name+'.blend')))
        if name in SHADOWS:
            rot=sun.rotation_euler.copy();rig.create_rig('TOP',(512,512),reset=False);sun.rotation_euler=rot
            rig.render_shadow_decal(r,OUT/(name+'_shadow.png'))
        print('F3P DONE '+name,flush=True)
    if all((OUT/(n+'.png')).exists() for n in LIMITS):
        props=[dict(name=n,weight=w,foot=[SPECS[n][0]//2,SPECS[n][1]],px_per_u=90.51,fade=n=='tank_large',**({'shadow_rig':'top'} if n in SHADOWS else {})) for n,w in WEIGHTS]
        (OUT/'props.json').write_text(json.dumps(dict(density=.05,props=props),indent=2)+'\n')
    print('F3P BUILD COMPLETE',flush=True)

if __name__=='__main__':build()
