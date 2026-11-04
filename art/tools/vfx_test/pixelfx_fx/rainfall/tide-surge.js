// Rainfall (top-down, for an iso camera): a tide surging out across the floor, seen from above. An arc of foam
// races out from a point behind the origin, the water floods in behind it, then it spends itself and breaks to lace.
import { fit, stream, fly, clamp, smooth, ease } from "../../core/index.js";
import { waterFront } from "./_lib.js";

export const meta = {
  name: "Tide surge",
  desc: "Seen from above, a tide surges right: an arc of white foam races out from behind the origin throwing spray, laced water floods in, then it spends itself into lace.",
  tags: ["rainfall", "water", "wave", "tide", "top-down", "directional", "one-shot"],
  size: [168, 196],
  origin: [56, 98],
  duration: 2.4,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06090d", "#0b1219", "#16222c", "#34505e", "#6f98a8", "#8fc8d8", "#BFF4FF", "#dff9ff"],
    back: 36, // px from the origin back to where the tide starts (the caster)
    r0: 10, // starting radius
    r1: 108, // furthest reach of the crest from the start
    span: 0.72, // half the arc (radians)
    band: 8,
    seed: 5,
  },
};

const RUN = 1.35; // the crest's run, then it spends itself

export function draw(p, t, o) {
  const C = fit(o.palette, 8), cx = -o.back;
  const radius = (tt) => o.r0 + (o.r1 - o.r0) * ease.outCubic(clamp(tt / RUN));
  const R = radius(t);
  const grow = smooth(0, 0.18, t), k = grow * (1 - smooth(RUN * 0.75, meta.duration - 0.05, t));
  const trail = Math.min(R - o.r0 * 0.5, 44) * (0.5 + 0.5 * smooth(0, 0.5, t));
  waterFront(p, C, { cx, R, A: o.span, band: o.band * (0.6 + 0.4 * grow), trail, flow: t * 18, wob: t * 3, k, seed: o.seed, curl: 10, light: 0.6 });
  // spray off the crest while it runs: beads flung forward and out, slowing, then dropping out
  stream(t, 0.04, RUN * 0.9, 34, o.seed + 9, (g) => g.range(0.3, 0.6), (age, life, r) => {
    const born = t - age, Rb = radius(born), a = r.range(-o.span, o.span) * 0.92, sp = r.range(25, 70) * (1 - born / RUN * 0.6);
    const bx = cx + Math.cos(a) * Rb, by = Math.sin(a) * Rb, dir = a + r.range(-0.4, 0.4);
    const [x, y] = fly(bx, by, Math.cos(dir) * sp, Math.sin(dir) * sp, age, 0, 4.5);
    const q = age / life;
    p.dot(x, y, C[q < 0.35 ? 7 : q < 0.7 ? 6 : 5], q < 0.6 ? 1 : (1 - q) / 0.4);
    p.light(x, y, C[6], 0.45 * (1 - q));
  });
  // a flash of light where it bursts out, then a cold pool riding the crest
  if (t < 0.25) p.glow(cx + o.r0, 0, 26, C[6], 0.6 * (1 - t / 0.25));
  for (let i = -2; i <= 2; i++) {
    const a = (i / 2) * o.span * 0.85;
    p.glow(cx + Math.cos(a) * (R - 4), Math.sin(a) * (R - 4), 16, C[5], 0.2 * k);
  }
}
