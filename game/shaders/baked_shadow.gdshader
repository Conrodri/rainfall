shader_type canvas_item;
// Ombres cuites (BakedShadows) et ombres de contact (CreatureShadows) : couche MULTIPLICATIVE,
// non éclairée, posée sur le sol et sous les entités. Le masque (0 = lumière, 1 = ombre pleine)
// vient du canal rouge (texture L8 cuite au chargement) ou de l'alpha (décalques <f>_shadow.png,
// disque de contact) selon `mask_from_alpha`. Une seule passe, aucune lecture de l'écran.
render_mode unshaded, blend_mul;

uniform vec4 shadow_color : source_color = vec4(0.1, 0.15, 0.15, 0.7);
uniform float strength = 1.0;
uniform bool mask_from_alpha = false;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float m = mask_from_alpha ? t.a : t.r;
	float a = clamp(m * shadow_color.a * strength * COLOR.a, 0.0, 1.0);
	COLOR = vec4(mix(vec3(1.0), shadow_color.rgb, a), 1.0);
}
