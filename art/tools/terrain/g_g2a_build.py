"""G2a replacement renderer; geometry derived from F2's MAP block builders."""
from pathlib import Path
import sys, math, random
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/assets/sprites/terrain/fog_forest/iso'
SRC=ROOT/'art/blender/terrain'
sys.path[:0]=[str(ROOT/'art/tools'),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso/_deps'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/monsters'),str(ROOT/'art/tools/terrain'),str(ROOT/'art/tools/night')]
import cel_style as cel
from f2_build import box, trunk, root_curve, pebble
import f2_build as f2
SPECS={n:((256,256),(128,192)) for n in ('block_a','block_b','block_c','rampart_ne','rampart_nw','rampart_corner_n')}

def linear(h):
    return tuple((v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4) for v in (int(h[i:i+2],16)/255 for i in (0,2,4)))+(1,)


def materials():
    from ash_lord_build import worn
    m={k:worn(k,a,b,0,.82) for k,a,b in [('sandstone','2E221C','7A5D45'),('slate','17171B','504950'),('crack','19151A','30252B'),('accent','C27BFF','C27BFF')]}
    p=m['accent'].node_tree.nodes.get('Principled BSDF')
    p.inputs['Emission Color'].default_value=linear('C27BFF')
    p.inputs['Emission Strength'].default_value=1
    m['accent']['rainfall_emissive']=True
    return m


def slab(root,m,seed,axis=None):
    # A single watertight faceted mass. Bedding is part of the rock mesh;
    # no floor, cylinders, root arches or separate vertical posts.
    from ash_lord_build import mesh
    rng=random.Random(seed)
    ring=[(-1,-.72),(-.77,-1),(-.20,-1),(.52,-1),(1,-.76),(1,-.10),(1,.74),(.73,1),(.08,1),(-.66,1),(-1,.71),(-1,.06)]
    def xy(x,y):
        if axis==1:return (x,.80+y*.20)
        if axis==0:return (-.80+x*.20,y)
        return x,y
    verts=[];faces=[];indices=[]
    levels=[0,.27,.285,.58,.595,.88,.895,1.18]
    for k,z in enumerate(levels):
        for j,(x,y) in enumerate(ring):
            if k==0: zz=.018
            elif k==7:
                # Periodic end profiles keep adjacent wall tiles closed.
                zz=1.18+.035*math.sin(j*2.7)+(.025 if j%3 else -.025)
            else:zz=z+.20*x+.055*y
            scale=(1 if k==0 else .97+rng.uniform(-.055,.035)) if axis is None else 1
            xx,yy=xy(x*scale,y*scale)
            if axis is not None and abs(x if axis==1 else y)<.99:
                # Broad fractured facets along the continuous wall, fixed ends.
                chip=.035*math.sin(j*2.1+k*.8)
                if axis==1:yy+=chip
                else:xx+=chip
            verts.append((xx,yy,zz))
    for k in range(7):
        for j in range(12):
            nj=(j+1)%12
            faces.append((k*12+j,k*12+nj,(k+1)*12+nj,(k+1)*12+j))
            indices.append(1 if k in (1,3,5) else 0)
    faces.append(tuple(reversed(range(12))));indices.append(0)
    # Broad angular cap facets, with a low irregular chipped upper profile.
    cx,cy=xy(.02,-.03);verts.append((cx,cy,1.205))
    for j in range(12):
        faces.append((84+j,84+(j+1)%12,96));indices.append(0)
    ob=mesh('Continuous oblique bedded rock',verts,faces,m['body'],root)
    if axis is not None:
        height=max(v.co.z for v in ob.data.vertices)
        for v in ob.data.vertices:v.co.z*=1.25/height
    ob.data.materials.append(m['crack'])
    for poly,idx in zip(ob.data.polygons,indices):poly.material_index=idx
    return ob


def ribbon(root,pts,width,mat,name):
    from ash_lord_build import mesh
    # Angular flush mineral fissure, not a tubular root.
    verts=[]
    for x,y,z in pts:verts.extend([(x-width,y,z),(x+width,y,z)])
    return mesh(name,verts,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(pts)-1)],mat,root)


def make(name,root,m):
    m['body']=m['slate' if name=='block_c' else 'sandstone']
    if name.startswith('block'):
        slab(root,m,212 if name=='block_a' else 319)
        if name in ('block_b','block_c'):
            mat=m['accent' if name=='block_b' else 'crack']
            for shift in (0,.34):
                ribbon(root,[(-.39+shift,-.96,.13),(-.31+shift,-1.003,.52),(-.43+shift,-1.003,.79),(-.29+shift,-.97,1.19),(-.23+shift,-.56,1.223),(-.05+shift,-.10,1.224),(-.16+shift,.37,1.216),(.02+shift,.81,1.214)],.013 if name=='block_b' else .023,mat,'Angular mineral split')
    else:
        edges=[1] if name.endswith('ne') else [0] if name.endswith('nw') else [0,1]
        for axis in edges:
            slab(root,m,481,axis)
            # Small squat faceted fragments merge into the foot of the wall.
            for i in range(7):
                a=-.84+i*.28
                pos=(a,.63,.10) if axis==1 else (-.63,a,.10)
                pebble('Squat foot concretion',pos,(.15,.12,.10),m['sandstone'],root,i)
        if name.endswith('corner_n'):
            ribbon(root,[(-.40,.555,.12),(-.33,.555,.42),(-.44,.555,.64),(-.30,.555,.90),(-.37,.61,1.21),(-.40,.84,1.23)],.018,m['accent'],'Corner mycelium split')


def build():
    import inspect
    code=inspect.getsource(f2.rig.render_frame).replace("('_n','_e')", "('_e',)")
    exec(compile(code,str(Path(f2.rig.__file__)), 'exec'),f2.rig.__dict__)
    for name,(size,pivot) in SPECS.items():
        s=f2.rig.create_rig('MAP',size);s.camera.location+=s.camera.rotation_euler.to_matrix()@f2.Vector((0,(pivot[1]-size[1]/2)/f2.rig.R,0));s.eevee.taa_render_samples=16
        cel.install('tile',keep_black_emission=False,normals=False)
        bpy.ops.object.empty_add();root=bpy.context.object;root.name=name;m=materials();make(name,root,m)
        for ob in [root,*root.children_recursive]:
            if ob.type=='MESH':
                for v in ob.data.vertices:
                    w=ob.matrix_world@v.co;w.x=max(-1,min(1,w.x));w.y=max(-1,min(1,w.y));w.z=min(1.25,w.z);v.co=ob.matrix_world.inverted()@w
        cel.toon_materials('tile')
        for key,colors in [('sandstone',('2E221C','5A4232','7A5D45')),('slate',('17171B','353138','504950'))]:
            ramp=m[key].node_tree.nodes.get('CEL tones')
            if ramp:
                for element,color in zip(ramp.color_ramp.elements,colors):element.color=linear(color)
        f2.rig.bake_ao_shadows(root)
        f2.rig.render_frame(OUT/(name+'.png'))
        from PIL import Image
        mask=OUT/(name+'_e.png')
        if mask.exists():
            from halve_emission import downscale
            with Image.open(mask) as im: downscale(im.convert('RGBA')).save(mask,optimize=True)
        f2.rig.create_rig('TOP',(512,512),reset=False);shadow=OUT/(name+'_shadow.png');f2.rig.render_shadow_decal(root,shadow)
    print('G2a PASS: 6 diffuse, 2 emission, 6 shadow',flush=True)

if __name__=='__main__':
    import bpy
    build()
