shader_type canvas_item;
// Passe d'émission de la chaîne (masque <planche>_e.png rendu dans Blender) : unshaded, additive,
// energy > 1 nourrit le glow HDR. Même découpage que arpenteuse_chain.gdshader.
render_mode unshaded, blend_add;

uniform sampler2D emit_tex : filter_linear;
uniform float frames = 4.0;
uniform float frame = 0.0;
uniform float u_offset = 0.0;
uniform float energy = 2.0;

void fragment() {
	float u = fract(UV.x * frames + u_offset);
	vec2 uv = vec2((floor(frame) + clamp(u, 0.002, 0.998)) / frames, UV.y);
	vec4 e = texture(emit_tex, uv) * COLOR;
	COLOR = vec4(e.rgb * energy, e.a);
}
