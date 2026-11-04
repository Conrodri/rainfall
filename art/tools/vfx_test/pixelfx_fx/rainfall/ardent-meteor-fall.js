// Rainfall (iso camera, drawn in screen space): one of Ardent's meteors falling out of the sky onto its mark, timed
// to land at the end (the impact is ardent-meteor-impact). A rock wrapped in flame streaks down from high up on
// the upper left, a comet tail of fire and smoke behind it, sparks shed; its shadow and a hot spot grow on the
// floor (a 2:1 ellipse) under where it will land.
import { fit, clamp, smooth, ease, noise, rng, TAU, WHITE, mix } from "../../core/index.js";
import { hotFirst, flameBlade, firePuff, smokePuff, solid, LAYERS, BIG_LAYERS } from "../fire/_lib.js";
import { PAL, SQ } from "./ardent-nova.js";

export const meta = {
  name: "Ardent meteor fall",
  desc: "Iso meteor fall: a flaming rock streaks down from high on the upper left onto its mark, a comet tail of fire and smoke behind it, its shadow growing on the floor.",
  tags: ["rainfall", "fire", "meteor", "fall", "iso", "one-shot"],
  size: [124, 212],
  origin: [96, 194],
  duration: 0.8,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: PAL,
    from: [-74, -168], // where it comes into view, px from the mark
    show: 0.36, // s before landing it comes into view
    rock: 7,
    seed: 2,
  },
};

export function draw(p, t, o) {
  const F = fit(o.palette, 9), H = hotFirst(F), D = meta.duration, HIT = D - 0.03, T0 = HIT - o.show;
  if (t >= HIT) return;
  const [fx, fy] = o.from, len = Math.hypot(fx, fy), ux = -fx / len, uy = -fy / len;
  // on the floor: the shadow and the hot spot it is about to make, growing as it comes
  const near = smooth(T0 - 0.25, HIT, t);
  if (near > 0) {
    const r = 3 + 9 * near;
    if (near > 0.25) p.ellipse(0, 0, r, r * SQ, F[1]);
    p.glow(0, 0, r * 2.2, H[3], 0.35 * near * near);
  }
  if (t < T0) {
    // a glint high up while it is still far
    const k = smooth(0, T0, t);
    p.glow(fx, fy, 4 + 3 * k, H[2], 0.4 * k);
    return;
  }
  const u = ease.inQuad(clamp((t - T0) / o.show)), x = fx * (1 - u), y = fy * (1 - u);
  const NZ = (rate, seed, off) => noise(t * rate + off, seed);
  // smoke and sparks left along the path
  for (let i = 0; i < 14; i++) {
    const g = rng(o.seed, i), tb = T0 + g.next() * (t - T0), ub = ease.inQuad(clamp((tb - T0) / o.show)), age = t - tb;
    if (age > 0.4) continue;
    const bx = fx * (1 - ub) + g.range(-2, 2), by = fy * (1 - ub) + g.range(-2, 2) - age * 12;
    if (i % 3 === 0) smokePuff(p, bx, by, 1 - age / 0.4, g.range(2, 3.5));
    else p.px(bx + g.range(-3, 3) * age * 10, by + age * 30, age < 0.15 ? H[1] : H[4]);
  }
  // the comet tail: a long blade of flame trailing back up the path, a shorter hotter one inside it
  const tail = 26 + 22 * u;
  flameBlade(p, x, y, -ux, -uy, tail, o.rock * 1.25, 2, NZ, 11, H, BIG_LAYERS);
  flameBlade(p, x, y, -ux, -uy, tail * 0.55, o.rock * 0.8, -1, NZ, 23, H, LAYERS);
  for (let k = 0; k < 4; k++) firePuff(p, x - ux * (8 + k * 7) + NZ(5, k) * 2, y - uy * (8 + k * 7), 0.8 - k * 0.18, 2.4 - k * 0.3, 0.2, H);
  // the rock: dark, cracked, lit white-hot on its leading face
  solid(p, x, y, o.rock, F[2]);
  solid(p, x - 0.8, y - 0.8, o.rock * 0.72, F[3]);
  solid(p, x + ux * 1.6, y + uy * 1.6, o.rock * 0.55, H[1]);
  p.px(x - 2, y + 1, H[3]), p.px(x + 1, y - 2, H[2]);
  p.glow(x, y, 16 + 6 * u, H[2], 0.6);
  p.glow(x - ux * tail * 0.5, y - uy * tail * 0.5, tail * 0.6, H[4], 0.25);
}
