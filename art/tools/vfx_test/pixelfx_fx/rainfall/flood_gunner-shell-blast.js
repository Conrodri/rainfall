// Rainfall (iso camera, drawn in screen space): a heavy blast on the floor. The floor is a 2:1 ellipse (the game's 30°
// camera) and the blast stands up out of it: a white flash, a shock ring racing over the floor ellipse to `radius`
// px (x) by radius / 2 (y), a scorch, a column of `fire` (1: fire balls cooling to smoke; 0: dust only) thrown up,
// chunks flung out that land, smoke and grit settling.
import { fit, burst, fly, clamp, smooth, ease, noise, TAU } from "../../core/index.js";

export const meta = {
  name: "Shell blast",
  desc: "Iso blast: a flash, a shock ring racing over a 2:1 floor ellipse, a scorch, a column of fire balls (or dust) thrown up, chunks flung out, smoke settling.",
  tags: ["rainfall", "boss", "explosion", "impact", "aoe", "iso", "one-shot"],
  size: [244, 200],
  origin: [122, 140],
  duration: 1.5,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#120804", "#241008", "#3c1c0e", "#6a3a1e", "#a0602e", "#d98038", "#FF9A3C", "#ffc684"],
    radius: 86,
    height: 90,
    fire: 1,
    run: 0.22,
    seed: 6,
  },
};

const SQ = 0.5;

export function draw(p, t, o) {
  const C = fit(o.palette, 8), R = o.radius, Hh = o.height, S = o.seed, F = o.fire > 0;
  const ring = R * (0.15 + 0.85 * ease.outCubic(clamp(t / o.run)));
  const fade = 1 - smooth(o.run, o.run + 0.35, t);
  // the scorch / dust bed over the struck ellipse
  const bed = 1 - smooth(0.5, meta.duration, t);
  if (bed > 0) {
    p.shade(-ring, -ring * SQ, ring, ring * SQ, (x, y, out) => {
      const d = Math.hypot(x / ring, y / (ring * SQ));
      if (d > 1) return;
      const n = noise(Math.atan2(y, x) * 3 + d * 4, S) * 0.25;
      if (d > 0.9 + n * 0.3) return;
      out.c = C[d < 0.35 && t < 0.4 && F ? 5 : d < 0.6 ? 2 : 1];
      out.a = 0.55 * bed * (1 - d * 0.5);
      out.k = F ? 0.15 * bed * (1 - d) : 0;
      out.l = C[5];
    });
  }
  // the shock ring
  if (fade > 0) {
    p.shade(-ring - 2, -ring * SQ - 2, ring + 2, ring * SQ + 2, (x, y, out) => {
      const d = Math.hypot(x / ring, y / (ring * SQ));
      if (d > 1 || d < 0.86) return;
      out.c = C[d > 0.95 ? 7 : 6];
      if (y > 0 && d < 0.93) out.c = C[5];
      out.a = fade;
      out.k = 0.55 * fade;
      out.l = C[6];
    });
  }
  if (t < 0.1) p.glow(0, -6, R * 0.9, C[7], 1 - t / 0.1);
  // the column: puffs thrown straight up, hot at first then cooling to smoke (dust only: pale grit)
  burst(F ? 22 : 16, S + 1, (r) => {
    const born = r.range(0, 0.12), age = t - born, life = r.range(0.6, 1.1);
    if (age < 0 || age > life) return;
    const q = age / life, h = Hh * r.range(0.35, 1) * ease.outCubic(clamp(age / 0.45));
    const x = r.range(-1, 1) * R * 0.22 * (1 + q), y = -h + r.range(-4, 4);
    const rad = (F ? 5 : 6) + 9 * q * r.range(0.6, 1);
    const ci = F ? (q < 0.15 ? 7 : q < 0.3 ? 6 : q < 0.45 ? 5 : 3) : (q < 0.3 ? 4 : 3);
    p.disc(x, y, rad, (d) => C[d < 0.4 && ci > 4 ? Math.min(7, ci + 1) : ci], (d) => (1 - d * d) * (1 - q) * (F ? 0.9 : 0.55));
    if (F && q < 0.4) p.light(x, y, C[6], 0.5 * (1 - q / 0.4));
  });
  // chunks flung out, landing on the floor
  burst(14, S + 2, (r) => {
    const ang = r.range(0, TAU), sp = r.range(60, 140), life = r.range(0.45, 0.8);
    if (t > life) return;
    const [x, y] = fly(0, -4, Math.cos(ang) * sp, Math.sin(ang) * sp * SQ - r.range(60, 140), t, 320, 1), q = t / life;
    p.rect(x - 1, y - 1, 2, 2, C[q < 0.3 && F ? 6 : 2]);
    if (F) p.light(x, y, C[5], 0.3 * (1 - q));
  });
  // dust rolling out along the floor behind the ring
  burst(18, S + 3, (r) => {
    const ang = r.range(0, TAU), born = r.range(0.05, 0.2), age = t - born, life = r.range(0.6, 1.1);
    if (age < 0 || age > life) return;
    const q = age / life, rr = R * (0.6 + 0.4 * ease.outQuad(q));
    p.disc(Math.cos(ang) * rr, Math.sin(ang) * rr * SQ - q * 6, 3 + 6 * q, () => C[3], (d) => (1 - d) * 0.4 * (1 - q));
  });
}
