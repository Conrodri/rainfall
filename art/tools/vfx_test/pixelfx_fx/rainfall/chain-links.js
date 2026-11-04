// Rainfall (top-down, for an iso camera): one tile of a hot copper chain lying along the floor, seen from above.
// The tile repeats seamlessly along x (its width is exactly `length` px, two links) and loops in time: lay copies
// end to end along the chain's path.
import { fit, clamp, wrap, TAU } from "../../core/index.js";

export const meta = {
  name: "Chain links",
  desc: "A tile of copper chain seen from above: a flat oval link then one on its edge, lit from the top left, with heat running along it in a slow wave. Tiles end to end along x.",
  tags: ["rainfall", "chain", "metal", "top-down", "tile", "loop"],
  size: [52, 32],
  origin: [8, 16],
  duration: 0.8,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0b0806", "#1a110c", "#2e1f17", "#6b4a38", "#a8501a", "#FF7A1F", "#ffa860"],
    length: 32, // px: one tile = two links
    seed: 1,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), L = o.length, ph = t / meta.duration, h = L / 2;
  const heat = (x) => 0.5 + 0.5 * Math.cos((x / L - ph) * TAU);
  // link centres (and their copies one tile over, so the ends join)
  const flat = [h * 0.5, h * 0.5 + L, h * 0.5 - L], edge = [h * 1.5, h * 1.5 - L, h * 1.5 + L];
  const rx = h * 0.6, ry = h * 0.46, hx = h * 0.32, hy = h * 0.19, bt = h * 0.16; // flat oval and its hole
  p.shade(0, -h * 0.75, L, h * 0.75, (x, y, out) => {
    if (x < 0 || x >= L) return;
    const hk = heat(x), up = hk > 0.85 ? 1 : 0;
    // the edge-on link: a bar with a lit top, over the flat links' ends
    for (const cx of edge) {
      const dx = Math.abs(x - cx);
      if (dx < h * 0.74 && Math.abs(y) < bt) {
        const end = dx > h * 0.74 - 1;
        out.c = C[clamp((y < -bt * 0.35 ? 6 : y < bt * 0.35 ? 4 : 2) - (end ? 1 : 0) + up, 0, 6)];
        out.k = (y < -bt * 0.35 ? 0.35 : 0.12) * (0.4 + hk);
        out.l = C[5];
        return;
      }
    }
    for (const cx of flat) {
      const dx = (x - cx) / rx, dy = y / ry, d = dx * dx + dy * dy;
      const ix = (x - cx) / hx, iy = y / hy, di = ix * ix + iy * iy;
      if (d > 1 || di < 1) continue;
      const rim = d > 0.55; // outer half of the ring
      const lit = (x - cx) / rx + y / ry < -0.2; // top-left side
      const inner = di < 1.9;
      let c = lit ? (rim ? 5 : 4) : rim ? 2 : 3;
      if (inner) c = lit ? 2 : 4; // the hole's far wall catches the light
      out.c = C[clamp(c + up, 0, 6)];
      out.k = (lit && rim ? 0.3 : 0.1) * (0.4 + hk);
      out.l = C[5];
      return;
    }
    // a warm glow along the chain, inside the tile only
    const k = 0.12 * Math.exp(-(y * y) / (h * 1.2)) * (0.3 + hk);
    if (k > 0.02) {
      out.k = k;
      out.l = C[4];
      out.c = 0;
    }
  });
}
