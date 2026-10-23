"""Assemble les trois passes Blender. PIL sert uniquement au redimensionnement/assemblage.
Usage: pack_monsters.py <monsters|bosses|bosses/mini|fx/elites> <nom> <taille> <anim[:fps[:noloop]]>... [--dirs] [--dirlist e,s,w,n]
Les frames sont dans art/renders/monsters/<nom>/<anim>/<dir>_<ff>[_n|_e].png.
Accepte aussi les dossiers de passes <anim>_n et <anim>_e historiques.
Une animation a une direction unique est nommee <anim>_s, sauf les fx/elites
non directionnels (x), qui conservent le nom <anim> (ex. default).
"""
import argparse,re,sys,subprocess
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'vendor'))
from PIL import Image
DIRS=['e','se','s','sw','w','nw','n','ne']
ROOT=Path(__file__).resolve().parents[3]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('category',choices=['monsters','bosses','bosses/mini','fx/elites']);p.add_argument('name');p.add_argument('size',type=int);p.add_argument('animations',nargs='+')
    p.add_argument('--dirs',action='store_true');p.add_argument('--dirlist')
    p.add_argument('--preserve-tres',action='store_true',help='Keep the existing SpriteFrames byte for byte')
    p.add_argument('--anim-dirs',action='append',default=[],metavar='ANIM=e,s,w,n',help='Directions par animation (prioritaires sur --dirlist); repetable')
    a=p.parse_args()
    animation_dirs={}
    for entry in a.anim_dirs:
        if '=' not in entry:p.error('--anim-dirs attend ANIM=e,s,w,n')
        anim_name,directions=entry.split('=',1)
        animation_dirs[anim_name]=directions.split(',')
        if anim_name not in [spec.split(':')[0] for spec in a.animations]:p.error('animation inconnue: '+anim_name)
    if a.size<=0 or not re.fullmatch(r'[a-z0-9_]+',a.name):p.error('nom ou taille invalide')
    base=ROOT/'art/renders/monsters'/a.name;out=ROOT/'game/assets/sprites'/a.category/a.name;out.mkdir(parents=True,exist_ok=True)
    ext=[];sub=[];body=[];sid=0;normal_sheets=[]
    for spec in a.animations:
        parts=spec.split(':');anim=parts[0];fps=int(parts[1]) if len(parts)>1 and parts[1] else 12;loop=not(len(parts)>2 and parts[2]=='noloop')
        d=base/anim
        dirs=animation_dirs.get(anim) or (a.dirlist.split(',') if a.dirlist else DIRS if a.dirs else ['s' if (d/'s_00.png').exists() else 'x'])
        if anim not in animation_dirs and len(dirs)>1 and not all((d/f'{dr}_00.png').exists() for dr in dirs):
            available=[dr for dr in DIRS+['x'] if (d/f'{dr}_00.png').exists()]
            if len(available)==1:dirs=available
        if any(x not in DIRS+['x'] for x in dirs) or len(set(dirs))!=len(dirs):p.error('directions invalides')
        ids=sorted(int(m.group(1)) for f in d.glob(f'{dirs[0]}_*.png') if (m:=re.fullmatch(rf'{dirs[0]}_(\d+)\.png',f.name)))
        if not ids or ids!=list(range(len(ids))):raise ValueError(f'Frames manquantes: {d}')
        nf=len(ids)
        def source(dr,f,suffix):
            path=d/f'{dr}_{f:02d}{suffix}.png'
            if not path.exists() and suffix:path=base/(anim+suffix)/f'{dr}_{f:02d}.png'
            return path
        for dr in dirs:
            actual=sorted(int(m.group(1)) for f in d.glob(f'{dr}_*.png') if (m:=re.fullmatch(rf'{dr}_(\d+)\.png',f.name)))
            if actual!=ids:raise ValueError(f'Frames incoherentes {anim}/{dr}')
        # Les auras additives peuvent avoir uniquement le diffus. Sinon les maps sont obligatoires.
        suffixes=['']+[suffix for suffix in ['_n','_e'] if source(dirs[0],0,suffix).exists()]
        for suffix in suffixes:
            sheet=Image.new('RGBA',(nf*a.size,len(dirs)*a.size),(128,128,255,0) if suffix=='_n' else (0,0,0,0))
            for row,dr in enumerate(dirs):
                for f in ids:
                    with Image.open(source(dr,f,suffix)) as im:
                        im=im.convert('RGBA')
                        if suffix=='_n':
                            # Preserve linear normal RGB and neutral transparent padding during resize.
                            im=Image.merge('RGBA',tuple(ch.resize((a.size,a.size),Image.Resampling.LANCZOS) for ch in im.split()))
                        else:im=im.resize((a.size,a.size),Image.Resampling.LANCZOS)
                        sheet.paste(im,(f*a.size,row*a.size))
            sheet.save(out/f'{anim}{suffix}.png')
            if suffix=='_n':normal_sheets.append(str(out/f'{anim}{suffix}.png'))
        tid=len(ext)+1;res=f'res://assets/sprites/{a.category}/{a.name}/{anim}.png'
        ext.append(f'[ext_resource type="Texture2D" path="{res}" id="{tid}"]')
        for row,dr in enumerate(dirs):
            frames=[]
            for f in ids:
                sid+=1;ref=f'a{sid}';frames.append('{"duration": 1.0, "texture": SubResource("'+ref+'")}')
                sub.append(f'[sub_resource type="AtlasTexture" id="{ref}"]\natlas = ExtResource("{tid}")\nregion = Rect2({f*a.size}, {row*a.size}, {a.size}, {a.size})\n')
            name=anim if a.category=='fx/elites' and dirs==['x'] else f'{anim}_{dr}' if len(dirs)>1 else f'{anim}_s'
            body.append('{\n"frames": ['+', '.join(frames)+f'],\n"loop": {str(loop).lower()},\n"name": &"{name}",\n"speed": {fps}.0\n'+'}')
    if normal_sheets:
        subprocess.run([r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe','--background','--python',str(Path(__file__).with_name('finalize_normals.py')),'--',*normal_sheets],check=True)
    tres=f'[gd_resource type="SpriteFrames" load_steps={len(ext)+len(sub)+1} format=3]\n\n'+'\n'.join(ext)+'\n\n'+'\n'.join(sub)+'\n[resource]\nanimations = ['+', '.join(body)+']\n'
    if not a.preserve_tres:(out/f'{a.name}.tres').write_text(tres,encoding='utf-8',newline='\n')
    print('ok',out)
if __name__=='__main__':main()



