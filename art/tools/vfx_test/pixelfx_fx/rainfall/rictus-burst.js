// Rainfall (screen space, for an iso camera): a stand-in puppet bursting. Not flat: a 2:1 ellipse (the blast's reach
// on the floor, radius `radius` px across, half that tall) flashes out, while porcelain shards, splinters of lacquered
// wood and snapped threads are thrown up and fall back. Pivot = the floor under the puppet; the flash sits at its
// chest. One-shot.
import { fit, burst, fly, flyV, clamp, smooth, ease, TAU, noise2 } from "../../core/index.js";

export const meta = {
  name: "Rictus decoy burst",
  desc: "A stand-in puppet bursts: a 2:1 ring flashes out across the floor, porcelain shards fly up and fall back, snapped threads whip, a pale flash at chest height.",
  tags: ["rainfall", "rictus", "explosion", "decoy", "porcelain", "iso", "one-shot"],
  size: [100, 100],
  origin: [50, 58],
  duration: 0.75,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0a0d0d", "#141b1b", "#26312f", "#46585a", "#6f8f8a", "#9FC8C0", "#c9e3dd"],
    radius: 38,
    chest: 8, // px above the floor of the flash
    seed: 51,
  },
};

const RUN = 0.24;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, H = o.chest, S = o.seed;
  const front = (tt) => R * (0.15 + 0.85 * ease.outCubic(clamp(tt / RUN)));
  const Rf = front(t), fade = 1 - smooth(RUN * 0.8, meta.duration * 0.85, t);
  // the floor ring: an ellipse 2:1, bright leading band lit from the upper left, a dim dithered disc inside
  if (fade > 0) {
    const B = 6;
    p.shade(-Rf - 2, -Rf / 2 - 2, Rf + 2, Rf / 2 + 2, (x, y, out) => {
      const e = Math.hypot(x, y * 2), a = Math.atan2(y * 2, x);
      const jit = noise2(Math.cos(a) * 3 + t * 3, Math.sin(a) * 3, S) * 1.2;
      const d = Rf - e + jit;
      if (d < -1) return;
      if (d < B) {
        const q = Math.max(0, d) / B, lit = Math.cos(a + 2.36);
        let c = q < 0.25 ? 6 : q < 0.6 ? 5 : 4;
        if (lit < -0.4 && c > 4) c -= 1;
        if (fade < 0.5) c = Math.max(3, c - Math.round((0.5 - fade) * 6));
        out.c = C[c];
        out.k = (q < 0.5 ? 0.5 : 0.18) * fade;
        out.l = C[5];
        return;
      }
      if ((Math.floor(x) + Math.floor(y)) % 2 === 0 && fade > 0.3) {
        out.c = C[2];
        out.a = 0.5 * fade * (1 - e / Rf);
      }
    });
  }
  // the flash at chest height, and its light on the floor
  const fl = 1 - smooth(0, 0.18, t);
  if (fl > 0) {
    p.circle(0, -H, 5 * (1 - fl * 0.3) + 2, (d) => C[d < 0.5 ? 6 : 5], fl);
    p.glow(0, -H, 26, C[6], 0.8 * fl);
  }
  p.glow(0, 0, R * 0.9, C[5], 0.25 * fade);
  // a puff of pale sawdust and lacquer smoke boiling up where the puppet stood
  burst(16, S + 4, (r) => {
    const a2 = t - r.range(0, 0.06), life = r.range(0.35, 0.55);
    if (a2 < 0 || a2 > life) return;
    const q = a2 / life, an = r.range(-Math.PI, 0), sp = r.range(10, 36), k = ease.outCubic(clamp(a2 / 0.25));
    const x = Math.cos(an) * sp * k, y = -H + Math.sin(an) * sp * 0.6 * k - 14 * ease.outCubic(q);
    const rad = 3 + 6 * ease.outCubic(clamp(q * 1.6));
    p.disc(x, y, rad, (dd, ang) => C[clamp((q < 0.3 ? 5 : 4) - (dd > 0.6 ? 1 : 0) - (Math.cos(ang + 2.36) < -0.3 ? 1 : 0), 2, 6)], (dd) => (1 - dd * dd) * 0.75 * (1 - q));
  });
  // porcelain shards and splinters thrown up, tumbling, falling back past the floor
  burst(34, S, (r) => {
    const born = r.range(0, 0.05), a2 = t - born, life = r.range(0.4, 0.65);
    if (a2 < 0 || a2 > life) return;
    const ang = r.range(0, TAU), sp = r.range(40, 110), up = r.range(60, 150);
    const vx = Math.cos(ang) * sp, vy = Math.sin(ang) * sp * 0.5 - up;
    const [x, y] = fly(0, -H, vx, vy, a2, 380, 1.5), q = a2 / life;
    const [ux, uy] = flyV(vx, vy, a2, 380, 1.5), l = Math.hypot(ux, uy) || 1;
    const shard = r.next() < 0.6, sz = shard ? r.range(2, 3.6) : 3;
    const spin = a2 * r.range(10, 25), cx = Math.cos(spin) * sz, sy = Math.sin(spin) * sz;
    if (shard) p.tri(x - cx, y - sy, x + cx, y + sy, x - sy * 0.6, y + cx * 0.6, C[q < 0.3 ? 6 : q < 0.7 ? 5 : 4]);
    else p.line(x, y, x - (ux / l) * 3, y - (uy / l) * 3, C[q < 0.3 ? 5 : 3]);
    p.light(x, y, C[5], 0.3 * (1 - q));
  });
  // snapped threads whipping outward from the chest
  burst(6, S + 2, (r) => {
    const a2 = t - r.range(0, 0.04), life = 0.3;
    if (a2 < 0 || a2 > life) return;
    const ang = r.range(-Math.PI, 0) + r.range(-0.4, 0.4), q = a2 / life, len = 10 + 26 * ease.outCubic(q);
    let px = 0, py = -H;
    for (let i = 1; i <= 8; i++) {
      const u = i / 8, w = Math.sin(u * 5 + q * 9) * 3 * u;
      const nx = Math.cos(ang) * len * u - Math.sin(ang) * w, ny = -H + Math.sin(ang) * len * u * 0.8 + Math.cos(ang) * w;
      p.line(px, py, nx, ny, C[u < 0.5 ? 5 : 4], (1 - q) * (1 - u * 0.5));
      px = nx; py = ny;
    }
  });
}
