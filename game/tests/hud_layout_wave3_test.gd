extends Node
## HUD vague 3 (retours joueur 22/10/2026) :
## 1. difficulté sous la minimap : aucun chevauchement des éléments du haut (fiche PV, chrono, or, pause, minimap,
##    difficulté, objectifs, barres de boss + mini-boss empilées) en clavier-souris ET tactile, à 1920×1080,
##    2400×1080, 2340×1080 (téléphones) et 1280×720 ; en tactile, rien sur la grappe de sorts ;
## 2. barres au-dessus de la tête : hauteur / largeur selon le sprite d'au moins 3 personnages, suivent le joueur,
##    se fondent au repos, réapparaissent au coup (perte retard), « +N » sur gain de pastille, réglage persistant ;
## 3. taux de régénération : « +X/s » des PV (Player.regen_per_s) et de la ressource (hook resource_regen_per_s),
##    résumé du menu pause ; rien pour un kit sans hook.
## godot --headless --path game res://tests/hud_layout_wave3_test.tscn  → « RESULT: OK »

class FakeBoss extends Node2D:
	var active := true


class FakePlayer extends CharacterBody2D:
	signal hp_changed(hp: float, max_hp: float)
	var hp := 100.0
	var max_hp := 100.0
	var dead := false
	var pickup_radius := 200.0
	var kit: Node = null

	func get_spell_cooldowns() -> Array:
		return []

	func regen_per_s() -> float:
		return 1.5


class RegenKit extends Node: ## ressource continue + hook de régénération (Averse)
	var level := 0.6
	func resource_state() -> Dictionary:
		return KitResource.make(&"water", "Eau", level, Color("#5FD4E8"), {"text": str(roundi(level * 100.0))})
	func resource_regen_per_s() -> float:
		return 3.5


class PipKit extends Node: ## pastilles sans hook de régénération (Bourbe, Tocsin)
	var filled := 1
	func resource_state() -> Dictionary:
		return KitResource.make(&"mottes", "Mottes", 0.0, Color("#B08850"), {"pips": 4, "filled": filled})


const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(2340, 1080), Vector2i(1280, 720)]
const CHARS: Array[StringName] = [&"tocsin", &"rainette", &"avare", &"ardent", &"bourbe"]
const CFG := "user://hud_wave3_test_settings.cfg"

var _fails := 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", msg)


func _frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _ready() -> void:
	var prev_mode: int = Platform.input_mode
	var prev_cfg := GameSettings.cfg_path
	GameSettings.cfg_path = CFG # jamais le réglage réel du joueur
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	for size in SIZES:
		await _layout_case(size, false)
		await _layout_case(size, true)
	Platform.set_input_mode(Platform.InputMode.KBM)
	await _overhead_sizes()
	await _overhead_feel_and_rates()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	GameSettings.cfg_path = prev_cfg
	Platform.set_input_mode(prev_mode)
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _new_hud(size: Vector2i, touch: bool) -> Array:
	var sv := SubViewport.new()
	sv.size = size
	add_child(sv)
	var hud: Hud = load("res://scripts/ui/hud.gd").new()
	sv.add_child(hud)
	var player := FakePlayer.new()
	player.add_to_group("player")
	player.kit = RegenKit.new()
	player.add_child(player.kit)
	sv.add_child(player)
	Platform.set_input_mode(Platform.InputMode.TOUCH if touch else Platform.InputMode.KBM)
	await _frames()
	hud.bind_player(player)
	return [sv, hud, player]


# --- 1. Éléments du haut sans chevauchement (boss + mini-boss affichés)
func _layout_case(size: Vector2i, touch: bool) -> void:
	var made: Array = await _new_hud(size, touch)
	var sv: SubViewport = made[0]
	var hud: Hud = made[1]
	var floor_boss := FakeBoss.new()
	var mini := FakeBoss.new()
	sv.add_child(floor_boss)
	sv.add_child(mini)
	hud.boss_bars._on_spawned(floor_boss, true)
	hud.boss_bars._on_spawned(mini, false)
	hud._on_difficulty(4.2, &"Furieux")
	await _wait(0.3) # replacement périodique des surimpressions (0,1 s)
	var tag := "%dx%d %s" % [size.x, size.y, "tactile" if touch else "kbm"]
	var vp := Rect2(Vector2.ZERO, Vector2(size))
	var s := hud.ui_scale
	_check(hud.boss_bars.visible and hud.boss_bars.count() == 2, "%s : boss + mini-boss affichés" % tag)
	var diff: Rect2 = hud._diff_box.get_global_rect()
	var mm: Rect2 = hud.minimap.get_compact_rect()
	var mr: Rect2 = hud.minimap.map_rect()
	if mr.size.y > 0.0: # losange dessiné (carte liée) : la difficulté peut occuper la bande vide sous lui
		mm = Rect2(hud.minimap.global_position + mr.position, mr.size)
	_check(hud._diff_box.is_visible_in_tree() and hud._diff_label.text == "Furieux", "%s : difficulté affichée (%s)" % [tag, hud._diff_label.text])
	_check(vp.encloses(diff), "%s : difficulté dans l'écran %s" % [tag, diff])
	_check(diff.position.y >= mm.end.y - 0.5 and absf(diff.get_center().x - mm.get_center().x) < 2.0, "%s : difficulté sous la minimap %s / %s" % [tag, diff, mm])
	_check(hud._diff_label.get_theme_font_size("font_size") >= HudMetrics.floor_px() and hud._diff_bar.size.y >= 10.0 * s, "%s : difficulté lisible" % tag)
	var cap: Rect2 = hud._diff_caption.get_global_rect()
	_check(hud._diff_caption.text == "Difficulté" and cap.end.y <= diff.position.y + 0.5 and cap.position.y >= mm.end.y - 0.5, "%s : titre « Difficulté » entre minimap et jauge %s" % [tag, cap])
	var rects := {
		"fiche": (hud._hp_bar.get_parent().get_parent().get_parent() as Control).get_global_rect(),
		"chrono": hud._time_plate.get_global_rect(),
		"or": hud._gold_box.get_global_rect(),
		"minimap": mm,
		"difficulte": diff,
		"boss": hud.boss_bars.get_global_rect(),
	}
	if hud.pause_button.visible:
		rects["pause"] = hud.pause_button.get_global_rect()
	if hud.objectives.visible:
		rects["objectifs"] = hud.objectives.get_global_rect()
	if touch:
		rects["sort3"] = hud.spell_buttons[1].get_global_rect()
		rects["sort4"] = hud.spell_buttons[2].get_global_rect()
		rects["interagir"] = hud.interact_button.get_global_rect()
		rects["jauge"] = hud.touch_gauge.get_global_rect()
	var keys := rects.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Rect2 = rects[keys[i]]
			var b: Rect2 = rects[keys[j]]
			if keys[i] in ["sort3", "sort4", "interagir", "jauge"] and keys[j] in ["sort3", "sort4", "interagir", "jauge"]:
				continue # grappe tactile : touch_layout_test
			_check(not a.intersects(b), "%s : %s %s chevauche %s %s" % [tag, keys[i], a, keys[j], b])
	_check(vp.encloses(rects["boss"]), "%s : barres de boss dans l'écran" % tag)
	# zone fixe des boss : la ligne du haut (place du chrono hors combat) ; le chrono se range à côté, jamais au-dessus
	var top_line := float(hud._top.get_theme_constant(&"margin_top"))
	var bb: Rect2 = rects["boss"]
	var ch: Rect2 = rects["chrono"]
	if size.x >= 1920:
		_check(absf(bb.position.y - top_line) < 1.0, "%s : barres de boss sur la ligne du haut %s (ligne %.0f)" % [tag, bb, top_line])
	_check(ch.position.x >= bb.end.x - 0.5 or bb.position.y >= ch.end.y, "%s : chrono hors de la zone des boss %s / %s" % [tag, ch, bb])
	_check(hud._time_label.get_theme_font_size("font_size") >= HudMetrics.floor_px(), "%s : chrono lisible pendant le combat" % tag)
	# fin du combat : le chrono revient en haut au centre, les barres ne bougent pas pendant le combat
	hud.boss_bars._on_killed(mini, false)
	await _wait(0.2)
	_check(absf(hud.boss_bars.get_global_rect().position.y - bb.position.y) < 1.0, "%s : barre du boss stable après la mort du mini-boss" % tag)
	hud.boss_bars._on_killed(floor_boss, true)
	await _wait(0.2)
	var ch2: Rect2 = hud._time_plate.get_global_rect()
	_check(not hud._time_plate.top_level and absf(ch2.get_center().x - vp.size.x * 0.5) < 8.0, "%s : chrono revenu en haut au centre %s" % [tag, ch2])
	sv.queue_free()
	await _frames()


# --- 2. Barres au-dessus de la tête : taille selon le personnage
func _overhead_sizes() -> void:
	var prev_char: StringName = RunState.character
	var heads := {}
	var widths := {}
	for cid in CHARS:
		RunState.character = cid
		var sv := SubViewport.new()
		sv.size = Vector2i(1920, 1080)
		add_child(sv)
		var hud: Hud = load("res://scripts/ui/hud.gd").new()
		sv.add_child(hud)
		var p: Node2D = load("res://scenes/player/player.tscn").instantiate()
		p.position = Vector2(900, 700)
		sv.add_child(p)
		await _frames(4)
		hud.bind_player(p)
		p.set(&"hp", float(p.get(&"max_hp")) * 0.5) # blessé : barre affichée
		await _frames(4)
		var ob := hud.overhead
		var spr := p.get_node(^"Visual") as AnimatedSprite2D
		var tex := spr.sprite_frames.get_frame_texture(&"idle_s", 0) if spr.sprite_frames.has_animation(&"idle_s") else null
		_check(tex != null, "%s : frame idle_s" % cid)
		var used := Rect2i(0, OverheadBars.opaque_top(tex), 1, 1) # premier pixel opaque (atlas décompressé)
		_check(used.position.y > 0, "%s : haut opaque du sprite lu (%d)" % [cid, used.position.y])
		var sc: Vector2 = spr.scale
		var xf := sv.get_canvas_transform() # caméra du joueur
		var top_w := p.global_position + spr.position + Vector2(0.0, (spr.offset.y - tex.get_height() * 0.5 + used.position.y) * sc.y)
		var vis_top := (xf * top_w).y
		_check(ob.visible and ob.alpha > 0.0, "%s : barres affichées (blessé)" % cid)
		_check(ob.bar_rect.end.y <= vis_top + 1.0 and ob.bar_rect.end.y >= vis_top - 40.0, "%s : barres juste au-dessus de la tête (bas %.0f, tête %.0f)" % [cid, ob.bar_rect.end.y, vis_top])
		_check(absf(ob.bar_rect.get_center().x - (xf * top_w).x) < 2.0, "%s : barres centrées sur le personnage" % cid)
		_check(not ob.res_state.is_empty() or KitResource.of(p).is_empty(), "%s : ressource du kit reprise" % cid)
		heads[cid] = ob.head_px
		widths[cid] = ob.bar_rect.size.x
		# suit le joueur
		p.position += Vector2(120, -40)
		await _frames(2)
		var feet := sv.get_canvas_transform() * p.global_position
		_check(absf(ob.bar_rect.get_center().x - feet.x) < 2.0 and ob.bar_rect.end.y < feet.y, "%s : barres suivent le joueur" % cid)
		print("  %s : hauteur visible %.0f px, largeur %.0f px" % [cid, heads[cid], widths[cid]])
		sv.queue_free()
		await _frames()
	RunState.character = prev_char
	var distinct := {}
	for cid in heads:
		distinct[roundi(float(heads[cid]) / 4.0)] = true
	_check(distinct.size() >= 3, "au moins 3 hauteurs distinctes : %s" % str(heads))
	# plus grand sprite -> barre au moins aussi large
	var ks := heads.keys()
	for i in ks.size():
		for j in ks.size():
			if float(heads[ks[i]]) > float(heads[ks[j]]):
				_check(float(widths[ks[i]]) >= float(widths[ks[j]]), "largeur suit la taille (%s vs %s)" % [ks[i], ks[j]])


# --- 2 bis / 3. Fondu, perte retard, « +N », réglage ; taux de régénération
func _overhead_feel_and_rates() -> void:
	var made: Array = await _new_hud(Vector2i(1920, 1080), false)
	var sv: SubViewport = made[0]
	var hud: Hud = made[1]
	var player: FakePlayer = made[2]
	player.position = Vector2(960, 600)
	await _wait(0.4)
	# taux
	_check(hud._hp_regen.text == "+1,5/s", "PV : « +1,5/s » dans la barre (%s)" % hud._hp_regen.text)
	_check(float(hud.bar_gauge.state.get("regen", -1.0)) == 3.5, "ressource : taux transmis à la jauge")
	var sum := Hud.regen_summary(player)
	_check(sum.contains("PV +1,5/s") and sum.contains("Eau +3,5/s"), "résumé du menu pause : %s" % sum)
	_check(Hud.fmt_rate(12.4) == "+12/s" and Hud.fmt_rate(0.0) == "+0,0/s", "format des taux")
	# fondu au repos (PV pleins, ressource stable)
	var ob := hud.overhead
	await _wait(OverheadBars.IDLE_FADE_AFTER_S + OverheadBars.FADE_S + 0.3)
	_check(ob.alpha <= 0.01, "repos : barres fondues (alpha %.2f)" % ob.alpha)
	# coup : réapparition + perte retard maintenue
	player.hp = 60.0
	await _frames(3)
	_check(ob.alpha > 0.0 and ob.ghost > ob.hp_frac + 0.3, "coup : barres réapparaissent, perte retard (%.2f > %.2f)" % [ob.ghost, ob.hp_frac])
	await _wait(1.2)
	_check(absf(ob.ghost - ob.hp_frac) < 0.01, "perte retard rattrapée")
	# en combat (ennemi à moins de 8 u) : reste affichée même sans nouveau coup
	var foe := Node2D.new()
	foe.add_to_group(&"enemies")
	foe.position = player.position + Vector2(200, 0)
	sv.add_child(foe)
	await _wait(OverheadBars.IDLE_FADE_AFTER_S + 0.5)
	_check(ob.alpha > 0.99, "en combat : barres toujours visibles (alpha %.2f)" % ob.alpha)
	foe.queue_free()
	_check(ob.bar_rect.size.y >= (OverheadBars.HP_H + OverheadBars.RES_H) * hud.ui_scale, "PV >= 9 px + ressource >= 5 px")
	# gain ponctuel de ressource (pastilles, pas de hook) : « +1 », pas de taux affiché
	var pk := PipKit.new()
	player.kit.queue_free()
	player.kit = pk
	player.add_child(pk)
	await _frames(3)
	_check(not hud.bar_gauge.state.has("regen"), "kit sans hook : aucun taux")
	_check(Hud.regen_summary(player) == "Régénération : PV +1,5/s", "résumé sans ressource : %s" % Hud.regen_summary(player))
	pk.filled = 2
	await _frames(2)
	_check(ob._popups.size() == 1 and String(ob._popups[0]["text"]) == "+1", "gain de pastille : « +1 » flottant %s" % str(ob._popups))
	# Averse affiche ses propres « +N » : pas de doublon
	var rk := RegenKit.new()
	pk.queue_free()
	player.kit = rk
	player.add_child(rk)
	await _wait(1.0)
	ob._popups.clear()
	rk.level = 0.9
	await _frames(2)
	_check(ob._popups.is_empty(), "eau d'Averse : pas de « +N » en double")
	# réglage persistant
	GameSettings.set_overhead_bars(false)
	var cf := ConfigFile.new()
	cf.load(CFG)
	_check(cf.get_value("gameplay", "overhead_bars", true) == false, "réglage écrit dans le fichier injecté")
	await _wait(0.7)
	_check(not ob.visible, "réglage désactivé : barres masquées")
	GameSettings.set_overhead_bars(true)
	await _wait(0.7)
	_check(ob.visible, "réglage réactivé")
	# Réglages : la case existe et reflète la valeur
	var sp := SettingsPanel.new()
	sv.add_child(sp)
	await _frames(2)
	_check(sp._overhead != null and sp._overhead.button_pressed, "Réglages : case « Barres au-dessus du personnage »")
	sv.queue_free()
	await _frames()
