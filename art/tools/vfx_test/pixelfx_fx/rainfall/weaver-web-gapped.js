// Rainfall (top-down, for an iso camera): the Weaver's web ring laid flat on the floor, seen from above, as a loop.
// Like web-ring (silk spokes, sagging spiral, glowing rim with light chasing round it, dew beads sliding out) but
// with the two breaches of the gameplay web cut through it at +x and -x (half opening `gap` radians): no silk
// there, mint pearls hanging on the cut ends to mark the way through. Rotate it so +x points at a breach.
import { fit, cycle, TAU } from "../../core/index.js";

export const meta = {
  name: "Web ring with breaches",
  desc: "Seen from above, a round web pinned flat to the floor, two breaches cut through it opposite each other with glowing pearls on the cut ends, light chasing round the rim.",
  tags: ["rainfall", "web", "silk", "spider", "trap", "top-down", "ground_dir", "loop"],
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
    gap: 0.3, // half opening of each breach (radians)
    seed: 6,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), R = o.radius, N = o.spokes, ph = t / meta.duration, G = o.gap;
  const inGap = (a) => {
    const d0 = Math.abs(Math.atan2(Math.sin(a), Math.cos(a)));
    return d0 < G || Math.PI - d0 < G;
  };
  const rimR = (a) => R * (0.97 + 0.03 * Math.sin(a * N));
  // spiral threads, cut at the breaches
  for (let k = 1; k <= o.turns; k++) {
    const rk = R * (0.18 + 0.8 * (k / (o.turns + 0.3)));
    let prev = null;
    for (let i = 0; i <= N * 8; i++) {
      const a = (i / (N * 8)) * TAU + 0.11, s = Math.abs(Math.sin(((a - 0.11) * N) / 2));
      const rr = rk * (1 - 0.06 * s), pt = [Math.cos(a) * rr, Math.sin(a) * rr];
      if (prev && !inGap(a) && !inGap(prev[2])) p.line(prev[0], prev[1], pt[0], pt[1], C[Math.cos(a + 2.36) > 0.3 ? 4 : 3]);
      prev = [pt[0], pt[1], a];
    }
  }
  // spokes, none through a breach
  for (let i = 0; i < N; i++) {
    const a = (i / N) * TAU + 0.11, r1 = rimR(a);
    if (inGap(a)) continue;
    p.line(Math.cos(a) * R * 0.1, Math.sin(a) * R * 0.1, Math.cos(a) * r1, Math.sin(a) * r1, C[Math.cos(a + 2.36) > 0 ? 5 : 4]);
  }
  // the rim, light chasing round it, cut at the breaches
  const pa = ph * TAU;
  for (let i = 0; i < 180; i++) {
    const a = (i / 180) * TAU;
    if (inGap(a)) continue;
    const r1 = rimR(a), x = Math.cos(a) * r1, y = Math.sin(a) * r1;
    const pu = Math.max(0, Math.cos(a - pa)) ** 6 + Math.max(0, Math.cos(a - pa - Math.PI)) ** 6;
    p.px(x, y, C[pu > 0.5 ? 7 : pu > 0.15 ? 6 : 5]);
    p.light(x, y, C[6], 0.12 + 0.4 * pu);
  }
  // pearls on the cut ends of the rim, pulsing: the way through
  const pulse = 0.6 + 0.4 * Math.sin(ph * TAU * 2);
  for (const base of [0, Math.PI])
    for (const s of [-1, 1]) {
      const a = base + s * G, r1 = rimR(a), x = Math.cos(a) * r1, y = Math.sin(a) * r1;
      p.circle(x, y, 2.2, (d) => C[d < 0.5 ? 7 : 6]);
      p.glow(x, y, 9, C[6], 0.45 * pulse);
    }
  // hub knot
  p.circle(0, 0, R * 0.08, (d) => C[d < 0.5 ? 6 : 4]);
  p.glow(0, 0, R * 0.25, C[5], 0.25);
  // dew beads sliding out along the spokes
  cycle(t, meta.duration, 10, o.seed, 1, (age, life, r) => {
    const i = Math.floor(r.range(0, N)), a = (i / N) * TAU + 0.11, k = age / life;
    if (inGap(a)) return;
    const rr = R * (0.15 + 0.8 * k * k), x = Math.cos(a) * rr, y = Math.sin(a) * rr;
    p.px(x, y, C[7]);
    p.light(x, y, C[6], 0.55 * Math.sin(Math.PI * k));
  });
}
