"""Talvi: fixed-seed bark reliefs, Nova medallion; background Blender only."""
import sys, math, subprocess, random
from pathlib import Path
BASE=Path(__file__).resolve().parent
sys.path.insert(0,str(BASE))
import icons_norm_build as n
from ui_kit import bpy, mat
ROOT=n.ROOT
WORK=ROOT/'art/blender/cel/talvi'
NAMES=['morfil_taille_lente','morfil_fendoir','morfil_affutage_en_marche','morfil_trempe']

def chips(points):
    for x,z,a in points:
        n.plate([(x-.025,z-.055),(x+.035,z),(x+.012,z+.075)],n.wood)
        n.line([(x,z),(x+.04*math.cos(a),z+.06*math.sin(a))],.012,n.heart)

def emblem(kind):
    if kind==0:
        # One broad diagonal kesa cut, bark edge and luminous sap inside.
        n.crescent(.65,.12,2.95,.19,.64)
        n.arc(0,0,.58,.80,3.50,n.wood,.048)
        chips([(-.45,-.29,2),(.48,.05,1),(.27,-.43,0)])
    elif kind==1:
        n.plate([(-.085,-.30),(-.10,.39),(0,.68),(.10,.39),(.075,-.30)],n.wood)
        n.line([(0,-.29),(0,.56)],.029,n.glow)
        n.line([(-.13,-.32),(.13,-.32)],.035,n.metal)
        n.line([(0,-.34),(0,-.57)],.052,n.wood)
        n.line([(0,-.59),(0,-.70)],.018,n.heart)
        chips([(-.26,.30,2),(.28,.23,0),(-.31,-.20,3),(.34,-.28,0)])
    elif kind==2:
        # Upright bark blade, overflowing sap edge, waterstone below; no legs.
        n.plate([(-.39,-.48),(.31,-.48),(.43,-.30),(-.29,-.30)],n.metal)
        n.line([(-.29,-.32),(.36,-.32)],.018,n.pale)
        n.knife(0,-.07,.06,.98,True)
        n.line([(-.012,-.11),(-.015,.40),(-.104,.65)],.032,n.glow,y=-.38)
        n.line([(.006,.02),(.012,.36),(-.096,.64)],.012,n.heart,y=-.42)
        for x,z,dx,dz in [(.12,.18,.14,.07),(.10,.33,.13,.15),(.07,.48,.02,.13),(-.26,.16,-.10,.10)]:
            n.line([(x,z),(x+dx,z+dz)],.014,n.heart,y=-.40)
    else:
        water=mat('#365550',.6,0,'#7FC8C0',.3)
        n.plate([(-.45,-.24),(-.32,-.48),(.32,-.48),(.45,-.24)],n.metal)
        n.arc(0,-.24,.43,0,math.tau,water,.025,sy=.22,y=-.40)
        n.knife(-.32,-.02,.18,.90,True)
        for x,z in [(-.28,-.05),(.27,.02)]:
            n.line([(x,z),(x-.04,z+.12),(x+.03,z+.24),(x,z+.35)],.024,n.pale,y=-.42)

def run():
    random.seed(331)
    n.cel.archive_folder('icons/spells')
    WORK.mkdir(parents=True,exist_ok=True)
    n.WORK=WORK
    s=n.scene('medallion');s.eevee.taa_render_samples=8
    bpy.ops.render.render(write_still=True)
    only = sys.argv[sys.argv.index("--only")+1].split(",") if "--only" in sys.argv else NAMES
    if any(name not in NAMES for name in only): raise ValueError("Unknown icon")
    for i,name in enumerate(NAMES):
        if name not in only: continue
        s=n.scene(name,lambda i=i:emblem(i),'#CDEB6E')
        s.eevee.taa_render_samples=8
        bpy.ops.render.render(write_still=True)
        subprocess.run([n.PY,str(BASE/'talvi_finish.py'),'fit',name],check=True,stdout=subprocess.DEVNULL)
        print('PASS '+name,flush=True)
        bpy.context.window.scene=bpy.data.scenes[0]
        bpy.data.scenes.remove(s)
        bpy.data.orphans_purge(do_recursive=True)

if __name__=='__main__':run()
