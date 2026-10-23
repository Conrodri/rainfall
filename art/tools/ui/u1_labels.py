"""Render typography for the inspection assembly; Pillow never draws."""
import sys,json,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from ui_kit import *
T=ROOT/'art/tools/ui';rows=json.loads((T/'_u1_inventory.json').read_text())['assets']
W=1920;GRID=((len(rows)+5)//6)*152;H=GRID+1080
reset_scene();setup_render();front_camera(W,H,W,H);s=bpy.context.scene
s.eevee.taa_render_samples=8;s.camera.location=(0,-4000,0);aim(s.camera,(0,0,0));s.camera.data.clip_end=6000
m=mat('#CCD4C9',1,0,'#CCD4C9',1)
def label(text,x,y,size=13,color=None):
    d=bpy.data.curves.new('proof label','FONT');d.body=text;d.size=size;d.extrude=0
    o=bpy.data.objects.new(text,d);s.collection.objects.link(o);o.location=(x-W/2,-2,H/2-y);o.rotation_euler=(math.pi/2,0,0);o.data.materials.append(color or m)
for i,row in enumerate(rows):
    x=i%6*320+12;y=i//6*152
    label(row['name'],x,y+18,12);label('%d x %d%s'%(*row['size'],'   + emission' if row['emission'] else ''),x,y+35,10)
for text,x,y,size in [('RAIN F A L L   /   U1  -  HUD on C1 stone',36,GRID+45,22),('27',76,GRID+116,27),('ARDENT',133,GRID+84,18),('736 / 1024',280,GRID+112,17),('NIVEAU 27',36,GRID+170,13),('9 820',1730,GRID+90,20),('18:42',934,GRID+92,26),('LE SEIGNEUR DES CENDRES',780,GRID+913,20),('E',1746,GRID+997,20),('OUVRIR',1660,GRID+1052,15),('EXPLORATION',1610,GRID+420,16)]:label(text,x,y,size)
render_to(T/'_u1_labels.png');print('PASS labels')
