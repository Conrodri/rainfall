class_name OverheadBars
extends Control
## Barre de vie + ressource du kit AU-DESSUS DE LA TÊTE du personnage joué (vague 3, retour joueur).
## Dessinées par le HUD en coordonnées écran (canvas transform de la caméra), un seul _draw.
## Taille adaptée au personnage : hauteur = haut OPAQUE du sprite d'idle (bounding box des pixels visibles de
## la frame 0 de `idle_s`, mise en cache par texture) × échelle de base du nœud Visual ; largeur proportionnelle
## à la hauteur visible à l'écran (bornée). Tocsin, Rainette, Avare… ont donc chacun leur hauteur et leur largeur.
## Langage visuel des barres de PV (HpBarStyle) : fond fer sombre, perte retard (ghost ambre maintenu puis
## rattrapé), flash de bord ambre court au coup (jamais de blanc pur), pulsation sous 25 %.
## Audit HUD lot C (H9) : la ressource se distingue des PV par la FORME, pas seulement la couleur : PV 10 px pleins avec
## liseré clair ; ressource plus fine (4 px), écart de 3 px, segmentée (encoches 1 px tous les 10 %, ou pastilles), losange
## d'icône à gauche, remplissage relevé à >= 3:1 sur son fond, cadre pulsé quand elle est pleine. Mobile : x1,25.
## Lisibilité (retour orchestrateur) : bloc sombre ~0,7 + liseré clair 1 px + ombre ; bloc sombre ~0,7 + liseré clair 1 px + ombre ;
## toujours visible en combat ; fondu seulement hors combat (IDLE_FADE_AFTER_S sans dégât, sans ennemi à moins de 8 u,
## ressource stable) ; réapparaît aussitôt au moindre coup / ennemi proche / gain / dépense.
## Gains ponctuels de ressource : petit « +N » flottant discret (pastilles : +1 ; jauge continue : saut de valeur),
## sauf pour les kits qui affichent déjà les leurs (OWN_POPUP_IDS : Averse, AverseWaterText).
## Réglage : GameSettings.overhead_bars() (Réglages > Jeu), relu par le HUD.
## Habillage : aplats aux couleurs de la jauge U1 (vert PV / accent du kit) + cadre fer fin en code : la texture
## de remplissage U1 essayée ici devient sombre et illisible à 4-7 px de haut (capture vague 3), donc non reprise.

const HP_H := 10.0 ## px écran à ui_scale 1 (audit H9 : PV pleins, épais)
const RES_H := 4.0 ## ressource plus fine que les PV
const PAD := 2.0 ## marge du bloc (fond sombre + liseré) autour des barres
const GAP := 3.0 ## écart PV / ressource (audit H9)
const MOBILE_K := 1.25 ## barres x1,25 en mode mobile (audit § 4.2)
const ICON_W := 7.0 ## losange de ressource, à gauche de la barre
const MARGIN := 8.0 ## entre le haut visible du sprite et le bas des barres
const W_MIN := 72.0
const W_MAX := 120.0
const W_PER_H := 0.6 ## largeur = hauteur visible du sprite à l'écran × W_PER_H
const IDLE_FADE_AFTER_S := 4.0 ## hors combat : ni dégât, ni ennemi proche, ni ressource qui bouge
const COMBAT_RADIUS := 8.0 * 64.0 ## ennemi actif à moins de 8 u = en combat
const NEAR_POLL_S := 0.2
const FADE_S := 0.35
const RES_EPS := 0.02 ## variation cumulée du niveau de ressource considérée comme une activité
const POPUP_S := 0.9
const POPUP_RISE := 26.0
const POPUP_MIN_JUMP := 0.06 ## saut de jauge continue (fraction) qui donne un « +N »
const OWN_POPUP_IDS: Array[StringName] = [&"water"] ## kits qui affichent eux-mêmes leurs gains
const COL_HP := Color("#52C45A") ## vie du joueur : vert vif non fluo (distinct de la braise des monstres)
const COL_HP_LOW := Color("#D9483A") ## sous LOW_HP_FRAC : rouge vif
const COL_HP_EDGE := Color("#B4E6A6") ## liseré haut (pas de blanc)
const COL_BLOCK := Color(0.035, 0.03, 0.028, 0.7) ## fond du bloc
const COL_BORDER := Color("#B9B3A6", 0.85) ## liseré fin clair désaturé
const COL_SHADOW := Color(0, 0, 0, 0.45)

var player: Node2D = null
var enabled := true
var ui_scale := 1.0
var hp_frac := 1.0
var ghost := 1.0
var res_state: Dictionary = {}
var alpha := 0.0 ## opacité courante (tests)
var bar_rect := Rect2() ## rect écran des barres (PV + ressource), tests
var head_px := 0.0 ## hauteur visible du sprite à l'écran (px), tests

var _head := Vector2(0, -64) ## décalage monde pieds -> haut opaque du sprite
var _head_key: Object = null ## SpriteFrames dont _head est tiré (cel / 3D : recalcul)
var _clock := 0.0
var _hold := 0.0
var _hit_t := -10.0
var _flash := 0.0
var _idle := 0.0
var _near_t := 0.0
var _enemy_near := false ## ennemi actif à moins de COMBAT_RADIUS (relu toutes les NEAR_POLL_S)
var _res_level := -1.0
var _res_ref := -1.0 ## niveau de référence de l'activité
var _res_filled := -1
var _res_id: StringName = &""
var _res_value := NAN
var _popups: Array = [] ## {text, t0, col}
var _font: Font = null

static var _top_cache := {} ## Texture2D -> ligne du premier pixel opaque


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font


func bind(p: Node) -> void:
	if p == player:
		return
	player = p as Node2D
	_head_key = null
	_res_level = -1.0
	_res_ref = -1.0
	_res_filled = -1
	_res_value = NAN
	_popups.clear()
	var hp: Variant = p.get(&"hp") if p != null else null
	var mx: Variant = p.get(&"max_hp") if p != null else null
	if hp != null and mx != null:
		hp_frac = clampf(float(hp) / maxf(float(mx), 1.0), 0.0, 1.0)
		ghost = hp_frac


## Premier pixel opaque (ligne) d'une texture, mis en cache ; 0 si illisible.
static func opaque_top(tex: Texture2D) -> int:
	if tex == null:
		return 0
	if _top_cache.has(tex):
		return int(_top_cache[tex])
	var top := 0
	var img: Image = null
	var at := tex as AtlasTexture
	if at != null and at.atlas != null: # planche compressée (VRAM) : région découpée dans l'atlas décompressé
		var full := _atlas_image(at.atlas)
		if full != null:
			var reg := Rect2i(at.region).intersection(Rect2i(Vector2i.ZERO, full.get_size()))
			if reg.size.x > 0 and reg.size.y > 0:
				img = full.get_region(reg)
				top = int(at.margin.position.y)
	else:
		img = tex.get_image()
		if img != null and img.is_compressed():
			img.decompress()
	if img != null and not img.is_compressed():
		var used := img.get_used_rect()
		if used.size.y > 0:
			top += used.position.y
	_top_cache[tex] = top
	return top


## Atlas décompressé (une fois par planche).
static func _atlas_image(atlas: Texture2D) -> Image:
	var k := "atlas:%d" % atlas.get_instance_id()
	if _top_cache.has(k):
		return _top_cache[k] as Image
	var img := atlas.get_image()
	if img != null and img.is_compressed():
		img = img.duplicate() as Image
		if img.decompress() != OK:
			img = null
	_top_cache[k] = img
	return img


## Décalage monde (depuis les pieds) du haut visible du sprite du personnage : frame 0 de `idle_s`,
## échelle de base du Visual (sans la respiration / l'écrasement animés).
static func head_offset(p: Node2D) -> Vector2:
	var v := p.get_node_or_null(^"Visual") as Node2D
	if v == null:
		return Vector2(0, -64)
	var sc := v.scale
	var bs: Variant = p.get(&"_vis_base_scale")
	if bs is Vector2 and (bs as Vector2).y != 0.0:
		sc = bs
	var top_local := -32.0
	var spr := v as AnimatedSprite2D
	if spr != null and spr.sprite_frames != null:
		var sf := spr.sprite_frames
		var anim: StringName = &"idle_s" if sf.has_animation(&"idle_s") else spr.animation
		if sf.has_animation(anim) and sf.get_frame_count(anim) > 0:
			var tex := sf.get_frame_texture(anim, 0)
			if tex != null:
				var h := float(tex.get_height())
				top_local = spr.offset.y + (-h * 0.5 if spr.centered else 0.0) + opaque_top(tex)
	return v.position + Vector2(0.0, top_local * sc.y)


func _process(delta: float) -> void:
	_clock += delta
	if not enabled or player == null or not is_instance_valid(player) or not player.is_inside_tree() \
			or player.get(&"dead") == true:
		if visible:
			visible = false
		alpha = 0.0
		_popups.clear()
		return
	visible = true
	var spr := player.get_node_or_null(^"Visual") as AnimatedSprite2D
	var key: Object = spr.sprite_frames if spr != null else player
	if key != _head_key:
		_head_key = key
		_head = head_offset(player)
	# --- PV : perte retard + flash (HpBarStyle)
	var hp: Variant = player.get(&"hp")
	var mx: Variant = player.get(&"max_hp")
	var frac := hp_frac
	if hp != null and mx != null:
		frac = clampf(float(hp) / maxf(float(mx), 1.0), 0.0, 1.0)
	if frac < hp_frac - 0.0005:
		_hold = _clock + HpBarStyle.GHOST_HOLD_S
		_hit_t = _clock
		_flash = _clock + HpBarStyle.FLASH_S
	hp_frac = frac
	if _clock >= _hold or ghost < hp_frac:
		ghost = HpBarStyle.ghost_step(ghost, hp_frac, delta)
	# --- Ressource
	_near_t -= delta
	if _near_t <= 0.0:
		_near_t = NEAR_POLL_S
		_enemy_near = _enemy_within(COMBAT_RADIUS)
	var active := _enemy_near or ghost > hp_frac + 0.001 # en combat : toujours visibles
	res_state = KitResource.of(player)
	if not res_state.is_empty():
		var lvl := KitResource.level(res_state)
		if _res_ref < 0.0 or absf(lvl - _res_ref) > RES_EPS:
			if _res_ref >= 0.0:
				active = true
			_res_ref = lvl
		if bool(res_state.get("blocked", false)) or bool(res_state.get("boost", false)) or bool(res_state.get("warn", false)):
			active = true
		_detect_gain(res_state, lvl)
		_res_level = lvl
	if active:
		_idle = 0.0
	else:
		_idle += delta
	var target := 1.0 if _idle < IDLE_FADE_AFTER_S else 0.0
	alpha = move_toward(alpha, target, delta / FADE_S)
	_place()
	for i in range(_popups.size() - 1, -1, -1):
		if _clock - float(_popups[i]["t0"]) > POPUP_S:
			_popups.remove_at(i)
	queue_redraw()


## Gain ponctuel : pastille de plus (+1) ou saut de jauge continue (+N lu dans `text` s'il est numérique).
func _detect_gain(st: Dictionary, lvl: float) -> void:
	var id := StringName(st.get("id", &""))
	if id != _res_id: # autre ressource (changement de kit) : pas de faux gain
		_res_id = id
		_res_filled = -1
		_res_value = NAN
	var pips := int(st.get("pips", 0))
	var filled := int(st.get("filled", 0))
	var value := float(String(st.get("text", "")).replace(",", ".")) if String(st.get("text", "")).replace(",", ".").is_valid_float() else NAN
	if not OWN_POPUP_IDS.has(id) and _res_level >= 0.0:
		var col: Color = st.get("color", Color(1.0, 0.55, 0.2))
		if pips > 0 and _res_filled >= 0 and filled > _res_filled:
			_pop("+%d" % (filled - _res_filled), col)
		elif pips == 0 and lvl - _res_level >= POPUP_MIN_JUMP and not is_nan(value) and not is_nan(_res_value) and value > _res_value:
			_pop("+%d" % roundi(value - _res_value), col)
	_res_filled = filled
	_res_value = value


func _pop(text: String, col: Color) -> void:
	if _popups.size() >= 4:
		_popups.pop_front()
	_popups.append({"text": text, "t0": _clock, "col": col})
	_idle = 0.0


## Position écran : relue au dessin (la caméra a fini de bouger dans l'image : aucun décalage d'une frame).
func _place() -> void:
	if player == null or not is_instance_valid(player):
		return
	var s := eff_scale()
	var xf := get_viewport().get_canvas_transform()
	var feet := xf * player.global_position
	var top := xf * (player.global_position + _head)
	head_px = absf(feet.y - top.y)
	var w := clampf(head_px * W_PER_H, W_MIN * s, W_MAX * s)
	var h := HP_H * s + ((GAP + RES_H) * s if not res_state.is_empty() else 0.0)
	bar_rect = Rect2(Vector2(top.x - w * 0.5, top.y - MARGIN * s - h), Vector2(w, h))


## Échelle effective : ui_scale du HUD x 1,25 en mode mobile.
func eff_scale() -> float:
	return ui_scale * (MOBILE_K if Platform.is_mobile() else 1.0)


func _draw() -> void:
	_place()
	if alpha <= 0.01 and _popups.is_empty():
		return
	var s := eff_scale()
	var r := Rect2(bar_rect.position, Vector2(bar_rect.size.x, HP_H * s))
	var a := alpha
	if a > 0.01:
		# bloc : ombre portée, fond sombre ~0,7, liseré fin clair désaturé (1 px)
		var block := bar_rect.grow(PAD * s)
		draw_rect(Rect2(block.position + Vector2(2.0, 2.0) * s, block.size), Color(COL_SHADOW, COL_SHADOW.a * a))
		draw_rect(block, Color(COL_BLOCK, COL_BLOCK.a * a))
		draw_rect(block.grow(0.5), Color(COL_BORDER, COL_BORDER.a * a), false, maxf(1.0, s))
		_draw_hp(r, s, a)
		if not res_state.is_empty():
			var rr := Rect2(Vector2(r.position.x, r.end.y + GAP * s), Vector2(r.size.x, RES_H * s))
			_draw_res(rr, s, a)
	# « +N » : depuis le bout droit de la barre de ressource, montent et s'effacent (même si la barre est fondue)
	var fs := maxi(int(16 * s), ResourceGauge.min_font())
	for p in _popups:
		var k := clampf((_clock - float(p["t0"])) / POPUP_S, 0.0, 1.0)
		var col: Color = (p["col"] as Color).lerp(Color("#E8E2D6"), 0.25)
		col.a = 1.0 - k * k
		var pos := Vector2(bar_rect.end.x + 4.0 * s, bar_rect.end.y - POPUP_RISE * s * k)
		draw_string_outline(_font, pos, String(p["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(4 * s), Color(0, 0, 0, 0.85 * col.a))
		draw_string(_font, pos, String(p["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Remplissage (aplat ; `frac` gardé pour un futur habillage).
func _fill(dst: Rect2, frac: float, col: Color) -> void:
	if dst.size.x <= 0.0:
		return
	draw_rect(dst, col)


func _enemy_within(radius: float) -> bool:
	var pp := player.global_position
	var r2 := radius * radius
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if e is Node2D and (e as Node2D).visible and e.get(&"active") != false 				and (e as Node2D).global_position.distance_squared_to(pp) <= r2:
			return true
	return false


## Fond de piste d'une barre (dans le bloc).
func _draw_frame(r: Rect2, _s: float, a: float) -> void:
	draw_rect(r, Color(HpBarStyle.COL_BG.r, HpBarStyle.COL_BG.g, HpBarStyle.COL_BG.b, 0.9 * a))


func _draw_hp(r: Rect2, s: float, a: float) -> void:
	_draw_frame(r, s, a)
	draw_rect(r.grow(0.5), Color(COL_HP_EDGE, 0.7 * a), false, maxf(1.0, s)) # liseré clair : PV = barre pleine encadrée
	var w := r.size.x
	if ghost > hp_frac:
		var gc := HpBarStyle.COL_GHOST_HIT if _clock - _hit_t < HpBarStyle.GHOST_WHITE_S + HpBarStyle.GHOST_HOLD_S else HpBarStyle.COL_GHOST
		draw_rect(Rect2(r.position + Vector2(w * hp_frac, 0), Vector2(w * (ghost - hp_frac), r.size.y)), Color(gc, a))
	if hp_frac > 0.0:
		var g := HpBarStyle.low_pulse(hp_frac, _clock)
		var fill := Rect2(r.position, Vector2(w * hp_frac, r.size.y))
		var hc := COL_HP if hp_frac > HpBarStyle.LOW_HP_FRAC else COL_HP_LOW
		_fill(fill, hp_frac, Color(HpBarStyle.brighten(hc, g), a))
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, maxf(1.0, 1.5 * s))), Color(COL_HP_EDGE, 0.8 * a))
		if _clock < _flash: # flash court et partiel : bord du remplissage, ambre
			var fw := minf(HpBarStyle.FLASH_EDGE_PX * s, fill.size.x)
			draw_rect(Rect2(Vector2(fill.end.x - fw, fill.position.y), Vector2(fw, fill.size.y)), Color(HpBarStyle.COL_GLINT, HpBarStyle.FLASH_ALPHA * a))


func _draw_res(r: Rect2, s: float, a: float) -> void:
	draw_rect(r, Color(ResourceGauge.BG, ResourceGauge.BG.a * a)) # fond de piste très sombre
	var acc: Color = (res_state.get("color", Color(1.0, 0.55, 0.2)) as Color).lerp(Color("#E8E2D6"), 0.22) # accent éclairci
	if bool(res_state.get("blocked", false)):
		acc = Color(acc.r * ResourceGauge.DIM, acc.g * ResourceGauge.DIM, acc.b * ResourceGauge.DIM)
	else:
		acc = ResourceGauge.lift(acc) # >= 3:1 sur le fond de piste (WCAG 1.4.11)
	_draw_res_icon(r, acc, s, a)
	var pips := int(res_state.get("pips", 0))
	if pips > 0: # segments, écart net
		var filled := int(res_state.get("filled", 0))
		var gap := 2.0 * s
		var sw := (r.size.x - gap * (pips - 1)) / float(pips)
		for i in pips:
			var seg := Rect2(r.position + Vector2((sw + gap) * i, 0), Vector2(sw, r.size.y))
			if i < filled:
				_fill(seg, 1.0, Color(acc, a))
			elif i == filled:
				var rt := clampf(float(res_state.get("ratio", 0.0)), 0.0, 1.0)
				_fill(Rect2(seg.position, Vector2(seg.size.x * rt, seg.size.y)), rt, Color(acc, 0.45 * a))
			else:
				draw_rect(seg, Color(ResourceGauge.EDGE_LIGHT, 0.35 * a), false, 1.0) # case vide : contour seul
	else:
		var rt := clampf(float(res_state.get("ratio", 0.0)), 0.0, 1.0)
		_fill(Rect2(r.position, Vector2(r.size.x * rt, r.size.y)), rt, Color(acc, a))
		for i in range(1, 10): # encoches 1 px sombres tous les 10 % : la ressource se lit « graduée », pas pleine comme les PV
			var xn := r.position.x + r.size.x * i * 0.1
			draw_line(Vector2(xn, r.position.y), Vector2(xn, r.end.y), Color(ResourceGauge.BG.r, ResourceGauge.BG.g, ResourceGauge.BG.b, 0.85 * a), maxf(1.0, s))
		var mark := float(res_state.get("mark", -1.0))
		if mark > 0.0 and mark < 1.0:
			var x := r.position.x + r.size.x * mark
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(HpBarStyle.COL_GLINT, 0.8 * a), maxf(1.0, s))
	if ResourceGauge.is_full(res_state): # pleine : cadre qui pulse (1 Hz)
		draw_rect(r.grow(1.5 * s), Color(ResourceGauge.EDGE_LIGHT, ResourceGauge.pulse_alpha(_clock) * a), false, maxf(1.0, s))


## Losange d'icône de ressource à gauche de la barre (forme propre à la ressource, absente des PV).
func _draw_res_icon(r: Rect2, acc: Color, s: float, a: float) -> void:
	var h := (RES_H + 3.0) * s
	var c := Vector2(r.position.x - (PAD + 1.0) * s - ICON_W * s * 0.5 - 1.0, r.position.y + r.size.y * 0.5)
	var pts := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.8, 0), c + Vector2(0, h), c + Vector2(-h * 0.8, 0)])
	draw_colored_polygon(pts, Color(acc, a))
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, Color(0.02, 0.02, 0.02, 0.9 * a), maxf(1.0, s))
