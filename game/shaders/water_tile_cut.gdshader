shader_type canvas_item;
// Tuiles d'eau profonde du Decor (sol v2, 31/10/2026) découpées par le même bord organique que l'eau
// d'ambiance et la rive : l'alpha de la tuile est multiplié par le masque lissé déformé (water_region.gdshaderinc).
// `map_x`, `map_y`, `map_o` : transformation MONDE (repère du canevas) -> repère carte (coin haut-gauche de la grille
// à l'origine), recalculée à la construction de la carte.
// 12/11/2026 : on part de MODEL_MATRIX * VERTEX et non de VERTEX seul. Un TileMapLayer dessine ses tuiles par
// quadrants de rendu (16 x 16 tuiles), chacun étant un élément de canevas décalé au centre de sa première tuile :
// VERTEX y est relatif au quadrant, pas à la couche. Le masque était donc décalé de plusieurs cases (d'autant plus
// loin du quadrant 0) et des losanges d'eau bleu sombre à bords droits débordaient sur le sol (« énormes carrés
// bleus » signalés par le joueur).

#include "res://shaders/water_region.gdshaderinc"
uniform vec2 map_x = vec2(1.0, 0.0);
uniform vec2 map_y = vec2(0.0, 1.0);
uniform vec2 map_o = vec2(0.0);

varying vec2 local;

void vertex() {
	vec2 w = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	local = map_x * w.x + map_y * w.y + map_o;
}

void fragment() {
	COLOR.a *= smoothstep(0.5 - edge_soft, 0.5 + edge_soft, region_value(local * region_inv_size, local));
}
