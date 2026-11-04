// Rainfall (top-down, for an iso camera): Averse's Flood, a ring of water bursting out all round her, seen from above.
// One-shot. A white foam crest races out from `r0` to `r1` px, water floods behind it in streaks running outward, a
// pressure ripple runs just ahead, spray is thrown off the crest, then it all spends itself into lace and a calm
// sheen at the centre (the game leaves its own puddle there).
import { fit, stream, fly, clamp, smooth, ease, tileNoise, TAU } from "../../core/index.js";

export const meta = {
  name: "Averse flood ring",
  desc: "Seen from above, a flood bursts out all round: a foam crest races out to r1, streaked water floods behind it, ripple ahead, spray, then it breaks to lace round a calm sheen.",
  tags: ["rainfall", "water", "flood", "wave", "nova", "ring", "top-down", "ground", "one-shot"],
  size: [188, 188],
  origin: [94, 94],
  duration: 1.4,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#04090f", "#08141f", "#0f2a38", "#2f6577", "#2a9fb5", "#5FD4E8", "#9fe8f2"],
    r0: 6,
    r1: 84,
    run: 0.55,
    band: 7,
    trail: 26,
    seed: 9,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), S = o.seed, RUN = o.run, B = o.band;
  const front = (tt) => o.r0 + (o.r1 - o.r0) * ease.outCubic(clamp(tt / RUN));
  const R = front(t);
  const grow = smooth(0, 0.08, t);
  const k = grow * (1 - smooth(RUN * 0.85, meta.duration - 0.05, t));
  const calm = smooth(0.1, 0.5, t) * (1 - smooth(0.9, meta.duration, t));
  const lim = o.r1 + 8;
  p.shade(-lim, -lim, lim, lim, (x, y, out) => {
    const r = Math.hypot(x, y);
    if (r > R + 5) return;
    const a = Math.atan2(y, x), lit = Math.cos(a + 2.36);
    const wv = 1.6 * tileNoise(x / 7 + 40, y / 7, 0, 0, S);
    const s = R - r + wv; // depth behind the crest
    if (s < 0) {
      // pressure ripple ahead
      if (s > -3.4 && s < -2.2 && k > 0.2 && tileNoise(x / 3, y / 3, 0, 0, S + 7) > 0.1 - 0.5 * k) {
        out.c = C[3];
        out.k = 0.1 * k;
        out.l = C[4];
      }
      return;
    }
    const bandE = B * (0.5 + 0.5 * k);
    if (s < bandE && k > 0.05) {
      const q = s / bandE;
      const f = tileNoise(x / 3, y / 3, 0, 0, S + 1);
      if (f < -1.1 + q * q * 1.3 + (1 - k) * 2.2) return;
      out.c = C[q < 0.3 ? 6 : lit > 0 ? 5 : 4];
      out.k = 0.55 * k * (1 - q * 0.5);
      out.l = C[5];
      return;
    }
    const u = (s - bandE) / o.trail;
    // flooded water behind the crest: outward streaks, breaking to lace as k falls
    if (u < 1 && k > 0.03) {
      const lane = Math.abs(Math.sin(a * 23 + 1.7 + 2 * tileNoise(x / 16, y / 16, 0, 0, S + 6)));
      const n = tileNoise((x - Math.cos(a) * t * 70) / 9, (y - Math.sin(a) * t * 70) / 9, 0, 0, S + 2);
      const need = -0.8 + u * 0.9 + (1 - k) * 1.6;
      if (n > need) {
        let c = u < 0.25 ? 3 : n > need + 0.5 ? 3 : 2;
        if (lane > 0.985 && n > need + 0.45) c = 4;
        out.c = C[c];
        out.a = u > 0.85 ? 0.6 : 1;
        out.k = (c >= 4 ? 0.2 : 0.05) * k;
        out.l = C[5];
        return;
      }
    }
    // calm sheen left in the middle
    if (calm > 0.05 && r < o.r1 * 0.4) {
      const n2 = tileNoise(x / 8, y / 8, 0, 0, S + 4);
      if (n2 < 0.6 - calm * 1.4 - (1 - r / (o.r1 * 0.4)) * 0.8) return;
      out.c = C[n2 > 0.45 ? 3 : 2];
      out.a = calm > 0.5 ? 1 : calm * 2;
      out.k = 0.03;
      out.l = C[4];
    }
  });
  // spray thrown off the crest while it runs
  stream(t, 0.03, RUN, 110, S + 9, (g) => g.range(0.2, 0.4), (age, life, r) => {
    const born = t - age, Rb = front(born), a = r.range(0, TAU), sp = r.range(20, 50);
    const dir = a + r.range(-0.4, 0.4);
    const [x, y] = fly(Math.cos(a) * Rb, Math.sin(a) * Rb, Math.cos(dir) * sp, Math.sin(dir) * sp, age, 0, 5);
    if (Math.hypot(x, y) > o.r1 + 7) return;
    const q = age / life;
    p.dot(x, y, C[q < 0.4 ? 6 : 5], q < 0.6 ? 1 : (1 - q) / 0.4);
    p.light(x, y, C[5], 0.35 * (1 - q));
  });
  if (t < 0.22) p.glow(0, 0, 30, C[6], 0.7 * (1 - t / 0.22));
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * TAU;
    p.glow(Math.cos(a) * (R - 4), Math.sin(a) * (R - 4), 16, C[5], 0.16 * k);
  }
}
