// Rainfall (for an iso camera): Rainette's Bulle, drawn in screen space for the 2:1 iso view. One-shot. A bubble of
// vase swells up from a footprint ellipse on the floor (`radius` px across x: what it swallows), hangs wobbling in the
// air for `hold` s with streaks swirling inside, then pops: its skin tears into droplets that rain onto `burst` px.
// The pivot is the centre of the footprint, on the floor.
import { fit, clamp, smooth, ease, burst, fly, cycle, TAU } from "../../core/index.js";

export const meta = {
  name: "Rainette bubble",
  desc: "A bubble of vase swells up from an elliptic footprint, hangs wobbling in the air with streaks swirling inside, then pops into droplets that rain onto the floor.",
  tags: ["rainfall", "bubble", "mud", "water", "trap", "iso", "one-shot"],
  size: [112, 132],
  origin: [56, 100],
  duration: 1.95,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#070b09", "#0f1612", "#1a261f", "#4a5f54", "#6b8c7b", "#8DBBA8", "#b5d6c6"],
    radius: 40, // footprint (catch) radius, px across x
    burst: 32, // where the droplets land
    hold: 1.5, // s until it pops
    seed: 6,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, H = o.hold, S = o.seed;
  const grow = ease.outBack(clamp(t / 0.28)), alive = t < H;
  const Rb = R * 0.78 * grow * (1 + 0.04 * Math.sin(t * 9)), cy = -R * 0.2 - Rb - 4 * smooth(0.3, H, t);
  // the footprint: a dark wet ring on the floor under it
  const fk = alive ? clamp(t / 0.15) : 1 - smooth(H, H + 0.3, t);
  if (fk > 0.02) {
    p.shade(-R - 2, -R / 2 - 2, R + 2, R / 2 + 2, (x, y, out) => {
      const e = Math.hypot(x, y * 2) / R;
      if (e > 1.02) return;
      if (e > 0.9) {
        out.c = C[x + y < 0 ? 5 : 4];
        out.a = 0.7 * fk;
        out.k = 0.18 * fk;
        out.l = C[5];
        return;
      }
      out.c = C[1];
      out.a = 0.35 * fk * (1 - e * 0.5);
    });
  }
  if (alive && Rb > 1) {
    // the skin: mostly clear so what it holds shows through; a rim, a lit crescent, a window highlight
    const wob = (a) => 1 + 0.05 * Math.sin(a * 3 + t * 7) + 0.03 * Math.sin(a * 5 - t * 11);
    p.shade(-Rb * 1.1, cy - Rb * 1.1, Rb * 1.1, cy + Rb * 1.1, (x, y, out) => {
      const dx = x, dy = y - cy, r = Math.hypot(dx, dy), a = Math.atan2(dy, dx), e = Rb * wob(a);
      if (r > e) return;
      const q = r / e, lit = Math.cos(a + 2.36);
      if (q > 0.9) {
        out.c = C[lit > 0.2 ? 6 : lit > -0.4 ? 5 : 3];
        out.k = (lit > 0.2 ? 0.45 : 0.15);
        out.l = C[5];
        return;
      }
      if (q > 0.72 && lit > 0.45) {
        out.c = C[5];
        out.a = 0.55;
        out.k = 0.2;
        out.l = C[5];
        return;
      }
      // swirling streaks of vase inside
      const sw = Math.sin(a * 2 + q * 6 - t * 5);
      if (sw > 0.93 && q > 0.3) {
        out.c = C[4];
        out.a = 0.5;
        return;
      }
      out.c = C[2];
      out.a = 0.18 + 0.12 * q;
    });
    const wx = -Rb * 0.42, wy = cy - Rb * 0.45;
    p.ellipse(wx, wy, Rb * 0.16, Rb * 0.09, C[6]);
    p.glow(wx, wy, Rb * 0.4, C[6], 0.35);
    p.glow(0, cy, Rb * 1.2, C[5], 0.18);
    // bubbles of air rising inside
    cycle(t, 0.9, 6, S, 0.7, (age, life, r) => {
      const k = age / life, x = r.range(-0.5, 0.5) * Rb, y = cy + Rb * 0.6 - k * Rb * 1.2;
      if (Math.hypot(x, y - cy) > Rb * 0.85) return;
      p.circle(x, y, 1.2, (d) => C[d < 0.5 ? 6 : 4], 0.8);
    });
  }
  // the pop: a flash, the skin tears into droplets that fall onto the floor
  const g = t - H;
  if (g > 0) {
    const Rp = R * 0.78, cp = -R * 0.2 - Rp - 4;
    p.glow(0, cp, Rp * (1 + g * 2), C[6], 0.8 * (1 - smooth(0, 0.18, g)));
    if (g < 0.1) p.glowRing(0, cp, Rp * (1 + g * 4), 3, C[6], 0.7);
    burst(40, S + 2, (r) => {
      const a = r.range(0, TAU), x0 = Math.cos(a) * Rp, y0 = cp + Math.sin(a) * Rp, life = r.range(0.32, 0.45);
      if (g > life) return;
      const land = r.range(0.4, 1) * o.burst, tx = Math.cos(a) * land, ty = (Math.sin(a) * land) / 2;
      const k = g / life, x = x0 + (tx - x0) * k, y = y0 + (ty - y0) * k * k - Rp * 0.3 * Math.sin(Math.PI * k) * 0;
      p.dot(x, y, C[k < 0.5 ? 6 : 5], 1 - k * 0.4);
      p.light(x, y, C[5], 0.3 * (1 - k));
    });
    // splash marks where they land
    const sk = smooth(0.25, 0.32, g) * (1 - smooth(0.32, 0.45, g));
    if (sk > 0.02)
      burst(16, S + 5, (r) => {
        const a = r.range(0, TAU), d = r.range(0.4, 1) * o.burst;
        p.ellipse(Math.cos(a) * d, (Math.sin(a) * d) / 2, 2.5, 1.2, C[4], sk);
      });
  }
}
