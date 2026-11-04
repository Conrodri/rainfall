// Rainfall (top-down, for an iso camera): Vigie's weighted net opening over a round patch of floor, seen from above.
// The bundle bursts at the centre, the mesh flings out to its full radius (radial cords, concentric rings, lead
// weights on the rim), snaps flat with a jolt, holds its catch, then slackens and fades.
import { fit, burst, fly, clamp, smooth, ease, TAU } from "../../core/index.js";

export const meta = {
  name: "Vigie weighted net",
  desc: "Seen from above, a rope net bursts open to a full circle (cords, rings of mesh, lead weights on the rim), snaps flat, holds taut, then slackens and fades.",
  tags: ["rainfall", "net", "snare", "root", "top-down", "ground", "one-shot"],
  size: [128, 128],
  origin: [64, 64],
  duration: 1.8,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0c0507", "#1c0a0e", "#35121a", "#6a1b2a", "#B02438", "#FF3A4F", "#FF8C98"],
    radius: 48, // px (16 px per game unit) : 3 u
    cords: 14,
    rings: 4,
    seed: 6,
  },
};

const OPEN = 0.16, HOLD = 1.5;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R0 = o.radius, N = o.cords, M = o.rings;
  const k = ease.outBack(clamp(t / OPEN), 1.2); // flung out, overshoots a hair and snaps back
  const R = R0 * k;
  const fade = smooth(HOLD, meta.duration, t), live = 1 - fade;
  const jolt = t > OPEN && t < OPEN + 0.08 ? 1 : 0;
  if (R < 1 || live <= 0.01) return;
  // the shadow of the net on the floor (very faint), so the catch area reads
  p.shade(-R, -R, R, R, (x, y, out) => {
    const d = Math.hypot(x, y) / R;
    if (d > 1 || ((Math.floor(x) + Math.floor(y)) & 1)) return;
    out.c = C[2];
    out.a = 0.22 * live;
  });
  // wobble: the cords sag between knots while slack, taut during the hold
  const sag = (1 - smooth(OPEN, OPEN + 0.12, t)) * 2.5 + fade * 2;
  const pt = (i, r) => {
    const a = (i / N) * TAU + 0.12;
    const s = Math.sin(i * 2.3 + r * 0.2) * sag * (r / R0);
    return [Math.cos(a) * r - Math.sin(a) * s, Math.sin(a) * r + Math.cos(a) * s];
  };
  // radial cords
  for (let i = 0; i < N; i++) {
    let [px, py] = pt(i, 3);
    for (let j = 1; j <= 8; j++) {
      const [qx, qy] = pt(i, 3 + ((R - 3) * j) / 8);
      p.line(px, py, qx, qy, C[jolt ? 6 : 4], live);
      [px, py] = [qx, qy];
    }
  }
  // concentric rings of mesh, joined knot to knot (polygonal: rope, not a drawn circle)
  for (let m = 1; m <= M; m++) {
    const r = (R * m) / M;
    for (let i = 0; i < N; i++) {
      const [ax, ay] = pt(i, r), [bx, by] = pt((i + 1) % N, r);
      p.line(ax, ay, bx, by, C[m === M ? 5 : 4], live * (m === M ? 1 : 0.9));
      if (m < M) p.px(ax, ay, C[5]);
    }
  }
  // red tie-ribbons on alternate knots of the middle ring: the only accent on the rope
  for (let i = 0; i < N; i += 2) {
    const [x, y] = pt(i, (R * 2) / M);
    p.px(x, y, C[6]);
    p.light(x, y, C[5], 0.45 * live);
  }
  // lead weights round the rim
  for (let i = 0; i < N; i++) {
    const [x, y] = pt(i, R + 1.5);
    p.disc(x, y, 1.8, C[2], live);
    p.px(x - 1, y - 1, C[6]);
  }
  // the burst at the centre, and a pulse of light round the rim when it snaps flat
  if (t < OPEN + 0.1) p.glow(0, 0, 20, C[5], 0.7 * (1 - t / (OPEN + 0.1)));
  if (jolt || (t > OPEN && t < OPEN + 0.2)) p.glowRing(0, 0, R, 6, C[5], 0.4 * (1 - (t - OPEN) / 0.2));
  p.glowRing(0, 0, R * 0.55, 10, C[4], 0.08 * live);
  // dust kicked up by the weights when they land
  burst(18, o.seed, (r) => {
    const a = r.range(0, TAU), age2 = t - OPEN * 0.9, life = r.range(0.2, 0.4);
    if (age2 < 0 || age2 > life) return;
    const q = age2 / life, [x, y] = fly(Math.cos(a) * R0, Math.sin(a) * R0, Math.cos(a) * r.range(10, 40), Math.sin(a) * r.range(10, 40), age2, 0, 6);
    p.dot(x, y, C[q < 0.4 ? 4 : 3], 0.8 * (1 - q));
  });
}
