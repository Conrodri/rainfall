// Rainfall (screen space, for an iso camera): Tocsin's smoking head, as a loop. Not flat: a low blanket of soot-grey
// smoke lies over a 2:1 ellipse on the floor (`radius` px across, half that tall), its puffs rolling, swelling and
// lifting a little; embers glow in it; at the centre the head tolls, sending a faint ring through the smoke.
// Pivot = the floor where the head lies.
import { fit, cycle, clamp, smooth, TAU } from "../../core/index.js";

export const meta = {
  name: "Tocsin smoke bell",
  desc: "A low blanket of soot smoke over a 2:1 floor ellipse, puffs rolling and lifting, embers glowing in it, the head tolling at the centre and sending a faint ring through the smoke.",
  tags: ["rainfall", "tocsin", "smoke", "cloud", "zone", "bell", "iso", "loop"],
  size: [160, 104],
  origin: [80, 64],
  duration: 2,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0d0d0c", "#1e1e1c", "#2f2f2c", "#4a4944", "#6d6a62", "#8c887c", "#FF7A1F"],
    radius: 64,
    puffs: 60,
    seed: 131,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, S = o.seed, ph = t / meta.duration;
  // the floor under the smoke: a soft dark ellipse marking the reach (no dither: it reads as a mesh on a lit floor)
  p.shade(-R, -R / 2, R, R / 2, (x, y, out) => {
    const e = Math.hypot(x / R, (y * 2) / R);
    if (e > 1) return;
    if (e > 0.94) { out.c = C[3]; out.a = 0.5; return; }
    out.c = C[e < 0.6 ? 2 : 1];
    out.a = 0.42 * (1 - e * e * 0.6);
  });
  // the blanket: rolling puffs, sampled inside the ellipse, rising a little as they swell and thin
  cycle(t, meta.duration, o.puffs, S, (g) => g.range(1.2, 2.0), (age, life, r) => {
    const a = r.range(0, TAU), d = Math.sqrt(r.next()) * 0.85, k = age / life;
    const x = Math.cos(a) * d * R + r.range(-6, 6) * k, y = (Math.sin(a) * d * R) / 2 - 10 * k - 3;
    const rad = r.range(8, 14) * (0.7 + 0.5 * k), al = Math.sin(Math.PI * k);
    p.disc(x, y, rad, (dd, an) => C[Math.cos(an + 2.36) > 0.2 && dd < 0.7 ? 5 : dd < 0.6 ? 4 : 3], (dd) => 0.48 * al * (1 - dd * dd));
  });
  // embers glowing in the smoke
  cycle(t, meta.duration, 14, S + 2, 0.9, (age, life, r) => {
    const a = r.range(0, TAU), d = Math.sqrt(r.next()) * 0.8, k = age / life;
    const x = Math.cos(a) * d * R, y = (Math.sin(a) * d * R) / 2 - 14 * k;
    const tw = Math.sin(Math.PI * k);
    p.dot(x, y, C[6], tw);
    p.light(x, y, C[6], 0.45 * tw);
  });
  // the head tolls twice per loop: a hot pulse at the centre and a faint ring through the smoke
  for (const t0 of [0, 1]) {
    const a = ((t - t0) % meta.duration + meta.duration) % meta.duration;
    if (a > 0.9) continue;
    const q = a / 0.9, rr = R * (0.15 + 0.85 * q);
    p.shade(-rr - 2, -rr / 2 - 2, rr + 2, rr / 2 + 2, (x, y, out) => {
      const e = Math.hypot(x, y * 2);
      if (Math.abs(e - rr) > 1.5) return;
      out.c = C[5];
      out.a = 0.5 * (1 - q);
      out.k = 0.2 * (1 - q);
      out.l = C[6];
    });
    p.glow(0, -4, 18, C[6], 0.5 * (1 - smooth(0, 0.3, a)));
  }
  p.circle(0, -3, 2.5, C[6], 0.9);
  p.glow(0, 0, R * 0.7, C[6], 0.08);
}
