// Rainfall (top-down, for an iso camera): an electric eel's whip lying along the floor, seen from above, as a loop.
// Drawn from the origin (the eel) to `length` px towards +x, `width` px wide: a dark slick tendril rippling in an S,
// a cold glow down its spine, sparks crawling along it and arcs snapping off its edges, a crackling tip.
import { fit, cycle, clamp, noise, TAU } from "../../core/index.js";

export const meta = {
  name: "Eel whip",
  desc: "Seen from above, an electric eel's whip along the floor: a dark tendril rippling in an S, a cold glowing spine, sparks crawling along it, arcs snapping off it.",
  tags: ["rainfall", "boss", "whip", "lightning", "water", "top-down", "directional", "loop"],
  size: [128, 40],
  origin: [6, 20],
  duration: 0.8,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06090d", "#0b1219", "#16222c", "#34505e", "#6f98a8", "#8fc8d8", "#BFF4FF", "#dff9ff"],
    length: 112,
    width: 18,
    seed: 5,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), L = o.length, W = o.width, ph = t / meta.duration, S = o.seed;
  const amp = W * 0.18;
  const mid = (x) => Math.sin((x / L * 1.5 - ph) * TAU) * amp * clamp(x / 20);
  const half = (x) => W * 0.5 * (0.55 + 0.45 * (1 - x / L)) * 0.9;
  p.shade(0, -W / 2 - 2, L + 2, W / 2 + 2, (x, y, out) => {
    const m = mid(x), h = half(x), d = Math.abs(y - m) / h;
    if (d > 1 || x > L) return;
    const pulse = Math.max(0, Math.sin((x / 22 - ph * 3) * TAU)) ** 4;
    if (d < 0.28) {
      out.c = C[pulse > 0.5 ? 7 : 6];
      out.k = 0.35 + 0.4 * pulse;
      out.l = C[6];
      return;
    }
    out.c = C[d > 0.8 ? (y - m < 0 ? 3 : 1) : 2];
    out.k = 0.05 + 0.15 * pulse * (1 - d);
    out.l = C[5];
  });
  // arcs snapping off the edges
  cycle(t, meta.duration, 7, S, 0.12, (age, life, r) => {
    const x0 = r.range(0.15, 0.95) * L, side = r.next() < 0.5 ? -1 : 1, len = r.range(5, 10);
    let x = x0, y = mid(x0) + side * half(x0);
    for (let i = 0; i < 4; i++) {
      const nx = x + r.range(-3, 3), ny = y + side * len / 4;
      p.line(x, y, nx, ny, C[7], 1 - age / life);
      p.light(nx, ny, C[6], 0.5);
      x = nx, y = ny;
    }
  });
  // the crackling tip
  const tx = L - 2, ty = mid(tx);
  p.glow(tx, ty, 10, C[6], 0.55 + 0.3 * Math.abs(noise(t * 20, S)));
  p.dot(tx, ty, C[7], 1);
}
