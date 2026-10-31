import sys,shutil
from pathlib import Path
R=Path('C:/Users/const/Documents/Rainfall');sys.path[:0]=[str(R/'art/tools/night'),str(R/'art/tools/cel')]
import m3_build as m,cel_style as cel,bpy
from PIL import Image
W=R/'art/blender/cel/rictus_vfx_retry';m.OUT=W/'raw';m.OUT.mkdir(exist_ok=True)
source=R/'art/blender/characters/rictus.blend';copy=W/'rictus_work.blend'
if not copy.exists():shutil.copy2(source,copy)
bpy.ops.wm.open_mainfile(filepath=str(copy));m.ui.studio('m3_sprites');m.palette();m.clear()
def render(path,size,rig='TOP',target=(0,0,0),passes=True):
 s=m.iso.create_rig(rig,size,target=target,reset=False);s.camera.data.shift_y=0
 s.eevee.taa_render_samples=8;s.render.threads_mode='FIXED';s.render.threads=8
 cel.install('vfx',normals=False);m.iso.common.configure_passes(path)
 s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
 ep=list(path.parent.glob(path.stem+'_e__*.png'));assert len(ep)==1
 for p,dest in [(path,path),(ep[0],path.with_name(path.stem+'_e.png'))]:
  with Image.open(p) as im:im.convert('RGBA').resize((size,size),Image.Resampling.LANCZOS).save(dest,optimize=True,compress_level=9)
 if ep[0].exists():ep[0].unlink()
 # Save geometry only into fresh files; never overwrite an existing blend.
 blend=W/f'arc_{path.stem}_retry.blend'
 if not blend.exists():bpy.ops.wm.save_as_mainfile(filepath=str(blend))
m.render=render
atlas=m.atlas
def assemble(*args,**kw):
 atlas(*args,**kw)
 p=m.DEST/'dagger_arc/default_e.png'
 with Image.open(p) as im:im.resize((im.width//2,im.height//2),Image.Resampling.LANCZOS).save(p,optimize=True,compress_level=9)
m.atlas=assemble;m.arc();print('PASS arc render',flush=True)
