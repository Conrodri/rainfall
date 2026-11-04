// Rainfall (iso camera, drawn in screen space): one heavy storm drop falling straight down, as a loop (the game moves
// it). A drop stretched by its speed, lit on its upper left, a streak of rain trailing up behind it and spray shed.
import { fit, cycle, TAU } from "../../core/index.js";

export const meta = {
  name: "Storm drop",
  desc: "Iso: one heavy storm drop falling straight down: a drop stretched by its speed, lit on its upper left, a streak of rain trailing up behind it, spray shed.",
  tags: ["rainfall", "boss", "water", "rain", "drop", "iso", "loop"],
  size: [32, 88],
  origin: [16, 78],
  duration: 0.4,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#070D12", "#0D1A22", "#16303F", "#35596C", "#3E86A8", "#5EC8FF", "#A8E6FF"],
    radius: 4,
    tail: 60,
    seed: 1,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, T = o.tail, ph = t / meta.duration;
  p.shade(-R, -T - R * 2, R, 0, (x, y, out) => {
    const u = (-y - R) / T, hw = R * 0.6 * (1 - u);
    if (u < 0 || u > 1 || Math.abs(x) > hw) return;
    out.c = C[u < 0.25 ? 6 : u < 0.6 ? 5 : 4];
    out.a = 1 - u;
    out.k = 0.3 * (1 - u);
    out.l = C[5];
  });
  p.ellipse(0, -R * 1.2, R, R * 2.2, (d, a) => C[d < 0.4 ? 6 : Math.cos(a + 2.36) > 0 ? 6 : 4]);
  p.dot(-1, -R * 2, C[6]);
  p.glow(0, -R, R * 3, C[5], 0.5 + 0.1 * Math.sin(ph * TAU));
  cycle(t, meta.duration, 5, o.seed, 0.25, (age, life, r) => {
    const q = age / life;
    p.dot(r.range(-R, R) * 1.5, -R * 2 - q * 20 - r.range(0, 20), C[5], 1 - q);
  });
}
