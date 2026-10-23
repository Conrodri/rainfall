extends Node
## Test headless du style de rendu 3D / cel-shadé (RenderStyle, contrat `_cel`).
## godot --headless --path game res://tests/render_style_test.tscn
## Réglages : fichier injecté (GameSettings.cfg_path), jamais le settings.cfg du joueur.
## Faux dossier `_cel` : créé dans user:// (copies du .tres de swarm_tier1), supprimé à la fin.

const CFG := "user://test_render_style.cfg"
const ROOT := "user://render_style_test"
const SRC := "res://assets/sprites/monsters/swarm_tier1/swarm_tier1.tres"

var _fails := 0


func _ready() -> void:
	GameSettings.cfg_path = CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	RenderStyle.reload()
	RenderStyle.exists_fn = Callable()

	# --- style cel par défaut (décision du joueur 22/10/2026) ; puis 3d explicite : chemins inchangés
	_check(RenderStyle.style() == RenderStyle.STYLE_CEL and RenderStyle.DEFAULT == RenderStyle.STYLE_CEL, "style par défaut cel (fichier vide)")
	_check(GameSettings.render_style() == "cel", "réglage absent -> cel")
	RenderStyle.set_style(RenderStyle.STYLE_3D, null, false)
	_check(RenderStyle.resolve(SRC) == SRC, "3d : chemin d'origine")
	_check(RenderStyle.cel_path("res://a/b/x.png") == "res://a/b_cel/x.png", "cel_path : dossier frère _cel")
	_check(RenderStyle.original_path("res://a/b_cel/x.png") == "res://a/b/x.png", "original_path : retire _cel")
	_check(RenderStyle.original_path(SRC) == SRC, "original_path : chemin d'origine inchangé")

	# --- style cel sans dossier _cel (résolution injectée : rien n'existe) -> repli silencieux
	RenderStyle.exists_fn = func(_p: String) -> bool: return false
	RenderStyle.set_style(RenderStyle.STYLE_CEL, null, false)
	_check(RenderStyle.is_cel(), "set_style cel")
	_check(RenderStyle.resolve(SRC) == SRC, "cel sans _cel : chemin d'origine")
	_check(RenderStyle.resolve("res://assets/sprites/characters/ardent/idle_e.png") == "res://assets/sprites/characters/ardent/idle_e.png", "cel sans _cel : émission d'origine")
	# résolution injectée : seul ardent_cel/idle.png « existe »
	RenderStyle.set_style(RenderStyle.STYLE_3D, null, false)
	RenderStyle.exists_fn = func(p: String) -> bool: return p == "res://assets/sprites/characters/ardent_cel/idle.png"
	RenderStyle.set_style(RenderStyle.STYLE_CEL, null, false)
	_check(RenderStyle.resolve("res://assets/sprites/characters/ardent/idle.png") == "res://assets/sprites/characters/ardent_cel/idle.png", "cel injecté : substitution ardent_cel")
	_check(RenderStyle.resolve("res://assets/sprites/characters/ardent/run.png") == "res://assets/sprites/characters/ardent/run.png", "cel injecté : fichier absent du _cel -> original")
	RenderStyle.exists_fn = Callable()

	# --- monstres réels : sans art livré, mêmes frames qu'en 3d (repli silencieux)
	var f_cel := EnemyVisual.frames_for_tier(1)
	if f_cel != null:
		var want := RenderStyle.resolve(SRC)
		_check(f_cel.resource_path == want, "frames_for_tier(1) en cel = %s" % want)
		if not DirAccess.dir_exists_absolute("res://assets/sprites/monsters/swarm_tier1_cel"):
			_check(f_cel.resource_path == SRC, "sans swarm_tier1_cel : frames d'origine")
	RenderStyle.set_style(RenderStyle.STYLE_3D, null, false)
	var f_3d := EnemyVisual.frames_for_tier(1)
	_check(f_3d == null or f_3d.resource_path == SRC, "frames_for_tier(1) en 3d = original (cache recalé)")

	# --- faux dossier _cel dans user:// : substitution réelle + bascule à chaud
	var base := _make_fixture()
	if base == "":
		_check(false, "fixture user:// (copie du .tres)")
	else:
		var orig := ROOT + "/swarm/swarm.tres"
		var cel := ROOT + "/swarm_cel/swarm.tres"
		var other := ROOT + "/swarm/other.tres"
		RenderStyle.set_style(RenderStyle.STYLE_CEL, null, false)
		_check(RenderStyle.resolve(orig) == cel, "user:// : substitution vers swarm_cel")
		_check(RenderStyle.resolve(other) == other, "user:// : fichier sans frère _cel -> original")
		RenderStyle.set_style(RenderStyle.STYLE_3D, null, false)
		_check(RenderStyle.resolve(orig) == orig, "user:// : 3d -> original")
		_test_hot_swap(orig, cel, base)

	# --- réglage persistant (chemin injecté)
	RenderStyle.set_style(RenderStyle.STYLE_CEL, get_tree(), true)
	_check(GameSettings.render_style() == "cel", "réglage écrit : cel")
	var cf := ConfigFile.new()
	_check(cf.load(CFG) == OK and String(cf.get_value("graphics", "render_style", "")) == "cel", "fichier injecté : [graphics] render_style = cel")
	RenderStyle.reload()
	_check(RenderStyle.is_cel(), "relu au démarrage : cel")
	RenderStyle.toggle(get_tree())
	_check(RenderStyle.style() == RenderStyle.STYLE_3D and GameSettings.render_style() == "3d", "toggle (F7) -> 3d persisté")
	var ev := InputEventKey.new()
	ev.keycode = KEY_F7
	ev.pressed = true
	_check(RenderStyle.is_toggle_event(ev), "F7 = bascule")
	ev.echo = true
	_check(not RenderStyle.is_toggle_event(ev), "répétition ignorée")

	# --- nettoyage
	_cleanup()
	GameSettings.cfg_path = GameSettings.PATH
	RenderStyle.exists_fn = Callable()
	RenderStyle.reload()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## Copie le .tres réel de swarm_tier1 en swarm/ et swarm_cel/ (mêmes anims, textures d'origine).
## Renvoie le nom d'une anim de >= 3 frames, ou "" si échec.
func _make_fixture() -> String:
	_cleanup()
	var src := load(SRC) as SpriteFrames
	if src == null:
		return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "/swarm"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "/swarm_cel"))
	for p in [ROOT + "/swarm/swarm.tres", ROOT + "/swarm_cel/swarm.tres", ROOT + "/swarm/other.tres"]:
		if ResourceSaver.save(src.duplicate(), p) != OK:
			return ""
	for a in src.get_animation_names():
		if src.get_frame_count(a) >= 3:
			return String(a)
	return ""


func _test_hot_swap(orig: String, cel: String, anim: String) -> void:
	# monstre (EnemyVisual, groupe render_style) et joueur (scène réelle)
	var vis := EnemyVisual.new()
	add_child(vis)
	vis._ensure_sprite()
	var spr := vis.get_node(^"Sprite") as AnimatedSprite2D
	EmissiveOverlay.apply(spr, load(orig) as SpriteFrames)
	spr.play(StringName(anim))
	spr.set_frame_and_progress(2, 0.4)

	var player: Node = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	var pspr := player.get_node(^"Visual") as AnimatedSprite2D
	EmissiveOverlay.apply(pspr, load(orig) as SpriteFrames)
	pspr.play(StringName(anim))
	pspr.set_frame_and_progress(1, 0.25)

	RenderStyle.set_style(RenderStyle.STYLE_CEL, get_tree(), false)
	for pair in [[spr, 2, "monstre"], [pspr, 1, "joueur"]]:
		var s: AnimatedSprite2D = pair[0]
		var tag: String = pair[2]
		_check(String(s.get_meta(RenderStyle.META_SRC)) == cel, "%s : frames _cel après bascule" % tag)
		_check(s.animation == StringName(anim) and s.frame == int(pair[1]) and s.is_playing(), "%s : même anim / frame / lecture (%s %d)" % [tag, s.animation, s.frame])
	_check(is_equal_approx(spr.frame_progress, 0.4), "monstre : progression conservée")

	RenderStyle.set_style(RenderStyle.STYLE_3D, get_tree(), false)
	_check(String(spr.get_meta(RenderStyle.META_SRC)) == orig, "monstre : retour aux frames d'origine")
	_check(spr.animation == StringName(anim) and spr.frame == 2, "monstre : anim / frame après retour")
	_check(String(pspr.get_meta(RenderStyle.META_SRC)) == orig, "joueur : retour aux frames d'origine")

	# nouveau sprite en style cel : suit le style (restyle à l'apparition)
	RenderStyle.set_style(RenderStyle.STYLE_CEL, null, false)
	var fresh := AnimatedSprite2D.new()
	add_child(fresh)
	EmissiveOverlay.apply(fresh, load(orig) as SpriteFrames)
	RenderStyle.restyle_sprite(fresh)
	_check(String(fresh.get_meta(RenderStyle.META_SRC)) == cel, "nouvel arrivant : frames _cel")
	RenderStyle.set_style(RenderStyle.STYLE_3D, null, false)
	player.queue_free()
	vis.queue_free()
	fresh.queue_free()


func _cleanup() -> void:
	for p in [ROOT + "/swarm/swarm.tres", ROOT + "/swarm/other.tres", ROOT + "/swarm_cel/swarm.tres", ROOT + "/swarm", ROOT + "/swarm_cel", ROOT]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label)
