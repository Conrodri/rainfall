class_name KitResource
extends RefCounted
## Contrat unique de la ressource d'un kit (jauge du HUD, sauvegarde, simulateur d'équilibrage).
## Un kit qui a une ressource expose `func resource_state() -> Dictionary` construit par `KitResource.make()` :
##   id: StringName      identifiant stable (water, gold_power, chain, breath, mottes, limbs)
##   label: String       nom court affiché (« Eau », « Souffle »…)
##   ratio: float        jauge continue : remplissage 0-1 ; avec pastilles : progression de la suivante (recharge)
##   text: String        valeur lisible (« 62 », « +45 % », « 3,5 u ») ; "" = rien
##   pips: int           pastilles discrètes (0 = jauge continue)
##   filled: int         pastilles pleines (pips > 0)
##   color: Color        accent du personnage
##   mark: float         repère sur la jauge (0-1, seuil d'une mécanique) ; < 0 = aucun
##   blocked: bool       ressource inutilisable (essoufflée, bourse vide) : jauge éteinte
##   boost: bool         état exalté (ultime) : jauge qui pulse
## Clés facultatives (Averse, 22/10/2026) :
##   marks: Array        repères secondaires (0-1), plus discrets que `mark`
##   warn: bool          un sort vient d'être refusé faute de ressource : la jauge clignote
##   regen: float        gain par seconde ; rempli par `of()` depuis le hook `kit.resource_regen_per_s()` s'il existe
## Ardent (pas de kit) et les kits sans ressource n'exposent rien : `of()` rend {}.


static func make(id: StringName, label: String, ratio: float, color: Color, opts: Dictionary = {}) -> Dictionary:
	var d := {
		"id": id, "label": label, "ratio": clampf(ratio, 0.0, 1.0), "color": color,
		"text": "", "pips": 0, "filled": 0, "mark": -1.0, "blocked": false, "boost": false,
	}
	for k: String in opts:
		d[k] = opts[k]
	return d


## Niveau 0-1 de la ressource, quelle que soit sa forme (pastilles pleines / total, sinon ratio) : simulateur.
static func level(d: Dictionary) -> float:
	var pips := int(d.get("pips", 0))
	if pips > 0:
		return clampf(float(d.get("filled", 0)) / pips, 0.0, 1.0)
	return float(d.get("ratio", 0.0))


## Ressource du kit d'un joueur (Node « player » avec `kit`), ou {} s'il n'en a pas.
static func of(player: Object) -> Dictionary:
	if player == null or not is_instance_valid(player) or not (&"kit" in player):
		return {}
	var kit: Variant = player.get(&"kit")
	if kit == null or not is_instance_valid(kit) or not (kit as Object).has_method(&"resource_state"):
		return {}
	var d: Variant = kit.resource_state()
	if not (d is Dictionary):
		return {}
	if (kit as Object).has_method(&"resource_regen_per_s"):
		d["regen"] = float(kit.resource_regen_per_s())
	return d


# --- Passif / ressource expliqué (infobulle du HUD, 23/10/2026) --------------------------------------
## Contrat : chaque kit expose `static func passive_info() -> Dictionary` construit par `KitResource.passive()`,
## lu par PassiveBadge.info_for(id). Les chiffres sont lus dans les constantes du kit (aucune valeur dupliquée) ;
## les kits sans kit_script (Ardent) passent par ArdentKit.passive_info().

## Nombre à la française : « 2,2 », « 12 » (une décimale au plus, zéro final retiré).
static func fmt(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return ("%.1f" % v).replace(".", ",")


static func pct(v: float) -> String:
	return "%s %%" % fmt(v * 100.0)


## {name, icon, intro, fills, drains, tiers, desc, hud} : `desc` assemble les blocs non vides.
## `hud` faux = pas d'icône au HUD (personnage sans passif ni ressource), l'infobulle reste lisible ailleurs.
static func passive(pname: String, icon: StringName, intro: String, fills: String, drains: String, tiers: String, hud := true) -> Dictionary:
	var parts: Array[String] = []
	if intro != "":
		parts.append(intro)
	if fills != "":
		parts.append("Remplit : " + fills)
	if drains != "":
		parts.append("Vide : " + drains)
	if tiers != "":
		parts.append("Effet : " + tiers)
	return {"name": pname, "icon": icon, "intro": intro, "fills": fills, "drains": drains, "tiers": tiers,
		"desc": "\n".join(parts), "hud": hud}
