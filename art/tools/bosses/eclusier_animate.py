"""Animations du modele valide. Blender 5.2, background uniquement."""
import sys, math, argparse
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from eclusier import build
from boss_common import *
OUT=ROOT/'art/renders/bosses/eclusier'
SPECS={**{f'idle_p{p}':(6,['s'],p) for p in (1,2,3)},**{f'walk_p{p}':(8,['e','s','w','n'],p) for p in (1,2,3)},'auto':(6,['s'],1),'spell_a':(8,['s'],1),'spell_b':(8,['s'],1),'trans_p2':(8,['s'],2),'trans_p3':(8,['s'],3),'death':(10,['s'],3),'anchored':(1,['s'],3),'wheel':(8,['s'],1),'wave':(8,['s'],0),'geyser':(12,['s'],0),'ground_geyser':(12,['s'],0),'ground_water':(4,['s'],0),'ground_wave':(8,['s'],0)}
def find(prefix):return next(o for o in bpy.context.scene.objects if o.name.startswith(prefix))
def descendants(o):return list(o.children_recursive)
def make(anim):
    frames,dirs,phase=SPECS[anim];s=setup_scene(6.4)
    s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=24
    if phase:
        root,base=build(phase);torso=find('Torse_pivot');wheel=find('Roue_de_vanne_pivot');gate=find('Vanne_coulissante');head=find('Tete_pivot')
        arms=[find('Bras_gauche'),find('Bras_droit')];legs=[find('Jambe_-1'),find('Jambe_1')]
        objects=descendants(root);rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in objects}
        waterobjs=[o for o in objects if any(o.name.startswith(x) for x in ('Eau peu','Ecoulement','Ride de','Eclaboussure','Goutte de','Algue'))]
        rupture=[o for o in objects if any(o.name.startswith(x) for x in ('Jet de','Filet reflet','Goutte rupture','Fissure','Source lumineuse','Douve eclatee','Echarde','Etai'))]
        debris=[]
        if anim=='death':
            mat=next(m for m in bpy.data.materials if m.name.startswith('Fibres usees'))
            for j in range(18):
                a=j*2.39996;r=.35+(j%5)*.30
                o=box('Planche effondree',(math.cos(a)*r,math.sin(a)*r,.12+(j%3)*.045),(.20,.82,.12),mat,root,.02)
                o.rotation_euler.z=a;debris.append((o,a,r))
        if anim=='wheel':
            keep=set(descendants(wheel)+[wheel]);wheel.location=(0,0,.2)
            for o in objects:o.hide_render=o not in keep
            s.camera.data.ortho_scale=3.9;s.render.resolution_x=s.render.resolution_y=256
        def pose(t):
            for o,(l,r,sc) in rest.items():o.location=l;o.rotation_euler=r;o.scale=sc;o.hide_render=False
            base(t,anim.startswith('walk'));w=math.sin(math.tau*t)
            torso.rotation_euler.x=.025*w;torso.scale.z=1+.012*w
            wheel.rotation_euler.y=math.tau*t*.125
            if anim.startswith('walk'):
                torso.rotation_euler.z=.045*w
                for i,l in enumerate(legs):l.location.z=rest[l][0].z+.10*max(0,math.sin(math.tau*t+i*math.pi))
            u=t*frames/max(1,frames-1)
            if anim=='auto':
                swing=[0,-.65,-1.15,-.65,1.05,.15][round(t*frames)]
                arms[1].rotation_euler.x=swing;torso.rotation_euler.z=-swing*.16;torso.rotation_euler.x=.12*max(0,swing)
            if anim=='spell_a':
                arms[0].rotation_euler.x=-1.05*math.sin(math.pi*u);arms[1].rotation_euler.x=-.5*math.sin(math.pi*u)
                wheel.rotation_euler.y=t*math.tau*1.35;gate.location.z=.52+.65*min(1,u*1.7)
                torso.rotation_euler.x=-.10*math.sin(math.pi*u)
            if anim=='spell_b':
                impact=[0,.15,.40,.25,-.20,-.12,-.04,0][round(t*frames)]
                legs[1].location.z+=max(0,impact);arms[0].rotation_euler.x=-max(0,impact)*2
                torso.location.z+=impact*.65;torso.rotation_euler.x=-impact*.5
            if anim=='trans_p2':
                for o in waterobjs:o.scale=rest[o][2]*max(.001,u)
                gate.location.z=.52+.23*u;torso.rotation_euler.x=.07*math.sin(math.pi*u)
            if anim=='trans_p3':
                torso.location.z=1.35-.22*u;wheel.scale=(1/1.16+u*(1-1/1.16),)*3;wheel.location.z=2.67-.19*u
                gate.location.z=.75+.25*u
                for i,l in enumerate(legs):l.location.x=(-1 if i==0 else 1)*(.46+.21*u)
                for o in rupture:o.scale=rest[o][2]*max(.001,u)
                for a in arms:a.rotation_euler.x=-.25*math.sin(math.pi*u)
            if anim=='death':
                fall=max(0,(u-.16)/.84);torso.location.z=1.13-.75*fall;torso.rotation_euler.x=1.25*fall;head.location.z-=.65*fall
                for i,a in enumerate(arms):a.rotation_euler.y=(-1 if i==0 else 1)*(.15+fall*.85)
                wheel.location.z=2.48-2.1*fall;wheel.location.x=.7*fall;wheel.rotation_euler.x=-1.57*fall;wheel.rotation_euler.y=fall*3
                for i,o in enumerate(objects):
                    if o.name.startswith(('Fut douve','Bras_porte_planche','Douve eclatee')):
                        o.rotation_euler.y+=fall*((i%5)-2)*.9;o.rotation_euler.x+=fall*1.35;o.location.x+=fall*((i%7)-3)*.25;o.location.z-=fall*(.25+(i%3)*.18)
                for o in waterobjs+rupture:o.scale=rest[o][2]*max(.001,1-fall)
                rubble=max(0,(u-.35)/.65)
                for o,a,r in debris:
                    o.hide_render=u<.35;o.scale=(max(.001,rubble),)*3
                    o.location.z=.12+(1-rubble)*.85;o.rotation_euler.y=(1-rubble)*.8
                if u>.77:
                    for o in descendants(torso):o.hide_render=True
                for i,l in enumerate(legs):l.rotation_euler.x=fall*1.2
            if anim=='wheel':
                for o in objects:o.hide_render=o not in keep
                wheel.location=(0,0,.2);wheel.rotation_euler.y=math.tau*t/8
        return root,pose
    # Water props are real animated Blender geometry, with matching rendered passes.
    root=empty('Water_prop');water=material('Eau argent',(.13,.40,.46),.3,.21,emission=.35);foam=material('Ecume lumineuse',(.48,.8,.81),.1,.26,emission=.75)
    long=anim in ('wave','ground_wave');ground=anim.startswith('ground_')
    s.render.resolution_x=256;s.render.resolution_y=1152 if long else 256
    s.camera.data.ortho_scale=19 if long else 3.8
    s.camera.location += s.camera.rotation_euler.to_matrix()@Vector((0,-(.12*6.4),0))
    if anim=='ground_water':
        # Periodic seamless surface, camera orthogonal to the square tile.
        s.camera.location=(0,0,10);s.camera.rotation_euler=(0,0,0);s.camera.data.ortho_scale=2
        verts=[];faces=[];N=40
        for j in range(N+1):
            for i in range(N+1):verts.append((-1+2*i/N,-1+2*j/N,0))
        for j in range(N):
            for i in range(N):a=j*(N+1)+i;faces.append((a,a+1,a+N+2,a+N+1))
        m=bpy.data.meshes.new('Periodic water');m.from_pydata(verts,[],faces);ob=bpy.data.objects.new('Tile',m);bpy.context.collection.objects.link(ob);ob.data.materials.append(water)
        def pose(t):
            for v in m.vertices:
                x,y=v.co.x,v.co.y;v.co.z=.035*(math.sin(math.pi*2*x+math.tau*t)+math.cos(math.pi*2*y-math.tau*t))
            m.update()
        return root,pose
    parts=[]
    if long:
        # Continuous water ridge with travelling foam, rather than stacked blobs.
        nx,ny=18,90;verts=[];faces=[]
        for j in range(ny+1):
            for i in range(nx+1):verts.append((-1.25+2.5*i/nx,-8.5+17*j/ny,0))
        for j in range(ny):
            for i in range(nx):
                a=j*(nx+1)+i;faces.append((a,a+1,a+nx+2,a+nx+1))
        mesh=bpy.data.meshes.new('Continuous wave');mesh.from_pydata(verts,[],faces);mesh.update()
        ob=bpy.data.objects.new('Wave surface',mesh);bpy.context.collection.objects.link(ob);ob.data.materials.append(water)
        for f in mesh.polygons:f.use_smooth=True
        ribbons=[]
        for k in range(3):
            o=tube('Foam crest',[(0,-8.5+17*j/45,.1) for j in range(46)],.025 if k else .045,foam,root);ribbons.append(o)
        def height(x,y,t):
            crest=x-.18*math.sin(y*1.5-math.tau*t)
            return .06+(.17 if ground else .65)*math.exp(-((crest+.25)/.50)**2)*(1+.15*math.sin(y*2+math.tau*t))
        def pose(t):
            for v in mesh.vertices:v.co.z=height(v.co.x,v.co.y,t)
            mesh.update()
            for k,o in enumerate(ribbons):
                for bp in o.data.splines[0].bezier_points:
                    y=bp.co.y;x=-.25+k*.20+.18*math.sin(y*1.5-math.tau*t)
                    bp.co.x=x;bp.co.z=height(x,y,t)+.022
        return root,pose
    else:
        sphere('Base fontaine',(0,0,0),(.95,.75,.06),water,root)
        for j in range(14):
            a=j*math.tau/14
            ob=tube('Jet fontaine',[(0,0,0),(.3*math.cos(a),.3*math.sin(a),.65 if ground else 1.5),(.85*math.cos(a),.85*math.sin(a),.1)],.055,water if j%2 else foam,root);parts.append((ob,j))
            ob=sphere('Goutte',(math.cos(a)*.7,math.sin(a)*.7,.8),(.065,.065,.12),foam,root);parts.append((ob,j+.5))
    rest={o:(o.location.copy(),o.scale.copy()) for o,j in parts}
    def pose(t):
        for o,j in parts:
            l,sc=rest[o];o.location=l;o.scale=sc
            a=math.tau*t+j*.65
            if long:o.location.x=l.x+.22*math.sin(a);o.scale.z=sc.z*(1+.32*math.sin(a));o.location.z=l.z+.06*math.cos(a)
            else:o.scale.z=sc.z*(.8+.2*math.sin(a));o.location.z=l.z+.10*math.sin(a)
    return root,pose

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--anims',nargs='+',default=list(SPECS));args=ap.parse_args(sys.argv[sys.argv.index('--')+1:])
    for anim in args.anims:
        root,pose=make(anim);frames,dirs,_=SPECS[anim]
        # Save an inspectable animation rig with actual transform keyframes.
        if anim=='idle_p1':
            for i in range(6):
                pose(i/6)
                for o in descendants(root):
                    for key in ('location','rotation_euler','scale'):o.keyframe_insert(data_path=key,frame=i+1)
            bpy.context.scene.frame_end=6
            bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/bosses/eclusier_animations.blend'))
            for o in descendants(root):o.animation_data_clear()
        render_animation(root,pose,OUT/anim,frames,dirs)
if __name__=='__main__':main()





