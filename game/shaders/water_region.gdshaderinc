// Bords organiques (31/10/2026) : un seul quad par couche d'eau couvre la carte ; `region_tex` est le masque
// cuit et lissé (GroundSplat.bake_water_mask : R eau profonde, G eau peu profonde, B sol praticable) et
// `region_chan` choisit le canal. Le bord est le seuil 0,5 du masque lissé, déformé par le bruit tuilable du
// sol (`warp_tex`), adouci par smoothstep : plus de bord de case, aucune boucle par image.
uniform bool use_region = false;
uniform sampler2D region_tex : filter_linear, repeat_disable;
uniform vec4 region_chan = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec2 region_inv_size = vec2(1.0);
uniform sampler2D warp_tex : filter_linear, repeat_enable;
uniform vec2 warp_offset = vec2(0.0);
uniform float warp_inv_px = 0.0006; // 1 / période du bruit en px (période du bruit du sol / 6)
uniform float warp_amount = 0.9;
uniform float edge_soft = 0.1;
uniform int warp_detail = 1; // 0 une octave (Bas), 1 deux octaves

// Valeur du masque après déformation (0,5 = bord de l'eau) ; `uv` = position dans la carte, en 0..1.
float region_value(vec2 uv, vec2 loc) {
	float d = dot(texture(region_tex, uv), region_chan);
	vec2 q = loc * warp_inv_px + warp_offset;
	float nz = texture(warp_tex, q).r - 0.5;
	if (warp_detail > 0) {
		nz = nz * 0.7 + (texture(warp_tex, q * 1.9 + 0.37).g - 0.5) * 0.22;
	}
	return d + nz * warp_amount;
}
