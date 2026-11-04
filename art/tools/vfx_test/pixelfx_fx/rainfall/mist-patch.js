// Rainfall (top-down, for an iso camera): a patch of low mist lying on the floor, seen from above, as a loop.
import { fit, cycle, TAU } from "../../core/index.js";

export const meta = {
  name: "Mist patch",
  desc: "Seen from above, a patch of low mist on the floor: soft lit puffs that swell, drift and thin, wisps curling at its ragged edge, a cold glow in its heart.",
  tags: ["rainfall", "weather", "mist", "fog", "top-down", "ground", "loop"],
  size: [176, 176],
  origin: [88, 88],
  duration: 3,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#05100c", "#0b1c16", "#16302a", "#2a5446", "#4a8070", "#6cc8a4", "#9CF0C8", "#d0fae8"],
    radius: 72,
    puffs: 50,
    drift: 14, // px a puff drifts over its life
    seed: 4,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), R = o.radius, S = o.seed;
  // the body: overlapping translucent puffs, each swelling then thinning as it drifts
  cycle(t, meta.duration, o.puffs, S, (g) => g.range(1.6, 2.8), (age, life, r) => {
    const a = r.range(0, TAU), d = Math.sqrt(r.next()) * R * 0.6, k = age / life;
    const da = r.range(0, TAU), x = Math.cos(a) * d + Math.cos(da) * o.drift * k, y = Math.sin(a) * d + Math.sin(da) * o.drift * k;
    const rad = r.range(R * 0.26, R * 0.42) * (0.7 + 0.5 * k), al = Math.sin(Math.PI * k);
    p.disc(x, y, rad, (dd, an) => C[dd < 0.5 && Math.cos(an + 2.36) > 0 ? 6 : dd < 0.8 ? 5 : 4], (dd) => 0.11 * al * (1 - dd * dd));
    p.glow(x, y, rad, C[5], 0.07 * al);
  });
  // wisps curling at the edge
  cycle(t, meta.duration, 10, S + 3, 1.8, (age, life, r) => {
    const a0 = r.range(0, TAU), k = age / life, dir = r.next() < 0.5 ? -1 : 1, al = Math.sin(Math.PI * k);
    for (let i = 0; i < 7; i++) {
      const u = i / 6, a = a0 + dir * (u * 0.5 + k * 0.25), rr = R * (0.66 + 0.18 * u + 0.05 * Math.sin(u * 6 + k * 3));
      p.disc(Math.cos(a) * rr, Math.sin(a) * rr, 5 - 3 * u, C[u < 0.5 ? 6 : 5], (dd) => 0.18 * al * (1 - u * 0.6) * (1 - dd));
    }
  });
  // a cold glow in the heart and a few motes hanging in it
  p.glow(0, 0, R * 0.8, C[5], 0.14);
  cycle(t, meta.duration, 8, S + 5, 1.5, (age, life, r) => {
    const a = r.range(0, TAU), d = Math.sqrt(r.next()) * R * 0.6, k = age / life;
    const x = Math.cos(a) * d, y = Math.sin(a) * d, tw = Math.sin(Math.PI * k);
    p.px(x, y, C[7]);
    p.light(x, y, C[6], 0.5 * tw);
  });
}
