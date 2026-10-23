"""Assemblage PIL uniquement (reduction LANCZOS, planches, .tres). Aucun pixel dessine hors Blender."""
from pathlib import Path
from PIL import Image
import json, hashlib, sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
ROOT=Path(__file__).resolve().parents[3]
SRC=ROOT/'art/renders/bosses/sonneur';DST=ROOT/'game/assets/sprites/bosses/etage/sonneur'
COUNTS={**{f'idle_p{p}':6 for p in (1,2,3)},**{f'walk_p{p}':8 for p in (1,2,3)},'auto':6,'spell_a':8,'spell_b':8,'trans_p2':8,'trans_p3':8,'death':10,'bell_ring':6,'boiler_open':6,
        'lightning':4,'bolt':6,'steam_vent':8,'ground_lightning':6,'ground_scorch':4,'ground_steam':8}
SIZES={'lightning':(128,768),'bolt':(32,32),'steam_vent':(64,384),'ground_lightning':(128,128),'ground_scorch':(128,128),'ground_steam':(64,384)}
LOOPS={'bell_ring','boiler_open','bolt','steam_vent','ground_steam'}
EDGE_OK={'lightning','steam_vent','ground_steam','bolt'}

def main():
    DST.mkdir(parents=True,exist_ok=True);resources=[];subs=[];animations=[];report={};idx=0;overview=[]
    for anim,count in COUNTS.items():
        dirs=['e','s','w','n'] if anim.startswith('walk') else ['s'];W,H=SIZES.get(anim,(256,256))
        sheets=[Image.new('RGBA',(W*count,H*len(dirs)),(128,128,255,0) if sf=='_n' else (0,0,0,0)) for sf in ('','_n','_e')]
        bounds=[];hashes=[]
        for row,d in enumerate(dirs):
            for f in range(count):
                ims=[Image.open(SRC/anim/f'{d}_{f:02}{sf}.png').convert('RGBA').resize((W,H),Image.Resampling.LANCZOS) for sf in ('','_n','_e')]
                alpha=ims[0].getchannel('A');bbox=alpha.getbbox();bounds.append(bbox);hashes.append(hashlib.sha256(ims[0].tobytes()).hexdigest())
                assert bbox,(anim,d,f,'vide')
                if anim not in EDGE_OK:
                    m=min(bbox[0],bbox[1],W-bbox[2],H-bbox[3]);assert m>=(4 if anim not in ('death',) else 4),(anim,d,f,bbox,m)
                for i,im in enumerate(ims):
                    if i:im.putalpha(alpha)
                    if i==1:im.putdata([(128,128,255,0) if p[3]==0 else p for p in im.getdata()])
                    sheets[i].paste(im,(f*W,row*H))
        for sheet,sf in zip(sheets,('','_n','_e')):sheet.save(DST/f'{anim}{sf}.png')
        assert len(set(hashes))>=min(4,count),(anim,'mouvement insuffisant')
        report[anim]={'frames':count,'directions':dirs,'frame_size':[W,H],'sheet_size':sheets[0].size,'bounds':bounds,'unique_frames':len(set(hashes))}
        contact=Image.new('RGBA',(W*count,H*len(dirs)*3),(60,68,70,255))
        for i,sh in enumerate(sheets):contact.alpha_composite(sh,(0,i*sh.height))
        contact.convert('RGB').save(SRC/f'contact_{anim}.png')
        overview.append((anim,sheets[0],W,H,count))
        resources.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/sonneur/{anim}.png" id="{anim}"]')
        for row,d in enumerate(dirs):
            frames=[]
            for f in range(count):
                idx+=1;sid=f'AtlasTexture_{idx}'
                subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{anim}")\nregion = Rect2({f*W}, {row*H}, {W}, {H})')
                frames.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
            prop=anim in SIZES or anim in ('bell_ring','boiler_open')
            name=anim if prop else anim+'_'+d
            loop=anim.startswith(('idle','walk')) or anim in LOOPS
            animations.append('{"frames": ['+', '.join(frames)+'], "loop": '+str(loop).lower()+', "name": &"'+name+'", "speed": '+('14.0' if anim.startswith('walk') else '12.0')+'}')
    (SRC/'sonneur_contract.tres').write_text('[gd_resource type="SpriteFrames" load_steps='+str(1+len(resources)+len(subs))+' format=3]\n\n'+'\n\n'.join(resources+subs)+'\n\n[resource]\nanimations = ['+',\n'.join(animations)+']\n',encoding='utf-8')
    assert (SRC/'sonneur_contract.tres').read_bytes()==(DST/'sonneur.tres').read_bytes(), 'Atlas contract changed'
    # Planche d'ensemble : cinq poses par animation, fond neutre de verification (non livre).
    rows=[]
    for anim,sh,W,H,count in overview:
        sel=[0,count//3,2*count//3,count-1]
        rows.append((anim,[sh.crop((f*W,0,(f+1)*W,H)) for f in sel]))
    cell=192;board=Image.new('RGBA',(8*cell,((len(rows)+1)//2)*cell),(60,68,70,255))
    for r,(anim,cells) in enumerate(rows):
        for c,im in enumerate(cells):
            im=im.copy();im.thumbnail((cell,cell));board.alpha_composite(im,(((r%2)*4+c)*cell+(cell-im.width)//2,(r//2)*cell+(cell-im.height)//2))
    board.convert('RGB').save(SRC/'contact_overview.png')
    (SRC/'validation.json').write_text(json.dumps(report,indent=1),encoding='utf-8')
    (DST/'lighting.md').write_text('''# Sonneur - eclairage et integration

Chaque sheet `<f>.png` a ses jumeaux `<f>_n.png` (normales ecran lineaires : R droite, G haut, B vers camera ; decoder RGB*2-1 puis renormaliser ; fond transparent (128,128,255,0) ; importer en donnees lineaires) et `<f>_e.png` (passe Emission Blender seule : yeux et cloche chaude, paratonnerre/arcs/foudre bleu-blanc `#CFE8FF`, rivets brillants phase 2, braise de chaudiere `#FF9A3C`, vapeur chaude). Meme taille, meme alpha, memes regions AtlasTexture ; le .tres ne reference que le diffus.

Vue ortho 55 deg, Sun chaud haut gauche + fill froid, film transparent, Standard, pas d'ombre au sol, rendu 2x puis LANCZOS. Boss 256 px (3,8 u), racine au sol vers 65-70 %. Marche : lignes e,s,w,n ; autres animations : une ligne `s` (noms `<anim>_s`). Props : noms simples, sans suffixe.

Props : `lightning` 4 variantes 128x768 (2 u x 12 u, vue de face, non boucle, impact en bas) ; `bolt` 32 px 6 frames boucle ; `steam_vent` 64x384 (1 u x 6 u, vue de face, boucle 8) ; `ground_lightning` 128 px 6 frames (cercle 2 u d'impact, decroissance) ; `ground_scorch` 128 px, 4 variantes ; `ground_steam` 64x384 8 frames boucle, vue de dessus, la base du jet en bas, a faire pivoter en jeu ; `bell_ring` 256 px 6 frames boucle (cloche qui vibre, boss p1) ; `boiler_open` couche seule (cavite, braise, fissures, vapeur) alignee sur idle_p3, 6 frames boucle, a additionner/pulser (phase 3).

Phases R3b : p1 cloche nervuree, berceau et bras-marteaux blindes ; p2 collecteurs isolants deployes + arcs ; p3 blindages ecartes, panneau ouvert, grille de foyer, quatre buses, braise et vapeur.

Sources : art/tools/bosses/sonneur.py (rendus), pack_sonneur.py (assemblage + controles). Relancer : blender --background --python art/tools/bosses/sonneur.py -- [--anims ...] puis python art/tools/bosses/pack_sonneur.py. Livraison R3b : contrat PNG et SpriteFrames conserve, inventaire art/tools/bosses/_r3b_inventory.json, verification _r3b_validate.py.
''',encoding='utf-8')
    lines=['# Livraison Sonneur','','| Animation | Frames | Directions | Frame px | Sheet px |','|---|---:|---|---|---|']
    for a,v in report.items():lines.append(f"| {a} | {v['frames']} | {','.join(v['directions'])} | {v['frame_size'][0]}x{v['frame_size'][1]} | {v['sheet_size'][0]}x{v['sheet_size'][1]} |")
    lines+=['','Chaque ligne = `<nom>.png`, `<nom>_n.png`, `<nom>_e.png`.','','## Fichiers','']
    for p in sorted(DST.iterdir()):
        if p.is_file() and p.name!='manifest.md':lines.append(f'- `{p.name}` ({p.stat().st_size} octets)')
    (DST/'manifest.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps({k:[v['sheet_size'],v['unique_frames']] for k,v in report.items()}))
if __name__=='__main__':main()
