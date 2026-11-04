// Rainfall (top-down, for an iso camera): a field of caltrops strewn on the floor, seen from above, as a loop.
import { fit, rng, clamp, TAU, cycle, sparkle } from "../../core/index.js";

export const meta = {
  name: "Caltrop field",
  desc: "Seen from above, iron caltrops strewn over a round patch of floor inside a dashed ring; their points catch the light one after another and glint, the ring creeps round.",
  tags: ["rainfall", "trap", "caltrops", "spikes", "top-down", "ground", "loop"],
  size: [112, 112],
  origin: [56, 56],
  duration: 2,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0c0507", "#1c0a0e", "#35121a", "#6a1b2a", "#B02438", "#FF3A4F", "#FF8C98"],
    radius: 48,
    count: 20,
    seed: 2,
  },
};

const DASHES = 28;

// a caltrop from above: three arms round a raised point, lit from the top left
function caltrop(p, C, x, y, s, rot, glint) {
  for (let i = 0; i < 3; i++) {
    const a = rot + (i * TAU) / 3, ex = x + Math.cos(a) * s, ey = y + Math.sin(a) * s;
    const lit = Math.cos(a + 2.36) > 0.2; // arms pointing up-left catch the light
    p.line(x + 1, y + 1, ex + 1, ey + 1, C[1]); // underside shadow
    p.line(x, y + 1, ex, ey + 1, C[lit ? 4 : 3]);
    p.line(x, y, ex, ey, C[lit ? 5 : 4]);
    p.px(ex, ey, C[lit ? 6 : 5]);
    p.light(ex, ey, C[5], 0.22);
  }
  p.rect(x - 1, y - 1, 2, 2, C[5]);
  p.px(x, y, C[4]);
  p.px(x - 1, y - 1, C[6]);
  p.glow(x, y, 5, C[5], 0.18);
  p.light(x - 1, y - 1, C[6], 0.35 + 0.6 * glint);
}

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, ph = t / meta.duration;
  // a faint warning floor, darker at the rim
  for (let y = -R; y <= R; y++)
    for (let x = -R; x <= R; x++) {
      const d = Math.hypot(x + 0.5, y + 0.5) / (R - 1);
      if (d < 1) p.blend(x, y, C[d > 0.85 ? 2 : 1], 0.22 + 0.2 * d * d);
    }
  // the dashed ring, creeping round one dash per loop
  for (let i = 0; i < DASHES * 4; i++) {
    const u = i / (DASHES * 4), a = (u + ph / DASHES) * TAU;
    if (i % 4 === 3) continue;
    const x = Math.cos(a) * R, y = Math.sin(a) * R;
    p.px(x, y, C[i % 4 === 1 ? 5 : 4]);
    p.px(x * (R - 1) / R, y * (R - 1) / R, C[3]);
    p.light(x, y, C[5], 0.35);
  }
  // the caltrops: spread out evenly-ish (rejecting crowding), each with its own glint time
  const g = rng(o.seed, 77), pts = [];
  for (let tries = 0; pts.length < o.count && tries < 600; tries++) {
    const a = g.range(0, TAU), d = Math.sqrt(g.next()) * (R - 6), x = Math.cos(a) * d, y = Math.sin(a) * d;
    if (pts.some((q) => (q.x - x) ** 2 + (q.y - y) ** 2 < 160)) continue;
    pts.push({ x, y, s: g.range(4, 5.6), rot: g.range(0, TAU), ph: g.next() });
  }
  for (const q of pts) {
    const k = ((ph - q.ph) % 1 + 1) % 1, glint = clamp(1 - Math.abs(k - 0.08) / 0.08);
    caltrop(p, C, q.x, q.y, q.s, q.rot, glint);
    if (glint > 0.05) {
      sparkle(p, q.x - 1, q.y - 1, 1 + 3 * glint, C[6], C[5], 0.5 * glint);
      p.glow(q.x - 1, q.y - 1, 7, C[5], 0.4 * glint);
    }
  }
  // embers of the flare drifting low over the field
  cycle(t, meta.duration, 10, o.seed + 5, 1.2, (age, life, r) => {
    const a = r.range(0, TAU), d = Math.sqrt(r.next()) * (R - 8), q = age / life;
    const x = Math.cos(a) * d + q * r.range(-6, 6), y = Math.sin(a) * d - q * 5;
    p.dot(x, y, C[q < 0.5 ? 6 : 5], q < 0.6 ? 1 : (1 - q) / 0.4);
    p.light(x, y, C[5], 0.3 * (1 - q));
  });
}
