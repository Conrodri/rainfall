class_name SaltSector
extends SafeSector
## Nef sèche de la Procession du Roi de sel : SafeSector (boîte à outils) où, en plus du secteur tournant, l'ombre
## derrière une Stèle de sel (SaltSteles.shelters) reste sèche. Le reste (télégraphe, rotation bornée à 6,3 u/s
## au bord, ticks hors nef seulement, répit) vient de SafeSector. Voir docs/Design_Boss_Raid.md §2.3.

var steles: SaltSteles = null


static func spawn_salt(p_boss: Node2D, center: Vector2, opts: Dictionary, p_steles: SaltSteles) -> SaltSector:
	var s := SaltSector.new()
	s.name = &"SaltSector"
	s.boss = p_boss
	s.steles = p_steles
	s.radius_u = float(opts.get("radius_u", 9.0))
	s.sector_deg = float(opts.get("sector_deg", 90.0))
	s.turn_deg_s = float(opts.get("turn_deg_s", 30.0))
	s.duration_s = float(opts.get("duration_s", 7.0))
	s.tele_s = maxf(float(opts.get("tele_s", 1.2)), 1.2)
	s.tick_s = float(opts.get("tick_s", 0.5))
	s.angle = float(opts.get("angle", 0.0))
	var max_turn := rad_to_deg(SafeSector.MAX_EDGE_SPEED_U / maxf(s.radius_u, 0.1))
	s.turn_deg_s = clampf(s.turn_deg_s, -max_turn, max_turn)
	RaidKit.world_of(p_boss).add_child(s)
	s.global_position = center
	s._vis = RaidFx.attach_ground(s, RaidFx.visual(&"safe_sector", RaidFx.Kind.SECTOR, RaidFx.CYAN, s.radius_u * RaidKit.U))
	RaidFx.set_value(s._vis, deg_to_rad(s.sector_deg) * 0.5)
	s._vis.rotation = s.angle
	return s


func in_safe(p: Vector2) -> bool:
	if super.in_safe(p):
		return true
	return steles != null and is_instance_valid(steles) and steles.shelters(p, global_position)


## Répit en cours (la marée baisse : « REFLUX »).
func in_respite() -> bool:
	if t < tele_s or respite_every_s <= 0.0:
		return false
	return fmod(t - tele_s, respite_every_s + respite_s) >= respite_every_s


func release() -> void:
	_done = true
	queue_free()
