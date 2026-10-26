"""Blender background: recolor the existing cel HUD fill, preserving its pixels."""
from pathlib import Path
import struct
import sys
import zlib

import bpy

ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT / 'art/tools/cel'), str(ROOT / 'art/tools/iso')]
import cel_style as cel


def png(path, width, height, rgba):
    def chunk(kind, data):
        return (struct.pack('>I', len(data)) + kind + data
                + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff))
    rows = b''.join(b'\0' + bytes(rgba[y*width*4:(y+1)*width*4])
                    for y in range(height))
    path.write_bytes(b'\x89PNG\r\n\x1a\n'
                     + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b''))


cel.install('ui', normals=False)
cel.setup_scene(samples=8)
folder = ROOT / 'game/assets/sprites/ui/da'
source = bpy.data.images.load(str(folder / 'bar_fill_hp.png'), check_existing=False)
source.colorspace_settings.name = 'Non-Color'
w, h = source.size
pixels = list(source.pixels[:])
raw = bytearray(round(max(0, min(1, v))*255) for v in pixels)
# Blender pixels start at the bottom. Work in PNG top-to-bottom order.
original = b''.join(raw[y*w*4:(y+1)*w*4] for y in reversed(range(h)))
result = bytearray(original)
for y in range(h):
    # Existing raised rim and lower bevel; no new silhouette or texture.
    target = (180, 230, 166) if 1 <= y <= 7 else ((47, 122, 54) if y >= 28 else (82, 196, 90))
    reference = original[(y*w+w//2)*4] if y <= 7 or y >= 28 else 136
    for x in range(w):
        i = (y*w+x)*4
        if not original[i+3]:
            continue
        ratio = original[i] / max(1, reference)
        result[i:i+3] = bytes(round(min(255, c*ratio)) for c in target)
output = folder / 'bar_fill_hp_green.png'
png(output, w, h, result)
assert original[3::4] == result[3::4], 'alpha changed'
assert result[(16*w+w//2)*4:(16*w+w//2)*4+3] == bytes((82, 196, 90))

# Contact sheet assembled directly from the delivered pixels on the requested ground.
cw, ch = w+32, 3*(h+24)+8
background = (11, 9, 7)
contact = bytearray((*background, 255)) * (cw*ch)
for row, fraction in enumerate((1, .6, .2)):
    for y in range(h):
        for x in range(round(w*fraction)):
            src = (y*w+x)*4
            dst = ((row*(h+24)+16+y)*cw+16+x)*4
            a = result[src+3]/255
            contact[dst:dst+3] = bytes(round(result[src+c]*a + background[c]*(1-a)) for c in range(3))
png(ROOT / 'art/tools/night/_uxhudb_contact.png', cw, ch, contact)
def luminance(rgb):
    values = [v/255 for v in rgb]
    values = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in values]
    return sum(v*k for v, k in zip(values, (.2126, .7152, .0722)))
contrast = (luminance((47, 122, 54))+.05)/(luminance(background)+.05)
assert contrast >= 3
print(f'PASS {w}x{h}; alpha identical; contrast minimum palette {contrast:.2f}:1; {output.stat().st_size} bytes')
