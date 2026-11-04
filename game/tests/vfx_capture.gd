extends Node2D
## Outil de revue (pas un test) : capture chaque VFX de test au pic de sa lumière, sous la vraie caméra iso,
## à côté d'Ardent pour l'échelle. Fenêtré (pas --headless) :
##   godot --path game res://tests/vfx_capture.tscn -- --keys=ardent/nova_ardente,morfil/fauche_lune --out=C:/chemin
## Option --frame=N : capture à l'image N (sinon au pic de lumière, au plus tôt l'image 4).
## Option --dirs=1,-0.4;-0.3,1 : une capture par direction logique (suffixe __d0, __d1… ; défaut : 1,-0.4 sans suffixe).
## Même chemin que le jeu pour le champ meta `usage` (VfxTestPlayer / VfxSwap) :
##   tile_along_line : ligne de 8 u (ou clé@L) tuilée par le lecteur ; la chaîne d'Arpenteuse passe par
##   VfxSwap.track_polyline (une tuile par porteur, comme en jeu) ;
##   line_from_pivot : ligne étirée à L u si clé@L (ex. hermit_cedar/root_spike@2.2 : gerbe du Cèdre), sinon native ;
##   ground_* : rayon R u si clé@R ;
##   anim de boss sans asset dédié et remappée (VfxSwap.BOSS_ANIMS) : effet de repli ; options
##   VfxSwap.BOSS_SPRITE_OPTS (ex. rain_sower/flood_water) ; fit_host_px : hôte factice dont l'échelle donne un rayon
##   de 6 u (ou clé@R) ;
##   host:<boss>/<anim>[@LxW] : sprite d'origine reconstruit comme son cerveau (HOSTS : racine du Cèdre, vrille par
##   défaut), l'effet passe par l'accroche VfxSwap (position, longueur et largeur relues sur le sprite).
## À RETIRER AVEC LE MODE TEST.

var _out := "user://vfx_capture"
var _keys: Array[String] = []
var _dirs: Array[Vector2] = []
var _frame := -1 ## --frame=N : capture à l'image N au lieu du pic de lumière

## Sprites d'origine reconstruits (host:) : longueur et largeur par défaut (u), comme dans leur cerveau.
const HOSTS := {
	"hermit_cedar/root_spike": [HermitCedarBrain.TENDRIL_LEN_U, HermitCedarBrain.TENDRIL_W_U], # _root_fx (vrille)
}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--keys="):
			for k in a.substr(7).split(",", false):
				_keys.append(k)
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--frame="):
			_frame = int(a.substr(8))
		elif a.begins_with("--dirs="):
			for d in a.substr(7).split(";", false):
				var p := d.split(",")
				if p.size() == 2:
					_dirs.append(Vector2(float(p[0]), float(p[1])).normalized())
	DirAccess.make_dir_recursive_absolute(_out)
	get_viewport().use_hdr_2d = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var cm := CanvasModulate.new()
	cm.color = Color(0.32, 0.34, 0.42)
	add_child(cm)
	var cam := Camera2D.new()
	cam.zoom = Iso.camera_zoom()
	add_child(cam)
	cam.make_current()
	queue_redraw()
	_run.call_deferred()


func _draw() -> void:
	# Sol : fond sombre et grille de la carte (cases de 1 u tournées de 45°), repère logique.
	draw_rect(Rect2(-3000, -3000, 6000, 6000), Color(0.11, 0.12, 0.14))
	var x := Iso.map_xform()
	for i in range(-20, 21):
		var c := Color(0.2, 0.22, 0.26) if i != 0 else Color(0.35, 0.3, 0.25)
		draw_line(x * Vector2(i * 64, -1280), x * Vector2(i * 64, 1280), c, 2.0)
		draw_line(x * Vector2(-1280, i * 64), x * Vector2(1280, i * 64), c, 2.0)


func _hero() -> Node2D:
	var space := Node2D.new()
	space.scale = Iso.UNSQUASH
	space.position = Vector2(-150, 0)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = load("res://assets/sprites/characters/ardent/ardent.tres")
	spr.scale = Vector2.ONE * Iso.SPRITE_K
	spr.centered = true
	space.add_child(spr)
	var tex := spr.sprite_frames.get_frame_texture(spr.animation, 0)
	if tex != null:
		spr.offset = Vector2(0, -tex.get_height() * 0.42)
	return space


## Attend le pic de lumière (ou --frame) puis enregistre la capture.
func _shoot(spec: String, suffix: String, peak: int, fps: float) -> void:
	var wait := (maxi(peak, 4) + 0.5) / fps
	if _frame >= 0:
		wait = (_frame + 0.5) / fps
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.linear_to_srgb()
	var fname := spec.replace("/", "__").replace("@", "_at_").replace(":", "_")
	img.save_png("%s/%s%s.png" % [_out, fname, suffix])
	print("capture ", spec, suffix, " t=", snappedf(wait, 0.01))


## host: sprite d'origine d'un boss posé comme par son cerveau (longueur L u, largeur W u, couché vers `dir`) ;
## l'accroche VfxSwap.on_sprite pose l'effet de test et cache le sprite.
func _capture_host(spec: String, src: String, len_u: float, w_u: float, dir: Vector2, suffix: String) -> void:
	var boss := src.get_slice("/", 0)
	var anim := StringName(src.get_slice("/", 1))
	var sf := load("res://assets/sprites/bosses/etage/%s/%s.tres" % [boss, boss]) as SpriteFrames
	if sf == null or not sf.has_animation(anim) or not HOSTS.has(src):
		push_warning("vfx_capture : hôte inconnu %s" % src)
		return
	var dflt: Array = HOSTS[src]
	var length := (len_u if len_u > 0.0 else float(dflt[0])) * Balance.UNIT_PX
	var w := (w_u if w_u > 0.0 else float(dflt[1])) * Balance.UNIT_PX
	TestMode.active = true
	TestMode.vfx_test = true
	var s := AnimatedSprite2D.new()
	EmissiveOverlay.apply(s, sf, 2.0)
	s.animation = anim
	var tex := sf.get_frame_texture(anim, 0)
	var ts := tex.get_size() if tex != null else Vector2(512.0, 128.0)
	s.centered = false # HermitCedarBrain._root_fx
	s.offset = Vector2(0.0, -ts.y * 0.5)
	s.scale = Vector2(length / ts.x, w / ts.y)
	s.play(anim)
	add_child(s)
	s.position = Vector2(60, 0)
	s.rotation = dir.angle()
	await get_tree().process_frame
	var key := String(s.get_meta(VfxSwap.META_CUR, ""))
	var meta := VfxTestPlayer.load_meta(String(VfxTestPlayer.resolve(key).get("asset_key", key)))
	var curve: Array = meta.get("light_curve", [1.0])
	var peak := 0
	for i in curve.size():
		if float(curve[i]) > float(curve[peak]):
			peak = i
	await _shoot(spec, suffix, peak, float(meta.get("fps", 15.0)))
	var f := VfxSwap.follower_of(s)
	if f != null:
		f.stop()
	s.queue_free()
	TestMode.vfx_test = false
	TestMode.active = false
	await get_tree().create_timer(0.3).timeout


func _run() -> void:
	add_child(_hero())
	var dirs: Array[Vector2] = _dirs.duplicate()
	if dirs.is_empty():
		dirs.append(Vector2(1, -0.4).normalized())
	for k in _keys:
		for di in dirs.size():
			await _capture(k, dirs[di], "" if _dirs.is_empty() else "__d%d" % di)
	get_tree().quit()


func _capture(spec: String, dir: Vector2, suffix: String) -> void:
	var k := spec.trim_prefix("host:")
	var arg := 0.0
	var arg2 := 0.0
	if k.contains("@"):
		var a := k.get_slice("@", 1)
		k = k.get_slice("@", 0)
		arg = float(a.get_slice("x", 0))
		if a.contains("x"):
			arg2 = float(a.get_slice("x", 1))
	if spec.begins_with("host:"):
		await _capture_host(spec, k, arg, arg2, dir, suffix)
		return
	var opts := {"duration": 30.0}
	var src := k
	opts.merge(VfxSwap.BOSS_SPRITE_OPTS.get(src, {}), true)
	if not VfxTestPlayer.available(k) and VfxSwap.BOSS_ANIMS.has(k):
		k = String(VfxSwap.BOSS_ANIMS[k])
	var meta := VfxTestPlayer.load_meta(String(VfxTestPlayer.resolve(k).get("asset_key", k)))
	var usage := String(meta.get("usage", ""))
	var curve: Array = meta.get("light_curve", [1.0])
	var peak := 0
	for i in curve.size():
		if float(curve[i]) > float(curve[peak]):
			peak = i
	var fps := float(meta.get("fps", 15.0))
	var fxs: Array[Node] = []
	var origin := Vector2(60, 0)
	if usage == "tile_along_line":
		opts["line_px"] = (arg if arg > 0.0 else 8.0) * Balance.UNIT_PX
	elif usage == "line_from_pivot" and arg > 0.0:
		opts["line_px"] = arg * Balance.UNIT_PX
	elif usage in VfxTestPlayer.RADIUS_USAGES and arg > 0.0 and not opts.has("fit_host_px"):
		opts["radius_u"] = arg
	if opts.has("fit_host_px"):
		# hôte factice (disque de crue) : son échelle encode le rayon gameplay, le lecteur la relit à chaque image
		var host := Node2D.new()
		add_child(host)
		host.position = origin
		host.scale = Vector2.ONE * (2.0 * (arg if arg > 0.0 else 6.0) * Balance.UNIT_PX / float(opts["fit_host_px"]))
		fxs.append(host)
		opts["follow"] = host
		fxs.append(VfxTestPlayer.spawn(host, k, Vector2.ZERO, dir, opts))
	elif usage == "tile_along_line" and k.begins_with("arpenteuse/"):
		var owner := Node2D.new()
		add_child(owner)
		var line := Node2D.new()
		owner.add_child(line)
		TestMode.active = true
		TestMode.vfx_test = true
		VfxSwap.track_polyline(owner, k, PackedVector2Array([origin, origin + dir * float(opts["line_px"])]), line)
		fxs.append(owner)
	else:
		fxs.append(VfxTestPlayer.spawn(self, k, origin, dir, opts))
	await _shoot(spec, suffix, peak, fps)
	for fx in fxs:
		if is_instance_valid(fx):
			VfxSwap.release_points(fx)
			fx.queue_free()
	TestMode.vfx_test = false
	TestMode.active = false
	await get_tree().create_timer(0.3).timeout
