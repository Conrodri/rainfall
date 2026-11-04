// Rainfall (iso camera, drawn in screen space): Ardent's ultimate, the Brasier. The nova's recipe (ardent-nova.js)
// at the ultimate's size: a burning front races out over a 2:1 floor ellipse to a wide radius, a sea of tall flames
// stands up out of the whole disc and holds, flame puffs roll up, then it burns down into embers and smoke.
import { makeBlast, PAL } from "./ardent-nova.js";

export const meta = {
  name: "Ardent brasier",
  desc: "Iso ultimate blaze: a burning front races out over a wide 2:1 floor ellipse, a sea of tall flames stands up over the whole disc and holds, then burns down into smoke.",
  tags: ["rainfall", "fire", "nova", "ultimate", "aoe", "iso", "one-shot"],
  size: [168, 150],
  origin: [84, 104],
  duration: 2.6,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: PAL,
    radius: 72,
    flame: 44,
    run: 0.42,
    burn: 0.75,
    hold: 0.7,
    tongues: 120,
    plume: 0.5,
    debris: 0,
    seed: 9,
  },
};

export function create(o) {
  return makeBlast(o, meta.duration);
}
