// Rainfall (top-down, for an iso camera): a round sheet of flood water on the floor, seen from above, as a loop. A
// wavering foam lip, ripple rings running outward, slow glints and a deeper heart. No splash column.
import { fit, cycle, noise2, tileNoise, clamp, wrap, TAU } from "../../core/index.js";

export const meta = {
  name: "Flood disc",
  desc: "Seen from above, a round sheet of flood water: a wavering lit foam lip, ripple rings running out across it, slow glints and a darker, deeper heart.",
  tags: ["rainfall", "water", "flood", "pool", "top-down", "ground", "loop"],
  size: [208, 208],
  origin: [104, 104],
  duration: 2.4,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#070D12", "#0D1A22", "#16303F", "#35596C", "#3E86A8", "#5EC8FF", "#A8E6FF"],
    radius: 96,
    rings: 3,
    seed: 11,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, S = o.seed, ph = t / meta.duration;
  // the lip wavers: two harmonics travelling round, whole cycles per loop so it stays seamless
  const edge = (a) =>
    R * (0.95 + 0.02 * Math.sin(a * 7 + ph * TAU) + 0.015 * Math.sin(a * 13 - ph * TAU * 2) + 0.012 * noise2(Math.cos(a) * 3, Math.sin(a) * 3, S));
  const ringAt = (r) => {
    let m = 0;
    for (let i = 0; i < o.rings; i++) {
      const c = wrap((i + ph) / o.rings, 1) * R, d = r - c;
      m = Math.max(m, Math.exp(-(d * d) / 3) * (0.2 + 0.8 * (c / R)));
    }
    return m;
  };
  p.shade(-R - 3, -R - 3, R + 3, R + 3, (x, y, out) => {
    const r = Math.hypot(x, y), a = Math.atan2(y, x), e = edge(a);
    if (r > e + 2) return;
    const lit = Math.cos(a + 2.36);
    if (r > e - 1.5) {
      // the foam lip
      out.c = C[lit > -0.3 ? 6 : 5];
      out.k = 0.4;
      out.l = C[5];
      return;
    }
    const q = r / e;
    // drifting mottling, scrolled by whole lattice periods over the loop so it stays seamless
    const n = tileNoise(x * 0.05 + ph * 12, y * 0.05, 12, 0, S + 1) + 0.5 * tileNoise(x * 0.11, y * 0.11 - ph * 24, 0, 24, S + 2);
    let c = q < 0.5 ? 2 : 3; // deeper in the heart
    if (n > 0.55) c += 1;
    const rg = ringAt(r + 2.5 * noise2(Math.cos(a) * 4, Math.sin(a) * 4, S + 3)) * (n > -0.3 ? 1 : 0.3);
    if (rg > 0.55) c = Math.max(c, lit > 0 ? 5 : 4);
    else if (rg > 0.25) c = Math.max(c, 3);
    if (q > 0.92) c = Math.max(c, 4); // shallow edge catches the light
    out.c = C[clamp(c, 1, 6)];
    out.k = rg > 0.45 ? 0.3 : c >= 4 ? 0.12 : 0.03;
    out.l = C[5];
  });
  // slow glints drifting on the surface
  cycle(t, meta.duration, 14, S + 5, (g) => g.range(0.6, 1.2), (age, life, r) => {
    const a = r.range(0, TAU), d = Math.sqrt(r.next()) * R * 0.85, k = age / life, tw = Math.sin(Math.PI * k);
    const x = Math.cos(a) * d, y = Math.sin(a) * d;
    p.px(x, y, C[6]);
    if (tw > 0.6) {
      p.px(x - 1, y, C[5]);
      p.px(x + 1, y, C[5]);
    }
    p.light(x, y, C[5], 0.45 * tw);
  });
}
