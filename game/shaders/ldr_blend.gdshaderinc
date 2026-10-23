// Paliers LDR (HDR 2D coupé : Moyen, Bas). Les profils d'ambiance sont calés pour un mélange en
// LINÉAIRE (HDR 2D) : un voile clair peu opaque sur un sol sombre y éclaircit bien plus qu'en sRGB.
// `ldr_alpha` rend l'opacité sRGB équivalente pour un fond de référence (sRGB 0,12, sol éclairé
// moyen des cartes) : la brume, la pluie et les reflets gardent en LDR la présence du rendu HDR.
// Pluie : part de correction réduite (0,25) : traits très clairs, la formule les sur-renforce.
uniform bool ldr = false;
const float LDR_VEIL_K = 0.5; // part de la correction appliquée (calée en capture, render_perf_test)

float ldr_alpha_k(float a, vec3 c, float k) {
	const float B = 0.12;
	const float BL = 0.0094; // 0,12^2,2
	float cs = max(max(c.r, c.g), c.b);
	if (!ldr || cs <= B + 0.02 || a <= 0.0) {
		return a;
	}
	float tot = pow(mix(BL, pow(cs, 2.2), a), 1.0 / 2.2);
	return mix(a, clamp((tot - B) / (cs - B), a, 1.0), k);
}

float ldr_alpha(float a, vec3 c) {
	return ldr_alpha_k(a, c, LDR_VEIL_K);
}
