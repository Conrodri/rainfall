shader_type canvas_item;
// Tuiles d'eau profonde du Decor (sol v2, 31/10/2026) découpées par le même bord organique que l'eau
// d'ambiance et la rive : l'alpha de la tuile est multiplié par le masque lissé déformé (water_region.gdshaderinc).
// `map_x`, `map_y`, `map_o` : transformation locale de la couche -> repère carte (coin haut-gauche de la grille
// à l'origine), recalculée à la construction de la carte.

#include "res://shaders/water_region.gdshaderinc"
uniform vec2 map_x = vec2(1.0, 0.0);
uniform vec2 map_y = vec2(0.0, 1.0);
uniform vec2 map_o = vec2(0.0);

varying vec2 local;

void vertex() {
	local = map_x * VERTEX.x + map_y * VERTEX.y + map_o;
}

void fragment() {
	COLOR.a *= smoothstep(0.5 - edge_soft, 0.5 + edge_soft, region_value(local * region_inv_size, local));
}
