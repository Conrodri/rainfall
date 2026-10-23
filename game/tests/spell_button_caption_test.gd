extends Node
## godot --headless --path game res://tests/spell_button_caption_test.tscn
## Lot UX A (audit HUD H2/H4/H10/H18) : initiale de repli (jamais le nom complet), rien d'autre que le chiffre
## en recharge, pas d'invite de touche sous le sort 1 (mais la colonne garde sa hauteur), sous-couche claire.

var _fails := 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", msg)
	else:
		print("ok: ", msg)


func _ready() -> void:
	# repli : initiale, pas de nom
	var b := SpellButton.new()
	b.interactive = false
	add_child(b)
	b.setup(3, 110.0)
	b.set_spell(&"sort_sans_icone_xyz", "Fusée de détresse")
	_check(b.icon == null, "sort sans icône livrée")
	_check(b.initial() == "F", "initiale « F » (pas le nom complet)")
	b.set_spell(&"autre_sans_icone", "éclat")
	_check(b.initial() == "É", "initiale en majuscule accentuée")
	var e := SpellButton.new()
	add_child(e)
	e.setup(4, 110.0)
	_check(e.initial() == "4", "sans nom : numéro du slot")
	# recharge : ne plante pas, le libellé n'est pas modifié (initiale seule, effacée)
	b.set_cooldown(4.9, 8.0)
	await get_tree().process_frame
	_check(b.caption == "éclat", "nom conservé pour les lecteurs, jamais dessiné en entier")
	b.set_cooldown(0.0, 8.0)
	# sous-couche claire
	_check(SpellButton.ICON_UNDERLAY.a >= 0.18 and SpellButton.ICON_UNDERLAY.get_luminance() > 0.6, "sous-couche claire alpha >= 0,18")
	# plancher de police
	_check(SpellButton._font_floor() >= 18, "plancher de police >= 18 px")
	# roulade : le nom ne bouge pas pendant la recharge
	var d := DodgeButton.new()
	d.interactive = false
	add_child(d)
	d.setup(0, 90.0)
	d.set_cooldown(2.0, 3.0)
	_check(d.caption == "Roulade" and d.initial() == "R", "roulade : nom conservé, initiale « R »")
	# invite de touche : sort 1 vide mais de même hauteur
	var k1 := KeyPrompt.new()
	add_child(k1)
	k1.set_action(&"spell_1", "Auto")
	_check(k1.text() == "", "sort 1 : aucune invite de touche")
	_check(k1.get_child_count() == 1 and k1.get_child(0).custom_minimum_size.y == k1.height, "sort 1 : colonne vide de même hauteur")
	var k2 := KeyPrompt.new()
	add_child(k2)
	k2.set_action(&"spell_2")
	_check(k2.get_child_count() > 0, "sort 2 : invite conservée")
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
