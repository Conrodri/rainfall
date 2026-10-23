shader_type canvas_item;
// Repère au sol (GroundMarker) : cercle fin en mélange normal (reste lisible sur sol clair),
// non éclairé. Même pulsation que ground_marker_glow.gdshader.
render_mode unshaded, blend_mix;

uniform vec4 tint : source_color = vec4(1.0, 0.93, 0.8, 0.5);
uniform float pulse_amp = 0.0;
uniform float pulse_hz = 0.55;

varying float v_k;

void vertex() {
	vec2 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float s = sin(TIME * 6.2831853 * pulse_hz + dot(wp, vec2(0.031, 0.047)));
	v_k = 1.0 + pulse_amp * s;
	VERTEX *= 1.0 + 0.22 * pulse_amp * s;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(tint.rgb, t.a * tint.a * clamp(v_k, 0.0, 2.0));
}
