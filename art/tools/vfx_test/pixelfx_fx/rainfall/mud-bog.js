// Rainfall (top-down, for an iso camera): a pool of sucking mud on the floor, seen from above, as a loop.
import { fit, cycle, noise2, clamp, TAU, ease } from "../../core/index.js";

export const meta = {
  name: "Mud bog",
  desc: "Seen from above, a pool of thick mud with a ragged glowing lip: mottled sludge, a wet sheen, bubbles that swell, pop and ring out across it.",
  tags: ["rainfall", "nature", "mud", "bog", "swamp", "top-down", "ground", "loop"],
  size: [176, 176],
  origin: [88, 88],
  duration: 2.4,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06100a", "#0f1c14", "#1d3324", "#3a5e42", "#5f9a6c", "#8DDBA8", "#C2F0D2"],
    radius: 80,
    bubbles: 14,
    seed: 3,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, S = o.seed;
  const edge = (a) => R * (0.86 + 0.09 * noise2(Math.cos(a) * 2.2, Math.sin(a) * 2.2, S) + 0.05 * noise2(Math.cos(a) * 6, Math.sin(a) * 6, S + 1));
  p.shade(-R - 2, -R - 2, R + 2, R + 2, (x, y, out) => {
    const r = Math.hypot(x, y), a = Math.atan2(y, x), e = edge(a);
    if (r > e + 1.5) return;
    if (r > e) {
      // the glowing wet lip
      out.c = C[5];
      out.k = 0.32;
      out.l = C[5];
      return;
    }
    const q = r / e;
    if (q > 0.93) {
      out.c = C[(x + y < 0) ? 4 : 3];
      out.k = 0.12;
      out.l = C[4];
      return;
    }
    // mottled sludge
    const sw = a;
    const n = noise2(Math.cos(sw) * r * 0.07 + 9, Math.sin(sw) * r * 0.07, S + 2) + 0.5 * noise2(x * 0.18, y * 0.18, S + 3);
    let c = n > 0.55 ? 3 : n > 0.05 ? 2 : 1;
    // a wet sheen on the upper left
    const sh = Math.cos(a + 2.36) * q;
    if (sh > 0.45 && n > 0.2 && n < 0.45) c = 4;
    out.c = C[c];
    out.k = c >= 3 ? 0.07 : 0.03;
    out.l = C[4];
  });
  // bubbles: swell, glint, pop and ring out
  cycle(t, meta.duration, o.bubbles, S + 7, (g) => g.range(0.9, 1.6), (age, life, r) => {
    const a = r.range(0, TAU), d = Math.sqrt(r.next()) * R * 0.78, x = Math.cos(a) * d, y = Math.sin(a) * d;
    const big = r.range(2.5, 5), pop = life * 0.7;
    if (age < pop) {
      const s = big * ease.outCubic(age / pop);
      p.circle(x, y, s, (dd, an) => C[dd > 0.7 ? (Math.cos(an + 2.36) > 0 ? 5 : 2) : 3]);
      p.px(x - s * 0.4, y - s * 0.4, C[6]);
      p.light(x - s * 0.4, y - s * 0.4, C[5], 0.4 * (age / pop));
    } else {
      const u = (age - pop) / (life - pop), rr = big + 7 * ease.outCubic(u);
      for (let i = 0; i < 16; i++) {
        const an = (i / 16) * TAU;
        p.dot(x + Math.cos(an) * rr, y + Math.sin(an) * rr, C[u < 0.4 ? 5 : 4], 1 - u);
      }
      p.glow(x, y, 6 + rr, C[5], 0.35 * (1 - u));
      if (u < 0.3) for (let i = 0; i < 4; i++) p.px(x + Math.cos(i * 1.9 + a) * (2 + u * 12), y + Math.sin(i * 1.9 + a) * (2 + u * 12), C[6]);
    }
  });
}
