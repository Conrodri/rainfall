extends Node
## Test headless : changement de personnage dans le même processus (Ardent puis Arpenteuse) sans aucune erreur
## moteur (enfant Emission d'Ardent qui jouait « plant_e » / « plant_nw » sur Arpenteuse), plus les contrats
## SpellCaster.defers_effects() (kit.defers_effects, ArdentVariantKit) et le signal SpellCaster.spell_hit.
## godot --headless --path game res://tests/emission_switch_test.tscn  (sortie : RESULT: OK)

const ARDENT_FRAMES := "res://assets/sprites/characters/ardent/ardent.tres"
## Frames d'Arpenteuse lues directement : le test ne dépend pas de l'état de arpenteuse_kit.gd (en travail ailleurs).
const ARPENTEUSE_FRAMES := "res://assets/sprites/characters/arpenteuse/arpenteuse.tres"
const DT := 1.0 / 60.0


## Capte toute erreur moteur ou de script (avertissements exclus) pendant le test.
class ErrLog extends Logger:
	var errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errors.append("%s (%s:%d %s) %s" % [code, file, line, function, rationale])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func snapshot() -> Array[String]:
		_mutex.lock()
		var out := errors.duplicate()
		_mutex.unlock()
		return out


class FakeEnemy extends Node2D:
	var taken: Array = []
	var radius_px := 0.0

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func is_slowed() -> bool:
		return false


var _fails: Array[String] = []
var _log := ErrLog.new()


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
		print("ÉCHEC : ", what)
	else:
		print("  ok   ", what)


func _ready() -> void:
	OS.add_logger(_log)
	await get_tree().process_frame
	await _test_overlay_direct()
	await _test_player_switch()
	await _test_defers_effects()
	_test_spell_hit()
	await get_tree().process_frame
	var errs := _log.snapshot()
	for e in errs:
		print("  erreur captée : ", e)
	_check(errs.is_empty(), "aucune erreur moteur pendant tout le test (%d)" % errs.size())
	OS.remove_logger(_log)
	if _fails.is_empty():
		print("RESULT: OK")
	else:
		print("RESULT: FAIL (%d)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)


func _arpenteuse_frames() -> SpriteFrames:
	return load(ARPENTEUSE_FRAMES) as SpriteFrames if ResourceLoader.exists(ARPENTEUSE_FRAMES) else null


## Joue chaque anim de `frames` sur `spr` quelques images (la synchro de l'émission suit).
func _play_all(spr: AnimatedSprite2D, frames: SpriteFrames) -> void:
	for a in frames.get_animation_names():
		spr.play(a)
		spr.frame = mini(1, frames.get_frame_count(a) - 1)
	await get_tree().process_frame


func _test_overlay_direct() -> void:
	print("EmissiveOverlay.apply : Ardent -> Arpenteuse -> Ardent")
	var ardent := load(ARDENT_FRAMES) as SpriteFrames
	var arp := _arpenteuse_frames()
	_check(ardent != null and arp != null, "SpriteFrames d'Ardent et d'Arpenteuse chargées")
	if ardent == null or arp == null:
		return
	var has_e := NormalMaps.emission_frames(ardent) != null
	var arp_e := NormalMaps.emission_frames(arp) != null
	var spr := AnimatedSprite2D.new()
	add_child(spr)
	EmissiveOverlay.apply(spr, ardent)
	spr.play(&"idle_s" if ardent.has_animation(&"idle_s") else ardent.get_animation_names()[0])
	if has_e:
		_check(spr.get_node_or_null(^"Emission") != null, "Ardent : enfant Emission présent")
	EmissiveOverlay.apply(spr, arp)
	if not arp_e:
		_check(spr.get_node_or_null(^"Emission") == null, "Arpenteuse sans _e : enfant Emission retiré")
	else:
		var em := spr.get_node_or_null(^"Emission") as AnimatedSprite2D
		_check(em != null and em.sprite_frames == NormalMaps.emission_frames(arp), "Arpenteuse : émission recalée sur ses frames")
	await _play_all(spr, arp)
	EmissiveOverlay.apply(spr, ardent)
	if has_e:
		var em2 := spr.get_node_or_null(^"Emission") as AnimatedSprite2D
		_check(em2 != null and em2.sprite_frames == NormalMaps.emission_frames(ardent) and em2.visible,
			"retour à Ardent : enfant Emission recréé et visible")
	await _play_all(spr, ardent)
	# diffus changé sans passer par apply : la synchro ne pose jamais une anim absente
	spr.sprite_frames = arp
	await _play_all(spr, arp)
	spr.queue_free()


func _new_player(cid: StringName, loadout := {}) -> CharacterBody2D:
	RunState.start_run(&"moyen", 1234)
	RunState.running = false
	RunState.level = 1
	var p: CharacterBody2D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	if cid == &"arpenteuse":
		# visuel d'Arpenteuse sur la base d'Ardent (sans kit) : seul le changement de SpriteFrames est testé
		var cd := CharacterData.for_id(&"ardent")
		cd.id = &"arpenteuse"
		cd.sprite_frames_path = ARPENTEUSE_FRAMES
		p.character = cd
	else:
		p.character = CharacterData.for_id(cid, loadout)
	add_child(p)
	p.global_position = Vector2.ZERO
	p.spells.manual_aim_enabled = false
	return p


func _test_player_switch() -> void:
	print("Joueur Ardent puis joueur Arpenteuse dans le même processus")
	var a := _new_player(&"ardent")
	for i in 30:
		a.tick(DT)
		await get_tree().process_frame
	a.queue_free()
	await get_tree().process_frame
	var p := _new_player(&"arpenteuse")
	var spr := p.get_node(^"Visual") as AnimatedSprite2D
	var arp := _arpenteuse_frames()
	_check(spr.sprite_frames == arp or arp == null, "Visual d'Arpenteuse sur ses frames")
	if NormalMaps.emission_frames(arp) == null:
		_check(spr.get_node_or_null(^"Emission") == null, "joueur Arpenteuse : aucun enfant Emission d'Ardent")
	if arp != null:
		for a_name in [&"plant_e", &"plant_nw", &"run_e", &"idle_s"]:
			if arp.has_animation(a_name):
				spr.play(a_name)
				await get_tree().process_frame
	for i in 30:
		p.tick(DT)
		await get_tree().process_frame
	p.queue_free()
	await get_tree().process_frame


func _test_defers_effects() -> void:
	print("SpellCaster.defers_effects")
	var base := _new_player(&"ardent")
	_check(base.kit is ArdentBaseKit and base.spells.defers_effects(), "Ardent de base : kit de base, effets différés")
	base.queue_free()
	await get_tree().process_frame
	var v := _new_player(&"ardent", {2: &"flame_pillar"})
	_check(v.kit is ArdentVariantKit, "Ardent + variante : kit de variantes")
	_check(v.spells.defers_effects(), "Ardent + variante : effets toujours différés (kit.defers_effects)")
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	e.global_position = Vector2(3.0 * 64.0, 0.0)
	var fired: int = v.spells.active_projectile_count()
	var ok: bool = v.spells.cast(1)
	_check(ok and v.spells.has_pending() and v.spells.active_projectile_count() == fired,
		"Ardent + variante : le tir de base attend la frame d'impact")
	v.spells.flush_pending()
	_check(v.spells.active_projectile_count() == fired + 1, "impact : le tir part")
	e.queue_free()
	v.queue_free()
	await get_tree().process_frame
	# aucun autre kit ne déclare le hook : comportement inchangé (effets immédiats)
	var dir := DirAccess.open("res://scripts/spells")
	for f in dir.get_files():
		if not f.ends_with("_kit.gd") or f in ["ardent_kit.gd", "ardent_variant_kit.gd"]:
			continue
		# lecture du texte (pas de chargement : un kit en cours d'édition par un autre agent ne casse pas ce test)
		var has := FileAccess.get_file_as_string("res://scripts/spells/" + f).contains("func defers_effects")
		_check(not has, "%s : pas de defers_effects (inchangé)" % f)


func _test_spell_hit() -> void:
	print("Signal SpellCaster.spell_hit")
	var p := _new_player(&"ardent")
	var got: Array = []
	p.spells.spell_hit.connect(func(s: SpellData, en: Node, amount: float) -> void: got.append([s, en, amount]))
	var e := FakeEnemy.new()
	add_child(e)
	var s: SpellData = p.character.spells[0]
	var dealt: float = p.spells.deal_damage(e, s)
	_check(got.size() == 1 and got[0][0] == s and got[0][1] == e and is_equal_approx(float(got[0][2]), dealt),
		"deal_damage émet spell_hit(spell, enemy, amount)")
	e.queue_free()
	p.queue_free()
