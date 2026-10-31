shader_type canvas_item;
// Rive organique de l'eau profonde « ~ » (31/10/2026). Un seul quad sur la carte ; la rive suit le même bord
// que l'eau (water_region.gdshaderinc : masque lissé + bruit du sol) : encre cel côté sol, liseré d'écume
// côté eau, ombre de berge qui s'estompe dans l'eau. Uniquement là où la berge est praticable (canal B du
// masque), jamais le long d'un mur. Palette : mêmes valeurs que StageMap.BANK_*.

#include "res://shaders/water_region.gdshaderinc"
uniform vec4 ink_color : source_color = vec4(0.094, 0.071, 0.063, 1.0);
uniform vec4 foam_color : source_color = vec4(0.52, 0.6, 0.66, 0.42);
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.55);
uniform float px_per_unit = 128.0; // largeur d'une case : le masque lissé monte de 0 à 1 sur ~1 case
uniform float ink_px = 7.0;
uniform float foam_px = 7.0;
uniform float shadow_px = 34.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 uv = local * region_inv_size;
	float v = region_value(uv, local);
	float walk = texture(region_tex, uv).b;
	float bank = smoothstep(0.15, 0.45, walk + 0.35 * (1.0 - smoothstep(0.35, 0.5, v)));
	float t = (v - 0.5) * px_per_unit; // px signés, > 0 côté eau
	// encre : juste côté sol
	float ink = smoothstep(-ink_px - 1.0, -ink_px, t) * (1.0 - smoothstep(-1.0, 0.0, t));
	// écume : juste côté eau
	float foam = smoothstep(-1.0, 0.0, t) * (1.0 - smoothstep(foam_px, foam_px + 2.0, t));
	// ombre de berge dans l'eau
	float sh = smoothstep(-1.0, 0.0, t) * (1.0 - clamp(t / shadow_px, 0.0, 1.0));
	vec4 col = vec4(0.0);
	col = mix(col, vec4(shadow_color.rgb, shadow_color.a * sh), step(0.001, sh));
	float fa = foam_color.a * foam;
	col = vec4(mix(col.rgb, foam_color.rgb, fa / max(fa + col.a * (1.0 - fa), 0.0001)), fa + col.a * (1.0 - fa));
	float ia = ink_color.a * ink;
	col = vec4(mix(col.rgb, ink_color.rgb, ia / max(ia + col.a * (1.0 - ia), 0.0001)), ia + col.a * (1.0 - ia));
	COLOR = vec4(col.rgb, col.a * bank);
}
