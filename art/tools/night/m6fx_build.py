"""M6FX: background Eevee only; source mini libraries are read only. No normal exports.
Run Blender --background --python this_file, then system Python this_file --finish.
Ground sheets: 64 px/u, centre pivot; obstacles: MAP rig, bottom centre.
"""
import sys, math, random, json, re, hashlib
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT/'art/tools/iso'), str(ROOT/'art/tools/cel'), str(ROOT/'art/tools/monsters')]
OUT = ROOT/'game/assets/sprites'
WORK = ROOT/'art/blender/fx/m6fx_frames'
SPECS = [('ice_block','bosses/mini/frost_bear',128,128,4),
         ('rock','bosses/mini/stone_colossus',128,128,4),
         ('zone_water','fx/minis',256,256,8),('zone_water_shock','fx/minis',256,256,8),
         ('zone_bubbles','fx/minis',256,256,8),('chain_link','fx/minis',64,32,1),('chain_break','fx/minis',64,32,1)]

def render_all():
    import bpy
    from mathutils import Vector
    import iso_rig as iso
    import cel_style as cel
    from ash_lord_build import mesh, rod
    from PIL import Image
    bpy.context.preferences.filepaths.save_version=0
    only=sys.argv[sys.argv.index('--only')+1] if '--only' in sys.argv else None
    source_materials = {}
    # Append only the original materials; never open/save the source mini scene.
    for mini in ('frost_bear','stone_colossus'):
        with bpy.data.libraries.load(str(ROOT/f'art/blender/monsters/{mini}.blend'), link=False) as (src,dst):
            dst.materials = [n for n in src.materials if any(t in n.lower() for t in ('glacial ice','fractured basalt','chipped wet stone'))]
        source_materials[mini] = list(dst.materials)
    def source(mini, needle):
        return next(m for m in source_materials[mini] if needle in m.name.lower())
    def mat(name, rgb, emission=0):
        return iso.material(name,rgb,roughness=.8,emission=emission)
    def clear():
        cel.uninstall()
        iso.create_rig('MAP',(128,128))
    def shard(name,loc,scale,material,seed):
        rng=random.Random(seed)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=loc)
        ob=bpy.context.object;ob.name=name
        for v in ob.data.vertices:
            v.co *= rng.uniform(.82,1.12)
        ob.scale=scale;ob.data.materials.append(material)
        bevel=ob.modifiers.new('Chipped arris','BEVEL');bevel.width=.018;bevel.segments=1
        return ob
    def output(name,i,size):
        p=WORK/name/f'{i:02d}.png';p.parent.mkdir(parents=True,exist_ok=True)
        iso.common.configure_passes(p)
        s=bpy.context.scene;s.render.filepath=str(p)
        bpy.ops.render.render(write_still=True)
        for suffix in ('','_e'):
            target=p.with_name(p.stem+suffix+'.png')
            if suffix:
                candidates=list(p.parent.glob(p.stem+suffix+'__*.png'))
                assert len(candidates)==1,(p,candidates)
                candidates[0].replace(target)
            with Image.open(target) as im:
                im.convert('RGBA').resize(size,Image.Resampling.LANCZOS).save(target,optimize=True)
        assert not list(p.parent.glob('*_n*.png'))
    def save(name):
        p=ROOT/f'art/blender/fx/m6fx_{name}.blend';p.parent.mkdir(parents=True,exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(p),check_existing=False)
    for name,mini in [('ice_block','frost_bear'),('rock','stone_colossus')]:
        if only and name!=only:continue
        for i in range(4):
            clear();s=bpy.context.scene
            up=s.camera.rotation_euler.to_matrix()@Vector((0,1,0))
            s.camera.location += up*.45
            body=source(mini,'glacial ice' if name=='ice_block' else 'fractured basalt')
            edge=mat('Frost along chipped arris',(.28,.35,.35)) if name=='ice_block' else source(mini,'chipped wet stone')
            recess=mat('Glacial grey fracture bed' if name=='ice_block' else 'Basalt fractured interior',(.07,.12,.13) if name=='ice_block' else (.045,.055,.05))
            accent=mat('Pale cyan fissure' if name=='ice_block' else 'Restrained ember fissure',(.23,.57,.62) if name=='ice_block' else (.85,.16,.025),.8)
            rng=random.Random(410+i)
            # Five irregular courses taper into a broken, asymmetrical stalactite / masonry crown.
            rings=[(0,.38),(.10,.46),(.43,.38),(.83,.26),(1.17,.035)] if name=='ice_block' else [(0,.35),(.14,.46),(.51,.47),(.86,.33),(.97,.20)]
            vertices=[];phase=i*.79
            for k,(z,r) in enumerate(rings):
                for j in range(7):
                    a=j*math.tau/7+phase+(0 if k<2 else .09*math.sin(k+i));rr=r*rng.uniform(.72,1.08)
                    zz=z+(rng.uniform(-.11,.10) if k>1 else 0)
                    vertices.append((rr*math.cos(a)+(.11*z*math.sin(i+1)),rr*math.sin(a)+.04*z*math.cos(i),max(0,zz)))
            faces=[tuple(range(6,-1,-1))]
            for k in range(4):
                for j in range(7):
                    a,b,c,d=k*7+j,k*7+(j+1)%7,(k+1)*7+(j+1)%7,(k+1)*7+j
                    if k>0 and (j+i)%3==0:faces.extend([(a,b,c),(a,c,d)])
                    else:faces.append((a,b,c,d))
            faces.append(tuple(range(28,35)))
            ob=mesh('Fallen fractured glacial monolith' if name=='ice_block' else 'Collapsed dressed basalt',vertices,faces,body,None,.012)
            ob.data.materials.append(edge)
            ob.data.materials.append(recess)
            for p in ob.data.polygons:
                if (p.index+i)%11==0:p.material_index=1
                elif (p.index+i)%5==0:p.material_index=2
            # Narrow fissures follow the actual exposed front-facing facet junctions.
            for j in (2,3,4):
                pts=[Vector(vertices[k*7+j])*Vector((1.012,1.012,1)) for k in range(1,4)]
                rod('Hairline cyan fracture' if name=='ice_block' else 'Ember in broken seam',pts,.008,accent,None)
                if name=='ice_block':
                    rod('Hoarfrost chipped ridge',[vertices[k*7+(j+1)%7] for k in range(1,4)],.013,edge,None)
            for j in range(5):
                a=j*2.4+i
                shard('Spalled base fragment',(.35*math.cos(a),.33*math.sin(a),.06),(.13,.09,.07),edge,40+i*7+j)
            # Layered broken masonry / frost splinters interrupt the broad facets.
            for j in range(4):
                a=-math.pi/4+j*.56+i*.37;z=.20+j*.16
                rr=.37 if j<2 else .27
                shard('Riven overlapping ice blade' if name=='ice_block' else 'Chipped masonry ledge',
                      (rr*math.cos(a),rr*math.sin(a),z),
                      (.12,.08,.18) if name=='ice_block' else (.15,.11,.10),
                      edge if j==0 else body,71+i*17+j)
            cel.install('prop',normals=False)
            if i==0:save(name)
            output(name,i,(128,128))
    def tube(name,points,r,material):
        if len(points)<2:return None
        return rod(name,points,r,material,None)
    def soft_disk(material,radius=1.88):
        # Geometry rings carry a transparent edge, without painting the texture.
        for k,(a,b,alpha) in enumerate([(0,.88,1),(.88,.94,.82),(.94,.975,.45),(.975,1,.12)]):
            m=material.copy();m.name=f'Soft shoreline {k}'
            nodes=m.node_tree.nodes;links=m.node_tree.links
            out=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
            shader=out.inputs['Surface'].links[0].from_socket
            mix=nodes.new('ShaderNodeMixShader');trans=nodes.new('ShaderNodeBsdfTransparent')
            mix.inputs[0].default_value=alpha;links.new(trans.outputs[0],mix.inputs[1]);links.new(shader,mix.inputs[2]);links.new(mix.outputs[0],out.inputs['Surface'])
            verts=[(radius*r*math.cos(j*math.tau/96),radius*r*math.sin(j*math.tau/96),0) for r in (a,b) for j in range(96)]
            faces=[(j,(j+1)%96,96+(j+1)%96,96+j) for j in range(96)]
            mesh('Feathered shoreline',verts,faces,m,None)
    for name in ('zone_water','zone_water_shock','zone_bubbles'):
        if only and name!=only:continue
        for i in range(8):
            clear();iso.create_rig('TOP',(256,256),reset=False)
            bpy.context.scene.camera.data.ortho_scale=4 # 64 px/u, not TOP's default 128.
            water=mat('Dark shallow cold water' if name!='zone_bubbles' else 'Silt green mud',(.026,.055,.067) if name!='zone_bubbles' else (.055,.069,.042))
            bubble=mat('Heavy marsh gas membrane',(.12,.15,.085))
            reflection=mat('Cold reflected sky',(.13,.23,.26),.55)
            cyan=mat('Cyan electrical contact',(.12,.72,.83),1.25)
            cel.install('vfx',normals=False)
            # Convert first: retain the transparency mixer when cel runs again.
            cel.toon_materials('vfx');soft_disk(water)
            t=i/8
            for j in range(10):
                a=j*2.399+.05*math.sin(t*math.tau+j)
                r=.35+(j%4)*.38
                points=[(r*math.cos(a+d),r*math.sin(a+d),.012) for d in [q*.035 for q in range(5+(j%4))]]
                tube('Broken cool surface ripple',points,.009,reflection)
            if name=='zone_water_shock':
                for j in range(4):
                    rng=random.Random(j+100*i)
                    a=j*math.tau/4+.17*math.sin(i)
                    pts=[]
                    for k in range(7):
                        r=.25+k*.23;aa=a+rng.uniform(-.17,.17)
                        pts.append((r*math.cos(aa),r*math.sin(aa),.026))
                    tube('Branching cyan electrical arc',pts,.014,cyan)
                    tube('Small fork',pts[3:5]+[(pts[4][0]+.18,pts[4][1]-.14,.026)],.008,cyan)
            if name=='zone_bubbles':
                for j in range(13):
                    phase=(t+j*.173)%1;r=.14+.17*phase
                    x=math.cos(j*2.399)*( .32+(j%4)*.34);y=math.sin(j*2.399)*(.32+(j%4)*.34)
                    if phase<.73:
                        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=(x,y,-.035))
                        ob=bpy.context.object;ob.name='Swelling mud bubble';ob.scale=(r,r,r*(.35+phase))
                        ob.data.materials.append(bubble)
                    else:
                        pts=[(x+r*math.cos(k*math.tau/24),y+r*math.sin(k*math.tau/24),.018) for k in range(25)]
                        tube('Ruptured bubble rim',pts,.018*(1-(phase-.73)/.27),bubble)
                        for k in range(3):
                            a=j+k*math.tau/3
                            shard('Burst droplet',(x+r*1.25*math.cos(a),y+r*1.25*math.sin(a),.06),(.025,.023,.035),bubble,j+k)
            if i==0:save(name)
            output(name,i,(256,256))
    for name in ('chain_link','chain_break'):
        if only and name!=only:continue
        clear();iso.create_rig('TOP',(64,32),reset=False);bpy.context.scene.camera.data.ortho_scale=1
        iron=mat('Dark worn chain steel',(.055,.065,.063));rust=mat('Rust scabs',(.15,.071,.037))
        glow=mat('Orange rust contact',(.72,.13,.025),.65)
        # Capsule length exactly one unit, repeated along local X; cut on the right for a breach.
        pts=[]
        for k in range(49):
            a=k*math.tau/48
            pts.append((.29*(1 if math.cos(a)>=0 else -1)+.16*math.cos(a),.145*math.sin(a),.04))
        if name=='chain_break':
            pts=pts[5:44]
        tube('Forged elongated rusted link',pts,.044,iron)
        for k in (8,19,32,40):
            tube('Worn rust patches',pts[max(0,k-1):min(len(pts),k+2)],.046,rust)
        tube('Glowing friction contact',[(x,y,z+.043) for x,y,z in pts[21:25]],.014,glow)
        if name=='chain_break':
            tube('Fresh hot broken end',[(x,y,z+.043) for x,y,z in pts[:2]],.018,glow)
        cel.install('prop',normals=False);save(name);output(name,0,(64,32))
    print('M6FX RENDER PASS',flush=True)

def finish():
    from PIL import Image
    import cel_style as cel
    sys.path.insert(0,str(ROOT/'art/tools'))
    from halve_emission import downscale
    checks=[]
    for name,folder,w,h,n in SPECS:
        dest=OUT/folder;dest.mkdir(parents=True,exist_ok=True)
        for suffix in ('','_e'):
            sheet=Image.new('RGBA',(w*n,h))
            for i in range(n):
                with Image.open(WORK/name/f'{i:02d}{suffix}.png') as im:sheet.paste(im,(i*w,0))
            if suffix:
                if max(sheet.getchannel(c).getextrema()[1] for c in ('R','G','B'))<=2:continue
                sheet=downscale(sheet)
            sheet.save(dest/f'{name}{suffix}.png',optimize=True,compress_level=9)
        checks.append(cel.check_sheet(f'{folder}/{name}.png',cell=(w,h),frames=n,rows=1,normals=False))
        assert not (dest/f'{name}_n.png').exists()
    for mini,name in [('frost_bear','ice_block'),('stone_colossus','rock')]:
        p=OUT/f'bosses/mini/{mini}/{mini}.tres';old=p.read_text(encoding='utf-8')
        if f'"name": &"{name}"' in old:
            original=(WORK/f'{mini}_original.tres').read_text(encoding='utf-8')
            before=original.split('animations = ',1)[1].strip()
            after=old.split('animations = ',1)[1].strip()
            assert after.startswith(before[:-1]+', {')
            assert len(re.findall(r'"name":',after))==len(re.findall(r'"name":',before))+1
            # All previous ext_resources and AtlasTextures remain byte-identical.
            for chunk in re.findall(r'\[(?:ext_resource|sub_resource)[\s\S]*?(?=\n\[|\Z)',original):
                assert chunk in old
            checks.append({'mini':mini,'previous_animations_sha256':hashlib.sha256(before.encode()).hexdigest(),'old_animations_identical':True})
            continue
        assert 'CanvasTexture' not in old and 'normal_texture' not in old
        old_animations=old.split('animations = ',1)[1].strip()
        backup=WORK/f'{mini}_original.tres';backup.parent.mkdir(parents=True,exist_ok=True)
        if not backup.exists():backup.write_text(old,encoding='utf-8')
        ext=f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/mini/{mini}/{name}.png" id="m6fx_{name}"]\n\n'
        sub=''
        for i in range(4):
            sub+=f'[sub_resource type="AtlasTexture" id="m6fx_{name}_{i}"]\natlas = ExtResource("m6fx_{name}")\nregion = Rect2({i*128}, 0, 128, 128)\n\n'
        new=old.replace('[sub_resource',ext+'[sub_resource',1).replace('[resource]',sub+'[resource]',1)
        frames=', '.join('{"duration": 1.0, "texture": SubResource("m6fx_'+name+'_'+str(i)+'")}' for i in range(4))
        addition=', {\n"frames": ['+frames+'],\n"loop": false,\n"name": &"'+name+'",\n"speed": 1.0\n}'
        pos=new.rfind(']');new=new[:pos]+addition+new[pos:]
        new=re.sub(r'load_steps=(\d+)',lambda m:'load_steps='+str(int(m[1])+5),new,count=1)
        assert new.split('animations = ',1)[1].strip().removesuffix(']').removesuffix(addition)+']'==old_animations
        p.write_text(new,encoding='utf-8')
    contact()
    report={'checks':checks,'choices':{
        'ice':'Asymmetric fractured glacial blocks, dirty blue-grey, chipped frosted edges, narrow cyan fissures; original Dirty glacial ice material.',
        'rock':'Collapsed dressed basalt, chipped ledges, restrained orange fissures; original Wet fractured basalt and Fresh chipped wet stone materials.',
        'ground':'Orthographic top view at 64 px/u, transparent feathered shoreline. Eight distinct frames; suggested playback 8 fps loop. Water reference radius 2 u, heron game radius 3 u => scale 1.5; bubbles radius 1.5 u => scale .75 (spit pool 4 u => scale 2).',
        'chain':'Local X along arc tangent; local Y across band. One frame each, centre pivot (32,16), 64 px = 1 u. Broken end opens toward +X. Rust orange contact is the sole emissive accent.',
        'obstacles':'Four static variants each, 128px cell, bottom-centre pivot (64,128), MAP rig 90.51px/u; game Iso.UNSQUASH * Iso.SPRITE_K. Radius .5 u. Height approx 1.2 u ice, 1 u rock.',
        'contact':'Terraces above, rust city below; bear and four ice variants left, colossus and four rocks right. Mini fitted-camera metadata normalizes both sources to the same 64 px/u. Water/shock radius 3 u, bubbles 1.5 u. CS1 right-half reference in footer.',
        'normals':False,'emission':'Half-resolution, original diffuse atlas cell layout retained.'}}
    (ROOT/'art/tools/night/_m6fx_verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('M6FX ASSEMBLY / PNG / TRES PASS')

def contact():
    from PIL import Image
    # Only assembly/resizing of rendered images. Both real biome floors, at game scale.
    canvas=Image.new('RGBA',(1536,1408),(20,23,26,255))
    for row,biome in enumerate(('terraces','rust_city')):
        floor=Image.open(OUT/f'terrain/{biome}/iso/ground_a.png').convert('RGBA').resize((256,128),Image.Resampling.LANCZOS)
        panel=Image.new('RGBA',(1536,576),(20,23,26,255))
        for k,y in enumerate(range(-128,640,64)):
            for x in range(-256,1792,256):panel.alpha_composite(floor,(x+(128 if k%2 else 0),y))
        canvas.alpha_composite(panel,(0,row*576))
        for j,(mini,name) in enumerate((('frost_bear','ice_block'),('stone_colossus','rock'))):
            p=OUT/f'bosses/mini/{mini}/{mini}.tres'
            txt=p.read_text(encoding='utf-8')
            cw=int(re.search(r'region = Rect2\(0, 0, (\d+)',txt)[1])
            im=Image.open(OUT/f'bosses/mini/{mini}/idle.png').convert('RGBA').crop((0,0,cw,cw))
            # Mini sheets are baked MAP at 90.51 px/u; game Iso.UNSQUASH*SPRITE_K = 1/sqrt(2).
            report=json.loads((ROOT/f'art/renders/monsters/{mini}/build_report.json').read_text())
            # Mini sources use their recorded fitted camera. Normalize both to 64 px/u.
            scale=report['framing']['ortho_scale']*64/cw
            im=im.resize((round(cw*scale),round(cw*scale)),Image.Resampling.LANCZOS)
            canvas.alpha_composite(im,(j*768+5,row*576+200-round(im.height*.70)))
            sheet=Image.open(OUT/f'bosses/mini/{mini}/{name}.png')
            for k in range(4):
                im=sheet.crop((k*128,0,(k+1)*128,128)).resize((91,91),Image.Resampling.LANCZOS)
                canvas.alpha_composite(im,(j*768+220+k*125,row*576+200-91))
        for j,name in enumerate(('zone_water','zone_water_shock','zone_bubbles')):
            sheet=Image.open(OUT/f'fx/minis/{name}.png')
            # Radius 3 u heron, 3 u/1.5 u toad; top-down disk flattened for iso display.
            diameter=384 if j<2 else 192
            im=sheet.crop((256*3,0,256*4,256)).resize((diameter,round(diameter*.566)),Image.Resampling.LANCZOS)
            canvas.alpha_composite(im,(30+j*430,row*576+285))
        for j,name in enumerate(('chain_link','chain_break')):
            im=Image.open(OUT/f'fx/minis/{name}.png').convert('RGBA')
            for k in range(6 if j==0 else 1):canvas.alpha_composite(im,(70+j*600+k*64,row*576+535))
    ref=ROOT/'art/tools/night/_cs1_contact.png'
    if ref.exists():
        im=Image.open(ref).convert('RGBA');im=im.crop((im.width//2,0,im.width,im.height));im.thumbnail((1536,256))
        canvas.alpha_composite(im,(0,1152))
    canvas.convert('RGB').save(ROOT/'art/tools/night/_m6fx_contact.png',optimize=True)

if __name__=='__main__':
    if '--finish' in sys.argv:finish()
    elif '--contact' in sys.argv:contact()
    else:render_all()
