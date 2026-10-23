"""M1: Marotte and the Montreur. Background Blender 5.2, no game writes.
Reuses C4 modelling helpers, ash_lord PBR and the shared CREA/pass exporter.
--build-only saves sources; --contact-only reassembles existing renders.
All geometry is bone-parented in a named, unanimated rest pose for M2.
"""
import sys, math, json, random
sys.dont_write_bytecode = True
from pathlib import Path
import bpy
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT/'art/tools/characters'))
from ardent_iso_build import bead, rings, soften
from ash_lord_build import worn, mesh, plate, rod, material, empty
import iso_rig
from boss_common import DIRECTIONS
OUT = ROOT/'art/tools/characters/_m1_out'
SOURCES = ROOT/'art/blender/characters'
_optimize_png = iso_rig.optimize_png
def keep_contract_pass(path,crop=False,margin=6):
    # M1 explicitly requests eight _e cells. An occluded glass reflection produces
    # a legitimately black rear cell, retained here instead of the usual omission.
    if Path(path).stem.endswith('_e'):
        from PIL import Image
        with Image.open(path) as im:im.save(path,optimize=True,compress_level=9)
        return (0,0,192,192)
    return _optimize_png(path,crop,margin)
iso_rig.optimize_png=keep_contract_pass

def pbr():
    wood=worn('Black brown cracked varnished timber','191612','66503A',0,.38)
    p=wood.node_tree.nodes.get('Principled BSDF');p.inputs['Coat Weight'].default_value=.28;p.inputs['Coat Roughness'].default_value=.3
    porcelain=worn('Dirty ivory porcelain D9CFC4','837E75','D9CFC4',0,.51)
    for mat in (wood,porcelain):
        n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF')
        tex=n.new('ShaderNodeTexVoronoi');tex.feature='DISTANCE_TO_EDGE';tex.inputs['Scale'].default_value=36 if mat==porcelain else 19
        ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.006;ramp.color_ramp.elements[0].color=(.015,.012,.009,1);ramp.color_ramp.elements[1].position=.028
        l.new(tex.outputs['Distance'],ramp.inputs[0]);mul=n.new('ShaderNodeMixRGB');mul.blend_type='MULTIPLY';mul.inputs[0].default_value=.65
        l.new(p.inputs['Base Color'].links[0].from_socket,mul.inputs[1]);l.new(ramp.outputs[0],mul.inputs[2]);l.new(mul.outputs[0],p.inputs['Base Color'])
    cloth=worn('Soaked faded diamond motley 4A5565 7A3B24','303844','4A5565',0,.83)
    n=cloth.node_tree.nodes;l=cloth.node_tree.links;p=n.get('Principled BSDF')
    uv=n.new('ShaderNodeTexCoord');mapping=n.new('ShaderNodeMapping');mapping.inputs['Scale'].default_value=(1,1,1);mapping.inputs['Rotation'].default_value[2]=math.pi/4
    l.new(uv.outputs['UV'],mapping.inputs[0]);check=n.new('ShaderNodeTexChecker');check.inputs['Scale'].default_value=7
    check.inputs['Color1'].default_value=(.068,.091,.13,1);check.inputs['Color2'].default_value=(.195,.045,.017,1)
    l.new(mapping.outputs[0],check.inputs['Vector']);mul=n.new('ShaderNodeMixRGB');mul.blend_type='MULTIPLY';mul.inputs[0].default_value=1
    # Neutral dirt preserves both specified dyes instead of tinting rust blue.
    dirt=n.new('ShaderNodeValToRGB');dirt.color_ramp.elements[0].color=(.36,.36,.34,1);dirt.color_ramp.elements[1].color=(.95,.95,.91,1)
    l.new(n.get('Noise Texture').outputs['Fac'],dirt.inputs[0]);l.new(dirt.outputs[0],mul.inputs[1]);l.new(check.outputs['Color'],mul.inputs[2]);l.new(mul.outputs[0],p.inputs['Base Color'])
    return dict(wood=wood,porcelain=porcelain,cloth=cloth,
        iron=worn('Pitted black iron fittings','1A1C1C','66645C',.65,.57),
        lead=worn('Oxidised silent lead bells','323835','7C8278',.65,.62),
        peg=worn('Pale split ash dowels','4D3E2E','A48E66',0,.66),
        dark=worn('Cavity dirt and empty socket','080B0C','1A2020',0,.95),
        ruff=worn('Water stained linen ruff','4F514A','B0ACA0',0,.88),
        patch=worn('Old sackcloth patches','393D39','767362',0,.95),
        mist=worn('Drowned charcoal spectral shroud','101B1E','3D5656',0,.96),
        silver=material('Only emission spectral silver 9FC8C0','9FC8C0',1.4,True))

def tailored(name,levels,mat,parent,n=24,closed=True):
    ob=rings(name,levels,mat,parent,n,closed)
    # Explicit circumference / height UVs keep the diamonds regular on every limb.
    uv=ob.data.uv_layers.new(name='Motley tailoring')
    for poly in ob.data.polygons:
        js=[v%n for v in poly.vertices];wrap=0 in js and n-1 in js
        for li,vi in zip(poly.loop_indices,poly.vertices):
            j=vi%n;u=j/n
            if wrap and j==0:u=1
            uv.data[li].uv=(u,(vi//n)/(len(levels)-1))
    return ob

def limb(name,a,b,r1,r2,mat,parent):
    length=(Vector(b)-Vector(a)).length
    ob=tailored(name,[(0,r1*.8,r1*.7,0),(length*.15,r1,r1*.78,0),(length*.6,r2*1.15,r2,0),(length,r2,r2*.8,0)],mat,parent,12)
    ob.location=a;ob.rotation_euler=(Vector(b)-Vector(a)).to_track_quat('Z','Y').to_euler()
    return ob

def bone_rig(root,spec,groups,attachments):
    data=bpy.data.armatures.new(root.name+'_Skeleton');rig=bpy.data.objects.new(root.name+'_Rig',data);bpy.context.collection.objects.link(rig);rig.parent=root
    bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
    for name,a,b,parent in spec:
        bone=data.edit_bones.new(name);bone.head=a;bone.tail=b
        if parent:bone.parent=data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True
    bpy.context.view_layer.update()
    for obj,name in groups:
        world=obj.matrix_world.copy();obj.parent=rig;obj.parent_type='BONE';obj.parent_bone=name;obj.matrix_world=world
    for name,pos,bone in attachments:
        obj=empty(name,pos,root);bpy.context.view_layer.update();world=obj.matrix_world.copy();obj.parent=rig;obj.parent_type='BONE';obj.parent_bone=bone;obj.matrix_world=world;obj['M2_attachment']=True
    rig['M2_notes']='Rigid separate wooden parts; bone parenting preserves pivots. No animation keys. Cloth pieces follow their owning segment.'
    return rig

def marotte(m):
    root=empty('Marotte');groups=[];spec=[('root',(0,0,0),(0,0,.15),None),('pelvis',(0,0,.61),(0,0,.72),'root'),('spine',(0,0,.72),(0,0,.99),'pelvis'),('neck',(0,0,.99),(0,0,1.08),'spine'),('head',(0,0,1.08),(0,0,1.30),'neck')]
    body=empty('Costume_body',parent=root);groups.append((body,'spine'))
    coat=tailored('Drenched fitted diamond doublet',[(.66,.067,.044,.015),(.74,.043,.031,0),(.86,.075,.048,0),(.95,.102,.043,.015),(.99,.048,.032,0)],m['cloth'],body)
    # Open front tears reveal a hollow wooden rib cage, never a solid barrel.
    import bmesh
    bm=bmesh.new();bm.from_mesh(coat.data)
    torn=[f for f in bm.faces if f.calc_center_median().y<-.015 and .76<f.calc_center_median().z<.94 and abs(f.calc_center_median().x)<.050]
    bmesh.ops.delete(bm,geom=torn,context='FACES');bm.to_mesh(coat.data);bm.free()
    rod('Exposed narrow wooden spine',[(0,.025,.70),(0,.025,.98)],.012,m['wood'],body)
    for z,r in [(.79,.048),(.83,.062),(.87,.073),(.91,.083)]:
        for side in (-1,1):
            rod('Exposed bent rib lath',[(side*.010,.024,z+.008),(side*r,.005,z),(side*r*.80,-.039,z-.015),(side*.014,-.043,z-.024)],.006,m['peg'],body)
    for side in (-1,1):
        rod('Bony wooden clavicle',[(side*.012,-.023,.972),(side*.065,-.030,.96),(side*.112,.005,.94)],.009,m['peg'],body)
        plate('Sodden torn coat lapel',[(side*.051,.935),(side*.070,.91),(side*.044,.83),(side*.036,.865)],-.052,.005,m['cloth'],body,.001)
    for side in (-1,1):
        plate('Split ragged doublet tail' ,[(side*.02,.70),(side*.075,.72),(side*.095,.57),(side*.055,.61),(side*.035,.55)],.04,.016,m['cloth'],body,.002)
    # Hand stitched square patches, not pristine decorative blocks.
    for x,z in [(-.042,.735),(.057,.945)]:
        plate('Irregular repaired linen patch',[(x-.018,z-.021),(x+.019,z-.019),(x+.016,z+.018),(x-.016,z+.014)],-.047,.004,m['patch'],body,.001)
        for i in range(4):
            xx=x-.014+i*.009
            rod('Uneven patch stitches',[(xx,-.053,z-.022),(xx+.003,-.054,z-.014)],.0015,m['ruff'],body)
    rod('Crooked doublet seam',[(.01,-.04,.67),(-.01,-.036,.71),(.008,-.034,.75)],.003,m['dark'],body)
    for z in (.68,.72,.755):bead('Dull lead fastening',(0,-.041,z),(.009,.006,.01),m['lead'],body)
    hip=empty('Wooden pelvis',parent=root);groups.append((hip,'pelvis'));bead('Pelvis core',(0,0,.65),(.064,.041,.065),m['wood'],hip)
    neck=empty('Neck and ruff',parent=root);groups.append((neck,'neck'))
    rod('Exposed neck dowel',[(0,0,.96),(0,0,1.10)],.017,m['peg'],neck)
    # Pleated radial linen fan with a ragged, weighted lower edge.
    verts=[];n=48
    for j in range(n):
        t=j*math.tau/n;rad=.094 if j%2==0 else .063
        verts.extend([(.035*math.cos(t),.035*math.sin(t),1.013),(rad*math.cos(t),rad*math.sin(t),.980+.012*(j%2))])
    ruff=mesh('Collapsed pleated ruff',verts,[(2*j,2*j+1,(2*((j+1)%n))+1,2*((j+1)%n)) for j in range(n)],m['ruff'],neck)
    solid=ruff.modifiers.new('Wet linen thickness','SOLIDIFY');solid.thickness=.003
    head=empty('Tilted porcelain head',(0,-.015,1.16),root);head.rotation_euler=(.06,-.20,.07);groups.append((head,'head'))
    bead('Carved wooden cranium',(0,.016,.012),(.092,.069,.135),m['wood'],head)
    # Sculpted convex face: actual perforations expose dark inset almond sockets.
    vs=[];rows=81;cols=65
    for i in range(rows):
        z=-.105+i*.245/(rows-1);width=.086*(.74+.26*math.sin(math.pi*i/(rows-1)))
        if i<5:width*=.65+.35*i/5
        for j in range(cols):
            u=(j/(cols-1)-.5)*2
            vs.append((u*width,-.052-.024*(1-u*u)-.010*math.sin(i*math.pi/(rows-1)),z))
    faces=[]
    for i in range(rows-1):
        for j in range(cols-1):
            ids=(i*cols+j,i*cols+j+1,(i+1)*cols+j+1,(i+1)*cols+j);x=sum(vs[k][0] for k in ids)/4;z=sum(vs[k][2] for k in ids)/4
            hole=any(((x-s*.040)/.029)**2+((z-.035-s*.05*x)/.014)**2<1 for s in (-1,1))
            if not hole:faces.append(ids)
    face=soften(mesh('Fissured porcelain face with open sockets',vs,faces,m['porcelain'],head));sol=face.modifiers.new('Porcelain shell edge','SOLIDIFY');sol.thickness=.005
    # Vertex pigment follows the porcelain surface: ragged brush edges and rain runs.
    paint=m['porcelain'].copy();paint.name='Hand painted cracked chalk, charcoal and blood red'
    face.data.materials[0]=paint
    attr=face.data.color_attributes.new(name='Rain pigment',type='FLOAT_COLOR',domain='POINT')
    for v in face.data.vertices:
        x,y,z=v.co;grain=math.sin(x*1870+math.sin(z*953))*math.sin(z*1531+x*497)
        c=(.79,.76,.69,1)
        orbit=min(((x-side*.040)/(.032+grain*.002))**2+((z-.035)/.027)**2 for side in (-1,1))
        drip=any(abs(x-(a+.003*math.sin(z*96+i)))<w*(.85+.2*grain) and low<z<.032 for i,(a,w,low) in enumerate([(-.058,.004,-.041),(-.034,.005,-.060),(.030,.004,-.035),(.055,.003,-.059)]))
        if orbit<1.0 or drip:c=(.009,.012,.011,1)
        smile=-.062+.037*(abs(x)/.078)**1.7
        if abs(x)<.080 and abs(z-smile)<.009+grain*.004:c=(.29+.055*grain,.012,.018,1)
        if any(abs(x-a-.002*math.sin(z*120))<.0025 and lo<z<hi for a,lo,hi in [(-.067,-.058,-.025),(.069,-.061,-.026),(.024,-.093,-.058)]):c=(.25,.014,.021,1)
        if grain>.77:c=tuple(k*.62 for k in c[:3])+(1,)
        attr.data[v.index].color=c
    nodes=paint.node_tree.nodes;links=paint.node_tree.links;bs=nodes.get('Principled BSDF')
    pigment=nodes.new('ShaderNodeVertexColor');pigment.layer_name='Rain pigment'
    mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=.83
    links.new(bs.inputs['Base Color'].links[0].from_socket,mix.inputs[1]);links.new(pigment.outputs['Color'],mix.inputs[2]);links.new(mix.outputs[0],bs.inputs['Base Color'])
    black=worn('Rain dissolved charcoal brows','080B0A','242824',0,.79)
    for side in (-1,1):
        rod('Arched hand brushed eyebrow',[(side*.016,-.084,.074),(side*.033,-.082,.093),(side*.052,-.076,.096),(side*.073,-.065,.080)],.0045,black,head)
    red=worn('Flaking dried blood red nose pigment','350A0D','8B272B',0,.58)
    bead('Chipped red painted nose tip',(0,-.113,-.005),(.015,.013,.014),red,head)
    hair=worn('Rain soaked green flax hair','19271E','52654A',0,.64)
    for side in (-1,1):
        for j in range(9):
            x=side*(.070+j*.002)
            rod('Clinging wet green flax strand',[(x,.006+j*.006,.109),(side*(.096+j*.001),-.005+j*.007,.043),(side*(.091+j*.002),-.025+j*.008,-.027-j*.003)],.0025,hair,head)
    tailored('Small collapsed soaked fool cap',[(.111,.074,.057,.02),(.137,.063,.047,.025),(.150,.044,.031,.033),(.148,.010,.014,.051)],m['cloth'],head,16)
    for side in (-1,1):
        bead('Recessed empty orbital cavity' ,(side*.040,-.063,.035),(.034,.011,.019),m['dark'],head)
        rod('Sculpted angular eyelid',[(side*.014,-.078,.047),(side*.043,-.077,.057),(side*.071,-.068,.044)],.004,black,head)
    glass=worn('Smoky glass inset eye','182925','59665C',.15,.19);glass.node_tree.nodes.get('Principled BSDF').inputs['Coat Weight'].default_value=.8
    bead('One small oblong glass eye',(-.040,-.073,.035),(.017,.009,.010),glass,head)
    rod('Silver reflection inside glass eye',[(-.047,-.083,.039),(-.034,-.083,.041)],.0028,m['silver'],head)
    plate('Chiselled narrow nose',[(-.010,.041),(.009,.042),(.014,-.008),(0,-.016),(-.012,-.007)],-.098,.023,m['porcelain'],head,.002)
    rod('Inset lip fissure under smeared smile',[(-.025,-.081,-.050),(-.006,-.089,-.054),(.021,-.083,-.051)],.002,m['dark'],head)
    rod('Forehead to jaw fracture',[(.012,-.073,.137),(.008,-.080,.105),(.019,-.084,.082),(.008,-.090,.055),(.017,-.090,.019),(.008,-.103,-.007),(.020,-.091,-.032),(.008,-.086,-.065),(.017,-.076,-.103)],.0028,m['dark'],head)
    rod('Branching porcelain fracture',[(.015,-.086,.080),(.045,-.080,.092),(.066,-.071,.081)],.0018,m['dark'],head)
    attachments=[('string_head',(0,-.015,1.295),'head')]
    for side,suffix in [(-1,'L'),(1,'R')]:
        shoulder=(side*.115,.005,.94);elbow=(side*.235,-.035,.70);wrist=(side*.30,-.095,.49)
        hippos=(side*.053,0,.65);knee=(side*.055,-.05,.37);ankle=(side*.14,0,.10)
        spec.extend([(f'upper_arm.{suffix}',shoulder,elbow,'spine'),(f'forearm.{suffix}',elbow,wrist,f'upper_arm.{suffix}'),(f'hand.{suffix}',wrist,(side*.31,-.12,.43),f'forearm.{suffix}'),(f'dagger.{suffix}',(side*.31,-.12,.43),(side*.37,-.20,.23),f'hand.{suffix}'),(f'thigh.{suffix}',hippos,knee,'pelvis'),(f'shin.{suffix}',knee,ankle,f'thigh.{suffix}'),(f'foot.{suffix}',ankle,(side*.14,-.13,.04),f'shin.{suffix}')])
        for name,a,b,r1,r2,mat,bone in [('upper_arm',shoulder,elbow,.027,.016,m['cloth'],f'upper_arm.{suffix}'),('forearm',elbow,wrist,.015,.011,m['wood'],f'forearm.{suffix}'),('thigh',hippos,knee,.032,.019,m['cloth'],f'thigh.{suffix}'),('shin',knee,ankle,.015,.012,m['wood'],f'shin.{suffix}')]:
            pivot=empty(name+'_'+suffix,parent=root);groups.append((pivot,bone))
            a1=Vector(a).lerp(Vector(b),.09);b1=Vector(a).lerp(Vector(b),.88);limb(name+' articulated segment',a1,b1,r1,r2,mat,pivot)
            if mat==m['wood']:
                rod('Pale longitudinal split',[Vector(a1)+Vector((0,-r1*.78,0)),Vector(b1)+Vector((.004,-r2,0))],.002,m['peg'],pivot)
            for pos in [a]:
                bead('Visible wooden ball joint',pos,(.029,.025,.029),m['wood'],pivot)
                rod('Exposed transverse joint peg',[(pos[0]-.036,pos[1],pos[2]),(pos[0]+.036,pos[1],pos[2])],.010,m['peg'],pivot)
        hand=empty('Carved hand_'+suffix,parent=root);groups.append((hand,f'hand.{suffix}'))
        bead('Narrow wooden palm',(side*.306,-.103,.459),(.022,.020,.037),m['wood'],hand)
        for j in range(3):rod('Wood finger curl',[(side*(.29+j*.01),-.124,.467),(side*(.29+j*.01),-.139,.437),(side*(.29+j*.01),-.115,.431)],.004,m['peg'],hand)
        foot=empty('Foot_'+suffix,parent=root);groups.append((foot,f'foot.{suffix}'))
        shoe=bead('Narrow rain swollen wooden shoe',(side*.14,-.045,.056),(.045,.103,.043),m['wood'],foot);shoe.rotation_euler.z=side*.16
        rod('Iron shoe sole',[(side*.14,-.125,.027),(side*.14,.025,.027)],.025,m['iron'],foot)
        dagger=empty('Dagger_'+suffix,parent=root);groups.append((dagger,f'dagger.{suffix}'))
        rod('Wood dagger handle',[(side*.31,-.115,.475),(side*.32,-.13,.405)],.012,m['wood'],dagger)
        rod('Black iron quillon',[(side*.28,-.139,.405),(side*.36,-.139,.405)],.008,m['iron'],dagger)
        plate('Angular wooden dagger blade',[(side*.30,.401),(side*.345,.401),(side*.39,.215),(side*.35,.25)],-.145,.020,m['wood'],dagger,.002)
        rod('Ferrule and forged dagger edge',[(side*.345,-.148,.397),(side*.39,-.148,.215),(side*.35,-.148,.25)],.006,m['iron'],dagger)
        for z in (.422,.448):rod('Handle wire wrap',[(side*.301,-.13,z),(side*.326,-.13,z)],.002,m['lead'],dagger)
        attachments.extend([(f'string_wrist.{suffix}',wrist,f'hand.{suffix}'),(f'string_knee.{suffix}',knee,f'shin.{suffix}')])
        # Lead bells have black slits and loops; no bright decorative enamel.
        for pos,parent in [((side*.087,-.034,.980),neck),((side*.075,-.038,.67),body)]:
            bead('Silent lead bell',pos,(.016,.014,.021),m['lead'],parent)
            rod('Bell split',[(pos[0]-.009,pos[1]-.014,pos[2]-.009),(pos[0]+.009,pos[1]-.014,pos[2]-.005)],.0018,m['dark'],parent)
    bone_rig(root,spec,groups,attachments)
    return root

def montreur(m):
    root=empty('Montreur');groups=[]
    # Separate actor lives at z=1.4, with camera tracking that root for a full cell.
    root.location.z=1.4
    spec=[('root',(0,0,0),(0,0,.13),None),('shroud',(0,.06,.04),(0,.06,.59),'root'),('hood',(0,.06,.59),(0,.06,.91),'shroud')]
    robe=empty('Dissolving shroud',parent=root);groups.append((robe,'shroud'))
    # Jagged open cloth strips rather than an opaque humanoid torso.
    for j in range(15):
        t=.48+j*(math.tau-.96)/14;verts=[]
        for k in range(5):
            z=.64-k*.145;r=.16+.065*k;half=.12 if k<3 else .065
            for delta in (-half,half):
                tt=t+delta;verts.append((r*math.sin(tt),.07-r*.62*math.cos(tt),z+.025*math.sin(j*2.3+k)))
        ob=mesh('Torn mist trailing panel',verts,[(k*2,k*2+1,k*2+3,k*2+2) for k in range(4)],m['mist'],robe)
        soften(ob)
    hood=empty('Faceless hood',parent=root);groups.append((hood,'hood'))
    verts=[];count=25
    for k,(z,rx,ry) in enumerate([(.48,.19,.13),(.64,.18,.15),(.80,.145,.12),(.92,.045,.055)]):
        for j in range(count):
            t=.62+(math.tau-1.24)*j/(count-1);verts.append((rx*math.sin(t),.05-ry*math.cos(t),z))
    ob=soften(mesh('Empty open hood of rain mist',verts,[(r*count+j,r*count+j+1,(r+1)*count+j+1,(r+1)*count+j) for r in range(3) for j in range(count-1)],m['mist'],hood))
    sol=ob.modifiers.new('Mist hem thickness','SOLIDIFY');sol.thickness=.009
    # Absolutely no face, eyes, skull or luminous face-shaped patch.
    for j in (0,count-1):rod('Frayed hood lip',[verts[k*count+j] for k in range(4)],.009,m['mist'],hood)
    # A dense chest behind the shredded mist gives a continuous readable silhouette.
    tailored('Dense upper spectral shroud',[(.24,.12,.075,.07),(.43,.18,.10,.07),(.61,.20,.10,.07),(.67,.13,.09,.07)],m['mist'],robe)
    bead('Black depth inside empty hood',(0,.045,.705),(.125,.075,.172),m['dark'],hood)
    rim=worn('Silver lit shroud edges','536F70','9FC8C0',.1,.68)
    for side in (-1,1):
        rod('Silver rain on hood edge',[(side*.111,-.057,.50),(side*.116,-.076,.65),(side*.085,-.047,.80),(side*.020,.018,.915)],.006,rim,hood)
    attachments=[]
    for side,suffix in [(-1,'L'),(1,'R')]:
        shoulder=(side*.17,.06,.59);elbow=(side*.29,-.01,.39);wrist=(side*.22,-.22,.37)
        spec.extend([(f'upper_arm.{suffix}',shoulder,elbow,'shroud'),(f'forearm.{suffix}',elbow,wrist,f'upper_arm.{suffix}'),(f'hand.{suffix}',wrist,(side*.20,-.30,.32),f'forearm.{suffix}')])
        upper=empty('Upper mist sleeve_'+suffix,parent=root);groups.append((upper,f'upper_arm.{suffix}'))
        limb('Loose sleeve upper',shoulder,elbow,.10,.13,m['mist'],upper)
        sleeve=empty('Hanging mist sleeve_'+suffix,parent=root);groups.append((sleeve,f'forearm.{suffix}'))
        limb('Open bell sleeve',elbow,wrist,.12,.075,m['mist'],sleeve)
        for j in range(4):
            x=side*(.20+j*.025)
            rod('Sleeve shredded fringe',[(x,-.20,.36),(x+side*.025,-.17,.16+j*.025)],.012,m['mist'],sleeve)
        hand=empty('Spectral hand_'+suffix,parent=root);groups.append((hand,f'hand.{suffix}'))
        limb('Long spectral palm',wrist,(side*.19,-.28,.32),.030,.026,m['silver'],hand)
        for j in range(5):
            x=side*(.16+j*.018);z=.30+.009*abs(j-2);a=(x,-.28,z+.025);b=(x,-.33,z);tip=(x,-.345,z-.026)
            bone=f'finger_{j+1}.{suffix}';spec.append((bone,a,tip,f'hand.{suffix}'))
            digit=empty('Finger_'+str(j+1)+'_'+suffix,parent=root);groups.append((digit,bone));rod('Tapered spectral finger',[a,b,tip],.006,m['silver'],digit)
            if (side==-1 and j<3) or (side==1 and j<2):attachments.append((f'string_finger_{len(attachments)+1}',tip,bone))
    cross=empty('Spectral control cross',parent=root);groups.append((cross,'crossbar'));spec.append(('crossbar',(0,-.30,.30),(0,-.30,.40),'root'))
    rod('Silver crossbar transverse',[(-.27,-.32,.30),(.27,-.32,.30)],.012,m['silver'],cross)
    rod('Silver crossbar longitudinal',[(0,-.53,.30),(0,-.12,.30)],.012,m['silver'],cross)
    bead('Worn control cross hub',(0,-.32,.30),(.024,.028,.019),m['lead'],cross)
    bpy.context.view_layer.update()
    # Bone heads are in actor local coordinates; convert temporary child transforms
    # to world before bone parenting (root is suspended, not on the floor).
    bone_rig(root,spec,groups,attachments)
    root['game_alpha']=.8;root['game_lift_u']=1.4;root['screen_upper_left_offset_u']=.3
    # Geometry opacity is stochastic mist, independently of the final game alpha.
    mat=m['mist'];n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF')
    noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=7;noise.inputs['Detail'].default_value=2
    ramp=n.new('ShaderNodeMapRange');ramp.inputs['To Min'].default_value=.86;ramp.inputs['To Max'].default_value=1.0
    l.new(noise.outputs['Fac'],ramp.inputs['Value']);l.new(ramp.outputs[0],p.inputs['Alpha'])
    return root

def configure(actor):
    lift=1.4 if actor=='montreur' else 0
    s=iso_rig.create_rig('CREA',192,target=(0,0,lift));s.eevee.taa_render_samples=16
    s.camera.data.shift_y=.21;s.render.threads_mode='FIXED';s.render.threads=8
    s['render_px_per_u']=iso_rig.R;s['ground_pivot_px']=[96,136.32];s['M1_actor_origin_z']=lift
    s['M1_contract']='192 RGBA, CREA 30deg, 8 directions e se s sw w nw n ne, 1 rest frame, screen normals + emission; M2 animates'
    bpy.context.preferences.filepaths.save_version=0
    return s

def save_and_render(actor):
    s=configure(actor);m=pbr();root=marotte(m) if actor=='marotte' else montreur(m)
    iso_rig.bake_ao_shadows(root);bpy.context.view_layer.update()
    s['M2_attachments']=json.dumps([o.name for o in root.children_recursive if o.get('M2_attachment')])
    rig=next(o for o in root.children_recursive if o.type=='ARMATURE')
    assert len(json.loads(s['M2_attachments']))==5
    assert not rig.animation_data
    assert all(o.parent_type=='BONE' for o in root.children_recursive if o.get('M2_attachment'))
    s['M1_mesh_triangles']=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in root.children_recursive if o.type=='MESH')
    s['M1_bone_names']=json.dumps(list(rig.data.bones.keys()))
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCES/(actor+'.blend')))
    if '--build-only' in sys.argv:return
    bounds={}
    from bpy_extras.object_utils import world_to_camera_view
    for direction,angle in DIRECTIONS.items():
        root.rotation_euler.z=angle;bpy.context.view_layer.update()
        path=OUT/actor/'idle'/(direction+'_00.png');iso_rig.render_frame(path)
        points={}
        for o in root.children_recursive:
            if o.get('M2_attachment'):
                v=world_to_camera_view(s,s.camera,o.matrix_world.translation);points[o.name]=[round(v.x*192,3),round((1-v.y)*192,3)]
        bounds[direction]=points
    (OUT/actor/'attachments.json').write_text(json.dumps(bounds,indent=2))
    root.rotation_euler.z=0
    # Close-ups retain actual materials and lights; no painted details.
    if actor=='marotte':
        for name,target,profile in [('face',(0,-.02,1.16),False),('costume',(0,0,.63),False),('profile',(0,0,.63),True)]:
            from mathutils import Quaternion
            view=Vector((1,0,0)) if profile else Vector((0,-1,0))
            s.camera.rotation_euler=(-view).to_track_quat('-Z','Y').to_euler()
            s.camera.location=Vector(target)+view*12;s.camera.data.shift_y=0
            iso_rig.set_frame((384,384),'CREA');s.camera.data.ortho_scale=384/(iso_rig.R*3)
            iso_rig.render_frame(OUT/('detail_'+name+'.png'))
    print('PASS M1 '+actor+' saved + eight directions',flush=True)

def contact():
    from PIL import Image
    from bpy_extras.object_utils import world_to_camera_view
    # Only crop, resize and alpha-assemble existing raster assets. Wires and text
    # are rendered in Blender below, never drawn with Pillow.
    canvas=Image.new('RGBA',(1536,1040),(20,25,27,255))
    tile=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    for depth in range(5):
        for i in range(3):
            j=depth-i
            if 0<=j<3:canvas.alpha_composite(tile,(512+(i-j)*256,125+(i+j)*128))
    # Four assemblies, independent actor PNGs, true physical R. Offset is 0.3u
    # along screen upper-left and 1.4u vertical, not an arbitrary pixel lift.
    directions=['se','s','sw','nw'];feet=[(390,410),(610,485),(850,485),(1090,410)]
    ap=json.loads((OUT/'marotte/attachments.json').read_text());fp=json.loads((OUT/'montreur/attachments.json').read_text())
    dx=-.3*iso_rig.R/math.sqrt(2);dy=-1.4*iso_rig.R*math.cos(math.pi/6)-.3*iso_rig.R/math.sqrt(2)
    wires=[]
    for d,foot in zip(directions,feet):
        px,py=round(foot[0]-96),round(foot[1]-136.32)
        im=Image.open(OUT/'marotte/idle'/(d+'_00.png')).convert('RGBA');canvas.alpha_composite(im,(px,py))
        ghost=Image.open(OUT/'montreur/idle'/(d+'_00.png')).convert('RGBA');ghost.putalpha(ghost.getchannel('A').point(lambda a:round(a*.8)))
        gx,gy=round(px+dx),round(py+dy);canvas.alpha_composite(ghost,(gx,gy))
        for finger,attach in zip(['string_finger_'+str(j) for j in range(1,6)],['string_wrist.L','string_knee.L','string_head','string_knee.R','string_wrist.R']):
            a=fp[d][finger];b=ap[d][attach];wires.append(((gx+a[0],gy+a[1]),(px+b[0],py+b[1])))
    ardent=Image.open(ROOT/'game/assets/sprites/characters/ardent/idle.png').convert('RGBA').crop((0,384,192,576))
    canvas.alpha_composite(ardent,(170,420))
    ash=Image.open(ROOT/'game/assets/sprites/bosses/mini/ash_lord/idle.png').convert('RGBA').crop((0,0,170,170))
    fit=json.loads((ROOT/'art/renders/monsters/ash_lord/build_report.json').read_text())['framing'];side=round(iso_rig.R*fit['ortho_scale']);ash=ash.resize((side,side),Image.Resampling.LANCZOS)
    canvas.alpha_composite(ash,(round(1270-side/2),round(550-.7*side)))
    for i,name in enumerate(('face','costume','profile')):
        im=Image.open(OUT/('detail_'+name+'.png')).convert('RGBA');canvas.alpha_composite(im,(180+i*440,630))
    # Preserve the actual C4 reference image on this one inspection sheet.
    c4=Image.open(ROOT/'art/tools/iso/_c4_contact.png').convert('RGBA').crop((0,0,768,192));c4.thumbnail((144,36));canvas.alpha_composite(c4,(12,988))
    s=iso_rig.create_rig('TOP',(1536,1040));s.eevee.taa_render_samples=8
    s.camera.location=(768,520,12);s.camera.data.ortho_scale=1536;s.camera.data.shift_y=0
    overlay=empty('Contact captions and five physical strings per actor')
    silver=material('Contact caption spectral silver','9FC8C0',.15,True)
    wire=material('Contact wire spectral silver alpha 0.35','9FC8C0',.12,True)
    wire.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.35
    for a,b in wires:rod('Simulated silver string',[(a[0],1040-a[1],0),((a[0]+b[0])/2-1,1040-(a[1]+b[1])/2,0),(b[0],1040-b[1],0)],.50,wire,overlay)
    def text(label,x,y,size=17):
        data=bpy.data.curves.new('Caption','FONT');data.body=label;data.size=size
        ob=bpy.data.objects.new('Caption '+label,data);s.collection.objects.link(ob);ob.location=(x,1040-y,0);ob.data.materials.append(silver)
    text('M1b / MAROTTE + LE MONTREUR',30,40,27)
    text('CREA 30 deg | R 90.51 px/u | native scale | C1 rain-soaked ground',30,72)
    for d,foot in zip(directions,feet):text(d.upper(),foot[0]-12,foot[1]+28)
    text('ARDENT / C4',170,580);text('ASH LORD / same R',1180,580)
    text('Rain clown pigment / glass / fracture - 3x',180,1025,15);text('Hollow rib cage / front - 3x',620,1025,15);text('Gaunt body / profile - 3x',1060,1025,15)
    text('C4 reference',12,980,13)
    iso_rig.render_frame(OUT/'contact_overlay.png',passes=False)
    canvas.alpha_composite(Image.open(OUT/'contact_overlay.png').convert('RGBA'));canvas.convert('RGB').save(ROOT/'art/tools/characters/_m1b_contact.png',optimize=True,compress_level=9)
    # A quiet, reproducible contract check on the exported pixels.
    summary={}
    for actor in ('marotte','montreur'):
        boxes=[];empty_emission=[]
        for d in DIRECTIONS:
            for su in ('','_n','_e'):
                p=OUT/actor/'idle'/(d+'_00'+su+'.png');im=Image.open(p).convert('RGBA');assert im.size==(192,192)
                if not su:
                    box=im.getchannel('A').getbbox();assert box and box[0]>=4 and box[1]>=4 and box[2]<=188 and box[3]<=188,(actor,d,box);boxes.append(box)
                if su=='_e' and max(ch.getextrema()[1] for ch in im.split()[:3])<=1:empty_emission.append(d)
        assert len(empty_emission)<8
        summary[actor]={'frames':8,'passes':['diffuse','_n','_e'],'bounds':boxes,'black_emission_occluded':empty_emission,'source':str(SOURCES/(actor+'.blend'))}
    summary['contact']={'directions':directions,'ghost_alpha':.8,'wire_alpha':.35,'wire_width_px':1,'lift_u':1.4,'offset_u':.3,'terrain':'C1 ground_a','comparison_R':iso_rig.R,'detail_scale':3}
    (OUT/'verification.json').write_text(json.dumps(summary,indent=2));print('PASS M1: 48 contractual PNGs, 2 sources, attachments, contact',flush=True)

if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True);SOURCES.mkdir(parents=True,exist_ok=True)
    if '--contact-only' not in sys.argv:
        for actor in ('marotte','montreur'):save_and_render(actor)
    if '--build-only' not in sys.argv:contact()
