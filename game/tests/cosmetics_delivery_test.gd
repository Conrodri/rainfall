extends Node
## Livraisons Codex des cosmétiques v1 : chaque asset cité par les articles livrés se charge (PNG -> Texture2D,
## .tres -> SpriteFrames), chaque Panoplie reprend les animations du personnage par défaut (mêmes noms, mêmes nombres
## de frames, mêmes tailles de frames, boucle et vitesse), `Cosmetics.has_assets` reconnaît l'article, et le catalogue ne
## marque plus `pending` un article livré.
## godot --headless --path game res://tests/cosmetics_delivery_test.tscn   (RESULT: OK)

## Articles livrés au lot 1 et complets (les autres du catalogue restent `pending`).
const DELIVERED: Array[String] = [
	"averse_avant_la_pluie", "vigie_avant_la_pluie", "ardent_avant_la_pluie", "rictus_avant_la_pluie",
	"braises", "bronze_de_cloche", "bivouac_des_cedres", "nuit_de_lanternes",
]
## Livrés mais bloqués : doivent rester `pending` tant que le défaut n'est pas corrigé (aucun pour l'instant).
const BLOCKED: Array[String] = []
## Animations à jouer au minimum (une par direction, celles que le défaut possède).
const MUST_HAVE: Array[String] = ["idle", "run"]
const DIRS: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
var _fails := 0


func _check(ok: bool, msg: String) -> void:
	print("ok   " if ok else "FAIL ", msg)
	if not ok:
		_fails += 1


func _load_frames(path: String) -> SpriteFrames:
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as SpriteFrames


func _frame_size(sf: SpriteFrames, anim: StringName, i: int) -> Vector2:
	var t := sf.get_frame_texture(anim, i)
	return t.get_size() if t != null else Vector2.ZERO


func _ready() -> void:
	Cosmetics.data_override = null
	Cosmetics.reload()
	for id in DELIVERED:
		var it := Cosmetics.item(id)
		_check(not it.is_empty(), "%s : dans le catalogue" % id)
		if it.is_empty():
			continue
		# Chaque asset cité existe et se charge.
		var loads := true
		for p in Cosmetics.asset_paths(it):
			var res: Resource = ResourceLoader.load(p) if ResourceLoader.exists(p) else null
			var good := res != null
			if p.ends_with(".tres") and good:
				good = res is SpriteFrames or res is Resource
			if not good and not p.ends_with(".tscn") and not p.ends_with(".json"):
				loads = false
				print("     ne charge pas : ", p)
			elif not good and FileAccess.file_exists(p):
				pass
			elif not good:
				loads = false
				print("     absent : ", p)
		_check(loads, "%s : tous les assets cités se chargent" % id)
		var probe := it.duplicate(true)
		probe.erase("pending")
		var recognised := Cosmetics.has_assets(probe)
		_check(recognised, "%s : has_assets reconnaît l'article (hors drapeau pending)" % id)
		_check(not bool(it.get("pending", false)) == recognised, "%s : drapeau pending cohérent avec has_assets" % id)
		var pv := Cosmetics.preview_path(it)
		_check(pv != "", "%s : aperçu présent" % id)
		if pv != "":
			var tex := ResourceLoader.load(pv) as Texture2D
			_check(tex != null and tex.get_size() == Vector2(256, 256), "%s : aperçu 256x256" % id)
		if Cosmetics.family_of(it) == &"panoplie":
			_check_panoplie(it)
		elif Cosmetics.family_of(it) == &"sillage":
			var sf := _load_frames(Cosmetics.asset(it, "frames"))
			_check(sf != null and sf.get_animation_names().size() > 0, "%s : SpriteFrames du sillage non vide" % id)
		elif Cosmetics.family_of(it) == &"ciel":
			# Chaque profil d'ambiance du Ciel se charge et passe le garde-fou de luminance (0,42).
			var profs: Array = (it.get("assets", {}) as Dictionary).get("profiles", [])
			_check(profs.size() >= 2, "%s : un profil par carte du biome" % id)
			for pp in profs:
				var prof := load(str(pp)) as AmbianceProfile
				_check(prof != null and AmbianceManager.ciel_readable(prof), "%s : profil %s lisible (luminance >= 0,42)" % [id, str(pp).get_file()])
		elif Cosmetics.family_of(it) == &"veillee":
			var sf2 := _load_frames(Cosmetics.asset(it, "fire"))
			_check(sf2 != null and sf2.has_animation(&"burn") and sf2.get_frame_count(&"burn") > 0, "%s : feu animé (burn)" % id)
	for id in BLOCKED:
		var bit := Cosmetics.item(id)
		_check(not bit.is_empty() and bool(bit.get("pending", false)), "%s : bloqué, reste pending" % id)
		_check(not Cosmetics.has_assets(bit), "%s : non proposé à l'achat (has_assets faux)" % id)
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check_panoplie(it: Dictionary) -> void:
	var id := str(it.id)
	var cid := str(it.target)
	var def_path := str(Skins.character(cid).get("sprite_frames", ""))
	var def_sf := _load_frames(def_path)
	var sk_path := Skins.skin_frames_path(cid, id)
	var sk_sf := _load_frames(sk_path)
	_check(def_sf != null and sk_sf != null, "%s : SpriteFrames défaut (%s) et Panoplie (%s) chargés" % [id, def_path, sk_path])
	if def_sf == null or sk_sf == null:
		return
	_check(Skins.has_assets(cid, id), "%s : Skins.has_assets" % id)
	_check(Skins.skins_of(cid).any(func(s: Dictionary) -> bool: return str(s.get("id", "")) == id), "%s : listé dans Skins.skins_of(%s)" % [id, cid])
	for a in MUST_HAVE:
		var ok_dirs := true
		var wanted := 0
		for d in DIRS:
			var nm := "%s_%s" % [a, d]
			if def_sf.has_animation(nm):
				wanted += 1
				ok_dirs = ok_dirs and sk_sf.has_animation(nm) and sk_sf.get_frame_count(nm) > 0
		_check(ok_dirs and (wanted > 0 or a != "idle"), "%s : animation %s (%d directions du défaut) présente" % [id, a, wanted])
	var def_names := Array(def_sf.get_animation_names())
	var sk_names := Array(sk_sf.get_animation_names())
	def_names.sort()
	sk_names.sort()
	_check(def_names == sk_names, "%s : mêmes %d noms d'animations que le défaut" % [id, def_names.size()])
	if def_names != sk_names:
		var missing := def_names.filter(func(n: Variant) -> bool: return not sk_names.has(n))
		var extra := sk_names.filter(func(n: Variant) -> bool: return not def_names.has(n))
		print("     manquantes : ", missing, " en trop : ", extra)
	var frames_ok := true
	var size_ok := true
	var loop_ok := true
	var null_ok := true
	for a in def_names:
		if not sk_sf.has_animation(a):
			continue
		var n := def_sf.get_frame_count(a)
		if sk_sf.get_frame_count(a) != n:
			frames_ok = false
			print("     frames ", a, " : défaut ", n, " panoplie ", sk_sf.get_frame_count(a))
			continue
		if sk_sf.get_animation_loop(a) != def_sf.get_animation_loop(a) or not is_equal_approx(sk_sf.get_animation_speed(a), def_sf.get_animation_speed(a)):
			loop_ok = false
			print("     boucle/vitesse ", a)
		for i in n:
			if sk_sf.get_frame_texture(a, i) == null:
				null_ok = false
				continue
			if _frame_size(sk_sf, a, i) != _frame_size(def_sf, a, i):
				size_ok = false
				print("     taille ", a, "#", i, " : ", _frame_size(def_sf, a, i), " vs ", _frame_size(sk_sf, a, i))
				break
	_check(frames_ok, "%s : même nombre de frames par animation" % id)
	_check(null_ok, "%s : aucune frame sans texture" % id)
	_check(size_ok, "%s : mêmes tailles de frames" % id)
	_check(loop_ok, "%s : mêmes boucle et vitesse" % id)
	var por := Skins.portrait_info(cid, id)
	_check(bool(por.exists) and (por.tex as Texture2D).get_size() == Vector2(256, 256), "%s : portrait 256x256" % id)
