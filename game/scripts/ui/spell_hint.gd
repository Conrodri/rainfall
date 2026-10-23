class_name SpellHint
extends Control
## Description d'un sort en jeu : bulle (SpellTooltip, celle de l'écran Nouvelle run) au-dessus du bouton.
##   - clavier-souris : au SURVOL d'une case de la barre de sorts (la souris continue de viser : rien n'est
##     intercepté, le survol est lu dans _input) ;
##   - tactile : à l'APPUI LONG (SpellButton.LONG_PRESS_S) sur un bouton de sort, sans lancer le sort ;
##     cachée au relâcher.
## Textes : data/characters.json (nom, slot auto/cd/ultime, desc, variantes ; même source que la fiche
## personnage) et SpellData du personnage joué (recharge). Le jeu n'est jamais mis en pause ; aucune bulle
## pendant une pause (menu pause, coffre). La bulle ignore la souris et le toucher.

const CHAR_PATH := "res://data/characters.json"

var hud: Hud
var tip: SpellTooltip
var button: SpellButton = null ## bouton dont la description est affichée (null = cachée)
var _mouse := Vector2(-1.0e6, -1.0e6) ## dernière position de la souris (coordonnées du HUD)
var _mouse_in := true
var _cache_char: StringName = &"__none__"
var _cache: Dictionary = {} ## spell id -> {name, slot, desc, base_name (variante)}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	tip = SpellTooltip.new()
	tip.name = "SpellTip"
	# plaque de la DA (fer usé, comme les cadres du HUD) ; repli : plaque plate de SpellTooltip
	var da := UiTheme.da_box("panel_small_9slice", 0.5)
	if da != null:
		da.content_margin_left = 22
		da.content_margin_right = 22
		da.content_margin_top = 16
		da.content_margin_bottom = 18
		tip.add_theme_stylebox_override("panel", da)
	add_child(tip)


func bind(h: Hud) -> void:
	hud = h


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position
		_mouse_in = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_in = false
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_in = true


func _exit_tree() -> void:
	SpellTooltip.set_user_bubble(&"spell_hint", false)


func _process(_delta: float) -> void:
	var target := _target()
	# arbitre (H5) : une bulle d'item déjà ouverte garde la main ; la bulle de sort attend
	if target != null and target != button and SpellTooltip.other_user_bubble_open(&"spell_hint"):
		target = null
	if target == button:
		return
	button = target
	SpellTooltip.set_user_bubble(&"spell_hint", target != null)
	if target == null:
		tip.hide_tip()
	else:
		var info := describe(target)
		var s := hud.ui_scale
		if Platform.input_mode == Platform.InputMode.TOUCH: # lisible au doigt, sur petit écran
			tip.set_text_sizes(int(38 * s), int(30 * s), int(32 * s), 620.0 * s)
		else:
			tip.set_text_sizes(int(32 * s), int(26 * s), int(26 * s), 520.0 * s)
		tip.show_for(target, info.title, info.tag, info.body)


## Bouton à décrire cette image, ou null.
func _target() -> SpellButton:
	if hud == null or not is_instance_valid(hud) or not hud.visible or get_tree().paused:
		return null
	if hud.pause_menu != null and hud.pause_menu.is_open:
		return null
	match Platform.input_mode:
		Platform.InputMode.TOUCH:
			for b in hud.spell_buttons:
				if b.is_visible_in_tree() and b.is_long_pressed():
					return b
		Platform.InputMode.KBM:
			if not _mouse_in:
				return null
			for b in hud.bar_buttons:
				if b.is_visible_in_tree() and b.get_global_rect().has_point(_mouse):
					return b
	return null


## Texte de la bulle : {title, tag, body}. Nom, type (Auto / Recharge X s / Ultime), description ;
## une variante choisie est signalée (« Variante de <sort de base> »).
func describe(b: SpellButton) -> Dictionary:
	var sid := b.spell_id()
	var info: Dictionary = _spell_info(sid)
	var sd := _spell_data(sid)
	var title := String(info.get("name", ""))
	if title == "":
		title = sd.display_name if sd != null else b.caption
	var slot_kind := String(info.get("slot", ""))
	if slot_kind == "":
		slot_kind = "auto" if b.is_auto else ("ultime" if b.slot == 4 else "cd")
	var cd := sd.base_cooldown if sd != null else b.total
	var parts: Array[String] = []
	match slot_kind:
		"auto":
			parts.append("Auto")
		"ultime":
			parts.append("Ultime")
			if cd > 0.0:
				parts.append("recharge %s s" % CharacterCard.fmt_num(cd))
		_:
			if cd > 0.0 or b.cost_text == "":
				parts.append("Recharge %s s" % CharacterCard.fmt_num(cd) if cd > 0.0 else "Recharge")
	if b.cost_text != "": # sort payé en ressource du kit (Averse : eau) : le coût remplace « Recharge »
		parts.append(("Coût : %s" if slot_kind != "ultime" else "%s") % b.cost_text)
	if info.has("base_name"):
		parts.append("Variante de %s" % String(info.base_name))
	if b.charges >= 0 and b.max_charges > 0:
		parts.append("%d/%d charges" % [b.charges, b.max_charges])
	return {"title": title, "tag": " · ".join(parts), "body": String(info.get("desc", ""))}


## Texte visible de la bulle (tests).
func text_content() -> String:
	return tip.text_content() if tip.visible else ""


func _char_id() -> StringName:
	var c: Variant = hud.player.get(&"character") if hud != null and hud.player != null and is_instance_valid(hud.player) else null
	if c is CharacterData:
		return (c as CharacterData).id
	return RunState.character


func _spell_data(sid: StringName) -> SpellData:
	var c: Variant = hud.player.get(&"character") if hud != null and hud.player != null and is_instance_valid(hud.player) else null
	if c is CharacterData:
		for s in (c as CharacterData).spells:
			if s.id == sid:
				return s
	return null


## Entrée de characters.json pour ce sort (sort de base ou variante), {} si absente.
func _spell_info(sid: StringName) -> Dictionary:
	var cid := _char_id()
	if cid != _cache_char:
		_cache_char = cid
		_cache = {}
		for c in CharacterCard.load_characters():
			if not (c is Dictionary) or StringName(String(c.get("id", ""))) != cid:
				continue
			for s in c.get("spells", []):
				if not (s is Dictionary):
					continue
				var base := {"name": String(s.get("name", "")), "slot": String(s.get("slot", "")), "desc": String(s.get("desc", ""))}
				_cache[StringName(String(s.get("id", "")))] = base
				for v in s.get("variants", []):
					if v is Dictionary:
						_cache[StringName(String(v.get("id", "")))] = {"name": String(v.get("name", "")), "slot": base.slot,
							"desc": String(v.get("desc", "")), "base_name": base.name}
	return _cache.get(sid, {})
