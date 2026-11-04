// Rainfall (top-down, for an iso camera): an electric discharge through the water around the eel, seen from above,
// centred on the origin. One-shot. The band from `r0` to `r1` px is struck at once: a flash over the band, jagged
// arcs racing round it and forking across it, sparks spat out of the water, the band's two edges ringing.
import { fit, burst, fly, clamp, smooth, rng, TAU } from "../../core/index.js";

export const meta = {
  name: "Eel discharge",
  desc: "Seen from above, an electric discharge through the water round the eel: a flash over a ring band, jagged arcs racing round and forking across it, sparks spat out.",
  tags: ["rainfall", "boss", "lightning", "ring", "water", "top-down", "ground", "one-shot"],
  size: [168, 168],
  origin: [84, 84],
  duration: 0.6,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06090d", "#0b1219", "#16222c", "#34505e", "#6f98a8", "#8fc8d8", "#BFF4FF", "#dff9ff"],
    r0: 32,
    r1: 76,
    seed: 6,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), R0 = o.r0, R1 = o.r1, S = o.seed;
  const fade = 1 - smooth(0.12, 0.55, t);
  if (fade <= 0) return;
  // the struck band: a pale wash and its two ringing edges
  p.shade(-R1 - 1, -R1 - 1, R1 + 1, R1 + 1, (x, y, out) => {
    const r = Math.hypot(x, y);
    if (r > R1 || r < R0) return;
    if (r > R1 - 1.5 || r < R0 + 1.5) {
      out.c = C[t < 0.1 ? 7 : 6];
      out.a = fade;
      out.k = 0.45 * fade;
      out.l = C[6];
      return;
    }
    const w = 0.3 * fade * (1 - smooth(0, 0.3, t));
    if (w < 0.05) return;
    out.c = C[4];
    out.a = w;
    out.k = w * 0.5;
    out.l = C[5];
  });
  // jagged arcs, re-rolled every 2 frames: some running round the band, some forking across it
  const step = Math.floor(t * 15), r = rng(S, step);
  const n = 7;
  for (let i = 0; i < n; i++) {
    const across = i % 3 === 0;
    let a = r.range(0, TAU), rad = across ? R0 : r.range(R0 + 4, R1 - 4);
    let x = Math.cos(a) * rad, y = Math.sin(a) * rad;
    for (let s = 0; s < 8; s++) {
      if (across) rad = Math.min(R1, rad + (R1 - R0) / 8 + r.range(-2, 2)), a += r.range(-0.08, 0.08);
      else a += r.range(0.05, 0.12), rad = clamp(rad + r.range(-4, 4), R0 + 2, R1 - 2);
      const nx = Math.cos(a) * rad, ny = Math.sin(a) * rad;
      p.line(x, y, nx, ny, C[7], fade);
      p.light(nx, ny, C[6], 0.45 * fade);
      x = nx, y = ny;
    }
  }
  if (t < 0.07) p.glow(0, 0, R1, C[6], 0.6 * (1 - t / 0.07));
  // sparks and droplets spat out of the water
  burst(24, S + 2, (rr) => {
    const ang = rr.range(0, TAU), rad = rr.range(R0, R1), sp = rr.range(20, 60), life = rr.range(0.2, 0.45);
    if (t > life) return;
    const [x, y] = fly(Math.cos(ang) * rad, Math.sin(ang) * rad, Math.cos(ang) * sp, Math.sin(ang) * sp, t, 0, 5), q = t / life;
    p.dot(x, y, C[q < 0.4 ? 7 : 6], 1 - q);
  });
}
