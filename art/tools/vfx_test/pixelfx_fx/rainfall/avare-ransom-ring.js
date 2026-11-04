// Rainfall (top-down, for an iso camera): Avare's Rançon seen from above. One-shot. A blow on the floor: a gold shock
// ring races out to `radius` px, and a ring of seals stamps down behind it (the marks): angular coin-stamps that flash,
// hold and cool, cracks under the blow, a burst of gold dust.
import { fit, clamp, smooth, ease, burst, fly, noise2, TAU } from "../../core/index.js";

export const meta = {
  name: "Avare ransom ring",
  desc: "Seen from above, a blow on the floor: a gold shock ring races out, a ring of angular seals stamps down behind it, flashes and cools, gold dust bursts.",
  tags: ["rainfall", "slam", "ring", "mark", "gold", "top-down", "ground", "one-shot"],
  size: [112, 112],
  origin: [56, 56],
  duration: 0.95,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0e0a04", "#1c1408", "#33260f", "#5c4620", "#8f6e2e", "#F2C14E", "#F8DE92"],
    radius: 48,
    seals: 8,
    seed: 4,
  },
};

const RUN = 0.3;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, S = o.seed, D = meta.duration;
  const Rf = R * (0.12 + 0.88 * ease.outCubic(clamp(t / RUN))), fade = 1 - smooth(RUN * 0.7, D * 0.7, t);
  // the shock ring and a dim wash inside it
  p.shade(-R - 3, -R - 3, R + 3, R + 3, (x, y, out) => {
    const r = Math.hypot(x, y), a = Math.atan2(y, x), jit = noise2(Math.cos(a) * 3, Math.sin(a) * 3, S) * 1.4;
    const d = Rf - r + jit, B = 6;
    if (d >= -1 && d < B && fade > 0.03) {
      const q = Math.max(0, d) / B, lit = Math.cos(a + 2.36);
      let c = q < 0.2 ? 6 : q < 0.55 ? 5 : 4;
      if (lit < -0.4 && c > 4) c -= 1;
      out.c = C[c];
      out.a = clamp(fade * 1.4, 0, 1);
      out.k = (q < 0.4 ? 0.5 : 0.2) * fade;
      out.l = C[5];
      return;
    }
    if (r < Rf && fade > 0.03) {
      out.k = 0.07 * fade * (r / R);
      out.l = C[4];
    }
  });
  // cracks under the blow
  const ck = 1 - smooth(0.3, D, t);
  burst(5, S + 1, (r, i) => {
    let a = (i / 5) * TAU + r.range(-0.4, 0.4), x = 0, y = 0;
    const l = R * 0.12 * ease.outExpo(clamp(t / 0.08));
    for (let s = 0; s < 3; s++) {
      a += r.range(-0.6, 0.6);
      const nx = x + Math.cos(a) * l, ny = y + Math.sin(a) * l;
      p.line(x, y, nx, ny, C[t < 0.2 ? 5 : 2], ck);
      x = nx;
      y = ny;
    }
  });
  // the seals: angular coin-stamps (a lozenge in a ring) stamped down as the ring passes
  for (let i = 0; i < o.seals; i++) {
    const a = (i / o.seals) * TAU + 0.3, rr = R * 0.72, sx = Math.cos(a) * rr, sy = Math.sin(a) * rr;
    const born = RUN * ease.outCubic(0.7) * 0.75, age = t - born - i * 0.012;
    if (age < 0) continue;
    const pop = ease.outBack(clamp(age / 0.1)), cool = smooth(0.08, D - born, age), k = 1 - smooth(D * 0.55, D, t);
    if (k <= 0.02) continue;
    const s = 4.2 * pop;
    p.shade(sx - s - 1, sy - s - 1, sx + s + 1, sy + s + 1, (x, y, out) => {
      const dx = x - sx, dy = y - sy, rr2 = Math.hypot(dx, dy), dia = Math.abs(dx) + Math.abs(dy);
      const ring = rr2 <= s && rr2 > s - 1.3, lozenge = dia < s * 0.62 && dia > s * 0.62 - 1.6, core = dia < 1.2;
      if (!ring && !lozenge && !core) return;
      const hot = cool < 0.4;
      out.c = C[ring ? (dx + dy < 0 ? (hot ? 6 : 5) : 4) : hot ? 6 : 5];
      out.a = k;
      out.k = (hot ? 0.5 : 0.2) * k;
      out.l = C[5];
    });
    p.glow(sx, sy, 8, C[5], 0.4 * (1 - cool) * k);
  }
  // gold dust kicked up by the blow
  burst(30, S + 3, (r) => {
    const a = r.range(0, TAU), born = r.range(0, 0.12), age = t - born, life = r.range(0.3, 0.55);
    if (age < 0 || age > life) return;
    const sp = r.range(40, 120), [x, y] = fly(0, 0, Math.cos(a) * sp, Math.sin(a) * sp, age, 0, 4.5), k = age / life;
    p.dot(x, y, C[k < 0.35 ? 6 : 5], 1 - k);
    p.light(x, y, C[5], 0.3 * (1 - k));
  });
  p.glow(0, 0, R * 0.5, C[6], 0.85 * (1 - smooth(0, 0.22, t)));
}
