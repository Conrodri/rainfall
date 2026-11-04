// Rainfall (top-down, for an iso camera): the Montreur yanks the thread. Seen from above, a line from the pivot (Rictus)
// to +x (the knife, at `len` px): the thread snaps taut with a flash, a bright knot races back from the knife to the
// hand, the thread rings (a decaying wobble) and sheds glints along its length. One-shot; stretched in x to the real
// distance by the game (line_from_pivot), so it holds no detail that breaks when stretched.
import { fit, burst, fly, clamp, smooth, ease } from "../../core/index.js";

export const meta = {
  name: "Rictus thread yank",
  desc: "Seen from above, a thread from the caster to the knife snaps taut: a flash at the far end, a bright knot racing back to the hand, the thread ringing and shedding glints.",
  tags: ["rainfall", "rictus", "thread", "line", "pull", "top-down", "directional", "one-shot"],
  size: [116, 32],
  origin: [10, 16],
  duration: 0.6,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0a0d0d", "#141b1b", "#26312f", "#46585a", "#6f8f8a", "#9FC8C0", "#c9e3dd"],
    len: 96,
    run: 0.32, // s for the knot to come back
    seed: 31,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), L = o.len, run = o.run;
  const fade = 1 - smooth(run, meta.duration, t);
  const snap = 1 - smooth(0, 0.08, t); // the flash of the snap
  const kx = L * (1 - ease.inCubic(clamp(t / run))); // the knot racing back
  const amp = 3 * Math.exp(-t * 9);
  if (fade <= 0) return;
  // the thread: a taut line, ringing; brighter just behind the knot
  for (let x = 0; x <= L; x++) {
    const u = x / L, y = Math.sin(u * Math.PI * 3 + t * 60) * amp * Math.sin(u * Math.PI);
    const near = Math.max(0, 1 - Math.abs(x - kx) / 18) * (t < run ? 1 : 0);
    const behind = x > kx && t < run;
    const lvl = near > 0.5 ? 6 : near > 0 || snap > 0.3 ? 5 : behind ? 4 : 3;
    p.dot(x, y, C[lvl], (0.55 + 0.45 * Math.max(near, snap)) * fade);
    p.dot(x, y + 1, C[Math.max(2, lvl - 1)], (0.4 + 0.4 * Math.max(near, snap)) * fade);
    if (near > 0 || snap > 0) p.light(x, y, C[5], (0.35 * near + 0.25 * snap) * fade);
  }
  // the knot (the knife's pull) racing home
  if (t < run) {
    p.circle(kx, 0, 2.2, C[6]);
    p.glow(kx, 0, 12, C[5], 0.6);
    p.glowLine(kx, 0, Math.min(L, kx + 26), 0, 4, C[5], 0.25);
  }
  // the snap at the far end
  if (snap > 0) p.glow(L, 0, 12, C[6], 0.7 * snap);
  // the hand catching it
  const c = t - run;
  if (c > 0 && c < 0.2) p.glow(0, 0, 9, C[6], 0.6 * (1 - c / 0.2));
  // glints shed along the thread
  burst(18, o.seed, (r) => {
    const x0 = r.range(0.05, 1) * L, born = run * (1 - x0 / L) * r.range(0.6, 1), a = t - born, life = r.range(0.15, 0.3);
    if (a < 0 || a > life) return;
    const [x, y] = fly(x0, 0, r.range(-20, 10), r.range(-40, 40), a, 0, 8), q = a / life;
    p.dot(x, y, C[q < 0.4 ? 6 : 5], 1 - q);
    p.light(x, y, C[5], 0.3 * (1 - q));
  });
}
