class_name RaidProp
extends Node2D
## Prop du décor à actionner (condition INTERACT, docs/Design_Boss_Raid.md §1.1) : brasero, vanne, cloche…
## Contrat d'interaction (CONTRACTS.md « Interaction ») : groupe `interactable`, `interact_state()` {visible, enabled,
## label, hold_s} (maintien `hold_s`, 0,6 s), `interact()`, `interact_priority()` 2. Le HUD est le seul à lire
## l'action `interact` (bouton Interagir tactile, touche E, bouton A) : rien à viser. Allumé -> `on_used.call(self)`.

const RANGE_U := 1.5

var boss: Node2D = null
var label := "Rallumer"
var hold_s := 0.6
var used := false
var on_used: Callable = Callable()
var _vis: Node2D = null


static func spawn(p_boss: Node2D, at: Vector2, opts: Dictionary = {}, p_on_used := Callable()) -> RaidProp:
	var r := RaidProp.new()
	r.name = &"RaidProp"
	r.boss = p_boss
	r.label = String(opts.get("prop_label", "Rallumer"))
	r.hold_s = float(opts.get("hold_s", 0.6))
	r.on_used = p_on_used
	RaidKit.world_of(p_boss).add_child(r)
	r.global_position = RaidKit.place(p_boss, at)
	r._vis = RaidFx.visual(&"raid_prop", RaidFx.Kind.PROP, RaidFx.CYAN, 0.5 * RaidKit.U)
	r.add_child(r._vis)
	r.add_to_group(&"interactable")
	r.add_to_group(RaidFx.CUE_GROUP)
	GroundMarker.attach(r, 0.6, true)
	return r


func player_near() -> bool:
	var pl := RaidKit.player_of(self)
	return pl != null and pl.global_position.distance_to(global_position) <= RANGE_U * RaidKit.U


func can_interact() -> bool:
	return not used and player_near()


func interact_label() -> String:
	return label


func interact_state() -> Dictionary:
	return {"visible": can_interact(), "enabled": true, "label": label, "hold_s": hold_s}


func interact_priority() -> int:
	return 2


func interact() -> bool:
	if used:
		return false
	used = true
	RaidFx.set_state(_vis, 1)
	remove_from_group(&"interactable")
	remove_from_group(RaidFx.CUE_GROUP)
	RaidFx.sfx(&"ui.raid_progress", global_position)
	if on_used.is_valid():
		on_used.call(self)
	return true
