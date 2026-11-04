// Rainfall (top-down, for an iso camera): Taliant's long thrust, seen from above. The point drives out along +x to
// the full reach in a narrow wedge (the game's cone), leaves a white streak that thins to a hair, and the tip flashes.
import { fit, burst, fly, clamp, smooth, ease, sparkle } from "../../core/index.js";

export const meta = {
  name: "Taliant thrust",
  desc: "Seen from above, a katana point drives out to its reach: a narrow pale wedge (the stab's cone), a white streak thinning to the hilt, a flash and sap chips at the point.",
  tags: ["rainfall", "melee", "thrust", "stab", "top-down", "directional", "one-shot"],
  size: [96, 64],
  origin: [12, 32],
  duration: 0.5,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0d1008", "#1a2010", "#2e3a1c", "#58703a", "#8fb04e", "#CDEB6E", "#E6F7A8"],
    reach: 58, // px (16 px per game unit)
    spread: 0.698, // full cone angle, radians (40°)
    seed: 9,
  },
};

const DRIVE = 0.07, HOLD = 0.1, FADE = 0.3;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), L = o.reach, H = o.spread / 2;
  const tip = L * ease.outExpo(clamp(t / DRIVE));
  const back = L * 0.85 * smooth(DRIVE + HOLD, DRIVE + HOLD + FADE, t);
  const age = clamp(t / (DRIVE + HOLD + FADE + 0.05));
  if (t >= DRIVE + HOLD + FADE) return;
  // the wedge: the cone the point swept, pale, brightest along the axis, dithered off the axis
  if (age < 0.9 && tip > 4)
    p.shade(3, -L, L, L, (x, y, out) => {
      const r = Math.hypot(x, y), a = Math.abs(Math.atan2(y, x));
      if (r > tip || r < Math.max(4, back) || a > H) return;
      const side = a / H; // 0 axis .. 1 cone edge
      if (side > 0.55 && ((Math.floor(x) + Math.floor(y)) & 1)) return;
      out.c = C[side < 0.3 ? 4 : 3];
      out.a = 0.75 * (1 - age) * (1 - side * 0.5);
      out.k = 0.12 * (1 - age) * (1 - side);
      out.l = C[4];
    });
  // the cone's edges: two faint lines catching the light while young
  if (age < 0.5 && tip > 6)
    for (const s of [-1, 1]) {
      const ex = Math.cos(H) * tip, ey = s * Math.sin(H) * tip;
      p.line(Math.cos(H) * 6, s * Math.sin(H) * 6, ex, ey, C[4], 0.9 * (1 - age * 2));
    }
  // the streak: thick at the point, thinning to a hair towards the hilt
  if (tip > back + 1)
    p.shade(back, -5, tip + 1, 5, (x, y, out) => {
      const u = (x - back) / Math.max(1, tip - back); // 0 hilt .. 1 point
      const w = (0.8 + 4.2 * Math.pow(u, 1.2)) * (1 - 0.45 * age);
      if (Math.abs(y) > w || x > tip) return;
      const q = Math.abs(y) / Math.max(0.5, w);
      out.c = C[clamp(Math.round(6 - q * 2 - age * 2.5), 2, 6)];
      out.k = (0.8 - q * 0.5) * (1 - age) * (0.3 + 0.7 * u);
      out.l = C[5];
    });
  // the point itself while driving
  if (t < DRIVE + 0.04) {
    p.tri(tip - 6, -3, tip - 6, 3, tip + 2, 0, () => C[6]);
    p.glowLine(Math.max(0, tip - 20), 0, tip, 0, 7, C[5], 0.6);
  }
  // flash where the point stops
  const g = t - DRIVE * 0.8;
  if (g > 0 && g < 0.2) sparkle(p, L, 0, 8 * ease.outBack(Math.min(1, g / 0.05)) * (1 - g / 0.2), C[6], C[4], 0.7);
  // sap chips sprayed forward from the point, and a few speed lines inside the wedge
  burst(14, o.seed, (r) => {
    const born = DRIVE * r.range(0.7, 1.1), age2 = t - born, life = r.range(0.14, 0.28);
    if (age2 < 0 || age2 > life) return;
    const a = r.range(-H * 1.4, H * 1.4), sp = r.range(70, 160), q = age2 / life;
    const [x, y] = fly(L - 2, 0, Math.cos(a) * sp, Math.sin(a) * sp, age2, 0, 9);
    p.line(x, y, x - Math.cos(a) * 2.5, y - Math.sin(a) * 2.5, C[q < 0.4 ? 6 : 5]);
    p.light(x, y, C[5], 0.5 * (1 - q));
  });
  burst(5, o.seed + 3, (r) => {
    const y = r.range(-0.6, 0.6) * Math.tan(H) * L * 0.7, x0 = r.range(0.2, 0.5) * L, len = r.range(10, 22);
    const k = clamp((t - 0.02) / 0.12);
    if (k <= 0 || k >= 1) return;
    const x = x0 + k * L * 0.4;
    p.line(x, y * (x / L), x + len * (1 - k), y * ((x + len) / L), C[4], 0.7 * (1 - k));
  });
  if (t < 0.35) p.glow(tip * 0.8, 0, 22, C[4], 0.45 * (1 - t / 0.35));
}
