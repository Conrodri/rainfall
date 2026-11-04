// Rainfall (top-down, for an iso camera): Arpenteuse's Tendeur, one tile of the chain cracking taut along its whole
// length, seen from above. One-shot. The links jolt sideways in a travelling wave and go white hot, a shock line runs
// either side, sparks fly off. Tiles seamlessly along x (exactly `length` px, two links).
import { fit, clamp, smooth, burst, TAU } from "../../core/index.js";

export const meta = {
  name: "Arpenteuse chain snap",
  desc: "Seen from above, one tile of copper chain cracking taut: links jolting sideways, white hot, a shock line either side, sparks flying off. Tiles end to end along x.",
  tags: ["rainfall", "chain", "whip", "snap", "top-down", "tile", "one-shot"],
  size: [44, 40],
  origin: [6, 20],
  duration: 0.3,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0b0806", "#1a110c", "#2e1f17", "#6b4a38", "#a8501a", "#FF7A1F", "#ffa860"],
    length: 32,
    amp: 5, // px sideways jolt
    seed: 8,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), L = o.length, h = L / 2, D = meta.duration;
  const decay = 1 - smooth(0.05, D * 0.85, t), hot = 1 - smooth(0.08, D, t);
  const off = (x) => o.amp * decay * Math.sin((x / L) * TAU - t * 40);
  const flat = [h * 0.5, h * 0.5 + L, h * 0.5 - L], edge = [h * 1.5, h * 1.5 - L, h * 1.5 + L];
  const rx = h * 0.6, ry = h * 0.46, hx = h * 0.32, hy = h * 0.19, bt = h * 0.16;
  const ext = o.amp + h * 0.75 + 8;
  p.shade(0, -ext, L, ext, (x, y0, out) => {
    if (x < 0 || x >= L) return;
    const y = y0 - off(x);
    for (const cx of edge) {
      const dx = Math.abs(x - cx);
      if (dx < h * 0.74 && Math.abs(y) < bt) {
        out.c = C[clamp((y < -bt * 0.35 ? 6 : 5) - (hot < 0.3 ? 1 : 0), 0, 6)];
        out.k = 0.55 * (0.3 + hot);
        out.l = C[6];
        return;
      }
    }
    for (const cx of flat) {
      const dx = (x - cx) / rx, dy = y / ry, d = dx * dx + dy * dy;
      const ix = (x - cx) / hx, iy = y / hy, di = ix * ix + iy * iy;
      if (d > 1 || di < 1) continue;
      const lit = (x - cx) / rx + y / ry < -0.2;
      out.c = C[lit ? 6 : hot > 0.5 ? 5 : 4];
      out.k = (lit ? 0.5 : 0.3) * (0.3 + hot);
      out.l = C[6];
      return;
    }
    // the shock line either side, racing outward then gone
    const sw = 3 + 9 * smooth(0, D * 0.7, t), ay = Math.abs(y0);
    if (Math.abs(ay - sw) < 0.9 && decay > 0.15 && ((x | 0) + (y0 > 0 ? 3 : 0)) % 5 < 3) {
      out.c = C[5];
      out.a = decay;
      out.k = 0.3 * decay;
      out.l = C[5];
      return;
    }
    const k = 0.25 * Math.exp(-(y * y) / (h * 1.6)) * hot;
    if (k > 0.02) {
      out.k = k;
      out.l = C[5];
    }
  });
  // sparks flung off the links
  burst(8, o.seed, (r) => {
    const x = r.range(0, L), born = r.range(0, 0.06), life = r.range(0.14, 0.24), age = t - born;
    if (age < 0 || age > life) return;
    const s = r.next() < 0.5 ? -1 : 1, vy = s * r.range(60, 120), vx = r.range(-30, 30), k = age / life;
    const px = x + vx * age, py = vy * age;
    p.line(px, py, px - vx * 0.03, py - vy * 0.03, C[k < 0.4 ? 6 : 5], 1 - k);
    p.light(px, py, C[5], 0.4 * (1 - k));
  });
}
