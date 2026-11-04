// Rainfall (for an iso camera): Avare's Faillite / Trésor enterré, drawn in screen space for the 2:1 iso view.
// One-shot. An explosion of coins: on the floor, a gold shock ring races out over an elliptic footprint (`radius` px
// across x); above it, coins are flung up in arcs, spinning, and rain back onto the footprint. `dirt`: the blast
// bursts out of the ground (dark clods and a plume of earth thrown up first). The pivot is the centre, on the floor.
import { fit, clamp, smooth, ease, burst, fly, noise2, TAU } from "../../core/index.js";

export const meta = {
  name: "Avare coin blast",
  desc: "An explosion of coins for a 2:1 iso view: a gold shock ring over an elliptic footprint, coins flung up in spinning arcs raining back, a core flash; optionally out of the ground.",
  tags: ["rainfall", "explosion", "coins", "gold", "iso", "one-shot"],
  size: [184, 168],
  origin: [92, 116],
  duration: 1.1,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0e0a04", "#1c1408", "#33260f", "#5c4620", "#8f6e2e", "#F2C14E", "#F8DE92"],
    radius: 80,
    coins: 40,
    dirt: 0,
    seed: 8,
  },
};

const RUN = 0.32;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, S = o.seed, D = meta.duration, dirt = o.dirt > 0;
  const Rf = R * (0.1 + 0.9 * ease.outCubic(clamp(t / RUN))), fade = 1 - smooth(RUN * 0.7, D * 0.75, t);
  // footprint: the shock ring on the floor and a scorched wash inside it
  p.shade(-R - 3, -R / 2 - 3, R + 3, R / 2 + 3, (x, y, out) => {
    const e = Math.hypot(x, y * 2), a = Math.atan2(y * 2, x), jit = noise2(Math.cos(a) * 3, Math.sin(a) * 3, S) * 2;
    const d = Rf - e + jit, B = 8;
    if (d >= -1 && d < B && fade > 0.03) {
      const q = Math.max(0, d) / B, lit = Math.cos(a + 2.36);
      let c = q < 0.2 ? 6 : q < 0.55 ? 5 : 4;
      if (lit < -0.4 && c > 4) c -= 1;
      out.c = C[c];
      out.a = clamp(fade * 1.4, 0, 1);
      out.k = (q < 0.4 ? 0.55 : 0.2) * fade;
      out.l = C[5];
      return;
    }
    if (e < Rf * 0.85) {
      const n = noise2(x * 0.12, y * 0.24, S + 1);
      const sk = 1 - smooth(D * 0.5, D, t);
      if (dirt && n > -0.1) {
        out.c = C[n > 0.4 ? 3 : 2];
        out.a = 0.8 * sk;
      } else if (n > 0.45) {
        out.c = C[3];
        out.a = 0.5 * sk;
      }
      out.k = 0.08 * fade * (1 - e / R);
      out.l = C[4];
    }
  });
  // a plume of earth punching out first (buried treasure)
  if (dirt) {
    burst(26, S + 4, (r) => {
      const a = r.range(-0.5, 0.5) - Math.PI / 2, born = r.range(0, 0.05), age = t - born, life = r.range(0.4, 0.65);
      if (age < 0 || age > life) return;
      const sp = R * r.range(1.6, 3), [x, y] = fly(r.range(-4, 4), 0, Math.cos(a) * sp, Math.sin(a) * sp, age, R * 7, 0.5), k = age / life;
      if (y > 2) return;
      p.circle(x, y, r.range(1.2, 2.6) * (R / 50) * (1 - k * 0.4), (d) => C[d < 0.4 ? 3 : 2], 1 - k * 0.3);
    });
  }
  // the coins: flung up in arcs, spinning, raining back onto the footprint
  burst(o.coins, S + 2, (r) => {
    const a = r.range(0, TAU), born = r.range(0, 0.1) + (dirt ? 0.04 : 0), age = t - born, life = r.range(0.6, 0.9);
    if (age < 0 || age > life) return;
    const land = r.range(0.25, 1) * R, tx = Math.cos(a) * land, ty = (Math.sin(a) * land) / 2;
    const k = age / life, hgt = R * r.range(0.45, 0.95) * 4 * k * (1 - k);
    const x = tx * k, y = ty * k - hgt;
    const spin = Math.abs(Math.cos(age * r.range(18, 30) + a)), face = spin > 0.5;
    if (k > 0.97) return;
    p.ellipse(x, y, 3 * Math.max(0.3, spin), 3, (d) => C[d > 0.7 ? 4 : face ? 6 : 5]);
    p.light(x, y, C[5], 0.35 * (1 - k * 0.6));
  });
  // the core flash and a column of gold glare rising off it
  const f = 1 - smooth(0, 0.22, t);
  p.glow(0, -R * 0.15, R * 0.75, C[6], 0.9 * f);
  if (t < 0.3) {
    const h = R * 0.7 * ease.outCubic(clamp(t / 0.15)), w = R * 0.12 * f;
    p.shade(-w - 1, -h, w + 1, 0, (x, y, out) => {
      if (Math.abs(x) > w * (1 + y / Math.max(1, h) * 0.6)) return;
      out.c = C[x < 0 ? 6 : 5];
      out.a = f;
      out.k = 0.5 * f;
      out.l = C[6];
    });
  }
  // gold dust over the footprint
  burst(24, S + 6, (r) => {
    const a = r.range(0, TAU), born = r.range(0.05, 0.25), age = t - born, life = r.range(0.35, 0.6);
    if (age < 0 || age > life) return;
    const d = r.range(0.2, 1) * R, k = age / life, x = Math.cos(a) * d, y = (Math.sin(a) * d) / 2 - 10 * k;
    p.dot(x, y, C[k < 0.4 ? 6 : 5], 1 - k);
    p.light(x, y, C[5], 0.25 * (1 - k));
  });
}
