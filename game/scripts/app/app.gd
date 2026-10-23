class_name App
extends Node
## Racine du jeu (docs/Design_Menus.md §0, §1, §8 lot F) : héberge soit un écran de menu, soit la scène
## de jeu `main.tscn` instanciée en enfant. Un seul écran à la fois ; chaque changement passe par un
## fondu (FadeLayer). Les écrans Control (Nouvelle run, Progression, Réglages) sont posés sur un
## CanvasLayer 10 devant un MenuBackground propre à App ; Titre et Crédits portent le leur.

signal screen_changed(screen: StringName)
signal run_started ## main.tscn a émis game_ready

const MAIN_SCENE := "res://scenes/main.tscn"
const TITLE_SCENE := preload("res://scenes/menu/title.tscn")
const CREDITS_SCENE := preload("res://scenes/menu/credits.tscn")
const NEW_RUN_SCENE := preload("res://scenes/menu/new_run.tscn")
const PROGRESS_SCENE := preload("res://scenes/menu/progress.tscn")
const SETTINGS_SCENE := preload("res://scenes/menu/settings.tscn")
const BG_SCENE := preload("res://scenes/menu/menu_background.tscn")
const UI_LAYER := 10
const FADE_S := 0.18

## Chemin de sauvegarde de run (vide = RunSave.PATH) ; les tests passent un user://test_….
var save_path := ""
## Autorise l'écriture de la sauvegarde en headless (tests uniquement).
var saves_in_headless := false

var current: Node = null ## écran affiché (TitleScreen, NewRunScreen…) ou scène de jeu
var current_name: StringName = &""
var main: Node = null ## scène de jeu en cours (null au titre)
var fade: FadeLayer
var last_config: Dictionary = {} ## dernière config de run, pour « Rejouer »
var busy := false

var _wrap: Node = null ## conteneur d'un écran Control (fond + CanvasLayer)
var _queued: Array = []


func _ready() -> void:
	fade = FadeLayer.new()
	fade.name = "FadeLayer"
	add_child(fade)
	await show(&"title")


# --- API ---------------------------------------------------------------------

## Affiche un écran de menu : &"title" | &"new_run" | &"progress" | &"settings" | &"credits".
func show(screen: StringName, toast := "") -> void:
	await _transition(func() -> void: _build_screen(screen, toast))


## Nouvelle run : config = {character, mode, spells}. Fondu, chargement (main.gd), fondu.
func start_run(config: Dictionary) -> void:
	last_config = config.duplicate(true)
	await _transition(func() -> void: _build_main(config, {}))


## Reprend la sauvegarde. Illisible : conversion en rubis (RunSave.load) puis retour au titre + toast.
func resume_run() -> void:
	var r := RunSave.load(save_path)
	if not bool(r.get("ok", false)):
		var rub := int(r.get("rubies", 0))
		var msg := "Aucune sauvegarde à reprendre."
		if String(r.get("reason", "")) != "missing":
			msg = "Sauvegarde incompatible : %d rubis récupérés." % rub
		await return_to_title(msg)
		return
	var data: Dictionary = r["data"]
	var run_d: Variant = data.get("run", {})
	last_config = {"character": StringName(str(data.get("character", "ardent"))),
		"mode": StringName(str(data.get("mode", "moyen"))),
		"spells": RunState.normalize_loadout((run_d as Dictionary).get("loadout", {}) if run_d is Dictionary else {})}
	await _transition(func() -> void: _build_main(last_config, data))


## Retour au titre (libère la scène de jeu, rend la main au menu).
func return_to_title(toast := "") -> void:
	await show(&"title", toast)


# --- Transition --------------------------------------------------------------

func _transition(build: Callable) -> void:
	if busy:
		_queued.append(build)
		return
	busy = true
	var cb := build
	while true:
		await fade.fade_out(FADE_S)
		_free_current()
		get_tree().paused = false
		# deux images : les nœuds libérés (Director, lumières, fond) quittent l'arbre avant le suivant
		await get_tree().process_frame
		await get_tree().process_frame
		cb.call()
		await get_tree().process_frame
		fade.fade_in(FADE_S)
		if _queued.is_empty():
			break
		cb = _queued.pop_front()
	busy = false


func _free_current() -> void:
	if main != null:
		LightRig.clear_all()
	var victim: Node = _wrap if _wrap != null else current
	if victim != null and is_instance_valid(victim):
		remove_child(victim)
		victim.queue_free()
	current = null
	_wrap = null
	main = null
	current_name = &""


func _build_screen(screen: StringName, toast: String) -> void:
	current_name = screen
	match screen:
		&"title":
			var t := TITLE_SCENE.instantiate() as TitleScreen
			if save_path != "":
				var sp := save_path
				t.summary_provider = func() -> Dictionary: return RunSave.summary(sp) if RunSave.exists(sp) else {}
			t.resume_requested.connect(resume_run)
			t.new_run_requested.connect(func() -> void: show(&"new_run"))
			t.quick_start_requested.connect(start_run) # M16 : appui long / [Y] sur « Jouer »
			t.progress_requested.connect(func() -> void: show(&"progress"))
			t.settings_requested.connect(func() -> void: show(&"settings"))
			t.credits_requested.connect(func() -> void: show(&"credits"))
			t.quit_requested.connect(_on_quit)
			add_child(t)
			current = t
			if toast != "":
				t.show_toast(toast)
		&"credits":
			var c := CREDITS_SCENE.instantiate() as CreditsScreen
			c.back_requested.connect(return_to_title)
			add_child(c)
			current = c
		&"new_run":
			var n := NEW_RUN_SCENE.instantiate() as NewRunScreen
			n.start_requested.connect(start_run)
			n.back_requested.connect(return_to_title)
			current = _wrap_control(n)
		&"progress":
			var p := PROGRESS_SCENE.instantiate() as ProgressScreen
			p.back_requested.connect(return_to_title)
			current = _wrap_control(p)
		&"settings":
			var s := SETTINGS_SCENE.instantiate() as SettingsScreen
			s.back_requested.connect(return_to_title)
			current = _wrap_control(s)
		_:
			push_error("App.show : écran inconnu « %s »" % screen)
			_build_screen(&"title", toast)
			return
	screen_changed.emit(current_name)


## Fond animé + CanvasLayer 10 portant un écran Control ; renvoie l'écran.
func _wrap_control(screen: Control) -> Node:
	_wrap = Node.new()
	_wrap.name = "ScreenHost"
	add_child(_wrap)
	var bg := BG_SCENE.instantiate() as MenuBackground
	bg.name = "Background"
	_wrap.add_child(bg)
	bg.setup(MenuBackground.daily_map_id())
	var layer := CanvasLayer.new()
	layer.name = "UI"
	layer.layer = UI_LAYER
	_wrap.add_child(layer)
	layer.add_child(screen)
	if Audio.current_map_id() != "menu":
		Audio.start_map("menu")
	return screen


func _build_main(config: Dictionary, resume: Dictionary) -> void:
	current_name = &"game"
	var m: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	m.set(&"run_mode", StringName(str(config.get("mode", "moyen"))))
	m.set(&"run_seed", 0)
	m.set(&"resume_data", resume)
	m.set(&"save_path", save_path)
	m.set(&"saves_in_headless", saves_in_headless)
	if resume.is_empty():
		RunState.character = StringName(str(config.get("character", "ardent")))
		RunState.loadout = RunState.normalize_loadout(config.get("spells", {})) # variantes de sorts choisies
	m.connect(&"title_requested", func() -> void: return_to_title())
	m.connect(&"replay_requested", func() -> void: start_run(last_config))
	m.connect(&"game_ready", func() -> void: run_started.emit())
	add_child(m)
	main = m
	current = m
	screen_changed.emit(current_name)


func _on_quit() -> void:
	Platform.quit_game()
