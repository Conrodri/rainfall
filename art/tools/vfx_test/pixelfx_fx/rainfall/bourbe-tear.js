// Rainfall (top-down, for an iso camera): Bourbe tears a clod of mud off her body and flings it towards +x, seen from
// above. One-shot. A ragged splatter bursts from the origin (her flank) along a narrow fan, clods and strings of mud
// fly out along it and land as splats, the torn edge drips. Range `reach` px.
import { fit, burst, fly, clamp, smooth, ease, tileNoise } from "../../core/index.js";

export const meta = {
  name: "Bourbe tear",
  desc: "Seen from above, a clod of mud ripped off the caster towards the right: a ragged splatter from the origin along a narrow fan, clods flying out and landing as splats.",
  tags: ["rainfall", "mud", "tear", "splatter", "top-down", "directional", "one-shot"],
  size: [76, 56],
  origin: [10, 28],
  duration: 0.7,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06100a", "#0f1c14", "#1d3324", "#3a5e42", "#5f9a6c", "#8DDBA8", "#C2F0D2"],
    reach: 52,
    span: 0.45,
    seed: 19,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), L = o.reach, A = o.span, S = o.seed;
  const fade = 1 - smooth(0.45, meta.duration, t);
  // splatter: a fan of mud streaks from the origin, growing out fast, ragged
  const Rf = L * 0.75 * ease.outCubic(clamp(t / 0.14));
  p.shade(-2, -L * 0.5, L, L * 0.5, (x, y, out) => {
    const r = Math.hypot(x, y), a = Math.atan2(y, x);
    if (r > Rf || Math.abs(a) > A) return;
    const q = r / L, ea = Math.abs(a) / A;
    const lane = tileNoise(a * 12, 0.5, 0, 0, S);
    const len = Rf * (0.45 + 0.55 * (lane * 0.5 + 0.5));
    if (r > len || ea > 0.95 - q * 0.3) return;
    const n = tileNoise(x / 3, y / 3, 0, 0, S + 1);
    if (n < -0.3 + q * 0.5) return;
    let c = n > 0.4 ? 3 : 2;
    if (y < 0 && n > 0.55) c = 4;
    out.c = C[c];
    out.a = fade;
    out.k = (c >= 4 ? 0.18 : 0.02) * fade;
    out.l = C[5];
  });
  // clods flying out along the fan, landing as splats
  burst(14, S + 2, (r) => {
    const a = r.range(-A, A) * 0.8, sp = r.range(0.5, 1) * L * 3.2, age = t - r.range(0, 0.06);
    if (age < 0) return;
    const fl = 0.22;
    const [x, y] = fly(4, 0, Math.cos(a) * sp, Math.sin(a) * sp, Math.min(age, fl), 0, 8);
    if (age < fl) {
      p.disc(x, y, 1.8, () => C[age < 0.08 ? 4 : 3], 1);
      p.light(x, y, C[5], 0.2);
    } else if (fade > 0.05) {
      p.dot(x, y, C[2], fade);
      p.dot(x + 1, y, C[3], fade);
      p.dot(x, y + 1, C[2], fade);
    }
  });
  // the torn edge: a wet glint and drips at the origin
  if (t < 0.25) p.glow(4, 0, 14, C[5], 0.55 * (1 - t / 0.25));
  burst(5, S + 4, (r) => {
    const age = t - r.range(0.05, 0.3);
    if (age < 0 || age > 0.3) return;
    const [x, y] = fly(r.range(0, 4), r.range(-4, 4), r.range(-10, 10), r.range(-8, 8), age, 0, 2);
    p.dot(x, y, C[3], 1 - age / 0.3);
  });
}
