// Shared pieces for the Rainfall top-down effects (seen from straight above: the game's iso camera squashes them,
// so nothing here has height; light comes from the top left).
import { tileNoise, clamp, smooth } from "../../core/index.js";

/**
 * A front of water seen from above, moving towards +x: an arc of radius R around (cx, 0), half span A (radians).
 * From the front backwards: a thin pressure ripple just ahead, the crest (white foam, `band` px thick), then the
 * water body (`trail` px) laced with foam and streaked by the backward flow, breaking up into lace at its back.
 * flow: px the water has slid backwards (scroll), wob: phase of the crest's wobble, k: 0..1 strength (it breaks
 * up as k falls). loopP: cells the noise repeats over (for seamless loops, scroll by a whole period).
 */
export function waterFront(p, C, { cx, R, A, band, trail, flow = 0, wob = 0, k = 1, seed = 0, loopP = 0, curl = 6, ahead = true, light = 0.55 }) {
  if (k <= 0.01 || R <= 1) return;
  const n = C.length, top = n - 1, cs = 4;
  const B = R + 6, v = R - trail - band - 8, x0 = cx + Math.min(v * Math.cos(A), v) - 8;
  p.shade(x0, -B, cx + R + 6, B, (x, y, o) => {
    const dx = x - cx, r = Math.hypot(dx, y), ang = Math.atan2(y, dx);
    const ea = Math.abs(ang) / A;
    if (ea > 1.08) return;
    const along = ang * R;
    // the crest wanders a little and its ends trail back as it loses height
    const wv = tileNoise(along / 7 + seed * 3.1, wob, 0, loopP ? 4 : 0, seed) * 1.6;
    const s = R - r + wv + curl * Math.pow(Math.min(ea, 1.08), 3);
    const end = 1 - smooth(0.82, 1.08, ea);
    const bandE = band * (0.45 + 0.55 * end) * (0.6 + 0.4 * k);
    if (s < -5) return;
    if (s < 0) {
      // pressure ripple ahead of the crest
      if (!ahead || s > -3.2 || s < -4.6) return;
      const rn = tileNoise(along / 3, wob * 2, 0, loopP ? 8 : 0, seed + 7);
      if (rn < 0.15 - 0.6 * k * end) return;
      o.c = C[Math.max(2, top - 3)];
      o.k = 0.12 * k * end;
      o.l = C[top - 2];
      return;
    }
    const sx = (s + flow) / cs;
    if (s < bandE) {
      // the crest: a solid white leading edge, then foam with a few dark holes
      const q = s / Math.max(1, bandE);
      const f = tileNoise(sx, along / 3, loopP, 0, seed + 1) * 0.7 + tileNoise(sx * 2, along / 1.6, loopP * 2, 0, seed + 2) * 0.3;
      const need = -1.2 + q * q * 1.3 + (1 - k) * 2.2 + (1 - end) * 0.7;
      if (f < need && (q > 0.2 || k < 0.7)) return;
      const hot = q < 0.3 ? top : f > 0.15 ? top - 1 : top - 2;
      // lit from the top left: the lower half of the crest a step darker behind its edge
      o.c = C[clamp(hot - (y > 0 && q > 0.5 ? 1 : 0), 0, top)];
      o.k = light * k * end * (1 - q * 0.5);
      o.l = C[top - 1];
      return;
    }
    const u = (s - bandE) / Math.max(1, trail);
    if (u > 1) return;
    // the body: a sheet of water whose back edge is ragged, streaked by the flow and laced with foam; past its
    // edge only lace is left, thinning out
    const edge = (0.5 + 0.35 * tileNoise(along / 9, 0.5, 0, 0, seed + 5)) * (0.4 + 0.6 * k);
    const lc = tileNoise(sx, along / 3.5, loopP, 0, seed + 4);
    const net = 1 - Math.abs(lc) * 5;
    const ln = net - u * 0.9 - (1 - k) * 0.8 - (1 - end) * 0.4;
    if (ln > 0.25) {
      o.c = C[ln > 0.5 ? top - 1 : top - 2];
      o.k = 0.2 * k * (1 - u) * end;
      o.l = C[top - 2];
      return;
    }
    if (u > edge) return;
    const st = tileNoise(sx / 2, along / 1.2, loopP ? loopP / 2 : 0, 0, seed + 3);
    const ue = u / Math.max(0.01, edge);
    let lvl = ue < 0.2 ? top - 3 : ue < 0.65 ? top - 4 : top - 5;
    if (st > 0.4) lvl += 1;
    if (y > 0 && ue > 0.3) lvl -= 1;
    o.c = C[clamp(lvl, 1, top)];
    o.a = ue > 0.85 ? 0.6 : 1;
    o.k = 0.05 * k * (1 - ue);
    o.l = C[top - 3];
  });
}
