extends CanvasLayer
## Invites contextuelles de la première run (docs/ux/Audit_Menus.md §3.1, lot M-A, problème M1).
## Une seule bulle à la fois, au-dessus du héros, jamais sur le HUD (Hud.reserved_rects()) :
##   move (t = 0, finie après 2 u parcourues) -> auto_fire (1er kill) -> dodge (1er dégât ou 25 s actives)
##   -> interact (<= 3 u d'une capsule ou d'un coffre) -> pillar (<= 6 u d'un pilier prêt) -> teleporter (étage nettoyé).
## Chaque invite : 6 s max, une seule fois (Profile.seen_hints), suspendue pendant un combat de boss, la pause,
## un carton d'étage ou l'aide des commandes. Fondu simple, aucune pulsation (« Flashs réduits »).
## Actif seulement si Profile.stats.runs == 0 et le réglage « Astuces de jeu » (gameplay/hints, défaut vrai).
## Ligne détail : astuce de data/tips.json (choisie par mot-clé).
## Didacticiel étendu (28/10/2026) : + "gold" (1er kill, disparaît au 1er ramassage d'or), "aim" (sorts 2-4 : curseur /
## stick droit / auto mobile, disparaît au 1er lancer), "charge" (gros pilier activé : rester dans le cercle, même pendant
## le combat de boss). « Revoir le didacticiel » : `request_replay()` (Réglages) relance toute la séquence à la prochaine run,
## même après la 1re (Profile.tutorial_replay, consommé au branchement).
## Branchement : Main._build -> `preload(...).attach(self, hud)` (null si inactif).

const SEQUENCE: Array[String] = ["move", "auto_fire", "gold", "aim", "dodge", "interact", "pillar", "charge", "teleporter"]
const LAYER := 11 ## au-dessus du HUD (10), sous la pause (100)
const NODE_NAME := "OnboardingHints"
const TIPS_PATH := "res://data/tips.json"
const SETTING_SECTION := "gameplay"
const SETTING_KEY := "hints"

const MAX_S := 6.0 ## durée max d'une invite
const MOVE_DONE_U := 2.0
const AIM_AFTER_S := 30.0 ## temps actif avant l'invite de visée des sorts 2-4
const CHARGE_DONE_RATIO := 0.03 ## la charge a démarré : l'invite « charge » a fait son travail
const DODGE_FALLBACK_S := 25.0 ## temps actif avant l'invite de roulade sans dégât subi
const INTERACT_U := 3.0
const PILLAR_U := 6.0
const QUEUE_EXPIRE_S := 10.0 ## une invite de contexte en attente trop longtemps est abandonnée (re-déclenchable)
const POLL_S := 0.25
const FADE_IN_S := 0.2
const FADE_OUT_S := 0.3
const HEAD_OFFSET_PX := 150.0 ## au-dessus de la tête et des barres de PV du personnage
const MARGIN_PX := 16.0
const GAP_PX := 10.0

const FONT := [32, 40] ## texte principal [PC, mobile] (audit : 32 px)
const DETAIL_FONT := [22, 30] ## ligne d'astuce (jamais sous le plancher 18 / 26)
const PROMPT_H := [44.0, 52.0]
const BG := Color(0.102, 0.086, 0.125, 0.9) ## #1a1620 α 0,9
const TEXT := Color("#F2EEE6")
const DETAIL := Color("#C9C2B6")
const DETAIL_KEYWORDS := {
	"auto_fire": "sort 1", "dodge": "roulade", "interact": "capsules",
	"pillar": "petits piliers", "teleporter": "téléporteur", "gold": "or",
}

var hud: Node = null
var current := "" ## id affiché ("" : aucun)
var bubble: PanelContainer
var prompt: KeyPrompt
var label: Label
var detail: Label

var _root: Control
var _queue: Array = [] ## [[id, attente_s]]
var _left := 0.0
var _fade := 0.0 ## 0..1
var _ending := false
var _elapsed := 0.0
var _start_pos := Vector2.INF
var _poll := 0.0
var _tips: Array = []


## Invites actives pour ce profil et ces réglages.
static func should_run() -> bool:
	if Profile.tutorial_replay:
		return true # « Revoir le didacticiel » : passe outre le réglage et le nombre de runs
	if not bool(GameSettings.get_value(SETTING_SECTION, SETTING_KEY, true)):
		return false
	return int(Profile.stats.get("runs", 0)) == 0


## Pose le nœud sous `parent` si les invites sont actives ; sinon null.
static func attach(parent: Node, hud_node: Node) -> CanvasLayer:
	if not should_run():
		return null
	var n: CanvasLayer = load("res://scripts/ui/onboarding_hints.gd").new()
	n.name = NODE_NAME
	n.hud = hud_node
	parent.add_child(n)
	if Profile.tutorial_replay:
		Profile.clear_tutorial_replay() # une seule run de rejeu ; seen_hints se remplit de nouveau
	return n


## « Revoir le didacticiel » (bouton des Réglages) : oublie les invites vues, relance la séquence à la prochaine run.
static func request_replay() -> void:
	Profile.request_tutorial_replay()


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _ready() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(TIPS_PATH)) if FileAccess.file_exists(TIPS_PATH) else null
	_tips = d if d is Array else []
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	bubble = PanelContainer.new()
	bubble.name = "Bubble"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	bubble.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	bubble.add_child(v)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	prompt = KeyPrompt.new()
	h.add_child(prompt)
	label = _make_label(TEXT, 3)
	h.add_child(label)
	detail = _make_label(DETAIL, 2)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(detail)
	bubble.visible = false
	_root.add_child(bubble)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_damaged.connect(_on_player_damaged)
	Events.floor_cleared.connect(_on_floor_cleared)
	Events.pickup_collected.connect(_on_pickup_collected)
	Events.pillar_state_changed.connect(_on_pillar_state)
	Events.pillar_charge_progress.connect(_on_charge_progress)
	Platform.input_mode_changed.connect(_on_mode_changed)
	trigger("move")


func _exit_tree() -> void:
	for pair in [[Events.enemy_killed, _on_enemy_killed], [Events.player_damaged, _on_player_damaged],
			[Events.floor_cleared, _on_floor_cleared], [Platform.input_mode_changed, _on_mode_changed],
			[Events.pickup_collected, _on_pickup_collected], [Events.pillar_state_changed, _on_pillar_state],
			[Events.pillar_charge_progress, _on_charge_progress]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])


func _make_label(c: Color, outline: int) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", outline)
	return l


# --- Déclencheurs ---------------------------------------------------------------

## Met une invite en file (ignorée si déjà vue, en cours ou en attente).
func trigger(id: String) -> void:
	if not SEQUENCE.has(id) or Profile.has_seen_hint(id) or id == current:
		return
	for q in _queue:
		if q[0] == id:
			return
	_queue.append([id, 0.0])


func _on_enemy_killed(_e: Node2D, _p: Vector2, _tier: int, _elite: bool) -> void:
	trigger("auto_fire")
	trigger("gold")


## Premier ramassage d'or : l'invite « gold » est faite (affichée ou en attente).
func _on_pickup_collected(kind: StringName, _amount: float) -> void:
	if kind == &"gold":
		_gesture_done("gold")


## Gros pilier activé : « rester dans le cercle » (le combat de boss qui démarre ne la bloque pas).
func _on_pillar_state(pillar: Node, state: StringName) -> void:
	if state == &"active" and pillar != null and pillar.get(&"kind") == 1: # Pillar.Kind.BIG
		trigger("charge")


func _on_charge_progress(_pillar: Node, ratio: float) -> void:
	if ratio >= CHARGE_DONE_RATIO:
		_gesture_done("charge")


## Le geste de l'invite `id` est fait : retirée de la file (consommée) ou terminée si affichée.
func _gesture_done(id: String) -> void:
	if current == id:
		_end()
	elif not Profile.has_seen_hint(id):
		_drop(id)
		Profile.mark_hint_seen(id)


func _on_player_damaged(_amount: float, _src: Node) -> void:
	trigger("dodge")


func _on_floor_cleared(_stage: int) -> void:
	trigger("teleporter")


func _on_mode_changed(_mode: int) -> void:
	if current != "":
		_fill(current)


# --- Boucle ------------------------------------------------------------------------

## Vrai quand une invite ne doit pas s'afficher (boss, carton, pause, aide des commandes).
func blocked(id := "") -> bool:
	if not RunState.running or get_tree().paused:
		return true
	if id != "charge" and not get_tree().get_nodes_in_group(&"bosses").is_empty():
		return true
	if hud != null and is_instance_valid(hud) and hud.has_method(&"is_help_visible") and hud.is_help_visible():
		return true
	return false


func _player() -> Node2D:
	return get_tree().get_first_node_in_group(&"player") as Node2D


func _process(delta: float) -> void:
	var p := _player()
	if p != null and _start_pos == Vector2.INF:
		_start_pos = p.global_position
	if RunState.running:
		_elapsed += delta
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_S
		_poll_context(p)
	# déplacement fait : l'invite « move » n'a plus lieu d'être (affichée ou non)
	if p != null and _start_pos != Vector2.INF and p.global_position.distance_to(_start_pos) >= MOVE_DONE_U * Balance.UNIT_PX:
		if current == "move":
			_end()
		elif not Profile.has_seen_hint("move"):
			_drop("move")
			Profile.mark_hint_seen("move")
	if _spell_pressed():
		_gesture_done("aim")
	if current == "dodge" and Input.is_action_just_pressed(&"dodge"):
		_end()
	elif (current == "interact" or current == "pillar" or current == "teleporter") and Input.is_action_just_pressed(&"interact"):
		_end()
	var block := blocked(current)
	for q in _queue:
		q[1] += delta
	_queue = _queue.filter(func(q: Array) -> bool: return q[0] in ["move", "auto_fire", "gold", "aim", "dodge", "charge", "teleporter"] or q[1] < QUEUE_EXPIRE_S)
	if current == "":
		if not _queue.is_empty() and not blocked(String(_queue[0][0])):
			_show(String(_queue.pop_front()[0]))
	elif block:
		_end() # contexte perdu (boss, pause…) : l'invite est consommée
	else:
		_left -= delta
		if _left <= 0.0:
			_end()
	_update_fade(delta)
	if bubble.visible:
		_layout(p)


func _poll_context(p: Node2D) -> void:
	if p == null:
		return
	var pp := p.global_position
	if _elapsed >= DODGE_FALLBACK_S:
		trigger("dodge")
	if _elapsed >= AIM_AFTER_S:
		trigger("aim")
	if not Profile.has_seen_hint("interact"):
		var r2 := pow(INTERACT_U * Balance.UNIT_PX, 2.0)
		for g in [&"gold_capsules", &"chests"]:
			for n in get_tree().get_nodes_in_group(g):
				var n2 := n as Node2D
				if n2 != null and n2.is_visible_in_tree() and n2.global_position.distance_squared_to(pp) <= r2:
					trigger("interact")
					break
	if not Profile.has_seen_hint("pillar"):
		var r2p := pow(PILLAR_U * Balance.UNIT_PX, 2.0)
		for n in get_tree().get_nodes_in_group(&"pillars"):
			var pl := n as Node2D
			if pl != null and StringName(pl.get(&"state")) == &"ready" and pl.global_position.distance_squared_to(pp) <= r2p:
				trigger("pillar")
				break


func _spell_pressed() -> bool:
	for a in [&"spell_2", &"spell_3", &"spell_4"]:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return false


func _drop(id: String) -> void:
	_queue = _queue.filter(func(q: Array) -> bool: return q[0] != id)


func _show(id: String) -> void:
	current = id
	_left = MAX_S
	_ending = false
	_fill(id)
	bubble.visible = true


func _end() -> void:
	if current == "":
		return
	Profile.mark_hint_seen(current)
	current = ""
	_ending = true


func _update_fade(delta: float) -> void:
	if current != "":
		_fade = minf(_fade + delta / FADE_IN_S, 1.0)
	else:
		_fade = maxf(_fade - delta / FADE_OUT_S, 0.0)
		if _fade <= 0.0:
			bubble.visible = false
			_ending = false
	bubble.modulate.a = _fade


# --- Contenu -------------------------------------------------------------------------

## Textes [action de l'invite de touche, texte principal] selon le mode d'entrée courant.
static func content(id: String, mode: int) -> Array:
	var touch := mode == Platform.InputMode.TOUCH
	var pad := mode == Platform.InputMode.GAMEPAD
	match id:
		"move":
			if touch:
				return ["", "Glissez le doigt n'importe où pour vous déplacer"]
			return ["", "Stick gauche : se déplacer" if pad else "ZQSD / WASD / flèches : se déplacer"]
		"auto_fire":
			return ["", "Votre premier sort tire tout seul : placez-vous bien"]
		"dodge":
			if touch:
				return ["", "Bouton Roulade : traversez les coups sans dégâts"]
			return ["dodge", "Roulade : traversez les coups sans dégâts"]
		"gold":
			return ["", "Passez sur les pièces d'or pour les ramasser : elles paient les coffres"]
		"aim":
			if touch:
				return ["", "Sorts 2 à 4 : touchez les boutons, ils visent tout seuls"]
			if pad:
				return ["", "Sorts 2 à 4 : visez avec le stick droit (sinon, l'ennemi le plus proche)"]
			return ["spell_2", "Sorts 2 à 4 : ils visent le curseur de la souris"]
		"charge":
			return ["", "Restez dans le cercle : le pilier se charge tant que vous y êtes"]
		"interact":
			if touch:
				return ["", "Bouton Interagir : ouvrir la capsule ou le coffre"]
			return ["interact", "Ouvrir la capsule ou le coffre"]
		"pillar":
			if touch:
				return ["", "Bouton Interagir près du pilier : un gardien apparaît"]
			return ["interact", "Activer le pilier : un gardien apparaît"]
		"teleporter":
			if touch:
				return ["", "Étage nettoyé : maintenez Interagir sur le téléporteur"]
			return ["interact", "Étage nettoyé : maintenez sur le téléporteur pour partir"]
	return ["", ""]


## Astuce de data/tips.json liée à l'invite (mot-clé), "" sinon.
func detail_for(id: String) -> String:
	var kw: String = DETAIL_KEYWORDS.get(id, "")
	if kw == "":
		return ""
	for t in _tips:
		if String(t).to_lower().contains(kw):
			return String(t)
	return ""


func _scale() -> float:
	return HudMetrics.geometry_scale(_root.get_viewport_rect().size)


func _fill(id: String) -> void:
	var c := content(id, Platform.input_mode)
	var s := _scale()
	var mobile := HudMetrics.is_mobile()
	prompt.set_height(float(HudMetrics.pick(PROMPT_H, mobile)) * s)
	prompt.set_action(StringName(c[0]))
	prompt.visible = String(c[0]) != ""
	label.text = String(c[1])
	label.add_theme_font_size_override("font_size", HudMetrics.font(FONT, s, mobile))
	detail.text = detail_for(id)
	detail.visible = detail.text != ""
	detail.add_theme_font_size_override("font_size", HudMetrics.font(DETAIL_FONT, s, mobile))
	bubble.reset_size()


## Taille de police effective (tests).
func font_px() -> int:
	return label.get_theme_font_size("font_size")


func detail_font_px() -> int:
	return detail.get_theme_font_size("font_size")


func bubble_rect() -> Rect2:
	return Rect2(bubble.position, bubble.size)


## Place la bulle au-dessus du héros, dans l'écran, hors des zones du HUD.
func _layout(p: Node2D) -> void:
	var vp := _root.get_viewport_rect().size
	var s := _scale()
	var sz := bubble.get_combined_minimum_size()
	bubble.size = sz
	var anchor := vp * 0.5
	if p != null and p.is_inside_tree():
		anchor = p.get_global_transform_with_canvas().origin
	var pos := Vector2(anchor.x - sz.x * 0.5, anchor.y - HEAD_OFFSET_PX * s - sz.y)
	var reserved: Array = hud.reserved_rects() if hud != null and is_instance_valid(hud) and hud.has_method(&"reserved_rects") else []
	bubble.position = place(pos, sz, vp, reserved)


## Position finale d'un rectangle `sz` voulu en `pos` : dans [MARGIN, vp - MARGIN], sans chevaucher `reserved`.
static func place(pos: Vector2, sz: Vector2, vp: Vector2, reserved: Array) -> Vector2:
	var lo := Vector2(MARGIN_PX, MARGIN_PX)
	var hi := (vp - sz - Vector2(MARGIN_PX, MARGIN_PX)).max(lo)
	pos = pos.clamp(lo, hi)
	for _i in 6:
		var hit := false
		for r in reserved:
			var rr := (r as Rect2).grow(GAP_PX * 0.5)
			if not Rect2(pos, sz).intersects(rr):
				continue
			hit = true
			# candidats : au-dessus, en dessous, à gauche, à droite de la zone ; le plus proche qui tient à l'écran
			var cands: Array[Vector2] = [
				Vector2(pos.x, rr.position.y - sz.y), Vector2(pos.x, rr.end.y),
				Vector2(rr.position.x - sz.x, pos.y), Vector2(rr.end.x, pos.y)]
			var best := pos
			var best_d := INF
			for c in cands:
				if c.x < lo.x - 0.5 or c.y < lo.y - 0.5 or c.x > hi.x + 0.5 or c.y > hi.y + 0.5:
					continue
				var free := true
				for r2 in reserved:
					if Rect2(c, sz).intersects((r2 as Rect2).grow(GAP_PX * 0.5)):
						free = false
						break
				var d := c.distance_squared_to(pos) - (1.0e9 if free else 0.0)
				if d < best_d:
					best_d = d
					best = c
			pos = best.clamp(lo, hi)
			break
		if not hit:
			break
	return pos
