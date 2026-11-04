// Rainfall (top-down, for an iso camera): a scalding steam jet lying along the floor, seen from above, as a loop.
// Drawn from the origin (the boiler's vent) to `length` px towards +x, `width` px wide at its end: a hot amber
// throat at the vent, a white core that frays, billows rolling out along it and curling off its edges.
import { fit, cycle, clamp, tileNoise, TAU } from "../../core/index.js";

export const meta = {
  name: "Steam jet",
  desc: "Seen from above, a scalding steam jet along the floor: a hot throat at the vent, a white core fraying out, billows rolling along it and curling off its edges.",
  tags: ["rainfall", "boss", "steam", "jet", "top-down", "directional", "loop"],
  size: [184, 56],
  origin: [6, 28],
  duration: 0.8,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#130c04", "#261808", "#40280c", "#6e4a1a", "#a87626", "#d9982f", "#FFB347", "#ffd58c"],
    length: 144,
    width: 24,
    seed: 3,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), L = o.length, W = o.width, ph = t / meta.duration, S = o.seed;
  const halfAt = (x) => W * 0.5 * (0.3 + 0.7 * Math.sqrt(clamp(x / L)));
  // the jet body: dense at the vent, turbulent and fraying towards the end; the noise scrolls out along it
  p.shade(0, -W * 0.5 - 3, L + 4, W * 0.5 + 3, (x, y, out) => {
    const h = halfAt(x), u = x / L;
    const n = tileNoise(x / 9 - ph * 8, y / 6, 8, 0, S) * 0.5 + tileNoise(x / 4.5 - ph * 16, y / 3, 16, 0, S + 1) * 0.25;
    const e = Math.abs(y) / h + n * 0.5 - (1 - u) * 0.1;
    const end = clamp((L - x) / 18 + n * 0.4);
    if (e > 1 || end <= 0.05) return;
    const core = 1 - e;
    let c = core > 0.7 ? 7 : core > 0.5 ? 6 : core > 0.3 ? 5 : core > 0.12 ? 4 : 3;
    if (u > 0.6 && c > 5) c -= 1;
    if (y > 0 && core < 0.4) c -= 1;
    out.c = C[c];
    out.a = clamp(0.25 + core * 0.75) * end;
    out.k = 0.3 * core * end * (1 - u * 0.5);
    out.l = C[6];
  });
  // billows curling off the edges and the end
  cycle(t, meta.duration, 12, S, 0.5, (age, life, r) => {
    const k = age / life, x0 = r.range(0.25, 1) * L, side = r.next() < 0.5 ? -1 : 1;
    const x = x0 + k * 26, y = side * (halfAt(x0) + k * r.range(4, 10));
    p.disc(x, y, 2 + 4 * k, () => C[k < 0.4 ? 5 : 4], (d) => (1 - d) * 0.5 * (1 - k));
  });
  // the hot throat at the vent
  p.glow(2, 0, 14, C[6], 0.6 + 0.1 * Math.sin(ph * TAU * 2));
}
