"""G10 material-only overrides; original geometry, cameras and timelines."""
def apply():
    import bpy
    import cel_style as cel
    cel.TONE_SCALES=(1.134,2.016,2.97)
    def linear(hexcode):
        a=[int(hexcode[i:i+2],16)/255 for i in (0,2,4)]
        return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in a)+(1,)
    for m in bpy.data.materials:
        if not m.use_nodes: continue
        bs=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
        if bs is None: continue
        glow=bs.inputs['Emission Strength'].default_value
        luminous=glow>.01 and (m.get('rainfall_emissive') or not any(n.type=='VALTORGB' for n in m.node_tree.nodes))
        name=m.name.lower()
        color='C27BFF' if luminous else '3A3634' if any(t in name for t in ('blade','claw','talon','tooth','teeth','mandible','cutting edge','fang','keratin')) else '8A8478' if any(t in name for t in ('fur','lichen','stone','body','grey','gray')) else '7A5D45'
        rgb=linear(color)
        # +10% chroma around luminance; brighter body bases retain the cel steps.
        y=sum(v*w for v,w in zip(rgb[:3],(.2126,.7152,.0722)))
        rgb=tuple(max(0,min(1,y+(v-y)*1.1)) for v in rgb[:3])+(1,)
        if not luminous and color!='3A3634':
            gain=.58/max(.001,sum(c*w for c,w in zip(rgb[:3],(.2126,.7152,.0722))))
            rgb=tuple(min(.72,v*gain) for v in rgb[:3])+(1,)
        m.node_tree.nodes.clear()
        bs=m.node_tree.nodes.new('ShaderNodeBsdfPrincipled'); out=m.node_tree.nodes.new('ShaderNodeOutputMaterial')
        m.node_tree.links.new(bs.outputs['BSDF'],out.inputs['Surface'])
        bs.inputs['Base Color'].default_value=rgb
        bs.inputs['Roughness'].default_value=.9
        if luminous:
            m['rainfall_emissive']=True
            bs.inputs['Emission Color'].default_value=linear('C27BFF')
            bs.inputs['Emission Strength'].default_value=glow
