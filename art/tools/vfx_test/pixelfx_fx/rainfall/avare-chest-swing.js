// Rainfall (top-down, for an iso camera): Avare's Coup de coffre seen from above. One-shot. The strongbox swung at the
// end of its chain sweeps a wide arc in front of him: the crescent smear of rainfall/crescent-sweep (reused as is),
// plus the chain from his hands to the box, the box itself riding the head of the arc, and coins shaken loose.
import { fit, clamp, ease, burst, fly } from "../../core/index.js";
import { draw as sweep } from "./crescent-sweep.js";

export const meta = {
  name: "Avare chest swing",
  desc: "Seen from above, a strongbox swung on its chain sweeps a wide arc: a heavy gold-rimmed smear, the taut chain, the box riding the head, coins shaken loose off the rim.",
  tags: ["rainfall", "melee", "swing", "chest", "gold", "top-down", "directional", "one-shot"],
  size: [96, 136],
  origin: [16, 68],
  duration: 0.52,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0e0a04", "#1c1408", "#33260f", "#5c4620", "#8f6e2e", "#F2C14E", "#F8DE92"],
    radius: 42,
    span: 2.618, // radians swept, centred on +x
    seed: 5,
  },
};

const SWEEP = 0.085, HOLD = 0.06;

export function draw(p, t, o) {
  sweep(p, t, o);
  const C = fit(o.palette, 7), R = o.radius, A0 = -o.span / 2;
  const head = A0 + o.span * ease.outExpo(clamp(t / SWEEP));
  const show = 1 - clamp((t - SWEEP - HOLD) / 0.12);
  if (show > 0.02) {
    const c = Math.cos(head), s = Math.sin(head), bx = c * (R - 7), by = s * (R - 7);
    // the chain, taut from the hands to the box
    for (let k = 0; k < 7; k++) {
      const u = (k + 0.5) / 7, x = c * (R - 12) * u + c * 3, y = s * (R - 12) * u + s * 3;
      p.dot(x, y, C[k % 2 ? 3 : 4], show);
      p.dot(x - s, y + c, C[2], show);
    }
    // the box: a dark square with gold banding, edge leading
    const w = 6.5;
    p.shade(bx - w * 1.5, by - w * 1.5, bx + w * 1.5, by + w * 1.5, (x, y, out) => {
      const dx = x - bx, dy = y - by, u = dx * c + dy * s, v = -dx * s + dy * c;
      if (Math.abs(u) > w || Math.abs(v) > w * 0.8) return;
      const band = Math.abs(u) > w - 1.6 || Math.abs(v) < 1;
      out.c = C[band ? (dx + dy < 0 ? 6 : 5) : u + v < 0 ? 2 : 1];
      out.a = show;
      out.k = band ? 0.3 * show : 0;
      out.l = C[5];
    });
    p.glow(bx, by, 14, C[5], 0.35 * show);
  }
  // coins shaken loose off the rim, flung outward
  burst(7, o.seed + 2, (r) => {
    const a = A0 + o.span * r.range(0.25, 1), born = SWEEP * r.range(0.3, 1), age = t - born, life = r.range(0.2, 0.32);
    if (age < 0 || age > life) return;
    const sp = r.range(50, 110), [x, y] = fly(Math.cos(a) * R, Math.sin(a) * R, Math.cos(a) * sp, Math.sin(a) * sp, age, 0, 6), k = age / life;
    const spin = Math.abs(Math.cos(age * 40 + a));
    p.ellipse(x, y, 1.8 * Math.max(0.3, spin), 1.8, C[k < 0.5 ? 6 : 5], 1 - k * 0.5);
    p.light(x, y, C[5], 0.45 * (1 - k));
  });
}
