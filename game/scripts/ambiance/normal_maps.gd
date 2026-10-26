class_name NormalMaps
extends RefCounted
## Masques d'émission des rendus Blender (nom historique : les normal maps ont été retirées le
## 22/10/2026, décision du joueur — rendu cel partout, budget mobile 180 Mo ; archives dans
## art/archive_normals/). Les sprites sont éclairés à plat par les Light2D (aucune normale).
##
## Convention de fichiers (CLAUDE.md) : <f>.png (diffus), <f>_e.png (émission, optionnelle),
## même découpage. Aucun `<f>_n.png` n'est produit ni chargé.
##
## Utilisation (un seul nœud visuel touché) :
##   Sprite2D :          NormalMaps.apply_to_sprite($Visual)               # enfant d'émission
##   AnimatedSprite2D :  NormalMaps.apply_to_animated($Visual)             # enfant d'émission synchronisé
## Les SpriteFrames d'émission sont mis en cache par chemin : appeler à chaque spawn ne recharge rien.
## Sans _e.png, rien n'est ajouté (aucune erreur).
##
## Émission : si <f>_e.png existe, un enfant « Emission » (même sprite, texture d'émission,
## matériau unshaded + additif + shader `emissive.gdshader`) est ajouté. Unshaded = il échappe au
## CanvasModulate et aux lumières (vérifié sur Mobile 4.7 : tests/ambiance_probe.gd) ; l'énergie
## > 1 nourrit le glow HDR. Régler `emission_energy` ou pulser via `set_emission_energy()`.
##
## Taille du `_e` : pleine taille (= diffus) ou demi-résolution ((w+1)//2 × (h+1)//2, réduit hors ligne
## par art/tools/halve_emission.py, budget mobile). Le rapport est déduit des tailles diffus/_e
## (`emission_ratio`), jamais du nom : l'enfant Emission reçoit l'échelle inverse (régions d'atlas,
## marges, region_rect et offset divisés d'autant), il recouvre donc exactement le diffus. Les deux
## tailles peuvent cohabiter dans un même SpriteFrames (échelle par frame, recalée à chaque frame).

const EMISSIVE_SHADER := "res://shaders/emissive.gdshader"
const EMISSION_NODE := &"Emission"

static var _frames_cache: Dictionary = {} ## "E:" + chemin SpriteFrames -> SpriteFrames d'émission (ou null)
static var _ratio_cache: Dictionary = {} ## chemin du _e -> Vector2 (taille diffus / taille _e)
const META_SCALE := &"emission_scale" ## SpriteFrames d'émission : {anim: PackedVector2Array} (absent si tout est à 1) ; Sprite2D Emission : Vector2
static var _emissive_shader: Shader = null

## Normalisation de l'émission des boss (retour joueur 26/10/2026 : « brillance excessive »). Masse émissive =
## moyenne de (luminance × alpha) du masque `_e` sur le PNG entier (table mesurée hors ligne, par animation).
## Au-delà de EMISSION_REF_MASS, l'énergie est réduite en 1/masse (plancher EMISSION_GAIN_MIN) ; un re-rendu
## plus brillant se corrige en relançant art/tools/measure_emission_mass.py (aucun chiffre par boss). Cerf/Sonneur (validés) ≈ 0,022 : intacts.
## N'agit que sur les SpriteFrames sous res://assets/sprites/bosses/ ; héros et monstres inchangés.
const EMISSION_REF_MASS := 0.03
const EMISSION_GAIN_MIN := 0.2
const EMISSION_MASS_TABLE := "res://data/boss_emission_mass.json"
static var _mass_table: Dictionary = {} ## chemin du _e -> masse émissive
const EMISSION_BOSS_DIR := "res://assets/sprites/bosses/"
const META_ENERGY_BASE := &"emission_energy_base"
static var _gain_cache: Dictionary = {} ## "chemin SpriteFrames|anim" -> gain (float)


static func emission_path(diffuse_path: String) -> String:
	return diffuse_path.get_basename() + "_e." + diffuse_path.get_extension()


## Texture d'émission associée (`<f>_e.png`), ou null. Accepte une AtlasTexture : même région, ramenée
## à la taille du _e (divisée par `emission_scale(tex)` si le _e est à demi-résolution).
static func emission_texture(tex: Texture2D) -> Texture2D:
	var base := _diffuse_of(tex)
	if base == null or base.resource_path == "":
		return null
	var ep := emission_path(base.resource_path)
	if not ResourceLoader.exists(ep):
		return null
	var e := load(ep) as Texture2D
	if e == null:
		return null
	var r := _ratio_of(base, e, ep)
	if tex is AtlasTexture:
		var src := tex as AtlasTexture
		var at := AtlasTexture.new()
		at.atlas = e
		at.region = Rect2(src.region.position / r, src.region.size / r)
		at.margin = Rect2(src.margin.position / r, src.margin.size / r)
		at.filter_clip = src.filter_clip
		return at
	return e


## Échelle à donner au sprite d'émission de `tex` pour couvrir le diffus : (1, 1) si le _e est pleine
## taille, ≈ (2, 2) s'il est à demi-résolution ; (1, 1) sans _e.
static func emission_scale(tex: Texture2D) -> Vector2:
	var base := _diffuse_of(tex)
	if base == null or base.resource_path == "":
		return Vector2.ONE
	var ep := emission_path(base.resource_path)
	if _ratio_cache.has(ep):
		return _ratio_cache[ep]
	if not ResourceLoader.exists(ep):
		return Vector2.ONE
	return _ratio_of(base, load(ep) as Texture2D, ep)


## Rapport taille diffus / taille _e (1 = pleine taille, ≈ 2 = demi-résolution). Déduit des tailles :
## un _e pleine taille livré plus tard (lot Codex) marche tel quel.
static func emission_ratio(diffuse: Texture2D, emission: Texture2D) -> Vector2:
	if diffuse == null or emission == null:
		return Vector2.ONE
	var d := diffuse.get_size()
	var e := emission.get_size()
	if e.x <= 0.0 or e.y <= 0.0 or d.x <= 0.0 or d.y <= 0.0 or d == e:
		return Vector2.ONE
	return d / e


## SpriteFrames d'émission (mêmes animations, textures `_e`), ou null si aucune image n'en a.
static func emission_frames(frames: SpriteFrames) -> SpriteFrames:
	if frames == null:
		return null
	var key := "E:" + (frames.resource_path if frames.resource_path != "" else str(frames.get_instance_id()))
	if _frames_cache.has(key):
		return _frames_cache[key]
	var out := SpriteFrames.new()
	if out.has_animation(&"default"):
		out.remove_animation(&"default")
	var any := false
	for anim in frames.get_animation_names():
		out.add_animation(anim)
		out.set_animation_speed(anim, frames.get_animation_speed(anim))
		out.set_animation_loop(anim, frames.get_animation_loop(anim))
		var scales := PackedVector2Array()
		for i in frames.get_frame_count(anim):
			var src := frames.get_frame_texture(anim, i)
			var e := emission_texture(src)
			any = any or e != null
			out.add_frame(anim, e, frames.get_frame_duration(anim, i))
			scales.append(emission_scale(src) if e != null else Vector2.ONE)
		if scales.count(Vector2.ONE) != scales.size():
			var by_anim: Dictionary = out.get_meta(META_SCALE, {})
			by_anim[anim] = scales
			out.set_meta(META_SCALE, by_anim)
	var res: SpriteFrames = out if any else null
	_frames_cache[key] = res
	return res


## Ajoute à un Sprite2D l'enfant d'émission si `_e.png` existe (la texture du sprite est gardée).
static func apply_to_sprite(sprite: Sprite2D, emission_energy: float = 2.0) -> void:
	if sprite == null:
		return
	var e := emission_texture(sprite.texture)
	if e == null:
		return
	var em := sprite.get_node_or_null(NodePath(EMISSION_NODE)) as Sprite2D
	if em == null:
		em = Sprite2D.new()
		em.name = EMISSION_NODE
		sprite.add_child(em)
	em.texture = e
	em.set_meta(META_SCALE, emission_scale(sprite.texture))
	_sync_sprite_rect(sprite, em)
	em.material = make_emissive_material(emission_energy)
	if not sprite.frame_changed.is_connected(_sync_sprite_frame.bind(sprite, em)):
		sprite.frame_changed.connect(_sync_sprite_frame.bind(sprite, em))
	# offset / region / découpage changés après l'appel (ex. pied de bloc posé ensuite) : recalés.
	if not sprite.item_rect_changed.is_connected(_sync_sprite_rect.bind(sprite, em)):
		sprite.item_rect_changed.connect(_sync_sprite_rect.bind(sprite, em))


## Ajoute à un AnimatedSprite2D l'enfant d'émission synchronisé (ses SpriteFrames sont gardés).
static func apply_to_animated(anim: AnimatedSprite2D, emission_energy: float = 2.0) -> void:
	if anim == null or anim.sprite_frames == null:
		return
	var ef := emission_frames(anim.sprite_frames)
	if ef == null:
		return
	var em := anim.get_node_or_null(NodePath(EMISSION_NODE)) as AnimatedSprite2D
	if em == null:
		em = AnimatedSprite2D.new()
		em.name = EMISSION_NODE
		anim.add_child(em)
	em.sprite_frames = ef
	em.centered = anim.centered
	em.set_meta(META_ENERGY_BASE, emission_energy)
	em.animation = anim.animation
	_refresh_material(anim, em)
	em.frame = anim.frame
	_place_animated(anim, em)
	var sync := _sync_animated.bind(anim, em)
	if not anim.frame_changed.is_connected(sync):
		anim.frame_changed.connect(sync)
		anim.animation_changed.connect(sync)
		anim.item_rect_changed.connect(sync)


## Matériau d'émission : unshaded + additif, énergie HDR réglable (uniform `energy`).
static var _emissive_mats := {} ## round(énergie × 100) -> ShaderMaterial partagé


## Matériau d'émission PARTAGÉ par valeur d'énergie (arrondie au centième) : 250 monstres = 1 seul
## matériau, donc des lots de rendu fusionnables (un matériau par instance cassait le batching).
static func make_emissive_material(energy: float = 2.0) -> ShaderMaterial:
	if _emissive_shader == null:
		_emissive_shader = load(EMISSIVE_SHADER) as Shader
	var key := roundi(energy * 100.0)
	var cached: ShaderMaterial = _emissive_mats.get(key)
	if cached != null:
		return cached
	var m := ShaderMaterial.new()
	m.shader = _emissive_shader
	m.set_shader_parameter(&"energy", key / 100.0)
	_emissive_mats[key] = m
	return m


## Change l'énergie d'émission d'un sprite traité par apply_to_* (pulsation en code).
static func set_emission_energy(visual: Node, energy: float) -> void:
	var em := visual.get_node_or_null(NodePath(EMISSION_NODE)) as CanvasItem
	if em != null:
		if em is AnimatedSprite2D and visual is AnimatedSprite2D:
			em.set_meta(META_ENERGY_BASE, energy)
			_refresh_material(visual as AnimatedSprite2D, em as AnimatedSprite2D)
			return
		em.material = make_emissive_material(energy) # matériau partagé : on change de matériau, jamais de paramètre


## Masse émissive d'un masque `_e` : lue dans data/boss_emission_mass.json (art/tools/measure_emission_mass.py,
## moyenne luminance × alpha du PNG entier). Les textures sont compressées en VRAM : pas de mesure à l'exécution.
## 0 sans masque ; -1 si le masque est absent de la table (le test boss_glow_cap_test le signale).
static func emission_mass(tex: Texture2D) -> float:
	if tex == null:
		return 0.0 # frame sans masque
	if _mass_table.is_empty():
		var f := FileAccess.open(EMISSION_MASS_TABLE, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_mass_table = d
		if _mass_table.is_empty():
			_mass_table = {"": 0.0}
	var t := tex
	if t is AtlasTexture:
		t = (t as AtlasTexture).atlas
	if t == null:
		return -1.0
	return float(_mass_table.get(t.resource_path, -1.0))


## Gain (<= 1) appliqué à l'énergie d'émission de l'animation `anim` des SpriteFrames diffus `frames` d'un boss
## (corps ET extras de sorts : crystal_block, stalactite, prism_beam… sont des animations du même .tres).
## 1 hors boss ou sans masque lisible. Mesuré par animation, mis en cache.
static func boss_gain(frames: SpriteFrames, anim: StringName) -> float:
	if frames == null or not frames.resource_path.begins_with(EMISSION_BOSS_DIR):
		return 1.0
	var key := frames.resource_path + "|" + String(anim)
	if _gain_cache.has(key):
		return _gain_cache[key]
	var gain := 1.0
	var ef := emission_frames(frames)
	if ef != null and ef.has_animation(anim):
		var total := 0.0
		var n := 0
		for i in ef.get_frame_count(anim):
			var m := emission_mass(ef.get_frame_texture(anim, i))
			if m >= 0.0:
				total += m
				n += 1
		if n > 0:
			var mass := total / float(n)
			if mass > EMISSION_REF_MASS:
				gain = clampf(EMISSION_REF_MASS / mass, EMISSION_GAIN_MIN, 1.0)
	_gain_cache[key] = gain
	return gain


## Matériau de l'enfant Emission d'un AnimatedSprite2D : énergie de base (meta) × gain de l'animation courante.
static func _refresh_material(anim: AnimatedSprite2D, em: AnimatedSprite2D) -> void:
	var base: float = em.get_meta(META_ENERGY_BASE, 2.0)
	em.material = make_emissive_material(base * boss_gain(anim.sprite_frames, anim.animation))


static func clear_cache() -> void:
	_gain_cache.clear()
	_frames_cache.clear()
	_ratio_cache.clear()


static func _ratio_of(base: Texture2D, e: Texture2D, ep: String) -> Vector2:
	if _ratio_cache.has(ep):
		return _ratio_cache[ep]
	var r := emission_ratio(base, e)
	_ratio_cache[ep] = r
	return r


static func _diffuse_of(tex: Texture2D) -> Texture2D:
	if tex is AtlasTexture:
		return _diffuse_of((tex as AtlasTexture).atlas)
	if tex is CanvasTexture:
		return (tex as CanvasTexture).diffuse_texture
	return tex


static func _sync_sprite_frame(sprite: Sprite2D, em: Sprite2D) -> void:
	if is_instance_valid(em):
		em.frame = sprite.frame
		em.flip_h = sprite.flip_h
		em.flip_v = sprite.flip_v


## Recopie la géométrie du sprite sur l'enfant d'émission, ramenée à la taille du _e (échelle inverse).
static func _sync_sprite_rect(sprite: Sprite2D, em: Sprite2D) -> void:
	if not is_instance_valid(em) or not is_instance_valid(sprite):
		return
	var s: Vector2 = em.get_meta(META_SCALE, Vector2.ONE)
	em.scale = s
	em.centered = sprite.centered
	em.offset = sprite.offset / s
	em.flip_h = sprite.flip_h
	em.flip_v = sprite.flip_v
	em.hframes = sprite.hframes
	em.vframes = sprite.vframes
	em.frame = sprite.frame
	em.region_enabled = sprite.region_enabled
	em.region_rect = Rect2(sprite.region_rect.position / s, sprite.region_rect.size / s)


## Échelle de la frame courante (demi-résolution -> ×2) et offset ramené en conséquence.
static func _place_animated(anim: AnimatedSprite2D, em: AnimatedSprite2D) -> void:
	var s := Vector2.ONE
	if em.sprite_frames != null and em.sprite_frames.has_meta(META_SCALE):
		var arr: PackedVector2Array = (em.sprite_frames.get_meta(META_SCALE) as Dictionary).get(em.animation, PackedVector2Array())
		if em.frame < arr.size():
			s = arr[em.frame]
	if em.scale != s:
		em.scale = s
	em.offset = anim.offset / s


static func _sync_animated(anim: AnimatedSprite2D, em: AnimatedSprite2D) -> void:
	if not is_instance_valid(em):
		return
	if em.animation != anim.animation:
		# frames d'émission périmées (diffus changé sans EmissiveOverlay.apply) : jamais d'anim absente
		if em.sprite_frames == null or not em.sprite_frames.has_animation(anim.animation):
			if em.visible:
				em.visible = false
				em.set_meta(&"stale_hidden", true)
			return
		em.animation = anim.animation
		if em.has_meta(META_ENERGY_BASE):
			_refresh_material(anim, em)
		if em.has_meta(&"stale_hidden"):
			em.remove_meta(&"stale_hidden")
			em.visible = true
	em.frame = anim.frame
	em.flip_h = anim.flip_h
	em.flip_v = anim.flip_v
	em.centered = anim.centered
	_place_animated(anim, em)
