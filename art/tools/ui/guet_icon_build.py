import sys, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/ui')]
WORK=ROOT/'art/blender/cel/guet'; OUT=ROOT/'game/assets/sprites/ui/icons/passives'
def emblem():
 import icons_norm_build as n
 # Lanterne carrée, toit et montants; grand œil en amande au centre.
 n.plate([(-.47,.43),(-.30,.62),(0,.69),(.30,.62),(.47,.43),(0,.35)],n.metal,d=.16,b=.035)
 n.line([(-.42,.40),(.42,.40)],.055,n.heart,y=-.42)
 n.line([(-.37,.37),(-.37,-.43)],.045,n.metal,y=-.41)
 n.line([(.37,.37),(.37,-.43)],.045,n.metal,y=-.41)
 n.line([(-.39,-.43),(.39,-.43)],.06,n.heart,y=-.42)
 n.plate([(-.50,-.48),(-.42,-.62),(.42,-.62),(.50,-.48)],n.wood,d=.12,b=.025)
 # Sculpted almond lids, gold emissive iris, vertical dark pupil.
 n.plate([(-.31,-.02),(-.20,.13),(0,.22),(.20,.13),(.31,-.02),(.20,-.17),(0,-.24),(-.20,-.17)],n.pale,d=.13,b=.025)
 n.arc(0,-.015,.265,0,math.pi,n.heart,.035,32,sy=.72,y=-.48)
 n.arc(0,-.015,.265,math.pi,math.tau,n.metal,.035,32,sy=.72,y=-.48)
 n.dot(0,-.015,.125,n.glow,y=-.49)
 n.plate([(-.035,-.15),(-.045,.08),(0,.16),(.045,.08),(.035,-.15),(0,-.19)],n.dark,d=.09,b=.012)
 # Cross bars suggest lantern glazing while leaving the eye unobstructed.
 n.line([(-.34,.29),(.34,.29)],.025,n.metal,y=-.40)
 n.line([(-.34,-.31),(.34,-.31)],.025,n.metal,y=-.40)
def run():
 import icons_norm_build as n
 from icons_norm_build import bpy
 WORK.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True);n.WORK=WORK
 s=n.scene('guet',emblem,'#D6A647');s.eevee.taa_render_samples=12
 s.render.filepath=str(WORK/'guet_raw.png');n.configure_cel(s.render.filepath);bpy.ops.render.render(write_still=True)
def finish():
 from PIL import Image
 import numpy as np
 raw=Image.open(WORK/'guet_raw.png').convert('RGBA');base=Image.open(ROOT/'art/blender/cel/icons_norm/medallion_raw.png').convert('RGBA')
 # fit to fixed medallion bounds
 def fit(p):
  im=Image.open(p).convert('RGBA').crop(base.getbbox()).resize((111,112),Image.Resampling.LANCZOS);o=Image.new('RGBA',(128,128));o.paste(im,(10,8));return o
 im=fit(WORK/'guet_raw.png');im.save(OUT/'guet.png',compress_level=9)
 masks=list(WORK.glob('guet_accent_mask__*.png'));assert masks
 e=fit(masks[0]);e=e.resize((64,64),Image.Resampling.LANCZOS);a=np.array(e);assert a[:,:,0].max()>2
 # The compositor mask is greyscale; convert its covered pixels to the gold accent.
 strength=a[:,:,0].copy();a[:,:,:3]=np.array([255,190,72],dtype=np.uint8);a[:,:,3]=strength;e=Image.fromarray(a,'RGBA');e.save(OUT/'guet_e.png',compress_level=9)
 assert im.size==(128,128) and im.mode=='RGBA' and not (OUT/'guet_n.png').exists()
 # Contrast of luminous gold against dark disk.
 aa=np.array(im);lum=aa[:,:,:3]@np.array([.2126,.7152,.0722]);gold=(aa[:,:,0]>150)&(aa[:,:,1]>80)&(aa[:,:,3]>200);dark=(aa[:,:,0]<50)&(aa[:,:,1]<55)&(aa[:,:,3]>200);assert gold.any() and dark.any()
 contrast=(np.median(lum[gold])+.05)/(np.median(lum[dark])+.05);assert contrast>=3,contrast
 print(f'PASS guet RGBA128 emission64 contrast={contrast:.2f}')
if __name__=='__main__': finish() if sys.argv[-1:]==['finish'] else run()
