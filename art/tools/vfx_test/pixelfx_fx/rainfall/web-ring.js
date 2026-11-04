// Rainfall (top-down, for an iso camera): a round web laid flat on the floor, seen from above, as a loop. Spokes run
// from the hub to a glowing rim, spiral threads cross them and dew beads slide out along the spokes.
import { fit, cycle, TAU } from "../../core/index.js";

export const meta = {
  name: "Web ring",
  desc: "Seen from above, a round web pinned flat to the floor: silk spokes, a sagging spiral, a glowing rim with light chasing round it and dew beads sliding out to it.",
  tags: ["rainfall", "web", "silk", "spider", "trap", "top-down", "ground", "loop"],
  size: [176, 176],
  origin: [88, 88],
  duration: 2,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#05100c", "#0b1c16", "#16302a", "#2a5446", "#4a8070", "#6cc8a4", "#9CF0C8", "#d0fae8"],
    radius: 72,
    spokes: 14,
    turns: 6,
    seed: 6,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), R = o.radius, N = o.spokes, ph = t / meta.duration;
  const rimR = (a) => R * (0.97 + 0.03 * Math.sin(a * N)); // the rim is pulled out at each spoke
  // spiral threads: one ring per turn, sagging inwards between spokes
  for (let k = 1; k <= o.turns; k++) {
    const rk = R * (0.18 + 0.8 * (k / (o.turns + 0.3)));
    let prev = null;
    for (let i = 0; i <= N * 8; i++) {
      const a = (i / (N * 8)) * TAU + 0.11, s = Math.abs(Math.sin(((a - 0.11) * N) / 2));
      const rr = rk * (1 - 0.06 * s), pt = [Math.cos(a) * rr, Math.sin(a) * rr];
      if (prev) p.line(prev[0], prev[1], pt[0], pt[1], C[Math.cos(a + 2.36) > 0.3 ? 4 : 3]);
      prev = pt;
    }
  }
  // spokes from the hub to the rim
  for (let i = 0; i < N; i++) {
    const a = (i / N) * TAU + 0.11, r1 = rimR(a);
    p.line(Math.cos(a) * R * 0.1, Math.sin(a) * R * 0.1, Math.cos(a) * r1, Math.sin(a) * r1, C[Math.cos(a + 2.36) > 0 ? 5 : 4]);
  }
  // the rim, a doubled thread with light chasing round it
  const pa = ph * TAU;
  for (let i = 0; i < 180; i++) {
    const a = (i / 180) * TAU, r1 = rimR(a), x = Math.cos(a) * r1, y = Math.sin(a) * r1;
    const pu = Math.max(0, Math.cos(a - pa)) ** 6 + Math.max(0, Math.cos(a - pa - Math.PI)) ** 6;
    p.px(x, y, C[pu > 0.5 ? 7 : pu > 0.15 ? 6 : 5]);
    p.light(x, y, C[6], 0.12 + 0.4 * pu);
  }
  // hub knot
  p.circle(0, 0, R * 0.08, (d) => C[d < 0.5 ? 6 : 4]);
  p.glow(0, 0, R * 0.25, C[5], 0.25);
  // dew beads sliding out along the spokes
  cycle(t, meta.duration, 10, o.seed, 1, (age, life, r) => {
    const i = Math.floor(r.range(0, N)), a = (i / N) * TAU + 0.11, k = age / life;
    const rr = R * (0.15 + 0.8 * k * k), x = Math.cos(a) * rr, y = Math.sin(a) * rr;
    p.px(x, y, C[7]);
    p.light(x, y, C[6], 0.55 * Math.sin(Math.PI * k));
  });
}
