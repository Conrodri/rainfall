extends Node
## Débordement de texte : ouvre les écrans (menus, fiches, options, progression, récap, HUD avec boss, pause, coffre)
## en 1920x1080, 2400x1080 et 1440x1080, souris puis tactile. Pour chaque Label / Button / RichTextLabel visible :
## texte rendu (largeur, hauteur, autowrap compris) dans son rect, rect dans le parent cadre/écran, pas de
## chevauchement entre frères texte. Liste chaque échec : écran / chemin / texte / dépassement px.
## godot --path game res://tests/text_overflow_test.tscn [-- --only=title|newrun|settings|endrun|hud --quick]
## RESULT: OK si 0 échec.

const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1440, 1080)]
const TOL := 2.0

class FakeProfile extends RefCounted:
	var rubies := 4820
	var unlocked_modes: Array = ["facile", "moyen"]
	var unlocked_spells: Array = []
	var last_mode := "moyen"
	var last_character := "averse"
	var stats := {"runs": 37, "victories": 5, "kills": 18423, "play_time_s": 43200.0, "best_time_s": {"facile": 812.0}}

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
	for touch in [false, true]:
		_set_touch(touch)
		for sz in SIZES:
			if _quick and sz == SIZES[2]:
				continue
			get_window().size = sz
			await _frames(40)
			var tag := "%dx%d/%s" % [sz.x, sz.y, "tactile" if touch else "souris"]
			_scan(hud, "%s HUD" % tag)
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
	_main.queue_free()


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
		if p is Control and (p is PanelContainer or p is Panel or p is Button or p is ScrollContainer):
			return p as Control
		p = p.get_parent()
	return null


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
