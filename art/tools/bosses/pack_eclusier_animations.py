from pathlib import Path
from PIL import Image
import json
ROOT=Path(__file__).resolve().parents[3]
SRC=ROOT/'art/renders/bosses/eclusier';DST=ROOT/'game/assets/sprites/bosses/etage/eclusier';DST.mkdir(parents=True,exist_ok=True)
counts={**{f'idle_p{p}':6 for p in (1,2,3)},**{f'walk_p{p}':8 for p in (1,2,3)},'auto':6,'spell_a':8,'spell_b':8,'trans_p2':8,'trans_p3':8,'death':10,'anchored':1,'wheel':8,'wave':8,'geyser':12,'ground_geyser':12,'ground_water':4,'ground_wave':8}
props={'wheel','wave','geyser','ground_geyser','ground_water','ground_wave'}
resources=[];subs=[];animations=[];report={};idx=0
for anim,count in counts.items():
    dirs=['e','s','w','n'] if anim.startswith('walk') else ['s']
    size=(128,576) if anim in ('wave','ground_wave') else (128,128) if anim in props else (256,256)
    boards=[];bboxes=[]
    for suffix in ('','_n','_e'):
        sheet=Image.new('RGBA',(size[0]*count,size[1]*len(dirs)),(128,128,255,0) if suffix=='_n' else (0,0,0,0))
        for row,d in enumerate(dirs):
            for f in range(count):
                file=SRC/anim/f'{d}_{f:02}{suffix}.png'
                im=Image.open(file).convert('RGBA').resize(size,Image.Resampling.LANCZOS)
                if suffix:
                    alpha=Image.open(SRC/anim/f'{d}_{f:02}.png').convert('RGBA').resize(size,Image.Resampling.LANCZOS).getchannel('A');im.putalpha(alpha)
                if suffix=='_n':im.putdata([(128,128,255,0) if p[3]==0 else p for p in im.getdata()])
                if not suffix:bboxes.append(im.getbbox())
                sheet.paste(im,(f*size[0],row*size[1]))
        sheet.save(DST/f'{anim}{suffix}.png');boards.append(sheet)
    contact=Image.new('RGBA',(boards[0].width,boards[0].height*3),(0,0,0,0))
    for i,b in enumerate(boards):contact.paste(b,(0,i*b.height))
    contact.save(SRC/f'contact_{anim}.png')
    report[anim]={'frames':count,'directions':dirs,'frame_size':size,'sheet_size':boards[0].size,'bounds':bboxes}
    resources.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/eclusier/{anim}.png" id="{anim}"]')
    for row,d in enumerate(dirs):
        fs=[]
        for f in range(count):
            idx+=1;sid=f'AtlasTexture_{idx}'
            subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{anim}")\nregion = Rect2({f*size[0]}, {row*size[1]}, {size[0]}, {size[1]})')
            fs.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
        loop=anim.startswith(('idle','walk','ground_')) or anim in ('wheel','geyser')
        name=anim if anim in props else anim+'_'+d
        animations.append('{"frames": ['+', '.join(fs)+'], "loop": '+str(loop).lower()+', "name": &"'+name+'", "speed": '+('14.0' if anim.startswith('walk') else '12.0')+'}')
(DST/'eclusier.tres').write_text('[gd_resource type="SpriteFrames" load_steps='+str(1+len(resources)+len(subs))+' format=3]\n\n'+'\n\n'.join(resources+subs)+'\n\n[resource]\nanimations = ['+',\n'.join(animations)+']\n',encoding='utf-8')
(SRC/'validation.json').write_text(json.dumps(report,indent=2))
(DST/'lighting.md').write_text('''# Eclusier — eclairage\n\nChaque sheet couleur est accompagnee de `_n` et `_e`, memes regions AtlasTexture.\nNormales ecran lineaires : R vers la droite, G vers le haut, B vers la camera ; decoder RGB * 2 - 1. Fond (128,128,255,0). Pass Normal Blender projete sur les axes fixes de la camera, sans transformation sRGB.\nEmission : pass Emission Blender seul, couleurs des yeux, eau et reflets ; noir pour les materiaux sans emission. Alpha identique a la couleur. Ne pas eclairer une seconde fois cette couche.\nCamera orthographique 55 degres, Sun chaud haut gauche, fill froid ; film transparent, aucune ombre au sol. Boss rendus en 512 puis reduits a 256 par LANCZOS ; props en 2x. Ground_water utilise une camera verticale et une surface periodique pour le raccord du tile.\nLignes walk : e,s,w,n. Autres : s. Props : noms simples. 12 fps, marche 14 fps. Boucles idle/walk/wheel/geyser/ground_*. Wave, attaques, transitions et mort sans boucle.\n\nSources : art/tools/bosses/eclusier_animate.py ; modele valide art/blender/bosses/eclusier.blend conserve.\n''',encoding='utf-8')
print(json.dumps({k:{x:v[x] for x in ('frames','directions','sheet_size')} for k,v in report.items()},indent=2))
manifest=['# Livraison Eclusier','', 'Chaque ligne correspond a trois fichiers : `<nom>.png`, `<nom>_n.png`, `<nom>_e.png`.','', '| Nom | Frames par direction | Directions | Frame | Sheet |', '|---|---:|---|---|---|']
for k,v in report.items():
    manifest.append(f"| {k} | {v['frames']} | {','.join(v['directions'])} | {'x'.join(map(str,v['frame_size']))} | {'x'.join(map(str,v['sheet_size']))} |")
manifest.extend(['','## Fichiers livres',''])
for p in sorted(DST.iterdir()):
    if p.is_file():manifest.append(f'- `{p.name}` ({p.stat().st_size} octets)')
manifest.extend(['','## Sources et controles','', '- Modele valide conserve : `art/blender/bosses/eclusier.blend`.','- Scene de travail : `art/blender/bosses/eclusier_animations.blend` (idle cle, les autres poses sont reproductibles avec le script).','- Generation : `art/tools/bosses/eclusier_animate.py -- --anims <noms>` via Blender 5.2 --background.','- Assemblage : `art/tools/bosses/pack_eclusier_animations.py`.','- Verification : `art/tools/bosses/check_eclusier.py`.','- Rendus 2x : `art/renders/bosses/eclusier/<anim>/<dir>_<ff>{,_n,_e}.png`.','- Contacts : `art/renders/bosses/eclusier/contact_<anim>.png` et `contact_overview.png`.','- Rapports : `validation.json` et `checks.json`.'])
(DST/'manifest.md').write_text('\n'.join(manifest)+'\n',encoding='utf-8')
