// Rainfall (top-down, for an iso camera): the crest of a wave running across the floor, seen from above. It rides
// on a moving host, so it stays at the origin and loops: the water slides back through it.
import { fit, cycle, fly, flyV, TAU, clamp } from "../../core/index.js";
import { waterFront } from "./_lib.js";

export const meta = {
  name: "Tide front",
  desc: "Seen from above, a wave crest running right across the floor: a bowed white foam line, a ripple ahead, laced water streaming back, spray flung off the lip.",
  tags: ["rainfall", "water", "wave", "top-down", "directional", "loop"],
  size: [120, 132],
  origin: [76, 66],
  duration: 1.2,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#070D12", "#0D1A22", "#16303F", "#35596C", "#3E86A8", "#5EC8FF", "#A8E6FF"],
    width: 64, // px across the run (the hit band's length)
    band: 9, // crest thickness
    trail: 30, // water behind the crest
    bow: 8, // how far the middle leads the ends
    spray: 34,
    seed: 3,
  },
};

const P = 8, CS = 4; // the backward flow scrolls exactly one noise period (P cells of CS px) per loop

export function draw(p, t, o) {
  const C = fit(o.palette, 7), ph = t / meta.duration, hw = o.width / 2;
  const R = (hw * hw) / (2 * Math.max(1, o.bow)) + o.bow / 2, A = Math.asin(clamp(hw / R, 0, 1));
  waterFront(p, C, { cx: -R, R, A, band: o.band, trail: o.trail, flow: ph * P * CS, wob: ph * 4, seed: o.seed, loopP: P, curl: 5 });
  // spray: beads thrown forward and out off the lip, slowing, falling back into the run
  cycle(t, meta.duration, o.spray, o.seed + 11, (g) => g.range(0.25, 0.5), (age, life, r) => {
    const a = r.range(-A, A) * 0.95, sp = r.range(30, 75), dev = r.range(-0.5, 0.5);
    const bx = -R + Math.cos(a) * R - 1, by = Math.sin(a) * R;
    const dir = a + dev * 0.8, [x, y] = fly(bx, by, Math.cos(dir) * sp, Math.sin(dir) * sp, age, 0, 5);
    const k = age / life, big = r.next() < 0.3;
    // carried back by the flow as they fall
    const xx = x - age * 26 * k;
    p.dot(xx, y, C[k < 0.4 ? 6 : k < 0.75 ? 5 : 4], k < 0.7 ? 1 : (1 - k) / 0.3);
    if (big && k < 0.6) {
      const [vx, vy] = flyV(Math.cos(dir) * sp, Math.sin(dir) * sp, age, 0, 5), l = Math.hypot(vx, vy) || 1;
      p.dot(xx - vx / l, y - vy / l, C[5], 0.9);
      p.dot(xx + 1, y, C[k < 0.3 ? 6 : 5], 0.9);
    }
    p.light(xx, y, C[5], 0.5 * (1 - k));
  });
  // a soft cold pool riding with the crest
  const tw = 0.85 + 0.15 * Math.sin(ph * TAU * 2);
  for (let i = -2; i <= 2; i++) {
    const a = (i / 2) * A * 0.8;
    p.glow(-R + Math.cos(a) * R - 3, Math.sin(a) * R, 14, C[4], 0.16 * tw);
  }
}
