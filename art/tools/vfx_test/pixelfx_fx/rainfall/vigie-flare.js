// Rainfall (billboard, for an iso camera): Vigie's magnesium distress flare, as a loop. Drawn upright in screen space
// (the flare stands and burns) over a 2:1 ground ellipse of red light whose rim marks the lit radius (the game's
// exposure range). Planted: an arrow shaft stuck in the ground, the flare sputtering at its nock. Held (Fanal): the
// flare burns at bow height over the caster's feet.
import { fit, cycle, fly, TAU } from "../../core/index.js";

export const meta = {
  name: "Vigie flare",
  desc: "Upright: a magnesium flare sputtering on a planted arrow (or held at bow height), sparks arcing down; a 2:1 ellipse of red light on the floor, rimmed at the lit radius. Loops.",
  tags: ["rainfall", "flare", "light", "fire", "billboard", "ground", "loop"],
  size: [128, 120],
  origin: [64, 76],
  duration: 1.2,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0c0507", "#1c0a0e", "#35121a", "#6a1b2a", "#B02438", "#FF3A4F", "#FF8C98"],
    radius: 48, // px of lit floor (16 px per game unit) : 3 u
    stake: 1, // 1 = planted arrow ; 0 = held flare (Fanal)
    lift: 10, // px : flare height when held
    seed: 12,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, RY = R / 2, ph = t / meta.duration;
  const flick = 0.88 + 0.06 * Math.sin(ph * TAU * 7) + 0.06 * Math.sin(ph * TAU * 11 + 1.3);
  // the flare head position: on the nock of a slanted stake, or held at bow height
  const hx = o.stake ? 3 : 3, hy = o.stake ? -12 : -o.lift; // a small flare: about 0.75 u up the shaft
  // floor: an ellipse of red light, dithered towards its rim, and the rim itself (the exposure radius)
  p.shade(-R - 1, -RY - 1, R + 1, RY + 1, (x, y, out) => {
    const d = Math.hypot(x / R, y / RY);
    if (d > 1.02) return;
    if (d > 0.93) {
      // the rim: short dashes creeping round
      const a = Math.atan2(y / RY, x / R) / TAU + ph * 0.25;
      if (((a * 40) % 1 + 1) % 1 > 0.55) return;
      out.c = C[4];
      out.a = 0.7;
      out.k = 0.25;
      out.l = C[5];
      return;
    }
    const f = 1 - d;
    if (d > 0.45 && ((Math.floor(x) + Math.floor(y)) & 1) && d > 0.7) return;
    out.c = C[d < 0.2 ? 6 : d < 0.45 ? 5 : d < 0.75 ? 4 : 3]; // a pool of red light, never a dark stain
    out.a = (0.12 + 0.5 * f) * flick;
    out.k = 0.2 * f * f * flick;
    out.l = C[5];
  });
  // a dark scorch where the stake bites the ground
  if (o.stake) {
    p.disc(0, 0, 1.5, C[0], 0.9);
    // the shaft, slanted, lit on its top side
    p.line(0, 0, hx, hy + 2, C[4]);
    p.line(1, 0, hx + 1, hy + 2, C[5]);
    // fletching low on the shaft, half buried
    p.line(1, -2, -1, -4, C[5]);
    p.line(1, -2, 3, -4, C[4]);
  }
  // the flare: a white-hot core in a ragged red bloom
  const s = 1.4 * flick;
  p.disc(hx, hy, s + 1.1, C[4], 0.85);
  p.disc(hx, hy, s + 0.4, C[5], 1);
  p.disc(hx, hy, s * 0.6, C[6], 1);
  // ragged spikes of flame, flickering
  for (let i = 0; i < 7; i++) {
    const a = -Math.PI / 2 + (i - 3) * 0.45, l = s + 1 + 1.5 * (0.5 + 0.5 * Math.sin(ph * TAU * (5 + i) + i * 1.7));
    p.line(hx, hy, hx + Math.cos(a) * l, hy + Math.sin(a) * l, C[i & 1 ? 5 : 6]);
  }
  p.glow(hx, hy, 9 * flick, C[5], 0.7);
  p.glow(hx, hy, 4, C[6], 0.5);
  // sputtering sparks: thrown up and out, falling back under gravity
  cycle(t, meta.duration, 22, o.seed, (g) => g.range(0.35, 0.7), (age, life, r) => {
    const q = age / life, a = -Math.PI / 2 + r.range(-1.3, 1.3), sp = r.range(14, 34);
    const [x, y] = fly(hx, hy, Math.cos(a) * sp, Math.sin(a) * sp, age, 140, 1.5);
    if (y > 2) return; // landed
    p.dot(x, y, C[q < 0.3 ? 6 : q < 0.7 ? 5 : 4], 1 - q * 0.5);
    p.light(x, y, C[5], 0.35 * (1 - q));
  });
  // a thin smoke thread drifting up and leaning
  cycle(t, meta.duration, 8, o.seed + 5, 0.9, (age, life, r) => {
    const q = age / life, x = hx + q * 5 + Math.sin((q + r.next()) * TAU) * 2, y = hy - 2 - q * 16;
    p.dot(x, y, C[q < 0.5 ? 3 : 2], 0.6 * (1 - q));
  });
}
