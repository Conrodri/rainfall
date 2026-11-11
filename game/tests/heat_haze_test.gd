extends Node
## Brume de chaleur du Ciel « Canicule de cendres » : profil canicule actif à l'intensité attendue
## (Haut 1, Moyen 0,5), autres profils inactifs, Bas coupé, estompée par la pluie (Hostile), coupée par
## « Réduire les mouvements ». godot --headless --path game res://tests/heat_haze_test.tscn

const CANICULE := "res://data/ambiance/cite_rouille_canicule_de_cendres.tres"
const CANICULE2 := "res://data/ambiance/cite_fonderie_canal_canicule_de_cendres.tres"
var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)


func _ready() -> void:
	Quality.persist = false
	Quality.dynamic_degrade = false
	var mgr: AmbianceManager = load("res://scenes/ambiance/ambiance_manager.tscn").instantiate()
	mgr.auto_bind = false
	add_child(mgr)
	await get_tree().process_frame
	var nominal := AmbianceManager.HAZE_MAX_SHIFT

	# Profils : seuls les deux Ciels canicule portent la brume ; toutes les autres cartes = 0.
	for path in [CANICULE, CANICULE2]:
		var cp := load(path) as AmbianceProfile
		_check(cp != null and cp.heat_haze_strength > 0.0, "%s : brume de chaleur définie" % path)
		_check(AmbianceTextures.is_real(cp.heat_haze_texture), "tuile %s livrée" % cp.heat_haze_texture)
	var dir := DirAccess.open("res://data/ambiance")
	for f in dir.get_files():
		if f.ends_with(".tres") and not f.contains("canicule"):
			var op := load("res://data/ambiance/" + f) as AmbianceProfile
			_check(op != null and op.heat_haze_strength == 0.0, "%s : pas de brume de chaleur" % f)

	# Haut : canicule à D = 1 (aucune pluie) = amplitude nominale.
	Quality.set_tier(Quality.Tier.HIGH, true)
	mgr.set_difficulty(1.0)
	_check(mgr.apply_profile_resource(load(CANICULE) as AmbianceProfile, &"cite_rouille", true), "profil canicule appliqué")
	mgr._process(0.016)
	_check(is_equal_approx(mgr.haze_amount_applied, nominal), "Haut : amplitude nominale (%.5f)" % mgr.haze_amount_applied)
	var m := mgr.grade_rect.material as ShaderMaterial
	_check(is_equal_approx(float(m.get_shader_parameter(&"haze_amount")), nominal), "shader : haze_amount = nominal")
	_check(m.get_shader_parameter(&"haze_tex") != null, "shader : tuile liée")
	var t0 := float(m.get_shader_parameter(&"time_s"))
	mgr._process(0.5)
	_check(float(m.get_shader_parameter(&"time_s")) > t0, "la tuile défile")

	# Moyen : réduite de moitié.
	Quality.set_tier(Quality.Tier.MEDIUM, true)
	mgr._process(0.016)
	_check(is_equal_approx(mgr.haze_amount_applied, nominal * 0.5), "Moyen : amplitude réduite (%.5f)" % mgr.haze_amount_applied)

	# Bas : coupée (matériau vignette, aucune lecture de l'écran).
	Quality.set_tier(Quality.Tier.LOW, true)
	mgr._process(0.016)
	_check(mgr.haze_amount_applied == 0.0, "Bas : coupée")
	_check(mgr.grade_rect.material != mgr._grade_mat, "Bas : matériau vignette (pas de lecture de l'écran)")

	# Pluie : estompée jusqu'à Hostile (D = 3,25 : pluie 0,75), nulle ensuite.
	Quality.set_tier(Quality.Tier.HIGH, true)
	var prev := nominal + 1.0
	for D in [1.0, 2.0, 2.6, 3.25, 5.0]:
		_set_d(mgr, D)
		_check(mgr.haze_amount_applied <= prev + 1e-9, "brume décroissante avec D (D=%.2f : %.5f)" % [D, mgr.haze_amount_applied])
		prev = mgr.haze_amount_applied
	_check(mgr.haze_amount_applied == 0.0, "brume nulle au palier Hostile et au-delà (%.5f)" % mgr.haze_amount_applied)
	_set_d(mgr, 1.0)
	_check(is_equal_approx(mgr.haze_amount_applied, nominal), "retour à D = 1 : amplitude nominale")

	# Réduire les mouvements : coupée.
	var was := GameSettings.reduce_motion()
	GameSettings._reduce = true
	mgr._process(0.016)
	_check(mgr.haze_amount_applied == 0.0, "réduire les mouvements : coupée")
	GameSettings._reduce = was

	# Autre profil (Cité de rouille classique) : inactif.
	_check(mgr.apply_profile(&"cite_rouille", true), "profil cite_rouille appliqué")
	_set_d(mgr, 1.0)
	_check(mgr.haze_amount_applied == 0.0, "profil standard : inactif")
	_check(is_zero_approx(float((mgr.grade_rect.material as ShaderMaterial).get_shader_parameter(&"haze_amount"))), "profil standard : shader à 0")

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


## Pose D sans attendre le lissage (demi-vie 2 s) puis rend une image d'ambiance.
func _set_d(mgr: AmbianceManager, D: float) -> void:
	mgr.set_difficulty(D)
	mgr._target = mgr.profile.evaluate(D)
	mgr._current = mgr._target.duplicate()
	mgr._process(0.016)
