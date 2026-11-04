// Rainfall (for an iso camera): Bourbe's spat glob of mud flying towards +x, as a loop. A round, wobbling ball of wet
// clay (stays a ball when the flight is foreshortened) with a pale-green will-o'-wisp glint inside, drips shed behind.
import { fit, cycle, fly, TAU, tileNoise } from "../../core/index.js";

export const meta = {
  name: "Bourbe mud glob",
  desc: "A wobbling ball of wet mud flying right, a pale wisp glint inside, drips and a short smear shed behind.",
  tags: ["rainfall", "mud", "glob", "projectile", "loop"],
  size: [44, 32],
  origin: [30, 16],
  duration: 0.4,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06100a", "#0f1c14", "#1d3324", "#3a5e42", "#5f9a6c", "#8DDBA8", "#C2F0D2"],
    radius: 7,
    seed: 31,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, ph = t / meta.duration, S = o.seed;
  // short smear behind
  p.shade(-R * 2.4, -R * 0.6, 0, R * 0.6, (x, y, out) => {
    const u = -x / (R * 2.4), hw = R * 0.55 * (1 - u);
    if (u < 0 || Math.abs(y) > hw) return;
    out.c = C[u < 0.4 ? 3 : 2];
    out.a = u > 0.6 ? 0.6 : 1;
  });
  // the ball: wobbling rim, lumpy, lit top left
  p.shade(-R - 2, -R - 2, R + 2, R + 2, (x, y, out) => {
    const r = Math.hypot(x, y), a = Math.atan2(y, x);
    const e = R * (1 + 0.08 * Math.sin(a * 3 + ph * TAU) + 0.06 * Math.sin(a * 5 - ph * TAU * 2));
    if (r > e) return;
    const lit = Math.cos(a + 2.36), q = r / e;
    const n = tileNoise(x / 2.5, y / 2.5, 0, 0, S);
    let c = q > 0.8 ? (lit > 0.3 ? 4 : 2) : n > 0.3 ? 3 : 2;
    if (q < 0.8 && lit > 0.5 && q > 0.45) c = 4;
    out.c = C[c];
    out.k = c >= 4 ? 0.15 : 0;
    out.l = C[5];
  });
  // the wisp glint inside
  p.px(-1, -1, C[6]);
  p.px(0, -1, C[5]);
  p.px(-1, 0, C[5]);
  p.glow(-0.5, -0.5, R * 1.6, C[5], 0.5 + 0.1 * Math.sin(ph * TAU));
  // drips shed behind, falling a little
  cycle(t, meta.duration, 6, S + 1, 0.3, (age, life, r) => {
    const k = age / life, [x, y] = fly(-R * 0.8, r.range(-R, R) * 0.5, -r.range(30, 60), r.range(-10, 10), age, 40);
    p.dot(x, y, C[k < 0.5 ? 3 : 2], 1 - k);
  });
}
