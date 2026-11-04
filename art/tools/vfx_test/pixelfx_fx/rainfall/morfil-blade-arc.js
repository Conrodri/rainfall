// Rainfall (top-down, for an iso camera): Taliant's katana swept round an arc of any span about the caster, seen from
// above. Full circle (Taille), 90° cone (Taille lente), twin counter-sweeps (Lames jumelles), quench hiss (Trempe).
// The thick-head, thin-tail smear and white outer rim follow Sprite Fusion's open-source slash
// (https://www.spritefusion.com/pixel-art-vfx/slash), MIT License, Copyright (c) 2026 Hugo Duprez.
import { fit, burst, fly, flyV, clamp, smooth, ease, sparkle, TAU } from "../../core/index.js";

export const meta = {
  name: "Taliant blade arc",
  desc: "Seen from above, a katana sweeps an arc of set span and radius round the caster: a white-rimmed smear, a pale wash, sap chips off the rim; twin: a second blade the other way.",
  tags: ["rainfall", "melee", "slash", "arc", "top-down", "directional", "one-shot"],
  size: [144, 144],
  origin: [72, 72],
  duration: 0.6,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0d1008", "#1a2010", "#2e3a1c", "#58703a", "#8fb04e", "#CDEB6E", "#E6F7A8"],
    radius: 45, // px (16 px per game unit)
    span: TAU, // radians swept, centred on +x
    sweep: 0.09, // s for the head to cross the span
    heavy: 0, // 1 = thicker, slower smear (Taille lente)
    twin: 0, // 1 = a second blade sweeps the other way, a beat later, just inside
    steam: 0, // 1 = quench steam rising off the swept ring (Trempe)
    seed: 5,
  },
};

const HOLD = 0.06, TRAIL = 0.3;

// one blade: sweeps `span` from `a0` in direction `sg` (1 = clockwise on screen, -1 = the other way), radius R
function blade(p, C, t, R, a0, span, sg, sweep, heavy, seed) {
  const prog = (a) => {
    // progress (0..span) of angle a along this sweep, wrapped
    let d = sg * (a - a0);
    d = ((d % TAU) + TAU) % TAU;
    return d;
  };
  const head = span * ease.outExpo(clamp(t / sweep));
  const tail = span * smooth(sweep + HOLD, sweep + HOLD + TRAIL, t);
  const age = clamp(t / (sweep + HOLD + TRAIL + 0.08));
  const thick = heavy ? 1.45 : 1;
  const W = (u) => (3 + 10 * thick * Math.pow(u, 0.7)) * (1 - 0.45 * smooth(sweep + HOLD, sweep + HOLD + TRAIL, t));
  const inSweep = (a) => {
    const d = prog(a);
    return d <= span + 0.001 && d >= tail && d <= head ? (d - tail) / Math.max(0.01, head - tail) : -1;
  };
  if (head <= tail + 0.01) return;
  // the wash: the swept ground, pale and brief
  if (age < 0.85)
    p.shade(-R, -R, R, R, (x, y, out) => {
      const r = Math.hypot(x, y);
      if (r > R - 3 || r < 5) return;
      const u = inSweep(Math.atan2(y, x));
      if (u < 0 || r > R - W(u) - 1) return;
      if (((Math.floor(x) + Math.floor(y)) & 1) && r < R * 0.55) return; // dithered towards the centre
      out.c = C[r > R * 0.6 ? 4 : 3];
      out.a = 0.5 * (1 - age) * (0.4 + 0.6 * u);
      out.k = 0.08 * (1 - age) * (r / R);
      out.l = C[4];
    });
  // the smear: thick at the head, a hair at the tail; white outer rim while young
  p.shade(-R - 1, -R - 1, R + 1, R + 1, (x, y, out) => {
    const r = Math.hypot(x, y);
    if (r > R + 0.5) return;
    const u = inSweep(Math.atan2(y, x));
    if (u < 0) return;
    const w = W(u);
    if (r < R - w) return;
    const q = (R - r) / w; // 0 rim .. 1 inner edge
    const ci = q < 0.2 && age < 0.45 ? 6 : Math.round(5 - q * 2.6 - age * 2.2 + u * 0.8);
    out.c = C[clamp(ci, 1, 6)];
    out.k = (0.75 * (1 - q) + 0.15) * (1 - age) * (0.3 + 0.7 * u);
    out.l = C[5];
  });
  // a thinner echo just inside, a beat behind
  const eh = span * ease.outExpo(clamp((t - 0.025) / sweep)), et = tail + 0.15;
  if (eh > et)
    p.shade(-R, -R, R, R, (x, y, out) => {
      const r = Math.hypot(x, y);
      if (Math.abs(r - R * 0.72) > 0.9) return;
      const d = prog(Math.atan2(y, x));
      if (d < et || d > eh) return;
      const u = (d - et) / Math.max(0.01, eh - et);
      out.c = C[u > 0.7 && age < 0.4 ? 5 : 4];
      out.a = (1 - age) * u;
    });
  // the blade's edge on the swing
  const ha = a0 + sg * head;
  if (t < sweep + 0.03) {
    const c = Math.cos(ha), s = Math.sin(ha);
    p.line(c * R * 0.25, s * R * 0.25, c * R, s * R, C[6]);
    p.glowLine(c * R * 0.25, s * R * 0.25, c * R, s * R, 6, C[5], 0.5);
  }
  // the tip glints where it stops
  const g = t - sweep * 0.7, ea = a0 + sg * span;
  if (g > 0 && g < 0.2 && span < TAU - 0.01)
    sparkle(p, Math.cos(ea) * (R - 2), Math.sin(ea) * (R - 2), 7 * ease.outBack(Math.min(1, g / 0.05)) * (1 - g / 0.2), C[6], C[4], 0.6);
  // sap chips flung off the rim along the swing
  burst(Math.round(10 + span * 3), seed, (rr) => {
    const k = rr.range(0.1, 1), a = a0 + sg * span * k, born = sweep * ease.outExpo(k) * 0.9, age2 = t - born;
    const life = rr.range(0.14, 0.3);
    if (age2 < 0 || age2 > life) return;
    const tx = -Math.sin(a) * sg, ty = Math.cos(a) * sg, sp = rr.range(60, 150), o = rr.range(0.2, 0.8);
    const vx = (tx + Math.cos(a) * o) * sp, vy = (ty + Math.sin(a) * o) * sp;
    const [x, y] = fly(Math.cos(a) * R, Math.sin(a) * R, vx, vy, age2, 0, 10);
    const [ux, uy] = flyV(vx, vy, age2, 0, 10), l = Math.hypot(ux, uy) || 1, q = age2 / life;
    p.line(x, y, x - (ux / l) * 2.5, y - (uy / l) * 2.5, C[q < 0.4 ? 6 : 5]);
    p.light(x, y, C[5], 0.5 * (1 - q));
  });
  // light riding the head
  if (t < 0.3) p.glow(Math.cos(ha) * (R - 6), Math.sin(ha) * (R - 6), 26, C[4], 0.45 * (1 - t / 0.3));
}

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, SPAN = o.span;
  const sweep = o.sweep * (o.heavy ? 1.35 : 1);
  const full = SPAN >= TAU - 0.01;
  // a full circle starts behind the caster (-x) so the head passes in front last; an arc is centred on +x
  const a0 = full ? Math.PI : -SPAN / 2;
  blade(p, C, t, R, a0, SPAN, 1, sweep, o.heavy, o.seed);
  if (o.twin) {
    const a1 = full ? 0 : SPAN / 2;
    blade(p, C, t - 0.05, Math.round(R * 0.84), a1, SPAN, -1, sweep, o.heavy, o.seed + 7);
  }
  // Trempe : steam hissing off the swept ring, pale and dark, drifting outward
  if (o.steam)
    burst(16, o.seed + 31, (rr) => {
      const a = rr.range(0, TAU), born = rr.range(0.05, 0.25), age2 = t - born, life = rr.range(0.25, 0.4);
      if (age2 < 0 || age2 > life) return;
      const q = age2 / life, r = R * rr.range(0.75, 1.0) + q * 7;
      const x = Math.cos(a) * r, y = Math.sin(a) * r, s = 1 + q * 2;
      p.disc(x, y, s, C[q < 0.4 ? 4 : 3], 0.5 * (1 - q));
    });
}
