// Rainfall (for an iso camera): the Phénix's fire bolt, as a loop, flying towards +x. Seen from above, a small bird of
// flame in a dive: a white-hot beak and head, a tapered body, two flame wings swept back in a V that beat a little,
// three tail streamers rippling behind, embers shed off it. Its outline reads as a bird or a feathered dart in every
// direction; the hot head stays the brightest point so the flight line reads at a glance.
import { fit, cycle, fly, noise, TAU } from "../../core/index.js";

export const meta = {
  name: "Ardent phoenix bolt",
  desc: "A small diving bird of flame flying right, seen from above: white-hot beak, tapered body, two flame wings swept back in a beating V, three rippling tail streamers, embers shed behind.",
  tags: ["rainfall", "fire", "phoenix", "bird", "feather", "projectile", "loop"],
  size: [104, 48],
  origin: [76, 24],
  duration: 0.6,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0d0504", "#1f0b06", "#3a1a10", "#6b3a26", "#a8481a", "#FF7319", "#ffa35a"],
    span: 15, // px, half wingspan at the tips
    sweep: 15, // px, how far back the wing tips sit behind the shoulders
    tail: 36, // px, streamers behind the body
    seed: 11,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), ph = t / meta.duration, S = o.span, W = o.sweep, T = o.tail;
  const beat = Math.sin(ph * TAU); // one wing beat per loop
  const bx = -12; // root of the tail
  // tail: three streamers rippling behind, tapering and broken up towards their ends
  for (let k = -1; k <= 1; k++) {
    const len = T * (k === 0 ? 1 : 0.8);
    for (let i = 0; i <= len; i++) {
      const u = i / len, x = bx - i;
      const y = k * (2 + u * 7) + Math.sin((u * 2.2 - ph) * TAU + k) * (1 + u * 3);
      if (u > 0.55 && ((i + Math.floor(ph * 12)) & 1)) continue;
      const c = u < 0.2 ? 6 : u < 0.5 ? 5 : u < 0.8 ? 4 : 3;
      p.dot(x, y, C[c], 1 - u * 0.5);
      if (u < 0.35) p.dot(x, y + (k >= 0 ? 1 : -1), C[c - 1], 0.8);
      if (u < 0.6) p.light(x, y, C[5], 0.35 * (1 - u));
    }
  }
  // wings: flame feathers swept back in a V from the shoulders, the tips beating in and out
  for (const side of [-1, 1]) {
    const tipX = -W - 4 + beat * 1.5, tipY = side * (S + beat * 2.5);
    for (let f = 0; f < 5; f++) {
      const sx = -2 - f * 2.2, sy = side * 2.5; // shoulder, each feather rooted further back
      const fl = 1 - f * 0.13 + 0.06 * noise(ph * 10 + f * 3 + side, 4);
      const ex = sx + (tipX - sx + f * 1.5) * fl, ey = sy + (tipY - sy) * fl * (1 - f * 0.08);
      const c = f === 0 ? 6 : f < 3 ? 5 : 4;
      p.line(sx, sy, ex, ey, C[c]);
      p.light(ex, ey, C[5], 0.25);
    }
    // leading edge lit from the top-left, dark trailing edge
    p.line(-1, side * 2, tipX + 1, tipY, C[side < 0 ? 6 : 5]);
    p.line(-10, side * 2, tipX + 2, tipY + side * -1, C[3], 0.8);
  }
  // body: a flame spindle, stretched backwards, flickering
  p.shade(bx - 2, -5, 6, 5, (x, y, out) => {
    const fl = 0.9 + 0.1 * Math.sin(ph * TAU * 3 + x * 0.5);
    const rx = x < 0 ? 13 * fl : 6, d = Math.hypot(x / rx, y / 3.6);
    if (d > 1) return;
    const lit = (-x - 2 * y) / 14;
    let c = d < 0.4 ? 6 : d < 0.75 ? 5 : 4;
    if (lit > 0.3 && c < 6) c += 1;
    out.c = C[c];
    out.k = d < 0.6 ? 0.6 : 0.25;
    out.l = C[5];
  });
  // head and beak: the brightest point, pointing along the flight
  p.tri(3, -3, 3, 3, 12, 0, () => C[6]);
  p.circle(3, 0, 2.5, () => C[6]);
  p.dot(11, 0, C[6]);
  p.glow(4, 0, 12, C[5], 0.65 + 0.1 * Math.sin(ph * TAU * 4));
  p.glow(-8, 0, 16, C[5], 0.3);
  // embers shed behind
  cycle(t, meta.duration, 14, o.seed, (g) => g.range(0.25, 0.45), (age, life, r) => {
    const k = age / life, [x, y] = fly(bx - r.range(0, 10), r.range(-S, S) * 0.6, -T / life, r.range(-14, 14), age, 0, 1.5);
    p.dot(x, y, C[k < 0.35 ? 6 : k < 0.7 ? 5 : 4], 1 - k);
    if (k < 0.4) p.light(x, y, C[5], 0.3 * (1 - k / 0.4));
  });
}
