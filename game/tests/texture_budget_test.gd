extends Node
## Budget textures (mobile d'abord) — pendant Godot de art/tools/texture_budget.py.
## godot --headless --path game res://tests/texture_budget_test.tscn  -> RESULT: OK
## Règles (tests/texture_budget.json) :
##  1. aucune PNG de res://assets > max_side_px (4096) de côté, sauf liste d'attente d'un re-rendu Codex ;
##  2. aucune normal map <f>_n à côté d'un diffus <f> (retirées le 22/10/2026, archivées dans
##     art/archive_normals/) ; un masque <f>_e a la taille du diffus <f> (rapport 1) ou sa demi-résolution
##     ((w+1)/2 × (h+1)/2, rapport 1/2 : art/tools/halve_emission.py ; NormalMaps déduit le rapport des tailles) ;
##  3. chaque région d'AtlasTexture des .tres tient dans sa planche (découpes en atlases ; régions posées
##     sur un _e réduit = coordonnées du diffus) ;
##  4. import 2D : pas de mipmaps, paramètres conformes à import_policy (VRAM haute qualité, UI lossless) ;
##  5. textures embarquées sur mobile (ASTC deflaté comme dans l'APK) <= apk_textures_mb.
## Lecture des en-têtes PNG et du texte des .tres seulement : aucune texture n'est chargée en mémoire.

const BUDGET_PATH := "res://tests/texture_budget.json"
const MB := 1048576.0

var _fails := 0
var _sizes: Dictionary = {} ## chemin res:// -> Vector2i


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  ok  ", msg)
	else:
		_fails += 1
		print("  FAIL ", msg)


func _ready() -> void:
	var budget: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUDGET_PATH))
	_check(budget != null and budget.has("max_side_px"), "budget lisible (%s)" % BUDGET_PATH)
	if budget == null:
		_finish()
		return
	var max_side := int(budget["max_side_px"])
	var allow: Dictionary = budget.get("oversize_allowlist", {})
	var pngs: Array[String] = []
	_walk("res://assets", pngs)
	_check(pngs.size() > 500, "PNG trouvées : %d" % pngs.size())
	for p in pngs:
		_sizes[p] = _png_size(p)

	# 1. Côté maximal.
	var over: Array[String] = []
	for p in pngs:
		var s: Vector2i = _sizes[p]
		if maxi(s.x, s.y) > max_side:
			var key := p.trim_prefix("res://")
			if allow.has(key):
				print("  note %s %dx%d toléré jusqu'au lot Codex %s" % [key, s.x, s.y, allow[key]])
			else:
				over.append("%s %dx%d" % [key, s.x, s.y])
	_check(over.is_empty(), "aucune texture > %d px de côté hors liste d'attente %s" % [max_side, over])
	for key in allow:
		var s2: Vector2i = _sizes.get("res://" + key, Vector2i.ZERO)
		if maxi(s2.x, s2.y) <= max_side:
			print("  note %s n'est plus hors limite : le retirer de oversize_allowlist" % key)

	# 2. Plus de normal maps ; masques _e alignés sur le diffus.
	# Un `<f>_n.png` sans diffus `<f>.png` est une texture ordinaire (ex. rampart_corner_n = coin nord).
	var normals: Array[String] = []
	var mismatched: Array[String] = []
	for p in pngs:
		if p.ends_with("_n.png") and _sizes.has(p.trim_suffix("_n.png") + ".png"):
			normals.append(p.trim_prefix("res://assets/sprites/"))
		if p.ends_with("_e.png"):
			var d: String = p.trim_suffix("_e.png") + ".png"
			if _sizes.has(d) and not _emission_size_ok(_sizes[p], _sizes[d]):
				mismatched.append("%s %s != %s" % [p.get_file(), _sizes[p], _sizes[d]])
	_check(normals.is_empty(), "aucune normal map _n (décision 22/10/2026 : déplacer vers art/archive_normals/) %d %s" % [normals.size(), normals.slice(0, 5)])
	_check(mismatched.is_empty(), "_e de la taille du diffus ou de sa demi-résolution (rapport 1 ou 1/2) %s" % [mismatched])

	# 3. Régions des AtlasTexture dans leur planche.
	var tres: Array[String] = []
	_walk("res://assets", tres, ".tres")
	var bad_regions: Array[String] = []
	var n_regions := 0
	for t in tres:
		n_regions += _check_tres_regions(t, bad_regions)
	_check(bad_regions.is_empty() and n_regions > 1000,
		"%d régions d'atlas dans %d .tres, toutes dans leur planche %s" % [n_regions, tres.size(), bad_regions.slice(0, 8)])

	# 4-5. Paramètres d'import (politique du budget) et poids embarqué sur mobile.
	var policy: Dictionary = budget.get("import_policy", {})
	var mips: Array[String] = []
	var off_policy: Array[String] = []
	var mobile_bytes := 0
	var vram_bytes := 0
	for p in pngs:
		var imp := _read_import(p + ".import")
		if imp.get("mipmaps/generate", "false") == "true":
			mips.append(p.get_file())
		var want := _expected_params(p.trim_prefix("res://"), policy)
		for k: String in want:
			if str(imp.get(k, "")) != _fmt(want[k]):
				off_policy.append("%s %s=%s (attendu %s)" % [p.trim_prefix("res://assets/sprites/"), k, imp.get(k, "?"), _fmt(want[k])])
				break
		var s: Vector2i = _sizes[p]
		vram_bytes += s.x * s.y * (1 if int(imp.get("compress/mode", "0")) == 2 else 4)
		var dests: Array = imp.get("dest_files", [])
		var has_astc := dests.any(func(x: String) -> bool: return ".astc." in x)
		for dest: String in dests:
			if ".s3tc." in dest or ".bptc." in dest or (".etc2." in dest and has_astc):
				continue
			var bytes := FileAccess.get_file_as_bytes(dest)
			# VRAM (ASTC/ETC2) : stocké brut, deflaté dans l'APK ; lossless : déjà compressé.
			mobile_bytes += bytes.compress(FileAccess.COMPRESSION_DEFLATE).size() if ".astc." in dest or ".etc2." in dest else bytes.size()
	_check(mips.is_empty(), "aucune texture 2D avec mipmaps %s" % [mips.slice(0, 5)])
	_check(off_policy.is_empty(), "%d .import conformes à import_policy (sinon : python art/tools/texture_budget.py --apply-policy) %s" % [pngs.size() - off_policy.size(), off_policy.slice(0, 5)])
	print("  info mémoire GPU si tout était chargé : %.0f Mo" % (vram_bytes / MB))
	var cap := float(budget["apk_textures_mb"])
	_check(mobile_bytes / MB <= cap, "textures embarquées sur mobile (ASTC deflaté) : %.0f Mo <= %.0f Mo" % [mobile_bytes / MB, cap])
	_finish()


func _finish() -> void:
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(_fails)


## Masque _e : même taille que le diffus, ou demi-résolution arrondie au-dessus (halve_emission.py).
static func _emission_size_ok(e: Vector2i, d: Vector2i) -> bool:
	return e == d or e == Vector2i((d.x + 1) / 2, (d.y + 1) / 2)


func _expected_params(rel: String, policy: Dictionary) -> Dictionary:
	var lossless := false
	for d: String in policy.get("lossless_dirs", []):
		if rel.begins_with(d):
			lossless = true
	var out: Dictionary = (policy.get("lossless" if lossless else "default", {}) as Dictionary).duplicate()
	if not out.has("process/size_limit"):
		out["process/size_limit"] = 0
	out.merge(policy.get("overrides", {}).get(rel, {}), true)
	return out


func _fmt(v: Variant) -> String:
	if v is bool:
		return "true" if v else "false"
	if v is float and is_equal_approx(v, roundf(v)):
		return str(int(v)) ## JSON lit 2 en 2.0
	return str(v)


func _walk(dir: String, out: Array[String], ext := ".png") -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if d.current_is_dir():
			if not n.begins_with("."):
				_walk(dir.path_join(n), out, ext)
		elif n.ends_with(ext):
			out.append(dir.path_join(n))
		n = d.get_next()


func _png_size(path: String) -> Vector2i:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return Vector2i.ZERO
	var h := f.get_buffer(24)
	if h.size() < 24:
		return Vector2i.ZERO
	f.big_endian = true
	f.seek(16)
	var w := f.get_32()
	var hh := f.get_32()
	return Vector2i(w, hh)


func _read_import(path: String) -> Dictionary:
	var out := {}
	var txt := FileAccess.get_file_as_string(path)
	for line in txt.split("\n"):
		var i := line.find("=")
		if i <= 0 or line.begins_with("["):
			continue
		var k := line.substr(0, i)
		var v := line.substr(i + 1)
		if k == "dest_files":
			var arr: Array[String] = []
			var re := RegEx.create_from_string("\"([^\"]+)\"")
			for m in re.search_all(v):
				arr.append(m.get_string(1))
			out[k] = arr
		else:
			out[k] = v
	return out


## Vérifie, sans rien charger, que chaque region d'AtlasTexture tient dans la planche pointée
## (directement, ou via la diffuse_texture d'une CanvasTexture éventuelle). Renvoie le nombre de régions vues.
func _check_tres_regions(path: String, bad: Array[String]) -> int:
	var txt := FileAccess.get_file_as_string(path)
	if not "AtlasTexture" in txt:
		return 0
	var ext := {}
	var re_ext := RegEx.create_from_string("\\[ext_resource type=\"Texture2D\"[^\\]]*path=\"([^\"]+)\" id=\"([^\"]+)\"\\]")
	for m in re_ext.search_all(txt):
		ext[m.get_string(2)] = m.get_string(1)
	var canvas := {}
	var cur_type := ""
	var cur_id := ""
	var atlas_ref := ""
	var n := 0
	for line in txt.split("\n"):
		if line.begins_with("[sub_resource"):
			var m := RegEx.create_from_string("type=\"(\\w+)\" id=\"([^\"]+)\"").search(line)
			cur_type = m.get_string(1) if m else ""
			cur_id = m.get_string(2) if m else ""
			atlas_ref = ""
		elif line.begins_with("["):
			cur_type = ""
		elif cur_type == "CanvasTexture" and line.begins_with("diffuse_texture = ExtResource(\""):
			canvas[cur_id] = line.get_slice("\"", 1)
		elif cur_type == "AtlasTexture" and line.begins_with("atlas = "):
			atlas_ref = line.trim_prefix("atlas = ")
		elif cur_type == "AtlasTexture" and line.begins_with("region = Rect2("):
			var nums := line.trim_prefix("region = Rect2(").trim_suffix(")").split(",")
			if nums.size() != 4:
				continue
			var r := Rect2(float(nums[0]), float(nums[1]), float(nums[2]), float(nums[3]))
			var eid := ""
			if atlas_ref.begins_with("ExtResource(\""):
				eid = atlas_ref.get_slice("\"", 1)
			elif atlas_ref.begins_with("SubResource(\""):
				eid = canvas.get(atlas_ref.get_slice("\"", 1), "")
			var tex_path: String = ext.get(eid, "")
			if tex_path == "" or not _sizes.has(tex_path):
				continue
			n += 1
			var s: Vector2i = _sizes[tex_path]
			var diffuse := tex_path.trim_suffix("_e.png") + ".png"
			if tex_path.ends_with("_e.png") and _sizes.has(diffuse):
				s = _sizes[diffuse] # régions d'un .tres d'émission = coordonnées du diffus (_e éventuellement réduit)
			if r.position.x < 0 or r.position.y < 0 or r.end.x > s.x + 0.5 or r.end.y > s.y + 0.5:
				bad.append("%s %s hors %s" % [path.get_file(), r, s])
	return n
