import bpy, math, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
# Reuse EP-I reset/mat/band conventions without running its production loop.
source=(ROOT/'art/tools/epreuve/ep_i_build.py').read_text(encoding='utf-8-sig').split("for skin,col in")[0]
source=source.replace("'DITHERED'", "'BLENDED'")
exec(compile(source,str(ROOT/'art/tools/epreuve/ep_i_build.py'),'exec'))
V=ROOT/'game/assets/sprites/vfx/epreuve'
WARM=(.86,.77,.59); LIGHT=(1,.93,.78); DARK=(.12,.105,.085)
def scene(w,h):
 c=reset(w); s=bpy.context.scene; s.render.resolution_x=w; s.render.resolution_y=h; c.data.ortho_scale=2
 s.render.use_compositing=False
 return c
def poly(points,m,z=.01):
 mesh=bpy.data.meshes.new('facet'); mesh.from_pydata([(x,y,z) for x,y in points],[],[tuple(range(len(points)))]); mesh.update()
 o=bpy.data.objects.new('facet',mesh); bpy.context.collection.objects.link(o); o.data.materials.append(m); return o
def rect(x,y,w,h,m,z=.01): return poly([(x-w/2,y-h/2),(x+w/2,y-h/2),(x+w/2,y+h/2),(x-w/2,y+h/2)],m,z)
def disk(r,m,z=0): return poly([(r*math.cos(i*math.tau/128),r*math.sin(i*math.tau/128)) for i in range(128)],m,z)
def line(points,width,m,z=.02):
 for (x,y),(xx,yy) in zip(points,points[1:]):
  dx=xx-x; dy=yy-y; d=math.hypot(dx,dy); nx=-dy/d*width/2; ny=dx/d*width/2
  poly([(x+nx,y+ny),(x-nx,y-ny),(xx-nx,yy-ny),(xx+nx,yy+ny)],m,z)
def save(name):
 cel.toon_materials('vfx'); bpy.context.scene.render.filepath=str(V/('ep2_'+name+'.png')); bpy.ops.render.render(write_still=True)
def ticks(n,r,length,m):
 for i in range(n):
  a=i*math.tau/n; line([((r-length)*math.cos(a),(r-length)*math.sin(a)),(r*math.cos(a),r*math.sin(a))],.009,m)
scene(256,256); gold=mat('pale gold',WARM); disk(.93,mat('translucent field',WARM,.045)); band(.947,.018,gold,.01); band(.855,.008,mat('inner trace',WARM,.35),.01); ticks(32,.916,.055,gold)
for i in range(8):
 a=i*math.tau/8; pts=[(.83,-.025),(.865,0),(.83,.025)]
 line([(x*math.cos(a)-y*math.sin(a),x*math.sin(a)+y*math.cos(a)) for x,y in pts],.012,gold)
save('geyser_tele')
scene(256,256)
for k in range(32,0,-1):
 r=.96*k/32; disk(r,mat('warm halo',LIGHT,.035+.11*(1-k/32)**2),.001*(33-k))
disk(.22,mat('dense flash',LIGHT),.04); save('geyser_flash')
scene(128,128); gold=mat('beveled gold',WARM); shadow=mat('edge shadow',(.30,.25,.18)); hi=mat('upper left edge',LIGHT)
poly([(-.57,.64),(-.28,.64),(.80,0),(-.28,-.64),(-.57,-.64),(.43,0)],shadow)
poly([(-.56,.60),(-.29,.60),(.73,.015),(-.29,-.57),(-.49,-.57),(.50,.015)],gold,.02)
line([(-.55,.60),(-.29,.60),(.73,.015)],.025,hi,.03); save('chevron')
scene(256,256); gold=mat('ring',WARM); band(.917,.086,gold); band(.952,.012,mat('rim',LIGHT),.01); ticks(64,.944,.026,mat('graduations',DARK)); save('progress_ring')
scene(64,32); gold=mat('track',WARM)
for y in [-.13,.13]:
 rect(0,y,2.05,.018,gold)
 for j in range(4): rect(0,y,2.05,.018+j*.015,mat('soft margin',WARM,.045),-.01-j*.001)
for x in [-.75,-.25,.25,.75]:
 poly([(x-.055,0),(x,.075),(x+.055,0),(x,-.075)],gold)
save('path_tile')
for end in [False,True]:
 scene(128,128); gold=mat('pad metal',WARM); disk(.77,mat('pad recess',DARK,.68)); band(.81,.055,gold); band(.68,.018,gold,.01); ticks(16,.77,.045,gold)
 if end:
  line([(-.10,-.30),(-.10,.36)],.035,mat('anchor',LIGHT)); poly([(-.08,.35),(.35,.23),(-.08,.08)],gold,.03); band(.17,.022,gold,.02)
 else:
  for x in [-.25,.10]: line([(x-.12,-.25),(x+.13,0),(x-.12,.25)],.04,gold)
 save('pad_end' if end else 'pad_start')
scene(64,16); gold=mat('rope shade',(.40,.34,.25)); rect(0,0,2.08,.13,gold)
for phase,col,z in [(0,WARM,.02),(math.pi,LIGHT,.025)]:
 pts=[(-1.03+i*2.06/192,.042*math.cos(4*math.tau*(-1.03+i*2.06/192)/2+phase)) for i in range(193)]
 line(pts,.044,mat('twisted strand',col),z)
save('rope')
scene(64,24)
for width,alpha in [(.22,.035),(.15,.065),(.09,.15),(.07,1)]: rect(0,0,2.08,width,mat('energy core',LIGHT,alpha))
for phase in [0,math.pi]:
 pts=[(-1.03+i*2.06/192,.075*math.sin(2*math.tau*(-1.03+i*2.06/192)/2+phase)) for i in range(193)]
 line(pts,.012,mat('filament',WARM,.7),.03)
save('link')
scene(192,24); metal=mat('dark metal',(.21,.18,.14)); rect(0,0,1.92,.16,mat('translucent recess',DARK,.32))
for y in [-.085,.085]:
 rect(0,y,1.92,.025,metal); rect(0,y+.007,1.90,.006,mat('worn rim',WARM),.02)
for x in [-.953,.953]: rect(x,0,.025,.18,metal)
for x in [-.88,.88]: rect(x,.079,.028,.014,mat('rivet',LIGHT),.03)
save('bar_frame')
scene(192,24)
for j in range(5): rect(0,(j-2)*.025,1.87,.025,mat('fill bands',tuple(c*(.55+.1*j) for c in LIGHT)))
for i in range(24): rect(-.90+i*.078,0,.009,.12,mat('ribs',WARM),.02)
save('bar_fill')
(ROOT/'art/blender/props').mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/props/ep2_fx.blend'))
print('PASS EP-II: 11 PNG final-size renders; no sidecars')


