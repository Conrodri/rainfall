"""C8b chest correction; reuses the C8 renderer, rig, materials and output contract."""
import sys,json,math,hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE))
import c8_build as c
from mathutils import Vector

def chest(root,name,pose,M):
    small='small' in name; legend='legendary' in name
    w,d,h=(.83,.62,.43) if small else ((1.14,.70,.46) if legend else (1.08,.76,.50))
    wood=c.mat('Weathered oak','49372A',0,.76)
    bronze=M['bronze']; gold=c.mat('Worn gilding','A88C52',.72,.52)
    rim=M['iron'] if small else gold if legend else bronze
    panel=M['stone'] if legend else wood
    glow=c.mat('Interior ember' if small else 'Interior gold' if legend else 'Interior water','CE7139' if small else 'E9BD59' if legend else '58AEBA',.05,.65,.55 if small else .85)
    box=c.box; C=c.C
    box('Bottom tray',(0,0,.08),(w+.04,d+.04,.12),M['iron'],root)
    box('Cavity floor',(0,0,.145),(w-.08,d-.08,.045),M['dark'],root)
    # Separate walls; there is no slab at the top of the cavity.
    for y in (-d/2,d/2):
        for i in range(6):
            box('Wall stave',((i-2.5)*w/6,y,(h+.13)/2),(w/6-.009,.065,h-.13),panel,root)
        box('Thick rim front back',(0,y,h),(w+.035,.078,.055),rim,root)
    for x in (-w/2,w/2):
        box('Side wall',(x,0,(h+.13)/2),(.065,d-.06,h-.13),panel,root)
        box('Thick rim sides',(x,0,h),(.078,d+.035,.055),rim,root)
    for x in (-w*.39,w*.39):
        for y in (-d/2-.025,d/2+.025):
            box('Body strap',(x,y,(h+.10)/2),(.055 if small else .075,.035,h-.04),rim,root)
            for z in (.17,h-.08):C.sphere('Body rivet',(x,y*1.02,z),(.019,.012,.019),M['iron'] if small else gold if legend else M['brass'],root)
    # Every lid component is parented to this single rear hinge in both poses.
    hinge=C.empty('Lid hinge',(0,d/2,h+.035),root)
    # Bevelled arch with matching lower skin and bronze/iron bands wrapping underneath.
    for j in range(8):
        y=-d+(j+.5)*d/8
        arch=.105*math.sin(math.pi*(j+.5)/8)
        box('Lid oak' if not legend else 'Lid carved stone',(0,y,.065+arch),(w,d/8+.004,.115),panel,hinge)
        for x in (-w*.39,w*.39):
            for zz in (.130+arch,-.002+arch):
                box('Lid continuous strap',(x,y,zz),(.060 if small else .085,d/8+.007,.025),rim,hinge)
            if j in (0,3,6):
                for zz in (.152+arch,-.025+arch):C.sphere('Lid strap rivet',(x,y,zz),(.018,)*3,M['iron'] if small else gold if legend else M['brass'],hinge)
    for y in (-d,0):
        box('Lid end profile',(0,y,.067),(w+.025,.045,.15),rim,hinge)
        for x in (-w*.39,w*.39):box('Lid strap return',(x,y,.065),(.085,.055,.17),rim,hinge)
    for x in (-w/2,w/2):
        box('Lid side profile',(x,-d/2,.09),(.045,d,.12),rim,hinge)
    for x in (-w*.29,w*.29):
        axle=c.cyl('Rear hinge barrel',(x,d/2+.025,h+.035),.035,.16,rim,root)
        axle.rotation_euler.y=math.pi/2
    if small:
        box('Simple iron latch',(0,-d/2-.046,h-.035),(.095,.04,.15),M['iron'],root)
    else:
        shackle=C.sphere('Padlock shackle',(0,-d/2-.052,h-.075),(.065,.022,.084),rim,root)
        box('Padlock',(0,-d/2-.07,h-.13),(.15,.055,.14),gold if legend else M['iron'],root)
        box('Keyhole',(0,-d/2-.104,h-.12),(.021,.008,.043),M['dark'],root)
        box('Lid lock tongue',(0,-d-.023,.018),(.085,.04,.18),rim,hinge)
    # Low, inset emissive source leaves the dark interior and wall thickness readable.
    C.sphere('Soft interior light',(0,0,.166),(w*.24,d*.19,.008),glow,root)
    if legend:
        box('Lid gold emissive seal',(0,-d/2,.239),(.055,.055,.012),glow,hinge)
        box('Lid gold emissive seal underside',(0,-d/2,.094),(.055,.055,.012),glow,hinge)
        for x in (-w*.24,w*.24):
            for z in (.25,.34,.43):
                rune=box('Engraved gold stroke',(x,-d/2-.036,z),(.09,.009,.014),gold,root)
                rune.rotation_euler.y=.48 if z==.34 else -.48
            box('Gold seal',(x,-d/2-.047,.225),(.035,.012,.045),glow,root)
        for x in (-w*.20,w*.20):
            for y in (-d*.30,-d*.62):
                box('Lid engraved inset',(x,y,.158),(.095,.025,.012),gold,hinge)
                box('Lid inset underside',(x,y,-.01),(.095,.025,.012),gold,hinge)
    hinge.rotation_euler.x=math.radians(-105) if pose=='open' else 0
    root['c8b_hollow']=True;root['c8b_lid_angle']=105 if pose=='open' else 0
    bpy=c.bpy;bpy.context.view_layer.update()
    # Audit local geometry: pose must never alter lid construction.
    sig=[]
    for ob in sorted(hinge.children_recursive,key=lambda ob:ob.name):
        if ob.type=='MESH':sig.append([ob.name.split('.')[0],list(ob.location),list(ob.scale),[m.name.split('.')[0] for m in ob.data.materials]])
    audit.setdefault(name,[]).append({'pose':pose,'lid_sha256':hashlib.sha256(json.dumps(sig,sort_keys=True).encode()).hexdigest(),'lid_parts':len(sig)})

audit={}
c.chest=chest
c.INV=HERE/'_c8b_inventory.json'
c.old_pivots=lambda d:d
c.build()
(HERE/'_c8b_geometry.json').write_text(json.dumps(audit,indent=2))
print('PASS C8b chest build')


