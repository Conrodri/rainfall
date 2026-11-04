// Rainfall (top-down, for an iso camera): a ladle of molten metal splashing onto the floor, seen from above. One-shot.
// A white-hot blob spreads with a ragged rim, droplets fly out and land as glowing specks, then it crusts and cools.
import { fit, burst, fly, clamp, smooth, ease, noise2, TAU } from "../../core/index.js";

export const meta = {
  name: "Molten splat",
  desc: "Seen from above, molten metal splashing onto the floor: a white-hot blob spreads with a ragged rim, droplets fly out and land glowing, then it crusts over and cools.",
  tags: ["rainfall", "fire", "molten", "metal", "puddle", "impact", "top-down", "ground", "one-shot"],
  size: [96, 96],
  origin: [48, 48],
  duration: 1.4,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#120804", "#241008", "#3c1c0e", "#6a3a1e", "#a0602e", "#d98038", "#FF9A3C", "#ffc684"],
    radius: 26,
    drops: 16,
    seed: 13,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), R = o.radius, S = o.seed;
  const grow = ease.outCubic(clamp(t / 0.22)), cool = smooth(0.25, 1.15, t), gone = smooth(1.0, 1.4, t);
  const edge = (a) => R * grow * (0.78 + 0.16 * noise2(Math.cos(a) * 2.2, Math.sin(a) * 2.2, S) + 0.06 * noise2(Math.cos(a) * 6, Math.sin(a) * 6, S + 1));
  p.shade(-R - 2, -R - 2, R + 2, R + 2, (x, y, out) => {
    const r = Math.hypot(x, y), a = Math.atan2(y, x), e = edge(a);
    if (r > e) return;
    const q = r / Math.max(1, e);
    if (gone > 0 && q > 1 - gone + 0.15 * noise2(x * 0.2, y * 0.2, S + 4)) return;
    const crack = Math.abs(noise2(x * 0.25, y * 0.25, S + 2)) < 0.08;
    let c = Math.round(7 - q * 2 - cool * 4.5);
    if (cool > 0.4 && crack) c = Math.max(c, 5);
    if (Math.cos(a + 2.36) > 0.4 && q > 0.6 && c < 7) c += 1;
    out.c = C[clamp(c, 1, 7)];
    out.k = (c >= 5 ? 0.55 : 0.08) * (1 - cool * 0.6);
    out.l = C[6];
  });
  p.glow(0, 0, R * 1.4, C[6], 0.7 * (1 - cool) * (1 - gone));
  // droplets flung out, landing as specks that cool
  burst(o.drops, S + 6, (r) => {
    const a = r.range(0, TAU), sp = r.range(R * 2.5, R * 5), fl = r.range(0.12, 0.22), born = r.range(0, 0.06), age = t - born;
    if (age < 0 || age > 1.25) return;
    const ta = Math.min(age, fl), [x, y] = fly(0, 0, Math.cos(a) * sp, Math.sin(a) * sp, ta, 0, 4);
    const k = smooth(fl, fl + 0.9, age);
    if (k > 0.98) return;
    const c = age < fl ? 7 : Math.round(6 - k * 3);
    p.px(x, y, C[c]);
    if (age >= fl && r.next() < 0.5) p.px(x + 1, y, C[Math.max(2, c - 1)]);
    p.light(x, y, C[6], 0.5 * (1 - k));
  });
}
