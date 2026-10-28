extends Node2D
## Scène de jeu : assemble et branche tous les systèmes d'une run.
##
## Ordre de construction (après l'écran de chargement, qui couvre la préchauffe des pools) :
##   AmbianceManager (crée la couche des télégraphes) → Director (pools préchauffés) →
##   DamageNumbers + EnemyHealthBars (sous AmbianceManager.telegraph_layer) → Pickups → Stage → Player → HUD.
## Branchement des cartes, une seule fois par étage, sans les auto-détections :
##   - Director.bind_map : appelé par StageManager.start_stage juste après l'ajout de la carte
##     (l'auto-détection du Director retrouve alors la même carte et ne refait rien) ;
##   - AmbianceManager.bind_map : ici, à stage_started (auto_bind désactivé : pas de double profil) ;
##   - Audio.start_map : ici, à stage_started (Audio.auto_start_map = false).
## Foudre : AmbianceManager.lightning_struck → Events.lightning_struck ; thunder → Audio.thunder_after ;
## shake_requested → secousse de la caméra du joueur. Limites de caméra = StageManager.get_bounds().
##
## Sauvegarde (docs/Design_Menus.md §6.1, RunSave) : `resume_data` non vide = reprise (RunState, étage
## via StageManager.from_dict, joueur, coffre en attente, puis RunState.rng.state). Autosave toutes
## les 15 s de jeu actif, à l'ouverture de la pause, à chaque item choisi, en arrière-plan / perte de
## focus / fermeture de fenêtre, et par « Sauvegarder et quitter ». Monstres vivants non sauvegardés.
## En headless, rien n'est écrit sauf si `saves_in_headless` (tests, avec un `save_path` de test).
## Fin de run (victoire / mort / abandon) : sauvegarde supprimée, Profile.add_run_result, récap
## EndRunScreen (§3.10) → « Continuer » (title_requested) ou « Rejouer » (replay_requested).
## Reprise après pause : 1,5 s de protection.

signal game_ready ## préchauffe terminée, étage lancé
signal run_ended(victory: bool, rubies: int)
## Relance (compatibilité) : émis par restart() hors scène courante quand personne n'écoute replay_requested.
signal restart_requested
signal title_requested ## « Continuer » du récap, « Sauvegarder et quitter » : retour au titre (App)
signal replay_requested ## « Rejouer » du récap : même personnage, même mode (App)

const AMBIANCE := "res://scenes/ambiance/ambiance_manager.tscn"
const PLAYER := "res://scenes/player/player.tscn"
const DIRECTOR := "res://scenes/enemies/director.tscn"
const PICKUPS := "res://scenes/pickups/pickup_manager.tscn"
const DAMAGE_NUMBERS := "res://scenes/fx/damage_numbers.tscn"
const HUD := "res://scenes/ui/hud.tscn"
const CHEST_UI := "res://scenes/ui/chest/chest_ui.tscn"
const APP_SCENE := "res://scenes/app.tscn"
const SAVE_PATH := RunSave.PATH
const AUTOSAVE_INTERVAL_S := 15.0
const RESUME_PROTECTION_S := 1.5
const DEATH_SCREEN_DELAY_S := 1.2
const THUNDER_MAX_DISTANCE := 6.0

@export var run_mode: StringName = &"moyen"
@export var run_seed := 0
## Optionnel : carte unique imposée (tests). Sinon, les cartes de data/maps tournent.
@export var map_scene: PackedScene = null
## Reprise : champ `data` d'une sauvegarde (RunSave.load()["data"]). Vide = nouvelle run.
@export var resume_data: Dictionary = {}
## Chemin de sauvegarde (vide = RunSave.PATH) ; les tests passent un user://test_….
@export var save_path := ""
## Autorise l'écriture de la sauvegarde en headless (tests uniquement).
@export var saves_in_headless := false

var ambiance: AmbianceManager
var director: Node
## Monde trié en profondeur (docs/Design_Isometrique.md §2.3) : carte, joueur, monstres du Director.
var world: Node2D
var stage: StageManager
var player: Node2D
var camera: Camera2D
var hud: Node
var pickups: Node
var damage_numbers: Node
var health_bars: EnemyHealthBars
var is_ready := false
var run_over := false
var pillars_done := 0
var last_rubies := 0
var last_unlocks: Array[StringName] = []
var _final_boss_time_s := 0.0 ## temps actif à l'abattage du boss final (étage final nettoyé) ; 0 = pas encore
var end_screen: RunScreens = null ## EndRunScreen (hérite de RunScreens)
var victory_screen: RunScreens = null
var autosave_timer: Timer
var floor_card: FloorCard = null ## carton de transition d'étage en cours

var _loading: RunScreens
var _dying := false
var _shake_amp := 0.0
var _shake_hz := 0.0
var _shake_left := 0.0
var _shake_total := 0.0
var _shake_t := 0.0


func _ready() -> void:
	LightRig.clear_all() # demandes statiques d'une run précédente (relance)
	if resume_data.is_empty():
		RunState.start_run(run_mode, run_seed)
	else:
		RunState.from_dict(resume_data.get("run", {}))
		run_mode = RunState.mode
		pillars_done = int(resume_data.get("run", {}).get("pillars_done", 0))
	Events.run_started.emit(not resume_data.is_empty()) # journal de run (RunLog) : avant le premier floor_started
	RunState.running = false # le temps actif ne court qu'une fois l'étage lancé
	Audio.auto_start_map = false
	Audio.thunder_driven = true
	GameSettings.apply_graphics()
	_loading = RunScreens.loading()
	add_child(_loading)
	# Deux images : l'écran de chargement est affiché avant la préchauffe (bloquante) des pools.
	await get_tree().process_frame
	await get_tree().process_frame
	_build()
	_loading.queue_free()
	_loading = null
	RunState.running = true
	is_ready = true
	_start_autosave()
	game_ready.emit()
	var pc: Variant = resume_data.get("pending_chest")
	if pc is Dictionary and not (pc as Dictionary).is_empty():
		_reopen_chest(pc)


func _build() -> void:
	ambiance = load(AMBIANCE).instantiate() as AmbianceManager
	ambiance.auto_bind = false
	add_child(ambiance)
	ambiance.lightning_struck.connect(_on_lightning)
	ambiance.thunder.connect(_on_thunder)
	ambiance.shake_requested.connect(shake)
	RunState.difficulty_changed.connect(ambiance.set_difficulty)

	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	director = load(DIRECTOR).instantiate()
	director.name = "Director"
	world.add_child(director)
	if TestMode.active: # mode test : pas d'apparitions tant que le panneau ne les active pas
		director.set(&"spawning_enabled", TestMode.spawns)
		director.set(&"waves_enabled", TestMode.spawns)

	if ResourceLoader.exists(DAMAGE_NUMBERS):
		damage_numbers = load(DAMAGE_NUMBERS).instantiate()
		var layer := AmbianceManager.telegraph_layer(get_tree())
		(layer if layer != null else self as Node).add_child(damage_numbers)
	# barres de vie des monstres blessés : un seul nœud, même couche (monde, non éclairée)
	health_bars = EnemyHealthBars.new()
	health_bars.name = "EnemyHealthBars"
	var hb_layer := AmbianceManager.telegraph_layer(get_tree())
	(hb_layer if hb_layer != null else self as Node).add_child(health_bars)
	if ResourceLoader.exists(PICKUPS):
		pickups = load(PICKUPS).instantiate()
		add_child(pickups)

	stage = StageManager.new()
	stage.name = "Stage"
	stage.map_scene = map_scene
	stage.bare_arena = TestMode.active # mode test : arène vide, sans coffre ni téléporteur
	stage.stage_started.connect(_on_stage_started)
	stage.victory_choice_requested.connect(_on_victory_choice)
	stage.run_won.connect(func() -> void: end_run(true))
	Events.floor_cleared.connect(_on_floor_cleared_record)
	world.add_child(stage) # avant le joueur : la carte se dessine sous les entités

	player = load(PLAYER).instantiate()
	world.add_child(player)
	camera = player.get_node_or_null(^"Camera2D") as Camera2D
	if "auto_cast_spells" in player:
		player.set(&"auto_cast_spells", GameSettings.auto_cast())

	hud = load(HUD).instantiate()
	add_child(hud)
	if TestMode.active:
		TestOverlay.attach(self) # panneau du mode test + bouton tactile (À RETIRER AVANT LA SORTIE)
	else:
		preload("res://scripts/ui/onboarding_hints.gd").attach(self, hud) # invites de 1re run (lot M-A), null si inactif
	hud.abandon_requested.connect(func() -> void: end_run(false, &"abandon"))
	if hud.has_signal(&"save_quit_requested"):
		hud.save_quit_requested.connect(_on_save_quit)
	var pm: Node = hud.get(&"pause_menu")
	if pm != null and pm.has_signal(&"resumed"):
		pm.resumed.connect(_on_resumed)
	if pm != null and pm.has_signal(&"opened"):
		pm.opened.connect(func() -> void: autosave())

	Events.player_died.connect(_on_player_died)
	Events.pillar_state_changed.connect(_on_pillar_state)
	Events.item_chosen.connect(_on_item_chosen)
	Events.pickup_collected.connect(_on_pickup_counter)
	Events.chest_opened.connect(_on_chest_counter)
	Events.gold_converted.connect(_on_gold_converted) # après celui du HUD : le toast existe déjà

	if resume_data.is_empty():
		stage.reset_run()
		stage.start_stage()
	else:
		_restore()


func _exit_tree() -> void:
	if TestMode.active:
		TestMode.end() # rend le profil d'avant (bac à sable) et coupe les triches
	if ambiance != null and RunState.difficulty_changed.is_connected(ambiance.set_difficulty):
		RunState.difficulty_changed.disconnect(ambiance.set_difficulty)
	if Events.player_died.is_connected(_on_player_died):
		Events.player_died.disconnect(_on_player_died)
	if Events.pillar_state_changed.is_connected(_on_pillar_state):
		Events.pillar_state_changed.disconnect(_on_pillar_state)
	if Events.pickup_collected.is_connected(_on_pickup_counter):
		Events.pickup_collected.disconnect(_on_pickup_counter)
	if Events.chest_opened.is_connected(_on_chest_counter):
		Events.chest_opened.disconnect(_on_chest_counter)
	if Events.item_chosen.is_connected(_on_item_chosen):
		Events.item_chosen.disconnect(_on_item_chosen)
	if Events.gold_converted.is_connected(_on_gold_converted):
		Events.gold_converted.disconnect(_on_gold_converted)
	Audio.auto_start_map = true
	Audio.thunder_driven = false


# --- Compteurs de déblocage d'objets (ItemUnlocks) --------------------------

func _on_pickup_counter(kind: StringName, amount: float) -> void:
	if kind == &"gold":
		RunState.add_counter(ItemUnlocks.COUNTER_GOLD, amount)


func _on_chest_counter(_chest: Node, _quality: StringName, _offered: Array) -> void:
	RunState.add_counter(ItemUnlocks.COUNTER_CHESTS)


# --- Étages -----------------------------------------------------------------

func _on_stage_started(n: int) -> void:
	ambiance.set_difficulty(RunState.difficulty())
	ambiance.bind_map(stage.map)
	Audio.start_map(stage.map_id)
	_apply_camera_limits()
	if player != null and player.has_method(&"clear_statuses"):
		player.clear_statuses()
	if n > 1 and is_ready and not run_over: # pas à la reprise de sauvegarde ni au 1er étage
		_show_floor_card(n)


## Carton de transition (FloorCard, docs/ux/Audit_Menus.md §3.3) : un seul à la fois.
func _show_floor_card(n: int) -> void:
	if is_instance_valid(floor_card):
		floor_card.queue_free()
	floor_card = FloorCard.create(n, player)
	add_child(floor_card)


## « +N XP (or converti) » vient après stage_started : affiché sur le carton, le toast du HUD est masqué.
func _on_gold_converted(gold: float, xp: float) -> void:
	if not is_instance_valid(floor_card):
		return
	floor_card.set_conversion(gold, xp)
	var root: Variant = hud.get(&"root") if hud != null else null
	var toast: Node = (root as Node).get_node_or_null(^"GoldConvertedLabel") if root is Node else null
	if toast is CanvasItem:
		(toast as CanvasItem).visible = false


func _apply_camera_limits() -> void:
	if camera == null or stage.map == null:
		return
	var b := stage.get_bounds()
	var r := Rect2(stage.map.to_global(b.position), b.size)
	camera.limit_left = int(r.position.x)
	camera.limit_top = int(r.position.y)
	camera.limit_right = int(r.end.x)
	camera.limit_bottom = int(r.end.y)
	camera.reset_smoothing()


func _on_pillar_state(_p: Node, state: StringName) -> void:
	if state == Pillar.STATE_DONE:
		pillars_done += 1


# --- Foudre et secousse -----------------------------------------------------

func _on_lightning(world_pos: Vector2, intensity: float, _gameplay: bool) -> void:
	Events.lightning_struck.emit(intensity, world_pos)


## AmbianceManager.thunder (émis au flash) : délai = 0,3 + distance × 0,35 s (Direction §3.4).
func _on_thunder(_intensity: float, delay_s: float) -> void:
	Audio.thunder_after(delay_s, clampf((delay_s - 0.3) / 0.35, 0.0, THUNDER_MAX_DISTANCE))


## Secousse de la caméra (amplitude px, fréquence Hz, durée s), décroissance linéaire.
func shake(amplitude_px: float, hz: float, duration_s: float) -> void:
	amplitude_px *= GameSettings.shake_scale() # réglage « Secousses de caméra » (0-100 %), point unique
	if amplitude_px <= 0.0 or duration_s <= 0.0:
		return
	if amplitude_px >= _shake_amp * (_shake_left / maxf(_shake_total, 0.001)):
		_shake_amp = amplitude_px
		_shake_hz = maxf(hz, 1.0)
		_shake_total = duration_s
		_shake_left = duration_s


func _process(delta: float) -> void:
	if camera == null:
		return
	if _shake_left > 0.0:
		_shake_left -= delta
		_shake_t += delta
		var k := clampf(_shake_left / _shake_total, 0.0, 1.0)
		var w := _shake_t * _shake_hz * TAU
		# offset en repère logique : la caméra iso écrase y de moitié, on le double pour garder l'amplitude écran
		camera.offset = Vector2(sin(w), cos(w * 1.31 + 0.7) / Iso.SQUASH) * _shake_amp * k
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO


# --- Pause, fin de run --------------------------------------------------------

func _on_resumed() -> void:
	if player != null and player.has_method(&"grant_invulnerability"):
		player.grant_invulnerability(RESUME_PROTECTION_S)


## Étage final nettoyé (boss final abattu) : note le temps pour le record « meilleure run » (Profile).
func _on_floor_cleared_record(stage_n: int) -> void:
	if _final_boss_time_s <= 0.0 and FloorPlan.is_final_stage(stage_n):
		_final_boss_time_s = RunState.active_time_s


func _on_victory_choice(_n: int) -> void:
	if run_over or victory_screen != null:
		return
	get_tree().paused = true
	var final := FloorPlan.is_final_stage(RunState.stage)
	victory_screen = RunScreens.dialog("La Source est tarie" if final else "Étage %d terminé" % RunState.stage,
		["Le Semeur de pluie est vaincu. Vous pouvez repartir en mode sans fin (étages 6-10, mêmes biomes, autre variante)." if final
			else "Vous pouvez continuer en mode sans fin.",
			"Terminer = victoire, rubis +25."],
		[["Terminer la run", _choose_finish], ["Continuer (sans fin)", _choose_endless]])
	add_child(victory_screen)


func _choose_finish() -> void:
	_close_victory()
	stage.finish_run() # -> run_won -> end_run(true)


func _choose_endless() -> void:
	_close_victory()
	get_tree().paused = false
	stage.continue_endless()


func _close_victory() -> void:
	if victory_screen != null:
		victory_screen.queue_free()
		victory_screen = null


func _on_player_died() -> void:
	if run_over:
		return
	_dying = true
	get_tree().create_timer(DEATH_SCREEN_DELAY_S, true).timeout.connect(func() -> void: end_run(false, &"death"))


## Fin de run : rubis (Balance.run_rubies), sauvegarde supprimée, Profil crédité, récap (§3.10).
## reason : &"victory" | &"death" | &"abandon".
func end_run(victory: bool, reason: StringName = &"victory") -> void:
	if run_over:
		return
	run_over = true
	Events.run_finished.emit(victory, reason) # journal de run (RunLog) : écrit le fichier de la run
	if TestMode.active:
		go_to_title() # mode test : ni récap, ni profil, ni rubis
		return
	if is_instance_valid(floor_card):
		floor_card.queue_free()
	RunState.running = false
	if autosave_timer != null:
		autosave_timer.stop()
	last_rubies = Balance.run_rubies(RunState.active_time_s / 60.0, RunState.mode, pillars_done, victory, RunState.gold)
	get_tree().paused = true
	if _saves_enabled():
		RunSave.delete(save_path)
	last_unlocks = Profile.add_run_result({
		"victory": victory, "mode": RunState.mode, "character": RunState.character,
		"active_time_s": RunState.active_time_s, "kills": RunState.kills, "rubies": last_rubies,
		"close_kills": int(player.get(&"close_kills")) if player != null and &"close_kills" in player else 0,
		"stage": RunState.stage, "counters": RunState.counters.duplicate(), "bosses_killed": RunState.bosses_killed.duplicate(true),
		"level": RunState.level, "items": RunState.items.duplicate(), "loadout": RunState.loadout.duplicate(),
		"boss_time_s": _final_boss_time_s if victory else 0.0,
	})
	end_screen = EndRunScreen.create(end_info(victory, reason))
	add_child(end_screen)
	end_screen.continue_pressed.connect(go_to_title)
	end_screen.replay_pressed.connect(restart)
	run_ended.emit(victory, last_rubies)


## Données du récap (EndRunScreen.info).
func end_info(victory: bool, reason: StringName) -> Dictionary:
	var n_items := 0
	for k in RunState.items:
		n_items += int(RunState.items[k])
	return {
		"victory": victory, "reason": reason,
		"character_name": RunSave.character_name(String(RunState.character)), "mode": RunState.mode,
		"stage": RunState.stage, "active_time_s": RunState.active_time_s, "level": RunState.level,
		"pillars": pillars_done, "kills": RunState.kills, "items": n_items, "gold": int(RunState.gold),
		"rubies": last_rubies, "unlocks": last_unlocks,
	}


## « Rejouer » : même personnage, même mode. Hébergée (App) : replay_requested ; seule : rechargement.
func restart() -> void:
	get_tree().paused = false
	LightRig.clear_all()
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()
	elif not replay_requested.get_connections().is_empty():
		replay_requested.emit()
	else:
		restart_requested.emit()


## Retour au titre : hébergée (App) : title_requested ; seule : bascule vers app.tscn si elle existe.
func go_to_title() -> void:
	get_tree().paused = false
	LightRig.clear_all()
	if get_tree().current_scene == self and ResourceLoader.exists(APP_SCENE):
		get_tree().change_scene_to_file(APP_SCENE)
	else:
		title_requested.emit()


# --- Sauvegarde ----------------------------------------------------------------

func _saves_enabled() -> bool:
	if TestMode.active:
		return false # mode test : jamais de sauvegarde de run
	return saves_in_headless or DisplayServer.get_name() != "headless"


func _start_autosave() -> void:
	autosave_timer = Timer.new()
	autosave_timer.name = "AutosaveTimer"
	autosave_timer.wait_time = AUTOSAVE_INTERVAL_S
	autosave_timer.process_mode = Node.PROCESS_MODE_PAUSABLE # temps de jeu actif seulement
	autosave_timer.timeout.connect(func() -> void: autosave())
	add_child(autosave_timer)
	autosave_timer.start()


func _on_item_chosen(_id: StringName) -> void:
	autosave.call_deferred() # après la fermeture de l'écran de coffre (pas de coffre « en attente »)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			autosave()


## Sauvegarde immédiate si la run est sauvegardable. true si le fichier est écrit.
func autosave() -> bool:
	if not can_save() or not _saves_enabled():
		return false
	var ok := RunSave.save(build_save_data(), save_path)
	if ok:
		Events.run_saved.emit()
	return ok


## Vrai pendant une run en cours (étage chargé, joueur vivant, run pas terminée).
func can_save() -> bool:
	if not is_ready or run_over or _dying or stage == null or stage.map == null:
		return false
	return player == null or not ("hp" in player) or float(player.get(&"hp")) > 0.0


## Instantané complet de la run (format RunSave, §6.1).
func build_save_data() -> Dictionary:
	var run := RunState.to_dict()
	run["pillars_done"] = pillars_done
	return {
		"character": String(RunState.character), "mode": String(RunState.mode),
		"seed": RunState.run_seed, "rng_state": run.get("rng_state", "0"),
		"map_id": stage.map_id if stage != null else "",
		"run": run,
		"stage": stage.to_dict() if stage != null and stage.map != null else {},
		"player": _player_dict(),
		"pending_chest": _pending_chest_dict(),
	}


func _player_dict() -> Dictionary:
	if player == null:
		return {}
	var cds: Array = []
	if player.has_method(&"get_spell_cooldowns"):
		for c: Dictionary in player.get_spell_cooldowns():
			cds.append({"slot": int(c["slot"]), "remaining": float(c["remaining"]), "total": float(c["total"])})
	return {
		"pos": [player.global_position.x, player.global_position.y],
		"hp": float(player.get(&"hp")) if "hp" in player else 0.0,
		"cooldowns": cds, "statuses": [],
		# état du kit (eau d'Averse, membres de Tocsin) ; clé absente des anciennes sauvegardes = état neuf
		"kit": player.kit_save_state() if player.has_method(&"kit_save_state") else {},
	}


## Écran de coffre ouvert et pas encore choisi (GDD §4 : même choix à la reprise), sinon null.
func _pending_chest_dict() -> Variant:
	var ui := _find_chest_ui()
	if ui == null or ui.session == null or ui.session.offered.is_empty():
		return null
	var s := ui.session
	return {
		"kind": String(s.kind), "stage": s.stage, "price": s.price, "quality": String(s.quality),
		"die": s.die, "offered": s.offered.duplicate(),
		"shown": s.shown.duplicate(), "gold_rerolls": s.gold_rerolls, "ad_rerolls": s.ad_rerolls,
	}


func _find_chest_ui() -> ChestUI:
	var hosts: Array[Node] = [self, get_tree().root]
	if get_tree().current_scene != null:
		hosts.append(get_tree().current_scene)
	for h in hosts:
		for c in h.get_children():
			if c is ChestUI and not c.is_queued_for_deletion():
				return c
	return null


## Reprise : RunState (déjà restauré dans _ready), étage, joueur, puis l'état du RNG.
func _restore() -> void:
	stage.from_dict(resume_data.get("stage", {}))
	# les piliers restaurés à « done » ont pu réémettre pillar_state_changed : on reprend la valeur sauvegardée
	pillars_done = int(resume_data.get("run", {}).get("pillars_done", 0))
	if player.has_method(&"apply_stats"):
		player.apply_stats(ItemStats.compute(RunState.items))
	var pd: Dictionary = resume_data.get("player", {})
	var pos: Variant = pd.get("pos")
	if pos is Array and (pos as Array).size() == 2:
		player.global_position = Vector2(float(pos[0]), float(pos[1]))
		if camera != null:
			camera.reset_smoothing()
	if pd.has("hp") and "hp" in player:
		var max_hp := float(player.get(&"max_hp"))
		player.set(&"hp", clampf(float(pd["hp"]), 1.0, max_hp))
		if player.has_signal(&"hp_changed"):
			player.emit_signal(&"hp_changed", player.get(&"hp"), max_hp)
	if player.has_method(&"kit_load_state") and pd.get("kit") is Dictionary:
		player.kit_load_state(pd["kit"])
	var caster: Variant = player.get(&"spells") if "spells" in player else null
	if caster is Object and (caster as Object).has_method(&"set_cooldown"):
		for c in pd.get("cooldowns", []):
			caster.set_cooldown(int(c.get("slot", -1)), float(c.get("remaining", 0.0)), float(c.get("total", 0.0)))
	RunState.gold_changed.emit(RunState.gold)
	RunState.xp_changed.emit(RunState.xp, Balance.xp_required(RunState.level))
	# en dernier : rien après ne doit consommer le RNG avant la reprise du jeu
	var st := str(resume_data.get("rng_state", resume_data.get("run", {}).get("rng_state", "")))
	if st != "":
		RunState.rng.state = int(st)


## Rouvre l'écran de coffre en attente avec exactement le même tirage (pas de nouveau d100).
func _reopen_chest(pc: Dictionary) -> void:
	if not ResourceLoader.exists(CHEST_UI):
		return
	var s := ChestSession.new(StringName(str(pc.get("kind", "petit"))), int(pc.get("stage", RunState.stage)), float(pc.get("price", 0.0)))
	s.quality = StringName(str(pc.get("quality", "commun")))
	s.die = int(pc.get("die", 0))
	s.offered = (pc.get("offered", []) as Array).map(func(v): return str(RunState.migrate_item_id(StringName(str(v))))) # items retirés -> remplaçant
	s.shown = (pc.get("shown", []) as Array).map(func(v): return str(RunState.migrate_item_id(StringName(str(v)))))
	s.gold_rerolls = int(pc.get("gold_rerolls", 0))
	s.ad_rerolls = int(pc.get("ad_rerolls", 0))
	if s.offered.is_empty():
		return
	var ui := load(CHEST_UI).instantiate() as ChestUI
	add_child(ui)
	ui.resume(s)


## « Sauvegarder et quitter » (et « Quitter le jeu », qui ferme ensuite l'application) :
## sauvegarde puis retour au titre.
func _on_save_quit() -> void:
	autosave()
	go_to_title()
