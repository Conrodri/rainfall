// Rainfall (top-down, for an iso camera): a tile of wet wake left on the floor behind a wave, seen from above, as a
// loop. Tiles seamlessly along x (exactly `length` px) and in time: foam streaks slide towards -x, the water sheet
// thins towards its edges. Line runs along x, width along y.
import { fit, tileNoise, clamp, wrap } from "../../core/index.js";

export const meta = {
  name: "Wake strip",
  desc: "Seen from above, a seamless tile of wet wake: a thin sheet of water with ragged edges, foam streaks and glints sliding back along it.",
  tags: ["rainfall", "water", "wake", "trail", "tile", "top-down", "ground_dir", "loop"],
  size: [48, 80],
  origin: [8, 40],
  duration: 1.2,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#070D12", "#0D1A22", "#16303F", "#35596C", "#3E86A8", "#5EC8FF", "#A8E6FF"],
    length: 32,
    width: 64,
    seed: 12,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), L = o.length, hw = o.width / 2, S = o.seed, ph = t / meta.duration;
  const flow = ph * L; // one tile per loop, towards -x
  p.shade(0, -hw - 1, L, hw + 1, (x, y, out) => {
    if (x < 0 || x >= L) return;
    const u = wrap(x + flow, L);
    // ragged edges, periodic in x
    const e = hw * (0.82 + 0.12 * tileNoise(u / 8, 2.5, L / 8, 0, S));
    const ay = Math.abs(y);
    if (ay > e) return;
    const q = ay / e;
    const n = tileNoise(u / 8, y / 6, L / 8, 0, S + 1) + 0.6 * tileNoise(u / 4, y / 3, L / 4, 0, S + 2);
    let c = q > 0.86 ? 3 : 2;
    if (n > 0.55) c = 3;
    // foam streaks: thin bright dashes running along the flow
    const lane = Math.abs(Math.sin(y * 0.55 + 1.3));
    if (lane > 0.93 && n > 0.25) c = y < 0 ? 5 : 4;
    if (q > 0.9 && n > 0.1) c = Math.max(c, y < 0 ? 5 : 4); // wet lit rim on the upper side
    out.c = C[clamp(c, 1, 6)];
    out.k = c >= 4 ? 0.22 : 0.03;
    out.l = C[5];
  });
  // glints, two per tile, sliding with the flow
  for (let i = 0; i < 2; i++) {
    const x = wrap(i * (L / 2) + 5 - flow, L), y = (i ? 0.35 : -0.4) * hw;
    p.px(x, y, C[6]);
    p.light(x, y, C[5], 0.35);
  }
}
