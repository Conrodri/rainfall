// Rainfall (top-down, for an iso camera): a noria, seen from above. One-shot. A water wheel churns at the origin
// (`hub` px) and a blade of water `radius` px long and `width` px wide sweeps round it from +x through `sweep`
// radians in `turn` seconds, at a steady rate (the gameplay blade), leaving a fading wash and spray behind its tip;
// then the wheel slows and drains. The sweep runs the way angles grow (clockwise on screen, y down).
import { fit, burst, fly, clamp, smooth, ease, tileNoise, TAU } from "../../core/index.js";

export const meta = {
  name: "Noria sweep",
  desc: "Seen from above, a water wheel churns on the floor while a long blade of water sweeps three quarters of a turn round it, foam on its leading edge, a fading wash behind.",
  tags: ["rainfall", "water", "wheel", "sweep", "beam", "boss", "top-down", "directional", "one-shot"],
  size: [172, 172],
  origin: [86, 86],
  duration: 1.95,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#06090d", "#0b1219", "#16222c", "#34505e", "#6f98a8", "#8fc8d8", "#5EC8FF", "#BFF4FF"],
    radius: 72, // blade length (px)
    width: 14, // blade width (px)
    hub: 12, // wheel radius (px)
    sweep: 4.71, // radians swept
    turn: 1.5, // seconds for the sweep
    seed: 8,
  },
};

const angd = (a, b) => {
  let d = (a - b) % TAU;
  if (d < -Math.PI) d += TAU;
  if (d > Math.PI) d -= TAU;
  return d;
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), L = o.radius, hw = o.width / 2, H = o.hub, S = o.seed;
  const k = clamp(t / o.turn), ang = o.sweep * k;
  const live = smooth(0, 0.06, t) * (1 - smooth(o.turn, o.turn + 0.4, t));
  const spin = t * 9 + ang; // the wheel turns with the blade
  if (live <= 0.01) return;
  const WASH = 0.9; // radians of wash trailing the blade
  p.shade(-L - 2, -L - 2, L + 2, L + 2, (x, y, out) => {
    const r = Math.hypot(x, y);
    if (r > L + 1.5) return;
    const a = Math.atan2(y, x);
    // the hub: a churning wheel, paddles turning, a bright rim lit from the top left
    if (r <= H + 1) {
      const pad = Math.cos((a - spin) * 6);
      const lit = Math.cos(a + 2.36);
      let c = r > H - 1.5 ? (lit > 0 ? 6 : 5) : pad > 0.75 ? 5 : r < H * 0.35 ? 6 : 3;
      out.c = C[c];
      out.k = (c >= 5 ? 0.45 : 0.1) * live;
      out.l = C[6];
      return;
    }
    // the blade: the band along the current angle, foam on its leading side, water streaming out along it
    const d = angd(a, ang);
    const across = r * Math.sin(d), along = r * Math.cos(d);
    if (along > 0 && Math.abs(across) <= hw) {
      const q = Math.abs(across) / hw, lead = across > 0; // + side leads (the way the angle grows)
      const n = tileNoise((along - t * 140) / 7, across / 3, 0, 0, S);
      let c = q < 0.25 ? 6 : n > 0.3 ? 5 : 4;
      if (lead && q > 0.6) c = 7;
      if (!lead && q > 0.8 && n < 0) return; // ragged trailing edge
      if (along > L - 3) c = 7;
      out.c = C[c];
      out.k = (c >= 6 ? 0.5 : 0.2) * live;
      out.l = C[6];
      return;
    }
    // the wash: the area the blade has just crossed, fading with the angle behind it
    const behind = -d; // >0 behind the blade
    if (behind > 0 && behind < Math.min(WASH, ang + 0.01) && r > H) {
      const w = 1 - behind / WASH;
      const n = tileNoise(r / 6 - t * 3, a * 4, 0, 0, S + 3);
      if (n < 0.55 - w * 1.1) return;
      out.c = C[w > 0.7 && n > 0.3 ? 5 : 3];
      out.a = 0.55 * w * live;
      out.k = 0.08 * w * live;
      out.l = C[5];
    }
  });
  // spray flung off the tip and the leading edge, kicked forward along the sweep
  burst(70, S + 5, (r) => {
    const born = r.range(0, o.turn), age = t - born, life = r.range(0.2, 0.45);
    if (age < 0 || age > life) return;
    const ab = o.sweep * clamp(born / o.turn), rr = L * r.range(0.45, 1.02);
    const tx = -Math.sin(ab), ty = Math.cos(ab), sp = r.range(40, 110) * (rr / L);
    const out = r.range(-0.2, 0.6);
    const vx = (tx + Math.cos(ab) * out) * sp, vy = (ty + Math.sin(ab) * out) * sp;
    const [x, y] = fly(Math.cos(ab) * rr, Math.sin(ab) * rr, vx, vy, age, 0, 5);
    const q = age / life;
    p.dot(x, y, C[q < 0.35 ? 7 : q < 0.7 ? 6 : 5], q < 0.6 ? 1 : (1 - q) / 0.4);
    p.light(x, y, C[6], 0.4 * (1 - q));
  });
  // light: the wheel's heart and a pool riding the blade's tip
  p.glow(0, 0, H * 2.2, C[6], 0.45 * live);
  p.glow(Math.cos(ang) * L * 0.8, Math.sin(ang) * L * 0.8, 22, C[6], 0.35 * live);
  if (t < 0.15) p.glow(0, 0, H * 3, C[7], 0.6 * (1 - t / 0.15));
}
