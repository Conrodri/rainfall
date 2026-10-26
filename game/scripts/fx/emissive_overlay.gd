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
	var ef := NormalMaps.emission_frames(frames)
	var old := anim.get_node_or_null(NodePath(NormalMaps.EMISSION_NODE)) as AnimatedSprite2D
	# L'enfant Emission d'une ressource précédente (ex. scène du joueur = Ardent, puis Arpenteuse) doit être recalé
	# AVANT le changement du diffus : la synchro (animation_changed) lui ferait jouer une anim absente de ses
	# anciennes frames (« Animation 'plant_e' doesn't exist »). Sans émission, il est retiré et déconnecté.
	if old != null:
		if ef == null:
			_remove_emission(anim, old)
		elif old.sprite_frames != ef:
			old.sprite_frames = ef
	anim.sprite_frames = frames
	if ef == null:
		return
	NormalMaps.apply_to_animated(anim, energy)
	var em := anim.get_node_or_null(NodePath(NormalMaps.EMISSION_NODE)) as AnimatedSprite2D
	if em != null:
		em.visible = true
		NormalMaps.set_emission_energy(anim, energy)


## Retire l'enfant Emission et ses connexions de synchro (bindées sur `em` par NormalMaps.apply_to_animated).
static func _remove_emission(anim: AnimatedSprite2D, em: AnimatedSprite2D) -> void:
	for sig: Signal in [anim.frame_changed, anim.animation_changed, anim.item_rect_changed]:
		for c: Dictionary in sig.get_connections():
			var cb: Callable = c["callable"]
			if cb.get_bound_arguments().has(em):
				sig.disconnect(cb)
	anim.remove_child(em)
	em.queue_free()
