// Rainfall (for an iso camera, screen space): the Lock-keeper's sluice wheel spinning upright behind its shoulders,
// as a loop. A rim of running water round dark bronze spokes, a glowing hub, drops flung off the rim along its
// spin and falling. Upright, so it faces the camera as a circle. The origin is the hub.
import { fit, cycle, fly, clamp, tileNoise, TAU } from "../../core/index.js";

export const meta = {
  name: "Sluice wheel",
  desc: "An upright sluice wheel spinning: a rim of running water round dark bronze spokes, a glowing hub, drops flung off the rim along its spin.",
  tags: ["rainfall", "water", "wheel", "boss", "iso", "billboard", "loop"],
  size: [104, 116],
  origin: [52, 48],
  duration: 1,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#070D12", "#0D1A22", "#16303F", "#35596C", "#3E86A8", "#5EC8FF", "#A8E6FF"],
    radius: 34,
    spokes: 8,
    seed: 2,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, N = o.spokes, S = o.seed, ph = t / meta.duration;
  const spin = ph * TAU * 2 / N; // two spoke steps per loop: seamless
  p.shade(-R - 2, -R - 2, R + 2, R + 2, (x, y, out) => {
    const r = Math.hypot(x, y);
    if (r > R + 0.5) return;
    const a = Math.atan2(y, x), lit = Math.cos(a + 2.36);
    // the rim: a band of water running round, streaked by its flow
    if (r > R - 5) {
      const n = tileNoise(((a - spin) / TAU) * 32, (R - r) / 2, 32, 0, S);
      const c = r > R - 1.5 ? (lit > 0 ? 6 : 5) : n > 0.3 ? 5 : n > -0.2 ? 4 : 3;
      out.c = C[c];
      out.k = c >= 5 ? 0.35 : 0.08;
      out.l = C[5];
      return;
    }
    // the hub
    if (r < 5) {
      out.c = C[r < 2.5 ? 6 : 5];
      out.k = 0.5;
      out.l = C[6];
      return;
    }
    // the spokes, dark bronze, lit on their upper edges; water sheeting down between them
    const sa = (((a - spin) * N) / TAU) % 1, d = Math.abs((sa < 0 ? sa + 1 : sa) - 0.5);
    if (d > 0.42) {
      out.c = C[lit > 0.2 ? 3 : 2];
      return;
    }
    const n = tileNoise(x / 3, (y - ph * 40) / 5, 0, 8, S + 1);
    if (n > 0.45) {
      out.c = C[4];
      out.a = 0.6;
      out.k = 0.05;
      out.l = C[5];
    }
  });
  // drops flung tangentially off the rim (spinning clockwise on screen), then falling
  cycle(t, meta.duration, 18, S + 3, (g) => g.range(0.3, 0.55), (age, life, r) => {
    const a0 = r.range(0, TAU), sp = r.range(30, 60);
    const tx = -Math.sin(a0), ty = Math.cos(a0);
    const [x, y] = fly(Math.cos(a0) * R, Math.sin(a0) * R, tx * sp, ty * sp, age, 260, 1);
    const q = age / life;
    p.dot(x, y, C[q < 0.4 ? 6 : 5], q < 0.7 ? 1 : (1 - q) / 0.3);
    p.light(x, y, C[5], 0.3 * (1 - q));
  });
  p.glow(0, 0, R * 0.8, C[5], 0.3);
}
