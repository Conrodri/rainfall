"""PIL assembly/encoding only. Validate every frame and write Godot resources."""
from pathlib import Path
from PIL import Image, ImageChops
import json, hashlib
ROOT=Path(__file__).resolve().parents[3]
SRC=ROOT/'art/renders/bosses/cerf';DST=ROOT/'game/assets/sprites/bosses/etage/cerf'
COUNTS={**{f'idle_p{p}':6 for p in (1,2,3)},**{f'walk_p{p}':8 for p in (1,2,3)},'auto':6,'spell_a':8,'spell_b':8,'trans_p2':8,'trans_p3':8,'death':10,'vanish':8,'reappear':8,'antlers':6,'wisp':6,'wisp_explode':8,'ground_mist':6,'ground_wisp_trail':6}
LOOPS={'antlers','wisp','ground_mist','ground_wisp_trail'}

def main():
    DST.mkdir(parents=True,exist_ok=True);resources=[];subs=[];animations=[];report={};idx=0;overview=[]
    for anim,count in COUNTS.items():
        dirs=['e','s','w','n'] if anim.startswith('walk') else ['s'];size=64 if anim in ('wisp','wisp_explode','ground_wisp_trail') else 256
        sheets=[Image.new('RGBA',(size*count,size*len(dirs)),(128,128,255,0) if sf=='_n' else (0,0,0,0)) for sf in ('','_n','_e')]
        bounds=[];hashes=[]
        for row,d in enumerate(dirs):
            for f in range(count):
                ims=[Image.open(SRC/anim/f'{d}_{f:02}{sf}.png').convert('RGBA').resize((size,size),Image.Resampling.LANCZOS) for sf in ('','_n','_e')]
                alpha=ims[0].getchannel('A');bbox=alpha.getbbox();bounds.append(bbox);hashes.append(hashlib.sha256(ims[0].tobytes()).hexdigest())
                if bbox:
                    margin=min(bbox[0],bbox[1],size-bbox[2],size-bbox[3]);assert margin>=(8 if anim in ('death','vanish','reappear') else 4),(anim,d,f,bbox)
                else:assert (anim in ('death','vanish','wisp_explode') and f==count-1) or (anim=='reappear' and f==0),(anim,d,f,'empty')
                for i,im in enumerate(ims):
                    if i:im.putalpha(alpha)
                    if i==1:im.putdata([(128,128,255,0) if p[3]==0 else p for p in im.get_flattened_data()])
                    sheets[i].paste(im,(f*size,row*size))
        for sheet,sf in zip(sheets,('','_n','_e')):sheet.save(DST/f'{anim}{sf}.png')
        assert len(set(hashes))>=min(4,count),(anim,'insufficient motion')
        report[anim]={'frames':count,'directions':dirs,'frame_size':size,'sheet_size':sheets[0].size,'bounds':bounds,'unique_frames':len(set(hashes))}
        contact=Image.new('RGBA',(size*count,size*len(dirs)*3))
        for i,sheet in enumerate(sheets):contact.paste(sheet,(0,i*sheet.height))
        contact.save(SRC/f'contact_{anim}.png')
        # One row per animation, up to six samples; assembly only, no drawing.
        cells=[]
        for f in sorted(set([0,count//4,count//2,3*count//4,count-1])):
            cell=sheets[0].crop((f*size,0,(f+1)*size,size));cells.append(cell)
        overview.append((anim,cells))
        resources.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/cerf/{anim}.png" id="{anim}"]')
        for row,d in enumerate(dirs):
            frames=[]
            for f in range(count):
                idx+=1;sid=f'AtlasTexture_{idx}'
                subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{anim}")\nregion = Rect2({f*size}, {row*size}, {size}, {size})')
                frames.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
            name=anim if anim in LOOPS or anim=='wisp_explode' else anim+'_'+d
            loop=anim.startswith(('idle','walk')) or anim in LOOPS
            animations.append('{"frames": ['+', '.join(frames)+'], "loop": '+str(loop).lower()+', "name": &"'+name+'", "speed": '+('14.0' if anim.startswith('walk') else '12.0')+'}')
    resource_text='[gd_resource type="SpriteFrames" load_steps='+str(1+len(resources)+len(subs))+' format=3]\n\n'+'\n\n'.join(resources+subs)+'\n\n[resource]\nanimations = ['+',\n'.join(animations)+']\n'
    assert (DST/'cerf.tres').read_text(encoding='utf-8')==resource_text, 'R3a: preserve existing atlas regions and resource'
    # Neutral backing is an assembly aid, never included in delivered sprites.
    board=Image.new('RGBA',(5*256,len(overview)*256),(40,48,49,255))
    for row,(anim,cells) in enumerate(overview):
        for col,cell in enumerate(cells):board.alpha_composite(cell,(col*256+(256-cell.width)//2,row*256+(256-cell.height)//2))
    board.save(SRC/'contact_overview.png')
    (SRC/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    (DST/'lighting.md').write_text('''# Cerf-Lanterne — éclairage et intégration

Chaque sheet dispose de sa normale `_n` et de sa passe Emission Blender `_e`, de dimensions et alpha identiques. Normal map écran linéaire : R droite, G haut, B vers caméra ; décoder RGB*2-1 et renormaliser après filtrage. Fond transparent (128,128,255,0). Importer `_n` comme données linéaires, sans conversion sRGB. Émission sur noir/transparent, sans éclairage diffus ; matériaux non émissifs noirs. Une émission HDR est écrêtée dans le PNG 8 bits.

Vue orthographique 55°, Sun chaud haut gauche et fill froid, Standard, film transparent, sans plan d'ombre. Rendu Blender 2x puis LANCZOS. Racine au sol à 70% de la frame ; le centre des quatre sabots peut varier avec la perspective et le mouvement. Boss de 3,2 u. Marche : lignes e,s,w,n. Autres : s. AtlasTexture couleur uniquement. Idle 12 fps, marche 14 fps, autres 12 fps. Boucles idle/walk/antlers/wisp/ground_mist/ground_wisp_trail.

`antlers` est la couche émissive seule des flammes de la ramure p1, sans cages opaques ni corps, au même emplacement et avec le même cycle que idle_p1. L'additionner avec une intensité modulée, sans doubler la ramure de base. `ground_mist` : translucide #B8C8C0, à placer sous les entités et télégraphes. Les autres VFX font 64 px par frame. Les normales des surfaces translucides conservent la pass Blender ; les renormaliser en shader. Pas de lumière ponctuelle intégrée : `_e` permet au jeu de piloter la lumière dynamique.

Transitions continues p1→p2 et p2→p3 ; la p3 possède des bords translucides et des lanternes éteintes avec faible braise. Fin de death/vanish/wisp_explode et début de reappear entièrement transparents, volontairement. Les noms des animations suivent eclusier.tres : suffixe _s pour le boss, noms simples pour les props.

Sources : art/tools/bosses/cerf.py ; assemblage et validations : art/tools/bosses/pack_cerf.py. Relancer Blender 5.2 --background --python art/tools/bosses/cerf.py puis python art/tools/bosses/pack_cerf.py. Option --anims pour un sous-ensemble. Planche contact_overview : lignes dans l'ordre du manifeste, cinq poses de début à fin. Les contacts individuels montrent toutes les frames, puis normales et émission.
''',encoding='utf-8')
    lines=['# Livraison Cerf-Lanterne','', '| Animation | Frames | Directions | Frame px | Sheet px |','|---|---:|---|---:|---|']
    for anim,v in report.items():lines.append(f"| {anim} | {v['frames']} | {','.join(v['directions'])} | {v['frame_size']} | {v['sheet_size'][0]} × {v['sheet_size'][1]} |")
    lines+=['','## Fichiers et tailles','']
    for p in sorted(DST.iterdir()):
        if p.is_file() and p.name!='manifest.md':lines.append(f'- `{p.name}` : {p.stat().st_size:,} octets')
    (DST/'manifest.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(f'PASS pack: {len(report)} animations, PNG color/normal/emission, unchanged cerf.tres')
if __name__=='__main__':main()
