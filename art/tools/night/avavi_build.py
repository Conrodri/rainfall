"""AVAVI: fixed-seed gold relief variants; shared Nova backing and raster fit.
Blender --background --python art/tools/night/avavi_build.py [-- --only id,...].
No normal maps, emission files, resources, or original scenes are delivered.
"""
import sys, math, random, argparse, subprocess
from pathlib import Path
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[2]
sys.dont_write_bytecode=True
sys.path.insert(0,str(BASE))
import icons_norm_build as n
import i3_build as nova
WORK=ROOT/'art/blender/cel/avavi'
NAMES=['avare_coffre_belier','avare_piece_truquee','avare_saisie','avare_tresor_enterre']

def ram():
    # Heavy frontal safe, diagonal reinforced corners, central dial and ram horns.
    n.plate([(-.38,-.32),(.38,-.32),(.38,.32),(-.38,.32)],n.metal)
    n.plate([(-.29,-.23),(.29,-.23),(.29,.24),(-.29,.24)],n.wood,-.34)
    for x in (-.34,.34):
        n.line([(x,-.28),(x,.28)],.035,n.glow,-.38)
    for z in (-.28,.28):n.line([(-.34,z),(.34,z)],.035,n.glow,-.38)
    before=set(n.meshes());n.coin(.035,.015,.135)
    for o in set(n.meshes())-before:o.location.y-=.20
    n.line([(.035,-.065),(.035,.095)],.018,n.dark,-.58)
    n.line([(-.035,.015),(.105,.015)],.018,n.dark,-.58)
    for z in (-.18,.18):n.line([(-.28,z),(-.20,z)],.03,n.heart,-.40)
    for x in (-.24,.24):
        n.plate([(x-.08,-.26),(x+.08,-.26),(x+.12,-.43),(x-.10,-.43)],n.glow,-.40)
    for z in (-.20,.04,.25):
        n.line([(-.60,z-.08),(-.44,z)],.025,n.glow)
        n.line([(.44,z),(.60,z-.08)],.025,n.glow)
    n.line([(-.20,-.52),(.20,-.52)],.025,n.heart)

def trick_coin():
    points=[(-.47,-.38),(-.24,.32),(.23,-.30),(.45,.35)]
    for a,b in zip(points,points[1:]):n.arrow(a,b,.085,n.glow)
    for x,z in points[:-1]:
        n.arc(x,z,.09,0,math.tau,n.heart,.018)
    n.coin(.41,.35,.215)
    # Large incised zigzag mark on the final, frontmost coin.
    n.line([(.37,.45),(.46,.45),(.37,.27),(.46,.27)],.022,n.dark,-.39)

def seizure():
    # Curling chain and open hook; clustered small bodies converge onto marked coin.
    points=[(-.52,.35),(-.36,.46),(-.17,.49),(.03,.47),(.22,.39),(.38,.25)]
    n.chain(points)
    n.arc(.34,.05,.20,-2.5,1.2,n.glow,.052,y=-.34)
    n.plate([(.14,-.07),(.15,.09),(.23,.01)],n.heart,-.38)
    for x,z in [(-.45,-.20),(-.20,-.37),(.07,-.42)]:
        n.dot(x,z+.105,.065,n.metal)
        n.plate([(x-.065,z+.025),(x+.065,z+.025),(x+.09,z-.12),(x-.09,z-.12)],n.metal)
        n.arrow((x+.04,z+.15),(-.05,-.02),.062,n.glow)
    n.coin(-.08,.04,.145)

def buried():
    # Gathered leather purse, lower half occluded by angular earth mound.
    n.plate([(-.27,-.17),(-.32,.08),(-.20,.34),(-.21,.44),(.17,.44),(.14,.31),(.29,.07),(.25,-.17)],n.wood)
    n.line([(-.19,.34),(.15,.34)],.036,n.glow,-.36)
    n.line([(-.13,.37),(-.18,.53),(-.02,.44),(.11,.54),(.11,.38)],.025,n.glow)
    n.line([(-.17,.24),(-.23,.03),(-.15,-.11)],.025,n.glow,-.36)
    n.plate([(-.61,-.28),(-.46,-.09),(-.29,-.13),(-.09,-.03),(.11,-.10),(.28,-.04),(.45,-.17),(.59,-.29),(.43,-.43),(-.41,-.43)],n.dark,-.40)
    n.line([(-.07,-.06),(.02,-.18),(-.09,-.26),(.09,-.34),(.02,-.42)],.038,n.glow,-.48)
    n.line([(.02,-.18),(.20,-.19),(.30,-.29)],.022,n.heart,-.49)
    for x,z in [(-.40,-.24),(.38,-.32)]:n.line([(x-.06,z),(x+.045,z+.03)],.018,n.metal,-.46)

def run():
    parser=argparse.ArgumentParser();parser.add_argument('--only')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    names=args.only.split(',') if args.only else NAMES
    assert set(names)<=set(NAMES)
    n.cel.archive_folder('icons/spells')
    WORK.mkdir(parents=True,exist_ok=True)
    # Reuse scene()/configure_cel(), materials()/backing() and shared run pipeline.
    # A separate medallion render provides i3_finish-derived common Nova crop.
    s=n.scene('avavi_medallion');s.render.filepath=str(WORK/'medallion_raw.png')
    n.bpy.ops.render.render(write_still=True)
    for name,emblem in zip(NAMES,[ram,trick_coin,seizure,buried]):
        if name not in names:continue
        random.seed(331)
        s=n.scene(name,emblem,'#F2C14E')
        s.render.filepath=str(WORK/(name+'_raw.png'))
        n.bpy.ops.render.render(write_still=True)
        subprocess.run([n.PY,str(BASE/'avavi_finish.py'),'fit',name],check=True)
        print('PASS '+name,flush=True)

if __name__=='__main__':run()
