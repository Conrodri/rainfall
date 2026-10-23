from pathlib import Path
p=Path(__file__).with_name('m1_build.py')
s=p.read_text()
def replace(a,b):
    global s
    assert a in s,a[:80]
    s=s.replace(a,b)
replace('import sys, math, json','import sys, math, json, random')
replace("(.66,.11,.075,.015),(.74,.105,.076,0),(.86,.14,.09,0),(.95,.16,.085,.015),(.99,.10,.065,0)","(.66,.067,.044,.015),(.74,.043,.031,0),(.86,.075,.048,0),(.95,.102,.043,.015),(.99,.048,.032,0)")
replace("    tailored('Drenched fitted diamond doublet'","    coat=tailored('Drenched fitted diamond doublet'")
replace("    for side in (-1,1):\n        plate('Split ragged doublet tail'",'''    # Open front tears reveal a hollow wooden rib cage, never a solid barrel.
    import bmesh
    bm=bmesh.new();bm.from_mesh(coat.data)
    torn=[f for f in bm.faces if f.calc_center_median().y<-.015 and .76<f.calc_center_median().z<.94 and abs(f.calc_center_median().x)<.050]
    bmesh.ops.delete(bm,geom=torn,context='FACES');bm.to_mesh(coat.data);bm.free()
    rod('Exposed narrow wooden spine',[(0,.025,.70),(0,.025,.98)],.012,m['wood'],body)
    for z,r in [(.79,.048),(.83,.062),(.87,.073),(.91,.083)]:
        for side in (-1,1):
            rod('Exposed bent rib lath',[(side*.010,.024,z+.008),(side*r,.005,z),(side*r*.80,-.039,z-.015),(side*.014,-.043,z-.024)],.006,m['peg'],body)
    for side in (-1,1):
        rod('Bony wooden clavicle',[(side*.012,-.023,.972),(side*.065,-.030,.96),(side*.112,.005,.94)],.009,m['peg'],body)
        plate('Sodden torn coat lapel',[(side*.051,.935),(side*.070,.91),(side*.044,.83),(side*.036,.865)],-.052,.005,m['cloth'],body,.001)
    for side in (-1,1):
        plate('Split ragged doublet tail' ''')
replace("(side*.13,.72),(side*.16,.57),(side*.09,.61)","(side*.075,.72),(side*.095,.57),(side*.055,.61)")
replace("[(-.062,.80),(.06,.91)]","[(-.042,.735),(.057,.945)]")
replace("x-.032,z-.035","x-.018,z-.021");replace("x+.03,z-.032","x+.019,z-.019");replace("x+.026,z+.032","x+.016,z+.018");replace("x-.028,z+.024","x-.016,z+.014")
replace("-.094,.006,m['patch']","-.047,.004,m['patch']")
replace("xx=x-.025+i*.016","xx=x-.014+i*.009")
replace("(xx,-.102,z-.038),(xx+.004,-.103,z-.026)","(xx,-.053,z-.022),(xx+.003,-.054,z-.014)")
replace("[(.01,-.083,.70),(-.01,-.10,.80),(.008,-.094,.91),(0,-.07,.98)]","[(.01,-.04,.67),(-.01,-.036,.71),(.008,-.034,.75)]")
replace("for z in (.75,.84,.93):bead","for z in (.68,.72,.755):bead")
replace("(0,-.105,z)","(0,-.041,z)")
replace("(.11,.074,.08)","(.064,.041,.065)")
replace("[(0,0,.98),(0,0,1.10)],.028","[(0,0,.96),(0,0,1.10)],.017")
replace("rad=.145 if j%2==0 else .11","rad=.094 if j%2==0 else .063")
replace("1.063),(rad*math.cos(t),rad*math.sin(t),1.026+.014*(j%2))","1.013),(rad*math.cos(t),rad*math.sin(t),.980+.012*(j%2))")
replace("vs=[];rows=23;cols=19","vs=[];rows=81;cols=65")
replace("    for side in (-1,1):\n        bead('Recessed empty orbital cavity'",'''    # Vertex pigment follows the porcelain surface: ragged brush edges and rain runs.
    paint=m['porcelain'].copy();paint.name='Hand painted cracked chalk, charcoal and blood red'
    face.data.materials[0]=paint
    attr=face.data.color_attributes.new(name='Rain pigment',type='FLOAT_COLOR',domain='POINT')
    for v in face.data.vertices:
        x,y,z=v.co;grain=math.sin(x*1870+math.sin(z*953))*math.sin(z*1531+x*497)
        c=(.79,.76,.69,1)
        orbit=min(((x-side*.040)/(.032+grain*.002))**2+((z-.035)/.027)**2 for side in (-1,1))
        drip=any(abs(x-(a+.003*math.sin(z*96+i)))<w*(.85+.2*grain) and low<z<.032 for i,(a,w,low) in enumerate([(-.058,.004,-.041),(-.034,.005,-.060),(.030,.004,-.035),(.055,.003,-.059)]))
        if orbit<1.0 or drip:c=(.009,.012,.011,1)
        smile=-.062+.037*(abs(x)/.078)**1.7
        if abs(x)<.080 and abs(z-smile)<.009+grain*.004:c=(.29+.055*grain,.012,.018,1)
        if any(abs(x-a-.002*math.sin(z*120))<.0025 and lo<z<hi for a,lo,hi in [(-.067,-.058,-.025),(.069,-.061,-.026),(.024,-.093,-.058)]):c=(.25,.014,.021,1)
        if grain>.77:c=tuple(k*.62 for k in c[:3])+(1,)
        attr.data[v.index].color=c
    nodes=paint.node_tree.nodes;links=paint.node_tree.links;bs=nodes.get('Principled BSDF')
    pigment=nodes.new('ShaderNodeVertexColor');pigment.layer_name='Rain pigment'
    mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=.83
    links.new(bs.inputs['Base Color'].links[0].from_socket,mix.inputs[1]);links.new(pigment.outputs['Color'],mix.inputs[2]);links.new(mix.outputs[0],bs.inputs['Base Color'])
    black=worn('Rain dissolved charcoal brows','080B0A','242824',0,.79)
    for side in (-1,1):
        rod('Arched hand brushed eyebrow',[(side*.016,-.084,.074),(side*.033,-.082,.093),(side*.052,-.076,.096),(side*.073,-.065,.080)],.0045,black,head)
    red=worn('Flaking dried blood red nose pigment','350A0D','8B272B',0,.58)
    bead('Chipped red painted nose tip',(0,-.113,-.005),(.015,.013,.014),red,head)
    hair=worn('Rain soaked green flax hair','19271E','52654A',0,.64)
    for side in (-1,1):
        for j in range(9):
            x=side*(.070+j*.002)
            rod('Clinging wet green flax strand',[(x,.006+j*.006,.109),(side*(.096+j*.001),-.005+j*.007,.043),(side*(.091+j*.002),-.025+j*.008,-.027-j*.003)],.0025,hair,head)
    tailored('Small collapsed soaked fool cap',[(.111,.074,.057,.02),(.137,.063,.047,.025),(.150,.044,.031,.033),(.148,.010,.014,.051)],m['cloth'],head,16)
    for side in (-1,1):
        bead('Recessed empty orbital cavity' ''')
replace("m['porcelain'],head)\n    glass=","black,head)\n    glass=")
replace("Closed unsmiling mouth","Inset lip fissure under smeared smile")
replace("shoulder=(side*.17,.005,.94)","shoulder=(side*.115,.005,.94)")
replace("hippos=(side*.082,0,.65)","hippos=(side*.053,0,.65)")
replace(".047,.029,m['cloth']",".027,.016,m['cloth']");replace(".026,.019,m['wood']",".015,.011,m['wood']")
replace(".056,.033,m['cloth']",".032,.019,m['cloth']");replace(".026,.021,m['wood']",".015,.012,m['wood']")
replace("(side*.128,-.034,1.025)","(side*.087,-.034,.980)");replace("(side*.143,-.058,.67)","(side*.075,-.038,.67)")
replace("root['game_alpha']=.55","root['game_alpha']=.8")
replace("default_value=.07;ramp.inputs['To Max'].default_value=.47","default_value=.86;ramp.inputs['To Max'].default_value=1.0")
replace("    attachments=[]\n    for side,suffix",'''    # A dense chest behind the shredded mist gives a continuous readable silhouette.
    tailored('Dense upper spectral shroud',[(.24,.12,.075,.07),(.43,.18,.10,.07),(.61,.20,.10,.07),(.67,.13,.09,.07)],m['mist'],robe)
    bead('Black depth inside empty hood',(0,.045,.705),(.125,.075,.172),m['dark'],hood)
    rim=worn('Silver lit shroud edges','536F70','9FC8C0',.1,.68)
    for side in (-1,1):
        rod('Silver rain on hood edge',[(side*.111,-.057,.50),(side*.116,-.076,.65),(side*.085,-.047,.80),(side*.020,.018,.915)],.006,rim,hood)
    attachments=[]
    for side,suffix''')
# Three orthographic front/profile detail crops at exactly 3x the native density.
a=s.index("        for name,target in [('face'")
b=s.index("    print('PASS M1 '+actor",a)
s=s[:a]+'''        for name,target,profile in [('face',(0,-.02,1.16),False),('costume',(0,0,.63),False),('profile',(0,0,.63),True)]:
            from mathutils import Quaternion
            view=Vector((1,0,0)) if profile else Vector((0,-1,0))
            s.camera.rotation_euler=(-view).to_track_quat('-Z','Y').to_euler()
            s.camera.location=Vector(target)+view*12;s.camera.data.shift_y=0
            iso_rig.set_frame((384,384),'CREA');s.camera.data.ortho_scale=384/(iso_rig.R*3)
            iso_rig.render_frame(OUT/('detail_'+name+'.png'))
'''+s[b:]
replace("(1536,890)","(1536,1040)")
replace("round(a*.55)","round(a*.8)")
replace("enumerate(('face','costume'))","enumerate(('face','costume','profile'))")
replace("(390+i*360,580)","(180+i*440,630)")
replace("s.camera.location=(768,445,12)","s.camera.location=(768,520,12)")
replace("silver=material('Contact wire spectral silver','9FC8C0',.7,True)","silver=material('Contact caption spectral silver','9FC8C0',.15,True)\n    wire=material('Contact wire spectral silver alpha 0.35','9FC8C0',.12,True)\n    wire.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.35")
replace("890-a[1]","1040-a[1]");replace("890-(a[1]+b[1])/2","1040-(a[1]+b[1])/2");replace("890-b[1]","1040-b[1]")
replace(".45,silver,overlay)",".50,wire,overlay)")
replace("(x,890-y,0)","(x,1040-y,0)")
replace("M1 / MAROTTE + LE MONTREUR","M1b / MAROTTE + LE MONTREUR")
replace("text('Porcelain / glass / fracture - 3x',390,875,15);text('Wet motley / patches - 3x',750,875,15)","text('Rain clown pigment / glass / fracture - 3x',180,1025,15);text('Hollow rib cage / front - 3x',620,1025,15);text('Gaunt body / profile - 3x',1060,1025,15)")
replace("_m1_contact.png',optimize","_m1b_contact.png',optimize")
replace("'ghost_alpha':.55","'ghost_alpha':.8,'wire_alpha':.35,'wire_width_px':1")
p.write_text(s)
print('PASS M1b targeted recipe update')
