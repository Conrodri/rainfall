// Rainfall (top-down, for an iso camera): the shadow of a crane's boom raking the floor, seen from above, as a loop.
// Drawn from the origin (the crane) to `length` px towards +x, `width` px wide: a hard dark band with lit edges,
// rivet glints running along it, and grit and sparks scraped off both edges as it sweeps.
import { fit, cycle, fly, clamp, noise, TAU } from "../../core/index.js";

export const meta = {
  name: "Crane boom sweep",
  desc: "Seen from above, a crane boom's shadow rakes the floor: a hard dark band with lit edges, rivet glints running along it, grit and sparks scraped off its edges.",
  tags: ["rainfall", "boss", "sweep", "beam", "shadow", "top-down", "directional", "loop"],
  size: [236, 48],
  origin: [8, 24],
  duration: 0.8,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#120804", "#241008", "#3c1c0e", "#6a3a1e", "#a0602e", "#d98038", "#FF9A3C", "#ffc684"],
    length: 210,
    width: 22,
    seed: 6,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), L = o.length, hw = o.width / 2, ph = t / meta.duration, S = o.seed;
  p.shade(0, -hw - 2, L, hw + 2, (x, y, out) => {
    const tip = clamp((L - x) / 6), ay = Math.abs(y);
    const half = hw * (0.85 + 0.15 * tip) + Math.sin((x / 30 - ph) * TAU) * 0.5;
    if (ay > half + 1) return;
    if (ay > half - 1.6) {
      // lit edges: the floor caught where the shadow ends, brighter on the upper (lit) side
      const run = 0.5 + 0.5 * Math.sin((x / 18 - ph * 3) * TAU);
      out.c = C[y < 0 ? (run > 0.6 ? 7 : 6) : 5];
      out.k = 0.4 * (y < 0 ? 1 : 0.6);
      out.l = C[6];
      return;
    }
    // the shadow: hard, dark, with the lattice of the boom showing through as slightly lighter struts
    const strut = Math.abs(((x + ay * 1.4) % 26) - 13) < 1.2 || Math.abs(((x - ay * 1.4 + 300) % 26) - 13) < 1.2;
    out.c = C[strut ? 2 : ay < half * 0.35 ? 0 : 1];
    out.a = 0.85;
  });
  // rivet glints running out along the boom
  for (let i = 0; i < 4; i++) {
    const gx = ((i + ph) % 1) * L;
    p.glow(gx, -hw * 0.4, 6, C[6], 0.45 * clamp((L - gx) / 20));
    p.dot(gx, -hw * 0.4, C[7], 1);
  }
  // grit and sparks scraped off both edges
  cycle(t, meta.duration, 16, S, 0.35, (age, life, r) => {
    const k = age / life, side = r.next() < 0.5 ? -1 : 1, x0 = r.range(10, L - 6);
    const [x, y] = fly(x0, side * hw, r.range(-20, 20), side * r.range(30, 70), age, 0, 6);
    if (r.next() < 0.5) {
      p.dot(x, y, C[k < 0.4 ? 7 : 6], 1 - k);
      p.light(x, y, C[6], 0.4 * (1 - k));
    } else p.disc(x, y, 1.5 + 2 * k, () => C[3], (d) => (1 - d) * 0.5 * (1 - k));
  });
  p.glow(0, 0, 14, C[5], 0.5 + 0.1 * noise(t * 8, S));
}
