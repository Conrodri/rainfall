"""C8 MAP assets. Python --inventory/--verify/--contact; Blender builds by default.
Reuses C0 iso_rig and official boss material/geometry/pass implementation.
"""
import sys, json, math, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
INV=HERE/'_c8_inventory.json'
SPR=ROOT/'game/assets/sprites'

def files():
    return sorted(list((SPR/'chests').glob('chest_*/*.png'))+list((SPR/'props').glob('pillar_*.png'))+list((SPR/'props').glob('teleporter_*.png'))+list((SPR/'props/gold_capsule').glob('*.png')))

def inventory():
    from PIL import Image
    rows=[]
    for p in files():
        if '_sw' in p.stem or p.stem.endswith('_shadow'): continue
        im=Image.open(p); w,h=im.size
        rows.append(dict(path=str(p.relative_to(ROOT)).replace('\\','/'),size=[w,h],columns=w//h,frame=[h,h],bbox=im.getbbox(),sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
    protected={str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for base in [SPR/'chests',SPR/'props'] for p in base.rglob('*') if p.suffix in ('.tres','.import')}
    data=dict(rig='MAP',elevation=30,yaw=45,px_per_u=64,note='64 px/u, explicitly overriding C0 R=90.50966799; unchanged game scale. Default = se (+X front, model +90 deg); sw = -Y front (model 0 deg), never mirrored.',assets=rows,protected=protected,verification='pending',pivots={},contact='3x3 C1 ground_a with C4 Ardent; all resized by the same physical px/u ratio')
    INV.write_text(json.dumps(data,indent=2),encoding='utf8');print('PASS inventory:',len(rows),'original PNGs')

def verify():
    from PIL import Image
    d=json.loads(INV.read_text()); errors=[]
    for a in d['assets']:
        p=ROOT/a['path']; im=Image.open(p)
        if list(im.size)!=a['size']:errors.append(p.name+' size')
        if hashlib.sha256(p.read_bytes()).hexdigest()==a['sha256']:errors.append(p.name+' unchanged')
        if im.mode!='RGBA':errors.append(p.name+' RGBA')
        if not p.stem.endswith(('_e','_n')):
            for i in range(a['columns']):
                f=im.crop((i*im.height,0,(i+1)*im.height,im.height));box=f.getchannel('A').point(lambda v:255 if v>24 else 0).getbbox()
                if not box or min(box[0],box[1],im.height-box[2],im.height-box[3])<3:errors.append(p.name+' clipped')
            if a['columns']>1:
                hashes={hashlib.sha256(im.crop((i*im.height,0,(i+1)*im.height,im.height)).tobytes()).hexdigest() for i in range(a['columns'])}
                if len(hashes)!=a['columns']:errors.append(p.name+' duplicated frames')
        if 'chests/' in a['path'] or 'teleporter_' in p.name:
            q=p.with_name(p.stem+'_sw.png')
            if not q.exists() or Image.open(q).size!=im.size:errors.append(q.name+' orientation')
        if p.stem.endswith('_e'):
            if max(c.getextrema()[1] for c in im.split()[:3])==0:errors.append(p.name+' black emission')
    for rel,h in d['protected'].items():
        if hashlib.sha256((ROOT/rel).read_bytes()).hexdigest()!=h:errors.append(rel+' protected modified')
    d['verification']='PASS' if not errors else 'FAIL';d['errors']=errors
    INV.write_text(json.dumps(d,indent=2),encoding='utf8');print(d['verification'],len(d['assets']),'original PNG contracts;',len(errors),'errors',errors[:6])

def contact():
    from PIL import Image
    d=json.loads(INV.read_text()); items=[a for a in d['assets'] if not Path(a['path']).stem.endswith(('_n','_e'))]
    expanded=[]
    for a in items:
        expanded.append((a,''))
        if 'chests/' in a['path'] or 'teleporter_' in a['path']:expanded.append((a,'_sw'))
    # R=48 contact: C1 and C4 use 90.5097, C8 uses 64. One common world scale.
    r=48; tile=Image.open(SPR/'terrain/terraces/iso/ground_a.png').convert('RGBA');tile=tile.resize((round(tile.width*r/(64*math.sqrt(2))),round(tile.height*r/(64*math.sqrt(2)))),Image.Resampling.LANCZOS)
    ard=Image.open(SPR/'characters/ardent/idle.png').convert('RGBA').crop((0,192,192,384));ard=ard.resize((round(192*r/(64*math.sqrt(2))),)*2,Image.Resampling.LANCZOS)
    cw,ch=850,480; cols=4
    board=Image.new('RGBA',(cols*cw,math.ceil(len(expanded)/cols)*ch),(19,25,28,255))
    for idx,(a,suffix) in enumerate(expanded):
        ox=(idx%cols)*cw;oy=(idx//cols)*ch;cx=ox+cw//2;cy=oy+250
        for i,j in sorted(((i,j) for i in range(-1,2) for j in range(-1,2)),key=lambda v:v[0]+v[1]):
            x=round(cx+(i-j)*tile.width/2);y=round(cy+(i+j)*tile.height/2)
            board.alpha_composite(tile,(x-tile.width//2,y-tile.height//2))
        p=ROOT/a['path'];p=p.with_name(p.stem+suffix+'.png');im=Image.open(p).convert('RGBA').crop((0,0,a['frame'][0],a['frame'][1]));sz=im.height
        im=im.resize((round(sz*r/64),)*2,Image.Resampling.LANCZOS)
        pivot=d['pivots'][a['path']]
        board.alpha_composite(im,(cx-round(pivot[0]*r/64),cy-round(pivot[1]*r/64)))
        # C4 origin is at 62% of its frame (documented C0 CREA rig).
        board.alpha_composite(ard,(cx-125-ard.width//2,cy+36-round(ard.height*.62)))
        label=str(p.relative_to(SPR)).replace('\\','/')
    board.convert('RGB').save(HERE/'_c8_contact.png',optimize=True);print('PASS contact:',len(expanded),'panels')

if __name__=='__main__' and '--inventory' in sys.argv:inventory();sys.exit()
if __name__=='__main__' and '--verify' in sys.argv:verify();sys.exit()
if __name__=='__main__' and '--contact' in sys.argv:contact();sys.exit()

import bpy
sys.path.insert(0,str(HERE))
import iso_rig as rig
C=rig.common
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
from PIL import Image

def color(h):
    vals=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals)

def mat(n,h,metal=0,rough=.6,emit=0):
    m=C.material(n,color(h),metal,rough,emit,grain=not emit)
    if not emit:
        nt=m.node_tree;p=nt.nodes.get('Principled BSDF');noise=next(x for x in nt.nodes if x.type=='TEX_NOISE')
        ramp=nt.nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.22;ramp.color_ramp.elements[0].color=tuple(v*.38 for v in color(h))+(1,)
        ramp.color_ramp.elements[1].position=.78;ramp.color_ramp.elements[1].color=tuple(min(1,v*1.5) for v in color(h))+(1,)
        nt.links.new(noise.outputs['Fac'],ramp.inputs[0]);nt.links.new(ramp.outputs[0],p.inputs['Base Color'])
    return m

def box(n,loc,dim,m,p):return C.box(n,loc,dim,m,p,bevel=.012)
def cyl(n,loc,r,h,m,p,verts=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=h,location=loc)
    return C.finish(bpy.context.object,n,m,p,.008)

def chest(root,name,pose,M):
    # The long body is aligned to X; front -Y is screen SE in the fixed MAP rig.
    w=1.03 if 'small' in name else 1.12;depth=.75;z=.49
    box('Iron bottom tray',(0,0,.10),(w+.07,depth+.06,.13),M['iron'],root)
    for i in range(5):box('Wet oak stave',((i-2)*w/5,0,.34),(w/5-.012,depth,.42),M['wood'],root)
    box('Black interior',(0,0,.48),(w-.08,depth-.09,.025),M['dark'],root)
    for x in (-w*.40,w*.40):
        for y in (-depth/2,depth/2):
            box('Corner iron strap',(x,y,.32),(.065,.036,.51),M['iron'],root)
            for zz in (.15,.40):C.sphere('Rivet',(x,y*1.055,zz),(.024,.012,.024),M['brass'],root)
    hinge=C.empty('Lid hinge',(0,depth/2,z),root)
    for j in range(5):box('Lid planks',((j-2)*w/5,-depth/2,.075),(w/5-.008,depth,.14),M['wood'],hinge)
    for x in (-w*.40,w*.40):
        box('Lid patinated straps',(x,-depth/2,.155),(.072,depth+.04,.035),M['bronze'],hinge)
        box('Clasp',(x,-depth-.02,.04),(.075,.05,.18),M['bronze'],hinge)
        for yy in (-.12,-.52,-.69):C.sphere('Lid rivet',(x,yy,.18),(.022,)*3,M['brass'],hinge)
    box('Lock escutcheon',(0,-depth/2-.035,.40),(.16,.045,.20),M['bronze'],root)
    box('Key recess',(0,-depth/2-.063,.40),(.024,.01,.075),M['dark'],root)
    if 'legendary' in name:
        for x in (-.32,.32):
            box('Ember slit',(x,-depth/2-.025,.30),(.075,.018,.045),M['glow'],root)
            box('Bronze edging',(x,0,.47),(.025,depth,.03),M['bronze'],root)
        box('Seal ember',(0,-depth-.028,.10),(.045,.01,.035),M['glow'],hinge)
    hinge.rotation_euler.x=math.radians(-105) if pose=='open' else 0

def pillar(root,name,frame,M):
    k=1.76 if 'large' in name else 1.;active='active' in name;on='off' not in name
    # Square plinths and four equal faces establish the map's two diagonals.
    def b(n,loc,dim,m):return box(n,tuple(v*k for v in loc),tuple(v*k for v in dim),m,root)
    b('Footing',(0,0,.09),(.71,.71,.18),M['stone']);b('Base moulding',(0,0,.22),(.57,.57,.09),M['bronze'])
    b('Carved wet stone shaft',(0,0,.72),(.37,.37,.94),M['stone'])
    for x in (-1,1):
        for y in (-1,1):b('Fluted corner rail',(x*.205,y*.205,.73),(.044,.044,.87),M['bronze'])
    for z in (.33,1.13):b('Oxidized collar',(0,0,z),(.48,.48,.075),M['iron'])
    b('Crown',(0,0,1.28),(.59,.59,.18),M['bronze'])
    b('Crown recess',(0,0,1.381),(.42,.42,.025),M['dark'])
    for x in (-1,1):
        for y in (-1,1):b('Crown tooth',(x*.225,y*.225,1.44),(.075,.075,.28),M['iron'])
    phase=math.tau*frame/8
    if on:
        gm=M['glow']
        for side in (-1,1):
            b('Recessed rune',(0,side*.191,.78),(.055,.018,.25),gm)
            b('Recessed rune',(side*.191,0,.78),(.018,.055,.25),gm)
        b('Crown core',(0,0,1.40+.017*math.sin(phase)),(.18,.18,.045),gm)
        if active:
            for side in (-1,1):
                pts=[(side*(.17*(1-t)+.025*math.sin(phase+q*1.3))*k,.025*math.cos(q+phase)*k,(1.47+t*.20)*k) for q in range(6) for t in [q/5]]
                C.tube('Confined electric arc',pts,.009*k,gm,root)

def teleporter(root,name,M):
    box('Square drowned plinth',(0,0,.09),(1.75,1.75,.18),M['stone'],root)
    box('Bronze threshold',(0,0,.21),(1.56,1.56,.09),M['bronze'],root)
    box('Recessed flagstone',(0,0,.27),(1.34,1.34,.04),M['dark'],root)
    active='active' in name
    for x in (-1,1):
        for y in (-1,1):
            box('Corner anchor',(x*.70,y*.70,.30),(.16,.16,.13),M['iron'],root)
            cyl('Anchor rivet',(x*.7,y*.7,.375),.035,.02,M['brass'],root)
    for x in (-.47,-.22,.22,.47):box('Threshold rune',(x,-.66,.30),(.055,.14,.018),M['glow'],root)
    # Directional entrance at -Y; rear pylons are present in both states.
    for x in (-.68,.68):
        box('Rear socket',(x,.52,.39),(.28,.30,.25),M['stone'],root)
        if active:
            box('Gate monolith',(x,.52,.98),(.17,.19,1.16),M['bronze'],root)
            box('Inner blue conduit',(x*.86,.40,1.0),(.027,.02,1.03),M['glow'],root)
            for zz in (.55,1.10,1.44):box('Gate iron collars',(x,.52,zz),(.22,.23,.065),M['iron'],root)
    if active:
        box('Gate lintel',(0,.52,1.60),(1.53,.22,.18),M['bronze'],root)
        for z in (.63,.95,1.27):C.tube('Contained portal filament',[(-.48,.50,z),(0,.50,z+.08),(.48,.50,z-.03)],.008,M['glow'],root)

def capsule(root,pose,M):
    # Small collectible vessel, retaining the original compact screen footprint.
    cyl('Foot iron', (0,0,.035),.23,.07,M['iron'],root)
    cyl('Fluted vessel',(0,0,.30),.205,.50,M['bronze'],root)
    for z in (.10,.47):cyl('Banded iron',(0,0,z),.224,.045,M['iron'],root)
    for i in range(12):
        a=i*math.tau/12;box('Vertical chased ridge',(.207*math.cos(a),.207*math.sin(a),.29),(.018,.018,.30),M['brass'],root)
    cyl('Dark mouth',(0,0,.56),.185,.025,M['dark'],root)
    if pose=='closed':
        cyl('Sealed lid',(0,0,.585),.23,.065,M['bronze'],root)
        cyl('Gold seal',(0,0,.626),.073,.02,M['glow'],root)
    else:
        # Rotational symmetry is maintained by an elevated coaxial lid.
        cyl('Raised lid',(0,0,.77),.23,.055,M['bronze'],root)
        cyl('Exposed seal',(0,0,.59),.09,.018,M['glow'],root)
        for i in range(4):
            a=i*math.pi/2;C.rod('Lid retention pin',(.17*math.cos(a),.17*math.sin(a),.54),(.17*math.cos(a),.17*math.sin(a),.76),.012,M['iron'],root)

def old_pivots(d):
    # Exact origins from original Blender cameras, before creating replacement scenes.
    result={}
    for n in ('teleporter_idle','teleporter_active'):
        p=ROOT/f'art/blender/terrain/props_{n}.blend'
        bpy.ops.wm.open_mainfile(filepath=str(p));s=bpy.context.scene;bpy.context.view_layer.update()
        v=world_to_camera_view(s,s.camera,Vector((0,0,0)));result[n]=[v.x*256,(1-v.y)*256]
    for a in d['assets']:
        p=Path(a['path']);size=a['frame'][0]
        if 'chests/' in a['path']:pivot=[64,89.6]
        elif 'pillar_small' in p.name:pivot=[64,128*(.5+.44/1.8)]
        elif 'pillar_large' in p.name:pivot=[128,256*(.5+.74/3.4)]
        elif 'teleporter_' in p.name:pivot=result['teleporter_active' if 'active' in p.name else 'teleporter_idle']
        else:pivot=[64,76.8] # Delivered capsule atlas is centered at 60%; raw rig FOOT was rescaled by pack.
        d['pivots'][a['path']]=pivot
    return d

def build():
    d=json.loads(INV.read_text());d=old_pivots(d);INV.write_text(json.dumps(d,indent=2),encoding='utf8')
    bases=[a for a in d['assets'] if not Path(a['path']).stem.endswith(('_n','_e'))]
    bpy.context.preferences.filepaths.save_version=0
    for a in bases:
        path=ROOT/a['path'];name=path.parent.name if path.parent.name.startswith('chest_') or path.parent.name=='gold_capsule' else path.stem
        pose=path.stem;sz=a['frame'][0];n=a['columns'];asym=name.startswith('chest') or name.startswith('teleporter')
        for orient in (['se','sw'] if asym else ['se']):
            outputs={s:[] for s in ('','_n','_e','_shadow')}
            for f in range(n):
                s=rig.create_rig('MAP',(sz,sz));s.camera.data.ortho_scale=sz/64
                s.eevee.taa_render_samples=16
                # Exact original pixel pivot, unchanged for every orientation and animation frame.
                pivot=d['pivots'][a['path']];up=s.camera.rotation_euler.to_matrix()@Vector((0,1,0));s.camera.location+=up*((pivot[1]-sz/2)/64)
                s.camera.data.shift_x=0;s.camera.data.shift_y=0
                M={k:mat(k,h,met,rough) for k,h,met,rough in [('stone','333E40',0,.38),('iron','2B2A29',.6,.5),('bronze','5F8F80',.65,.5),('brass','A8946E',.65,.48),('wood','362A23',0,.7),('dark','101719',0,.9)]}
                warm='legendary' in name or name=='gold_capsule'
                M['glow']=mat('Ember' if warm else 'Cold blue','FF7A1F' if warm else ('A7C4D5' if 'done' in name else '68B9DE'),.1,.4,2.3 if 'idle' not in name else .45)
                root=C.empty('C8_'+name)
                if name.startswith('chest'):chest(root,name,pose,M)
                elif name.startswith('pillar'):pillar(root,name,f,M)
                elif name.startswith('teleporter'):teleporter(root,name,M)
                else:capsule(root,pose,M)
                if name.startswith('chest'):root.scale=(1.02,1.02,.82)
                elif name.startswith('pillar'):root.scale.z=.70
                if asym:root.rotation_euler.z=math.pi/2 if orient=='se' else 0
                rig.bake_ao_shadows(root)
                # Physical, soft contact decal: shader radial falloff rendered in Blender.
                bpy.ops.mesh.primitive_plane_add(size=1,location=(0,0,.001));foot=bpy.context.object;foot.name='Baked ground contact'
                radius=.48 if name.startswith('chest') else .42 if 'small' in name else .90 if name.startswith('teleporter') else .69 if name.startswith('pillar') else .25
                foot.scale=(radius*2,radius*1.7,1)
                m=bpy.data.materials.new('Contact AO');m.use_nodes=True;nt=m.node_tree;nt.nodes.clear()
                out=nt.nodes.new('ShaderNodeOutputMaterial');mix=nt.nodes.new('ShaderNodeMixShader');trans=nt.nodes.new('ShaderNodeBsdfTransparent');em=nt.nodes.new('ShaderNodeEmission');em.inputs[0].default_value=(.006,.009,.01,1)
                uv=nt.nodes.new('ShaderNodeTexCoord');dist=nt.nodes.new('ShaderNodeVectorMath');dist.operation='DISTANCE';dist.inputs[1].default_value=(.5,.5,0)
                nt.links.new(uv.outputs['UV'],dist.inputs[0]);ramp=nt.nodes.new('ShaderNodeMapRange');ramp.inputs['From Min'].default_value=.12;ramp.inputs['From Max'].default_value=.5;ramp.inputs['To Min'].default_value=.56;ramp.inputs['To Max'].default_value=0
                nt.links.new(dist.outputs['Value'],ramp.inputs[0]);nt.links.new(ramp.outputs[0],mix.inputs[0]);nt.links.new(trans.outputs[0],mix.inputs[1]);nt.links.new(em.outputs[0],mix.inputs[2]);nt.links.new(mix.outputs[0],out.inputs[0]);foot.data.materials.append(m)
                foot.hide_render=True
                dest=path.with_name(path.stem+('_sw' if orient=='sw' else '')+'.png')
                if f==0:
                    foot.hide_render=False
                    s['c8_px_per_u']=64;s['c8_pivot']=pivot;s['c8_orientation']=orient
                    blend=ROOT/'art/blender/props'/f'c8_{name}_{pose}_{orient}.blend';blend.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(blend))
                # Frames kept in memory and assembled only after every Blender pass is rendered.
                foot.hide_render=True
                rig.render_frame(dest,passes=True)
                for suffix in ('','_n','_e'):
                    p=dest.with_name(dest.stem+suffix+'.png')
                    if p.exists():outputs[suffix].append(Image.open(p).convert('RGBA').copy())
                # Contact-only render is composited into beauty; no normal/emission contamination.
                hidden=[o for o in s.objects if o.type in ('MESH','CURVE') and o!=foot]
                for ob in hidden:ob.hide_render=True
                foot.hide_render=False;rig.render_frame(dest.with_name(dest.stem+'_shadow.png'),passes=False)
                shadow=Image.open(dest.with_name(dest.stem+'_shadow.png')).convert('RGBA')
                outputs[''][-1]=Image.alpha_composite(shadow,outputs[''][-1])
                for ob in hidden:ob.hide_render=False
                foot.hide_render=True
                rig.render_shadow_decal(root,dest)
                cast=Image.open(dest.with_name(dest.stem+'_shadow.png')).convert('RGBA')
                outputs['_shadow'].append(Image.alpha_composite(cast,shadow))
            for suffix,frames in outputs.items():
                if not frames:continue
                # Preserve original auxiliary pass inventory; add only matching SW and shadow sheets.
                original=path.with_name(path.stem+suffix+'.png')
                target=path.with_name(path.stem+suffix+('_sw' if orient=='sw' else '')+'.png')
                temp=path.with_name(path.stem+('_sw' if orient=='sw' else '')+suffix+'.png')
                if suffix not in ('','_shadow') and not any(x['path']==str(original.relative_to(ROOT)).replace('\\','/') for x in d['assets']):
                    if temp.exists():temp.unlink()
                    continue
                if len(frames)!=n:raise RuntimeError('Missing pass '+str(target))
                sheet=Image.new('RGBA',(sz*n,sz))
                for i,im in enumerate(frames):sheet.paste(im,(i*sz,0))
                sheet.save(target,optimize=True,compress_level=9)
                if temp!=target and temp.exists():temp.unlink()
    print('PASS C8 render complete')

if __name__=='__main__':build()
