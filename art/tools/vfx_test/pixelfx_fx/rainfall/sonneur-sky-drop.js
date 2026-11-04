// Rainfall (iso camera, drawn in screen space): something dropped out of the sky onto its mark, then the impact.
// The floor is a 2:1 ellipse (the game's 30° camera), heights stand straight up. Timeline: `wait` s of nothing but a
// shadow growing on the floor, `fall` s of falling from `height` px (accelerating, a little from the upper left),
// then the hit at t = wait + fall over a floor ellipse of `radius` px (x) by radius / 2 (y).
// obj: 0 a hex bolt tumbling, 1 a water drop stretched by its speed, 2 an artillery shell with a burning fuse.
// hit: 0 sparks, a shock ring and a scorch; 1 a splash crown, a foam ring and droplets; 2 none (another effect does it).
import { fit, burst, fly, clamp, smooth, ease, TAU } from "../../core/index.js";

export const meta = {
  name: "Sky drop",
  desc: "Iso: a bolt, a drop or a shell falls from high above onto its mark while its shadow grows, then hits: sparks and a shock ring, or a splash crown and foam ring.",
  tags: ["rainfall", "boss", "fall", "impact", "iso", "one-shot"],
  size: [96, 236],
  origin: [48, 212],
  duration: 1.2,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#130c04", "#261808", "#40280c", "#6e4a1a", "#a87626", "#d9982f", "#FFB347", "#ffd58c"],
    wait: 0,
    fall: 0.45,
    height: 180,
    radius: 24,
    obj: 0,
    hit: 0,
    objk: 1, // size of the falling object
    seed: 4,
  },
};

const SQ = 0.5;

export function draw(p, t, o) {
  const C = fit(o.palette, 8), R = o.radius, H = o.height, T0 = o.wait, HIT = o.wait + o.fall, S = o.seed;
  const fromX = -H * 0.18;
  // the shadow growing on the floor until it lands
  if (t < HIT + 0.05) {
    const near = smooth(Math.max(0, T0 - 0.2), HIT, t);
    const r = R * (0.25 + 0.6 * near);
    p.ellipse(0, 0, r, r * SQ, C[0], 0.55 * near);
  }
  if (t >= T0 && t < HIT) {
    const u = ease.inQuad(clamp((t - T0) / o.fall)), x = fromX * (1 - u), y = -H * (1 - u);
    // a streak behind it, along its path
    const sl = 10 + 30 * u;
    const dx = -fromX, dy = H, l = Math.hypot(dx, dy), ux = dx / l, uy = dy / l;
    for (let i = 1; i < sl; i++) p.blend(x - ux * i, y - uy * i, C[o.obj === 1 ? 5 : 4], 0.5 * (1 - i / sl));
    drawObj(p, o.obj, x, y, t, C, o.objk);
    return;
  }
  if (t < HIT || o.hit === 2) return;
  const a = t - HIT;
  if (o.hit === 1) splash(p, a, R, C, S);
  else sparks(p, a, R, C, S);
}

function drawObj(p, obj, x, y, t, C, k = 1) {
  if (obj === 1) {
    // a drop stretched by its speed, lit on its upper left
    p.ellipse(x, y - 3 * k, 2.6 * k, 6 * k, (d, a) => C[d < 0.4 ? 7 : Math.cos(a + 2.36) > 0 ? 6 : 5]);
    p.glow(x, y, 10 * k, C[6], 0.45);
    return;
  }
  if (obj === 2) {
    // a dark shell, nose down, with a fuse burning at its tail
    p.ellipse(x, y, 4 * k, 7 * k, (d, a) => C[d > 0.75 ? (Math.cos(a + 2.36) > 0 ? 4 : 2) : 3]);
    p.dot(x - k, y - 2 * k, C[5]);
    p.glow(x, y - 8 * k, 7 * k, C[7], 0.7);
    p.dot(x, y - 8 * k, C[7]);
    return;
  }
  // a hex bolt tumbling as it falls, its edges catching the light
  const a0 = t * 18;
  const pts = [];
  for (let i = 0; i < 6; i++) pts.push([x + Math.cos(a0 + i * TAU / 6) * 4.5 * k, y + Math.sin(a0 + i * TAU / 6) * 3 * k]);
  p.poly(pts, C[3]);
  p.dot(x, y, C[1]);
  p.line(pts[0][0], pts[0][1], pts[1][0], pts[1][1], C[7]);
  p.glow(x, y, 10 * k, C[6], 0.5);
}

// sparks and a shock ring over the floor ellipse, a scorch that cools
function sparks(p, a, R, C, S) {
  const k = clamp(a / 0.5), ring = R * (0.3 + 0.7 * ease.outCubic(clamp(a / 0.2)));
  if (a < 0.08) p.glow(0, -4, R * 1.1, C[7], 0.9 * (1 - a / 0.08));
  if (k < 1) {
    p.shade(-ring - 1, -ring * SQ - 1, ring + 1, ring * SQ + 1, (x, y, out) => {
      const d = Math.hypot(x / ring, y / (ring * SQ));
      if (d > 1 || d < 0.78) return;
      out.c = C[d > 0.9 ? 7 : 6];
      out.a = 1 - k;
      out.k = 0.5 * (1 - k);
      out.l = C[6];
    });
  }
  const sc = clamp(a / 0.7);
  if (sc < 1) p.ellipse(0, 0, R * 0.55, R * 0.55 * SQ, (d) => C[d < 0.5 && sc < 0.4 ? 5 : 2], (d) => (1 - d * 0.5) * (1 - sc));
  burst(16, S, (r) => {
    const ang = r.range(0, TAU), sp = r.range(40, 110), life = r.range(0.25, 0.5);
    if (a > life) return;
    const [x, y] = fly(0, -2, Math.cos(ang) * sp, Math.sin(ang) * sp * SQ - r.range(40, 90), a, 260, 3), q = a / life;
    p.dot(x, y, C[q < 0.4 ? 7 : 6], 1 - q * q);
    p.light(x, y, C[6], 0.4 * (1 - q));
  });
}

// a splash crown thrown up, a foam ring over the floor ellipse, droplets falling back
function splash(p, a, R, C, S) {
  const k = clamp(a / 0.55), ring = R * (0.3 + 0.75 * ease.outCubic(clamp(a / 0.3)));
  if (a < 0.06) p.glow(0, -3, R, C[6], 0.7 * (1 - a / 0.06));
  if (k < 1) {
    p.shade(-ring - 1, -ring * SQ - 1, ring + 1, ring * SQ + 1, (x, y, out) => {
      const d = Math.hypot(x / ring, y / (ring * SQ));
      if (d > 1 || d < 0.72) return;
      out.c = C[d > 0.88 ? 7 : 5];
      out.a = 1 - k;
      out.k = 0.35 * (1 - k);
      out.l = C[6];
    });
    p.ellipse(0, 0, ring * 0.7, ring * 0.7 * SQ, C[3], 0.35 * (1 - k));
  }
  // the crown: a ring of jets standing up off the rim, then falling
  const ck = clamp(a / 0.35);
  if (ck < 1) {
    for (let i = 0; i < 12; i++) {
      const ang = i * TAU / 12, cx = Math.cos(ang) * R * 0.5, cy = Math.sin(ang) * R * 0.5 * SQ;
      const h = R * 0.7 * Math.sin(ck * Math.PI) * (0.7 + 0.3 * Math.cos(ang * 3));
      p.line(cx, cy, cx * 1.15, cy * 1.15 - h, C[ck < 0.5 ? 7 : 6], 1 - ck);
    }
  }
  burst(14, S + 2, (r) => {
    const ang = r.range(0, TAU), sp = r.range(30, 80), life = r.range(0.35, 0.6);
    if (a > life) return;
    const [x, y] = fly(0, -2, Math.cos(ang) * sp, Math.sin(ang) * sp * SQ - r.range(60, 120), a, 300, 2), q = a / life;
    p.dot(x, y, C[q < 0.5 ? 7 : 6], 1 - q);
  });
}
