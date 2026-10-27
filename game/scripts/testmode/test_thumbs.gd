class_name TestThumbs
extends RefCounted
## Vignettes du panneau du mode test : première frame d'idle (direction s / se) des SpriteFrames du jeu, rognée aux pixels
## opaques, recuite en petite texture (le SpriteFrames d'origine n'est pas gardé en mémoire) ; portraits des personnages
## et des skins (mêmes sources que l'écran Nouvelle run) ; icônes d'objets. Aucun visuel n'est dessiné ici : tout vient
## des assets du jeu. À RETIRER OU MASQUER AVANT LA SORTIE avec le mode test.

const MAX_PX := 160 ## grand côté d'une vignette recuite
const IDLE_ANIMS: Array[StringName] = [&"idle_se", &"idle_s", &"idle_p1_se", &"idle_p1_s", &"run_se", &"run_s", &"walk_p1_se", &"walk_p1_s", &"closed"]
const ITEM_ICON := "res://assets/sprites/icons/items/%s.png"

static var _cache := {}


static func clear() -> void:
	_cache.clear()


## Texture d'un chemin res:// (null si absente), avec cache.
static func tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	if _cache.has(path):
		return _cache[path]
	var t := load(path) as Texture2D
	_cache[path] = t
	return t


static func item_icon(id: StringName) -> Texture2D:
	return tex(ITEM_ICON % String(id))


## {tex, provisional} d'une entrée du catalogue des monstres. Sprite non livré : emprunt (la brute du biome par défaut),
## `provisional` = true.
static func monster(entry: Dictionary) -> Dictionary:
	var key := "m:%s" % str(entry.get("key", ""))
	if _cache.has(key):
		return _cache[key]
	var out := {"tex": null, "provisional": false}
	var kind: StringName = entry.get("kind", &"tier")
	var frames: SpriteFrames = null
	if kind == &"tier":
		var tier := int(entry.get("tier", 1))
		var k := EnemyVisual.LEAPER_KEY if tier == 2 and int(entry.get("variant", -1)) == Enemy.VARIANT_LEAPER else tier
		frames = EnemyVisual.monster_frames(k, EnemyVisual.default_biome())
	else:
		var bid := StringName(entry.get("boss_id", &""))
		if bid != &"" and EnemyVisual.boss_available(bid):
			var f := load(RenderStyle.resolve(EnemyVisual.boss_path(bid))) as SpriteFrames
			frames = f
		if frames == null:
			frames = EnemyVisual.monster_frames(3, EnemyVisual.default_biome())
			out["provisional"] = true
	out["tex"] = from_frames(frames)
	_cache[key] = out
	return out


## {tex} d'une entrée du catalogue des coffres (frame « closed » du sprite réel).
static func chest(entry: Dictionary) -> Texture2D:
	var key := "k:%s" % str(entry.get("key", ""))
	if _cache.has(key):
		return _cache[key]
	var p := str(entry.get("frames", ""))
	var t: Texture2D = from_frames(load(p) as SpriteFrames) if p != "" and ResourceLoader.exists(p) else null
	_cache[key] = t
	return t


## Première frame d'idle (s / se) d'un SpriteFrames, rognée et recuite. null si rien de lisible.
static func from_frames(frames: SpriteFrames) -> Texture2D:
	if frames == null:
		return null
	var anim := &""
	for a in IDLE_ANIMS:
		if frames.has_animation(a) and frames.get_frame_count(a) > 0:
			anim = a
			break
	if anim == &"":
		for a in frames.get_animation_names():
			if frames.get_frame_count(a) > 0:
				anim = a
				break
	if anim == &"":
		return null
	return bake(frames.get_frame_texture(anim, 0))


## Rogne aux pixels opaques, ratio gardé, grand côté <= MAX_PX. Image illisible (rendu factice) : texture telle quelle.
static func bake(t: Texture2D) -> Texture2D:
	if t == null:
		return null
	var img: Image
	if t is AtlasTexture and (t as AtlasTexture).atlas != null:
		# AtlasTexture.get_image() échoue sur une planche compressée (VRAM) : on décompresse la planche puis on découpe.
		var sheet := (t as AtlasTexture).atlas.get_image()
		if sheet == null or sheet.is_empty():
			return t
		if sheet.is_compressed():
			sheet.decompress()
		img = sheet.get_region(Rect2i((t as AtlasTexture).region))
	else:
		img = t.get_image()
		if img != null and img.is_compressed():
			img.decompress()
	if img == null or img.is_empty():
		return t
	var r := img.get_used_rect()
	if r.size.x < 2 or r.size.y < 2:
		return null
	if r.size != img.get_size():
		img = img.get_region(r)
	var m := maxi(img.get_width(), img.get_height())
	if m > MAX_PX:
		var s := float(MAX_PX) / float(m)
		img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


## Portrait d'un personnage (`skin_id` "" : apparence par défaut) : celui de l'écran Nouvelle run, sinon vignette du skin.
static func character(c: Dictionary, skin_id: String = "") -> Texture2D:
	var cid := str(c.get("id", ""))
	var key := "c:%s:%s" % [cid, skin_id]
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = null
	if skin_id == "":
		t = CharacterCard.portrait_info(c, "-").get("tex")
	else:
		var sp := Skins.portrait_info(cid, skin_id)
		t = sp.get("tex")
		if t == null:
			var p := Skins.skin_frames_path(cid, skin_id)
			if p != "" and ResourceLoader.exists(p):
				t = from_frames(load(p) as SpriteFrames)
		elif not (t is ImageTexture):
			t = bake(t)
	_cache[key] = t
	return t
