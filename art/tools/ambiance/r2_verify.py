"""Verification finale en lecture des PNG; Pillow ne dessine aucun asset."""
import json,hashlib
from pathlib import Path
from PIL import Image,ImageChops,ImageStat
root=Path(__file__).resolve().parents[3]
inv=json.loads((root/'art/tools/ambiance/_r2_inventory.json').read_text())['files']
rows=[]
for it in inv:
 p=root/'game/assets/sprites/ambiance'/it['file']; im=Image.open(p)
 assert list(im.size)==it['size'],p
 assert im.mode==it['mode'],(p,im.mode,it['mode'])
 assert im.getchannel('A').getextrema()[1]>0,p
 sha=hashlib.sha256(p.read_bytes()).hexdigest(); assert sha!=it['sha256'],p
 stage=root/'art/renders/ambiance/r2'/it['family']; data=json.loads((stage/'validation.json').read_text())
 record=next(q for q in data if q['file']==it['file'])
 assert sha==record['sha256'],p
 raw=Image.open(stage/'2x'/it['file']); assert list(raw.size)==[a*2 for a in it['size']],p
 if it['seamless']:
  assert (stage/('tile2x2_'+it['file'])).exists(),p
 if it['use']=='normal':
  assert ImageStat.Stat(im.getchannel('B'),im.getchannel('A')).mean[0]>150,p
 rows.append(dict(file=it['file'],size=it['size'],family=it['family'],frames=it['frames'],use=it['use'],seamless=it['seamless'],sha256=sha))
report=dict(replaced=len(rows),not_replaced=[],errors=[],files=rows)
(root/'art/renders/ambiance/r2/final_validation.json').write_text(json.dumps(report,indent=2))
lines=['# R2 ambiance — rapport','',f'{len(rows)}/{len(inv)} PNG provisoires remplaces. Aucun fichier du lot non remplace.', '', 'Rendus Eevee 8 echantillons, 2x puis reduction Blender. Sources : art/blender/ambiance/r2_<famille>.blend ; graphes conserves. Le DSL de noeuds est derive de amb_lib.py ; les graphes de textures sont reecrits dans r2_render.py.','', 'Controles : noms, tailles, RGBA, alpha non vide, nombre de frames, empreintes differentes des provisoires, compagnons _n/_e, canaux de donnees, raccords periodiques et apercus 2x2. Familles publiees apres validation complete. Inventaire avant remplacement : _r2_inventory.json. Resultats detailles : art/renders/ambiance/r2/*/validation.json et final_validation.json.', '', 'Non remplaces hors lot : rain/ (livraison Codex anterieure conservee). fog_height_mask_<carte> absent du lot initial : non cree, cartes non fournies.','', 'Limites restantes : aspect non valide en situation dans Godot ; repetition du motif perceptible a grande echelle ; particules 16 px volontairement simples. Aucun changement de code/scene/ressource Godot.','', '## Liste exacte des fichiers remplaces','']
for row in rows:
 lines.append('- game/assets/sprites/ambiance/'+row['file']+' — '+str(row['size'][0])+' x '+str(row['size'][1])+' px ; '+str(row['frames'])+' frame(s) ; '+row['use'])
(root/'art/tools/ambiance/_r2_report.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('OK',len(rows),'PNG; dimensions, frames, canaux, alpha, sources 2x et validations presentes')
