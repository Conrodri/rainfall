extends Node
## Objets débloquables : règles de items.json, pool de loot filtré (+ repli), déblocage en fin de run, interrupteur de test,
## récap de fin de run et section « Objets » de l'écran Progression. Profil réel de l'autoload restauré à la fin (headless : rien écrit).
## godot --headless --path game res://tests/item_unlocks_test.tscn   (RESULT: OK)

const ProfileScript := preload("res://scripts/save/profile.gd")
const RULE_TYPES := ["counter", "win_with", "boss_kill", "floor_reached"]
var _fails := 0


func _check(ok: bool, msg: String) -> void:
	print("ok   " if ok else "FAIL ", msg)
	if not ok:
		_fails += 1


func _fresh() -> Node:
	var p: Node = ProfileScript.new()
	p.write_enabled = false
	p.unlock_all_variants = false
	return p


func _ready() -> void:
	var lockable := ItemUnlocks.lockable_ids()
	_check(lockable.size() >= 10 and lockable.size() <= 16, "10-16 objets verrouillables (%d)" % lockable.size())
	_check(not ItemUnlocks.is_lockable("couronne_d_echo") and not ItemUnlocks.is_lockable("de_pipe"), "couronne et dé pipé restent libres")
	for id in lockable:
		var u := ItemUnlocks.rule_of(id)
		_check(str(u.get("text", "")) != "" and RULE_TYPES.has(str(u.get("type", ""))), "règle valide : " + id)

	# --- Profil vierge : verrouillé ; déblocage via une run ---
	var p := _fresh()
	_check(not ItemUnlocks.is_unlocked("moisson", p) and ItemUnlocks.is_unlocked("lame_jumelle", p), "moisson verrouillée, lame jumelle libre")
	var r: Array = p.add_run_result({"victory": false, "mode": "moyen", "character": "ardent", "active_time_s": 100.0, "kills": 350,
		"rubies": 0, "stage": 1, "counters": {"chests_opened": 3}, "bosses_killed": []})
	_check(r.has(&"item:orbe_de_veille") and ItemUnlocks.is_unlocked("orbe_de_veille", p), "300 kills -> Orbe de veille")
	_check(not r.has(&"item:marque_du_chasseur") and not r.has(&"item:eclair_en_bouteille"), "rien d'autre débloqué")
	_check(ItemUnlocks.progress("venin_concentre", p).get("value", -1.0) == 3.0, "avancement coffres 3/10")
	var r2: Array = p.add_run_result({"victory": false, "mode": "moyen", "character": "ardent", "active_time_s": 100.0, "kills": 10,
		"rubies": 0, "stage": 3, "counters": {"gold_collected": 6000.0}, "bosses_killed": [{"id": "cerf", "floor_boss": true}]})
	for k in [&"item:marque_du_chasseur", &"item:bouclier_reactif", &"item:faveur_du_marchand"]:
		_check(r2.has(k), "run 2 débloque " + String(k))
	_check(not r2.has(&"item:orbe_de_veille"), "orbe pas ré-annoncée")
	_check(not r2.has(&"item:armure_du_colosse"), "pas de victoire -> Armure du colosse verrouillée")
	var r3: Array = p.add_run_result({"victory": true, "mode": "moyen", "character": "rictus", "active_time_s": 100.0, "kills": 0,
		"rubies": 0, "stage": 5, "counters": {}, "bosses_killed": []})
	_check(r3.has(&"item:armure_du_colosse") and r3.has(&"item:nova_infinie"), "victoire étage 5 : Armure, Nova")
	_check(r3.has(&"item:eclair_en_bouteille"), "3e run -> Éclair en bouteille")
	var d: Dictionary = p.to_dict()
	_check(d["unlocked_items"].has("moisson") == p.unlocked_items.has(&"moisson") and d["unlocked_items"].size() == p.unlocked_items.size(), "sérialisation du profil")
	p.free()

	# --- Interrupteur de test ---
	var p3 := _fresh()
	p3.unlock_all_variants = true
	_check(ItemUnlocks.is_unlocked("moisson", p3) and p3.is_unlocked(&"item:moisson"), "interrupteur de test débloque les objets")
	p3.free()

	# --- Pool de loot (profil autoload) ---
	var prof := Profile
	var save_items: Array = prof.unlocked_items.duplicate()
	var save_all: bool = prof.unlock_all_variants
	prof.unlocked_items = []
	prof.unlock_all_variants = false
	var legend := LootRoller.available_ids(&"legendaire")
	_check(legend.size() == 3 and "couronne_d_echo" in legend and "de_pipe" in legend and "coeur_du_chronomancien" in legend, "pool légendaire de départ = 3 libres (%s)" % str(legend))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var bad := 0
	for i in 400:
		for q in ItemDB.QUALITIES:
			for id in LootRoller.pick_pair(q, {}, [], rng):
				if not ItemUnlocks.is_unlocked(id):
					bad += 1
	_check(bad == 0, "400 tirages x 4 qualités : aucun objet verrouillé offert")
	prof.unlocked_items = [&"moisson"]
	_check("moisson" in LootRoller.available_ids(&"legendaire"), "objet débloqué entre dans le pool")
	prof.unlock_all_variants = true
	_check(LootRoller.available_ids(&"legendaire") == ItemDB.ids_of_quality(&"legendaire"), "interrupteur : pool complet, ordre d'origine (graines stables)")
	# Repli : qualité sans aucun objet débloqué (items factices).
	prof.unlock_all_variants = false
	prof.unlocked_items = []
	ItemDB.set_source("res://tests/_item_unlocks_fixture.json")
	var fb := LootRoller.available_ids(&"legendaire")
	_check(fb == ["rare_libre"], "repli : légendaire entièrement verrouillée -> qualité inférieure (%s)" % str(fb))
	var pair := LootRoller.pick_pair(&"legendaire", {}, [], rng)
	_check(pair.size() == 2 and pair[0] == "rare_libre", "pick_pair avec repli (pool de 1) -> 2 entrées")
	ItemDB.set_source(ItemDB.DEFAULT_PATH)
	prof.unlocked_items = save_items
	prof.unlock_all_variants = save_all

	# --- Récap de fin de run ---
	var scr := EndRunScreen.create({"victory": true, "reason": &"victory", "character_name": "Ardent", "mode": &"moyen", "stage": 5,
		"active_time_s": 600.0, "level": 10, "pillars": 3, "kills": 300, "items": 0, "gold": 10, "rubies": 5,
		"unlocks": [&"item:moisson", &"item:nova_infinie"]})
	add_child(scr)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(scr.find_child("NewItems", true, false) != null and scr.find_child("NewItem_moisson", true, false) != null, "récap : bloc « Nouveaux objets débloqués »")
	_check(EndRunScreen.unlock_text(&"item:moisson") == "Nouvel objet : Moisson !", "texte d'objet débloqué")
	_check(_no_frame_over_icon(scr.find_child("NewItem_moisson", true, false)), "récap : fond de qualité derrière l'icône, aucun cadre par-dessus")
	scr.queue_free()

	# --- Écran Progression : onglet Objets ---
	var pp := _fresh()
	pp.stats["kills"] = 340
	pp.unlocked_items.append(&"moisson")
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child(host)
	var ps := ProgressScreen.new()
	ps.profile = pp
	host.add_child(ps)
	ps.size = host.size
	for i in 4:
		await get_tree().process_frame
	_check(ps.item_cells.size() == ItemDB.all_ids().size(), "une cellule par objet (%d)" % ps.item_cells.size())
	var open := 0
	for id in ItemDB.all_ids():
		if ItemUnlocks.is_unlocked(id, pp):
			open += 1
	_check(ps.items_count_label.text == "%d/%d objets débloqués" % [open, ItemDB.all_ids().size()], "compteur : " + ps.items_count_label.text)
	_check(not ps.items_scroll.visible and ps._chars_scroll.visible, "onglet Personnages par défaut")
	ps.tab_items.pressed.emit()
	await get_tree().process_frame
	ps._layout()
	_check(ps.items_scroll.visible and not ps._chars_scroll.visible, "onglet Objets affiché")
	var locked_cell := ps.find_child("Item_tempete_de_braises", true, false)
	_check(locked_cell != null and locked_cell.find_child("Condition", true, false) != null, "objet verrouillé : condition affichée")
	var prog: Node = locked_cell.find_child("Progress", true, false) if locked_cell != null else null
	_check(prog != null and (prog as ProgressBar).value == 340.0 and (prog as ProgressBar).max_value == 1500.0, "barre d'avancement 340/1500")
	var open_cell := ps.find_child("Item_moisson", true, false)
	var icon_box: Node = open_cell.find_child("QualityBack", true, false).get_parent() if open_cell != null and open_cell.find_child("QualityBack", true, false) != null else null
	_check(icon_box != null and _no_frame_over_icon(icon_box), "onglet Objets : fond de qualité derrière l'icône, aucun cadre par-dessus")
	_check(open_cell != null and open_cell.find_child("Condition", true, false) == null, "objet débloqué : pas de condition")
	var sr := Rect2(ps.items_scroll.global_position, ps.items_scroll.size)
	var back := Rect2(ps.back_button.global_position, ps.back_button.size)
	_check(not sr.intersects(back) and Rect2(Vector2.ZERO, host.size).encloses(sr), "zone d'objets sans chevauchement ni débordement")
	for c in ps.item_cells:
		_check_cell_text(c)
	ps.queue_free()
	pp.free()

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


## Aucun texte de cellule ne dépasse la cellule : autowrap borné sur effet et condition, rognage du nom.
func _check_cell_text(c: Button) -> void:
	for n in ["Name", "Effect", "Condition"]:
		var l := c.find_child(n, true, false) as Label
		if l == null:
			continue
		if n == "Name":
			_check(l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING, "%s/%s : nom rogné si trop long" % [c.name, n])
		else:
			_check(l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.max_lines_visible > 0, "%s/%s : retour à la ligne borné" % [c.name, n])


## Le 1er enfant est le fond de qualité (Panel) et aucune texture « frame_<qualité> » n'est dessinée par-dessus l'icône.
func _no_frame_over_icon(box: Node) -> bool:
	if box == null or box.get_child_count() < 1 or box.get_child(0).name != "QualityBack" or not (box.get_child(0) is Panel):
		return false
	for n in box.get_children():
		if n is TextureRect and n.texture != null and "/frame_" in n.texture.resource_path:
			return false
	return true
