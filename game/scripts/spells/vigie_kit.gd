class_name VigieKit
extends Node
## Kit de Vigie, la guetteuse de la digue (docs/Design_Personnages.md §2.8, fiche joueur docs/fiches/vigie.md).
## Archère « classique » : 4 sorts / 0 passif, ressource « Tension » (la corde bandée).
## - Tension 0-1 : se remplit seule (TENSION_MOVING_S en marchant, TENSION_STILL_S ancrée = immobile), × (1 +
##   vitesse d'attaque). Pleine : le prochain tir automatique est un « Trait d'allonge » (perce tout, 12 u) qui la vide.
## - Sort 1 Trait (auto) : flèche vers l'ennemi le plus proche ; Trait d'allonge quand la Tension est pleine.
## - Sort 2 Fusée de détresse : flèche-fusée au point visé ; une fusée de magnésium reste plantée 5 s : les monstres
##   dans sa lumière sont « exposés » (+20 % de dégâts subis, Enemy.add_damage_taken_mod).
## - Sort 3 Filet lesté : flèche lestée ; le filet s'ouvre au premier monstre (ou au point visé) : emprisonne 1,5 s
##   (boss : ralentis) et remplit la Tension (« le temps d'ajuster »).
## - Sort 4 Grêle : volée tirée au ciel ; 0,45 s après, pluie de flèches 2,5 s sur 4 u (ralentit, expose).
## Tous les sorts : Behavior.KIT (SpellCaster -> cast_spell), effet à la frame d'impact de l'anim d'action
## (Player.action_impact). Assets absents (lots Codex VG1/VG2) : Ardent teinté, flèches = couteau de Rictus,
## zones = contours ZoneEffect, fusée = lueur dessinée + vraie lumière rouge.

# --- Assets attendus (lots Codex VG1 / VG2, art/tools/night/_vg1.txt, _vg2.txt) ---------------------
const ASSET_DIR := "res://assets/sprites/characters/vigie/"
const SPRITE_FRAMES := ASSET_DIR + "vigie.tres" ## idle/run/attack/draw/brace/flare/net/volley/death _<dir>
const ARROW_FRAMES := ASSET_DIR + "arrow/arrow.tres" ## CREA 4, pointe vers +X
const ARROW_CHARGED_FRAMES := ASSET_DIR + "arrow_charged/arrow_charged.tres" ## Trait d'allonge, traînée rouge
const FLARE_ARROW_FRAMES := ASSET_DIR + "flare_arrow/flare_arrow.tres"
const NET_ARROW_FRAMES := ASSET_DIR + "net_arrow/net_arrow.tres"
const FLARE_FRAMES := ASSET_DIR + "flare/flare.tres" ## CREA : `default` (boucle), `end` facultative
const NET_BURST_FRAMES := ASSET_DIR + "net_burst/net_burst.tres" ## TOP, 6 frames, filet ouvert
const NET_BURST_RADIUS_PX := 288.0 ## rayon du filet dans la frame (TOP 96 px/u × 3 u)
const HAIL_FRAMES := ASSET_DIR + "hail_zone/hail_zone.tres" ## TOP, `default` en boucle + `end`
const HAIL_RADIUS_PX := 288.0 ## rayon de la pluie dans la frame (TOP 64 px/u × 4,5 u)
## Repli tant que VG2 n'est pas livré : la lame de Rictus (fine, pointe vers +X) plutôt que la braise d'Ardent.
const ARROW_FALLBACK := "res://assets/sprites/characters/rictus/knife/knife.tres"
const PLACEHOLDER_TINT := Color(0.62, 0.66, 0.6) ## Ardent teinté roseau / ardoise, en attendant VG1

# --- Identité ---------------------------------------------------------------------------------------
const ACCENT := Color("#FF3A4F") ## rouge de fusée de détresse (accent émissif unique)
const ZONE_COLOR := Color("#FFC21A") ## ambre : contours de toutes les zones de Vigie (fusée, chausse-trapes, filet, grêle), lisible sur sol sombre comme clair
const BODY_COLOR := Color("#5A5540") ## pèlerine de roseaux
const PLAYER_LIGHT_COLOR := Color("#E3CFC9") ## lumière du joueur : blanc de pluie à peine rosé
const PLAYER_CORE_COLOR := Color("#FF5A66") ## cœur : la mèche de fusée allumée à sa hanche

# --- Statistiques (§2.8.6) ----------------------------------------------------------------------------
const BASE_HP := 90.0
const HP_PER_LEVEL := 27.0
const ARMOR := 0.0
const BASE_REGEN := 1.0
const REGEN_PER_LEVEL := 0.2
const SPEED_U := 4.2
const HITBOX_U := 0.45

# --- Tension --------------------------------------------------------------------------------------
const TENSION_MOVING_S := 2.2 ## de 0 à pleine en marchant
const TENSION_STILL_S := 1.0 ## de 0 à pleine ancrée (immobile)
const ANCHOR_DELAY_S := 0.15 ## immobile depuis ce temps = ancrée (pas de clignotement au joystick)
const EMISSION_LOW := 0.6 ## énergie du masque _e (corde, pointes) à Tension nulle
const EMISSION_FULL := 3.2
const EMISSION_STEPS := 10

# --- Sort 1 : Trait / Trait d'allonge ---------------------------------------------------------------
const TRAIT_COEF := 0.8
const TRAIT_CD := 0.6
const TRAIT_RANGE_U := 9.0
const TRAIT_SPEED_U := 16.0
const TRAIT_PIERCE := 1 ## traverse 1 monstre (comme l'Éclat d'Ardent) : la ligne compte aussi hors allonge
const ALLONGE_COEF := 2.0
const ALLONGE_RANGE_U := 12.0
const ALLONGE_SPEED_U := 24.0
const ALLONGE_PIERCE := 30 ## « perce tout » (plafond de sécurité)
const ALLONGE_KNOCK_U := 0.8

# --- Sort 2 : Fusée de détresse ---------------------------------------------------------------------
const FUSEE_CD := 8.0
const FUSEE_COEF := 1.2 ## flèche-fusée sur le premier monstre touché
const FUSEE_RANGE_U := 9.0
const FUSEE_SPEED_U := 14.0
const FLARE_RADIUS_U := 3.0
const FLARE_LIFE_S := 5.0
const EXPOSE_MULT := 1.1 ## +10 % de dégâts subis dans la lumière (toutes sources)
const EXPOSE_ID := &"vigie_expose"
const EXPOSE_REFRESH_S := 0.2
const EXPOSE_HOLD_S := 0.35 ## durée de la marque posée à chaque rafraîchissement

# --- Sort 3 : Filet lesté ------------------------------------------------------------------------
const FILET_CD := 9.0
const FILET_COEF := 0.5 ## flèche lestée (premier monstre)
const NET_COEF := 1.2 ## ouverture du filet (zone)
const FILET_RANGE_U := 7.0
const FILET_SPEED_U := 13.0
const NET_RADIUS_U := 3.0
const NET_HOLD_S := 1.5
const NET_BOSS_SLOW_PCT := 0.4
const MIN_SHOT_U := 1.5 ## un tir visé trop près part quand même à cette distance

# --- Sort 4 : Grêle ------------------------------------------------------------------------------
const GRELE_CD := 20.0
const GRELE_COEF := 0.7 ## par volée (toutes les HAIL_TICK_S, première à l'arrivée)
const GRELE_RANGE_U := 10.0
const HAIL_RADIUS_U := 4.5
const HAIL_LIFE_S := 2.5
const HAIL_TICK_S := 0.25
const HAIL_DELAY_S := 0.45 ## temps de vol de la volée tirée au ciel
const HAIL_SLOW_PCT := 0.25
const HAIL_SLOW_S := 0.5

# --- Variantes de sorts (docs/Variantes_Sorts.md §2.9 ; CONTRACTS.md « Variantes de sorts ») -------------
const V_DOUBLE := &"vigie_tir_double"
const V_FANAL := &"vigie_fanal"
const V_CHAUSSE := &"vigie_chausse_trapes"
const V_SIGNAL := &"vigie_tir_de_signal"
## Compteurs de déblocage (RunState.add_counter -> Profile.stats ; règles « counter » de characters.json)
const COUNTER_EXPOSED := "vigie_exposed" ## monstre exposé par une Fusée de détresse (+1 par monstre et par fusée)
const COUNTER_NETTED := "vigie_netted" ## monstre immobilisé par le Filet lesté
const COUNTER_GRELE_KILLS := "vigie_grele_kills" ## monstre dont le dernier coup vient de la Grêle
const META_LAST_HIT := &"vigie_last_hit"
# Tir double : 2 flèches légères, Tension pleine -> volée de 3 traits en éventail
const DOUBLE_COEF := 0.42
const DOUBLE_RANGE_U := 8.0
const DOUBLE_PROC := 0.8
const VOLLEY_COEF := 1.2
const VOLLEY_COUNT := 3
const VOLLEY_FAN_DEG := 20.0 ## ouverture totale de l'éventail
const VOLLEY_RANGE_U := 12.0
const VOLLEY_KNOCK_U := 0.5
# Fanal : lumière attachée à Vigie ; la corde se bande « ancrée » même en marche
const FANAL_CD := 8.0
const FANAL_LIFE_S := 5.0
const FANAL_TENSION_MOVING_S := 1.0 ## marche pendant le Fanal (au lieu de 2,2)
const FANAL_TENSION_STILL_S := 0.7 ## ancrée pendant le Fanal (au lieu de 1,0)
# Chausse-trapes : champ de pointes, dégâts + ralentissement + Tension à l'entrée
const CHAUSSE_CD := 9.0
const CHAUSSE_ARROW_COEF := 0.5
const CHAUSSE_RADIUS_U := 3.0
const CHAUSSE_LIFE_S := 6.0
const CHAUSSE_ENTRY_COEF := 0.6
const CHAUSSE_ENTRY_PROC := 0.5
const CHAUSSE_SLOW_PCT := 0.5
const CHAUSSE_BOSS_SLOW_PCT := 0.25
const CHAUSSE_SLOW_S := 1.0
const CHAUSSE_TENSION := 0.25
const CHAUSSE_FRAMES := ASSET_DIR + "caltrop_field/caltrop_field.tres" ## TOP, `default` en boucle + `end`
const CHAUSSE_RADIUS_PX := 288.0 ## rayon du champ dans la frame (TOP 96 px/u x 3 u)
# Tir de signal : flèche au ciel, télégraphe, impact lourd, lumière 8 s
const SIGNAL_CD := 20.0
const SIGNAL_COEF := 7.0
const SIGNAL_RANGE_U := 10.0
const SIGNAL_RADIUS_U := 3.5
const SIGNAL_DELAY_S := 1.2
const SIGNAL_HOLD_S := 1.0
const SIGNAL_BOSS_SLOW_PCT := 0.4
const SIGNAL_BOSS_SLOW_S := 1.5
const SIGNAL_KNOCK_U := 1.5
const SIGNAL_LIGHT_S := 8.0
const SIGNAL_SHAKE_PX := 10.0
const SIGNAL_FLARE_SCALE := 1.5

# --- Anims d'action (Player.play_action) : frames d'impact (index 0) ----------------------------------
const ACTION_IMPACT_FRAMES := {&"attack": 2, &"draw": 4, &"flare": 3, &"net": 2, &"volley": 4,
	&"cast": 3, &"cast_ult": 4}
## Anim manquante (repli sur Ardent) : base générique jouée à la place, même file d'effets.
const ACTION_GENERIC := {&"attack": &"attack", &"draw": &"attack", &"flare": &"cast", &"net": &"cast",
	&"volley": &"cast_ult"}
const DIR_NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const PENDING_SAFETY_S := 1.0 ## effet jamais déclenché (anim coupée) : part quand même

var player: CharacterBody2D = null
var tension := 0.0
var still_t := 0.0 ## temps immobile continu
var flares: Array = [] ## VigieFlare plantées
var hails: Array = [] ## ZoneEffect de Grêle vivantes
var allonge_spell: SpellData = null
var _visual: AnimatedSprite2D = null
var _pending: Array = [] ## {base, fn, t}
var _timers: Array = [] ## {t, fn} (vol de la Grêle)
var _expose_t := 0.0
var _emission_step := -1
var _ready_light: LightRig.Handle = null
var _was_full := false
var _allonge_cast := false ## Trait d'allonge lancé : l'anim d'action du slot 1 est `draw`
var volley_spell: SpellData = null ## Volée d'allonge (Tir double)
var fanal_t := 0.0 ## s restantes du Fanal (Tension au rythme ancré)
var caltrops: Array = [] ## VigieCaltrops vivants
var _spike: SpellData = null


# --- Données -------------------------------------------------------------------------------------

static func _force_for(knock_u: float) -> float:
	return clampf(inverse_lerp(Balance.KB_MIN_U, Balance.KB_MAX_U, knock_u), 0.0, 1.0)


static func _frames_or_fallback(path: String) -> String:
	return path if ResourceLoader.exists(path) else ARROW_FALLBACK


static func _spell(sid: StringName, name: String, slot: int, coef: float, cd: float) -> SpellData:
	var s := SpellData.new()
	s.id = sid
	s.display_name = name
	s.slot = slot
	s.behavior = SpellData.Behavior.KIT
	s.coef = coef
	s.base_cooldown = cd
	s.element = &"physical"
	s.color = ACCENT
	s.zone_outline_color = ZONE_COLOR
	s.light_preset = &"vigie_arrow"
	return s


## Trait d'allonge : tir automatique chargé (hors barre de sorts : même slot 1, bonus d'auto).
static func make_allonge() -> SpellData:
	var a := _spell(&"vigie_allonge", "Trait d'allonge", 1, ALLONGE_COEF, TRAIT_CD)
	a.is_auto = true
	a.is_zone = false
	a.range_u = ALLONGE_RANGE_U
	a.speed_u = ALLONGE_SPEED_U
	a.pierce = ALLONGE_PIERCE
	a.item_pierce = false
	a.proc_coef = 1.0
	a.hit_force = _force_for(ALLONGE_KNOCK_U)
	a.light_preset = &"vigie_allonge"
	a.projectile_frames = _frames_or_fallback(ARROW_CHARGED_FRAMES)
	return a


static func character() -> CharacterData:
	var c := CharacterData.new()
	c.id = &"vigie"
	c.display_name = "Vigie"
	c.base_hp = BASE_HP
	c.hp_per_level = HP_PER_LEVEL
	c.armor = ARMOR
	c.base_regen = BASE_REGEN
	c.regen_per_level = REGEN_PER_LEVEL
	c.base_speed_u = SPEED_U
	c.hitbox_u = HITBOX_U
	c.kit_script = VigieKit
	c.sprite_frames_path = SPRITE_FRAMES
	c.placeholder_tint = PLACEHOLDER_TINT
	c.body_color = BODY_COLOR
	c.accent_color = ACCENT
	c.light_color = PLAYER_LIGHT_COLOR
	c.light_core_color = PLAYER_CORE_COLOR
	c.action_impact_frames = ACTION_IMPACT_FRAMES

	var s1 := _spell(&"vigie_trait", "Trait", 1, TRAIT_COEF, TRAIT_CD)
	s1.is_auto = true
	s1.is_zone = false
	s1.range_u = TRAIT_RANGE_U
	s1.trigger_range_u = TRAIT_RANGE_U
	s1.speed_u = TRAIT_SPEED_U
	s1.pierce = TRAIT_PIERCE
	s1.proc_coef = 1.0
	s1.projectile_frames = _frames_or_fallback(ARROW_FRAMES)

	var s2 := _spell(&"vigie_fusee", "Fusée de détresse", 2, FUSEE_COEF, FUSEE_CD)
	s2.is_zone = false
	s2.range_u = FUSEE_RANGE_U
	s2.radius_u = FLARE_RADIUS_U
	s2.duration = FLARE_LIFE_S
	s2.speed_u = FUSEE_SPEED_U
	s2.proc_coef = 1.0
	s2.trigger_range_u = 7.0
	s2.target_mode = &"densest"
	s2.rests_on_ground = true
	s2.light_preset = &"vigie_flare"
	s2.projectile_frames = _frames_or_fallback(FLARE_ARROW_FRAMES)

	var s3 := _spell(&"vigie_filet", "Filet lesté", 3, FILET_COEF, FILET_CD)
	s3.is_zone = false
	s3.range_u = FILET_RANGE_U
	s3.radius_u = NET_RADIUS_U
	s3.speed_u = FILET_SPEED_U
	s3.proc_coef = 0.5
	s3.trigger_range_u = 5.0
	s3.target_mode = &"densest"
	s3.rests_on_ground = true
	s3.light_preset = &"vigie_net"
	s3.projectile_frames = _frames_or_fallback(NET_ARROW_FRAMES)

	var s4 := _spell(&"vigie_grele", "Grêle", 4, GRELE_COEF, GRELE_CD)
	s4.range_u = GRELE_RANGE_U
	s4.radius_u = HAIL_RADIUS_U
	s4.duration = HAIL_LIFE_S
	s4.tick = HAIL_TICK_S
	s4.proc_coef = 0.25 ## équilibrage 23/10 : 0,4 -> 0,25
	s4.trigger_range_u = 7.0
	s4.target_mode = &"densest"
	s4.light_preset = &"vigie_hail"
	s4.vfx_frames = HAIL_FRAMES
	s4.vfx_radius_px = HAIL_RADIUS_PX
	s4.vfx_floor_aspect = 1.0 # rig TOP : jamais pré-écrasé

	c.spells = [s1, s2, s3, s4]
	return c


## Zone d'ouverture du filet (instantanée, dégâts NET_COEF).
static func make_net_burst() -> SpellData:
	var n := _spell(&"vigie_filet_burst", "Filet lesté", 3, NET_COEF, FILET_CD)
	n.radius_u = NET_RADIUS_U
	n.proc_coef = 0.5
	n.hit_force = 0.0 # le filet tient, il ne repousse pas
	n.light_preset = &"vigie_net"
	n.vfx_frames = NET_BURST_FRAMES
	n.vfx_radius_px = NET_BURST_RADIUS_PX
	n.vfx_floor_aspect = 1.0
	return n


## Volée d'allonge du Tir double (hors barre de sorts : même slot 1, bonus d'auto).
static func make_volley() -> SpellData:
	var a := _spell(&"vigie_volee", "Volée d'allonge", 1, VOLLEY_COEF, TRAIT_CD)
	a.is_auto = true
	a.is_zone = false
	a.range_u = VOLLEY_RANGE_U
	a.speed_u = ALLONGE_SPEED_U
	a.pierce = ALLONGE_PIERCE
	a.item_pierce = false
	a.proc_coef = 1.0
	a.hit_force = _force_for(VOLLEY_KNOCK_U)
	a.light_preset = &"vigie_allonge"
	a.projectile_frames = _frames_or_fallback(ARROW_CHARGED_FRAMES)
	return a


## Entrée dans le champ de pointes (Chausse-trapes) : un coup de CHAUSSE_ENTRY_COEF, sans recul.
static func make_spike() -> SpellData:
	var n := _spell(&"vigie_pointes", "Chausse-trapes", 3, CHAUSSE_ENTRY_COEF, CHAUSSE_CD)
	n.proc_coef = CHAUSSE_ENTRY_PROC
	n.hit_force = 0.0
	n.light_preset = &""
	return n


## Variantes (contrat CONTRACTS.md) : SpellData de la variante `variant_id` pour `slot`, ou null (non codée).
## Coefficients ajustés par balance_sim (+-15 % du sort de base en DPS cible et zone) ; le style ne change pas.
static func variant(slot: int, variant_id: StringName) -> SpellData:
	match [slot, variant_id]:
		[1, V_DOUBLE]:
			var s1 := _spell(V_DOUBLE, "Tir double", 1, DOUBLE_COEF, TRAIT_CD)
			s1.is_auto = true
			s1.is_zone = false
			s1.range_u = DOUBLE_RANGE_U
			s1.trigger_range_u = DOUBLE_RANGE_U
			s1.speed_u = TRAIT_SPEED_U
			s1.pierce = 0
			s1.proc_coef = DOUBLE_PROC
			s1.projectile_frames = _frames_or_fallback(ARROW_FRAMES)
			return s1
		[2, V_FANAL]:
			var s2 := _spell(V_FANAL, "Fanal", 2, 0.0, FANAL_CD)
			s2.is_zone = false
			s2.range_u = 3.0
			s2.radius_u = FLARE_RADIUS_U
			s2.duration = FANAL_LIFE_S
			s2.trigger_range_u = 4.0
			s2.target_mode = &"nearest"
			s2.light_preset = &"vigie_flare"
			return s2
		[3, V_CHAUSSE]:
			var s3 := _spell(V_CHAUSSE, "Chausse-trapes", 3, CHAUSSE_ARROW_COEF, CHAUSSE_CD)
			s3.is_zone = false
			s3.range_u = FILET_RANGE_U
			s3.radius_u = CHAUSSE_RADIUS_U
			s3.duration = CHAUSSE_LIFE_S
			s3.speed_u = FILET_SPEED_U
			s3.proc_coef = 0.5
			s3.trigger_range_u = 5.0
			s3.target_mode = &"densest"
			s3.rests_on_ground = true
			s3.light_preset = &"vigie_net"
			s3.projectile_frames = _frames_or_fallback(NET_ARROW_FRAMES)
			return s3
		[4, V_SIGNAL]:
			var s4 := _spell(V_SIGNAL, "Tir de signal", 4, SIGNAL_COEF, SIGNAL_CD)
			s4.range_u = SIGNAL_RANGE_U
			s4.radius_u = SIGNAL_RADIUS_U
			s4.duration = 0.0 # impact instantané (coup direct, recul radial)
			s4.proc_coef = 1.0
			s4.trigger_range_u = 8.0
			s4.target_mode = &"densest"
			s4.hit_force = _force_for(SIGNAL_KNOCK_U)
			s4.light_preset = &"vigie_hail"
			return s4
	return null


# --- Mise en place ------------------------------------------------------------------------------

var _net_burst: SpellData = null


func setup(p: CharacterBody2D) -> void:
	player = p
	_visual = p.get_node_or_null(^"Visual") as AnimatedSprite2D
	allonge_spell = make_allonge()
	_net_burst = make_net_burst()
	volley_spell = make_volley()
	_spike = make_spike()
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.floor_started.connect(_on_floor_started)
	Events.player_died.connect(_on_player_died)
	if p.has_signal(&"action_impact"):
		p.action_impact.connect(_on_action_impact)
	_ready_light = LightRig.attach(p, &"vigie_tension")
	if _ready_light != null:
		_ready_light.set_enabled(false)
	_update_emission()


func _exit_tree() -> void:
	for pair in [[Events.floor_started, _on_floor_started], [Events.player_died, _on_player_died],
			[Events.enemy_killed, _on_enemy_killed]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	if _ready_light != null:
		LightRig.detach(_ready_light)
		_ready_light = null
	clear_transients()


func _caster() -> SpellCaster:
	return player.spells if player != null else null


func _spell_of(slot: int) -> SpellData:
	for sp in player.character.spells:
		if sp.slot == slot:
			return sp
	return null


# --- Tension (ressource) ----------------------------------------------------------------------------

func is_full() -> bool:
	return tension >= 1.0


func is_anchored() -> bool:
	return still_t >= ANCHOR_DELAY_S


## Remplissage par seconde (0-1/s) : ancrée ou en marche, accéléré par la vitesse d'attaque des items.
func tension_rate() -> float:
	var base_s := TENSION_STILL_S if is_anchored() else TENSION_MOVING_S
	if fanal_t > 0.0: # Fanal : la corde se bande au rythme ancré même en marche, plus vite ancrée
		base_s = FANAL_TENSION_STILL_S if is_anchored() else FANAL_TENSION_MOVING_S
	return (1.0 + maxf(player.stat(&"attack_speed"), 0.0)) / base_s


func set_tension(v: float) -> void:
	tension = clampf(v, 0.0, 1.0)
	_update_emission()


## Contrat KitResource : jauge continue, « PRÊTE » qui pulse quand le Trait d'allonge est armé.
func resource_state() -> Dictionary:
	var txt := "PRÊTE" if is_full() else "%d %%" % floori(tension * 100.0)
	return KitResource.make(&"tension", "Tension", tension, ACCENT, {"text": txt, "boost": is_full()})


func save_state() -> Dictionary:
	return {"tension": tension}


func load_state(d: Dictionary) -> void:
	set_tension(float(d.get("tension", 0.0)))


## Corde et pointes (masque _e) : l'énergie suit la Tension, par paliers (pas de réécriture par image).
func _update_emission() -> void:
	if _visual == null:
		return
	var step := roundi(tension * EMISSION_STEPS)
	if step == _emission_step:
		return
	_emission_step = step
	NormalMaps.set_emission_energy(_visual, lerpf(EMISSION_LOW, EMISSION_FULL, float(step) / EMISSION_STEPS))


# --- Hooks du joueur et de SpellCaster ----------------------------------------------------------

func blocks_slot(_slot: int) -> bool:
	return false


func can_dodge() -> bool:
	return true


## Auto-cast (accessibilité, simulateur) : le Filet sert à recharger la Tension, pas à la gâcher.
func auto_cast_ok(slot: int) -> bool:
	if slot == 3:
		return tension < 0.5
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
	still_t = 0.0


func on_cast(_s: SpellData) -> void:
	_allonge_cast = false


## Anim d'action de chaque sort (base livrée par VG1, sinon base générique d'Ardent).
func action_for(s: SpellData) -> StringName:
	match s.slot:
		1:
			return _act(&"draw" if _allonge_cast or s.id == &"vigie_allonge" or s.id == &"vigie_volee" else &"attack")
		2:
			return _act(&"flare")
		3:
			return _act(&"net")
		4:
			return _act(&"volley")
	return &""


func _act(base: StringName) -> StringName:
	if _visual != null and _visual.sprite_frames != null:
		if _visual.sprite_frames.has_animation(StringName("%s_s" % base)) or _visual.sprite_frames.has_animation(base):
			return base
	return ACTION_GENERIC.get(base, base)


## Lancement (SpellCaster, Behavior.KIT) : la visée est figée au lancement, l'effet part à la frame d'impact.
func cast_spell(s: SpellData, aim: Variant) -> bool:
	if player == null or player.dead:
		return false
	var c := _caster()
	var origin := player.global_position
	match s.slot:
		1:
			if s.id == V_DOUBLE:
				return _cast_double(s, c, origin)
			var shot: SpellData = allonge_spell if is_full() else s
			var target := c.nearest_enemy(c.range_px(shot))
			if target == null:
				return false # l'auto ne consomme rien sans cible
			var dir := (target.global_position - origin).normalized()
			if dir != Vector2.ZERO:
				player.facing = dir
			if shot == allonge_spell:
				set_tension(0.0) # la corde se relâche au lancement (jamais deux allonges)
				_set_ready_fx(false)
				_allonge_cast = true # action_for (Player.on_cast, juste après) joue `draw`
			_queue(action_for(s), func() -> void: c.fire_at(shot, target, dir))
		2, 3:
			if s.id == V_FANAL:
				_queue(action_for(s), func() -> void: start_fanal())
				return true
			var at := _aim_point(aim, s)
			var dir := at - origin
			if dir.length_squared() < 1.0:
				dir = player.facing if player.facing != Vector2.ZERO else Vector2.DOWN
			player.facing = dir.normalized()
			var shot := s.duplicate() as SpellData # portée = distance du point visé (la flèche s'y pose)
			shot.range_u = maxf(dir.length(), MIN_SHOT_U * Balance.UNIT_PX) / (Balance.UNIT_PX * (1.0 + player.stat(&"range_add")))
			var fdir := dir.normalized()
			_queue(action_for(s), func() -> void: c.fire_at(shot, null, fdir))
		4:
			var at := _aim_point(aim, s)
			if (at - origin).length_squared() > 1.0:
				player.facing = (at - origin).normalized()
			if s.id == V_SIGNAL:
				_queue(action_for(s), func() -> void: _launch_signal(s, at))
			else:
				_queue(action_for(s), func() -> void: _launch_hail(s, at))
		_:
			return false
	return true


## Point visé : souris / stick / paquet le plus dense (SpellCaster), sinon ennemi le plus proche, sinon devant ;
## limité à la portée du sort.
func _aim_point(aim: Variant, s: SpellData) -> Vector2:
	var o := player.global_position
	var c := _caster()
	var at: Variant = aim
	if at == null:
		var t := c.nearest_enemy(c.range_px(s))
		if t != null:
			at = t.global_position
	if at == null:
		var f: Vector2 = player.facing if player.facing != Vector2.ZERO else Vector2.DOWN
		at = o + f * 4.0 * Balance.UNIT_PX
	return o + ((at as Vector2) - o).limit_length(c.range_px(s))


## Fusée et filet : la flèche se pose au premier monstre touché (rests_on_hit) ou au bout de sa course.
func rests_on_hit(s: SpellData) -> bool:
	return s.id == &"vigie_fusee" or s.id == &"vigie_filet" or s.id == V_CHAUSSE


func on_projectile_rest(s: SpellData, at: Vector2, _group: Dictionary) -> void:
	if player == null or player.dead:
		return
	match s.id:
		&"vigie_fusee":
			plant_flare(at)
		&"vigie_filet":
			open_net(at)
		V_CHAUSSE:
			plant_caltrops(s, at)


func _queue(base: StringName, fn: Callable) -> void:
	_pending.append({"base": base, "fn": fn, "t": 0.0})


func _on_action_impact(base: StringName) -> void:
	if _pending.is_empty():
		return
	var keep: Array = []
	var fire: Array = []
	for p in _pending:
		(fire if p["base"] == base else keep).append(p)
	_pending = keep
	for p in fire:
		if player != null and not player.dead:
			(p["fn"] as Callable).call()


func has_pending() -> bool:
	return not _pending.is_empty()


func flush_pending() -> void:
	var all := _pending
	_pending = []
	for p in all:
		(p["fn"] as Callable).call()


# --- Effets --------------------------------------------------------------------------------------

## Fusée de magnésium plantée : lumière rouge FLARE_LIFE_S, expose les monstres dans FLARE_RADIUS_U.
func plant_flare(at: Vector2) -> Node2D:
	var c := _caster()
	var f := VigieFlare.new()
	c.effects_parent().add_child(f)
	f.setup(at, flare_radius_px(), FLARE_LIFE_S, FLARE_FRAMES, ACCENT)
	flares.append(f)
	LightRig.flash(at, &"vigie_flare", 0.35, {"radius": 1.4})
	_expose_t = 0.0
	return f


func flare_radius_px() -> float:
	return FLARE_RADIUS_U * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))


func net_radius_px() -> float:
	return NET_RADIUS_U * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))


## Filet : emprisonne (boss : ralentit) puis frappe la zone ; la Tension est pleine (« le temps d'ajuster »).
func open_net(at: Vector2) -> void:
	var r := net_radius_px()
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"apply_status"):
			continue
		if (e as Node2D).global_position.distance_to(at) > r:
			continue
		if e.get(&"is_boss") == true:
			e.apply_status(&"slow", {"pct": NET_BOSS_SLOW_PCT, "duration": NET_HOLD_S})
		else:
			e.apply_status(&"imprisoned", {"duration": NET_HOLD_S})
			RunState.add_counter(COUNTER_NETTED) # déblocage des Chausse-trapes
	_caster().spawn_zone(_net_burst, at)
	_net_outline(at, r)
	LightRig.flash(at, &"vigie_net", 0.3)
	set_tension(1.0)
	_set_ready_fx(true)


## Cercle du filet pendant l'emprisonnement (le burst est instantané : pas de ZoneOutline propre). Hôte jetable.
func _net_outline(at: Vector2, r: float) -> ZoneOutline:
	var host := Node2D.new()
	host.name = "NetZone"
	_caster().effects_parent().add_child(host)
	host.global_position = at
	var o := ZoneOutline.attach(host, r, ZONE_COLOR, NET_HOLD_S)
	if o != null:
		o.emphasize()
	player.get_tree().create_timer(NET_HOLD_S + 0.2).timeout.connect(host.queue_free)
	return o


## Tir double : deux flèches sur les deux monstres les plus proches ; Tension pleine : volée de trois traits.
func _cast_double(s: SpellData, c: SpellCaster, origin: Vector2) -> bool:
	var full := is_full()
	var shot: SpellData = volley_spell if full else s
	var near: Array = c.nearest_enemies(origin, c.range_px(shot), 2)
	if near.is_empty():
		return false # l'auto ne consomme rien sans cible
	var first: Node2D = near[0]
	var second: Node2D = near[1] if near.size() > 1 else first
	var dir := (first.global_position - origin).normalized()
	if dir != Vector2.ZERO:
		player.facing = dir
	if full:
		set_tension(0.0)
		_set_ready_fx(false)
		_allonge_cast = true
		_queue(action_for(s), func() -> void: fire_volley(shot, dir))
	else:
		var dir2 := (second.global_position - origin).normalized()
		_queue(action_for(s), func() -> void:
			c.fire_at(shot, first, dir)
			c.fire_at(shot, second, dir2))
	return true


## Volée d'allonge : VOLLEY_COUNT traits en éventail de VOLLEY_FAN_DEG centré sur `dir`.
func fire_volley(shot: SpellData, dir: Vector2) -> void:
	var c := _caster()
	for i in VOLLEY_COUNT:
		var k := 0.0 if VOLLEY_COUNT <= 1 else (float(i) / float(VOLLEY_COUNT - 1) - 0.5)
		c.fire_at(shot, null, dir.rotated(deg_to_rad(VOLLEY_FAN_DEG) * k))


## Fanal : la lumière de la fusée suit Vigie FANAL_LIFE_S ; la Tension se bande au rythme ancré.
func start_fanal() -> Node2D:
	for f in flares.duplicate():
		if is_instance_valid(f) and f.follow != null:
			f.queue_free()
			flares.erase(f)
	var c := _caster()
	var f := VigieFlare.new()
	c.effects_parent().add_child(f)
	f.setup(player.global_position, flare_radius_px(), FANAL_LIFE_S, FLARE_FRAMES, ACCENT)
	f.follow = player
	flares.append(f)
	fanal_t = FANAL_LIFE_S
	LightRig.flash(player.global_position, &"vigie_flare", 0.35, {"radius": 1.4})
	_expose_t = 0.0
	return f


## Chausse-trapes : champ de pointes posé là où la flèche s'est arrêtée.
func plant_caltrops(s: SpellData, at: Vector2) -> Node2D:
	var f := VigieCaltrops.new()
	_caster().effects_parent().add_child(f)
	f.setup(self, _spike, at, CHAUSSE_RADIUS_U * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add")),
			s.duration if s.duration > 0.0 else CHAUSSE_LIFE_S)
	caltrops.append(f)
	LightRig.flash(at, &"vigie_net", 0.3)
	return f


## Entrée d'un monstre dans les pointes (VigieCaltrops) : la corde se bande.
func on_caltrop_entry(_enemy: Node2D) -> void:
	set_tension(tension + CHAUSSE_TENSION)
	if is_full():
		_set_ready_fx(true)


## Tir de signal : télégraphe SIGNAL_DELAY_S au point visé, puis l'impact.
func _launch_signal(s: SpellData, at: Vector2) -> void:
	var tg := VigieTelegraph.new()
	_caster().effects_parent().add_child(tg)
	var r: float = SIGNAL_RADIUS_U * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))
	tg.setup(at, r, SIGNAL_DELAY_S, ACCENT)
	_timers.append({"t": SIGNAL_DELAY_S, "fn": func() -> void: signal_impact(s, at)})


func signal_impact(s: SpellData, at: Vector2) -> void:
	if player == null or player.dead:
		return
	var r: float = SIGNAL_RADIUS_U * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"apply_status"):
			continue
		if (e as Node2D).global_position.distance_to(at) > r:
			continue
		if e.get(&"is_boss") == true:
			e.apply_status(&"slow", {"pct": SIGNAL_BOSS_SLOW_PCT, "duration": SIGNAL_BOSS_SLOW_S})
		else:
			e.apply_status(&"imprisoned", {"duration": SIGNAL_HOLD_S})
	_caster().spawn_zone(s, at)
	LightRig.flash(at, &"vigie_hail", 0.5)
	var f := VigieFlare.new()
	_caster().effects_parent().add_child(f)
	f.setup(at, r, SIGNAL_LIGHT_S, FLARE_FRAMES, ACCENT)
	f.set_visual_scale(SIGNAL_FLARE_SCALE)
	f.counts_exposed = false
	flares.append(f)
	_expose_t = 0.0
	_shake(SIGNAL_SHAKE_PX)


func _shake(px: float) -> void:
	var n := player.get_parent()
	while n != null:
		if n.has_method(&"shake"):
			n.shake(px, 22.0, 0.2)
			return
		n = n.get_parent()


## Dernier coup porté par la Grêle (déblocage du Tir de signal : monstres tués par la Grêle).
func on_spell_hit(s: SpellData, enemy: Node, _amount: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if s.id == &"vigie_grele":
		enemy.set_meta(META_LAST_HIT, true)
	elif enemy.has_meta(META_LAST_HIT):
		enemy.remove_meta(META_LAST_HIT)


func _on_enemy_killed(enemy: Node2D, _pos: Vector2, _tier: int, _elite: bool) -> void:
	if enemy != null and is_instance_valid(enemy) and enemy.has_meta(META_LAST_HIT):
		RunState.add_counter(COUNTER_GRELE_KILLS)


## Grêle : la volée part au ciel à la frame d'impact, la pluie tombe HAIL_DELAY_S plus tard.
func _launch_hail(s: SpellData, at: Vector2) -> void:
	var tg := VigieTelegraph.new() # télégraphe de la zone pendant le vol de la volée
	_caster().effects_parent().add_child(tg)
	tg.setup(at, s.radius_u * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add")), HAIL_DELAY_S, ZONE_COLOR)
	_timers.append({"t": HAIL_DELAY_S, "fn": func() -> void: spawn_hail(s, at)})


func spawn_hail(s: SpellData, at: Vector2) -> Node2D:
	var z := _caster().spawn_zone(s, at)
	var ho := ZoneOutline.of(z)
	if ho != null:
		ho.emphasize()
	hails.append(z)
	LightRig.flash(at, &"vigie_hail", 0.4)
	_expose_t = 0.0
	return z


## Lumière de la fusée et pluie de la Grêle : marque d'exposition rafraîchie ; la Grêle ralentit en plus.
func _expose_tick() -> void:
	var live_f: Array = []
	for f in flares:
		if is_instance_valid(f) and not f.is_ending():
			live_f.append(f)
	var live_h: Array = []
	for z in hails:
		if is_instance_valid(z) and not z.is_ending():
			live_h.append(z)
	if live_f.is_empty() and live_h.is_empty():
		return
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e):
			continue
		var p: Vector2 = (e as Node2D).global_position
		var lit := false
		for f in live_f:
			if p.distance_to(f.global_position) <= float(f.radius):
				lit = true
				if f.counts_exposed and not f.seen.has(e.get_instance_id()):
					f.seen[e.get_instance_id()] = true
					RunState.add_counter(COUNTER_EXPOSED) # déblocage du Fanal
				break
		var hailed := false
		for z in live_h:
			if p.distance_to(z.global_position) <= float(z.radius):
				hailed = true
				break
		if (lit or hailed) and e.has_method(&"add_damage_taken_mod"):
			e.add_damage_taken_mod(EXPOSE_ID, EXPOSE_MULT, EXPOSE_HOLD_S)
		if hailed and e.has_method(&"apply_status"):
			e.apply_status(&"slow", {"pct": HAIL_SLOW_PCT, "duration": HAIL_SLOW_S})


## Allonge armée : petite lueur rouge sur la corde (lumière vigie_tension).
func _set_ready_fx(on: bool) -> void:
	if _ready_light != null:
		_ready_light.set_enabled(on)
	if on and not _was_full and player != null:
		LightRig.flash(player.global_position, &"vigie_tension", 0.25, {"radius": 1.6})
	_was_full = on


# --- Boucle (Player.tick, avant les sorts) -------------------------------------------------------

func tick(delta: float) -> void:
	if player == null or player.dead:
		return
	if player.is_moving or player.is_dodging():
		still_t = 0.0
	else:
		still_t += delta
	if not is_full():
		set_tension(tension + tension_rate() * delta)
		if is_full():
			_set_ready_fx(true)
	fanal_t = maxf(fanal_t - delta, 0.0)
	_expose_t -= delta
	if _expose_t <= 0.0:
		_expose_t = EXPOSE_REFRESH_S
		_expose_tick()
	for i in range(_timers.size() - 1, -1, -1):
		var tm: Dictionary = _timers[i]
		tm["t"] = float(tm["t"]) - delta
		if float(tm["t"]) <= 0.0:
			_timers.remove_at(i)
			(tm["fn"] as Callable).call()
	for p in _pending.duplicate():
		p["t"] = float(p["t"]) + delta
		if float(p["t"]) > PENDING_SAFETY_S:
			_pending.erase(p)
			(p["fn"] as Callable).call()
	flares = flares.filter(func(f): return is_instance_valid(f))
	hails = hails.filter(func(z): return is_instance_valid(z))
	caltrops = caltrops.filter(func(z): return is_instance_valid(z))


# --- Nettoyage -----------------------------------------------------------------------------------

func clear_transients() -> void:
	_pending = []
	_timers = []
	for f in flares:
		if is_instance_valid(f):
			f.queue_free()
	flares.clear()
	for z in hails:
		if is_instance_valid(z):
			z.queue_free()
	hails.clear()
	for z in caltrops:
		if is_instance_valid(z):
			z.queue_free()
	caltrops.clear()
	fanal_t = 0.0


func _on_floor_started(_n: int) -> void:
	clear_transients() # la Tension est gardée d'un étage à l'autre


func _on_player_died() -> void:
	clear_transients()
	_set_ready_fx(false)
	if _visual != null and _visual.sprite_frames != null:
		var anim := StringName("death_" + _dir_of(player.facing))
		if _visual.sprite_frames.has_animation(anim):
			_visual.sprite_frames.set_animation_loop(anim, false)
			_visual.play(anim)


# --- Rendu ----------------------------------------------------------------------------------------

func _dir_of(v: Vector2) -> String:
	if v == Vector2.ZERO:
		v = Vector2.DOWN
	var i := roundi(v.angle() / (TAU / 8.0)) % 8
	return DIR_NAMES[(i + 8) % 8]


## Ancrée (immobile, sans action) : `brace` (arc à demi bandé) si VG1 l'a livrée ; sinon idle/run/action.
func visual_anim(fallback: StringName) -> StringName:
	if is_anchored() and player.action_base() == &"" and _visual != null and _visual.sprite_frames != null:
		var a := StringName("brace_" + _dir_of(player.facing))
		if _visual.sprite_frames.has_animation(a):
			return a
	return fallback



# --- Passif expliqué (infobulle du HUD ; contrat KitResource.passive) ------------------------------------

static func passive_info() -> Dictionary:
	var f := KitResource.fmt
	return KitResource.passive("Tension", &"tension",
		"La corde de Vigie se bande toute seule. Pleine, elle arme ton prochain tir automatique.",
		"0 à 100 %% en %s s en marchant, %s s immobile (ancrée) ; la vitesse d'attaque accélère le tout. Le Filet lesté la remplit d'un coup." % [f.call(TENSION_MOVING_S), f.call(TENSION_STILL_S)],
		"le tir qui part à 100 % relâche la corde : retour à 0.",
		"à 100 %% (« PRÊTE »), le Trait devient un Trait d'allonge : dégâts ×%s (coef %s au lieu de %s), perce tous les monstres, portée %s u au lieu de %s." % [
			f.call(ALLONGE_COEF / TRAIT_COEF), f.call(ALLONGE_COEF), f.call(TRAIT_COEF), f.call(ALLONGE_RANGE_U), f.call(TRAIT_RANGE_U)])
