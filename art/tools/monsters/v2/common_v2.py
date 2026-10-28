"""Shared v2 CREA pipeline. Blender background; fixed cells; no normal files."""
import sys, math, hashlib
from pathlib import Path
import bpy
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[4]
sys.path[:0] = [str(ROOT/'art/tools/iso'), str(ROOT/'art/tools/cel')]
import iso_rig
import cel_style as cel
from PIL import Image
DIRS = ('e','se','s','sw','w','nw','n','ne')

def empty(name, loc=(0,0,0), parent=None):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o)
    o.parent=parent; o.location=loc; return o

def mesh(name, verts, faces, mat, parent):
    m=bpy.data.meshes.new(name); m.from_pydata(verts,[],faces); m.update()
    o=bpy.data.objects.new(name,m); bpy.context.collection.objects.link(o)
    o.parent=parent; o.data.materials.append(mat); return o

def material(name, color, emission=0):
    c=[int(color[i:i+2],16)/255 for i in (0,2,4)]
    c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]
    m=iso_rig.material(name,c,roughness=.85,emission=emission)
    if emission: m['rainfall_emissive']=True
    return m

def ellipsoid(name, loc, scale, mat, parent, subdiv=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv,radius=1)
    o=bpy.context.object; o.name=name; o.parent=parent; o.location=loc; o.scale=scale
    o.data.materials.append(mat); return o

def taper(name, a, b, radii, mat, parent, sides=5):
    """Faceted variable-section segment; joint pivots are separate parent empties."""
    a,b=Vector(a),Vector(b); q=(b-a).to_track_quat('Z','Y')
    verts=[a.lerp(b,t)+q@Vector((r*math.cos(j*math.tau/sides),r*math.sin(j*math.tau/sides),0))
           for t,r in ((0,radii[0]),(.38,max(radii)),(1,radii[1])) for j in range(sides)]
    faces=[tuple(range(sides-1,-1,-1)),tuple(range(2*sides,3*sides))]
    faces += [(k*sides+j,k*sides+(j+1)%sides,(k+1)*sides+(j+1)%sides,(k+1)*sides+j)
              for k in range(2) for j in range(sides)]
    return mesh(name,verts,faces,mat,parent)

def rig(size,bottom):
    s=iso_rig.create_rig('CREA',size)
    s.camera.data.ortho_scale=size[0]/64
    s.camera.data.shift_y=(bottom-size[1]/2)/size[0]
    s.render.image_settings.color_mode='RGBA'; s.render.dither_intensity=0
    return s

def tres(name, size, counts, out):
    lines=['[gd_resource type="SpriteFrames" load_steps=%d format=3]'%(5+sum(n*(4 if a=='death' else 8) for a,n in counts.items())), '']
    for i,a in enumerate(counts,1):
        lines += ['[ext_resource type="Texture2D" path="res://assets/sprites/monsters/%s/%s.png" id="%d"]'%(name,a,i),'']
    anims=[]
    for i,(a,n) in enumerate(counts.items(),1):
        for row,d in enumerate(('e','s','w','n') if a=='death' else DIRS):
            ids=[]
            for f in range(n):
                ident='%s_%s_%d'%(a,d,f); ids.append(ident)
                lines += ['[sub_resource type="AtlasTexture" id="%s"]'%ident,'atlas = ExtResource("%d")'%i,
                          'region = Rect2(%d, %d, %d, %d)'%(f*size[0],row*size[1],*size),'']
            frames=', '.join('{"duration": 1.0, "texture": SubResource("%s")}'%x for x in ids)
            anims.append('{"frames": [%s], "loop": %s, "name": &"%s_%s", "speed": %.1f}'%(frames,str(a in ('idle','run','leap')).lower(),a,d,8 if a=='idle' else 14 if a in ('run','leap') else 12))
    lines += ['[resource]','animations = [\n'+',\n'.join(anims)+'\n]']
    (out/(name+'.tres')).write_text('\n'.join(lines)+'\n',encoding='utf8')

def produce(name,size,bottom,counts,root,pose):
    s=bpy.context.scene; out=ROOT/'game/assets/sprites/monsters'/name
    work=ROOT/'art/blender/monsters/v2'/('_'+name+'_frames'); work.mkdir(parents=True,exist_ok=True)
    out.mkdir(parents=True,exist_ok=True)
    meshes=[o for o in root.children_recursive if o.type=='MESH']
    tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
    limit=1500 if name=='swarm_tier1' else 3000
    assert tris<=limit,(name,tris,limit)
    iso_rig.bake_ao_shadows(root)
    cel.install('creature',normals=False)
    cel.toon_materials('creature')
    for mat in bpy.data.materials:
        if not mat.use_nodes: continue
        diffuse=next((n for n in mat.node_tree.nodes if n.type=='BSDF_DIFFUSE'),None)
        if diffuse:
            ao=mat.node_tree.nodes.new('ShaderNodeAmbientOcclusion')
            ao.name='V2 baked AO into cel lighting'; ao.inputs['Distance'].default_value=.18
            ao.inputs['Color'].default_value=diffuse.inputs['Color'].default_value
            mat.node_tree.links.new(ao.outputs['Color'],diffuse.inputs['Color'])
    # Persist actual articulated timelines, not merely a static render pose.
    animated=[o for o in root.children_recursive if o.type=='EMPTY']
    offset=1
    for a,n in counts.items():
        s.timeline_markers.new(a,frame=offset)
        for f in range(n):
            pose(a,f,n)
            for o in animated:
                for prop in ('location','rotation_euler','scale'): o.keyframe_insert(data_path=prop,frame=offset+f)
        offset+=n
    s.frame_end=offset-1; s.frame_set(1)
    root['v2_cell']=list(size); root['v2_bottom']=bottom; root['v2_tris']=tris
    root['v2_density']=64; root['v2_directions']=','.join(DIRS)
    # Remove animation evaluation for manual per-frame posing; restore for saved source.
    actions=[(o,o.animation_data.action) for o in animated if o.animation_data]
    for o,_ in actions: o.animation_data.action=None
    pose('idle',0,counts['idle']); root.rotation_euler.z=0
    # Camera ground anchor follows the fixed foot stance, independent of the action.
    footrefs=[Vector(v) for v in root['foot_reference']]
    for a,n in counts.items():
        if '--only' in sys.argv and a not in sys.argv[sys.argv.index('--only')+1].split(','): continue
        dirs=('e','s','w','n') if a=='death' else DIRS
        sheets={k:Image.new('RGBA',(size[0]*n,size[1]*len(dirs))) for k in ('','_e')}
        for row,d in enumerate(dirs):
            root.rotation_euler.z=math.radians(90-45*DIRS.index(d))
            rot=root.rotation_euler.to_matrix()
            lowest=min((rot@p).y*.5+p.z*math.cos(math.pi/6) for p in footrefs)
            s.camera.data.shift_y=(bottom-size[1]/2+lowest*64)/size[0]
            for f in range(n):
                pose(a,f,n); bpy.context.view_layer.update()
                path=work/('%s_%s_%02d.png'%(a,d,f))
                iso_rig.common.configure_passes(path)
                s.render.filepath=str(path); bpy.ops.render.render(write_still=True)
                for suffix in ('','_e'):
                    src=path if not suffix else next(work.glob(path.stem+'_e__*.png'))
                    with Image.open(src) as im: im=im.convert('RGBA').resize(size,Image.Resampling.LANCZOS)
                    sheets[suffix].paste(im,(f*size[0],row*size[1]))
                    if suffix: src.unlink()
                path.unlink()
        for suffix,im in sheets.items():
            if suffix: im=im.resize(((im.width+1)//2,(im.height+1)//2),Image.Resampling.LANCZOS)
            im.save(out/(a+suffix+'.png'),optimize=True)
        print('V2 COMPLETE',name,a,flush=True)
    tres(name,size,counts,out)
    for o,action in actions: o.animation_data.action=action
    root.rotation_euler.z=0; s.frame_set(1)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/monsters/v2'/(name+'.blend')))
    verify(name,size,counts)
    print('V2 PASS',name,'triangles',tris,flush=True)

def verify(name,size,counts):
    out=ROOT/'game/assets/sprites/monsters'/name
    for a,n in counts.items():
        im=Image.open(out/(a+'.png')).convert('RGBA'); rows=4 if a=='death' else 8
        assert im.size==(size[0]*n,size[1]*rows)
        for r in range(rows):
            seen=set()
            for f in range(n):
                cell=im.crop((f*size[0],r*size[1],(f+1)*size[0],(r+1)*size[1]))
                box=cell.getchannel('A').point(lambda v:255 if v>12 else 0).getbbox()
                assert box and box[0]>=4 and box[1]>=4 and box[2]<=size[0]-4 and box[3]<=size[1]-4,(a,r,f,box)
                h=hashlib.sha256(cell.tobytes()).digest(); assert h not in seen,(a,r,f,'duplicate'); seen.add(h)
        e=Image.open(out/(a+'_e.png')).convert('RGBA')
        assert e.size==((im.width+1)//2,(im.height+1)//2)
        assert max(e.getchannel('G').getextrema())>2
    assert not list(out.glob('*_n.png'))

def contact():
    """2x2 panels: run s/e then impact s/e; each contains swarm, shooter, Ash Lord.
    V2 at 64 px/u, Ash Lord at actual mini-boss scale (2.4 * 1.1 * 64 / 100).
    Assembly only; every visible pixel comes from a rendered game asset.
    """
    ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    board=Image.new('RGBA',(720,480))
    for y in range(-ground.height,board.height,ground.height//2):
        for x in range(-ground.width,board.width,ground.width): board.alpha_composite(ground,(x+(ground.width//2 if (y//(ground.height//2))%2 else 0),y))
    ash=Image.open(ROOT/'game/assets/sprites/bosses/mini/ash_lord/run.png').convert('RGBA')
    # Atlas has 70x118 cells; apply the game's current mini-boss scale uniformly.
    factor=2.4*1.1*64/100
    ref=ash.crop((0,0,70,118)).resize((round(70*factor),round(118*factor)),Image.Resampling.LANCZOS)
    for panel,(a,d) in enumerate((('run','s'),('run','e'),('attack','s'),('attack','e'))):
        ox=(panel%2)*360; baseline=(panel//2)*240+218
        for x,name,size,bottom,n in ((62,'swarm_tier1',(64,56),48,6),(157,'shooter_tier2',(88,104),96,8)):
            f=0 if a=='run' else n//2; row=DIRS.index(d)
            source=Image.open(ROOT/'game/assets/sprites/monsters'/name/(a+'.png')).convert('RGBA')
            tile=source.crop((f*size[0],row*size[1],(f+1)*size[0],(row+1)*size[1]))
            board.alpha_composite(tile,(ox+x-size[0]//2,baseline-bottom))
        board.alpha_composite(ref,(ox+280-ref.width//2,baseline-round(117*factor)))
    board.save(ROOT/'art/tools/night/_mob_v2_t1_contact.png',optimize=True)
