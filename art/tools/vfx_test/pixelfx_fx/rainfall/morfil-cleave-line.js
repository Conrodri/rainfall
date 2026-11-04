// Rainfall (top-down, for an iso camera): Taliant's Fendoir, a vertical cut that splits a straight line of ground
// in front of him, seen from above. The edge comes down along the whole line (near to far in a blink), the ground opens
// in a dark seam with a sap-lit lip, chips spit out to both sides, and a flash marks the far end.
import { fit, burst, fly, clamp, smooth, ease, sparkle, noise } from "../../core/index.js";

export const meta = {
  name: "Taliant cleave line",
  desc: "Seen from above, a straight cut opens the ground along +x: a white edge falls along the line, a dark seam with a sap lip in a pale band, chips to both sides, a far-end flash.",
  tags: ["rainfall", "melee", "cleave", "line", "top-down", "directional", "one-shot"],
  size: [112, 52],
  origin: [12, 26],
  duration: 0.6,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0d1008", "#1a2010", "#2e3a1c", "#58703a", "#8fb04e", "#CDEB6E", "#E6F7A8"],
    length: 80, // px (16 px per game unit) : 5 u
    width: 16, // px : 1 u
    seed: 21,
  },
};

const FALL = 0.08, HOLD = 0.08, FADE = 0.36;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), L = o.length, HW = o.width / 2;
  const front = L * ease.outCubic(clamp(t / FALL)); // how far along the line the edge has come down
  const age = clamp((t - FALL - HOLD) / FADE);
  const live = 1 - age;
  if (t > FADE + FALL + HOLD + 0.04) return;
  // the band: the width of the hit, pale, dithered at its sides
  p.shade(0, -HW, front, HW, (x, y, out) => {
    const s = Math.abs(y) / HW, u = x / L;
    if (s > 1) return;
    if (s > 0.6 && ((Math.floor(x) + Math.floor(y)) & 1)) return;
    out.c = C[s < 0.35 ? 3 : 2];
    out.a = 0.5 * live * (1 - s * 0.5) * (0.5 + 0.5 * (1 - u));
    out.k = 0.05 * live * (1 - s);
    out.l = C[4];
  });
  // the seam: a dark split with a ragged sap-lit lip each side
  p.shade(0, -4, front, 4, (x, y, out) => {
    const j = (noise(x * 0.35, o.seed) - 0.5) * 1.6; // the crack wanders a little
    const d = Math.abs(y - j), open = 1.2 + 1.3 * smooth(0, FALL + HOLD, t) * (1 - x / (L * 1.6));
    if (d > open + 1.2) return;
    if (d <= open * 0.45) {
      out.c = C[0];
      out.a = live;
      return;
    }
    if (d <= open) {
      out.c = C[age < 0.35 ? 5 : 4];
      out.k = 0.7 * live;
      out.l = C[5];
      return;
    }
    out.c = C[3];
    out.a = 0.7 * live;
  });
  // the falling edge: a white bar at the front of the cut while it comes down
  if (t < FALL + 0.03) {
    p.line(Math.max(0, front - 14), 0, front, 0, C[6]);
    p.line(front - 1, -HW, front + 1, HW, C[6], 0.8);
    p.glowLine(Math.max(0, front - 18), 0, front, 0, 8, C[5], 0.65);
  }
  // flash at the far end, then at the near end a smaller one (the blade's heel)
  const g = t - FALL * 0.85;
  if (g > 0 && g < 0.22) sparkle(p, L, 0, 8 * ease.outBack(Math.min(1, g / 0.05)) * (1 - g / 0.22), C[6], C[4], 0.7);
  // chips spat out to both sides along the line, as the edge passes
  burst(24, o.seed, (r) => {
    const u = r.range(0.05, 1), born = FALL * ease.outCubic(u) * 0.9 + 0.01, age2 = t - born, life = r.range(0.16, 0.32);
    if (age2 < 0 || age2 > life) return;
    const side = r.next() < 0.5 ? -1 : 1, a = side * r.range(0.9, 1.5), sp = r.range(50, 120), q = age2 / life;
    const [x, y] = fly(u * L, side * 1.5, Math.cos(a) * sp * 0.4, Math.sin(a) * sp, age2, 0, 9);
    p.line(x, y, x - Math.cos(a) * 1.5, y - Math.sin(a) * 2.5, C[q < 0.4 ? 6 : 5]);
    p.light(x, y, C[5], 0.45 * (1 - q));
  });
  // light along the line, strongest at the moment of the cut
  const k = t < FALL ? 0.6 : 0.6 * live;
  p.glowLine(0, 0, front, 0, 12, C[4], k * 0.5);
}
