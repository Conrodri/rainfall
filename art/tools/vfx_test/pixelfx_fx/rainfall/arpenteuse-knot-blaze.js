// Rainfall (top-down, for an iso camera): Arpenteuse's Nœud seen from above. One-shot. A coil of hot chain winds in
// from the edge of a `radius` px disc and cinches into a knot; the knot flares and the whole disc burns for a second
// (what is caught is held): radial flame licks, a glowing rim, embers.
import { fit, clamp, smooth, ease, burst, cycle, noise2, TAU } from "../../core/index.js";

export const meta = {
  name: "Arpenteuse knot blaze",
  desc: "Seen from above, a coil of hot chain cinches into a knot at the centre of a disc, flares, and the disc burns for a second: radial flame licks, glowing rim, embers.",
  tags: ["rainfall", "chain", "fire", "knot", "prison", "top-down", "ground", "one-shot"],
  size: [80, 80],
  origin: [40, 40],
  duration: 1.2,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0b0806", "#1a110c", "#2e1f17", "#6b4a38", "#a8501a", "#FF7A1F", "#ffa860"],
    radius: 32,
    seed: 5,
  },
};

const CINCH = 0.22;

function link(p, C, x, y, a, s, hot) {
  // one chain link seen from above: an oval ring along angle a
  const ca = Math.cos(a), sa = Math.sin(a), rx = 3.2 * s, ry = 2.2 * s;
  p.shade(x - rx - 1, y - rx - 1, x + rx + 1, y + rx + 1, (px, py, out) => {
    const dx = px - x, dy = py - y, u = (dx * ca + dy * sa) / rx, v = (-dx * sa + dy * ca) / ry, d = u * u + v * v;
    if (d > 1 || d < 0.3) return;
    const lit = dx + dy < 0;
    out.c = C[clamp((lit ? 5 : 3) + hot, 0, 6)];
    out.k = (lit ? 0.35 : 0.12) * (0.5 + hot);
    out.l = C[5];
  });
}

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, D = meta.duration, S = o.seed;
  const c = ease.inCubic(clamp(t / CINCH)); // 0: coil laid out, 1: cinched
  const burn = smooth(CINCH - 0.04, CINCH + 0.08, t) * (1 - smooth(D * 0.7, D, t));
  // the burning disc: radial flame licks, darker gaps, a glowing rim (the prison's edge)
  if (burn > 0.01) {
    p.shade(-R - 2, -R - 2, R + 2, R + 2, (x, y, out) => {
      const r = Math.hypot(x, y), a = Math.atan2(y, x);
      if (r > R + 1.5) return;
      if (r > R - 1.5) {
        out.c = C[Math.cos(a + 2.36) > -0.3 ? 5 : 4];
        out.a = burn;
        out.k = 0.35 * burn;
        out.l = C[5];
        return;
      }
      const q = r / R;
      const lick = noise2(a * 3.2, q * 3 - t * 6, S) + 0.6 * noise2(a * 7, q * 6 - t * 9, S + 1);
      const need = 0.15 + q * 0.5 + (1 - burn) * 1.2;
      if (lick > need) {
        out.c = C[lick > need + 0.5 ? 6 : lick > need + 0.25 ? 5 : 4];
        out.a = 0.9 * burn;
        out.k = (lick > need + 0.4 ? 0.4 : 0.15) * burn;
        out.l = C[5];
        return;
      }
      if (q < 0.9 && lick > need - 0.35) {
        out.c = C[2];
        out.a = 0.55 * burn;
      }
      out.k = 0.06 * burn * (1 - q);
      out.l = C[4];
    });
  }
  // the coil: links along a spiral that winds in and tightens
  const turns = 1.6, n = 16;
  if (t < CINCH + 0.3) {
    const fadeC = 1 - smooth(CINCH, CINCH + 0.3, t);
    for (let i = 0; i < n; i++) {
      const u = i / (n - 1), th = u * turns * TAU + c * 2.2;
      const r = R * (1 - u * 0.7) * (1 - c * 0.85) + 2;
      const x = Math.cos(th) * r, y = Math.sin(th) * r;
      if (fadeC > 0.3 || u > 0.6) link(p, C, x, y, th + Math.PI / 2 + (i % 2) * 0.9, 1, c > 0.6 ? 1 : 0);
    }
  }
  // the knot at the centre: three links crossed, white hot at the cinch
  if (t > CINCH * 0.7 && t < D * 0.9) {
    const hot = t < CINCH + 0.25 ? 1 : 0;
    for (let k = 0; k < 3; k++) link(p, C, Math.cos(k * 2.1) * 2.5, Math.sin(k * 2.1) * 2.5, k * 1.05, 1.15, hot);
  }
  // the flare as it cinches
  const fl = t - CINCH;
  if (fl > -0.03 && fl < 0.3) {
    const q = clamp(fl / 0.3);
    p.glow(0, 0, 10 + R * 0.8 * q, C[6], 0.9 * (1 - q));
    p.glowRing(0, 0, R * ease.outCubic(q), 4, C[5], 0.6 * (1 - q));
  }
  p.glow(0, 0, R * 0.9, C[4], 0.25 * burn);
  // embers lifting off the disc
  burst(26, S + 9, (r) => {
    const born = CINCH + r.range(0, 0.6), life = r.range(0.3, 0.55), age = t - born;
    if (age < 0 || age > life) return;
    const a = r.range(0, TAU), d = Math.sqrt(r.next()) * R * 0.95, k = age / life;
    const x = Math.cos(a) * d + r.range(-4, 4) * k, y = Math.sin(a) * d - 6 * k;
    p.dot(x, y, C[k < 0.4 ? 6 : 5], 1 - k);
    p.light(x, y, C[5], 0.35 * (1 - k));
  });
}
