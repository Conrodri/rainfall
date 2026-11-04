// Rainfall (top-down, for an iso camera): the burning furrow the Phénix leaves when it dives, seen from straight
// above in the game's logical floor plane (the camera squashes it 2:1). One-shot. A white-hot seam races along +x
// from the pivot over `len` px, flame blooms open along it (round, hot hearts), then it smoulders into a scorched
// streak with glowing cinders.
import { fit, clamp, smooth, ease, noise2, rand, rng, TAU, WHITE, mix } from "../../core/index.js";
import { hotFirst, ember } from "../fire/_lib.js";
import { PAL } from "./ardent-nova.js";

export const meta = {
  name: "Ardent fire streak",
  desc: "Seen from above: a white-hot seam races along the floor, flame blooms open along it, then it smoulders into a scorched streak with glowing cinders.",
  tags: ["rainfall", "fire", "streak", "line", "top-down", "ground", "one-shot"],
  size: [64, 48],
  origin: [8, 24],
  duration: 0.9,
  loop: false,
  fps: 30,
  bg: "dark",
  options: { palette: PAL, len: 48, width: 16, run: 0.08, seed: 4 },
};

export function draw(p, t, o) {
  const F = fit(o.palette, 9), H = hotFirst(F), L = o.len, W = o.width / 2, S = o.seed * 7, D = meta.duration;
  if (t >= D - 0.02) return;
  const head = L * ease.outCubic(clamp(t / o.run)), cool = smooth(0.12, D - 0.05, t);
  // the streak: scorch, seam and cinders
  p.shade(-2, -W - 1, L + 2, W + 1, (x, y, out) => {
    if (x > head) return;
    const u = x / L, taper = Math.sin(Math.PI * clamp(u * 0.92 + 0.04)), half = W * (0.35 + 0.65 * taper) * (0.85 + 0.15 * noise2(x * 0.3, 0, S));
    const q = Math.abs(y) / Math.max(1, half);
    if (q > 1) return;
    const heat = clamp(1 - cool * 1.1 - q * 0.5 + 0.2 * noise2(x * 0.4, y * 0.4, S + 1));
    if (q < 0.25 && heat > 0.3) {
      out.c = heat > 0.8 ? H[0] : heat > 0.6 ? H[1] : H[3];
      out.k = 0.6 * heat;
      out.l = H[2];
      return;
    }
    const cin = rand(Math.floor(x / 2), Math.floor(y / 2), S + 2) < 0.22 * (1 - q);
    if (cin && heat > 0.1) {
      out.c = heat > 0.5 ? H[2] : H[4];
      out.k = 0.35 * heat;
      out.l = H[3];
      return;
    }
    // scorch: sparse, warm-dark patches that thin out as it cools (no solid black band)
    if (rand(Math.floor(x / 3), Math.floor(y / 2), S + 3) < 0.35 + cool * 0.65 + q * 0.3) return;
    out.c = q < 0.5 ? F[3] : F[2];
  });
  // flame blooms along the seam, seen from above: round flames with hot hearts, opening then guttering
  for (let i = 0; i < 9; i++) {
    const g = rng(o.seed, i), x = L * (0.08 + 0.84 * (i / 8)) + g.range(-2, 2), y = g.range(-W * 0.35, W * 0.35);
    const born = o.run * (x / L), age = t - born, life = g.range(0.3, 0.55);
    if (age < 0 || age > life) continue;
    const k = age / life, r = (3 + g.range(0, 3)) * Math.sin(Math.PI * Math.min(1, k * 1.4 + 0.1));
    if (r < 0.6) continue;
    p.circle(x, y, r + 1, k < 0.5 ? H[4] : H[5]);
    p.circle(x - 0.4, y - 0.4, r * 0.65, k < 0.4 ? H[1] : H[3]);
    if (k < 0.3) p.circle(x - 0.6, y - 0.6, r * 0.3, H[0]);
    p.glow(x, y, r * 3, H[3], 0.35 * (1 - k));
  }
  // cinders thrown off the sides
  for (let i = 0; i < 12; i++) {
    const g = rng(o.seed + 5, i), x0 = g.range(0, L), born = o.run * (x0 / L), age = t - born, life = g.range(0.3, 0.6);
    if (age < 0 || age > life) continue;
    const side = g.chance(0.5) ? 1 : -1, d = W * 0.4 + age * g.range(20, 40);
    ember(p, x0 + age * g.range(-6, 10), side * d, 1 - age / life, 1, [H[0], H[1], H[3], H[5]], age * 30 + i);
  }
  if (t < o.run + 0.05) p.glow(head, 0, 10, H[1], 0.6);
}
