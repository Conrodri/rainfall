shader_type canvas_item;
// Émission des décalques de sol v2 (atlas `decals_e.png`, même grille que `decals.png`) : même MultiMesh que
// les décalques, unshaded + additif (échappe au CanvasModulate, nourrit le glow), pulsation lente facultative.
render_mode unshaded, blend_add;

uniform vec2 atlas_grid = vec2(4.0, 4.0);
uniform float energy = 1.6;
uniform float pulse_hz = 0.0; // 0 = fixe ; grotte : 0,12 Hz (docs/Design_Etage2_Grotte.md)
uniform float pulse_depth = 0.35;

varying float v_alpha;
varying float v_phase;

void vertex() {
	float idx = INSTANCE_CUSTOM.x;
	vec2 cell = vec2(mod(idx, atlas_grid.x), floor(idx / atlas_grid.x));
	UV = (UV + cell) / atlas_grid;
	v_alpha = INSTANCE_CUSTOM.y;
	v_phase = INSTANCE_CUSTOM.z * 6.2831853;
}

void fragment() {
	vec4 e = texture(TEXTURE, UV);
	float p = 1.0 - pulse_depth * 0.5 * (1.0 + sin(TIME * pulse_hz * 6.2831853 + v_phase)) * step(0.0001, pulse_hz);
	COLOR = vec4(e.rgb * energy * p, e.a * v_alpha);
}
