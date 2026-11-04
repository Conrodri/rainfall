// Rainfall (iso camera, a billboard): Ardent's Phénix, a bird of fire flying right, as a loop (one wing beat). Seen
// side-on and a little from above like every standing thing in the game: a body of layered flame, a head with a
// beak and a crest, the far wing behind and dimmer, the near wing in front, both beating; three long streamers of
// flame for a tail rippling behind, embers shed off it.
import { fit, clamp, rng, wrap, TAU, WHITE, mix } from "../../core/index.js";
import { hotFirst, flameBlade, solid, ember, noiseFor, looped, LAYERS, BACK_LAYERS } from "../fire/_lib.js";
import { PAL } from "./ardent-nova.js";

export const meta = {
  name: "Ardent phoenix",
  desc: "A bird of fire flying right, looped over one wing beat: layered flame body, beaked head and crest, far wing dim behind, near wing in front, a three-streamer tail shedding embers.",
  tags: ["rainfall", "fire", "phoenix", "bird", "familiar", "iso", "loop"],
  size: [84, 76],
  origin: [56, 38],
  duration: 0.6,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: PAL,
    wing: 27, // px, longest feather
    seed: 7,
  },
};

export function draw(p, t, o) {
  const F = fit(o.palette, 9), H = hotFirst(F), D = meta.duration, ph = t / D, S = o.seed * 23;
  const N = noiseFor(D), NT = (rate, seed, off) => N(t, rate, seed, off);
  const glowC = mix(H[3], WHITE, 0.1);
  const bob = -Math.sin(TAU * ph + 0.6) * 1.5; // the body rises a little on the down-stroke
  // a wing is a fan of feathers spanning out sideways and swung about the body's axis: theta is its angle above the
  // horizontal. The camera looks down 30°, so a wing reaching towards it (near) shows a little lower, the far one higher.
  const theta = 0.35 + 0.85 * Math.sin(TAU * ph + 0.6);
  const wing = (x0, y0, near, layers, dim, seedOff) => {
    for (let i = 4; i >= 0; i--) {
      const L = o.wing * (1 - i * 0.1) * dim, depth = L * Math.cos(theta) * 0.5 * (near ? 1 : -1);
      const tx = -L * (0.18 + i * 0.13), ty = -L * Math.sin(theta) + depth, len = Math.hypot(tx, ty) || 1;
      flameBlade(p, x0 - i * 1.4, y0 + i * 0.3, tx / len, ty / len, len, 2.4 + (4 - i) * 0.35, near ? -2 : 2, NT, S + seedOff + i * 5, H, layers, 0.4, 0.8);
    }
  };
  // the tail: three streamers rippling behind
  for (let i = 0; i < 3; i++) {
    const a = Math.PI + 0.22 - i * 0.2, L = 30 - i * 4, bend = 4 * Math.sin(TAU * (ph + i * 0.21));
    flameBlade(p, -8, 2 + bob, Math.cos(a), Math.sin(a), L, 2.4, bend, NT, S + 60 + i * 9, H, i === 1 ? LAYERS : BACK_LAYERS, 0.5, 1.4);
  }
  // the far wing, behind the body
  wing(2, -4 + bob, false, BACK_LAYERS, 0.85, 20);
  // the body: a teardrop of flame, hot at its heart
  for (let k = 0; k <= 8; k++) {
    const u = k / 8, x = -9 + u * 16, y = 2 - u * 4 + bob, r = 2.5 + 3.2 * Math.sin(Math.PI * clamp(u * 1.1));
    solid(p, x, y, r + 0.8, H[5]);
  }
  for (let k = 0; k <= 8; k++) {
    const u = k / 8, x = -8 + u * 15, y = 1.6 - u * 4 + bob, r = 1.8 + 2.4 * Math.sin(Math.PI * clamp(u * 1.1));
    solid(p, x - 0.4, y - 0.5, r, u > 0.3 && u < 0.85 ? H[2] : H[3]);
  }
  solid(p, -1, -1 + bob, 2.2, H[0]);
  // neck, head, beak, eye, crest
  solid(p, 9, -5 + bob, 3.3, H[4]);
  solid(p, 8.6, -5.5 + bob, 2.4, H[2]);
  p.tri(11.5, -6.5 + bob, 16.5, -4.6 + bob, 11.5, -3.6 + bob, H[1]);
  p.px(10, -6 + bob, H[0]);
  for (let i = 0; i < 3; i++) flameBlade(p, 7.5, -7.5 + bob, -0.75 + i * 0.12, -0.65 + i * 0.1, 9 - i * 2, 1.4, 1.5, NT, S + 90 + i, H, LAYERS, 0.4, 0.9);
  // the near wing, in front
  wing(0, -2 + bob, true, LAYERS, 1, 0);
  p.glow(0, -2 + bob, 26, glowC, 0.45);
  p.glow(-20, 4 + bob, 18, H[4], 0.2);
  // embers shed off the tail and wing tips, drifting back
  looped(t, D, 14, o.seed + 1, (r) => ({ x: r.range(-30, -6), y: r.range(-8, 10), life: r.range(0.35, 0.6), vx: -r.range(20, 45), vy: r.range(-20, 6), ph: r.range(0, 6) }), (q, age) => {
    ember(p, q.x + q.vx * age, q.y + q.vy * age + bob, 1 - age / q.life, 1, [H[0], H[1], H[3], H[5]], age * 30 + q.ph);
  });
}
