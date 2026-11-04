// Rainfall (for an iso camera): Averse's water blade flying towards +x, as a loop. A crescent of water, convex side
// forward, wrapped round a round bead: it stays a readable blob when the game foreshortens the flight (towards the top
// or the bottom of the screen). A short streak of spray and droplets shed behind. shape "drop": a plain bead (Bruine).
import { fit, cycle, fly, clamp, TAU } from "../../core/index.js";

export const meta = {
  name: "Averse water blade",
  desc: "A water blade flying right: a bright crescent of water round a round bead, a short tapering spray streak and droplets shed behind. shape drop: a plain teardrop bead.",
  tags: ["rainfall", "water", "blade", "bullet", "projectile", "loop"],
  size: [64, 40],
  origin: [46, 20],
  duration: 0.4,
  loop: true,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#04090f", "#08141f", "#0f2a38", "#2f6577", "#2a9fb5", "#5FD4E8", "#9fe8f2"],
    radius: 9,
    tail: 26,
    shape: "blade",
    seed: 21,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 7), R = o.radius, T = o.tail, ph = t / meta.duration, blade = o.shape !== "drop";
  const wob = Math.sin(ph * TAU);
  // spray streak: a tapering wedge, brighter lanes sliding back along it
  const hw0 = R * (blade ? 0.55 : 0.5);
  p.shade(-T - 1, -hw0 - 1, 0, hw0 + 1, (x, y, out) => {
    const u = -x / T;
    if (u < 0 || u > 1) return;
    const hw = hw0 * Math.pow(1 - u, 1.3);
    if (Math.abs(y) > hw) return;
    const q = Math.abs(y) / Math.max(hw, 0.5);
    const dash = ((x + ph * 12) % 6 + 6) % 6;
    let c = u < 0.25 ? 5 : u < 0.55 ? 4 : 3;
    if (q > 0.55 && dash > 3) return; // ragged lanes at the edge
    if (q < 0.35 && dash < 2.5 && u < 0.7) c = Math.min(6, c + 1);
    if (y > 0 && q > 0.4) c -= 1; // lit from the top left
    out.c = C[clamp(c, 2, 6)];
    out.a = u > 0.75 ? 0.6 : 1;
    out.k = 0.2 * (1 - u);
    out.l = C[5];
  });
  if (blade) {
    // the crescent: between an outer circle and an inner one set further back; tips swept back
    const ox = -R * 0.55, ix = -R * 1.05;
    p.shade(-R * 1.6, -R - 1, R * 0.5, R + 1, (x, y, out) => {
      const ro = Math.hypot(x - ox, y), ri = Math.hypot(x - ix, y * (1.02 + 0.04 * wob));
      if (ro > R || ri < R) return;
      const a = Math.atan2(y, x - ox);
      if (Math.abs(a) > 1.25) return;
      const q = (R - ro) / Math.max(1, R - (ri - R)); // 0 front edge .. inner
      let c = R - ro < 1.3 ? 6 : q < 0.5 ? 5 : 4;
      if (y > R * 0.25 && c < 6) c -= 1;
      if (Math.abs(a) > 1.0) c = Math.min(c, 4);
      out.c = C[clamp(c, 2, 6)];
      out.k = c >= 5 ? 0.3 : 0.12;
      out.l = C[5];
    });
  }
  // the bead: round (blade) or a short teardrop (drop); white glint top left
  const br = blade ? R * 0.42 : R * 0.6;
  p.ellipse(blade ? -R * 0.05 : -br * 0.15, 0, blade ? br : br * 1.2, br, (d, a) => {
    if (d < 0.4) return C[6];
    if (d > 0.78) return C[Math.cos(a + 2.36) > 0 ? 5 : 3];
    return C[Math.cos(a + 2.36) > -0.2 ? 5 : 4];
  });
  p.px(-br * 0.35, -br * 0.45, C[6]);
  p.glow(0, 0, R * 2, C[5], 0.35 + 0.05 * wob);
  // droplets shed backwards and out
  cycle(t, meta.duration, blade ? 9 : 6, o.seed, 0.3, (age, life, r) => {
    const k = age / life, side = r.range(-1, 1);
    const [x, y] = fly(-R * 0.6, side * R * 0.6, -r.range(40, 80), side * r.range(15, 45), age, 0, 3);
    p.dot(x, y, C[k < 0.4 ? 6 : 5], 1 - k * 0.8);
    p.light(x, y, C[5], 0.3 * (1 - k));
  });
}
