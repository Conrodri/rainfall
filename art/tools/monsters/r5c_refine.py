"""Sculpt additions onto the saved animated Claude meshes; preserve every animation."""
from boss_pipeline import *

def refine(name):
    s=bpy.context.scene
    for obj in s.objects:
        for mod in obj.modifiers:
            if mod.name=='Forged thickness':mod.offset=0
    if s.get('r5c_refined'):return
    def meshes(prefix):
        return [o for o in s.objects if o.type=='MESH' and (o.name==prefix or o.name.startswith(prefix+'.'))]
    def stretch(prefix,xyz):
        for o in meshes(prefix):
            for v in o.data.vertices:
                for i in range(3):v.co[i]*=xyz[i]
    def recolor(label,color):
        m=bpy.data.materials[label];rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)]
        rgb=[v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
        p=m.node_tree.nodes.get('Principled BSDF')
        p.inputs['Base Color'].default_value=(*rgb,1);p.inputs['Emission Color'].default_value=(*rgb,1)
        return m
    def shard(label,a,b,r,mat,parent):
        a,b=Vector(a),Vector(b)
        bpy.ops.mesh.primitive_cone_add(vertices=5,radius1=r,radius2=0,depth=(b-a).length)
        o=finish(bpy.context.object,label,(a+b)/2,(1,1,1),mat,parent)
        o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
        for face in o.data.polygons:face.use_smooth=False
        return o
    def plate(label,coords,mat,parent,thickness=.045):
        mesh=bpy.data.meshes.new(label);mesh.from_pydata(coords,[],[tuple(range(len(coords)))]);mesh.update()
        o=bpy.data.objects.new(label,mesh);s.collection.objects.link(o);o.parent=parent;o.data.materials.append(mat)
        mod=o.modifiers.new('Forged thickness','SOLIDIFY');mod.thickness=thickness;mod.offset=0
        mod=o.modifiers.new('Chipped edge','BEVEL');mod.width=.018;mod.segments=1
        return o
    if name=='frost_bear':
        body=bpy.data.objects['Long low bear body'];head=bpy.data.objects['Low muzzle head']
        fur=recolor('Pale blue grey fur','8EAFC0');tuft=recolor('Fur tips','CCDDE3')
        ice=recolor('Pale blue stalactites','9BDCEF');dark=bpy.data.materials['Nose and mouth'];glow=bpy.data.materials['Cold pulsing eyes and crystal veins']
        stretch('Bear head',(1.17,1.08,1.12));stretch('High shoulder hump',(1.13,1.05,1.08))
        stretch('Broad bear paw',(1.12,1.08,1.06));stretch('Icy eye',(1.25,1.2,1.25))
        for o in meshes('Back ice stalactite'):
            for face in o.data.polygons:face.use_smooth=False
        for sign in (-1,1):
            segment('R5c fierce frost brow',(sign*.16,-.328,.15),(sign*.36,-.25,.11),.055,fur,head)
            for j in range(3):
                shard('R5c frozen cheek ruff',(sign*(.28+.035*j),-.01+j*.13,-.04),(sign*(.49+.045*j),.15+j*.13,-.28),.12,tuft,head)
            for j in range(4):
                y=-.55+j*.29
                shard('R5c angular glacier ridge',(sign*.38,y,1.37),(sign*(.54+.04*(j%2)),y+.10,1.83+.14*(j%2)),.14,ice,body)
                segment('R5c glacier seam',(sign*.43,y,1.33),(sign*.51,y+.07,1.66),.023,glow,body)
            for j in range(3):
                shard('R5c layered shoulder fur',(sign*.47,-.61+j*.15,1.09),(sign*.72,-.48+j*.15,.76),.14,tuft if j==0 else fur,body)
        sphere('R5c chin shadow',(0,-.40,-.255),(.19,.14,.035),dark,head)
    elif name=='rust_archon':
        body=bpy.data.objects['Floating hollow armor'];weapon=bpy.data.objects['Two body lengths halberd']
        rust=recolor('Light rust #B58A6A','BFA087');edge=recolor('Worn pale metal trim','DDD2BB')
        patina=recolor('Verdigris','93BDB2');cyan=bpy.data.materials['Split helm cyan light']
        stretch('Broad pauldron',(1.16,1.08,1.12))
        for o in meshes('Breastplate half')+meshes('Split helm half'):
            for v in o.data.vertices:
                if v.co.z<0:v.co.x*=.77
        for sign in (-1,1):
            # An open, forked crown continues the split helmet; the chest stays hollow.
            shard('R5c forked helm crown',(sign*.19,.02,2.65),(sign*.29,.06,3.02),.105,patina,body)
            segment('R5c helmet cheek trim',(sign*.24,-.205,2.61),(sign*.16,-.205,2.30),.026,edge,body)
            for j in range(3):
                sphere('R5c breastplate rivet',(sign*.31,-.265,1.61+j*.18),(.025,.018,.025),edge,body)
            plate('R5c pointed hanging tasset',[(sign*.10,-.265,1.34),(sign*.42,-.24,1.30),(sign*.43,-.25,1.03),(sign*.26,-.28,.88)],rust,body)
            segment('R5c floating rib rim',(sign*.09,-.04,1.55),(sign*.32,-.04,1.45),.025,cyan,body)
        for arm in [o for o in s.objects if o.type=='EMPTY' and o.name.startswith('Detached arm')]:
            sign=-1 if arm.location.x<0 else 1
            plate('R5c layered shoulder shield',[(sign*-.15,-.265,.10),(sign*.22,-.265,.15),(sign*.40,-.24,-.05),(sign*.27,-.27,-.30),(sign*-.10,-.27,-.16)],patina,arm)
            shard('R5c pauldron ridge',(sign*.13,.01,.12),(sign*.38,.06,.38),.10,rust,arm)
        # A broad hooked forged silhouette replaces the provisional rectangular axe.
        for o in meshes('Axe blade')+meshes('Axe cutting edge'):o.hide_render=True
        plate('R5c crescent halberd',[(.02,0,2.76),(.35,0,2.91),(.61,0,2.72),(.57,0,2.39),(.33,0,2.14),(.21,0,2.39),(.02,0,2.38)],patina,weapon,.08)
        segment('R5c axe sharpened bevel',(.60,-.055,2.73),(.56,-.055,2.40),.045,edge,weapon)
        segment('R5c axe lower bevel',(.56,-.055,2.40),(.33,-.055,2.15),.038,edge,weapon)
        segment('R5c cyan axe inlay',(.10,-.055,2.54),(.39,-.055,2.60),.022,cyan,weapon)
    elif name=='stone_colossus':
        body=bpy.data.objects['Massive block torso'];stone=recolor('Light granite','8996A5')
        edge=recolor('Fresh chipped edges','B8C3CD');joint=recolor('Stone joints','596778');fire=bpy.data.materials['Pulsing molten fissures']
        stretch('Chest monolith',(1.06,1.0,1.0));stretch('Hammer fist',(1.14,1.03,1.10))
        for sign in (-1,1):
            plate('R5c fractured breast slab',[(sign*.08,-.40,1.91),(sign*.57,-.40,1.90),(sign*.63,-.40,1.60),(sign*.39,-.40,1.50),(sign*.13,-.40,1.67)],stone,body,.08)
            segment('R5c branching chest fault',(sign*.11,-.455,1.90),(sign*.17,-.455,1.70),.022,fire,body)
            segment('R5c branching chest fault',(sign*.17,-.455,1.70),(sign*.39,-.455,1.58),.020,fire,body)
            segment('R5c chest branch',(sign*.17,-.455,1.70),(sign*.47,-.455,1.78),.014,fire,body)
            shard('R5c broken crown stone',(sign*.21,.03,2.29),(sign*.26,.07,2.59),.13,stone,body)
        for arm in [o for o in s.objects if o.type=='EMPTY' and o.name.startswith('Hammer shoulder')]:
            sign=-1 if arm.location.x<0 else 1
            cube('R5c shoulder cap',(sign*.025,0,.26),(.36,.41,.085),stone,arm,.04)
            for j in range(3):
                shard('R5c crag shoulder',(sign*(-.15+j*.16),.04,.30),(sign*(-.20+j*.22),.09,.63+(j%2)*.12),.13,edge if j==1 else stone,arm)
                cube('R5c knuckle block',(-.17+j*.17,-.385,-.69),(.065,.065,.13),edge,arm,.025)
            segment('R5c shoulder fault',(sign*-.20,-.425,.27),(sign*.21,-.425,.18),.018,fire,arm)
        cube('R5c central keystone',(0,-.41,1.31),(.13,.07,.14),joint,body,.03)
        shard('R5c molten keystone',(0,-.49,1.23),(0,-.49,1.45),.052,fire,body)
    s['r5c_refined']=True
    s['r5c_note']='Original animated hierarchy refined in Blender; fixed 35 degree camera and complete normal/emission passes.'
