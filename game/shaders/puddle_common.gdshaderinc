// Eau et flaques (World z -18, §1.3, §2) : gradient de ciel reflété + ondulations (normal map
// `ripple_normal_256` défilée 2 fois, exposée en NORMAL_MAP : les lumières à bit 2 s'y
// reflètent) ; mode 2 (Haut) : miroir simplifié des entités (relecture décalée et ondulée de
// l'écran). `mask_mode` : 0 rectangle plein (cases « , » et « ~ »), 1 masque `puddle_mask_1024`
// (flaques du sol, R = flaque). `flash` : remplissage blanc à l'éclair.

#include "res://shaders/ldr_blend.gdshaderinc"
uniform sampler2D ripples : repeat_enable, filter_linear;
uniform bool has_ripples = false;
uniform sampler2D sky : filter_linear;
uniform bool has_sky = false;
uniform sampler2D mask : repeat_enable, filter_linear;
uniform int mask_mode = 0;
#ifdef MIRROR
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
#endif
uniform int mode = 1; // 0 ciel + ondulation, 1 + lumières, 2 + miroir
uniform float strength = 0.4;
uniform float sky_amount = 0.3;
uniform float mirror_alpha = 0.25;
uniform vec4 base_tint : source_color = vec4(0.6, 0.7, 0.8, 1.0);
uniform vec2 offset_a = vec2(0.0);
uniform vec2 offset_b = vec2(0.0);
uniform float tile_px = 256.0;
uniform float mask_tile_px = 1024.0;
uniform float sky_scroll = 0.0;
uniform float mirror_offset_uv = 0.03;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(0.86, 0.89, 1.0, 1.0);
// Eau profonde : reflets mouvants (texture Codex `water_caustics_512`, 2 couches défilées et multipliées ->
// éclats épars qui bougent). caustic_amount = 0 : désactivé (flaques, eau peu profonde).
uniform sampler2D caustics : repeat_enable, filter_linear;
uniform float caustic_amount = 0.0;
uniform float caustic_tile_px = 960.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float m = 1.0;
	if (mask_mode == 1) {
		m = texture(mask, world / mask_tile_px).r;
	}
	vec2 n = vec2(0.0);
	if (has_ripples) {
		vec2 n1 = texture(ripples, (world + offset_a) / tile_px).rg * 2.0 - 1.0;
		vec2 n2 = texture(ripples, (world + offset_b) / (tile_px * 0.73)).rg * 2.0 - 1.0;
		n = (n1 + n2) * 0.5;
	}
	vec3 col = base_tint.rgb;
	if (has_sky) {
		vec2 suv = vec2(fract(world.x / 4096.0 + sky_scroll), fract(world.y / 1024.0) * 0.2 + 0.4 + n.y * 0.05);
		col = mix(col, texture(sky, suv).rgb, sky_amount);
	}
	if (mode >= 1) {
		NORMAL_MAP = normalize(vec3(n * 0.8, 1.0)) * 0.5 + 0.5;
	}
#ifdef MIRROR
	if (mode >= 2) {
		vec3 refl = texture(screen_tex, SCREEN_UV + vec2(n.x * 0.006, mirror_offset_uv + n.y * 0.006)).rgb;
		col = mix(col, refl, mirror_alpha);
	}
#endif
	if (caustic_amount > 0.0) {
		vec4 t1 = texture(caustics, (world + offset_a * 0.6) / caustic_tile_px);
		vec4 t2 = texture(caustics, (world.yx + offset_b * 0.5) / (caustic_tile_px * 0.77));
		float c1 = t1.r * t1.a;
		float c2 = t2.r * t2.a;
		col += vec3(0.55, 0.78, 0.9) * smoothstep(0.12, 0.5, c1 * c2) * caustic_amount; // croisements seuls : éclats épars
	}
	col = mix(col, flash_color.rgb, flash);
	COLOR = vec4(col, ldr_alpha(clamp(strength * m + flash * 0.5 * m, 0.0, 1.0), col));
}
