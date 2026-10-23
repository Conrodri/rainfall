extends Node
## Capture de contrôle du poids des coups (flash, hitstop, recul, étincelles, flammèches de DoT).
## Debug seulement. godot --path game --write-movie <dossier>/hit.png --fixed-fps 60 --resolution 1280x720 res://tests/capture_hit_feel.tscn
## Chronologie (s) : 0,3 monstres proches + un brûlé (DoT) ; tirs auto d'Ardent ; 1,2 Nova ardente ; 2,5 fin.
## Imprime « HIT frame=<n> ... » pour chaque coup, afin de retrouver les images autour d'un impact.

var _main: Node
var _t := 0.0
var _step := 0
var _frame := 0


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 7)
	add_child(_main)
	Events.enemy_damaged.connect(func(e: Node2D, amount: float, crit: bool, el: StringName) -> void:
		print("HIT frame=%d el=%s amount=%.1f crit=%s hitstop=%.3f kb=%.1f" % [_frame, el, amount, crit,
			e.hitstop_left() if e.has_method(&"hitstop_left") else 0.0,
			e.knockback_left().length() if e.has_method(&"knockback_left") else 0.0]))


func _process(delta: float) -> void:
	_frame += 1
	if _main == null or not bool(_main.get(&"is_ready")):
		return
	_t += delta
	var hud = _main.get(&"hud")
	if hud != null and hud.pause_menu.is_open:
		hud.pause_menu._close()
	if _step == 0 and _t > 0.3:
		_step = 1
		_main.player.grant_invulnerability(1.0e6)
		var cam: Camera2D = _main.camera
		if cam != null:
			cam.zoom = Iso.camera_zoom(1.6)
		var d: Director = _main.director
		d.spawning_enabled = false
		var pp: Vector2 = _main.player.global_position
		var e1 := d.spawn_enemy(1, pp + Vector2(190, -20))
		d.spawn_enemy(1, pp + Vector2(230, 60))
		d.spawn_enemy(3, pp + Vector2(-210, 40))
		var e4 := d.spawn_enemy(2, pp + Vector2(20, -200))
		e4.apply_status(&"burn", {"total": 40.0, "duration": 3.0})
		e4.apply_status(&"poison", {"total": 32.0, "duration": 4.0})
		print("SPAWN frame=%d t1=%s" % [_frame, e1.position])
	if _step == 1 and _t > 1.2:
		_step = 2
		_main.player.spells.cast(2) # Nova ardente : coup direct radial
		print("NOVA frame=%d" % _frame)
	if _step == 2 and _t > 2.5:
		get_tree().quit()
