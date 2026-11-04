// Rainfall (top-down, for an iso camera): a whirl of storm water round the caster, seen from above, centred on the
// origin. One-shot. Spiral arms of foam wind out across a disc of `radius` px as its rim races out, the water spins,
// spray is flung off the rim, then it all spends itself into lace.
import { fit, burst, fly, clamp, smooth, ease, tileNoise, TAU } from "../../core/index.js";

export const meta = {
  name: "Storm whirl",
  desc: "Seen from above, a whirl of storm water round the caster: foam arms spiral out over a disc as its rim races out, spray flung off the rim, then it breaks into lace.",
  tags: ["rainfall", "boss", "water", "vortex", "whirl", "top-down", "ground", "one-shot"],
  size: [136, 136],
  origin: [68, 68],
  duration: 0.9,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#070D12", "#0D1A22", "#16303F", "#35596C", "#3E86A8", "#5EC8FF", "#A8E6FF"],
    radius: 56,
    arms: 4,
    seed: 3,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, S = o.seed, top = 6;
  const rim = R * (0.2 + 0.8 * ease.outCubic(clamp(t / 0.22)));
  const k = 1 - smooth(0.35, 0.9, t), spin = t * 7;
  if (k <= 0) return;
  p.shade(-rim - 2, -rim - 2, rim + 2, rim + 2, (x, y, out) => {
    const r = Math.hypot(x, y), a = Math.atan2(y, x);
    if (r > rim + 1) return;
    const lit = Math.cos(a + 2.36);
    // the rim: a foam lip
    if (r > rim - 3) {
      out.c = C[lit > -0.3 ? top : top - 1];
      out.a = k;
      out.k = 0.45 * k;
      out.l = C[top - 1];
      return;
    }
    // spiral arms: phase along a log spiral, turning with time
    const arm = (a * o.arms + Math.log(Math.max(2, r)) * 5 - spin * o.arms) / TAU;
    const f = arm - Math.floor(arm);
    const n = tileNoise(a * 2, r / 6, 0, 0, S) * 0.15;
    const u = r / rim;
    if (Math.abs(f - 0.5) < 0.12 + n - u * 0.04) {
      out.c = C[f > 0.5 ? top : top - 1];
      out.a = k * (0.5 + 0.5 * u);
      out.k = 0.25 * k * u;
      out.l = C[top - 1];
      return;
    }
    out.c = C[u < 0.4 ? 1 : 2];
    out.a = 0.5 * k;
  });
  // spray flung off the rim, tangentially
  burst(26, S + 1, (r) => {
    const ang = r.range(0, TAU), born = r.range(0.05, 0.4), age = t - born, life = r.range(0.2, 0.4);
    if (age < 0 || age > life) return;
    const r0 = R * (0.2 + 0.8 * ease.outCubic(clamp(born / 0.22))), sp = r.range(40, 90), q = age / life;
    const vx = -Math.sin(ang) * sp + Math.cos(ang) * sp * 0.5, vy = Math.cos(ang) * sp + Math.sin(ang) * sp * 0.5;
    const [x, y] = fly(Math.cos(ang) * r0, Math.sin(ang) * r0, vx, vy, age, 0, 4);
    p.dot(x, y, C[q < 0.5 ? top : top - 1], 1 - q);
  });
  if (t < 0.1) p.glow(0, 0, R * 0.5, C[top - 1], 0.6 * (1 - t / 0.1));
}
