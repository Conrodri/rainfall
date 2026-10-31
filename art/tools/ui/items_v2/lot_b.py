"""Eight worn cel inventory objects; background rendering only."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from iv2_lib import *
IDS=['sablier_fele','antidote','botte_rapiecee','pierre_a_aiguiser','bague_de_vigueur','amulette_de_cuir','aimant_de_poche','sifflet_de_chasse']

def accent(color):return mat(color,emit_hex=color,emit_strength=.8)
def box(x,z,w,h,m,y=0,d=.2):return bevelled_box((x,y,z),(w,d,h),m,.025,'Worn fitting')
def rivet(x,z,m,y=-.24):disk(x,z,.045,m,y=y)

def sablier_fele():
    wood=mat('#896849');edge=mat('#C1A77A');glass=mat('#91ADB0');shade=mat('#526C72');sand=mat('#5FD4E8');glow=accent('#5FD4E8')
    for z in [-1.12,1.12]:
        box(0,z,1.44,.19,wood,d=.68);box(0,z+.065,1.35,.055,edge,y=-.35,d=.045)
    for x in [-.56,.56]:
        line([(x,-1.02),(x,1.02)],wood,.065,y=-.23,name='Turned wood upright')
        for z in [-.88,.88]:box(x,z,.18,.12,edge,y=-.23)
    outline=[(-.43,1.00),(.43,1.00),(.40,.64),(.23,.22),(.08,0),(.24,-.26),(.41,-.67),(.43,-1),(-.43,-1),(-.41,-.67),(-.24,-.26),(-.08,0),(-.23,.22),(-.40,.64)]
    plate(outline,.33,shade,'Hourglass silhouette',bevel=.035)
    plate([(x*.86,z*.96) for x,z in outline],.045,glass,'Faceted glass',y=-.185)
    plate([(-.32,.72),(.32,.72),(.18,.26),(0,.04),(-.18,.26)],.02,sand,'Upper sand',y=-.22)
    plate([(-.33,-.92),(.33,-.92),(.22,-.73),(0,-.48),(-.22,-.73)],.02,sand,'Lower sand',y=-.22)
    line([(0,.12),(0,-.57)],glow,.025,y=-.26,name='Cyan falling sand')
    line([(.30,.92),(.12,.69),(.22,.42),(.08,.24)],edge,.019,y=-.25,name='Glass crack')

def antidote():
    green=mat('#748968');light=mat('#A9B98A');dark=mat('#344F43');cork=mat('#B29971');metal=mat('#C9C6A8');glow=accent('#7FA35B')
    plate([(-.29,.64),(-.31,.30),(-.67,.05),(-.78,-.39),(-.61,-.84),(-.32,-1),(.37,-1),(.68,-.79),(.78,-.36),(.65,.06),(.29,.31),(.28,.64)],.58,green,'Apothecary flask',bevel=.08)
    plate([(-.58,-.34),(-.44,-.76),(.30,-.83),(.59,-.62),(.59,-.34)],.03,dark,'Medicine level',y=-.33)
    line([(-.55,-.16),(-.60,-.40),(-.46,-.72)],light,.055,y=-.36,name='Worn glass bevel')
    box(0,.57,.65,.16,metal,d=.64);box(0,.84,.47,.40,cork,d=.42)
    box(0,-.34,.20,.65,metal,y=-.39,d=.035);box(0,-.34,.57,.19,metal,y=-.42,d=.035)
    line([(-.29,.48),(.28,.48)],glow,.045,y=-.36,name='Single green neck seal')

def botte_rapiecee():
    leather=mat('#906D51');dark=mat('#443B33');patch=mat('#BA9569');thread=mat('#DACBA7');glow=accent('#F2C14E')
    shape=[(-.48,1.10),(.34,1.10),(.28,.48),(.27,-.17),(.54,-.42),(.95,-.52),(1.02,-.77),(.84,-.94),(-.55,-.94),(-.66,-.74),(-.53,-.18)]
    plate(shape,.64,leather,'Weathered boot',bevel=.06)
    plate([(-.65,-.79),(1.02,-.79),(1.04,-1),(.86,-1.09),(-.66,-1.09)],.72,dark,'Heavy layered sole',bevel=.035)
    box(-.08,1.03,.94,.19,dark,d=.75)
    plate([(-.45,.12),(-.05,.19),(.04,-.32),(-.39,-.39)],.045,patch,'Stitched leather patch',y=-.35)
    for z in [-.27,-.10,.07]:line([(-.47,z),(-.34,z+.025)],thread,.018,y=-.39)
    for z in [.32,.52,.72]:
        line([(-.16,z),(.20,z+.13)],thread,.028,y=-.36,name='Crossed lace');line([(.20,z),(-.16,z+.13)],thread,.028,y=-.37)
    line([(.34,-.46),(.69,-.57),(.81,-.69)],patch,.029,y=-.36,name='Toe scuff')
    box(.23,.85,.18,.15,glow,y=-.40,d=.05)

def pierre_a_aiguiser():
    stone=mat('#818C8D');light=mat('#BFC9C7');dark=mat('#424F52');steel=mat('#AEBEC0');edge=mat('#E3E4D3');wood=mat('#8D694C');glow=accent('#F2C14E')
    plate([(-1.02,-.59),(-.94,-.05),(.73,.12),(1,-.12),(.88,-.67),(-.73,-.83)],.48,stone,'Flat whetstone',bevel=.065)
    line([(-.86,-.12),(.66,.03),(.86,-.15)],light,.035,y=-.27,name='Stone upper bevel')
    for x in [-.55,-.12,.28]:line([(x,-.30),(x+.24,-.37)],dark,.016,y=-.27,name='Sharpening groove')
    plate([(-.77,.87),(-.49,.95),(.55,-.05),(.57,-.39),(.24,-.28)],.09,steel,'Blade touching stone',y=-.39)
    line([(-.76,.86),(.25,-.26),(.54,-.37)],edge,.025,y=-.46,name='Honed edge')
    line([(-.66,.88),(-1.02,1.29)],wood,.115,y=-.36,name='Knife handle')
    line([(-.85,.92),(-.52,1.18)],dark,.045,y=-.38,name='Knife guard')
    for points in [[(.46,-.22),(.81,.15)],[(.52,-.29),(.97,-.19)],[(.48,-.18),(.52,.22)]]:line(points,glow,.032,y=-.52,name='Contact spark')

def bague_de_vigueur():
    gold=mat('#C4A565');shade=mat('#80643D');light=mat('#E4CF98');ruby=mat('#9D353D');facet=mat('#CE6565');glow=accent('#E94B53')
    torus((0,0,-.14),.68,.17,gold,'Heavy gold shank')
    torus((0,-.14,-.14),.68,.035,light,'Worn ring edge')
    plate([(-.43,.39),(-.32,.93),(.23,1.06),(.51,.63),(.27,.28),(-.24,.23)],.25,shade,'Angular bezel',y=-.12)
    plate([(-.34,.43),(-.25,.85),(.19,.95),(.40,.62),(.21,.36),(-.20,.32)],.16,ruby,'Cut ruby',y=-.30)
    plate([(-.25,.85),(.19,.95),(.10,.63),(-.12,.55)],.012,facet,'Ruby crown facet',y=-.39,bevel=0)
    line([(-.27,.79),(-.30,.48),(-.16,.38)],glow,.032,y=-.42,name='Ruby light')
    for x,z in [(-.37,.43),(.32,.38),(-.27,.90),(.25,.93)]:rivet(x,z,light,y=-.43)

def amulette_de_cuir():
    leather=mat('#C2A17A');dark=mat('#8A7359');edge=mat('#E5CAA0');brass=mat('#D9C797');glow=accent('#F2C14E')
    line([(-.12,.13),(-.67,.77),(-.46,1.44),(.03,1.69),(.54,1.32),(.62,.82),(.12,.13)],dark,.055,y=.05,name='Leather neck cord')
    line([(-.48,1.29),(-.40,1.40),(.03,1.59)],edge,.018,y=.00)
    disk(0,-.45,.75,dark,y=0,depth=.18);disk(0,-.45,.66,leather,y=-.12,depth=.12)
    torus((0,-.20,-.45),.57,.024,edge,'Stitched rim')
    for i in range(8):
        a=i*math.pi/4;rivet(.55*math.cos(a),-.45+.55*math.sin(a),brass,y=-.24)
    line([(-.20,-.75),(-.28,-.40),(-.04,-.19),(.18,-.32),(.12,-.62)],dark,.033,y=-.22,name='Leather stamped mark')
    box(0,.26,.25,.24,brass,y=-.05)
    disk(0,-.45,.095,glow,y=-.26)

def aimant_de_poche():
    red=mat('#A65047');steel=mat('#C4CFCD');dark=mat('#525D60');gold=mat('#CFAC63');edge=mat('#E4CC8B');glow=accent('#F2C14E')
    pts=[(-.83,.92),(-.83,-.38),(-.62,-.84),(-.25,-1.02),(.26,-1.02),(.64,-.82),(.84,-.37),(.84,.92),(.37,.92),(.37,-.32),(.22,-.53),(-.21,-.53),(-.37,-.31),(-.37,.92)]
    plate(pts,.37,red,'Forged horseshoe magnet',bevel=.055)
    for x in [-.60,.60]:box(x,.75,.48,.43,steel,d=.40);line([(x-.13,.67),(x+.12,.74)],dark,.018,y=-.23,name='Pole wear')
    for x,z in [(-.65,-.28),(.57,-.67)]:
        disk(x,z,.26,gold,y=-.28,depth=.10);torus((x,-.35,z),.20,.022,edge,'Coin rim')
        line([(x-.08,z-.09),(x+.08,z+.09)],edge,.037,y=-.39,name='Coin relief')
    line([(.43,-.66),(.54,-.53),(.68,-.56)],glow,.03,y=-.41,name='Gold magnetic glint')

def sifflet_de_chasse():
    bone=mat('#D0C7A7');shade=mat('#8F896F');brass=mat('#BA9C61');dark=mat('#3D413A');cord=mat('#80664D');glow=accent('#F2C14E')
    plate([(-.27,1.02),(.24,1.02),(.32,.70),(.31,-.51),(.22,-.82),(0,-1),(-.26,-.83),(-.34,-.51),(-.32,.70)],.38,bone,'Carved bone whistle',bevel=.06)
    plate([(-.28,.55),(-.12,.66),(-.12,-.66),(-.24,-.79),(-.31,-.49)],.015,shade,'Bone side plane',y=-.21,bevel=0)
    box(0,.91,.57,.21,brass,d=.42);box(0,.43,.37,.26,dark,y=-.23,d=.03)
    box(0,.25,.44,.09,brass,y=-.26,d=.05)
    torus((0,-.03,-.86),.14,.042,brass,'Lanyard eye')
    line([(.10,-.90),(.57,-1.03),(.83,-.70),(.93,.10),(.70,.31),(.48,.03),(.61,-.66),(.10,-.90)],cord,.04,y=.04,name='Hunting cord loop')
    line([(-.14,-.16),(-.07,-.33),(-.15,-.48)],shade,.022,y=-.24,name='Bone scratch')
    line([(-.17,.27),(.17,.27)],glow,.03,y=-.30,name='Single brass lip glint')

def finish(ident):
    from mathutils import Matrix
    objs=[o for o in bpy.context.scene.objects if o.type in {'MESH','CURVE'}]
    bpy.context.view_layer.update()
    camera=bpy.context.scene.camera;basis=camera.rotation_euler.to_matrix()
    axis=basis@Vector((0,0,1))
    angle={'sablier_fele':-40,'antidote':-18,'botte_rapiecee':-12,'pierre_a_aiguiser':-15,'bague_de_vigueur':-22,'amulette_de_cuir':-30,'aimant_de_poche':-30,'sifflet_de_chasse':-40}[ident]
    rotation=Matrix.Rotation(math.radians(angle),4,axis)@Matrix.Rotation(math.radians(-9),4,'Z')
    for o in objs:o.matrix_world=rotation@o.matrix_world
    frame_object_ortho(objs,margin=.065)
    camera=bpy.context.scene.camera;basis=camera.rotation_euler.to_matrix();inv=basis.transposed()
    graph=bpy.context.evaluated_depsgraph_get();points=[]
    for o in objs:
        evaluated=o.evaluated_get(graph);mesh=evaluated.to_mesh()
        points.extend(inv@(o.matrix_world@v.co) for v in mesh.vertices);evaluated.to_mesh_clear()
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    camera.location=basis@((lo+hi)*.5+Vector((0,0,10)));camera.data.ortho_scale=max(hi.x-lo.x,hi.y-lo.y)/.86
    cel.toon_materials('icon');RAW.mkdir(parents=True,exist_ok=True)
    raw=RAW/(ident+'.png');cel.cel_passes(raw,'icon',base_configure=passes,normals=False)
    bpy.context.scene.render.filepath=str(raw);bpy.ops.render.render(write_still=True)
    before=ROOT/'art/renders/items_v2/before';before.mkdir(parents=True,exist_ok=True)
    if not (before/(ident+'.png')).exists():shutil.copy2(DEST/(ident+'.png'),before/(ident+'.png'))
    subprocess.run([PY,'-I',str(Path(__file__).with_name('check_b.py')),'--finalize',ident],check=True,stdout=subprocess.DEVNULL)

def main():
    chosen=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else IDS
    if set(chosen)-set(IDS):raise ValueError('Unknown item')
    scenes=[]
    for ident in chosen:scenes.append(reset(ident));globals()[ident]();finish(ident)
    for s in list(bpy.data.scenes):
        if s not in scenes:bpy.data.scenes.remove(s)
    out=ROOT/'art/blender/items_v2/lot_b.blend';out.parent.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(out))
    print('PASS lot_b '+str(len(chosen))+' icons',flush=True)
if __name__=='__main__':main()
