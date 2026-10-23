class_name EnemyHealthBars
extends Node2D
## Barres de vie au-dessus des monstres blessés, toutes dessinées par CE seul nœud (un _draw, aucun
## nœud par monstre). À instancier une fois, sous AmbianceManager.telegraph_layer (coordonnées monde,
## ni éclairé ni étalonné) : unshaded, light_mask 0.
## Règles : visible seulement si le monstre a pris des dégâts et n'est pas à pleins PV ; masquée
## HIDE_AFTER_S après le dernier coup (fondu sur FADE_S) ; hauteur selon le tier ; le boss d'étage n'en a
## pas (barre de boss en haut de l'écran, HUD).
## Ressenti (docs/HP_Bars_Recherche.md, HpBarStyle) : barre retard (ghost) maintenue puis rattrapée, flash du
## remplissage au coup direct, tremblement sur gros coup / critique, éclat au bord, DoT sans flash ni
## maintien (ghost fin teinté du statut), pulsation sous 25 %.
## Statuts : monstres de base = teinte du statut dominant + petits pips colorés (bits Enemy.status_mask(),
## relus une image sur 8) ; élites et mini-boss = barre « riche » (cadre fer, encoches de phase du
## mini-boss, icônes 12 px avec anneau de durée et stacks), dessinée à part (peu nombreuses).
## Lot UX A11y-L1 : le statut dominant d'un monstre de BASE porte aussi un pictogramme de 16 px au bout de sa barre
## (StatusPictos : un atlas partagé, dessiné en lot, aucun nœud par monstre) ; la couleur seule ne porte plus le statut.
## Palette selon le mode daltonien (CvdPalette, lecture seule de GameSettings) : teinte, pips et tics de DoT suivent.
## Coût : un accès Dictionary par Events.enemy_damaged, puis une boucle sur les seuls monstres suivis ;
## 3 appels de dessin groupés pour toutes les barres de base + 1 pour TOUS les pictogrammes (triangles texturés).
## Perf (réparation vague 3) : aucun tableau alloué par image (tampons préalloués réécrits sur place), couleurs par
## mode daltonien en cache, picto du statut dominant recalculé seulement quand le masque change (relu 1 image sur 8).
## Caméra iso 2:1 : barres non plates au sol, le nœud porte Iso.UNSQUASH (espace billboard) ; positions (x, y/2).
## Habillage : assets HB1 (HpBarStyle.tex : elite_frame, mini_frame, status_<id>) s'ils existent, sinon formes.

const HIDE_AFTER_S := 3.0
const FADE_S := 0.3
const BAR_H := 6.0
const BORDER := 1.5
const PIP := 3.0 ## pips de statut (carrés) sous la barre des monstres de base
const PICTO := 16.0 ## pictogramme du statut dominant (monstres de base), à droite de la barre
const PICTO_GAP := 3.0
## tier -> {w: largeur px, y: hauteur du haut de la barre au-dessus des pieds (px)}
const TIER_GEOM := {
	1: {"w": 46.0, "y": 78.0},
	2: {"w": 54.0, "y": 92.0},
	3: {"w": 70.0, "y": 122.0},
	4: {"w": 140.0, "y": 170.0}, # mini-boss (le boss d'étage est exclu)
}
const ELITE_WIDTH_MULT := 1.4
const FEEL_MAX_BARS := 64
const DOT_TICK_S := 0.22 ## durée du tic coloré au bord après un dégât de DoT ## au-delà, barres de base sans ghost / flash / tremblement (horde)
const RICH_H := {1: 8.0, 2: 10.0} ## kind -> hauteur (élite, mini-boss)
const RICH_ICON := 12.0
const RICH_H_E := 8.0
const OFS_N := 6 ## décalages par barre (_ofs) : fond gauche, fond droit, début et fin du remplissage, picto, premier pip
const PIC_DX := Vector2(PICTO, 0.0)
const PIC_DY := Vector2(0.0, PICTO)
const PIC_D := Vector2(PICTO, PICTO)
const PIP_DX := Vector2(PIP, 0.0)
const PIP_STEP := Vector2(PIP + 1.0, 0.0)
const DOT_DX := Vector2(1.0, 0.0)
const ICON_DX := Vector2(RICH_ICON, 0.0)
const ICON_DY := Vector2(0.0, RICH_ICON)
const ICON_D := Vector2(RICH_ICON, RICH_ICON)
const ICON_DUR := Vector2(0.0, RICH_ICON + 1.5) ## trait de durée sous l'icône
const ICON_STEP := Vector2(RICH_ICON + 2.0, 0.0) ## = RICH_H[KIND_ELITE] (boucle : pas de lecture de Dictionary)
const COL_BG := HpBarStyle.COL_BG
const COL_FILL := HpBarStyle.COL_FILL
const COL_FILL_ELITE := HpBarStyle.COL_FILL ## recherche §5 : même rouge, le cadre distingue l'élite
const COL_FILL_BOSS := HpBarStyle.COL_MINI
const KIND_BASE := 0
const KIND_ELITE := 1
const KIND_MINI := 2

var stat_usec := 0 ## coût (µs) de la dernière mise à jour + dessin, pour les tests de perf
var _clock := 0.0
var _frame := 0
var _drawn := false
## Monstres suivis (tableaux parallèles, retrait par échange avec le dernier)
var _tracked: Array[Enemy] = []
var _index := {} ## Enemy -> index dans _tracked
var _last_hit := PackedFloat32Array()
var _half_w := PackedFloat32Array() ## demi-largeur (px), figée au premier coup
var _top := PackedFloat32Array() ## hauteur de la barre au-dessus des pieds (px)
var _kind := PackedByteArray()
var _ghost := PackedFloat32Array() ## fraction affichée par la barre retard
var _hold := PackedFloat32Array() ## échéance (horloge) du maintien du ghost
var _hit_t := PackedFloat32Array() ## horloge du dernier coup direct (couleur du ghost)
var _flash := PackedFloat32Array() ## échéance du flash
var _shake := PackedFloat32Array() ## échéance du tremblement
var _shake_amp := PackedFloat32Array()
var _dot := PackedByteArray() ## dernier DoT reçu : 0 aucun, 1 brûlure, 2 poison (tic coloré au bord)
var _dot_t := PackedFloat32Array() ## horloge du dernier tic de DoT
var _mask := PackedInt32Array() ## Enemy.status_mask() (relu une image sur 8)
## PV / PV max du monstre, mis à jour à chaque Events.enemy_damaged (seul chemin des dégâts) et relus une image sur 8
## (soins, réapparition, désactivation) : la boucle ne lit plus hp / max_hp / active à chaque image.
var _frac := PackedFloat32Array()
## Horde : géométrie d'une barre = point d'ancrage du monstre (x, y/2) + décalages figés au suivi (OFS_N par barre ;
## la fin du remplissage suit _frac) -> une addition de vecteurs par sommet au lieu d'un calcul complet.
var _ofs := PackedVector2Array()
## Horde : barre de base hors vue à sa dernière vérification (1). Revérifiée une image sur 8 seulement : la marge de
## la vue (160 px) couvre largement 7 images de déplacement, la barre réapparaît avant d'entrer à l'écran.
var _culled := PackedByteArray()
## Géométrie de la frame (barres de base) : 2 points par segment épais, 3 appels de dessin
var _bg_pts := PackedVector2Array()
var _bg_cols := PackedColorArray()
var _fill_pts := PackedVector2Array()
var _fill_cols := PackedColorArray()
var _pip_pts := PackedVector2Array()
var _pip_cols := PackedColorArray()
var _rich: Array[Dictionary] = [] ## barres d'élites / mini-boss de la frame (dessin individuel)
var _count := 0
var _draw_usec := 0
var _font: Font = null
var _elite_tex: Texture2D = null
## Élites groupées : 3 couches de ke segments (contour h+6, cadre h+4, fond h), un tableau par couche (aucun slice)
var _e0_pts := PackedVector2Array()
var _e0_cols := PackedColorArray()
var _e1_pts := PackedVector2Array()
var _e1_cols := PackedColorArray()
var _e2_pts := PackedVector2Array()
var _e2_cols := PackedColorArray()
var _e_n := 0
var _e_low_pts := PackedVector2Array()
var _e_low_cols := PackedColorArray()
var _ef_pts := PackedVector2Array()
var _ef_cols := PackedColorArray()
var _icon_en: Array[Enemy] = []
var _icon_pos := PackedVector3Array() ## (x0, haut de la rangée d'icônes, alpha)
var _bg_faded := false
var _n_rich := 0 ## barres suivies d'élites / mini-boss (0 = aucun travail sur les tableaux d'élites) ## au moins un fond en fondu cette image (sinon un seul draw_multiline monochrome)
var _tints := PackedColorArray() ## masque de statuts (0-31) -> teinte du remplissage, refaite à chaque image
var _pip_base := PackedColorArray() ## couleur des pips, ordre des bits Enemy.ST_*
var _dom_idx := PackedInt32Array() ## masque (0-31) -> index du pictogramme du statut dominant (-1 aucun)
var _cvd_mode := -1 ## mode daltonien pour lequel _tints / _pip_base ont été construits
var _burn_col := Color.WHITE
var _poison_col := Color.WHITE
var _dot_burn := Color.WHITE ## tic de DoT au bord (brûlure), éclairci ; en cache par mode
var _dot_poison := Color.WHITE
var _low_bit := PackedInt32Array() ## masque (1-31) -> bit le plus bas (pips : boucle sur les seuls bits actifs)
var _st_slot := {} ## id de statut -> index d'atlas StatusPictos
## Pictogrammes de la frame (statut dominant des monstres de base + icônes des élites groupées) : UN tableau de
## triangles texturés (atlas StatusPictos), 4 sommets par picto, tampons préalloués réécrits sur place.
var _pic_idx := PackedInt32Array() ## index d'atlas par picto (tests)
var _pq_pts := PackedVector2Array()
var _pq_uvs := PackedVector2Array()
var _pq_cols := PackedColorArray()
var _pq_state := PackedInt32Array() ## par case de picto : index d'atlas + 1 si UV et couleur opaques déjà écrits (0 = à écrire)
var _pq_ind := PackedInt32Array() ## 6 indices par picto, complétés seulement quand le nombre de pictos change
var _np := 0 ## pictos de la frame
var _uv_tab := PackedVector2Array() ## index d'atlas -> 4 UV (sens horaire depuis le coin haut-gauche)
var _dom := PackedInt32Array() ## par barre suivie : picto du statut dominant (-1 aucun), mis à jour quand le masque change
var _st_cache := {} ## élite groupée -> PackedFloat32Array (horloge de lecture + statuts compactés ; relu 1 image sur 8, durées extrapolées)
var _stk := PackedFloat32Array() ## stacks > 1 à écrire : (x, y, stacks, alpha) par entrée ; vide presque toujours
var _no_bones := PackedInt32Array()
var _no_weights := PackedFloat32Array()


func _ready() -> void:
	z_index = 100
	light_mask = 0
	scale = Iso.UNSQUASH
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	_font = ThemeDB.fallback_font
	Events.enemy_damaged.connect(_on_damaged)


func _exit_tree() -> void:
	if Events.enemy_damaged.is_connected(_on_damaged):
		Events.enemy_damaged.disconnect(_on_damaged)


## Pictogrammes de statut dessinés à la dernière image : tableau de {idx, id, color} (tests).
func picto_list() -> Array:
	var out: Array = []
	for j in _np:
		out.append({"idx": _pic_idx[j], "id": HpBarStyle.STATUS_ORDER[_pic_idx[j]], "color": _pq_cols[j * 4]})
	return out


## Nombre de pictogrammes de statut dessinés à la dernière image (perf, tests).
func picto_count() -> int:
	return _np


## Teinte du remplissage pour un masque de statuts, dans le mode daltonien courant (tests).
func tint_for_mask(mask: int) -> Color:
	_build_tints(0.0)
	return _tints[mask]


## Nombre de barres affichées à la dernière image (tests).
func visible_count() -> int:
	return _count


## État d'une barre suivie (tests, debug) : {frac, ghost, mask, flash, shake, kind} ; vide si non suivie.
func bar_info(enemy: Node) -> Dictionary:
	var i: int = _index.get(enemy, -1)
	if i < 0:
		return {}
	var en := _tracked[i]
	return {"frac": en.hp / en.max_hp, "ghost": _ghost[i], "mask": _mask[i], "flash": _flash[i] - _clock,
		"shake": _shake[i] - _clock, "kind": _kind[i], "dot": _dot[i]}


func _on_damaged(enemy: Node2D, amount: float, is_crit: bool, element: StringName) -> void:
	var i: int = _index.get(enemy, -1)
	var en := enemy as Enemy
	if i < 0:
		if en == null or en.boss_kind == &"etage":
			return
		var g: Dictionary = TIER_GEOM.get(en.tier, TIER_GEOM[1])
		var w: float = g["w"]
		var kind := KIND_BASE
		if en.is_boss:
			kind = KIND_MINI
		elif en.is_elite:
			w *= ELITE_WIDTH_MULT
			kind = KIND_ELITE
		i = _tracked.size()
		if kind != KIND_BASE:
			_n_rich += 1
		_index[en] = i
		_tracked.append(en)
		_last_hit.append(_clock)
		_half_w.append(w * 0.5)
		_top.append(float(g["y"]))
		_kind.append(kind)
		_ghost.append(0.0)
		_hold.append(-1.0)
		_hit_t.append(-1.0)
		_flash.append(-1.0)
		_shake.append(-1.0)
		_shake_amp.append(0.0)
		_dot.append(0)
		_dot_t.append(-10.0)
		var m0 := en.status_mask()
		_mask.append(m0)
		_ensure_tables()
		_dom.append(_dom_idx[m0])
		_frac.append(1.0)
		_culled.append(0)
		var hw0 := w * 0.5
		var dy0 := BAR_H * 0.5 - float(g["y"])
		_ofs.append_array(PackedVector2Array([Vector2(-hw0 - BORDER, dy0), Vector2(hw0 + BORDER, dy0), Vector2(-hw0, dy0),
			Vector2(hw0, dy0), Vector2(hw0 + BORDER + PICTO_GAP, dy0 - PICTO * 0.5),
			Vector2(-hw0, dy0 + BAR_H * 0.5 + 1.0 + PIP * 0.5)]))
	_last_hit[i] = _clock
	var mhp := maxf(en.max_hp, 1.0)
	var frac := clampf(en.hp / mhp, 0.0, 1.0)
	_frac[i] = frac
	_set_fill_end(i, frac)
	if element == &"burn" or element == &"poison": # DoT : ni ghost, ni flash, ni tremblement ; tic coloré au bord
		_dot[i] = 1 if element == &"burn" else 2
		_dot_t[i] = _clock
		return
	_ghost[i] = clampf(maxf(_ghost[i], frac + amount / mhp), 0.0, 1.0)
	_hold[i] = _clock + HpBarStyle.GHOST_HOLD_S
	_hit_t[i] = _clock
	if Quality.flashes_level > 0:
		_flash[i] = _clock + HpBarStyle.FLASH_S
		if (is_crit or amount / mhp >= HpBarStyle.SHAKE_MIN_FRAC) and not GameSettings.reduce_motion():
			_shake[i] = _clock + HpBarStyle.SHAKE_S
			_shake_amp[i] = (2.5 if _kind[i] != KIND_BASE else 1.5) * (HpBarStyle.SHAKE_CRIT_MULT if is_crit else 1.0)


func _remove_at(i: int) -> void:
	var last := _tracked.size() - 1
	if _kind[i] != KIND_BASE:
		_n_rich -= 1
		_st_cache.erase(_tracked[i])
	_index.erase(_tracked[i])
	if i != last:
		var moved := _tracked[last]
		_tracked[i] = moved
		_index[moved] = i
		_last_hit[i] = _last_hit[last]
		_half_w[i] = _half_w[last]
		_top[i] = _top[last]
		_kind[i] = _kind[last]
		_ghost[i] = _ghost[last]
		_hold[i] = _hold[last]
		_hit_t[i] = _hit_t[last]
		_flash[i] = _flash[last]
		_shake[i] = _shake[last]
		_shake_amp[i] = _shake_amp[last]
		_dot[i] = _dot[last]
		_dot_t[i] = _dot_t[last]
		_mask[i] = _mask[last]
		_dom[i] = _dom[last]
		_frac[i] = _frac[last]
		_culled[i] = _culled[last]
		for j in OFS_N:
			_ofs[i * OFS_N + j] = _ofs[last * OFS_N + j]
	_tracked.resize(last)
	_last_hit.resize(last)
	_half_w.resize(last)
	_top.resize(last)
	_kind.resize(last)
	_ghost.resize(last)
	_hold.resize(last)
	_hit_t.resize(last)
	_flash.resize(last)
	_shake.resize(last)
	_shake_amp.resize(last)
	_dot.resize(last)
	_dot_t.resize(last)
	_mask.resize(last)
	_dom.resize(last)
	_frac.resize(last)
	_ofs.resize(last * OFS_N)
	_culled.resize(last)


## Fin du remplissage (décalage) d'une barre suivie pour la fraction de PV `frac`.
func _set_fill_end(i: int, frac: float) -> void:
	var o := _ofs[i * OFS_N + 2]
	_ofs[i * OFS_N + 3] = Vector2(o.x + 2.0 * _half_w[i] * frac, o.y)


func _process(delta: float) -> void:
	_clock += delta
	_frame += 1
	if _tracked.is_empty():
		if _drawn:
			_count = 0
			_drawn = false
			_rich.clear()
			_np = 0
			_e_n = 0
			_st_cache.clear()
			queue_redraw()
		return
	var t0 := Time.get_ticks_usec()
	var n := _tracked.size()
	_bg_pts.resize(n * 2)
	_bg_cols.resize(n)
	_fill_pts.resize(n * 6)
	_fill_cols.resize(n * 3)
	_pip_pts.resize(n * 10) # 5 pips max par barre
	_pip_cols.resize(n * 5)
	_rich.clear()
	var k := 0 # barres de base dessinées
	var kf := 0 # segments remplissage + ghost + éclat
	var kp := 0 # pips
	var np := 0 # pictogrammes (4 sommets chacun)
	var cap := n + 5 * _n_rich # base : 1 picto ; élite groupée : jusqu'à 5 icônes
	if _pic_idx.size() < cap: # tampons agrandis seulement (jamais réduits : les sommets au-delà de _np ne sont pas indexés)
		var old_cap := _pic_idx.size()
		_pic_idx.resize(cap)
		_pq_state.resize(cap)
		for j in range(old_cap, cap):
			_pq_state[j] = 0
		_pq_pts.resize(cap * 4)
		_pq_uvs.resize(cap * 4)
		_pq_cols.resize(cap * 4)
	if not _stk.is_empty():
		_stk.resize(0)
	var ke := 0 # élites groupées
	var kef := 0 # segments remplissage d'élites
	if _n_rich > 0 or _e_n > 0:
		_elite_tex = HpBarStyle.tex("elite_frame")
		_e0_pts.resize(n * 2)
		_e1_pts.resize(n * 2)
		_e2_pts.resize(n * 2)
		_e0_cols.resize(n)
		_e1_cols.resize(n)
		_e2_cols.resize(n)
		_e_low_pts.resize(n * 2)
		_e_low_cols.resize(n)
		_ef_pts.resize(n * 8)
		_ef_cols.resize(n * 4)
		_icon_en.clear()
		_icon_pos.clear()
	var i := n - 1
	var y_mid := BAR_H * 0.5
	var pip_dy := y_mid + 1.0 + PIP * 0.5
	# perf : tout ce qui ne dépend pas du monstre est calculé une fois par image (table masque -> teinte)
	var flick := 0.5 + 0.5 * sin(_clock * 23.0) # braise qui vacille (brûlure)
	_build_tints(flick)
	var col_dot_burn := _dot_burn
	var col_dot_poison := _dot_poison
	var pip_base := _pip_base
	var low_bit := _low_bit
	var uv_tab := _uv_tab
	var pic_sz := Vector2(PICTO, PICTO)
	var e0_op := Color(HpBarStyle.COL_OUTLINE, HpBarStyle.COL_OUTLINE.a)
	var e1_op := Color(HpBarStyle.COL_FRAME, 1.0)
	var e2_op := Color(COL_BG.r, COL_BG.g, COL_BG.b, 0.92)
	var elow_op := Color(HpBarStyle.COL_FILL_LOW, 0.55)
	var pulse_low := HpBarStyle.low_pulse(0.2, _clock)
	var pulse_crit := HpBarStyle.low_pulse(0.05, _clock)
	var fade_start := HIDE_AFTER_S - FADE_S
	var shake_k := sin(_clock * 95.0) / HpBarStyle.SHAKE_S
	var g_rate := 1.6 / HpBarStyle.GHOST_DRAIN_S
	var g_min := HpBarStyle.GHOST_MIN_RATE * delta
	var refresh := _frame & 7 # statuts relus une image sur 8 par barre
	var tints := _tints
	# Horde (> FEEL_MAX_BARS barres) : les monstres de base gardent remplissage, teinte et pips mais perdent
	# ghost, flash et tremblement (recherche §1 / §2 : ne pas animer des centaines de barres de monde).
	var lite := n > FEEL_MAX_BARS
	# perf : tous les monstres (boss compris) partagent le conteneur du Director -> une seule
	# transformation globale par image (position locale × xf) au lieu d'un global_position par monstre.
	var xf := Transform2D.IDENTITY
	var first := _tracked[n - 1]
	if is_instance_valid(first) and first.get_parent() is Node2D:
		xf = (first.get_parent() as Node2D).global_transform
	# Culling : barres hors de la vue (marge d'une barre de boss) non dessinées.
	var cxf := get_viewport().get_canvas_transform().affine_inverse()
	var view := Rect2(cxf.origin, get_viewport().get_visible_rect().size * cxf.get_scale()).grow(160.0)
	# horde : ancrage directement en espace billboard (y / 2) et vue dans le même espace
	var xf_b := Transform2D(Vector2(1.0, 0.0), Vector2(0.0, 0.5), Vector2.ZERO) * xf
	var view_b := Rect2(view.position.x, view.position.y * 0.5, view.size.x, view.size.y * 0.5)
	var culled := 0
	_bg_faded = false
	# perf : copies locales des tableaux lus seulement dans la boucle (lecture locale plus rapide). _remove_at(i)
	# déplace le dernier élément en i puis on passe à i - 1 : les indices < i des copies restent justes.
	var last_hit := _last_hit
	var half_w := _half_w
	var top := _top
	var kinds := _kind
	var dot_t := _dot_t
	var tracked := _tracked
	var clock := _clock
	while i >= 0:
		if lite and _culled[i] != 0 and (i & 7) != refresh: # hors vue (horde) : rien à faire avant la revérification
			culled += 1
			i -= 1
			continue
		if not is_instance_valid(tracked[i]):
			_remove_at(i)
			i -= 1
			continue
		var en := tracked[i]
		var since := clock - last_hit[i]
		var frac: float
		if (i & 7) == refresh: # relecture complète une image sur 8 : soins, réapparition, désactivation, statuts
			frac = clampf(en.hp / maxf(en.max_hp, 1.0), 0.0, 1.0) if en.active else 0.0
			if frac != _frac[i]:
				_frac[i] = frac
				_set_fill_end(i, frac)
			var m_new := en.status_mask()
			if m_new != _mask[i]:
				_mask[i] = m_new
				_dom[i] = _dom_idx[m_new]
		else:
			frac = _frac[i]
		if frac <= 0.0 or frac >= 1.0 or since > HIDE_AFTER_S:
			_remove_at(i)
			i -= 1
			continue
		var kind := kinds[i]
		if lite and kind == KIND_BASE:
			# chemin rapide (horde) : remplissage teinté, fond, tic de DoT, picto, pips ; rien d'autre
			var c := xf_b * en.position
			if not view_b.has_point(c):
				_culled[i] = 1
				culled += 1
				i -= 1
				continue
			if _culled[i] != 0:
				_culled[i] = 0
			var ob := i * OFS_N
			var mq := _mask[i]
			var cq: Color = tints[mq]
			if frac <= HpBarStyle.LOW_HP_FRAC:
				cq = HpBarStyle.brighten(cq, pulse_crit if frac <= HpBarStyle.CRIT_HP_FRAC else pulse_low)
			var aq := 1.0
			if since > fade_start:
				aq = (HIDE_AFTER_S - since) / FADE_S
				cq.a = aq
				if not _bg_faded: # premier fond en fondu : les précédents (opaques) n'avaient pas besoin de couleur
					_bg_faded = true
					for j in k:
						_bg_cols[j] = COL_BG
				_bg_cols[k] = Color(COL_BG.r, COL_BG.g, COL_BG.b, COL_BG.a * aq)
			elif _bg_faded:
				_bg_cols[k] = COL_BG
			_bg_pts[k * 2] = c + _ofs[ob]
			_bg_pts[k * 2 + 1] = c + _ofs[ob + 1]
			k += 1
			var fs := c + _ofs[ob + 2]
			var fe := c + _ofs[ob + 3]
			_fill_pts[kf * 2] = fs
			_fill_pts[kf * 2 + 1] = fe
			_fill_cols[kf] = cq
			kf += 1
			if clock - dot_t[i] < DOT_TICK_S:
				_fill_pts[kf * 2] = Vector2(maxf(fe.x - 3.0, fs.x), fe.y)
				_fill_pts[kf * 2 + 1] = fe + DOT_DX
				_fill_cols[kf] = col_dot_burn if _dot[i] == 1 else col_dot_poison
				kf += 1
			if mq != 0:
				var dq := _dom[i]
				if dq >= 0:
					var o := c + _ofs[ob + 4]
					var v4 := np * 4
					_pq_pts[v4] = o
					_pq_pts[v4 + 1] = o + PIC_DX
					_pq_pts[v4 + 2] = o + PIC_D
					_pq_pts[v4 + 3] = o + PIC_DY
					if aq < 1.0 or _pq_state[np] != dq + 1: # même picto opaque qu'à l'image précédente : UV et couleur déjà là
						var u4 := dq * 4
						_pq_uvs[v4] = uv_tab[u4]
						_pq_uvs[v4 + 1] = uv_tab[u4 + 1]
						_pq_uvs[v4 + 2] = uv_tab[u4 + 2]
						_pq_uvs[v4 + 3] = uv_tab[u4 + 3]
						var pc: Color = pip_base[dq]
						pc.a = aq
						_pq_cols[v4] = pc
						_pq_cols[v4 + 1] = pc
						_pq_cols[v4 + 2] = pc
						_pq_cols[v4 + 3] = pc
						_pic_idx[np] = dq
						_pq_state[np] = dq + 1 if aq >= 1.0 else 0
					np += 1
				var pp := c + _ofs[ob + 5]
				var mm := mq
				while mm != 0:
					var b := low_bit[mm]
					mm &= mm - 1
					_pip_pts[kp * 2] = pp
					_pip_pts[kp * 2 + 1] = pp + PIP_DX
					var bc: Color = pip_base[b]
					if aq < 1.0:
						bc.a = aq
					_pip_cols[kp] = bc
					kp += 1
					pp += PIP_STEP
			i -= 1
			continue
		# animations (même hors vue : l'état reste juste au retour à l'écran)
		# perf : maintien, flash et tremblement stockés en échéances (horloge) : aucune écriture par image
		var g := frac
		var fl := -1.0
		g = _ghost[i]
		if g > frac:
			if _clock >= _hold[i]:
				g = maxf(frac, g - maxf((g - frac) * g_rate * delta, g_min))
				_ghost[i] = g
		elif g < frac: # soin : remonte tout de suite
			g = frac
			_ghost[i] = g
		fl = _flash[i] - _clock
		var p := xf * en.position
		if not view.has_point(p):
			culled += 1
			i -= 1
			continue
		var hw := _half_w[i]
		var y := p.y * 0.5 - _top[i] + y_mid # p.y / Iso.UNSQUASH.y
		var x := p.x
		if fl > -HpBarStyle.SHAKE_S: # tremblement (toujours plus court que le flash qui l'accompagne)
			var sh := _shake[i] - _clock
			if sh > 0.0:
				x += _shake_amp[i] * shake_k * sh
		var x0 := x - hw
		var mask := _mask[i]
		# couleur du remplissage : statut dominant (table), pulsation PV bas, flash, fondu de sortie
		var col: Color = tints[mask] if kind != KIND_MINI else COL_FILL_BOSS
		if frac <= HpBarStyle.LOW_HP_FRAC:
			col = HpBarStyle.brighten(col, pulse_crit if frac <= HpBarStyle.CRIT_HP_FRAC else pulse_low)
		var alpha := 1.0
		if since > fade_start:
			alpha = (HIDE_AFTER_S - since) / FADE_S
			col.a = alpha
		if kind == KIND_ELITE and (lite or _elite_tex == null):
			# élites groupées (5 appels pour toutes) ; icônes individuelles seulement si statut
			var w := 2.0 * hw
			var ey := y + RICH_H_E * 0.5 - y_mid
			var efx := w * frac
			_e0_pts[ke * 2] = Vector2(x0 - 3.0, ey)
			_e0_pts[ke * 2 + 1] = Vector2(x0 + w + 3.0, ey)
			_e1_pts[ke * 2] = Vector2(x0 - 2.0, ey)
			_e1_pts[ke * 2 + 1] = Vector2(x0 + w + 2.0, ey)
			_e2_pts[ke * 2] = Vector2(x0, ey)
			_e2_pts[ke * 2 + 1] = Vector2(x0 + w, ey)
			_e_low_pts[ke * 2] = Vector2(x0, ey + RICH_H_E * 0.3)
			_e_low_pts[ke * 2 + 1] = Vector2(x0 + efx, ey + RICH_H_E * 0.3)
			if alpha >= 1.0: # couleurs opaques en cache (aucune construction)
				_e0_cols[ke] = e0_op
				_e1_cols[ke] = e1_op
				_e2_cols[ke] = e2_op
				_e_low_cols[ke] = elow_op
			else:
				_e0_cols[ke] = Color(HpBarStyle.COL_OUTLINE, HpBarStyle.COL_OUTLINE.a * alpha)
				_e1_cols[ke] = Color(HpBarStyle.COL_FRAME, alpha)
				_e2_cols[ke] = Color(COL_BG.r, COL_BG.g, COL_BG.b, 0.92 * alpha)
				_e_low_cols[ke] = Color(HpBarStyle.COL_FILL_LOW, 0.55 * alpha)
			ke += 1
			_ef_pts[kef * 2] = Vector2(x0, ey)
			_ef_pts[kef * 2 + 1] = Vector2(x0 + efx, ey)
			_ef_cols[kef] = col
			kef += 1
			if _clock - _dot_t[i] < DOT_TICK_S and fl <= 0.0:
				_ef_pts[kef * 2] = Vector2(x0 + maxf(efx - 3.0, 0.0), ey)
				_ef_pts[kef * 2 + 1] = Vector2(x0 + efx + 1.0, ey)
				_ef_cols[kef] = col_dot_burn if _dot[i] == 1 else col_dot_poison
				kef += 1
			if g > frac + 0.01:
				var gcol3: Color = HpBarStyle.COL_GHOST_HIT if clock - _hit_t[i] < HpBarStyle.GHOST_WHITE_S else HpBarStyle.COL_GHOST
				gcol3.a *= alpha
				_ef_pts[kef * 2] = Vector2(x0 + efx, ey)
				_ef_pts[kef * 2 + 1] = Vector2(x0 + w * g, ey)
				_ef_cols[kef] = gcol3
				kef += 1
			if efx > 0.0:
				_ef_pts[kef * 2] = Vector2(x0 + efx - 1.5, ey)
				_ef_pts[kef * 2 + 1] = Vector2(x0 + efx, ey)
				_ef_cols[kef] = Color(HpBarStyle.COL_GLINT, (HpBarStyle.FLASH_ALPHA if fl > 0.0 else 0.3) * alpha)
				kef += 1
			if mask != 0 and not lite:
				_icon_en.append(en)
				_icon_pos.append(Vector3(x0, ey + RICH_H_E * 0.5, alpha))
			elif mask != 0:
				# horde : icônes de statut dans le lot de pictogrammes (même atlas, un seul appel de dessin) ; durée
				# restante = trait sous l'icône (lot des pips) ; liste des statuts relue 1 image sur 8, durées extrapolées
				var sc_v: Variant = _st_cache.get(en) # null si jamais lu (aucun tableau par défaut alloué)
				if sc_v == null or (i & 7) == refresh:
					# statuts compactés : [horloge de lecture, puis (case d'atlas, reste, stacks, 1 / durée de référence) par statut]
					var pk := PackedFloat32Array([_clock])
					for s: Dictionary in en.status_list():
						var sid: StringName = s["id"]
						var slot0: int = _st_slot.get(sid, -1)
						if slot0 >= 0:
							pk.append_array(PackedFloat32Array([slot0, s["left"], s["stacks"], 1.0 / _status_total(sid)]))
					sc_v = pk
					_st_cache[en] = pk
				var sc: PackedFloat32Array = sc_v
				var el_t: float = _clock - sc[0]
				var iv := Vector2(x0, ey + RICH_H_E * 0.5 + 3.0) # coin haut-gauche de l'icône courante
				for q in range(1, sc.size(), 4):
					var left: float = sc[q + 1] - el_t
					if left <= 0.0:
						continue
					var slot := int(sc[q])
					var v4 := np * 4
					_pq_pts[v4] = iv
					_pq_pts[v4 + 1] = iv + ICON_DX
					_pq_pts[v4 + 2] = iv + ICON_D
					_pq_pts[v4 + 3] = iv + ICON_DY
					var ic: Color = pip_base[slot]
					if alpha < 1.0 or _pq_state[np] != slot + 1:
						var u4 := slot * 4
						_pq_uvs[v4] = uv_tab[u4]
						_pq_uvs[v4 + 1] = uv_tab[u4 + 1]
						_pq_uvs[v4 + 2] = uv_tab[u4 + 2]
						_pq_uvs[v4 + 3] = uv_tab[u4 + 3]
						ic.a = alpha
						_pq_cols[v4] = ic
						_pq_cols[v4 + 1] = ic
						_pq_cols[v4 + 2] = ic
						_pq_cols[v4 + 3] = ic
						_pic_idx[np] = slot
						_pq_state[np] = slot + 1 if alpha >= 1.0 else 0
					np += 1
					if kp < n * 5: # trait de durée (part restante) sous l'icône
						var dv := iv + ICON_DUR
						_pip_pts[kp * 2] = dv
						_pip_pts[kp * 2 + 1] = Vector2(dv.x + RICH_ICON * clampf(left * sc[q + 3], 0.05, 1.0), dv.y)
						_pip_cols[kp] = ic
						kp += 1
					if sc[q + 2] > 1.5:
						_stk.append_array(PackedFloat32Array([iv.x + RICH_ICON - 3.0, iv.y + RICH_ICON + 1.0, sc[q + 2], alpha]))
					iv += ICON_STEP
			i -= 1
			continue
		if kind != KIND_BASE:
			var gcol := _ghost_color(i)
			gcol.a *= alpha
			_rich.append({"en": en, "x0": x0, "y": y - y_mid, "w": 2.0 * hw, "frac": frac, "ghost": g,
				"col": col, "gcol": gcol, "alpha": alpha, "kind": kind, "flash": fl > 0.0})
			i -= 1
			continue
		var xf_end := x0 + 2.0 * hw * frac
		_bg_pts[k * 2] = Vector2(x0 - BORDER, y)
		_bg_pts[k * 2 + 1] = Vector2(x + hw + BORDER, y)
		if alpha < 1.0:
			_bg_faded = true
		_bg_cols[k] = COL_BG if alpha >= 1.0 else Color(COL_BG.r, COL_BG.g, COL_BG.b, COL_BG.a * alpha)
		k += 1
		# remplissage, ghost et éclat partagent l'épaisseur BAR_H : un seul tableau (ordre = ordre de dessin)
		_fill_pts[kf * 2] = Vector2(x0, y)
		_fill_pts[kf * 2 + 1] = Vector2(xf_end, y)
		_fill_cols[kf] = col
		kf += 1
		if g > frac + 0.01:
			var gcol2: Color = HpBarStyle.COL_GHOST_HIT if _clock - _hit_t[i] < HpBarStyle.GHOST_WHITE_S else HpBarStyle.COL_GHOST
			gcol2.a *= alpha
			_fill_pts[kf * 2] = Vector2(xf_end, y)
			_fill_pts[kf * 2 + 1] = Vector2(x0 + 2.0 * hw * g, y)
			_fill_cols[kf] = gcol2
			kf += 1
		if fl > 0.0: # éclat au bord du remplissage
			_fill_pts[kf * 2] = Vector2(maxf(xf_end - 4.0, x0), y)
			_fill_pts[kf * 2 + 1] = Vector2(xf_end, y)
			_fill_cols[kf] = Color(HpBarStyle.COL_GLINT, HpBarStyle.FLASH_ALPHA * alpha)
			kf += 1
		elif _clock - _dot_t[i] < DOT_TICK_S: # tic de DoT : bord coloré du statut (distinct du coup direct)
			_fill_pts[kf * 2] = Vector2(maxf(xf_end - 3.0, x0), y)
			_fill_pts[kf * 2 + 1] = Vector2(xf_end + 1.0, y)
			_fill_cols[kf] = col_dot_burn if _dot[i] == 1 else col_dot_poison
			kf += 1
		if mask != 0: # pictogramme du statut dominant à droite de la barre + pips sous la barre, un par statut actif
			var dn := _dom[i]
			if dn >= 0:
				var o := Vector2(x + hw + BORDER + PICTO_GAP, y - PICTO * 0.5)
				var v4 := np * 4
				_pq_pts[v4] = o
				_pq_pts[v4 + 1] = Vector2(o.x + PICTO, o.y)
				_pq_pts[v4 + 2] = o + pic_sz
				_pq_pts[v4 + 3] = Vector2(o.x, o.y + PICTO)
				if alpha < 1.0 or _pq_state[np] != dn + 1: # même picto opaque qu'à l'image précédente : UV et couleur déjà là
					var u4 := dn * 4
					_pq_uvs[v4] = uv_tab[u4]
					_pq_uvs[v4 + 1] = uv_tab[u4 + 1]
					_pq_uvs[v4 + 2] = uv_tab[u4 + 2]
					_pq_uvs[v4 + 3] = uv_tab[u4 + 3]
					var pc: Color = pip_base[dn]
					pc.a = alpha
					_pq_cols[v4] = pc
					_pq_cols[v4 + 1] = pc
					_pq_cols[v4 + 2] = pc
					_pq_cols[v4 + 3] = pc
					_pic_idx[np] = dn
					_pq_state[np] = dn + 1 if alpha >= 1.0 else 0
				np += 1
			var px := x0
			var py := y + pip_dy
			var mm := mask
			while mm != 0:
				var b := low_bit[mm]
				mm &= mm - 1
				_pip_pts[kp * 2] = Vector2(px, py)
				_pip_pts[kp * 2 + 1] = Vector2(px + PIP, py)
				var bc: Color = pip_base[b]
				if alpha < 1.0:
					bc.a = alpha
				_pip_cols[kp] = bc
				kp += 1
				px += PIP + 1.0
		i -= 1
	if _n_rich > 0 or _e_n > 0:
		_e0_pts.resize(ke * 2)
		_e1_pts.resize(ke * 2)
		_e2_pts.resize(ke * 2)
		_e0_cols.resize(ke)
		_e1_cols.resize(ke)
		_e2_cols.resize(ke)
		_e_low_pts.resize(ke * 2)
		_e_low_cols.resize(ke)
		_ef_pts.resize(kef * 2)
		_ef_cols.resize(kef)
	_e_n = ke
	_count = k + ke + _rich.size() + culled # barres actives (les hors-vue, non dessinées, comptent : elles réapparaissent à l'écran)
	_bg_pts.resize(k * 2)
	_bg_cols.resize(k)
	_fill_pts.resize(kf * 2)
	_fill_cols.resize(kf)
	_pip_pts.resize(kp * 2)
	_pip_cols.resize(kp)
	_np = np
	_drawn = true
	queue_redraw()
	stat_usec = Time.get_ticks_usec() - t0 + _draw_usec


## Table masque -> teinte du remplissage selon le statut dominant (32 entrées, la brûlure vacille). Refaite quand le
## mode daltonien change (CvdPalette.mode() est mis en cache : aucune lecture de fichier par image).
func _build_tints(flick: float) -> void:
	_ensure_tables()
	# brûlure dominante (masques 1 et 3) : seule teinte animée
	var burn := COL_FILL.lerp(_burn_col, 0.55 + 0.3 * flick)
	_tints[1] = burn
	_tints[3] = burn


## Tables par mode daltonien (couleurs des pips / pictos, teintes, tics de DoT) : refaites seulement quand le mode
## change ; tables indépendantes du mode (bit le plus bas, picto dominant, UV de l'atlas) faites une fois.
func _ensure_tables() -> void:
	if _low_bit.is_empty():
		_low_bit.resize(32)
		_low_bit[0] = -1
		for m in range(1, 32):
			var b := 0
			while not (m & (1 << b)):
				b += 1
			_low_bit[m] = b
		var cells := float(StatusPictos.IDS.size())
		for j in StatusPictos.IDS.size():
			var r := StatusPictos.region(j)
			var u0 := r.position.x / (StatusPictos.CELL * cells)
			var u1 := r.end.x / (StatusPictos.CELL * cells)
			_uv_tab.append_array(PackedVector2Array([Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0)]))
		for j in HpBarStyle.STATUS_ORDER.size():
			_st_slot[HpBarStyle.STATUS_ORDER[j]] = j
	var cm := CvdPalette.mode()
	if _pip_base.is_empty() or cm != _cvd_mode:
		_cvd_mode = cm
		_pip_base.clear()
		for id in HpBarStyle.STATUS_ORDER:
			_pip_base.append(CvdPalette.status(id, cm))
		_burn_col = CvdPalette.status(&"burn", cm)
		_poison_col = CvdPalette.status(&"poison", cm)
		_tints.resize(32)
		_dom_idx.resize(32)
		for m in 32:
			var dom := HpBarStyle.dominant(m)
			_tints[m] = COL_FILL if dom == &"" else COL_FILL.lerp(CvdPalette.status(dom, cm), 0.8)
			_dom_idx[m] = HpBarStyle.STATUS_ORDER.find(dom) if dom != &"" else -1
		_dot_burn = HpBarStyle.brighten(_burn_col, 0.3)
		_dot_poison = HpBarStyle.brighten(_poison_col, 0.3)
		_st_cache.clear()
		_pq_state.fill(0) # couleurs des pictos à réécrire dans la nouvelle palette


func _ghost_color(i: int) -> Color:
	return HpBarStyle.COL_GHOST_HIT if _clock - _hit_t[i] < HpBarStyle.GHOST_WHITE_S else HpBarStyle.COL_GHOST


## Barres de base : 3 appels groupés (fonds ; remplissages + ghosts + éclats ; pips) ; élites / mini-boss à part.
func _draw() -> void:
	if _fill_cols.is_empty() and _rich.is_empty() and _e_n == 0 and _np == 0:
		return
	var t0 := Time.get_ticks_usec()
	if not _bg_cols.is_empty():
		if _bg_faded:
			draw_multiline_colors(_bg_pts, _bg_cols, BAR_H + 2.0 * BORDER)
		else:
			draw_multiline(_bg_pts, COL_BG, BAR_H + 2.0 * BORDER)
		draw_multiline_colors(_fill_pts, _fill_cols, BAR_H)
	if _e_n > 0:
		var eh: float = RICH_H[KIND_ELITE]
		draw_multiline_colors(_e0_pts, _e0_cols, eh + 6.0)
		draw_multiline_colors(_e1_pts, _e1_cols, eh + 4.0)
		draw_multiline_colors(_e2_pts, _e2_cols, eh)
		draw_multiline_colors(_ef_pts, _ef_cols, eh)
		draw_multiline_colors(_e_low_pts, _e_low_cols, eh * 0.4)
	# pips (base) + traits de durée (icônes d'élites groupées) : un appel ; pictos : un appel (triangles texturés)
	if not _pip_cols.is_empty():
		draw_multiline_colors(_pip_pts, _pip_cols, PIP)
	if _np > 0:
		var ni := _np * 6
		if _pq_ind.size() != ni:
			var old := _pq_ind.size() / 6
			_pq_ind.resize(ni)
			for j in range(old, _np):
				var v := j * 4
				_pq_ind[j * 6] = v
				_pq_ind[j * 6 + 1] = v + 1
				_pq_ind[j * 6 + 2] = v + 2
				_pq_ind[j * 6 + 3] = v
				_pq_ind[j * 6 + 4] = v + 2
				_pq_ind[j * 6 + 5] = v + 3
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _pq_ind, _pq_pts, _pq_cols, _pq_uvs,
			_no_bones, _no_weights, StatusPictos.atlas().get_rid())
		for j in range(0, _stk.size(), 4): # stacks (rare : poison cumulé sur une élite de horde)
			draw_string(_font, Vector2(_stk[j], _stk[j + 1] + 6.0), str(int(_stk[j + 2])), HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
				Color(1, 1, 1, _stk[j + 3]))
	if _e_n > 0:
		for j in _icon_en.size():
			var en := _icon_en[j]
			if is_instance_valid(en):
				var ip := _icon_pos[j]
				_draw_icons(en, Vector2(ip.x, ip.y), ip.z)
	for r in _rich:
		_draw_rich(r)
	_draw_usec = Time.get_ticks_usec() - t0


## Barre d'élite / de mini-boss : cadre fer, ghost, remplissage dégradé, éclat, encoches de phase, icônes.
func _draw_rich(r: Dictionary) -> void:
	var en: Enemy = r["en"]
	if not is_instance_valid(en):
		return
	var kind: int = r["kind"]
	var h: float = RICH_H[kind]
	var a: float = r["alpha"]
	var rect := Rect2(r["x0"], r["y"], r["w"], h)
	var frame_tex := HpBarStyle.tex("mini_frame" if kind == KIND_MINI else "elite_frame")
	var fr := rect.grow(2.0)
	if frame_tex != null:
		# 9-patch HB1 : elite_frame 256×24 (fenêtre et marges 8 px), mini_frame 512×64 (fenêtre 24/22, marges 32/24)
		var win := Vector2(8.0, 8.0) if kind == KIND_ELITE else BossHealthBar.FRAME_WINDOW
		var mar := Vector2(8.0, 8.0) if kind == KIND_ELITE else BossHealthBar.FRAME_MARGIN
		var k := 0.5 # rendu à demi-échelle au-dessus des têtes (le centre 9-patch s'étire sur la barre)
		HpBarStyle.nine_patch(self, frame_tex, rect.grow_individual(win.x * k, win.y * k, win.x * k, win.y * k), mar, k, Color(1, 1, 1, a))
	else:
		draw_rect(fr.grow(1.0), Color(HpBarStyle.COL_OUTLINE, HpBarStyle.COL_OUTLINE.a * a))
		draw_rect(fr, Color(HpBarStyle.COL_FRAME, a))
		draw_rect(Rect2(fr.position, Vector2(fr.size.x, 1.0)), Color(0.48, 0.44, 0.40, a)) # arête haute éclairée
	draw_rect(rect, Color(HpBarStyle.COL_BG.r, HpBarStyle.COL_BG.g, HpBarStyle.COL_BG.b, 0.92 * a))
	var frac: float = r["frac"]
	var gx: float = rect.size.x * float(r["ghost"])
	var fx := rect.size.x * frac
	if gx > fx + 0.5:
		draw_rect(Rect2(rect.position.x + fx, rect.position.y, gx - fx, h), r["gcol"])
	var col: Color = r["col"]
	draw_rect(Rect2(rect.position, Vector2(fx, h)), col)
	draw_rect(Rect2(rect.position.x, rect.position.y + h * 0.6, fx, h * 0.4), Color(HpBarStyle.COL_FILL_LOW, 0.55 * a))
	draw_rect(Rect2(rect.position.x, rect.position.y, fx, 1.0), Color(1, 1, 1, 0.18 * a))
	if fx > 0.0:
		draw_rect(Rect2(rect.position.x + fx - 1.5, rect.position.y, 1.5, h), Color(HpBarStyle.COL_GLINT, (HpBarStyle.FLASH_ALPHA if r["flash"] else 0.3) * a))
	# encoches de phase (mini-boss ; élites seulement si leur cerveau en définit)
	if kind == KIND_MINI or en.brain != null:
		for t in en.phase_thresholds():
			var nx := rect.position.x + rect.size.x * t
			var broken := frac <= t
			draw_rect(Rect2(nx - 1.0, rect.position.y - 2.0, 2.0, h + 4.0), Color(0, 0, 0, 0.85 * a))
			if not broken:
				draw_rect(Rect2(nx, rect.position.y - 2.0, 1.0, h + 4.0), Color(0.85, 0.80, 0.72, 0.8 * a))
	_draw_icons(en, Vector2(rect.position.x, rect.end.y), a)


## Icônes de statut (12 px) sous une barre riche (coin haut-gauche de la rangée : at), anneau de durée, stacks.
func _draw_icons(en: Enemy, at: Vector2, a: float) -> void:
	var sl: Array = en.status_list()
	var cx := at.x + RICH_ICON * 0.5
	var cy := at.y + 3.0 + RICH_ICON * 0.5
	for s: Dictionary in sl:
		var id: StringName = s["id"]
		var left: float = s["left"]
		HpBarStyle.draw_status_icon(self, id, Vector2(cx, cy), RICH_ICON, clampf(left / _status_total(id), 0.0, 1.0),
			int(s["stacks"]), _font, 10, a)
		cx += RICH_ICON + 2.0


## Durée de référence d'un statut (anneau des barres de monde : durées par défaut d'Enemy).
static func _status_total(id: StringName) -> float:
	match id:
		&"burn":
			return Enemy.BURN_DURATION
		&"poison":
			return Enemy.POISON_DURATION
		&"frost":
			return 2.0
	return 1.5
