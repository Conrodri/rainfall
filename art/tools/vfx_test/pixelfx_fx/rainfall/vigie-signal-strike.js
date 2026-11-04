// Rainfall (billboard, for an iso camera): Vigie's Tir de signal landing, one-shot. A huge arrow shot into the sky
// comes straight down (it really falls) and slams into the floor: white flash, a 2:1 shockwave ring racing out to the
// zone's radius, chunks of floor thrown up and falling back, the giant arrow left quivering in the ground.
import { fit, burst, fly, clamp, smooth, ease, TAU } from "../../core/index.js";

export const meta = {
  name: "Vigie signal strike",
  desc: "Upright: a giant arrow drops out of the sky, a white flash, a 2:1 shockwave ring out to the zone radius, chunks thrown up, the arrow left stuck and quivering, then fading.",
  tags: ["rainfall", "arrow", "impact", "slam", "billboard", "ground", "one-shot"],
  size: [144, 216],
  origin: [72, 168],
  duration: 1.0,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0c0507", "#1c0a0e", "#35121a", "#6a1b2a", "#B02438", "#FF3A4F", "#FF8C98"],
    radius: 56, // px of floor (16 px per game unit) : 3,5 u
    seed: 41,
  },
};

const FALL = 0.1, LEN = 34;

function arrow(p, C, x, y, a) {
  // a giant arrow pointing down, its head at (x, y): broad steel head, thick shaft, big red fletching on top
  p.tri(x - 5, y - 9, x + 5, y - 9, x, y + 1, () => C[6]);
  p.line(x - 4, y - 9, x, y, C[5], a);
  p.rect(x - 1, y - 9 - LEN, 3, LEN, C[4], a);
  p.line(x - 1, y - 9 - LEN, x - 1, y - 9, C[6], a);
  for (let i = 0; i < 3; i++) {
    const fy = y - 9 - LEN + 2 + i * 3;
    p.line(x - 1, fy, x - 6, fy - 5, C[5], a);
    p.line(x + 1, fy, x + 6, fy - 5, C[4], a);
  }
}

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, RY = R / 2;
  if (t < FALL) {
    // the drop: the arrow and a long white streak above it
    const q = ease.inQuad(t / FALL), y = -90 * (1 - q);
    p.glowLine(0, y - 50, 0, y, 7, C[5], 0.5);
    p.line(0, y - 56, 0, y - 12, (u) => C[u > 0.6 ? 6 : 4], (u) => u);
    arrow(p, C, 0, y, 1);
    p.glow(0, y, 14, C[5], 0.8);
    // the zone lights up under it
    p.glowRing(0, 0, R * 0.7, 6, C[4], 0.15 * q);
    return;
  }
  const s = t - FALL, life = meta.duration - FALL, q = s / life;
  // the flash: two frames of white over the impact
  if (s < 0.07) {
    p.disc(0, -3, 9 * (1 - s / 0.07) + 3, C[6]);
    p.glow(0, 0, 46, C[6], 1.0 * (1 - s / 0.07));
  }
  // shockwave: a 2:1 ring racing out to the radius, thick then thin
  const w = ease.outCubic(clamp(s / 0.22)), rx = R * w, ry = RY * w, wa = 1 - smooth(0.15, 0.45, s);
  if (wa > 0)
    p.shade(-R - 2, -RY - 2, R + 2, RY + 2, (x, y, out) => {
      const d = Math.hypot(x / Math.max(1, rx), y / Math.max(1, ry));
      const th = 0.16 * (1 - w) + 0.05;
      if (Math.abs(d - 1) > th) return;
      out.c = C[Math.abs(d - 1) < th * 0.4 ? 6 : 5];
      out.a = wa;
      out.k = 0.6 * wa;
      out.l = C[5];
    });
  // dust ring left behind on the floor, settling
  p.shade(-R, -RY, R, RY, (x, y, out) => {
    const d = Math.hypot(x / R, y / RY);
    if (d > w * 0.95 || d > 1 || ((Math.floor(x) + Math.floor(y)) & 1)) return;
    out.c = C[d < 0.35 ? 3 : 2];
    out.a = 0.5 * (1 - q) * (0.4 + 0.6 * d);
  });
  // a crater mark under the arrow
  p.shade(-9, -4, 9, 4, (x, y, out) => {
    if (Math.hypot(x / 9, y / 4) > 1) return;
    out.c = C[0];
    out.a = 0.8 * (1 - q);
  });
  // chunks thrown up and falling back
  burst(20, o.seed, (r) => {
    const a = r.range(0, TAU), sp = r.range(30, 80), up = r.range(60, 140), lf = r.range(0.35, 0.6);
    if (s > lf) return;
    const [x, y] = fly(Math.cos(a) * 4, Math.sin(a) * 2, Math.cos(a) * sp, Math.sin(a) * sp * 0.5 - up, s, 420, 0.5);
    const k = s / lf;
    p.rect(x, y, 2, 2, C[k < 0.3 ? 4 : 2], 1 - k * 0.5);
    if (k < 0.3) p.light(x, y, C[5], 0.4);
  });
  // the arrow stuck in the ground, quivering, then fading as the flare takes over
  const quiver = Math.sin(s * 70) * 2 * Math.exp(-s * 7), al = 1 - smooth(0.55, life, s);
  if (al > 0.01) {
    arrow(p, C, quiver * 0.3, 6, al);
    p.glow(0, -10, 20, C[5], 0.6 * al);
  }
}
