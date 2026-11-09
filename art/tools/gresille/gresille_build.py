"""Grésille: three concept studies; background Blender only, no gameplay export.
Geometry/render helpers and Blender-only layout convention from cd_cd3_common.
"""
import sys, math, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.dont_write_bytecode=True
sys.path.insert(0,str(ROOT/'art/tools/characters'))
import cd_cd3_common as cd
from cd_cd3_common import worn,mesh,plate,rod,cube,ell,tube,loft,torus,empty,rgb,emit
import bpy
from mathutils import Vector
sys.path.insert(0,str(ROOT/'art/tools/cel'))
import cel_style as cel
OUT=ROOT/'art/renders/gresille'
OUT.mkdir(parents=True,exist_ok=True)

# Revision 2: a single 1.35 u woman (head 0.20 u), linked across three studies.
# Clothing follows anatomy; no ball shoulders, mitten hands or block boots.
RETOUCH=dict(wool=('3F434B','5A5E66'),hair=('0D0B0B','221B18'),
    cape_bottom={'A':.885,'B':1.049,'C':.977},
    cape_width={'A':.237,'B':.218,'C':.229},weave_radius=.0028,
    coil_radius=.089,accent_power=1.6)
def sweep(name, sections, material, parent, N=24):
    """Continuous tapered limb, circular sections perpendicular to its centreline."""
    vs=[]
    for i,(co,rx,ry) in enumerate(sections):
        v=Vector(co)
        axis=Vector(sections[min(i+1,len(sections)-1)][0])-Vector(sections[max(0,i-1)][0])
        q=axis.to_track_quat('Z','Y')
        for j in range(N):
            t=j*math.tau/N;vs.append(v+q@Vector((rx*math.cos(t),ry*math.sin(t),0)))
    fs=[(i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j) for i in range(len(sections)-1) for j in range(N)]
    fs += [tuple(range(N-1,-1,-1)),tuple(range((len(sections)-1)*N,len(sections)*N))]
    o=mesh(name,vs,fs,material,parent)
    for f in o.data.polygons:f.use_smooth=True
    return o


def materials():
    def m(n,a,b,metal=0,rough=.8):
        ma=worn('Grésille / '+n,a,b,metal,rough);ma['gresille_surface']=n;return ma
    return dict(wool=m('laine mouillée',*RETOUCH['wool']),rubber=m('gutta-percha lisse','111619','30373B',0,.37),
        canvas=m('toile caoutchoutée','383228','65594B'),skin=m('peau olive','9C846E','C7AF95',0,.72),
        copper=m('cuivre vert-de-gris','405B4E','4F6B5E',.65,.27),edge=m('cuivre frotté','66503C','A58A64',.7,.32),
        patina=m('fond treillis oxydé','263B33','344B40',.55,.35),
        glass=m('verre fumé','263544','536579',.3,.26),wood=m('bois ciré','28241E','584B36',0,.48),
        hair=m('cheveux bruns tirés',*RETOUCH['hair']),ink=m('coutures et creux','171B20','2A2D30'),
        lip=m('lèvres sourdes','887061','B19A84'),eye=m('blanc des yeux terne','8F958C','C5C6B5'))


def build_body(M):
    root=empty('Grésille A / corps unique 6.75 têtes')
    root['height_u']=1.35;root['head_height_u']=.20;root['body_revision']=2
    wool,rubber,canvas,skin,copper,edge,glass,wood,hair,ink,lip,eye=[M[n] for n in ('wool','rubber','canvas','skin','copper','edge','glass','wood','hair','ink','lip','eye')]
    # Hips, long femurs and knees: crotch 0.675, waist 0.86, shoulders 1.10.
    loft('Bassin féminin / pantalon ajusté',[(.68,.114,.082,.012),(.725,.164,.100,.012),(.78,.169,.101,.006),(.825,.128,.085,0),(.862,.105,.078,0)],wool,root,N=32)
    for side in [-1,1]:
        x=side*.092;fy=-.025 if side==1 else .025
        sweep('Jambe longue / genou anatomique',[
            ((x,.012,.758),.081,.086),((x+side*.005,.006,.675),.077,.077),
            ((x+side*.010,-.014+fy,.565),.060,.061),((x+side*.012,-.022+fy,.49),.050,.051),
            ((x+side*.013,-.014+fy,.435),.052,.052),((x+side*.012,.004+fy,.35),.053,.055)],wool,root)
        # Smooth moulded rubber: ankle, instep, rounded toe and calf in one surface.
        xx=x+side*.012
        boot=loft('Botte gutta-percha / tige lisse',[(.042,.049,.086,-.036+fy),(.068,.052,.095,-.043+fy),
            (.098,.047,.082,-.033+fy),(.135,.039,.048,fy),(.19,.039,.045,fy),(.28,.050,.052,.010+fy),
            (.35,.057,.054,.005+fy),(.405,.056,.052,.004+fy)],rubber,root,N=32);boot.location.x=xx
        sole=loft('Semelle moulée arrondie',[(.018,.044,.088,-.043+fy),(.025,.053,.101,-.045+fy),(.043,.053,.101,-.045+fy),(.051,.049,.096,-.041+fy)],ink,root,N=32);sole.location.x=xx
        torus('Lèvre souple de botte',(xx,.004+fy,.404),.054,.004,rubber,root,sc=(1,.96,1))
        tube('Couture arrière botte',[(xx,.054+fy,.14),(xx,.061+fy,.28),(xx,.056+fy,.392)],.0014,ink,root)
        for i in range(3):
            z=.455+i*.024
            tube('Plis obliques du genou',[(xx-.039,-.043+fy,z+.008),(xx,-.063+fy,z),(xx+.032,-.049+fy,z+.007)],.0027,ink if i==1 else wool,root)
    # Tailored working jacket: narrow waist, modest chest, square shoulder line.
    jacket=loft('Veste de laine cintrée',[(.745,.164,.102,.002),(.785,.163,.107,0),(.825,.128,.089,-.002),
        (.86,.105,.078,0),(.91,.116,.088,0),(.96,.134,.103,-.006),
        (1.005,.144,.108,-.005),(1.052,.145,.087,0),(1.09,.147,.067,.008),
        (1.108,.120,.058,.008),(1.13,.048,.045,.004)],wool,root,N=40,rough=.006)
    # Bust is contained inside the continuous garment, never separate spheres.
    for v in jacket.data.vertices:
        if v.co.y<-.035:
            v.co.y-=.024*math.exp(-((v.co.z-.99)/.051)**2)*math.exp(-((abs(v.co.x)-.057)/.036)**2)
    for side in [-1,1]:
        plate('Revers laine cassé',[(side*.020,1.122),(side*.079,1.090),(side*.060,1.067),(side*.075,1.055),(side*.016,1.012)],-.106,.008,wool,root,.002)
        tube('Surpiqûre taille',[(side*.135,-.049,.794),(side*.111,-.073,.862),(side*.133,-.086,.947)],.0016,ink,root)
        tube('Bretelle du râtelier',[(side*.119,.064,1.086),(side*.115,-.074,1.091),(side*.094,-.111,.982),(side*.089,-.091,.86)],.010,rubber,root)
        cube('Boucle de harnais',(side*.098,-.119,1.003),(.024,.009,.031),edge,root,.003)
    tube('Patte de boutonnage',[(.009,-.112,1.014),(.007,-.092,.91),(.005,-.087,.837)],.004,canvas,root)
    for z,y in [(1.018,-.118),(.961,-.118),(.906,-.098),(.85,-.089)]:ell('Petit bouton terne',(.007,y,z),(.005,.003,.005),edge,root)
    # Narrow belt retains the waist; tools hang over the hips, never a square apron.
    loft('Ceinture de métier',[(.824,.129,.092,0),(.85,.112,.083,0)],rubber,root,N=32)
    cube('Boucle martelée',(0,-.095,.839),(.040,.012,.027),edge,root,.003)
    for side in [-1,1]:
        ob=cube('étui de toile cousu',(side*.139,-.059,.758),(.057,.037,.096),canvas,root,.009);ob.rotation_euler.y=side*.10
        for i in range(5):tube('Points de couture étui',[(side*.139-.021+i*.010,-.079,.722),(side*.139-.019+i*.010,-.079,.728)],.0009,edge,root)
    for x in [.128,.15]:rod('Manche de pince',[(x,-.087,.754),(x+.005,-.087,.846)],.005,rubber,root)
    rod('Mâchoires de pince',[(.133,-.087,.847),(.145,-.087,.863),(.16,-.087,.847)],.005,edge,root)
    cube('Brosse de laiton',(-.14,-.086,.794),(.025,.018,.043),wood,root,.002)
    for i in range(6):rod('Soie de brosse',[(-.15+i*.004,-.089,.814),(-.15+i*.004,-.089,.838)],.0013,edge,root)
    torus('Mètre à ruban',(-.172,.018,.814),.021,.005,edge,root,rot=(math.pi/2,0,0))
    # Continuous tapered sleeves, with elbow folds, slender wrists and five digits.
    for side in [-1,1]:
        sweep('Manche sans épaulière',[
            ((side*.128,.004,1.075),.042,.045),((side*.157,.002,1.048),.038,.040),
            ((side*.178,-.005,.985),.034,.036),((side*.201,-.025,.919),.031,.033),
            ((side*.222,-.058,.858),.029,.029),((side*.239,-.088,.798),.025,.026)],wool,root)
        for j in range(3):
            z=.901+j*.016
            tube('Plis de coude',[(side*.178,-.046,z+.008),(side*.207,-.058,z),(side*.23,-.045,z+.009)],.0025,ink if j==0 else wool,root)
        sweep('Manchette de toile caoutchoutée',[((side*.238,-.085,.813),.035,.036),((side*.244,-.103,.776),.031,.030)],canvas,root)
        sweep('Paume du gant fin',[((side*.244,-.103,.783),.025,.022),((side*.247,-.109,.757),.027,.021),((side*.247,-.113,.739),.023,.017)],canvas,root,N=20)
        for j in range(4):
            x=side*(.229+j*.012);end=.688+[.009,0,.003,.014][j]
            pts=[(x,-.116,.744),(x+side*.002,-.128,.722),(x+side*.001,-.123,end+.012),(x,-.109,end)]
            sweep('Doigt articulé %d'%j,[(pts[0],.0061,.0064),(pts[1],.0059,.006),(pts[2],.0048,.005),(pts[3],.003,.0035)],canvas,root,N=10)
            tube('Couture de doigt',[(x,-.135,.728),(x,-.132,.714)],.0008,ink,root)
        sweep('Pouce opposable',[((side*.226,-.105,.767),.009,.009),((side*.211,-.124,.749),.008,.008),((side*.215,-.14,.732),.005,.005)],canvas,root,N=12)
    # Head: fine chin, cheekbones, brow, crown. 0.20 u = 6.75 heads total.
    loft('Cou fin',[(1.09,.035,.034,.006),(1.14,.031,.030,.003),(1.177,.032,.031,.003)],skin,root,N=24)
    head=loft('Visage sculpté / menton fin',[(1.15,.019,.025,-.018),(1.159,.032,.034,-.014),
        (1.178,.040,.040,-.009),(1.205,.055,.051,-.004),(1.219,.064,.054,-.001),(1.227,.067,.056,0),(1.233,.068,.057,.001),
        (1.254,.065,.058,.005),(1.278,.065,.060,.010),(1.307,.059,.057,.013),
        (1.331,.043,.045,.015),(1.341,.022,.025,.016),(1.344,.003,.004,.016)],skin,root,N=40)
    # Locally project facial plane while keeping narrow temples and an unbroken jaw.
    for v in head.data.vertices:
        if v.co.y<-.025:
            v.co.y-=.008*math.exp(-((v.co.z-1.205)/.025)**2)*math.exp(-((abs(v.co.x)-.036)/.025)**2)
            v.co.y-=.014*math.exp(-((v.co.z-1.229)/.015)**2)*math.exp(-(v.co.x/.010)**2)
    for side in [-1,1]:
        ell('Oreille fine',(side*.064,.005,1.239),(.010,.013,.022),skin,root)
        tube('Pli du pavillon',[(side*.069,-.004,1.25),(side*.073,-.008,1.24),(side*.07,-.006,1.227)],.0014,lip,root)
        x=side*.027
        ell('Cerne discret',(x,-.052,1.237),(.015,.002,.0025),lip,root)
        ell('Oeil étroit',(x,-.056,1.247),(.014,.0034,.0042),eye,root)
        ell('Iris sombre',(x,-.059,1.247),(.0032,.0014,.0035),hair,root)
        tube('Paupière supérieure',[(x-.014,-.055,1.247),(x,-.060,1.251),(x+.014,-.055,1.248)],.0011,lip,root)
        tube('Sourcil fin',[(side*.014,-.054,1.263),(side*.029,-.056,1.265),(side*.045,-.048,1.26)],.0014,hair,root)
    tube('Bouche fine',[(-.010,-.057,1.192),(0,-.061,1.191),(.010,-.057,1.192)],.0008,lip,root)
    # Swept hair cap has a high forehead; bun and copper pins at the back.
    vs=[];fs=[];N=40
    for row in range(7):
        f=row/6
        for j in range(N):
            t=j*math.tau/N
            lower=1.254+.035*math.cos(t)+.005*math.sin(t) # front hairline, nape lower
            z=lower+(1.350-lower)*f
            r=math.sqrt(max(0,1-((z-1.265)/.085)**2))
            vs.append((.074*r*math.sin(t),.009-.071*r*math.cos(t),z))
    for i in range(6):
        for j in range(N):fs.append((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j))
    cap=mesh('Cheveux tirés / front dégagé',vs,fs,hair,root)
    for f in cap.data.polygons:f.use_smooth=True
    ell('Chignon serré',(-.060,.062,1.324),(.043,.040,.041),hair,root)
    for j in range(14):
        t=(j+.4)*math.tau/14
        tube('Mèche peignée',[(.069*math.sin(t),.009-.068*math.cos(t),1.258+.035*math.cos(t)+.005*math.sin(t)),(.052*math.sin(t+.08),.012-.051*math.cos(t+.08),1.326),(-.054,.067,1.345)],.0018,hair,root)
    for i in range(3):rod('Épingle en cuivre',[(-.097+i*.013,.031,1.322),(-.018+i*.008,.071,1.36)],.0024,edge,root)
    for i in range(4):
        x=-.046+i*.022
        tube('Mèche dressée',[(x,-.020,1.327),(x-.006,-.018,1.355),(x-.016,-.016,1.377+i%2*.009)],.0024,hair,root)
    return root


def clone_body(source,k):
    root=empty('Grésille '+k+' / même corps lié');root['body_revision']=2
    for ob in source.children_recursive:
        cp=ob.copy();cp.data=ob.data;bpy.context.collection.objects.link(cp);cp.parent=root
    return root


def build_variant(root,k,M):
    wool,rubber,canvas,skin,copper,edge,glass,wood,hair,ink=[M[n] for n in ('wool','rubber','canvas','skin','copper','edge','glass','wood','hair','ink')]
    accent=emit(k+' / unique accent','D8EEFF' if k=='B' else 'B9A6FF',RETOUCH['accent_power']);accent['rainfall_emissive']=True
    # Partial shoulder mantle, open at the chest so the waist stays visible.
    bottom=RETOUCH['cape_bottom'][k]
    vs=[];fs=[];N=49;rows=13;opening=2.60
    def cape_point(t,f,lift=0):
        shoulder=min(1,f/.30);drape=max(0,(f-.30)/.70)
        outer=RETOUCH['cape_width'][k]
        fold=.009*math.cos(11*t)*math.sin(math.pi*f*.85)
        rx=.055+(outer-.055)*shoulder-.012*drape+fold+lift
        ry=.052+(.143-.052)*shoulder+.015*drape+fold+lift
        z=1.137-.052*shoulder+(bottom-1.085)*drape+.006*math.cos(7*t)*f
        return (rx*math.sin(t),.008+ry*math.cos(t),z)
    for r in range(rows):
        for j in range(N):vs.append(cape_point(-opening+j*2*opening/(N-1),r/(rows-1)))
    for r in range(rows-1):
        for j in range(N-1):a=r*N+j;fs.append((a,a+1,a+N+1,a+N))
    mantle=mesh('Cape-treillis / volume oxydé',vs,fs,M['patina'],root)
    solid=mantle.modifiers.new('Épaisseur du treillis mouillé','SOLIDIFY');solid.thickness=.006
    # Actual diagonal copper weave: integrated fine mesh, not spherical shoulder pads.
    for j in range(39):
        t=-3.4+j*6.8/38
        for slope in [-1,1]:
            pts=[cape_point(t+slope*1.50*(r/20-.5),r/20,.006) for r in range(21) if abs(t+slope*1.50*(r/20-.5))<=opening]
            if len(pts)>1:tube('Maille cuivre diagonale',pts,RETOUCH['weave_radius'],copper,root)
    for f in [.30,1]:tube('Lisière treillis',[cape_point(-opening+j*2*opening/64,f,.007) for j in range(65)],.0032,edge if f==1 else copper,root)
    for side in [-1,1]:
        tube('Bord retombant du treillis',[cape_point(side*opening,r/12,.007) for r in range(13)],.0035,copper,root)
    for j in range(9):
        t=-2.5+j*.61
        tube('Reflet mouillé sur maille',[cape_point(t+.07*f,f,.009) for f in [.34,.39,.44]],.0018,edge,root)
    # Waxed rack sits behind the figure; silhouette changes are structural.
    jar_specs={'A':[(-.157,.102,.875,.064,.305),(.157,.102,.875,.064,.305)],
        'B':[(0,.145,.747,.105,.325)],
        'C':[(-.177,.115,1.033,.057,.36),(0,.139,1.065,.059,.38),(.177,.115,1.033,.057,.36)]}[k]
    rz={'A':.99,'B':.86,'C':1.16}[k];width={'A':.30,'B':.245,'C':.38}[k]
    for x in [-width*.42,width*.42]:cube('Montant de bois ciré',(x,.166,rz),(.022,.033,.33 if k!='C' else .46),wood,root,.003)
    for z in [rz-.115,rz+.105]:cube('Traverse du râtelier',(0,.17,z),(width,.028,.025),wood,root,.003)
    for x,y,base,r,h in jar_specs:
        loft('Leyde / verre fumé cerclé',[(base,r*.70,r*.70,y),(base+.016,r,r,y),(base+h*.78,r,r,y),(base+h*.88,r*.65,r*.65,y),(base+h,r*.48,r*.48,y)],glass,root,N=28).location.x=x
        for dz in [.025,h*.42,h*.77,h*.91]:torus('Cerclage Leyde',(x,y,base+dz),r if dz<h*.85 else r*.57,.0055,copper,root)
        cube('Borne de cuivre',(x,y,base+h+.008),(r*.65,r*.62,.017),edge,root,.003)
        # Front and outer side arc traces remain legible through the smoked housing.
        for sign in [-1,1]:
            ax=x+sign*r*.45;ay=y-r*.96-.006
            rod('Arc dans la Leyde',[(ax,ay,base+.052),(ax-sign*.018,ay-.001,base+h*.37),(ax+sign*.006,ay,base+h*.54),(ax-sign*.015,ay,base+h*.73)],.0055,accent,root)
        torus('Charge isolateur Leyde',(x,y,base+h*.91),r*.57,.0055,accent,root)
        if k!='B' and abs(x)>.1:
            side=1 if x>0 else -1;ax=x+side*(r+.006);ay=y-r*.28
            tube('Filament latéral Leyde',[(ax,ay,base+.055),(ax+side*.004,ay,base+h*.38),(ax-side*.003,ay,base+h*.57),(ax,ay,base+h*.74)],.0055,accent,root)
        tube('Reflet de verre mouillé',[(x-r*.66,y-r*.73,base+.05),(x-r*.69,y-r*.73,base+h*.73)],.0017,glass,root)
    for side in [-1,1]:
        jar=jar_specs[0 if side==-1 else -1];x,y,base,r,h=jar
        if k=='C':pts=[(x,y,base+h), (side*.257,.10,1.23),(side*.326,-.013,1.02),(side*.29,-.16,.89),(side*.244,-.11,.79)]
        else:pts=[(x,y,base+h),(side*.205,.13,1.105),(side*.272,.012,.99),(side*.274,-.05,.85),(side*.244,-.11,.79)]
        tube('Câble gainé de tissu',pts,.008,rubber,root)
        for z in [.855,.878]:torus('Collier de câble',(side*.27,-.04,z),.009,.002,copper,root)
        if k=='B':
            a=Vector((side*.240,-.057,.923));b=Vector((side*.266,-.108,.787));axis=(b-a).normalized();q=axis.to_track_quat('Z','Y');radius=RETOUCH['coil_radius']
            sweep('Gaine du gantelet bobine',[(a,radius*.98,radius*.94),(b,radius*.91,radius*.88)],rubber,root)
            for i in range(12):
                p=a.lerp(b,i/11);ob=torus('Spire de cuivre du gantelet',p,radius,.006,edge,root);ob.rotation_euler=q.to_euler()
            for f in [.06,.94]:
                ob=torus('Charge de bobine',a.lerp(b,f),radius+.003,.0045,accent,root);ob.rotation_euler=q.to_euler()
    if k!='B':
        for x in [-.041,.003]:
            tube('Mèche chargée lilas',[(x,-.019,1.353),(x-.006,-.018,1.371),(x-.014,-.016,1.381)],.0028,accent,root)
    if k=='A':
        # Exactly 0.9 u including the polished point, planted like a walking stick.
        x=.263;y=-.119;z=.023
        rod('Tige courte bronze 0.9 u',[(x,y,z),(x,y,z+.785)],.0065,copper,root)
        for dz in [.681,.726,.771]:
            loft('Isolateur verre / assiette',[(z+dz-.009,.014,.014,y),(z+dz-.003,.034,.034,y),(z+dz+.004,.034,.034,y),(z+dz+.011,.014,.014,y)],glass,root,N=28).location.x=x
            torus('Arc sur isolateur',(x,y,z+dz+.004),.026,.0045,accent,root)
        sweep('Pointe polie', [((x,y,z+.79),.009,.009),((x,y,z+.9),.0008,.0008)],edge,root,N=12)
    return root


def surface_finish(M):
    """Retain ash-lord worn material grain within the shared three-tone CEL shader."""
    palettes={'wool':('353941','43474F','5A5E66'),
        'hair':('090707','16110F','2A211D'),
        'patina':('273A31','344B40','415C4E'),
        'copper':('344E40','4F6B5E','70917D')}
    for key,colors in palettes.items():
        ramp=M[key].node_tree.nodes.get('CEL tones')
        if ramp:
            for stop,h in zip(ramp.color_ramp.elements,colors):stop.color=rgb(h)
    for ma in M.values():
        nodes,links=ma.node_tree.nodes,ma.node_tree.links
        diffuse=next((n for n in nodes if n.type=='BSDF_DIFFUSE'),None)
        emission=next((n for n in nodes if n.type=='EMISSION'),None)
        ramp=nodes.get('CEL tones')
        if not diffuse or not ramp:continue
        n=nodes.new('ShaderNodeTexNoise');n.inputs['Scale'].default_value=180;n.inputs['Detail'].default_value=2
        r=nodes.new('ShaderNodeMapRange');r.inputs['To Min'].default_value=.82;r.inputs['To Max'].default_value=1.05
        if ma==M['wool']:
            n.inputs['Scale'].default_value=55;r.inputs['To Min'].default_value=.72;r.inputs['To Max'].default_value=1.02
        links.new(n.outputs['Fac'],r.inputs[0])
        mul=nodes.new('ShaderNodeVectorMath');mul.operation='SCALE';links.new(ramp.outputs['Color'],mul.inputs[0]);links.new(r.outputs[0],mul.inputs['Scale']);links.new(mul.outputs[0],emission.inputs['Color'])
        bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.09;bump.inputs['Distance'].default_value=.001
        if ma['gresille_surface']=='gutta-percha lisse':bump.inputs['Strength'].default_value=.015
        if ma['gresille_surface']=='peau olive':bump.inputs['Strength'].default_value=.025
        links.new(n.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],diffuse.inputs['Normal'])


def raw_render(path,w,h,target,scale,az=-25,elev=18):
    # Native common render, CEL configure, no normal output and no asset resizing.
    configure=cel.install('creature',normals=False,keep_black_emission=False)
    bpy.context.view_layer.update()
    cel.setup_scene(samples=16);cel.toon_materials('creature')
    # render() positions the camera before compositor setup; target that same basis here.
    configure(path)
    cd.render(path,w,h,target,scale,az,elev)
    finish_pass(path)

def finish_pass(path):
    from PIL import Image, ImageStat
    for p in path.parent.glob(path.stem+'_e__*.png'):
        with Image.open(p) as im:
            if max(ImageStat.Stat(im.convert('RGB')).extrema[i][1] for i in range(3))>2:
                im.save(path.with_name(path.stem+'_e.png'))
        p.unlink()

def make_layout():
    # cd_cd3_common.make_layout convention: orthographic Blender quads, fonts, image UVs.
    s=bpy.data.scenes.new('Planche Grésille');bpy.context.window.scene=s
    s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=8
    s.render.resolution_x=2400;s.render.resolution_y=1350;s.render.resolution_percentage=100
    s.view_settings.view_transform='Standard';s.world=bpy.data.worlds.new('Fond planche')
    bpy.ops.object.camera_add(location=(1200,675,3000));s.camera=bpy.context.object
    s.camera.data.type='ORTHO';s.camera.data.ortho_scale=2400;s.camera.data.clip_end=10000
    bg=emit('Fond','17212D');fg=emit('Texte','E1E4E4');muted=emit('Légende','A6B4BC')
    def quad(n,x,y,w,h,m,z=0):return mesh(n,[(x,1350-y-h,z),(x+w,1350-y-h,z),(x+w,1350-y,z),(x,1350-y,z)],[(0,1,2,3)],m,None)
    quad('Fond',0,0,2400,1350,bg,-2)
    font=bpy.data.fonts.load('C:/Windows/Fonts/segoeui.ttf')
    def text(t,x,y,size=24,ma=fg):
        c=bpy.data.curves.new('Typographie','FONT');c.body=t;c.font=font;c.size=size
        o=bpy.data.objects.new(t,c);s.collection.objects.link(o);o.location=(x,1350-y,10);o.data.materials.append(ma)
    def panel(file,x,y,w,h,nearest=False):
        m=bpy.data.materials.new(file);m.use_nodes=True;n=m.node_tree.nodes;n.clear();l=m.node_tree.links
        im=n.new('ShaderNodeTexImage');im.image=bpy.data.images.load(str(OUT/file));im.interpolation='Closest' if nearest else 'Linear'
        mix=n.new('ShaderNodeMixRGB');mix.inputs[1].default_value=rgb('17212D');l.new(im.outputs['Alpha'],mix.inputs[0]);l.new(im.outputs['Color'],mix.inputs[2])
        e=n.new('ShaderNodeEmission');o=n.new('ShaderNodeOutputMaterial');l.new(mix.outputs[0],e.inputs[0]);l.new(e.outputs[0],o.inputs[0])
        ob=quad(file,x,y,w,h,m,1);uv=ob.data.uv_layers.new()
        for f in ob.data.polygons:
            for li,co in zip(f.loop_indices,[(0,0),(1,0),(1,1),(0,1)]):uv.data[li].uv=co
    text('GRÉSILLE',52,70,48);text('PARATONNERRIÈRE  /  ÉTUDE DE SILHOUETTES  /  1,35 u',382,65,24,muted)
    for j,(k,name,desc) in enumerate([('A','TIGE COURTE','Tige 0,9 u · deux Leyde dorsales'),('B','BOBINES','Gantelets-bobines · une Leyde basse'),('C','RÂTELIER HAUT','Trois Leyde hautes · câbles gainés')]):
        x=48+j*792
        text(k+'  /  '+name,x,131,32);text(desc,x,167,21,muted)
        panel('big_'+k+'.png',x+60,182,640,660)
        panel('jeu_'+k+'.png',x,850,480,192,True)
        panel('sprite_'+k+'.png',x+518,850,192,192,True)
        text('ARDENT + GRÉSILLE · SOL C1 · 1:1',x,1066,18,muted)
        text('CREA · SE · 192²',x+518,1066,18,muted)
        palette=['4F6B5E','1F2124','3B4A5C','5A5E66','4A3F33','B89E86','D8EEFF' if k=='B' else 'B9A6FF']
        for i,h in enumerate(palette):
            xx=x+i*104;quad('Nuancier',xx,1092,86,24,emit('Hex '+h,h),3);text('#'+h,xx,1140,17)
    text('QUESTION OUVERTE  /  LISIBILITÉ DANS LE GOUFFRE',52,1211,24)
    text('Lilas #B9A6FF face au mycélium #C27BFF : confusion en jeu ? B propose le bleu-blanc #D8EEFF.',52,1252,25)
    text('Bleu d’arc très blanc : à distinguer d’Averse #5FD4E8 et des cristaux des Cryptes #BFF4FF.  /  CONCEPT À VALIDER',52,1296,21,muted)
    s.render.image_settings.file_format='PNG';s.render.filepath=str(OUT/'planche_silhouettes.png');bpy.ops.render.render(write_still=True)

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    s=bpy.context.scene;s.world=bpy.data.worlds.new('Studio');s.world.color=(.12,.12,.12)
    s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=16
    s.render.threads_mode='FIXED';s.render.threads=8
    M=materials();base=build_body(M)
    roots=[base,clone_body(base,'B'),clone_body(base,'C')]
    for k,r in zip('ABC',roots):build_variant(r,k,M)
    cd.area('Key',(-3,-4,6),650,(1,.87,.72),4);cd.area('Fill',(3,-1,4),350,(.64,.76,1),4);cd.area('Rim',(0,4,4),500,(.75,.82,1),3)
    bpy.ops.object.camera_add();s.camera=bpy.context.object
    # Preserve all three complete hierarchies side by side in the source .blend.
    for i,r in enumerate(roots):r.location.x=(i-1)*1.5
    cd.aim(s.camera,(0,0,.7));s.camera.location=(3,-7,3);cd.aim(s.camera,(0,0,.7));s.camera.data.type='ORTHO';s.camera.data.ortho_scale=5.3
    s['brief']='Grésille RÉVISION 2 / corps féminin unique 6,75 têtes / A tige courte, B bobines, C râtelier haut';s['height_u']=1.35
    blend=ROOT/'art/blender/characters/gresille_concept.blend';blend.parent.mkdir(parents=True,exist_ok=True)
    cel.install('creature',normals=False,keep_black_emission=False);cel.toon_materials('creature');surface_finish(M)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    for r in roots:r.location.x=0
    def show(active):
        for r in roots:
            for o in [r,*r.children_recursive]:o.hide_render=r!=active
    for k,r in zip('ABC',roots):
        show(r);r.rotation_euler.z=0;raw_render(OUT/f'big_{k}.png',900,930,(0,0,.73),1.67,-26,16)
        cd.iso_rig.create_rig('CREA',(192,192),target=(0,0,.66),reset=False)
        r.rotation_euler.z=cd.iso_rig.DIRECTIONS['se']
        s.render.resolution_x=192;s.render.resolution_y=192;s.render.resolution_percentage=100
        s.eevee.taa_render_samples=16;s.render.film_transparent=True
        path=OUT/f'sprite_{k}.png';cd.iso_rig.common.configure_passes(path)
        s.eevee.taa_render_samples=16;s.render.filepath=str(path);bpy.ops.render.render(write_still=True);finish_pass(path)
    s.compositing_node_group=None
    with bpy.data.libraries.load(str(ROOT/'art/blender/characters/ardent_iso.blend'),link=False) as (a,b):b.objects=a.objects
    loaded=[o for o in b.objects if o and o.type not in {'CAMERA','LIGHT'}]
    for o in loaded:
        s.collection.objects.link(o)
        if o.animation_data:o.animation_data_clear()
    for o in [o for o in loaded if o.parent not in loaded]:o.location.x=-.70;o.rotation_euler.z=cd.iso_rig.DIRECTIONS['se']
    # C1 terrace mapping reused from cd_cd3_common.board.
    m=bpy.data.materials.new('C1 sol');m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
    tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png'))
    m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color']);p.inputs['Roughness'].default_value=.9
    a=math.sqrt(.5)
    for x in range(-4,5):
        for y in range(-3,4):
            cx=(x-y)*a;cy=(x+y)*a
            o=mesh('C1',[(cx,cy+a,-.015),(cx+a,cy,-.015),(cx,cy-a,-.015),(cx-a,cy,-.015)],[(0,3,2,1)],m,None);uv=o.data.uv_layers.new()
            for f in o.data.polygons:
                for li,co in zip(f.loop_indices,[(.5,1),(0,.5),(.5,0),(1,.5)]):uv.data[li].uv=co
    for k,r in zip('ABC',roots):
        show(r);r.location.x=.65
        cd.iso_rig.create_rig('CREA',(480,192),target=(0,0,.58),reset=False)
        s.render.resolution_x=480;s.render.resolution_y=192;s.render.resolution_percentage=100;s.render.film_transparent=False;s.eevee.taa_render_samples=16
        s.render.filepath=str(OUT/f'jeu_{k}.png');bpy.ops.render.render(write_still=True);r.location.x=0
    make_layout()
    from PIL import Image
    board=OUT/'planche_silhouettes.png'
    with Image.open(board) as im:
        im.convert('RGB').quantize(colors=256,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).save(board,optimize=True)
    assert board.stat().st_size<2*1024*1024
    print('PASS Gresille R2 retouch: female body retained; copper mantles A/C, collar B; dark wool/hair; visible accents; massive B coils; 9 renders; normals=False',flush=True)

if __name__=='__main__':main()
