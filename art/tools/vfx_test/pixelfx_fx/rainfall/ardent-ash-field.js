// Rainfall (iso camera, drawn in screen space): Ardent's Cendres, a carpet of burning ash on the floor, as a loop.
// The footprint is the zone's disc seen by the game's camera (a 2:1 ellipse, ragged rim); on it, grey ash with
// cinders breathing red and seams of heat; out of it, low flames licking up here and there, smoke wisps curling up
// and embers rising: a floor that burns, with volume, not a flat decal.
import { fit, clamp, smooth, noise2, tileNoise, rng, rand, wrap, TAU, mix, WHITE } from "../../core/index.js";
import { hotFirst, flameTongue, smokePuff, ember, floorLight, noiseFor, looped, LAYERS, BACK_LAYERS } from "../fire/_lib.js";
import { SQ } from "./ardent-nova.js";

export const meta = {
  name: "Ardent ash field",
  desc: "Iso burning ash zone, looped: grey ash over a 2:1 floor ellipse, cinders breathing red, seams of heat, low flames licking up, smoke wisps and rising embers.",
  tags: ["rainfall", "fire", "ash", "zone", "ground", "iso", "loop"],
  size: [112, 92],
  origin: [56, 58],
  duration: 2,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0c0b0a", "#1a1816", "#2e2a27", "#4a423c", "#6b5446", "#a8481a", "#FF7319"],
    radius: 44,
    flames: 15,
    seed: 6,
  },
};

export function draw(p, t, o) {
  const F = fit(o.palette, 9), H = hotFirst(F), R = o.radius, S = o.seed * 17, D = meta.duration, ph = t / D;
  const N = noiseFor(D), NT = (rate, seed, off) => N(t, rate, seed, off);
  const rim = (a) => R * (0.9 + 0.1 * tileNoise(((a / TAU + 1) % 1) * 9, 0.5, 9, 0, S));
  const E = R + 2;
  // the ash: charred floor, flecks of grey ash, a dense bed of cinders breathing red, seams of heat pulsing along
  p.shade(-E, -E * SQ - 1, E, E * SQ + 1, (x, y, out) => {
    const gy = y / SQ, g = Math.hypot(x, gy), a = Math.atan2(gy, x), e = rim(a);
    if (g > e) return;
    const q = g / e, n = tileNoise(x * 0.13 + 20, gy * 0.13 + 20, 0, 0, S), m = tileNoise(x * 0.45 + 5, gy * 0.45 + 5, 0, 0, S + 1);
    const seam = Math.abs(tileNoise(x * 0.07 + 40, gy * 0.07 + 40, 0, 0, S + 2)) < 0.05;
    const cell = rand(Math.floor(x / 2), Math.floor(gy / 2), S + 3);
    const breath = 0.5 + 0.5 * Math.sin(TAU * (ph * 2 + cell * 3));
    const edge = 1 - smooth(0.7, 1, q);
    if (seam && q < 0.9) {
      const run = 0.5 + 0.5 * Math.sin(TAU * (ph * 2 - (x + gy) * 0.04));
      out.c = run > 0.65 ? H[0] : run > 0.3 ? H[1] : H[2];
      out.k = 0.4 + 0.4 * run;
      out.l = H[2];
      return;
    }
    if (cell < 0.16 * edge + 0.04 && n > -0.35) {
      out.c = breath > 0.7 ? H[0] : breath > 0.35 ? H[1] : H[2];
      out.k = 0.3 + 0.45 * breath;
      out.l = H[3];
      return;
    }
    if (q > 0.85 && m < 0) return; // ragged rim
    if (m < -0.45) {
      out.c = H[(-x - gy) > 0 ? 3 : 4]; // grey ash flecks, lit from the upper left
      return;
    }
    out.c = n > -0.3 ? H[5] : H[7];
    out.k = 0.06 * edge;
    out.l = H[5];
  });
  floorLight(p, 0, 0, R * 1.1, R * 1.1 * SQ, H[3], 0.45);
  // the low flames: they gutter up, burn a while and die, each at its own spot
  const spots = [];
  for (let i = 0; i < o.flames; i++) {
    const g = rng(o.seed, i, 3), rr = R * (0.15 + 0.7 * Math.sqrt(g.next())), a = g.next() * TAU;
    spots.push({ x: Math.cos(a) * rr, y: Math.sin(a) * rr * SQ, h: g.range(7, 15), off: g.next(), n: i * 13 + S });
  }
  spots.sort((a, b) => a.y - b.y);
  for (const s of spots) {
    const k = wrap(ph * 2 + s.off, 1), life = Math.sin(Math.PI * clamp(k / 0.8));
    if (life <= 0.05) continue;
    flameTongue(p, s.x, s.y, s.h * life, 1.4 + s.h * 0.18, 0, NT, s.n, H, s.y < 0 ? BACK_LAYERS : LAYERS);
    p.glow(s.x, s.y - s.h * 0.4 * life, 6 + s.h * 0.6, H[3], 0.18 * life);
  }
  // smoke wisps curling up off the ash, drifting with the draught
  looped(t, D, 6, o.seed + 1, (r) => {
    const rr = R * 0.8 * Math.sqrt(r.next()), a = r.next() * TAU;
    return { x: Math.cos(a) * rr, y: Math.sin(a) * rr * SQ, life: r.range(1.2, 1.8), s: r.range(2.4, 4), dx: r.range(-6, 6) };
  }, (q, age) => {
    const k = age / q.life;
    smokePuff(p, q.x + q.dx * k + Math.sin(k * 5 + q.x) * 2, q.y - 4 - age * 18, 1 - k, q.s, 0, false, 0.7);
  });
  // embers rising and wandering
  looped(t, D, 22, o.seed + 2, (r) => {
    const rr = R * 0.9 * Math.sqrt(r.next()), a = r.next() * TAU;
    return { x: Math.cos(a) * rr, y: Math.sin(a) * rr * SQ, life: r.range(0.7, 1.3), vy: r.range(16, 34), w: r.range(-1, 1), ph: r.range(0, 6) };
  }, (q, age) => {
    const k = age / q.life;
    ember(p, q.x + Math.sin(age * 6 + q.ph) * 2 + q.w * age * 8, q.y - age * q.vy, 1 - k, 1, [H[1], H[2], H[4], H[6]], age * 30 + q.ph);
  });
}
