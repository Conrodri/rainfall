extends Node
## Aperçu de jeu de la fiche personnage (SpellPreview).
## godot --headless --path game res://tests/spell_preview_test.tscn  -> RESULT: OK
## Vérifie : les 4 sorts des 10 personnages produisent un effet dans l'arène ; RunState, profil, InputMap et volumes de bus
## restent identiques ; aucune fuite de nœuds après ouverture/fermeture répétées et changements de personnage ;
## passage par la fiche (preview_spell) et repli propre quand le kit ne peut pas lancer.

const IDS := ["ardent", "rictus", "tocsin", "averse", "arpenteuse", "rainette", "avare", "bourbe", "vigie", "morfil"]
const CAST_FRAMES := 150
const LEAK_TOLERANCE := 6

var _fails: Array[String] = []
var _chars := {}


func _check(c: bool, w: String) -> void:
	if not c:
		_fails.append(w)
		printerr("FAIL: ", w)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _snapshot() -> Dictionary:
	var inputs := {}
	for a in SpellPreview.LOCKED_ACTIONS:
		if InputMap.has_action(a):
			inputs[a] = InputMap.action_get_events(a).size()
	var buses := {}
	for b in SpellPreview.SFX_BUSES:
		var idx := AudioServer.get_bus_index(b)
		if idx != -1:
			buses[b] = AudioServer.get_bus_volume_db(idx)
	return {
		"run": JSON.stringify(RunState.to_dict()), "running": RunState.running, "character": RunState.character,
		"loadout": JSON.stringify(RunState.loadout), "profile": JSON.stringify(Profile.to_dict()),
		"inputs": inputs, "buses": buses,
	}


func _same(a: Dictionary, b: Dictionary, what: String) -> void:
	for k in a:
		_check(JSON.stringify(a[k]) == JSON.stringify(b[k]), "%s : %s modifié" % [what, k])


func _ready() -> void:
	for c in CharacterCard.load_characters():
		_chars[String(c.id)] = c
	Profile.write_enabled = false # le test n'écrit jamais le profil réel
	await _test_effects()
	await _test_leaks()
	await _test_sheet()
	await _test_fallback()
	print("RESULT: ", "OK" if _fails.is_empty() else "FAIL (%d)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)


func _host() -> Control:
	var host := Control.new()
	host.size = Vector2(560, 700)
	add_child(host)
	return host


## 1. Les 4 sorts de chaque personnage produisent un effet, et l'état global est restitué.
func _test_effects() -> void:
	var before := _snapshot()
	for id in IDS:
		var c: Dictionary = _chars[id]
		var host := _host()
		var pv := SpellPreview.new()
		host.add_child(pv)
		pv.start(c, {})
		await get_tree().process_frame
		_check(pv.ready_to_cast, "%s : arène prête" % id)
		for slot in [1, 2, 3, 4]:
			var d0 := pv.damage_total
			var s0 := pv.spawned_total
			var sharp0: float = pv.player.kit.sharpness if (pv.player != null and pv.player.kit != null and &"sharpness" in pv.player.kit) else -1.0
			var ok := pv.play(slot, {})
			await _frames(CAST_FRAMES)
			var sharp1: float = pv.player.kit.sharpness if (pv.player != null and pv.player.kit != null and &"sharpness" in pv.player.kit) else -1.0
			var effect := pv.damage_total - d0 > 0.0 or pv.spawned_total - s0 > 0 or sharp1 > sharp0 + 0.5
			_check(ok, "%s sort %d : lancé" % [id, slot])
			_check(effect, "%s sort %d : aucun effet visible (dégâts %.1f, nœuds %d)" % [id, slot, pv.damage_total - d0, pv.spawned_total - s0])
		_check(pv.dummies.size() >= 3 and pv.dummies.size() <= 5, "%s : 3 à 5 mannequins" % id)
		pv.shutdown()
		await get_tree().process_frame
		await get_tree().process_frame
		host.queue_free()
		await get_tree().process_frame
	_same(before, _snapshot(), "effets")


## 2. Ouvertures répétées et changements de personnage : pas de fuite de nœuds.
func _test_leaks() -> void:
	var before := _snapshot()
	var n0 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for round in 2:
		for id in ["ardent", "arpenteuse", "morfil"]:
			var host := _host()
			var pv := SpellPreview.new()
			host.add_child(pv)
			pv.start(_chars[id], {})
			await get_tree().process_frame
			pv.play(2, {})
			await _frames(40)
			pv.shutdown()
			await get_tree().process_frame
			host.queue_free()
			await get_tree().process_frame
	await _frames(3)
	var grown := Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - n0
	_check(grown <= LEAK_TOLERANCE, "fuite de nœuds après 6 arènes : +%d" % int(grown))
	_same(before, _snapshot(), "fuites")


## 3. Par la fiche : un clic sur un sort lance l'arène ; changement de perso et fermeture libèrent tout.
func _test_sheet() -> void:
	var before := _snapshot()
	var n0 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var sh := CharacterSheet.new()
	sh.custom_minimum_size = Vector2(1500, 800)
	sh.size = Vector2(1500, 800)
	add_child(sh)
	for id in ["ardent", "avare", "ardent"]:
		var c: Dictionary = _chars[id]
		sh.open(c, false, false)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(sh.arena != null and sh.arena.ready_to_cast, "%s : fiche, arène prête" % id)
		if sh.arena == null:
			continue
		var d0 := sh.arena.damage_total
		var s0 := sh.arena.spawned_total
		var fired := [0]
		sh.spell_previewed.connect(func(_s: int, _i: StringName) -> void: fired[0] += 1, CONNECT_ONE_SHOT)
		sh.preview_spell(2, sh._option_for_slot(2))
		await _frames(CAST_FRAMES)
		_check(fired[0] == 1, "%s : spell_previewed émis" % id)
		_check(sh.arena.damage_total > d0 or sh.arena.spawned_total > s0, "%s : sort 2 par la fiche sans effet" % id)
		_check(sh.preview != null and not sh.preview.visible, "%s : ancien aperçu masqué" % id)
	sh.visible = false
	await get_tree().process_frame
	_check(sh.arena == null, "fiche masquée : arène libérée")
	sh.queue_free()
	await _frames(3)
	var grown := Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - n0
	_check(grown <= LEAK_TOLERANCE, "fuite de nœuds après la fiche : +%d" % int(grown))
	_same(before, _snapshot(), "fiche")


## 4. Repli : arène indisponible (jamais démarrée) = ancienne animation + VFX, sans erreur.
func _test_fallback() -> void:
	var sh := CharacterSheet.new()
	sh.size = Vector2(1500, 800)
	add_child(sh)
	sh.open(_chars["ardent"], false, false)
	await get_tree().process_frame
	await get_tree().process_frame
	sh.arena.shutdown() # simule un kit/arène inutilisable
	sh.arena = null
	if sh.preview != null:
		sh.preview.visible = true
	var fired := [0]
	sh.spell_previewed.connect(func(_s: int, _i: StringName) -> void: fired[0] += 1)
	sh.preview_spell(2, sh._option_for_slot(2))
	await get_tree().process_frame
	_check(fired[0] == 1, "repli : spell_previewed émis")
	sh.queue_free()
	await get_tree().process_frame
