// Rainfall (top-down, for an iso camera): a surveyor's stake driven into the floor, seen from above. One-shot. Angular
// cracks shoot out from the hole, a ring of grit is thrown off, hot copper chips spark, the hole glows then cools.
import { fit, clamp, smooth, ease, burst, fly, TAU } from "../../core/index.js";

export const meta = {
  name: "Arpenteuse stake burst",
  desc: "Seen from above, a stake punched into the floor: angular cracks shooting out from a glowing hole, a ring of grit thrown off, hot copper chips sparking.",
  tags: ["rainfall", "impact", "stake", "ground", "crack", "top-down", "one-shot"],
  size: [64, 64],
  origin: [32, 32],
  duration: 0.7,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0b0806", "#1a110c", "#2e1f17", "#6b4a38", "#a8501a", "#FF7A1F", "#ffa860"],
    radius: 20, // px reach of the cracks
    cracks: 6,
    seed: 3,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, D = meta.duration, S = o.seed;
  const grow = ease.outExpo(clamp(t / 0.1)), cool = smooth(0.15, D, t), fade = 1 - smooth(D * 0.6, D, t);
  // the cracks: jagged polylines, hot at first then dark scars
  burst(o.cracks, S, (r, i) => {
    let a = (i / o.cracks) * TAU + r.range(-0.3, 0.3), x = 0, y = 0;
    const len = R * r.range(0.65, 1) * grow, steps = 4;
    for (let s = 0; s < steps; s++) {
      a += r.range(-0.5, 0.5);
      const l = len / steps, nx = x + Math.cos(a) * l, ny = y + Math.sin(a) * l;
      const u = s / steps;
      p.line(x, y, nx, ny, C[cool < 0.4 ? (u < 0.5 ? 6 : 5) : cool < 0.75 ? 4 : 2], fade);
      if (cool < 0.5) p.glowLine(x, y, nx, ny, 3, C[5], 0.25 * (1 - cool) * (1 - u));
      // a short fork on the way
      if (s === 1 && r.next() < 0.7) {
        const fa = a + (r.next() < 0.5 ? -1 : 1) * r.range(0.6, 1);
        p.line(nx, ny, nx + Math.cos(fa) * l * 0.7, ny + Math.sin(fa) * l * 0.7, C[cool < 0.5 ? 5 : 2], fade * 0.8);
      }
      x = nx;
      y = ny;
    }
  });
  // the hole
  p.circle(0, 0, 3.2, (d, an) => C[d > 0.6 ? (Math.cos(an + 2.36) > 0 ? 3 : 1) : cool < 0.5 ? 6 : 1], fade);
  p.glow(0, 0, 9 + 10 * (1 - cool), C[5], 0.8 * (1 - cool));
  // grit ring thrown off the impact
  const gr = R * 0.35 + R * 0.8 * ease.outCubic(clamp(t / 0.35));
  const gk = 1 - smooth(0.12, 0.45, t);
  if (gk > 0) {
    for (let i = 0; i < 28; i++) {
      const a = (i / 28) * TAU + Math.sin(i * 7.1) * 0.1, rr = gr * (0.9 + 0.12 * Math.sin(i * 3.7));
      p.dot(Math.cos(a) * rr, Math.sin(a) * rr, C[Math.cos(a + 2.36) > 0 ? 3 : 2], gk);
    }
  }
  // copper chips sparking out
  burst(14, S + 4, (r) => {
    const a = r.range(0, TAU), sp = r.range(50, 110), life = r.range(0.18, 0.35), age = t - r.range(0, 0.04);
    if (age < 0 || age > life) return;
    const [x, y] = fly(0, 0, Math.cos(a) * sp, Math.sin(a) * sp, age, 0, 6), k = age / life;
    p.dot(x, y, C[k < 0.4 ? 6 : 5], 1 - k);
    p.light(x, y, C[5], 0.45 * (1 - k));
  });
}
