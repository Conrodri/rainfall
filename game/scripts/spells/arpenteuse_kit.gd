class_name ArpenteuseKit
extends Node
## Kit de l'Arpenteuse, géomètre de la Cité (docs/Design_Personnages.md §2.2 ; kit complété le 22/10/2026
## dans l'esprit de la fiche et de Rictus §2.6, voir le rapport d'intégration). 4 sorts / 0 passif.
## Ressource = la chaîne au sol : les CHAIN_MAX_U derniers u de son trajet. Elle ne blesse que ce qu'elle a parcouru.
## - Sort 1 Chaîne (auto) : la traîne elle-même ; tick de zone-ligne (cadence = vitesse d'attaque), ralentit.
##   Immobile : le touret rembobine la chaîne (CHAIN_IDLE_S puis CHAIN_REEL_U_S) : rester sur place = ne rien faire.
## - Sort 2 Boucle : ferme la chaîne d'un trait droit ; le polygone s'embrase (dedans + contour), attire vers
##   le centre ; la chaîne est consommée. Exige BOUCLE_MIN_U de chaîne.
## - Sort 3 Piquet : piquet planté au point visé (6 u) ; ligne tendue piquet -> elle 5 s qui balaie
##   (immunité par monstre) ; arrachée au-delà de PEG_SNAP_U.
## - Sort 4 Tendeur : la chaîne (et la ligne du piquet) claque, puis se rembobine en traînant les monstres
##   touchés jusqu'à elle, emprisonnés 1 s (statut `imprisoned` d'Enemy, partagé avec Tocsin).
## Variantes (docs/Variantes_Sorts.md §2.5, lot 7 du 23/10/2026) : Chaîne lestée (slot 1), Nœud (2), Jalons (3),
## Cerceau (4) ; `variant(slot, id)` rend leur SpellData, le kit lit l'id du sort du slot pour se comporter.
## Effets à la frame d'impact des anims d'action (loop / plant / whip, lot AR1). Rendu : ArpenteuseChainLine.
## Logique : enfant « Kit » du joueur (CharacterData.kit_script), hooks interrogés par Player et SpellCaster.

# --- Assets (lots Codex AR1 / AR2) ----------------------------------------------------------------
const ASSET_DIR := "res://assets/sprites/characters/arpenteuse/"
const SPRITE_FRAMES := ASSET_DIR + "arpenteuse.tres" ## idle/run/plant/loop/whip/attack/cast/cast_ult/death _<dir>
const PEG_FRAMES := ASSET_DIR + "effects/peg.tres" ## peg_<dir> (CREA 192, 1 frame, chaîne pendante vers <dir>)
const LOOP_BLAZE_FRAMES := ASSET_DIR + "effects/loop_blaze.tres" ## `default` TOP 256, 6 frames, hexagone de chaîne
const LOOP_BLAZE_RADIUS_PX := 108.0 ## rayon de l'hexagone dans la cellule (mesuré sur la planche AR2)
const TOP_PX_PER_U := 128.0 ## rig TOP
const PEG_OFFSET := Vector2(0, -40.32) ## pivot des pieds des rendus CREA (136,32 px dans la cellule 192)
const PLACEHOLDER_TINT := Color(0.62, 0.45, 0.34) ## Ardent teinté ciré brun si AR1 manque
const ACCENT := Color("#FF7A1F") ## cuivre chauffé : accent unique (la chaîne), rien d'émissif sur elle

# --- Gameplay : chaîne (sort 1) --------------------------------------------------------------------
const HP_BASE := 85.0
const HP_PER_LEVEL := 25.0
const REGEN_BASE := 1.0
const REGEN_PER_LEVEL := 0.2
const SPEED_U := 4.2
const CHAIN_MAX_U := 14.0
const CHAIN_STEP_U := 0.25 ## espacement des points posés (23/10 : 0,5 -> 0,25, angles plus doux et segments ancrés)
const CHAIN_HALF_WIDTH_U := 0.25 ## zone-ligne de 0,5 u de large
const CHAIN_VIS_WIDTH_U := 0.9 ## bande texturée (maillons ~40 % de la cellule) ; capture : 0,6 trop fin en iso
const CHAIN_COEF := 1.0 ## équilibrage 22/10 : 0,8 -> 1,0 ; fiche 0,5 -> 0,8 : un monstre de base (18 PV) tombe en 2 ticks (rythme Ardent/Rictus)
const CHAIN_TICK_S := 0.5 ## Balance.attack_interval : la vitesse d'attaque accélère les ticks
const CHAIN_PROC := 0.3
const CHAIN_FORCE := 0.1 ## petit flash sans recul (la chaîne mord, ne repousse pas)
const CHAIN_SLOW_PCT := 0.35 ## équilibrage 22/10 : 0,2 -> 0,35 (sa défense : ce qui la poursuit s'englue dans la chaîne)
const CHAIN_SLOW_S := 0.6
const CHAIN_IDLE_S := 0.6 ## immobile plus longtemps : le touret rembobine
const CHAIN_REEL_U_S := 4.0
const CHAIN_JUMP_U := 4.0 ## saut de position (téléporteur) : la chaîne est coupée
const HEAT_FLASH_S := 0.18 ## la chaîne rougit quand elle mord
const HEAT_ENERGY := 2.6
const HEAT_FLASH_ENERGY := 4.5
const CHAIN_LIGHTS := 2
# --- Boucle (sort 2) -------------------------------------------------------------------------------
const BOUCLE_COEF := 3.5 ## équilibrage 22/10 : 3,0 -> 3,5
const BOUCLE_CD := 6.0
const BOUCLE_MIN_U := 3.0 ## en dessous, pas de boucle (rien n'est lancé, aucune recharge)
const BOUCLE_PULL_U := 1.0
const BOUCLE_FLARE_S := 0.45 ## contour embrasé
const BOUCLE_EDGE_U := 0.5 ## aide 23/10 : tolérance du contour (trait de fermeture compris) 0,25 -> 0,5 u, une boucle ratée de justesse touche quand même
const PREVIEW_WIDTH_PX := 3.0 ## aperçu du trait de fermeture de la Boucle (placeholder)
const PREVIEW_ALPHA := 0.5
# --- Piquet (sort 3) -------------------------------------------------------------------------------
const PIQUET_COEF := 1.0
const PIQUET_CD := 8.0
const PIQUET_RANGE_U := 6.0
const PIQUET_DEFAULT_U := 3.0 ## sans visée ni cible : devant elle
const PEG_LIFE_S := 5.0
const PEG_IMMUNITY_S := 0.5 ## fiche 0,3 -> 0,5 : un boss collé à la ligne ne dépasse pas 2 coefs/s
const PEG_PROC := 0.5
const PEG_KNOCK_U := 0.3
const PEG_SNAP_U := 10.0 ## plus loin, le piquet est arraché
const PEG_WALL_BACK_U := 0.3
# --- Tendeur (sort 4) ------------------------------------------------------------------------------
const TENDEUR_COEF := 10.0
const TENDEUR_CD := 20.0
const TENDEUR_REACH_U := 1.0
const TENDEUR_MIN_U := 2.0 ## chaîne minimale (ou piquet planté)
const TENDEUR_STUN_S := 1.5 ## équilibrage 22/10 : 1,0 -> 1,5
const TENDEUR_KEEP_U := 1.0 ## les monstres traînés s'arrêtent à 1 u d'elle
const SNAP_S := 0.25
const REWIND_S := 0.5
## Frames d'impact (index 0) des anims d'action d'AR1 (planches vérifiées : geste au sol / bras tendu).
const ACTION_IMPACT_FRAMES := {&"plant": 2, &"loop": 2, &"whip": 2, &"attack": 3, &"cast": 2, &"cast_ult": 3}
const PENDING_TIMEOUT_S := 1.0
const WALL_MASK := 1
## Équilibrage 22/10/2026 : boucler une cible mobile est rare (cible unique −44 % vs Ardent au simulateur).
## La géomètre « mesure les grands » : +BIG_TARGET_ADD (additif) sur élites et boss pour Boucle, Piquet, Tendeur.
const BIG_TARGET_ADD := 0.4 ## équilibrage 23/10 : 0,6 -> 0,4
# --- Variantes (docs/Variantes_Sorts.md §2.5) -----------------------------------------------------
const V_LESTEE := &"arpenteuse_chaine_lestee"
const V_NOEUD := &"arpenteuse_noeud"
const V_JALONS := &"arpenteuse_jalons"
const V_CERCEAU := &"arpenteuse_cerceau"
const LESTEE_MAX_U := 7.0 ## chaîne de 7 u, deux fois plus lourde
const LESTEE_COEF := 2.0
const LESTEE_SLOW_PCT := 0.5
const LESTEE_HALF_WIDTH_U := 0.3
const LESTEE_REEL_U_S := 8.0
const NOEUD_COEF := 3.5
const NOEUD_CD := 6.0
const NOEUD_MIN_U := 4.0 ## chaîne exigée
const NOEUD_TAIL_U := 4.0 ## u de queue noués (et consommés)
const NOEUD_RADIUS_U := 2.0
const NOEUD_SQUEEZE_S := 0.25
const NOEUD_PRISON_S := 1.0
const NOEUD_BOSS_SLOW := 0.4
const JALONS_COEF := 1.0
const JALONS_CD := 8.0
const JALONS_A_RANGE_U := 6.0
const JALONS_B_RANGE_U := 8.0 ## B à 8 u de A au plus
const JALONS_B_DEFAULT_U := 4.0 ## sans 2e pression : B à 4 u de A
const JALONS_WINDOW_S := 3.0
const JALONS_MIN_GAP_S := 0.6 ## 2e pression acceptée après ce délai (l'auto-cast ne pose pas A et B d'un trait)
const JALONS_MIN_SPAN_U := 3.0 ## B plus près que cela : le fil est allongé à JALONS_SPAN_U
const JALONS_SPAN_U := 6.0
const JALONS_LIFE_S := 6.0
const JALONS_PROC := 0.5
const JALONS_KNOCK_U := 0.3
const CERCEAU_COEF := 1.25
const CERCEAU_CD := 20.0
const CERCEAU_MIN_U := 2.0
const CERCEAU_RADIUS_U := 3.0 ## milieu de la bande (2,5 - 3,5 u)
const CERCEAU_BAND_HALF_U := 0.5
const CERCEAU_SPIN_S := 1.0 ## un tour par seconde
const CERCEAU_LIFE_S := 4.0
const CERCEAU_TICK_S := 0.5
const CERCEAU_PROC := 0.4
const CERCEAU_KNOCK_U := 0.6
const CERCEAU_POINTS := 40
const LOOP_AUTO_MIN_HITS := 2 ## auto-cast de la Boucle / du Nœud : attend au moins 2 monstres pris (1 si élite ou boss)
const DIR_NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

var player: CharacterBody2D = null
var chain: PackedVector2Array = [] ## points posés, de la queue au dernier ; la tête = sa position
var _tail_s := 0.0 ## abscisse de la queue (px), pour fixer les maillons au sol
var _m := 0.0 ## glissement de la matière (rembobinage)
var _idle_t := 0.0
var _tick_t := 0.0
var _heat_t := 0.0
var _last_head := Vector2.ZERO
var _pending := {} ## base d'anim -> {spell, aim, t}
var snap_left := 0.0
var rewind_left := 0.0
var _rewind_speed := 0.0
var _dragged: Array = []
# Piquet
var peg_left := 0.0
var peg_pos := Vector2.ZERO
var _peg_node: Node2D = null
var _peg_sprite: AnimatedSprite2D = null
var _peg_hits := {} ## instance_id -> temps du dernier coup
var _time := 0.0
# Variantes
var _lestee := false ## sort 1 = Chaîne lestée
var jal_stage := 0 ## Jalons : 0 rien, 1 piquet A planté (fenêtre de 3 s pour B)
var jal_a := Vector2.ZERO
var jal_b := Vector2.ZERO
var jal_line := false ## la ligne A-B est tendue
var _jal_t := 0.0
var _jal_dir := Vector2.DOWN
var _peg2_node: Node2D = null
var _peg2_sprite: AnimatedSprite2D = null
var ring_left := 0.0 ## Cerceau en cours (s restantes)
var _ring_angle := 0.0
var _ring_tick_t := 0.0
var ring_hits := 0 ## coups du Cerceau (tests)
var last_ring := {}
var last_noeud := {}
var _probe_t := -1.0 ## aperçu des monstres pris par la Boucle / le Nœud (auto-cast)
var _probe_n := 0
# Rendu
var _visual: AnimatedSprite2D = null
var fx_root: Node2D = null
var line: ArpenteuseChainLine = null
var peg_line: ArpenteuseChainLine = null
var preview: Line2D = null ## trait de fermeture de la Boucle quand elle est prête
var _lights: Array = []
## Compteurs pour les tests : coups de chaîne, ticks, dernière boucle {hits, area_px}.
var chain_hits := 0
var last_loop := {}
var last_tendeur := {}


# --- Données -------------------------------------------------------------------------------------

static func _force_for(knock_u: float) -> float:
	return clampf(inverse_lerp(Balance.KB_MIN_U, Balance.KB_MAX_U, knock_u), 0.0, 1.0)


static func _spell(sid: StringName, name: String, slot: int, coef: float, cd: float, preset: StringName) -> SpellData:
	var s := SpellData.new()
	s.id = sid
	s.display_name = name
	s.slot = slot
	s.behavior = SpellData.Behavior.KIT
	s.coef = coef
	s.base_cooldown = cd
	s.element = &"physical"
	s.color = ACCENT
	s.light_preset = preset ## cuivre chauffé, jamais la braise d'Ardent
	return s


static func character() -> CharacterData:
	var c := CharacterData.new()
	c.id = &"arpenteuse"
	c.display_name = "Arpenteuse"
	c.base_hp = HP_BASE
	c.hp_per_level = HP_PER_LEVEL
	c.armor = 0.0
	c.base_regen = REGEN_BASE
	c.regen_per_level = REGEN_PER_LEVEL
	c.base_speed_u = SPEED_U
	c.kit_script = ArpenteuseKit
	c.sprite_frames_path = SPRITE_FRAMES
	c.placeholder_tint = PLACEHOLDER_TINT
	c.body_color = Color("#3F2B1E")
	c.accent_color = ACCENT
	c.action_impact_frames = ACTION_IMPACT_FRAMES

	var s1 := _spell(&"arpenteuse_chaine", "Chaîne", 1, CHAIN_COEF, CHAIN_TICK_S, &"arpenteuse_chain")
	s1.is_auto = true
	s1.radius_u = CHAIN_HALF_WIDTH_U
	s1.range_u = CHAIN_MAX_U
	s1.proc_coef = CHAIN_PROC
	s1.hit_force = CHAIN_FORCE

	var s2 := _spell(&"arpenteuse_boucle", "Boucle", 2, BOUCLE_COEF, BOUCLE_CD, &"arpenteuse_blaze")
	s2.range_u = CHAIN_MAX_U
	s2.proc_coef = 1.0
	s2.hit_force = 1.0
	s2.trigger_range_u = 4.0

	var s3 := _spell(&"arpenteuse_piquet", "Piquet", 3, PIQUET_COEF, PIQUET_CD, &"arpenteuse_chain")
	s3.range_u = PIQUET_RANGE_U
	s3.duration = PEG_LIFE_S
	s3.proc_coef = PEG_PROC
	s3.hit_force = _force_for(PEG_KNOCK_U)
	s3.target_mode = &"densest" # mobile : piquet sur le paquet le plus dense
	s3.trigger_range_u = PIQUET_RANGE_U

	var s4 := _spell(&"arpenteuse_tendeur", "Tendeur", 4, TENDEUR_COEF, TENDEUR_CD, &"arpenteuse_snap")
	s4.range_u = CHAIN_MAX_U
	s4.radius_u = TENDEUR_REACH_U
	s4.proc_coef = 1.0
	s4.hit_force = 1.0
	s4.trigger_range_u = 4.0

	c.spells = [s1, s2, s3, s4]
	return c


## Variantes de sorts (contrat CONTRACTS.md « Variantes de sorts ») : SpellData de la variante `variant_id`
## pour le slot, ou null (sort de base gardé). Chiffres : docs/Variantes_Sorts.md §2.5.
static func variant(slot: int, variant_id: StringName) -> SpellData:
	match [slot, variant_id]:
		[1, V_LESTEE]:
			var s1 := _spell(V_LESTEE, "Chaîne lestée", 1, LESTEE_COEF, CHAIN_TICK_S, &"arpenteuse_chain")
			s1.is_auto = true
			s1.radius_u = LESTEE_HALF_WIDTH_U
			s1.range_u = LESTEE_MAX_U
			s1.proc_coef = CHAIN_PROC
			s1.hit_force = CHAIN_FORCE
			return s1
		[2, V_NOEUD]:
			var s2 := _spell(V_NOEUD, "Nœud", 2, NOEUD_COEF, NOEUD_CD, &"arpenteuse_blaze")
			s2.range_u = NOEUD_TAIL_U
			s2.radius_u = NOEUD_RADIUS_U
			s2.proc_coef = 1.0
			s2.hit_force = 0.0 # pas d'attraction : les monstres sont coincés
			s2.trigger_range_u = 4.0
			return s2
		[3, V_JALONS]:
			var s3 := _spell(V_JALONS, "Jalons", 3, JALONS_COEF, JALONS_CD, &"arpenteuse_chain")
			s3.range_u = JALONS_A_RANGE_U
			s3.duration = JALONS_LIFE_S
			s3.proc_coef = JALONS_PROC
			s3.hit_force = _force_for(JALONS_KNOCK_U)
			s3.target_mode = &"densest"
			s3.trigger_range_u = JALONS_A_RANGE_U
			return s3
		[4, V_CERCEAU]:
			var s4 := _spell(V_CERCEAU, "Cerceau", 4, CERCEAU_COEF, CERCEAU_CD, &"arpenteuse_snap")
			s4.range_u = CERCEAU_RADIUS_U
			s4.radius_u = CERCEAU_RADIUS_U
			s4.duration = CERCEAU_LIFE_S
			s4.proc_coef = CERCEAU_PROC
			s4.hit_force = _force_for(CERCEAU_KNOCK_U)
			s4.trigger_range_u = 4.0
			return s4
	return null


# --- Mise en place ------------------------------------------------------------------------------

func setup(p: CharacterBody2D) -> void:
	player = p
	_lestee = _spell_id(1) == V_LESTEE
	_visual = p.get_node_or_null(^"Visual") as AnimatedSprite2D
	fx_root = Node2D.new()
	fx_root.name = "ArpenteuseFX"
	fx_root.top_level = true
	fx_root.z_index = -1 # au sol : sous les personnages, comme les télégraphes
	p.add_child(fx_root)
	line = ArpenteuseChainLine.new()
	line.name = "Chain"
	fx_root.add_child(line)
	line.setup(CHAIN_VIS_WIDTH_U * Balance.UNIT_PX, ACCENT)
	var g := Gradient.new() # chaleur : la queue refroidit, la tête est chauffée à blanc
	g.set_color(0, Color(0.5, 0.42, 0.4))
	g.set_color(1, Color(1, 1, 1))
	line.glow.gradient = g
	peg_line = ArpenteuseChainLine.new()
	peg_line.name = "PegLine"
	fx_root.add_child(peg_line)
	peg_line.setup(CHAIN_VIS_WIDTH_U * Balance.UNIT_PX, ACCENT)
	peg_line.visible = false
	preview = Line2D.new()
	preview.name = "BouclePreview"
	preview.width = PREVIEW_WIDTH_PX
	preview.default_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, PREVIEW_ALPHA)
	preview.z_index = 1
	preview.visible = false
	fx_root.add_child(preview)
	_last_head = p.global_position
	chain = PackedVector2Array([p.global_position])
	Events.floor_started.connect(_on_floor_started)
	Events.player_died.connect(_on_player_died)
	if p.has_signal(&"action_impact"):
		p.action_impact.connect(_on_action_impact)


func _exit_tree() -> void:
	if Events.floor_started.is_connected(_on_floor_started):
		Events.floor_started.disconnect(_on_floor_started)
	if Events.player_died.is_connected(_on_player_died):
		Events.player_died.disconnect(_on_player_died)
	clear_transients()


func _caster() -> SpellCaster:
	return player.spells if player != null else null


func _spell_id(slot: int) -> StringName:
	var sp := _spell_of(slot)
	return sp.id if sp != null else &""


## Paramètres de la chaîne selon le sort 1 (Chaîne lestée : 7 u, plus lourde, plus collante).
func _max_u() -> float:
	return LESTEE_MAX_U if _lestee else CHAIN_MAX_U


func _half_w_u() -> float:
	return LESTEE_HALF_WIDTH_U if _lestee else CHAIN_HALF_WIDTH_U


func _slow_pct() -> float:
	return LESTEE_SLOW_PCT if _lestee else CHAIN_SLOW_PCT


func _reel_u_s() -> float:
	return LESTEE_REEL_U_S if _lestee else CHAIN_REEL_U_S


func _spell_of(slot: int) -> SpellData:
	for s in player.character.spells:
		if s.slot == slot:
			return s
	return null


# --- Hooks du joueur et de SpellCaster ----------------------------------------------------------

## La Chaîne (slot 1) n'est jamais lancée par SpellCaster : c'est la traîne, tenue par ce kit.
## SpellCaster.compute_damage : bonus additif sur élites et boss (sorts 2-4).
func damage_add(s: SpellData, enemy: Node) -> float:
	if s.slot >= 2 and is_instance_valid(enemy) and (enemy.get(&"is_elite") == true or enemy.is_in_group(&"bosses")):
		return BIG_TARGET_ADD
	return 0.0


func blocks_slot(slot: int) -> bool:
	return slot == 1


func can_dodge() -> bool:
	return true


func speed_mult() -> float:
	return 1.0


func inertia_s() -> float:
	return 0.0


func slow_immune() -> bool:
	return false


func locks_facing() -> bool:
	return false


func dodge_ghosts() -> bool:
	return true


func on_dodge_start(_dir: Vector2) -> void:
	pass # la roulade déroule 3 u de chaîne d'un coup : rien de spécial à faire


func on_cast(_s: SpellData) -> void:
	pass


func is_busy() -> bool:
	return snap_left > 0.0 or rewind_left > 0.0 or not _pending.is_empty()


func cast_spell(s: SpellData, aim: Variant) -> bool:
	if player == null or player.dead:
		return false
	match s.slot:
		2:
			if is_busy() or chain_length() < BOUCLE_MIN_U * Balance.UNIT_PX:
				return false
			_pending[&"loop"] = {"spell": s, "aim": aim, "t": 0.0}
			return true
		3:
			if _pending.has(&"plant"):
				return false
			_pending[&"plant"] = {"spell": s, "aim": aim, "t": 0.0}
			return true
		4:
			if is_busy() or (chain_length() < TENDEUR_MIN_U * Balance.UNIT_PX and peg_left <= 0.0):
				return false
			_pending[&"whip"] = {"spell": s, "aim": aim, "t": 0.0}
			return true
	return false


## Anim d'action de chaque sort (Player.action_base_for) : Boucle = loop, Piquet = plant, Tendeur = whip.
func action_for(s: SpellData) -> StringName:
	match s.slot:
		2:
			return &"loop"
		3:
			return &"plant"
		4:
			return &"whip"
	return &""


func _on_action_impact(base: StringName) -> void:
	if _pending.has(base):
		var pend: Dictionary = _pending[base]
		_pending.erase(base)
		if player != null and not player.dead:
			_fire(base, pend)


func _fire(base: StringName, pend: Dictionary) -> void:
	match base:
		&"loop":
			_do_boucle(pend["spell"])
		&"plant":
			_do_piquet(pend["spell"], pend["aim"])
		&"whip":
			_do_tendeur(pend["spell"])


## Sorts lancés dont la frame d'impact n'est pas encore passée (tests).
func has_pending() -> bool:
	return not _pending.is_empty()


func visual_anim(fallback: StringName) -> StringName:
	return fallback


## Ressource (contrat KitResource) : longueur de chaîne / CHAIN_MAX_U ; repère = minimum de la Boucle.
func resource_state() -> Dictionary:
	var u := chain_length() / Balance.UNIT_PX
	var min_u := NOEUD_MIN_U if _spell_id(2) == V_NOEUD else BOUCLE_MIN_U
	return KitResource.make(&"chain", "Chaîne", u / _max_u(), ACCENT,
		{"text": ("%.1f u" % u).replace(".", ","), "mark": min_u / _max_u()})


# --- Géométrie de la chaîne ----------------------------------------------------------------------

## Polyligne complète, de la queue à elle (tête = position du joueur).
func chain_points() -> PackedVector2Array:
	var pts := chain.duplicate()
	if player != null and (pts.is_empty() or pts[pts.size() - 1].distance_squared_to(player.global_position) > 0.01):
		pts.append(player.global_position)
	return pts


func chain_length() -> float:
	var pts := chain_points()
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i - 1].distance_to(pts[i])
	return l


func _cut_chain() -> void:
	chain = PackedVector2Array([player.global_position]) if player != null else PackedVector2Array()
	_tail_s = 0.0
	_m = 0.0


## Raccourcit la chaîne de `x` px par la queue (point interpolé). Retourne la longueur retirée.
## Correctif 23/10 (retour joueur « la chaîne ne se bloque pas au sol ») : l'ancienne version retirait aussi le
## dernier point posé quand il coïncidait avec la tête (cas de chaque pose à pleine longueur) : les points
## proches d'elle disparaissaient et le dernier segment s'allongeait d'une corde, d'où des angles faux.
func _trim_tail(x: float) -> float:
	var removed := 0.0
	var head := player.global_position
	while x > 0.0 and not chain.is_empty():
		var nxt: Vector2 = chain[1] if chain.size() >= 2 else head
		var d := chain[0].distance_to(nxt)
		if d <= x:
			x -= d
			removed += d
			chain.remove_at(0)
			if chain.is_empty():
				chain.append(head) # plus rien derrière : la chaîne repart de sa position
				break
		else:
			chain[0] = chain[0].lerp(nxt, x / d)
			removed += x
			x = 0.0
	_tail_s = fposmod(_tail_s + removed, _tile_px())
	return removed


## Longueur d'une tuile de maillons au sol (cellule 128×64 sur la largeur de bande).
static func _tile_px() -> float:
	return CHAIN_VIS_WIDTH_U * Balance.UNIT_PX * ArpenteuseChainLine.CELL_ASPECT


func _lay(delta: float) -> void:
	var head := player.global_position
	var moved := head.distance_to(_last_head)
	if chain.is_empty() or moved > CHAIN_JUMP_U * Balance.UNIT_PX:
		_cut_chain() # téléportation, début d'étage : jamais de segment géant
	_last_head = head
	_idle_t = 0.0 if moved > 0.5 else _idle_t + delta
	# pose régulière : un point tous les CHAIN_STEP_U le long du trajet (même après un trou de frame), jamais de corde
	var step := CHAIN_STEP_U * Balance.UNIT_PX
	var last: Vector2 = chain[chain.size() - 1]
	var gap := head.distance_to(last)
	if gap >= step:
		var n := int(gap / step)
		for k in range(1, n + 1):
			chain.append(last.lerp(head, float(k) * step / gap))
	var over := chain_length() - _max_u() * Balance.UNIT_PX
	if over > 0.0:
		_trim_tail(over)
	if _idle_t > CHAIN_IDLE_S and chain_length() > 0.5:
		_m = fposmod(_m + _trim_tail(_reel_u_s() * Balance.UNIT_PX * delta), _tile_px()) # le touret rembobine : les maillons glissent vers elle


## Distance de `p` à la polyligne (px), +INF si moins de 2 points.
static func dist_to_polyline(p: Vector2, pts: PackedVector2Array) -> float:
	var best := INF
	for i in range(1, pts.size()):
		var c := Geometry2D.get_closest_point_to_segment(p, pts[i - 1], pts[i])
		best = minf(best, p.distance_to(c))
	return best


static func _bounds(pts: PackedVector2Array, grow: float) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		r = r.expand(q)
	return r.grow(grow)


static func _radius_of(e: Node) -> float:
	return float(e.get(&"radius_px")) if &"radius_px" in e else 0.0


## Ennemis touchant la polyligne (dans `reach` px + leur rayon).
func _enemies_on(pts: PackedVector2Array, reach: float) -> Array:
	var out: Array = []
	if pts.size() < 2:
		return out
	var box := _bounds(pts, reach + Balance.UNIT_PX)
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"take_damage"):
			continue
		var pos: Vector2 = e.global_position
		if not box.has_point(pos):
			continue
		if dist_to_polyline(pos, pts) <= reach + _radius_of(e):
			out.append(e)
	return out


# --- Boucle (appelée par Player.tick, avant les sorts) -------------------------------------------

func tick(delta: float) -> void:
	if player == null or player.dead:
		return
	_time += delta
	for b in _pending.keys(): # jamais d'effet perdu : impact manqué (anim coupée) -> effet au bout du délai
		_pending[b]["t"] = float(_pending[b]["t"]) + delta
		if float(_pending[b]["t"]) >= PENDING_TIMEOUT_S:
			var pend: Dictionary = _pending[b]
			_pending.erase(b)
			_fire(b, pend)
	if snap_left > 0.0:
		snap_left = maxf(snap_left - delta, 0.0)
		_last_head = player.global_position
		if snap_left <= 0.0:
			_start_rewind()
	elif rewind_left > 0.0:
		rewind_left = maxf(rewind_left - delta, 0.0)
		_m = fposmod(_m + _trim_tail(_rewind_speed * delta), _tile_px())
		_last_head = player.global_position
		if rewind_left <= 0.0:
			_cut_chain()
			line.set_sheet(&"tile")
	else:
		_lay(delta)
		_tick_t += delta
		var s1 := _spell_of(1)
		var interval := Balance.attack_interval(s1.base_cooldown if s1 != null else CHAIN_TICK_S, player.stat(&"attack_speed"))
		if _tick_t >= interval:
			_tick_t = 0.0
			_chain_tick(s1)
	_heat_t = maxf(_heat_t - delta, 0.0)
	if peg_left > 0.0:
		_peg_step(delta)
	_update_visuals(delta)


## Sort 1 : tout monstre qui touche la chaîne prend CHAIN_COEF et ralentit.
func _chain_tick(s: SpellData) -> int:
	if s == null or _caster() == null:
		return 0
	var hit := 0
	for e in _enemies_on(chain_points(), _half_w_u() * Balance.UNIT_PX):
		_caster().deal_damage(e, s, {})
		if is_instance_valid(e) and e.has_method(&"apply_status"):
			e.apply_status(&"slow", {"pct": _slow_pct(), "duration": CHAIN_SLOW_S})
		hit += 1
	if hit > 0:
		chain_hits += hit
		_heat_t = HEAT_FLASH_S
	return hit


# --- Sort 2 : Boucle --------------------------------------------------------------------------------

static func polygon_centroid(poly: PackedVector2Array) -> Vector2:
	var a := 0.0
	var c := Vector2.ZERO
	for i in poly.size():
		var p0 := poly[i]
		var p1 := poly[(i + 1) % poly.size()]
		var cr := p0.cross(p1)
		a += cr
		c += (p0 + p1) * cr
	if absf(a) < 1.0:
		var avg := Vector2.ZERO
		for p in poly:
			avg += p
		return avg / maxf(poly.size(), 1)
	return c / (3.0 * a)


static func polygon_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(a) * 0.5


func _do_boucle(s: SpellData) -> void:
	var pts := chain_points()
	if pts.size() < 2:
		return
	var closed := pts.duplicate()
	closed.append(pts[0]) # trait droit d'elle à la queue
	var center := polygon_centroid(pts)
	var reach := BOUCLE_EDGE_U * Balance.UNIT_PX
	var box := _bounds(closed, reach + Balance.UNIT_PX)
	var hits := 0
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"take_damage"):
			continue
		var pos: Vector2 = e.global_position
		if not box.has_point(pos):
			continue
		var inside := pts.size() >= 3 and Geometry2D.is_point_in_polygon(pos, pts)
		if not inside and dist_to_polyline(pos, closed) > reach + _radius_of(e):
			continue
		_caster().deal_damage(e, s, {})
		hits += 1
		if is_instance_valid(e) and e.has_method(&"push") and not e.is_in_group(&"bosses"):
			e.push((center - pos).limit_length(BOUCLE_PULL_U * Balance.UNIT_PX))
	var area := polygon_area(pts)
	last_loop = {"hits": hits, "area_px": area, "center": center}
	var r := maxf(sqrt(area / PI), 0.6 * Balance.UNIT_PX)
	_spawn_blaze(center, r)
	_spawn_flare(closed)
	LightRig.flash(center, s.light_preset, 0.6, {"radius": clampf(r / (2.2 * Balance.UNIT_PX), 0.6, 1.6)})
	_cut_chain() # la chaîne est consommée : elle repousse en marchant


func _spawn_blaze(center: Vector2, r: float) -> void:
	if not ResourceLoader.exists(LOOP_BLAZE_FRAMES):
		return
	var frames := load(LOOP_BLAZE_FRAMES) as SpriteFrames
	if frames == null or not frames.has_animation(&"default"):
		return
	var fx := AnimatedSprite2D.new()
	fx.name = "LoopBlaze"
	fx_root.add_child(fx)
	fx.global_position = center
	EmissiveOverlay.apply(fx, frames, 2.6)
	var k := r / LOOP_BLAZE_RADIUS_PX # rig TOP, aspect 1 : posé au sol, la caméra écrase
	fx.scale = Vector2(k, k)
	fx.sprite_frames.set_animation_loop(&"default", false)
	fx.play(&"default")
	fx.animation_finished.connect(fx.queue_free)


## Contour embrasé : la chaîne fermée flambe (planche chain_snap) puis s'éteint.
func _spawn_flare(closed: PackedVector2Array) -> void:
	var fl := ArpenteuseChainLine.new()
	fl.name = "LoopFlare"
	fx_root.add_child(fl)
	fl.setup(CHAIN_VIS_WIDTH_U * Balance.UNIT_PX, ACCENT)
	fl.set_sheet(&"snap")
	fl.u_offset = line.u_offset
	fl.energy = HEAT_FLASH_ENERGY * 1.3
	fl.set_line(closed)
	var tw := fl.create_tween()
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(fl):
			fl.advance(1.0 / 60.0)
			fl.modulate.a = 1.0 - t, 0.0, 1.0, BOUCLE_FLARE_S)
	tw.tween_callback(fl.queue_free)


# --- Sort 3 : Piquet --------------------------------------------------------------------------------

func _do_piquet(s: SpellData, aim: Variant) -> void:
	var origin := player.global_position
	var target: Vector2
	if aim != null and ((aim as Vector2) - origin).length_squared() > 1.0:
		target = origin + ((aim as Vector2) - origin).limit_length(PIQUET_RANGE_U * Balance.UNIT_PX * (1.0 + player.stat(&"range_add")))
	else:
		var f: Vector2 = player.facing if player.facing != Vector2.ZERO else Vector2.DOWN
		target = origin + f.normalized() * PIQUET_DEFAULT_U * Balance.UNIT_PX
	if player.is_inside_tree(): # jamais dans un mur
		var q := PhysicsRayQueryParameters2D.create(origin, target, WALL_MASK, [player.get_rid()])
		var res := player.get_world_2d().direct_space_state.intersect_ray(q)
		if not res.is_empty():
			var hp: Vector2 = res["position"]
			target = hp - (hp - origin).normalized() * PEG_WALL_BACK_U * Balance.UNIT_PX
	_end_peg(false)
	peg_pos = target
	peg_left = s.duration if s.duration > 0.0 else PEG_LIFE_S
	_peg_hits.clear()
	_spawn_peg_visual()
	peg_line.visible = true
	LightRig.flash(peg_pos, &"arpenteuse_snap", 0.25, {"energy": 0.6})


func peg_active() -> bool:
	return peg_left > 0.0


func peg_segment() -> PackedVector2Array:
	return PackedVector2Array([peg_pos, player.global_position]) if peg_left > 0.0 else PackedVector2Array()


func _peg_step(delta: float) -> void:
	peg_left = maxf(peg_left - delta, 0.0)
	if peg_left <= 0.0:
		_end_peg(false)
		return
	if peg_pos.distance_to(player.global_position) > PEG_SNAP_U * Balance.UNIT_PX:
		_end_peg(true) # arraché
		return
	var s := _spell_of(3)
	if s == null or _caster() == null:
		return
	for e in _enemies_on(peg_segment(), CHAIN_HALF_WIDTH_U * Balance.UNIT_PX):
		var id: int = e.get_instance_id()
		if _time - float(_peg_hits.get(id, -INF)) < PEG_IMMUNITY_S:
			continue
		_peg_hits[id] = _time
		var c := Geometry2D.get_closest_point_to_segment(e.global_position, peg_pos, player.global_position)
		_caster().deal_damage(e, s, {"source_pos": c}) # balayé : écarté de la ligne
		_heat_t = HEAT_FLASH_S


func _spawn_peg_visual() -> void:
	_peg_node = Node2D.new()
	_peg_node.name = "Peg"
	fx_root.add_child(_peg_node)
	_peg_node.z_index = 1 # debout : remonte au niveau des personnages (fx_root est au sol)
	_peg_node.global_position = peg_pos
	if not ResourceLoader.exists(PEG_FRAMES):
		return
	var holder := Node2D.new()
	holder.scale = Iso.UNSQUASH * Iso.SPRITE_K # billboard CREA
	_peg_node.add_child(holder)
	_peg_sprite = AnimatedSprite2D.new()
	_peg_sprite.offset = PEG_OFFSET
	holder.add_child(_peg_sprite)
	EmissiveOverlay.apply(_peg_sprite, load(PEG_FRAMES) as SpriteFrames, 2.0)
	_orient_peg()


func _orient_peg() -> void:
	if _peg_sprite == null or _peg_sprite.sprite_frames == null:
		return
	var d := player.global_position - peg_pos
	var i := roundi(d.angle() / (TAU / 8.0)) % 8 if d.length_squared() > 1.0 else 2
	var a := StringName("peg_" + DIR_NAMES[(i + 8) % 8])
	if _peg_sprite.sprite_frames.has_animation(a) and _peg_sprite.animation != a:
		_peg_sprite.play(a)


func _end_peg(snapped: bool) -> void:
	if snapped and peg_left > 0.0:
		LightRig.flash(peg_pos, &"arpenteuse_snap", 0.2, {"energy": 0.5})
	peg_left = 0.0
	_peg_hits.clear()
	if _peg_node != null and is_instance_valid(_peg_node):
		_peg_node.queue_free()
	_peg_node = null
	_peg_sprite = null
	if peg_line != null:
		peg_line.visible = false
		peg_line.set_line(PackedVector2Array())


# --- Sort 4 : Tendeur -------------------------------------------------------------------------------

func _do_tendeur(s: SpellData) -> void:
	var pts := chain_points()
	var peg := peg_segment()
	var reach: float = TENDEUR_REACH_U * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))
	var targets: Array = _enemies_on(pts, reach)
	for e in _enemies_on(peg, reach):
		if not targets.has(e):
			targets.append(e)
	_dragged.clear()
	for e in targets:
		_caster().deal_damage(e, s, {})
		if is_instance_valid(e) and e.is_in_group(&"enemies") and not e.is_in_group(&"bosses"):
			_dragged.append(e)
	last_tendeur = {"hits": targets.size(), "dragged": _dragged.size()}
	# éclats de lumière le long de la chaîne qui claque
	var all := pts.duplicate()
	all.append_array(peg)
	for k in 3:
		if all.size() >= 2:
			LightRig.flash(all[int(float(all.size() - 1) * (k + 0.5) / 3.0)], s.light_preset, 0.35, {"energy": 0.8})
	snap_left = SNAP_S
	line.set_sheet(&"snap")
	if peg_left > 0.0: # la ligne du piquet claque avec la chaîne
		peg_line.set_sheet(&"snap")


func _start_rewind() -> void:
	var l := chain_length()
	rewind_left = REWIND_S
	_rewind_speed = l / REWIND_S
	line.set_sheet(&"rewind")
	var head := player.global_position
	for e in _dragged: # traînés jusqu'à elle, puis étourdis
		if not is_instance_valid(e) or not e.is_in_group(&"enemies"):
			continue
		var v: Vector2 = head - e.global_position
		var keep := TENDEUR_KEEP_U * Balance.UNIT_PX
		if e.has_method(&"push") and v.length() > keep:
			e.push(v - v.normalized() * keep)
		if e.has_method(&"apply_status"):
			e.apply_status(&"imprisoned", {"duration": TENDEUR_STUN_S})
	_dragged.clear()
	if peg_left > 0.0:
		peg_line.set_sheet(&"tile")
		_end_peg(true) # le piquet est arraché par le rembobinage


func is_rewinding() -> bool:
	return snap_left > 0.0 or rewind_left > 0.0


# --- Nettoyage (étage, mort) ------------------------------------------------------------------------

func clear_transients() -> void:
	_pending.clear()
	if preview != null:
		preview.visible = false
	_dragged.clear()
	snap_left = 0.0
	rewind_left = 0.0
	_end_peg(false)
	if player != null:
		_cut_chain()
	if line != null:
		line.set_sheet(&"tile")
		line.set_line(PackedVector2Array())
	for h in _lights:
		LightRig.detach(h)
	_lights.clear()


func _on_floor_started(_n: int) -> void:
	clear_transients()
	if player != null:
		_last_head = player.global_position


func _on_player_died() -> void:
	clear_transients()
	if _visual != null and _visual.sprite_frames != null:
		var anim := StringName("death_" + _dir_name())
		if _visual.sprite_frames.has_animation(anim):
			_visual.sprite_frames.set_animation_loop(anim, false)
			_visual.play(anim)


# --- Rendu ----------------------------------------------------------------------------------------

func _dir_name() -> String:
	var i := roundi(player.facing.angle() / (TAU / 8.0)) % 8
	return DIR_NAMES[(i + 8) % 8]


func _update_visuals(delta: float) -> void:
	if line == null:
		return
	var pts := chain_points()
	var tile_px := CHAIN_VIS_WIDTH_U * Balance.UNIT_PX * ArpenteuseChainLine.CELL_ASPECT
	line.u_offset = fposmod((_tail_s - _m) / tile_px, 1.0)
	line.energy = lerpf(HEAT_ENERGY, HEAT_FLASH_ENERGY, _heat_t / HEAT_FLASH_S)
	if snap_left > 0.0:
		line.energy = HEAT_FLASH_ENERGY * 1.4
	line.set_line(smooth_polyline(pts))
	line.advance(delta)
	_update_preview(pts)
	if peg_left > 0.0:
		var seg := peg_segment()
		peg_line.u_offset = 0.0
		peg_line.energy = HEAT_ENERGY * 1.4 if snap_left <= 0.0 else HEAT_FLASH_ENERGY * 1.4 # tendue = plus chaude
		peg_line.set_line(seg)
		peg_line.advance(delta)
		_orient_peg()
	_update_lights(pts)


## Lissage de rendu (Chaikin, un passage) : les angles du trajet s'arrondissent, extrémités conservées.
## Les dégâts restent calculés sur la polyligne posée.
static func smooth_polyline(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array()
	out.append(pts[0])
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		if i > 0:
			out.append(a.lerp(b, 0.25))
		if i < pts.size() - 2:
			out.append(a.lerp(b, 0.75))
	out.append(pts[pts.size() - 1])
	return out


## Aide à la prise en main : le trait droit qui fermera la Boucle (queue -> elle) s'affiche quand elle est prête.
func _update_preview(pts: PackedVector2Array) -> void:
	if preview == null:
		return
	var show := false
	var c := _caster()
	var s2 := _spell_of(2)
	if c != null and s2 != null and s2.id == &"arpenteuse_boucle" and pts.size() >= 2 and not is_busy() 			and c.cooldown_remaining(2) <= 0.0 and chain_length() >= BOUCLE_MIN_U * Balance.UNIT_PX:
		show = true
	preview.visible = show
	if show:
		preview.points = PackedVector2Array([pts[0], pts[pts.size() - 1]])


## Deux lueurs cuivre le long de la chaîne (au tiers et aux deux tiers), énergie selon la longueur.
func _update_lights(pts: PackedVector2Array) -> void:
	var l := chain_length()
	if l < Balance.UNIT_PX:
		for h in _lights:
			LightRig.detach(h)
		_lights.clear()
		return
	while _lights.size() < CHAIN_LIGHTS:
		_lights.append(LightRig.attach_at(player.global_position, &"arpenteuse_chain"))
	for k in _lights.size():
		var h: LightRig.Handle = _lights[k]
		h.position = _point_at(pts, l * float(k + 1) / float(CHAIN_LIGHTS + 1))
		h.set_energy(clampf(l / (_max_u() * Balance.UNIT_PX), 0.3, 1.0) * (1.6 if _heat_t > 0.0 else 1.0))


static func _point_at(pts: PackedVector2Array, s: float) -> Vector2:
	for i in range(1, pts.size()):
		var d := pts[i - 1].distance_to(pts[i])
		if s <= d and d > 0.0:
			return pts[i - 1].lerp(pts[i], s / d)
		s -= d
	return pts[pts.size() - 1]
