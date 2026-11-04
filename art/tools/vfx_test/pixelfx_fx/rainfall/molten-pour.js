// Rainfall (top-down, for an iso camera): a gob of molten metal flung along the floor, seen from above. A compact
// white-hot head runs out from the origin to `length` px, leaving a glowing trail of slag that crusts over and cools.
import { fit, burst, fly, clamp, smooth, ease, noise, noise2 } from "../../core/index.js";

export const meta = {
  name: "Molten pour",
  desc: "Seen from above, a white-hot gob races out along the floor leaving a molten trail that spits sparks, crusts over in dark plates and cools from the tail.",
  tags: ["rainfall", "fire", "molten", "metal", "projectile", "top-down", "directional", "one-shot"],
  size: [228, 56],
  origin: [24, 28],
  duration: 1.5,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: ["#120804", "#241008", "#3c1c0e", "#6a3a1e", "#a0602e", "#d98038", "#FF9A3C", "#ffc684"],
    length: 168,
    width: 18,
    run: 0.35, // s for the head to reach the end
    seed: 3,
  },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), L = o.length, hw = o.width / 2, S = o.seed;
  const head = L * ease.outQuad(clamp(t / o.run));
  const laid = (x) => o.run * (1 - Math.sqrt(1 - clamp(x / L))); // when the head passed x (inverse of outQuad)
  const edge = (x) => hw * (0.55 + 0.25 * noise(x * 0.13, S) + 0.2 * clamp(x / 20));
  // the trail: molten where fresh, crusting into dark plates as it cools, from the tail first
  p.shade(0, -hw - 2, Math.min(head, L), hw + 2, (x, y, out) => {
    const age = t - laid(x);
    if (age < 0) return;
    const e = edge(x) * (1 - 0.35 * smooth(0.4, 1.2, age)), ay = Math.abs(y);
    if (ay > e) return;
    const cool = smooth(0.15, 1.1, age), v = ay / e;
    const crack = Math.abs(noise2(x * 0.22, y * 0.45, S + 2)) < 0.07;
    const gone = smooth(0.9, 1.45, t) * 1.3 - noise(x * 0.2, S + 4) * 0.3;
    if (gone > 1 - v * 0.3) return;
    let c = Math.round(7 - v * 2.5 - cool * 4.5);
    if (cool > 0.5 && crack) c = Math.max(c, 5); // glowing cracks between the plates
    if (y > 0 && v > 0.5) c -= 1;
    out.c = C[clamp(c, 1, 7)];
    out.k = (c >= 5 ? 0.5 : 0.08) * (1 - cool * 0.6);
    out.l = C[6];
  });
  // the head: a compact white-hot gob, stretched by its speed
  if (t < o.run + 0.08) {
    const sp = clamp(1 - t / o.run), hx = head, len = 4 + 10 * sp;
    p.ellipse(hx - len * 0.3, 0, len, hw * 0.75, (d, a) => C[d < 0.45 ? 7 : Math.cos(a + 2.36) > 0 ? 6 : 5]);
    p.glow(hx, 0, 22, C[6], 0.85);
  } else {
    p.glow(L, 0, 18, C[6], 0.6 * (1 - smooth(o.run, o.run + 0.5, t)));
  }
  // sparks spat off the trail and the head
  burst(30, S + 6, (r) => {
    const x0 = r.range(0, L), born = laid(x0) + r.range(0, 0.15), age = t - born, life = r.range(0.2, 0.45);
    if (age < 0 || age > life) return;
    const side = r.next() < 0.5 ? -1 : 1, a = side * r.range(0.4, 1.4), sp = r.range(40, 110);
    const [x, y] = fly(x0, side * edge(x0) * 0.5, Math.cos(a) * sp * 0.5, Math.sin(a) * sp, age, 0, 6), k = age / life;
    p.dot(x, y, C[k < 0.4 ? 7 : 6], k < 0.6 ? 1 : (1 - k) / 0.4);
    p.light(x, y, C[6], 0.45 * (1 - k));
  });
}
