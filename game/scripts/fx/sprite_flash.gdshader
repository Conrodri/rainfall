shader_type canvas_item;
// Flash blanc au coup : le drapeau est passé par la modulation (COLOR.r > 1.5, ex. Color(2,2,2)),
// donc un seul ShaderMaterial partagé par tous les sprites (pas de paramètre par instance).
// Armement d'un coup (EnemyVisual.set_charge, docs/Comportements_Monstres.md) : alpha de modulation > 1
// = lueur chaude additive (0 à 1 pour alpha 1 à 2) ; l'alpha rendu reste celui de la texture. Le même alpha
// > 1 avive aussi l'enfant Emission (additif, non éclairé) : lisible même sur un corps sombre la nuit.
// Éclairage 2D plat (aucune normal map depuis le 22/10/2026).
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float f = step(1.5, COLOR.r);
	float g = clamp(COLOR.a - 1.0, 0.0, 1.0);
	vec3 c = t.rgb * COLOR.rgb + vec3(0.85, 0.38, 0.10) * g;
	COLOR = vec4(mix(c, vec3(1.0), f), t.a * min(COLOR.a, 1.0));
}
