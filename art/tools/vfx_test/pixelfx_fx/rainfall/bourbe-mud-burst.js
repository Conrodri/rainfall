// Rainfall (for an iso camera, drawn in screen space): a ball of Bourbe's mud bursting on the floor at the origin.
// One-shot. The footprint is a 2:1 ellipse (`radius` px across, half that deep): a dark splat whose ragged edge races
// out to the rim, a short lumpy plume of mud thrown up and clods arcing out that fall back onto the footprint, a flash
// of the pale-green wisp at the heart. The ground is y = 0.
import { fit, burst, fly, clamp, smooth, ease, tileNoise, TAU } from "../../core/index.js";

export const meta = {
  name: "Bourbe mud burst",
  desc: "A ball of mud bursts on the floor: a dark 2:1 splat racing out to its rim, a short lumpy plume, clods arcing out and falling back, a wisp-green flash at the heart.",
  tags: ["rainfall", "mud", "burst", "splat", "explosion", "billboard", "one-shot"],
  size: [104, 100],
  origin: [52, 72],
  duration: 0.9,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06100a", "#0f1c14", "#1d3324", "#3a5e42", "#5f9a6c", "#8DDBA8", "#C2F0D2"],
    radius: 36,
    height: 26,
    seed: 12,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, H = o.height, S = o.seed;
  const fade = 1 - smooth(0.6, meta.duration, t);
  // the splat on the floor
  const Rs = R * ease.outCubic(clamp(t / 0.16));
  p.shade(-R - 3, -R / 2 - 3, R + 3, R / 2 + 3, (x, y, out) => {
    const d = Math.hypot(x, y * 2), a = Math.atan2(y * 2, x);
    const e = Rs * (0.82 + 0.18 * tileNoise(Math.cos(a) * 3 + 5, Math.sin(a) * 3, 0, 0, S));
    if (d > e) return;
    const q = d / Math.max(e, 1);
    const n = tileNoise(x / 3, y / 1.5, 0, 0, S + 1);
    if (q > 0.55 && n < -0.2 + q * 0.4) return; // spatter holes towards the edge
    let c = n > 0.35 ? 3 : 2;
    if (q > 0.86 && Math.cos(a + 2.36) > 0) c = 4; // wet lit lip
    out.c = C[c];
    out.a = fade;
    out.k = (c >= 4 ? 0.2 : 0.02) * fade;
    out.l = C[5];
  });
  // the plume: a lumpy column of mud thrown up, then slumping
  const ph = t < 0.12 ? ease.outCubic(t / 0.12) : 1 - ease.inQuad(clamp((t - 0.12) / 0.38));
  if (ph > 0.05) {
    const h = H * ph, w0 = R * 0.38;
    p.shade(-w0 - 3, -h - 4, w0 + 3, 2, (x, y, out) => {
      const hh = -y;
      if (hh < -1 || hh > h) return;
      const u = clamp(hh / Math.max(h, 1));
      const w = w0 * (1 - 0.55 * u) * (0.85 + 0.25 * tileNoise(hh / 3, 2, 0, 0, S + 2));
      if (Math.abs(x) > w) return;
      const s = x / w, n = tileNoise(x / 2, hh / 2, 0, 0, S + 3);
      let c = s < -0.4 ? 4 : n > 0.2 ? 3 : 2;
      if (u > 0.85) c = Math.max(c, 3);
      out.c = C[c];
      out.k = c >= 4 ? 0.2 : 0.02;
      out.l = C[5];
    });
  }
  // clods arcing out and falling back onto the splat
  burst(22, S + 4, (r) => {
    const a = r.range(0, TAU), born = r.range(0, 0.08), age = t - born;
    if (age < 0) return;
    const sp = r.range(0.45, 1) * R * 2.2, up = r.range(70, 140);
    const gx = Math.cos(a), gy = Math.sin(a) * 0.5;
    const tf = (2 * up) / 420; // time back to the floor
    const ta = Math.min(age, tf);
    const [x, yUp] = fly(0, 0, gx * sp, -up, ta, 420);
    const y = yUp + gy * sp * ta;
    if (age < tf) {
      p.disc(x, y, 1.7, () => C[age < 0.1 ? 4 : 3], 1);
      p.light(x, y, C[5], 0.15);
    } else if (fade > 0.05) {
      p.dot(x, y, C[2], fade);
      p.dot(x + 1, y, C[3], fade);
    }
  });
  if (t < 0.2) p.glow(0, -4, R * 0.7, C[5], 0.7 * (1 - t / 0.2));
}
