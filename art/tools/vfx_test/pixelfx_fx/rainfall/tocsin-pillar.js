// Rainfall (screen space, for an iso camera): Tocsin's arm planted as a pillar, discharging. Not flat: the floor zone
// is a 2:1 ellipse (`radius` px across, half that tall) whose rim crackles in short bright segments, while jagged arcs
// leap from the pillar's top (`height` px up) down to points on the rim and re-strike every few frames. Sparks spit off
// the tip. Pivot = the foot of the pillar. Loop.
import { fit, cycle, rng, bolt, TAU, clamp } from "../../core/index.js";

export const meta = {
  name: "Tocsin pillar discharge",
  desc: "A planted arm discharging: the floor zone's rim (2:1 ellipse) crackles, jagged arcs leap from the pillar's top to the rim and re-strike, sparks spit off the tip.",
  tags: ["rainfall", "tocsin", "lightning", "electric", "pillar", "zone", "iso", "loop"],
  size: [84, 76],
  origin: [42, 48],
  duration: 0.8,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0d0704", "#1d1108", "#3b2a1a", "#6a4a2a", "#b05a1a", "#FF7A1F", "#ffb06a"],
    radius: 35,
    height: 18,
    arcs: 3,
    seed: 101,
  },
};

const STRIKE = 0.1; // s between re-strikes (8 per loop: seamless)

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, Ry = R / 2, Hh = o.height, S = o.seed, ph = t / meta.duration;
  const slot = Math.floor(t / STRIKE) % Math.round(meta.duration / STRIKE), within = (t % STRIKE) / STRIKE;
  // the rim: a thin dim ellipse, with bright crackling runs that hop around it
  p.shade(-R - 2, -Ry - 2, R + 2, Ry + 2, (x, y, out) => {
    const e = Math.hypot(x / R, y / Ry);
    if (Math.abs(e - 1) > 0.05) {
      if (e < 1 && (Math.floor(x) + Math.floor(y * 2)) % 4 === 0) { out.c = C[2]; out.a = 0.35; }
      return;
    }
    const a = Math.atan2(y / Ry, x / R);
    let hot = 0;
    for (let k = 0; k < 4; k++) {
      const g = rng(S, slot, k), c0 = g.range(0, TAU), w = g.range(0.25, 0.6);
      let d = a - c0;
      d -= Math.round(d / TAU) * TAU;
      if (Math.abs(d) < w) hot = Math.max(hot, 1 - Math.abs(d) / w);
    }
    const lit = Math.cos(a + 2.36);
    out.c = C[hot > 0.5 ? 6 : hot > 0 ? 5 : lit > 0 ? 4 : 3];
    out.k = 0.15 + 0.45 * hot;
    out.l = C[5];
  });
  // arcs from the tip to the rim, re-struck every STRIKE; bright the first frames, then flickering out
  const tipY = -Hh, life = 1 - within;
  for (let k = 0; k < o.arcs; k++) {
    const g = rng(S + 7, slot, k), a = g.range(0, TAU), ex = Math.cos(a) * R, ey = Math.sin(a) * Ry;
    const path = bolt(g, 0, tipY, ex, ey, { jag: 0.25, depth: 4 });
    const c = life > 0.6 ? C[6] : C[5];
    p.polyline(path, c, clamp(life * 1.4));
    for (let i = 0; i < path.length; i += 2) p.light(path[i][0], path[i][1], C[5], 0.35 * life);
    p.glow(ex, ey, 8, C[6], 0.4 * life);
  }
  // the tip: a hot node, pulsing
  p.circle(0, tipY, 2.2, C[6]);
  p.glow(0, tipY, 16, C[6], 0.5 + 0.15 * Math.sin(ph * TAU * 4));
  p.glow(0, 0, R, C[5], 0.12);
  // sparks spitting off the tip
  cycle(t, meta.duration, 10, S + 3, 0.3, (age, life2, r) => {
    const k = age / life2, an = r.range(-Math.PI, 0), sp = r.range(30, 70);
    const x = Math.cos(an) * sp * age, y = tipY + Math.sin(an) * sp * age + 160 * age * age;
    p.dot(x, y, C[k < 0.4 ? 6 : 5], 1 - k);
    p.light(x, y, C[5], 0.3 * (1 - k));
  });
}
