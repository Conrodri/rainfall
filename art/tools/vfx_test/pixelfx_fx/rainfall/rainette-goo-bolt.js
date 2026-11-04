// Rainfall (for an iso camera): a glob of sticky vase spat towards +x, as a loop. Round and wobbling so it reads as a
// ball from any direction, a wet highlight on the upper left, strings and drips trailing behind it.
import { fit, cycle, fly, noise2, TAU } from "../../core/index.js";

export const meta = {
  name: "Rainette goo bolt",
  desc: "A round glob of sticky vase flying right, wobbling, wet highlight on the upper left, strings and drips trailing behind.",
  tags: ["rainfall", "mud", "goo", "spit", "projectile", "loop"],
  size: [48, 24],
  origin: [34, 12],
  duration: 0.6,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#070b09", "#0f1612", "#1a261f", "#4a5f54", "#6b8c7b", "#8DBBA8", "#b5d6c6"],
    radius: 6,
    tail: 26,
    seed: 3,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, ph = (t / meta.duration) * TAU;
  // strings of goo stretched behind, thinning out
  for (let s = -1; s <= 1; s += 2) {
    const amp = 1.2 + 0.6 * Math.sin(ph + s);
    for (let x = -o.tail * 0.7; x < 0; x++) {
      const u = -x / (o.tail * 0.7), y = s * R * 0.35 * (1 - u) + amp * Math.sin(x * 0.4 + ph * 2) * u;
      if (u > 0.75 && ((x | 0) & 1)) continue;
      p.dot(x, y, C[u < 0.4 ? 4 : 3], 1 - u * 0.7);
    }
  }
  // drips shed behind
  cycle(t, meta.duration, 7, o.seed, 0.35, (age, life, r) => {
    const k = age / life, [x, y] = fly(r.range(-3, 0), r.range(-R, R) * 0.5, -o.tail / life * 0.7, r.range(-10, 10), age);
    p.circle(x, y, 1.3 * (1 - k * 0.6), (d) => C[d < 0.4 ? 5 : 3], 1 - k * 0.5);
    p.light(x, y, C[5], 0.25 * (1 - k));
  });
  // the glob: wobbling outline, dark body, wet highlight
  p.shade(-R - 2, -R - 2, R + 2, R + 2, (x, y, out) => {
    const a = Math.atan2(y, x), r = Math.hypot(x, y);
    const e = R * (1 + 0.1 * Math.sin(a * 3 + ph * 2) + 0.06 * noise2(Math.cos(a) * 2, Math.sin(a) * 2 + t * 3, o.seed));
    if (r > e) return;
    const q = r / e, lit = Math.cos(a + 2.36);
    let c = q > 0.82 ? (lit > 0 ? 5 : 2) : lit * q > 0.35 ? 5 : q < 0.5 ? 3 : 4;
    if (lit > 0.6 && q > 0.35 && q < 0.65) c = 6;
    out.c = C[c];
    out.k = c >= 5 ? 0.3 : 0.06;
    out.l = C[5];
  });
  p.glow(0, 0, R * 2.2, C[5], 0.35);
}
