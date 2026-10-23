shader_type canvas_item;
// Rayons de lumière (World z 32, §2) : texture `godray_512x1024`, additive, non éclairée ;
// translation lente et fondu périodique (12 s) pilotés côté CPU via `opacity`.
render_mode unshaded, blend_add;

uniform float opacity = 0.0;
uniform vec4 ray_color : source_color = vec4(1.0, 0.89, 0.71, 1.0);

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(ray_color.rgb * opacity, t.a);
}
