"""Refine the saved Claude mini-boss meshes, preserving their keyed hierarchy."""
from boss_pipeline import *

def refine(name):
    s=bpy.context.scene
    if s.get('r5b_refined'):return
    def objects(prefix):
        return [o for o in s.objects if o.type=='MESH' and (o.name==prefix or o.name.startswith(prefix+'.'))]
    def stretch(prefix,xyz):
        for o in objects(prefix):
            for v in o.data.vertices:
                v.co=Vector(tuple(v.co[i]*xyz[i] for i in range(3)))
    def recolor(name,hexcolor):
        m=bpy.data.materials[name];rgb=[int(hexcolor[i:i+2],16)/255 for i in (0,2,4)]
        rgb=[v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
        p=m.node_tree.nodes.get('Principled BSDF')
        p.inputs['Base Color'].default_value=(*rgb,1);p.inputs['Emission Color'].default_value=(*rgb,1)
        return m
    def ribbon(label,points,width,mat,parent):
        # A faceted cloth/leaf surface modeled in Blender; pointed trailing end.
        vertices=[]
        for i,p in enumerate(points):
            w=width*(1-i/(len(points)-1)*.95)
            vertices.extend([(p[0]-w,p[1],p[2]),(p[0]+w,p[1],p[2])])
        faces=[(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(points)-1)]
        mesh=bpy.data.meshes.new(label);mesh.from_pydata(vertices,[],faces);mesh.update()
        o=bpy.data.objects.new(label,mesh);s.collection.objects.link(o);o.parent=parent;o.data.materials.append(mat)
        solid=o.modifiers.new('Cloth thickness','SOLIDIFY');solid.thickness=.018
        return o
    if name=='ash_lord':
        body=bpy.data.objects['Ash lord'];head=bpy.data.objects['Head'];cape=bpy.data.objects['Tattered cape']
        rag=recolor('Charred cape','51465F');bone=recolor('Pale cage bone','D6C9B4')
        coal=material('R5b charcoal folds','34303F');ember=bpy.data.materials['Ember heart']
        stretch('Skull',(1.18,1.12,1.12));stretch('Ember eye',(1.25,1.1,1.1))
        stretch('Ember heart',(1.25,1.15,1.2))
        for o in objects('Ember heart'):o.location.y=-.155
        for o in objects('Ragged strip'):
            for v in o.data.vertices:
                v.co.x*=1.22 if v.co.z>0 else .48
        for sign in (-1,1):
            sphere('R5b charred mantle',(sign*.32,.055,1.91),(.30,.19,.14),rag,body)
            ribbon('R5b outer torn cloak',[(sign*.35,.16,1.95),(sign*.58,.24,1.45),(sign*.62,.32,.76),(sign*.49,.25,.24)],.16,rag,body)
            ribbon('R5b cloak raised fold',[(sign*.30,.05,1.89),(sign*.46,.13,1.4),(sign*.48,.20,.7)],.035,coal,body)
            sphere('R5b hood rim',(sign*.18,.035,.02),(.10,.16,.25),rag,head)
            segment('R5b brow',(sign*.035,-.16,.11),(sign*.16,-.15,.10),.028,coal,head)
            for j in range(3):
                cone('R5b mantle ember',(sign*(.35+j*.10),-.04,1.94+j*.035),.035,0,.15,ember,body).rotation_euler.y=sign*.65
        sphere('R5b hood back',(0,.105,.15),(.23,.12,.20),rag,head)
        for j in range(3):
            segment('R5b jaw teeth',((j-1)*.055,-.172,-.10),((j-1)*.055,-.185,-.17),.017,bone,head)
    elif name=='bramble_queen':
        body=bpy.data.objects['Slender queen'];head=bpy.data.objects['Head']
        deep=recolor('Black green gown','36543F');leaf=recolor('Bramble green','7CA779')
        thorn=bpy.data.materials['Pale thorn crown'];bark=bpy.data.materials['Root bark'];glow=bpy.data.materials['Poison green eyes and berries']
        stretch('Pale face',(1.18,1.1,1.15));stretch('Poison eye',(1.18,1.1,1.2))
        stretch('Crown thorn',(1.22,1.22,1.12));stretch('Thorn collar',(1.15,1.1,1.3))
        stretch('Root',(1.16,1.16,1.05))
        for sign in (-1,1):
            for j in range(3):
                x=sign*(.20+j*.105)
                ribbon('R5b layered thorn mantle',[(x,.01,1.94),(x+sign*.12,-.08,1.77),(x+sign*.14,-.10,1.47+j*.09)],.12,deep if j%2 else leaf,body)
            for j in range(3):
                x=sign*(.13+j*.12);z=.18+j*.07
                segment('R5b crown branch',(sign*.14,.04,.16),(x,.03,z+.21),.025,bark,head)
                cone('R5b crown antler',(x,.03,z+.34),.045,0,.30+.10*j,thorn,head).rotation_euler.y=sign*.3
            ribbon('R5b gown leaf',[(sign*.17,-.19,1.56),(sign*.28,-.29,1.05),(sign*.38,-.35,.26)],.11,leaf,body)
            for j in range(3):
                sphere('R5b luminous gown seed',(sign*(.20+j*.065),-.26-j*.045,1.35-j*.31),(.033,.028,.055),glow,body)
        segment('R5b breast vine',(0,-.185,1.45),(0,-.19,1.88),.03,bark,body)
    elif name=='brood_mother':
        body=bpy.data.objects['Inverted drop body'];head=bpy.data.objects['Head'];abd=bpy.data.objects['Abdomen pivot']
        shell=recolor('Olive chitin','8FAD64');dark=recolor('Dark joints','46503B')
        belly=recolor('Translucent yellow green abdomen','B9CF65');p=belly.node_tree.nodes.get('Principled BSDF')
        p.inputs['Transmission Weight'].default_value=.22;p.inputs['Roughness'].default_value=.28
        p.inputs['Subsurface Weight'].default_value=.12
        core=bpy.data.materials['Pulsing brood light'];wing=bpy.data.materials['Pale veined wings']
        wing['rainfall_emissive']=False
        stretch('Insect head',(1.12,1.12,1.12));stretch('Amber compound eye',(1.12,1.1,1.12))
        stretch('Femur',(1.28,1.28,1));stretch('Tibia',(1.22,1.22,1));stretch('Tarsus',(1.22,1.22,1))
        # Visible luminous brood nodules and armoured lateral seams articulate the abdomen.
        for j in range(4):
            y=.21+j*.29
            for sign in (-1,1):
                segment('R5b carapace seam',(sign*.31,y,.68),(sign*.61,y,.40),.035,shell,abd)
                sphere('R5b brood vesicle',(sign*.56,y,.29),(.12,.13,.16),core,abd)
        for w in [o for o in s.objects if o.type=='EMPTY' and (o.name=='Wing' or o.name.startswith('Wing.'))]:
            sign=-1 if w.location.x<0 else 1
            for j in range(3):
                segment('R5b wing vein',(sign*.10,.11,.08),(sign*(.65+.09*j),-.01+j*.13,.087),.012,dark,w)
            segment('R5b wing leading edge',(sign*.04,.01,.08),(sign*.97,.02,.08),.018,shell,w)
        for sign in (-1,1):
            cone('R5b mandible fang',(sign*.16,-.37,-.16),.065,0,.24,dark,head).rotation_euler.x=1.0
            sphere('R5b royal thorax plate',(sign*.21,-.14,1.36),(.23,.30,.12),shell,body)
    s['r5b_refined']=True
    s['r5b_note']='Existing animated meshes refined; fixed 35 degree camera; full diffuse/normal/emission passes.'
