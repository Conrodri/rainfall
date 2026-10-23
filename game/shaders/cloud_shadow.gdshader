shader_type canvas_item;
// Ombres de nuages / de canopée (World z -16, §1.3) : multiply d'une texture raccordable ancrée
// au monde, 1 ou 2 couches en parallaxe, respiration d'échelle (canopée). Sous les entités.
render_mode unshaded, blend_mul;

uniform sampler2D clouds : repeat_enable, filter_linear_mipmap;
uniform float opacity = 0.2;
uniform int layers = 1;
uniform float tile_px = 2048.0;
uniform vec2 offset_a = vec2(0.0);
uniform vec2 offset_b = vec2(0.0);
uniform float scale_mult = 1.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float m = texture(clouds, (world + offset_a) / (tile_px * scale_mult)).a;
	if (layers > 1) {
		m = max(m, texture(clouds, (world + offset_b) / (tile_px * 0.63 * scale_mult)).a * 0.7);
	}
	COLOR = vec4(vec3(1.0 - opacity * m), 1.0);
}
