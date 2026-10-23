shader_type canvas_item;
// Palier Bas (§5) : vignette seule, multiply, sans lecture de l'écran (1 draw). Utilise la
// texture Blender `vignette_1024` si elle est fournie (alpha = assombrissement), sinon le même
// calcul radial que grading.gdshader.
render_mode unshaded, blend_mul;

uniform sampler2D vignette_tex : filter_linear;
uniform bool use_tex = false;
uniform float vignette_strength = 0.25;
uniform float vignette_radius = 0.75;
uniform float vignette_softness = 0.5;
uniform vec3 vignette_color : source_color = vec3(0.1);
uniform float aspect = 1.7778;

void fragment() {
	float v;
	if (use_tex) {
		v = texture(vignette_tex, UV).a;
	} else {
		vec2 d = (UV - 0.5) * vec2(aspect, 1.0) / (0.5 * length(vec2(aspect, 1.0)));
		v = smoothstep(vignette_radius - vignette_softness * 0.5, vignette_radius + vignette_softness * 0.5, length(d));
	}
	COLOR = vec4(mix(vec3(1.0), vignette_color, v * vignette_strength), 1.0);
}
