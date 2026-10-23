shader_type canvas_item;
// Émission (masque <f>_e.png) : unshaded => échappe au CanvasModulate et aux lumières ;
// additif ; energy > 1 nourrit le glow HDR 2D. Utilisé par NormalMaps.apply_to_* (masques _e).
render_mode unshaded, blend_add;

uniform float energy = 2.0;

void fragment() {
	vec4 e = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(e.rgb * energy, e.a); // blend_add multiplie déjà par alpha
}
