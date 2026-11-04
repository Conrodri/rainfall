// Rainfall (top-down, for an iso camera): Avare's Coffre-bélier seen from above. One-shot. The strongbox rams straight
// out along +x for `length` px: a gold wake `width` px wide streaked by speed lines, the box at its head, and at the
// end of the line a forward shock (chevrons and grit) that throws what it hits back.
import { fit, clamp, smooth, ease, burst, fly } from "../../core/index.js";

export const meta = {
  name: "Avare ram line",
  desc: "Seen from above, a strongbox rams straight ahead: a gold wake streaked with speed lines, the box at its head, a forward shock of chevrons and grit at the end of the line.",
  tags: ["rainfall", "melee", "ram", "line", "chest", "gold", "top-down", "directional", "one-shot"],
  size: [112, 48],
  origin: [12, 24],
  duration: 0.5,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0e0a04", "#1c1408", "#33260f", "#5c4620", "#8f6e2e", "#F2C14E", "#F8DE92"],
    length: 56,
    width: 22,
    seed: 7,
  },
};

const RUN = 0.12;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), L = o.length, Wh = o.width / 2, S = o.seed;
  const hx = L * ease.outCubic(clamp(t / RUN)), fade = 1 - smooth(RUN, meta.duration * 0.85, t);
  // the wake: a band from the start to the head, narrowing behind, laced with speed lines
  if (fade > 0.02) {
    p.shade(0, -Wh - 1, hx, Wh + 1, (x, y, out) => {
      const u = x / Math.max(1, hx), hw = Wh * (0.45 + 0.55 * u);
      const ay = Math.abs(y);
      if (ay > hw) return;
      const q = ay / hw;
      const streak = Math.sin(y * 1.9 + 1.3) > 0.75 && ((x + y * 3 + t * 300) % 11) < 7;
      if (q > 0.85) {
        out.c = C[y < 0 ? 5 : 4];
        out.a = fade * (0.5 + 0.5 * u);
        out.k = 0.2 * fade;
        out.l = C[5];
        return;
      }
      if (streak) {
        out.c = C[u > 0.6 ? 6 : 5];
        out.a = fade;
        out.k = 0.3 * fade * u;
        out.l = C[5];
        return;
      }
      out.c = C[2];
      out.a = 0.45 * fade * (0.4 + 0.6 * u);
      out.k = 0.08 * fade * u;
      out.l = C[4];
    });
  }
  // the box at the head
  const show = 1 - smooth(RUN + 0.05, RUN + 0.2, t), w = Wh * 0.62;
  if (show > 0.02) {
    p.shade(hx - w * 1.6, -w, hx + 1, w, (x, y, out) => {
      const u = hx - x;
      if (u < 0 || u > w * 1.5 || Math.abs(y) > w) return;
      const band = u < 1.6 || u > w * 1.5 - 1.6 || Math.abs(y) > w - 1.4 || Math.abs(u - w * 0.75) < 0.9;
      out.c = C[band ? (y < 0 || u < 1.6 ? 6 : 5) : y < 0 ? 2 : 1];
      out.a = show;
      out.k = band ? 0.35 * show : 0;
      out.l = C[5];
    });
    p.glow(hx, 0, Wh * 1.4, C[5], 0.5 * show);
  }
  // the shock at the end of the line: chevrons racing forward, grit thrown ahead
  const g = t - RUN * 0.8;
  if (g > 0 && g < 0.3) {
    const q = g / 0.3;
    for (let k = 0; k < 3; k++) {
      const x = L + 2 + k * 4 + q * 10, hw = Wh * (0.9 - k * 0.2);
      p.line(x - 5, -hw, x, 0, C[k === 0 ? 6 : 5], 1 - q);
      p.line(x - 5, hw, x, 0, C[k === 0 ? 6 : 5], 1 - q);
    }
    p.glow(L, 0, Wh * 1.6, C[6], 0.7 * (1 - q));
  }
  burst(16, S, (r) => {
    const born = RUN * r.range(0.7, 1.1), age = t - born, life = r.range(0.18, 0.3);
    if (age < 0 || age > life) return;
    const a = r.range(-0.7, 0.7), sp = r.range(60, 130), [x, y] = fly(L, r.range(-Wh, Wh) * 0.6, Math.cos(a) * sp, Math.sin(a) * sp, age, 0, 6), k = age / life;
    p.dot(x, y, C[r.next() < 0.4 ? (k < 0.5 ? 6 : 5) : 3], 1 - k);
    p.light(x, y, C[5], 0.3 * (1 - k));
  });
}
