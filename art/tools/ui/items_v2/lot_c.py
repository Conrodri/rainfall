"""Lot C: sculpted, worn inventory icons; background Eevee only."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from iv2_lib import *
from mathutils import Matrix

IDS=['etincelle','flocon','fiole_verte','pavois_fele','coeur_de_mousse','piece_porte_bonheur','eclat_d_experience','plume_d_empenne']

def glow(color):return mat(color,emit_hex=color,emit_strength=.85)

def facet(points,material,y=-.2,name='Broad worn facet'):
    return plate(points,.012,material,name,y=y,bevel=0)

def crystal(points,center,mats,name='Crystal',depth=.2,y=0):
    # Real triangular relief, with an off-axis ridge and broad readable planes.
    cx,cz=center;n=len(points)
    verts=[(x,y,z) for x,z in points]+[(cx,y-depth,cz),(cx,y+depth*.65,cz)]
    faces=[(i,(i+1)%n,n) for i in range(n)]+[((i+1)%n,i,n+1) for i in range(n)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    for m in mats:o.data.materials.append(m)
    for i,p in enumerate(o.data.polygons):p.material_index=i%len(mats)
    return o

def etincelle():
    stone=mat('#6C7275');light=mat('#B5B8AE');shade=mat('#454E54');rust=mat('#8E6243')
    flame=mat('#CD6B2F');lit=mat('#E7AB60');hot=glow('#FF9B39')
    crystal([(-1.03,-.72),(-.78,-1.12),(.56,-1.13),(1.01,-.80),(.77,-.38),(.13,-.23),(-.64,-.34)],(-.16,-.52),[stone,shade,light,stone,rust],depth=.38,name='Split flint stone')
    # Wind-bent flame: angular tongue, unequal shoulders, no floating confetti.
    plate([(-.46,-.54),(-.65,-.17),(-.52,.20),(-.25,.44),(-.37,.78),(-.11,.64),(.28,1.40),(.27,.85),(.56,.51),(.43,.19),(.67,.34),(.63,-.09),(.28,-.49)],.16,flame,'Wind bent ember',y=-.23,bevel=.018)
    facet([(-.42,-.36),(-.39,.06),(-.16,.34),(-.13,.76),(.13,.53),(.28,.98),(.24,.29),(.43,.02),(.22,-.36)],lit,y=-.329)
    plate([(-.21,-.47),(-.26,-.13),(-.05,.15),(.04,.56),(.17,.22),(.11,-.11),(.27,-.37),(.07,-.51)],.02,hot,'One thick incandescent core',y=-.355,bevel=.008)
    line([(-.67,-.66),(-.33,-.56),(-.12,-.69),(.08,-.64)],shade,.027,y=-.39,name='Flint fracture')

def flocon():
    silver=mat('#A2C6CF');ice=mat('#5E899E');white=mat('#D3E5DF');dark=mat('#3E6477');accent=glow('#5FD4E8')
    for i in range(6):
        a=math.radians(i*60+10);c,s=math.cos(a),math.sin(a)
        def p(x,z):return (x*c-z*s,x*s+z*c)
        poly=[p(x,z) for x,z in [(-.115,.10),(-.105,.71),(-.37,.95),(-.34,1.08),(-.10,.92),(-.065,1.31),(0,1.41),(.08,1.27),(.10,.92),(.35,1.09),(.39,.96),(.105,.70),(.115,.10)]]
        plate(poly,.16,ice,'Six thick ice arms',bevel=.018)
        facet([p(x,z) for x,z in [(0,.15),(-.055,.73),(-.28,.98),(-.05,.85),(0,1.29),(.04,.73),(.04,.15)]],silver,y=-.095)
        line([p(0,.30),p(0,1.14)],white,.021,y=-.113,name='Frost ridge')
    crystal([(-.24,-.14),(-.22,.15),(0,.28),(.25,.14),(.24,-.15),(0,-.29)],(-.05,.03),[silver,white,dark],depth=.20,y=-.11,name='Hexagonal ice hub')
    line([(-.10,-.12),(-.13,.08),(.02,.18),(.17,.08),(.14,-.10),(-.10,-.12)],accent,.036,y=-.33,name='Single cyan heart')

def fiole_verte():
    metal=mat('#A6B4A7');rim=mat('#CBD5BC');glass=mat('#435F56');glasslight=mat('#7D9D88');liquid=mat('#7FA35B');bright=mat('#91AC70');cork=mat('#92704C');dark=mat('#2A3931');accent=glow('#7FA35B')
    shape=[(-.17,1.23),(.17,1.23),(.20,.68),(.53,.23),(.66,-.23),(.56,-.76),(.25,-1.04),(-.24,-1.05),(-.59,-.77),(-.65,-.27),(-.49,.27),(-.19,.68)]
    plate(shape,.42,glass,'Heavy teardrop glass',bevel=.06)
    plate([(-.44,.12),(.45,.12),(.52,-.27),(.44,-.69),(.20,-.88),(-.19,-.90),(-.46,-.66),(-.53,-.29)],.025,liquid,'Opaque herbal infusion',y=-.238,bevel=.025)
    facet([(-.44,.09),(.43,.09),(.37,-.025),(-.43,-.025)],accent,y=-.261,name='Single toxic meniscus accent')
    facet([(-.45,-.16),(-.31,-.12),(-.34,-.59),(-.14,-.81),(-.28,-.78),(-.46,-.57)],glasslight,y=-.278,name='Wide glass reflection')
    line([(-.13,.95),(-.14,.62),(-.40,.26),(-.51,-.07)],rim,.035,y=-.266,name='Worn glass shoulder')
    for z in [.70,1.08]:bevelled_box((0,-.01,z),(.49,.52,.14),metal,.03,'Pewter neck collar')
    bevelled_box((0,0,1.27),(.29,.31,.25),cork,.025,'Tapered cork')
    line([(-.06,1.22),(-.04,1.35)],dark,.018,y=-.17,name='Cork split')
    # Small irregular rising bubbles; no dark eye rings or curved mouth mark.
    for x,z,r in [(.28,-.19,.027),(.22,-.40,.019),(.30,-.57,.013)]:
        disk(x,z,r,bright,y=-.275,depth=.008)

def pavois_fele():
    wood=mat('#92724D');wood2=mat('#715B42');light=mat('#B79868');iron=mat('#687778');edge=mat('#B0B8AC');black=mat('#292E2B');rust=mat('#86664B');accent=glow('#DB9D51')
    disk(0,0,1.20,iron,y=.02,depth=.24)
    disk(0,0,1.075,black,y=-.13,depth=.025)
    # Separate planks with visible joints; the central jagged fracture stays open.
    for i in range(7):
        x=-1.015+i*.29;xr=x+.275
        z0=math.sqrt(max(0,1.04**2-max(abs(x),abs(xr))**2))
        samples=[x+(xr-x)*j/6 for j in range(7)]
        upper=[(xx,math.sqrt(max(0,1.04**2-xx**2))) for xx in reversed(samples)]
        lower=[(xx,-math.sqrt(max(0,1.04**2-xx**2))) for xx in samples]
        plate(lower+upper,.075,wood if i%2 else wood2,'Oak plank',y=-.18,bevel=.012)
        if i in [1,3,5]:line([(x+.065,-z0*.70),(x+.05,z0*.63)],light,.015,y=-.23,name='Worn wood fibre')
    # Broad broken seam and a single luminous splinter at its foot.
    crack=[(.20,1.05),(.10,.70),(.22,.43),(.04,.13),(.12,-.16),(-.08,-.45),(-.02,-.78),(-.20,-1.04)]
    line(crack,black,.055,y=-.257,name='Open jagged shield crack')
    line([(.16,.69),(.29,.58),(.36,.59)],black,.024,y=-.258)
    line([(-.08,-.45),(-.02,-.76),(-.15,-.94)],accent,.033,y=-.28,name='One lucky glowing splinter')
    torus((0,-.21,0),1.14,.075,iron,'Heavy riveted iron band')
    for i in range(10):
        a=math.radians(i*36+9);x,z=1.14*math.cos(a),1.14*math.sin(a)
        disk(x,z,.041,edge,y=-.286,depth=.028)
    disk(-.13,.03,.34,black,y=-.27,depth=.10)
    crystal([(-.43,.03),(-.27,.28),(.02,.29),(.18,.04),(.02,-.22),(-.28,-.24)],(-.17,.08),[iron,edge,iron,rust],depth=.18,y=-.32,name='Hammered shield boss')

def coeur_de_mousse():
    stone=mat('#8B9691');light=mat('#BBC0AA');dark=mat('#535F5A');moss=mat('#607C43');ml=mat('#8F9C59');md=mat('#405A38');accent=glow('#A2BD64')
    pts=[(0,-1.18),(-.92,-.29),(-1.10,.25),(-1.01,.72),(-.65,.98),(-.28,.92),(.02,.62),(.34,.96),(.74,.94),(1.04,.66),(1.08,.18),(.85,-.32)]
    crystal(pts,(-.08,.03),[stone,dark,stone,light,stone,dark,light],depth=.40,name='Weathered heart shaped stone')
    facet([(-1.02,.28),(-.91,.68),(-.62,.91),(-.30,.85),(-.10,.59),(-.30,.42),(-.43,.57),(-.59,.29),(-.78,.41),(-.84,.14)],moss,y=-.31,name='Broad old moss crust')
    facet([(-.91,.51),(-.67,.79),(-.38,.76),(-.22,.60),(-.43,.59),(-.55,.43),(-.73,.54)],ml,y=-.334)
    facet([(.57,-.38),(.81,-.19),(.97,.17),(.79,.24),(.71,.05),(.51,.06),(.43,-.20),(.26,-.32),(.25,-.57)],md,y=-.30)
    facet([(.54,-.30),(.78,-.16),(.87,.10),(.74,.04),(.58,-.05),(.46,-.25)],moss,y=-.33)
    line([(.27,.43),(.14,.24),(.25,.03),(.10,-.23),(.18,-.44)],dark,.026,y=-.414,name='Stone fault')
    line([(-.65,.59),(-.54,.45),(-.37,.49),(-.26,.36)],accent,.038,y=-.36,name='Single moss light')

def piece_porte_bonheur():
    gold=mat('#C1A05B');light=mat('#E3CC91');dark=mat('#76603B');patina=mat('#526C58');recess=mat('#565E3E');accent=glow('#EFC469')
    disk(0,0,1.13,dark,y=.03,depth=.22)
    disk(0,0,1.09,gold,y=-.10,depth=.06)
    disk(0,0,.94,dark,y=-.145,depth=.015)
    disk(0,0,.87,gold,y=-.16,depth=.015)
    torus((0,-.181,0),1.015,.040,light,'Worn coin raised lip')
    # Engraving: four angular heart leaves cut into the gold surface.
    leaf=[(0,.03),(-.29,.30),(-.31,.51),(-.17,.62),(0,.49),(.17,.62),(.31,.51),(.29,.30)]
    for i in range(4):
        a=math.radians(i*90+12);c,s=math.cos(a),math.sin(a)
        points=[(x*c-z*s,x*s+z*c+.06) for x,z in leaf]
        plate(points,.012,recess,'Incised clover leaf',y=-.181,bevel=.012)
        line([(0,.06),(-.10*math.sin(a),.06+.34*math.cos(a))],patina,.018,y=-.196,name='Patina in engraving')
    line([(0,.02),(.15,-.47),(.32,-.66)],recess,.050,y=-.19,name='Clovers bent stem')
    for i in range(12):
        a=math.radians(i*30);x,z=.94*math.cos(a),.94*math.sin(a)
        line([(x*.96,z*.96),(x*1.025,z*1.025)],dark,.016,y=-.20,name='Minted rim ticks')
    line([(-.93,.37),(-.81,.60),(-.65,.77)],accent,.033,y=-.225,name='One warm rim glint')
    for x,z in [(.62,-.54),(.55,-.62),(-.50,-.72)]:line([(x,z),(x+.09,z+.04)],light,.018,y=-.20,name='Coin wear')

def eclat_d_experience():
    shadow=mat('#365B6B');cyan=mat('#668F9A');light=mat('#C0D5CF');mid=mat('#86B2BA');accent=glow('#63D9E3');rock=mat('#575F62')
    crystal([(-.49,-.90),(-.62,.09),(-.20,1.49),(.41,.76),(.59,-.18),(.23,-1.16)],(-.04,.17),[shadow,light,mid,cyan,shadow,mid],depth=.43,name='Single experience crystal')
    # Small broken mineral foot stays subordinate to the large pointed shard.
    crystal([(-.63,-.80),(-.75,-1.03),(-.18,-1.20),(.32,-1.12),(.40,-.89),(-.05,-.76)],(-.14,-.94),[rock,shadow,cyan],depth=.24,y=-.04,name='Mineral fracture foot')
    line([(-.16,1.22),(-.08,.64),(-.18,.28),(-.06,-.04),(-.11,-.47)],accent,.043,y=-.46,name='Single cyan experience seam')

def plume_d_empenne():
    slate=mat('#788A91');pale=mat('#BCC6BF');mid=mat('#95A2A0');dark=mat('#42565E');shaft=mat('#B6AA83');accent=glow('#73BEC9')
    # Feather has interlocking vane cuts; coarse enough for a 48 px inventory slot.
    left=[(-.04,-.97),(-.36,-.74),(-.54,-.39),(-.42,-.38),(-.61,-.15),(-.66,.17),(-.51,.08),(-.64,.43),(-.53,.76),(-.41,.68),(-.42,1.03),(-.22,1.31),(.03,1.50),(.10,.99),(.04,.48),(.02,-.15)]
    right=[(.04,-.98),(.33,-.73),(.47,-.43),(.32,-.45),(.56,-.13),(.57,.18),(.44,.10),(.56,.49),(.43,.86),(.32,.74),(.30,1.10),(.03,1.50),(.10,.99),(.04,.48),(.02,-.15)]
    plate(left,.085,slate,'Left cut feather vane',bevel=.015)
    plate(right,.085,mid,'Right cut feather vane',y=.012,bevel=.015)
    facet([(-.04,-.73),(-.37,-.31),(-.48,.20),(-.35,.63),(-.20,1.14),(.01,1.39),(-.13,.60),(-.18,.06)],pale,y=-.06,name='Broad feather sheen')
    for x,z in [(-.48,-.11),(-.46,.35),(-.33,.78),(.43,-.10),(.43,.39),(.31,.80)]:
        line([(.045,z-.30),(x,z)],dark,.016,y=-.08,name='Coarse feather barbs')
    line([(.02,-1.39),(-.02,-.73),(.02,-.12),(.08,.57),(.04,1.40)],shaft,.036,y=-.105,name='Strong hollow quill')
    line([(.02,-1.25),(-.01,-1.02),(-.005,-.81)],accent,.041,y=-.147,name='Single cyan quill mark')

def deliver_c(ident):
    objs=[o for o in bpy.context.scene.objects if o.type in {'MESH','CURVE'}]
    bpy.context.view_layer.update()
    yaw=Matrix.Rotation(math.radians(-9),4,'Z')
    for o in objs:o.matrix_world=yaw@o.matrix_world
    if ident in {'fiole_verte','eclat_d_experience','plume_d_empenne'}:
        axis=bpy.context.scene.camera.rotation_euler.to_matrix()@Vector((0,0,1))
        tilt=Matrix.Rotation(math.radians(-39 if ident=='fiole_verte' else 39),4,axis)
        for o in objs:o.matrix_world=tilt@o.matrix_world
    frame_object_ortho(objs,margin=.07)
    # Fit evaluated vertices, including bevels, into 87.5% of the square.
    cam=bpy.context.scene.camera;basis=cam.rotation_euler.to_matrix();inv=basis.transposed()
    graph=bpy.context.evaluated_depsgraph_get();points=[]
    for obj in objs:
        ev=obj.evaluated_get(graph);mesh=ev.to_mesh()
        points.extend(inv@(obj.matrix_world@v.co) for v in mesh.vertices);ev.to_mesh_clear()
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    cam.location=basis@((lo+hi)*.5+Vector((0,0,10)))
    cam.data.ortho_scale=max(hi.x-lo.x,hi.y-lo.y)/.875
    cel.toon_materials('icon');RAW.mkdir(parents=True,exist_ok=True)
    raw=RAW/(ident+'.png');cel.cel_passes(raw,'icon',base_configure=passes,normals=False)
    bpy.context.scene.render.filepath=str(raw);bpy.ops.render.render(write_still=True)
    before=ROOT/'art/renders/items_v2/before';before.mkdir(parents=True,exist_ok=True)
    if not (before/raw.name).exists():shutil.copy2(DEST/raw.name,before/raw.name)
    subprocess.run([PY,'-I',str(Path(__file__).with_name('check_c.py')),'--finalize',ident],check=True)

def main():
    chosen=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else IDS
    if set(chosen)-set(IDS):raise ValueError('Unknown lot C item')
    scenes=[]
    for ident in chosen:
        scenes.append(reset(ident));globals()[ident]();deliver_c(ident)
    for s in list(bpy.data.scenes):
        if s not in scenes:bpy.data.scenes.remove(s)
    out=ROOT/'art/blender/items_v2/lot_c.blend';out.parent.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(out))
    print('PASS lot_c '+str(len(chosen))+' icons',flush=True)
if __name__=='__main__':main()
