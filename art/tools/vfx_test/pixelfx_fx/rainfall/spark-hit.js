// Rainfall (top-down, for an iso camera): a rivet or bullet striking the floor, seen from above. One-shot. A white
// star flash, a scorched pock with a cooling rim, sparks spraying radially and skidding to a stop.
import { fit, burst, fly, smooth, TAU } from "../../core/index.js";

export const meta = {
  name: "Spark hit",
  desc: "Seen from above, a hard impact on the floor: a white star flash, a scorched pock with a glowing rim that cools, sparks spraying out and skidding to a stop.",
  tags: ["rainfall", "impact", "hit", "spark", "bullet", "top-down", "ground", "one-shot"],
  size: [64, 64],
  origin: [32, 32],
  duration: 0.6,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#120804", "#241008", "#3c1c0e", "#a0602e", "#d98038", "#FF9A3C", "#ffc684"],
    radius: 22, // reach of the sparks
    sparks: 24,
    seed: 10,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius;
  const f = 1 - smooth(0, 0.2, t);
  // the scorched pock with a cooling rim
  const cool = smooth(0.05, 0.55, t), fade = 1 - smooth(0.4, 0.6, t);
  if (fade > 0) {
    p.disc(0, 0, 5, () => C[1], () => 0.8 * fade);
    p.ring(0, 0, 5, 1.5, () => C[Math.round(6 - cool * 3)], fade);
    p.light(0, 0, C[5], 0.6 * (1 - cool) * fade);
  }
  // star flash
  if (f > 0) {
    const L = 14 * f + 4;
    p.line(-L, 0, L, 0, C[6], f);
    p.line(0, -L, 0, L, C[6], f);
    p.line(-L * 0.55, -L * 0.55, L * 0.55, L * 0.55, C[5], f);
    p.line(-L * 0.55, L * 0.55, L * 0.55, -L * 0.55, C[5], f);
    p.circle(0, 0, 4 * f + 1, () => C[6]);
    p.glow(0, 0, 18, C[6], 0.9 * f);
  }
  // sparks spraying radially, skidding along the floor
  burst(o.sparks, o.seed, (r) => {
    const a = r.range(0, TAU), sp = r.range(R * 2.5, R * 5), life = r.range(0.2, 0.45), age = t - r.range(0, 0.03);
    if (age < 0 || age > life) return;
    const k = age / life;
    const [x, y] = fly(0, 0, Math.cos(a) * sp, Math.sin(a) * sp, age, 0, 4);
    const [x0, y0] = fly(0, 0, Math.cos(a) * sp, Math.sin(a) * sp, Math.max(0, age - 0.04), 0, 4);
    p.line(x0, y0, x, y, C[k < 0.3 ? 6 : k < 0.6 ? 5 : 4], k < 0.6 ? 1 : (1 - k) / 0.4);
    p.light(x, y, C[5], 0.5 * (1 - k));
  });
}
