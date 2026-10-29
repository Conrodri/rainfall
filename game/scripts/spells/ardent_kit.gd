class_name ArdentKit
extends RefCounted
## Kit d'Ardent. Variante A seulement (prototype) ; la variante B sera une autre fonction/ressource.

## Identifiants des sorts de la variante B (GDD §Ardent), réservés : ce sont aussi les ids
## audio (`spell.<id>.cast_<niveau>` dans data/audio/sounds.json) et les presets de LightRig.
const VARIANT_B_IDS := {1: &"roaming_embers", 2: &"flame_pillar", 3: &"meteor_rain", 4: &"phoenix"}
## Slot de l'ultime (son d'ultime, ducking, réchauffement de l'étalonnage).
const ULTIMATE_SLOT := 4
## Équilibrage (simulateur du 22/10/2026) : Ardent reste le débutant sûr (kite, zone) mais ne domine plus la cible
## unique. Nova 3,0 -> 2,5 et Brasier 10 -> 8 (≈ −10 % de DPS cible, zone quasi inchangée).
## Combos (docs/Design_Combos.md §3, 29/10/2026) : −8 % de base pour compenser les bonus de la marque braise
## (ArdentBaseKit) : Nova 2,5 -> 2,3 et Brasier 8 -> 7,4.
const NOVA_COEF := 2.3
const BRASIER_COEF := 7.4
## Frames d'impact des anims d'action (Design_Feel_Sorts §9.2) : `cast` (Nova et Cendres) 3 -> 2, soit 10 f au lieu de 15 f
## à 12 fps. Éclat auto (`attack`, 2) et Brasier (`cast_ult`, 4) inchangés ; la pose tenue et les retimings attendent Codex.
const ACTION_IMPACT_FRAMES := {&"attack": 2, &"cast": 2, &"cast_ult": 4}
## Variantes de sorts (docs/Variantes_Sorts.md §2.1) : coefs de départ, ajustés au simulateur (balance_sim_run
## --chars=ardent) pour rester à ±15 % du sort de base : tests/ardent_variants_bench.tscn (sort isolé, base vs variante).
## 23/10 : valeurs de la 2e passe de mesure ; METEOR_COEF (6,0) est une extrapolation à re-mesurer (voir art/tools/night/reprise/ardent.md).
const EMBER_COEF := 0.50 ## par orbe et par touche (immunité 0,4 s par orbe et par monstre)
const PILLAR_COEF := 0.25 ## par tick de 0,25 s
const METEOR_COEF := 6.0 ## par impact (5 par lancer)
const PHOENIX_COEF := 0.4 ## par piqué (toutes les 1,5 s pendant 12 s)
const PHOENIX_BURST_COEF := 1.3 ## explosion finale
## Preset LightRig par sort (éclat à l'impact / lumière de zone).
const SPELL_LIGHTS := {
	&"eclat_de_braise": &"ember", &"nova_ardente": &"nova", &"cendres": &"ash_zone", &"brasier": &"brasier",
	&"roaming_embers": &"ember", &"flame_pillar": &"flame_pillar", &"meteor_rain": &"meteor_impact", &"phoenix": &"phoenix",
	&"phoenix_burst": &"nova",
}
## VFX rendus (assets/sprites/vfx/<nom>/<nom>.tres) par sort : seule table de chemins des effets d'Ardent.
## radius_px = rayon de l'empreinte au sol dans la frame (anneau principal), floor_aspect = ellipse du sol dans
## la frame (rendus fx_p1/p4 caméra 55° : 0,67 ; rendus iso du lot A2 : ~0,49). Variante B : branchée dès que
## ses sorts seront codés (mêmes champs SpellData).
## Lot A2 (Codex, 22/10/2026, art/tools/iso/a2_build.py) : rayon du lit incandescent z=0 projeté par la caméra iso,
## mesuré dans la frame (nova 512 px, cendres 384 px, brasier 640 px). ZoneEffect met l'anneau au rayon de gameplay
## exact (k = rayon / radius_px) : plus d'agrandissement parasite du brasier.
const VFX_DIR := "res://assets/sprites/vfx/"
const SPELL_VFX := {
	&"nova_ardente": {"name": "ardent_nova", "radius_px": 189.02, "floor_aspect": 0.4895},
	&"cendres": {"name": "ardent_ashes", "radius_px": 155.57, "floor_aspect": 0.4829},
	&"brasier": {"name": "ardent_brasier", "radius_px": 224.60, "floor_aspect": 0.4895, "flame_h_px": 560.0},
	&"flame_pillar": {"name": "flame_pillar", "radius_px": 50.0, "floor_aspect": 0.67},
	&"meteor_rain": {"name": "meteor_impact", "radius_px": 85.0, "floor_aspect": 0.67},
	&"phoenix_burst": {"name": "ardent_nova", "radius_px": 189.02, "floor_aspect": 0.4895}, # placeholder : VFX de la Nova
	&"ash_flare": {"name": "ardent_nova", "radius_px": 189.02, "floor_aspect": 0.4895}, # flambée d'une Cendres (ArdentBaseKit)
}


## Renseigne les champs vfx_* du sort d'après SPELL_VFX (rien si le sort n'a pas d'effet rendu).
static func apply_vfx(s: SpellData) -> SpellData:
	s.light_preset = SPELL_LIGHTS.get(s.id, s.light_preset)
	var v: Dictionary = SPELL_VFX.get(s.id, {})
	if not v.is_empty():
		s.vfx_frames = VFX_DIR + "%s/%s.tres" % [v["name"], v["name"]]
		s.vfx_radius_px = float(v["radius_px"])
		s.vfx_floor_aspect = float(v["floor_aspect"])
		s.vfx_flame_h_px = float(v.get("flame_h_px", 0.0))
	return s


## Icônes de sorts (assets/sprites/icons/spells/<nom>.png) : les ids de la variante B diffèrent des fichiers.
const ICON_DIR := "res://assets/sprites/icons/spells/"
const ICON_NAMES := {
	&"roaming_embers": "braises_errantes", &"flame_pillar": "pilier_de_flamme",
	&"meteor_rain": "pluie_de_meteores", &"phoenix": "phenix",
}


## Icône d'un sort, ou null si elle n'est pas encore livrée (le HUD affiche alors un libellé).
static func spell_icon(sid: StringName) -> Texture2D:
	var path: String = ICON_DIR + String(ICON_NAMES.get(sid, String(sid))) + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	# Icônes livrées préfixées par le personnage (averse_goutte_lame.png, bourbe_gifle_de_vase.png…) alors que
	# l'id du sort ne l'est pas : on essaie « <id perso>_<id sort> » pour chaque personnage de characters.json.
	for cid in _character_ids():
		var p2: String = ICON_DIR + cid + "_" + String(sid) + ".png"
		if ResourceLoader.exists(p2):
			return load(p2) as Texture2D
	return null


static var _char_ids: Array = []


static func _character_ids() -> Array:
	if _char_ids.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
		if parsed is Array:
			for c in parsed:
				if c is Dictionary and str(c.get("id", "")) != "":
					_char_ids.append(str(c.get("id", "")))
	return _char_ids


static func _spell(sid: StringName, name: String, slot: int, behavior: SpellData.Behavior, coef: float, cd: float) -> SpellData:
	var s := SpellData.new()
	s.id = sid
	s.display_name = name
	s.slot = slot
	s.behavior = behavior
	s.coef = coef
	s.base_cooldown = cd
	return apply_vfx(s)


## Variantes de sorts d'Ardent (contrat CONTRACTS.md « Variantes de sorts ») : SpellData de la variante
## `variant_id` pour le slot, ou null tant qu'elle n'est pas codée (le sort de base est alors gardé).
static func variant(slot: int, variant_id: StringName) -> SpellData:
	if VARIANT_B_IDS.get(slot, &"") != variant_id:
		return null
	var s: SpellData = null
	match variant_id:
		&"roaming_embers":
			# 3 orbes de 1,8 u de rayon d'orbite (ArdentEmberRing) : sort permanent, recul 0,15 u
			s = _spell(variant_id, "Braises errantes", 1, SpellData.Behavior.KIT, EMBER_COEF, 0.6)
			s.is_auto = true
			s.is_zone = false
			s.item_pierce = false
			s.range_u = 1.8
			s.trigger_range_u = 1.8
			s.proc_coef = 0.6
			s.hit_force = _force_for(0.15)
		&"flame_pillar":
			# colonne rayon 1,2 u pendant 2,5 s, 1 tick / 0,25 s ; visée 6 u (curseur, stick, ou paquet le plus dense)
			s = _spell(variant_id, "Pilier de flamme", 2, SpellData.Behavior.KIT, PILLAR_COEF, 6.0)
			s.radius_u = 1.2
			s.duration = 2.5
			s.tick = 0.25
			s.range_u = 6.0
			s.trigger_range_u = 6.0
			s.proc_coef = 0.3
			s.target_mode = &"densest"
			s.hit_force = 0.0
			s.color = Color(1.0, 0.45, 0.1)
		&"meteor_rain":
			# 5 impacts de 1 u sur un disque de 3 u visé à 7 u ; durée 0 = impact instantané (ArdentVariantKit)
			s = _spell(variant_id, "Pluie de météores", 3, SpellData.Behavior.KIT, METEOR_COEF, 8.0)
			s.radius_u = 1.0
			s.range_u = 7.0
			s.trigger_range_u = 7.0
			s.proc_coef = 0.8
			s.target_mode = &"densest"
			s.hit_force = _force_for(0.5)
			s.color = Color(1.0, 0.4, 0.1)
		&"phoenix":
			# `coef` = un piqué (ArdentPhoenix) ; l'explosion finale est phoenix_burst_spell()
			s = _spell(variant_id, "Phénix", 4, SpellData.Behavior.KIT, PHOENIX_COEF, 20.0)
			s.range_u = 8.0
			s.trigger_range_u = 8.0
			s.proc_coef = 0.7
			s.color = Color(1.0, 0.5, 0.1)
	if s != null:
		s.set_meta(&"kit_script", ArdentVariantKit) # CharacterData.apply_loadout : le joueur reçoit ce nœud de kit
	return s


## Explosion finale du Phénix (zone instantanée, rayon 3 u, coef 2,0 ; le VFX est celui de la Nova, à remplacer).
static func phoenix_burst_spell() -> SpellData:
	var s := _spell(&"phoenix_burst", "Phénix consumé", ULTIMATE_SLOT, SpellData.Behavior.NOVA, PHOENIX_BURST_COEF, 0.0)
	s.radius_u = 3.0
	s.proc_coef = 1.0
	s.color = Color(1.0, 0.45, 0.1)
	return s


## Force de coup (recul) correspondant à un recul de `knock_u` unités.
static func _force_for(knock_u: float) -> float:
	return clampf(inverse_lerp(Balance.KB_MIN_U, Balance.KB_MAX_U, knock_u), 0.0, 1.0)


static func variant_a() -> CharacterData:
	ArdentTracker.ensure_hook() # compteurs de déblocage des variantes (Nova, Cendres, boss de l'étage 2)
	var c := CharacterData.new()
	c.ultimate_grade = AmbianceManager.WARM_COLOR # #FFD6B0 (Brasier, Direction §4.2), réglé à la main
	c.id = &"ardent"
	c.display_name = "Ardent"
	c.dodge_kind = DodgeMove.KIND_BLINK # Éclat : téléportation courte en braises (docs/Design_Esquives.md)
	c.kit_script = ArdentBaseKit # marque braise et combos (Design_Combos §3) ; remplacé par ArdentVariantKit avec une variante
	c.action_impact_frames = ACTION_IMPACT_FRAMES

	var s1 := _spell(&"eclat_de_braise", "Éclat de braise", 1, SpellData.Behavior.PROJECTILE, 0.8, 0.6)
	s1.is_auto = true
	s1.is_zone = false
	s1.pierce = 1
	s1.range_u = 9.0

	var s2 := _spell(&"nova_ardente", "Nova ardente", 2, SpellData.Behavior.NOVA, NOVA_COEF, 6.0)
	s2.radius_u = 3.5
	s2.trigger_range_u = 3.0

	var s3 := _spell(&"cendres", "Cendres", 3, SpellData.Behavior.GROUND_ZONE, 0.5, 8.0)
	s3.radius_u = 2.5
	s3.duration = 5.0
	s3.tick = 0.5
	s3.range_u = 7.0
	s3.trigger_range_u = 6.0
	s3.proc_coef = 0.3 # 10 ticks par lancement : sinon chaque tick relance les procs
	s3.color = Color(0.6, 0.3, 0.2)

	var s4 := _spell(&"brasier", "Brasier", 4, SpellData.Behavior.NOVA, BRASIER_COEF, 20.0)
	s4.radius_u = 6.0
	s4.trigger_range_u = 4.0
	s4.color = Color(1.0, 0.2, 0.05)

	c.spells = [s1, s2, s3, s4]
	return c



# --- Passif expliqué (infobulle du HUD ; contrat KitResource.passive) ------------------------------------

static func passive_info() -> Dictionary:
	# Ardent n'a ni jauge ni palier : son « passif » est son rythme de braises (chiffres lus dans variant_a).
	var kit := variant_a().spells
	var s1: SpellData = kit[0]
	var cds: Array[String] = []
	for i in [1, 2, 3]:
		cds.append("%s %s s" % [(kit[i] as SpellData).display_name, KitResource.fmt((kit[i] as SpellData).base_cooldown)])
	return KitResource.passive("Braise", &"braise",
		"Ardent n'a pas de jauge à gérer : aucune ressource, aucun palier. Il vit de ses braises. Le sort 1 (%s) tire tout seul toutes les %s s et traverse %d monstres sur %s u ; la Nova, les Cendres et le Brasier se lancent sur recharge." % [
			s1.display_name, KitResource.fmt(s1.base_cooldown), s1.pierce + 1, KitResource.fmt(s1.range_u)],
		"", "",
		"recharges %s, ultime Brasier %s s." % [
			", ".join(cds), KitResource.fmt((kit[3] as SpellData).base_cooldown)])
