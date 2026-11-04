// Rainfall (iso camera, drawn in screen space): a column of cold light bursting up out of a floor mark. The floor is a
// 2:1 ellipse of `radius` px (x) by radius / 2 (y): its rim flashes, the column shoots up `height` px, a few glints rise
// with it, then it thins to a thread and goes out, leaving the rim to fade.
import { fit, burst, clamp, smooth, ease, noise } from "../../core/index.js";

export const meta = {
  name: "Light column",
  desc: "Iso: a column of cold light bursts up out of a floor ring: the 2:1 rim flashes, the column shoots up with rising glints, thins to a thread and goes out.",
  tags: ["rainfall", "boss", "holy", "pillar", "column", "iso", "one-shot"],
  size: [72, 140],
  origin: [36, 124],
  duration: 0.8,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06090d", "#0b1219", "#16222c", "#34505e", "#6f98a8", "#8fc8d8", "#BFF4FF", "#dff9ff"],
    radius: 24,
    height: 110,
    seed: 3,
  },
};

const SQ = 0.5;

export function draw(p, t, o) {
  const C = fit(o.palette, 8), R = o.radius, Hh = o.height, S = o.seed;
  const rimK = 1 - smooth(0.15, 0.75, t);
  // the floor rim and its pale fill
  if (rimK > 0) {
    p.shade(-R - 1, -R * SQ - 1, R + 1, R * SQ + 1, (x, y, out) => {
      const d = Math.hypot(x / R, y / (R * SQ));
      if (d > 1) return;
      if (d > 0.84) {
        out.c = C[t < 0.12 ? 7 : y < 0 ? 6 : 5];
        out.a = rimK;
        out.k = 0.5 * rimK;
        out.l = C[6];
        return;
      }
      out.c = C[3];
      out.a = 0.35 * rimK * (1 - d * 0.6);
      out.k = 0.08 * rimK;
      out.l = C[5];
    });
  }
  // the column: shoots up, holds, thins to a thread
  const up = ease.outCubic(clamp(t / 0.12)), thin = smooth(0.25, 0.65, t);
  const top = -Hh * up, w = R * 0.55 * (1 - 0.85 * thin);
  if (thin < 1 && w > 0.4) {
    p.shade(-w - 1, top - 2, w + 1, 1, (x, y, out) => {
      const v = Math.abs(x) / w, h = -y / Hh;
      const tipFade = clamp((y - top) / 14);
      const wob = noise(y * 0.08 - t * 12, S) * 0.15;
      if (v > 1 - wob) return;
      out.c = C[v < 0.25 ? (t < 0.16 ? 7 : 6) : v < 0.6 ? 5 : 4];
      out.a = tipFade * (1 - thin * 0.5) * (v < 0.25 ? 0.95 : v < 0.6 ? 0.75 : 0.5);
      out.k = 0.45 * tipFade * (1 - thin) * (1 - h * 0.4);
      out.l = C[6];
    });
  }
  if (t < 0.1) p.glow(0, -6, R * 1.2, C[7], 0.9 * (1 - t / 0.1));
  // glints rising up the column and off the rim
  burst(14, S, (r) => {
    const born = r.range(0.02, 0.35), age = t - born, life = r.range(0.25, 0.45);
    if (age < 0 || age > life) return;
    const q = age / life, x = r.range(-1, 1) * R * 0.8, y = r.range(-0.4, 0.4) * R * SQ - q * Hh * r.range(0.3, 0.8);
    p.dot(x, y, C[q < 0.5 ? 7 : 6], 1 - q);
    p.light(x, y, C[6], 0.4 * (1 - q));
  });
}
