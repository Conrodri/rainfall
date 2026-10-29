class_name RictusKit
extends Node
## Kit de Rictus, pantin de la barge noyée (docs/Design_Personnages.md §2.6) : 4 sorts / 0 passif,
## le Montreur (fantôme) est un trait intégré. Données : character(). Logique d'état : ce nœud, enfant
## « Kit » du joueur (CharacterData.kit_script) ; le joueur et SpellCaster l'interrogent par des hooks
## (blocks_slot, cast_spell, speed_mult, inertia_s, slow_immune, can_dodge, visual_anim…).
## - Sort 1 Dagues en demi-lune : SpellData ARC (SpellCaster), vers l'ennemi le plus proche, jamais le curseur.
## - Sort 2 Éventail : SpellData FAN, 5 couteaux ; un couteau en fin de course reste planté (GroundPickup, S6).
## - Sort 3 Toupie : état SPIN (ticks de zone, glisse avec inertie, roulade interdite, sort 1 suspendu), vertige.
## - Sort 4 Les Doublures : 6 leurres Decoy (S14) en hexagone ; la Toupie les expédie en étoile.
## - Roulade = levée : même dash que la roulade (Balance.DODGE_*), pantin soulevé de LIFT_HEIGHT_U.
## - Fils tendus : +2 % PV max en fin de Toupie et à la première explosion de chaque Doublures.
## Rendu : CompanionSprite (le Montreur) + StringRig (5 fils) ; assets M1-M3 absents = repli sur Ardent teinté.

# --- Assets attendus (lots Codex M2/M3) : chemins et noms d'anims de §2.6.11 ----------------------
const ASSET_DIR := "res://assets/sprites/characters/rictus/"
const MONTREUR_DIR := "res://assets/sprites/characters/montreur/"
const SPRITE_FRAMES := ASSET_DIR + "rictus.tres" ## idle/run/slash/throw/stagger/summon/lift/death _<dir> ; spin (1 dir)
const MONTREUR_FRAMES := MONTREUR_DIR + "montreur.tres" ## hover_<dir>, pull_<dir>
const STRINGS_MANIFEST := ASSET_DIR + "strings.json" ## points d'attache des fils (format : StringRig)
const STRING_TEXTURE := MONTREUR_DIR + "string_tile/string_tile.png"
const KNIFE_FRAMES := ASSET_DIR + "knife/knife.tres" ## anim `default`, pointe vers +X
const KNIFE_PLANTED_FRAMES := ASSET_DIR + "knife_planted/knife_planted.tres" ## `default_<dir>`
## Demi-lune au sol (lot M3, rig TOP 128 px/u, 4 frames, arc centré sur +X, Rictus au centre de la frame) ;
## absente = croissant dessiné par ZoneEffect. Rayon de l'arc dans la frame : 2,5 u × 128 px.
const DAGGER_ARC_FRAMES := ASSET_DIR + "dagger_arc/dagger_arc.tres"
const DAGGER_ARC_RADIUS_PX := 320.0
## Explosion des doublures (lot M3, anim `default` = vue TOP 128 px/u, 6 frames non bouclées) : l'anneau
## final de la gerbe est à 1,92 u = 246 px du centre, calé sur le rayon réel de l'explosion (2 u + zone_size_add).
const DOUBLE_BURST_FRAMES := ASSET_DIR + "double_burst/double_burst.tres"
const DOUBLE_BURST_RADIUS_PX := 246.0
## Traînée de la toupie (lot M3, CREA 4 frames en boucle, additive, même échelle que le pantin, 90,5 px/u),
## enfant du sprite du pantin, centrée à 0,48 u au-dessus des pieds (= décalage du pivot, 40,32 px).
const SPIN_BLUR_FRAMES := ASSET_DIR + "spin_blur/spin_blur.tres"
const SPIN_BLUR_OFFSET := Vector2(0, -40.32)
const SPIN_BLUR_ALPHA := 0.55 ## teinte argent spectral (accent unique), discrète : le pantin reste lisible dessous
const PLACEHOLDER_TINT := Color(0.78, 0.66, 0.6) ## Ardent teinté bois verni / porcelaine, en attendant M2

# --- Rendu (retour joueur : fils fins et discrets, fantôme lisible) --------------------------------
const MONTREUR_LIFT_U := 1.4
const MONTREUR_ALPHA := 0.8
const STRING_COLOR := Color("#9FC8C0")
const STRING_ALPHA := 0.2 ## retour joueur : fils plus transparents (0,35 -> 0,2)
const STRING_GLOW := 1.25 ## légère lueur : couleur HDR (glow de l'étalonnage)
const STRING_WIDTH_SCREEN_PX := 1.0
const STRING_VIBRATE_S := 0.2

# --- Gameplay (§2.6.3, §2.6.7) --------------------------------------------------------------------
const HITBOX_U := 0.45
const SPIN_HITBOX_U := 0.5
const SPIN_SPEED_U := 4.8 ## 4,2 × (4,8 / 4,2) : la toupie glisse à 4,8 u/s de base
const SPIN_INERTIA_S := 0.3
const SPIN_TICK_S := 0.25
const SPIN_KNOCK_U := 0.3
const STAGGER_S := 0.3
const STAGGER_SPEED_MULT := 0.5
const HEAL_PCT := 0.02
const LIFT_HEIGHT_U := 0.8
const ARC_KNOCK_U := 0.2
const KNIFE_LIFE_S := 4.0
const KNIFE_CONTACT_U := 0.6
const KNIFE_REFUND_S := 1.0
const KNIFE_REFUND_CAP_S := 5.0 ## par salve
const DECOY_COUNT := 6
const DECOY_RING_U := 1.2
const DECOY_HP_FRAC := 0.2
const DECOY_LIFE_S := 3.0
const DECOY_BURST_U := 2.4 ## rayon d'explosion de chaque doublure (2,0 -> 2,4 u, retour joueur 26/10)
const DECOY_DEATH_FRAC := 0.6
const DECOY_BLOCK_PUSH_U := 0.5
const FLIGHT_COEF := 1.2 ## retour joueur 26/10 : ultime plus impactant (1,0 -> 1,4 par doublure expédiée par la Toupie)
## Équilibrage (simulateur du 22/10/2026) : cible unique −36 % et dégâts subis ×1,8-2,4 vs Ardent à l'origine.
const ARC_COEF := 0.8 ## demi-lune 0,6 -> 0,8
const FAN_COEF := 1.35 ## Éventail 1,2 -> 1,6 -> 1,8 -> 1,35 par couteau (équilibrage 23/10 : 1,8 -> 1,35 ; sous la plage P3 1,7-1,9 : les 5 couteaux touchent tous un boss)
const DECOY_COEF := 2.4 ## retour joueur 26/10 : ultime plus fort (1,8 -> 2,6) ; avant : ## Doublures 2,5 -> 3,0 -> 2,0 -> 1,8 (équilibrage 23/10 : 2,0 -> 1,8, bas de la plage P3 : sans effet mesurable sur le DPS boss, la toupie domine)
## Garde du Montreur : après chaque demi-lune, les fils tirent le pantin hors des coups (−30 % de dégâts subis
## pendant GUARD_S). La mêlée garde son risque hors attaque (déplacement, vertige).
## Pointe de la toupie (retour joueur 26/10 : manque de monocible) : à chaque tick, un coup supplémentaire frappe l'ennemi
## le plus proche (la cible clouée au centre). Aucune dépendance à l'ultime : la Toupie devient la source monocible.
const TOUPIE_FOCUS_COEF := 0.15
const TOUPIE_FOCUS_RADIUS_U := 0.9
const TOUPIE_COEF := 0.42 ## Toupie, par tick (équilibrage 23/10 : 0,7 -> 0,5 ; levier principal sur les boss, la toupie touche tous les ticks)
const GUARD_TAKEN_MULT := 0.7
const GUARD_S := 0.3 ## équilibrage 23/10 : 0,5 -> 0,35 -> 0,3
const FLIGHT_PROC := 0.5
## Anims d'action (Player.play_action) : slash à chaque demi-lune (anim complète), throw (Éventail),
## summon (Doublures, posées à la frame d'impact). Frames d'impact (index 0) des anims de rictus.tres.
## Lot M2b : `throw_ult` (6 frames × 8 dir, impact frame 3) remplace `summon` pour les Doublures (bras lancés
## vers l'extérieur, tirés par les fils) ; `summon` reste le repli si throw_ult n'est pas livrée.
const ACTION_IMPACT_FRAMES := {&"slash": 1, &"throw": 2, &"summon": 3, &"throw_ult": 3}
const ULT_ACTIONS: Array[StringName] = [&"throw_ult", &"summon"]
const WALL_MASK := 1

# --- Variantes de sorts (docs/Variantes_Sorts.md §2.2 ; contrat CONTRACTS.md « Variantes de sorts ») ---------
const V_MAIN := &"rictus_main_du_montreur" ## slot 1 (remplace les Dagues en demi-lune)
const V_PENDULE := &"rictus_lame_pendule" ## slot 2 (remplace l'Éventail)
const V_PIROUETTE := &"rictus_pirouette" ## slot 3 (remplace la Toupie)
const V_RIDEAU := &"rictus_rideau" ## slot 4 (remplace Les Doublures)
const COUNTER_KNIVES := "rictus.knives_picked" ## couteaux plantés ramassés (déblocage Lame-pendule)
const COUNTER_DOUBLES := "rictus.doubles_launched" ## doublures expédiées par Toupie / Pirouette (déblocage Pirouette)
const VAR_DIR := ASSET_DIR + "variants/" ## VFX des variantes (lot Codex RICV), absents = replis dessinés
## Main du Montreur : claquement au sol sur le paquet le plus dense à portée.
const MAIN_RANGE_U := 4.0
const MAIN_RADIUS_U := 1.4
const MAIN_GUARD_U := 1.5 ## la garde ne vaut que si le claquement tombe à cette distance de Rictus
const MAIN_COEF := 1.3 ## doc 0,8 ; sim : le pilote tient 2,8 u et perd l'uptime de ses sorts de mêlée -> coef relevé
const MAIN_KNOCK_U := 0.2
## Lame-pendule : aller-retour à tout monstre traversé.
const PENDULE_RANGE_U := 7.0
const PENDULE_SPEED_U := 14.0
const PENDULE_COEF := 3.5 ## à l'aller ET au retour (doc 2,5 ; sim : un seul couteau touche un boss là où 5 touchaient)
const PENDULE_KNOCK_U := 0.4
const PENDULE_CD := 6.0
## Pirouette : tour bref, invulnérable, immobile ; impact à mi-course.
const PIROUETTE_S := 0.6
const PIROUETTE_IMPACT_S := 0.3
const PIROUETTE_RADIUS_U := 2.2
const PIROUETTE_COEF := 3.7
const PIROUETTE_KNOCK_U := 1.0
const PIROUETTE_CD := 8.0
## Rideau : 6 doublures en ligne perpendiculaire à la visée.
const RIDEAU_AHEAD_U := 2.0
const RIDEAU_SPACING_U := 1.0
const RIDEAU_LIFE_S := 6.0
const RIDEAU_HP_FRAC := 0.3
const RIDEAU_COEF := 1.7 ## doc 2,5 (calé sur la base à 3,0) ; base ramenée à 1,8 -> même rapport 15/18 ; 26/10 : 1,35 -> 1,95 (base 1,8 -> 2,6)
const RIDEAU_AIM_U := 8.0 ## sans visée manuelle : ennemi le plus proche à cette distance
const DIR_NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

var player: CharacterBody2D = null
var companion: CompanionSprite = null
var strings: StringRig = null
var knives: Array = [] ## GroundPickup plantés
var spin_left := 0.0
var stagger_left := 0.0
var lifting := false
var _spin_elapsed := 0.0
var _spin_ticks := 0
var _spin_total := 2.5
var _spin_tick_spell: SpellData = null
var _spin_focus_spell: SpellData = null
var _pending_decoys := {} ## Doublures lancées, posées à la frame d'impact de `summon` : {spell, aim}
var _visual: AnimatedSprite2D = null
var guard_left := 0.0 ## garde du Montreur après une demi-lune
var spin_blur: AnimatedSprite2D = null ## traînée additive pendant la toupie (null sans asset)
var pirouette_left := 0.0 ## variante Pirouette en cours (s restantes)
var _pir_elapsed := 0.0
var _pir_struck := false
var _pir_spell: SpellData = null
var pendulums: Array = [] ## RictusPendulum en vol


# --- Données -------------------------------------------------------------------------------------

## Recul imposé (u) -> force de coup (Balance.knockback_px est linéaire entre KB_MIN_U et KB_MAX_U).
static func _force_for(knock_u: float) -> float:
	return clampf(inverse_lerp(Balance.KB_MIN_U, Balance.KB_MAX_U, knock_u), 0.0, 1.0)


static func _spell(sid: StringName, name: String, slot: int, behavior: SpellData.Behavior, coef: float, cd: float) -> SpellData:
	var s := SpellData.new()
	s.id = sid
	s.display_name = name
	s.slot = slot
	s.behavior = behavior
	s.coef = coef
	s.base_cooldown = cd
	s.element = &"physical"
	s.color = STRING_COLOR
	s.light_preset = &"spell_steel" ## argent spectral (accent unique), jamais la braise d'Ardent
	return s


static func character() -> CharacterData:
	var c := CharacterData.new()
	c.id = &"rictus"
	c.display_name = "Rictus"
	c.base_hp = 95.0
	c.hp_per_level = 28.0
	c.armor = 10.0
	c.base_regen = 0.6
	c.regen_per_level = 0.12
	c.base_speed_u = 4.2
	c.hitbox_u = HITBOX_U
	c.kit_script = RictusKit
	c.sprite_frames_path = SPRITE_FRAMES
	c.placeholder_tint = PLACEHOLDER_TINT
	c.body_color = Color("#7A3B24")
	c.accent_color = STRING_COLOR
	c.action_impact_frames = ACTION_IMPACT_FRAMES

	var s1 := _spell(&"dagues_demi_lune", "Dagues en demi-lune", 1, SpellData.Behavior.ARC, ARC_COEF, 0.6)
	s1.is_auto = true
	s1.range_u = 3.0 # retour joueur 23/10 : portée de l'auto 2,5 -> 3,0 u (le VFX se met à l'échelle : k = rayon / DAGGER_ARC_RADIUS_PX)
	s1.radius_u = 3.0
	s1.spread_deg = 180.0
	s1.proc_coef = 0.8
	s1.hit_force = _force_for(ARC_KNOCK_U)
	s1.vfx_frames = DAGGER_ARC_FRAMES
	s1.vfx_radius_px = DAGGER_ARC_RADIUS_PX
	s1.vfx_floor_aspect = 1.0 # rig TOP : jamais pré-écrasé

	var s2 := _spell(&"eventail", "Éventail", 2, SpellData.Behavior.FAN, FAN_COEF, 6.0)
	s2.count = 5
	s2.spread_deg = 60.0
	s2.speed_u = 14.0
	s2.range_u = 7.0
	s2.pierce = 1
	s2.item_pierce = false # Pointe perforante : sort 1 seulement
	s2.is_zone = false
	s2.proc_coef = 0.8
	s2.rests_on_ground = true
	s2.target_mode = &"densest"
	s2.trigger_range_u = 6.0
	s2.projectile_frames = KNIFE_FRAMES

	var s3 := _spell(&"toupie", "Toupie", 3, SpellData.Behavior.SPIN, TOUPIE_COEF, 8.0)
	s3.radius_u = 2.2 # retour joueur : toupie plus large (1,5 -> 2,2 u)
	s3.duration = 2.5
	s3.tick = SPIN_TICK_S
	s3.proc_coef = 0.3
	s3.trigger_range_u = 2.5
	s3.hit_force = _force_for(SPIN_KNOCK_U)

	var s4 := _spell(&"doublures", "Les Doublures", 4, SpellData.Behavior.DECOYS, DECOY_COEF, 20.0)
	s4.radius_u = DECOY_BURST_U
	s4.duration = DECOY_LIFE_S
	s4.proc_coef = 1.0
	s4.trigger_range_u = 3.0
	s4.hit_force = 1.0

	c.spells = [s1, s2, s3, s4]
	return c


## Variantes (contrat CONTRACTS.md) : SpellData de la variante `variant_id` pour `slot`, ou null (non codée).
## Coefficients ajustés par balance_sim (±15 % du sort de base en DPS cible et zone) ; le style ne change pas.
static func variant(slot: int, variant_id: StringName) -> SpellData:
	match [slot, variant_id]:
		[1, V_MAIN]:
			var s1 := _spell(V_MAIN, "Main du Montreur", 1, SpellData.Behavior.KIT, MAIN_COEF, 0.6)
			s1.is_auto = true
			s1.range_u = MAIN_RANGE_U
			s1.trigger_range_u = MAIN_RANGE_U
			s1.radius_u = MAIN_RADIUS_U
			s1.proc_coef = 0.8
			s1.hit_force = _force_for(MAIN_KNOCK_U)
			s1.vfx_frames = VAR_DIR + "montreur_hand_slam/montreur_hand_slam.tres"
			s1.vfx_radius_px = MAIN_RADIUS_U * 128.0 # rig TOP 128 px/u
			s1.vfx_floor_aspect = 1.0
			return s1
		[2, V_PENDULE]:
			var s2 := _spell(V_PENDULE, "Lame-pendule", 2, SpellData.Behavior.KIT, PENDULE_COEF, PENDULE_CD)
			s2.range_u = PENDULE_RANGE_U
			s2.speed_u = PENDULE_SPEED_U
			s2.is_zone = false
			s2.item_pierce = false
			s2.proc_coef = 0.8
			s2.hit_force = _force_for(PENDULE_KNOCK_U)
			s2.target_mode = &"densest"
			s2.trigger_range_u = 6.0
			return s2
		[3, V_PIROUETTE]:
			var s3 := _spell(V_PIROUETTE, "Pirouette", 3, SpellData.Behavior.KIT, PIROUETTE_COEF, PIROUETTE_CD)
			s3.radius_u = PIROUETTE_RADIUS_U
			s3.duration = 0.0 # coup direct (recul), pas un DoT
			s3.proc_coef = 0.8
			s3.trigger_range_u = 2.5
			s3.hit_force = _force_for(PIROUETTE_KNOCK_U)
			s3.vfx_frames = VAR_DIR + "pirouette_burst/pirouette_burst.tres"
			s3.vfx_radius_px = PIROUETTE_RADIUS_U * 128.0 # rig TOP 128 px/u
			s3.vfx_floor_aspect = 1.0
			return s3
		[4, V_RIDEAU]:
			var s4 := _spell(V_RIDEAU, "Rideau", 4, SpellData.Behavior.DECOYS, RIDEAU_COEF, 20.0)
			s4.radius_u = DECOY_BURST_U
			s4.duration = RIDEAU_LIFE_S
			s4.proc_coef = 1.0
			s4.trigger_range_u = 3.0
			s4.hit_force = 1.0
			return s4
	return null


# --- Mise en place ------------------------------------------------------------------------------

func setup(p: CharacterBody2D) -> void:
	player = p
	_visual = p.get_node_or_null(^"Visual") as AnimatedSprite2D
	if _visual != null:
		companion = CompanionSprite.attach(p, _visual, MONTREUR_FRAMES, MONTREUR_LIFT_U, MONTREUR_ALPHA)
		var col := Color(STRING_COLOR.r * STRING_GLOW, STRING_COLOR.g * STRING_GLOW, STRING_COLOR.b * STRING_GLOW, STRING_ALPHA)
		strings = StringRig.attach(p, _visual, companion, STRINGS_MANIFEST, col,
				STRING_WIDTH_SCREEN_PX / Iso.camera_zoom().x, STRING_TEXTURE)
		_attach_spin_blur()
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


func _spell_of(slot: int) -> SpellData:
	for s in player.character.spells:
		if s.slot == slot:
			return s
	return null


# --- Hooks du joueur et de SpellCaster ----------------------------------------------------------

func is_spinning() -> bool:
	return spin_left > 0.0


func is_staggered() -> bool:
	return stagger_left > 0.0


## Table d'états §2.6.4.
func blocks_slot(slot: int) -> bool:
	if lifting:
		return true
	if spin_left > 0.0:
		return slot == 1 or slot == 3
	if stagger_left > 0.0:
		return slot == 3
	return false


## Retour joueur : la levée est permise pendant la Toupie (la toupie continue) ; seul le vertige l'interdit.
func can_dodge() -> bool:
	return stagger_left <= 0.0


func speed_mult() -> float:
	if pirouette_left > 0.0:
		return 0.0 # Pirouette : immobile (pas de glisse)
	if spin_left > 0.0:
		return SPIN_SPEED_U / maxf(player.character.base_speed_u, 0.01)
	if stagger_left > 0.0:
		return STAGGER_SPEED_MULT
	return 1.0


func inertia_s() -> float:
	return SPIN_INERTIA_S if spin_left > 0.0 else 0.0


## Le Montreur tient la toupie droite : ralentissements ignorés (et non appliqués).
func slow_immune() -> bool:
	return spin_left > 0.0


## L'orientation pendant la demi-lune est tenue par l'anim d'action du joueur (Player.action_locks_facing).
func locks_facing() -> bool:
	return false


func dodge_ghosts() -> bool:
	return false # la levée se lit par le pantin soulevé, pas par des fantômes


func dodge_label() -> String:
	return "Levée"


func on_dodge_start(_dir: Vector2) -> void:
	lifting = true
	# au-dessus des monstres : masque sans la couche 3 (le joueur n'a déjà que le monde) ; les murs arrêtent
	player.collision_mask = WALL_MASK
	if strings != null:
		strings.tension = 1.0


func cast_spell(s: SpellData, aim: Variant) -> bool:
	match s.id:
		V_MAIN:
			return _cast_main(s)
		V_PENDULE:
			return _cast_pendule(s, aim)
		V_PIROUETTE:
			return _start_pirouette(s)
	match s.behavior:
		SpellData.Behavior.SPIN:
			return _start_spin(s)
		SpellData.Behavior.DECOYS:
			_pending_decoys = {"spell": s, "aim": aim}
			return true
	return false


## Anim d'action de chaque sort (Player.action_base_for) ; la Toupie a ses propres anims d'état.
func action_for(s: SpellData) -> StringName:
	match s.behavior:
		SpellData.Behavior.ARC:
			return &"slash"
		SpellData.Behavior.KIT:
			return &"slash" if s.id == V_MAIN else &""
		SpellData.Behavior.FAN:
			return &"throw"
		SpellData.Behavior.DECOYS:
			return ult_action()
	return &""


## Anim de lancement des Doublures : `throw_ult` (M2b) si livrée, sinon `summon`.
func ult_action() -> StringName:
	if _visual != null and _visual.sprite_frames != null:
		for a: StringName in ULT_ACTIONS:
			if _visual.sprite_frames.has_animation(StringName("%s_s" % a)) or _visual.sprite_frames.has_animation(a):
				return a
	return &"summon"


## Frame d'impact de `throw_ult` / `summon` : les doublures apparaissent (Player.action_impact).
func _on_action_impact(base: StringName) -> void:
	if base in ULT_ACTIONS and not _pending_decoys.is_empty():
		var pend := _pending_decoys
		_pending_decoys = {}
		if player != null and not player.dead:
			_spawn_decoys(pend["spell"], pend["aim"])


## Doublures lancées mais pas encore posées (avant la frame d'impact).
func decoys_pending() -> bool:
	return not _pending_decoys.is_empty()


## Anims et orientation : Player.play_action (action_for) ; rien d'autre à faire au lancement.
func on_cast(s: SpellData) -> void:
	if s.slot == 1 and s.id != V_MAIN: # Main du Montreur : garde posée par _cast_main (conditionnelle)
		guard_left = GUARD_S


## Hook Player.take_damage : garde du Montreur juste après une demi-lune.
func damage_taken_mult(_source: Node) -> float:
	return GUARD_TAKEN_MULT if guard_left > 0.0 else 1.0


## Couteau en fin de course (portée ou mur) : planté KNIFE_LIFE_S ; marcher dessus rend 1 s à l'Éventail.
func on_projectile_rest(s: SpellData, at: Vector2, group: Dictionary) -> void:
	if player == null or player.dead or player.get_parent() == null:
		return
	var g := GroundPickup.spawn(player.get_parent(), at, player, func(_g: GroundPickup) -> void:
		_collect_knife(s.slot, group), KNIFE_LIFE_S, KNIFE_CONTACT_U, KNIFE_PLANTED_FRAMES,
		_knife_facing(at))
	knives.append(g)
	g.tree_exiting.connect(func() -> void: knives.erase(g))


## Orientation du couteau planté (default_<dir>) : direction de vol approchée (du pantin vers le point de chute).
func _knife_facing(at: Vector2) -> Vector2:
	var d := at - player.global_position
	return d.normalized() if d.length_squared() > 1.0 else player.facing


func _collect_knife(slot: int, group: Dictionary) -> void:
	var left := KNIFE_REFUND_CAP_S - float(group.get("refunded", 0.0))
	if left <= 0.0 or _caster() == null:
		return
	group["refunded"] = float(group.get("refunded", 0.0)) + _caster().reduce_cooldown(slot, minf(KNIFE_REFUND_S, left))
	RunState.add_counter(COUNTER_KNIVES)
	Audio.play(&"pickup.coin", player.global_position, -8.0, 1.6)


# --- Boucle (appelée par Player.tick, avant les sorts) -------------------------------------------

func tick(delta: float) -> void:
	guard_left = maxf(guard_left - delta, 0.0)
	if stagger_left > 0.0:
		stagger_left = maxf(stagger_left - delta, 0.0)
	if lifting and not player.is_dodging():
		lifting = false
	if spin_left > 0.0:
		_spin_step(delta)
	if pirouette_left > 0.0:
		_pirouette_step(delta)
	_update_rig()


func _start_spin(s: SpellData) -> bool:
	if spin_left > 0.0 or lifting:
		return false
	_spin_tick_spell = s.duplicate() as SpellData
	_spin_tick_spell.behavior = SpellData.Behavior.NOVA
	_spin_tick_spell.duration = 0.0 # chaque tick = coup direct (recul), pas un DoT
	_spin_focus_spell = _spin_tick_spell.duplicate() as SpellData
	_spin_focus_spell.coef = TOUPIE_FOCUS_COEF
	_spin_focus_spell.radius_u = TOUPIE_FOCUS_RADIUS_U
	_spin_focus_spell.vfx_frames = "" # coup direct sans gerbe
	_spin_focus_spell.is_zone = false
	_spin_focus_spell.hit_force = -1.0
	_spin_total = s.duration
	spin_left = s.duration
	_spin_elapsed = 0.0
	_spin_ticks = 0
	player.set_hitbox_u(SPIN_HITBOX_U)
	player.clear_slow()
	player.grant_invulnerability(s.duration) # retour joueur : invulnérable pendant toute la toupie
	_spin_tick() # premier tick au lancement : 10 ticks à 0, 0,25 … 2,25 s
	_push_decoys()
	return true


func _spin_step(delta: float) -> void:
	_spin_elapsed += delta
	spin_left = maxf(_spin_total - _spin_elapsed, 0.0)
	var n := int(roundf(_spin_total / SPIN_TICK_S))
	while _spin_ticks < n and _spin_elapsed + 0.0001 >= _spin_ticks * SPIN_TICK_S:
		_spin_tick()
	_push_decoys()
	if spin_left <= 0.0:
		_end_spin()


func _spin_tick() -> void:
	_spin_ticks += 1
	if _caster() != null and _spin_tick_spell != null:
		_caster().spawn_zone(_spin_tick_spell, player.global_position)
		if _spin_focus_spell != null: # Pointe de la toupie : coup monocible sur l'ennemi le plus proche
			var tgt := _caster().nearest_enemy(spin_radius_px())
			if tgt != null:
				_caster().spawn_zone(_spin_focus_spell, tgt.global_position)


func spin_radius_px() -> float:
	var r: float = _spin_tick_spell.radius_u if _spin_tick_spell != null else 1.5
	return r * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))


## Toute doublure dont le centre entre dans la toupie est percutée (une fois) : départ droit devant elle.
func _push_decoys(radius_px := -1.0) -> void:
	if Decoy.live.is_empty():
		return
	var r := radius_px if radius_px >= 0.0 else spin_radius_px()
	for d in Decoy.live.duplicate():
		if is_instance_valid(d) and not d.pushed and d.global_position.distance_to(player.global_position) <= r:
			if d.push():
				RunState.add_counter(COUNTER_DOUBLES)


## Fin de toupie : fils tendus (+2 % PV), vertige.
func _end_spin() -> void:
	spin_left = 0.0
	stagger_left = STAGGER_S
	player.set_hitbox_u(HITBOX_U)
	player.heal(HEAL_PCT * player.max_hp)
	if strings != null:
		strings.vibrate(STRING_VIBRATE_S)


# --- Variantes : Main du Montreur, Lame-pendule, Pirouette ------------------------------------------

## Main du Montreur : claquement (disque) sur le paquet le plus dense à MAIN_RANGE_U ; la garde ne vaut que de près.
func _cast_main(s: SpellData) -> bool:
	var c := _caster()
	if c == null:
		return false
	var pt: Variant = c.densest_point(MAIN_RANGE_U * Balance.UNIT_PX)
	if pt == null:
		return false
	var at: Vector2 = pt
	var zs := s.duplicate() as SpellData
	zs.behavior = SpellData.Behavior.NOVA
	zs.duration = 0.0
	var d := at - player.global_position
	if d.length_squared() > 1.0:
		player.facing = d.normalized()
	c.spawn_zone(zs, at)
	if d.length() <= MAIN_GUARD_U * Balance.UNIT_PX:
		guard_left = GUARD_S
	if strings != null:
		strings.vibrate(STRING_VIBRATE_S)
	return true


## Lame-pendule : couteau-pendule vers la visée (curseur / paquet le plus dense), sinon devant ; plusieurs en vol permis.
func _cast_pendule(s: SpellData, aim: Variant) -> bool:
	var c := _caster()
	if c == null:
		return false
	var dir: Vector2 = player.facing if player.facing != Vector2.ZERO else Vector2.DOWN
	if aim != null and ((aim as Vector2) - player.global_position).length_squared() > 1.0:
		dir = ((aim as Vector2) - player.global_position).normalized()
	var spd := s.speed_u * Balance.UNIT_PX * (1.0 + minf(player.stat(&"projectile_speed"), Balance.PROJECTILE_SPEED_BONUS_CAP))
	var n := RictusPendulum.launch(c, player, s, dir, spd, c.range_px(s))
	pendulums.append(n)
	n.tree_exiting.connect(func() -> void: pendulums.erase(n))
	player.facing = dir
	return true


## Pirouette : 0,6 s invulnérable et immobile ; coup de zone à mi-course ; roulade et sort 1 libres, pas de vertige.
func _start_pirouette(s: SpellData) -> bool:
	if pirouette_left > 0.0 or spin_left > 0.0 or lifting:
		return false
	_pir_spell = s.duplicate() as SpellData
	_pir_spell.behavior = SpellData.Behavior.NOVA
	_pir_spell.duration = 0.0
	pirouette_left = PIROUETTE_S
	_pir_elapsed = 0.0
	_pir_struck = false
	player.grant_invulnerability(PIROUETTE_S)
	if strings != null:
		strings.tension = 1.0
	return true


func _pirouette_step(delta: float) -> void:
	_pir_elapsed += delta
	if not _pir_struck and _pir_elapsed + 0.0001 >= PIROUETTE_IMPACT_S:
		_pir_struck = true
		if _caster() != null and _pir_spell != null:
			_caster().spawn_zone(_pir_spell, player.global_position)
			_push_decoys(_pir_spell.radius_u * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add")))
		if strings != null:
			strings.vibrate(STRING_VIBRATE_S)
	pirouette_left = maxf(PIROUETTE_S - _pir_elapsed, 0.0)


# --- Doublures (S14) ----------------------------------------------------------------------------

func _spawn_decoys(s: SpellData, aim: Variant) -> void:
	var origin := player.global_position
	var first := Vector2.UP # sans visée : vers le haut de l'écran
	if aim != null and ((aim as Vector2) - origin).length_squared() > 1.0:
		first = ((aim as Vector2) - origin).normalized()
	var explode := s.duplicate() as SpellData
	explode.behavior = SpellData.Behavior.NOVA
	explode.duration = 0.0
	explode.vfx_frames = DOUBLE_BURST_FRAMES # gerbe de copeaux et de fils rompus (M3, vue TOP)
	explode.vfx_radius_px = DOUBLE_BURST_RADIUS_PX
	explode.vfx_floor_aspect = 1.0 # rig TOP : jamais pré-écrasé
	var death := explode.duplicate() as SpellData
	death.coef = s.coef * DECOY_DEATH_FRAC
	var flight := explode.duplicate() as SpellData
	flight.vfx_frames = "" # coups directs en vol : pas de gerbe
	flight.coef = FLIGHT_COEF
	flight.proc_coef = FLIGHT_PROC
	flight.is_zone = false
	flight.hit_force = -1.0
	var token := {"healed": false}
	var parent := player.get_parent()
	var space := player.get_world_2d().direct_space_state if player.is_inside_tree() else null
	var rideau := s.id == V_RIDEAU
	var fwd := Vector2.UP
	if rideau: # ligne perpendiculaire à la visée, dos à Rictus (poussée vers l'avant)
		fwd = _rideau_forward(aim)
	for i in DECOY_COUNT:
		var dir := first.rotated(i * TAU / DECOY_COUNT)
		var pos := origin + dir * DECOY_RING_U * Balance.UNIT_PX
		if rideau:
			dir = fwd
			pos = origin + fwd * RIDEAU_AHEAD_U * Balance.UNIT_PX + fwd.orthogonal() * (float(i) - (DECOY_COUNT - 1) * 0.5) * RIDEAU_SPACING_U * Balance.UNIT_PX
		if space != null: # position dans un mur (ou derrière) : sautée
			var q := PhysicsRayQueryParameters2D.create(origin, pos, WALL_MASK, [player.get_rid()])
			if not space.intersect_ray(q).is_empty():
				continue
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if e is Node2D and e.has_method(&"push") and not e.is_in_group(&"bosses"):
				var er: float = float(e.get(&"radius_px")) if &"radius_px" in e else 0.0
				if e.global_position.distance_to(pos) <= Decoy.RADIUS_U * Balance.UNIT_PX + er:
					e.push(dir * DECOY_BLOCK_PUSH_U * Balance.UNIT_PX)
		var d := Decoy.new()
		d.caster = _caster()
		d.max_hp = (RIDEAU_HP_FRAC if rideau else DECOY_HP_FRAC) * player.max_hp
		d.hp = d.max_hp
		d.life_s = s.duration if s.duration > 0.0 else DECOY_LIFE_S
		d.facing = dir
		d.explode_spell = explode
		d.death_spell = death
		d.flight_spell = flight
		d.on_explode = func(_d: Decoy) -> void: _on_decoy_exploded(token)
		parent.add_child(d)
		d.global_position = pos
		d.copy_look(_visual)
		d.appear()
	if spin_left > 0.0: # ultime pendant la toupie : percutées à la frame suivante (au plus tard)
		_push_decoys()


## Sens du Rideau : visée manuelle, sinon ennemi le plus proche à RIDEAU_AIM_U, sinon orientation du pantin.
func _rideau_forward(aim: Variant) -> Vector2:
	if aim != null and ((aim as Vector2) - player.global_position).length_squared() > 1.0:
		return ((aim as Vector2) - player.global_position).normalized()
	var c := _caster()
	if c != null:
		var e := c.nearest_enemy(RIDEAU_AIM_U * Balance.UNIT_PX)
		if e != null and (e.global_position - player.global_position).length_squared() > 1.0:
			return (e.global_position - player.global_position).normalized()
	return player.facing if player.facing != Vector2.ZERO else Vector2.DOWN


func _on_decoy_exploded(token: Dictionary) -> void:
	if strings != null:
		strings.vibrate(STRING_VIBRATE_S)
	if not bool(token["healed"]) and player != null and is_instance_valid(player) and not player.dead:
		token["healed"] = true
		player.heal(HEAL_PCT * player.max_hp)


# --- Nettoyage (§2.6.5 : étage, mort) ------------------------------------------------------------

func clear_transients() -> void:
	_pending_decoys = {}
	for n in pendulums.duplicate():
		if is_instance_valid(n):
			n.queue_free()
	pendulums.clear()
	Decoy.clear_all()
	for k in knives.duplicate():
		if is_instance_valid(k):
			k.queue_free()
	knives.clear()


func _on_floor_started(_n: int) -> void:
	clear_transients()


func _on_player_died() -> void:
	spin_left = 0.0
	pirouette_left = 0.0
	stagger_left = 0.0
	clear_transients()
	if strings != null:
		strings.visible = false # fils coupés
	if _visual != null and _visual.sprite_frames != null:
		var anim := _resolve(&"death", _dir_name())
		if anim != &"":
			_visual.sprite_frames.set_animation_loop(anim, false)
			_visual.play(anim)


# --- Rendu ----------------------------------------------------------------------------------------

func _dir_name() -> String:
	var i := roundi(player.facing.angle() / (TAU / 8.0)) % 8
	return DIR_NAMES[(i + 8) % 8]


## Anim `<base>_<dir>`, sinon `<base>` (spin : 1 direction), sinon &"" (le joueur garde idle/run).
func _resolve(base: StringName, dir: String) -> StringName:
	if _visual == null or _visual.sprite_frames == null:
		return &""
	# `spin` n'a qu'une direction (symétrie de rotation) : livrée `spin`, `spin_s` ou `spin_e` (M2b) selon le lot
	for a: StringName in [StringName("%s_%s" % [base, dir]), base, StringName("%s_s" % base), StringName("%s_e" % base)]:
		if _visual.sprite_frames.has_animation(a):
			return a
	return &""


## Anim du pantin (Player._update_visual) : états du kit (levée, toupie, vertige) prioritaires ; sinon
## `fallback` = anim d'action en cours (slash/throw/summon) ou idle/run_<dir>.
func visual_anim(fallback: StringName) -> StringName:
	var base := &""
	if lifting:
		base = &"lift"
	elif spin_left > 0.0 or pirouette_left > 0.0:
		base = &"spin"
	elif stagger_left > 0.0:
		base = &"stagger"
	if base != &"":
		var a := _resolve(base, _dir_name())
		if a != &"":
			return a
	return fallback


## Traînée de la toupie : enfant du pantin (même échelle, suit la levée), additive, cachée hors toupie.
func _attach_spin_blur() -> void:
	if not ResourceLoader.exists(SPIN_BLUR_FRAMES):
		return
	var sf := load(SPIN_BLUR_FRAMES) as SpriteFrames
	if sf == null or not sf.has_animation(&"default"):
		return
	spin_blur = AnimatedSprite2D.new()
	spin_blur.name = "SpinBlur"
	spin_blur.sprite_frames = sf
	spin_blur.offset = SPIN_BLUR_OFFSET
	spin_blur.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	spin_blur.material = m
	spin_blur.modulate = Color(STRING_COLOR.r * STRING_GLOW, STRING_COLOR.g * STRING_GLOW, STRING_COLOR.b * STRING_GLOW, SPIN_BLUR_ALPHA)
	spin_blur.visible = false
	_visual.add_child(spin_blur)


func _update_rig() -> void:
	if spin_blur != null:
		var on := spin_left > 0.0 or pirouette_left > 0.0
		if on != spin_blur.visible:
			spin_blur.visible = on
			if on:
				spin_blur.play(&"default")
			else:
				spin_blur.stop()
	var taut: bool = lifting or spin_left > 0.0 or pirouette_left > 0.0 or player.action_base() in ULT_ACTIONS
	if _visual != null:
		# levée : le pantin monte et redescend (arc sinus), à la hauteur LIFT_HEIGHT_U au milieu du saut
		var k := 0.0
		if lifting:
			k = sin(PI * clampf(1.0 - player.dodge_progress_left(), 0.0, 1.0))
		_visual.position.y = Iso.lift_logical(LIFT_HEIGHT_U) * k
	if companion != null:
		companion.sync(_dir_name(), &"pull" if taut else &"hover")
	if strings != null:
		strings.tension = 1.0 if taut else 0.0



# --- Passif expliqué (infobulle du HUD ; contrat KitResource.passive) ------------------------------------

static func passive_info() -> Dictionary:
	return KitResource.passive("Fils du Montreur", &"fils",
		"Pas de jauge : deux effets passifs. Les fils tirent le pantin hors des coups, et se tendent pour le réparer.",
		"",
		"",
		"Garde : -%s de dégâts subis pendant %s s après chaque demi-lune. Fils tendus : +%s des PV max rendus en fin de Toupie et à la première explosion de chaque Doublures. Pointe : chaque tick de Toupie frappe en plus l'ennemi le plus proche (coef %s)." % [
			KitResource.pct(1.0 - GUARD_TAKEN_MULT), KitResource.fmt(GUARD_S), KitResource.pct(HEAL_PCT), KitResource.fmt(TOUPIE_FOCUS_COEF)])
