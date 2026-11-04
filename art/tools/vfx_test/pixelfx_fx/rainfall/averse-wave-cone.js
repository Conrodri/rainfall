// Rainfall (top-down, for an iso camera): Averse's Wave, a cone of water thrown from her feet towards +x, seen from
// above. The cone's apex is the origin; a white crest races out across the cone's full width to `r1` px, the water
// floods the wedge behind it in streaks running outward, foam lines its two edges, spray flies off the crest, then it
// all spends itself into lace. One-shot.
import { fit, stream, fly, clamp, smooth, ease, tileNoise } from "../../core/index.js";
import { waterFront } from "./_lib.js";

export const meta = {
  name: "Averse wave cone",
  desc: "Seen from above, a cone of water thrown right from the origin: a foam crest races out across the cone, streaked water floods the wedge, foam edges, spray, then it breaks to lace.",
  tags: ["rainfall", "water", "wave", "cone", "top-down", "directional", "one-shot"],
  size: [124, 148],
  origin: [10, 74],
  duration: 0.9,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#04090f", "#08141f", "#0f2a38", "#2f6577", "#2a9fb5", "#5FD4E8", "#9fe8f2"],
    r0: 8,
    r1: 96, // reach (px) of the crest: the cone's length
    span: 0.611, // half angle (radians): 35°
    run: 0.32, // s for the crest to reach r1
    band: 7,
    seed: 4,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), A = o.span, S = o.seed, RUN = o.run;
  const front = (tt) => o.r0 + (o.r1 - o.r0) * ease.outCubic(clamp(tt / RUN));
  const R = front(t);
  const grow = smooth(0, 0.06, t);
  const k = grow * (1 - smooth(RUN * 0.9, meta.duration - 0.04, t));
  if (k <= 0.01) return;
  // the flooded wedge: streaks running outward, thinner towards the apex and the edges, breaking up as k falls
  const ext = R + 2;
  p.shade(0, -ext, ext, ext, (x, y, out) => {
    const r = Math.hypot(x, y);
    if (r < 2 || r > R - o.band * 0.5) return;
    const a = Math.atan2(y, x), ea = Math.abs(a) / A;
    if (ea > 1) return;
    const q = r / R;
    const sr = (r - t * 110) / 9;
    const n = tileNoise(sr, (a * 40) / 6, 0, 0, S) * 0.7 + tileNoise(sr * 2, (a * 40) / 3, 0, 0, S + 1) * 0.3;
    const need = -0.85 + (1 - k) * 1.7 + (1 - q) * 0.45 + smooth(0.75, 1, ea) * 0.7;
    if (n < need) return;
    let c = q < 0.5 ? 2 : n > 0.3 ? 3 : 2;
    const lane = Math.abs(Math.sin(a * 17 + S + 2 * tileNoise(r / 14, 0.5, 0, 0, S + 5)));
    if (lane > 0.97 && n > need + 0.35) c = q > 0.6 && y < 0 ? 5 : 4;
    if (ea > 0.88 && n > need + 0.2) c = Math.max(c, y < 0 ? 5 : 4); // foam along the edges
    out.c = C[clamp(c, 1, 6)];
    out.a = q < 0.15 ? 0.6 : 1;
    out.k = (c >= 4 ? 0.22 : 0.05) * k;
    out.l = C[5];
  });
  // the crest across the cone
  waterFront(p, C, { cx: 0, R, A, band: o.band * (0.6 + 0.4 * grow), trail: 12, flow: t * 40, wob: t * 3, k, seed: S, curl: 3, light: 0.65 });
  // spray flung forward and out off the crest while it runs
  stream(t, 0.02, RUN, 70, S + 9, (g) => g.range(0.2, 0.4), (age, life, r) => {
    const born = t - age, Rb = front(born), a = r.range(-A, A) * 0.95, sp = r.range(30, 70);
    const dir = a + r.range(-0.3, 0.3);
    const [x, y] = fly(Math.cos(a) * Rb, Math.sin(a) * Rb, Math.cos(dir) * sp, Math.sin(dir) * sp, age, 0, 5);
    if (Math.hypot(x, y) > o.r1 + 14) return;
    const q = age / life;
    p.dot(x, y, C[q < 0.4 ? 6 : 5], q < 0.6 ? 1 : (1 - q) / 0.4);
    p.light(x, y, C[5], 0.4 * (1 - q));
  });
  // the gush at her feet, then light riding the crest
  if (t < 0.18) p.glow(6, 0, 16, C[6], 0.55 * (1 - t / 0.18));
  for (let i = -2; i <= 2; i++) {
    const a = (i / 2) * A * 0.8;
    p.glow(Math.cos(a) * (R - 4), Math.sin(a) * (R - 4), 14, C[5], 0.22 * k);
  }
}
