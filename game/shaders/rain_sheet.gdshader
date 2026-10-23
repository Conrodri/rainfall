shader_type canvas_item;
// Calque de pluie (World z 30, §1.3, §5) : texture `rain_sheet_512` (traits verticaux, 3
// densités cuites dans R, G, B), inclinée et défilée en shader, ancrée au monde. 1 ou 2 couches
// (lointaine : traits plus courts, 60 % de l'opacité). Rafales : modulation de densité (CPU).
// Opacité plafonnée à 12 % (§0 règle 5). Non éclairée, sous les télégraphes et l'UI.
render_mode unshaded;
#include "res://shaders/ldr_blend.gdshaderinc"

uniform sampler2D sheet : repeat_enable, filter_linear;
uniform float opacity = 0.05;
uniform float density = 0.3; // 0..1 : choisit le canal R -> G -> B
uniform int layers = 1;
uniform float angle = 0.17; // rad depuis la verticale
uniform float fall_px = 0.0; // défilement cumulé (px), calculé côté CPU
uniform float tile_px = 512.0;
uniform float length_scale = 1.0; // étirement vertical des traits
uniform vec4 tint : source_color = vec4(0.85, 0.9, 1.0, 1.0);

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float sample_layer(vec2 p, float scale, float speed) {
	float ca = cos(angle);
	float sa = sin(angle);
	vec2 r = vec2(ca * p.x - sa * p.y, sa * p.x + ca * p.y);
	r.y = (r.y - fall_px * speed) / length_scale;
	vec3 t = texture(sheet, r / (tile_px * scale)).rgb;
	float d = clamp(density, 0.0, 1.0) * 2.0;
	return d < 1.0 ? mix(t.r, t.g, d) : mix(t.g, t.b, d - 1.0);
}

void fragment() {
	float a = sample_layer(world, 1.0, 1.0);
	if (layers > 1) {
		a = max(a, sample_layer(world + vec2(173.0, 91.0), 0.6, 0.7) * 0.6);
	}
	COLOR = vec4(tint.rgb, ldr_alpha_k(a * min(opacity, 0.12), tint.rgb, 0.25));
}
