"""Small, idempotent silhouette edits to the existing Claude meshes."""
import bpy
from mathutils import Vector

def refine(name):
    s=bpy.context.scene
    if s.get('r5a_refined'):return
    def stretch(prefix,xyz):
        for o in s.objects:
            if o.type=='MESH' and (o.name==prefix or o.name.startswith(prefix+'.')):
                # Edit local vertices: preserve every keyed transform and parent.
                for v in o.data.vertices:
                    v.co=Vector((v.co.x*xyz[0],v.co.y*xyz[1],v.co.z*xyz[2]))
    if name=='swarm_tier1':
        stretch('Round silt body',(1.06,1.03,.94))
        stretch('Gelatinous drop tip',(.85,.85,1.20))
        stretch('Rounded toe',(1.10,1.18,1))
    elif name=='shooter_tier2':
        stretch('Pointed hood',(.91,.96,1.18))
        stretch('Red slit eye',(1.25,1.08,1.35))
        stretch('Long split tunic',(.94,1,1))
    elif name=='leaper_tier2':
        stretch('Powerful haunches',(1.16,1.12,1.09))
        stretch('Dorsal spine',(.90,.90,1.20))
        stretch('Red eye',(1.08,1.10,1.12))
        stretch('Rear thigh',(1.13,1.08,1.08))
    elif name=='brute_tier3':
        stretch('Huge shoulder',(1.12,1.06,1.10))
        stretch('Rust shoulder band',(1.12,1.06,1))
        stretch('Massive fist',(1.10,1.06,1.06))
        stretch('Heavy brow',(1.16,1.10,1.06))
        stretch('Red slit eye',(1.12,1.06,1.20))
    s['r5a_refined']=True
    s['r5a_note']='Existing meshes refined; 35 degree camera; larger heads; original animations.'
