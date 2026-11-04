// Rainfall (top-down, for an iso camera): Rictus's twin daggers swept round a half circle in front of him, seen from
// above. Two blades a beat apart (thick white-rimmed smear tapering to a hair, then a thinner echo), the threads that
// hold them glinting from the pivot, porcelain chips flung off the rim. Pivot = the caster, swept from -90° to +90°.
// Smear shape adapted from crescent-sweep.js (itself after Sprite Fusion's open-source slash, MIT, Hugo Duprez).
import { fit, burst, fly, flyV, clamp, smooth, ease, sparkle } from "../../core/index.js";

export const meta = {
  name: "Rictus half-moon daggers",
  desc: "Seen from above, two daggers sweep a half circle in front of the puppet a beat apart: white-rimmed smears, glinting threads from the pivot, porcelain chips off the rim.",
  tags: ["rainfall", "rictus", "melee", "slash", "crescent", "top-down", "directional", "one-shot"],
  size: [80, 128],
  origin: [16, 64],
  duration: 0.5,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0a0d0d", "#141b1b", "#26312f", "#46585a", "#6f8f8a", "#9FC8C0", "#c9e3dd"],
    radius: 48,
    span: Math.PI,
    seed: 11,
  },
};

const SWEEP = 0.08, HOLD = 0.05, TRAIL = 0.26, LAG = 0.05;

function blade(p, C, t, R, SPAN, k, thick) {
  const A0 = -SPAN / 2;
  const head = A0 + SPAN * ease.outExpo(clamp(t / SWEEP));
  const tail = A0 + SPAN * smooth(SWEEP + HOLD, SWEEP + HOLD + TRAIL, t);
  const age = clamp(t / (SWEEP + HOLD + TRAIL + 0.08));
  if (t <= 0 || head <= tail + 0.01) return head;
  const W = (u) => (2 + thick * Math.pow(u, 0.7)) * (1 - 0.45 * smooth(SWEEP + HOLD, SWEEP + HOLD + TRAIL, t));
  p.shade(-R - 1, -R - 1, R + 1, R + 1, (x, y, out) => {
    const r = Math.hypot(x, y), a = Math.atan2(y, x);
    if (r > R + 0.5 || a < tail || a > head) return;
    const u = (a - tail) / Math.max(0.01, head - tail), w = W(u);
    if (r < R - w) return;
    const q = (R - r) / w;
    const ci = q < 0.22 && age < 0.45 ? 6 : Math.round(5 - q * 2.6 - age * 2.2 + u * 0.8);
    out.c = C[clamp(ci, 1, 6)];
    out.k = (0.7 * (1 - q) + 0.15) * (1 - age) * (0.3 + 0.7 * u) * k;
    out.l = C[5];
  });
  return head;
}

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, SPAN = o.span, A0 = -SPAN / 2;
  const age = clamp(t / (SWEEP + HOLD + TRAIL + 0.08));
  // the wash of the first sweep, pale and brief
  const h1 = A0 + SPAN * ease.outExpo(clamp(t / SWEEP)), t1 = A0 + SPAN * smooth(SWEEP + HOLD, SWEEP + HOLD + TRAIL, t);
  if (h1 > t1 + 0.02 && age < 0.85) {
    p.shade(0, -R, R, R, (x, y, out) => {
      const r = Math.hypot(x, y), a = Math.atan2(y, x);
      if (r > R - 3 || r < 5 || a < t1 || a > h1) return;
      const u = (a - t1) / Math.max(0.01, h1 - t1);
      if ((Math.floor(x) + Math.floor(y)) % 2) return; // dithered: a veil, not a disc
      out.c = C[r > R * 0.6 ? 3 : 2];
      out.a = 0.32 * (1 - age) * (0.3 + 0.7 * u);
      out.k = 0.04 * (1 - age);
      out.l = C[4];
    });
  }
  // the second dagger, a beat behind and a little shorter, then the first on top
  const hb = blade(p, C, t - LAG, R * 0.86, SPAN, 0.7, 7);
  const ha = blade(p, C, t, R, SPAN, 1, 11);
  // the threads tied to the daggers, taut from the pivot while they swing
  for (const [h, rr, tt] of [[ha, R, t], [hb, R * 0.86, t - LAG]]) {
    if (tt <= 0 || tt > SWEEP + 0.12) continue;
    const c = Math.cos(h), s = Math.sin(h), f = 1 - clamp((tt - SWEEP) / 0.12);
    p.line(c * 4, s * 4, c * (rr - 2), s * (rr - 2), C[5], 0.55 * f);
    p.glowLine(c * 4, s * 4, c * rr, s * rr, 3, C[5], 0.18 * f);
  }
  // blade edges on the swing
  for (const [h, rr, tt] of [[ha, R, t], [hb, R * 0.86, t - LAG]]) {
    if (tt <= 0 || tt > SWEEP + 0.03) continue;
    const c = Math.cos(h), s = Math.sin(h);
    p.line(c * rr * 0.55, s * rr * 0.55, c * rr, s * rr, C[6]);
    p.glowLine(c * rr * 0.55, s * rr * 0.55, c * rr, s * rr, 5, C[5], 0.5);
  }
  // the tip glints where it stops
  const g = t - SWEEP * 0.7;
  if (g > 0 && g < 0.2) sparkle(p, Math.cos(A0 + SPAN) * (R - 2), Math.sin(A0 + SPAN) * (R - 2), 7 * ease.outBack(Math.min(1, g / 0.05)) * (1 - g / 0.2), C[6], C[4], 0.6);
  // porcelain chips flung off the rim, angular flakes
  burst(20, o.seed, (r) => {
    const a = A0 + SPAN * r.range(0.15, 1), born = SWEEP * ease.outExpo(clamp(r.range(0.2, 1))) * 0.9, a2 = t - born;
    const life = r.range(0.14, 0.3);
    if (a2 < 0 || a2 > life) return;
    const tx = -Math.sin(a), ty = Math.cos(a), sp = r.range(50, 140), out = r.range(0.2, 0.8);
    const vx = (tx + Math.cos(a) * out) * sp, vy = (ty + Math.sin(a) * out) * sp;
    const [x, y] = fly(Math.cos(a) * R, Math.sin(a) * R, vx, vy, a2, 0, 10);
    const [ux, uy] = flyV(vx, vy, a2, 0, 10), l = Math.hypot(ux, uy) || 1, q = a2 / life;
    p.line(x, y, x - (ux / l) * 2, y - (uy / l) * 2, C[q < 0.4 ? 6 : 5]);
    p.light(x, y, C[5], 0.45 * (1 - q));
  });
  if (t < 0.3) p.glow(Math.cos(ha) * (R - 6), Math.sin(ha) * (R - 6), 24, C[4], 0.45 * (1 - t / 0.3));
}
