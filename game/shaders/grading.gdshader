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
// Brume de chaleur (Ciel « Canicule de cendres ») : ondulation de l'écran lue dans une tuile de bruit gris
// qui défile lentement. haze_amount = décalage max en hauteur d'écran (0 = coupé : aucune lecture de la
// tuile, un seul passage plein écran, pas de copie d'écran en plus). Plus forte vers le bas de l'écran.
uniform sampler2D haze_tex : filter_linear, repeat_enable;
uniform float haze_amount = 0.0;
uniform float haze_scale = 2.5; // répétitions de la tuile par hauteur d'écran

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 suv = SCREEN_UV;
	if (haze_amount > 0.0) {
		vec2 t = vec2(SCREEN_UV.x * aspect, SCREEN_UV.y) * haze_scale;
		float a = texture(haze_tex, t + vec2(0.0, -time_s * 0.035)).r;
		float b = texture(haze_tex, t * 1.3 + vec2(time_s * 0.02, -time_s * 0.05) + vec2(0.37, 0.61)).r;
		// la tuile est quasi plate autour de 0,5 (écart-type ~0,02) : on amplifie l'écart à la moyenne
		vec2 o = clamp((vec2(a, b) - 0.5) * 12.0, -1.0, 1.0);
		suv += vec2(o.x / aspect, o.y) * haze_amount * mix(0.45, 1.0, SCREEN_UV.y);
	}
	vec3 c = texture(screen_tex, suv).rgb;
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
