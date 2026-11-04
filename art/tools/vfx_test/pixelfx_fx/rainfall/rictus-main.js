// Rainfall (screen space, for an iso camera): the Montreur's ghostly hand slaps the floor. Not flat: an angular,
// porcelain-pale hand (palm down, fingers spread) drops from above on its threads and slams; on contact a 2:1 ellipse
// (the slap's reach on the floor, `radius` px across) cracks out, dust and chips jump, the threads snap taut and the
// hand fades back up. Pivot = the floor at the point of impact. One-shot.
import { fit, burst, fly, clamp, smooth, ease, TAU, noise2 } from "../../core/index.js";

export const meta = {
  name: "Rictus Montreur hand",
  desc: "A ghostly porcelain hand drops from above on its threads and slaps the floor: a cracked 2:1 ring flashes out, dust and chips jump, the threads snap, the hand fades back up.",
  tags: ["rainfall", "rictus", "slam", "hand", "ghost", "impact", "iso", "one-shot"],
  size: [76, 96],
  origin: [38, 70],
  duration: 0.7,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0a0d0d", "#141b1b", "#26312f", "#46585a", "#6f8f8a", "#9FC8C0", "#c9e3dd"],
    radius: 22,
    seed: 71,
  },
};

const HIT = 0.16;

// hand outline seen from 30° above, palm down, wrist up-left: points around (0,0) = middle of the palm's heel line
const HAND = [
  [-9, -2], [-13, -8], [-11, -10], [-6, -6], // thumb
  [-6, -12], [-7, -22], [-4, -23], [-2, -13], // index
  [-1, -24], [2, -25], [3, -13], // middle
  [5, -23], [8, -22], [7, -12], // ring
  [10, -19], [12, -17], [9, -8], // little
  [9, -1], [5, 3], [-5, 3],
];

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, S = o.seed;
  // the hand: falls from 46 px up, slaps, holds, then rises and fades
  const fall = t < HIT ? 1 - ease.inCubic(clamp(t / HIT)) : 0;
  const rise = smooth(HIT + 0.12, meta.duration * 0.85, t);
  const lift = -46 * fall - 30 * rise, ha = t < HIT ? 0.55 + 0.45 * (t / HIT) : 1 - rise;
  const sq = t >= HIT && t < HIT + 0.08 ? 1.0 + 0.25 * (1 - (t - HIT) / 0.08) : 1; // squash on impact
  if (ha > 0.02) {
    const pts = HAND.map(([x, y]) => [x * sq, y / sq * 0.75 + lift + 2]);
    p.poly(pts, (x, y) => {
      const lit = (x < 0 ? 1 : 0) + (y < lift - 12 ? 1 : 0);
      return C[4 + Math.min(2, lit)];
    }, 0.92 * ha);
    p.polyline([...pts, pts[0]], C[6], 0.8 * ha);
    p.glow(0, lift - 8, 22, C[5], 0.35 * ha);
    // the threads holding it, up out of frame
    for (const fx of [-6, 0, 6]) {
      const taut = t >= HIT && t < HIT + 0.1 ? 1 : 0.5;
      p.line(fx, lift - 20, fx * 0.6, -70, C[5], 0.5 * taut * ha);
    }
  }
  const a = t - HIT;
  if (a < 0) return;
  // the crack ring on the floor: a 2:1 ellipse racing out to R, jagged, lit from the upper left
  const k = clamp(a / 0.14), Rf = R * (0.3 + 0.7 * ease.outCubic(k)), fade = 1 - smooth(0.12, 0.45, a);
  if (fade > 0) {
    p.shade(-Rf - 3, -Rf / 2 - 3, Rf + 3, Rf / 2 + 3, (x, y, out) => {
      const e = Math.hypot(x, y * 2), an = Math.atan2(y * 2, x);
      const jit = noise2(Math.cos(an) * 4, Math.sin(an) * 4, S) * 2.2;
      const d = Rf - e + jit;
      if (d < -1 || d > 4) {
        // cracks running out from the centre
        const cr = Math.abs(Math.sin(an * 7 + noise2(e / 6, an, S + 1) * 1.5));
        if (e < Rf && cr < 0.08 && fade > 0.4) { out.c = C[5]; out.k = 0.3 * fade; out.l = C[5]; }
        return;
      }
      const lit = Math.cos(an + 2.36);
      out.c = C[d < 1.5 ? (lit < -0.4 ? 5 : 6) : 4];
      out.k = 0.5 * fade;
      out.l = C[5];
    });
    p.glow(0, 0, R * 1.2, C[5], 0.55 * fade);
  }
  // dust and chips jumping off the ring
  burst(22, S + 3, (r) => {
    const an = r.range(0, TAU), life = r.range(0.25, 0.45);
    if (a > life) return;
    const sp = r.range(25, 60), x0 = Math.cos(an) * R * 0.8, y0 = Math.sin(an) * R * 0.4;
    const [x, y] = fly(x0, y0, Math.cos(an) * sp, Math.sin(an) * sp * 0.5 - r.range(40, 90), a, 300, 2), q = a / life;
    p.dot(x, y, C[q < 0.4 ? 6 : 4], 1 - q * 0.6);
    p.light(x, y, C[5], 0.25 * (1 - q));
  });
}
