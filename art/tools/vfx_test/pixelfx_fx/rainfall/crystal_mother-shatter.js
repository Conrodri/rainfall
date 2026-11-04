// Rainfall (top-down, for an iso camera): crypt crystal shattering on the floor, seen from above, centred on the
// origin. One-shot. A white flash, a ring of frost racing out to `radius` px, angular shards flung out radially,
// spinning and skidding to a stop, rime dust settling.
import { fit, burst, fly, clamp, smooth, ease, noise, TAU } from "../../core/index.js";

export const meta = {
  name: "Crystal shatter",
  desc: "Seen from above, crystal shattering on the floor: a white flash, a frost ring racing out, angular shards flung out radially that skid to a stop, rime dust settling.",
  tags: ["rainfall", "boss", "ice", "crystal", "shatter", "top-down", "ground", "one-shot"],
  size: [112, 112],
  origin: [56, 56],
  duration: 0.8,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06090d", "#0b1219", "#16222c", "#34505e", "#6f98a8", "#8fc8d8", "#BFF4FF", "#dff9ff"],
    radius: 40,
    seed: 4,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), R = o.radius, S = o.seed;
  const front = R * (0.15 + 0.85 * ease.outCubic(clamp(t / 0.2))), fade = 1 - smooth(0.2, 0.6, t);
  if (fade > 0) {
    p.shade(-front - 2, -front - 2, front + 2, front + 2, (x, y, out) => {
      const r = Math.hypot(x, y), a = Math.atan2(y, x);
      const d = front - r + noise(Math.cos(a) * 3, Math.sin(a) * 3 + S) * 1.5;
      if (d < -1 || d > 4) return;
      out.c = C[d < 1.5 ? 7 : Math.cos(a + 2.36) > 0 ? 6 : 5];
      out.a = fade;
      out.k = 0.5 * fade;
      out.l = C[6];
    });
  }
  // rime dust left over the disc
  const dust = 1 - smooth(0.3, 0.8, t);
  if (dust > 0) p.disc(0, 0, front * 0.9, (d) => C[d < 0.3 ? 4 : 3], (d) => 0.25 * dust * (1 - d));
  if (t < 0.08) p.glow(0, 0, R * 0.7, C[7], 1 - t / 0.08);
  // angular shards flung out, spinning, skidding to a stop
  burst(16, S, (r) => {
    const ang = r.range(0, TAU), sp = R * r.range(2.2, 4), life = r.range(0.4, 0.7);
    if (t > life) return;
    const [x, y] = fly(Math.cos(ang) * 3, Math.sin(ang) * 3, Math.cos(ang) * sp, Math.sin(ang) * sp, t, 0, 7), q = t / life;
    const s = r.range(2, 3.5), spin = t * r.range(-14, 14) + ang;
    const c = Math.cos(spin), si = Math.sin(spin);
    p.tri(x + c * s, y + si * s, x - si * s * 0.5, y + c * s * 0.5, x + si * s * 0.5, y - c * s * 0.5, C[q < 0.4 ? 7 : 5], 1 - q * q);
    p.light(x, y, C[6], 0.35 * (1 - q));
  });
}
