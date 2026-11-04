// Rainfall (screen space, for an iso camera): Tocsin's head bursts like a cracked bell. Not flat: a shock ring races out
// across the floor as a 2:1 ellipse to `radius` px (the blast's reach), a squat dome of bronze fire and soot boils up
// over the pivot, bell shards arc out and fall back, a white-hot flash at the heart. Pivot = the floor at the blast.
// One-shot.
import { fit, burst, fly, flyV, clamp, smooth, ease, noise2, TAU } from "../../core/index.js";

export const meta = {
  name: "Tocsin bell blast",
  desc: "A head bursting like a cracked bell: a 2:1 shock ring races across the floor to the reach, a dome of bronze fire and soot boils up, shards arc out, a white-hot flash at the heart.",
  tags: ["rainfall", "tocsin", "explosion", "bell", "fire", "shockwave", "iso", "one-shot"],
  size: [176, 160],
  origin: [88, 98],
  duration: 0.95,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0d0704", "#1d1108", "#3b2a1a", "#6a4a2a", "#b05a1a", "#FF7A1F", "#ffb06a"],
    radius: 64,
    seed: 121,
  },
};

const RUN = 0.32;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, S = o.seed;
  // the floor ring (2:1)
  const Rf = R * (0.1 + 0.9 * ease.outCubic(clamp(t / RUN))), fade = 1 - smooth(RUN * 0.8, RUN + 0.4, t);
  if (fade > 0.02) {
    const B = 8;
    p.shade(-Rf - 3, -Rf / 2 - 3, Rf + 3, Rf / 2 + 3, (x, y, out) => {
      const e = Math.hypot(x, y * 2), a = Math.atan2(y * 2, x);
      const d = Rf - e + noise2(Math.cos(a) * 3 + t * 2, Math.sin(a) * 3, S) * 1.5;
      if (d < -1) return;
      if (d < B) {
        const q = Math.max(0, d) / B, lit = Math.cos(a + 2.36);
        let c = q < 0.2 ? 6 : q < 0.5 ? 5 : 4;
        if (lit < -0.4 && c > 4) c -= 1;
        if (fade < 0.5) c = Math.max(3, c - Math.round((0.5 - fade) * 6));
        out.c = C[c];
        out.k = (q < 0.5 ? 0.55 : 0.2) * fade;
        out.l = C[5];
        return;
      }
      // scorched floor inside, dithered
      if ((Math.floor(x) + Math.floor(y)) % 2 === 0) { out.c = C[1]; out.a = 0.55 * fade; }
    });
  }
  // the dome of fire and soot boiling up: puffs rising, hot at first, cooling to soot
  burst(34, S, (r) => {
    const born = r.range(0, 0.12), a = t - born, life = r.range(0.45, 0.75);
    if (a < 0 || a > life) return;
    const q = a / life, an = r.range(-Math.PI, 0), sp = r.range(24, 80);
    const x = Math.cos(an) * sp * ease.outCubic(clamp(a / 0.3)) * 0.9;
    const y = Math.sin(an) * sp * 0.5 * ease.outCubic(clamp(a / 0.3)) - 34 * ease.outCubic(q) - 6;
    const rad = 6 + 11 * ease.outCubic(clamp(q * 1.5));
    const heat = q < 0.25 ? 6 : q < 0.45 ? 5 : q < 0.65 ? 4 : 2;
    p.disc(x, y, rad, (dd, ang) => C[clamp(heat - (dd > 0.6 ? 1 : 0) - (Math.cos(ang + 2.36) < -0.3 ? 1 : 0), 1, 6)], (dd) => (1 - dd * dd) * (q < 0.7 ? 0.9 : (1 - q) / 0.3 * 0.9));
    if (heat >= 5) p.glow(x, y, rad * 1.8, C[5], 0.3 * (1 - q));
  });
  // bell shards arcing out and falling back
  burst(16, S + 2, (r) => {
    const a = t - r.range(0, 0.04), life = r.range(0.5, 0.8);
    if (a < 0 || a > life) return;
    const an = r.range(0, TAU), sp = r.range(60, 130), up = r.range(80, 160), q = a / life;
    const vx = Math.cos(an) * sp, vy = Math.sin(an) * sp * 0.5 - up;
    const [x, y] = fly(0, -6, vx, vy, a, 420, 1.2);
    const sp2 = a * r.range(12, 22), s = r.range(1.5, 2.8);
    p.tri(x - Math.cos(sp2) * s, y - Math.sin(sp2) * s, x + Math.cos(sp2) * s, y + Math.sin(sp2) * s, x + Math.sin(sp2) * s * 0.6, y - Math.cos(sp2) * s * 0.6, C[q < 0.4 ? 6 : 4]);
    const [ux, uy] = flyV(vx, vy, a, 420, 1.2), l = Math.hypot(ux, uy) || 1;
    p.line(x, y, x - (ux / l) * 4, y - (uy / l) * 4, C[5], 0.6 * (1 - q));
    p.light(x, y, C[5], 0.35 * (1 - q));
  });
  // the flash
  const fl = 1 - smooth(0, 0.16, t);
  if (fl > 0) {
    p.circle(0, -8, 4 + 6 * (1 - fl), C[6], fl);
    p.glow(0, -8, 40, C[6], 0.9 * fl);
  }
  p.glow(0, 0, R, C[5], 0.3 * fade);
}
