shader_type canvas_item;
// Décalques de sol v2 (scripts/stage/ground_decals.gd) : un MultiMesh, un draw call. Chaque instance
// lit sa case d'atlas dans INSTANCE_CUSTOM.x (index) et son alpha dans INSTANCE_CUSTOM.y.
uniform vec2 atlas_grid = vec2(4.0, 4.0);

varying float v_alpha;

void vertex() {
	float idx = INSTANCE_CUSTOM.x;
	vec2 cell = vec2(mod(idx, atlas_grid.x), floor(idx / atlas_grid.x));
	UV = (UV + cell) / atlas_grid;
	v_alpha = INSTANCE_CUSTOM.y;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(c.rgb, c.a * v_alpha);
}
