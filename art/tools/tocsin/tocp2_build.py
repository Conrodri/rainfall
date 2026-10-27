"""TOCP2: Blender geometry, shared cel materials, 64 px/u; no normal files."""
import sys, math, random
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT/'art/tools/vfx'), str(ROOT/'art/tools/cel'), str(ROOT/'art/tools/bosses')]
import bpy
import vfx_lib as v
import cel_style as cel
RAW = ROOT/'art/renders/tocp2'
RAW.mkdir(parents=True, exist_ok=True)
W,H=448,320
s=v.setup(W,H,samples=8)
cel.install('vfx', normals=False)
cel.setup_scene(samples=8)
s.view_layers[0].use_pass_normal=False
s.render.dither_intensity=0
s.world=bpy.data.worlds.new('Night'); s.world.use_nodes=True
s.world.node_tree.nodes.get('Background').inputs[0].default_value=(.15,.17,.2,1)
light=bpy.data.objects.new('UpperLeft',bpy.data.lights.new('UpperLeft','AREA'))
bpy.context.collection.objects.link(light); light.location=(-3,-4,7); light.data.energy=500; light.data.size=5
def material(name, color, emission=0, alpha=1):
    import boss_common as bc
    m=bc.material(name,v.lin(v.hexc(color)),emission=emission)
    cel.toon_materials('vfx')
    if alpha<1:
        n=m.node_tree.nodes; l=m.node_tree.links
        out=next(x for x in n if x.type=='OUTPUT_MATERIAL')
        src=out.inputs['Surface'].links[0].from_socket
        tr=n.new('ShaderNodeBsdfTransparent'); mix=n.new('ShaderNodeMixShader')
        mix.inputs[0].default_value=alpha; l.new(tr.outputs[0],mix.inputs[1]); l.new(src,mix.inputs[2]); l.new(mix.outputs[0],out.inputs['Surface'])
        m.surface_render_method='BLENDED'
    v.G['mats'][name]=m
    return name
BLUE=material('blue','8FD9FF',1)
CORE=material('core','DDF4FF',1)
VEIL=material('veil','8FD9FF',.3,.055)
FIRE=material('ember','FF7A1F',1)
SMOKE=material('smoke','69716C',0,.32)
CREA=False
def xy(p):
    return (p[0]/.70710678,p[1]/1.4142136,p[2] if len(p)>2 else 0) if CREA else p
def line(pts,width,mat):
    return v.ribbon(mat,[xy(p) for p in pts],width,v.WHITE,1)
def disk(x,y,rx,ry,mat,depth=0):
    pts=[(x+rx*math.cos(i*math.tau/32),y+ry*math.sin(i*math.tau/32),depth) for i in range(32)]
    verts=[tuple(v.S(*xy(p))) for p in pts]
    me=bpy.data.meshes.new('disk'); me.from_pydata(verts,[],[tuple(range(32))]); me.materials.append(v.mat(mat))
    return v._add(bpy.data.objects.new('disk',me),mat,v.WHITE,1)
def ring(r,width,mat=BLUE):
    line([(r*math.cos(i*math.tau/96),r*.5*math.sin(i*math.tau/96),-.015) for i in range(97)],width,mat)
def bolt(angle,length,seed,width=.025):
    rng=random.Random(seed)
    pts=[(0,0,-.035)]
    for j in range(1,10):
        t=j/9; off=rng.uniform(-.10,.10)*(math.sin(t*math.pi)**.5)
        pts.append((length*t*math.cos(angle)-off*math.sin(angle),(.5*length*t*math.sin(angle)+off*math.cos(angle)), -.035))
    line(pts,width*2.5,BLUE); line([(x,y,d-.012) for x,y,d in pts],width,CORE)
    for j in (3,5,7):
        p=pts[j]; a=angle+rng.choice([-1,1])*rng.uniform(.5,1.1)
        branch=[p,(p[0]+.14*math.cos(a),p[1]+.09*math.sin(a),-.04),(p[0]+.34*math.cos(a+.3),p[1]+.22*math.sin(a+.3),-.04)]
        line(branch,width*.8,BLUE)
def frame(kind,f,variant=0,crea=False):
    global CREA
    CREA=crea; v.clear()
    if kind=='impact':
        t=f/7; r=.32+1.88*(1-(1-t)**2)
        ring(r,.065*(1-t)+.014)
        if f<6: ring(r*.78,.024)
        for j in range(8): bolt(j*math.tau/8+.2,r*.94,70+j,.018*(1-.7*t))
        for j in range(12):
            a=j*math.tau/12; q=.3+t*1.4
            line([(q*math.cos(a),q*.5*math.sin(a),-.06),((q+.11)*math.cos(a),(q+.11)*.5*math.sin(a)+.05,-.06)],.018,FIRE)
    elif kind=='zone':
        pulse=.5+.5*math.cos(f*math.tau/12)
        disk(0,0,2.18,1.09,VEIL,.03)
        ring(2.2,.025+.025*pulse); ring(2.11,.012)
        for j in range(9): bolt(j*math.tau/9+.1,1.35+(j%3)*.25,100+j,.012+.012*pulse)
        for j in range(12):
            a=j*math.tau/12; r=2.02
            line([(r*math.cos(a),r*.5*math.sin(a),-.03),(2.16*math.cos(a),1.08*math.sin(a),-.03)],.026,CORE)
    elif kind=='arc':
        a=[.25,2.4,3.65,5.35][variant]; length=[1.2,1.55,1.9,2.2][variant]
        bolt(a,length,200+variant*17+f//2,.032*(1-f/7))
        x,y=length*math.cos(a),.5*length*math.sin(a)
        for j in range(4):
            z=j*math.tau/4+f*.2; q=.045+.018*f
            line([(x,y,-.07),(x+q*math.cos(z),y+q*math.sin(z),-.07)],.018*(1-f/7),CORE)
    else:
        t=f/5; rng=random.Random(101)
        smoke_mix=next(x for x in v.mat(SMOKE).node_tree.nodes if x.type=='MIX_SHADER')
        smoke_mix.inputs[0].default_value=.32*(1-.9*t)
        for j in range(7):
            a=j*2.4; q=.08+t*.45
            disk(q*math.cos(a),.08+q*.5*math.sin(a)+t*.65,.18+.08*t,.12+.10*t,SMOKE,.01+j*.002)
        for j in range(13):
            a=rng.uniform(0,math.tau); q=.12+t*rng.uniform(.3,.9)
            x=q*math.cos(a); y=.5*q*math.sin(a)+t*.3
            line([(x,y,-.10),(x+.015,y+.045*(1-t)+.008,-.10)],.018*(1-.8*t),FIRE)
    label=f'{kind}_{"crea" if crea else "top"}_{variant}_{f:02}'
    s.render.filepath=str(RAW/(label+'.png')); bpy.ops.render.render(write_still=True)
    hidden=[]
    for o in v.G['objs']:
        if o['k']=='smoke': o.hide_render=True; hidden.append(o)
    s.render.filepath=str(RAW/(label+'_e.png')); bpy.ops.render.render(write_still=True)
    for o in hidden:o.hide_render=False
for kind,n in [('impact',8),('zone',12),('arc',6),('end',6)]:
    for crea in ([False,True] if kind=='arc' else [False]):
        for variant in range(4 if kind=='arc' else 1):
            for f in range(n): frame(kind,f,variant,crea)
    print('PASS rendered',kind,flush=True)
