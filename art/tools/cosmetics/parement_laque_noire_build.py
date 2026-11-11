"""Build the Laque noire UI skin from the established U1 UI geometry."""
import sys, json, shutil, hashlib, os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/ui'))
import u1_build as ui
sys.path.insert(0,str(ROOT/'art/tools/cel'))
import cel_style as cel
OUT=ROOT/'game/assets/sprites/ui/parements/laque_noire'
OUT.mkdir(parents=True,exist_ok=True)
ui.D=OUT

def set_material(m, color, metal=.78, rough=.28):
    p=m.node_tree.nodes.get('Principled BSDF')
    from ui_kit import rgba
    p.inputs['Base Color'].default_value=rgba(color)
    p.inputs['Metallic'].default_value=metal
    p.inputs['Roughness'].default_value=rough

def palette():
    global bronze,edge,iron,leather,ember,blue,blood
    bronze=ui.worn('Black lacquer','#1B1920','#26232C',.18,.22)
    edge=ui.worn('Gold inlay','#C9A04A','#F0D58A',.68,.22)
    iron=ui.worn('Pearl edge','#C9C2B5','#E5E0D7',.18,.30)
    leather=ui.worn('Black lacquer inset','#1B1920','#26232C',.08,.42)
    ember=ui.worn('Danger dark red','#7A2A22','#9B4A40',.1,.5)
    blue=bronze
    blood=bronze
    ui.iron,ui.bronze,ui.edge,ui.leather,ui.ember,ui.blue,ui.blood=iron,bronze,edge,leather,ember,blue,blood

def inscription(body,size):
    import bpy
    curve=bpy.data.curves.new('engraved inscription','FONT');curve.body=body;curve.size=size
    curve.align_x='CENTER';curve.align_y='CENTER';curve.extrude=.08;curve.bevel_depth=.03
    obj=bpy.data.objects.new('engraved '+body,curve);bpy.context.scene.collection.objects.link(obj)
    obj.location=(0,-9,0);obj.rotation_euler=(1.5707963,0,0);obj.data.materials.append(bronze)

def main():
    import bpy
    if os.environ.get("LAQUE_PREVIEW_ONLY") != "1":
        palette()
        configure=cel.install('ui',normals=False)
        original_begin=ui.begin
        def begin(name,w,h):
            scene=original_begin(name,w,h)
            palette()
            return scene
        ui.begin=begin
        def render(path):
            scene=bpy.context.scene
            scene.render.resolution_percentage=50
            configure(str(path))
            scene.render.filepath=str(path)
            bpy.ops.render.render(write_still=True)
        ui.render_to=render
        # Keep U1's established profiles, dimensions, and nine-slice margins.
        def gen(name,w,h,build,margins=None,emission=False):
            ui.make(name,w,h,build,margins,emission)
        for name,w,h,m in [('panel_9slice',384,384,28),('panel_small_9slice',192,192,24),('header_banner',640,96,24),('timer_plate',256,80,22)]:
            def plate(name=name,w=w,h=h):
                ui.panel(w,h)
                if name=='header_banner':inscription('LAQUE NOIRE',19)
                elif name=='timer_plate':inscription('GALA NOIR',16)
            gen(name,w,h,plate,[m]*4 if name!='header_banner' else [28,20,28,20])
        gen('divider',512,24,lambda:(ui.line([(-250,0),(-22,0)],bronze,1.4),ui.line([(22,0),(250,0)],bronze,1.4),ui.diamond(0,0,8,edge),ui.diamond(-15,0,3,bronze),ui.diamond(15,0,3,bronze)))
        for state in ['normal','hover','pressed','disabled','danger','primary','primary_hover','primary_pressed']:
            def button(state=state):
                ui.panel(320,96,ember if state=='danger' else None,'pressed' in state)
                # Gold perimeter with a pearl glint.
                ui.frame(300,78,2,edge,-7,c=4)
                for x in (-145,145):
                    for z in (-34,34):
                        ui.disk(x,z,3,bronze,-10);ui.disk(x,z,1,edge,-11)
                if state=='disabled':
                    for m in (bronze,edge):
                        for n in m.node_tree.nodes:
                            if n.type=='VALTORGB':
                                for e in n.color_ramp.elements:e.color=(.18,.15,.12,1)
                if state in ('primary_hover','primary_pressed'):ui.frame(282,58,1,bronze,-9,c=3)
                ui.diamond(143,34,5,ui.worn('Pearl inlay','#C9C2B5','#E5E0D7',.18,.24),-10)
            gen('button_'+state,320,96,button,[28,24,28,24],state in ('hover','danger','primary','primary_hover','primary_pressed'))
        for kind,w,h in [('hp',512,48),('xp',512,28),('boss',1024,64)]:
            def bar(w=w,h=h,kind=kind):
                ui.frame(w-6,h-6,4,iron,c=6);ui.frame(w-12,h-12,1.4,bronze,-6,c=3)
                ui.frame(w-17,h-17,.7,edge,-8,c=5)
                for sx in (-1,1):
                    ui.disk(sx*(w/2-11),0,2.4,bronze,-10)
                    if kind=='boss':ui.diamond(sx*(w/2-22),0,7,edge)
            gen('bar_frame_'+kind,w,h,bar,[32 if kind=='boss' else 18,10,32 if kind=='boss' else 18,10])
            shutil.copyfile(ROOT/'game/assets/sprites/ui/da'/('bar_frame_'+kind+'.json'),OUT/('bar_frame_'+kind+'.json'))
        # Spell medallions use U2's established camera, medal geometry and states.
        import u2_build as u2
        for state in ('normal','pressed','cooldown'):
            u2.scene('bell_'+state)
            u2.iron=ui.worn('Black lacquer','#1B1920','#26232C',.18,.24)
            u2.bronze=ui.worn('Black lacquer','#17151A','#242127',.18,.22)
            u2.edge=ui.worn('Gold inlay','#C9A04A','#F0D58A',.68,.22)
            u2.bone=ui.worn('Pearl inlay','#C9C2B5','#E5E0D7',.18,.24)
            u2.ember=u2.bronze
            u2.medal(state)
            u2.front_camera(2.45,2.45,320,320)
            bpy.context.scene.render.resolution_percentage=50
            bpy.context.scene.render.filepath=str(OUT/('spell_frame'+('' if state=='normal' else '_'+state)+'.png'))
            bpy.ops.render.render(write_still=True)
    # Composite the requested preview in Blender from the finished raster assets.
    scene=bpy.data.scenes.new('Laque noire preview')
    bpy.context.window.scene=scene
    scene.render.engine='BLENDER_EEVEE'
    scene.render.resolution_x=256;scene.render.resolution_y=256;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
    scene.world=bpy.data.worlds.new('preview dark world');scene.world.use_nodes=True
    bg=scene.world.node_tree.nodes.get('Background');bg.inputs['Color'].default_value=(.00518,.00478,.00605,1);bg.inputs['Strength'].default_value=1
    # Give transparent sprite texels a real backdrop in Eevee; the world alone
    # can resolve them to black in the mixed transparent/emission shader.
    mesh=bpy.data.meshes.new('preview background mesh')
    mesh.from_pydata([(-128,10,-128),(128,10,-128),(128,10,128),(-128,10,128)],[],[(0,1,2,3)])
    back=bpy.data.objects.new('preview background',mesh);scene.collection.objects.link(back)
    mat=bpy.data.materials.new('preview background material');mat.diffuse_color=(.00518,.00478,.00605,1);mat.use_nodes=True
    nodes=mat.node_tree.nodes;nodes.clear();out=nodes.new('ShaderNodeOutputMaterial');em=nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=(.00518,.00478,.00605,1);mat.node_tree.links.new(em.outputs[0],out.inputs['Surface']);mesh.materials.append(mat)
    scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.view_settings.exposure=0;scene.view_settings.gamma=1
    def sprite(path,x,z,w,h):
        mesh=bpy.data.meshes.new('preview plane')
        mesh.from_pydata([(-w/2,0,-h/2),(w/2,0,-h/2),(w/2,0,h/2),(-w/2,0,h/2)],[],[(0,1,2,3)])
        ob=bpy.data.objects.new('preview '+path.stem,mesh);scene.collection.objects.link(ob);ob.location.x=x;ob.location.z=z
        uv=mesh.uv_layers.new()
        for poly in mesh.polygons:
            for li,uvco in zip(poly.loop_indices,[(0,0),(1,0),(1,1),(0,1)]):uv.data[li].uv=uvco
        mat=bpy.data.materials.new('preview raster');mat.use_nodes=True
        nodes=mat.node_tree.nodes;nodes.clear();out=nodes.new('ShaderNodeOutputMaterial');tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(path),check_existing=True)
        em=nodes.new('ShaderNodeEmission');mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MIX';mix.inputs[1].default_value=(.00518,.00478,.00605,1)
        mat.node_tree.links.new(tex.outputs['Alpha'],mix.inputs[0]);mat.node_tree.links.new(tex.outputs['Color'],mix.inputs[2]);mat.node_tree.links.new(mix.outputs['Color'],em.inputs['Color']);mat.node_tree.links.new(em.outputs[0],out.inputs['Surface'])
        ob.data.materials.append(mat)
    sprite(OUT/'bar_frame_hp.png',0,46,176,18)
    sprite(ROOT/'game/assets/sprites/ui/da/bar_fill_hp.png',-60,46,35.2,11)
    sprite(OUT/'button_primary.png',0,-57,150,46)
    sprite(OUT/'spell_frame.png',0,0,66,66)
    camdata=bpy.data.cameras.new('preview camera');cam=bpy.data.objects.new('preview camera',camdata);scene.collection.objects.link(cam)
    cam.location=(0,-300,0);cam.rotation_euler=(1.5707963,0,0);camdata.type='ORTHO';camdata.ortho_scale=256;scene.camera=cam
    scene.render.filepath=str(ROOT/'game/assets/sprites/cosmetics/previews/laque_noire.png')
    Path(scene.render.filepath).parent.mkdir(parents=True,exist_ok=True);bpy.ops.render.render(write_still=True)
    # Ship matching atlas metadata verbatim wherever the existing set defines it.
    da=ROOT/'game/assets/sprites/ui/da'
    for p in OUT.glob('*.png'):
        source=da/(p.stem+'.json')
        if source.exists():shutil.copyfile(source,OUT/source.name)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/cel/cosmetics/parement_laque_noire.blend'))
    for temp in OUT.glob('*_e__Image.png'):
        temp.unlink()
    print('PASS generated 19 diffuse assets',flush=True)

if __name__=='__main__':main()
