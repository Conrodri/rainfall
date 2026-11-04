// Rainfall (top-down, for an iso camera): Arpenteuse's Halage, one tile of the band that flares along the laid chain,
// seen from above. One-shot. The chain line goes white hot, a heat wash spreads `band` px either side, and streaks
// rush in from the band's edges to the chain (what is caught is hauled against it). Tiles along x (`length` px).
import { fit, clamp, smooth, ease, burst } from "../../core/index.js";

export const meta = {
  name: "Arpenteuse haul band",
  desc: "Seen from above, one tile of a flaring band along a chain: the line goes white hot, a heat wash fills the band either side, streaks rush in from its edges to the chain, sparks.",
  tags: ["rainfall", "chain", "pull", "band", "top-down", "tile", "one-shot"],
  size: [44, 52],
  origin: [6, 26],
  duration: 0.45,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0b0806", "#1a110c", "#2e1f17", "#6b4a38", "#a8501a", "#FF7A1F", "#ffa860"],
    length: 32, // px along x (one tile)
    band: 19, // px half width of the band
    seed: 6,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), L = o.length, B = o.band, D = meta.duration;
  const flash = 1 - smooth(0.05, 0.3, t), spread = ease.outCubic(clamp(t / 0.12)), fade = 1 - smooth(0.2, D, t);
  // heat wash over the band, strongest on the chain, ragged edge that closes in
  const edge = B * spread * (1 - 0.35 * smooth(0.15, D, t));
  p.shade(0, -B - 1, L, B + 1, (x, y, out) => {
    if (x < 0 || x >= L || fade < 0.03) return;
    const ay = Math.abs(y);
    const wob = 1.5 * Math.sin((x / L) * Math.PI * 4 + (y > 0 ? 1.3 : 0));
    if (ay > edge + wob) return;
    const q = ay / Math.max(1, edge);
    if (ay < 2.2) {
      // the chain line itself, white hot then cooling
      out.c = C[flash > 0.4 ? 6 : 5];
      out.k = 0.6 * (0.4 + flash) * fade;
      out.l = C[5];
      return;
    }
    if (q > 0.88) {
      // bright rim of the band
      out.c = C[y < 0 ? 5 : 4];
      out.a = 0.85 * fade;
      out.k = 0.25 * fade;
      out.l = C[5];
      return;
    }
    // the wash: sparse heat shimmer, denser near the chain
    const n = Math.sin(x * 1.7 + y * 0.9) * Math.sin(x * 0.6 - y * 1.3);
    if (n > 0.55 - 0.5 * (1 - q)) {
      out.c = C[q < 0.4 ? 4 : 3];
      out.a = 0.7 * fade;
    }
    out.k = 0.14 * (1 - q) * fade;
    out.l = C[4];
  });
  // haul streaks: dashes rushing from the band edges to the chain
  burst(10, o.seed, (r, i) => {
    const x = (i + r.range(0.1, 0.9)) * (L / 10), side = i % 2 ? 1 : -1, born = r.range(0.02, 0.18), life = r.range(0.12, 0.2);
    const age = t - born;
    if (age < 0 || age > life) return;
    const u = ease.inQuad(age / life), y0 = side * B * r.range(0.75, 1), y = y0 * (1 - u), len = 3 + 4 * (1 - u);
    p.line(x, y, x, y + side * len, C[u < 0.5 ? 5 : 6], 1 - u * 0.5);
    p.light(x, y, C[5], 0.4 * (1 - u));
  });
  // sparks thrown off the chain
  burst(6, o.seed + 3, (r) => {
    const x = r.range(1, L - 1), born = r.range(0, 0.1), life = r.range(0.2, 0.32), age = t - born;
    if (age < 0 || age > life) return;
    const sp = r.range(30, 70) * (r.next() < 0.5 ? -1 : 1), k = age / life;
    p.dot(x + r.range(-6, 6) * k, sp * age, C[k < 0.5 ? 6 : 5], 1 - k);
    p.light(x, sp * age, C[5], 0.35 * (1 - k));
  });
}
