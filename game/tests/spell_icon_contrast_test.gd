extends Node
## Lisibilité des icônes de sort : après normalisation (SpellButton.icon_gain), la luminance effective des
## 4 icônes de Vigie est au moins celle des icônes d'Ardent (moins une marge de 5 %), et les gains restent bornés.
## godot --headless --path game res://tests/spell_icon_contrast_test.tscn

const DIR := "res://assets/sprites/icons/spells/"
const ARDENT := ["eclat_de_braise", "nova_ardente", "brasier", "braises_errantes", "pilier_de_flamme", "phenix", "pluie_de_meteores"]
const VIGIE := ["vigie_trait", "vigie_fusee", "vigie_filet", "vigie_grele"]

var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)


func _eff(name: String) -> float:
	var tex := load(DIR + name + ".png") as Texture2D
	_check(tex != null, "icône absente : " + name)
	if tex == null:
		return 0.0
	var l := SpellButton.icon_luma(tex)
	var g := SpellButton.icon_gain(tex)
	_check(g >= 1.0 and g <= SpellButton.ICON_MAX_GAIN, "gain hors bornes %s : %.2f" % [name, g])
	return minf(l * g, 1.0)


func _ready() -> void:
	var ard_min := 1.0
	for n in ARDENT:
		ard_min = minf(ard_min, _eff(n))
	for n in VIGIE:
		var e := _eff(n)
		print("%s luma=%.3f effective=%.3f (Ardent min %.3f)" % [n, SpellButton.icon_luma(load(DIR + n + ".png")), e, ard_min])
		_check(e >= ard_min * 0.95, "contraste Vigie < Ardent : %s %.3f < %.3f" % [n, e, ard_min])
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
