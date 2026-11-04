// Rainfall (top-down, for an iso camera): a prayer glyph burning on the floor, seen from above, as a loop. A circle of
// `radius` px with an inner ring, six rune strokes turning slowly between them, a cross of light at the heart and a
// faint fill that breathes: the mark where a column of light will strike.
import { fit, clamp, TAU } from "../../core/index.js";

export const meta = {
  name: "Prayer glyph",
  desc: "Seen from above, a prayer glyph burning on the floor: a circle and an inner ring, six rune strokes turning between them, a cross of light at its heart.",
  tags: ["rainfall", "boss", "glyph", "circle", "holy", "top-down", "ground", "loop"],
  size: [56, 56],
  origin: [28, 28],
  duration: 1.2,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06090d", "#0b1219", "#16222c", "#34505e", "#6f98a8", "#8fc8d8", "#BFF4FF", "#dff9ff"],
    radius: 24,
    seed: 2,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), R = o.radius, ph = t / meta.duration, br = 0.5 + 0.5 * Math.sin(ph * TAU);
  const rot = ph * TAU / 6; // a sixth of a turn per loop: six identical strokes, so it loops cleanly
  p.shade(-R - 1, -R - 1, R + 1, R + 1, (x, y, out) => {
    const r = Math.hypot(x, y), a = Math.atan2(y, x);
    if (r > R + 0.5) return;
    const lit = Math.cos(a + 2.36) > 0;
    if (r > R - 2) {
      out.c = C[lit ? 7 : 6];
      out.k = 0.4 + 0.2 * br;
      out.l = C[6];
      return;
    }
    if (Math.abs(r - R * 0.62) < 1) {
      out.c = C[lit ? 6 : 5];
      out.k = 0.25;
      out.l = C[5];
      return;
    }
    // rune strokes: short radial bars with a hook, between the two rings
    const sa = ((a - rot) / TAU * 6 % 1 + 1) % 1;
    if (r > R * 0.66 && r < R - 3 && (Math.abs(sa - 0.5) < 0.05 || (Math.abs(sa - 0.58) < 0.05 && r > R * 0.82))) {
      out.c = C[6];
      out.k = 0.3 + 0.2 * br;
      out.l = C[6];
      return;
    }
    // the cross at the heart
    if (r < R * 0.5 && (Math.abs(x) < 1 || Math.abs(y) < 1)) {
      out.c = C[r < R * 0.2 ? 7 : 6];
      out.k = 0.3;
      out.l = C[6];
      return;
    }
    out.c = C[3];
    out.a = (0.18 + 0.12 * br) * clamp(r / R + 0.3);
  });
  p.glow(0, 0, R * 0.7, C[6], 0.15 + 0.15 * br);
}
