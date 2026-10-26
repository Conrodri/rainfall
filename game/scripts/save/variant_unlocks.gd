extends RefCounted
## Moteur de déblocage des variantes de sorts (sans class_name : `preload("res://scripts/save/variant_unlocks.gd")`).
## Règles lues dans data/characters.json, clé `unlock_rule` d'une variante (game/CONTRACTS.md « Variantes de sorts ») :
##   {"type": "win_with"[, "character": id|"any"][, "mode": "facile"|"moyen"|"difficile"]}
##       gagner une run avec le personnage (défaut : le propriétaire de la variante), mode minimal facultatif
##       (victoire = boss final abattu, run terminée ; c'est aussi la règle des skins, voir Skins) ;
##   {"type": "counter", "key": "<clé>", "value": N}
##       compteur cumulé du profil `stats[<clé>]` >= N (Profile.add_stat, RunState.add_counter pendant la run) ;
##   {"type": "boss_kill", "boss": "<id>"|"any"[, "character": …][, "mode": …]}
##       tuer ce boss d'étage pendant une run (« any » = n'importe quel boss d'étage) ;
##   {"type": "floor_reached", "floor": N[, "character": …][, "mode": …]}
##       atteindre l'étage N (RunState.stage en fin de run, victoire ou non).
## Sans `unlock_rule`, la variante de l'emplacement « auto » (sort 1) se débloque par {"type": "win_with"} ;
## les autres restent verrouillées (seul le mode test RAINFALL_UNLOCK_ALL_VARIANTS les montre).
## Type inconnu : warning, jamais débloquée, jamais de plantage.

const RULE_TYPES: Array[String] = ["win_with", "counter", "boss_kill", "floor_reached"]
const MODE_RANK := {"facile": 0, "moyen": 1, "difficile": 2}
const MODE_NAMES := {"facile": "Facile", "moyen": "Moyen", "difficile": "Difficile"}
static var _warned := {} ## types inconnus déjà signalés (un warning par type)


## Clé de déblocage d'une variante : `unlock_key`, sinon "spell:<id>".
static func key_of(variant: Dictionary) -> StringName:
	var k := str(variant.get("unlock_key", ""))
	return StringName(k if k != "" else "spell:" + str(variant.get("id", "")))


## Règle effective d'une variante (voir en-tête) ; {} = aucune règle (jamais débloquée automatiquement).
static func rule_of(spell: Dictionary, variant: Dictionary) -> Dictionary:
	var r: Variant = variant.get("unlock_rule")
	if r is Dictionary and not (r as Dictionary).is_empty():
		return r
	if str(spell.get("slot", "")) == "auto":
		return {"type": "win_with"}
	return {}


## Toutes les variantes du roster : [{character, slot (1-4), spell, variant, key, rule}].
static func all_variants(characters: Array) -> Array:
	var out: Array = []
	for c in characters:
		if not (c is Dictionary):
			continue
		var spells: Array = c.get("spells", []) if c.get("spells") is Array else []
		for i in spells.size():
			var sp: Variant = spells[i]
			if not (sp is Dictionary):
				continue
			for v in (sp as Dictionary).get("variants", []):
				if v is Dictionary and str(v.get("id", "")) != "":
					out.append({"character": c, "slot": i + 1, "spell": sp, "variant": v,
						"key": key_of(v), "rule": rule_of(sp, v)})
	return out


## Clés "spell:<id>" dont la règle est remplie par la run `result` et pas encore possédées.
## `result` : {victory, mode, character, stage, bosses_killed: [{id, floor_boss}]} ; les compteurs du profil
## (`stats`) doivent déjà inclure la run (Profile.add_run_result s'en charge avant l'appel).
static func evaluate(profile: Object, characters: Array, result: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var owned: Array = profile.get("unlocked_spells") if profile != null and "unlocked_spells" in profile else []
	for e in all_variants(characters):
		var key: StringName = e.key
		if not String(key).begins_with("spell:") or owned.has(StringName(String(key).substr(6))) or out.has(key):
			continue
		if rule_met(e.rule, StringName(str(e.character.get("id", ""))), profile, result):
			out.append(key)
	return out


## Vrai si la règle est remplie (owner = personnage propriétaire de la variante).
static func rule_met(rule: Dictionary, owner: StringName, profile: Object, result: Dictionary) -> bool:
	if rule.is_empty():
		return false
	var t := str(rule.get("type", ""))
	match t:
		"counter":
			var key := str(rule.get("key", ""))
			return key != "" and _stat(profile, key) >= float(rule.get("value", INF))
		"win_with":
			return bool(result.get("victory", false)) and _run_matches(rule, owner, result)
		"boss_kill":
			if not _run_matches(rule, owner, result):
				return false
			var want := str(rule.get("boss", "any"))
			for b in result.get("bosses_killed", []):
				var bid := str(b.get("id", "")) if b is Dictionary else str(b)
				var floor_boss := bool(b.get("floor_boss", true)) if b is Dictionary else true
				if (want == "any" and floor_boss) or bid == want:
					return true
			return false
		"floor_reached":
			return _run_matches(rule, owner, result) and int(result.get("stage", 0)) >= int(rule.get("floor", 999))
	if not _warned.has(t):
		_warned[t] = true
		push_warning("VariantUnlocks : type de règle inconnu « %s »" % t)
	return false


## Filtres communs : personnage (défaut : propriétaire ; "any" = tous) et mode minimal.
static func _run_matches(rule: Dictionary, owner: StringName, result: Dictionary) -> bool:
	var who := str(rule.get("character", String(owner)))
	if who != "any" and who != str(result.get("character", "")):
		return false
	var m := str(rule.get("mode", ""))
	if m != "" and int(MODE_RANK.get(str(result.get("mode", "")), -1)) < int(MODE_RANK.get(m, 0)):
		return false
	return true


static func _stat(profile: Object, key: String) -> float:
	if profile == null:
		return 0.0
	if profile.has_method(&"stat"):
		return float(profile.call(&"stat", key))
	var st: Variant = profile.get("stats") if "stats" in profile else null
	var v: Variant = (st as Dictionary).get(key, 0.0) if st is Dictionary else 0.0
	return float(v) if (v is float or v is int) else 0.0


## Avancement d'une règle à compteur : {value, target} ; {} pour les autres types.
static func progress(profile: Object, spell: Dictionary, variant: Dictionary) -> Dictionary:
	var r := rule_of(spell, variant)
	if str(r.get("type", "")) != "counter":
		return {}
	return {"value": _stat(profile, str(r.get("key", ""))), "target": float(r.get("value", 0.0))}


## Texte de quête d'une variante : `unlock_text`, sinon déduit de la règle (jamais un id brut).
static func quest_text(character: Dictionary, spell: Dictionary, variant: Dictionary) -> String:
	var txt := str(variant.get("unlock_text", ""))
	if txt != "":
		return txt
	var r := rule_of(spell, variant)
	var who := str(r.get("character", ""))
	var cname := "n'importe quel personnage" if who == "any" else str(character.get("name", "ce personnage"))
	var mode := str(r.get("mode", ""))
	var mtxt := (" en mode %s ou plus dur" % MODE_NAMES.get(mode, mode)) if mode != "" else ""
	match str(r.get("type", "")):
		"win_with":
			return "Gagner une run avec %s%s." % [cname, mtxt]
		"counter":
			return "Objectif cumulé : %s." % str(int(float(r.get("value", 0))))
		"boss_kill":
			return "Vaincre un boss d'étage avec %s%s." % [cname, mtxt]
		"floor_reached":
			return "Atteindre l'étage %d avec %s%s." % [int(r.get("floor", 0)), cname, mtxt]
	return "Déblocage à venir."
