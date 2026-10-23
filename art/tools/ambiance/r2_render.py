"""R2 : nouveaux graphes proceduraux Eevee. Aucun pixel dessine hors rendu.
Une famille par invocation, fichiers stages puis valides avant publication.
"""
import sys, json, math, random, hashlib, shutil
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
from r2_nodes import *
import numpy as np
INV=json.loads((ROOT/'art/tools/ambiance/_r2_inventory.json').read_text())['files']
FAMILY=sys.argv[sys.argv.index('--')+1]
STAGE=RAW/'r2'/FAMILY
STAGE.mkdir(parents=True,exist_ok=True)
setup()
C.sc.render.image_settings.compression=65
try: C.sc.eevee.taa_render_samples=8
except: pass

def normal(hf,size,amp):
    d=1/size; z=hf(0,0)
    v=vec(-(hf(d,0)-z)/d*amp,-(hf(0,d)-z)/d*amp,1)
    n=C.tree.nodes.new('ShaderNodeVectorMath'); n.operation='NORMALIZE'; C.tree.links.new(v.s,n.inputs[0])
    return tuple(q*.5+.5 for q in sep(V(n.outputs[0])))

def rgbhex(s): return srgb(tuple(int(s[i:i+2],16)/255 for i in (0,2,4)))
def color(a,b,t): return tuple(lerp(x,y,t) for x,y in zip(rgbhex(a),rgbhex(b)))
def field(u,v,seed,scale=2):
    warp=tn(u,v,.8,seed=seed,detail=2)-.5
    return .72*tn(u+warp*.13,v-warp*.08,scale,seed=seed+4,detail=3,rough=.48)+.28*tn(u,v,scale*2.7,seed=seed+9,detail=2)

def build(item):
 name=item['file'][:-4]; base=name.removesuffix('_n').removesuffix('_e')
 seed=1+int(hashlib.sha256(base.encode()).hexdigest()[:6],16)%997/19
 variant= int(base.split('_')[-1]) if base.split('_')[-1].isdigit() and len(base.split('_')[-1])==1 else 1
 isn=item['use']=='normal'
 def b(e):
    x,y=e.x,e.y; u,v=e.u,e.v; r=hyp(x,y)
    # Gouttes facettees, reflet haut-gauche et bourrelet refractif.
    if name.startswith(('drop_32','drop_window')):
        window=name.startswith('drop_window'); rx=(.25+.035*variant) if window else [.38,.29,.51,.25][variant-1]
        ry=(.30+.045*variant) if window else [.73,.82,.57,.86][variant-1]
        cy=.12 if window and variant in (4,5) else 0
        def height(du,dv):
            yy=(y+dv*2-cy)/ry
            xx=(x+du*2+.10*yy)/rx
            q=hyp(xx/(1-.30*smooth(-.4,1,yy)),yy)
            return sqrt(clamp01(1-q*q))
        h=height(0,0); shape=smooth(0,.18,h)
        if isn: return normal(height,item['size'][0],.09),shape
        hl=gauss(x+rx*.32,rx*.19)*gauss(y-cy-ry*.30,ry*.20)
        rim=(1-smooth(.12,.55,h))*shape
        a=shape*(.23+.49*rim)+hl*.9
        if window and variant in (4,5): a=mx(a,gauss(x,.045)*smooth(-.95,-.3,y)*smooth(.2,-.1,y)*.22)
        return None,a
    if name.startswith('rain_'):
        layers=[]
        for k in range(3):
            n=67+37*k; cell=floor(u*n); local=fract(u*n)
            offset=wn(cell,seed+k,2); phase=fract(v+wn(cell,seed+k,3))
            length=.12+(.20 if variant==2 else .07)*wn(cell,seed+k,4)
            a=gauss(local-.25-offset*.5,.10)*smooth(0,.008,phase)*clamp01(1-phase/length)**1.5
            layers.append(a*gt(.65+k*.1,wn(cell,seed+k,1)))
        a=mx(mx(layers[0],layers[1]),layers[2])
        return (tuple(layers) if name.startswith('rain_sheet') else None),a
    if name.startswith('splash_'):
        fi,t,x,y=e.atlas(8); rr=hyp(x,y/.57); theta=atan2(y/.57,x)
        R=.07+.63*sqrt(t); fade=(1-t)**1.1
        crown=1+.12*sin(theta*(9+variant)+seed)*(1-t)
        a=gauss(rr-R*crown,.038+variant*.013)*fade*.8
        a=a+gauss(rr-R*.76,.025)*fade*.32+gauss(rr,.11)*(1-smooth(0,.3,t))
        rnd=random.Random(int(seed*100))
        for j in range(11 if variant!=2 else 7):
            ang=rnd.uniform(0,TAU); speed=rnd.uniform(.5,.86)
            px=math.cos(ang)*speed*sqrt(t); py=math.sin(ang)*speed*.57*sqrt(t)+(.5 if variant!=2 else .26)*4*t*(1-t)
            a=a+gauss(hyp(x-px,y-py),.029 if variant!=2 else .06)*fade*smooth(0,.12,t)
        return None,a
    # Brouillards : tore 4D, deux echelles, filaments et nappes peu opaques.
    if name.startswith(('fog_','cloud_shadow','canopy_shadow','steam_')):
        puff=name.startswith(('fog_puff','steam_'))
        def hf(du,dv):
            if puff:
                xx=x+du*2; yy=y+dv*2
                n=noise(xx*2+seed,yy*2,seed,detail=4,rough=.52)
                wisps=noise(xx*4+seed,yy*6,seed+3,detail=3,rough=.53)
                q=hyp(xx/(.90-.03*variant),yy/(.68+.03*variant))+(n-.5)*.45
                return smooth(1,.05,q)*(.20+.55*n+.25*wisps)*smooth(1,.86,hyp(xx,yy))
            f=field(u+du,v+dv,seed,1.6 if 'volume' not in name else 2.6)
            fine=tn(u+du,v+dv,6,1.7,seed=seed+12,detail=2)
            return smooth(.29,.72,f)*(.62+.38*fine)
        h=hf(0,0)
        if isn: return normal(hf,item['size'][0],.016),smooth(0,.03,h)
        if name.startswith('canopy'):
            leaf=1-smooth(.13,.26,tv(u,v,12,7,seed=seed))
            return 0,h*(.32+.68*leaf)*.82
        if name.startswith('cloud'): return 0,smooth(.15,.72,h)*.72
        return None,h*(.65 if puff else .42)
    # Eau : hauteur periodique commune aux masques et aux normales.
    if name.startswith('puddle_'):
        def hf(du,dv): return field(u+du,v+dv,seed,1.6+.15*variant)
        f=hf(0,0); threshold=item.get('threshold',.57)
        if isn: return normal(lambda a,b:smooth(threshold-.03,threshold+.16,hf(a,b)),1024,.025),1
        red=smooth(threshold,threshold+.016,f)
        return (red,smooth(threshold,threshold+.18,f),smooth(threshold-.07,threshold-.015,f)*(1-red)),1
    if name.startswith('ripple_normal'):
        return normal(lambda du,dv:field(u+du,v+dv,seed,3),256,.035),1
    if name.startswith('water_caustics'):
        warp=tn(u,v,1.3,seed=seed,detail=2)-.5
        d=tv(u+warp*.12,v-warp*.1,3.4,seed=seed,feature='DISTANCE_TO_EDGE')
        d2=tv(u+warp*.1,v,5.5,seed=seed+3,feature='DISTANCE_TO_EDGE')
        return None,clamp01(gauss(d,.043)+.35*gauss(d2,.025))*.86
    if name.startswith('ripple_8'):
        fi,t,x,y=e.atlas(8); rr=hyp(x,y/.58); a=0
        for j in range(2+variant%2):
            R=t*.9-j*.22
            a=a+gauss(rr-R,.025+.025*t)*smooth(0,.08,R)*(1-t)**1.2/(1+j*.4)
        return None,a
    # Feuilles avec nervures et variations de lumiere, cendres texturees.
    if name.startswith('leaf_pine'):
        if variant==3:
            q=hyp(x/.49,y/.77); cell=voro(x*4,y*5,seed,feature='F1')
            return color('382C24','99764C',smooth(.5,.1,cell)*(.6+.25*y)),smooth(1,.88,q)
        a=0
        segments=[(-.1,-.85,-.55,.80),(0,-.85,.04,.91),(.1,-.85,.58,.72)] if variant==1 else [(-.8,-.65,.72,.70),(-.68,.7,.73,-.55)]
        for ax,ay,bx,by in segments:
            dd=seg(x,y,ax,ay,bx,by); a=mx(a,smooth(.065,.015,dd))
        return color('304735','93A46A',clamp01(.48+y*.3-x*.2)),a
    if name.startswith('leaf_'):
        d=seg(x,y,-.1,-.83,.10,.84); leaf=gauss(d,.036)
        for j in range(6):
            yy=-.64+j*.25
            x=x+.015*(variant-1)*sin(y*5)
            for sign in (-1,1):
                endx=sign*(.62-j*.065); endy=yy+.25
                dd=seg(x,y,yy*.1,yy,endx,endy)
                leaf=mx(leaf,smooth(.055 if 'pine' in name else .095,.014,dd))
        return color('304735','8C9E62',clamp01(.50+y*.27-x*.20)),leaf
    if name.startswith('ash_'):
        f=noise(x*3+seed,y*3,seed,detail=3)
        mask=smooth(.9,.45,hyp(x/.83,y/.61)+(f-.5)*.45)
        return color('393D43','A69B87',f),mask
    if name.startswith('frost_'):
        th=atan2(y,x); arm=absv(cos(th*(3 if variant!=3 else 2)))**8
        return color('8EB8CB','EFF8FF',1-r),smooth(.95,.5,r/(.22+.75*arm))
    if name.startswith(('spark_','ember_','firefly_','mote_','glint_','bubble_')):
        if name.startswith('bubble'): return None,(gauss(r-.66,.065)*.8+gauss(x+.25,.1)*gauss(y-.35,.1)) * smooth(.9,.82,r)
        core=gauss(r,.12+.025*variant); glow=gauss(r,.38+.10*variant)*(.20+.05*variant)
        if name.startswith('glint'): return None,(mx(gauss(x,.025+.012*variant)*gauss(y,.48+.06*variant),gauss(y,.025+.012*variant)*gauss(x,.48+.06*variant))+core)*smooth(1,.85,r)
        if name.startswith(('spark','ember')):
            rr=hyp(x,y-.35); t=clamp01((.35-y)/1.25)
            a=gauss(rr,.13+.025*variant)+gauss(x+.09*sin(y*(3+variant)),.075+.025*variant)*(1-t)**2*smooth(.4,.2,y)
            return (color('FFE8A8','D35E26',t) if name.startswith('ember') else None),a
        return (color('71A36B','DBF7AF',core) if name.startswith('firefly') else None),core+glow
    if name.startswith('sky_'):
        cols=('B36F67','E0B883','657982') if 'sunset' in name else ('1B2C46','557B8B','A5BDBC') if 'dawn' in name else ('202735','474755','7B7E8B')
        lo=color(cols[0],cols[1],smooth(0,.68,1-v)); hi=rgbhex(cols[2]); t=smooth(.65,1,1-v)
        return tuple(lerp(a,c,t) for a,c in zip(lo,hi)),1
    if name.startswith('horizon_'):
        n=noise(u*9,v*3,seed,detail=3)
        return None,(1-v)**2.2*(.5+.5*n)*.83
    if name.startswith(('godray_','lightcone_')):
        s=v if name.startswith('godray') and variant==3 else 1-v
        width=.16+.68*s if variant!=2 else .18+.12*s
        xx=x/e.asp
        striation=.65+.35*noise(xx*13,s*2,seed,detail=2)
        a=smooth(1,.35,absv(xx)/width)*striation*(1-s)**.65*smooth(0,.05,s)*.68
        return None,a
    if name.startswith(('lightning_','arc_')):
        if name.startswith('arc_'): fi,t,x,y=e.atlas(8); s=(x+1)*.5; cross=y; key=seed+fi*2
        else: s=v; cross=x/e.asp; key=seed
        def jag(q,k,N):
            i=floor(q*N); f=fract(q*N)
            return (lerp(wn(i,k,0),wn(i+1,k,0),f)-.5)
        center=jag(s,key,13)*.95+jag(s,key+4,41)*.23
        width=.10 if name.endswith('_e') else .018
        a=gauss(cross-center,width)
        for j in range(3):
            start=.25+j*.23; side=(-1)**j
            branch=center+side*(s-start)*1.8+jag(s,key+j+10,27)*.17*smooth(start,start+.07,s)
            a=a+gauss(cross-branch,width*.65)*smooth(start,start+.025,s)*smooth(start+.21,start+.15,s)*.65
        return None,a*smooth(0,.025,s)*smooth(1,.975,s)
    if name.startswith('wind_'):
        return None,gauss(y-.15*sin(u*7+variant),.045)*sin(u*math.pi)**2*.8
    if name.startswith('trail_'):
        t=v; w=.12*(1-.7*t)
        return None,gauss(x+sin(t*13)*.025*(variant-1),w)*(1-t)**1.5*smooth(0,.035,t)
    if name.startswith('impact_'):
        fi,t,x,y=e.atlas(8); rr=hyp(x,y); theta=atan2(y,x)
        R=.1+.72*sqrt(t); teeth=1+.12*cos(theta*9+fi)
        return None,(gauss(rr-R*teeth,.05)+gauss(rr,.23*(1-t)+.02))*((1-t)**1.2)
    if name.startswith('vignette_'): return 0,smooth(.42,1.4,r)*.88
    if name.startswith(('light_ring','aura_')):
        a=gauss(r-.76,.045 if variant==1 else .08)
        if name.startswith('light_ring') and variant==2: a=a*(.4+.6*smooth(-.05,.05,y))
        return None,a
    if name.startswith('light_hard'): return None,smooth(.95,.76,r)
    if name.startswith('lantern_'):
        a=gauss(y,.025)*gauss(x,.5)+gauss(r,.15)+.18*gauss(r,.5)
        return color('E7AD6E','FFF1C9',gauss(r,.25)),a*smooth(1,.85,r)
    if name.startswith(('light_soft','halo_soft')): return None,gauss(r,.45 if name.startswith('light_soft') else .62)*smooth(1,.85,r)
    raise RuntimeError('Non traite '+name)
 return b

results=[]
for it in [q for q in INV if q['family']==FAMILY]:
    name=it['file']; w,h=it['size']; path=STAGE/name
    raw=it['use'] in ('normal','puddle_rgb','rain_rgb')
    if it['use']=='puddle_rgb':
        lo,hi=.35,.75
        for iteration in range(7):
            mid=(lo+hi)/2; it['threshold']=mid
            render(STAGE/'calibration.png',128,128,build(it),True)
            im=bpy.data.images.load(str(STAGE/'calibration.png'),check_existing=False)
            px=np.empty(128*128*4,np.float32); im.pixels.foreach_get(px)
            cov=float((px.reshape(-1,4)[:,0]>.5).mean()); bpy.data.images.remove(im)
            if cov>.245: lo=mid
            else: hi=mid
        it['threshold']=(lo+hi)/2
        # Reporter le meme seuil sur la normale correspondante.
        for companion in INV:
            if companion['file']==name[:-4]+'_n.png': companion['threshold']=it['threshold']
    render(path,w*2,h*2,build(it),raw)
    rawdir=STAGE/'2x'; rawdir.mkdir(exist_ok=True)
    shutil.copy2(path,rawdir/name)
    # Reduction dans Blender, sans fabrication de pixels en Python.
    img=bpy.data.images.load(str(path),check_existing=False)
    img.scale(w,h); img.filepath_raw=str(path); img.file_format='PNG'; img.save(); bpy.data.images.remove(img)
    img=bpy.data.images.load(str(path),check_existing=False)
    assert list(img.size)==[w,h]
    pixels=np.empty(w*h*4,np.float32); img.pixels.foreach_get(pixels); a=pixels.reshape(h,w,4)
    assert a[:,:,3].max()>0, name+' alpha vide'
    if it['frames']==8:
        frames=[float(a[:,j*64:(j+1)*64,3].max()) for j in range(8)]
        assert sum(v>0 for v in frames)>=6,(name,frames)
    else: frames=None
    check=dict(file=name,size=[w,h],frames=it['frames'],alpha_max=float(a[:,:,3].max()),alpha_mean=float(a[:,:,3].mean()),frame_alpha=frames)
    if it['seamless']:
        # L'ecart de bord doit etre comparable au gradient local, pas une cassure.
        channels=a if it['use'] in ('normal','rain_rgb','puddle_rgb') else a[:,:,3:4]
        seam=float(max(np.abs(channels[0]-channels[-1]).mean(),np.abs(channels[:,0]-channels[:,-1]).mean()))
        interior=float(max(np.abs(np.diff(channels,axis=0)).mean(),np.abs(np.diff(channels,axis=1)).mean()))
        check.update(seam_mean=seam,interior_gradient=interior)
        assert seam<max(.025,interior*5),(name,'raccord',seam,interior)
    if it['use']=='puddle_rgb':
        check['red_coverage']=float((a[:,:,0]>.5).mean())
        assert .02<check['red_coverage']<.6
    bpy.data.images.remove(img)
    if it['seamless']: tile2x2(path,STAGE/('tile2x2_'+name),256)
    check['sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
    assert check['sha256']!=it['sha256'],name+' inchange'
    results.append(check)
    print('R2 VERIFIED',name,flush=True)
# La famille complete doit passer avant de remplacer les livrables.
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND/('r2_'+FAMILY+'.blend')))
montage([STAGE/q['file'] for q in results if not q['file'].endswith(('_n.png','_e.png'))],STAGE/'contact.png',192,6)
for q in results: shutil.copy2(STAGE/q['file'],OUT/q['file'])
(STAGE/'validation.json').write_text(json.dumps(results,indent=2))
print('R2 FAMILY COMPLETE',FAMILY,len(results),flush=True)
