// Rainfall (top-down, for an iso camera): a long ray raking along the floor from the caster, seen from above, as a
// loop. Drawn from the origin to `length` px towards +x.
import { fit, cycle, fly, clamp, wrap, TAU } from "../../core/index.js";

export const meta = {
  name: "Ground beam",
  desc: "Seen from above, a ray lies along the floor from the caster: a white-hot core, wavering edges, pulses racing out along it, a flaring source and a spray where it ends.",
  tags: ["rainfall", "beam", "ray", "light", "top-down", "directional", "loop"],
  size: [220, 48],
  origin: [12, 24],
  duration: 0.8,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06090d", "#0b1219", "#16222c", "#34505e", "#6f98a8", "#8fc8d8", "#BFF4FF", "#dff9ff"],
    length: 168,
    width: 12,
    pulses: 4,
    seed: 2,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), L = o.length, hw = o.width / 2, ph = t / meta.duration, n = o.pulses;
  const pulse = (x) => {
    let m = 0;
    for (let i = 0; i < n; i++) {
      const c = wrap((i + ph) * (L / n), L), d = x - c;
      m = Math.max(m, Math.exp(-(d * d) / 30));
    }
    return m;
  };
  p.shade(0, -hw - 3, L, hw + 3, (x, y, out) => {
    const tip = clamp((L - x) / 10), base = clamp(x / 4);
    const wob = Math.sin((x / 24 - ph * 2) * TAU) * 0.8 + Math.sin((x / 11 + ph * 3) * TAU) * 0.4;
    const half = hw * (0.75 + 0.25 * tip) + wob * 0.6;
    const ay = Math.abs(y), pu = pulse(x);
    if (ay > half + 1.5) return;
    if (ay > half) {
      // scorched glow just outside the edge
      out.c = C[2];
      out.a = 0.5;
      out.k = 0.06;
      out.l = C[4];
      return;
    }
    const v = ay / Math.max(1, half);
    let c = v < 0.18 ? 7 : v < 0.45 ? 6 : v < 0.8 ? 5 : 4;
    if (pu > 0.5 && c < 7) c += 1;
    if (y > 0 && v > 0.6) c -= 1; // the lower edge a step darker
    out.c = C[clamp(c, 1, 7)];
    out.k = (v < 0.45 ? 0.55 : 0.25) * base + 0.35 * pu;
    out.l = C[6];
  });
  // the source flares at the caster, the end sprays
  const fl = 0.8 + 0.2 * Math.sin(ph * TAU * 2);
  p.circle(0, 0, hw * 0.9 * fl, (d) => C[d < 0.5 ? 7 : 6]);
  p.glow(0, 0, hw * 3.5, C[6], 0.6 * fl);
  p.glow(L, 0, hw * 2.2, C[6], 0.45);
  cycle(t, meta.duration, 14, o.seed, (g) => g.range(0.2, 0.4), (age, life, r) => {
    const a = r.range(-1.2, 1.2), sp = r.range(40, 90), [x, y] = fly(L - 2, r.range(-hw, hw) * 0.6, Math.cos(a) * sp, Math.sin(a) * sp, age, 0, 6);
    const k = age / life;
    p.dot(x, y, C[k < 0.4 ? 7 : 6], k < 0.6 ? 1 : (1 - k) / 0.4);
    p.light(x, y, C[6], 0.4 * (1 - k));
  });
}
