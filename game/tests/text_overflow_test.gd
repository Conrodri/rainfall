extends Node
## Débordement de texte : ouvre les écrans (menus, fiches, options, progression, récap, HUD avec boss, pause, coffre)
## en 1920x1080, 2400x1080 et 1440x1080, souris puis tactile. Pour chaque Label / Button / RichTextLabel visible :
## texte rendu (largeur, hauteur, autowrap compris) dans son rect, rect dans le parent cadre/écran, pas de
## chevauchement entre frères texte. Liste chaque échec : écran / chemin / texte / dépassement px.
## Contrôles ajoutés (26/10) : hauteur de ligne contre hauteur de la barre (ProgressBar = cadre), textes dessinés en
## `_draw` (méthode `text_rects()` des contrôles : rect global, taille de police, zones à éviter), textes du monde
## (Labels hors CanvasLayer : entièrement dans la vue, hors zones réservées du HUD), montée de niveau, panneau
## d'objectifs, infobulle de sort, chevauchement des zones du HUD entre elles, plancher de police.
## Règle de marge verticale (26/10) : entre la boîte de texte (ascent + descent réels de la police) et le bord intérieur
## visible du cadre (UiTheme.frame_edge), au moins UiTheme.ink_pad(taille) = max(4 px, 15 % de la taille). Les textes
## dessinés en `_draw` la passent via la clé `frame` (Rect2 : bord intérieur visible du cadre) de text_rects().
## godot --path game res://tests/text_overflow_test.tscn [-- --only=title|newrun|settings|endrun|hud --quick --textscale=0|1|2]
## RESULT: OK si 0 échec.

const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1440, 1080)]
const TOL := 2.0
const MIN_GAP := 6.0 ## écart mini entre deux textes dessinés sur la même ligne (px)

class FakeProfile extends RefCounted:
	var rubies := 4820
	var unlocked_modes: Array = ["facile", "moyen"]
	var unlocked_spells: Array = []
	var last_mode := "moyen"
	var last_character := "averse"
	var stats := {"runs": 37, "victories": 5, "kills": 18423, "play_time_s": 43200.0, "best_time_s": {"facile": 812.0}}
	var unlocked_skins: Array = ["ardent_skin1", "averse_skin1"]
	var selected_skin := {"averse": "averse_skin1"}
	## Meilleures runs (panneau) : records chargés (nombreux objets, deux variantes) en Facile et Difficile, aucun en Moyen.
	var best_runs := {"averse": {
		"facile": {"time_s": 812.0, "date": "2026-10-26T22:57:23", "level": 18, "kills": 18423, "stage": 5,
			"items": {"moisson": 12, "lame_jumelle": 1, "orbe_de_veille": 3, "nova_infinie": 1, "armure_du_colosse": 2, "marque_du_chasseur": 1,
				"bouclier_reactif": 1, "faveur_du_marchand": 4, "couronne_d_echo": 1, "de_pipe": 1, "coeur_du_chronomancien": 1, "venin_concentre": 2},
			"variants": {"2": "averse_geyser", "3": "averse_gouttiere"}},
		"difficile": {"time_s": 3725.0, "date": "2026-10-27T10:00:00", "level": 31, "kills": 123456, "stage": 5, "items": {}, "variants": {}}}}

	func is_unlocked(_key: StringName) -> bool:
		return false

var failures: Array[String] = []
var _checked := 0
var _only := ""
var _quick := false
var _shot_dir := ""
var _shot_n := 0
var _main: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.substr(7)
		elif a == "--quick":
			_quick = true
		elif a.begins_with("--shots="):
			_shot_dir = a.substr(8)
		elif a.begins_with("--textscale="): # 0 / 1 / 2 : « Taille du texte » 100 / 115 / 130 % (accessibilité)
			GameSettings.text_scale_override = int(a.substr(12))
			Accessibility.apply_text_scale()
	await _frames(3)
	for touch in [false, true]:
		_set_touch(touch)
		for sz in SIZES:
			if _quick and sz == SIZES[2]:
				continue
			get_window().size = sz
			await _frames(3)
			await _menus("%dx%d/%s" % [sz.x, sz.y, "tactile" if touch else "souris"])
	if _wants("hud"):
		await _hud_runs()
	print("Contrôles texte vérifiés : ", _checked)
	for f in failures:
		print("FAIL ", f)
	print("RESULT: ", "OK" if failures.is_empty() else "FAIL (%d)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _set_touch(touch: bool) -> void:
	Platform.set_input_mode(Platform.InputMode.TOUCH if touch else Platform.InputMode.KBM)


func _wants(n: String) -> bool:
	return _only == "" or _only == n


func _menus(tag: String) -> void:
	if _wants("title"):
		var t := (load("res://scenes/menu/title.tscn") as PackedScene).instantiate() as TitleScreen
		t.summary_provider = func(): return {"character": "ardent", "character_name": "Ardent", "mode": "moyen", "stage": 2, "active_time_s": 252.0, "map_id": "terrasses_noyees", "saved_at": 0}
		add_child(t)
		await _frames(30)
		_scan(t, "%s titre" % tag)
		t.queue_free()
		var c := (load("res://scenes/menu/credits.tscn") as PackedScene).instantiate()
		add_child(c)
		await _frames(20)
		_scan(c, "%s crédits" % tag)
		c.queue_free()
		await _frames(2)
	if _wants("newrun"):
		var s := NewRunScreen.new()
		s.profile = FakeProfile.new()
		add_child(s)
		await _frames(20)
		_scan(s, "%s nouvelle-run/liste" % tag)
		for i in s.characters.size():
			s.cards[i].pressed.emit()
			await _frames(12)
			_scan(s, "%s fiche/%s" % [tag, String(s.characters[i].get("id", i))])
		s.queue_free()
		await _frames(2)
	if _wants("settings"):
		var st := (load("res://scenes/menu/settings.tscn") as PackedScene).instantiate()
		add_child(st)
		await _frames(20)
		_scan(st, "%s options" % tag)
		st._show(st.controls)
		await _frames(10)
		_scan(st, "%s options/commandes" % tag)
		st.queue_free()
		var pr := (load("res://scenes/menu/progress.tscn") as PackedScene).instantiate()
		pr.set("profile", FakeProfile.new())
		add_child(pr)
		await _frames(20)
		_scan(pr, "%s progression" % tag)
		pr.tab_skins.pressed.emit()
		await _frames(6)
		_scan(pr, "%s progression/skins" % tag)
		pr.tab_chars.pressed.emit()
		await _frames(3)
		for ch in pr.characters:
			if str(ch.get("id", "")) == "averse":
				pr.open_best_runs(ch)
		await _frames(6)
		_scan(pr, "%s progression/meilleures runs" % tag)
		pr.queue_free()
		await _frames(2)
	if _wants("endrun"):
		for v in [false, true]:
			var e := EndRunScreen.create({"victory": v, "reason": "death", "character_name": "Averse", "mode": "moyen",
				"stage": 3, "active_time_s": 642.0, "level": 17, "pillars": 4, "kills": 1204, "items": 9, "gold": 230,
				"rubies": 87, "unlocks": [&"character:rictus", &"spell:roaming_embers", &"mode:difficile"]})
			add_child(e)
			await _frames(70)
			_scan(e, "%s récap/%s" % [tag, "victoire" if v else "défaite"])
			e.queue_free()
			await _frames(2)


func _hud_runs() -> void:
	RunState.character = &"averse"
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	_main.set(&"run_seed", 2024)
	add_child(_main)
	while not bool(_main.get(&"is_ready")):
		await _frames(1)
	var hud: Hud = _main.hud
	var p: Node2D = _main.player
	p.grant_invulnerability(1.0e6)
	var d: Director = _main.director
	var pp: Vector2 = p.global_position
	d.spawn_boss(&"etage", pp + Vector2(560, -280))
	d.spawn_boss(&"mini", pp + Vector2(-480, 220))
	RunState.difficulty_changed.emit(4.4, &"Furieux")
	var chest_scene := load("res://scenes/chests/chest.tscn") as PackedScene
	for off in [Vector2(900, 100), Vector2(-900, -120), Vector2(250, -520), Vector2(-250, 520), Vector2(1100, 600),
			Vector2(-1000, 500), Vector2(1000, -450), Vector2(0, -700), Vector2(1250, 120), Vector2(-1300, 100)]:
		var ch := chest_scene.instantiate() as Node2D
		ch.call(&"setup", &"large", 1)
		p.get_parent().add_child(ch)
		ch.global_position = pp + off
	for touch in [false, true]:
		_set_touch(touch)
		Platform.mobile_preview = touch # tactile = vrai mobile pour le HUD (planchers 26 px, tables mobiles)
		for sz in SIZES:
			if _quick and sz == SIZES[2]:
				continue
			get_window().size = sz
			await _frames(40)
			var tag := "%dx%d/%s" % [sz.x, sz.y, "tactile" if touch else "souris"]
			_scan(hud, "%s HUD" % tag)
			_scan_draw(hud, "%s HUD/_draw" % tag)
			_scan_hud_zones(hud, "%s HUD/zones" % tag)
			await _hud_extras(hud, tag)
			hud.pause_menu.open()
			await _frames(20)
			_scan(hud.pause_menu, "%s pause" % tag)
			hud.pause_menu._close()
			await _frames(4)
			hud.pause_menu.open_items()
			await _frames(20)
			_scan(hud.pause_menu, "%s pause/objets" % tag)
			hud.pause_menu._close()
			await _frames(4)
			var ui := (load("res://scenes/ui/chest/chest_ui.tscn") as PackedScene).instantiate() as ChestUI
			_main.add_child(ui)
			ui.open(&"large", 2, 60.0)
			await _frames(150)
			_scan(ui, "%s coffre" % tag)
			get_tree().paused = false
			ui.queue_free()
			await _frames(3)
	Platform.mobile_preview = false
	_main.queue_free()


## Montée de niveau, panneau d'objectifs, infobulle de sort : affichés puis scannés (hud = HUD de la run).
func _hud_extras(hud: Hud, tag: String) -> void:
	hud.call(&"_on_level", RunState.level + 1)
	var mgr := get_tree().get_first_node_in_group("stage_manager")
	if mgr != null:
		mgr.set("floor_cleared", true)
	var sb: SpellButton = hud.bar_buttons[1] if hud.bar_buttons[1].is_visible_in_tree() else hud.spell_buttons[0]
	var info := hud.spell_hint.describe(sb)
	hud.spell_hint.tip.show_for(sb, info.title, info.tag, info.body)
	await _frames(12)
	_scan(hud, "%s HUD/niveau+objectifs+infobulle" % tag)
	_scan_draw(hud, "%s HUD/niveau+objectifs+infobulle/_draw" % tag)
	_scan_hud_zones(hud, "%s HUD/zones+objectifs" % tag)
	if mgr != null:
		mgr.set("floor_cleared", false)
	hud.spell_hint.tip.hide_tip()
	await _frames(4)


## Textes dessinés en `_draw` : tout contrôle exposant `text_rects()` -> Array[Dictionary]
## {text, rect (global), size (px police), within? (Rect2), avoid? (Array[Rect2]), decor? (bool : pas de plancher)}.
func _scan_draw(root: Node, screen: String) -> void:
	var vp := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var floor_px := HudMetrics.floor_px()
	var owners: Array[Control] = []
	_collect_draw(root, owners)
	for o in owners:
		var items: Array = o.call(&"text_rects")
		for i in items.size():
			var it: Dictionary = items[i]
			var r: Rect2 = it["rect"]
			var txt := String(it.get("text", ""))
			_checked += 1
			var tag := "%s | %s | « %s » | " % [screen, o.get_path(), txt.left(40)]
			if not bool(it.get("decor", false)) and int(it.get("size", floor_px)) < floor_px:
				failures.append(tag + "police %d px < plancher %d" % [int(it["size"]), floor_px])
			if it.has("within"):
				var w: Rect2 = it["within"]
				var ov := maxf(maxf(w.position.x - r.position.x, r.end.x - w.end.x), maxf(w.position.y - r.position.y, r.end.y - w.end.y))
				if ov > TOL:
					failures.append(tag + "sort de sa zone de %.0f px" % ov)
			if it.has("frame") and not bool(it.get("decor", false)):
				var fr: Rect2 = it["frame"]
				var padv := UiTheme.ink_pad(int(it.get("size", 18))) - 0.5
				var gtop := r.position.y - fr.position.y
				var gbot := fr.end.y - r.end.y
				if minf(gtop, gbot) < padv:
					failures.append(tag + "marge verticale %.1f px < %.1f (haut %.1f, bas %.1f)" % [minf(gtop, gbot), padv, gtop, gbot])
			for av: Rect2 in it.get("avoid", []):
				var inter := av.intersection(r)
				if inter.size.x > TOL and inter.size.y > TOL:
					failures.append(tag + "chevauche un élément voisin de %.0f px" % minf(inter.size.x, inter.size.y))
			var sv := maxf(maxf(vp.position.x - r.position.x, r.end.x - vp.end.x), maxf(vp.position.y - r.position.y, r.end.y - vp.end.y))
			if sv > TOL:
				failures.append(tag + "sort de l'écran de %.0f px" % sv)
			for j in range(i + 1, items.size()):
				var r2: Rect2 = items[j]["rect"]
				var inter2 := r.intersection(r2)
				if inter2.size.x > TOL and inter2.size.y > TOL:
					failures.append(tag + "chevauche « %s » de %.0f px" % [String(items[j].get("text", "")), minf(inter2.size.x, inter2.size.y)])
				elif absf(r.get_center().y - r2.get_center().y) < minf(r.size.y, r2.size.y) * 0.5:
					var gap := maxf(r2.position.x - r.end.x, r.position.x - r2.end.x)
					if gap < MIN_GAP:
						failures.append(tag + "collé à « %s » (écart %.0f px < %.0f)" % [String(items[j].get("text", "")), gap, MIN_GAP])
			for sib in o.get_parent().get_children():
				if sib != o and sib is Control and (sib as Control).visible and sib.has_method(&"text_rects"):
					var inter3 := (sib as Control).get_global_rect().intersection(r)
					if inter3.size.x > TOL and inter3.size.y > TOL:
						failures.append(tag + "chevauche le contrôle voisin %s de %.0f px" % [sib.name, minf(inter3.size.x, inter3.size.y)])


func _collect_draw(n: Node, out: Array[Control]) -> void:
	for ch in n.get_children():
		if ch is CanvasItem and not (ch as CanvasItem).visible:
			continue
		if ch is Control and ch.has_method(&"text_rects") and (ch as Control).is_visible_in_tree():
			out.append(ch as Control)
		_collect_draw(ch, out)


## Textes du monde (prix des coffres…) : plus contrôlés ici. Décision du joueur (27/10/2026) : ils restent accrochés
## à leur objet, quitte à sortir de l'écran ou à passer sous le HUD, au lieu de glisser pour rester lisibles.


## Zones du HUD (reserved_rects) : aucune ne doit en recouvrir une autre.
func _scan_hud_zones(hud: Hud, screen: String) -> void:
	var rects := hud.reserved_rects()
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var inter := rects[i].intersection(rects[j])
			if inter.size.x > TOL and inter.size.y > TOL:
				failures.append("%s | zone %d %s chevauche zone %d %s de %.0f px" % [screen, i, rects[i], j, rects[j], minf(inter.size.x, inter.size.y)])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# --- vérification ---------------------------------------------------------------------------

func _is_text(n: Node) -> bool:
	return n is Label or n is Button or n is RichTextLabel


func _text_of(c: Control) -> String:
	if c is Label:
		return (c as Label).text
	if c is Button:
		return (c as Button).text
	return (c as RichTextLabel).get_parsed_text()


## Taille du texte rendu dans la largeur disponible `w` (autowrap compris).
func _text_size(c: Control, w: float) -> Vector2:
	var font := c.get_theme_font(&"font")
	var fs := c.get_theme_font_size(&"font_size")
	var txt := _text_of(c)
	if c is Label:
		var l := c as Label
		var wrap := l.autowrap_mode != TextServer.AUTOWRAP_OFF
		var flags := TextServer.BREAK_MANDATORY
		if wrap:
			flags |= TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		return font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, w if wrap else -1.0, fs, l.max_lines_visible, flags)
	if c is RichTextLabel:
		var r := c as RichTextLabel
		return Vector2(r.get_content_width(), r.get_content_height())
	var b := c as Button
	if b.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND)
	return font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)


## Place disponible pour le texte (rect moins marges du style).
func _inner(c: Control) -> Vector2:
	var sz := c.size
	if c is Button:
		var sb := c.get_theme_stylebox(&"normal")
		if sb != null:
			sz -= Vector2(sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT), sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM))
		if (c as Button).icon != null:
			sz.x -= (c as Button).icon.get_width()
	return sz


func _in_scroll(n: Node, root: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != root:
		if p is ScrollContainer or (p is Control and (p as Control).clip_contents):
			return true # défilement ou zone rognée voulue (générique de crédits)
		p = p.get_parent()
	return false


func _frame_parent(c: Control) -> Control:
	var p := c.get_parent()
	while p != null:
		if p is Control and (p is PanelContainer or p is Panel or p is Button or p is ScrollContainer or p is ProgressBar):
			return p as Control
		p = p.get_parent()
	return null


## Marge verticale texte / bord intérieur visible du cadre le plus proche (cadre = parent encadré, ou le bouton lui-même).
func _check_v_pad(screen: String, c: Control, fp: Control, ts: Vector2) -> void:
	var frame: Control = c if c is Button else fp
	if frame == null or frame is ScrollContainer or frame is ProgressBar or c is RichTextLabel:
		return
	var sb: StyleBox = null
	if frame is Button:
		sb = frame.get_theme_stylebox(&"normal")
	elif frame is PanelContainer or frame is Panel:
		sb = frame.get_theme_stylebox(&"panel")
	var edge := UiTheme.frame_edge(sb)
	if edge <= 0.0:
		return
	var fs := c.get_theme_font_size(&"font_size")
	var need := UiTheme.ink_pad(fs) - 0.5
	var fr := frame.get_global_rect()
	var tr := _text_rect(c)
	var h := minf(ts.y, tr.size.y) if not (c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF) else ts.y
	var top := tr.position.y
	var bottom := tr.position.y + h
	if c is Label and (c as Label).vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		bottom = c.get_global_rect().end.y
		top = bottom - h
	var gap_top := top - (fr.position.y + edge)
	var gap_bot := (fr.end.y - edge) - bottom
	var gap := minf(gap_top, gap_bot)
	if gap < need:
		_fail(screen, c, "marge verticale (haut %.1f, bas %.1f, requis %.1f) manque de" % [gap_top, gap_bot, need + 0.5], need - gap)


func _fail(screen: String, c: Control, what: String, px: float) -> void:
	var t := _text_of(c).replace("\n", " ")
	failures.append("%s | %s | « %s » | %s %.0f px" % [screen, c.get_path(), t.left(60), what, px])


func _scan(root: Node, screen: String) -> void:
	var vp := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var texts: Array[Control] = []
	_collect(root, texts)
	for c in texts:
		if _text_of(c).strip_edges() == "":
			continue
		_checked += 1
		var r := _visual_rect(c)
		var scroll := _in_scroll(c, root)
		var inner := _inner(c)
		var ts := _text_size(c, inner.x)
		var clipped := (c is Label and ((c as Label).clip_text or (c as Label).text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING)) \
			or (c is Button and ((c as Button).clip_text or (c as Button).text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING))
		if not clipped and ts.x > inner.x + TOL:
			_fail(screen, c, "largeur texte > rect de", ts.x - inner.x)
		elif not clipped and not (c is RichTextLabel) and ts.y > inner.y + TOL:
			_fail(screen, c, "hauteur texte > rect de", ts.y - inner.y)
		if scroll:
			continue
		var fp := _frame_parent(c)
		if fp != null and fp is ProgressBar and ts.y > fp.size.y + TOL:
			_fail(screen, c, "ligne de texte plus haute que la barre %s de" % fp.name, ts.y - fp.size.y)
		_check_v_pad(screen, c, fp, ts)
		if fp != null:
			var pr := fp.get_global_rect()
			var ov := maxf(maxf(pr.position.x - r.position.x, r.end.x - pr.end.x), maxf(pr.position.y - r.position.y, r.end.y - pr.end.y))
			if ov > TOL:
				_fail(screen, c, "sort du cadre %s de" % fp.name, ov)
		var sv := maxf(maxf(vp.position.x - r.position.x, r.end.x - vp.end.x), maxf(vp.position.y - r.position.y, r.end.y - vp.end.y))
		if sv > TOL:
			_fail(screen, c, "sort de l'écran de", sv)
	var by_parent := {}
	for c in texts:
		if _text_of(c).strip_edges() == "" or _in_scroll(c, root):
			continue
		var pk := c.get_parent()
		if not by_parent.has(pk):
			by_parent[pk] = []
		by_parent[pk].append(c)
	for pk in by_parent:
		if pk is Container:
			continue # un conteneur ne superpose pas ses enfants
		var arr: Array = by_parent[pk]
		for i in arr.size():
			for j in range(i + 1, arr.size()):
				var a := _text_rect(arr[i] as Control)
				var b := _text_rect(arr[j] as Control)
				var inter := a.intersection(b)
				if inter.size.x > TOL and inter.size.y > TOL:
					_fail(screen, arr[i] as Control, "chevauche « %s » de" % _text_of(arr[j] as Control).left(30), minf(inter.size.x, inter.size.y))
	if _shot_dir != "" and not failures.is_empty() and failures[-1].begins_with(screen):
		_shot_n += 1
		CaptureUtil.save_viewport(get_viewport(), "%s/%03d_%s.png" % [_shot_dir, _shot_n, screen.replace("/", "_").replace(" ", "_")])


## Rect visuel : le rect du contrôle ; pour un contrôle agrandi par une animation (scale != 1), le rect du texte
## réellement dessiné (un Label plein largeur agrandi de 20 % déborderait sinon sans que le texte ne le fasse).
func _visual_rect(c: Control) -> Rect2:
	var sc := c.get_global_transform().get_scale()
	if absf(sc.x - 1.0) < 0.01 and absf(sc.y - 1.0) < 0.01:
		return c.get_global_rect()
	var tr := _text_rect(c)
	var ctr := tr.get_center()
	return Rect2(ctr - tr.size * sc * 0.5, tr.size * sc)


func _text_rect(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var ts := _text_size(c, _inner(c).x)
	var al := (c as Label).horizontal_alignment if c is Label else HORIZONTAL_ALIGNMENT_CENTER
	var w := minf(ts.x, r.size.x)
	var x := r.position.x
	if al == HORIZONTAL_ALIGNMENT_CENTER:
		x += (r.size.x - w) * 0.5
	elif al == HORIZONTAL_ALIGNMENT_RIGHT:
		x += r.size.x - w
	var h := minf(ts.y, r.size.y)
	var y := r.position.y
	if c is Button or (c is Label and (c as Label).vertical_alignment == VERTICAL_ALIGNMENT_CENTER):
		y += (r.size.y - h) * 0.5
	return Rect2(x, y, w, h)


func _collect(n: Node, out: Array[Control]) -> void:
	for ch in n.get_children():
		if ch is CanvasItem and not (ch as CanvasItem).visible:
			continue
		if _is_text(ch) and (ch as Control).is_visible_in_tree() and (ch as CanvasItem).modulate.a > 0.05 and (ch as Control).size.x > 1.0:
			out.append(ch as Control)
		_collect(ch, out)
