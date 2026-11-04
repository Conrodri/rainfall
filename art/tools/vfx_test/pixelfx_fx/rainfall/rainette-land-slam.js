// Rainfall (for an iso camera): a heavy landing in the marsh, drawn in screen space for the 2:1 iso view. One-shot.
// The footprint on the floor is an ellipse twice as wide as tall (`radius` px across x): a shock ring races out to it,
// clods of vase skid along the floor, and the volume stands up from it: a crown of splash and mud thrown up and falling
// back. Options: `water` (a taller crown of water, the flood song), `reeds` (reed blades spring up round the ring).
// The pivot is the centre of the footprint, on the floor.
import { fit, clamp, smooth, ease, burst, fly, noise2, TAU } from "../../core/index.js";

export const meta = {
  name: "Rainette land slam",
  desc: "A heavy marsh landing for a 2:1 iso view: a shock ring racing out over an elliptic footprint, clods skidding along the floor, a crown of vase and splash thrown up and raining back.",
  tags: ["rainfall", "impact", "slam", "landing", "mud", "water", "iso", "one-shot"],
  size: [132, 112],
  origin: [66, 78],
  duration: 1.0,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#070b09", "#0f1612", "#1a261f", "#4a5f54", "#6b8c7b", "#8DBBA8", "#b5d6c6"],
    radius: 48,
    water: 0,
    reeds: 0,
    seed: 4,
  },
};

const RUN = 0.26;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, S = o.seed, D = meta.duration, Wt = o.water > 0, Rd = o.reeds > 0;
  const front = (tt) => R * (0.18 + 0.82 * ease.outCubic(clamp(tt / RUN)));
  const Rf = front(t), fade = 1 - smooth(RUN * 0.8, D * 0.85, t);
  // the footprint: a dark wet stain spreading under everything, then a shock ring racing to the edge
  const stain = R * 0.62 * ease.outCubic(clamp(t / 0.18)), sk = 1 - smooth(D * 0.5, D, t);
  p.shade(-R - 3, -R / 2 - 3, R + 3, R / 2 + 3, (x, y, out) => {
    const e = Math.hypot(x, y * 2); // elliptic radius, in px across x
    const a = Math.atan2(y * 2, x);
    const jit = noise2(Math.cos(a) * 2.5, Math.sin(a) * 2.5, S) * 3;
    const d = Rf - e + jit; // 0 on the ring, growing inwards
    const B = 5 + 3 * (1 - fade);
    if (d >= -1 && d < B && fade > 0.05) {
      const q = Math.max(0, d) / B, lit = Math.cos(a + 2.36);
      let c = q < 0.25 ? 6 : q < 0.6 ? 5 : 4;
      if (lit < -0.3 && c > 4) c -= 1;
      if (fade < 0.5) c = Math.max(3, c - 1);
      if (q > 0.5 && fade < 0.6 && (Math.sin(a * 11) > 0.3)) return;
      out.c = C[c];
      out.a = clamp(fade * 1.3, 0, 1);
      out.k = (q < 0.4 ? 0.5 : 0.2) * fade;
      out.l = C[5];
      return;
    }
    if (e < stain + jit && sk > 0.02) {
      const n = noise2(x * 0.15, y * 0.3, S + 2);
      out.c = C[n > 0.35 ? 3 : n > -0.2 ? 2 : 1];
      out.a = 0.85 * sk;
      if (n > 0.55 && x + y < 0) out.c = C[4];
      out.k = 0.04 * sk;
      out.l = C[4];
    }
  });
  // clods skidding outward along the floor
  burst(18, S + 1, (r) => {
    const a = r.range(0, TAU), born = r.range(0, 0.06), age = t - born, life = r.range(0.3, 0.5);
    if (age < 0 || age > life) return;
    const sp = r.range(R * 2.2, R * 3.6), [d] = fly(R * 0.2, 0, sp, 0, age, 0, 7), k = age / life;
    const x = Math.cos(a) * Math.min(d, R * 1.05), y = (Math.sin(a) * Math.min(d, R * 1.05)) / 2;
    p.dot(x, y, C[k < 0.5 ? 4 : 3], 1 - k * 0.6);
    p.dot(x + 1, y, C[2], 1 - k);
  });
  // reed blades springing up round the ring (Chœur des roseaux)
  if (Rd) {
    burst(14, S + 7, (r, i) => {
      const a = (i / 14) * TAU + r.range(-0.2, 0.2), born = 0.06 + r.range(0, 0.12), age = t - born;
      if (age < 0) return;
      const rr = R * r.range(0.55, 0.95), bx = Math.cos(a) * rr, by = (Math.sin(a) * rr) / 2;
      const hgt = R * r.range(0.35, 0.6) * ease.outBack(clamp(age / 0.18)) * (1 - smooth(D * 0.6, D, t));
      if (hgt < 1) return;
      const lean = r.range(-0.25, 0.25) + Math.cos(a) * 0.2;
      p.line(bx, by, bx + lean * hgt, by - hgt, (u) => C[u > 0.75 ? 6 : u > 0.3 ? 5 : 3]);
      p.line(bx + 1, by, bx + 1 + lean * hgt * 0.8, by - hgt * 0.8, C[3]);
      p.light(bx + lean * hgt, by - hgt, C[5], 0.35);
    });
  }
  // the crown: splash and vase thrown up from the ring, raining back to the floor
  const n = Wt ? 64 : 48, up = Wt ? 1.2 : 0.8;
  burst(n, S + 3, (r) => {
    const a = r.range(0, TAU), born = r.range(0.02, 0.14), age = t - born, life = r.range(0.6, 0.85);
    if (age < 0 || age > life) return;
    const r0 = front(born) * r.range(0.7, 1), x0 = Math.cos(a) * r0, y0 = (Math.sin(a) * r0) / 2;
    const vx = Math.cos(a) * r.range(15, 45), vy = -R * up * r.range(2.8, 4.4), g = R * up * 10;
    const [x, y] = fly(x0, y0, vx, vy, age, g, 0), k = age / life;
    if (y > y0 + 1) return; // back on the floor
    const big = r.next() < 0.35;
    const c = C[Wt ? (k < 0.4 ? 6 : 5) : big ? (k < 0.3 ? 5 : 4) : k < 0.4 ? 6 : 5];
    const [ux, uy] = [vx, vy + g * age], ul = Math.hypot(ux, uy) || 1;
    p.line(x, y, x - (ux / ul) * 3, y - (uy / ul) * 3, c, 1 - k * 0.5);
    if (big) p.circle(x, y, 1.3, (d) => C[d < 0.5 ? 5 : 3], 1 - k * 0.6);
    if (Wt) p.dot(x + 1, y, C[5], 0.6 * (1 - k));
    p.light(x, y, C[5], (Wt ? 0.35 : 0.22) * (1 - k));
  });
  // a short central plume where she hits
  const pl = clamp(t / 0.25);
  if (pl < 1) {
    const h = R * (Wt ? 0.8 : 0.5) * ease.outCubic(pl), w = R * 0.16 * (1 - pl * 0.5);
    p.shade(-w, -h, w, 0, (x, y, out) => {
      const v = -y / Math.max(1, h), hw = w * (1 - v * 0.6);
      if (Math.abs(x) > hw) return;
      if (noise2(x * 0.5, y * 0.4 + t * 20, S + 5) < -0.1 + v * 0.6) return;
      out.c = C[x < 0 ? 6 : 5];
      out.a = 1 - pl;
      out.k = 0.3 * (1 - pl);
      out.l = C[5];
    });
  }
  // the impact light and a glow riding the ring
  p.glow(0, 0, R * 0.7, C[6], 0.8 * (1 - smooth(0, 0.2, t)));
  if (fade > 0.05)
    for (let i = 0; i < 12; i++) {
      const a = (i / 12) * TAU;
      p.glow(Math.cos(a) * Rf, (Math.sin(a) * Rf) / 2, 7, C[5], 0.12 * fade);
    }
}
