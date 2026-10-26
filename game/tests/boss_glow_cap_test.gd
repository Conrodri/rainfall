extends Node
## Test headless : plafond de brillance des boss (NormalMaps.boss_gain, LightRig.BOSS_LIGHT_MAX_ENERGY).
## Pour chaque animation de chaque .tres de boss/mini-boss : masse émissive × gain <= EMISSION_REF_MASS
## (ou gain au plancher), gain dans [EMISSION_GAIN_MIN, 1]. Héros inchangés (gain 1). Presets de lumière boss
## relevés au plafond. godot --headless --path game res://tests/boss_glow_cap_test.tscn  (RESULT: OK)

var _fails: Array[String] = []


func _ready() -> void:
	var tres: Array[String] = []
	_collect("res://assets/sprites/bosses", tres)
	var rows := 0
	var capped := 0
	for path in tres:
		var frames := load(path) as SpriteFrames
		if frames == null:
			continue
		var ef := NormalMaps.emission_frames(frames)
		if ef == null:
			continue
		for anim in frames.get_animation_names():
			if not ef.has_animation(anim) or ef.get_frame_count(anim) == 0:
				continue
			var g := NormalMaps.boss_gain(frames, anim)
			if g < NormalMaps.EMISSION_GAIN_MIN - 0.0001 or g > 1.0001:
				_fails.append("%s/%s gain hors bornes %.3f" % [path, anim, g])
			var tot := 0.0
			var cnt := 0
			for i in ef.get_frame_count(anim):
				var m := NormalMaps.emission_mass(ef.get_frame_texture(anim, i))
				if m < 0.0:
					_fails.append("%s/%s : masque absent de data/boss_emission_mass.json (relancer art/tools/measure_emission_mass.py)" % [path, anim])
					break
				tot += m
				cnt += 1
			var mass := tot / maxf(cnt, 1)
			rows += 1
			if g < 0.999:
				capped += 1
				print("CAP %s/%s masse %.3f gain %.2f" % [path.get_file(), anim, mass, g])
			if mass * g > NormalMaps.EMISSION_REF_MASS + 0.0005 and g > NormalMaps.EMISSION_GAIN_MIN + 0.0005:
				_fails.append("%s/%s masse effective %.3f > plafond" % [path, anim, mass * g])
	if rows == 0:
		_fails.append("aucune animation mesurée")
	# Hors boss : jamais touché.
	var ardent := load("res://assets/sprites/characters/ardent/ardent.tres") as SpriteFrames
	if ardent != null and NormalMaps.boss_gain(ardent, ardent.get_animation_names()[0]) != 1.0:
		_fails.append("gain appliqué hors boss")
	# Lumières de boss plafonnées.
	var rig := LightRig.new()
	add_child(rig)
	var h := LightRig.attach(self_node(), &"boss_cerf", {"energy": 10.0})
	rig.reassign()
	rig._update_lights(10.0)
	for hh in rig.assigned_handles():
		var hd := hh as LightRig.Handle
		if hd.light != null and hd.light.energy > LightRig.BOSS_LIGHT_MAX_ENERGY + 0.001:
			_fails.append("lumière boss %.2f > plafond" % hd.light.energy)
	LightRig.detach(h)
	print("animations mesurées %d, réduites %d" % [rows, capped])
	print("RESULT: %s" % ("OK" if _fails.is_empty() else "FAIL " + str(_fails)))
	get_tree().quit(0 if _fails.is_empty() else 1)


func self_node() -> Node2D:
	var n := Node2D.new()
	add_child(n)
	return n


func _collect(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tres"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		_collect(dir + "/" + d, out)
