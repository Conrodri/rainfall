// Rainfall (for an iso camera): an arrow in flight, as a loop, flying towards +x. A pale shaft, a bright head, red
// fletching and a glowing streak behind. `charged` adds a thicker streak and a spiral of sparks round it.
import { fit, cycle, fly, clamp, TAU } from "../../core/index.js";

export const meta = {
  name: "Arrow bolt",
  desc: "An arrow flying right: a pale lit shaft, a bright steel head, red fletching and a glowing streak behind; charged, it trails a spiral of sparks.",
  tags: ["rainfall", "arrow", "projectile", "bow", "loop"],
  size: [96, 32],
  origin: [72, 16],
  duration: 0.4,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0c0507", "#1c0a0e", "#35121a", "#6a1b2a", "#B02438", "#FF3A4F", "#FF8C98"],
    length: 34, // shaft + head
    tail: 36, // glowing streak behind the fletching
    charged: 0,
    seed: 14,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), L = o.length, T = o.tail, ph = t / meta.duration, ch = o.charged ? 1 : 0;
  const x0 = -L + 8; // the nock
  // the glowing streak, tapering back
  const sw = 3 + ch * 2;
  p.shade(x0 - T, -sw - 1, x0, sw + 1, (x, y, out) => {
    const u = (x0 - x) / T, hw = sw * (1 - u);
    if (Math.abs(y) > hw + 0.3) return;
    if (u > 0.55 && ((x + Math.floor(ph * 8)) & 1)) return; // broken up towards its end
    out.c = C[u < 0.25 ? 6 : u < 0.6 ? 5 : 4];
    out.k = 0.45 * (1 - u) + 0.2 * ch;
    out.l = C[5];
  });
  // shaft: three pixels, lit on top
  p.line(x0, -1, 2, -1, C[6]);
  p.line(x0, 0, 2, 0, C[6]);
  p.line(x0, 1, 2, 1, C[4]);
  // fletching: three red vanes each side
  for (let i = 0; i < 3; i++) {
    const fx = x0 + 1 + i * 2;
    p.line(fx, -2, fx - 4, -6, C[5]);
    p.line(fx, 2, fx - 4, 6, C[4]);
  }
  // head: a bright barbed point
  p.tri(1, -5, 1, 6, 12, 0.5, () => C[6]);
  p.line(2, -3, 1, -5, C[5]);
  p.line(2, 4, 1, 6, C[4]);
  p.glow(5, 0, 12 + ch * 6, C[5], 0.7 + 0.2 * ch);
  p.glow(x0 - T * 0.3, 0, 8 + ch * 6, C[5], 0.3 + 0.2 * ch);
  // charged: sparks spiralling round the streak
  if (ch) {
    for (let i = 0; i < 2; i++) {
      for (let j = 0; j < 10; j++) {
        const u = j / 10, x = x0 - u * T, a = (u * 3 + ph + i * 0.5) * TAU, y = Math.sin(a) * (5 - 3 * u);
        p.dot(x, y, C[Math.cos(a) > 0 ? 6 : 5], 1 - u * 0.7);
        p.light(x, y, C[5], 0.3 * (1 - u));
      }
    }
  }
  // embers shed behind
  cycle(t, meta.duration, 6 + ch * 6, o.seed, 0.3, (age, life, r) => {
    const k = age / life, [x, y] = fly(x0 - r.range(0, 6), r.range(-2, 2), -T / life, r.range(-10, 10), age);
    p.dot(x, y, C[k < 0.4 ? 6 : 5], 1 - k);
  });
}
