// Rainfall (for an iso camera, drawn in screen space): Averse's Geyser bursting out of the floor at the origin. The
// floor footprint is an ellipse 2:1 (radius `radius` px across, half that deep) where the water boils up and a foam
// ring runs out; a column of water stands up from it (height `height` px), crowned with froth, throws spray that falls
// back onto the footprint, then collapses into ripples. One-shot. The ground is y = 0.
import { fit, burst, fly, clamp, smooth, ease, tileNoise, TAU } from "../../core/index.js";

export const meta = {
  name: "Averse geyser",
  desc: "A geyser bursts from the floor: a 2:1 elliptic footprint with a foam ring running out, a tall frothing column of water, spray falling back, then ripples.",
  tags: ["rainfall", "water", "geyser", "column", "billboard", "one-shot"],
  size: [96, 124],
  origin: [48, 100],
  duration: 1.3,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#04090f", "#08141f", "#0f2a38", "#2f6577", "#2a9fb5", "#5FD4E8", "#9fe8f2"],
    radius: 32, // footprint radius (px) across; the depth is half
    height: 48, // column height (px)
    seed: 8,
  },
};

const RISE = 0.12, HOLD = 0.55, FALL = 0.95;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, H = o.height, S = o.seed;
  // footprint: churned water inside the ellipse, a foam ring running out to the rim, then rings of ripples
  const ringR = R * (0.35 + 0.65 * ease.outCubic(clamp(t / 0.35)));
  const kf = 1 - smooth(0.8, meta.duration, t);
  p.shade(-R - 2, -R / 2 - 2, R + 2, R / 2 + 2, (x, y, out) => {
    const d = Math.hypot(x, y * 2);
    if (d > R + 1) return;
    const q = d / R;
    const n = tileNoise(x / 4 + t * 3, y / 2, 0, 0, S);
    const ring = Math.abs(d - ringR);
    const rip = t > 0.45 ? Math.abs(d - R * ((t - 0.45) * 2.2 % 1)) : 99;
    let c = 0, a = kf > 0.6 ? 1 : kf / 0.6;
    if (q < 0.95 && n > -0.15 + q * 0.5) c = n > 0.45 ? 3 : 2; // churned water, patchy towards the rim
    if (ring < 1.6 && t < 0.7) { c = y < 0 ? 6 : 5; a = kf; }
    else if (rip < 1.1 && n > -0.3) c = Math.max(c, 4);
    if (!c) return;
    out.c = C[c];
    out.a = a;
    out.k = c >= 5 ? 0.35 * kf : 0.04 * kf;
    out.l = C[5];
  });
  // the column: rises fast, holds, then its top falls back
  const top = t < RISE ? H * ease.outCubic(t / RISE) : t < HOLD ? H * (1 + 0.04 * Math.sin(t * 40)) : H * (1 - ease.inQuad(clamp((t - HOLD) / (FALL - HOLD))));
  if (top > 2) {
    const base = R * 0.42;
    p.shade(-base - 3, -top - 4, base + 3, 1, (x, y, out) => {
      const h = -y;
      if (h < 0 || h > top) return;
      const u = h / Math.max(top, 1);
      const w = base * (1 - 0.45 * u) + 1.5 * tileNoise(h / 5 - t * 14, 1.5, 0, 0, S + 2);
      if (Math.abs(x) > w) return;
      const s = x / w; // -1 left (lit) .. 1 right
      const st = tileNoise(x / 2.2, (h + t * 220) / 7, 0, 0, S + 3);
      let c = s < -0.45 ? 5 : s < 0.35 ? 4 : 3;
      if (st > 0.35) c += 1;
      if (Math.abs(s) > 0.85) c = s < 0 ? 5 : 3;
      out.c = C[clamp(c, 2, 6)];
      out.a = u > 0.92 ? 0.8 : 1;
      out.k = c >= 5 ? 0.45 : 0.15;
      out.l = C[5];
    });
    // froth crown
    const cw = base * 0.75;
    p.ellipse(0, -top, cw, cw * 0.6, (d, a) => (d < 0.5 ? C[6] : Math.cos(a + 2.36) > 0 ? C[5] : C[4]));
    p.glow(0, -top * 0.6, R * 0.9, C[5], 0.55 * (t < HOLD ? 1 : 1 - (t - HOLD) / (FALL - HOLD + 0.2)));
  }
  // spray flung off the crown, falling back to the floor plane (ellipse) where it splashes
  burst(46, S + 5, (r) => {
    const born = r.range(0.05, 0.6), age = t - born;
    if (age < 0) return;
    const hb = H * (born < RISE ? born / RISE : 1) * r.range(0.6, 1);
    const a = r.range(0, TAU), sp = r.range(25, 60);
    const vx = Math.cos(a) * sp, vy = -r.range(20, 90);
    const [x, y] = fly(Math.cos(a) * 3, -hb, vx, vy, age, 260, 0.6);
    const gy = Math.sin(a) * Math.min(Math.abs(x), R) * 0.5; // where it lands on the floor ellipse
    if (kf < 0.05) return;
    if (y < gy) {
      p.dot(x, y, C[age < 0.15 ? 6 : 5], kf);
      p.light(x, y, C[5], 0.3);
    } else if (y < gy + 10 && Math.abs(x) < R + 2) {
      // splash on landing: a tiny flat ring
      p.dot(x - 1, gy, C[4], 0.8 * kf);
      p.dot(x + 1, gy, C[4], 0.8 * kf);
    }
  });
  if (t < 0.1) p.glow(0, -6, R, C[6], 0.7 * (1 - t / 0.1));
}
