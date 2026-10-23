"""C5 serious angular base creatures. Background Blender, preserved legacy atlases."""
import sys, math, json, hashlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from ash_lord_build import worn, mesh, plate, rod, shard
from common import empty, material
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'iso'))
import iso_rig
from PIL import Image
# Preserve black back-facing frames: legacy emission atlas has a fixed grid.
iso_rig.optimize_png=lambda path,**kwargs: None
_original_passes=iso_rig.common.configure_passes
def configure_passes(path):
    _original_passes(path)
    s=bpy.context.scene
    tree=getattr(s,'node_tree',None) or s.compositing_node_group
    for node in tree.nodes:
        if node.bl_idname=='CompositorNodeSetAlpha':node.inputs['Type'].default_value='Replace Alpha'
iso_rig.common.configure_passes=configure_passes
ROOT=Path(__file__).resolve().parents[3]
CFG={'swarm_tier1':(96,90.50966799187809,['run']),'shooter_tier2':(112,64,['run','attack']),'leaper_tier2':(112,64,['run','charge']),'brute_tier3':(160,64,['run','attack','cast'])}
DIRS=['e','se','s','sw','w','nw','n','ne']

def shell(name,center,radii,mat,parent):
    # Tapered irregular eight-sided armour, with a raised angular ridge.
    x,y,z=center; rx,ry,rz=radii
    verts=[(x,y-ry,z),(x-rx*.65,y-ry*.65,z-rz*.4),(x-rx,y+ry*.35,z-rz*.2),(x-rx*.5,y+ry,z),(x+rx*.5,y+ry,z),(x+rx,y+ry*.35,z-rz*.2),(x+rx*.65,y-ry*.65,z-rz*.4),(x,y,z+rz)]
    return mesh(name,verts,[(i,(i+1)%7,7) for i in range(7)]+[tuple(range(6,-1,-1))],mat,parent,.007)

def build(name):
    size,R,anims=CFG[name];s=iso_rig.create_rig('CREA',size);s.eevee.taa_render_samples=12
    s.camera.data.ortho_scale=size/R;s.camera.data.shift_y=.20
    s['render_px_per_u']=R;s['ground_pivot_percent']=70
    iron=worn('Pitted black iron','202224','64645D',.65,.58)
    bone=worn('Eroded horn','34352E','8D8B72',.05,.81)
    hide=worn('Mud stained chitin','202A27','596358',.12,.78)
    cloth=worn('Rotten charcoal linen','1B1D23','4B4850',0,.91)
    rust=worn('Oxidised bindings','30241E','70503A',.5,.72)
    accent={'swarm_tier1':'A7D26D','shooter_tier2':'75CAD0','leaper_tier2':'92C7A9','brute_tier3':'83B5D1'}[name]
    glow=material('Single cold emission',accent,4,True)
    root=empty(name);body=empty('Body',parent=root);limbs=[]
    def limb(label,pts,r,mat=hide):
        o=empty(label,parent=body);rod(label+' angular limb',pts,r,mat,o);limbs.append(o);return o
    if name=='swarm_tier1':
        # Low segmented marsh predator: small wedge skull, six sharp articulated legs.
        for i in range(4):
            shell('Overlapping dorsal scute', (0,.19-i*.105,.20+i*.012),(.16-i*.012,.145,.105),hide if i%2 else iron,body)
        shell('Narrow mandible skull',(0,-.27,.18),(.098,.13,.065),bone,body)
        for side in (-1,1):
            for i in range(3):
                y=.19-i*.16
                limb('Jointed leg',[(side*.1,y,.20),(side*(.29 if i==1 else .25),y+.03,.12),(side*.32,y-.09,.025)],.025)
            rod('Serrated jaw',[(side*.065,-.30,.17),(side*.105,-.40,.13),(side*.02,-.43,.14)],.015,bone,body)
            rod('Acid eye slit',[(side*.045,-.354,.222),(side*.078,-.323,.225)],.012,glow,body)
        rod('Ragged tail',[(0,.28,.19),(.03,.40,.12),(.10,.46,.08)],.025,hide,body)
    elif name=='shooter_tier2':
        # Narrow adult proportions, pointed hood, layered ragged mantle and recurve bow.
        shell('Lean ribcage',(0,0,.87),(.17,.11,.23),cloth,body)
        for side in (-1,1):
            limb('Shin',[(side*.085,0,.69),(side*.105,.035,.35),(side*.10,-.07,.035)],.041,cloth)
            rod('Boot',[(side*.10,.025,.045),(side*.10,-.15,.04)],.045,iron,body)
            plate('Torn long coat',[(side*.03,.90),(side*.19,.78),(side*.21,.29),(side*.13,.37),(side*.09,.25)],.075,.035,cloth,body)
        plate('Hood silhouette',[(-.14,1.05),(-.14,1.24),(-.015,1.40),(.14,1.23),(.13,1.04)],-.025,.16,cloth,body)
        plate('Deep angular face',[(-.082,1.10),(-.075,1.23),(.018,1.30),(.08,1.20),(.065,1.08)],-.048,.012,iron,body)
        rod('Solitary cyan eye',[(-.035,-.064,1.19),(.034,-.064,1.195)],.013,glow,body)
        limb('Bow arm',[(.15,0,1.02),(.26,-.12,.88),(.29,-.26,.94)],.035,cloth)
        limb('Drawing arm',[(-.15,0,1.02),(-.27,-.10,.91),(.04,-.24,.96)],.032,cloth)
        rod('Recurve iron bow',[(.29,-.25,.53),(.37,-.25,.66),(.31,-.25,.94),(.37,-.25,1.17),(.29,-.25,1.30)],.023,rust,body)
        rod('Bowstring',[(.29,-.25,.53),(.19,-.25,.94),(.29,-.25,1.30)],.006,bone,body)
        rod('Bolt',[(.19,-.56,.94),(.19,-.06,.94)],.009,bone,body)
        for z in (.77,.88,.99):rod('Chest binding',[(-.12,-.12,z),(.12,-.12,z+.025)],.012,rust,body)
    elif name=='leaper_tier2':
        shell('Long sinewy ribcage',(0,.025,.43),(.19,.36,.15),hide,body)
        shell('Narrow hunting skull',(0,-.40,.37),(.10,.17,.08),bone,body)
        for side in (-1,1):
            limb('Long front tendon',[(side*.12,-.20,.46),(side*.23,-.33,.20),(side*.19,-.53,.025)],.034)
            limb('Powerful rear hock',[(side*.16,.25,.43),(side*.26,.40,.24),(side*.17,.12,.06),(side*.19,.03,.025)],.052)
            rod('Slit eye',[(side*.055,-.51,.43),(side*.087,-.46,.445)],.012,glow,body)
            for x in (-.025,.025):rod('Claw',[(side*.19+x,-.50,.035),(side*.19+x,-.60,.018)],.009,bone,body)
        for i in range(6):
            y=-.20+i*.115
            rod('Splintered dorsal spine',[(0,y,.53),(0,y+.055,.73 if i<3 else .66)],.028,iron,body)
        rod('Whip tail',[(0,.36,.43),(.03,.58,.35),(.13,.69,.18)],.035,hide,body)
    else:
        shell('Massive tapered torso',(0,0,1.16),(.36,.21,.33),iron,body)
        shell('Small buried skull',(0,-.045,1.62),(.11,.11,.13),bone,body)
        for side in (-1,1):
            shell('Broken shoulder pauldron',(side*.37,.01,1.42),(.25,.25,.20),iron,body)
            limb('Load bearing leg',[(side*.19,0,.92),(side*.22,.08,.48),(side*.23,-.02,.08)],.115,hide)
            shell('Iron boot',(side*.23,-.09,.07),(.13,.20,.08),iron,body)
            limb('Heavy arm',[(side*.40,0,1.35),(side*.52,-.02,1.02),(side*.49,-.22,.82)],.10,hide)
            shell('Gauntlet',(side*.49,-.22,.83),(.13,.14,.13),rust,body)
            rod('Glacial eye',[(side*.025,-.155,1.65),(side*.072,-.145,1.65)],.013,glow,body)
            for j in range(3):rod('Shoulder rivet',[(side*(.24+j*.10),-.19,1.48),(side*(.24+j*.10),-.21,1.48)],.023,bone,body)
        rod('War maul haft',[(.49,-.22,.43),(.49,-.22,1.16)],.038,rust,body)
        shell('Asymmetric stone maul',(.49,-.22,.48),(.23,.17,.19),iron,body)
        for z in (.98,1.11,1.24):rod('Old chest straps',[(-.25,-.20,z),(.25,-.20,z+.06)],.024,rust,body)
        rod('Cold breastplate crack',[(-.07,-.22,1.31),(.02,-.23,1.20),(-.02,-.23,1.12)],.012,glow,body)
    if name=='shooter_tier2':body.scale=(.82,.82,.82)
    if name=='leaper_tier2':body.scale=(.88,.88,.88)
    if name=='brute_tier3':body.scale=(.90,.90,.90)
    iso_rig.bake_ao_shadows(root)
    s['animation_manifest']=json.dumps({a:{'start':j*16+1,'frames':8,'directions':DIRS} for j,a in enumerate(anims)})
    for j,anim in enumerate(anims):
        s.timeline_markers.new(anim,frame=j*16+1)
        for f in range(8):
            t=f/8;wave=math.sin(t*math.tau)
            body.location=(0,.008*math.cos(t*math.tau) if anim=='run' else 0,.012*wave if anim=='run' else 0)
            body.rotation_euler=(0,0,0)
            if anim!='run':
                # Four frames of clear recoil, then a fast forward release at frame 5.
                k=[0,-.10,-.19,-.26,-.19,.22,.12,0][f]
                body.rotation_euler.x=k if name!='brute_tier3' else k*1.4
                if name=='brute_tier3' and anim=='attack':body.rotation_euler.z=k*1.4
                if anim=='cast':body.location.z=-.12 if f>=5 else .03;body.rotation_euler.x=k*1.8
                if anim=='charge':body.location.y=[0,.03,.06,.07,.02,-.10,-.16,-.08][f];body.location.z=-.04 if f<4 else .035
            for i,o in enumerate(limbs):
                o.rotation_euler.x=(.16 if name!='swarm_tier1' else .23)*math.sin(t*math.tau+i*2.17) if anim=='run' else (-.24 if f<4 else .26)*((-1)**i)
                o.keyframe_insert('rotation_euler',frame=j*16+f+1)
            body.keyframe_insert('location',frame=j*16+f+1);body.keyframe_insert('rotation_euler',frame=j*16+f+1)
    s.frame_start=1;s.frame_end=(len(anims)-1)*16+8;s.render.fps=14
    # Verify all poses against contractual cell before rendering.
    bounds=[size,size,0,0]
    from bpy_extras.object_utils import world_to_camera_view
    for j,a in enumerate(anims):
        for d in range(8):
            root.rotation_euler.z=math.radians(90-45*d)
            for f in range(8):
                s.frame_set(j*16+f+1);bpy.context.view_layer.update()
                for ob in root.children_recursive:
                    if ob.type!='MESH':continue
                    for corner in ob.bound_box:
                        p=world_to_camera_view(s,s.camera,ob.matrix_world@Vector(corner));x=p.x*size;y=(1-p.y)*size
                        bounds=[min(bounds[0],x),min(bounds[1],y),max(bounds[2],x),max(bounds[3],y)]
    if min(bounds[:2])<4 or max(bounds[2:])>size-4:raise RuntimeError('Frame overflow '+str(bounds))
    root.rotation_euler.z=0;s.frame_set(1)
    bpy.context.preferences.filepaths.save_version=0
    source=ROOT/'art/blender/monsters'/f'{name}_iso.blend';source.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    out=ROOT/'game/assets/sprites/monsters'/name;temp=ROOT/'art/tools/monsters/iso_monster_frames'/name
    before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.tres')}
    for j,a in enumerate(anims):
        sheets={suf:Image.new('RGBA',(size*8,size*8)) for suf in ('','_n','_e')}
        for d in range(8):
            root.rotation_euler.z=math.radians(90-45*d)
            for f in range(8):
                s.frame_set(j*16+f+1);path=temp/f'{a}_{d}_{f}.png';iso_rig.render_frame(path)
                for suf in sheets:
                    p=path.with_stem(path.stem+suf)
                    with Image.open(p) as im:sheets[suf].paste(im,(f*size,d*size))
        for suf,im in sheets.items():
            if suf=='_e':assert max(c.getextrema()[1] for c in im.split()[:3])>0
            im.save(out/f'{a}{suf}.png',optimize=True,compress_level=9)
    assert before=={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.tres')}
    inv=ROOT/'art/tools/iso/_c5_inventory.json';data=json.loads(inv.read_text()) if inv.exists() else {}
    data[name]={'render_px_per_u':R,'size':size,'frames':8,'directions':DIRS,'pivot':[size*.5,size*.7],'bounds':bounds,'anims':anims,'tres_sha256':before,'verified':True}
    inv.write_text(json.dumps(data,indent=2))
    print('PASS C5',name,flush=True)

if __name__=='__main__':build(sys.argv[sys.argv.index('--')+1])







