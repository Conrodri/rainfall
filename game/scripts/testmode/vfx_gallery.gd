class_name VfxGallery
extends VBoxContainer
## Galerie VFX du mode test (onglet « Galerie VFX » de TestPanel) : propriétaires puis sorts des VFX de test pixelfx
## (res://assets/sprites/vfx_test/). Un clic (souris, tactile ou manette) joue l'effet au pied du joueur 1, dirigé vers la
## souris (PC), le stick droit (manette) ou la droite (tactile). Options conservées entre deux ouvertures du panneau.
## À RETIRER OU MASQUER AVANT LA SORTIE avec le mode test.

static var opt_loop := false
static var opt_halo := true
static var opt_light := true
static var opt_particles := true
static var opt_scale := 1.0
static var selected_owner := ""

var panel: TestPanel
var _current: VfxTestPlayer = null
var _queue: Array[String] = []
var _token := 0
var _last_key := ""
var _scale_label: Label


func build(p: TestPanel) -> void:
	panel = p
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override(&"separation", 10)
	var cat := VfxTestPlayer.catalog()
	add_child(panel._heading("Galerie VFX (test pixelfx)"))
	add_child(panel._note("Joue l'effet au pied du joueur 1, vers la souris (PC), le stick droit (manette) ou la droite (tactile). Corps + halo additif HDR + lumière du pool + particules."))
	if cat.is_empty():
		add_child(panel._note("Aucun effet trouvé dans assets/sprites/vfx_test/."))
		return
	var opts := panel._grid(2)
	add_child(opts)
	opts.add_child(panel._expand(panel._check("Rejouer en boucle", opt_loop, func(on: bool) -> void: opt_loop = on)))
	opts.add_child(panel._expand(panel._check("Halo", opt_halo, func(on: bool) -> void: opt_halo = on)))
	opts.add_child(panel._expand(panel._check("Lumière", opt_light, func(on: bool) -> void: opt_light = on)))
	opts.add_child(panel._expand(panel._check("Particules", opt_particles, func(on: bool) -> void: opt_particles = on)))
	var sl_row := HBoxContainer.new()
	sl_row.add_theme_constant_override(&"separation", 12)
	add_child(sl_row)
	_scale_label = panel._label("Échelle ×%.2f" % opt_scale, TestPanel.FS_BODY)
	_scale_label.custom_minimum_size = Vector2(230, 0)
	sl_row.add_child(_scale_label)
	var sl := HSlider.new()
	sl.name = "ScaleSlider"
	sl.min_value = 0.4
	sl.max_value = 2.5
	sl.step = 0.05
	sl.value = opt_scale
	sl.custom_minimum_size = Vector2(0, TestPanel.BTN_H)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.value_changed.connect(func(v: float) -> void:
		opt_scale = v
		_scale_label.text = "Échelle ×%.2f" % v)
	sl_row.add_child(sl)
	var stop := panel._btn("Arrêter", stop_all)
	stop.name = "VfxStop"
	add_child(stop)
	add_child(panel._heading("Propriétaires"))
	if selected_owner == "" or not cat.has(selected_owner):
		selected_owner = String(cat.keys()[0])
	var og := panel._grid(maxi(2, panel._cols(220.0)))
	add_child(og)
	for o in cat:
		var ob := panel._btn("%s (%d)" % [o, (cat[o] as Array).size()], func() -> void: _pick_owner(String(o)))
		ob.name = "Owner_%s" % o
		ob.clip_text = true
		panel._expand(ob)
		if o == selected_owner:
			ob.modulate = TestPanel.COL_ON
		og.add_child(ob)
	add_child(panel._heading("Sorts de « %s »" % selected_owner))
	var all := panel._btn("Jouer tout le propriétaire", func() -> void: play_owner(selected_owner))
	all.name = "VfxPlayAll"
	add_child(all)
	var sg := panel._grid(maxi(2, panel._cols(250.0)))
	add_child(sg)
	for s in cat[selected_owner]:
		var key := "%s/%s" % [selected_owner, s]
		var cls := VfxTestPlayer.resolve(key)
		var tag := "%s · %s" % [cls.get("projection", "?"), cls.get("particles", "?")] if not cls.is_empty() and cls.has("projection") else ""
		var sb := panel._btn("%s\n%s" % [s, tag] if tag != "" else String(s), func() -> void: play(key))
		sb.name = "Spell_%s" % s
		sb.clip_text = true
		panel._expand(sb)
		sg.add_child(sb)


func _pick_owner(o: String) -> void:
	selected_owner = o
	panel._select_tab(&"vfx")


# --- Lecture -------------------------------------------------------------------------------

func stop_all() -> void:
	_token += 1
	_queue.clear()
	if is_instance_valid(_current):
		_current.stop()
	_current = null


static func aim_direction(player: Node2D) -> Vector2:
	match Platform.input_mode:
		Platform.InputMode.TOUCH:
			return Vector2.RIGHT
		Platform.InputMode.GAMEPAD:
			var st := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
			return Iso.screen_to_logical_dir(st) if st.length() > 0.2 else Vector2.RIGHT
	var d := player.get_global_mouse_position() - player.global_position
	return d.normalized() if d.length() > 4.0 else Vector2.RIGHT


func play(key: String) -> VfxTestPlayer:
	stop_all()
	return _play(key)


func play_owner(o: String) -> void:
	stop_all()
	var cat := VfxTestPlayer.catalog()
	if not cat.has(o):
		return
	for s in cat[o]:
		_queue.append("%s/%s" % [o, s])
	_advance(_token)


func _advance(tok: int) -> void:
	if tok != _token or _queue.is_empty():
		return
	_play(_queue.pop_front())


func _play(key: String) -> VfxTestPlayer:
	var player := TestTools.player_of(get_tree())
	if player == null or player.get_parent() == null:
		panel.say("Aucun joueur : lance l'arène du mode test.")
		return null
	var v := VfxTestPlayer.spawn(player.get_parent(), key, player.global_position, aim_direction(player), {
		"scale_mult": opt_scale, "halo": opt_halo, "light": opt_light, "particles": opt_particles, "always": true,
	}) as VfxTestPlayer
	if v == null:
		panel.say("%s : images manquantes (lot en cours ?)." % key)
		return null
	_current = v
	_last_key = key
	var tok := _token
	v.finished.connect(func(_p: VfxTestPlayer) -> void: _on_finished(tok, key))
	panel.say("%s · %s · particules %s" % [key, v.projection, v.particles_kind])
	return v


func _on_finished(tok: int, key: String) -> void:
	if tok != _token or not is_inside_tree():
		return
	if not _queue.is_empty():
		_advance(tok)
	elif opt_loop:
		_play(key)
