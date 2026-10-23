shader_type canvas_item;
// Étalonnage plein écran (CanvasLayer 4, AmbianceManager.LAYER_GRADE), Direction §2 et §5 :
// lift (teinte des ombres), gain (teinte des hautes lumières), contraste autour d'un pivot,
// saturation, vignette (intensité, rayon, douceur, couleur), grain optionnel (aucun par défaut).
// Les couches 5+ (télégraphes, chiffres de dégâts, flash, HUD) ne sont PAS étalonnées.
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform bool linear_input = true; // HDR 2D actif : l'écran est en linéaire
uniform vec3 lift_color : source_color = vec3(0.2);
uniform float lift_amount = 0.0;
uniform vec3 gain_color : source_color = vec3(1.0);
uniform float gain_amount = 0.0;
uniform float contrast = 1.0;
uniform float contrast_pivot = 0.45;
uniform float saturation = 1.0;
uniform float vignette_strength = 0.25;
uniform float vignette_radius = 0.75;
uniform float vignette_softness = 0.5;
uniform vec3 vignette_color : source_color = vec3(0.1);
uniform float aspect = 1.7778; // largeur / hauteur de l'écran
uniform float grain_strength = 0.0;
uniform float time_s = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec3 s = linear_input ? pow(max(c, vec3(0.0)), vec3(1.0 / 2.2)) : c;
	vec3 over = max(s - 1.0, vec3(0.0)); // émissions HDR : préservées pour le glow
	s = min(s, vec3(1.0));
	float l = dot(s, vec3(0.2126, 0.7152, 0.0722));
	float w_shadow = 1.0 - smoothstep(0.0, contrast_pivot * 1.6, l);
	float w_high = smoothstep(contrast_pivot * 0.8, 1.0, l);
	s = mix(s, lift_color, lift_amount * w_shadow);
	s = mix(s, s * gain_color * 1.12, gain_amount * w_high);
	s = (s - contrast_pivot) * contrast + contrast_pivot;
	float l2 = dot(s, vec3(0.2126, 0.7152, 0.0722));
	s = mix(vec3(l2), s, saturation);
	vec2 d = (SCREEN_UV - 0.5) * vec2(aspect, 1.0) / (0.5 * length(vec2(aspect, 1.0)));
	float v = smoothstep(vignette_radius - vignette_softness * 0.5, vignette_radius + vignette_softness * 0.5, length(d));
	s = mix(s, vignette_color, v * vignette_strength);
	if (grain_strength > 0.0) {
		s += (hash(floor(FRAGCOORD.xy) + fract(time_s) * 97.0) - 0.5) * grain_strength;
	}
	s = clamp(s, 0.0, 1.0) + over;
	COLOR = vec4(linear_input ? pow(s, vec3(2.2)) : s, 1.0);
}
