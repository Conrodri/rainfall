// Rainfall (top-down, for an iso camera): Bourbe's Mud Slap, a wide arc of mud swung round her, seen from above.
// One-shot. The swing sweeps `span` radians centred on +x at radius `radius` px: a heavy, lumpy smear of dark mud with
// a wet lit rim, thick at the head and thinning to drips at the tail, clods flung off the rim that land as splats.
import { fit, burst, fly, clamp, smooth, ease, tileNoise } from "../../core/index.js";

export const meta = {
  name: "Bourbe mud slap",
  desc: "Seen from above, a wide arc of mud swung round the caster: a heavy lumpy smear with a wet lit rim, thinning to drips, clods flung off that land as splats.",
  tags: ["rainfall", "melee", "slap", "mud", "arc", "top-down", "directional", "one-shot"],
  size: [100, 136],
  origin: [24, 68],
  duration: 0.6,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06100a", "#0f1c14", "#1d3324", "#3a5e42", "#5f9a6c", "#8DDBA8", "#C2F0D2"],
    radius: 52,
    span: 3.665, // 210°
    seed: 7,
  },
};

const SWEEP = 0.11, HOLD = 0.06, TRAIL = 0.32;

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, SPAN = o.span, A0 = -SPAN / 2, S = o.seed;
  const head = A0 + SPAN * ease.outExpo(clamp(t / SWEEP));
  const tail = A0 + SPAN * smooth(SWEEP + HOLD, SWEEP + HOLD + TRAIL, t);
  const age = clamp(t / (SWEEP + HOLD + TRAIL + 0.1));
  const W = (u) => (4 + 12 * Math.pow(u, 0.6)) * (1 - 0.4 * smooth(SWEEP + HOLD, SWEEP + HOLD + TRAIL, t));
  if (head > tail + 0.01 && age < 0.98) {
    p.shade(-R - 2, -R - 2, R + 2, R + 2, (x, y, out) => {
      const r = Math.hypot(x, y), a = Math.atan2(y, x);
      if (r > R + 2 || a < tail || a > head) return;
      const u = (a - tail) / Math.max(0.01, head - tail), w = W(u);
      const lump = 2.2 * tileNoise(a * 9, r / 5, 0, 0, S); // lumpy outer edge
      const rr = R + lump;
      if (r > rr || r < rr - w) return;
      const q = (rr - r) / w; // 0 rim .. 1 inner edge
      if (q > 0.7 && tileNoise(a * 14, r / 3, 0, 0, S + 1) < -0.1 + (1 - u) * 0.6) return; // ragged inner edge
      const n = tileNoise(x / 3, y / 3, 0, 0, S + 2);
      let c = q < 0.18 ? (age < 0.5 ? 5 : 4) : n > 0.35 ? 3 : 2;
      if (q < 0.18 && Math.cos(a + 2.36) < -0.3) c -= 1; // lit from the top left
      if (n > 0.7 && q > 0.25 && age < 0.6) c = 4; // wet glints in the mud
      out.c = C[clamp(c, 1, 6)];
      out.a = age > 0.75 ? (1 - age) / 0.25 : 1;
      out.k = (q < 0.18 ? 0.45 : c >= 4 ? 0.2 : 0.02) * (1 - age) * (0.3 + 0.7 * u);
      out.l = C[5];
    });
  }
  // the hand of mud on the swing
  if (t < SWEEP + 0.04) {
    const c = Math.cos(head), s = Math.sin(head);
    p.disc(c * (R - 6), s * (R - 6), 6, (d) => (d < 0.4 ? C[5] : d < 0.8 ? C[3] : C[2]), 1);
    p.glow(c * (R - 6), s * (R - 6), 18, C[5], 0.45);
  }
  // clods flung off the rim, flying out and landing as flat splats
  burst(26, S + 3, (r) => {
    const a = A0 + SPAN * r.range(0.1, 1), born = SWEEP * ease.outExpo(clamp(r.range(0.1, 1))) * 0.9, age2 = t - born;
    if (age2 < 0) return;
    const fl = r.range(0.12, 0.22);
    const tx = -Math.sin(a), ty = Math.cos(a), sp = r.range(50, 110), outw = r.range(0.4, 1);
    const vx = (tx * 0.6 + Math.cos(a) * outw) * sp, vy = (ty * 0.6 + Math.sin(a) * outw) * sp;
    const [x, y] = fly(Math.cos(a) * R, Math.sin(a) * R, vx, vy, Math.min(age2, fl), 0, 6);
    const fade = 1 - smooth(0.35, 0.55, t);
    if (fade <= 0) return;
    if (age2 < fl) {
      p.disc(x, y, 1.6, () => C[age2 < fl * 0.5 ? 4 : 3], fade);
      p.light(x, y, C[5], 0.3 * fade);
    } else {
      p.dot(x, y, C[2], fade);
      p.dot(x + 1, y, C[3], fade);
      p.dot(x, y + 1, C[2], fade * 0.8);
    }
  });
  if (t < 0.3) p.glow(Math.cos(head) * (R - 8), Math.sin(head) * (R - 8), 26, C[4], 0.35 * (1 - t / 0.3));
}
