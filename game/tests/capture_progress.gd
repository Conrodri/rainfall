extends Node
## Capture de l'écran Progression (profil factice, rien n'est écrit sur disque).
## godot --path game --write-movie <dossier>/f.png --fixed-fps 30 --quit-after 20 res://tests/capture_progress.tscn

class FakeProfile extends RefCounted:
	var rubies := 4820
	var stats := {"runs": 37, "victories": 5, "kills": 18423, "play_time_s": 3600.0 * 12.0,
		"best_time_s": {"facile": 812.0}, "victories_by_mode": {"facile": 5}}


func _ready() -> void:
	var ps := ProgressScreen.new()
	ps.profile = FakeProfile.new()
	add_child(ps)
