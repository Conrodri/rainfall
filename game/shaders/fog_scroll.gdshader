shader_type canvas_item;
// Brume plein écran (§2, §5) : 1 à 2 calques défilants d'une texture raccordable, ancrés au monde
// (le rectangle suit la caméra). Non éclairée. Basse : World z -14 (sous les entités). Haute :
// World z 20 avec un masque radial qui dégage `clear_radius` px autour du joueur.
// Masque de hauteur optionnel (par carte, Haut) : plus dense dans les creux.
render_mode unshaded;
#include "res://shaders/ldr_blend.gdshaderinc"

uniform sampler2D fog_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D fog_b : repeat_enable, filter_linear_mipmap;
uniform int layers = 1;
uniform vec4 color_a : source_color = vec4(0.8, 0.83, 0.8, 1.0);
uniform vec4 color_b : source_color = vec4(0.84, 0.86, 0.82, 1.0);
uniform float opacity_a = 0.08;
uniform float opacity_b = 0.04;
uniform float tile_px = 1024.0;
uniform vec2 offset_a = vec2(0.0);
uniform vec2 offset_b = vec2(0.0);
uniform vec2 clear_center = vec2(0.0);
uniform float clear_radius = 0.0;
uniform sampler2D height_mask : filter_linear;
uniform bool use_height_mask = false;
uniform vec4 map_rect = vec4(0.0, 0.0, 1.0, 1.0); // origine (xy) et taille (zw) de la carte, px monde

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float a = texture(fog_a, (world + offset_a) / tile_px).a * opacity_a;
	vec3 col = color_a.rgb;
	if (layers > 1) {
		float b = texture(fog_b, (world + offset_b) / (tile_px * 0.7)).a * opacity_b;
		col = mix(col, color_b.rgb, b / max(a + b, 0.0001));
		a = a + b;
	}
	if (use_height_mask) {
		a *= 0.5 + texture(height_mask, (world - map_rect.xy) / map_rect.zw).r;
	}
	if (clear_radius > 0.0) {
		a *= smoothstep(clear_radius * 0.6, clear_radius, distance(world, clear_center));
	}
	COLOR = vec4(col, ldr_alpha(clamp(a, 0.0, 0.15), col)); // §0 règle 6 : densité plein écran <= 15 % (équivalent HDR en LDR)
}
