class_name AllyFx
extends RefCounted
## VFX des ALLIÉS atténués (coop 1-4, docs/multi/Design_Coop.md §4.2) : les sorts d'un autre joueur sont tracés à
## Palette.ALLY_VFX_ALPHA (0,55 ; 0,35 en qualité Basse) pour que les siens et les télégraphes ennemis restent lisibles.
## Jamais atténués : les télégraphes ennemis, et les BORDS des zones persistantes alliées (on doit savoir où marcher).
## Solo, ou un effet du joueur local : 1,0 (aucun changement).
## Usage : `node.modulate.a *= AllyFx.alpha_for(owner_slot)` ou `AllyFx.apply(node, owner_slot)`.


## Opacité d'un effet appartenant au joueur `owner_slot` (-1 / Events.NO_PLAYER : inconnu, donc 1,0).
static func alpha_for(owner_slot: int) -> float:
	if owner_slot < 0 or not LocalState.is_coop() or owner_slot == Players.local_id():
		return 1.0
	return Palette.ally_vfx_alpha(Quality.tier == Quality.Tier.LOW)


## Multiplie l'alpha de modulate de `node` ; retourne le facteur appliqué.
static func apply(node: CanvasItem, owner_slot: int) -> float:
	var a := alpha_for(owner_slot)
	if a < 1.0 and node != null:
		var m := node.modulate
		m.a *= a
		node.modulate = m
	return a
