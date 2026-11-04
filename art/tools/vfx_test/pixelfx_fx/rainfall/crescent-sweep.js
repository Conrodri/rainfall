// Rainfall (top-down, for an iso camera): a blade swept round a half circle in front of the caster, seen from above.
// The slash's thick-head, thin-tail smear and white outer rim follow Sprite Fusion's open-source slash
// (https://www.spritefusion.com/pixel-art-vfx/slash), MIT License, Copyright (c) 2026 Hugo Duprez.
import { fit, burst, fly, flyV, clamp, smooth, ease, sparkle } from "../../core/index.js";

export const meta = {
  name: "Crescent sweep",
  desc: "Seen from above, a blade sweeps a half circle in front of the caster: a thick white-rimmed smear tapering to a hair, a pale wash, sap sparks off the rim.",
  tags: ["rainfall", "melee", "slash", "crescent", "top-down", "directional", "one-shot"],
  size: [96, 136],
  origin: [16, 68],
  duration: 0.52,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0d1008", "#1a2010", "#2e3a1c", "#58703a", "#8fb04e", "#CDEB6E", "#E6F7A8"],
    radius: 56,
    span: Math.PI, // radians swept, centred on +x
    seed: 3,
  },
};

const SWEEP = 0.085, HOLD = 0.06, TRAIL = 0.3;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, SPAN = o.span, A0 = -SPAN / 2;
  const head = A0 + SPAN * ease.outExpo(clamp(t / SWEEP));
  const tail = A0 + SPAN * smooth(SWEEP + HOLD, SWEEP + HOLD + TRAIL, t);
  const age = clamp(t / (SWEEP + HOLD + TRAIL + 0.08));
  const W = (u) => (3 + 11 * Math.pow(u, 0.7)) * (1 - 0.45 * smooth(SWEEP + HOLD, SWEEP + HOLD + TRAIL, t));
  // the wash: the swept area, pale and brief
  if (head > tail + 0.02 && age < 0.85) {
    for (let y = -R; y < R; y++)
      for (let x = -R; x < R; x++) {
        const px = x + 0.5, py = y + 0.5, r = Math.hypot(px, py), a = Math.atan2(py, px);
        if (r > R - 3 || r < 6 || a < tail || a > head) continue;
        const u = (a - tail) / Math.max(0.01, head - tail);
        if (r > R - W(u) - 1) continue;
        p.blend(x, y, C[r > R * 0.6 ? 4 : 3], 0.3 * (1 - age) * (0.4 + 0.6 * u) * (r / R));
        p.light(x, y, C[4], 0.05 * (1 - age) * (r / R));
      }
  }
  // the smear: thick at the head, a hair at the tail; white outer rim while young, cooling inward and with age
  if (head > tail + 0.01) {
    p.shade(-R - 1, -R - 1, R + 1, R + 1, (x, y, out) => {
      const r = Math.hypot(x, y), a = Math.atan2(y, x);
      if (r > R + 0.5 || a < tail || a > head) return;
      const u = (a - tail) / Math.max(0.01, head - tail), w = W(u);
      if (r < R - w) return;
      const q = (R - r) / w; // 0 rim .. 1 inner edge
      const ci = q < 0.2 && age < 0.45 ? 6 : Math.round(5 - q * 2.6 - age * 2.2 + u * 0.8);
      out.c = C[clamp(ci, 1, 6)];
      out.k = (0.75 * (1 - q) + 0.15) * (1 - age) * (0.3 + 0.7 * u);
      out.l = C[5];
    });
    // a thinner echo just inside, a beat behind
    const eh = A0 + SPAN * ease.outExpo(clamp((t - 0.02) / SWEEP)), et = tail + 0.15;
    if (eh > et) p.arc(0, 0, R * 0.74, 2, et, eh, (u) => C[u > 0.7 && age < 0.4 ? 5 : 4], (u) => (1 - age) * u);
  }
  // the blade's edge on the swing
  if (t < SWEEP + 0.03) {
    const c = Math.cos(head), s = Math.sin(head);
    p.line(c * R * 0.3, s * R * 0.3, c * R, s * R, C[6]);
    p.glowLine(c * R * 0.3, s * R * 0.3, c * R, s * R, 6, C[5], 0.5);
  }
  // the tip glints where it stops
  const g = t - SWEEP * 0.7;
  if (g > 0 && g < 0.2) sparkle(p, Math.cos(A0 + SPAN) * (R - 2), Math.sin(A0 + SPAN) * (R - 2), 8 * ease.outBack(Math.min(1, g / 0.05)) * (1 - g / 0.2), C[6], C[4], 0.6);
  // sap sparks flung off the rim along the swing, and shavings left behind
  burst(22, o.seed, (r) => {
    const a = A0 + SPAN * r.range(0.15, 1), born = SWEEP * ease.outExpo(clamp(r.range(0.2, 1))) * 0.9, age2 = t - born;
    const life = r.range(0.14, 0.3);
    if (age2 < 0 || age2 > life) return;
    const tx = -Math.sin(a), ty = Math.cos(a), sp = r.range(60, 160), out = r.range(0.2, 0.8);
    const vx = (tx + Math.cos(a) * out) * sp, vy = (ty + Math.sin(a) * out) * sp;
    const [x, y] = fly(Math.cos(a) * R, Math.sin(a) * R, vx, vy, age2, 0, 10);
    const [ux, uy] = flyV(vx, vy, age2, 0, 10), l = Math.hypot(ux, uy) || 1, q = age2 / life;
    p.line(x, y, x - (ux / l) * 2.5, y - (uy / l) * 2.5, C[q < 0.4 ? 6 : 5]);
    p.light(x, y, C[5], 0.5 * (1 - q));
  });
  // light riding the head, then a pool over the arc
  if (t < 0.35) p.glow(Math.cos(head) * (R - 6), Math.sin(head) * (R - 6), 30, C[4], 0.5 * (1 - t / 0.35));
}
