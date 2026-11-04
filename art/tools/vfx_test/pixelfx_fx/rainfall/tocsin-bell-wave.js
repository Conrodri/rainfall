// Rainfall (top-down, for an iso camera): Tocsin strikes his bell, seen from above. One-shot. Two shock rings race out
// across the floor one beat apart (the bell's double toll), the first bright and thick to `r1` px, the second fainter
// behind it; soot and glints kicked off the edge, a hot flash at the bell. Ring shape after ring-wave.js.
import { fit, burst, fly, clamp, smooth, ease, noise2, TAU } from "../../core/index.js";

export const meta = {
  name: "Tocsin bell toll",
  desc: "Seen from above, the bell's toll: two shock rings race out across the floor one beat apart, soot and glints kicked off the edge, a hot flash at the centre.",
  tags: ["rainfall", "tocsin", "shockwave", "ring", "bell", "sound", "top-down", "ground", "one-shot"],
  size: [116, 116],
  origin: [58, 58],
  duration: 0.75,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0d0704", "#1d1108", "#3b2a1a", "#6a4a2a", "#b05a1a", "#FF7A1F", "#ffb06a"],
    r0: 6,
    r1: 48,
    run: 0.3, // s to reach r1
    band: 7,
    seed: 111,
  },
};

function ring(p, C, t, o, k, S) {
  const B = o.band * k, run = o.run;
  if (t < 0) return;
  const R = o.r0 + (o.r1 - o.r0) * ease.outCubic(clamp(t / run));
  const fade = (1 - smooth(run * 0.7, run + 0.3, t)) * k;
  if (fade <= 0.02) return;
  p.shade(-R - 3, -R - 3, R + 3, R + 3, (x, y, out) => {
    const r = Math.hypot(x, y), a = Math.atan2(y, x), lit = Math.cos(a + 2.36);
    const d = R - r + noise2(Math.cos(a) * 3 + t * 2, Math.sin(a) * 3, S) * 1.2;
    if (d < -1 || d >= B) return;
    const q = Math.max(0, d) / B;
    let c = q < 0.2 ? 6 : q < 0.5 ? 5 : 4;
    if (lit < -0.4 && c > 4) c -= 1;
    if (fade < 0.5) c = Math.max(3, c - Math.round((0.5 - fade) * 6));
    if (fade * (1 - q) < 0.2 && q > 0.3) return;
    out.c = C[c];
    out.k = (q < 0.5 ? 0.55 : 0.2) * fade;
    out.l = C[5];
  });
}

export function draw(p, t, o) {
  const C = fit(o.palette, 7), S = o.seed;
  ring(p, C, t, o, 1, S);
  ring(p, C, t - 0.16, o, 0.6, S + 1);
  // soot and glints kicked outward off the first ring
  burst(30, S + 3, (r) => {
    const a = r.range(0, TAU), born = r.range(0.02, o.run * 0.8), age = t - born, life = r.range(0.2, 0.4);
    if (age < 0 || age > life) return;
    const r0 = o.r0 + (o.r1 - o.r0) * ease.outCubic(clamp(born / o.run)), sp = r.range(30, 70);
    const [x, y] = fly(Math.cos(a) * r0, Math.sin(a) * r0, Math.cos(a) * sp, Math.sin(a) * sp, age, 0, 5), k = age / life;
    const soot = r.next() < 0.4;
    p.dot(x, y, soot ? C[2] : C[k < 0.35 ? 6 : 5], k < 0.6 ? 1 : (1 - k) / 0.4);
    if (!soot) p.light(x, y, C[5], 0.35 * (1 - k));
  });
  // the flash at the bell
  p.glow(0, 0, o.r0 * 4, C[6], 0.75 * (1 - smooth(0, 0.2, t)));
}
