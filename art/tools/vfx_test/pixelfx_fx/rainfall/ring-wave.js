// Rainfall (top-down, for an iso camera): a shock ring racing out across the floor, seen from above. One-shot. A bright
// leading band runs from `r0` to `r1` px, a fainter echo follows it, dust and glints are kicked off its edge.
import { fit, burst, fly, clamp, smooth, ease, noise2, TAU } from "../../core/index.js";

export const meta = {
  name: "Ring wave",
  desc: "Seen from above, a shock ring races out across the floor: a bright leading band lit from the upper left, a fainter echo behind it, dust and glints kicked off its edge.",
  tags: ["rainfall", "shockwave", "ring", "nova", "sound", "top-down", "ground", "one-shot"],
  size: [208, 208],
  origin: [104, 104],
  duration: 1.2,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06090d", "#0b1219", "#16222c", "#34505e", "#6f98a8", "#8fc8d8", "#BFF4FF", "#dff9ff"],
    r0: 8,
    r1: 88,
    run: 0.8, // s to reach r1
    band: 10, // px, width of the bright band
    echo: 0.55, // strength of the trailing echo ring
    seed: 5,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), S = o.seed, B = o.band, run = o.run;
  const front = (tt) => o.r0 + (o.r1 - o.r0) * ease.outCubic(clamp(tt / run));
  const R = front(t), fade = 1 - smooth(run * 0.75, meta.duration, t);
  const Re = front(t - 0.16), fadeE = o.echo * (1 - smooth(run * 0.6, meta.duration * 0.9, t));
  if (fade <= 0) return;
  const ext = R + 3;
  p.shade(-ext, -ext, ext, ext, (x, y, out) => {
    const r = Math.hypot(x, y), a = Math.atan2(y, x);
    const lit = Math.cos(a + 2.36); // upper left lit, lower right in shade
    const jit = noise2(Math.cos(a) * 3 + t * 2, Math.sin(a) * 3, S) * 1.5;
    const d = R - r + jit; // 0 at the leading edge, growing inwards
    if (d >= -1 && d < B) {
      const q = Math.max(0, d) / B, thin = 1 - smooth(0.4, 1, q);
      let c = q < 0.18 ? 7 : q < 0.45 ? 6 : q < 0.75 ? 5 : 4;
      if (lit < -0.4 && c > 4) c -= 1;
      if (fade < 0.5) c = Math.max(3, c - Math.round((0.5 - fade) * 6));
      if (thin * fade < 0.25 && q > 0.3) return;
      out.c = C[c];
      out.k = (q < 0.45 ? 0.55 : 0.2) * fade;
      out.l = C[6];
      return;
    }
    const de = Re - r + jit;
    if (fadeE > 0.02 && de >= 0 && de < B * 0.6) {
      const q = de / (B * 0.6);
      if (fadeE * (1 - q) < 0.22) return;
      out.c = C[q < 0.3 ? 5 : 4];
      out.k = 0.25 * fadeE;
      out.l = C[5];
      return;
    }
  });
  // dust and glints kicked outward off the edge
  burst(34, S + 3, (r) => {
    const a = r.range(0, TAU), born = r.range(0.02, run * 0.8), age = t - born, life = r.range(0.25, 0.5);
    if (age < 0 || age > life) return;
    const r0 = front(born), sp = r.range(30, 70);
    const [x, y] = fly(Math.cos(a) * r0, Math.sin(a) * r0, Math.cos(a) * sp, Math.sin(a) * sp, age, 0, 5), k = age / life;
    p.dot(x, y, C[k < 0.35 ? 7 : k < 0.7 ? 6 : 5], k < 0.6 ? 1 : (1 - k) / 0.4);
    p.light(x, y, C[6], 0.35 * (1 - k));
  });
  // the flash where it started
  p.glow(0, 0, o.r0 * 3, C[6], 0.7 * (1 - smooth(0, 0.25, t)));
}
