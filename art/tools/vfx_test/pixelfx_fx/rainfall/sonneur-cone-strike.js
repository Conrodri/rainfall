// Rainfall (top-down, for an iso camera): a boss's melee blow over a cone in front of it, seen from above. One-shot.
// The cone starts at the origin (the boss) and opens towards +x with a half angle `half` (radians) and a reach of
// `radius` px: a flash at the origin, the cone's two edges and a pale wash light up, a bright front races out to the
// reach, then the style's own mark: 0 slam (glowing cracks, dust and chips), 1 sweep (a smear swept edge to edge),
// 2 spray (molten gobs flung out that land and cool), 3 bite (two jaws snapping shut from the edges).
import { fit, burst, fly, clamp, smooth, ease, noise, noise2 } from "../../core/index.js";

export const meta = {
  name: "Cone strike",
  desc: "Seen from above, a heavy blow over a cone: edges and wash light up, a front races to its reach, then cracks, a swept smear, flung molten gobs or snapping jaws.",
  tags: ["rainfall", "melee", "cone", "boss", "top-down", "directional", "one-shot"],
  size: [100, 170],
  origin: [6, 85],
  duration: 0.7,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#130c04", "#261808", "#40280c", "#6e4a1a", "#a87626", "#d9982f", "#FFB347", "#ffd58c"],
    radius: 80, // px reach
    half: 0.785, // half angle (radians)
    style: 0, // 0 slam, 1 sweep, 2 spray, 3 bite
    run: 0.14, // s for the front to reach the radius
    seed: 4,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), R = o.radius, A = o.half, S = o.seed, RUN = o.run, D = meta.duration;
  const front = R * (0.12 + 0.88 * ease.outCubic(clamp(t / RUN)));
  const fade = 1 - smooth(RUN + 0.1, D, t);
  const inCone = (a) => Math.abs(a) <= A;
  if (fade <= 0) return;
  // the wash over the struck cone and its bright front, lit from the top left
  p.shade(0, -R - 2, R + 2, R + 2, (x, y, out) => {
    const r = Math.hypot(x, y), a = Math.atan2(y, x);
    if (r > front + 1 || r < 2 || !inCone(a)) return;
    const ea = Math.abs(a) / A, jit = noise2(x * 0.15, y * 0.15, S) * 2;
    const d = front - r + jit; // 0 at the front, growing inwards
    const band = (3 + R * 0.06) * (o.style === 0 ? 1 : 0.55);
    if (d < band && t < RUN + 0.25) {
      const q = Math.max(0, d) / band, k = (1 - smooth(RUN, RUN + 0.25, t)) * (o.style === 0 ? 1 : 0.7);
      let c = q < 0.25 ? 7 : q < 0.6 ? 6 : 5;
      if (Math.sin(a) > 0.3 && c > 5) c -= 1;
      if (k * (1 - q * 0.6) < 0.3) return;
      out.c = C[c];
      out.k = 0.55 * k;
      out.l = C[6];
      return;
    }
    // the cone's edges: thin lit lines that show where the blow reached
    if (ea > 0.94 && r < R) {
      if (fade * (1 - smooth(0.25, 0.6, t)) < 0.25) return;
      out.c = C[5];
      out.k = 0.25 * fade;
      out.l = C[5];
      return;
    }
    const wash = 0.35 * fade * (1 - smooth(0, 0.55, t)) * (0.4 + 0.6 * r / R);
    if (wash < 0.04) return;
    p.blend(x, y, C[r > R * 0.55 ? 4 : 3], wash);
    p.light(x, y, C[5], wash * 0.25);
  });
  // flash at the origin
  p.glow(R * 0.12, 0, R * 0.35, C[6], 0.7 * (1 - smooth(0, 0.18, t)));
  if (o.style === 0) slam(p, t, o, C, front, fade);
  else if (o.style === 1) sweep(p, t, o, C, fade);
  else if (o.style === 2) spray(p, t, o, C, fade);
  else bite(p, t, o, C, fade);
}

// glowing cracks branching out along the cone, dust thrown off the front, chips
function slam(p, t, o, C, front, fade) {
  const R = o.radius, A = o.half, S = o.seed;
  const n = 5 + Math.round(A * 3);
  for (let i = 0; i < n; i++) {
    const a0 = -A * 0.85 + (2 * A * 0.85) * (i + 0.5) / n + (noise(i * 3.1, S) * 0.25) * A / n;
    const len = R * (0.55 + 0.35 * (0.5 + 0.5 * noise(i * 1.7, S + 1)));
    const reach = Math.min(len, front - 2);
    let x = R * 0.14 * Math.cos(a0), y = R * 0.14 * Math.sin(a0), a = a0;
    const cool = smooth(0.15, 0.65, t);
    for (let s = 0; s < 14; s++) {
      const r = Math.hypot(x, y);
      if (r >= reach) break;
      const step = R * 0.06;
      a = a0 + noise(s * 0.9 + i * 5, S + 2) * 0.6 + (s % 2 ? 0.18 : -0.18) * noise(i, S + 7);
      const nx = x + Math.cos(a) * step, ny = y + Math.sin(a) * step;
      const c = cool < 0.3 ? 7 : cool < 0.7 ? 6 : 4;
      p.line(x, y, nx, ny, C[c], fade);
      p.light(x, y, C[6], 0.35 * fade * (1 - cool));
      x = nx, y = ny;
    }
  }
  // dust puffs riding the front
  burst(18, S + 5, (r) => {
    const a = r.range(-A, A) * 0.95, born = r.range(0.04, 0.16), age = t - born, life = r.range(0.25, 0.45);
    if (age < 0 || age > life) return;
    const rr = R * r.range(0.75, 1.0), k = age / life;
    const [x, y] = fly(Math.cos(a) * rr, Math.sin(a) * rr, Math.cos(a) * 30, Math.sin(a) * 30, age, 0, 6);
    p.disc(x, y, 2 + 4 * k, () => C[k < 0.3 ? 4 : 3], (d) => (1 - d) * 0.45 * (1 - k));
  });
  chips(p, t, o, C, 16);
}

// a smear swept from one edge of the cone to the other at the reach, tapering behind the head
function sweep(p, t, o, C, fade) {
  const R = o.radius, A = o.half, SW = 0.16, TR = 0.25;
  const head = -A + 2 * A * ease.outCubic(clamp((t - 0.02) / SW));
  const tail = -A + 2 * A * smooth(SW, SW + TR, t);
  if (head > tail + 0.02) {
    p.arc(0, 0, R, (u) => 3 + R * 0.16 * Math.pow(u, 0.8), tail, head,
      (u, v) => C[v > 0.82 && t < 0.3 ? 7 : u > 0.6 ? 6 : 5],
      (u) => (0.35 + 0.65 * u) * fade);
    p.arc(0, 0, R * 0.7, 2, tail + 0.1, head, () => C[5], (u) => u * 0.6 * fade);
    p.glow(Math.cos(head) * R * 0.9, Math.sin(head) * R * 0.9, R * 0.3, C[6], 0.5 * fade);
  }
  chips(p, t, o, C, 10);
}

// molten gobs flung over the cone, landing as glowing spots that crust over
function spray(p, t, o, C, fade) {
  const R = o.radius, A = o.half, S = o.seed;
  burst(26, S + 9, (r) => {
    const a = r.range(-A, A) * 0.92, dist = R * r.range(0.35, 1.0), born = r.range(0, 0.08), fl = 0.1 + 0.18 * dist / R;
    const age = t - born;
    if (age < 0) return;
    const u = clamp(age / fl), x = Math.cos(a) * dist * ease.outQuad(u), y = Math.sin(a) * dist * ease.outQuad(u);
    if (u < 1) {
      p.disc(x, y, 1.8, () => C[7], 1);
      p.light(x, y, C[6], 0.6);
      return;
    }
    const k = smooth(0, 0.45, age - fl), rad = 2 + 2.5 * r.next();
    if (k >= 1) return;
    p.disc(x, y, rad, (d) => C[d < 0.4 ? (k < 0.4 ? 7 : 5) : k < 0.5 ? 5 : 3], (d) => (1 - d * 0.4) * (1 - k * 0.7) * fade);
    p.light(x, y, C[6], 0.35 * (1 - k));
  });
}

// two jaws snapping shut from the cone's edges onto its axis, a flash where they meet
function bite(p, t, o, C, fade) {
  const R = o.radius, A = o.half, SN = 0.13;
  const k = ease.inQuad(clamp((t - 0.03) / SN)), open = A * (1 - k);
  const rr = R * 0.9;
  for (const s of [-1, 1]) {
    const a1 = s * open, a0 = s * A;
    const lo = Math.min(a0, a1), hi = Math.max(a0, a1) + 0.001;
    p.arc(0, 0, rr, (u) => 3 + R * 0.2 * (s < 0 ? u : 1 - u), lo, hi,
      (u, v) => C[v > 0.75 ? 7 : v > 0.4 ? 5 : 3], () => fade * (t < SN + 0.25 ? 1 : 0.5));
    // fangs along the jaw
    for (let i = 1; i <= 3; i++) {
      const fa = a0 + (a1 - a0) * (i / 4);
      p.line(Math.cos(fa) * rr * 0.92, Math.sin(fa) * rr * 0.92, Math.cos(fa) * rr * 0.72, Math.sin(fa) * rr * 0.72, C[6], fade);
    }
  }
  const snap = t - 0.03 - SN;
  if (snap > 0 && snap < 0.25) {
    p.glow(rr * 0.85, 0, R * 0.35, C[7], 0.8 * (1 - snap / 0.25));
    p.line(rr * 0.55, 0, rr, 0, C[7], 1 - snap / 0.25);
  }
  chips(p, t, o, C, 12);
}

// sparks and chips thrown out of the cone by the blow
function chips(p, t, o, C, n) {
  const R = o.radius, A = o.half;
  burst(n, o.seed + 3, (r) => {
    const a = r.range(-A, A) * 0.9, born = r.range(0.05, 0.18), age = t - born, life = r.range(0.2, 0.4);
    if (age < 0 || age > life) return;
    const r0 = R * r.range(0.5, 0.95), sp = r.range(40, 110), k = age / life;
    const [x, y] = fly(Math.cos(a) * r0, Math.sin(a) * r0, Math.cos(a) * sp, Math.sin(a) * sp, age, 0, 6);
    p.dot(x, y, C[k < 0.4 ? 7 : 6], k < 0.6 ? 1 : (1 - k) / 0.4);
    p.light(x, y, C[6], 0.4 * (1 - k));
  });
}
