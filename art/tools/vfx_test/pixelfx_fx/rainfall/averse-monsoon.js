// Rainfall (for an iso camera, drawn in screen space): Averse's Monsoon, a downpour over a round patch of floor, as a
// loop. The footprint is an ellipse 2:1 (`radius` px across, half that deep) of wet, rippled floor with a lit rim;
// rain streaks fall from high above onto it and splash in small 2:1 rings. The ground is y = 0 at the centre.
import { fit, cycle, tileNoise, clamp, TAU } from "../../core/index.js";

export const meta = {
  name: "Averse monsoon",
  desc: "A downpour over a round patch of floor: a 2:1 elliptic footprint of wet rippled ground with a lit rim, rain streaks falling from above, splash rings where they land.",
  tags: ["rainfall", "water", "rain", "storm", "zone", "billboard", "loop"],
  size: [136, 172],
  origin: [68, 132],
  duration: 1.2,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#04090f", "#08141f", "#0f2a38", "#2f6577", "#2a9fb5", "#5FD4E8", "#9fe8f2"],
    radius: 60,
    height: 96, // where the streaks start, above their landing point
    drops: 70,
    seed: 13,
  },
};

const FALL = 0.32, SPLASH = 0.28;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, S = o.seed, ph = t / meta.duration;
  // footprint: dark wet floor, drifting mottles, a broken lit rim
  p.shade(-R - 2, -R / 2 - 2, R + 2, R / 2 + 2, (x, y, out) => {
    const d = Math.hypot(x, y * 2), q = d / R;
    if (q > 1.02) return;
    const a = Math.atan2(y * 2, x);
    const n = tileNoise(x / 9 + ph * 8, y / 4.5, 8, 0, S);
    if (q > 0.94) {
      const lit = Math.cos(a + 2.36);
      if (n < -0.35) return;
      out.c = C[lit > 0 ? 5 : 4];
      out.k = lit > 0 ? 0.2 : 0.08;
      out.l = C[5];
      return;
    }
    const n2 = tileNoise(x / 5, y / 2.5, 0, 0, S + 7);
    if (n2 < -0.1 + q * 0.4) return; // wet patches, not a flat disc
    out.c = C[n > 0.45 ? 3 : 2];
    out.k = 0.03;
    out.l = C[4];
  });
  // drops: a streak falling to a point on the footprint, then a splash ring there
  cycle(t, meta.duration, o.drops, S + 1, FALL + SPLASH, (age, life, r) => {
    const a = r.range(0, TAU), d = Math.sqrt(r.next()) * R * 0.94;
    const gx = Math.cos(a) * d, gy = Math.sin(a) * d * 0.5;
    if (age < FALL) {
      const k = age / FALL, h = o.height * (1 - k);
      const x = gx - h * 0.12, y = gy - h;
      p.line(x, y, x - 0.9, y - 6, C[k > 0.6 ? 5 : 4], 0.85);
      p.light(x, y, C[5], 0.08);
      return;
    }
    const k = (age - FALL) / SPLASH, rr = 1.5 + 4.5 * k;
    for (let i = 0; i < 10; i++) {
      const b = (i / 10) * TAU;
      p.dot(gx + Math.cos(b) * rr, gy + Math.sin(b) * rr * 0.5, C[k < 0.4 ? 6 : 5], 1 - k);
    }
    if (k < 0.35) {
      p.dot(gx - 1, gy - 2 - 3 * k, C[6], 1);
      p.dot(gx + 1, gy - 2 - 2 * k, C[5], 1);
    }
    p.light(gx, gy, C[5], 0.35 * (1 - k));
  });
  // a cold glow over the whole patch
  p.glow(0, -6, R * 0.8, C[4], 0.18);
}
