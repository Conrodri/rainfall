extends Node
## Sons des variantes de sorts (lot VARIANTES_AUDIO) : chaque variante a ses clés cast_light|medium|heavy et hit_*
## (sauf les variantes sans coup direct), découvertes automatiquement ; play_cast choisit bien la clé de la variante.
## godot --headless --path game res://tests/variant_sounds_test.tscn

const IDS_ALL: Array[String] = [
	"tocsin_vapeur", "tocsin_tete_fumigene",
	"averse_bruine", "averse_geyser", "averse_gouttiere", "averse_mousson",
	"arpenteuse_chaine_lestee", "arpenteuse_noeud", "arpenteuse_jalons", "arpenteuse_cerceau",
	"rainette_croassement", "rainette_ricochet", "rainette_bulle", "rainette_choeur",
	"avare_coffre_belier", "avare_piece_truquee", "avare_saisie", "avare_tresor_enterre",
	"bourbe_crachat_de_vase", "bourbe_bouture", "bourbe_eclatement", "bourbe_maree_de_vase",
	"rictus_main_du_montreur", "rictus_eventail", "rictus_toupie", "rictus_rideau",
	"vigie_tir_double", "vigie_fanal", "vigie_chausse_trapes", "vigie_tir_de_signal",
	"morfil_taille_lente", "morfil_fendoir", "morfil_affutage_en_marche", "morfil_trempe",
]
const NO_HIT: Array[String] = ["vigie_fanal", "morfil_affutage_en_marche"]
var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)


func _ready() -> void:
	await get_tree().process_frame
	var bank = Audio.bank
	_check(bank.load_ok, "sounds.json chargé")
	for id in IDS_ALL:
		for lvl in ["light", "medium", "heavy"]:
			_check(bank.has_sound(StringName("spell.%s.cast_%s" % [id, lvl])), "%s cast_%s" % [id, lvl])
			if not NO_HIT.has(id):
				_check(bank.has_sound(StringName("spell.%s.hit_%s" % [id, lvl])), "%s hit_%s" % [id, lvl])
		# play_cast ne plante pas et résout la clé de puissance
		Audio.play_cast(StringName(id), Vector2.ZERO, 1.0)
		Audio.play_cast(StringName(id), Vector2.ZERO, 5.0)
	print("clés vérifiées : %d variantes" % IDS_ALL.size())
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
