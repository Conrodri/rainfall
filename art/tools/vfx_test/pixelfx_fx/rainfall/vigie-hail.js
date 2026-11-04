// Rainfall (billboard, for an iso camera): Vigie's Grêle, a volley falling out of the sky on a round patch of floor,
// as a loop. Drawn in screen space: the arrows fall upright (they really drop from the sky) and land anywhere inside a
// 2:1 ground ellipse whose dashed rim marks the zone; each lands with a spark and stays stuck a moment.
import { fit, cycle, clamp, TAU } from "../../core/index.js";

export const meta = {
  name: "Vigie hail of arrows",
  desc: "Upright arrows rain out of the sky onto a 2:1 ellipse of floor: falling streaks, a spark where each lands, arrows left stuck a moment; a dashed rim marks the zone. Loops.",
  tags: ["rainfall", "arrows", "volley", "rain", "billboard", "ground", "loop"],
  size: [176, 216],
  origin: [88, 152],
  duration: 0.8,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0c0507", "#1c0a0e", "#35121a", "#6a1b2a", "#B02438", "#FF3A4F", "#FF8C98"],
    radius: 72, // px of floor (16 px per game unit) : 4,5 u
    count: 40, // arrows per loop
    seed: 31,
  },
};

const FALL = 0.12, STUCK = 0.36, DROP = 92;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, RY = R / 2, ph = t / meta.duration;
  // floor: the zone's shadow, dithered, and a dashed rim creeping round
  p.shade(-R - 1, -RY - 1, R + 1, RY + 1, (x, y, out) => {
    const d = Math.hypot(x / R, y / RY);
    if (d > 1.02) return;
    if (d > 0.95) {
      const a = Math.atan2(y / RY, x / R) / TAU - ph * 0.125;
      if (((a * 48) % 1 + 1) % 1 > 0.5) return;
      out.c = C[4];
      out.k = 0.2;
      out.l = C[5];
      return;
    }
    if (((Math.floor(x) + Math.floor(y)) & 1) || d > 0.92) return;
    out.c = C[2];
    out.a = 0.3 * (1 - d * 0.5);
  });
  // the arrows: each falls from the sky onto its own spot, sticks, and fades
  cycle(t, meta.duration, o.count, o.seed, FALL + STUCK, (age, life, r) => {
    // a spot inside the ellipse, spread evenly
    const a = r.range(0, TAU), rr = Math.sqrt(r.next()) * 0.92, gx = Math.cos(a) * R * rr, gy = Math.sin(a) * RY * rr;
    const lean = r.range(-0.18, 0.18); // the volley comes down slightly slanted
    if (age < FALL) {
      // falling: a streak with the head leading, the trail fading upward
      const q = age / FALL, hy = gy - DROP * (1 - q), hx = gx - lean * DROP * (1 - q);
      const tx = hx - lean * 28, ty = hy - 28;
      p.line(tx, ty, hx, hy, (u) => C[u > 0.8 ? 6 : u > 0.4 ? 5 : 3], (u) => 0.25 + 0.75 * u);
      p.line(tx + 1, ty, hx + 1, hy, (u) => C[u > 0.7 ? 5 : 3], (u) => 0.15 + 0.6 * u);
      p.light(hx, hy, C[5], 0.6);
      return;
    }
    const s = age - FALL, q = s / STUCK;
    // the landing: a spark and a puff on the first frames
    if (s < 0.06) {
      p.dot(gx, gy, C[6]);
      p.dot(gx - 1, gy, C[5]);
      p.dot(gx + 1, gy, C[5]);
      p.dot(gx, gy - 1, C[5]);
      p.glow(gx, gy, 8, C[5], 0.7 * (1 - s / 0.06));
    }
    // the stuck arrow: a short shaft leaning back, fletching up, fading
    const al = 1 - q * q, top = 8;
    p.line(gx, gy, gx - lean * top, gy - top, C[5], al);
    p.line(gx + 1, gy, gx + 1 - lean * top, gy - top, C[3], al);
    p.line(gx - lean * top, gy - top, gx - lean * top - 2, gy - top - 2, C[5], al);
    p.line(gx - lean * top, gy - top, gx - lean * top + 2, gy - top - 2, C[4], al);
    p.dot(gx + 1, gy + 1, C[1], al * 0.8);
  });
  p.glow(0, 0, R * 0.8, C[4], 0.1);
}
