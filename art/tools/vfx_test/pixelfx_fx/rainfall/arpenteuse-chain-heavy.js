// Rainfall (top-down, for an iso camera): one tile of a HEAVY hot copper chain lying along the floor, seen from above
// (Arpenteuse, Chaîne lestée). Thick links, slag glowing between them, molten beads that well up and stick to the floor
// beside it. Tiles seamlessly along x (exactly `length` px, two links) and loops in time.
import { fit, clamp, cycle, TAU } from "../../core/index.js";

export const meta = {
  name: "Arpenteuse heavy chain",
  desc: "A tile of heavy copper chain seen from above: two thick links lit from the top left, slag glowing in the joints, molten beads welling up beside it. Tiles end to end along x.",
  tags: ["rainfall", "chain", "metal", "heavy", "top-down", "tile", "loop"],
  size: [52, 40],
  origin: [8, 20],
  duration: 0.8,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0b0806", "#1a110c", "#2e1f17", "#6b4a38", "#a8501a", "#FF7A1F", "#ffa860"],
    length: 32, // px: one tile = two links
    heft: 1.35, // link size relative to a plain chain
    seed: 4,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), L = o.length, ph = t / meta.duration, h = L / 2, H = o.heft;
  const heat = (x) => 0.5 + 0.5 * Math.cos((x / L - ph) * TAU);
  const flat = [h * 0.5, h * 0.5 + L, h * 0.5 - L], edge = [h * 1.5, h * 1.5 - L, h * 1.5 + L];
  const rx = h * 0.62 * Math.min(H, 1.25), ry = h * 0.46 * H, hx = h * 0.26, hy = h * 0.15 * H, bt = h * 0.2 * H;
  const ext = h * 0.75 * H + 2;
  p.shade(0, -ext, L, ext, (x, y, out) => {
    if (x < 0 || x >= L) return;
    const hk = heat(x), up = hk > 0.8 ? 1 : 0;
    // the edge-on link: a thick bar, lit top, dark underside
    for (const cx of edge) {
      const dx = Math.abs(x - cx);
      if (dx < h * 0.78 && Math.abs(y) < bt) {
        const end = dx > h * 0.78 - 1.2;
        const v = y / bt;
        out.c = C[clamp((v < -0.45 ? 6 : v < 0.1 ? 4 : v < 0.6 ? 3 : 1) - (end ? 1 : 0) + up, 0, 6)];
        out.k = (v < -0.45 ? 0.45 : 0.14) * (0.4 + hk);
        out.l = C[5];
        return;
      }
    }
    for (const cx of flat) {
      const dx = (x - cx) / rx, dy = y / ry, d = dx * dx + dy * dy;
      const ix = (x - cx) / hx, iy = y / hy, di = ix * ix + iy * iy;
      if (d > 1 || di < 1) continue;
      const rim = d > 0.5;
      const lit = (x - cx) / rx + y / ry < -0.2;
      const inner = di < 1.8;
      let c = lit ? (rim ? 5 : 4) : rim ? 2 : 3;
      if (inner) c = lit ? 1 : 4;
      out.c = C[clamp(c + up, 0, 6)];
      out.k = (lit && rim ? 0.35 : 0.12) * (0.4 + hk);
      out.l = C[5];
      return;
    }
    // glowing slag and a hot shadow pooled on the floor under the chain
    const g = Math.exp(-(y * y) / (h * 2.2));
    const k = 0.2 * g * (0.35 + hk);
    if (g > 0.55 && hk > 0.55) {
      out.c = C[2];
      out.a = 0.7;
    }
    if (k > 0.02) {
      out.k = k;
      out.l = C[4];
    }
  });
  // molten beads welling up beside the links, stuck to the floor (the chain glues what it touches)
  cycle(t, meta.duration, 5, o.seed, 0.8, (age, life, r) => {
    const x = r.range(2, L - 2), side = r.next() < 0.5 ? -1 : 1, y = side * r.range(ry * 0.9, ry * 1.25);
    const q = age / life, s = 0.8 + 1.4 * Math.sin(Math.PI * q);
    p.circle(x, y, s, (d) => C[d < 0.45 ? 6 : 5], 0.9);
    p.light(x, y, C[5], 0.5 * Math.sin(Math.PI * q));
  });
}
