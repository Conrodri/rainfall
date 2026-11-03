// Exporte un effet pixelfx en deux couches brutes pour les VFX de TEST (voir build_lit.py) :
//   base.rgba  : la couleur seule (sans lumière), RGBA 8 bits, image après image
//   light.rgba : le tampon de lumière additive (halo), RGB 8 bits + A = 255
//   info.json  : w, h, n, fps, loop, pivot
// Usage : node export_lit.mjs <id> <outdir> [optsJSON] [light]
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const PFX = process.env.PIXELFX_DIR ?? "C:/Users/const/Documents/pixelfx";
const lib = await import(pathToFileURL(join(PFX, "tools/lib/fxlib.mjs")).href);
const { composite } = await import(pathToFileURL(join(PFX, "src/core/fx.js")).href);

const [id, out, optsJson = "{}", lightArg] = process.argv.slice(2);
const options = JSON.parse(optsJson);
if (lightArg !== undefined) options.light = +lightArg;
const fx = await lib.loadEffect(id);
const r = lib.renderFrames(fx, { actor: false, bg: "none", options });
const { w, h } = r, px = w * h;
const base = Buffer.alloc(px * 4 * r.frames.length);
const light = Buffer.alloc(px * 4 * r.frames.length);
const zero = new Uint32Array(px);
r.frames.forEach((f, i) => {
  const rgba = composite({ w, h, color: f.raw, light: zero }, new Uint8ClampedArray(px * 4), null);
  base.set(rgba, i * px * 4);
  for (let p = 0; p < px; p++) {
    const l = f.light[p], j = (i * px + p) * 4;
    light[j] = l & 255; light[j + 1] = (l >>> 8) & 255; light[j + 2] = (l >>> 16) & 255; light[j + 3] = 255;
  }
});
mkdirSync(out, { recursive: true });
writeFileSync(join(out, "base.rgba"), base);
writeFileSync(join(out, "light.rgba"), light);
writeFileSync(join(out, "info.json"), JSON.stringify({ id, w, h, n: r.frames.length, fps: r.fps, loop: !!fx.meta.loop, pivot: fx.meta.origin }));
console.log(`${id} ${r.frames.length}f ${w}x${h}`);
