// Rainfall (top-down, for an iso camera): one tile of a taut silk thread lying across the floor, seen from above.
// The tile repeats seamlessly along x (its width is exactly `length` px) and loops in time: lay copies end to end
// along the thread's line.
import { fit, clamp, wrap, TAU } from "../../core/index.js";

export const meta = {
  name: "Silk thread",
  desc: "A tile of taut silk seen from above: three twisted strands round a bright core, dew beads that glint, a pulse of light running along it. Tiles end to end along x.",
  tags: ["rainfall", "silk", "thread", "web", "top-down", "tile", "loop"],
  size: [48, 28],
  origin: [8, 14],
  duration: 1,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#05100c", "#0b1c16", "#16302a", "#2a5446", "#4a8070", "#6cc8a4", "#9CF0C8", "#d0fae8"],
    length: 32, // px: one tile
    width: 13, // px across the band
    seed: 1,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), L = o.length, hw = o.width / 2, ph = t / meta.duration;
  const strands = [
    { k: 1, a: hw * 0.42, f: 0.3, c: 5 },
    { k: 2, a: hw * 0.3, f: 2.1, c: 4 },
    { k: 1, a: hw * 0.62, f: 4.0, c: 4 },
  ];
  const sy = (s, x) => Math.sin((x / L) * TAU * s.k + s.f) * s.a;
  const pulse = (x) => {
    const d = wrap(x - ph * L, L), e = Math.min(d, L - d);
    return Math.exp(-(e * e) / 18);
  };
  const beads = [L * 0.27, L * 0.71];
  p.shade(0, -hw - 2, L, hw + 2, (x, y, out) => {
    if (x < 0 || x >= L) return;
    const pu = pulse(x), up = pu > 0.55 ? 1 : 0;
    // the core: two pixels thick, lit on its upper edge
    if (y >= -1 && y < 1) {
      out.c = C[clamp((y < 0 ? 6 : 4) + up, 0, 7)];
      out.k = 0.22 + 0.7 * pu;
      out.l = C[6];
      return;
    }
    for (const s of strands) {
      const d = y - sy(s, x);
      if (Math.abs(d) < 0.55) {
        out.c = C[clamp(s.c + up, 0, 7)];
        out.k = 0.1 + 0.45 * pu;
        out.l = C[6];
        return;
      }
    }
    // dew beads on the first strand
    for (const bx of beads) {
      const by = sy(strands[0], bx), dx = x - bx, dy = y - by;
      if (dx * dx + dy * dy < 2.3) {
        out.c = C[dx < 0 && dy < 0 ? 7 : dx + dy > 0.5 ? 4 : 6];
        out.k = 0.35 + 0.4 * pu;
        out.l = C[7];
        return;
      }
    }
    // a soft halo hugging the band (only inside the tile, so copies join up)
    const k = 0.1 * Math.exp(-(y * y) / 10) * (0.6 + pu);
    if (k > 0.02) {
      out.k = k;
      out.l = C[5];
      out.c = 0;
    }
  });
}
