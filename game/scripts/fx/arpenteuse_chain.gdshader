shader_type canvas_item;
// Chaîne de l'Arpenteuse (Line2D en mode TILE) : échantillonne une planche de frames rendue dans Blender
// (chain_tile / chain_snap / chain_rewind, cellules 128×64, rig TOP) ; aucune forme dessinée ici.
// u_offset garde les maillons fixes au sol quand la queue raccourcit (ils ne « rampent » pas) ;
// frame = index de la frame dans la planche. Passe diffuse éclairée à plat (pas de normal map).

uniform float frames = 4.0;
uniform float frame = 0.0;
uniform float u_offset = 0.0;

void fragment() {
	float u = fract(UV.x * frames + u_offset);
	vec2 uv = vec2((floor(frame) + clamp(u, 0.002, 0.998)) / frames, UV.y);
	COLOR = texture(TEXTURE, uv) * COLOR;
}
