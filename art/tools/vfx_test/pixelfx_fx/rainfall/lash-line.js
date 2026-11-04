// Rainfall (top-down, for an iso camera): a tongue or a thorned branch lashing out along the floor, seen from above.
import { fit, burst, fly, clamp, smooth, ease, TAU } from "../../core/index.js";

export const meta = {
  name: "Lash line",
  desc: "Seen from above, a tongue or thorned branch whips out right in an S that snaps straight, splats or sprays at its tip, then reels back in.",
  tags: ["rainfall", "nature", "whip", "tongue", "lash", "top-down", "directional", "one-shot"],
  size: [112, 56],
  origin: [10, 28],
  duration: 0.55,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#070b09", "#0f1612", "#1a261f", "#4a5f54", "#6b8c7b", "#8DBBA8", "#b5d6c6"],
    length: 72, // px reach
    thick: 6, // px at the base
    tip: 5, // radius of the sticky tip (0: none)
    thorns: 0, // 1: thorned bark instead of a smooth tongue
    seed: 2,
  },
};

const EXT = 0.13, HOLD = 0.07, BACK = 0.17;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), L = o.length, br = o.thorns > 0;
  const e = ease.outCubic(clamp(t / EXT)), back = ease.inQuad(clamp((t - EXT - HOLD) / BACK));
  const len = L * e * (1 - back);
  const amp = 9 * Math.pow(1 - e, 1.3) + 1.5 * Math.sin(clamp((t - EXT) / 0.12) * Math.PI) * (1 - back);
  const cy = (x) => amp * Math.sin((x / Math.max(8, len)) * Math.PI * 1.5) * Math.min(1, x / 10);
  const th = (x) => o.thick * (br ? 1 - 0.55 * (x / L) : 1 - 0.15 * (x / L));
  if (len > 1) {
    p.shade(0, -14, len + 1, 14, (x, y, out) => {
      if (x > len) return;
      const half = th(x) / 2, d = y - cy(x);
      if (Math.abs(d) > half) return;
      const v = d / half; // -1 top (lit) .. 1 bottom
      let c;
      if (br) c = v < -0.55 ? 4 : v < 0.1 ? 3 : v < 0.6 ? 2 : 1;
      else c = v < -0.6 ? 6 : v < -0.15 ? 5 : v < 0.5 ? 4 : 2;
      // the branch's sap vein glows down its middle; the tongue has a wet streak
      if (br && Math.abs(v + 0.05) < 0.2 && x > 3) c = 6;
      if (!br && Math.abs(v + 0.35) < 0.12 && (x | 0) % 7 < 4) c = 6;
      out.c = C[c];
      out.k = (c >= 5 ? 0.4 : 0.08) * (1 - back * 0.6);
      out.l = C[5];
    });
    // thorns hooked back towards the base, alternating sides
    if (br)
      for (let x = 7; x < len - 3; x += 7) {
        const side = (x / 7) % 2 < 1 ? -1 : 1, by = cy(x) + side * th(x) * 0.45, l = 3 + 2 * (1 - x / L);
        p.tri(x - 1.5, by, x + 1.5, by, x - l * 0.7, by + side * l, C[side < 0 ? 4 : 3]);
        p.px(x - l * 0.7, by + side * l, C[6]);
      }
    // the tip
    const tx = len, ty = cy(len);
    if (o.tip > 0) {
      p.circle(tx, ty, o.tip, (d, a) => C[d > 0.75 ? (Math.sin(a) > 0 ? 2 : 5) : Math.cos(a + 2.36) > 0.3 ? 6 : 5]);
      p.px(tx - 1, ty - 1, C[6]);
    } else {
      p.line(tx, ty, tx + 3, ty, C[5]);
    }
    p.glow(tx, ty, 10, C[5], 0.5 * (1 - back));
  }
  // at full reach: a splat (tongue) or a spray of sap and torn leaves (branch)
  const h = t - EXT;
  if (h > 0) {
    const q = clamp(h / 0.3);
    if (q < 1) {
      p.glow(L, cy(L), 16, C[6], 0.8 * (1 - q));
      const rr = 3 + 9 * ease.outCubic(q);
      for (let i = 0; i < 20; i++) {
        const a = (i / 20) * TAU;
        p.dot(L + Math.cos(a) * rr, Math.sin(a) * rr, C[q < 0.4 ? 6 : 4], 1 - q);
      }
    }
    burst(br ? 16 : 12, o.seed + 4, (r) => {
      const life = r.range(0.25, 0.45), a = r.range(-1.6, 1.6), sp = r.range(40, 110);
      if (h > life) return;
      const [x, y] = fly(L, 0, Math.cos(a) * sp, Math.sin(a) * sp, h, 0, 7), k = h / life;
      if (br && r.next() < 0.4) {
        // a torn leaf, tumbling
        const s = Math.sin(h * 30 + r.range(0, 6));
        p.px(x, y, C[5]);
        p.px(x + (s > 0 ? 1 : 0), y + (s > 0 ? 0 : 1), C[4]);
      } else {
        p.dot(x, y, C[k < 0.4 ? 6 : 5], k < 0.6 ? 1 : (1 - k) / 0.4);
        if (!br && r.next() < 0.5) p.dot(x + 1, y, C[4], 1 - k);
      }
      p.light(x, y, C[5], 0.4 * (1 - k));
    });
  }
}
