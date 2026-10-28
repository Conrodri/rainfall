class_name MetaTracker
extends Node
## Méta hors ligne : écoute `Events` (et RunState) pour les succès, le défi du jour et la notification en jeu.
## Hébergé par App (un seul exemplaire pour toute la session). Mode test : ne fait rien (rien n'est écrit au profil).
##
## - Succès : data/achievements.json, évalués aux événements utiles (floor_cleared, boss_killed, chest_opened,
##   item_chosen, level_up, pilier terminé, fin de run) ; kills en direct par seuil. Compteurs à vie ajoutés au profil :
##   chests_opened, pillars_done, minis_killed, items_picked ; boss d'étage tués : Profile.boss_kills.
## - Défi du jour : à run_started, la graine de la run dit si elle est « du jour » ; FloorPlan.ignore_memory évite que la
##   mémoire des boss du profil change le plan. À la fin de la run : DailyChallenge.record (+ rubis, série).
## - Services de plateforme : PlatformServices.current reçoit les déblocages (interface vide, aucun réseau).

signal achievement_unlocked(id: String)
signal daily_recorded(result: Dictionary)

var toast: AchievementToast
## Tests : objet profil injecté (par défaut l'autoload Profile).
var profile: Object = null

var daily_key := 0 ## clé AAAAMMJJ de la run en cours si c'est un défi du jour, sinon 0
var _kill_goal := -1.0 ## plus petit seuil de kills restant à franchir (-1 : aucun)
var _eval_queued := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if profile == null:
		profile = Profile
	toast = AchievementToast.new()
	toast.name = "AchievementToast"
	add_child(toast)
	Events.run_started.connect(_on_run_started)
	Events.run_finished.connect(_on_run_finished)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.boss_killed.connect(_on_boss_killed)
	Events.floor_cleared.connect(_on_floor_cleared)
	Events.chest_opened.connect(_on_chest_opened)
	Events.item_chosen.connect(_on_item_chosen)
	Events.pillar_state_changed.connect(_on_pillar_state)
	RunState.level_up.connect(_on_level_up)
	_refresh_kill_goal()


func _exit_tree() -> void:
	FloorPlan.ignore_memory = false


func _on() -> bool:
	return not TestMode.active


# --- Événements -----------------------------------------------------------------------------

func _on_run_started(_resumed: bool) -> void:
	daily_key = 0
	if _on():
		daily_key = DailyChallenge.key_of_seed(RunState.run_seed)
	FloorPlan.ignore_memory = daily_key != 0


func _on_run_finished(victory: bool, reason: StringName) -> void:
	if not _on():
		FloorPlan.ignore_memory = false
		daily_key = 0
		return
	var ctx := {
		"run_end": true, "victory": victory, "reason": String(reason), "mode": String(RunState.mode),
		"stage": RunState.stage, "time_s": RunState.active_time_s, "kills": RunState.kills, "level": RunState.level,
		"character": String(RunState.character),
	}
	var key := daily_key
	daily_key = 0
	FloorPlan.ignore_memory = false
	# Après Profile.add_run_result (synchrone, juste après cet événement dans Main.end_run).
	_finish_run.call_deferred(ctx, key)


func _finish_run(ctx: Dictionary, key: int) -> void:
	if key != 0:
		var res := DailyChallenge.record(profile, key, ctx)
		if bool(res.get("counted", false)):
			toast.push("Défi du jour terminé", "+%d rubis · série de %d jour%s" % [int(res["rubies"]), int(res["streak"]),
				"s" if int(res["streak"]) > 1 else ""], _ruby_icon())
			PlatformServices.current.submit_daily_score(key, ctx)
		daily_recorded.emit(res)
	_evaluate(ctx)


func _on_enemy_killed(_e: Node2D, _p: Vector2, _tier: int, _elite: bool) -> void:
	if _kill_goal > 0.0 and _on() and Achievements.stat_value(profile, "kills") >= _kill_goal:
		_evaluate({})


func _on_boss_killed(boss: Node2D, is_floor_boss: bool) -> void:
	if not _on():
		return
	if is_floor_boss:
		var bid := String(boss.call(&"boss_id")) if boss != null and boss.has_method(&"boss_id") else ""
		profile.call(&"add_boss_kill", bid)
	else:
		profile.call(&"add_stat", "minis_killed", 1.0)
	_evaluate({})


func _on_floor_cleared(stage: int) -> void:
	if _on():
		_evaluate({"stage": stage})


func _on_chest_opened(_chest: Node, quality: StringName, _offered: Array) -> void:
	if not _on():
		return
	profile.call(&"add_stat", "chests_opened", 1.0)
	_evaluate({"quality": String(quality)})


func _on_item_chosen(_id: StringName) -> void:
	if not _on():
		return
	profile.call(&"add_stat", "items_picked", 1.0)
	_queue_eval()


func _on_pillar_state(_pillar: Node, state: StringName) -> void:
	if not _on():
		return
	if state == &"done":
		profile.call(&"add_stat", "pillars_done", 1.0)
		_evaluate({})


func _on_level_up(_lvl: int) -> void:
	if _on():
		_queue_eval()


func _queue_eval() -> void:
	if _eval_queued:
		return
	_eval_queued = true
	_evaluate_deferred.call_deferred()


func _evaluate_deferred() -> void:
	_eval_queued = false
	_evaluate({})


# --- Évaluation -----------------------------------------------------------------------------

## Évalue les succès et notifie les nouveaux. Retourne les définitions débloquées.
func _evaluate(ctx: Dictionary) -> Array:
	if not _on():
		return []
	var got := Achievements.evaluate(profile, ctx)
	for a in got:
		var id := str(a["id"])
		toast.push("Succès débloqué", str(a["name"]), Achievements.icon_of(a))
		PlatformServices.current.report_achievement(id)
		achievement_unlocked.emit(id)
	if not got.is_empty():
		_refresh_kill_goal()
		Audio.play_ui(&"ui.item_pick", -10.0, 1.2)
	return got


func _refresh_kill_goal() -> void:
	_kill_goal = -1.0
	for a in Achievements.all():
		var c: Dictionary = a["cond"]
		if str(c.get("type", "")) == "stat" and str(c.get("key", "")) == "kills" and not bool(profile.call(&"is_achievement_unlocked", str(a["id"]))):
			var v := float(c["value"])
			if _kill_goal < 0.0 or v < _kill_goal:
				_kill_goal = v


func _ruby_icon() -> Texture2D:
	var p := "res://assets/sprites/ui/da/icon_ruby.png"
	return load(p) as Texture2D if ResourceLoader.exists(p) else null
