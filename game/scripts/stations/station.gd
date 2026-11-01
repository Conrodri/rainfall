class_name Station
extends Area2D
## Atelier de la carte (Fondoir, Matrice, Alambic, Enclume ; docs/Ateliers_Chiffres.md). Interactable comme un
## coffre : groupe `interactable`, action « interagir » seulement (jamais au contact), invite par
## `interact_state()`. Les règles vivent dans `StationState` ; le choix d'objet passe par `ItemPicker`.
## Visuel PROVISOIRE : le coffre légendaire teinté (fermé = prêt, ouvert = épuisé), en attendant les 4 props de
## art/tools/props/_ateliers.txt (même nœud `Visual` à échanger, rien d'autre ne change).

signal used(station: Station)
signal depleted(station: Station)

const FRAMES := "res://assets/sprites/chests/chest_legendary/chest_legendary.tres" ## provisoire (coffre légendaire teinté)
## Props définitifs (lot art/tools/props/_ateliers.txt) : repérés par id ; absents = repli provisoire, teinte appliquée.
const PROP_FRAMES := "res://assets/sprites/props/stations/%s/%s.tres"
const VISUAL_SCALE := 0.95
const NAMES := {&"fondoir": "Fondoir", &"matrice": "Matrice", &"alambic": "Alambic", &"enclume": "Enclume de bronze"}
const TINTS := {
	&"fondoir": Color(1.0, 0.62, 0.42), &"matrice": Color(0.8, 0.85, 1.0),
	&"alambic": Color(0.55, 0.95, 0.8), &"enclume": Color(1.0, 0.78, 0.45),
}
const LIGHT_PRESET := &"chest_large"
const ITEM_ICON := "res://assets/sprites/icons/items/%s.png"
const RADIUS := 96.0

var state: StationState
var _player_inside := false
var _busy := false
var _visual: EmissiveOverlay
var _billboard: Node2D
var _label: Label
var _icon: Sprite2D
var _light: LightRig.Handle = null
var _picker: ItemPicker = null
var _has_own_prop := false


func setup(p_state: StationState) -> void:
	state = p_state
	name = "Station_%s" % state.kind
	if is_node_ready():
		_refresh()


func _ready() -> void:
	collision_layer = 64 # couche 7 : interactables
	collision_mask = 2 # joueur
	input_pickable = false
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	cs.shape = circle
	add_child(cs)
	_billboard = Node2D.new()
	_billboard.name = "Billboard"
	add_child(_billboard)
	_visual = EmissiveOverlay.new()
	_visual.name = "Visual"
	_visual.offset = Vector2(0, -43)
	_visual.scale = Iso.UNSQUASH * VISUAL_SCALE
	_billboard.add_child(_visual)
	var own := PROP_FRAMES % [state.kind, state.kind] if state != null else ""
	_has_own_prop = own != "" and ResourceLoader.exists(own)
	if _has_own_prop:
		_visual.set_frames(load(own) as SpriteFrames)
	elif ResourceLoader.exists(FRAMES):
		_visual.set_frames(load(FRAMES) as SpriteFrames)
	_label = Label.new()
	_label.name = "Label"
	_label.position = Vector2(-160, -270)
	_label.size = Vector2(320, 48)
	_label.scale = Iso.UNSQUASH
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	_billboard.add_child(_label)
	_icon = Sprite2D.new()
	_icon.name = "ItemIcon"
	_icon.position = Vector2(0, -340)
	_billboard.add_child(_icon)
	add_to_group("stations")
	add_to_group("interactable")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	RunState.scrap_changed.connect(_refresh)
	RunState.items_changed.connect(_refresh)
	RunState.item_added.connect(_on_item_added)
	RunState.gold_changed.connect(_on_gold_changed)
	_refresh()


func _exit_tree() -> void:
	if _light != null:
		_light.release()
		_light = null
	if is_instance_valid(_picker):
		_picker.queue_free()


func _on_body_entered(b: Node) -> void:
	if b.is_in_group("player"):
		_player_inside = true


func _on_body_exited(b: Node) -> void:
	if b.is_in_group("player"):
		_player_inside = false


func _on_item_added(_id: StringName, _n: int) -> void:
	_refresh()


func _on_gold_changed(_g: float) -> void:
	if state != null and state.kind == &"enclume":
		_refresh()


## Libellé flottant, icône de l'objet affiché (Matrice), teinte, lumière.
func _refresh() -> void:
	if state == null or _visual == null:
		return
	var tint: Color = TINTS.get(state.kind, Color.WHITE)
	if state.kind == &"matrice" and state.quality != &"":
		tint = tint.lerp(StationState.SCRAP_COLORS.get(state.quality, Color.WHITE), 0.5) # la teinte lit la qualité de loin
	var done := state.exhausted()
	_visual.animation = &"open" if done else &"closed"
	_visual.stop()
	_visual.frame = 0
	if _has_own_prop:
		_visual.modulate = Color(0.55, 0.55, 0.58) if done else Color.WHITE # le prop porte sa propre teinte
	else:
		_visual.modulate = tint.darkened(0.55) if done else tint
	var txt := String(NAMES.get(state.kind, state.kind))
	var col := Color(1, 0.9, 0.6)
	if done:
		txt += " (épuisé)"
		col = Color(0.65, 0.65, 0.68)
	elif state.kind == &"matrice":
		txt = "%s : %s" % [txt, str(ItemDB.get_item(state.item_id).get("name", state.item_id))]
		var note := state.matrice_note()
		if note != "":
			txt += " (%s)" % note
		txt += " (%d)" % state.uses_left()
	else:
		txt += " (%d)" % state.uses_left()
	_label.text = txt
	_label.modulate = col
	_icon.visible = state.kind == &"matrice" and not done and state.item_id != &""
	if _icon.visible:
		var path := ITEM_ICON % state.item_id
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			_icon.texture = tex
			var k := 76.0 / maxf(float(tex.get_height()), 1.0)
			_icon.scale = Iso.UNSQUASH * k
	if done and _light != null:
		_light.release()
		_light = null
	elif not done and _light == null and is_inside_tree():
		_light = LightRig.attach(self, LIGHT_PRESET)


# --- Contrat « Interaction » ----------------------------------------------------------------------

func can_interact() -> bool:
	return _player_inside and not _busy


## Invite : verbe de l'atelier (≤ 24 caractères), refus écrit quand l'atelier est épuisé.
func interact_label() -> String:
	if state == null:
		return ""
	if state.exhausted():
		return "%s épuisé" % NAMES.get(state.kind, "")
	match state.kind:
		&"fondoir":
			return "Fondre un objet"
		&"matrice":
			if state.forge_scrap_reason() == "":
				return "Forger : 1 scorie %s" % StationState.SCRAP_NAMES.get(state.quality, "")
			return "Forger : donner 1 objet"
		&"alambic":
			return "Distiller %d objets" % Balance.ALAMBIC_INPUT
		&"enclume":
			return "Forger un exemplaire"
	return "Utiliser"


func interact_state() -> Dictionary:
	return {"visible": can_interact(), "enabled": state != null and not state.exhausted(), "label": interact_label(), "hold_s": 0.0}


func interact_priority() -> int:
	return 3


func interact() -> bool:
	if state == null or _busy or state.exhausted():
		return false
	match state.kind:
		&"fondoir":
			_open_melt()
		&"matrice":
			if state.forge_scrap_reason() == "":
				_after(state.forge(get_tree(), {"scrap": true}))
			else:
				_open_forge()
		&"alambic":
			_open_distill()
		&"enclume":
			_open_enclume()
		_:
			return false
	return true


# --- Panneaux -------------------------------------------------------------------------------------

func _host() -> Node:
	return get_tree().current_scene if get_tree().current_scene != null else get_tree().root


func _open(cfg: Dictionary, on_picked: Callable) -> ItemPicker:
	_busy = true
	_picker = ItemPicker.open(_host(), cfg)
	_picker.picked.connect(on_picked)
	_picker.closed.connect(func() -> void: _busy = false)
	return _picker


func _open_melt() -> void:
	var list: Array = []
	for id in StationState.owned_of(StationState.QUALITY_ORDER):
		var why := state.melt_reason(id)
		var q := StationState.quality_of(id)
		list.append({"key": id, "id": id, "enabled": why == "", "reason": why,
			"line": "Fondre : +%d or, +1 scorie %s" % [int(round(StationState.refund_gold(q))), StationState.SCRAP_NAMES.get(q, "")]})
	var cfg := {"title": "Fondre un objet",
		"subtitle": "Scories : %d/%d · usages restants : %d · l'objet est perdu (effet interne perdu)" % [RunState.scrap_total(), Balance.SCRAP_CAP, state.uses_left()],
		"entries": list}
	_open(cfg, _on_melt_picked)


func _on_melt_picked(chosen: Array) -> void:
	_after(state.melt(get_tree(), StringName(chosen[0]["id"])))


func _open_forge() -> void:
	var target := str(ItemDB.get_item(state.item_id).get("name", state.item_id))
	var qn: String = StationState.QUALITY_NAMES.get(state.quality, "")
	var list: Array = []
	for id in StationState.owned_of([state.quality]):
		var why := state.forge_item_reason(id)
		list.append({"key": id, "id": id, "enabled": why == "", "reason": why, "line": "Donner contre : %s" % target})
	var cfg := {"title": "Forger : %s" % target,
		"subtitle": "Donnez 1 objet %s (ou 1 scorie %s) · usages restants : %d" % [qn, StationState.SCRAP_NAMES.get(state.quality, ""), state.uses_left()],
		"empty_text": "Aucun objet %s à donner" % qn,
		"entries": list}
	_open(cfg, _on_forge_picked)


func _on_forge_picked(chosen: Array) -> void:
	_after(state.forge(get_tree(), {"item": StringName(chosen[0]["id"])}))


func _open_distill() -> void:
	var list: Array = []
	for id in StationState.owned_of(StationState.QUALITY_ORDER):
		var q := StationState.quality_of(id)
		var up := StationState.next_quality(q)
		var ok := up != &"" and (up != &"legendaire" or Balance.ALAMBIC_ALLOW_LEGENDARY)
		var spend := StationState.spendable_stacks(id)
		var reason := "" if ok else "Pas de légendaire par l'alambic"
		if ok and spend <= 0:
			ok = false
			reason = "Phénix déjà consommé"
		for n in mini(maxi(spend, 1), Balance.ALAMBIC_INPUT):
			list.append({"key": "%s#%d" % [id, n], "id": id, "count": RunState.stacks(id), "enabled": ok, "reason": reason,
				"line": "Distiller → un objet %s" % StationState.QUALITY_NAMES.get(up, "")})
	var cfg := {"title": "Distiller",
		"subtitle": "Donnez %d objets de même qualité : vous recevez 1 objet de la qualité au-dessus, proche de leurs tags · usages restants : %d" % [Balance.ALAMBIC_INPUT, state.uses_left()],
		"entries": list, "multi": Balance.ALAMBIC_INPUT, "confirm_label": "Distiller", "validate": _validate_distill}
	_open(cfg, _on_distill_picked)


func _validate_distill(sel: Array) -> String:
	return state.distill_reason(_ids_of(sel))


func _on_distill_picked(chosen: Array) -> void:
	_after(state.distill(get_tree(), _ids_of(chosen)))


static func _ids_of(entries: Array) -> Array:
	var ids: Array = []
	for e in entries:
		ids.append(StringName(str(e["id"])))
	return ids


func _open_enclume() -> void:
	var list: Array = []
	for id in StationState.owned_of(StationState.QUALITY_ORDER):
		var why := state.enclume_reason(id)
		list.append({"key": id, "id": id, "enabled": why == "", "reason": why,
			"line": "Forger : %d or" % int(ceil(state.enclume_price(id)))})
	var cfg := {"title": "Forger un exemplaire",
		"subtitle": "Prix x%s à chaque usage · usages restants : %d · or : %d" % [str(Balance.ENCLUME_PRICE_GROWTH).replace(".", ","), state.uses_left(), int(RunState.gold)],
		"entries": list}
	_open(cfg, _on_enclume_picked)


func _on_enclume_picked(chosen: Array) -> void:
	_after(state.forge_copy(get_tree(), StringName(chosen[0]["id"])))


## Suite d'une opération : retour visuel, sonore, état.
func _after(res: Dictionary) -> void:
	if not bool(res.get("ok", false)):
		_float_text(str(res.get("reason", "Refusé")), Color(1, 0.5, 0.45))
		return
	var gold := float(res.get("gold", 0.0))
	if gold > 0.0:
		_float_text("+%d or" % int(round(gold)), Color(1, 0.9, 0.4))
		Audio.play_coin()
	elif gold < 0.0:
		_float_text("%d or" % int(round(gold)), Color(1, 0.9, 0.4))
	Audio.play_ui(&"ui.item_pick")
	LightRig.flash(global_position, &"chest_open", 0.6)
	_refresh()
	used.emit(self)
	if state.exhausted():
		depleted.emit(self)


func _float_text(text: String, color: Color) -> void:
	if _billboard == null:
		return
	var l := Label.new()
	l.text = text
	l.position = Vector2(-160, -190)
	l.size = Vector2(320, 48)
	l.scale = Iso.UNSQUASH
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	_billboard.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", -300.0, 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)
