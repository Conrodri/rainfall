"""Lecture seule des PNG : dimensions, couverture, marges et padding des normales."""
import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent/'vendor'))
from PIL import Image, ImageChops
BASE=Path(__file__).resolve().parents[1]/'renders/ardent'

def audit():
    report={'count':0,'diffuse_count':0,'normal_count':0,'emission_count':0,'minimum_margin':384,'minimum_margin_alpha128':384,'alpha_mismatches':[],'problems':[]}
    for anim in ['idle','run']:
        for d in ['e','se','s','sw','w','nw','n','ne']:
            for frame in range(8):
                name=f'{d}_{frame:02d}.png'
                images=[Image.open(BASE/(anim+suffix)/name) for suffix in ['', '_n','_e']]
                for kind,im in zip(['diffuse','normal','emission'],images):
                    report['count']+=1;report[kind+'_count']+=1
                    if im.mode!='RGBA' or im.size!=(384,384):report['problems'].append([anim,name,kind,'format'])
                alpha=images[0].getchannel('A')
                for suffix,im in zip(['_n','_e'],images[1:]):
                    if alpha.tobytes()!=im.getchannel('A').tobytes():report['alpha_mismatches'].append([anim+suffix,name])
                box=alpha.getbbox()
                margin=min(box[0],box[1],384-box[2],384-box[3])
                if margin<report['minimum_margin']:
                    report['minimum_margin']=margin;report['tightest_frame']=[anim,name,list(box)]
                box128=alpha.point(lambda v:255 if v>=128 else 0).getbbox()
                report['minimum_margin_alpha128']=min(report['minimum_margin_alpha128'],box128[0],box128[1],384-box128[2],384-box128[3])
                # All alpha-zero pixels must have the exact required neutral normal RGB.
                if any((r,g,b)!=(128,128,255) for r,g,b,a in images[1].getdata() if a==0):report['problems'].append([anim,name,'normal padding'])
                for im in images:im.close()
    report['passed']=not report['problems'] and not report['alpha_mismatches'] and report['minimum_margin']>=5 and report['count']==384
    return report

if __name__=='__main__':
    result=audit()
    path=BASE/'pass_report.json';report=json.loads(path.read_text());report['audit']=result;path.write_text(json.dumps(report,indent=2))
    print(json.dumps(result))
