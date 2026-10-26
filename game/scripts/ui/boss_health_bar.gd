class_name BossHealthBar
extends Control
## Barre de PV « riche » d'un boss (d'étage ou mini-boss) dans le HUD (BossBars), dessinée en _draw.
## - Encoches aux seuils de phase RÉELS (`Enemy.phase_thresholds()`, relus toutes les 0,5 s) ; au
##   franchissement : l'encoche se brise (éclats), le segment perdu flashe blanc puis s'éteint, la barre
##   tremble (6 px, 0,3 s), le ghost est écrasé, la nouvelle teinte de phase balaie la barre (1 s).
## - Transition de phase (`Enemy.phase_transitioning()`) : remplissage grisé hachuré ; si
##   `Enemy.is_invulnerable()` : cadenas + « INVULNÉRABLE », aucun flash de coup.
## - Ressenti : barre retard (ghost maintenu 0,4 s puis rattrapage), flash au coup direct, tremblement si
##   >= 10 % des PV max ou critique (×1,5), éclat + étincelles au bord du remplissage, DoT sans flash
##   (ghost teinté du statut), pulsation sous 25 % (cadre et remplissage).
## - État du boss (`brain.boss_state_tag()` s'il existe : {text, color, kind}) : libellé à droite sous la barre
##   (ex. Anguille « PLONGÉE — DÉGÂTS RÉDUITS ») ; kind &"guarded" = remplissage désaturé bleu acier (dégâts
##   réduits), &"exposed" = liseré chaud qui pulse (fenêtre de dégâts). INVULNÉRABLE / TRANSITION priment.
## - Statuts : rangée d'icônes sous la barre (anneau de durée, stacks) + effet sur le remplissage
##   (braises qui montent, suintement qui goutte, givre, étoiles d'étourdissement).
## Assets HB1 (HpBarStyle.tex) chargés s'ils existent : boss_frame / mini_frame (9-patch), boss_fill (teintable),
## notch, notch_broken, shard, status_<id>, fx_burn / fx_poison / fx_frost (bandes animées) ; sinon formes.
## Valeurs : docs/HP_Bars_Recherche.md ; contrat : CONTRACTS.md « Barres de PV ».

## 9-patch des cadres HB1 (px source) : boss_frame.png 512×64, fenêtre creuse à 24 px des bords gauche /
## droit et 22 px des bords haut / bas ; coins non étirés = 32 px (côtés) et 24 px (haut / bas).
const FRAME_SRC_H := 64.0
const FRAME_WINDOW := Vector2(24.0, 22.0)
const FRAME_MARGIN := Vector2(32.0, 24.0)
const FILL_SRC_H := 32.0 ## boss_fill.png 256×32, tuilable horizontalement
const BAR_H := 18.0 ## hauteur du remplissage à ui_scale 1 (recherche : 14-18 px)
const ICON := 22.0 ## icônes de statut (recherche : 20 px boss)
const ROW_GAP := 7.0
const SPARKS_HIT := 5
const SHARDS_BREAK := 9
const DOT_TICK_S := 0.25
const BG_ALPHA := 0.92 ## fond plus opaque que les barres de monde (VFX clairs derrière le HUD)

var boss: Enemy = null
var is_floor := true
var ui_scale := 1.0

var _thresholds := PackedFloat32Array()
var _broken := PackedByteArray()
var _break_t := PackedFloat32Array() ## temps depuis la rupture (-1 = jamais)
var _thr_refresh := 0.0
var _frac := 1.0
var _ghost := 1.0
var _hold := 0.0
var _hit_clock := -10.0
var _flash := 0.0
var _shake := 0.0
var _shake_amp := 0.0
var _shake_dur := HpBarStyle.SHAKE_S
var _dot := 0 ## dernier DoT : 1 brûlure, 2 poison (tic coloré au bord)
var _dot_t := -10.0
var _clock := 0.0
var _appear := 0.0
var _sweep := -1.0 ## temps écoulé du balayage de teinte de phase (-1 = aucun)
var _transition := false
var _invuln := false
var _tag: Dictionary = {} ## état du boss (brain.boss_state_tag())
var _statuses: Array = []
var _st_total := {} ## id -> durée de référence de l'anneau (plus grande durée vue depuis le dernier rafraîchissement)
var _st_last := {}
var _sparks: Array[Dictionary] = [] ## {p, v, life, max, col, size}
var _rng := RandomNumberGenerator.new()
var _font: Font = null


func setup(p_boss: Enemy, p_is_floor: bool) -> void:
	boss = p_boss
	is_floor = p_is_floor
	_rng.seed = 7741
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_frac = _read_frac()
	_ghost = _frac
	refresh_thresholds()
	set_ui_scale(ui_scale)


func _ready() -> void:
	_font = get_theme_default_font()
	Events.enemy_damaged.connect(_on_damaged)


func _exit_tree() -> void:
	if Events.enemy_damaged.is_connected(_on_damaged):
		Events.enemy_damaged.disconnect(_on_damaged)


func set_ui_scale(s: float) -> void:
	ui_scale = s
	custom_minimum_size.y = (BAR_H + 2.0 * _frame_out().y + ROW_GAP) * s + _row_h() + 6.0 * s


# --- Lecture (tests) ----------------------------------------------------------------------------

func notch_fracs() -> PackedFloat32Array:
	return _thresholds.duplicate()


func broken_count() -> int:
	var n := 0
	for b in _broken:
		n += b
	return n


func fill_frac() -> float:
	return _frac


func ghost_frac() -> float:
	return _ghost


func status_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: Dictionary in _statuses:
		out.append(s["id"])
	return out


func is_transition_shown() -> bool:
	return _transition


func is_invulnerable_shown() -> bool:
	return _invuln


## Libellé d'état affiché sous la barre ("" = aucun).
func state_tag_text() -> String:
	return "" if _invuln or _transition or _tag.is_empty() else str(_tag.get("text", ""))


func phase_index() -> int:
	return 1 + broken_count()


## Relit les seuils du boss (cerveau / data / Balance) ; les encoches déjà franchies restent brisées sans
## rejouer d'effet.
func refresh_thresholds() -> void:
	var t := boss.phase_thresholds() if is_instance_valid(boss) else PackedFloat32Array()
	if t == _thresholds:
		return
	_thresholds = t
	_broken.resize(t.size())
	_break_t.resize(t.size())
	for j in t.size():
		_broken[j] = 1 if _frac <= t[j] else 0
		_break_t[j] = -1.0


# --- Mise à jour ----------------------------------------------------------------------------------

func _read_frac() -> float:
	if not is_instance_valid(boss):
		return 0.0
	return clampf(boss.hp / maxf(boss.max_hp, 1.0), 0.0, 1.0)


func _on_damaged(enemy: Node2D, amount: float, is_crit: bool, element: StringName) -> void:
	if enemy != boss or not is_instance_valid(boss):
		return
	var mhp := maxf(boss.max_hp, 1.0)
	var frac := _read_frac()
	if element == &"burn" or element == &"poison": # DoT : ni ghost ni flash, tic coloré au bord
		_dot = 1 if element == &"burn" else 2
		_dot_t = _clock
		return
	_ghost = clampf(maxf(_ghost, frac + amount / mhp), 0.0, 1.0)
	_hold = HpBarStyle.GHOST_HOLD_S
	_hit_clock = _clock
	if _invuln or Quality.flashes_level == 0:
		return
	_flash = HpBarStyle.FLASH_S
	if is_crit or amount / mhp >= HpBarStyle.SHAKE_MIN_FRAC:
		_start_shake(HpBarStyle.SHAKE_S, 4.0 * (HpBarStyle.SHAKE_CRIT_MULT if is_crit else 1.0))
	var inner := _inner_rect()
	var edge := Vector2(inner.position.x + inner.size.x * frac, inner.position.y + inner.size.y * 0.5)
	for k in (SPARKS_HIT + (2 if is_crit else 0)):
		_sparks.append({"p": edge + Vector2(0, _rng.randf_range(-0.4, 0.4) * inner.size.y),
			"v": Vector2(_rng.randf_range(10.0, 90.0), _rng.randf_range(-110.0, -20.0)) * ui_scale,
			"life": 0.0, "max": _rng.randf_range(0.25, 0.4), "col": HpBarStyle.COL_GLINT, "size": 2.0 * ui_scale})


func _start_shake(dur: float, amp: float) -> void:
	if GameSettings.reduce_motion():
		return # « Réduire les mouvements » : pas de tremblement de barre
	if _shake > 0.0 and _shake_amp >= amp * ui_scale:
		return
	_shake = dur
	_shake_dur = dur
	_shake_amp = amp * ui_scale


func _process(delta: float) -> void:
	_clock += delta
	_appear = minf(_appear + delta, HpBarStyle.APPEAR_S)
	if not is_instance_valid(boss):
		return
	_frac = _read_frac()
	_thr_refresh -= delta
	if _thr_refresh <= 0.0:
		_thr_refresh = 0.5
		refresh_thresholds()
	for j in _thresholds.size():
		if _broken[j] == 0 and _frac <= _thresholds[j]:
			_broken[j] = 1
			_break_t[j] = 0.0
			_on_break(j)
		elif _break_t[j] >= 0.0:
			_break_t[j] += delta
	if _hold > 0.0:
		_hold -= delta
	else:
		_ghost = HpBarStyle.ghost_step(_ghost, _frac, delta)
	_flash = maxf(_flash - delta, 0.0)
	_shake = maxf(_shake - delta, 0.0)
	if _sweep >= 0.0:
		_sweep += delta
		if _sweep > HpBarStyle.PHASE_SWEEP_S:
			_sweep = -1.0
	_transition = boss.phase_transitioning()
	_invuln = boss.is_invulnerable()
	var br: Variant = boss.brain
	_tag = br.boss_state_tag() if br != null and br.has_method(&"boss_state_tag") else {}
	_statuses = boss.status_list()
	for s: Dictionary in _statuses:
		var id: StringName = s["id"]
		var left: float = s["left"]
		if not _st_total.has(id) or left > float(_st_last.get(id, 0.0)) + 0.05:
			_st_total[id] = maxf(left, 0.1)
		_st_last[id] = left
	for id in _st_last.keys():
		if not status_ids().has(id):
			_st_last.erase(id)
			_st_total.erase(id)
	for i in range(_sparks.size() - 1, -1, -1):
		var sp := _sparks[i]
		sp["life"] = float(sp["life"]) + delta
		if float(sp["life"]) >= float(sp["max"]):
			_sparks.remove_at(i)
			continue
		sp["v"] = (sp["v"] as Vector2) + Vector2(0, 260.0 * ui_scale) * delta
		sp["p"] = (sp["p"] as Vector2) + (sp["v"] as Vector2) * delta
	queue_redraw()


## Seuil franchi : écrase le ghost, tremblement fort, éclats de l'encoche, balayage de la nouvelle teinte.
func _on_break(j: int) -> void:
	_ghost = _frac
	_hold = 0.0
	_sweep = 0.0
	if Quality.flashes_level == 0:
		return
	_start_shake(HpBarStyle.BREAK_SHAKE_S, HpBarStyle.BREAK_SHAKE_PX)
	var inner := _inner_rect()
	var p := Vector2(inner.position.x + inner.size.x * _thresholds[j], inner.position.y + inner.size.y * 0.5)
	for k in SHARDS_BREAK:
		var a := _rng.randf_range(-PI, 0.0) if k % 2 == 0 else _rng.randf_range(0.0, PI)
		_sparks.append({"p": p, "v": Vector2.from_angle(a) * _rng.randf_range(60.0, 170.0) * ui_scale,
			"life": 0.0, "max": _rng.randf_range(0.35, 0.6), "col": Color(0.86, 0.80, 0.72) if k % 3 else HpBarStyle.COL_GLINT,
			"size": _rng.randf_range(2.0, 4.0) * ui_scale, "shard": true})


# --- Géométrie --------------------------------------------------------------------------------------

## Débord du cadre autour du remplissage (px à ui_scale 1).
func _frame_out() -> Vector2:
	var k := BAR_H / (FRAME_SRC_H - 2.0 * FRAME_WINDOW.y)
	return FRAME_WINDOW * k if HpBarStyle.tex(_frame_name()) != null else Vector2(4.0, 4.0)


func _frame_name() -> String:
	return "boss_frame" if is_floor else "mini_frame"


## Rectangle du remplissage (coordonnées locales), déploiement depuis le centre compris.
func _inner_rect() -> Rect2:
	var s := ui_scale
	var fo := _frame_out() * s
	var full := maxf(size.x - 2.0 * fo.x, 10.0)
	var k := ease(_appear / HpBarStyle.APPEAR_S, 0.4)
	var w := full * k
	return Rect2(fo.x + (full - w) * 0.5, fo.y, w, BAR_H * s)


func _phase_color(ph: int) -> Color:
	if not is_floor:
		return HpBarStyle.COL_MINI if ph <= 1 else HpBarStyle.COL_PHASE[2]
	return HpBarStyle.COL_PHASE[clampi(ph - 1, 0, HpBarStyle.COL_PHASE.size() - 1)]


# --- Dessin ------------------------------------------------------------------------------------------

func _draw() -> void:
	if not is_instance_valid(boss):
		return
	var s := ui_scale
	var off := Vector2.ZERO
	if _shake > 0.0:
		var k := _shake / _shake_dur
		off = Vector2(sin(_clock * 97.0), cos(_clock * 71.0) * 0.5) * _shake_amp * k
	draw_set_transform(off)
	var inner := _inner_rect()
	var fo := _frame_out() * s
	var frame := inner.grow_individual(fo.x, fo.y, fo.x, fo.y)
	var pulse := HpBarStyle.low_pulse(_frac, _clock)
	_draw_frame(frame, inner, pulse)
	draw_rect(inner, Color(HpBarStyle.COL_BG, BG_ALPHA))
	var fx := inner.size.x * _frac
	# ghost (barre retard)
	var gx := inner.size.x * _ghost
	if gx > fx + 0.5:
		var gcol := HpBarStyle.COL_GHOST_HIT if _clock - _hit_clock < HpBarStyle.GHOST_WHITE_S else HpBarStyle.COL_GHOST
		draw_rect(Rect2(inner.position.x + fx, inner.position.y, gx - fx, inner.size.y), gcol)
	# remplissage : teinte de phase (balayage après rupture), statut, transition, pulsation, flash
	var ph := phase_index()
	var col := _phase_color(ph)
	if _transition: # (statuts : icônes + effets sur le remplissage, la teinte de phase reste lisible)
		col = col.lerp(HpBarStyle.COL_TRANSITION, 0.65)
	var tag_kind: StringName = _tag.get("kind", &"")
	if tag_kind == &"guarded" and not _transition: # dégâts réduits : teinte de phase éteinte vers le bleu acier
		col = col.lerp(Color(0.30, 0.45, 0.56), 0.6)
	col = HpBarStyle.brighten(col, pulse)
	var fill_r := Rect2(inner.position, Vector2(fx, inner.size.y))
	_draw_fill(fill_r, col)
	if _sweep >= 0.0 and not _transition:
		var old := _phase_color(ph - 1)
		var k := clampf(_sweep / HpBarStyle.PHASE_SWEEP_S, 0.0, 1.0)
		var sx := fx * k
		_draw_fill(Rect2(inner.position.x + sx, inner.position.y, fx - sx, inner.size.y), HpBarStyle.brighten(old, pulse))
		if fx > 0.0:
			draw_rect(Rect2(inner.position.x + sx - 2.0 * s, inner.position.y, 2.0 * s, inner.size.y), Color(HpBarStyle.COL_GLINT, 0.5 * (1.0 - k)))
	_draw_status_fx(fill_r, inner)
	if _transition:
		_draw_hatch(fill_r)
	if _flash > 0.0 and fx > 0.0: # flash partiel : bord du segment touché seulement
		var fl := 1.0 if _flash > HpBarStyle.FLASH_S - HpBarStyle.FLASH_FULL_S else _flash / (HpBarStyle.FLASH_S - HpBarStyle.FLASH_FULL_S)
		var ew := minf(HpBarStyle.FLASH_EDGE_PX * s, fx)
		draw_rect(Rect2(inner.position.x + fx - ew, inner.position.y, ew, inner.size.y), Color(HpBarStyle.COL_GLINT, HpBarStyle.FLASH_ALPHA * fl))
	# éclat au bord du remplissage ; tic de DoT = bord coloré du statut
	if fx > 0.0:
		var ga := 0.35 + (0.15 if _flash > 0.0 else 0.0)
		draw_rect(Rect2(inner.position.x + fx - 2.0 * s, inner.position.y, 2.0 * s, inner.size.y), Color(HpBarStyle.COL_GLINT, ga))
		var dt := _clock - _dot_t
		if dt < DOT_TICK_S and _flash <= 0.0:
			var dc := HpBarStyle.brighten(HpBarStyle.status_color(&"burn" if _dot == 1 else &"poison"), 0.3)
			draw_rect(Rect2(inner.position.x + fx - 4.0 * s, inner.position.y, 4.0 * s, inner.size.y), Color(dc, 1.0 - dt / DOT_TICK_S))
	_draw_notches(inner)
	for sp in _sparks:
		var k2 := 1.0 - float(sp["life"]) / float(sp["max"])
		var sz: float = sp["size"]
		draw_rect(Rect2((sp["p"] as Vector2) - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(sp["col"] as Color, k2))
	if tag_kind == &"exposed" and not _transition and not _invuln: # fenêtre de dégâts : liseré chaud qui pulse
		draw_rect(inner.grow(1.0 * s), Color(_tag.get("color", Color.WHITE) as Color, 0.45 + 0.35 * sin(_clock * 7.0)), false, 2.0 * s)
	if _invuln:
		_draw_lock(Vector2(frame.end.x - 2.0 * s, inner.position.y + inner.size.y * 0.5), 9.0 * s)
	_draw_status_row(frame)
	draw_set_transform(Vector2.ZERO)


func _draw_frame(frame: Rect2, inner: Rect2, pulse: float) -> void:
	var s := ui_scale
	var t := HpBarStyle.tex(_frame_name())
	if t != null:
		var k := inner.size.y / (FRAME_SRC_H - 2.0 * FRAME_WINDOW.y)
		HpBarStyle.nine_patch(self, t, frame, FRAME_MARGIN, k)
		if pulse > 0.0:
			draw_rect(frame, Color(HpBarStyle.COL_PHASE[2], pulse * 0.8), false, 2.0 * s)
		return
	draw_rect(frame.grow(1.0 * s), HpBarStyle.COL_OUTLINE)
	draw_rect(frame, HpBarStyle.COL_FRAME_DARK)
	var edge := HpBarStyle.COL_FRAME.lerp(HpBarStyle.COL_PHASE[2], pulse * 3.0)
	draw_rect(frame, edge, false, 2.0 * s)
	draw_rect(Rect2(frame.position + Vector2(2, 1) * s, Vector2(frame.size.x - 4.0 * s, 1.0 * s)), Color(0.62, 0.56, 0.50, 0.55)) # arête haute éclairée (lumière haut-gauche)
	if is_floor: # embouts en pointe (fer) aux deux extrémités
		var cy := frame.position.y + frame.size.y * 0.5
		var hh := frame.size.y * 0.5 + 3.0 * s
		for side in [-1.0, 1.0]:
			var x: float = frame.position.x if side < 0.0 else frame.end.x
			var pts := PackedVector2Array([Vector2(x, cy - hh), Vector2(x + side * 10.0 * s, cy), Vector2(x, cy + hh)])
			draw_colored_polygon(pts, HpBarStyle.COL_FRAME_DARK)
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2]]), edge, 1.5 * s)
	draw_rect(inner.grow(1.0 * s), Color(0, 0, 0, 0.85), false, 1.0 * s)


func _draw_fill(r: Rect2, col: Color) -> void:
	if r.size.x <= 0.0:
		return
	var t := HpBarStyle.tex("boss_fill")
	if t != null:
		var k := r.size.y / FILL_SRC_H
		draw_texture_rect_region(t, r, Rect2(0, 0, r.size.x / k, FILL_SRC_H), col)
		return
	draw_rect(r, col)
	draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.55, r.size.x, r.size.y * 0.45), Color(HpBarStyle.COL_FILL_LOW, 0.55))
	draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.12, r.size.x, maxf(r.size.y * 0.12, 1.0)), Color(1, 0.92, 0.8, 0.22))


## Effets de statut sur le remplissage (bandes HB1 fx_<id> si livrées, sinon formes simples).
func _draw_status_fx(fill_r: Rect2, inner: Rect2) -> void:
	var s := ui_scale
	for st: Dictionary in _statuses:
		var id: StringName = st["id"]
		var col := HpBarStyle.status_color(id)
		var stacks: int = st["stacks"]
		var t := HpBarStyle.tex("fx_" + String(id))
		if t != null and fill_r.size.x > 0.0:
			var k := fill_r.size.y / t.get_size().y
			draw_texture_rect_region(t, fill_r, Rect2(-_clock * 40.0, 0, fill_r.size.x / k, t.get_size().y), Color(col, 0.85))
			continue
		match id:
			&"burn": # braises qui montent du remplissage, plus nombreuses avec les stacks
				var n := clampi(2 + stacks, 3, 8)
				for k in n:
					var ph := fposmod(_clock * 0.9 + k * 0.37, 1.0)
					var x := fill_r.position.x + fposmod(k * 53.7 + floorf(_clock * 0.9 + k * 0.37) * 31.3, maxf(fill_r.size.x, 1.0))
					var y := fill_r.position.y + fill_r.size.y * 0.3 - ph * 16.0 * s
					var sz := (2.5 - ph * 1.5) * s
					draw_rect(Rect2(x, y, sz, sz), Color(col.lerp(HpBarStyle.COL_GLINT, 0.4), 1.0 - ph))
				draw_rect(Rect2(fill_r.position.x, fill_r.position.y, fill_r.size.x, 2.0 * s), Color(col, 0.35 + 0.25 * sin(_clock * 19.0)))
			&"poison": # suintement : gouttes qui tombent sous la barre (1 goutte / 0,8 s par point)
				var n2 := clampi(1 + stacks / 2, 2, 5)
				for k in n2:
					var ph2 := fposmod(_clock / 0.8 + k * 0.29, 1.0)
					var x2 := fill_r.position.x + fposmod(k * 71.3 + 17.0, maxf(fill_r.size.x, 1.0))
					var y2 := inner.end.y + ph2 * 10.0 * s
					draw_rect(Rect2(x2, inner.end.y, 2.0 * s, 2.0 * s), Color(col, 0.8))
					draw_rect(Rect2(x2, y2, 2.0 * s, (2.0 + 2.0 * ph2) * s), Color(col, 1.0 - ph2))
				draw_rect(Rect2(fill_r.position.x, fill_r.end.y - 3.0 * s, fill_r.size.x, 3.0 * s), Color(col, 0.35))
			&"frost": # givre : liseré pâle, cristaux fixes
				draw_rect(Rect2(inner.position.x, inner.position.y, inner.size.x, 2.0 * s), Color(col, 0.85))
				draw_rect(Rect2(inner.position.x, inner.end.y - 1.0 * s, inner.size.x, 1.0 * s), Color(col, 0.6))
				var x3 := fill_r.position.x + 6.0 * s
				while x3 < fill_r.end.x - 2.0 * s:
					draw_line(Vector2(x3, inner.position.y), Vector2(x3 + 3.0 * s, inner.position.y + inner.size.y * 0.35), Color(0.9, 0.96, 1.0, 0.5), 1.0 * s)
					x3 += 23.0 * s
			&"stun":
				draw_rect(fill_r, Color(col, 0.2))
				for k in 3:
					var a := _clock * 4.0 + k * TAU / 3.0
					var c := Vector2(inner.position.x + inner.size.x * 0.5, inner.position.y - 6.0 * s) + Vector2(cos(a) * 18.0, sin(a) * 3.0) * s
					HpBarStyle.draw_status_glyph(self, &"stun", c, 3.5 * s, Color(col, 0.9))
			&"imprisoned": # chaînes le long du cadre
				var x4 := inner.position.x
				while x4 < inner.end.x:
					draw_rect(Rect2(x4, inner.position.y - 3.0 * s, 6.0 * s, 3.0 * s), Color(col, 0.9), false, 1.0 * s)
					draw_rect(Rect2(x4, inner.end.y, 6.0 * s, 3.0 * s), Color(col, 0.9), false, 1.0 * s)
					x4 += 9.0 * s


## Hachures de transition (remplissage grisé, invulnérable ou figé).
func _draw_hatch(r: Rect2) -> void:
	if r.size.x <= 0.0:
		return
	var s := ui_scale
	var step := 7.0 * s
	var h := r.size.y
	var a := 0.30 + 0.12 * sin(_clock * 6.0)
	var x := r.position.x - fposmod(_clock * 20.0 * s, step)
	while x < r.end.x:
		var x0 := maxf(x, r.position.x)
		var x1 := minf(x + h, r.end.x)
		if x1 > x0:
			var y0 := r.end.y - (x0 - x)
			var y1 := r.end.y - (x1 - x)
			draw_line(Vector2(x0, y0), Vector2(x1, y1), Color(0.72, 0.70, 0.66, a), 1.5 * s)
		x += step


## Encoches de phase : intactes (trait sombre + arête claire + repères triangulaires hors du cadre) ;
## brisées (fissure éteinte) ; à la rupture, le segment perdu flashe blanc puis s'éteint.
func _draw_notches(inner: Rect2) -> void:
	var s := ui_scale
	var tn := HpBarStyle.tex("notch")
	var tb := HpBarStyle.tex("notch_broken")
	for j in _thresholds.size():
		var t := _thresholds[j]
		var x := inner.position.x + inner.size.x * t
		var top := inner.position.y
		var h := inner.size.y
		var bt := _break_t[j]
		if bt >= 0.0 and bt < HpBarStyle.BREAK_FLASH_S + HpBarStyle.BREAK_FADE_S:
			var a := 1.0 if bt < HpBarStyle.BREAK_FLASH_S else 1.0 - (bt - HpBarStyle.BREAK_FLASH_S) / HpBarStyle.BREAK_FADE_S
			var prev := _thresholds[j - 1] if j > 0 else 1.0
			var seg := Rect2(x, top, inner.size.x * (prev - t), h)
			draw_rect(seg, Color(HpBarStyle.COL_GLINT, 0.5 * a))
		if _broken[j] == 0:
			if tn != null:
				var w := h * tn.get_size().x / tn.get_size().y * 1.6
				draw_texture_rect(tn, Rect2(x - w * 0.5, top - h * 0.3, w, h * 1.6), false)
				continue
			draw_rect(Rect2(x - 2.0 * s, top, 4.0 * s, h), Color(0.03, 0.02, 0.02, 0.95))
			draw_rect(Rect2(x, top, 1.5 * s, h), Color(0.88, 0.82, 0.74, 0.9))
			for sgn in [-1.0, 1.0]: # repères hors du cadre (pointe vers la barre)
				var yb: float = top - 7.0 * s if sgn < 0.0 else top + h + 7.0 * s
				var tip: float = top - 0.5 * s if sgn < 0.0 else top + h + 0.5 * s
				var tri := PackedVector2Array([Vector2(x - 5.0 * s, yb), Vector2(x + 5.0 * s, yb), Vector2(x, tip)])
				draw_colored_polygon(tri, Color(0.86, 0.80, 0.72))
				draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0, 0, 0, 0.8), 1.0 * s)
		else:
			if tb != null:
				var w2 := h * tb.get_size().x / tb.get_size().y * 1.6
				draw_texture_rect(tb, Rect2(x - w2 * 0.5, top - h * 0.3, w2, h * 1.6), false)
				continue
			draw_polyline(PackedVector2Array([Vector2(x - 1.0 * s, top), Vector2(x + 2.0 * s, top + h * 0.4),
				Vector2(x - 2.0 * s, top + h * 0.65), Vector2(x + 1.0 * s, top + h)]), Color(0.02, 0.02, 0.02, 0.9), 2.0 * s)


func _draw_lock(c: Vector2, r: float) -> void:
	draw_arc(c + Vector2(0, -r * 0.35), r * 0.55, PI, TAU, 10, HpBarStyle.COL_TRANSITION.lightened(0.3), maxf(r * 0.25, 1.5))
	draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.3), Vector2(r * 1.6, r * 1.2)), HpBarStyle.COL_TRANSITION.lightened(0.3))
	draw_rect(Rect2(c + Vector2(-r * 0.12, 0.0), Vector2(r * 0.24, r * 0.45)), Color(0.08, 0.07, 0.06))


## Police des textes de la rangée d'état : jamais sous le plancher (18 px PC / 26 px mobile).
func _row_font_px(base: float) -> int:
	return maxi(int(base * ui_scale), HudMetrics.floor_px())


func _row_font() -> Font:
	return _font if _font != null else get_theme_default_font()


## Hauteur de la rangée sous le cadre : icônes ou ligne de texte (la plus haute).
func _row_h() -> float:
	var f := _row_font()
	var th := f.get_height(_row_font_px(16.0)) if f != null else 0.0
	return maxf(ICON * ui_scale, th)


## Texte tronqué avec « … » pour tenir dans `max_w` px (jamais sous 1 caractère).
func _fit_text(txt: String, fs: int, max_w: float) -> String:
	var f := _row_font()
	if f == null or f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
		return txt
	var t := txt
	while t.length() > 1 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		t = t.left(t.length() - 1)
	return t.strip_edges() + "…"


## Texte d'état de la rangée (INVULNÉRABLE / TRANSITION / état de combat) : {text, fs, color, pulse, outline, pos, rect}
## ou {} ; `frame` = cadre de la barre (coordonnées locales). Aligné à droite, après les icônes de statut.
func _row_text(frame: Rect2) -> Dictionary:
	var f := _row_font()
	if f == null:
		return {}
	var s := ui_scale
	var rowh := _row_h()
	var cy := frame.end.y + ROW_GAP * s + rowh * 0.5
	var txt := ""
	var fs := 0
	var col := Color.WHITE
	var outline := 3
	var pulse := 0.0
	if _invuln or _transition:
		txt = "INVULNÉRABLE" if _invuln else "TRANSITION"
		fs = _row_font_px(13.0)
		col = Color(0.85, 0.84, 0.8)
		pulse = 0.75 + 0.25 * sin(_clock * 6.0)
	elif not _tag.is_empty():
		txt = str(_tag.get("text", ""))
		fs = _row_font_px(16.0) # état de combat : un cran plus gros que les statuts (lisible d'un coup d'œil)
		col = _tag.get("color", Color.WHITE)
		outline = 4
		pulse = 0.85 + 0.15 * sin(_clock * 4.0)
	else:
		return {}
	var icons_end := frame.position.x + 6.0 * s + _statuses.size() * (ICON * s + 6.0 * s)
	var max_w := maxf(frame.end.x - 4.0 * s - icons_end, 40.0 * s)
	txt = _fit_text(txt, fs, max_w)
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var th := f.get_height(fs)
	var left := frame.end.x - tw - 4.0 * s
	return {"text": txt, "fs": fs, "color": col, "pulse": pulse, "outline": outline,
		"pos": Vector2(left, cy - th * 0.5 + f.get_ascent(fs)), "rect": Rect2(left, cy - th * 0.5, tw, th)}


## Rangée d'icônes de statut sous le cadre (max 5) + texte d'état à droite.
func _draw_status_row(frame: Rect2) -> void:
	var s := ui_scale
	var sz := ICON * s
	var cy := frame.end.y + ROW_GAP * s + _row_h() * 0.5
	var cx := frame.position.x + 6.0 * s + sz * 0.5
	var fs := int(13.0 * s)
	for st: Dictionary in _statuses:
		var id: StringName = st["id"]
		var total: float = _st_total.get(id, 1.0)
		HpBarStyle.draw_status_icon(self, id, Vector2(cx, cy), sz, clampf(float(st["left"]) / total, 0.0, 1.0), int(st["stacks"]), _font, fs)
		cx += sz + 6.0 * s
	var rt := _row_text(frame)
	if not rt.is_empty():
		var c: Color = rt["color"]
		draw_string_outline(_font, rt["pos"], rt["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, rt["fs"], rt["outline"], Color(0, 0, 0, 0.9))
		draw_string(_font, rt["pos"], rt["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, rt["fs"], Color(c, float(rt["pulse"])))


## Texte d'état dessiné (rect global) pour text_overflow_test.
func text_rects() -> Array:
	var out: Array = []
	if not is_instance_valid(boss):
		return out
	var inner := _inner_rect()
	var fo := _frame_out() * ui_scale
	var frame := inner.grow_individual(fo.x, fo.y, fo.x, fo.y)
	var rt := _row_text(frame)
	if rt.is_empty():
		return out
	var g := get_global_rect().position
	var s := ui_scale
	var icons: Array = []
	for i in _statuses.size():
		icons.append(Rect2(g + Vector2(frame.position.x + 6.0 * s + i * (ICON * s + 6.0 * s), frame.end.y + ROW_GAP * s), Vector2(ICON * s, ICON * s)))
	var r: Rect2 = rt["rect"]
	out.append({"text": rt["text"], "size": rt["fs"], "rect": Rect2(g + r.position, r.size), "within": get_global_rect(), "avoid": icons})
	return out


static func _mask_of(statuses: Array) -> int:
	var m := 0
	for st: Dictionary in statuses:
		var i := HpBarStyle.STATUS_ORDER.find(st["id"])
		if i >= 0:
			m |= HpBarStyle.STATUS_BITS[i]
	return m
