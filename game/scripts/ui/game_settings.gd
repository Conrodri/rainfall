class_name GameSettings
extends RefCounted
## Réglages du joueur persistés dans user://settings.cfg (même fichier que les volumes d'Audio,
## section « audio », écrite par Audio lui-même). Sections gérées ici :
##   [graphics] quality = -1 (auto) | 0 Bas | 1 Moyen | 2 Haut ; flashes = 0 aucun | 1 réduits | 2 complets
##   [graphics] fullscreen = bool (PC) ; show_fps = bool ; colorblind = 0 aucun | 1 deutéranopie | 2 protanopie | 3 tritanopie
##   [gameplay] auto_cast = bool (sorts 2-4 automatiques, option d'accessibilité) ; haptics = bool ;
##   pause_long_press = bool ; damage_text_scale = 0,8 | 1 | 1,3
##   [gameplay] key_hints = bool (invites de touches sous les sorts toujours visibles ; sinon 5 s en début de partie)
##   [gameplay] overhead_bars = bool (barres de vie / ressource au-dessus du personnage, défaut true)
##   [gameplay] shake = 0.0..1.0 (secousses de caméra, pas de 0,1, défaut 1) ; reduce_motion = bool (défaut false :
##   plus d'arrêt sur image, de tremblement de barre ni de pulsation PV bas)
## Flashs / secousses / mouvements : GameSettings est la SEULE source de vérité. Quality.flashes_level n'est qu'un
## miroir d'exécution, resynchronisé par set_flashes / apply_graphics / reset_all. Consommateurs : flash_scale(),
## shake_scale(), hitstop_enabled(), reduce_motion().
##   [gameplay] chest_reveal, ui_scale, hints ; [accessibility] strong_telegraphs, stick_deadzone, joystick_scale,
##   mono_audio, reticle_scale ; [first_launch] photosensitivity_seen : voir la section « Vague 2 UX » en fin de fichier.
## Chaque écriture relit le fichier pour conserver les autres sections. Comme Quality, rien n'est
## écrit en headless (les tests ne touchent pas la config du joueur).

const PATH := "user://settings.cfg"
static var cfg_path := PATH ## chemin effectif (tests : fichier injecté, jamais le réglage réel du joueur)
const QUALITY_AUTO := -1
const DAMAGE_SCALES := [0.8, 1.0, 1.3] ## Petits · Normaux · Grands


static func _cfg() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.load(cfg_path) # fichier absent : config vide
	return cf


static func get_value(section: String, key: String, default: Variant) -> Variant:
	return _cfg().get_value(section, key, default)


static func set_value(section: String, key: String, value: Variant) -> void:
	if cfg_path == PATH and (DisplayServer.get_name() == "headless" or Engine.get_write_movie_path() != ""):
		return # tests et captures : la config du joueur reste intacte
	var cf := _cfg()
	cf.set_value(section, key, value)
	cf.save(cfg_path)


## Palier de qualité choisi : QUALITY_AUTO ou 0..2 (par défaut : l'état courant de Quality).
static func quality_choice() -> int:
	var q: Node = _quality()
	var fallback := QUALITY_AUTO
	if q != null and not bool(q.get("auto")):
		fallback = int(q.get("tier"))
	return int(get_value("graphics", "quality", fallback))


static func flashes_level() -> int:
	return clampi(int(get_value("graphics", "flashes", 2)), 0, 2)


const FLASH_SCALES := [0.0, 0.25, 1.0] ## Aucun · Réduits · Complets
const SHAKE_DEFAULT := 1.0

# Cache des deux réglages lus à chaque coup (secousse, arrêt sur image) : relu si le fichier injecté change.
static var _cache_path := "<unset>"
static var _shake := SHAKE_DEFAULT
static var _reduce := false


static func _ensure_cache() -> void:
	if _cache_path == cfg_path:
		return
	_cache_path = cfg_path
	_shake = clampf(float(get_value("gameplay", "shake", SHAKE_DEFAULT)), 0.0, 1.0)
	_reduce = bool(get_value("gameplay", "reduce_motion", false))


## Échelle des flashs [0, 1] : 0 aucun, 0,25 réduits, 1 complets. Lit l'état d'exécution (Quality, resynchronisé
## depuis ce fichier) pour que les tests qui posent Quality.flashes_level restent cohérents.
static func flash_scale() -> float:
	var q: Node = _quality()
	var lvl := int(q.get("flashes_level")) if q != null else flashes_level()
	return float(FLASH_SCALES[clampi(lvl, 0, 2)])


## Secousses de caméra : multiplicateur [0, 1], indépendant des flashs.
static func shake_scale() -> float:
	_ensure_cache()
	return _shake


static func set_shake(v: float) -> void:
	_ensure_cache()
	_shake = snappedf(clampf(v, 0.0, 1.0), 0.1)
	set_value("gameplay", "shake", _shake)


## « Réduire les mouvements » : pas d'arrêt sur image, de tremblement de barre ni de pulsation PV bas.
static func reduce_motion() -> bool:
	_ensure_cache()
	return _reduce


static func set_reduce_motion(on: bool) -> void:
	_ensure_cache()
	_reduce = on
	set_value("gameplay", "reduce_motion", on)


## Arrêts sur image autorisés (joueur, monstres, boss).
static func hitstop_enabled() -> bool:
	return not reduce_motion()


static func auto_cast() -> bool:
	return bool(get_value("gameplay", "auto_cast", false))


## Applique la qualité et les flashs enregistrés (début de partie). Sans entrée : on laisse Quality.
static func apply_graphics() -> void:
	_cache_path = "<unset>" # secousse / mouvements relus depuis le fichier
	var q: Node = _quality()
	if q == null:
		return
	var cf := _cfg()
	if cf.has_section_key("graphics", "quality"):
		_apply_quality(q, int(cf.get_value("graphics", "quality", QUALITY_AUTO)))
	q.call(&"set_flashes_level", int(cf.get_value("graphics", "flashes", 2))) # miroir toujours resynchronisé
	if cf.has_section_key("graphics", "fullscreen"):
		apply_fullscreen(bool(cf.get_value("graphics", "fullscreen", false)))


static func set_quality(choice: int) -> void:
	var q: Node = _quality()
	if q != null:
		_apply_quality(q, choice)
	set_value("graphics", "quality", choice)


static func set_flashes(level: int) -> void:
	var q: Node = _quality()
	if q != null:
		q.call(&"set_flashes_level", level)
	set_value("graphics", "flashes", clampi(level, 0, 2))


## Option auto-cast : appliquée au joueur courant (groupe `player`) et enregistrée.
static func set_auto_cast(tree: SceneTree, on: bool) -> void:
	apply_auto_cast(tree, on)
	set_value("gameplay", "auto_cast", on)


static func apply_auto_cast(tree: SceneTree, on: bool) -> void:
	var p := tree.get_first_node_in_group(&"player") if tree != null else null
	if p != null and "auto_cast_spells" in p:
		p.set(&"auto_cast_spells", on)


static func _apply_quality(q: Node, choice: int) -> void:
	if choice < 0:
		if not bool(q.get("auto")):
			q.call(&"set_auto")
	elif bool(q.get("auto")) or int(q.get("tier")) != choice:
		q.call(&"set_tier", choice)


static func _quality() -> Node:
	var ml := Engine.get_main_loop() as SceneTree
	return ml.root.get_node_or_null(^"Quality") if ml != null else null


# --- Nouvelles clés (Design_Menus §5). Les consommateurs (HUD FPS, DamageNumbers, haptique) lisent ces getters.

static func fullscreen() -> bool:
	return bool(get_value("graphics", "fullscreen", false))


static func show_fps() -> bool:
	return bool(get_value("graphics", "show_fps", false))


static func colorblind() -> int:
	return clampi(int(get_value("graphics", "colorblind", 0)), 0, 3)


static func haptics() -> bool:
	return bool(get_value("gameplay", "haptics", true))


## Appui long sur le bouton pause : activé par défaut sur mobile, désactivé sur PC.
static func pause_long_press() -> bool:
	var pl := _platform()
	var mobile := bool(pl.call(&"is_mobile")) if pl != null else false
	return bool(get_value("gameplay", "pause_long_press", mobile))


static func damage_text_scale() -> float:
	return float(get_value("gameplay", "damage_text_scale", 1.0))


static func set_fullscreen(on: bool) -> void:
	apply_fullscreen(on)
	set_value("graphics", "fullscreen", on)


## Plein écran : PC seulement, jamais en headless / capture vidéo.
static func apply_fullscreen(on: bool) -> void:
	if DisplayServer.get_name() == "headless" or Engine.get_write_movie_path() != "":
		return
	var pl := _platform()
	if pl != null and not bool(pl.call(&"is_pc")):
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


static func set_show_fps(on: bool) -> void:
	set_value("graphics", "show_fps", on)


static func set_colorblind(mode: int) -> void:
	set_value("graphics", "colorblind", clampi(mode, 0, 3))


static func set_haptics(on: bool) -> void:
	set_value("gameplay", "haptics", on)


## Intensité des vibrations [0, 1] (défaut 1) : lue par le module Haptics (mobile et manette).
static func haptics_strength() -> float:
	return clampf(float(get_value("gameplay", "haptics_strength", 1.0)), 0.0, 1.0)


static func set_haptics_strength(v: float) -> void:
	set_value("gameplay", "haptics_strength", snappedf(clampf(v, 0.0, 1.0), 0.1))


static func set_pause_long_press(on: bool) -> void:
	set_value("gameplay", "pause_long_press", on)


static func set_damage_text_scale(v: float) -> void:
	set_value("gameplay", "damage_text_scale", v)


## Indice (0..2) de DAMAGE_SCALES le plus proche de la valeur enregistrée.
static func damage_text_index() -> int:
	var v := damage_text_scale()
	var best := 0
	for i in DAMAGE_SCALES.size():
		if absf(float(DAMAGE_SCALES[i]) - v) < absf(float(DAMAGE_SCALES[best]) - v):
			best = i
	return best


## « Réinitialiser » : efface les sections graphics et gameplay, remet les volumes par défaut
## (Audio.DEFAULT_VOLUMES) et applique les valeurs par défaut (qualité auto, flashs complets, auto-cast off).
static func reset_all(tree: SceneTree = null) -> void:
	if cfg_path != PATH or (DisplayServer.get_name() != "headless" and Engine.get_write_movie_path() == ""):
		var cf := _cfg()
		for sec in ["graphics", "gameplay", "accessibility"]: # [first_launch] conservé : l'avertissement ne revient pas
			if cf.has_section(sec):
				cf.erase_section(sec)
		cf.save(cfg_path)
	var q: Node = _quality()
	if q != null:
		_apply_quality(q, QUALITY_AUTO)
		q.call(&"set_flashes_level", 2)
	_cache_path = cfg_path # section gameplay effacée : valeurs par défaut
	_shake = SHAKE_DEFAULT
	_reduce = false
	apply_fullscreen(false)
	var ml := Engine.get_main_loop() as SceneTree
	RenderStyle.set_style(RenderStyle.DEFAULT, tree if tree != null else ml, false) # section graphics effacée
	apply_auto_cast(tree if tree != null else ml, false)
	apply_show_hitbox(tree if tree != null else ml, true) # section gameplay effacée : défaut affiché
	var au: Node = ml.root.get_node_or_null(^"Audio") if ml != null else null
	if au != null:
		var defaults: Dictionary = (au.get_script() as GDScript).get_script_constant_map().get("DEFAULT_VOLUMES", {})
		for k in defaults:
			au.call(&"set_volume", k, float(defaults[k]))
	if ml != null and ml.root != null:
		ml.root.size_changed.emit() # taille de l'interface revenue au défaut : le HUD se recalcule


static func _platform() -> Node:
	var ml := Engine.get_main_loop() as SceneTree
	return ml.root.get_node_or_null(^"Platform") if ml != null else null


## Invites de touches sous les boutons de sorts : toujours visibles (true) ou 5 s en début de partie (false, défaut).
static func key_hints() -> bool:
	return bool(get_value("gameplay", "key_hints", false))


static func set_key_hints(on: bool) -> void:
	set_value("gameplay", "key_hints", on)


## Barres de vie / ressource au-dessus de la tête du personnage (OverheadBars) : affichées (true, défaut) ou masquées.
static func overhead_bars() -> bool:
	return bool(get_value("gameplay", "overhead_bars", true))


static func set_overhead_bars(on: bool) -> void:
	set_value("gameplay", "overhead_bars", on)


## Anneau de hitbox au sol sous le joueur (HitboxRing) : affiché (true, défaut) ou masqué. Réglages > Accessibilité.
static func show_hitbox() -> bool:
	return bool(get_value("gameplay", "show_hitbox", true))


static func set_show_hitbox(tree: SceneTree, on: bool) -> void:
	set_value("gameplay", "show_hitbox", on)
	apply_show_hitbox(tree, on)


## Applique à chaud aux anneaux vivants (groupe HitboxRing.GROUP).
static func apply_show_hitbox(tree: SceneTree, on: bool) -> void:
	if tree == null:
		return
	for n in tree.get_nodes_in_group(&"hitbox_ring"):
		n.set(&"enabled", on)


## Style de rendu des sprites : « cel » (défaut, DA validée 22/10/2026) ou « 3d » (ancien rendu). Appliqué par RenderStyle
## (RenderStyle.set_style persiste ici ; F7 en jeu bascule à chaud).
static func render_style() -> String:
	return String(get_value("graphics", "render_style", String(RenderStyle.DEFAULT)))


static func set_render_style(s: String) -> void:
	set_value("graphics", "render_style", s)


# --- Vague 2 UX (agent « Réglages ») : coffres, taille de l'interface, astuces, accessibilité, confort -----------
## Clés lues par d'autres lots via get_value (noms exacts, ne pas renommer) :
##   [gameplay] chest_reveal = "complete" | "short" | "instant" (défaut complete ; Balance.CHEST_REVEAL_MULT)
##   [gameplay] ui_scale = 0,8..1,5 par pas de 0,1 : taille affichée « 80-150 % » rapportée au PC ; défaut 1,5 mobile
##              (= HudMetrics.MOBILE_K), 1,0 PC. Le HUD lit hud_user_scale() = ui_scale / facteur plateforme.
##   [gameplay] hints = bool (astuces de jeu de la 1re run, lot M-A ; défaut true)
##   [accessibility] strong_telegraphs = bool (télégraphes renforcés, lot A11y-L9 ; défaut false)
##   [accessibility] stick_deadzone = 0,10..0,35 (zone morte des sticks, défaut 0,20) ; joystick_scale = 0,8..1,5
##              (taille du joystick tactile, défaut 1) ; mono_audio = bool (défaut false) ; reticle_scale = 1 | 1,5
##   [first_launch] photosensitivity_seen = bool (avertissement du titre déjà montré ; jamais effacé par reset_all)

const CHEST_REVEAL_DEFAULT := "complete"
const UI_SCALE_MIN := 0.8
const UI_SCALE_MAX := 1.5
const DEADZONE_MIN := 0.10
const DEADZONE_MAX := 0.35
const DEADZONE_DEFAULT := 0.20
const JOYSTICK_SCALE_MIN := 0.8
const JOYSTICK_SCALE_MAX := 1.5
const RETICLE_SCALES := [1.0, 1.5] ## 100 % · 150 %


static func chest_reveal() -> String:
	var v := String(get_value("gameplay", "chest_reveal", CHEST_REVEAL_DEFAULT))
	return v if Balance.CHEST_REVEAL_MULT.has(StringName(v)) else CHEST_REVEAL_DEFAULT


static func set_chest_reveal(mode: String) -> void:
	set_value("gameplay", "chest_reveal", mode if Balance.CHEST_REVEAL_MULT.has(StringName(mode)) else CHEST_REVEAL_DEFAULT)


## Multiplicateurs [rareté, items] des durées de l'écran de coffre (ChestUI.RARITY_DUR / ITEM_DUR).
static func chest_reveal_mult() -> Array:
	return Balance.CHEST_REVEAL_MULT[StringName(chest_reveal())]


## Facteur de taille propre à la plateforme (100 % = tailles PC) : HudMetrics.MOBILE_K sur mobile.
static func platform_ui_k() -> float:
	var pl := _platform()
	return HudMetrics.MOBILE_K if pl != null and bool(pl.call(&"is_mobile")) else 1.0


## « Taille de l'interface » affichée (0,8..1,5) ; défaut : facteur de la plateforme.
static func ui_scale() -> float:
	return clampf(snappedf(float(get_value("gameplay", "ui_scale", platform_ui_k())), 0.1), UI_SCALE_MIN, UI_SCALE_MAX)


## Multiplicateur appliqué par le HUD par-dessus ses tables PC / mobile (1,0 au défaut de chaque plateforme).
static func hud_user_scale() -> float:
	return ui_scale() / platform_ui_k()


## Écrit la taille et relance la mise en page du HUD (signal size_changed de la fenêtre racine).
static func set_ui_scale(v: float) -> void:
	set_value("gameplay", "ui_scale", clampf(snappedf(v, 0.1), UI_SCALE_MIN, UI_SCALE_MAX))
	var ml := Engine.get_main_loop() as SceneTree
	if ml != null and ml.root != null:
		ml.root.size_changed.emit()


static func hints() -> bool:
	return bool(get_value("gameplay", "hints", true))


static func set_hints(on: bool) -> void:
	set_value("gameplay", "hints", on)


static func strong_telegraphs() -> bool:
	return bool(get_value("accessibility", "strong_telegraphs", false))


static func set_strong_telegraphs(on: bool) -> void:
	set_value("accessibility", "strong_telegraphs", on)


static func stick_deadzone() -> float:
	return clampf(float(get_value("accessibility", "stick_deadzone", DEADZONE_DEFAULT)), DEADZONE_MIN, DEADZONE_MAX)


static func set_stick_deadzone(v: float) -> void:
	set_value("accessibility", "stick_deadzone", clampf(snappedf(v, 0.05), DEADZONE_MIN, DEADZONE_MAX))


static func joystick_scale() -> float:
	return clampf(float(get_value("accessibility", "joystick_scale", 1.0)), JOYSTICK_SCALE_MIN, JOYSTICK_SCALE_MAX)


static func set_joystick_scale(v: float) -> void:
	set_value("accessibility", "joystick_scale", clampf(snappedf(v, 0.1), JOYSTICK_SCALE_MIN, JOYSTICK_SCALE_MAX))


static func mono_audio() -> bool:
	return bool(get_value("accessibility", "mono_audio", false))


static func set_mono_audio(on: bool) -> void:
	set_value("accessibility", "mono_audio", on)


static func reticle_scale() -> float:
	return 1.5 if float(get_value("accessibility", "reticle_scale", 1.0)) > 1.25 else 1.0


static func set_reticle_scale(v: float) -> void:
	set_value("accessibility", "reticle_scale", 1.5 if v > 1.25 else 1.0)


## Avertissement de photosensibilité (titre, premier lancement).
static func photosensitivity_seen() -> bool:
	return bool(get_value("first_launch", "photosensitivity_seen", false))


static func set_photosensitivity_seen() -> void:
	set_value("first_launch", "photosensitivity_seen", true)
