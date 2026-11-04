// Rainfall (top-down, for an iso camera): brine flooding out over a disc round the origin, seen from above, except a
// dry wedge (the nave) of half angle `gap` facing +x. One-shot. A foam front races out from `r0` to `r1` px all round
// but the nave, laced water floods in behind it, then it stills and thins to a sheen of lace.
import { fit, burst, fly, clamp, smooth, ease } from "../../core/index.js";
import { waterFront } from "./_lib.js";

export const meta = {
  name: "Brine flood",
  desc: "Seen from above, brine floods out over a disc but for a dry wedge: a foam front races out all round, laced water floods in behind it, then thins to lace.",
  tags: ["rainfall", "boss", "water", "flood", "tide", "top-down", "ground", "one-shot"],
  size: [232, 232],
  origin: [116, 116],
  duration: 1.8,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06090d", "#0b1219", "#16222c", "#34505e", "#6f98a8", "#8fc8d8", "#BFF4FF", "#dff9ff"],
    r0: 10,
    r1: 108,
    gap: 0.7, // half angle of the dry wedge (radians), centred on +x
    run: 0.9,
    band: 8,
    seed: 5,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), R1 = o.r1, gap = o.gap, A = Math.PI - gap;
  const R = o.r0 + (R1 - o.r0) * ease.outCubic(clamp(t / o.run));
  const k = 1 - smooth(o.run * 0.8, meta.duration, t);
  if (k <= 0.01) return;
  // waterFront draws an arc centred on +x (half span up to a right angle): three arcs, rotated round the dry wedge
  const Ah = A / 3;
  for (const c of [gap + Ah, Math.PI, -(gap + Ah)]) {
    p.place(meta.origin[0], meta.origin[1], false, c);
    waterFront(p, C, { cx: 0, R, A: Ah * 1.04, band: o.band, trail: Math.min(R - 2, 100), flow: t * 40, wob: t * 2, k, seed: o.seed, curl: 1, light: 0.5 });
  }
  p.place(meta.origin[0], meta.origin[1]);
  // the dry wedge's edges: brine lapping along them
  burst(20, o.seed + 1, (r) => {
    const side = r.next() < 0.5 ? -1 : 1, born = r.range(0.1, o.run), age = t - born, life = r.range(0.3, 0.6);
    if (age < 0 || age > life) return;
    const along = r.range(0.25, 1) * R, ang = side * gap;
    const [x, y] = fly(Math.cos(ang) * along, Math.sin(ang) * along, 0, side * r.range(10, 25), age, 0, 6), q = age / life;
    p.dot(x, y, C[q < 0.5 ? 7 : 6], (1 - q) * k);
  });
}
