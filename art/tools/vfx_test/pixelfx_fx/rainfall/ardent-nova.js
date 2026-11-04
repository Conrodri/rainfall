// Rainfall (iso camera, drawn in screen space): Ardent's fire nova. The floor is an ellipse squashed 2:1 exactly
// like the game's floor under its 30° camera, and the flames stand up out of it, so the effect has both a true
// footprint and volume. A white flash at the feet, a burning front racing out across the floor to `radius`, flame
// tongues flaring as it passes them and burning down behind it, sparks and flame puffs thrown up, embers and smoke.
// makeBlast() is shared with ardent-brasier and ardent-meteor-impact (same recipe, other sizes and timings).
// Flame tongues, puffs and floor light come from the fire effects' shared recipes (fire/_lib.js).
import { Particles, Bits, Lights, P, PF, B, Rng, fit, clamp, smooth, ease, noise, noise2, rand, TAU, WHITE, mix, rgb } from "../../core/index.js";
import { hotFirst, flameTongue, simDraw, floorLight, LAYERS, BACK_LAYERS, BIG_LAYERS } from "../fire/_lib.js";

export const PAL = ["#0d0504", "#1f0b06", "#3a1a10", "#6b3a26", "#a8481a", "#FF7319", "#ffa35a"];
export const SQ = 0.5; // the game's floor squash (sin 30°)

export const meta = {
  name: "Ardent nova",
  desc: "Iso fire nova: a flash at the feet, a burning front racing out over a 2:1 floor ellipse, flame tongues flaring as it passes, sparks, puffs, embers and smoke.",
  tags: ["rainfall", "fire", "nova", "ring", "aoe", "iso", "one-shot"],
  size: [140, 118],
  origin: [70, 76],
  duration: 1.5,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: PAL,
    radius: 56, // px on the floor (ground radius: the ellipse is radius x radius/2)
    flame: 26, // px, tallest tongue
    run: 0.28, // s for the front to reach the radius
    burn: 0.5, // s a tongue burns after the front passes it
    hold: 0, // s the whole disc keeps burning after the front (brasier)
    tongues: 0, // 0 = from the radius
    plume: 0, // 0..1 a column of fire balls thrown straight up from the middle (meteor impact)
    debris: 0, // chunks of rock flung out (meteor impact)
    seed: 4,
  },
};

const WARM = rgb(255, 170, 90);

/** The blast, for a one-shot of D seconds: { update(dt), draw(p) }. */
export function makeBlast(o, D) {
  const F = fit(o.palette, 9), H = hotFirst(F), R = o.radius, FL = o.flame, RUN = o.run, BURN = o.burn, HOLD = o.hold ?? 0;
  const S = o.seed * 31, rnd = new Rng(o.seed);
  const groundY = R * SQ + 3;
  const ps = new Particles({ rng: rnd, ground: () => groundY, sparks: [H[1], H[2], H[3], H[5]] });
  const bits = new Bits({ ground: () => groundY });
  const lights = new Lights();
  const front = (tt) => R * ease.outCubic(clamp(tt / RUN));
  const arrive = (g) => RUN * (1 - Math.cbrt(Math.max(0, 1 - clamp(g / R)))); // when the front reaches ground radius g
  // the tongues: most on the rim, the rest scattered inside; each lights when the front reaches it
  const n = o.tongues || Math.round(R * 0.9);
  const tongues = [];
  for (let i = 0; i < n; i++) {
    const rim = rand(i, S, 1) < 0.58;
    const g = R * (rim ? 0.82 + 0.18 * rand(i, S, 2) : 0.2 + 0.62 * Math.sqrt(rand(i, S, 2)));
    const a = rand(i, S, 3) * TAU;
    const x = Math.cos(a) * g, y = Math.sin(a) * g * SQ;
    const h = FL * (rim ? 0.7 + 0.3 * rand(i, S, 4) : 0.35 + 0.35 * rand(i, S, 4)) * (1 - 0.18 * Math.max(0, -Math.sin(a)));
    const born = arrive(g) + rand(i, S, 5) * 0.04;
    tongues.push({ x, y, h, w: 1.6 + h * 0.2, born, life: BURN * (0.7 + 0.6 * rand(i, S, 6)) + HOLD * (rim ? 1 : 0.85), back: Math.sin(a) < 0, n: i * 7 + S, sx: Math.cos(a) * h * 0.25, done: false });
  }
  tongues.sort((a, b) => a.y - b.y);
  const glowC = mix(H[3], WHITE, 0.15);
  let t = 0, boomed = false;

  function boom() {
    lights.add(0, -FL * 0.4, R * 1.3, WARM, 0.85, 0.35 + HOLD * 0.3);
    lights.add(0, -3, R * 0.5, WHITE, 0.8, 0.12);
    // sparks thrown out and up, spread over the floor's ellipse
    for (let i = 0; i < Math.round(20 + R * 0.6); i++) {
      const a = rnd.range(0, TAU), sp = rnd.range(60, 150) * (0.6 + R / 140);
      ps.spawn(P.SPARK, Math.cos(a) * 3, Math.sin(a) * 1.5 - 2, Math.cos(a) * sp, Math.sin(a) * sp * SQ - rnd.range(60, 170), rnd.range(0.25, 0.6));
    }
    if (o.plume > 0) {
      for (let i = 0; i < Math.round(18 * o.plume); i++) {
        ps.spawn(P.FIRE, rnd.range(-R * 0.3, R * 0.3), rnd.range(-2, 2), rnd.range(-14, 14), -rnd.range(40, 120) * o.plume, rnd.range(0.35, 0.7), 0, rnd.range(2.2, 4.2), rnd.range(0, 0.08), PF.SMOKES | PF.BIG);
      }
    }
    for (let i = 0; i < (o.debris ?? 0); i++) {
      const a = rnd.range(0, TAU), sp = rnd.range(40, 110);
      bits.add({ kind: B.CHUNK, x: rnd.range(-2, 2), y: -1, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp * SQ - rnd.range(120, 230), g: 1, drag: 0.4, bounce: 0.3, life: rnd.range(0.8, 1.2), a: rnd.range(0, TAU), va: rnd.range(-14, 14), s: rnd.int(1, 2), ramp: [F[0], F[1], F[2], F[3], F[4]] });
    }
  }

  function floor(p) {
    const fr = front(t), out = smooth(D * 0.3, D - 0.15, t), E = R + 4;
    if (out >= 1) return;
    p.shade(-E, -E * SQ - 1, E, E * SQ + 1, (x, y, px) => {
      const g = Math.hypot(x, y / SQ);
      const wob = noise2(x * 0.12, y * 0.24, S) * 2.2;
      const d = fr - g + wob; // >= 0 inside the burnt disc, 0 at the front
      if (d < 0) return;
      const since = t - arrive(clamp(g / R) * R);
      // the front: a bright seam of fire lying on the floor, lit from the upper left
      const band = 3 + R * 0.04;
      if (t < RUN + 0.12 && d < band) {
        const q = d / band, lit = (-x - y / SQ) / (R * 1.4);
        let c = q < 0.3 ? 1 : q < 0.65 ? 2 : 4;
        if (lit < -0.3) c += 1;
        px.c = H[c];
        px.k = 0.55 * (1 - q);
        px.l = H[3];
        return;
      }
      // behind it: scorched floor, cinders glowing and cooling, cracks that hold the heat longest
      const heat = Math.exp(-Math.max(0, since - HOLD) * 4.0) * (1 - out);
      const cn = noise2(x * 0.34, y * 0.68, S + 1), crack = Math.abs(noise2(x * 0.11, y * 0.22, S + 2)) < 0.06;
      if ((crack && heat > 0.08) || (cn > 0.62 && heat > 0.18)) {
        const c = heat > 0.7 ? 2 : heat > 0.45 ? 3 : heat > 0.25 ? 4 : 5;
        px.c = H[c];
        px.k = 0.3 * heat;
        px.l = H[3];
        return;
      }
      // soot: solid patches that shrink away as it cools (no dithered fill)
      if (g > R + 1) return;
      const soot = noise2(x * 0.16, y * 0.32, S + 3) + 0.25 * noise2(x * 0.5, y, S + 4);
      if (soot > 0.3 + out * 1.2 + (g / R) * 0.3) px.c = soot > 0.65 + out * 0.6 ? F[1] : F[2];
    });
    // the floor glows while it burns
    floorLight(p, 0, 0, Math.max(4, fr * 1.08), Math.max(2, fr * 1.08 * SQ), glowC, 0.3 * (1 - smooth(RUN + HOLD, RUN + HOLD + BURN + 0.3, t)));
  }

  function flames(p, back) {
    const NZ = (rate, seed, off) => noise(t * rate + off, seed);
    for (const q of tongues) {
      if (q.back !== back) continue;
      const age = t - q.born;
      if (age < 0 || age > q.life) continue;
      const k = age / q.life;
      const h = q.h * ease.outCubic(Math.min(1, age / 0.07)) * (1 - smooth(0.45, 1, k)) * (0.82 + 0.18 * noise(t * 9, q.n));
      if (h < 1.5) continue;
      const layers = back ? BACK_LAYERS : h > 18 ? BIG_LAYERS : LAYERS;
      flameTongue(p, q.x, q.y, h, q.w * (1 - 0.3 * k), q.sx * (1 - k), NZ, q.n, H, layers);
      if (h > 6) p.glow(q.x, q.y - h * 0.4, h * 0.9, glowC, h > 24 ? 0.07 : 0.11);
    }
  }

  return {
    update(dt) {
      t += dt;
      if (!boomed) (boomed = true), boom();
      // flame puffs and embers thrown up by the tongues as they burn
      for (const q of tongues) {
        const age = t - q.born;
        if (age < 0 || age > q.life) continue;
        if (!q.done) {
          q.done = true;
          if (rnd.chance(0.7)) ps.spawn(P.FIRE, q.x, q.y - q.h * 0.5, q.x * 0.25 + rnd.range(-8, 8), -rnd.range(30, 70), rnd.range(0.25, 0.5), 0, rnd.range(1.8, 3.2) * (0.6 + q.h / 34), 0, rnd.chance(0.4) ? PF.SMOKES : 0);
        }
        if (rnd.chance(dt * (0.6 + HOLD * 2))) ps.spawn(P.EMBER, q.x, q.y - q.h * 0.6, rnd.range(-12, 12), -rnd.range(30, 70), rnd.range(0.4, 0.9), H[3], 1);
        if (age > q.life * 0.7 && rnd.chance(dt * 1.2)) ps.spawn(P.SMOKE, q.x, q.y - q.h * 0.5, rnd.range(-4, 4), -rnd.range(10, 22), rnd.range(0.5, 0.9), 0, rnd.range(2, 3.5));
      }
      ps.update(dt);
      bits.update(dt);
      lights.update(dt);
    },
    draw(p) {
      if (t >= D - 0.02) return;
      floor(p);
      simDraw(p, ps, H, "back");
      flames(p, true);
      bits.draw(p);
      // the flash at the feet
      const f = 1 - smooth(0, 0.16, t);
      if (f > 0) {
        p.glow(0, -4, R * 0.55, H[1], 0.9 * f);
        p.ellipse(0, 0, 3 + R * 0.12 * f, (3 + R * 0.12 * f) * SQ, H[0], f);
      }
      flames(p, false);
      simDraw(p, ps, H, "front");
      lights.draw(p);
    },
  };
}

export function create(o) {
  return makeBlast(o, meta.duration);
}
