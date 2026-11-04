// Rainfall (top-down, for an iso camera): one tile of a ploughed furrow lying along the floor, seen from above, as a
// loop. Tiles seamlessly along x (exactly `length` px) and in time. Two banks of turned earth, clods lit on their
// upper-left faces, frame a channel: with `mud` 0 it holds still water with glints drifting slowly back; with `mud` 1
// it is a churning tongue of sludge running out towards +x, bubbles swelling and popping. Line along x, width along y.
import { fit, cycle, tileNoise, clamp, wrap, TAU } from "../../core/index.js";

export const meta = {
  name: "Furrow strip",
  desc: "Seen from above, a seamless tile of ploughed furrow: two banks of turned clods framing a channel of still water with glints, or a running tongue of sludge with bubbles.",
  tags: ["rainfall", "mud", "water", "furrow", "trail", "tile", "top-down", "ground_dir", "loop"],
  size: [48, 64],
  origin: [8, 32],
  duration: 1.2,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0a0907", "#1c1812", "#2e271d", "#463b2c", "#5f513e", "#7a6a52", "#5EC8FF", "#A8E6FF"],
    length: 32,
    width: 26,
    mud: 0,
    seed: 9,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), L = o.length, hw = o.width / 2, S = o.seed, ph = t / meta.duration;
  const mud = o.mud > 0.5;
  const flow = mud ? -ph * L : ph * L; // sludge runs out (+x), water creeps back (-x): one tile per loop
  const flowB = 0; // the banks stay put
  p.shade(0, -hw - 1, L, hw + 1, (x, y, out) => {
    if (x < 0 || x >= L) return;
    const ub = wrap(x + flowB, L), u = wrap(x + flow, L);
    const ay = Math.abs(y);
    const e = hw * (0.86 + 0.1 * tileNoise(ub / 6, y > 0 ? 3.5 : 7.5, L / 6, 0, S));
    if (ay > e) return;
    const ch = e * (0.52 + 0.08 * tileNoise(ub / 5, y > 0 ? 1.5 : 5.5, L / 5, 0, S + 3)); // channel half width
    if (ay > ch) {
      // banks: clods of turned earth, lit on the upper side of each clod (light from the top left)
      const n = tileNoise(ub / 3, y / 2.5, L / 3, 0, S + 1);
      const nl = tileNoise((ub - 1) / 3, (y - 1) / 2.5, L / 3, 0, S + 1);
      let c = n > 0.2 ? 4 : n > -0.3 ? 3 : 2;
      if (n - nl > 0.18) c = 5; // the lit face of a clod (earth tones stay below the accent)
      if (ay > e - 1.2 && n < 0) return; // crumbly outer edge
      out.c = C[c];
      return;
    }
    const q = ay / ch;
    if (mud) {
      // churning sludge, a lit wet sheen streaking along the flow
      const n = tileNoise(u / 6, y / 3, L / 6, 0, S + 4) + 0.5 * tileNoise(u / 3, y / 1.5, L / 3, 0, S + 5);
      let c = n > 0.45 ? 5 : n > -0.2 ? 4 : 3;
      if (Math.abs(Math.sin(y * 0.9 + 0.7)) > 0.95 && n > 0.2) c = y < 0 ? 7 : 6;
      out.c = C[c];
      out.k = c >= 6 ? 0.3 : 0.03;
      out.l = C[6];
      return;
    }
    // still water: dark, lit rim along the upper bank, faint streaks
    const n = tileNoise(u / 8, y / 3, L / 8, 0, S + 6);
    let c = q > 0.8 && y < 0 ? 7 : n > 0.35 ? 6 : 3;
    out.c = C[c];
    out.k = c === 7 ? 0.4 : c === 6 ? 0.2 : 0.04;
    out.l = C[6];
  });
  if (mud) {
    // bubbles that swell and pop in the sludge
    cycle(t, meta.duration, 4, S + 7, (g) => g.range(0.3, 0.6), (age, life, r) => {
      const x = wrap(r.range(0, L) - ph * L, L), y = r.range(-0.4, 0.4) * hw, k = age / life;
      if (x < 4 || x > L - 4) return; // stays inside the tile: the strip keeps its exact length
      if (k < 0.8) p.circle(x, y, 0.8 + 1.4 * k, (d) => C[d > 0.6 ? 5 : 4]);
      else {
        p.ring(x, y, 2.6, 1, C[6]);
        p.light(x, y, C[6], 0.35);
      }
    });
  } else {
    // glints on the water, drifting with it
    for (let i = 0; i < 2; i++) {
      const x = wrap(i * (L / 2) + 6 - flow, L), y = (i ? 0.25 : -0.3) * hw;
      p.px(x, y, C[7]);
      p.light(x, y, C[6], 0.4);
    }
  }
}
