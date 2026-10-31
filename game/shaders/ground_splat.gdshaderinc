// Sol v2 (GroundSplat, scripts/stage/ground_splat.gd) : un seul quad par carte, en repère CARTE
// (enfant de Visual, tourné de 45° puis écrasé par la caméra iso). Aucun motif de grille propre au
// rendu : 4 matières vues de dessus, tuilables, mélangées par
//   - un masque de carte (mask_tex, cuit au chargement depuis la grille ASCII, lissé) :
//     R = sol (hors vide), G = humidité (proximité de l'eau), B = proximité des murs, A = eau peu profonde ;
//   - un bruit tuilable basse fréquence (noise_tex, cuit une fois par session) : taches de matière,
//     variation macro de valeur et de teinte qui casse la répétition des textures.
// Transitions « par hauteur » : la luminance des textures découpe le bord des taches (organique).
// Paliers (QUALITY défini par le shader enveloppe) : 0 Bas = 2 matières, 1 bruit ; 1 Moyen = 4 matières,
// 2 bruits ; 2 Haut = Moyen + anti-répétition des matières organiques (2e échantillon tourné).
// Coût fixe par pixel, rien de calculé par image côté CPU.

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform sampler2D tex0 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex1 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex2 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex3 : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 layer_inv_px = vec4(0.00390625); // 1 / (taille d'une répétition en px carte), par matière
uniform vec3 tint0 = vec3(1.0); // multiplicateur (pas une couleur : pas de conversion sRGB)
uniform vec3 tint1 = vec3(1.0); // multiplicateur (pas une couleur : pas de conversion sRGB)
uniform vec3 tint2 = vec3(1.0); // multiplicateur (pas une couleur : pas de conversion sRGB)
uniform vec3 tint3 = vec3(1.0); // multiplicateur (pas une couleur : pas de conversion sRGB)
uniform vec2 map_origin = vec2(0.0); // coin haut-gauche de la grille (px carte)
uniform vec2 map_inv_size = vec2(0.000244140625); // 1 / taille de la grille (px carte)
uniform float noise_inv_px = 0.00048828125; // 1 / période du bruit macro (px carte)
uniform vec2 noise_offset = vec2(0.0); // décalage par carte (graine)
uniform float patch_cover = 0.45; // part du sol couverte par la matière 1 (taches)
uniform float wet_amount = 1.0; // matière 2 près de l'eau
uniform float wall_amount = 1.0; // matière 3 au pied des murs
uniform float macro_value = 0.16; // ± variation de valeur basse fréquence
uniform vec3 macro_tint = vec3(1.0); // multiplicateur vers lequel tirent les zones « hautes » du bruit
uniform float macro_tint_amount = 0.0;
uniform float edge_ao = 0.28; // assombrissement au pied des murs
uniform vec3 shallow_tint : source_color = vec3(0.33, 0.44, 0.48);
uniform float shallow_alpha = 0.45;
uniform float blend_sharp = 5.0; // netteté des bords de taches
uniform float height_k = 1.4; // influence de la luminance des textures sur le bord des taches

varying vec2 mp;

void vertex() {
	mp = VERTEX;
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Mélange par hauteur : w (0..1, lisse) devient un bord net et organique découpé par la luminance.
vec3 hblend(vec3 base, vec3 layer, float w) {
	float h = (lum(layer) - lum(base)) * height_k;
	float k = clamp((w - 0.5) * blend_sharp + 0.5 + h, 0.0, 1.0);
	return mix(base, layer, k * step(0.001, w));
}

vec3 sample_layer(sampler2D t, vec2 uv, float n) {
#if QUALITY >= 2
	// anti-répétition : 2e lecture tournée de 90° et décalée, mêlée selon le bruit
	vec2 uv2 = vec2(-uv.y, uv.x) + vec2(0.37, 0.61);
	return mix(texture(t, uv).rgb, texture(t, uv2).rgb, smoothstep(0.35, 0.65, n));
#else
	return texture(t, uv).rgb;
#endif
}

void fragment() {
	vec4 m = texture(mask_tex, (mp - map_origin) * map_inv_size);
	vec2 nuv = mp * noise_inv_px + noise_offset;
	vec2 n = texture(noise_tex, nuv).rg; // r : macro, g : taches
#if QUALITY >= 1
	// 2e octave tournée (décorrélée) : bords de taches et matières de bord
	vec2 n2 = texture(noise_tex, mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * nuv * 3.7 + vec2(0.29, 0.71)).rg;
#else
	vec2 n2 = n.gr;
#endif
	vec3 c = texture(tex0, mp * layer_inv_px.x).rgb * tint0;
	// matière 1 : taches macro sur tout le sol
	// (même famille que la 0 : fondu large, sans bord découpé, sinon effet « camouflage »)
	float w1 = smoothstep(0.0, 1.0, clamp((mix(n.g, n2.r, 0.35) - (1.0 - patch_cover)) * 2.2 + 0.5, 0.0, 1.0));
	c = mix(c, texture(tex1, mp * layer_inv_px.y).rgb * tint1, w1);
#if QUALITY >= 1
	// matière 2 : humidité près de l'eau, plus quelques flaques de bruit
	float w2 = clamp(m.g * 1.5 * wet_amount + (n2.g - 0.5) * 0.9 - 0.35, 0.0, 1.0);
	c = hblend(c, sample_layer(tex2, mp * layer_inv_px.z, n.r) * tint2, w2);
	// matière 3 : pied des murs
	float w3 = clamp(m.b * 1.5 * wall_amount + (n2.r - 0.5) * 0.8 - 0.3, 0.0, 1.0);
	c = hblend(c, sample_layer(tex3, mp * layer_inv_px.w, n2.g) * tint3, w3);
#endif
	// variation macro : valeur et teinte basse fréquence (aucune case ne ressemble à sa voisine)
	c *= 1.0 + (n.r - 0.5) * 2.0 * macro_value;
	c = mix(c, c * macro_tint * 1.6, clamp((n.r - 0.5) * 2.0, 0.0, 1.0) * macro_tint_amount);
	c *= 1.0 - edge_ao * m.b * m.b;
	// film d'eau peu profonde « , » : bords lissés, plus de losanges
	c = mix(c, c * 0.55 + shallow_tint * 0.35, smoothstep(0.2, 0.6, m.a) * shallow_alpha);
	// sol uniquement hors du vide : bord arrondi et légèrement irrégulier
	float land = smoothstep(0.22, 0.42, m.r + (n2.g - 0.5) * 0.12);
	COLOR = vec4(c, land);
}
