"""Grésille: three concept studies; background Blender only, no gameplay export.
Geometry/render helpers and Blender-only layout convention from cd_cd3_common.
"""
import sys, math, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.dont_write_bytecode=True
sys.path.insert(0,str(ROOT/'art/tools/characters'))
import cd_cd3_common as cd
from cd_cd3_common import worn,mesh,plate,rod,cube,ell,tube,loft,torus,empty,rgb,emit
import bpy
from mathutils import Vector
sys.path.insert(0,str(ROOT/'art/tools/cel'))
import cel_style as cel
OUT=ROOT/'art/renders/gresille'
OUT.mkdir(parents=True,exist_ok=True)

def build(k):
    root=empty('Grésille '+k)
    def mat(n,a,b,metal=0):return worn(k+' / '+n,a,b,metal)
    wool=mat('laine','42464D','687079');rubber=mat('gutta-percha','15191C','30363A')
    canvas=mat('toile','332C23','615243');skin=mat('peau olive','897565','C4AD93')
    copper=mat('cuivre patiné','344A40','607D6C',.55);edge=mat('cuivre poli','755844','A58A62',.65)
    glass=mat('verre fumé','273747','52677A',.25);wood=mat('bois ciré','29251F','5A4938')
    hair=mat('cheveux','161B1D','3B3F3E');ink=mat('coutures','171B20','25292D')
    accent=emit(k+' / unique accent','D8EEFF' if k=='B' else 'B9A6FF',1.6)
    accent['rainfall_emissive']=True
    # Heavy work boots, short sturdy legs; head crown at 1.35 u.
    for x in [-.135,.135]:
        cube('Semelle rainurée',(x,-.05,.047),(.19,.32,.085),rubber,root)
        ell('Botte',(x,-.055,.145),(.10,.17,.115),rubber,root)
        loft('Tige botte',[(.12,.095,.11,0),(.34,.083,.08,0)],rubber,root,N=16).location.x=x
        torus('Rebord botte',(x,0,.33),.084,.014,copper,root,sc=(1,.9,1))
        rod('Pantalon',[(x,0,.29),(x,.02,.52),(x*.8,0,.69)],.103,wool,root)
        for z in [.075,.10]:cube('Stries semelle',(x,-.207,z),(.17,.008,.009),ink,root,b=.002)
    loft('Veste épaisse',[(.53,.19,.135,0),(.67,.22,.145,0),(.89,.255,.145,0),(.99,.235,.13,0),(1.04,.17,.12,0)],wool,root,N=20)
    cube('Plastron toile',(0,-.14,.80),(.31,.035,.34),canvas,root)
    for x in [-.13,.13]:
        tube('Bretelle',[(x,.10,1.01),(x,-.12,1.01),(x,-.17,.74)],.022,rubber,root)
        cube('Boucle bretelle',(x,-.182,.89),(.048,.016,.045),edge,root,b=.004)
    for z in [.76,.83,.90]:ell('Bouton',(0,-.171,z),(.012,.008,.012),edge,root)
    loft('Ceinture',[(.61,.225,.16,0),(.67,.225,.16,0)],rubber,root,N=24)
    cube('Boucle ceinture',(0,-.177,.641),(.065,.02,.047),edge,root,b=.004)
    for x in [-.19,.19]:cube('Poche outils',(x,-.14,.58),(.09,.07,.12),canvas,root)
    for x in [.14,.19]:rod('Pince manche',[(x,-.19,.58),(x+.018,-.19,.73)],.012,edge,root)
    rod('Pince bec',[(.15,-.19,.73),(.18,-.19,.76),(.20,-.19,.73)],.012,copper,root)
    cube('Brosse laiton',(-.20,-.19,.66),(.045,.035,.072),wood,root)
    for i in range(6):rod('Soies',[(-.22+i*.008,-.19,.69),(-.22+i*.008,-.19,.73)],.003,edge,root)
    torus('Mètre ruban',(-.27,-.07,.63),.035,.012,edge,root,rot=(math.pi/2,0,0))
    # Realistic tired face; strong nose, recessed eyes, tight mouth, copper hairpins.
    rod('Cou',[(0,0,1.0),(0,0,1.12)],.066,skin,root)
    ell('Crâne',(0,-.005,1.205),(.092,.086,.121),skin,root)
    ell('Mâchoire',(0,-.038,1.15),(.074,.064,.064),skin,root)
    ell('Chevelure',(0,.029,1.245),(.096,.075,.097),hair,root)
    ell('Cheveux tirés sur le crâne',(0,.002,1.288),(.094,.085,.046),hair,root)
    for i in range(7):
        x=-.075+i*.025
        tube('Mèche plaquée',[(x,-.06,1.281),(x*.9,.015,1.331),(x*.6,.09,1.30)],.003,ink,root)
    ell('Chignon',(0,.104,1.26),(.065,.053,.060),hair,root)
    for x in [-.092,.092]:ell('Oreille',(x,-.005,1.20),(.018,.018,.032),skin,root)
    for x in [-.035,.035]:
        ell('Cernes',(x,-.083,1.198),(.023,.005,.008),canvas,root)
        rod('Paupière',[(x-.018,-.091,1.211),(x+.015,-.091,1.209)],.0025,ink,root)
        rod('Sourcil',[(x-.023,-.083,1.231),(x+.02,-.084,1.23)],.006,hair,root)
    ell('Nez',(0,-.09,1.183),(.013,.021,.027),skin,root)
    rod('Bouche serrée',[(-.027,-.094,1.145),(.024,-.094,1.145)],.0035,ink,root)
    for i in range(3):rod('Épingle cuivre',[(-.07+i*.035,.07,1.28),(.055+i*.022,.13,1.345)],.004,edge,root)
    for i in range(5):tube('Mèche',[(-.07+i*.025,.02,1.30),(-.075+i*.027,-.02,1.325),(-.08+i*.029,-.025,1.34)],.003,hair,root)
    # Copper mesh cape: individually modelled diagonal weave over a fabric backing.
    low=.30 if k=='C' else .71
    levels=[(low,.27,.15,.115),(.78,.31,.17,.06),(.98,.30,.16,.025),(1.035,.19,.12,.02)]
    vs=[];fs=[]
    for z,xr,yr,cy in levels:
        for j in range(17):
            t=-math.pi/2+j*math.pi/16;vs.append((xr*math.sin(t),cy+yr*math.cos(t),z))
    for h in range(3):
        for j in range(16):a=h*17+j;fs.append((a,a+1,a+18,a+17))
    mesh('Cape treillis support',vs,fs,canvas,root)
    rows=18 if k=='C' else 9
    for row in range(rows):
        z=low+(1.02-low)*row/rows
        for j in range(15):
            t=-1.45+j*.20;xr=.28 if z<.96 else .24
            x=xr*math.sin(t);y=.08+.18*math.cos(t)
            torus('Maille cuivre',(x,y,z),.017,.003,copper,root,rot=(math.pi/2,0,-t),sc=(.78,1,1))
    cube('Râtelier bois',(0,.223,.85 if k!='C' else .65),(.47,.07,.40),wood,root)
    for z in [.73,.96]:cube('Traverse cuivre',(0,.272,z if k!='C' else z-.20),(.52,.027,.035),copper,root)
    for side in [-1,1]:
        x=side*(.23 if k!='C' else .285);y=.23 if k!='C' else .105
        base=.70 if k!='C' else .47;radius=.112 if k=='B' else .091
        loft('Bouteille Leyde',[(base,radius*.8,radius*.8,y),(base+.035,radius,radius,y),(base+.31,radius,radius,y),(base+.36,radius*.67,radius*.67,y),(base+.40,radius*.55,radius*.55,y)],glass,root,N=20).location.x=x
        for dz in [.035,.14,.30,.36]:torus('Cerclage bouteille',(x,y,base+dz),radius if dz<.35 else radius*.63,.009,copper,root)
        cube('Contact Leyde',(x,y,base+.411),(.08,.06,.025),edge,root)
        ax=x+side*radius*.68;ay=y-radius*.78
        rod('Arc interne',[(ax-.018,ay,base+.065),(ax+.018,ay,base+.14),(ax-.018,ay,base+.21),(ax+.018,ay,base+.29)],.007,accent,root)
        shoulder=(side*.245,0,.97);elbow=(side*(.36 if k=='B' else .30),-.025,.81);hand=(side*(.40 if k=='B' else .32),-.14,.69)
        ell('Épaule',shoulder,(.107,.135,.11),wool,root)
        rod('Manche',[shoulder,elbow],.09,wool,root);rod('Manchette',[elbow,hand],.081,canvas,root)
        ell('Gant',hand,(.073,.08,.086),canvas,root)
        for i in range(3):rod('Couture gant',[(hand[0]-.03+i*.025,-.215,.69),(hand[0]-.03+i*.025,-.21,.72)],.003,ink,root)
        tube('Câble gainé',[(x,y,base+.41),(side*.38,.16,1.02),(side*.44,-.02,.84),hand],.018,rubber,root)
        if k=='B':
            for z in [.73,.755,.78,.805,.83]:torus('Bobine gantelet',(side*.39,-.115,z),.102,.012,edge,root)
            torus('Anneau arc',(side*.39,-.115,.85),.089,.007,accent,root)
        if k=='C':
            tube('Boucle de câble au sol',[(x,y,.82),(side*.48,-.06,.59),(side*.57,-.21,.15),(side*.47,-.34,.033),(side*.34,-.25,.04),(side*.48,-.02,.30),hand],.023,rubber,root)
            for z in [.36,.43]:torus('Collier câble',(side*.48,-.02,z),.026,.005,copper,root)
    if k!='B':
        x=.34 if k=='A' else -.23;y=-.15 if k=='A' else .35;z=.22 if k=='A' else .40
        rod('Paratonnerre',[(x,y,z),(x,y,z+1.0 if k=='A' else z+.72)],.015,copper,root)
        for dz in [.68,.75,.82] if k=='A' else [.48,.54,.60]:
            torus('Isolateur verre',(x,y,z+dz),.054,.012,glass,root)
            torus('Charge isolateur',(x,y,z+dz+.01),.038,.005,accent,root)
        rod('Pointe polie',[(x,y,z+(.85 if k=='A' else .63)),(x,y,z+(1.10 if k=='A' else .77))],.009,edge,root)
    return root

def raw_render(path,w,h,target,scale,az=-25,elev=18):
    # Native common render, CEL configure, no normal output and no asset resizing.
    configure=cel.install('creature',normals=False,keep_black_emission=False)
    bpy.context.view_layer.update()
    cel.setup_scene(samples=16);cel.toon_materials('creature')
    # render() positions the camera before compositor setup; target that same basis here.
    configure(path)
    cd.render(path,w,h,target,scale,az,elev)
    finish_pass(path)

def finish_pass(path):
    from PIL import Image, ImageStat
    for p in path.parent.glob(path.stem+'_e__*.png'):
        with Image.open(p) as im:
            if max(ImageStat.Stat(im.convert('RGB')).extrema[i][1] for i in range(3))>2:
                im.save(path.with_name(path.stem+'_e.png'))
        p.unlink()

def make_layout():
    # cd_cd3_common.make_layout convention: orthographic Blender quads, fonts, image UVs.
    s=bpy.data.scenes.new('Planche Grésille');bpy.context.window.scene=s
    s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=8
    s.render.resolution_x=2400;s.render.resolution_y=1350;s.render.resolution_percentage=100
    s.view_settings.view_transform='Standard';s.world=bpy.data.worlds.new('Fond planche')
    bpy.ops.object.camera_add(location=(1200,675,3000));s.camera=bpy.context.object
    s.camera.data.type='ORTHO';s.camera.data.ortho_scale=2400;s.camera.data.clip_end=10000
    bg=emit('Fond','17212D');fg=emit('Texte','E1E4E4');muted=emit('Légende','A6B4BC')
    def quad(n,x,y,w,h,m,z=0):return mesh(n,[(x,1350-y-h,z),(x+w,1350-y-h,z),(x+w,1350-y,z),(x,1350-y,z)],[(0,1,2,3)],m,None)
    quad('Fond',0,0,2400,1350,bg,-2)
    font=bpy.data.fonts.load('C:/Windows/Fonts/segoeui.ttf')
    def text(t,x,y,size=24,ma=fg):
        c=bpy.data.curves.new('Typographie','FONT');c.body=t;c.font=font;c.size=size
        o=bpy.data.objects.new(t,c);s.collection.objects.link(o);o.location=(x,1350-y,10);o.data.materials.append(ma)
    def panel(file,x,y,w,h,nearest=False):
        m=bpy.data.materials.new(file);m.use_nodes=True;n=m.node_tree.nodes;n.clear();l=m.node_tree.links
        im=n.new('ShaderNodeTexImage');im.image=bpy.data.images.load(str(OUT/file));im.interpolation='Closest' if nearest else 'Linear'
        mix=n.new('ShaderNodeMixRGB');mix.inputs[1].default_value=rgb('17212D');l.new(im.outputs['Alpha'],mix.inputs[0]);l.new(im.outputs['Color'],mix.inputs[2])
        e=n.new('ShaderNodeEmission');o=n.new('ShaderNodeOutputMaterial');l.new(mix.outputs[0],e.inputs[0]);l.new(e.outputs[0],o.inputs[0])
        ob=quad(file,x,y,w,h,m,1);uv=ob.data.uv_layers.new()
        for f in ob.data.polygons:
            for li,co in zip(f.loop_indices,[(0,0),(1,0),(1,1),(0,1)]):uv.data[li].uv=co
    text('GRÉSILLE',52,70,48);text('PARATONNERRIÈRE  /  ÉTUDE DE SILHOUETTES  /  1,35 u',382,65,24,muted)
    for j,(k,name,desc) in enumerate([('A','MÂT','Tige longue · trois isolateurs'),('B','BOBINES','Gantelets-bobines · Leyde élargies'),('C','CÂBLES','Boucles au sol · cape longue')]):
        x=48+j*792
        text(k+'  /  '+name,x,131,32);text(desc,x,167,21,muted)
        panel('big_'+k+'.png',x+60,182,640,660)
        panel('jeu_'+k+'.png',x,850,480,192,True)
        panel('sprite_'+k+'.png',x+518,850,192,192,True)
        text('ARDENT + GRÉSILLE · SOL C1 · 1:1',x,1066,18,muted)
        text('CREA · SE · 192²',x+518,1066,18,muted)
        palette=['4F6B5E','1F2124','3B4A5C','5A5E66','4A3F33','B89E86','D8EEFF' if k=='B' else 'B9A6FF']
        for i,h in enumerate(palette):
            xx=x+i*104;quad('Nuancier',xx,1092,86,24,emit('Hex '+h,h),3);text('#'+h,xx,1140,17)
    text('QUESTION OUVERTE  /  LISIBILITÉ DANS LE GOUFFRE',52,1211,24)
    text('Lilas #B9A6FF face au mycélium #C27BFF : confusion en jeu ? B propose le bleu-blanc #D8EEFF.',52,1252,25)
    text('Bleu d’arc très blanc : à distinguer d’Averse #5FD4E8 et des cristaux des Cryptes #BFF4FF.  /  CONCEPT À VALIDER',52,1296,21,muted)
    s.render.image_settings.file_format='PNG';s.render.filepath=str(OUT/'planche_silhouettes.png');bpy.ops.render.render(write_still=True)

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s=bpy.context.scene;s.world=bpy.data.worlds.new('Studio');s.world.color=(.12,.12,.12)
    s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=16
    s.render.threads_mode='FIXED';s.render.threads=8
    roots=[build(k) for k in 'ABC']
    cd.area('Key',(-3,-4,6),650,(1,.87,.72),4);cd.area('Fill',(3,-1,4),350,(.64,.76,1),4);cd.area('Rim',(0,4,4),500,(.75,.82,1),3)
    bpy.ops.object.camera_add();s.camera=bpy.context.object
    # Preserve all three complete hierarchies side by side in the source .blend.
    for i,r in enumerate(roots):r.location.x=(i-1)*1.5
    cd.aim(s.camera,(0,0,.7));s.camera.location=(3,-7,3);cd.aim(s.camera,(0,0,.7));s.camera.data.type='ORTHO';s.camera.data.ortho_scale=5.3
    s['brief']='Grésille / A Mât, B Bobines, C Câbles / concept only';s['height_u']=1.35
    blend=ROOT/'art/blender/characters/gresille_concept.blend';blend.parent.mkdir(parents=True,exist_ok=True)
    cel.install('creature',normals=False,keep_black_emission=False);cel.toon_materials('creature')
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    for r in roots:r.location.x=0
    def show(active):
        for r in roots:
            for o in [r,*r.children_recursive]:o.hide_render=r!=active
    for k,r in zip('ABC',roots):
        show(r);raw_render(OUT/f'big_{k}.png',900,930,(0,0,.67),1.78,-30,18)
        cd.iso_rig.create_rig('CREA',(192,192),target=(0,0,.66),reset=False)
        r.rotation_euler.z=cd.iso_rig.DIRECTIONS['se']
        s.render.resolution_x=192;s.render.resolution_y=192;s.render.resolution_percentage=100
        s.eevee.taa_render_samples=16;s.render.film_transparent=True
        path=OUT/f'sprite_{k}.png';cd.iso_rig.common.configure_passes(path)
        s.eevee.taa_render_samples=16;s.render.filepath=str(path);bpy.ops.render.render(write_still=True);finish_pass(path)
    s.compositing_node_group=None
    with bpy.data.libraries.load(str(ROOT/'art/blender/characters/ardent_iso.blend'),link=False) as (a,b):b.objects=a.objects
    loaded=[o for o in b.objects if o and o.type not in {'CAMERA','LIGHT'}]
    for o in loaded:
        s.collection.objects.link(o)
        if o.animation_data:o.animation_data_clear()
    for o in [o for o in loaded if o.parent not in loaded]:o.location.x=-.70;o.rotation_euler.z=cd.iso_rig.DIRECTIONS['se']
    # C1 terrace mapping reused from cd_cd3_common.board.
    m=bpy.data.materials.new('C1 sol');m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
    tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png'))
    m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color']);p.inputs['Roughness'].default_value=.9
    a=math.sqrt(.5)
    for x in range(-4,5):
        for y in range(-3,4):
            cx=(x-y)*a;cy=(x+y)*a
            o=mesh('C1',[(cx,cy+a,-.015),(cx+a,cy,-.015),(cx,cy-a,-.015),(cx-a,cy,-.015)],[(0,3,2,1)],m,None);uv=o.data.uv_layers.new()
            for f in o.data.polygons:
                for li,co in zip(f.loop_indices,[(.5,1),(0,.5),(.5,0),(1,.5)]):uv.data[li].uv=co
    for k,r in zip('ABC',roots):
        show(r);r.location.x=.65
        cd.iso_rig.create_rig('CREA',(480,192),target=(0,0,.58),reset=False)
        s.render.resolution_x=480;s.render.resolution_y=192;s.render.resolution_percentage=100;s.render.film_transparent=False;s.eevee.taa_render_samples=16
        s.render.filepath=str(OUT/f'jeu_{k}.png');bpy.ops.render.render(write_still=True);r.location.x=0
    make_layout()
    print('PASS Grésille: 3 models, 9 renders, 2400x1350 board; normals=False',flush=True)

if __name__=='__main__':main()
