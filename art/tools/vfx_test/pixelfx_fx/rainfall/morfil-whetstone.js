// Rainfall (billboard, for an iso camera): Taliant draws his blade along the whetstone. Drawn upright in screen space
// at his side (the blade stands), with a small 2:1 ground ellipse of light at his feet: the edge lights up in a glint
// that runs from heel to tip, sparks spray off the stone at each pass, and the tip rings with a star when it is keen.
import { fit, burst, fly, clamp, smooth, ease, sparkle, bump, TAU } from "../../core/index.js";

export const meta = {
  name: "Taliant whetstone",
  desc: "Upright at the caster's side: the edge glints heel to tip at each pass of the stone, sparks fall, the tip rings with a star. Over-edge: more passes, motes spiral up the blade.",
  tags: ["rainfall", "buff", "sharpen", "blade", "billboard", "one-shot"],
  size: [80, 96],
  origin: [40, 76],
  duration: 0.9,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0d1008", "#1a2010", "#2e3a1c", "#58703a", "#8fb04e", "#CDEB6E", "#E6F7A8"],
    passes: 2,
    over: 0, // 1 = Sur-aiguisage : brighter, motes spiral up the blade
    seed: 4,
  },
};

// the blade, in screen px from the feet: heel low at the side, tip high and slightly forward
const HX = 9, HY = -10, TX = 15, TY = -50;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), n = o.passes + (o.over ? 1 : 0), PASS = o.over ? 0.16 : 0.22;
  const end = n * PASS, fade = smooth(end, end + 0.35, t), live = 1 - fade;
  const bx = (u) => HX + (TX - HX) * u, by = (u) => HY + (TY - HY) * u;
  // floor light: a 2:1 ellipse under the caster, brightest during the passes
  const fl = live * (0.5 + 0.5 * (o.over ? 1 : 0.6));
  p.shade(-22, -11, 22, 11, (x, y, out) => {
    const d = Math.hypot(x / 20, y / 10);
    if (d > 1) return;
    if (d > 0.6 && ((Math.floor(x) + Math.floor(y)) & 1)) return;
    out.c = C[d < 0.5 ? 3 : 2];
    out.a = 0.35 * fl * (1 - d);
    out.k = 0.08 * fl * (1 - d);
    out.l = C[4];
  });
  if (live <= 0.01) return;
  // the edge: a thin bright line along the blade, dimmer between passes
  const ph = clamp(t / PASS), k = Math.min(n - 1, Math.floor(t / PASS)), local = clamp((t - k * PASS) / PASS);
  p.line(bx(0), by(0), bx(1), by(1), C[5], live);
  p.line(bx(0) + 1, by(0), bx(1) + 1, by(1), C[3], 0.9 * live);
  p.line(bx(0) - 1, by(0) + 1, bx(0) + 2, by(0) + 1, C[2], live); // the tsuba
  p.glowLine(bx(0), by(0), bx(1), by(1), 5, C[4], 0.25 * live);
  // the glint running heel to tip on this pass
  if (t < end) {
    const g = ease.inOutQuad(local), gx = bx(g), gy = by(g);
    p.line(bx(Math.max(0, g - 0.35)), by(Math.max(0, g - 0.35)), gx, gy, C[6]);
    p.line(bx(Math.max(0, g - 0.35)) + 1, by(Math.max(0, g - 0.35)), gx + 1, gy, C[5]);
    p.glowLine(bx(Math.max(0, g - 0.3)), by(Math.max(0, g - 0.3)), gx, gy, 6, C[5], 0.6);
    // the stone: a dark block pressed on the edge, sliding with the glint
    p.rect(gx - 3, gy - 1, 3, 3, C[1]);
    p.px(gx - 3, gy - 1, C[3]);
    // sparks off the stone, falling outward
    burst(11, o.seed + k * 13, (r) => {
      const born = r.range(0, 0.9) * PASS, a2 = local * PASS - born, life = r.range(0.12, 0.24);
      if (a2 < 0 || a2 > life) return;
      const u0 = ease.inOutQuad(born / PASS), sx = bx(u0), sy = by(u0), q = a2 / life;
      const [x, y] = fly(sx, sy, r.range(10, 60), r.range(-40, 10), a2, 260, 2);
      p.dot(x, y, C[q < 0.35 ? 6 : 5], 1 - q * 0.6);
      p.light(x, y, C[5], 0.4 * (1 - q));
    });
  }
  // the tip rings when the last pass ends
  const g2 = t - end + 0.03;
  if (g2 > 0 && g2 < 0.28) sparkle(p, bx(1), by(1), (o.over ? 9 : 7) * ease.outBack(Math.min(1, g2 / 0.06)) * (1 - g2 / 0.28), C[6], C[4], 0.8);
  // over-edge: sap motes spiralling up round the blade
  if (o.over)
    burst(12, o.seed + 77, (r) => {
      const born = r.range(0, end), a2 = t - born, life = r.range(0.35, 0.55);
      if (a2 < 0 || a2 > life) return;
      const q = a2 / life, u = clamp(r.range(0, 0.4) + q * 0.8), sp = Math.sin((q * 2 + r.next()) * TAU) * (4 - 2 * q);
      const x = bx(u) + sp, y = by(u) - q * 4;
      p.dot(x, y, C[q < 0.5 ? 6 : 5], 1 - q);
      p.light(x, y, C[5], 0.35 * (1 - q));
    });
  p.glow(bx(0.6), by(0.6), 20, C[4], 0.35 * live * (o.over ? 1.3 : 1) * (0.6 + 0.4 * bump(ph, 0, 1)));
}
