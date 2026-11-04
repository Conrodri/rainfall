// Rainfall (top-down, for an iso camera): Rictus's curtain of stand-ins, seen from above, as a loop. A line across the
// direction (along local y, centred on the pivot): six thread knots `gap` px apart where the stand-ins stand, strung
// together by doubled threads that sag and shimmer, light pulses running along them, a faint veil hanging between.
// Directional (ground_dir): +x is the way the curtain faces.
import { fit, cycle, TAU } from "../../core/index.js";

export const meta = {
  name: "Rictus curtain",
  desc: "Seen from above, a curtain of threads across the way ahead: six knots where the stand-ins stand, doubled threads shimmering between them, pulses running along.",
  tags: ["rainfall", "rictus", "thread", "curtain", "wall", "top-down", "directional", "loop"],
  size: [44, 112],
  origin: [22, 56],
  duration: 1.2,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0a0d0d", "#141b1b", "#26312f", "#46585a", "#6f8f8a", "#9FC8C0", "#c9e3dd"],
    count: 6,
    gap: 16,
    seed: 61,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), N = o.count, G = o.gap, ph = t / meta.duration;
  const span = (N - 1) * G, y0 = -span / 2;
  // the veil: a dithered band across, thicker at the knots' line
  p.shade(-5, y0 - 2, 5, -y0 + 2, (x, y, out) => {
    if ((Math.floor(x) + Math.floor(y)) % 2) return;
    const w = Math.abs(x) / 5, sh = 0.5 + 0.5 * Math.sin((y / span) * TAU * 2 - ph * TAU);
    out.c = C[2 + (sh > 0.7 ? 1 : 0)];
    out.a = 0.55 * (1 - w);
  });
  // doubled threads between neighbouring knots, sagging forward and back, shimmering
  for (let i = 0; i < N - 1; i++) {
    const ya = y0 + i * G, yb = ya + G;
    for (const [side, amp] of [[1, 2.5], [-1, 1.8]]) {
      for (let k = 0; k <= G; k++) {
        const u = k / G, y = ya + k;
        const sway = Math.sin(ph * TAU + i * 1.3 + side) * 0.8;
        const x = side * (amp + sway) * Math.sin(u * Math.PI);
        const sh = 0.5 + 0.5 * Math.sin(u * Math.PI * 2 + ph * TAU * 2 + i);
        p.dot(x, y, C[sh > 0.75 ? 6 : sh > 0.35 ? 5 : 4], 0.85);
        if (sh > 0.75) p.light(x, y, C[5], 0.2);
      }
    }
  }
  // pulses running along the curtain, end to end
  cycle(t, meta.duration, 3, o.seed, 0.6, (age, life, r) => {
    const k = age / life, dirn = r.next() < 0.5 ? 1 : -1, y = dirn * (y0 + span * k);
    p.circle(0, y, 1.6, C[6]);
    p.glow(0, y, 9, C[5], 0.5 * Math.sin(Math.PI * k));
  });
  // the knots where the stand-ins stand
  for (let i = 0; i < N; i++) {
    const y = y0 + i * G, tw = 0.5 + 0.5 * Math.sin(ph * TAU + i * 2.1);
    p.circle(0, y, 2.4, (d) => C[d < 0.5 ? 6 : 5]);
    p.glow(0, y, 10, C[5], 0.25 + 0.2 * tw);
  }
}
