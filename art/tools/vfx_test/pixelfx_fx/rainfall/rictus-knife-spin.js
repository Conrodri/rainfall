// Rainfall (for an iso camera): Rictus's heavy knife thrown on its thread, flying towards +x, as a loop. The blade
// spins end over end so fast it reads as a round steel blur (readable in every direction, even foreshortened), a
// porcelain-white glint at the hub, a short wake of steel motes and the taut thread trailing behind.
import { fit, cycle, fly, TAU, clamp } from "../../core/index.js";

export const meta = {
  name: "Rictus spinning knife",
  desc: "A heavy knife spinning end over end towards the right: a round steel blur with two bright blade arcs, a glint at the hub, the thread and a wake of motes trailing behind.",
  tags: ["rainfall", "rictus", "knife", "blade", "projectile", "spin", "loop"],
  size: [64, 32],
  origin: [44, 16],
  duration: 0.4,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0a0d0d", "#141b1b", "#26312f", "#46585a", "#6f8f8a", "#9FC8C0", "#c9e3dd"],
    radius: 8,
    tail: 30,
    seed: 21,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, T = o.tail, ph = t / meta.duration;
  const spin = ph * TAU * 2; // two turns per loop, seamless
  // the thread trailing back to the hand, a faint wavering hair
  for (let x = -R; x > -R - T; x--) {
    const u = (-R - x) / T, y = Math.sin(u * 7 - ph * TAU) * 1.2 * u;
    p.dot(x, y, C[u < 0.4 ? 5 : 4], 0.7 * (1 - u));
  }
  // the blur disc: a dim steel veil, two bright arcs where the blade's edges sweep
  p.shade(-R - 1, -R - 1, R + 1, R + 1, (x, y, out) => {
    const r = Math.hypot(x, y);
    if (r > R + 0.3) return;
    const a = Math.atan2(y, x);
    let best = 1;
    for (let k = 0; k < 2; k++) {
      let d = a - (spin + k * Math.PI);
      d -= Math.round(d / TAU) * TAU;
      if (d < 0 && d > -1.6) best = Math.min(best, -d / 1.6); // smear behind each edge
    }
    const rim = r > R - 2.2;
    if (best < 1) {
      const q = best;
      out.c = C[clamp(Math.round(6 - q * 3 - (rim ? 0 : 1)), 2, 6)];
      out.k = 0.5 * (1 - q) * (r / R);
      out.l = C[5];
      return;
    }
    if (rim && (Math.floor(x) + Math.floor(y)) % 2 === 0) { out.c = C[3]; out.a = 0.7; return; }
    if (r < R * 0.5) { out.c = C[2]; out.a = 0.5; }
  });
  // the blade itself at this instant: a long sliver through the hub
  const c = Math.cos(spin), s = Math.sin(spin);
  p.line(-c * R, -s * R, c * R, s * R, C[6]);
  p.line(-c * R * 0.6 - s, -s * R * 0.6 + c, c * R * 0.6 - s, s * R * 0.6 + c, C[4]);
  // hub glint and light
  p.dot(0, 0, C[6]);
  p.glow(0, 0, R * 2.6, C[5], 0.55 + 0.1 * Math.sin(ph * TAU * 2));
  // motes shed backwards
  cycle(t, meta.duration, 9, o.seed, 0.25, (age, life, r) => {
    const k = age / life, a = r.range(0, TAU);
    const [x, y] = fly(Math.cos(a) * R * 0.8, Math.sin(a) * R * 0.8, (-T / life) * 0.8, r.range(-18, 18), age);
    p.dot(x, y, C[k < 0.4 ? 6 : 5], 1 - k);
    p.light(x, y, C[5], 0.3 * (1 - k));
  });
}
