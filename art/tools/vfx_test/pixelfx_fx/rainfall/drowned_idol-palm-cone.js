// Rainfall (top-down, for an iso camera): a palm strike that throws a fan of water across the floor, seen from above.
// One-shot. The front races out from the origin to `radius` px inside a cone of half angle `span` (radians, centred
// on +x) in a tenth of a second: the whole cone is the hit, so it fills at once, laced water behind a white crest,
// spray thrown off the rim, then it drains away. Used by the Drowned Idol's palm and the Lock-keeper's gate blow.
import { fit, stream, burst, fly, clamp, smooth, ease } from "../../core/index.js";
import { waterFront } from "./_lib.js";

export const meta = {
  name: "Palm cone",
  desc: "Seen from above, a palm strike throws a fan of water over the floor: a white crest races to the cone's reach at once, laced water fills it, spray flies off, then it drains.",
  tags: ["rainfall", "water", "cone", "melee", "boss", "top-down", "directional", "one-shot"],
  size: [104, 160],
  origin: [10, 80],
  duration: 0.8,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06090d", "#0b1219", "#16222c", "#34505e", "#6f98a8", "#8fc8d8", "#5EC8FF", "#BFF4FF"],
    radius: 72, // px reach of the cone
    span: 1.05, // half angle (radians)
    band: 6,
    seed: 4,
  },
};

const RUN = 0.11; // the front reaches the cone's rim

export function draw(p, t, o) {
  const C = fit(o.palette, 8), R1 = o.radius, A = o.span;
  const reach = (tt) => R1 * (0.12 + 0.88 * ease.outExpo(clamp(tt / RUN)));
  const R = reach(t);
  const k = smooth(0, 0.04, t) * (1 - smooth(0.3, meta.duration - 0.04, t));
  // the water body fills the whole cone back to the origin, its flow running outwards
  waterFront(p, C, { cx: 0, R, A, band: o.band * (1.1 - 0.4 * smooth(RUN, 0.5, t)), trail: Math.max(R - 4, 4), flow: -t * 60, wob: t * 4, k, seed: o.seed, curl: 4, light: 0.55 });
  // radial jets inside the cone while the front runs: bright streaks shooting out from the palm
  burst(14, o.seed + 2, (r) => {
    const a = r.range(-A, A) * 0.9, born = r.range(0, RUN * 0.8), age = t - born, life = r.range(0.12, 0.22);
    if (age < 0 || age > life) return;
    const q = age / life, r0 = reach(born) * r.range(0.1, 0.4), len = R1 * r.range(0.3, 0.6) * ease.outCubic(q);
    const c = Math.cos(a), s = Math.sin(a);
    p.line(c * (r0 + len * 0.5), s * (r0 + len * 0.5), c * (r0 + len), s * (r0 + len), C[q < 0.5 ? 7 : 6], 1 - q);
    p.light(c * (r0 + len), s * (r0 + len), C[6], 0.4 * (1 - q));
  });
  // spray flung forward off the rim, slowing and falling out
  stream(t, 0.02, RUN + 0.08, 220, o.seed + 9, (g) => g.range(0.2, 0.42), (age, life, r) => {
    const born = t - age, Rb = reach(born), a = r.range(-A, A) * 0.95, sp = r.range(30, 80), dir = a + r.range(-0.35, 0.35);
    const [x, y] = fly(Math.cos(a) * Rb, Math.sin(a) * Rb, Math.cos(dir) * sp, Math.sin(dir) * sp, age, 0, 5);
    const q = age / life;
    p.dot(x, y, C[q < 0.35 ? 7 : q < 0.7 ? 6 : 5], q < 0.6 ? 1 : (1 - q) / 0.4);
    p.light(x, y, C[6], 0.45 * (1 - q));
  });
  // the two edges of the cone catch the light for a beat: the player reads the angle
  if (t < 0.4) {
    const e = 1 - smooth(0.12, 0.4, t);
    for (const s of [-1, 1]) {
      const c = Math.cos(A * s), sn = Math.sin(A * s);
      p.line(c * 6, sn * 6, c * R * 0.97, sn * R * 0.97, C[s < 0 ? 6 : 5], 0.7 * e);
    }
  }
  // the palm's flash, then a cold light riding the rim
  if (t < 0.2) p.glow(6, 0, 22, C[7], 0.7 * (1 - t / 0.2));
  for (let i = -2; i <= 2; i++) {
    const a = (i / 2) * A * 0.8;
    p.glow(Math.cos(a) * (R - 5), Math.sin(a) * (R - 5), 14, C[6], 0.22 * k);
  }
}
