// Rainfall (top-down, for an iso camera): Bourbe's Recall, seen from above. One-shot. Streaks of mud rush in from all
// round (from `radius` px) towards the origin along the floor, a ring of churned mud closes on her, then everything
// rejoins her in a heavy splash at the centre (a short ring of spatter going out) with a wisp-green flash.
import { fit, burst, clamp, smooth, ease, tileNoise, TAU } from "../../core/index.js";

export const meta = {
  name: "Bourbe recall",
  desc: "Seen from above, mud rushes in from all round to the centre: converging streaks, a closing ring of churned mud, then a heavy splash at the heart with a wisp-green flash.",
  tags: ["rainfall", "mud", "recall", "implode", "converge", "top-down", "ground", "one-shot"],
  size: [168, 168],
  origin: [84, 84],
  duration: 0.9,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06100a", "#0f1c14", "#1d3324", "#3a5e42", "#5f9a6c", "#8DDBA8", "#C2F0D2"],
    radius: 72,
    run: 0.5,
    seed: 27,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, RUN = o.run, S = o.seed;
  // the closing ring
  const Rr = R * (1 - ease.inQuad(clamp(t / RUN)));
  const kr = smooth(0, 0.08, t) * (1 - smooth(RUN * 0.8, RUN, t));
  if (kr > 0.02 && Rr > 3) {
    p.shade(-Rr - 4, -Rr - 4, Rr + 4, Rr + 4, (x, y, out) => {
      const r = Math.hypot(x, y), d = r - Rr;
      if (d < -5 || d > 1.5) return;
      const n = tileNoise(x / 4, y / 4, 0, 0, S);
      if (n < -0.4 + (1 - kr) * 1.2) return;
      const a = Math.atan2(y, x), lit = Math.cos(a + 2.36);
      out.c = C[d > -1.5 ? (lit > 0 ? 4 : 3) : 2];
      out.k = d > -1.5 ? 0.25 * kr : 0.02;
      out.l = C[5];
    });
  }
  // streaks rushing in along the floor, each a short tapered smear of mud pointing at the centre
  burst(18, S + 1, (r) => {
    const a = r.range(0, TAU), r0 = R * r.range(0.6, 1), born = r.range(0, 0.12);
    const u = clamp((t - born) / (RUN - born));
    if (t < born || u >= 1) return;
    const rh = r0 * (1 - ease.inQuad(u)), len = 10 + 10 * u;
    const cx = Math.cos(a), cy = Math.sin(a);
    for (let s = 0; s < len; s += 1) {
      const rr = rh + s, w = 2.2 * (1 - s / len);
      const x = cx * rr, y = cy * rr;
      p.disc(x, y, w, () => C[s < 2 ? 4 : s < len * 0.5 ? 3 : 2], s < len * 0.7 ? 1 : 0.6);
    }
    p.light(cx * rh, cy * rh, C[5], 0.3);
  });
  // the rejoining splash
  const ts = t - RUN;
  if (ts > 0) {
    const k = clamp(ts / (meta.duration - RUN)), rs = 6 + 20 * ease.outCubic(k);
    p.shade(-rs - 2, -rs - 2, rs + 2, rs + 2, (x, y, out) => {
      const r = Math.hypot(x, y);
      if (r > rs) return;
      const n = tileNoise(x / 3, y / 3, 0, 0, S + 3);
      const q = r / rs;
      if (q > 0.7 && n < -0.2 + q * 0.6 + k * 0.6) return;
      if (q < 0.7 && n < -0.6 + k * 1.6) return;
      out.c = C[q > 0.75 ? 4 : n > 0.3 ? 3 : 2];
      out.a = 1 - k;
      out.k = q > 0.75 ? 0.25 * (1 - k) : 0.02;
      out.l = C[5];
    });
    p.glow(0, 0, 26, C[5], 0.7 * (1 - k));
  }
}
