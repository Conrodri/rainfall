// Rainfall (iso camera, drawn in screen space): Ardent's Pilier de flamme, a column of fire standing on its disc,
// as a loop. Its foot is the zone's disc seen by the game's camera (a 2:1 ellipse with a burning rim and glowing
// cracks); a ring of tongues stands round that rim (the far side dimmer, behind), a roaring core rises out of the
// middle and breaks into tongues at the top, flame puffs and embers stream up off it.
import { fit, clamp, smooth, tileNoise, noise2, rng, wrap, TAU, WHITE, mix } from "../../core/index.js";
import { hotFirst, flameTongue, firePuff, smokePuff, ember, floorLight, noiseFor, looped, LAYERS, BACK_LAYERS, BIG_LAYERS } from "../fire/_lib.js";
import { PAL, SQ } from "./ardent-nova.js";

export const meta = {
  name: "Ardent flame column",
  desc: "Iso pillar of fire, looped: a burning 2:1 floor ellipse, a ring of tongues round its rim, a roaring core rising out of it and breaking into tongues, puffs and embers streaming up.",
  tags: ["rainfall", "fire", "pillar", "column", "zone", "iso", "loop"],
  size: [78, 118],
  origin: [39, 100],
  duration: 1,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: PAL,
    radius: 20, // px on the floor
    height: 50, // px, top of the core
    seed: 5,
  },
};

export function draw(p, t, o) {
  const F = fit(o.palette, 9), H = hotFirst(F), R = o.radius, HC = o.height, S = o.seed * 19, D = meta.duration, ph = t / D;
  const N = noiseFor(D), NT = (rate, seed, off) => N(t, rate, seed, off);
  const glowC = mix(H[3], WHITE, 0.1);
  // the foot: the disc burning, a bright rim, cracks of heat
  const E = R + 3;
  p.shade(-E, -E * SQ - 1, E, E * SQ + 1, (x, y, out) => {
    const gy = y / SQ, g = Math.hypot(x, gy);
    if (g > R + 1.5) return;
    const q = g / R, crack = Math.abs(tileNoise(x * 0.18 + 30, gy * 0.18 + 30, 0, 0, S)) < 0.07;
    if (q > 0.86) {
      out.c = H[(Math.sin(TAU * (ph * 2 + Math.atan2(gy, x) / TAU * 3)) > 0) ? 2 : 3];
      out.k = 0.5;
      out.l = H[3];
      return;
    }
    out.c = crack ? H[2] : q < 0.5 ? H[4] : H[5];
    out.k = crack ? 0.5 : 0.25;
    out.l = H[3];
  });
  floorLight(p, 0, 0, R * 2.2, R * 2.2 * SQ, glowC, 0.45);
  // the ring of tongues round the rim: back half first (behind the core), front half after
  const ring = [];
  for (let i = 0; i < 14; i++) {
    const a = (i / 14) * TAU + 0.2, g = rng(o.seed, i, 5);
    ring.push({ x: Math.cos(a) * R * 0.92, y: Math.sin(a) * R * 0.92 * SQ, h: HC * g.range(0.28, 0.45), off: g.next(), n: S + i * 11, lean: -Math.cos(a) * 3 });
  }
  const tongue = (q) => {
    const k = 0.75 + 0.25 * Math.sin(TAU * (ph * 2 + q.off));
    flameTongue(p, q.x, q.y, q.h * k, 2.4 + q.h * 0.1, q.lean, NT, q.n, H, q.y < 0 ? BACK_LAYERS : LAYERS);
  };
  for (const q of ring) if (q.y < 0) tongue(q);
  // the core: rows of flame rising, hottest in the middle, wavering, thinning to tongues at the top
  const W = R * 0.78;
  for (let y = 0; y >= -HC; y--) {
    const v = -y / HC, cx = N(t, 2, S + 1, v * 3) * 2 * v;
    const swell = 1 + 0.25 * tileNoise(v * 6 - ph * 6, 0.5, 6, 0, S + 2);
    const half = W * swell * (1 - smooth(0.6, 1, v) * 0.85) * (0.9 + 0.1 * Math.min(1, -y / 4));
    if (half < 0.4) continue;
    for (let x = Math.floor(cx - half); x <= Math.ceil(cx + half); x++) {
      const qx = Math.abs(x + 0.5 - cx) / half;
      if (qx > 1) continue;
      const streak = tileNoise((x - cx) * 0.35 + 10, v * 8 - ph * 8, 0, 8, S + 3);
      let lvl = qx < 0.25 ? 0 : qx < 0.5 ? 1 : qx < 0.72 ? 2 : qx < 0.9 ? 4 : 5;
      lvl += Math.round(v * 2.2) + (streak > 0.35 ? -1 : streak < -0.35 ? 1 : 0);
      p.px(x, y, H[clamp(lvl, 0, 7)]);
    }
    if (y % 8 === 0) p.glow(cx, y, half * 2.6 + 6, glowC, 0.2);
  }
  // the crown: tongues breaking off the top
  for (let i = 0; i < 4; i++) {
    const dx = (i - 1.5) * W * 0.5, k = 0.7 + 0.3 * Math.sin(TAU * (ph * 3 + i * 0.27));
    flameTongue(p, dx, -HC * 0.82, HC * 0.28 * k * (i === 1 || i === 2 ? 1 : 0.7), W * 0.38, -dx * 0.4, NT, S + 40 + i, H, BIG_LAYERS);
  }
  for (const q of ring) if (q.y >= 0) tongue(q);
  // puffs, smoke and embers streaming up
  looped(t, D, 8, o.seed + 3, (r) => ({ x: r.range(-W, W), life: r.range(0.45, 0.75), s: r.range(2.4, 4), dx: r.range(-5, 5) }), (q, age) => {
    const k = age / q.life;
    firePuff(p, q.x + q.dx * k, -HC * 0.75 - age * 60, 1 - k, q.s, 0.3, H);
  });
  looped(t, D, 4, o.seed + 4, (r) => ({ x: r.range(-W, W) * 0.6, life: r.range(0.8, 1.1), s: r.range(3, 4.5) }), (q, age) => {
    smokePuff(p, q.x + age * 4, -HC - 4 - age * 22, 1 - age / q.life, q.s, 0, false, 0.6);
  });
  looped(t, D, 18, o.seed + 5, (r) => ({ x: r.range(-R, R), y0: r.range(-HC * 0.9, -4), life: r.range(0.5, 0.9), vy: r.range(40, 80), ph: r.range(0, 6), w: r.range(-12, 12) }), (q, age) => {
    ember(p, q.x + q.w * age + Math.sin(age * 7 + q.ph) * 1.5, q.y0 - age * q.vy, 1 - age / q.life, 1, [H[0], H[1], H[3], H[5]], age * 30 + q.ph);
  });
  p.glow(0, -HC * 0.45, HC * 0.8, glowC, 0.3);
}
