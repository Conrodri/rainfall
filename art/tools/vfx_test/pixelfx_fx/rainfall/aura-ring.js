// Rainfall (top-down, for an iso camera): a temper aura on the floor around the feet, seen from above, as a loop. A
// glowing ring with two bright arcs chasing round it, ticks like a blade's temper line, motes circling inward.
import { fit, cycle, clamp, TAU } from "../../core/index.js";

export const meta = {
  name: "Aura ring",
  desc: "Seen from above, a tempering aura round the feet: a glowing ring with two bright arcs chasing round it, edge ticks like a temper line, motes circling inward.",
  tags: ["rainfall", "aura", "buff", "ring", "status", "top-down", "ground", "loop"],
  size: [56, 56],
  origin: [28, 28],
  duration: 1.6,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0d1008", "#1a2010", "#2e3a1c", "#58703a", "#8fb04e", "#CDEB6E", "#E6F7A8"],
    radius: 20,
    width: 3,
    seed: 7,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, W = o.width, ph = t / meta.duration, pa = ph * TAU;
  p.shade(-R - W, -R - W, R + W, R + W, (x, y, out) => {
    const r = Math.hypot(x, y), d = Math.abs(r - R);
    if (d > W) return;
    const a = Math.atan2(y, x);
    const chase = Math.max(0, Math.cos(a - pa)) ** 8 + Math.max(0, Math.cos(a - pa - Math.PI)) ** 8;
    const tick = Math.abs(Math.sin(a * 9)) > 0.93 && r > R;
    const q = d / W;
    let c = q < 0.35 ? 4 : 3;
    if (chase > 0.2) c = chase > 0.6 && q < 0.5 ? 6 : 5;
    if (tick) c = Math.max(c, 5);
    if (Math.cos(a + 2.36) < -0.5 && c < 6) c -= 1;
    if (q > 0.75 && chase < 0.2) return;
    out.c = C[c];
    out.k = 0.18 + 0.45 * chase;
    out.l = C[5];
  });
  // inner wash
  p.glow(0, 0, R * 0.9, C[4], 0.12 + 0.05 * Math.sin(pa * 2));
  // motes spiralling inward
  cycle(t, meta.duration, 8, o.seed, 0.8, (age, life, r) => {
    const a0 = r.range(0, TAU), k = age / life, a = a0 + k * 1.6, rr = R * (1 - 0.7 * k);
    const x = Math.cos(a) * rr, y = Math.sin(a) * rr;
    p.dot(x, y, C[k < 0.5 ? 6 : 5], Math.sin(Math.PI * k));
    p.light(x, y, C[5], 0.4 * Math.sin(Math.PI * k));
  });
}
