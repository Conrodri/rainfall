class_name CharacterData
extends Resource
## Données d'un personnage : kit de sorts (slots 1-4) et statistiques de base (S0, Design_Personnages §3.3).
## Une stat laissée à 0 reprend la formule de Balance (valeurs d'Ardent) : Ardent n'a rien à déclarer.

@export var id: StringName = &""
@export var display_name := ""
@export var spells: Array[SpellData] = []
@export var body_color := Color(1.0, 0.55, 0.2)

@export_group("Statistiques (0 = Balance / Ardent)")
@export var base_hp := 0.0 ## PV max au niveau 1
@export var hp_per_level := 0.0
@export var armor := 0.0 ## s'ajoute à la stat `armor` des items
@export var base_regen := 0.0 ## PV/s au niveau 1
@export var regen_per_level := 0.0
@export var base_speed_u := 0.0 ## u/s (Balance.PLAYER_SPEED_U sinon)
@export var hitbox_u := 0.0 ## rayon de la hitbox (0 = forme de la scène)

@export_group("Kit")
## Logique propre au personnage (états, ressources, sorts hors SpellCaster) : script d'un Node ajouté
## comme enfant « Kit » du joueur. null = aucun (Ardent).
@export var kit_script: Script = null
## SpriteFrames du personnage ; absent sur disque = celles de la scène, teintées par `placeholder_tint`.
@export var sprite_frames_path := ""
@export var placeholder_tint := Color.WHITE
## Accent émissif du personnage : flash du repli procédural des anims d'action (Player.play_action).
@export var accent_color := Color(1.0, 0.55, 0.2)
## Frame d'impact (index 0) des anims d'action `<base>_<dir>` : l'effet du sort part à cette frame.
## Absente = ACTION_IMPACT_DEFAULT_FRAC de la durée.
@export var action_impact_frames := {&"attack": 2, &"cast": 3, &"cast_ult": 4}
## Échelle du Visual quand les SpriteFrames manquent (repli teinté plus massif, ex. Bourbe 1,15).
@export var placeholder_scale := 1.0

@export_group("Hooks génériques (0 / transparent = valeur d'Ardent)")
## Longueur de la roulade (u), parcourue à la vitesse de Balance.DODGE_* : plus courte = plus brève (et
## invulnérabilité d'autant). 0 = Balance.DODGE_DISTANCE_U. Un kit dont la roulade varie en jeu (Tocsin,
## Averse) expose en plus `dodge_distance_u()`, lu par Player.dodge_distance_u() au départ de la roulade.
@export var dodge_distance_u := 0.0
## Genre d'esquive (DodgeMove.KIND_*, docs/Design_Esquives.md) : &"" / &"roll" = roulade, &"blink" = Éclat (Ardent),
## &"slide" = Glissade. Un kit qui expose `make_dodge()` a priorité.
@export var dodge_kind: StringName = &""
## Lumières du joueur (presets LightRig `player` / `player_core`) ; alpha 0 = couleur du preset (braise d'Ardent).
@export var light_color := Color(0, 0, 0, 0)
@export var light_core_color := Color(0, 0, 0, 0)
## Teinte vers laquelle l'étalonnage se réchauffe pendant l'ultime (AmbianceManager.set_ultimate_warmth) ;
## alpha 0 = dérivée de l'accent (ultimate_grade_color()).
@export var ultimate_grade := Color(0, 0, 0, 0)

## Mélange de l'accent vers le blanc pour la teinte d'ultime dérivée (Ardent #FF8C33 -> ~#FFD6B6 ≈ #FFD6B0).
const ULTIMATE_GRADE_WHITE := 0.68


## Teinte d'étalonnage de l'ultime : déclarée, sinon accent éclairci (une ambiance qui vire à l'accent du perso).
func ultimate_grade_color() -> Color:
	if ultimate_grade.a > 0.0:
		return ultimate_grade
	return Color(accent_color.r, accent_color.g, accent_color.b, 1.0).lerp(Color.WHITE, ULTIMATE_GRADE_WHITE)


## Distance de roulade déclarée (u), Balance sinon.
func base_dodge_distance_u() -> float:
	return dodge_distance_u if dodge_distance_u > 0.0 else Balance.DODGE_DISTANCE_U


## Kit d'un personnage : script `<id>_kit.gd` avec `static func character() -> CharacterData` (modèle : RictusKit).
const KIT_PATH := "res://scripts/spells/%s_kit.gd"
const ARDENT_KIT_PATH := "res://scripts/spells/ardent_kit.gd"
## Variantes de sorts (CONTRACTS.md « Variantes de sorts ») : le kit expose
## `static func variant(slot: int, variant_id: StringName) -> SpellData` (null = pas encore codée).
const VARIANT_FUNC := &"variant"
## Tests seulement : id -> chemin d'un kit factice (prioritaire sur KIT_PATH).
static var kit_paths := {}

## Variantes appliquées à ce personnage pour la run : slot (int) -> id de la variante (vide = sorts de base).
## Un kit (nœud) lit son choix par `variant_of(slot)` ou en testant l'id du SpellData du slot.
var loadout := {}


## Personnage jouable d'après son id (RunState.character). Inconnu ou sans kit = Ardent variante A.
## `spell_loadout` {slot -> id du sort} (RunState.loadout) : chaque id différent du sort de base est demandé au kit
## (`variant`) ; variante inconnue ou non codée = sort de base + warning, jamais de plantage.
static func for_id(cid: StringName, spell_loadout: Dictionary = {}) -> CharacterData:
	var cd: CharacterData
	if has_kit(cid):
		cd = load(_kit_path(cid)).character()
	else:
		cd = ArdentKit.variant_a()
	if cd != null and not spell_loadout.is_empty():
		apply_loadout(cd, cid if has_kit(cid) else &"ardent", spell_loadout)
	return cd


## Script de kit d'un personnage (ardent_kit.gd pour Ardent / inconnu), null si absent.
static func kit_script_of(cid: StringName) -> Script:
	var path := _kit_path(cid) if has_kit(cid) else ARDENT_KIT_PATH
	return load(path) as Script if ResourceLoader.exists(path) else null


## Sort d'une variante fourni par le kit (slot forcé), ou null (kit sans `variant`, variante non codée, mauvais type).
## `quiet` : pas de warning (fiche de personnage).
static func variant_spell(cid: StringName, slot: int, variant_id: StringName, quiet := false) -> SpellData:
	var script := kit_script_of(cid)
	var has_func := false
	if script != null:
		for m in script.get_script_method_list():
			if StringName(m.get("name", "")) == VARIANT_FUNC:
				has_func = true
				break
	if not has_func:
		if not quiet:
			push_warning("Variante « %s » (slot %d) : le kit de %s n'expose pas variant() ; sort de base gardé" % [variant_id, slot, cid])
		return null
	var v: Variant = script.call(VARIANT_FUNC, slot, variant_id)
	if not (v is SpellData):
		if not quiet:
			push_warning("Variante « %s » (slot %d) de %s non codée ; sort de base gardé" % [variant_id, slot, cid])
		return null
	var sd: SpellData = v
	sd.slot = slot
	if sd.id == &"":
		sd.id = variant_id
	return sd


## Remplace, pour chaque slot du loadout, le sort de base par la variante demandée (si le kit la fournit).
static func apply_loadout(cd: CharacterData, cid: StringName, spell_loadout: Dictionary) -> void:
	for k in spell_loadout:
		var slot := int(str(k))
		var vid := StringName(str(spell_loadout[k]))
		var idx := -1
		for i in cd.spells.size():
			if cd.spells[i] != null and cd.spells[i].slot == slot:
				idx = i
				break
		if idx < 0:
			push_warning("Loadout de %s : slot %d inconnu ; ignoré" % [cid, slot])
			continue
		if vid == &"" or cd.spells[idx].id == vid:
			continue # sort de base
		var sd := variant_spell(cid, slot, vid)
		if sd == null:
			continue
		cd.spells[idx] = sd
		cd.loadout[slot] = vid
		# Personnage sans kit (Ardent) : une variante peut porter son nœud de kit en méta `kit_script`.
		var ks: Variant = sd.get_meta(&"kit_script") if sd.has_meta(&"kit_script") else null
		if (cd.kit_script == null or cd.kit_script == ArdentBaseKit) and ks is Script:
			cd.kit_script = ks


## Variante choisie pour le slot (&"" = sort de base).
func variant_of(slot: int) -> StringName:
	return StringName(loadout.get(slot, &""))


static func has_kit(cid: StringName) -> bool:
	return cid != &"ardent" and cid != &"" and ResourceLoader.exists(_kit_path(cid))


static func _kit_path(cid: StringName) -> String:
	return str(kit_paths.get(cid, KIT_PATH % cid))


func max_hp_at(level: int) -> float:
	if base_hp <= 0.0:
		return Balance.player_max_hp(level)
	return base_hp + hp_per_level * (level - 1)


func regen_at(level: int) -> float:
	if base_regen <= 0.0:
		return Balance.player_regen(level)
	return base_regen + regen_per_level * (level - 1)


## Multiplicateur de vitesse de base par rapport à Ardent (4,2 / 4,0 pour Rictus).
func speed_mult() -> float:
	return base_speed_u / Balance.PLAYER_SPEED_U if base_speed_u > 0.0 else 1.0
