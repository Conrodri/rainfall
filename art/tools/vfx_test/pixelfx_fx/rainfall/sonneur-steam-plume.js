// Rainfall (iso camera, drawn in screen space): a scalding plume of steam standing up from a floor vent, as a loop.
// The vent is a 2:1 ellipse of `radius` px; puffs well up from it hot, rise `height` px, swell, cool and thin.
import { fit, cycle, clamp, TAU } from "../../core/index.js";

export const meta = {
  name: "Steam plume",
  desc: "Iso: a scalding plume of steam standing up from a floor vent: a hot 2:1 vent mouth, puffs welling up that swell, cool and thin as they rise.",
  tags: ["rainfall", "boss", "steam", "plume", "iso", "loop"],
  size: [64, 112],
  origin: [32, 96],
  duration: 1.2,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#130c04", "#261808", "#40280c", "#6e4a1a", "#a87626", "#d9982f", "#FFB347", "#ffd58c"],
    radius: 12,
    height: 80,
    seed: 2,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), R = o.radius, Hh = o.height, ph = t / meta.duration;
  p.ellipse(0, 0, R, R * 0.5, (d) => C[d < 0.5 ? 6 : 4], 0.8);
  p.glow(0, -2, R * 1.4, C[6], 0.45 + 0.1 * Math.sin(ph * TAU * 2));
  cycle(t, meta.duration, 14, o.seed, 0.9, (age, life, r) => {
    const q = age / life, h = Hh * q * r.range(0.7, 1);
    const x = r.range(-0.4, 0.4) * R + Math.sin(q * 5 + r.range(0, 6)) * R * 0.25 * q, y = -h;
    const rad = R * (0.35 + 0.65 * q) * r.range(0.8, 1.1);
    const ci = q < 0.15 ? 7 : q < 0.35 ? 6 : q < 0.6 ? 5 : 4;
    p.disc(x, y, rad, (d) => C[d < 0.4 ? Math.min(7, ci + 1) : ci], (d) => (1 - d * d) * (1 - q) * 0.75);
    if (q < 0.3) p.light(x, y, C[6], 0.35 * (1 - q / 0.3));
  });
}
