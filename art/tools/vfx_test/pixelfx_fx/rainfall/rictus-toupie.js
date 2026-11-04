// Rainfall (top-down, for an iso camera): Rictus spinning as a top, seen from above, as a loop. Three blade smears whirl
// round the pivot at radius R (the reach of the spin), a pale dithered wash inside, a thin spiral of thread wound round
// the hub, porcelain chips flung off tangentially. Centred on the pivot (the puppet's feet).
import { fit, cycle, fly, TAU, clamp } from "../../core/index.js";

export const meta = {
  name: "Rictus spinning top",
  desc: "Seen from above, three blade smears whirl round the caster at the spin's reach, a pale wash inside, a spiral of thread round the hub, chips flung off tangentially.",
  tags: ["rainfall", "rictus", "melee", "spin", "whirl", "top-down", "ground", "loop"],
  size: [100, 100],
  origin: [50, 50],
  duration: 0.5,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0a0d0d", "#141b1b", "#26312f", "#46585a", "#6f8f8a", "#9FC8C0", "#c9e3dd"],
    radius: 35,
    blades: 3,
    seed: 41,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, N = o.blades, ph = t / meta.duration;
  const rot = ph * ((TAU * 2) / N); // two blade steps per loop: seamless
  const SM = 1.9; // radians of smear behind each blade
  p.shade(-R - 2, -R - 2, R + 2, R + 2, (x, y, out) => {
    const r = Math.hypot(x, y);
    if (r > R + 0.5) return;
    const a = Math.atan2(y, x);
    let q = 1;
    for (let k = 0; k < N; k++) {
      let d = rot + (k * TAU) / N - a; // angle from this point forward to the blade (turning +)
      d -= Math.floor(d / TAU) * TAU;
      if (d < SM) q = Math.min(q, d / SM);
    }
    // smear band near the rim, thick at the head, thin at the tail
    const w = 3 + 9 * (1 - q);
    if (q < 1 && r > R - w) {
      const v = (R - r) / w;
      out.c = C[clamp(Math.round(6 - v * 2.5 - q * 2.5), 2, 6)];
      out.k = 0.6 * (1 - q) * (1 - v * 0.6);
      out.l = C[5];
      return;
    }
    // the wash inside: dithered veil, a little brighter behind each smear
    if (r < R - 2 && r > R * 0.5 && q < 0.8 && (Math.floor(x) + Math.floor(y)) % 2 === 0) {
      out.c = C[q < 0.5 ? 3 : 2];
      out.a = 0.2 + 0.3 * (1 - q);
      out.k = 0.04 * (1 - q);
      out.l = C[4];
    }
  });
  // blade edges at this instant
  for (let k = 0; k < N; k++) {
    const a = rot + (k * TAU) / N, c = Math.cos(a), s = Math.sin(a);
    p.line(c * R * 0.45, s * R * 0.45, c * R, s * R, C[6]);
    p.glowLine(c * R * 0.5, s * R * 0.5, c * R, s * R, 5, C[5], 0.35);
  }
  // thread wound round the hub: a spiral, turning with the blades
  for (let i = 0; i < 40; i++) {
    const u = i / 39, a = rot + u * TAU * 1.5, rr = 3 + u * R * 0.35;
    p.dot(Math.cos(a) * rr, Math.sin(a) * rr, C[5], 0.5 * (1 - u));
  }
  p.glow(0, 0, R * 0.9, C[4], 0.18);
  // chips flung off tangentially
  cycle(t, meta.duration, 14, o.seed, 0.22, (age, life, r) => {
    const a = r.range(0, TAU), k = age / life, sp = r.range(70, 130);
    const [x, y] = fly(Math.cos(a) * R, Math.sin(a) * R, -Math.sin(a) * sp, Math.cos(a) * sp, age, 0, 6);
    p.dot(x, y, C[k < 0.4 ? 6 : 5], 1 - k);
    p.light(x, y, C[5], 0.35 * (1 - k));
  });
}
