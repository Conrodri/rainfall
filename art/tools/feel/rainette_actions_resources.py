def resources():
    # Only replace action entries; preserve the non-action dictionaries and atlases.
    for filename in ('rainette.tres','rainette_emission.tres'):
        path=BASE/filename
        if not path.exists():continue
        raw=(WORK/filename).read_bytes();s=raw.decode();nl='\r\n' if b'\r\n' in raw else '\n'
        ext=re.findall(r'\[ext_resource[^\]]+\]',s)
        eids={Path(re.search(r'path="([^"]+)"',e).group(1)).stem.removesuffix('_e'):re.search(r'id="([^"]+)"',e).group(1) for e in ext}
        subs={m.group(1):m.group(0).rstrip() for m in re.finditer(r'\[sub_resource[^\]]*id="([^"]+)"\][\s\S]*?(?=\n\[|\Z)',s)}
        body=s[s.index('animations = [')+len('animations = ['):].strip()[:-1]
        entries=[];depth=0
        for i,c in enumerate(body):
            if c=='{':
                if depth==0:begin=i
                depth+=1
            elif c=='}':
                depth-=1
                if depth==0:entries.append(body[begin:i+1])
        kept=[];newsubs=[];newentries=[];seen=set()
        for entry in entries:
            name=re.search(r'"name"\s*:\s*&?"([^"]+)"',entry).group(1)
            if any(name.startswith(a+'_') for a in [*ANIMS,*ALIASES]):continue
            kept.append(entry)
            for sid in re.findall(r'SubResource\("([^"]+)"\)',entry):
                if sid not in seen:newsubs.append(subs[sid]);seen.add(sid)
        cell=96 if 'emission' in filename else 192
        if cell==96:
            # Existing emission sheets are already halved; repair legacy 192px regions.
            def half_region(match):
                values=list(map(float,match.group(1).split(',')))
                if values[2:]==[192,192]:values=[v/2 for v in values]
                return 'region = Rect2('+', '.join(f'{v:g}' for v in values)+')'
            newsubs=[re.sub(r'region = Rect2\(([^)]+)\)',half_region,sub) for sub in newsubs]
        for a in ANIMS:
            for row,d in enumerate(ra.DIRS):
                frames=[]
                for f in range(ANIMS[a]):
                    sid=f'action_{a}_{d}_{f}'
                    newsubs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{eids[a]}")\nregion = Rect2({f*cell}, {row*cell}, {cell}, {cell})')
                    frames.append('{"duration": '+str(F60[a][f]*12/60)+', "texture": SubResource("'+sid+'")}')
                for alias in [a]+[k for k,v in ALIASES.items() if v==a]:
                    newentries.append('{"frames": ['+', '.join(frames)+'], "loop": false, "name": &"'+alias+'_'+d+'", "speed": 12.0}')
        header=re.search(r'^\[gd_resource[^\]]+\]',s).group(0)
        header=re.sub(r'load_steps=\d+','load_steps='+str(len(ext)+len(newsubs)+1),header)
        result=header+'\n\n'+'\n'.join(ext)+'\n\n'+'\n\n'.join(newsubs)+'\n\n[resource]\nanimations = [\n'+',\n'.join(kept+newentries)+'\n]\n'
        path.write_bytes(result.replace('\r\n','\n').replace('\n',nl).encode())

