// Rainfall (for an iso camera): Vigie's special arrows in flight, as a loop, flying towards +x (projectile class: the
// game turns it and shortens it with the perspective, so the head stays a compact blob readable in every direction).
// kind 1 = distress flare arrow (a sputtering red-white head, a smoky spark trail);
// kind 2 = weighted net arrow (a dark rolled net bundle with lead weights behind the point, a dull wake).
import { fit, cycle, fly, TAU } from "../../core/index.js";

export const meta = {
  name: "Vigie arrow (flare / net)",
  desc: "An arrow flying right. Flare: a white-hot head throwing sparks and smoke. Net: a rolled net bundle with two lead weights swinging behind the point.",
  tags: ["rainfall", "arrow", "projectile", "flare", "net", "loop"],
  size: [96, 40],
  origin: [72, 20],
  duration: 0.4,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0c0507", "#1c0a0e", "#35121a", "#6a1b2a", "#B02438", "#FF3A4F", "#FF8C98"],
    kind: 1,
    seed: 23,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), ph = t / meta.duration, x0 = -26;
  const flare = o.kind === 1;
  // shaft, lit on top
  p.line(x0, -1, 0, -1, C[6]);
  p.line(x0, 0, 0, 0, C[5]);
  p.line(x0, 1, 0, 1, C[3]);
  // fletching
  for (let i = 0; i < 3; i++) {
    const fx = x0 + 1 + i * 2;
    p.line(fx, -1, fx - 4, -5, C[5]);
    p.line(fx, 1, fx - 4, 5, C[4]);
  }
  if (flare) {
    // the flare head: a ragged bloom round a white-hot core, the trail of sparks and a thread of smoke behind
    const s = 3 + 0.6 * Math.sin(ph * TAU * 3);
    p.disc(3, 0, s + 2, C[4], 0.9);
    p.disc(3, 0, s + 0.8, C[5]);
    p.disc(3, 0, s * 0.5, C[6]);
    p.glow(3, 0, 16, C[5], 0.95);
    p.glowLine(-20, 0, 3, 0, 6, C[5], 0.35);
    cycle(t, meta.duration, 16, o.seed, 0.3, (age, life, r) => {
      const q = age / life, [x, y] = fly(r.range(-2, 4), r.range(-2, 2), -r.range(50, 110), r.range(-25, 25), age, 30);
      p.dot(x, y, C[q < 0.3 ? 6 : q < 0.65 ? 5 : 4], 1 - q * 0.6);
      p.light(x, y, C[5], 0.35 * (1 - q));
    });
    cycle(t, meta.duration, 6, o.seed + 9, 0.4, (age, life, r) => {
      const q = age / life;
      p.dot(-4 - q * 30, r.range(-1, 1) - q * 3, C[q < 0.5 ? 3 : 2], 0.7 * (1 - q));
    });
  } else {
    // the point
    p.tri(0, -3, 0, 4, 8, 0.5, () => C[5]);
    // the rolled net: a dark bundle with a cord lattice, and two lead weights swinging below and above
    p.rect(-11, -3, 9, 7, C[2]);
    for (let i = -10; i < -2; i += 2) p.line(i, -3, i + 2, 3, C[4]);
    p.line(-11, -3, -3, -3, C[3]);
    const sw = Math.sin(ph * TAU) * 2;
    for (const s of [-1, 1]) {
      const wx = -9 + sw * s, wy = s * 6;
      p.line(-7, s * 3, wx, wy, C[3]);
      p.disc(wx, wy, 1.6, C[1]);
      p.px(wx - 1, wy - 1, C[4]);
    }
    p.glow(-6, 0, 12, C[4], 0.35);
    p.glow(5, 0, 8, C[5], 0.4);
    cycle(t, meta.duration, 5, o.seed, 0.25, (age, life, r) => {
      const q = age / life;
      p.dot(-12 - q * 22, r.range(-2, 2), C[3], 0.6 * (1 - q));
    });
  }
}
