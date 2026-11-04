// Rainfall (for an iso camera): a gold coin flung and spinning, as a loop, flying towards +x, with a glinting trail.
// The coin turns about its own axis so it reads as a disc from any direction.
import { fit, cycle, fly, TAU } from "../../core/index.js";

export const meta = {
  name: "Coin bolt",
  desc: "A gold coin flung right, spinning edge over face with a sharp glint each turn, a streak of gold light and twinkles trailing behind.",
  tags: ["rainfall", "coin", "gold", "projectile", "loop"],
  size: [56, 28],
  origin: [40, 14],
  duration: 0.6,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0e0a04", "#1c1408", "#33260f", "#5c4620", "#8f6e2e", "#F2C14E", "#F8DE92"],
    radius: 6,
    spins: 3, // turns per loop
    tail: 30,
    seed: 9,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, ph = t / meta.duration;
  const spin = Math.cos(ph * TAU * o.spins), w = Math.max(0.18, Math.abs(spin)), face = spin > 0;
  // streak of light behind
  p.shade(-o.tail, -R * 0.6, 0, R * 0.6, (x, y, out) => {
    const u = -x / o.tail, hw = R * 0.55 * (1 - u);
    if (Math.abs(y) > hw) return;
    if (Math.abs(y) > hw * 0.5 && u > 0.5) return;
    out.c = C[u < 0.3 ? 6 : u < 0.6 ? 5 : 4];
    out.k = 0.3 * (1 - u);
    out.l = C[5];
  });
  // twinkles left behind
  cycle(t, meta.duration, 8, o.seed, 0.35, (age, life, r) => {
    const k = age / life, [x, y] = fly(r.range(-4, 0), r.range(-R, R) * 0.7, (-o.tail / life) * 0.8, 0, age);
    p.dot(x, y, C[k < 0.4 ? 6 : 5], 1 - k);
    p.light(x, y, C[5], 0.4 * (1 - k));
  });
  // the coin: an ellipse squashed by its spin, rim darker, face brighter on the upper left
  p.ellipse(0, 0, R * w, R, (d, a) => {
    if (d > 0.78) return C[Math.cos(a + 2.36) > 0 ? 5 : 3];
    if (!face) return C[d < 0.4 ? 5 : 4];
    return C[d < 0.35 ? 6 : Math.cos(a + 2.36) > 0.2 ? 6 : 5];
  });
  // a sharp glint as it turns edge-on
  const g = 1 - Math.abs(spin);
  if (g > 0.75) {
    const k = (g - 0.75) / 0.25;
    p.line(-R * 1.6 * k, 0, R * 1.6 * k, 0, C[6], k);
    p.line(0, -R * 1.4 * k, 0, R * 1.4 * k, C[6], k);
  }
  p.glow(0, 0, R * 2.4, C[5], 0.45 + 0.35 * g);
}
