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
        n.plate([(-.42,-.14),(.30,-.14),(.43,.07),(-.30,.07)],n.metal)
        n.line([(-.34,-.11),(.30,-.11)],.019,n.glow)
        n.knife(.96,-.03,.27,.83,True)
        n.line([(-.20,-.20),(-.25,-.38),(-.44,-.48)],.045,n.wood)
        n.line([(.20,-.20),(.26,-.41),(.44,-.36)],.045,n.wood)
        for a in (.1,.7,1.3):
            n.line([(.22,.16),(.22+.20*math.cos(a),.16+.20*math.sin(a))],.018,n.heart)
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
    for i,name in enumerate(NAMES):
        s=n.scene(name,lambda i=i:emblem(i),'#CDEB6E')
        s.eevee.taa_render_samples=8
        bpy.ops.render.render(write_still=True)
        subprocess.run([n.PY,str(BASE/'talvi_finish.py'),'fit',name],check=True,stdout=subprocess.DEVNULL)
        print('PASS '+name,flush=True)
        bpy.context.window.scene=bpy.data.scenes[0]
        bpy.data.scenes.remove(s)
        bpy.data.orphans_purge(do_recursive=True)

if __name__=='__main__':run()
