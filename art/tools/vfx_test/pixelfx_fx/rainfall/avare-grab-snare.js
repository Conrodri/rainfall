// Rainfall (top-down, for an iso camera): Avare's Saisie, the catch at the end of the chain, seen from above. One-shot.
// A gold noose snaps shut on a `radius` px disc, hooks biting inward, then the catch is hauled back towards -x (towards
// Avare): drag streaks and a smear of grit leaving the disc in that direction. Directional: Avare is on the -x side.
import { fit, clamp, smooth, ease, burst, TAU } from "../../core/index.js";

export const meta = {
  name: "Avare grab snare",
  desc: "Seen from above, a gold noose snaps shut on a disc, hooks biting inward, then the catch is hauled back to the left: drag streaks and grit.",
  tags: ["rainfall", "chain", "grab", "pull", "gold", "top-down", "directional", "one-shot"],
  size: [96, 76],
  origin: [56, 38],
  duration: 0.6,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0e0a04", "#1c1408", "#33260f", "#5c4620", "#8f6e2e", "#F2C14E", "#F8DE92"],
    radius: 32,
    hooks: 6,
    seed: 2,
  },
};

const SNAP = 0.16;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, S = o.seed;
  const close = ease.inCubic(clamp(t / SNAP)), Rn = R * (1 - 0.55 * close), fade = 1 - smooth(0.3, meta.duration, t);
  // the noose: a gold ring tightening, with a dim wash of the disc it sweeps
  p.shade(-R - 2, -R - 2, R + 2, R + 2, (x, y, out) => {
    const r = Math.hypot(x, y), a = Math.atan2(y, x);
    if (Math.abs(r - Rn) < 1.8 && fade > 0.02) {
      out.c = C[Math.cos(a + 2.36) > 0 ? 6 : 5];
      out.a = fade;
      out.k = 0.45 * fade;
      out.l = C[5];
      return;
    }
    if (r < R && r > Rn && t < SNAP + 0.1) {
      out.k = 0.1 * (1 - (r - Rn) / Math.max(1, R - Rn)) * (1 - smooth(SNAP, SNAP + 0.1, t));
      out.l = C[4];
    }
  });
  // hooks biting inward from the ring
  for (let i = 0; i < o.hooks; i++) {
    const a = (i / o.hooks) * TAU + 0.4, c = Math.cos(a), s = Math.sin(a);
    const x0 = c * Rn, y0 = s * Rn, x1 = c * (Rn - 5), y1 = s * (Rn - 5);
    p.line(x0, y0, x1, y1, C[6], fade);
    p.line(x1, y1, x1 - s * 2, y1 + c * 2, C[5], fade);
  }
  // the haul: streaks leaving the disc towards -x (Avare), grit dragged behind
  const h = t - SNAP;
  if (h > 0) {
    burst(14, S, (r) => {
      const y = r.range(-0.8, 0.8) * Rn, born = r.range(0, 0.08), age = h - born, life = r.range(0.18, 0.3);
      if (age < 0 || age > life) return;
      const k = age / life, x = r.range(-0.4, 0.6) * Rn - ease.outCubic(k) * R * 1.3, len = 6 + 8 * (1 - k);
      p.line(x, y, x + len, y * (1 - 0.1 * k), C[k < 0.4 ? 6 : 5], 1 - k);
      p.light(x, y, C[5], 0.35 * (1 - k));
    });
    p.glow(-R * 0.4 * clamp(h / 0.2), 0, Rn * 1.4, C[5], 0.45 * (1 - smooth(0, 0.35, h)));
  }
  p.glow(0, 0, R, C[6], 0.6 * smooth(SNAP - 0.04, SNAP, t) * (1 - smooth(SNAP, SNAP + 0.12, t)));
}
