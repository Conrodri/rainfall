"""G11 procedural replacement; immutable originals, duration/LUFS matching."""
import json
import shutil
import subprocess
from pathlib import Path
import numpy as np
import audio_common as ac
import gen_music as music
import gen_ambience as ambience
import synth_lib as sl

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT/'game/assets/audio'
ARCHIVE = ROOT/'art/archive_3d/audio_foret'

def loudness(path):
    p = subprocess.run(['ffmpeg','-hide_banner','-i',str(path),'-af',
        'loudnorm=I=-23:TP=-1:LRA=11:print_format=json','-f','null','-'],
        capture_output=True, text=True, check=True)
    return float(json.JSONDecoder().raw_decode(p.stderr[p.stderr.rfind('{'):])[0]['input_i'])

def main():
    files = [Path(f'music/music_foret_brume_{s}_01.ogg') for s in ('base','tension','drive','climax')]
    files += [Path('music/music_boss_foret_brume_01.ogg'),Path('ambience/amb_foret_brume_decor_01.ogg'),Path('ambience/amb_wind_foret_brume_01.ogg')]
    for rel in files:
        dst=ARCHIVE/rel
        dst.parent.mkdir(parents=True,exist_ok=True)
        if not dst.exists(): shutil.copy2(OUT/rel,dst)
    rows=[]
    for i,rel in enumerate(files):
        old=ARCHIVE/rel
        original=ac.decode(old)
        n=len(original)
        old_lufs=loudness(old)
        del original
        if i<4:
            x=music.cave_layer(n,n/ac.SR,('base','tension','drive','climax')[i])
        elif i==4:
            x=np.zeros((n,2))
            for layer,g in (('base',.8),('tension',.7),('drive',.65),('climax',.45)):
                x+=music.cave_layer(n,n/ac.SR,layer,True)*g
        else:
            x=ambience.cave_ambience(n,wind=i==6)
        x-=x.mean(0)
        x=sl.soft_limit(x*10**((-21-ac.rms_db(x))/20),-9,-2.5)
        path=OUT/rel
        ac.write_ogg(path,x,6)
        measured=loudness(path)
        x*=10**((old_lufs-measured)/20)
        assert ac.peak_db(x)<-1.4, (rel,'headroom',ac.peak_db(x))
        ac.write_ogg(path,x,6)
        del x
        decoded=ac.decode(path)
        new_lufs=loudness(path)
        assert len(decoded)==n and np.isfinite(decoded).all()
        assert abs(new_lufs-old_lufs)<.3 and ac.peak_db(decoded)<-1
        rows.append(dict(path=rel.as_posix(),duration=n/ac.SR,old_lufs=old_lufs,lufs=new_lufs,peak=ac.peak_db(decoded)))
        del decoded
        print(rel.as_posix(),'PASS',flush=True)
    (Path(__file__).with_name('g11_verification.json')).write_text(json.dumps(rows,indent=2))
    print('G11 PASS: 7 files')

if __name__=='__main__': main()
