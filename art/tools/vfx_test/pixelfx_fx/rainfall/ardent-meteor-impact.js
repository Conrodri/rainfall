// Rainfall (iso camera, drawn in screen space): where one of Ardent's meteors lands (the fall itself is
// ardent-meteor-fall). The nova's recipe (ardent-nova.js) small and violent: a white flash, a plume of fire balls
// thrown straight up, rock chunks flung out, a ring of fire racing over a 2:1 floor ellipse to the impact radius,
// a cooling crater, embers and smoke.
import { makeBlast, PAL } from "./ardent-nova.js";

export const meta = {
  name: "Ardent meteor impact",
  desc: "Iso meteor impact: a flash, a plume of fire thrown straight up, rock chunks flung out, a ring of fire racing over a small 2:1 floor ellipse, a cooling crater and smoke.",
  tags: ["rainfall", "fire", "meteor", "impact", "aoe", "iso", "one-shot"],
  size: [96, 112],
  origin: [48, 80],
  duration: 1.4,
  loop: false,
  fps: 30,
  bg: "dark",
  options: {
    palette: PAL,
    radius: 26,
    flame: 15,
    run: 0.14,
    burn: 0.4,
    hold: 0,
    tongues: 26,
    plume: 1,
    debris: 9,
    seed: 3,
  },
};

export function create(o) {
  return makeBlast(o, meta.duration);
}
