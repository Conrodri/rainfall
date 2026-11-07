class_name SharedCamera
extends Camera2D
## Caméra commune de la coop locale PC (étape 4, docs/multi/Design_Coop.md §4.5 option B, docs/multi/Archi_Reseau.md §2
## ligne 3). Une seule caméra (un seul rendu) pour 2 à 4 joueurs sur le même écran :
## - cadre les joueurs VIVANTS (Players.alive() : spectateurs et morts exclus) ; centre = centre du rectangle qui les
##   contient, agrandi d'une marge (COOP_LOCAL_CAM_MARGIN_U, plus la tête des sprites en haut) ;
## - dézoome juste ce qu'il faut pour les contenir, au plus de Balance.COOP_LOCAL_CAM_ZOOM_MAX (zoom iso 2:1 de
##   Iso.camera_zoom(1 / ZOOM_MAX)), jamais plus près que la vue solo ;
## - laisse : un joueur ne peut pas sortir du cadre le plus large. Après les déplacements de l'image de physique, sa
##   position est ramenée dans [max(autres) - W, min(autres) + W] sur chaque axe (W = étendue maximale des positions
##   que le cadre le plus large peut montrer) : mur doux, il glisse le long du bord, jamais bloqué net, et ne tire
##   jamais les autres (seul celui qui s'éloigne est retenu) ;
## - laisse libre en bas la bande des plaques du HUD (COOP_LOCAL_CAM_HUD_BOTTOM_PX) ;
## - reste dans les limites de la carte (limit_* posées par Main, comme la caméra solo) ; les secousses passent toujours
##   par Main.shake, qui écrit `offset` (non touché ici).
## Le Director lit SharedCamera.active pour faire apparaître les monstres hors du cadre COMMUN (et non hors de la vue
## supposée centrée sur chaque joueur).
## Aucune allocation par image (au plus 4 joueurs, tampons fixes).

## Caméra commune en service (null en solo, en ligne ou hors de la scène de jeu).
static var active: SharedCamera = null

## Vrai : laisse active (désactivable pour les tests de cadrage).
var leash_enabled := true
## Mutiplicateur courant de zoom (1 = vue solo, 1 / ZOOM_MAX = dézoom maximal) et sa cible.
var mult := 1.0
var target_mult := 1.0
## Cadre visé (repère logique) au dernier calcul : rectangle des joueurs vivants agrandi des marges.
var frame_rect := Rect2()
## Joueurs retenus par la laisse à la dernière image de physique (tests, journal).
var leashed_count := 0

var _center := Vector2.ZERO
var _target_center := Vector2.ZERO
var _has_target := false
var _pos := PackedVector2Array() ## positions des vivants (tampon fixe)
var _prev := PackedVector2Array() ## position de chaque joueur (par player_id) après la laisse de l'image précédente
var _prev_ok := PackedByteArray() ## 1 : _prev valable (vivant à l'image précédente)


func _init() -> void:
	name = "SharedCamera"
	position_smoothing_enabled = false
	drag_horizontal_enabled = false
	drag_vertical_enabled = false
	process_physics_priority = 100 # après les déplacements des joueurs (priorité 0) : la laisse corrige l'image même
	_pos.resize(Balance.MULTI_MAX_PLAYERS)
	_prev.resize(Balance.MULTI_MAX_PLAYERS)
	_prev_ok.resize(Balance.MULTI_MAX_PLAYERS)
	_prev_ok.fill(0)
	zoom = Iso.camera_zoom()


func _enter_tree() -> void:
	active = self


func _exit_tree() -> void:
	if active == self:
		active = null


# --- Géométrie ----------------------------------------------------------------------

## Taille logique de l'écran (base 1920×1080 keep_height : la largeur suit le ratio).
func _vp() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(1920.0, 1080.0)


## Zone d'écran utile au cadrage (sans la bande des plaques du bas), px logiques.
func usable_screen() -> Vector2:
	var vp := _vp()
	return Vector2(vp.x, maxf(vp.y - Balance.COOP_LOCAL_CAM_HUD_BOTTOM_PX, vp.y * 0.5))


## Marges du cadre autour des joueurs (repère logique) : x = gauche/droite, y = bas, z = haut (tête comprise).
static func margins() -> Vector3:
	var m := Balance.COOP_LOCAL_CAM_MARGIN_U * Balance.UNIT_PX
	return Vector3(m, m, m - Iso.lift_logical(Balance.COOP_LOCAL_CAM_HEAD_U))


static func min_mult() -> float:
	return 1.0 / maxf(Balance.COOP_LOCAL_CAM_ZOOM_MAX, 1.0)


## Étendue logique visible (zone utile) au multiplicateur `k`.
func view_extent(k: float) -> Vector2:
	var z := Iso.camera_zoom(k)
	var u := usable_screen()
	return Vector2(u.x / z.x, u.y / z.y)


## Écart maximal entre deux joueurs vivants (repère logique) que le cadre le plus large peut montrer, marges déduites.
func max_extent() -> Vector2:
	var v := view_extent(min_mult())
	var mg := margins()
	return Vector2(maxf(v.x - 2.0 * mg.x, 64.0), maxf(v.y - mg.y - mg.z, 64.0))


## Centre réel de la vue (repère logique, secousse exclue).
func view_center() -> Vector2:
	return _center


## Rectangle logique réellement affiché (écran entier, secousse exclue).
func view_rect() -> Rect2:
	var z := Iso.camera_zoom(mult)
	var vp := _vp()
	var size := Vector2(vp.x / z.x, vp.y / z.y)
	return Rect2(_center - size * 0.5, size)


# --- Boucle -------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if leash_enabled:
		apply_leash()


func _process(delta: float) -> void:
	_compute_target()
	if not _has_target:
		return
	var fk := 1.0 - exp(-Balance.COOP_LOCAL_CAM_FOLLOW_HZ * delta)
	var hz := Balance.COOP_LOCAL_CAM_ZOOM_OUT_HZ if target_mult < mult else Balance.COOP_LOCAL_CAM_ZOOM_IN_HZ
	mult = lerpf(mult, target_mult, 1.0 - exp(-hz * delta))
	_center = _center.lerp(_clamp_center(_target_center, mult), fk)
	_apply()


## Recadre immédiatement (début d'étage, reprise, téléportation) : ni lissage de suivi ni de zoom.
func snap() -> void:
	_compute_target()
	if not _has_target:
		return
	mult = target_mult
	_center = _clamp_center(_target_center, mult)
	_apply()


func _apply() -> void:
	zoom = Iso.camera_zoom(mult)
	global_position = _center


## Cadre visé : rectangle des vivants + marges ; multiplicateur qui le contient (borné) ; centre décalé vers le bas de
## la moitié de la bande des plaques (le cadre est centré dans la zone utile, au-dessus des plaques).
func _compute_target() -> void:
	var n := _gather()
	if n == 0:
		_has_target = false
		return
	var lo := _pos[0]
	var hi := _pos[0]
	for i in range(1, n):
		lo = lo.min(_pos[i])
		hi = hi.max(_pos[i])
	var mg := margins()
	frame_rect = Rect2(Vector2(lo.x - mg.x, lo.y - mg.z), Vector2(hi.x - lo.x + 2.0 * mg.x, hi.y - lo.y + mg.y + mg.z))
	var z1 := Iso.camera_zoom()
	var u := usable_screen()
	var k := minf(u.x / (z1.x * maxf(frame_rect.size.x, 1.0)), u.y / (z1.y * maxf(frame_rect.size.y, 1.0)))
	target_mult = clampf(k, min_mult(), 1.0)
	var band := Balance.COOP_LOCAL_CAM_HUD_BOTTOM_PX if u.y < _vp().y else 0.0
	_target_center = frame_rect.get_center() + Vector2(0.0, band * 0.5 / (z1.y * target_mult))
	if not _has_target:
		_has_target = true
		mult = target_mult
		_center = _clamp_center(_target_center, mult)


## Centre gardé dans les limites de la carte (limit_*), vue entière ; carte plus petite que la vue : centrée.
func _clamp_center(c: Vector2, k: float) -> Vector2:
	if limit_left <= -10000000 or limit_right >= 10000000:
		return c
	var z := Iso.camera_zoom(k)
	var vp := _vp()
	var half := Vector2(vp.x / z.x, vp.y / z.y) * 0.5
	var r := Rect2(Vector2(limit_left, limit_top), Vector2(limit_right - limit_left, limit_bottom - limit_top))
	if r.size.x <= half.x * 2.0:
		c.x = r.get_center().x
	else:
		c.x = clampf(c.x, r.position.x + half.x, r.end.x - half.x)
	if r.size.y <= half.y * 2.0:
		c.y = r.get_center().y
	else:
		c.y = clampf(c.y, r.position.y + half.y, r.end.y - half.y)
	return c


## Positions des joueurs vivants dans _pos ; rend leur nombre.
func _gather() -> int:
	var n := 0
	for p in Players.alive():
		if n >= _pos.size():
			break
		_pos[n] = p.global_position
		n += 1
	return n


## Laisse : chaque joueur vivant est ramené dans l'étendue maximale autour des AUTRES vivants. Public pour les tests.
## La correction d'un joueur ne peut qu'annuler (tout ou partie) SON propre déplacement depuis l'image de physique
## précédente (axe par axe) : celui qui s'éloigne est retenu, celui qui reste ou revient n'est jamais tiré, et le
## résultat ne dépend pas de l'ordre des joueurs (deux joueurs qui s'écartent ensemble s'arrêtent tous les deux).
func apply_leash() -> void:
	leashed_count = 0
	var alive := Players.alive()
	var n := alive.size()
	var w := max_extent()
	var seen := 0 # masque des player_id vivants à cette image
	for i in n:
		var p := alive[i]
		var pid := int(p.get(&"player_id"))
		var pos := p.global_position
		var slot_ok := pid >= 0 and pid < _prev.size()
		var d := pos - _prev[pid] if slot_ok and _prev_ok[pid] == 1 else Vector2.ZERO
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for j in n:
			if j == i:
				continue
			var q := alive[j].global_position
			lo = lo.min(q)
			hi = hi.max(q)
		var c := pos
		# intervalle permis [hi - W, lo + W] ; inversé (autres déjà trop écartés) : axe laissé libre
		if n >= 2 and hi.x - w.x <= lo.x + w.x:
			c.x = pos.x + _own_share(clampf(pos.x, hi.x - w.x, lo.x + w.x) - pos.x, d.x)
		if n >= 2 and hi.y - w.y <= lo.y + w.y:
			c.y = pos.y + _own_share(clampf(pos.y, hi.y - w.y, lo.y + w.y) - pos.y, d.y)
		if slot_ok:
			_prev[pid] = c
			_prev_ok[pid] = 1
			seen |= 1 << pid
		if c != pos:
			leashed_count += 1
			p.global_position = c
			if p is CharacterBody2D:
				var body := p as CharacterBody2D
				var v := body.velocity
				if c.x != pos.x and signf(v.x) == signf(pos.x - c.x):
					v.x = 0.0
				if c.y != pos.y and signf(v.y) == signf(pos.y - c.y):
					v.y = 0.0
				body.velocity = v
	# morts, spectateurs, retirés : plus de position précédente (au retour, la première image ne corrige rien)
	for k in _prev_ok.size():
		if (seen >> k) & 1 == 0:
			_prev_ok[k] = 0


## Part de la correction `corr` (sur un axe) que le joueur subit : seulement ce qui annule son propre déplacement `d`
## de l'image (sens opposé, au plus |d|) ; sinon rien.
static func _own_share(corr: float, d: float) -> float:
	if corr == 0.0 or d == 0.0 or signf(corr) == signf(d):
		return 0.0
	return signf(corr) * minf(absf(corr), absf(d))
