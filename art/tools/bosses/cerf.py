"""Cerf-Lanterne. Blender 5.2 --background --python cerf.py -- [--anims ...].
All geometry, transparency, animation and lighting are produced by Blender.
"""
import sys, math, argparse
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from boss_common import *
OUT=ROOT/'art/renders/bosses/cerf'
SPECS={**{f'idle_p{p}':(6,['s'],p,256) for p in (1,2,3)},
       **{f'walk_p{p}':(8,['e','s','w','n'],p,256) for p in (1,2,3)},
       **{a:(n,['s'],p,256) for a,n,p in [('auto',6,1),('spell_a',8,1),('spell_b',8,1),('trans_p2',8,1),('trans_p3',8,2),('death',10,3),('vanish',8,3),('reappear',8,3),('antlers',6,1),('ground_mist',6,0)]},
       **{a:(n,['s'],0,64) for a,n in [('wisp',6),('wisp_explode',8),('ground_wisp_trail',6)]}}

def linear(h):
    c=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c)

def fade_material(mat, spectral=False, opacity=1):
    mat.surface_render_method='BLENDED'
    n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF');out=n.get('Material Output')
    trans=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader')
    value=n.new('ShaderNodeValue');value.name='Visibility';value.outputs[0].default_value=opacity
    fac=value.outputs[0]
    if spectral:
        layer=n.new('ShaderNodeLayerWeight');mul=n.new('ShaderNodeMath');mul.operation='MULTIPLY_ADD';mul.inputs[1].default_value=.62;mul.inputs[2].default_value=.20
        # Facing=0 at face-on, 1 at grazing: fade the silhouette edges.
        inv=n.new('ShaderNodeMath');inv.operation='SUBTRACT';inv.inputs[0].default_value=1;l.new(layer.outputs['Facing'],inv.inputs[1])
        l.new(inv.outputs[0],mul.inputs[0])
        amount=n.new('ShaderNodeValue');amount.name='Spectral';amount.outputs[0].default_value=0
        delta=n.new('ShaderNodeMath');delta.operation='SUBTRACT';l.new(mul.outputs[0],delta.inputs[0]);delta.inputs[1].default_value=1
        interp=n.new('ShaderNodeMath');interp.operation='MULTIPLY_ADD';l.new(delta.outputs[0],interp.inputs[0]);l.new(amount.outputs[0],interp.inputs[1]);interp.inputs[2].default_value=1
        mult=n.new('ShaderNodeMath');mult.operation='MULTIPLY';l.new(interp.outputs[0],mult.inputs[0]);l.new(fac,mult.inputs[1]);fac=mult.outputs[0]
    l.new(fac,mix.inputs[0]);l.new(trans.outputs[0],mix.inputs[1]);l.new(p.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs[0])
    return value.outputs[0]

def soften_mist(mat):
    """Noise-modulated grazing transparency, entirely in the Blender shader."""
    n=mat.node_tree.nodes;l=mat.node_tree.links
    mix=next(o for o in n if o.type=='MIX_SHADER');old=mix.inputs[0].links[0].from_socket
    tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=4;tex.inputs['Detail'].default_value=3
    layer=n.new('ShaderNodeLayerWeight');mul=n.new('ShaderNodeMath');mul.operation='MULTIPLY'
    l.new(tex.outputs['Fac'],mul.inputs[0]);l.new(layer.outputs['Facing'],mul.inputs[1])
    mult=n.new('ShaderNodeMath');mult.operation='MULTIPLY';l.new(old,mult.inputs[0]);l.new(mul.outputs[0],mult.inputs[1]);l.new(mult.outputs[0],mix.inputs[0])

def build(phase=1):
    root=empty('CERF_ROOT');root['height_u']=3.2;root['phase']=phase
    coat=material('Pelage ecorce sombre',linear('303A36'),roughness=.74,grain=True)
    ridge=material('Cretes du pelage',linear('546257'),roughness=.8)
    bone=material('Bois ancien',linear('716347'),roughness=.8,grain=True)
    brass=material('Fer patine des cages',linear('3F5A50'),metallic=.5,roughness=.4)
    hoof=material('Sabots noirs',linear('202A29'),roughness=.4)
    flame=material('Flamme #9CF0C8',linear('9CF0C8'),emission=1.0);flame.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(0,0,0,1)
    eyes=material('Yeux pales',linear('D2FFE4'),emission=1.2)
    mats=[coat,ridge,bone,brass,hoof,flame,eyes]
    visibility=[fade_material(m,True) for m in mats]
    torso=empty('Thorax',(0,.12,1.54),root)
    sphere('Cage thoracique',(0,0,0),(.45,.72,.57),coat,torso)
    sphere('Croupe',(0,.56,-.04),(.41,.36,.44),coat,torso)
    sphere('Poitrine',(0,-.43,.08),(.51,.36,.65),coat,torso)
    # Overlapping bark plates give the chest a carved, ancient silhouette.
    for side in (-1,1):
        for j in range(4):
            ob=sphere('Ecorce scapulaire',(side*(.36-j*.025),-.38+j*.20,.22-j*.035),(.14,.28,.34-j*.035),ridge,torso)
            ob.rotation_euler.y=side*.40
        tube('Nervure de poitrine',[(side*.37,-.57,.30),(side*.23,-.72,.03),(side*.12,-.58,-.40)],.027,bone,torso)
    tube('Crete dorsale',[(0,.76,.20),(0,.3,.46),(0,-.26,.48)],.043,ridge,torso)
    tail=empty('Queue pivot',(0,.82,.1),torso)
    sphere('Queue',(0,.15,-.05),(.09,.25,.12),ridge,tail)
    neck=empty('Cou pivot',(0,-.49,.22),torso)
    ob=sphere('Cou haut',(0,-.12,.35),(.31,.30,.60),coat,neck);ob.rotation_euler.x=-.28
    for j in range(5):
        ob=sphere('Criniere',(0,.10,.12+j*.13),(.24-j*.018,.16,.15),ridge,neck)
    head=empty('Tete pivot',(0,-.27,.83),neck)
    sphere('Crane',(0,-.03,0),(.27,.32,.26),coat,head)
    sphere('Museau long',(0,-.33,-.09),(.16,.30,.135),ridge,head)
    sphere('Truffe',(0,-.57,-.08),(.14,.09,.09),hoof,head)
    sphere('Chanfrein osseux',(0,-.23,.09),(.095,.30,.07),bone,head)
    for side in (-1,1):
        tube('Joue gravee',[(side*.21,-.10,.02),(side*.18,-.27,-.10),(side*.10,-.43,-.13)],.025,bone,head)
    for j in range(5):
        x=(j-2)*.057
        tube('Barbe de lichen',[(x,-.20,-.17),(x*1.3,-.22,-.32),(x*.8,-.15,-.50+abs(j-2)*.06)],.026,ridge,head)
    for side in (-1,1):
        ear=empty('Oreille pivot',(side*.18,.06,.12),head)
        ob=sphere('Oreille feuille',(side*.18,.02,.06),(.27,.105,.085),coat,ear);ob.rotation_euler.y=-side*.3
        ob=sphere('Oreille interieur',(side*.19,-.04,.075),(.18,.035,.045),ridge,ear);ob.rotation_euler.y=-side*.3
        sphere('Oeil pale',(side*.194,-.18,.045),(.054,.071,.048),eyes,head)
        tube('Sourcil',[(side*.18,-.25,.12),(side*.245,-.15,.14),(side*.22,-.07,.11)],.028,bone,head)
    crown=empty('RAMURE',(0,.015,.17),head)
    cages=[];flames=[];antler_objects=[];phase_branches=[];ghost_ribs=[]
    for side in (-1,1):
        pts=[(side*.12,.03,0),(side*.37,.14,.22),(side*.72,.28,.40),(side*1.08,.40,.49)]
        antler_objects.append(tube('Merrain ramifie',pts,.052,bone,crown))
        # Tall forked tines make the crown readable independently of the lanterns.
        for j in range(3):
            x=side*(.36+j*.32);y=.16+j*.10;z=.22+j*.09
            tube('Bois en fleche',[(x,y,z),(x+side*.10,y+.05,z+.25),(x+side*.04,y+.09,z+.45-j*.04)],.031,bone,crown)
            branch=tube('Ramure de brume',[(x,y,z),(x+side*.22,y-.12,z+.22),(x+side*.29,y-.13,z+.43)],.025,bone,crown)
            phase_branches.append(branch)
        for j in range(3):
            x=side*(.40+j*.33);y=-.12+j*.24;z=.29+j*.10
            antler_objects.append(tube('Andouiller',[(side*(.26+j*.29),.14+j*.10,.18+j*.09),(x,y,z+.08)],.035,bone,crown))
            cage=empty('Lanterne pivot',(x,y,z+.03),crown);cages.append(cage)
            r=.15;h=.36
            for zz in (-h/2,h/2):
                antler_objects.append(ring('Cercle laiton',(0,0,zz),r,.018,brass,cage,rotation=(0,0,0)))
            antler_objects.append(tube('Anse suspendue',[(0,0,h/2+.04),(0,0,h/2+.13),(.04,0,h/2+.18)],.012,brass,cage))
            antler_objects.append(tube('Pointe de lanterne',[(0,0,-h/2),(0,0,-h/2-.10)],.025,brass,cage))
            for k in range(4):
                a=math.tau*k/4+math.pi/4
                antler_objects.append(rod('Montant cage',(r*math.cos(a),r*math.sin(a),-h/2),(r*math.cos(a),r*math.sin(a),h/2),.015,brass,cage))
            bpy.ops.mesh.primitive_cone_add(vertices=6,radius1=.11,radius2=.03,depth=.07,location=(0,0,h/2+.04))
            antler_objects.append(finish(bpy.context.object,'Toit de lanterne',brass,cage))
            f=empty('Flamme pivot',parent=cage);flames.append(f)
            antler_objects.append(sphere('Coeur lumineux',(0,0,-.03),(.11,.11,.15),flame,f))
            ob=sphere('Langue de flamme',(.018,0,.065),(.05,.052,.16),flame,f);ob.rotation_euler.y=.25;antler_objects.append(ob)
    legs=[]
    for front in (True,False):
        for side in (-1,1):
            leg=empty('Hanche '+str((front,side)),(side*.27,-.37 if front else .59,-.16),torso)
            rod('Cuisse',(0,0,0),(0,.09,-.56),.125 if front else .155,coat,leg)
            sphere('Genou',(0,.09,-.56),(.085,.085,.095),ridge,leg)
            shin=empty('Tibia pivot',(0,.09,-.56),leg)
            rod('Canon fin',(0,0,0),(0,-.10,-.68),.06,coat,shin)
            for sx in (-1,1):box('Sabot fendu',(sx*.04,-.14,-.74),(.075,.24,.16),hoof,shin,.018)
            legs.append((leg,shin,front,side))
    for side in (-1,1):
        for j in range(4):
            rib=tube('Cote spectrale',[(side*.12,-.24+j*.20,.34),(side*.43,-.24+j*.20,.12),(side*.34,-.24+j*.20,-.24)],.027,bone,torso)
            ghost_ribs.append(rib)
        for j in range(3):
            trail=tube('Lambeau spectral',[(side*.25,.45+j*.09,.05-j*.12),(side*.43,.82+j*.13,-.08-j*.16),(side*.27,1.10+j*.13,-.30-j*.16)],.040,ridge,torso)
            ghost_ribs.append(trail)
    mistmat=material('Brume #B8C8C0',linear('B8C8C0'),roughness=1,emission=.12)
    mistvis=fade_material(mistmat,False,.10)
    soften_mist(mistmat)
    mist=[]
    for j in range(12):
        a=j*2.39996;r=.4+(j%4)*.15
        ob=sphere('Brume basse',(math.cos(a)*r,math.sin(a)*r,.09+(j%3)*.035),(.43,.28,.065),mistmat,root);mist.append(ob)
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in root.children_recursive}
    def state(p):
        # Continuous phase states, with changes to geometry as well as materials.
        q=min(1,max(0,p-1));spect=min(1,max(0,p-2))
        for ob in phase_branches:
            ob.hide_render=q<.01
            ob.scale=(q,)*3
        for ob in ghost_ribs:
            ob.hide_render=spect<.01
            ob.scale=(spect,)*3
        crown.scale=(1+.08*q+.05*spect,1,1+.08*q+.10*spect)
        torso.scale=(1-.12*spect,1,1+.05*spect)
        for m in mats:m.node_tree.nodes['Spectral'].outputs[0].default_value=spect
        for c in cages:c.scale=(1+.36*q-.17*spect,)*3
        for f in flames:f.scale=(max(.04,1-.94*spect),)*3
        for m,col in [(coat,'A1B6AE'),(ridge,'C0D1C7'),(bone,'D1D3C4'),(brass,'AEB4A8'),(hoof,'718C83')]:
            original={coat:'303A36',ridge:'546257',bone:'716347',brass:'3F5A50',hoof:'202A29'}[m]
            a=linear(original);b=linear(col);m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*(a[i]*(1-spect)+b[i]*spect for i in range(3)),1)
        flame.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=(1.0+.45*q)*(1-.986*spect)
        for o in mist:o.hide_render=p<1.01
        mistvis.default_value=.10*q
    def pose(t,anim='idle_p1'):
        for o,(l,r,sc) in rest.items():o.location=l;o.rotation_euler=r;o.scale=sc;o.hide_render=False
        root.location=(0,0,0);root.scale=(1.0,1.0,1.0)
        for v in visibility:v.default_value=1
        w=math.sin(math.tau*t);u=t*SPECS[anim][0]/(SPECS[anim][0]-1)
        p=1+u if anim=='trans_p2' else 2+u if anim=='trans_p3' else phase
        state(p)
        torso.location.z+=.04*w;torso.scale.x*=1+.03*w
        neck.rotation_euler.x=.06*w;head.rotation_euler.z=.08*w;tail.rotation_euler.z=.3*w;crown.rotation_euler.y=.04*w
        for j,f in enumerate(flames):f.scale.z*=1+.14*math.sin(math.tau*t+j)
        if anim.startswith('walk'):
            torso.location.z+=.09*math.cos(t*math.tau*2);torso.rotation_euler.z=.06*w
            for leg,shin,front,side in legs:
                a=math.tau*t+(0 if (front and side==1) or (not front and side==-1) else math.pi)
                leg.rotation_euler.x=.62*math.sin(a);shin.rotation_euler.x=-.9*max(0,math.cos(a));leg.location.z+=.1*max(0,math.cos(a))
            neck.rotation_euler.x=-.06*w
        if anim=='auto':
            swing=[0,-.45,-.8,.72,.28,0][round(t*6)]
            neck.rotation_euler.x=swing;head.rotation_euler.z=[0,.22,.5,-.6,-.2,0][round(t*6)];torso.rotation_euler.x=swing*.20
            crown.rotation_euler.z=[0,.20,.38,-.42,-.12,0][round(t*6)]
            torso.location.y+=[0,.08,.18,-.24,-.10,0][round(t*6)]
        if anim=='spell_a':
            bend=[0,.4,.82,.92,.52,.2,-.08,0][round(t*8)]
            neck.rotation_euler.x=bend;head.rotation_euler.x=bend*.38
            jump=[0,-.1,-.22,-.16,.36,.5,.2,0][round(t*8)]
            torso.location.z+=jump;torso.rotation_euler.x=-jump*.25
            for leg,shin,front,side in legs:leg.rotation_euler.x=(-1 if front else 1)*jump*1.7;shin.rotation_euler.x=-max(0,jump)
            torso.location.y+=[0,.08,.18,.12,-.30,-.48,-.16,0][round(t*8)]
        if anim=='spell_b':
            rear=math.sin(math.pi*u)**2
            torso.rotation_euler.x=-.55*rear;torso.location.z+=.3*rear;neck.rotation_euler.x=-.4*rear
            for leg,shin,front,side in legs:
                if front:leg.rotation_euler.x=-1.2*rear;shin.rotation_euler.x=-.85*rear
            for j,f in enumerate(flames):f.scale*=1+.55*rear
        if anim.startswith('trans'):
            neck.rotation_euler.x=-.15*math.sin(math.pi*u);crown.rotation_euler.y=.08*math.sin(math.tau*u)
        if anim in ('death','vanish','reappear'):
            f=1-u if anim=='reappear' else u
            for v in visibility:v.default_value=(1-f)**1.4
            torso.location.z+=.20*f;torso.scale.z=1+.20*f;neck.rotation_euler.x=-.16*f
            for j,c in enumerate(cages):c.location.z+=f*(.20+j*.035)
            for j,ob in enumerate(root.children_recursive):
                if ob.type in ('MESH','CURVE'):
                    ob.location.x+=math.sin(j*2.4)*f*f*.13;ob.location.z+=f*f*(j%4)*.045
            for fob in flames:fob.scale*=max(.001,1-f*1.5)
            if f>=.999:
                for ob in root.children_recursive:ob.hide_render=True
        if anim=='antlers':
            keep=set(antler_objects)
            for ob in root.children_recursive:
                if ob.type in ('MESH','CURVE'):ob.hide_render=ob not in keep or not ob.name.startswith(('Coeur lumineux','Langue de flamme'))
        for j,ob in enumerate(mist):
            ob.location.x+=.12*math.sin(math.tau*t+j);ob.scale.x*=1+.1*math.sin(math.tau*t+j)
            if anim in ('antlers','death','vanish','reappear'):ob.hide_render=True
    return root,pose

def prop(anim):
    root=empty('VFX_ROOT');mat=material('Feu follet #9CF0C8',linear('9CF0C8'),emission=2.4)
    vis=fade_material(mat,True,.8);mat.node_tree.nodes['Spectral'].outputs[0].default_value=1;objects=[]
    if anim=='ground_mist':
        mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*linear('B8C8C0'),1)
        mat.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=.10
        vis.default_value=.12
        soften_mist(mat)
        for j in range(18):
            a=j*2.39996;r=.3+(j%5)*.20
            objects.append(sphere('Nappe de brume',(r*math.cos(a),r*math.sin(a),.05+(j%3)*.03),(.47,.30,.09),mat,root))
    else:
        objects.append(sphere('Ame du follet',(0,0,.27),(.13,.13,.18),mat,root))
        objects.append(tube('Flamme du follet',[(0,0,.29),(.08,.01,.46),(.02,.01,.64)],.06,mat,root))
        eye=material('Yeux follet',linear('344B43'),emission=.1)
        if anim=='wisp':
            for x in (-.044,.044):objects.append(sphere('Oeil follet',(x,-.115,.31),(.019,.022,.027),eye,root))
        for j in range(9):
            a=j*2.39996
            objects.append(sphere('Etincelle',(math.cos(a)*.20,math.sin(a)*.20,.12+j*.035),(.022,.022,.04),mat,root))
    rest=[(o,o.location.copy(),o.scale.copy()) for o in objects]
    def pose(t):
        w=math.sin(math.tau*t);u=t*8/7
        for j,(o,l,sc) in enumerate(rest):
            o.location=l;o.scale=sc;o.hide_render=False
            if anim=='ground_mist':o.location.x+=.13*math.sin(math.tau*t+j);o.location.y+=.08*math.cos(math.tau*t+j);o.scale.x*=1+.10*w
            elif anim=='wisp_explode':
                a=j*2.39996;o.location.x+=math.cos(a)*u*.43;o.location.y+=math.sin(a)*u*.43;o.location.z+=u*.15;o.scale*=max(.001,1-u)* (1+1.3*math.sin(math.pi*min(1,u)))
                vis.default_value=max(0,1-u)
                if u>=.999:o.hide_render=True
            else:o.location.z+=.04*math.sin(math.tau*t+j*.5);o.location.x+=.025*math.sin(math.tau*t+j);o.scale.z*=1+.13*w
    return root,pose

def render_frame(root,pose,path,t=0,direction='s'):
    """Blended beauty plus opaque geometry Normal/Emission passes.
    Eevee BLENDED omits auxiliary passes. Render the same posed surfaces with
    opacity disabled for these passes; pack_cerf restores the beauty alpha.
    No images are drawn or synthesized outside Blender.
    """
    path=Path(path)
    render_still(root,pose,path,t,direction)
    changes=[]
    for mat in bpy.data.materials:
        if not mat.use_nodes:continue
        for mix in mat.node_tree.nodes:
            if mix.type!='MIX_SHADER':continue
            links=[(l.from_socket,l.to_socket) for l in mix.inputs[0].links]
            changes.append((mat,mix,links,mat.surface_render_method))
            for link in list(mix.inputs[0].links):mat.node_tree.links.remove(link)
            mix.inputs[0].default_value=1;mat.surface_render_method='DITHERED'
    aux=path.with_name(path.stem+'_geometry.png')
    render_still(root,pose,aux,t,direction)
    for suffix in ('_n','_e'):
        aux.with_name(aux.stem+suffix+'.png').replace(path.with_name(path.stem+suffix+'.png'))
    aux.unlink()
    for mat,mix,links,method in changes:
        mat.surface_render_method=method
        for a,b in links:mat.node_tree.links.new(a,b)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--anims',nargs='*');parser.add_argument('--preview',action='store_true');args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for anim in args.anims or SPECS:
        count,dirs,phase,size=SPECS[anim];s=setup_scene(5.1 if phase else 3.8 if anim=='ground_mist' else 1.45)
        s.render.resolution_x=s.render.resolution_y=size*2;s.eevee.taa_render_samples=24
        # Ground at 70%; fixed camera throughout all boss animations/layers.
        scale=s.camera.data.ortho_scale;s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,scale*.08,0))
        root,pose=build(phase) if phase else prop(anim)
        fn=(lambda t:pose(t,anim)) if phase else pose
        if anim=='idle_p1':
            fn(0);configure_passes(OUT/anim/'s_00.png');bpy.context.scene['rebuild']='cerf.py --background; --anims selects animations; all poses deterministic'
            bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/bosses/cerf.blend'))
        if args.preview:
            render_frame(root,fn,OUT/'_preview'/f'{anim}.png',0,'s')
        else:
            for direction in dirs:
                for f in range(count):render_frame(root,fn,OUT/anim/f'{direction}_{f:02}.png',f/count,direction)
if __name__=='__main__':main()
