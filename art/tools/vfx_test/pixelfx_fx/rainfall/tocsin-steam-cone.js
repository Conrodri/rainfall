// Rainfall (top-down, for an iso camera): Tocsin's furnace vents scalding steam, seen from above. A cone of `span`
// radians centred on +x (or a full ring when span >= 2π), `radius` px long: puffs blasted out from the pivot that swell,
// slow and thin at the reach, a hot ember-lit core at the mouth, wisps curling at the rim, a few sparks carried out.
// One-shot.
import { fit, burst, fly, clamp, smooth, ease, TAU } from "../../core/index.js";

export const meta = {
  name: "Tocsin steam cone",
  desc: "Seen from above, a cone (or ring) of scalding steam blasted from the caster: puffs thinning to the reach, an ember-lit mouth, wisps at the rim, sparks carried out.",
  tags: ["rainfall", "tocsin", "steam", "cone", "breath", "top-down", "directional", "one-shot"],
  size: [124, 124],
  origin: [62, 62],
  duration: 0.62,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#0d0d0c", "#1e1e1c", "#3a3a37", "#66645e", "#9a968c", "#c9c3b4", "#FF7A1F"],
    radius: 48,
    span: Math.PI / 3,
    puffs: 56,
    seed: 91,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, ring = o.span >= TAU - 0.01, H = ring ? Math.PI : o.span / 2, S = o.seed;
  // the blast's front, from the mouth to the reach
  const front = R * ease.outCubic(clamp(t / 0.22));
  const fade = 1 - smooth(0.2, meta.duration, t);
  // the faint sector already swept: a dithered pale floor-wash, so the cone's shape reads at a glance
  if (fade > 0.05) {
    p.shade(-front, -front, front, front, (x, y, out) => {
      const r = Math.hypot(x, y);
      if (r > front || r < 3) return;
      if (!ring && Math.abs(Math.atan2(y, x)) > H) return;
      if ((Math.floor(x) + Math.floor(y)) % 2) return;
      out.c = C[r > front - 4 ? 4 : 3];
      out.a = 0.5 * fade * (1 - (r / R) * 0.5);
    });
  }
  // puffs blown out along the cone: swell, slow, thin
  burst(o.puffs, S, (r) => {
    const born = r.range(0, 0.16), a = t - born, life = r.range(0.28, 0.42);
    if (a < 0 || a > life) return;
    const ang = ring ? r.range(0, TAU) : r.range(-H, H) * Math.sqrt(r.next());
    const dist = R * r.range(0.55, 1.0), q = a / life;
    const d = dist * ease.outCubic(clamp(a / (life * 0.8)));
    const x = Math.cos(ang) * d, y = Math.sin(ang) * d;
    const rad = 3 + 11 * Math.sqrt(q) * (dist / R);
    const hot = d < R * 0.25;
    p.disc(x, y, rad, (dd, an) => C[hot ? 6 : dd < 0.5 && Math.cos(an + 2.36) > 0 ? 5 : 4], (dd) => (1 - dd * dd) * 0.55 * (1 - q));
    if (hot) p.glow(x, y, rad * 2, C[6], 0.35 * (1 - q));
  });
  // wisps curling at the rim
  burst(ring ? 10 : 5, S + 1, (r) => {
    const a = t - r.range(0.12, 0.22), life = 0.25;
    if (a < 0 || a > life) return;
    const q = a / life, a0 = ring ? r.range(0, TAU) : r.range(-H, H), sgn = r.next() < 0.5 ? -1 : 1;
    for (let i = 0; i < 6; i++) {
      const u = i / 5, an = a0 + sgn * (u * 0.35 + q * 0.2), rr = R * (0.92 + 0.12 * u);
      p.disc(Math.cos(an) * rr, Math.sin(an) * rr, 3 - 2 * u, C[5], (dd) => 0.35 * (1 - q) * (1 - dd));
    }
  });
  // the ember-lit mouth of the furnace
  const m = 1 - smooth(0, 0.25, t);
  if (m > 0) {
    p.circle(0, 0, 3, C[6], m);
    p.glow(ring ? 0 : 4, 0, 16, C[6], 0.6 * m);
  }
  // sparks carried out on the blast
  burst(ring ? 14 : 8, S + 2, (r) => {
    const a = t - r.range(0, 0.1), life = r.range(0.18, 0.3);
    if (a < 0 || a > life) return;
    const ang = ring ? r.range(0, TAU) : r.range(-H, H), sp = r.range(120, 220);
    const [x, y] = fly(0, 0, Math.cos(ang) * sp, Math.sin(ang) * sp, a, 0, 5), q = a / life;
    p.dot(x, y, C[6], 1 - q);
    p.light(x, y, C[6], 0.4 * (1 - q));
  });
}
