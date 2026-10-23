extends Node
## Variantes de sorts (infrastructure générique, CONTRACTS.md « Variantes de sorts ») :
## sélection sur la fiche (souris / manette), mémoire par personnage (Profile.loadout), transmission à la run
## (RunState.loadout + sauvegarde), chargement d'une variante factice par le kit, repli sur le sort de base,
## moteur de règles `unlock_rule` (win_with, counter, boss_kill, floor_reached), annonce de fin de run.
## godot --headless --path game res://tests/variants_test.tscn  → « RESULT: OK »
## Aucun fichier réel touché : profil sur chemin de test, écritures désactivées, sauvegarde de run non écrite.

const NEW_RUN := preload("res://scenes/menu/new_run.tscn")
const TEST_PROFILE := "user://test_variants_profile.json"
const FAKE_KIT := "res://tests/variants_fake_kit.gd"


## Profil factice pour l'écran (aucune écriture disque).
class FakeProfile:
	extends RefCounted
	var rubies := 0
	var unlocked_modes: Array = ["facile", "moyen"]
	var unlocked_spells: Array = []
	var last_mode := "moyen"
	var last_character := "ardent"
	var stats := {"runs": 3, "victories": 0, "kills": 10, "play_time_s": 60.0, "best_time_s": {}, "ardent.test_counter": 120.0}
	var saved := {}

	func is_unlocked(key: StringName) -> bool:
		var s := String(key)
		return s.begins_with("spell:") and unlocked_spells.has(s.substr(6))

	func get_loadout(cid: StringName) -> Dictionary:
		return (saved.get(String(cid), {}) as Dictionary).duplicate()

	func set_loadout(cid: StringName, spells: Dictionary) -> void:
		saved[String(cid)] = spells.duplicate()


var _fails: Array[String] = []


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
		print("ÉCHEC : ", what)


func _frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


## Ardent de characters.json avec des variantes de test (une règle de chaque type, une inconnue).
func _test_character() -> Dictionary:
	var c: Dictionary = {}
	for x in JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json")):
		if x is Dictionary and str(x.get("id", "")) == "ardent":
			c = (x as Dictionary).duplicate(true)
	var sp: Array = c["spells"]
	sp[0]["variants"] = [{"id": "roaming_embers", "name": "Braises errantes", "desc": "Orbes de braise."}] # auto : win_with implicite
	sp[1]["variants"] = [{"id": "flame_pillar", "name": "Pilier de flamme", "desc": "Pilier.",
		"unlock_text": "Compteur de test.", "unlock_rule": {"type": "counter", "key": "ardent.test_counter", "value": 500}}]
	sp[2]["variants"] = [{"id": "meteor_rain", "name": "Pluie de météores", "desc": "Météores.",
		"unlock_rule": {"type": "boss_kill", "boss": "any"}},
		{"id": "mystere", "name": "Mystère", "desc": "?", "unlock_rule": {"type": "inconnu"}}]
	sp[3]["variants"] = [{"id": "phoenix", "name": "Phénix", "desc": "Renaissance.",
		"unlock_rule": {"type": "floor_reached", "floor": 3, "mode": "difficile"}}]
	return c


func _ready() -> void:
	var plat := get_node_or_null("/root/Platform")
	if plat != null:
		plat.set_input_mode(1)
	await _test_selection()
	await _test_hidden()
	await _test_loading()
	_test_unlock_rules()
	_test_announce()
	if _fails.is_empty():
		print("RESULT: OK")
	else:
		print("RESULT: FAIL (%d)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)


func _spawn(profile: Object, c: Dictionary) -> NewRunScreen:
	var s: NewRunScreen = NEW_RUN.instantiate()
	s.profile = profile
	s.characters = [c]
	add_child(s)
	return s


func _variant_button(s: NewRunScreen, slot: int, vid: String) -> Button:
	for b in s.sheet.focus_rows()[slot - 1]:
		if not bool(b.get_meta("is_base", true)) and str((b.get_meta("option") as Dictionary).get("id", "")) == vid:
			return b
	return null


# --- 1. Sélection, mémoire, transmission -------------------------------------------------

func _test_selection() -> void:
	var c := _test_character()
	var pr := FakeProfile.new()
	pr.unlocked_spells = ["flame_pillar"]
	var s := _spawn(pr, c)
	await _frames(3)
	_check(s.sheet.show_variants, "une variante débloquée : colonne de variantes visible")
	var vb := _variant_button(s, 2, "flame_pillar")
	var lb := _variant_button(s, 1, "roaming_embers")
	_check(vb != null and lb != null, "boutons de variantes présents (slot 1 verrouillé, slot 2 débloqué)")
	if vb == null or lb == null:
		s.queue_free()
		return
	_check(not bool(vb.get_meta("locked", false)) and bool(lb.get_meta("locked", false)), "états verrouillé / débloqué")
	# Manette : focus visible sur la variante, voisins câblés.
	plat_mode(2)
	vb.grab_focus()
	await _frames(2)
	_check(vb.has_focus() and vb.has_theme_stylebox_override("focus"), "manette : focus visible sur la variante")
	_check(not vb.focus_neighbor_left.is_empty() and not vb.focus_neighbor_top.is_empty() and not vb.focus_neighbor_bottom.is_empty(), "manette : voisins de focus câblés")
	# Variante verrouillée : pas de sélection, quête lisible (règle implicite win_with).
	lb.pressed.emit()
	await _frames(1)
	_check(s.sheet.chosen.get(1) == &"eclat_de_braise", "variante verrouillée : sort de base gardé")
	_check(s.tooltip._body.text.contains("Gagner une run avec Ardent"), "quête déduite de la règle : " + s.tooltip._body.text)
	# Variante débloquée : choisie + mémorisée par personnage.
	vb.pressed.emit()
	await _frames(1)
	_check(s.sheet.chosen.get(2) == &"flame_pillar", "variante débloquée sélectionnée")
	_check((pr.saved.get("ardent", {}) as Dictionary).get(2) == &"flame_pillar", "choix mémorisé dans le profil (loadout)")
	var cfg := {} # les lambdas capturent par valeur : on remplit le dictionnaire partagé
	s.start_requested.connect(func(conf: Dictionary) -> void: cfg.merge(conf, true))
	s._on_start()
	_check((cfg.get("spells", {}) as Dictionary).get(2) == &"flame_pillar" and (cfg.get("spells", {}) as Dictionary).get(1) == &"eclat_de_braise", "config de run : variante transmise")
	s.queue_free()
	await _frames(2)
	# Réouverture : choix restauré.
	plat_mode(1)
	var s2 := _spawn(pr, c)
	await _frames(3)
	_check(s2.sheet.chosen.get(2) == &"flame_pillar", "réouverture : variante restaurée")
	var ctr := CharacterSheet.variant_quest(pr, c, 2, (c["spells"][1]["variants"] as Array)[0])
	_check(ctr.contains("Compteur de test.") and ctr.contains("120 / 500"), "quête à compteur avec progression : " + ctr)
	s2.queue_free()
	await _frames(2)
	# Variante mémorisée mais plus débloquée : sort de base.
	pr.unlocked_spells = []
	_check(CharacterSheet.resolve_loadout(pr, c).get(2) == &"nova_ardente", "variante reverrouillée : base")


func plat_mode(m: int) -> void:
	var plat := get_node_or_null("/root/Platform")
	if plat != null:
		plat.set_input_mode(m)


func _test_hidden() -> void:
	var pr := FakeProfile.new()
	var s := _spawn(pr, _test_character())
	await _frames(3)
	_check(not s.sheet.show_variants, "aucune variante débloquée : colonne masquée")
	var note: Label = s.sheet.find_child("VariantsNote", true, false)
	_check(note != null and note.text.begins_with("5 variantes"), "note « N variantes à débloquer »")
	_check(s.sheet.find_child("Variant_*", true, false) == null, "aucun bouton de variante")
	var all := _all_text(s)
	_check(not all.contains("todo_design") and not all.to_lower().contains("todo"), "jamais de todo_design affiché")
	s.queue_free()
	await _frames(2)


func _all_text(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + "\n"
	for ch in n.get_children():
		out += _all_text(ch)
	return out


# --- 2. Chargement (kit) et sauvegarde de run ---------------------------------------------

func _test_loading() -> void:
	CharacterData.kit_paths[&"fake"] = FAKE_KIT
	var cd := CharacterData.for_id(&"fake", {2: &"fake_nova_b"})
	var s2: SpellData = cd.spells[1]
	_check(s2.id == &"fake_nova_b" and s2.slot == 2 and is_equal_approx(s2.coef, 4.0), "kit : variante factice chargée au slot 2")
	_check(cd.variant_of(2) == &"fake_nova_b" and cd.variant_of(1) == &"", "CharacterData.variant_of")
	_check(cd.spells[0].id == &"eclat_de_braise", "autres slots : base")
	var cd2 := CharacterData.for_id(&"fake", {"2": "inconnue", "9": "x"})
	_check(cd2.spells[1].id == &"nova_ardente" and cd2.spells.size() == 4, "variante inconnue / slot inconnu : base + warning, pas de plantage")
	var cd3 := CharacterData.for_id(&"ardent", {1: &"roaming_embers"})
	_check(cd3.spells[0].id == &"eclat_de_braise", "variante d'Ardent non codée : base")
	_check(CharacterData.for_id(&"fake", {2: &"nova_ardente"}).loadout.is_empty(), "id de base dans le loadout : rien de remplacé")
	# RunState : transmission + sauvegarde (to_dict / from_dict), anciennes sauvegardes sans clé.
	var keep_char := RunState.character
	RunState.loadout = RunState.normalize_loadout({"2": "fake_nova_b", 1: &"eclat_de_braise"})
	var d := RunState.to_dict()
	_check((d.get("loadout", {}) as Dictionary).get("2") == "fake_nova_b", "sauvegarde : run.loadout écrit")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(d))
	RunState.loadout = {}
	RunState.from_dict(parsed)
	RunState.running = false
	_check(RunState.loadout == {1: &"eclat_de_braise", 2: &"fake_nova_b"}, "reprise : loadout relu (%s)" % [RunState.loadout])
	parsed.erase("loadout")
	RunState.from_dict(parsed)
	RunState.running = false
	_check(RunState.loadout.is_empty(), "ancienne sauvegarde : sorts de base")
	# Joueur réel : SpellCaster reçoit la variante (RunState.character + RunState.loadout).
	RunState.character = &"fake"
	RunState.loadout = {2: &"fake_nova_b"}
	var p: Node = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(p)
	await _frames(2)
	var ids: Array = []
	for cdn: Dictionary in p.get_spell_cooldowns():
		ids.append(cdn["id"])
	_check(ids.has(&"fake_nova_b") and not ids.has(&"nova_ardente"), "joueur : SpellCaster avec la variante (%s)" % [ids])
	p.queue_free()
	await _frames(2)
	RunState.character = keep_char
	RunState.loadout = {}
	CharacterData.kit_paths.erase(&"fake")


# --- 3. Déblocages (Profile + VariantUnlocks) ---------------------------------------------

func _test_unlock_rules() -> void:
	var keep_path := Profile.path
	var keep_w: bool = Profile.write_enabled
	Profile.path = TEST_PROFILE
	Profile.write_enabled = false
	Profile.unlock_all_variants = false
	Profile.characters_override = [_test_character()]
	Profile.reset()
	var base := {"mode": &"moyen", "character": &"ardent", "active_time_s": 100.0, "kills": 5, "rubies": 0}
	var r := base.duplicate()
	r["victory"] = false
	r["counters"] = {"ardent.test_counter": 300.0}
	var u := Profile.add_run_result(r)
	_check(not _has_spell(u), "défaite : aucune variante (%s)" % [u])
	_check(is_equal_approx(Profile.stat("ardent.test_counter"), 300.0), "compteur de run versé dans stats")
	r = base.duplicate()
	r["victory"] = true
	u = Profile.add_run_result(r)
	_check(u.has(&"spell:roaming_embers") and Profile.is_unlocked(&"spell:roaming_embers"), "victoire avec Ardent : variante de l'auto (%s)" % [u])
	_check(not u.has(&"spell:flame_pillar"), "compteur pas encore atteint")
	r = base.duplicate()
	r["victory"] = true
	u = Profile.add_run_result(r)
	_check(not u.has(&"spell:roaming_embers"), "déjà débloquée : pas d'annonce en double")
	Profile.add_stat("ardent.test_counter", 200.0)
	r = base.duplicate()
	r["victory"] = false
	u = Profile.add_run_result(r)
	_check(u.has(&"spell:flame_pillar"), "counter : stats >= value (%s)" % [u])
	r = base.duplicate()
	r["victory"] = false
	r["bosses_killed"] = [{"id": "cerf", "floor_boss": true}]
	r["character"] = &"rictus"
	u = Profile.add_run_result(r)
	_check(not u.has(&"spell:meteor_rain"), "boss_kill : autre personnage, rien")
	r["character"] = &"ardent"
	u = Profile.add_run_result(r)
	_check(u.has(&"spell:meteor_rain"), "boss_kill : boss d'étage tué (%s)" % [u])
	r = base.duplicate()
	r["victory"] = false
	r["stage"] = 4
	u = Profile.add_run_result(r)
	_check(not u.has(&"spell:phoenix"), "floor_reached : mode trop facile")
	r["mode"] = &"difficile"
	u = Profile.add_run_result(r)
	_check(u.has(&"spell:phoenix"), "floor_reached : étage 4 en Difficile (%s)" % [u])
	_check(not Profile.is_unlocked(&"spell:mystere"), "règle inconnue : jamais débloquée")
	Profile.add_stat("autre.cle", 2.0)
	_check(is_equal_approx(Profile.stat("autre.cle"), 2.0) and int(Profile.stats["runs"]) == 8, "add_stat générique, stats intactes")
	var d := Profile.to_dict()
	Profile.reset()
	var reread: Dictionary = JSON.parse_string(JSON.stringify(d))
	_check(float((reread["stats"] as Dictionary).get("ardent.test_counter", 0.0)) == 500.0, "compteurs sérialisés dans stats")
	# Mode test « toutes les variantes » (à retirer avant sortie) : ne touche pas au profil.
	Profile.unlock_all_variants = true
	_check(Profile.is_unlocked(&"spell:phoenix") and Profile.unlocked_spells.is_empty(), "RAINFALL_UNLOCK_ALL_VARIANTS : tout visible, rien écrit")
	_check(Profile.unlock(&"spell:phoenix") and Profile.unlocked_spells.has(&"phoenix"), "mode test : un vrai déblocage s'enregistre quand même")
	Profile.unlock_all_variants = false
	OS.set_environment(Profile.UNLOCK_ALL_VARIANTS_ENV, "1")
	_check(Profile._detect_unlock_all_variants(), "variable d'environnement détectée")
	OS.unset_environment(Profile.UNLOCK_ALL_VARIANTS_ENV)
	_check(not Profile._detect_unlock_all_variants() or OS.get_cmdline_user_args().has("--unlock-variants"), "sans variable : désactivé")
	Profile.characters_override = null
	Profile.reset()
	Profile.path = keep_path
	Profile.write_enabled = keep_w
	_check(not FileAccess.file_exists(TEST_PROFILE), "aucun profil écrit")


func _has_spell(u: Array) -> bool:
	for k in u:
		if String(k).begins_with("spell:"):
			return true
	return false


# --- 4. Annonce de fin de run ---------------------------------------------------------

func _test_announce() -> void:
	var t := EndRunScreen.unlock_text(&"spell:roaming_embers")
	_check(t.contains("Braises errantes") and t.contains("Ardent") and not t.contains("roaming"), "annonce lisible : " + t)
	var t2 := EndRunScreen.unlock_text(&"spell:variante_inconnue")
	_check(not t2.contains("variante_inconnue"), "id inconnu humanisé : " + t2)
	var info := {"victory": true, "reason": &"victory", "character_name": "Ardent", "mode": &"moyen", "stage": 5,
		"active_time_s": 1100.0, "level": 30, "pillars": 4, "kills": 900, "items": 20, "gold": 10, "rubies": 50,
		"unlocks": [&"spell:roaming_embers"]}
	var s := EndRunScreen.create(info)
	add_child(s)
	_check(_all_text(s).contains("Nouvelle variante pour Ardent : Braises errantes !"), "écran de fin : ligne de déblocage de variante")
	s.queue_free()
