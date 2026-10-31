import math, os, sys, random
if '--finish' not in sys.argv: import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
OUT = os.path.join(ROOT, 'game/assets/sprites/terrain/crypts/sol')
RENDER = os.path.join(ROOT, 'art/renders/sol_v2/codex/cryptes')
BLEND = os.path.join(ROOT, 'art/blender/sol/cryptes_sol.blend')
for folder in (OUT, RENDER, os.path.dirname(BLEND)): os.makedirs(folder, exist_ok=True)
sys.path.insert(0, os.path.dirname(__file__))

def linear(v):
    return v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4

def rgba(c): return tuple(linear(v/255) for v in c)+(1,)

class Graph:
    def __init__(self, name):
        self.mat=bpy.data.materials.new(name); self.mat.use_nodes=True
        self.n=self.mat.node_tree.nodes; self.n.clear(); self.l=self.mat.node_tree.links
        self.out=self.n.new('ShaderNodeOutputMaterial')
    def node(self, kind): return self.n.new(kind)
    def put(self, socket, val):
        if hasattr(val,'node'): self.l.new(val,socket)
        else: socket.default_value=val
    def op(self, kind, a, b=0):
        n=self.node('ShaderNodeMath'); n.operation=kind
        self.put(n.inputs[0],a); self.put(n.inputs[1],b); return n.outputs[0]
    def vec(self, kind, a, b):
        n=self.node('ShaderNodeVectorMath'); n.operation=kind
        self.put(n.inputs[0],a); self.put(n.inputs[1],b); return n.outputs[0]
    def combine(self,x,y,z):
        n=self.node('ShaderNodeCombineXYZ')
        for s,v in zip(n.inputs,(x,y,z)): self.put(s,v)
        return n.outputs[0]
    def ramp(self,fac, entries):
        n=self.node('ShaderNodeValToRGB'); cr=n.color_ramp
        for i,(pos,col) in enumerate(entries):
            e=cr.elements[i] if i<2 else cr.elements.new(pos)
            e.position=pos; e.color=col
        self.put(n.inputs[0],fac); return n.outputs[0]
    def noise(self, coord, scale, w=None):
        n=self.node('ShaderNodeTexNoise'); n.inputs['Scale'].default_value=scale
        n.inputs['Detail'].default_value=3; n.inputs['Roughness'].default_value=.65
        self.put(n.inputs['Vector'],coord)
        if w is not None: n.noise_dimensions='4D'; self.put(n.inputs['W'],w)
        return n
    def mix(self,a,b,fac):
        n=self.node('ShaderNodeMixRGB'); self.put(n.inputs[0],fac); self.put(n.inputs[1],a); self.put(n.inputs[2],b)
        return n.outputs[0]
    def emit(self,color,alpha=None):
        e=self.node('ShaderNodeEmission'); self.put(e.inputs['Color'],color)
        if alpha is None: self.l.new(e.outputs[0],self.out.inputs[0])
        else:
            t=self.node('ShaderNodeBsdfTransparent'); m=self.node('ShaderNodeMixShader')
            self.put(m.inputs[0],alpha); self.l.new(t.outputs[0],m.inputs[1]); self.l.new(e.outputs[0],m.inputs[2]); self.l.new(m.outputs[0],self.out.inputs[0])
        return self.mat

def material(idx):
    g=Graph('crypt_floor_%d_EMISSION_PERIODIC'%idx)
    tc=g.node('ShaderNodeTexCoord'); sep=g.node('ShaderNodeSeparateXYZ'); g.put(sep.inputs[0],tc.outputs['UV'])
    x=g.op('MULTIPLY',sep.outputs['X'],math.tau); y=g.op('MULTIPLY',sep.outputs['Y'],math.tau)
    coord=g.combine(g.op('COSINE',x),g.op('SINE',x),g.op('COSINE',y)); w=g.op('SINE',y)
    warp=g.noise(coord,1.7,w)
    # Vector warp, periodic in both axes, with independently varying fourth dimension.
    vn=g.node('ShaderNodeVectorMath'); vn.operation='SCALE'; g.put(vn.inputs[0],warp.outputs['Color']); vn.inputs['Scale'].default_value=.42
    coord=g.vec('ADD',coord,vn.outputs[0]); w=g.op('ADD',w,g.op('MULTIPLY',warp.outputs['Fac'],.3))
    noise=g.noise(coord,[5,8,4,12][idx],w)
    fine=g.noise(coord,54,w)
    def vor(scale,feature):
        n=g.node('ShaderNodeTexVoronoi'); n.voronoi_dimensions='4D'; n.feature=feature
        n.inputs['Scale'].default_value=scale; n.inputs['Randomness'].default_value=1
        g.put(n.inputs['Vector'],coord); g.put(n.inputs['W'],w); return n.outputs['Distance']
    v1=vor([4.8,10,5,13][idx],'F1'); v2=vor([4.8,10,5,13][idx],'F2')
    edge=g.op('SUBTRACT',v2,v1)
    height=g.op('ADD',g.op('MULTIPLY',noise.outputs['Fac'],.65),g.op('MULTIPLY',fine.outputs['Fac'],.18))
    height=g.op('ADD',height,g.op('MULTIPLY',vor(23,'F1'),.17))
    palettes=[[(23,29,35),(55,56,53),(82,80,69)],[(44,46,44),(82,82,72),(139,134,116)],[(6,12,18),(23,29,35),(90,97,101)],[(26,30,33),(64,65,60),(114,110,94)]]
    color=g.ramp(height,[(.18,rgba(palettes[idx][0])),(.49,rgba(palettes[idx][1])),(.78,rgba(palettes[idx][2]))])
    joints=g.ramp(edge,[(.012,(0,0,0,1)),(.10,(1,1,1,1))])
    if idx in (0,3): color=g.mix(rgba((19,24,29) if idx==0 else (31,33,33)),color,joints)
    if idx==3:
        chip=g.ramp(vor(29,'F1'),[(.19,(1,1,1,1)),(.28,(0,0,0,1))])
        color=g.mix(color,rgba((140,135,120)),g.op('MULTIPLY',chip,.65))
    return g.emit(color)

def setup_scene():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=12
    scene.render.resolution_x=1024; scene.render.resolution_y=1024; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'
    scene.render.film_transparent=True; scene.render.image_settings.color_depth='8'
    scene.view_settings.view_transform='Standard'; scene.view_settings.look='None'; scene.view_settings.exposure=0; scene.view_settings.gamma=1
    bpy.ops.mesh.primitive_plane_add(size=8); plane=bpy.context.object; plane.name='crypt_top_tile'
    cam_data=bpy.data.cameras.new('TOP_ortho'); cam=bpy.data.objects.new('TOP_ortho',cam_data); scene.collection.objects.link(cam)
    cam.location=(0,0,8); cam.rotation_euler=(0,0,0); cam_data.type='ORTHO'; cam_data.ortho_scale=8; scene.camera=cam
    scene.world.color=(0,0,0); return scene,plane

def render_bases(scene,plane):
    for i in range(4):
        plane.data.materials.clear(); plane.data.materials.append(material(i))
        scene.render.filepath=os.path.join(RENDER,'base_%d_raw.png'%i); bpy.ops.render.render(write_still=True)

# Each atlas cell is a separate alpha plane with its own analytic painted material.
def decal_material(cell):
    g=Graph('decal_%02d'%cell); rng=random.Random(431+cell*59)
    tc=g.node('ShaderNodeTexCoord'); sep=g.node('ShaderNodeSeparateXYZ'); g.put(sep.inputs[0],tc.outputs['UV'])
    X=sep.outputs['X']; Y=sep.outputs['Y']; noise=g.noise(tc.outputs['UV'],21+cell)
    alpha=0.; col=rgba((140,135,120)); kind=['bone','bone','bone','skull','skull','crystal','crystal','puddle','puddle','salt','salt','crack','crack','bone','salt','crack'][cell]
    def maximum(a,b): return g.op('MAXIMUM',a,b)
    def ellipse(cx,cy,rx,ry,angle=0):
        dx=g.op('SUBTRACT',X,cx); dy=g.op('SUBTRACT',Y,cy)
        u=g.op('ADD',g.op('MULTIPLY',dx,math.cos(angle)),g.op('MULTIPLY',dy,math.sin(angle)))
        v=g.op('SUBTRACT',g.op('MULTIPLY',dy,math.cos(angle)),g.op('MULTIPLY',dx,math.sin(angle)))
        d=g.op('ADD',g.op('POWER',g.op('DIVIDE',u,rx),2),g.op('POWER',g.op('DIVIDE',v,ry),2))
        return g.op('MULTIPLY',g.op('SUBTRACT',1,d),12)
    def segment(ax,ay,bx,by,width):
        dx=bx-ax; dy=by-ay; length=dx*dx+dy*dy
        px=g.op('SUBTRACT',X,ax); py=g.op('SUBTRACT',Y,ay)
        t=g.op('DIVIDE',g.op('ADD',g.op('MULTIPLY',px,dx),g.op('MULTIPLY',py,dy)),length)
        t=g.op('MINIMUM',g.op('MAXIMUM',t,0),1)
        ux=g.op('SUBTRACT',px,g.op('MULTIPLY',t,dx)); uy=g.op('SUBTRACT',py,g.op('MULTIPLY',t,dy))
        d=g.op('SQRT',g.op('ADD',g.op('MULTIPLY',ux,ux),g.op('MULTIPLY',uy,uy)))
        return g.op('MULTIPLY',g.op('SUBTRACT',width,d),450)
    if kind=='bone':
        for j in range(3+cell%3):
            cx=rng.uniform(.28,.72); cy=rng.uniform(.28,.72); a=rng.uniform(.3,5.8); le=rng.uniform(.12,.23)
            dx=math.cos(a)*le/2; dy=math.sin(a)*le/2
            alpha=maximum(alpha,segment(cx-dx,cy-dy,cx+dx,cy+dy,.012))
            for s in (-1,1):
                for t in (-1,1): alpha=maximum(alpha,ellipse(cx+s*dx+t*.009,cy+s*dy,.024,.018,a))
    elif kind=='skull':
        a=[-.31,.39][cell-3]; cx=.47 if cell==3 else .56; cy=.53
        alpha=maximum(ellipse(cx,cy,.19,.22,a),ellipse(cx+.035,cy-.18,.12,.08,a))
        eyes=maximum(ellipse(cx-.073,cy-.025,.045,.06,a),ellipse(cx+.067,cy+.005,.046,.058,a))
        eyes=maximum(eyes,ellipse(cx+.009,cy-.10,.021,.032,a))
        col=g.mix(col,rgba((28,31,32)),g.op('MINIMUM',g.op('MAXIMUM',eyes,0),1))
        for j in range(4):
            tooth=segment(cx-.075+j*.045,cy-.18,cx-.06+j*.045,cy-.235,.006)
            col=g.mix(col,rgba((65,64,57)),g.op('MINIMUM',g.op('MAXIMUM',tooth,0),1))
        alpha=maximum(alpha,ellipse(.25 if cell==3 else .77,.32,.045,.028,.4))
    elif kind=='crystal':
        col=rgba((135,168,169))
        for j in range(3+cell%2):
            cx=.30+j*.115; cy=.44+rng.uniform(-.1,.12); a=rng.uniform(-.8,.8)
            dx=g.op('SUBTRACT',X,cx); dy=g.op('SUBTRACT',Y,cy)
            u=g.op('ADD',g.op('MULTIPLY',dx,math.cos(a)),g.op('MULTIPLY',dy,math.sin(a)))
            v=g.op('SUBTRACT',g.op('MULTIPLY',dy,math.cos(a)),g.op('MULTIPLY',dx,math.sin(a)))
            diamond=g.op('ADD',g.op('DIVIDE',g.op('ABSOLUTE',u),.055),g.op('DIVIDE',g.op('ABSOLUTE',v),.19))
            alpha=maximum(alpha,g.op('MULTIPLY',g.op('SUBTRACT',1,diamond),22))
        col=g.mix(col,rgba((74,103,110)),g.op('MULTIPLY',noise.outputs['Fac'],.7))
    elif kind in ('puddle','salt'):
        col=rgba((10,16,21) if kind=='puddle' else (129,128,113))
        for j in range(4+cell%3):
            shape=ellipse(rng.uniform(.32,.68),rng.uniform(.32,.68),rng.uniform(.11,.23),rng.uniform(.08,.18),rng.random()*5)
            alpha=maximum(alpha,g.op('ADD',shape,g.op('MULTIPLY',noise.outputs['Fac'],2)))
        if kind=='salt':
            alpha=g.op('MULTIPLY',alpha,g.ramp(noise.outputs['Fac'],[(.39,(0,0,0,1)),(.64,(.75,.75,.75,1))]))
        else: col=g.mix(col,rgba((37,47,51)),g.op('MULTIPLY',noise.outputs['Fac'],.45))
    else:
        col=rgba((14,18,22)); px=.22; py=rng.uniform(.3,.6)
        for j in range(6):
            qx=px+rng.uniform(.065,.10); qy=py+rng.uniform(-.095,.10)
            alpha=maximum(alpha,segment(px,py,qx,qy,.007))
            if j in (1,3,4):
                ex=px+rng.uniform(-.04,.13); ey=py+rng.choice((-1,1))*.16
                alpha=maximum(alpha,segment(px,py,ex,ey,.0045))
            px,py=qx,qy
    # A soft common boundary guarantees >=8 pixels of transparent margin.
    boundary=g.op('MINIMUM',g.op('MINIMUM',X,g.op('SUBTRACT',1,X)),g.op('MINIMUM',Y,g.op('SUBTRACT',1,Y)))
    fade=g.op('MINIMUM',g.op('MAXIMUM',g.op('MULTIPLY',g.op('SUBTRACT',boundary,.09),30),0),1)
    alpha=g.op('MINIMUM',g.op('MAXIMUM',alpha,0),1); alpha=g.op('MULTIPLY',alpha,fade)
    shade=g.ramp(noise.outputs['Fac'],[(.2,(.60,.60,.60,1)),(.75,(1,1,1,1))])
    mult=g.node('ShaderNodeMixRGB'); mult.blend_type='MULTIPLY'; mult.inputs[0].default_value=1
    g.put(mult.inputs[1],col); g.put(mult.inputs[2],shade)
    return g.emit(mult.outputs[0],alpha)

def emit_decals(scene,plane):
    plane.hide_render=True
    for cell in range(16):
        bpy.ops.mesh.primitive_plane_add(size=2,location=(-3+2*(cell%4),3-2*(cell//4),0))
        ob=bpy.context.object; ob.name='decal_cell_%02d'%cell; ob.data.materials.append(decal_material(cell))
    scene.render.filepath=os.path.join(RENDER,'decals_raw.png'); bpy.ops.render.render(write_still=True)

def main():
    scene,plane=setup_scene(); render_bases(scene,plane); emit_decals(scene,plane)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print('CRYPTES_RENDER_PASS bases=4 decals=16 raw=1024 no_lights no_normals')

def finish():
    from PIL import Image
    import numpy as np
    from sol_tools import make_seamless, verify, sheet3x3
    checks=[]
    contact=Image.new('RGB',(960,1440),(28,31,35))
    for i in range(4):
        p=os.path.join(OUT,'base_%d.png'%i)
        make_seamless(os.path.join(RENDER,'base_%d_raw.png'%i),p,size=512)
        v=verify(p); checks.append(v['ok_size'] and v['mode']=='RGB' and v['kb']<=450 and v['seam_ratio']<2.5 and 8<=v['std']<=28)
        sheet=os.path.join(RENDER,'base_%d_sheet3x3.png'%i); sheet3x3(p,sheet)
        contact.paste(Image.open(sheet).resize((480,480),Image.Resampling.LANCZOS),((i%2)*480,(i//2)*480))
        a=np.asarray(Image.open(p),dtype=float)
        drift=max(a.mean((1,2)).std(),a.mean((0,2)).std())
        print('base_%d'%i,v,'drift=%.2f'%drift)
    im=Image.open(os.path.join(RENDER,'decals_raw.png')).convert('RGBA').resize((512,512),Image.Resampling.LANCZOS)
    im.save(os.path.join(OUT,'decals.png'),optimize=True)
    a=np.asarray(im); distinct=set(); cover=[]
    for i in range(16):
        c=a[(i//4)*128:(i//4+1)*128,(i%4)*128:(i%4+1)*128]
        al=c[:,:,3]; margin=np.concatenate((al[:8].ravel(),al[-8:].ravel(),al[:,:8].ravel(),al[:,-8:].ravel()))
        checks.append(not margin.any() and np.count_nonzero(al)>80 and np.count_nonzero((al>0)&(al<255))>20)
        distinct.add(c.tobytes()); cover.append(int(np.count_nonzero(al)))
    checks.append(len(distinct)==16)
    back=Image.new('RGB',(512,512),(62,64,63)); back.paste(im,mask=im.getchannel('A'))
    contact.paste(back.resize((480,480),Image.Resampling.LANCZOS),(240,960)); contact.save(os.path.join(RENDER,'contact.png'))
    print('decals size=512 mode=RGBA distinct=%d margin=8 alpha_pixels=%s'%(len(distinct),cover))
    print(('PASS' if all(checks) else 'FAIL')+' dimensions modes size seams contrast margins alpha unique')
    if not all(checks): raise SystemExit(1)

if __name__=='__main__':
    if '--finish' in sys.argv: finish()
    else: main()
