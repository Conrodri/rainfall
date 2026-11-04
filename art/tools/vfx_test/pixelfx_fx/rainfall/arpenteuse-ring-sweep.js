// Rainfall (top-down, for an iso camera): Arpenteuse's Cerceau seen from above, as a loop. The chain whirls round the
// caster on a band from `radius - band` to `radius + band` px: a dim heat band, a white-hot head sweeping one full turn
// per loop with a fading wake behind it, sparks flung outward off the head (what it mows is thrown back).
import { fit, clamp, cycle, fly, TAU } from "../../core/index.js";

export const meta = {
  name: "Arpenteuse ring sweep",
  desc: "Seen from above, a chain whirling round the caster on a ring band: dim heat band, a white-hot head sweeping one turn per loop with a fading wake, sparks flung outward.",
  tags: ["rainfall", "chain", "spin", "ring", "aura", "top-down", "ground", "loop"],
  size: [128, 128],
  origin: [64, 64],
  duration: 1.0,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0b0806", "#1a110c", "#2e1f17", "#6b4a38", "#a8501a", "#FF7A1F", "#ffa860"],
    radius: 48,
    band: 8,
    wake: 2.4, // radians of wake behind the head
    seed: 2,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, W = o.band, ph = t / meta.duration, head = ph * TAU;
  p.shade(-R - W - 1, -R - W - 1, R + W + 1, R + W + 1, (x, y, out) => {
    const r = Math.hypot(x, y), d = r - R;
    if (Math.abs(d) > W) return;
    const a = Math.atan2(y, x);
    let behind = head - a;
    behind -= Math.floor(behind / TAU) * TAU; // 0 at the head, growing backwards
    const wk = behind < o.wake ? 1 - behind / o.wake : 0;
    const q = Math.abs(d) / W;
    const lit = Math.cos(a + 2.36);
    if (wk > 0.02) {
      // the wake: bright near the head, a link pattern scrolling through it
      const links = Math.sin(a * 30 - ph * TAU * 3) > 0.2;
      const core = q < 0.35 + 0.4 * wk;
      if (!core && wk < 0.6) {
        if (q < 0.95 && Math.sin(a * 13 + r) > 0.4) {
          out.c = C[3];
          out.a = 0.6 * wk;
        }
        out.k = 0.12 * wk;
        out.l = C[4];
        return;
      }
      let c = wk > 0.85 ? 6 : wk > 0.5 ? 5 : 4;
      if (links && q < 0.3) c = Math.min(6, c + 1);
      if (lit < -0.4 && c > 3) c -= 1;
      out.c = C[c];
      out.a = clamp(0.4 + wk, 0, 1);
      out.k = 0.55 * wk * (1 - q * 0.5);
      out.l = C[5];
      return;
    }
    // the band at rest: two thin rims and a faint shimmer
    if (q > 0.82) {
      out.c = C[lit > 0 ? 3 : 2];
      out.a = 0.8;
      out.k = 0.05;
      out.l = C[4];
      return;
    }
    out.k = 0.05 * (1 - q);
    out.l = C[4];
  });
  // the head: a hot knot of links
  const hx = Math.cos(head) * R, hy = Math.sin(head) * R;
  p.circle(hx, hy, W * 0.55, (d, an) => C[d < 0.5 ? 6 : Math.cos(an + 2.36) > 0 ? 6 : 5]);
  p.glow(hx, hy, W * 3, C[5], 0.7);
  // sparks flung outward off the head
  cycle(t, meta.duration, 18, o.seed, 0.3, (age, life, r) => {
    const born = t - age, a = (born / meta.duration) * TAU + r.range(-0.15, 0.05);
    const ox = Math.cos(a) * R, oy = Math.sin(a) * R, sp = r.range(40, 90);
    const vx = Math.cos(a) * sp - Math.sin(a) * sp * 0.6, vy = Math.sin(a) * sp + Math.cos(a) * sp * 0.6;
    const [x, y] = fly(ox, oy, vx, vy, age, 0, 5), k = age / life;
    p.dot(x, y, C[k < 0.4 ? 6 : 5], 1 - k);
    p.light(x, y, C[5], 0.35 * (1 - k));
  });
}
