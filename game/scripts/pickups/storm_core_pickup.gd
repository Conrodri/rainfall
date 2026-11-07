class_name StormCorePickup
extends GroundPickup
## Noyau d'orage au sol (Forge, docs/Design_Forge.md) : posé à la mort d'un boss d'étage 1-4 et à l'ouverture du
## reliquaire secret. Ramassable seulement par son propriétaire (`player`), au contact, avec un petit glissement
## vers lui (Balance.CRAFT_CATALYST_MAGNET_*). N'expire pas. Un noyau non ramassé est crédité au départ de l'étage
## (RunState.flush_pending_catalysts) : PlayerState.pending_catalysts le garde en attendant.
## Hérite de GroundPickup (groupe `ground_pickups`) : le groupe `pickups` est réservé au PickupManager (or/XP).

const TEX_PATH := "res://assets/sprites/pickups/storm_core.png"
const ICON_PATH := "res://assets/sprites/icons/storm_core.png"
const EMIT_PATH := "res://assets/sprites/pickups/storm_core_e.png" ## masque d'émission (additif, non éclairé)
const SHADOW_PATH := "res://assets/sprites/pickups/storm_core_shadow.png" ## ombre cuite (même cadrage que le diffus)
const EMIT_ENERGY := 1.4
const NEVER_S := 1.0e9

var state: PlayerState = null
var _vis: Sprite2D = null
var _emit: Sprite2D = null


## Pose un noyau pour `st` (porté par `owner_node`) à `at` si la place le permet. Retourne le pickup, ou null si
## aucun pickup n'a pu être posé (pas de nœud joueur vivant, plafond atteint, pas de parent) : l'appelant crédite
## alors directement via `award`.
static func drop(parent: Node, at: Vector2, st: PlayerState, owner_node: Node2D) -> StormCorePickup:
	if parent == null or st == null or owner_node == null or not is_instance_valid(owner_node) \
			or _is_dead(owner_node) or st.catalyst_room() <= 0:
		return null
	var c := StormCorePickup.new()
	c.state = st
	c.player = owner_node
	c.life_s = NEVER_S
	c.contact_u = Balance.CRAFT_CATALYST_CONTACT_U
	c.on_collect = c._on_collected
	parent.add_child(c)
	c.global_position = at
	c._make_core_visual()
	GroundMarker.attach(c, 0.45, true)
	st.pending_catalysts += 1
	return c


## Crédite (ou pose) un noyau à ce joueur : pickup si son nœud est vivant, sinon crédit direct (spectateur : il peut
## forger, docs/Design_Forge.md §coop). Retourne le nombre de noyaux gagnés ou posés (0 = plafond atteint).
static func award(parent: Node, at: Vector2, st: PlayerState, owner_node: Node2D) -> int:
	if drop(parent, at, st, owner_node) != null:
		return 1
	if owner_node != null and is_instance_valid(owner_node) and not _is_dead(owner_node):
		return 0 # joueur vivant mais plafond atteint : rien à poser
	return st.add_catalyst(1) if st != null else 0


static func _is_dead(n: Node) -> bool:
	return n.get(&"dead") == true


func _make_core_visual() -> void:
	if not ResourceLoader.exists(TEX_PATH):
		return
	_vis = Sprite2D.new()
	_vis.texture = load(TEX_PATH)
	_vis.scale = Iso.UNSQUASH * Iso.SPRITE_K
	_vis.offset = Vector2(0.0, -float(_vis.texture.get_height()) * 0.32) # le point d'appui du noyau (bas de la sphère, ~y 80/96) tombe sur l'origine du nœud
	if ResourceLoader.exists(SHADOW_PATH): # ombre cuite : décalque sous le noyau, même cadrage, jamais éclairé
		var sh := Sprite2D.new()
		sh.name = &"BakedShadow"
		sh.texture = load(SHADOW_PATH)
		sh.scale = _vis.scale
		sh.offset = _vis.offset
		sh.light_mask = 0
		sh.z_index = -1
		add_child(sh)
	add_child(_vis)
	if ResourceLoader.exists(EMIT_PATH): # émission cyan par-dessus, additive, indépendante de l'éclairage 2D
		_emit = Sprite2D.new()
		_emit.name = &"Emission"
		_emit.texture = load(EMIT_PATH)
		_emit.offset = _vis.offset # enfant de _vis : échelle et teinte héritées, seul le décalage se répète
		var cm := CanvasItemMaterial.new()
		cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		cm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_emit.material = cm
		_emit.modulate = Color(EMIT_ENERGY, EMIT_ENERGY, EMIT_ENERGY, 1.0)
		_vis.add_child(_emit)
	# Coop : teinte de la couleur d'équipe du propriétaire (Palette.team_color, redondance : le chiffre est sur la plaque).
	var base := Color.WHITE
	if Players.count() > 1 and state != null:
		base = Color.WHITE.lerp(Palette.team_color(state.slot), 0.55)
	var tw := create_tween().set_loops()
	tw.tween_property(_vis, "modulate", Color(base.r * 1.35, base.g * 1.35, base.b * 1.6), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_vis, "modulate", base, 0.7).set_trans(Tween.TRANS_SINE)


func step(delta: float) -> void:
	if player != null and is_instance_valid(player) and not _is_dead(player):
		var d := player.global_position.distance_to(global_position)
		var m := Balance.CRAFT_CATALYST_MAGNET_U * Balance.UNIT_PX
		if d <= m and d > 1.0:
			global_position = global_position.move_toward(player.global_position,
					Balance.CRAFT_CATALYST_MAGNET_SPEED_U * Balance.UNIT_PX * delta)
	super.step(delta)


func _on_collected(_g: GroundPickup) -> void:
	if state == null:
		return
	state.pending_catalysts = maxi(state.pending_catalysts - 1, 0)
	state.add_catalyst(1)
	_play_gain_sound()
	_announce()


## Son de gain : seulement pour un joueur local.
func _play_gain_sound() -> void:
	if not is_inside_tree():
		return
	var e: Variant = Players.entry(state.slot) if Players.count() > 1 else null
	if e != null and not e.is_local:
		return
	Audio.play_ui(&"storm_core_gain")


## Annonce de ramassage : toast d'AchievementToast (hébergé par MetaTracker) « Noyau d'orage +1 » et compteur x/2.
## Aucune annonce pour un joueur distant (réseau) ni sans toast (tests).
func _announce() -> void:
	if not is_inside_tree():
		return
	var toast := get_tree().root.find_child("AchievementToast", true, false) as AchievementToast
	if toast == null:
		return
	var coop := Players.count() > 1
	var e: Variant = Players.entry(state.slot) if coop else null
	if e != null and not e.is_local:
		return
	var tex: Texture2D = load(ICON_PATH) if ResourceLoader.exists(ICON_PATH) else null
	var who := ("Joueur %d · " % (state.slot + 1)) if coop else ""
	toast.push("Noyau d'orage +1", "%s%d/%d · forge dans l'inventaire (TAB)" % [who, state.catalysts, Balance.CRAFT_CATALYST_CAP], tex)
