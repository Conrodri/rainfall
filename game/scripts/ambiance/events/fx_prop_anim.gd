extends AmbientEffect
## Prop fixe qui s'anime pendant l'événement (« La noria repart », Rizières hautes) : le sprite statique du prop n'est
## JAMAIS tourné ni déformé en code ; si Codex a livré une SpriteFrames `frames` (animation `anim`), elle est jouée
## par un AnimatedSprite2D enfant du prop (même pied, même échelle, même miroir, fondu des murs hérité) et le diffus
## statique est masqué (self_modulate) ; décalque d'ombre cuite et collision du prop inchangés. Son de roue
## (`sound`, boucle spatialisée sur le prop) seulement quand l'animation tourne. Sans l'asset : rien (repli
## discret), le besoin remonte par `missing` (rapport, tests).
## Paramètres : "prop" ("noria"), "frames" (res:// d'une SpriteFrames), "anim" ("spin"), "sound" ("amb.noria"),
## "sound_db" (-6).

var sprites: Array[Sprite2D] = []
var anims: Array[AnimatedSprite2D] = []
var _frames: SpriteFrames = null
var _loops: Array = []
var _base_alpha: Array[float] = []


func setup() -> void:
	var path := String(def.get("frames", ""))
	if path == "" or not ResourceLoader.exists(path):
		note_missing("SpriteFrames %s (animation « %s »)" % [path, String(def.get("anim", "spin"))])
		return
	_frames = load(path) as SpriteFrames
	if _frames == null or not _frames.has_animation(StringName(def.get("anim", "spin"))):
		note_missing("animation « %s » dans %s" % [String(def.get("anim", "spin")), path])
		_frames = null


func has_asset() -> bool:
	return _frames != null


func start() -> void:
	if _frames == null:
		return
	var anim := StringName(def.get("anim", "spin"))
	sprites = fixed_props(String(def.get("prop", "noria")))
	_base_alpha.clear()
	for s in sprites:
		var a := AnimatedSprite2D.new()
		a.name = "AmbientAnim"
		a.sprite_frames = _frames
		a.animation = anim
		a.centered = s.centered
		a.offset = s.offset
		a.flip_h = s.flip_h
		s.add_child(a)
		NormalMaps.apply_to_animated(a)
		a.play(anim)
		_base_alpha.append(s.self_modulate.a)
		s.self_modulate.a = 0.0 # diffus statique masqué, enfants (roue animée) visibles
		anims.append(a)
		var au := audio()
		if au != null:
			var res: Variant = au.call(&"play_loop", StringName(def.get("sound", "amb.noria")), s, float(def.get("sound_db", -6.0)))
			if res is Dictionary and not (res as Dictionary).is_empty():
				_loops.append(res)


## Les props ne sont pas reconstruits avec l'ambiance : la roue continue.
func refresh() -> void:
	pass


func stop() -> void:
	var au := audio()
	if au != null:
		for h in _loops:
			au.call(&"stop_loop", h)
	_loops.clear()
	for a in anims:
		if is_instance_valid(a):
			a.queue_free()
	anims.clear()
	for i in sprites.size():
		if is_instance_valid(sprites[i]) and i < _base_alpha.size():
			sprites[i].self_modulate.a = _base_alpha[i]
	sprites.clear()
	_base_alpha.clear()


func describe() -> Dictionary:
	var d := super.describe()
	d["animated"] = anims.size()
	d["asset"] = _frames != null
	return d
