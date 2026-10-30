class_name ArpenteuseKit
extends Node
## Kit de l'Arpenteuse, géomètre de la Cité (docs/Design_Personnages.md §2.2 ; kit complété le 22/10/2026
## dans l'esprit de la fiche et de Rictus §2.6, voir le rapport d'intégration). 4 sorts / 0 passif.
## Ressource = la chaîne au sol : les CHAIN_MAX_U derniers u de son trajet. Elle ne blesse que ce qu'elle a parcouru.
## - Sort 1 Chaîne (auto) : la traîne elle-même ; tick de zone-ligne (cadence = vitesse d'attaque), ralentit.
##   Immobile : le touret rembobine la chaîne (CHAIN_IDLE_S puis CHAIN_REEL_U_S) : rester sur place = ne rien faire.
## - Sort 2 Boucle (24/10 : « Halage », zone le long de TOUTE la chaîne) : bande de BOUCLE_BAND_U autour de la
##   chaîne posée, frappe et attire vers la chaîne. Rien n'est consommé. Exige BOUCLE_MIN_U de chaîne.
## - Sort 3 Piquet : piquet planté au point visé (6 u) ; ligne tendue piquet -> elle 5 s qui balaie
##   (immunité par monstre) ; arrachée au-delà de PEG_SNAP_U.
## - Sort 4 Tendeur : la chaîne (et la ligne du piquet) claque, traîne les monstres touchés jusqu'à elle,
##   emprisonnés 1,5 s (statut `imprisoned`). Chaîne et piquet restent posés (24/10 : plus de rembobinage).
## Combo : Boucle (attire) -> Chaîne (brûle) -> Piquet (balaie la ligne tendue).
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
const HAND_H_U := 0.45 ## hauteur de la main : la tête de la chaîne y est accrochée (rendu seulement)
const HAND_RAMP_U := 1.0 ## la chaîne monte du sol à la main sur ce dernier tronçon
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
## Trait tendu (esquive, docs/Design_Esquives.md §Arpenteuse) : après la roulade, la chaîne reste tendue TAUT_S :
## ralentissement TAUT_SLOW_PCT sur toute la chaîne, sans dégât de plus.
const TAUT_S := 1.5
const TAUT_SLOW_PCT := 0.5
const DODGE_SOUND := [&"spell.arpenteuse_tendeur.cast_light", -6.0, 1.2]
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
const BOUCLE_PULL_U := 1.5 ## attraction vers la chaîne
const BOUCLE_BAND_U := 1.2 ## demi-largeur de la bande de la Boucle (24/10 : zone le long de TOUTE la chaîne, plus de fermeture)
const BOUCLE_FLARE_S := 0.45 ## contour embrasé
const BOUCLE_EDGE_U := 0.5 ## aide 23/10 : tolérance du contour (trait de fermeture compris) 0,25 -> 0,5 u, une boucle ratée de justesse touche quand même
# --- Piquet (sort 3) -------------------------------------------------------------------------------
const PIQUET_COEF := 1.0
const PIQUET_CD := 8.0
const PIQUET_RANGE_U := 6.0
const PIQUET_DEFAULT_U := 3.0 ## sans visée ni cible : devant elle
const PEG_LIFE_S := 5.0
const PEG_IMMUNITY_S := 0.7 ## 29/10/2026 : 0,65 -> 0,7 (décision du joueur, élite 1,37 -> cible 1,30, docs/Design_Combos.md §7.3) ; ≈ 1,4 coef/s par cible
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
## Frames d'impact (index 0) des anims d'action d'AR1 (planches vérifiées : geste au sol / bras tendu).
const ACTION_IMPACT_FRAMES := {&"plant": 2, &"loop": 2, &"whip": 4, &"attack": 3, &"cast": 2, &"cast_ult": 3}
const PENDING_TIMEOUT_S := 1.0
const WALL_MASK := 1
## Équilibrage 22/10/2026 : boucler une cible mobile est rare (cible unique −44 % vs Ardent au simulateur).
## La géomètre « mesure les grands » : +BIG_TARGET_ADD (additif) sur élites et boss pour Boucle, Piquet, Tendeur.
const BIG_TARGET_ADD := 0.25 ## équilibrage 26/10 : 0,4 -> 0,25 (cible élite 1,30)
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
const CERCEAU_COEF := 1.15 ## équilibrage 26/10 : 1,25 -> 1,15 (simulateur : ×1,09 de la Tendeur, ×1,2 à bas niveau)
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
## Combos (docs/Design_Combos.md §2, 29/10/2026) : la chaîne et ses lignes sont l'état ; le Halage lit les emprisonnés (Tendeur
## juste avant) et le segment tendu (Trait juste avant) ; un monstre « croisé » (chaîne ET ligne du piquet) fait rougir la chaîne.
const HALAGE_HELD_ADD := 0.5 ## Tendeur -> Halage : +0,5 coef sur les emprisonnés (plage sûre 0,3-0,7)
const HALAGE_TAUT_ADD := 0.5 ## Trait -> Halage : +0,5 coef sur la bande du segment tendu (plage 0,3-0,6)
const CROSS_FLASH_ENERGY := 6.0
const CROSS_MIN_LINES_HITS := 3 ## combo_ready(Tendeur) : un croisé, ou au moins 3 monstres sur les lignes
const COMBO_PROBE_S := 0.25 ## sondage des fenêtres (jamais une boucle par monstre et par image)
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
var _taut_seg := PackedVector2Array() ## segment du Trait (départ -> arrivée) : la bande tendue du Halage
var _cross_t := 0.0 ## flash « croisé » restant
var _probe_combo_t := -10.0
var _ready2 := false
var _ready4 := false
var taut_left := 0.0 ## Trait tendu : chaîne tendue après la roulade (ralentissement TAUT_SLOW_PCT)
var jal_stage := 0 ## Jalons : 0 rien, 1 piquet A lancé (fenêtre de 3 s pour B), 2 piquet B lancé
var jal_a := Vector2.ZERO
var jal_b := Vector2.ZERO
var jal_line := false ## la ligne A-B est tendue
var _jal_t := 0.0
var _jal_dir := Vector2.DOWN
var jal_left := 0.0 ## Jalons : ligne A-B tendue (s restantes)
var _jal_hits := {}
var _jal_a_node: Node2D = null
var _jal_b_node: Node2D = null
var _jal_a_sprite: AnimatedSprite2D = null
var _jal_b_sprite: AnimatedSprite2D = null
var knot_left := 0.0 ## Nœud : resserrement en cours (s restantes)
var _knot_pos := Vector2.ZERO
var _knot_spell: SpellData = null
var ring_left := 0.0 ## Cerceau en cours (s restantes)
var _ring_outline: ZoneOutline = null ## contour de la bande du Cerceau
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

	var s2 := _spell(&"arpenteuse_boucle", "Halage", 2, BOUCLE_COEF, BOUCLE_CD, &"arpenteuse_blaze")
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
	var base := LESTEE_SLOW_PCT if _lestee else CHAIN_SLOW_PCT
	return maxf(base, TAUT_SLOW_PCT) if taut_left > 0.0 else base


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


# --- Combos (docs/Design_Combos.md §2) ----------------------------------------------------------------

## Halage de base (sort 2 hors Nœud) : bonus de coef sur les emprisonnés (AR-2) et sur la bande du segment tendu (AR-3).
func _halage_bonus(s: SpellData, enemy: Node) -> float:
	if s.slot != 2 or _spell_id(2) == V_NOEUD or not is_instance_valid(enemy):
		return 0.0
	var add := 0.0
	if enemy.has_method(&"is_imprisoned") and enemy.is_imprisoned():
		add += HALAGE_HELD_ADD
	if taut_left > 0.0 and _taut_seg.size() >= 2 and enemy is Node2D \
			and dist_to_polyline((enemy as Node2D).global_position, _taut_seg) <= BOUCLE_BAND_U * Balance.UNIT_PX + _radius_of(enemy):
		add += HALAGE_TAUT_ADD
	return add


## SpellCaster.compute_damage : coef additif de combo.
func combo_coef_add(s: SpellData, enemy: Node) -> float:
	return _halage_bonus(s, enemy)


## SpellCaster.deal_damage : coup de combo (chiffre en accent, son lourd) = Halage préparé, ou Tendeur / Piquet sur un croisé.
func combo_hit(s: SpellData, enemy: Node) -> bool:
	if s.slot == 2:
		return _halage_bonus(s, enemy) > 0.0
	if s.slot == 4 or s.slot == 3:
		return is_instance_valid(enemy) and enemy is Node2D and _is_crossed(enemy as Node2D)
	return false


## Monstre touché par la chaîne ET par une ligne (piquet, Jalons) : la double chaîne.
func _is_crossed(e: Node2D) -> bool:
	var reach := CHAIN_HALF_WIDTH_U * Balance.UNIT_PX + _radius_of(e)
	var on_chain := dist_to_polyline(e.global_position, chain_points()) <= reach
	if not on_chain:
		return false
	for seg in [peg_segment(), jal_segment()]:
		if seg.size() >= 2 and dist_to_polyline(e.global_position, seg) <= reach:
			return true
	return false


## Fenêtre de combo du slot (HUD : le bouton pulse). Halage : un Tendeur vient d'emprisonner ou le Trait tend la chaîne ;
## Tendeur : un croisé ou >= 3 monstres sur les lignes. Sondé toutes les COMBO_PROBE_S.
func combo_ready(slot: int) -> bool:
	if player == null or not is_inside_tree():
		return false
	if _time - _probe_combo_t >= COMBO_PROBE_S:
		_probe_combo_t = _time
		_ready2 = taut_left > 0.0
		_ready4 = false
		var lines := _lines()
		var on := _enemies_on_lines(lines, CHAIN_HALF_WIDTH_U * Balance.UNIT_PX)
		for e in on:
			if not _ready2 and e.has_method(&"is_imprisoned") and e.is_imprisoned():
				_ready2 = true
			if not _ready4 and _is_crossed(e):
				_ready4 = true
		_ready4 = _ready4 or on.size() >= CROSS_MIN_LINES_HITS
	return _ready2 if slot == 2 else (_ready4 if slot == 4 else false)


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


## Trait tendu : la chaîne posée par la roulade reste tendue TAUT_S (ralentissement TAUT_SLOW_PCT au lieu de
## CHAIN_SLOW_PCT, sans dégât de plus).
func on_dodge_end(from: Vector2, to: Vector2) -> void:
	taut_left = TAUT_S
	_taut_seg = PackedVector2Array([from, to])


func dodge_label() -> String:
	return "Trait"


func dodge_sound() -> Array:
	return DODGE_SOUND


func on_cast(_s: SpellData) -> void:
	pass


func is_busy() -> bool:
	return snap_left > 0.0 or not _pending.is_empty()


func cast_spell(s: SpellData, aim: Variant) -> bool:
	if player == null or player.dead:
		return false
	match s.slot:
		2:
			var have := chain_length() if s.id == V_NOEUD else lines_length() # le Nœud noue la traîne ; le Halage frappe toute chaîne posée
			var min_u := NOEUD_MIN_U if s.id == V_NOEUD else BOUCLE_MIN_U
			if is_busy() or ring_left > 0.0 or knot_left > 0.0 or have < min_u * Balance.UNIT_PX:
				return false
			_pending[&"loop"] = {"spell": s, "aim": aim, "t": 0.0}
			return true
		3:
			if _pending.has(&"plant"):
				return false
			if s.id == V_JALONS:
				return _cast_jalon(s, aim)
			_pending[&"plant"] = {"spell": s, "aim": aim, "t": 0.0}
			return true
		4:
			if is_busy() or ring_left > 0.0:
				return false
			var min_u4 := CERCEAU_MIN_U if s.id == V_CERCEAU else TENDEUR_MIN_U
			if chain_length() < min_u4 * Balance.UNIT_PX and peg_left <= 0.0 and not jal_line:
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
			if (pend["spell"] as SpellData).id == V_NOEUD:
				_do_noeud(pend["spell"])
			else:
				_do_boucle(pend["spell"])
		&"plant":
			if (pend["spell"] as SpellData).id == V_JALONS:
				_do_jalon(pend["spell"], pend["aim"], int(pend.get("which", 1)))
			else:
				_do_piquet(pend["spell"], pend["aim"])
		&"whip":
			if (pend["spell"] as SpellData).id == V_CERCEAU:
				_do_cerceau(pend["spell"])
			else:
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
	if _idle_t > CHAIN_IDLE_S and chain_length() > 0.5 and ring_left <= 0.0:
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
	taut_left = maxf(taut_left - delta, 0.0)
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
			_drag_and_stun()
			line.set_sheet(&"tile")
			peg_line.set_sheet(&"tile")
	else:
		_lay(delta)
		_tick_t += delta
		var s1 := _spell_of(1)
		var interval := Balance.attack_interval(s1.base_cooldown if s1 != null else CHAIN_TICK_S, player.stat(&"attack_speed"))
		if _tick_t >= interval:
			_tick_t = 0.0
			if ring_left <= 0.0: # Cerceau : la chaîne a quitté le sol, l'anneau tient lieu de sort 1
				_chain_tick(s1)
	_heat_t = maxf(_heat_t - delta, 0.0)
	_cross_t = maxf(_cross_t - delta, 0.0)
	if peg_left > 0.0:
		_peg_step(delta)
	_jalons_step(delta)
	if knot_left > 0.0:
		_knot_step(delta)
	if ring_left > 0.0:
		_ring_step(delta)
	_update_visuals(delta)


## Sort 1 : tout monstre qui touche la chaîne prend CHAIN_COEF et ralentit.
func _chain_tick(s: SpellData) -> int:
	if s == null or _caster() == null:
		return 0
	var hit := 0
	var lines_other := peg_left > 0.0 or jal_line
	for e in _enemies_on(chain_points(), _half_w_u() * Balance.UNIT_PX):
		var crossed := lines_other and e is Node2D and _is_crossed(e as Node2D)
		_caster().deal_damage(e, s, {"combo": true} if crossed else {})
		if crossed:
			_cross_t = HEAT_FLASH_S
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


## Lignes de chaîne posées au sol : la traîne, la ligne du piquet (poteau -> elle) et la ligne A-B des Jalons.
## Le Halage les frappe toutes (correctif 24/10 : avec le poteau planté, la chaîne attachée au poteau compte
## comme chaîne posée ; avant, seule la traîne comptait et le Halage restait refusé une fois la traîne rembobinée).
func _lines() -> Array:
	var out: Array = []
	for pts in [chain_points(), peg_segment(), jal_segment()]:
		if pts.size() >= 2:
			out.append(pts)
	return out


func lines_length() -> float:
	var l := 0.0
	for pts in _lines():
		for i in range(1, pts.size()):
			l += pts[i - 1].distance_to(pts[i])
	return l


## Monstres touchant l'une des lignes posées (sans doublon).
func _enemies_on_lines(lines: Array, reach: float) -> Array:
	var out: Array = []
	for pts in lines:
		for e in _enemies_on(pts, reach):
			if not out.has(e):
				out.append(e)
	return out


static func _closest_on_lines(lines: Array, p: Vector2) -> Vector2:
	var best := p
	var bd := INF
	for pts in lines:
		var c := _closest_on(pts, p)
		var d := p.distance_squared_to(c)
		if d < bd:
			bd = d
			best = c
	return best


func _do_boucle(s: SpellData) -> void:
	var lines := _lines()
	if lines.is_empty():
		return
	var reach := BOUCLE_BAND_U * Balance.UNIT_PX
	var hits := 0
	for e in _enemies_on_lines(lines, reach):
		var pos: Vector2 = e.global_position
		var c := _closest_on_lines(lines, pos)
		_caster().deal_damage(e, s, {})
		hits += 1
		var held: bool = e.has_method(&"is_imprisoned") and e.is_imprisoned() # tenu par le Tendeur : rien à attirer
		if is_instance_valid(e) and e.has_method(&"push") and not e.is_in_group(&"bosses") and not (held and _spell_id(2) != V_NOEUD):
			e.push((c - pos).limit_length(BOUCLE_PULL_U * Balance.UNIT_PX))
	last_loop = {"hits": hits, "length_px": lines_length()}
	RunState.add_counter("arpenteuse.boucle_hits", float(hits)) # déblocage du Nœud
	for pts in lines:
		var smooth: PackedVector2Array = smooth_polyline(pts) if pts == chain_points() else pts
		_spawn_flare(smooth)
		var l := 0.0
		for i in range(1, pts.size()):
			l += pts[i - 1].distance_to(pts[i])
		for k in 3:
			LightRig.flash(_point_at(pts, l * (float(k) + 0.5) / 3.0), s.light_preset, 0.5, {"radius": 0.9})
	# les chaînes restent posées (24/10) : rien n'est consommé


## Point de la polyligne le plus proche de `p`.
static func _closest_on(pts: PackedVector2Array, p: Vector2) -> Vector2:
	var best := pts[0]
	var bd := INF
	for i in range(1, pts.size()):
		var c := Geometry2D.get_closest_point_to_segment(p, pts[i - 1], pts[i])
		var d := p.distance_squared_to(c)
		if d < bd:
			bd = d
			best = c
	return best


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
		var crossed := e is Node2D and dist_to_polyline((e as Node2D).global_position, chain_points()) <= CHAIN_HALF_WIDTH_U * Balance.UNIT_PX + _radius_of(e)
		_caster().deal_damage(e, s, {"source_pos": c, "combo": true} if crossed else {"source_pos": c}) # balayé : écarté de la ligne
		if crossed:
			_cross_t = HEAT_FLASH_S
		RunState.add_counter("arpenteuse.piquet_hits") # déblocage des Jalons
		_heat_t = HEAT_FLASH_S


func _spawn_peg_visual() -> void:
	_peg_node = Node2D.new()
	_peg_node.name = "Peg"
	fx_root.add_child(_peg_node)
	_peg_node.z_index = 1 # debout : remonte au niveau des personnages (fx_root est au sol)
	_peg_node.global_position = peg_pos
	ZoneOutline.attach_capsule(_peg_node, CHAIN_HALF_WIDTH_U * Balance.UNIT_PX, ZoneOutline.color_for(_spell_of(3), _caster()), peg_left, player)
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
	var jseg := jal_segment()
	for e in _enemies_on(jseg, reach): # le Tendeur claque aussi sur la ligne A-B des Jalons
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
	all.append_array(jseg)
	for k in 3:
		if all.size() >= 2:
			LightRig.flash(all[int(float(all.size() - 1) * (k + 0.5) / 3.0)], s.light_preset, 0.35, {"energy": 0.8})
	snap_left = SNAP_S
	line.set_sheet(&"snap")
	if peg_left > 0.0 or jal_line: # la ligne du piquet (ou des Jalons) claque avec la chaîne
		peg_line.set_sheet(&"snap")


## Fin du claquement : les monstres touchés sont traînés jusqu'à elle puis étourdis. La chaîne et le piquet
## restent posés (24/10 : plus de rembobinage).
func _drag_and_stun() -> void:
	var head := player.global_position
	for e in _dragged:
		if not is_instance_valid(e) or not e.is_in_group(&"enemies"):
			continue
		var v: Vector2 = head - e.global_position
		var keep := TENDEUR_KEEP_U * Balance.UNIT_PX
		if e.has_method(&"push") and v.length() > keep:
			e.push(v - v.normalized() * keep)
		if e.has_method(&"apply_status"):
			e.apply_status(&"imprisoned", {"duration": TENDEUR_STUN_S})
	_dragged.clear()


func is_rewinding() -> bool:
	return snap_left > 0.0


# --- Variantes : Nœud (sort 2) ------------------------------------------------------------------------

## Points (tous les 0,25 u) des `len_px` premiers pixels de la polyligne, depuis la queue.
static func _tail_section(pts: PackedVector2Array, len_px: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() < 2:
		return out
	var step := CHAIN_STEP_U * Balance.UNIT_PX
	var s := 0.0
	while s <= len_px:
		out.append(_point_at(pts, s))
		s += step
	return out


static func _mean(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / maxf(pts.size(), 1)


func _knot_reach() -> float:
	return NOEUD_RADIUS_U * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))


## Frame d'impact : les NOEUD_TAIL_U de queue sont consommés et se resserrent sur leur centroïde (NOEUD_SQUEEZE_S).
func _do_noeud(s: SpellData) -> void:
	var tail := _tail_section(chain_points(), NOEUD_TAIL_U * Balance.UNIT_PX)
	if tail.is_empty():
		return
	_knot_pos = _mean(tail)
	_knot_spell = s
	knot_left = NOEUD_SQUEEZE_S
	_trim_tail(NOEUD_TAIL_U * Balance.UNIT_PX)
	_spawn_knot_flare(tail, _knot_pos)


func _knot_step(delta: float) -> void:
	knot_left = maxf(knot_left - delta, 0.0)
	if knot_left > 0.0:
		return
	var s := _knot_spell
	_knot_spell = null
	if s == null or _caster() == null:
		return
	var reach := _knot_reach()
	var hits := 0
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"take_damage"):
			continue
		if (e as Node2D).global_position.distance_to(_knot_pos) > reach + _radius_of(e):
			continue
		_caster().deal_damage(e, s, {"source_pos": _knot_pos})
		hits += 1
		if not is_instance_valid(e):
			continue
		if e.is_in_group(&"bosses"):
			if e.has_method(&"apply_status"):
				e.apply_status(&"slow", {"pct": NOEUD_BOSS_SLOW, "duration": NOEUD_PRISON_S})
		elif e.has_method(&"apply_status"):
			e.apply_status(&"imprisoned", {"duration": NOEUD_PRISON_S})
	last_noeud = {"hits": hits, "center": _knot_pos, "radius_px": reach}
	_heat_t = HEAT_FLASH_S
	LightRig.flash(_knot_pos, s.light_preset, 0.5, {"radius": 0.9})
	_spawn_blaze(_knot_pos, reach)


func _spawn_knot_flare(tail: PackedVector2Array, center: Vector2) -> void:
	var fl := ArpenteuseChainLine.new()
	fl.name = "KnotFlare"
	fx_root.add_child(fl)
	fl.setup(CHAIN_VIS_WIDTH_U * Balance.UNIT_PX, ACCENT)
	fl.set_sheet(&"snap")
	fl.energy = HEAT_FLASH_ENERGY * 1.3
	var tw := fl.create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(fl):
			return
		var q := PackedVector2Array()
		for p in tail:
			q.append(p.lerp(center, t))
		fl.set_line(q)
		fl.advance(1.0 / 60.0), 0.0, 1.0, NOEUD_SQUEEZE_S)
	tw.tween_callback(fl.queue_free)


## Auto-cast du sort 2 (SpellCaster._auto_cast_ok ; jamais consulté en manuel) : attend au moins LOOP_AUTO_MIN_HITS
## monstres pris (1 si élite ou boss), sinon la recharge partirait dans le vide.
func auto_cast_ok(slot: int) -> bool:
	if slot != 2 or player == null or not is_inside_tree():
		return true
	if _time - _probe_t < 0.15:
		return _probe_n >= LOOP_AUTO_MIN_HITS or _probe_n < 0
	_probe_t = _time
	var found: Array = []
	if _spell_id(2) == V_NOEUD:
		var tail := _tail_section(chain_points(), NOEUD_TAIL_U * Balance.UNIT_PX)
		if not tail.is_empty():
			var c := _mean(tail)
			var reach := _knot_reach()
			for e in get_tree().get_nodes_in_group(&"enemies"):
				if e is Node2D and is_instance_valid(e) and (e as Node2D).global_position.distance_to(c) <= reach + _radius_of(e):
					found.append(e)
	else:
		found = _enemies_on_lines(_lines(), BOUCLE_BAND_U * Balance.UNIT_PX)
	var big := false
	for e in found:
		if e.get(&"is_elite") == true or e.is_in_group(&"bosses"):
			big = true
	_probe_n = -1 if big else found.size() # -1 : une cible de poids suffit
	return _probe_n >= LOOP_AUTO_MIN_HITS or _probe_n < 0


# --- Variantes : Jalons (sort 3) ----------------------------------------------------------------------

func jal_segment() -> PackedVector2Array:
	return PackedVector2Array([jal_a, jal_b]) if jal_line else PackedVector2Array()


## 1re pression : piquet A ; 2e pression (après JALONS_MIN_GAP_S, dans la fenêtre) : piquet B. Un nouveau A remplace l'ancien.
func _cast_jalon(s: SpellData, aim: Variant) -> bool:
	if jal_stage == 1:
		if _jal_t < JALONS_MIN_GAP_S:
			return false
		jal_stage = 2
		_pending[&"plant"] = {"spell": s, "aim": aim, "t": 0.0, "which": 2}
		return true
	if jal_stage == 2:
		return false
	_end_jalons()
	jal_stage = 1
	_jal_t = 0.0
	_pending[&"plant"] = {"spell": s, "aim": aim, "t": 0.0, "which": 1}
	return true


## Coupe le trajet origine -> cible au premier mur (jamais de piquet dans un mur).
func _wall_clip(origin: Vector2, target: Vector2) -> Vector2:
	if player.is_inside_tree():
		var q := PhysicsRayQueryParameters2D.create(origin, target, WALL_MASK, [player.get_rid()])
		var res := player.get_world_2d().direct_space_state.intersect_ray(q)
		if not res.is_empty():
			var hp: Vector2 = res["position"]
			return hp - (hp - origin).normalized() * PEG_WALL_BACK_U * Balance.UNIT_PX
	return target


func _do_jalon(s: SpellData, aim: Variant, which: int) -> void:
	var px := Balance.UNIT_PX
	var rng_mult: float = 1.0 + float(player.stat(&"range_add"))
	if which == 2 and _jal_a_node == null:
		which = 1 # A perdu (nettoyage) : on repart de zéro
		jal_stage = 1
	if which == 1:
		var origin := player.global_position
		var target: Vector2
		if aim != null and ((aim as Vector2) - origin).length_squared() > 1.0:
			target = origin + ((aim as Vector2) - origin).limit_length(JALONS_A_RANGE_U * px * rng_mult)
		else:
			var f: Vector2 = player.facing if player.facing != Vector2.ZERO else Vector2.DOWN
			target = origin + f.normalized() * PIQUET_DEFAULT_U * px
		target = _wall_clip(origin, target)
		jal_a = target
		_jal_dir = (target - origin).normalized() if target.distance_squared_to(origin) > 1.0 else (player.facing if player.facing != Vector2.ZERO else Vector2.DOWN)
		var made := _make_peg(jal_a)
		_jal_a_node = made.get("node")
		_jal_a_sprite = made.get("sprite")
		LightRig.flash(jal_a, &"arpenteuse_snap", 0.25, {"energy": 0.6})
		return
	var target_b: Vector2
	if aim != null and ((aim as Vector2) - jal_a).length_squared() > 1.0:
		target_b = jal_a + ((aim as Vector2) - jal_a).limit_length(JALONS_B_RANGE_U * px * rng_mult)
	else:
		target_b = jal_a + _jal_dir * JALONS_B_DEFAULT_U * px
	var d := target_b - jal_a
	if d.length() < JALONS_MIN_SPAN_U * px: # trop court : le fil est allongé
		target_b = jal_a + (d.normalized() if d.length_squared() > 1.0 else _jal_dir) * JALONS_SPAN_U * px
	jal_b = _wall_clip(jal_a, target_b)
	var made_b := _make_peg(jal_b)
	_jal_b_node = made_b.get("node")
	_jal_b_sprite = made_b.get("sprite")
	jal_line = true
	jal_stage = 0
	jal_left = s.duration if s.duration > 0.0 else JALONS_LIFE_S
	ZoneOutline.attach_capsule(_jal_a_node, _half_w_u() * Balance.UNIT_PX, ZoneOutline.color_for(s, _caster()), jal_left, null, jal_b)
	_jal_hits.clear()
	peg_line.visible = true
	LightRig.flash(jal_b, &"arpenteuse_snap", 0.25, {"energy": 0.6})


func _jalons_step(delta: float) -> void:
	var caster := _caster()
	if jal_stage == 1 and caster != null:
		_jal_t += delta
		var s3 := _spell_of(3)
		if s3 != null:
			var cd := caster._cooldown_of(s3)
			if _jal_t >= JALONS_WINDOW_S and not _pending.has(&"plant"):
				jal_stage = 2 # pas de 2e pression : B part tout seul à JALONS_B_DEFAULT_U
				_do_jalon(s3, null, 2)
				caster.set_cooldown(3, cd, cd) # recharge après la pose de B
			else:
				caster.set_cooldown(3, 0.0, cd) # le sort reste prêt pour la 2e pression
	if not jal_line:
		return
	jal_left = maxf(jal_left - delta, 0.0)
	if jal_left <= 0.0:
		_end_jalons()
		return
	var s := _spell_of(3)
	if s == null or caster == null:
		return
	for e in _enemies_on(jal_segment(), _half_w_u() * Balance.UNIT_PX):
		var id: int = e.get_instance_id()
		if _time - float(_jal_hits.get(id, -INF)) < PEG_IMMUNITY_S:
			continue
		_jal_hits[id] = _time
		var c := Geometry2D.get_closest_point_to_segment(e.global_position, jal_a, jal_b)
		caster.deal_damage(e, s, {"source_pos": c})
		_heat_t = HEAT_FLASH_S


## Piquet debout (visuel CREA) en `pos` : {node, sprite} ; node nul sans les rendus.
func _make_peg(pos: Vector2) -> Dictionary:
	var node := Node2D.new()
	node.name = "JalonPeg"
	fx_root.add_child(node)
	node.z_index = 1
	node.global_position = pos
	var sprite: AnimatedSprite2D = null
	if ResourceLoader.exists(PEG_FRAMES):
		var holder := Node2D.new()
		holder.scale = Iso.UNSQUASH * Iso.SPRITE_K
		node.add_child(holder)
		sprite = AnimatedSprite2D.new()
		sprite.offset = PEG_OFFSET
		holder.add_child(sprite)
		EmissiveOverlay.apply(sprite, load(PEG_FRAMES) as SpriteFrames, 2.0)
	return {"node": node, "sprite": sprite}


func _orient_to(sprite: AnimatedSprite2D, d: Vector2) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var i := roundi(d.angle() / (TAU / 8.0)) % 8 if d.length_squared() > 1.0 else 2
	var a := StringName("peg_" + DIR_NAMES[(i + 8) % 8])
	if sprite.sprite_frames.has_animation(a) and sprite.animation != a:
		sprite.play(a)


func _orient_jalons() -> void:
	_orient_to(_jal_a_sprite, jal_b - jal_a)
	_orient_to(_jal_b_sprite, jal_a - jal_b)


func _end_jalons() -> void:
	jal_stage = 0
	jal_line = false
	jal_left = 0.0
	_jal_hits.clear()
	for n in [_jal_a_node, _jal_b_node]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_jal_a_node = null
	_jal_b_node = null
	_jal_a_sprite = null
	_jal_b_sprite = null
	if peg_line != null and peg_left <= 0.0:
		peg_line.visible = false
		peg_line.set_line(PackedVector2Array())


# --- Variantes : Cerceau (sort 4) ---------------------------------------------------------------------

func _ring_radius() -> float:
	return CERCEAU_RADIUS_U * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))


## Anneau fermé de CERCEAU_POINTS points autour d'elle (rendu ; les dégâts testent la distance à elle).
func ring_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	var c := player.global_position
	var r := _ring_radius()
	for i in CERCEAU_POINTS + 1:
		out.append(c + Vector2.RIGHT.rotated(TAU * float(i) / float(CERCEAU_POINTS)) * r)
	return out


func _do_cerceau(s: SpellData) -> void:
	ring_left = s.duration if s.duration > 0.0 else CERCEAU_LIFE_S
	var ring_half: float = CERCEAU_BAND_HALF_U * Balance.UNIT_PX * (1.0 + float(player.stat(&"zone_size_add")))
	_ring_outline = ZoneOutline.attach_band(player, _ring_radius() + ring_half, _ring_radius() - ring_half, ZoneOutline.color_for(s, _caster()), ring_left)
	_ring_angle = 0.0
	_ring_tick_t = CERCEAU_TICK_S # premier coup tout de suite
	LightRig.flash(player.global_position, s.light_preset, 0.4, {"radius": 1.2})


func _ring_step(delta: float) -> void:
	ring_left = maxf(ring_left - delta, 0.0)
	_ring_angle = fposmod(_ring_angle + TAU * delta / CERCEAU_SPIN_S, TAU)
	_ring_tick_t += delta
	var s := _spell_of(4)
	if s != null and _caster() != null:
		var interval := Balance.attack_interval(CERCEAU_TICK_S, player.stat(&"attack_speed"))
		if _ring_tick_t >= interval:
			_ring_tick_t = 0.0
			_ring_hit(s)
	if ring_left <= 0.0:
		_end_ring()


## Un tick du Cerceau : tout monstre dans la bande (r ± CERCEAU_BAND_HALF_U) prend CERCEAU_COEF et est repoussé vers l'extérieur.
func _ring_hit(s: SpellData) -> int:
	var c := player.global_position
	var r := _ring_radius()
	var half: float = CERCEAU_BAND_HALF_U * Balance.UNIT_PX * (1.0 + float(player.stat(&"zone_size_add")))
	var hits := 0
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"take_damage"):
			continue
		var d := (e as Node2D).global_position.distance_to(c)
		if absf(d - r) > half + _radius_of(e):
			continue
		_caster().deal_damage(e, s, {"source_pos": c})
		hits += 1
	if hits > 0:
		ring_hits += hits
		_heat_t = HEAT_FLASH_S
	last_ring = {"hits": hits, "radius_px": r}
	return hits


## Fin du Cerceau : la chaîne retombe pleine (prolongée droit derrière la queue si elle était plus courte).
func _end_ring() -> void:
	if is_instance_valid(_ring_outline):
		_ring_outline.release()
	ring_left = 0.0
	_idle_t = 0.0 # le touret ne rembobine pas tout de suite la chaîne rendue
	_refill_chain()
	LightRig.flash(player.global_position, &"arpenteuse_snap", 0.3, {"energy": 0.8})


func _refill_chain() -> void:
	var need := _max_u() * Balance.UNIT_PX - chain_length()
	if need < 1.0:
		return
	var dir := Vector2.ZERO
	var base := player.global_position
	if chain.size() >= 2:
		dir = (chain[0] - chain[1]).normalized()
		base = chain[0]
	elif chain.size() == 1:
		base = chain[0]
	if dir == Vector2.ZERO:
		dir = -(player.facing if player.facing != Vector2.ZERO else Vector2.DOWN).normalized()
	var step := CHAIN_STEP_U * Balance.UNIT_PX
	var far := _wall_clip(base, base + dir * need) # jamais à travers un mur
	var n := int(base.distance_to(far) / step)
	var fresh := PackedVector2Array()
	for k in range(n, 0, -1):
		fresh.append(base + dir * step * float(k))
	fresh.append_array(chain)
	chain = fresh


# --- Nettoyage (étage, mort) ------------------------------------------------------------------------

func clear_transients() -> void:
	_pending.clear()
	_dragged.clear()
	snap_left = 0.0
	_end_peg(false)
	_end_jalons()
	knot_left = 0.0
	ring_left = 0.0
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
	if _cross_t > 0.0 and Quality.flashes_level > 0: # monstre croisé (double chaîne) : la chaîne rougit plus fort
		line.energy = lerpf(line.energy, CROSS_FLASH_ENERGY, _cross_t / HEAT_FLASH_S)
	if snap_left > 0.0:
		line.energy = HEAT_FLASH_ENERGY * 1.4
	if ring_left > 0.0:
		line.u_offset = fposmod(_ring_angle / TAU * 2.0, 1.0)
		line.energy = HEAT_FLASH_ENERGY
		line.set_line(ring_points())
	else:
		line.set_line(_lift_head(smooth_polyline(pts)))
	line.advance(delta)
	if jal_line:
		var jseg := jal_segment()
		peg_line.u_offset = 0.0
		peg_line.energy = HEAT_ENERGY * 1.4 if snap_left <= 0.0 else HEAT_FLASH_ENERGY * 1.4
		peg_line.set_line(jseg)
		peg_line.advance(delta)
		_orient_jalons()
	if peg_left > 0.0:
		var seg := peg_segment()
		peg_line.u_offset = 0.0
		peg_line.energy = HEAT_ENERGY * 1.4 if snap_left <= 0.0 else HEAT_FLASH_ENERGY * 1.4 # tendue = plus chaude
		peg_line.set_line(seg)
		peg_line.advance(delta)
		_orient_peg()
	_update_lights(pts)


## Rendu : le dernier tronçon (HAND_RAMP_U) monte du sol jusqu'à la main d'Arpenteuse (la tête touche son corps,
## plus d'écart visible). Les dégâts restent calculés au sol.
static func _lift_head(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 2:
		return pts
	var out := pts.duplicate()
	var ramp := HAND_RAMP_U * Balance.UNIT_PX
	var lift := Iso.lift_logical(HAND_H_U)
	var run := 0.0
	var last := out.size() - 1
	out[last].y += lift
	for i in range(last - 1, -1, -1):
		run += pts[i].distance_to(pts[i + 1])
		if run >= ramp:
			break
		out[i].y += lift * (1.0 - run / ramp)
	return out


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



# --- Passif expliqué (infobulle du HUD ; contrat KitResource.passive) ------------------------------------

static func passive_info() -> Dictionary:
	var f := KitResource.fmt
	return KitResource.passive("Chaîne", &"chaine",
		"La chaîne est la traîne d'Arpenteuse : elle ne blesse que ce qu'elle a parcouru (largeur %s u, un tick toutes les %s s, ralentit de %s)." % [
			f.call(CHAIN_HALF_WIDTH_U * 2.0), f.call(CHAIN_TICK_S), KitResource.pct(CHAIN_SLOW_PCT)],
		"chaque pas : les %s derniers u de ton trajet restent posés au sol." % f.call(CHAIN_MAX_U),
		"immobile plus de %s s, le touret rembobine la chaîne (%s u par seconde) : rester sur place, c'est perdre ta zone." % [f.call(CHAIN_IDLE_S), f.call(CHAIN_REEL_U_S)],
		"la Boucle (sort 2) exige au moins %s u de chaîne et frappe toute sa longueur. Les sorts 2 à 4 font +%s de dégâts sur élites et boss." % [f.call(BOUCLE_MIN_U), KitResource.pct(BIG_TARGET_ADD)])
