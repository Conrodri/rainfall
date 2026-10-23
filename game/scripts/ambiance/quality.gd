extends Node
## Autoload Quality : palier de qualité graphique (Bas / Moyen / Haut) partagé par tous les
## systèmes d'ambiance. Valeurs : docs/Direction_Lumiere_Ambiance.md §5.
##
## Détection automatique : plateforme (PC = Haut, mobile = Moyen), puis mesure de 5 s de frame
## time pendant les premières secondes de jeu (`begin_auto_measure()`, appelée par
## AmbianceManager à la première carte) : descend d'un palier si le jeu ne tient pas sa cible,
## monte d'un palier si la marge GPU est large. Résultat mémorisé (user://quality.cfg).
## Réglage manuel : `set_tier(Tier.LOW)` (coupe l'auto), `set_auto()` pour revenir.
##
## Dégradation dynamique (§5) : si le frame time moyen sur 2 s dépasse la cible du palier de
## 20 %, `degrade_level` monte d'un cran (ordre de coupe DEGRADE_ORDER) ; il ne redescend
## qu'après 20 s sous la cible. Les systèmes testent `Quality.is_cut(&"rays")`.
##
## Abonnement : `Quality.quality_changed.connect(f)` (palier ou dégradation changés), puis lire
## `Quality.get_setting(&"clé")`. Les systèmes doivent se reconfigurer à chaud à chaque signal.

signal quality_changed(tier: int)

enum Tier { LOW, MEDIUM, HIGH }

const TIER_NAMES := ["Bas", "Moyen", "Haut"]
const CFG_PATH := "user://quality.cfg"
const MEASURE_WARMUP_S := 2.0 ## ignore le chargement / la compilation des shaders
const MEASURE_WINDOW_S := 5.0 ## §0 règle 12 : « mesure de 5 s de frame time »
const UPGRADE_GPU_MS := 6.0 ## temps GPU moyen sous ce seuil (et cible tenue) -> palier supérieur
const MAX_AUTO_PASSES := 2
const DEGRADE_WINDOW_S := 2.0
const DEGRADE_MARGIN := 1.2
const RECOVER_AFTER_S := 20.0

## Ordre de coupe de la dégradation dynamique (§5). Jamais coupés : lumière du joueur, piliers,
## télégraphes, flash d'éclair.
const DEGRADE_ORDER: Array[StringName] = [&"entity_mirror", &"secondary_shadows", &"fog_puffs_extra", &"rays", &"ambient_half", &"glow", &"sun"]

## Plafonds de lumières par catégorie (§5 « PointLight2D visibles »). Catégories des presets :
## player, pillar, boss, spell, chest, elite, decor, pickup, event. `max_lights` = total.
const SETTINGS := {
	Tier.LOW: {
		&"target_frame_ms": 33.3,
		&"max_lights": 8,
		&"light_caps": {&"player": 1, &"pillar": 2, &"chest": 2, &"boss": 1, &"spell": 2, &"decor": 0, &"elite": 0, &"pickup": 0, &"event": 1},
		&"shadow_lights": 0, ## lumières ponctuelles qui projettent des ombres
		&"shadow_filter": 0, ## Light2D.ShadowFilter : 0 none, 1 PCF5, 2 PCF13
		&"shadow_atlas": 512,
		&"sun": false, ## DirectionalLight2D absente : ambiante compensée (profil ambient_low)
		&"entity_fill": true, ## v2 : fill plat des entités (1 directionnelle sans ombre, bit 1) : lisibilité sans éclaircir le sol
		&"sun_shadows": false, ## ombres DYNAMIQUES du soleil : remplacées partout par les ombres cuites
		&"baked_shadows": true, ## ombres cuites du décor (BakedShadows : 1 texture, 1 draw, coût ~nul)
		&"baked_shadow_strength": 0.8, ## Bas : un peu plus léger (sol plancher 0,16, pas d'étalonnage)
		&"contact_shadows": true, ## ombre de contact des créatures (CreatureShadows : 1 draw)
		&"occluders": &"none", ## none | obstacles | all (obstacles + boss + coffres + piliers)
		&"hdr_2d": false,
		&"glow": false,
		&"glow_levels": [],
		&"glow_intensity": 0.0,
		&"glow_bloom": 0.0,
		&"glow_threshold": 1.2,
		&"grading": &"vignette", ## vignette seule (pas de lecture de l'écran)
		&"rain_layers": 1,
		&"rain_density_mult": 0.6,
		&"rain_gusts": false,
		&"rain_drops": false, ## gouttes individuelles (particules)
		&"splash_max": 40.0, ## éclaboussures / s
		&"fog_layers": 1,
		&"fog_puffs_max": 0,
		&"fog_high": false,
		&"fog_height_mask": false,
		&"cloud_layers": 0,
		&"rays_max": 0,
		&"ambient_particles_max": 150,
		&"puddles": 0, ## 0 ciel statique + ondulation, 1 + lumières (bit 2), 2 + miroir des entités
		&"lightning_sun": false,
		&"lightning_extras": false, ## ombres longues, rayons, bolt
	},
	Tier.MEDIUM: {
		&"target_frame_ms": 16.7,
		&"max_lights": 16,
		&"light_caps": {&"player": 2, &"pillar": 2, &"chest": 4, &"boss": 3, &"spell": 3, &"decor": 2, &"elite": 2, &"pickup": 0, &"event": 2},
		&"shadow_lights": 0, ## perf 21/10 : aucune ombre dynamique (le décor est cuit, BakedShadows)
		&"shadow_filter": 1,
		&"shadow_atlas": 1024,
		&"sun": true,
		&"entity_fill": true,
		&"sun_shadows": false, ## perf 21/10 : ombres du soleil CUITES (BakedShadows), plus de projection par image
		&"baked_shadows": true,
		&"baked_shadow_strength": 1.0,
		&"contact_shadows": true,
		&"occluders": &"none", ## aucune ombre dynamique en Moyen : aucun LightOccluder2D
		## perf 22/10 : HDR 2D coupé en Moyen (CPU de rendu ≈ -1 à -3,5 ms selon la machine, perf_bench /
		## render_perf_test). Rendu tenu par AmbianceManager : soleil, fill et lumières ponctuelles convertis
		## en équivalent LDR (ldr_light), glow LDR sur seuil bas (glow_threshold_ldr).
		&"hdr_2d": false,
		&"glow": true,
		&"glow_levels": [3, 5],
		&"glow_intensity": 0.55,
		&"glow_bloom": 0.0,
		&"glow_threshold": 1.2, ## v2 : seules les émissions et les cœurs de lumière (> 1,2) fleurissent : pas de voile
		&"glow_threshold_ldr": 0.82, ## sans HDR 2D les valeurs plafonnent à 1 : seuls les quasi-blancs (émissions, cœurs de lumière) fleurissent
		&"grading": &"full",
		&"rain_layers": 2,
		&"rain_density_mult": 1.0,
		&"rain_gusts": true,
		&"rain_drops": false,
		&"splash_max": 120.0,
		&"fog_layers": 2,
		&"fog_puffs_max": 8,
		&"fog_high": false,
		&"fog_height_mask": false,
		&"cloud_layers": 1,
		&"rays_max": 3,
		&"ambient_particles_max": 500,
		&"puddles": 1,
		&"lightning_sun": true,
		&"lightning_extras": false,
	},
	Tier.HIGH: {
		&"target_frame_ms": 16.7,
		&"max_lights": 32,
		&"light_caps": {&"player": 2, &"pillar": 3, &"chest": 4, &"boss": 4, &"spell": 6, &"decor": 5, &"elite": 6, &"pickup": 1, &"event": 2},
		&"shadow_lights": 2, ## plafond perf 21/10 : joueur + 1 lumière la plus proche (décor cuit)
		&"shadow_filter": 2,
		&"shadow_atlas": 2048,
		&"sun": true,
		&"entity_fill": true,
		&"sun_shadows": false, ## ombres du soleil cuites (BakedShadows)
		&"baked_shadows": true,
		&"baked_shadow_strength": 1.0,
		&"contact_shadows": true,
		&"occluders": &"all", ## pour les seules lumières ponctuelles ombrées (joueur + 1)
		&"hdr_2d": true,
		&"glow": true,
		&"glow_levels": [2, 3, 5],
		&"glow_intensity": 0.7,
		&"glow_bloom": 0.04, ## v2 : 0,15 délavait les noirs
		&"glow_threshold": 1.2,
		&"glow_threshold_ldr": 0.82, ## si le HDR 2D est forcé coupé (hdr_override)
		&"grading": &"full",
		&"rain_layers": 2,
		&"rain_density_mult": 1.0,
		&"rain_gusts": true,
		&"rain_drops": true,
		&"splash_max": 220.0,
		&"fog_layers": 3,
		&"fog_puffs_max": 24,
		&"fog_high": true,
		&"fog_height_mask": true,
		&"cloud_layers": 2,
		&"rays_max": 6,
		&"ambient_particles_max": 1500,
		&"puddles": 2,
		&"lightning_sun": true,
		&"lightning_extras": true,
	},
}

var tier: int = Tier.HIGH
var auto: bool = true ## false = choix manuel du joueur
var calibrated: bool = false ## la mesure automatique a déjà tranché sur cet appareil
## Miroir d'exécution de GameSettings.flashes_level() (source unique, non persisté ici) : 2 complet, 1 réduit (×0,25), 0 aucun.
var flashes_level: int = 2
var last_measure: Dictionary = {} ## {fps, frame_ms, gpu_ms, cpu_ms, tier_before, tier_after}
var persist := true ## false = ne jamais écrire user://quality.cfg (bancs d'essai)
var degrade_level := 0 ## 0 = rien de coupé ; n = les n premiers éléments de DEGRADE_ORDER
var dynamic_degrade := true
var hdr_override := -1 ## bancs de comparaison : -1 = palier, 0 = HDR 2D forcé coupé, 1 = forcé (glow requis)

var _measuring := false
var _measure_t := 0.0
var _frames := 0
var _gpu_acc := 0.0
var _cpu_acc := 0.0
var _passes := 0
var _deg_t := 0.0
var _deg_frames := 0
var _deg_acc := 0.0
var _under_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	if auto and not calibrated:
		tier = default_tier_for_platform()
	_apply_global()


## Palier de départ selon la plateforme (avant mesure).
func default_tier_for_platform() -> int:
	if not _is_mobile():
		return Tier.HIGH
	return Tier.LOW if is_low_end_mobile() else Tier.MEDIUM


## GPU mobiles d'entrée de gamme (Direction §5 : Mali-G52 / Adreno 610 visés par le palier Bas) ou
## appareil à peu de cœurs : départ en Bas (la mesure auto peut ensuite monter d'un palier).
const LOW_END_GPU_HINTS := ["mali-g31", "mali-g51", "mali-g52", "mali-g57", "mali-g68", "mali-t", "adreno (tm) 3", "adreno (tm) 4", "adreno (tm) 50", "adreno (tm) 51", "adreno (tm) 60", "adreno (tm) 61", "powervr", "img bxm"]


func is_low_end_mobile() -> bool:
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	for h in LOW_END_GPU_HINTS:
		if gpu.contains(h):
			return true
	return OS.get_processor_count() <= 4


## Réglage du palier courant, corrigé par la dégradation dynamique.
func get_setting(key: StringName) -> Variant:
	var v: Variant = SETTINGS[tier].get(key)
	match key:
		&"glow":
			return bool(v) and not is_cut(&"glow")
		&"hdr_2d":
			if hdr_override >= 0:
				v = hdr_override == 1
			return bool(v) and not is_cut(&"glow") # le HDR 2D ne sert qu'au glow : coupé avec lui
		&"sun":
			return bool(v) and not is_cut(&"sun")
		&"sun_shadows":
			return bool(v) and not is_cut(&"sun") and not is_cut(&"secondary_shadows")
		&"shadow_lights":
			return mini(int(v), 1) if is_cut(&"secondary_shadows") else v
		&"fog_puffs_max":
			return mini(int(v), 8) if is_cut(&"fog_puffs_extra") else v
		&"rays_max":
			return 0 if is_cut(&"rays") else v
		&"ambient_particles_max":
			return int(v) / 2 if is_cut(&"ambient_half") else v
		&"puddles":
			return mini(int(v), 1) if is_cut(&"entity_mirror") else v
	return v


func settings_for(t: int) -> Dictionary:
	return SETTINGS[clampi(t, Tier.LOW, Tier.HIGH)]


func tier_name(t: int = -1) -> String:
	return TIER_NAMES[tier if t < 0 else t]


func is_cut(feature: StringName) -> bool:
	var i := DEGRADE_ORDER.find(feature)
	return i >= 0 and i < degrade_level


## Multiplicateur des flashs d'éclair selon l'option d'accessibilité.
func flash_mult() -> float:
	return [0.0, 0.25, 1.0][clampi(flashes_level, 0, 2)]


## Réglage manuel (menu options). `manual = true` coupe la détection automatique.
func set_tier(t: int, manual: bool = true) -> void:
	t = clampi(t, Tier.LOW, Tier.HIGH)
	if manual:
		auto = false
		_measuring = false
	var changed := t != tier
	tier = t
	degrade_level = 0
	_save()
	if changed:
		_apply_global()
		quality_changed.emit(tier)


## Revient à la détection automatique (re-mesure à la prochaine carte).
func set_auto() -> void:
	auto = true
	calibrated = false
	_passes = 0
	set_tier(default_tier_for_platform(), false)


func set_flashes_level(level: int) -> void:
	flashes_level = clampi(level, 0, 2)
	_save()


## Lance une mesure si la détection auto n'a pas encore tranché. Sans effet sinon.
func begin_auto_measure() -> void:
	if not auto or calibrated or _measuring or _passes >= MAX_AUTO_PASSES:
		return
	_measuring = true
	_measure_t = 0.0
	_frames = 0
	_gpu_acc = 0.0
	_cpu_acc = 0.0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func is_measuring() -> bool:
	return _measuring


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _measuring:
		_measure_t += delta
		if _measure_t >= MEASURE_WARMUP_S:
			var vp := get_viewport().get_viewport_rid()
			_frames += 1
			_gpu_acc += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			_cpu_acc += RenderingServer.viewport_get_measured_render_time_cpu(vp) + Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			if _measure_t >= MEASURE_WARMUP_S + MEASURE_WINDOW_S:
				_finish_measure()
	elif dynamic_degrade:
		_track_degrade(delta)


func _finish_measure() -> void:
	_measuring = false
	_passes += 1
	var fps := float(_frames) / MEASURE_WINDOW_S
	var gpu := _gpu_acc / maxf(_frames, 1)
	var cpu := _cpu_acc / maxf(_frames, 1)
	var before := tier
	var after := decide_tier(before, fps, gpu)
	last_measure = {"fps": fps, "frame_ms": 1000.0 / maxf(fps, 0.001), "gpu_ms": gpu, "cpu_ms": cpu, "tier_before": before, "tier_after": after}
	if after == before or _passes >= MAX_AUTO_PASSES:
		calibrated = true
	set_tier(after, false)
	if not calibrated:
		begin_auto_measure.call_deferred() # confirme le nouveau palier


## Règle de décision pure (testée). Cible : 30 i/s en Bas, 60 i/s en Moyen/Haut (§5).
static func decide_tier(current: int, fps: float, gpu_ms: float) -> int:
	var target_fps := 1000.0 / float(SETTINGS[current][&"target_frame_ms"])
	if fps < target_fps * 0.87 and current > Tier.LOW:
		return current - 1
	if current < Tier.HIGH and fps >= 57.0 and gpu_ms > 0.0 and gpu_ms < UPGRADE_GPU_MS:
		return current + 1
	return current


## Dégradation dynamique : moyenne sur 2 s ; +1 cran si > cible ×1,2 ; -1 après 20 s sous la cible.
func _track_degrade(delta: float) -> void:
	_deg_t += delta
	_deg_frames += 1
	_deg_acc += delta
	if _deg_t < DEGRADE_WINDOW_S:
		return
	var avg_ms := _deg_acc / float(_deg_frames) * 1000.0
	_deg_t = 0.0
	_deg_frames = 0
	_deg_acc = 0.0
	var target := float(SETTINGS[tier][&"target_frame_ms"])
	if avg_ms > target * DEGRADE_MARGIN and degrade_level < DEGRADE_ORDER.size():
		degrade_level += 1
		_under_t = 0.0
		_apply_global()
		quality_changed.emit(tier)
	elif avg_ms <= target * 1.02:
		_under_t += DEGRADE_WINDOW_S
		if _under_t >= RECOVER_AFTER_S and degrade_level > 0:
			degrade_level -= 1
			_under_t = 0.0
			_apply_global()
			quality_changed.emit(tier)
	else:
		_under_t = 0.0


## Réglages globaux : HDR 2D du viewport racine, taille de l'atlas d'ombres 2D.
func _apply_global() -> void:
	var s: Dictionary = SETTINGS[tier]
	if is_inside_tree():
		get_tree().root.use_hdr_2d = bool(get_setting(&"hdr_2d"))
	RenderingServer.canvas_set_shadow_texture_size(int(s[&"shadow_atlas"]))


func _is_mobile() -> bool:
	var p := get_node_or_null(^"/root/Platform")
	if p != null and p.has_method(&"is_mobile"):
		return bool(p.call(&"is_mobile"))
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	auto = bool(cfg.get_value("quality", "auto", true))
	calibrated = bool(cfg.get_value("quality", "calibrated", false))
	tier = clampi(int(cfg.get_value("quality", "tier", default_tier_for_platform())), Tier.LOW, Tier.HIGH)


func _save() -> void:
	if not persist or DisplayServer.get_name() == "headless":
		return # les tests headless ne doivent pas écrire la config du joueur
	var cfg := ConfigFile.new()
	cfg.set_value("quality", "auto", auto)
	cfg.set_value("quality", "calibrated", calibrated)
	cfg.set_value("quality", "tier", tier)
	cfg.save(CFG_PATH)
