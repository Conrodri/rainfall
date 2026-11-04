// Rainfall (top-down, for an iso camera): Avare's Saisie, the harpoon chain seen from above. One-shot. A dark iron
// chain with gold glints shoots from the pivot along +x to `length` px, its gold hook bites at the far end, then it reels
// back in to the pivot.
import { fit, clamp, smooth, ease } from "../../core/index.js";

export const meta = {
  name: "Avare grab chain",
  desc: "Seen from above, an iron chain with gold glints shoots out right, its gold hook bites at the far end, then it reels back in.",
  tags: ["rainfall", "chain", "harpoon", "grab", "gold", "top-down", "directional", "one-shot"],
  size: [100, 24],
  origin: [6, 12],
  duration: 0.5,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0e0a04", "#1c1408", "#33260f", "#5c4620", "#8f6e2e", "#F2C14E", "#F8DE92"],
    length: 80,
    seed: 1,
  },
};

const OUT = 0.12, HOLD = 0.1, BACK = 0.2;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), L = o.length;
  const e = ease.outCubic(clamp(t / OUT)), back = ease.inQuad(clamp((t - OUT - HOLD) / BACK));
  const len = L * e * (1 - back);
  if (len < 1) return;
  const taut = t > OUT && t < OUT + HOLD + 0.05 ? 1 : 0;
  // links: alternating flat ovals and edge bars, 6 px each, scrolling back as it reels in
  const scroll = back * L;
  p.shade(0, -4, len, 4, (x, y, out) => {
    const s = x + scroll, cell = ((s % 6) + 6) % 6, flat = Math.floor(s / 6) % 2 === 0;
    if (flat) {
      const dx = (cell - 3) / 3, dy = y / 2.6, d = dx * dx + dy * dy;
      if (d > 1 || d < 0.3) return;
      out.c = C[dx + dy < -0.2 ? 4 : 2];
    } else {
      if (Math.abs(y) > 1 || cell < 0.5 || cell > 5.5) return;
      out.c = C[y < 0 ? 5 : 3];
    }
    out.k = 0.1 + 0.2 * taut;
    out.l = C[5];
  });
  // glints running along the chain
  for (let k = 0; k < 5; k++) {
    const x = (((t * 260 + k * 23) % L) + L) % L;
    if (x < len) p.dot(x, -1, C[6], 0.8);
  }
  // the hook at the head
  const hx = len;
  p.line(hx, 0, hx + 4, 0, C[6]);
  p.line(hx + 4, 0, hx + 1, -4, C[5]);
  p.line(hx + 4, 0, hx + 1, 4, C[5]);
  p.glow(hx + 2, 0, 9, C[5], 0.5 + 0.4 * taut);
  if (taut) p.glow(hx + 2, 0, 16, C[6], 0.5 * (1 - smooth(OUT, OUT + HOLD, t)));
}
