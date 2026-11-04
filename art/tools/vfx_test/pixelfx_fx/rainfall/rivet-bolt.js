// Rainfall (for an iso camera): a red-hot rivet fired as a slug, as a loop, flying towards +x. A compact, nearly round
// glowing head (stays readable when the flight is foreshortened), a short streak and puffs of soot behind.
import { fit, cycle, fly, TAU } from "../../core/index.js";

export const meta = {
  name: "Rivet bolt",
  desc: "A red-hot rivet flying right: a compact glowing slug with a white-hot face, a short bright streak and soot puffs and sparks left behind.",
  tags: ["rainfall", "rivet", "bullet", "projectile", "metal", "loop"],
  size: [64, 28],
  origin: [44, 14],
  duration: 0.4,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#120804", "#241008", "#3c1c0e", "#a0602e", "#d98038", "#FF9A3C", "#ffc684"],
    radius: 5,
    tail: 28,
    seed: 15,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, T = o.tail, ph = t / meta.duration;
  // soot puffs left behind
  cycle(t, meta.duration, 5, o.seed, 0.4, (age, life, r) => {
    const k = age / life, x = -R - r.range(2, 6) - k * T * 0.7, y = r.range(-2, 2);
    p.disc(x, y, 1.5 + 2.5 * k, () => C[2], (d) => (1 - d) * 0.5 * (1 - k));
  });
  // short streak
  p.shade(-R - T, -R * 0.6, 0, R * 0.6, (x, y, out) => {
    const u = -x / (R + T), hw = R * 0.6 * (1 - u);
    if (Math.abs(y) > hw) return;
    out.c = C[u < 0.3 ? 6 : u < 0.6 ? 5 : 4];
    out.k = 0.35 * (1 - u);
    out.l = C[5];
  });
  // the slug: barely elongated, so it stays a blob when foreshortened
  p.ellipse(0, 0, R * 1.15, R, (d, a) => {
    if (d < 0.45) return C[6];
    if (d > 0.8) return C[Math.cos(a + 2.36) > 0 ? 5 : 3];
    return C[Math.cos(a) > 0.2 ? 6 : 5];
  });
  p.glow(0, 0, R * 3, C[5], 0.65 + 0.1 * Math.sin(ph * TAU * 2));
  // sparks shed backwards
  cycle(t, meta.duration, 8, o.seed + 1, 0.25, (age, life, r) => {
    const k = age / life, [x, y] = fly(-R, r.range(-R, R) * 0.5, -T / life, r.range(-20, 20), age);
    p.dot(x, y, C[k < 0.4 ? 6 : 5], 1 - k);
    p.light(x, y, C[5], 0.3 * (1 - k));
  });
}
