// Rainfall (for an iso camera, screen space): a geyser bursting out of the floor. One-shot. Drawn as the camera sees
// it: the hit circle on the floor is a 2:1 ellipse of half width `radius` px round the origin (a foam ring that
// flashes, then a ripple), and a column of water `height` px tall blasts straight up at once from the whole
// footprint, holds with a churning head, then collapses; drops rain back inside the ring.
import { fit, burst, fly, clamp, smooth, ease, tileNoise, TAU } from "../../core/index.js";

export const meta = {
  name: "Geyser burst",
  desc: "Seen by the iso camera, a geyser bursts from the floor: a foam ring flashes on the hit circle, a column of water blasts up at once, holds, collapses and rains back.",
  tags: ["rainfall", "water", "geyser", "column", "eruption", "iso", "billboard", "one-shot"],
  size: [96, 132],
  origin: [48, 108],
  duration: 1.15,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#070D12", "#0D1A22", "#16303F", "#35596C", "#3E86A8", "#5EC8FF", "#A8E6FF"],
    radius: 24, // half width of the floor ellipse (px)
    height: 72, // column height (px)
    seed: 6,
  },
};

const UP = 0.09, HOLD = 0.42, DOWN = 0.78;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, Ry = R / 2, S = o.seed;
  const rise = ease.outExpo(clamp(t / UP)), fall = smooth(HOLD, DOWN, t);
  const Hc = o.height * rise * (1 - fall);
  const W = R * 0.72 * (1 - 0.35 * fall); // column half width at its foot
  // floor: churned water inside the ring, the foam rim flashing white, then a ripple running out
  const fl = 1 - smooth(0.6, meta.duration - 0.08, t);
  if (fl > 0.01) p.shade(-R * 1.5, -Ry * 1.5, R * 1.5, Ry * 1.5, (x, y, out) => {
    const e = Math.hypot(x / R, y / Ry);
    const rip = 1 + 0.45 * smooth(0.15, 0.9, t);
    if (e < 1) {
      const n = tileNoise(x / 4 + t * 6, y / 2, 0, 0, S);
      const rim = e > 0.82;
      const c = rim ? (t < 0.08 ? 6 : y < 0 ? 5 : 4) : n > 0.35 ? 4 : 2;
      if (!rim && n < -0.3) return;
      out.c = C[c];
      out.a = (rim ? 1 : 0.75) * fl;
      out.k = (rim ? 0.4 : 0.1) * fl;
      out.l = C[5];
      return;
    }
    if (t > 0.15 && Math.abs(e - rip) < 0.06) {
      out.c = C[y < 0 ? 5 : 4];
      out.a = 0.8 * fl;
      out.k = 0.2 * fl;
      out.l = C[5];
    }
  });
  // the column: streaks racing up it, lit down its left side, a darker right flank
  if (Hc > 1) {
    p.shade(-W - 2, -Hc - W, W + 2, 1, (x, y, out) => {
      const h = -y; // height above the floor
      if (h < 0 || h > Hc) return;
      const u = h / Math.max(1, Hc);
      const w = W * (1 - 0.35 * u) + 1.2 * Math.sin(h * 0.4 + t * 30);
      if (Math.abs(x) > w) return;
      const sx = x / w;
      const n = tileNoise(x / 2.5, (h + t * 260) / 9, 0, 0, S + 1);
      let c = sx < -0.55 ? 6 : sx > 0.6 ? 3 : n > 0.25 ? 5 : 4;
      if (n < -0.45 && Math.abs(sx) < 0.5) c = 3;
      if (fall > 0.3 && n < 0.1 - fall * 0.3 && Math.abs(sx) > 0.2) return; // tearing apart as it collapses
      out.c = C[c];
      out.k = (c >= 5 ? 0.35 : 0.08) * (1 - fall * 0.6);
      out.l = C[5];
    });
    // the churning head
    const hr = W * (0.9 + 0.25 * Math.sin(t * 40));
    p.shade(-hr - 2, -Hc - hr - 2, hr + 2, -Hc + hr + 2, (x, y, out) => {
      const dx = x, dy = y + Hc, d = Math.hypot(dx, dy * 1.2);
      const n = tileNoise(dx / 3 + t * 9, dy / 3 - t * 12, 0, 0, S + 2);
      if (d > hr * (0.8 + 0.25 * n)) return;
      out.c = C[d < hr * 0.45 || dx < -hr * 0.3 ? 6 : 5];
      out.k = 0.45 * (1 - fall * 0.6);
      out.l = C[6];
    });
  }
  // drops thrown off the head, arcing out and falling back inside the ring
  burst(26, S + 4, (r) => {
    const born = r.range(0.04, 0.45), age = t - born, life = r.range(0.3, 0.55);
    if (age < 0 || age > life) return;
    const hb = o.height * ease.outExpo(clamp(born / UP)) * (1 - smooth(HOLD, DOWN, born));
    const a = r.range(0, TAU), sp = r.range(15, 45);
    const [x, y] = fly(Math.cos(a) * W * 0.6, -hb, Math.cos(a) * sp, -r.range(20, 70), age, 320, 1);
    if (y > Math.sin(a) * Ry * 0.6) return; // landed
    const q = age / life;
    p.dot(x, y, C[q < 0.4 ? 6 : 5], q < 0.7 ? 1 : (1 - q) / 0.3);
    p.light(x, y, C[5], 0.35 * (1 - q));
  });
  // light: a flash on the floor, then a glow climbing with the column
  if (t < 0.18) p.glow(0, 0, R * 1.4, C[6], 0.7 * (1 - t / 0.18));
  if (Hc > 1) p.glow(0, -Hc * 0.6, W * 2.5, C[5], 0.35 * (1 - fall));
}
