// Rainfall (for an iso camera): a drifting ember, as a loop, flying towards +x. A compact white-hot core, a flickering
// flame jacket leaning back, a trail of sparks and ash left behind. Round, so it reads from any direction.
import { fit, cycle, fly, noise, TAU } from "../../core/index.js";

export const meta = {
  name: "Ember bolt",
  desc: "A compact drifting ember flying right: a white-hot core in a flickering flame jacket leaning back, sparks and ash streaming off behind it.",
  tags: ["rainfall", "fire", "ember", "projectile", "loop"],
  size: [72, 36],
  origin: [52, 18],
  duration: 0.8,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0d0504", "#1f0b06", "#3a1a10", "#6b3a26", "#a8481a", "#FF7319", "#ffa35a"],
    radius: 6,
    tail: 40,
    seed: 8,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), Rr = o.radius, ph = t / meta.duration;
  // sparks and ash streaming back
  cycle(t, meta.duration, 24, o.seed, (g) => g.range(0.3, 0.55), (age, life, r) => {
    const k = age / life, sp = (o.tail / life) * 1.4, wob = r.range(-16, 16);
    const [x, y] = fly(r.range(-2, 2), r.range(-Rr, Rr) * 0.6, -sp, wob, age, 0, 1.5);
    const c = k < 0.3 ? 6 : k < 0.6 ? 5 : k < 0.85 ? 4 : 3;
    p.dot(x, y, C[c], k < 0.7 ? 1 : (1 - k) / 0.3);
    if (k < 0.25) p.dot(x + 1, y, C[5], 1);
    if (k < 0.6) p.light(x, y, C[5], 0.4 * (1 - k / 0.6));
  });
  // flame jacket leaning back, flickering
  p.shade(-Rr * 3.2, -Rr * 1.6, Rr * 1.4, Rr * 1.6, (x, y, out) => {
    const fl = 0.85 + 0.15 * Math.sin(ph * TAU * 3 + y * 0.6) + 0.1 * noise(ph * 8 + y * 0.3, 2);
    const ex = x < 0 ? x / (3 * fl) : x; // stretched backwards
    const d = Math.hypot(ex, y * (1 + 0.15 * Math.sin(ph * TAU * 2))) / (Rr * 1.25);
    if (d > 1) return;
    const lit = (-x - y) / (Rr * 2);
    let c = d < 0.35 ? 6 : d < 0.6 ? 5 : d < 0.85 ? 4 : 3;
    if (lit > 0.2 && c < 6 && d < 0.75) c += 1;
    out.c = C[c];
    out.k = d < 0.6 ? 0.6 : 0.2;
    out.l = C[5];
  });
  p.circle(Rr * 0.15, -Rr * 0.1, Rr * 0.45, () => C[6]);
  p.glow(0, 0, Rr * 3.2, C[5], 0.55 + 0.1 * Math.sin(ph * TAU * 4));
}
