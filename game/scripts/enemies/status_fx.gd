class_name StatusFx
extends Node2D
## Visuels d'état sur les monstres (docs/Design_Etats_Visuels.md) : bulles de poison, flammèches / braises / cendres
## de brûlure, gouttes et teinte assombrie des monstres trempés (Averse), arcs électriques juste après un coup
## électrique (Éclair en bouteille, pilier de Tocsin), étoiles d'étourdissement. Purement visuel : lit l'état réel
## (Enemy.status_mask, durées posées par les kits) et ne change aucun effet de jeu.
##
## Performance (250 monstres) :
## - aucun coût sans état : la liste suivie est vide et _process éteint tant qu'aucun monstre n'a d'état visible ;
## - un monstre n'est suivi qu'à partir du moment où un état visible le touche (Enemy -> StatusFx.track / wet /
##   shock / stun), et il est relâché dès que ses états sont finis ;
## - relecture des états toutes les REFRESH_S (pas à chaque image) ; à chaque relecture, choix des ÉMETTEURS :
##   au plus EMITTERS[palier] monstres par état, à l'écran seulement, boss d'abord, puis les plus proches du centre
##   de l'écran ; hors écran = rien ;
## - particules CPU dans UN pool fixe (tableaux packés alloués au _ready), rendues par une MultiMeshInstance2D par
##   (sorte, variante de texture) : nombre de lots borné quel que soit le nombre de particules, aucun nœud créé en jeu ;
## - plafonds globaux par sorte de particule et par palier de qualité (Bas : teinte seule + très peu de particules).
##
## Formes distinctes (daltonisme, GameSettings.colorblind) : bulles RONDES qui montent (poison), flammèches POINTUES
## + paillettes de cendre qui tournoient (brûlure), GOUTTES qui tombent (trempé), ZIGZAGS brefs (électrique),
## ÉTOILES qui tournent au-dessus de la tête (étourdi). Réduction des mouvements (GameSettings.reduce_motion) :
## moitié moins de particules, arcs tenus sans scintillement, étoiles quasi immobiles.
##
## Textures : rendues par Codex dans Blender sous assets/sprites/vfx/status/ (art/briefs/status_fx.md) ; en attendant,
## repli sur des textures Blender existantes (vfx/particles, ambiance). Une sorte sans aucune texture est simplement
## coupée (jamais de dessin en code).
##
## Iso : comme HitFx, le nœud est top_level à l'échelle Iso.UNSQUASH (espace billboard : x, y logique / 2).

enum Kind { BUBBLE, FLAME, EMBER, ASH, DROP, ARC, STAR }
const KIND_COUNT := 7
const VARIANTS := 4

## Bits de _mask (ceux d'Enemy.status_mask repris tels quels pour la brûlure et le poison).
const B_BURN := 1 ## = Enemy.ST_BURN
const B_POISON := 2 ## = Enemy.ST_POISON
const B_STUN := 8
const B_WET := 64
const B_SHOCK := 128
## États émetteurs (index de _acc et des plafonds d'émetteurs).
enum St { POISON, BURN, WET, SHOCK, STUN }
const ST_COUNT := 5
const ST_BITS: Array[int] = [B_POISON, B_BURN, B_WET, B_SHOCK, B_STUN]

const SHOCK_S := 0.45 ## arcs après un coup électrique (0,3-0,6 s demandés)
const REFRESH_S := 0.1 ## relecture des états et choix des émetteurs
const DIRTY_MIN_S := 0.05 ## relecture anticipée (nouvel état) au plus toutes les 50 ms
const MAX_TRACK := 512
const Z := 25 ## au-dessus des monstres, sous les étincelles d'impact (HitFx, 30)
const VIEW_MARGIN_PX := 96.0

## Paliers Quality.Tier (LOW, MEDIUM, HIGH).
const EMITTERS: Array[int] = [3, 8, 16] ## émetteurs au plus par état
const RATE_MULT: Array[float] = [0.45, 0.75, 1.0]
const CAP_MULT: Array[float] = [0.15, 0.45, 1.0]
## Plafond de particules vivantes par sorte au palier Haut (le pool est dimensionné sur leur somme).
const KIND_CAP: Array[int] = [96, 96, 32, 48, 80, 64, 48]
## Sortes coupées en Bas (cendres et braises : la flammèche suffit à lire la brûlure).
const KIND_LOW_OFF: Array[bool] = [false, false, true, true, false, false, false]
const KIND_ADDITIVE: Array[bool] = [false, true, true, false, false, true, true]
## Part de la vitesse du monstre héritée à l'apparition (la particule suit le corps le temps de sa vie).
const KIND_INHERIT: Array[float] = [0.9, 1.0, 0.8, 0.3, 1.0, 1.0, 1.0]
const KIND_COLOR: Array[Color] = [
	Color(1.0, 1.0, 1.0, 1.0), # bulle : texture déjà verte
	Color(1.3, 1.12, 1.0, 1.0), # flammèche (HDR additif, sans virer au blanc)
	Color(1.6, 1.25, 0.9, 1.0), # braise
	Color(0.62, 0.6, 0.58, 1.0), # cendre (gris sombre)
	Color(0.78, 0.88, 1.0, 1.0), # goutte (eau claire)
	Color(0.85, 0.95, 1.6, 1.0), # arc (blanc bleuté HDR)
	Color(1.5, 1.35, 0.7, 1.0), # étoile (jaune pâle)
]
## Fondu : 0 quadratique, 1 « éclate » (tenu puis disparition rapide), 2 linéaire, 3 entrée-sortie (sinus).
const KIND_FADE: Array[int] = [1, 0, 0, 0, 1, 2, 3]
const STATUS_DIR := "res://assets/sprites/vfx/status/"
## [fichier du lot Codex (vfx/status/<nom>_NN.png), replis existants]
const KIND_FILES := [
	["poison_bubble", ["res://assets/sprites/vfx/particles/poison_bubble_01.png", "res://assets/sprites/vfx/particles/poison_bubble_02.png",
		"res://assets/sprites/vfx/particles/poison_bubble_03.png", "res://assets/sprites/vfx/particles/poison_bubble_04.png"]],
	["burn_flame", ["res://assets/sprites/vfx/particles/fire_drop_01.png", "res://assets/sprites/vfx/particles/fire_drop_02.png",
		"res://assets/sprites/vfx/particles/fire_drop_03.png", "res://assets/sprites/vfx/particles/fire_drop_04.png"]],
	["burn_ember", ["res://assets/sprites/vfx/particles/ember_01.png", "res://assets/sprites/vfx/particles/ember_03.png"]],
	["burn_ash", ["res://assets/sprites/ambiance/ash_16.png", "res://assets/sprites/ambiance/ash_16_2.png"]],
	["wet_drip", ["res://assets/sprites/ambiance/drop_32.png", "res://assets/sprites/ambiance/drop_32_2.png",
		"res://assets/sprites/ambiance/drop_32_4.png"]],
	["shock_arc", ["res://assets/sprites/vfx/particles/arc_fragment_01.png", "res://assets/sprites/vfx/particles/arc_fragment_02.png",
		"res://assets/sprites/vfx/particles/arc_fragment_03.png", "res://assets/sprites/vfx/particles/arc_fragment_04.png"]],
	["stun_star", ["res://assets/sprites/vfx/particles/ember_01.png", "res://assets/sprites/vfx/particles/ember_03.png"]], # lueurs rondes (les spark_* sont des traînées)
]
## Hauteur du corps (px billboard) = rayon de collision × facteur (tier ; boss à part). Sprites v2 : essaim ~48 px,
## tireur ~96, brute ~124 (art/briefs/monsters_v2.md §2).
const HEIGHT_K := {1: 2.0, 2: 3.0, 3: 2.6}
const HEIGHT_K_BOSS := 2.3

static var _inst: StatusFx = null
## Banc / débogage : faux = plus rien n'est suivi (mesure « avant » du banc de perf).
static var enabled := true
## Coût CPU de la dernière image (µs : relecture + émission + particules) et compteurs de relecture (tests, banc).
static var stat_usec := 0
static var stat_refreshes := 0

# --- Monstres suivis (tableaux denses ; une case morte est compactée à la relecture suivante)
var _n := 0
var _ent: Array[Enemy] = []
var _dead := PackedByteArray()
var _mask := PackedInt32Array()
var _wet_left := PackedFloat32Array()
var _shock_left := PackedFloat32Array()
var _stun_left := PackedFloat32Array()
var _shock_new := PackedByteArray() ## arcs : salve d'ouverture à émettre
var _stun_new := PackedByteArray() ## étoiles : couronne de 3 à poser
var _tinted := PackedByteArray()
var _emit := PackedInt32Array() ## bits ST_BITS dont ce monstre est émetteur
var _acc := PackedFloat32Array() ## accumulateurs d'émission, ST_COUNT par case
var _prev := PackedVector2Array() ## position billboard de l'image précédente (vitesse héritée)
var _vel := PackedVector2Array()
var _h := PackedFloat32Array() ## hauteur du corps (px billboard)
var _hw := PackedFloat32Array() ## demi-largeur
var _size := PackedFloat32Array() ## facteur de taille des particules (boss plus gros)
var _rate := PackedFloat32Array() ## facteur de débit (boss plus dense)
var _boss := PackedByteArray()
var _em_slots := PackedInt32Array() ## cases émettrices (reconstruites à chaque relecture)
var _em_n := 0
var _em_count := PackedInt32Array() ## émetteurs par état (dernière relecture)

# --- Particules (pool fixe)
var _pcap := 0
var _free := PackedInt32Array()
var _live := PackedInt32Array()
var _pkind := PackedByteArray()
var _pvar := PackedByteArray()
var _ppos := PackedVector2Array()
var _pvel := PackedVector2Array()
var _page := PackedFloat32Array()
var _plife := PackedFloat32Array()
var _ps0 := PackedFloat32Array()
var _ps1 := PackedFloat32Array()
var _pa0 := PackedFloat32Array()
var _prot := PackedFloat32Array()
var _pspin := PackedFloat32Array()
var _pgrav := PackedFloat32Array()
var _pang := PackedFloat32Array() ## étoiles : angle d'orbite
var _porb := PackedVector2Array() ## étoiles : rayons d'orbite (0 = pas d'orbite)
var _kind_live := PackedInt32Array()

# --- Rendu
var _tex: Array = [] ## Kind -> Array[Texture2D]
var _mm: Array[MultiMesh] = [] ## index kind × VARIANTS + variante
var _mmi: Array[MultiMeshInstance2D] = []
var _mm_count := PackedInt32Array()
var _mm_shown := PackedInt32Array()
var _tex_size := PackedVector2Array()

var _rng := RandomNumberGenerator.new()
var _refresh_t := 0.0
var _since_refresh := 0.0
var _dirty := false
var _tier := 2
var _reduce := false
var _flashes := 2


## Crée l'instance unique (différé) sous `parent` si elle n'existe pas encore.
static func ensure(parent: Node) -> void:
	if _inst != null and is_instance_valid(_inst) and not _inst.is_queued_for_deletion():
		return
	if parent == null:
		return
	_inst = StatusFx.new()
	_inst.name = &"StatusFx"
	parent.add_child.call_deferred(_inst)


static func instance() -> StatusFx:
	if _inst != null and is_instance_valid(_inst) and _inst.is_inside_tree():
		return _inst
	return null


# --- API (appelée par Enemy et par les kits ; coût nul si l'instance manque ou si le monstre est déjà suivi)

## Un état lu dans Enemy.status_mask (brûlure, poison) vient d'être posé.
static func track(e: Enemy) -> void:
	var fx := instance()
	if fx != null and enabled:
		fx._slot_of(e)


## Monstre trempé par Averse pendant `seconds` (miroir visuel de AverseKit._soak : une trempe courte n'écourte jamais
## une trempe en cours).
static func wet(e: Node, seconds: float) -> void:
	var fx := instance()
	if fx == null or not enabled or not (e is Enemy):
		return
	var i := fx._slot_of(e as Enemy)
	if i >= 0:
		fx._wet_left[i] = maxf(fx._wet_left[i], seconds)


## Coup électrique (foudre en chaîne, pilier électrisé de Tocsin) : arcs sur le corps pendant `seconds`.
static func shock(e: Node, seconds: float = SHOCK_S) -> void:
	var fx := instance()
	if fx == null or not enabled or not (e is Enemy):
		return
	var i := fx._slot_of(e as Enemy)
	if i >= 0:
		if fx._shock_left[i] <= 0.0:
			fx._shock_new[i] = 1
		fx._shock_left[i] = maxf(fx._shock_left[i], seconds)


## Étourdissement réel (Enemy.stun) : étoiles au-dessus de la tête pendant `seconds`.
static func stun(e: Enemy, seconds: float) -> void:
	var fx := instance()
	if fx == null or not enabled:
		return
	var i := fx._slot_of(e)
	if i >= 0:
		if fx._stun_left[i] <= 0.0:
			fx._stun_new[i] = 1
		fx._stun_left[i] = maxf(fx._stun_left[i], seconds)


## Monstre rendu au pool ou réactivé : on l'oublie (teinte retirée tout de suite).
static func forget(e: Enemy) -> void:
	var fx := instance()
	if fx == null:
		e.status_fx_slot = -1
		return
	fx._forget(e)


# --- Lecture (tests, banc)

func tracked_count() -> int:
	var c := 0
	for i in _n:
		if _dead[i] == 0:
			c += 1
	return c


func live_count() -> int:
	return _live_n


func kind_live(k: int) -> int:
	return _kind_live[k]


func emitter_count(st: int) -> int:
	return _em_count[st]


func kind_cap(k: int) -> int:
	return _kind_cap(k)


func is_tracked(e: Enemy) -> bool:
	return e.status_fx_slot >= 0 and e.status_fx_slot < _n and _ent[e.status_fx_slot] == e and _dead[e.status_fx_slot] == 0


func has_texture(k: int) -> bool:
	return not (_tex[k] as Array).is_empty()


## Force la relecture à la prochaine image (tests).
func refresh_now() -> void:
	_dirty = true
	_since_refresh = DIRTY_MIN_S


func _ready() -> void:
	top_level = true
	scale = Iso.UNSQUASH
	z_index = Z
	light_mask = 0
	_rng.randomize()
	var mat_add := CanvasItemMaterial.new()
	mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat_add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var mat_mix := CanvasItemMaterial.new()
	mat_mix.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var quad := _unit_quad()
	_pcap = 0
	for k in KIND_COUNT:
		_pcap += KIND_CAP[k]
		_tex.append(_load_kind(k))
	_mm_count.resize(KIND_COUNT * VARIANTS)
	_mm_shown.resize(KIND_COUNT * VARIANTS)
	_tex_size.resize(KIND_COUNT * VARIANTS)
	for k in KIND_COUNT:
		var texs: Array = _tex[k]
		for v in VARIANTS:
			var mm: MultiMesh = null
			var mmi: MultiMeshInstance2D = null
			if v < texs.size():
				var t: Texture2D = texs[v]
				mm = MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_2D
				mm.use_colors = true
				mm.mesh = quad
				mm.instance_count = KIND_CAP[k]
				mm.visible_instance_count = 0
				mmi = MultiMeshInstance2D.new()
				mmi.name = &"%s_%d" % [KIND_FILES[k][0], v]
				mmi.multimesh = mm
				mmi.texture = t
				mmi.material = mat_add if KIND_ADDITIVE[k] else mat_mix
				mmi.light_mask = 0
				mmi.visible = false
				add_child(mmi)
				_tex_size[k * VARIANTS + v] = t.get_size()
			_mm.append(mm)
			_mmi.append(mmi)
	_ent.resize(MAX_TRACK)
	_dead.resize(MAX_TRACK)
	_mask.resize(MAX_TRACK)
	_wet_left.resize(MAX_TRACK)
	_shock_left.resize(MAX_TRACK)
	_stun_left.resize(MAX_TRACK)
	_shock_new.resize(MAX_TRACK)
	_stun_new.resize(MAX_TRACK)
	_tinted.resize(MAX_TRACK)
	_emit.resize(MAX_TRACK)
	_acc.resize(MAX_TRACK * ST_COUNT)
	_prev.resize(MAX_TRACK)
	_vel.resize(MAX_TRACK)
	_h.resize(MAX_TRACK)
	_hw.resize(MAX_TRACK)
	_size.resize(MAX_TRACK)
	_rate.resize(MAX_TRACK)
	_boss.resize(MAX_TRACK)
	_em_slots.resize(MAX_TRACK)
	_em_count.resize(ST_COUNT)
	_kind_live.resize(KIND_COUNT)
	_pkind.resize(_pcap)
	_pvar.resize(_pcap)
	_ppos.resize(_pcap)
	_pvel.resize(_pcap)
	_page.resize(_pcap)
	_plife.resize(_pcap)
	_ps0.resize(_pcap)
	_ps1.resize(_pcap)
	_pa0.resize(_pcap)
	_prot.resize(_pcap)
	_pspin.resize(_pcap)
	_pgrav.resize(_pcap)
	_pang.resize(_pcap)
	_porb.resize(_pcap)
	_free.resize(_pcap)
	for i in _pcap:
		_free[i] = _pcap - 1 - i
	_free_n = _pcap
	_live.resize(_pcap) # taille réservée ; _live_n compte les vivantes
	_live_n = 0
	set_process(false)


var _live_n := 0
var _free_n := 0 ## pile des particules libres : _free[0.._free_n)


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


## Quad unité centré (sommets 2D, UV à la convention du canevas : y vers le bas, aucune inversion).
static func _unit_quad() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Textures d'une sorte : lot Codex (vfx/status/<nom>_01..04.png) s'il existe, sinon les replis.
static func _load_kind(k: int) -> Array:
	var out: Array = []
	var base: String = KIND_FILES[k][0]
	for v in VARIANTS:
		var p := "%s%s_%02d.png" % [STATUS_DIR, base, v + 1]
		if ResourceLoader.exists(p):
			out.append(load(p))
	if out.is_empty():
		for p: String in KIND_FILES[k][1]:
			if out.size() < VARIANTS and ResourceLoader.exists(p):
				out.append(load(p))
	return out


# --- Suivi

## Case du monstre (créée au besoin) ; -1 si la liste est pleine ou le monstre inactif.
func _slot_of(e: Enemy) -> int:
	var i := e.status_fx_slot
	if i >= 0 and i < _n and _ent[i] == e and _dead[i] == 0:
		return i
	if not e.active or _n >= MAX_TRACK:
		return -1
	i = _n
	_n += 1
	_ent[i] = e
	_dead[i] = 0
	_mask[i] = 0
	_wet_left[i] = 0.0
	_shock_left[i] = 0.0
	_stun_left[i] = 0.0
	_shock_new[i] = 0
	_stun_new[i] = 0
	_tinted[i] = 0
	_emit[i] = 0
	for s in ST_COUNT:
		_acc[i * ST_COUNT + s] = 0.0
	var b := _billboard(e.global_position)
	_prev[i] = b
	_vel[i] = Vector2.ZERO
	var boss := e.is_boss
	_boss[i] = 1 if boss else 0
	var r := e.radius_px
	_h[i] = r * (HEIGHT_K_BOSS if boss else float(HEIGHT_K.get(e.tier, 2.4)))
	_hw[i] = r * (0.85 if boss else 1.0)
	_size[i] = clampf(r / 26.0, 0.9, 1.7) if boss else 1.0
	_rate[i] = 2.0 if boss else (1.3 if e.tier == 3 else 1.0)
	e.status_fx_slot = i
	_dirty = true
	if not is_processing():
		_refresh_t = 0.0
		_since_refresh = DIRTY_MIN_S
		set_process(true)
	return i


func _forget(e: Enemy) -> void:
	var i := e.status_fx_slot
	e.status_fx_slot = -1
	if i < 0 or i >= _n or _ent[i] != e or _dead[i] != 0:
		return
	_release(i)


## Libère une case (teinte retirée) ; compactée à la relecture.
func _release(i: int) -> void:
	var e := _ent[i]
	if _tinted[i] != 0 and e != null:
		(e.visual as EnemyVisual).set_wet(false)
	_tinted[i] = 0
	_dead[i] = 1
	_emit[i] = 0
	if e != null and e.status_fx_slot == i:
		e.status_fx_slot = -1


func _compact() -> void:
	var w := 0
	for i in _n:
		if _dead[i] != 0:
			_ent[i] = null
			continue
		if w != i:
			_ent[w] = _ent[i]
			_ent[i] = null
			_dead[w] = 0
			_mask[w] = _mask[i]
			_wet_left[w] = _wet_left[i]
			_shock_left[w] = _shock_left[i]
			_stun_left[w] = _stun_left[i]
			_shock_new[w] = _shock_new[i]
			_stun_new[w] = _stun_new[i]
			_tinted[w] = _tinted[i]
			_emit[w] = _emit[i]
			for s in ST_COUNT:
				_acc[w * ST_COUNT + s] = _acc[i * ST_COUNT + s]
			_prev[w] = _prev[i]
			_vel[w] = _vel[i]
			_h[w] = _h[i]
			_hw[w] = _hw[i]
			_size[w] = _size[i]
			_rate[w] = _rate[i]
			_boss[w] = _boss[i]
			_ent[w].status_fx_slot = w
		w += 1
	_n = w


# --- Boucle

func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_refresh_t -= delta
	_since_refresh += delta
	if _refresh_t <= 0.0 or (_dirty and _since_refresh >= DIRTY_MIN_S):
		_refresh(_since_refresh)
	_emit_all(delta)
	_step_particles(delta)
	if _n == 0 and _live_n == 0:
		set_process(false)
	stat_usec = Time.get_ticks_usec() - t0


## Relecture des états (toutes les REFRESH_S) : fin des états, teinte mouillée, choix des émetteurs.
func _refresh(elapsed: float) -> void:
	stat_refreshes += 1
	_refresh_t = REFRESH_S
	_since_refresh = 0.0
	_dirty = false
	_tier = clampi(Quality.tier, 0, 2)
	_reduce = GameSettings.reduce_motion()
	_flashes = Quality.flashes_level
	# rectangle visible (y logique) agrandi d'une marge ; centre pour le niveau de détail
	var vp := get_viewport()
	var view := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	view = view.grow(VIEW_MARGIN_PX)
	var center := view.get_center()
	var near2 := view.size.length_squared() * 0.06 # ~25 % de la diagonale
	for s in ST_COUNT:
		_em_count[s] = 0
	_em_n = 0
	var cap := EMITTERS[_tier]
	# passe 1 : états à jour, cases libérées ; boss puis monstres proches du centre -> émetteurs
	for i in _n:
		if _dead[i] != 0:
			continue
		var e := _ent[i]
		if e == null or not e.active:
			_release(i)
			continue
		if _wet_left[i] > 0.0:
			_wet_left[i] -= elapsed
		if _shock_left[i] > 0.0:
			_shock_left[i] -= elapsed
		if _stun_left[i] > 0.0:
			_stun_left[i] -= elapsed
		var m := e.status_mask() & (B_BURN | B_POISON)
		if _wet_left[i] > 0.0:
			m |= B_WET
		if _shock_left[i] > 0.0:
			m |= B_SHOCK
		if _stun_left[i] > 0.0 and e.is_stunned():
			m |= B_STUN
		_mask[i] = m
		_emit[i] = 0
		if m == 0:
			_release(i)
			continue
		var wet_on := 1 if (m & B_WET) != 0 else 0
		if wet_on != _tinted[i]:
			_tinted[i] = wet_on
			(e.visual as EnemyVisual).set_wet(wet_on == 1)
		var p := e.global_position
		if not view.has_point(p):
			_mask[i] = m | (1 << 30) # hors écran : jamais émetteur
			continue
		if _boss[i] != 0 or p.distance_squared_to(center) <= near2:
			_assign(i, m, cap)
	# passe 2 : les autres monstres à l'écran, dans la limite des places restantes
	for i in _n:
		if _dead[i] != 0 or _emit[i] != 0 or (_mask[i] & (1 << 30)) != 0:
			continue
		if _boss[i] == 0 and _ent[i].global_position.distance_squared_to(center) > near2:
			_assign(i, _mask[i], cap)
	_compact_if_needed()


func _assign(i: int, m: int, cap: int) -> void:
	var bits := 0
	for s in ST_COUNT:
		if (m & ST_BITS[s]) != 0 and _em_count[s] < cap:
			_em_count[s] += 1
			bits |= ST_BITS[s]
	if bits == 0:
		return
	if _emit[i] == 0:
		_prev[i] = _billboard(_ent[i].global_position)
		_vel[i] = Vector2.ZERO
	_emit[i] = bits
	_em_slots[_em_n] = i
	_em_n += 1


func _compact_if_needed() -> void:
	var any_dead := false
	for i in _n:
		if _dead[i] != 0:
			any_dead = true
			break
	if not any_dead:
		return
	_compact()
	# les indices ont bougé : liste des émetteurs reconstruite
	_em_n = 0
	for i in _n:
		if _emit[i] != 0:
			_em_slots[_em_n] = i
			_em_n += 1


## Émission (émetteurs seulement) : accumulateurs par état, débit × palier × taille du monstre.
func _emit_all(delta: float) -> void:
	if delta <= 0.0:
		return
	var rm: float = RATE_MULT[_tier] * (0.5 if _reduce else 1.0)
	for j in _em_n:
		var i := _em_slots[j]
		if _dead[i] != 0 or _emit[i] == 0:
			continue
		var e := _ent[i]
		if not e.active:
			continue
		var b := _billboard(e.global_position)
		var v := (b - _prev[i]) / delta
		_vel[i] = _vel[i].lerp(v, 0.5) if v.length_squared() < 4.0e6 else _vel[i] # téléportation : vitesse ignorée
		_prev[i] = b
		var bits := _emit[i]
		var r := rm * _rate[i]
		var a := i * ST_COUNT
		if (bits & B_POISON) != 0:
			_acc[a] += 6.0 * r * delta
			while _acc[a] >= 1.0:
				_acc[a] -= 1.0
				_spawn_bubble(i, b)
		if (bits & B_BURN) != 0:
			_acc[a + 1] += 9.0 * r * delta
			while _acc[a + 1] >= 1.0:
				_acc[a + 1] -= 1.0
				_spawn_flame(i, b)
				# cendres et braises : une flammèche sur trois environ (coupées en Bas)
				var roll := _rng.randf()
				if roll < 0.33:
					_spawn_ash(i, b)
				elif roll < 0.55:
					_spawn_ember(i, b)
		if (bits & B_WET) != 0:
			_acc[a + 2] += 6.0 * r * delta
			while _acc[a + 2] >= 1.0:
				_acc[a + 2] -= 1.0
				_spawn_drop(i, b)
		if (bits & B_SHOCK) != 0:
			if _shock_new[i] != 0:
				_shock_new[i] = 0
				_acc[a + 3] += 1.0 if _reduce else 3.0 # salve d'ouverture
			_acc[a + 3] += (4.0 if _reduce else 10.0) * r * delta
			while _acc[a + 3] >= 1.0:
				_acc[a + 3] -= 1.0
				_spawn_arc(i, b)
		if (bits & B_STUN) != 0:
			if _stun_new[i] != 0: # couronne de 3 étoiles réparties d'emblée
				_stun_new[i] = 0
				var a0 := _rng.randf() * TAU
				for n in 3:
					_spawn_star(i, b, a0 + TAU * float(n) / 3.0)
			_acc[a + 4] += 4.0 * minf(r, 1.0) * delta # ~3 étoiles visibles ensuite, quelle que soit la taille
			while _acc[a + 4] >= 1.0:
				_acc[a + 4] -= 1.0
				_spawn_star(i, b, _rng.randf() * TAU)


# --- Apparitions (positions en espace billboard ; pieds = b, y vers le haut négatif)

func _spawn_bubble(i: int, b: Vector2) -> void:
	var h := _h[i]
	var p := b + Vector2(_rng.randf_range(-0.8, 0.8) * _hw[i], -_rng.randf_range(0.15, 0.75) * h)
	var v := Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-48.0, -26.0))
	_spawn(Kind.BUBBLE, i, p, v, _rng.randf_range(0.7, 1.0), _rng.randf_range(0.45, 0.7) * _size[i], 1.3, 0.95, 0.0, 0.0, -12.0)


func _spawn_flame(i: int, b: Vector2) -> void:
	var p := b + Vector2(_rng.randf_range(-0.7, 0.7) * _hw[i], -_rng.randf_range(0.1, 0.8) * _h[i])
	var v := Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-72.0, -50.0))
	_spawn(Kind.FLAME, i, p, v, _rng.randf_range(0.3, 0.45), _rng.randf_range(0.7, 1.0) * _size[i], 0.35, 0.9,
		_rng.randf_range(-0.2, 0.2), 0.0, -60.0)


func _spawn_ember(i: int, b: Vector2) -> void:
	var p := b + Vector2(_rng.randf_range(-0.6, 0.6) * _hw[i], -_rng.randf_range(0.3, 0.9) * _h[i])
	var v := Vector2(_rng.randf_range(-25.0, 25.0), _rng.randf_range(-90.0, -60.0))
	_spawn(Kind.EMBER, i, p, v, _rng.randf_range(0.6, 0.9), _rng.randf_range(0.25, 0.4) * _size[i], 0.5, 0.95, 0.0, 0.0, -20.0)


func _spawn_ash(i: int, b: Vector2) -> void:
	var p := b + Vector2(_rng.randf_range(-0.6, 0.6) * _hw[i], -_rng.randf_range(0.6, 1.0) * _h[i])
	var v := Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-32.0, -15.0))
	var spin := _rng.randf_range(-3.0, 3.0) * (0.3 if _reduce else 1.0)
	_spawn(Kind.ASH, i, p, v, _rng.randf_range(1.0, 1.4), _rng.randf_range(1.0, 1.5) * _size[i], 0.7, 0.85,
		_rng.randf() * TAU, spin, -6.0)


func _spawn_drop(i: int, b: Vector2) -> void:
	var lift := _rng.randf_range(0.25, 0.7) * _h[i]
	var p := b + Vector2(_rng.randf_range(-0.9, 0.9) * _hw[i], -lift)
	const G := 700.0
	var life := clampf(sqrt(2.0 * lift / G), 0.15, 0.45) # touche le sol à la fin de sa vie
	_spawn(Kind.DROP, i, p, Vector2(0.0, 25.0), life, _rng.randf_range(0.45, 0.6) * _size[i], 1.0, 0.9, 0.0, 0.0, G)


func _spawn_arc(i: int, b: Vector2) -> void:
	var p := b + Vector2(_rng.randf_range(-0.8, 0.8) * _hw[i], -_rng.randf_range(0.2, 0.9) * _h[i])
	var life := _rng.randf_range(0.2, 0.3) if _reduce else _rng.randf_range(0.07, 0.13)
	var a0 := 1.0 if _flashes >= 2 else (0.75 if _flashes == 1 else 0.5)
	_spawn(Kind.ARC, i, p, Vector2.ZERO, life, _rng.randf_range(0.45, 0.7) * _size[i], 1.0, a0, _rng.randf() * TAU, 0.0, 0.0)


func _spawn_star(i: int, b: Vector2, ang: float) -> void:
	var c := b + Vector2(0.0, -_h[i] - 8.0)
	var k := _spawn(Kind.STAR, i, c, Vector2.ZERO, 0.6, 0.45 * _size[i], 1.0, 1.0, 0.0, 0.0, 0.0)
	if k >= 0:
		var rx := _hw[i] * 0.9 + 6.0
		_porb[k] = Vector2(rx, rx * 0.35)
		_pang[k] = ang
		_pspin[k] = (1.2 if _reduce else 5.0) # vitesse d'orbite (rad/s)


## Particule de sorte `kind` ; retourne son index (-1 : plafond atteint, pool plein ou sorte sans texture).
func _spawn(kind: int, i: int, pos: Vector2, v: Vector2, life: float, s0: float, s1: float, a0: float, rot: float, spin: float, grav: float) -> int:
	if _kind_live[kind] >= _kind_cap(kind) or _free_n <= 0:
		return -1
	var texs: Array = _tex[kind]
	if texs.is_empty():
		return -1
	_free_n -= 1
	var k := _free[_free_n]
	_live[_live_n] = k
	_live_n += 1
	_kind_live[kind] += 1
	_pkind[k] = kind
	_pvar[k] = _rng.randi() % texs.size()
	_ppos[k] = pos
	_pvel[k] = v + _vel[i] * KIND_INHERIT[kind]
	_page[k] = 0.0
	_plife[k] = life
	_ps0[k] = s0
	_ps1[k] = s1
	_pa0[k] = a0
	_prot[k] = rot
	_pspin[k] = spin
	_pgrav[k] = grav
	_porb[k] = Vector2.ZERO
	return k


func _kind_cap(k: int) -> int:
	if _tier == 0 and KIND_LOW_OFF[k]:
		return 0
	return maxi(1, roundi(float(KIND_CAP[k]) * CAP_MULT[_tier]))


## Avance les particules et remplit les MultiMesh (une par sorte et variante).
func _step_particles(delta: float) -> void:
	for m in _mm_count.size():
		_mm_count[m] = 0
	var j := _live_n - 1
	while j >= 0:
		var k := _live[j]
		var age := _page[k] + delta
		var life := _plife[k]
		if age >= life:
			_kind_live[_pkind[k]] -= 1
			_free[_free_n] = k
			_free_n += 1
			_live_n -= 1
			_live[j] = _live[_live_n]
			j -= 1
			continue
		_page[k] = age
		var kind := _pkind[k]
		var v := _pvel[k]
		v.y += _pgrav[k] * delta
		_pvel[k] = v
		var p := _ppos[k] + v * delta
		_ppos[k] = p
		var t := age / life
		var draw_p := p
		var orb := _porb[k]
		if orb.x > 0.0:
			var ang := _pang[k] + _pspin[k] * delta
			_pang[k] = ang
			draw_p = p + Vector2(cos(ang) * orb.x, sin(ang) * orb.y)
		elif _pspin[k] != 0.0:
			_prot[k] += _pspin[k] * delta
		var a := _pa0[k]
		match KIND_FADE[kind]:
			0:
				a *= 1.0 - t * t
			1:
				a *= 1.0 - pow(t, 6.0)
			2:
				a *= 1.0 - t
			_:
				a *= sin(PI * t)
		var sc := _ps0[k] * lerpf(1.0, _ps1[k], t)
		var mi := kind * VARIANTS + _pvar[k]
		var c := _mm_count[mi]
		var sz := _tex_size[mi] * sc
		var mm := _mm[mi]
		mm.set_instance_transform_2d(c, Transform2D(_prot[k], sz, 0.0, draw_p))
		var col: Color = KIND_COLOR[kind]
		if _flashes == 0 and KIND_ADDITIVE[kind]:
			col = Color(minf(col.r, 1.0), minf(col.g, 1.0), minf(col.b, 1.0), 1.0)
		col.a = a
		mm.set_instance_color(c, col)
		_mm_count[mi] = c + 1
		j -= 1
	for m in _mm_count.size():
		var c := _mm_count[m]
		if c != _mm_shown[m] and _mm[m] != null:
			_mm_shown[m] = c
			_mm[m].visible_instance_count = c
			_mmi[m].visible = c > 0


## Point du monde (y logique) -> espace billboard : (x, y/2).
static func _billboard(p: Vector2) -> Vector2:
	return Vector2(p.x, p.y / Iso.UNSQUASH.y)
