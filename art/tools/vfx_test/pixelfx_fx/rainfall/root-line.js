// Rainfall (top-down, for an iso camera): a line of thorned roots tearing up out of the floor, seen from above.
import { fit, burst, fly, clamp, smooth, ease, noise, TAU } from "../../core/index.js";

export const meta = {
  name: "Root line",
  desc: "Seen from above, a glowing seam races right along the floor and thorned roots and stake-tips tear up out of it in a wave, spitting soil; they hold, then sink back.",
  tags: ["rainfall", "nature", "roots", "thorns", "top-down", "directional", "one-shot"],
  size: [164, 60],
  origin: [12, 30],
  duration: 0.82,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#05100c", "#0b1c16", "#16302a", "#2a5446", "#4a8070", "#6cc8a4", "#9CF0C8", "#d0fae8"],
    length: 128, // px along the line
    width: 16, // px across
    seed: 4,
  },
};

const RACE = 0.14, SINK0 = 0.46, SINK1 = 0.78;

export function draw(p, t, o) {
  const C = fit(o.palette, 8), L = o.length, hw = o.width / 2, S = o.seed;
  const seam = (x) => noise(x * 0.06, S) * hw * 0.35;
  const born = (x) => 0.02 + RACE * clamp(x / L);
  const head = L * ease.outCubic(clamp((t - 0.02) / RACE));
  const sink = smooth(SINK0, SINK1, t);
  const taper = (x) => Math.min(1, x / 10, (L - x) / 12);
  // two ropes twisting round the seam
  const ropes = [
    { a: hw * 0.45, l: 23, ph: 0.4, w: 6.5 },
    { a: hw * 0.4, l: 17, ph: 2.6, w: 5 },
  ];
  const ry = (r, x) => seam(x) + Math.sin(x / r.l * TAU * 0.5 + r.ph) * r.a;

  // the seam: a dark crack with a hot lit lip, racing ahead of the roots, cooling as they sink
  if (t > 0.02 && sink < 0.55) {
    for (let x = 0; x < head; x++) {
      const age = t - born(x), hot = clamp(1 - age / 0.35);
      p.dot(x, seam(x) + 1, C[0], 1 - sink * 1.8);
      p.dot(x, seam(x), hot > 0.5 ? C[7] : hot > 0.1 ? C[6] : C[3], 1 - sink * 1.8);
      p.light(x, seam(x), C[6], (0.25 + 0.6 * hot) * (1 - sink));
    }
    if (head < L) p.glow(head, seam(head), 10, C[7], 0.8);
  }
  // soil and dust kicked out as each stretch tears open
  burst(26, S + 3, (r) => {
    const x0 = r.range(4, L - 4), age = t - born(x0) - 0.01;
    if (age < 0) return;
    const life = r.range(0.35, 0.7);
    if (age > life) return;
    const side = r.next() < 0.5 ? -1 : 1, sp = r.range(30, 80), a = side * r.range(0.9, 2.2);
    const [x, y] = fly(x0, seam(x0), Math.cos(a) * sp * 0.6, Math.sin(a) * sp, age, 0, 6);
    const q = age / life, big = r.next() < 0.4;
    p.dot(x, y, C[q < 0.3 ? 4 : 2], q < 0.6 ? 1 : (1 - q) / 0.4);
    if (big) p.dot(x + 1, y, C[1], q < 0.6 ? 1 : (1 - q) / 0.4);
  });
  burst(9, S + 5, (r) => {
    const x0 = r.range(8, L - 8), age = t - born(x0);
    if (age < 0 || age > 0.6) return;
    const q = age / 0.6;
    p.disc(x0 + r.range(-3, 3), seam(x0) + r.range(-4, 4), 3 + 6 * ease.outCubic(q), C[3], 0.28 * (1 - q));
  });

  // the roots: bark lit on the top edge, dark underneath, glowing veins; torn up behind the seam, sinking at the end
  p.shade(0, -hw - 3, L, hw + 3, (x, y, out) => {
    if (x > head) return;
    const g = clamp((t - born(x)) / 0.08), tp = taper(x);
    if (g <= 0 || tp <= 0) return;
    const gone = noise(x * 0.35, S + 9) * 0.5 + 0.5;
    if (sink > gone * 0.9 + 0.05) return;
    for (const r of ropes) {
      const cy = ry(r, x), half = (r.w * tp * ease.outBack(g)) / 2 * (1 - sink * 0.5);
      const d = y - cy;
      if (Math.abs(d) > half) continue;
      const v = d / Math.max(0.5, half); // -1 top edge .. 1 bottom edge
      const vein = Math.abs(noise(x * 0.5 + r.ph * 7, S + 2)) < 0.12 && Math.abs(v) < 0.5;
      let c = v < -0.5 ? 5 : v < -0.1 ? 4 : v < 0.35 ? 3 : v < 0.7 ? 2 : 0;
      if (vein) c = 6;
      out.c = C[c];
      if (vein || v < -0.45) {
        out.k = (vein ? 0.45 : 0.12) * (1 - sink);
        out.l = C[6];
      }
      return;
    }
  });
  // thorns hooked off the ropes and stake-tips (pyramids seen from above: lit top-left facets)
  burst(16, S + 7, (r, i) => {
    const rope = ropes[i % 2], x = 8 + ((i + 0.5) / 16) * (L - 16) + r.range(-2, 2);
    const g = clamp((t - born(x) - 0.03) / 0.06);
    if (g <= 0) return;
    const sk = clamp(sink * 1.4 - r.next() * 0.3);
    if (sk >= 1) return;
    const side = i % 4 < 2 ? -1 : 1, cy = ry(rope, x), len = (4 + r.range(0, 3.5)) * ease.outBack(g) * (1 - sk);
    const bx = x, by = cy + side * rope.w * 0.4, tx = bx + len * 0.55, ty = by + side * len;
    p.tri(bx - 1.5, by, bx + 1.5, by, tx, ty, C[side < 0 ? 4 : 2]);
    p.dot(tx, ty, C[6]);
  });
  burst(7, S + 8, (r, i) => {
    const x = 10 + ((i + 0.5) / 7) * (L - 20) + r.range(-4, 4), y = seam(x) + r.range(-2, 2);
    const g = clamp((t - born(x) - 0.04) / 0.07);
    if (g <= 0) return;
    const sk = clamp(sink * 1.3 - r.next() * 0.25);
    if (sk >= 1) return;
    const s = (4.5 + r.range(0, 2.5)) * ease.outBack(g, 2.4) * (1 - sk);
    // four facets round a lit apex
    p.tri(x, y, x - s, y, x, y - s, C[6]);
    p.tri(x, y, x, y - s, x + s, y, C[4]);
    p.tri(x, y, x - s, y, x, y + s, C[3]);
    p.tri(x, y, x + s, y, x, y + s, C[1]);
    p.px(x, y, C[7]);
    const fl = 1 - clamp((t - born(x) - 0.04) / 0.25);
    p.glow(x, y, 6 + 6 * fl, C[6], (0.25 + 0.5 * fl) * (1 - sk));
  });
}
