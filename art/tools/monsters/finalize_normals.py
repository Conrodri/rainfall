"""Finalisation des normales filtrees, dans Blender exclusivement.
Renormalise les vecteurs apres reduction et remet le fond transparent neutre.
"""
import bpy,sys
from pathlib import Path
import numpy as np
assert bpy.app.background
for filename in sys.argv[sys.argv.index('--')+1:]:
    path=Path(filename);im=bpy.data.images.load(str(path),check_existing=False)
    im.colorspace_settings.name='Non-Color';im.alpha_mode='STRAIGHT'
    px=np.empty(len(im.pixels),dtype=np.float32);im.pixels.foreach_get(px);px=px.reshape((-1,4))
    normals=px[:,:3]*2-1;lengths=np.linalg.norm(normals,axis=1,keepdims=True)
    px[:,:3]=normals/np.maximum(lengths,1e-8)*.5+.5
    px[px[:,3]==0,:3]=(128/255,128/255,1)
    im.pixels.foreach_set(px.ravel());im.filepath_raw=str(path);im.file_format='PNG';im.save();bpy.data.images.remove(im)
    print('NORMAL_FINAL',path)
