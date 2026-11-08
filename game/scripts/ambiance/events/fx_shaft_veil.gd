extends AmbientEffect
## « Puits voilés » (Gouffre A, Furieux, docs/Design_Etage2_Grotte.md §Jauge) : l'orage de surface voile les puits de
## jour (lumières `preset` × `light_mult` en fondu de 10 s, rai billboard de l'AmbianceManager à `ray_mult` de son
## alpha), le mycélium monte (lumières `boost_preset` × `boost_mult`) et la poussière en suspension s'éteint
## (système de particules du profil nommé `mute_particles`). La salle passe du blanc-chaud au violet ; le fill des
## entités et le plancher de luminance ne bougent pas (jamais d'obscurité). Aucun effet de jeu.
## Paramètres : "preset" ("light_shaft"), "light_mult" (0,4), "ray_mult" (0,343 : alpha 0,35 -> 0,12),
## "boost_preset" ("mycelium_glow"), "boost_mult" (1,35), "mute_particles" ("poussière").


func start() -> void:
	mgr.set_preset_light_mult(StringName(def.get("preset", "light_shaft")), float(def.get("light_mult", 0.4)))
	var bp := String(def.get("boost_preset", ""))
	if bp != "":
		mgr.set_preset_light_mult(StringName(bp), float(def.get("boost_mult", 1.35)))
	mgr.shaft_ray_target = float(def.get("ray_mult", 0.12 / 0.35))
	var mute := String(def.get("mute_particles", ""))
	if mute != "" and mgr.weather != null:
		mgr.weather.set_particle_mult(mute, 0.0)


func stop() -> void:
	if mgr == null or not is_instance_valid(mgr):
		return
	mgr.set_preset_light_mult(StringName(def.get("preset", "light_shaft")), 1.0)
	var bp := String(def.get("boost_preset", ""))
	if bp != "":
		mgr.set_preset_light_mult(StringName(bp), 1.0)
	mgr.shaft_ray_target = 1.0
	var mute := String(def.get("mute_particles", ""))
	if mute != "" and mgr.weather != null:
		mgr.weather.set_particle_mult(mute, 1.0)
