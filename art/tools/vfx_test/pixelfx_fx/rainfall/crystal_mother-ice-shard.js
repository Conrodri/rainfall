// Rainfall (for an iso camera): a shard of crypt crystal fired as a bolt, as a loop, flying towards +x. A compact
// faceted crystal (barely longer than wide, so it reads foreshortened in any direction) with a white leading facet,
// a short frost streak and motes of rime shed behind it.
import { fit, cycle, fly, TAU } from "../../core/index.js";

export const meta = {
  name: "Ice shard bolt",
  desc: "A crypt-crystal shard flying right: a compact faceted crystal with a white leading facet, a short frost streak and rime motes shed behind it.",
  tags: ["rainfall", "boss", "ice", "crystal", "projectile", "loop"],
  size: [56, 28],
  origin: [40, 14],
  duration: 0.4,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06090d", "#0b1219", "#16222c", "#34505e", "#6f98a8", "#8fc8d8", "#BFF4FF", "#dff9ff"],
    radius: 5,
    tail: 22,
    seed: 9,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), R = o.radius, T = o.tail, ph = t / meta.duration;
  // frost streak
  p.shade(-R - T, -R * 0.5, 0, R * 0.5, (x, y, out) => {
    const u = -x / (R + T), hw = R * 0.5 * (1 - u);
    if (Math.abs(y) > hw) return;
    out.c = C[u < 0.3 ? 6 : u < 0.6 ? 5 : 4];
    out.a = 1 - u * 0.6;
    out.k = 0.3 * (1 - u);
    out.l = C[6];
  });
  // the crystal: a rhombus, lit facet on the upper left, white leading facet
  const L = R * 1.3, Wd = R;
  p.poly([[L, 0], [0, -Wd], [-L * 0.8, 0], [0, Wd]], C[4]);
  p.poly([[L, 0], [0, -Wd], [0, 0]], C[7]);
  p.poly([[0, -Wd], [-L * 0.8, 0], [0, 0]], C[5]);
  p.poly([[L, 0], [0, 0], [0, Wd]], C[6]);
  p.line(-L * 0.8, 0, L, 0, C[7]);
  p.glow(0, 0, R * 3, C[6], 0.55 + 0.1 * Math.sin(ph * TAU * 2));
  // rime motes shed behind
  cycle(t, meta.duration, 7, o.seed, 0.3, (age, life, r) => {
    const k = age / life, [x, y] = fly(-R, r.range(-R, R) * 0.5, -T / life, r.range(-16, 16), age);
    p.dot(x, y, C[k < 0.4 ? 7 : 6], 1 - k);
    p.light(x, y, C[6], 0.25 * (1 - k));
  });
}
