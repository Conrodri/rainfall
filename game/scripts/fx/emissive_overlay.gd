class_name EmissiveOverlay
extends AnimatedSprite2D
## AnimatedSprite2D diffus (éclairage plat, sans normales) avec masque d'émission <f>_e.png affiché
## par-dessus, additif et unshaded (shader emissive.gdshader), synchronisé frame par frame.
## Réutilise le helper d'ambiance NormalMaps (aucune logique dupliquée).
##
## En scène : poser le script sur un AnimatedSprite2D dont `sprite_frames` est assigné ;
## l'émission est branchée au _ready. Changement de ressource : set_frames().
## Sans code de nœud : EmissiveOverlay.apply(anim, frames, énergie) sur n'importe quel AnimatedSprite2D.
## SpriteFrames partagés : le .tres chargé est gardé tel quel, l'émission est en cache par chemin.

@export var emission_energy := 2.0


func _ready() -> void:
	if sprite_frames != null:
		apply(self, sprite_frames, emission_energy)


func set_frames(frames: SpriteFrames) -> void:
	apply(self, frames, emission_energy)


## `frames` = la ressource d'origine (.tres chargé), jamais une version déjà convertie.
static func apply(anim: AnimatedSprite2D, frames: SpriteFrames, energy: float = 2.0) -> void:
	if anim == null or frames == null:
		return
	anim.set_meta(RenderStyle.META_SRC, frames.resource_path) # bascule de style à chaud (RenderStyle.restyle_sprite)
	anim.set_meta(RenderStyle.META_ENERGY, energy)
	anim.sprite_frames = frames
	NormalMaps.apply_to_animated(anim, energy)
	var em := anim.get_node_or_null(NodePath(NormalMaps.EMISSION_NODE)) as AnimatedSprite2D
	if em != null:
		em.visible = NormalMaps.emission_frames(frames) != null
		NormalMaps.set_emission_energy(anim, energy)
