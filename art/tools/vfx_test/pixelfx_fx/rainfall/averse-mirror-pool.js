// Rainfall (top-down, for an iso camera): Averse's Mirror Puddle, a round sheet of still black water on the floor,
// seen from above, as a loop. A lit lip, a pale band of reflected sky sliding across the mirror, rings from rain
// drops opening on it, a few glints. No splash column.
import { fit, cycle, noise2, tileNoise, clamp, wrap, TAU } from "../../core/index.js";

export const meta = {
  name: "Averse mirror pool",
  desc: "Seen from above, a round mirror of black water: a lit lip, a pale band of reflected sky drifting across, drop rings opening on it, glints.",
  tags: ["rainfall", "water", "puddle", "mirror", "pool", "top-down", "ground", "loop"],
  size: [104, 104],
  origin: [52, 52],
  duration: 2.0,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#04090f", "#08141f", "#0f2a38", "#2f6577", "#2a9fb5", "#5FD4E8", "#9fe8f2"],
    radius: 48,
    seed: 17,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, S = o.seed, ph = t / meta.duration;
  const edge = (a) => R * (0.95 + 0.025 * Math.sin(a * 6 + ph * TAU) + 0.015 * noise2(Math.cos(a) * 3, Math.sin(a) * 3, S));
  const band = wrap(ph * 1.6 * R, 1.6 * R) - 0.8 * R; // reflected sky band, sliding along the diagonal
  p.shade(-R - 2, -R - 2, R + 2, R + 2, (x, y, out) => {
    const r = Math.hypot(x, y), a = Math.atan2(y, x), e = edge(a);
    if (r > e + 1.5) return;
    const lit = Math.cos(a + 2.36);
    if (r > e - 1.5) {
      out.c = C[lit > -0.2 ? 6 : 4];
      out.k = lit > -0.2 ? 0.35 : 0.1;
      out.l = C[5];
      return;
    }
    const q = r / e;
    const n = tileNoise(x * 0.06 + ph * 10, y * 0.06, 10, 0, S + 1);
    let c = q < 0.6 ? 1 : 2;
    if (n > 0.5) c += 1;
    const dg = (x + y) * 0.7071 - band;
    if (Math.abs(dg) < 4 + 2 * n) c = Math.max(c, Math.abs(dg) < 1.5 ? 4 : 3);
    if (q > 0.9) c = Math.max(c, 3);
    out.c = C[clamp(c, 1, 6)];
    out.k = c >= 4 ? 0.18 : 0.04;
    out.l = C[5];
  });
  // drop rings opening on the mirror
  cycle(t, meta.duration, 9, S + 3, 0.7, (age, life, r) => {
    const a = r.range(0, TAU), d = Math.sqrt(r.next()) * R * 0.8, k = age / life;
    const cx = Math.cos(a) * d, cy = Math.sin(a) * d, rr = 1 + 7 * k;
    for (let i = 0; i < 14; i++) {
      const b = (i / 14) * TAU;
      p.dot(cx + Math.cos(b) * rr, cy + Math.sin(b) * rr, C[k < 0.3 ? 5 : 4], 1 - k);
    }
    p.light(cx, cy, C[5], 0.25 * (1 - k));
  });
  cycle(t, meta.duration, 8, S + 5, (g) => g.range(0.5, 1.0), (age, life, r) => {
    const a = r.range(0, TAU), d = Math.sqrt(r.next()) * R * 0.85, tw = Math.sin(Math.PI * age / life);
    const x = Math.cos(a) * d, y = Math.sin(a) * d;
    p.px(x, y, C[6]);
    p.light(x, y, C[5], 0.4 * tw);
  });
}
