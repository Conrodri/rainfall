// Rainfall (top-down, for an iso camera): a tile of Averse's Gutter, a rivulet running along the floor towards +x,
// seen from above, as a loop. Tiles seamlessly along x (exactly `length` px) and in time: chevron ripples and foam
// streaks run downstream (+x) between two wet dark banks. Line runs along x, width along y.
import { fit, tileNoise, clamp, wrap } from "../../core/index.js";

export const meta = {
  name: "Averse rivulet",
  desc: "Seen from above, a seamless tile of running water: a channel between wet dark banks, chevron ripples and foam streaks flowing right, glints.",
  tags: ["rainfall", "water", "stream", "rivulet", "tile", "top-down", "ground_dir", "loop"],
  size: [56, 36],
  origin: [4, 18],
  duration: 0.8,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#04090f", "#08141f", "#0f2a38", "#2f6577", "#2a9fb5", "#5FD4E8", "#9fe8f2"],
    length: 48,
    width: 24,
    seed: 6,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), L = o.length, hw = o.width / 2, S = o.seed, ph = t / meta.duration;
  const flow = ph * L; // one tile per loop, towards +x
  p.shade(0, -hw - 2, L, hw + 2, (x, y, out) => {
    if (x < 0 || x >= L) return;
    const u = wrap(x - flow, L);
    const e = hw * (0.9 + 0.1 * tileNoise(u / 6, 3.5, L / 6, 0, S));
    const ay = Math.abs(y);
    if (ay > e + 1.5) return;
    if (ay > e - 1) {
      // wet bank: dark lip, lit on the upper side
      out.c = C[y < 0 ? 4 : 2];
      out.k = y < 0 ? 0.12 : 0;
      out.l = C[5];
      return;
    }
    const q = ay / e;
    const n = tileNoise(u / 6, y / 4, L / 6, 0, S + 1) + 0.5 * tileNoise(u / 3, y / 2, L / 3, 0, S + 2);
    let c = q < 0.5 ? 3 : 2;
    if (n > 0.5) c += 1;
    // chevrons pointing downstream
    const ch = wrap(u + ay * 0.9, 12);
    if (ch < 1.4 && q < 0.85) c = Math.max(c, n > -0.2 ? 5 : 4);
    // foam streaks along the current
    const lane = Math.abs(Math.sin(y * 0.6 + 0.8));
    if (lane > 0.95 && n > 0.2) c = Math.max(c, 4);
    out.c = C[clamp(c, 1, 6)];
    out.k = c >= 5 ? 0.3 : c >= 4 ? 0.14 : 0.03;
    out.l = C[5];
  });
  // glints riding the flow
  for (let i = 0; i < 3; i++) {
    const x = wrap(i * (L / 3) + 7 + flow, L), y = (i - 1) * 0.35 * hw;
    p.px(x, y, C[6]);
    p.light(x, y, C[5], 0.35);
  }
}
