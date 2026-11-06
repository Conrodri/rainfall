class_name StationState
extends RefCounted
## État et règles d'un atelier (Fondoir, Matrice, Alambic, Enclume de bronze ; docs/Ateliers_Chiffres.md §3-6,
## docs/Propositions_Boucle_Interactions.md §2.1-2.4). Aucune interface : le nœud `Station` et le panneau
## `ItemPicker` l'appellent ; les tests le pilotent directement. Les objets passent par RunState (add_item /
## remove_item) puis `apply_items` recalcule les stats du joueur.
## Chaque opération renvoie {ok: bool, reason: String, ...} ; `reason` est un texte joueur (refus écrit en toutes lettres).

const KINDS: Array[StringName] = [&"fondoir", &"matrice", &"alambic", &"enclume"]
const QUALITY_ORDER: Array[StringName] = [&"commun", &"peu_commun", &"rare", &"legendaire"]
const QUALITY_NAMES := {&"commun": "commun", &"peu_commun": "peu commun", &"rare": "rare", &"legendaire": "légendaire"}
## Teinte de la scorie : blanc / vert / rouge (docs/Propositions_Boucle_Interactions.md §2.2).
const SCRAP_NAMES := {&"commun": "blanche", &"peu_commun": "verte", &"rare": "rouge"}
const SCRAP_COLORS := {&"commun": Color(0.92, 0.92, 0.94), &"peu_commun": Color(0.4, 0.85, 0.45), &"rare": Color(0.9, 0.3, 0.25)}
const PHENIX_SPECIAL := "phenix"

var kind: StringName = &"fondoir"
var stage := 1
var uses_total := 0
var item_id: StringName = &"" ## Matrice : objet affiché (tiré au début de l'étage)
var quality: StringName = &"" ## Matrice : qualité de l'objet affiché
## Coop (étape 2, lot 3) : un atelier sert chaque joueur séparément. `actor` = joueur qui l'utilise (posé par Station avant
## chaque opération ; null = joueur 1) ; ses objets, scories et or sont ceux de CE joueur, et le quota d'usages est
## PAR JOUEUR (`_uses` : emplacement -> usages faits). En solo : un seul acteur, comportement inchangé.
var actor: PlayerState = null
var _uses := {}
## Usages faits par l'acteur courant (écrire = compter un usage de l'acteur).
var uses_done: int:
	get: return int(_uses.get(_slot(), 0))
	set(v): _uses[_slot()] = v


func _slot() -> int:
	return actor.slot if actor != null else 0


## PlayerState de l'acteur (joueur 1 par défaut).
func _ps() -> PlayerState:
	return actor if actor != null else RunState.local()


## Lie l'atelier au joueur qui l'utilise (PlayerState du registre).
func bind(st: PlayerState) -> void:
	actor = st


static func _st(st: PlayerState) -> PlayerState:
	return st if st != null else RunState.local()


static func make(p_kind: StringName, p_stage: int) -> StationState:
	var s := StationState.new()
	s.kind = p_kind
	s.stage = p_stage
	match p_kind:
		&"fondoir":
			s.uses_total = Balance.FONDOIR_USES
		&"matrice":
			s.uses_total = Balance.MATRICE_USES
			s.draw_matrice()
		&"alambic":
			s.uses_total = Balance.ALAMBIC_USES
		&"enclume":
			s.uses_total = Balance.ENCLUME_USES
	return s


func uses_left() -> int:
	return maxi(uses_total - uses_done, 0)


func exhausted() -> bool:
	return uses_left() <= 0


func to_dict() -> Dictionary:
	var d := {"kind": String(kind), "stage": stage, "uses_total": uses_total, "uses_done": int(_uses.get(0, 0)),
		"item": String(item_id), "quality": String(quality)}
	var by := {}
	for k in _uses:
		if int(k) != 0:
			by[str(k)] = int(_uses[k])
	if not by.is_empty():
		d["uses_by"] = by
	return d


static func from_dict(d: Dictionary) -> StationState:
	var s := StationState.new()
	s.kind = StringName(str(d.get("kind", "fondoir")))
	s.stage = int(d.get("stage", 1))
	s.uses_total = int(d.get("uses_total", 0))
	s._uses = {0: int(d.get("uses_done", 0))}
	if d.get("uses_by") is Dictionary:
		for k in d["uses_by"]:
			s._uses[int(str(k))] = int((d["uses_by"] as Dictionary)[k])
	s.item_id = StringName(str(d.get("item", "")))
	s.quality = StringName(str(d.get("quality", "")))
	return s


# --- Outils communs -----------------------------------------------------------------------------

static func quality_of(id: StringName) -> StringName:
	return StringName(str(ItemDB.get_item(id).get("quality", "")))


static func tags_of(id: StringName) -> Array:
	return ItemDB.get_item(id).get("tags", [])


static func is_copy_excluded(id: StringName) -> bool:
	return Balance.STATION_COPY_EXCLUDED.has(id) or ItemDB.is_craft_only(id) # un objet forgé ne se copie pas


static func is_phenix(id: StringName) -> bool:
	return str(ItemDB.get_item(id).get("special", "")) == PHENIX_SPECIAL


## Exemplaires donnables / fondables : un Phénix consommé (compteur phenix_used du joueur) ne compte plus.
static func spendable_stacks(id: StringName, st: PlayerState = null) -> int:
	if ItemDB.is_craft_only(id):
		return 0 # objet forgé : ni fondu, ni donné, ni ingrédient
	var ps := _st(st)
	var n := ps.stacks(id)
	if is_phenix(id):
		n = mini(n, maxi(ps.stacks(id) - int(ps.counters.get(ItemEffects.COUNTER_PHENIX, 0.0)), 0))
	return n


## Vrai si l'objet n'apporterait plus rien (toutes ses stats déjà au plafond de Balance.ITEM_BONUS_CAPS).
static func is_capped(id: StringName, st: PlayerState = null) -> bool:
	var it := ItemDB.get_item(id)
	var stats: Dictionary = it.get("stats", {})
	if stats.is_empty() or not (it.get("procs", []) as Array).is_empty() or it.get("special") != null:
		return false
	var cur := ItemStats.compute(_st(st).items)
	for key in stats:
		if not Balance.ITEM_BONUS_CAPS.has(key):
			return false
		if float(cur.get(key, 0.0)) < float(Balance.ITEM_BONUS_CAPS[key]) - 0.0001:
			return false
	return true


## Texte « tag Or » etc. : tags de l'objet séparés par des espaces.
static func tag_line(id: StringName) -> String:
	var out: Array[String] = []
	for t in tags_of(id):
		out.append("[%s]" % str(t))
	return " ".join(out)


## +1 exemplaire (chemin officiel) puis recalcul des stats du joueur.
static func give_item(tree: SceneTree, id: StringName, st: PlayerState = null) -> void:
	_st(st).add_item(id)
	apply_items(tree, st)


static func take_item(tree: SceneTree, id: StringName, st: PlayerState = null) -> bool:
	var ok := _st(st).remove_item(id)
	if ok:
		apply_items(tree, st)
	return ok


## Recalcule les stats du joueur concerné (son nœud du registre, sinon le premier du groupe `player`).
static func apply_items(tree: SceneTree, st: PlayerState = null) -> void:
	if tree == null:
		return
	var ps := _st(st)
	var player: Node = Players.by_id(ps.slot)
	if player == null:
		player = tree.get_first_node_in_group(&"player")
	if player != null and player.has_method(&"apply_stats"):
		player.apply_stats(ItemStats.compute(ps.items))


func _finish(verb: StringName, given: Array, received: Array, gold: float) -> void:
	uses_done += 1
	_ps().add_counter("station.%s_uses" % kind)
	Events.station_used.emit(kind, verb, given, received, gold)


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


## Prix de référence P de l'étage courant (D figé au début de l'étage).
static func price_p() -> float:
	return Balance.station_price_p(RunState.floor_start_d, RunState.stage)


## Ensemble des objets possédés (id -> exemplaires) triés par qualité puis nom, qualité dans `qualities`.
static func owned_of(qualities: Array, st: PlayerState = null) -> Array[StringName]:
	var out: Array[StringName] = []
	var items := _st(st).items
	for id in items:
		if int(items[id]) > 0 and qualities.has(quality_of(StringName(id))) and not ItemDB.is_craft_only(id):
			out.append(StringName(id))
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		var qa := QUALITY_ORDER.find(quality_of(a))
		var qb := QUALITY_ORDER.find(quality_of(b))
		if qa != qb:
			return qa < qb
		return str(ItemDB.get_item(a).get("name", a)) < str(ItemDB.get_item(b).get("name", b)))
	return out


# --- Fondoir ------------------------------------------------------------------------------------

static func refund_gold(q: StringName) -> float:
	return Balance.fondoir_refund(q, RunState.floor_start_d, RunState.stage)


## Raison de refus d'une fonte de `id` ("" = permise). Légendaires, objets absents et Phénix consommé refusés.
func melt_reason(id: StringName) -> String:
	if kind != &"fondoir":
		return "Pas un Fondoir"
	if exhausted():
		return "Fondoir épuisé"
	var q := quality_of(id)
	if not Balance.FONDOIR_REFUND_P.has(q):
		return "Les légendaires ne fondent pas"
	if _ps().stacks(id) <= 0:
		return "Objet non possédé"
	if spendable_stacks(id, _ps()) <= 0:
		return "Phénix déjà consommé"
	if _ps().scrap_total() >= Balance.SCRAP_CAP:
		return "Scories pleines (%d/%d)" % [_ps().scrap_total(), Balance.SCRAP_CAP]
	return ""


## Fond un exemplaire : -1 objet, +1 scorie de la qualité, + remboursement en or.
func melt(tree: SceneTree, id: StringName) -> Dictionary:
	var why := melt_reason(id)
	if why != "":
		return _fail(why)
	var q := quality_of(id)
	var gold := refund_gold(q)
	take_item(tree, id, _ps())
	_ps().add_scrap(q)
	_ps().add_gold(gold)
	_finish(&"fondre", [id], [StringName("scorie_%s" % q)], gold)
	return {"ok": true, "reason": "", "gold": gold, "scrap": q}


# --- Matrice ------------------------------------------------------------------------------------

## Tirage de l'objet affiché, seedé (graine de run, étage) : la sauvegarde le conserve. Qualité d'après
## Balance.MATRICE_QUALITY_TABLE (ligne de l'étage, bornée à 2-4), jamais légendaire, jamais un objet exclu des
## copies ni possédé à MATRICE_MAX_OWNED exemplaires ou plus ; tags du build x MATRICE_TAG_WEIGHT.
func draw_matrice(salt: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([RunState.run_seed, "matrice", stage]) if salt == 0 else hash([RunState.run_seed, "matrice", stage, salt])
	var table: Dictionary = Balance.MATRICE_QUALITY_TABLE[clampi(stage, 2, 4)]
	var total := 0
	for q in QUALITY_ORDER:
		total += int(table.get(q, 0))
	var roll := rng.randi_range(1, maxi(total, 1))
	var picked: StringName = &"commun"
	var acc := 0
	for q in QUALITY_ORDER:
		acc += int(table.get(q, 0))
		if int(table.get(q, 0)) > 0 and roll <= acc:
			picked = q
			break
	# repli : qualité sans objet admissible -> plus basse la plus proche, puis plus haute (jamais légendaire)
	var order: Array[StringName] = []
	var base := QUALITY_ORDER.find(picked)
	for i in range(base, -1, -1):
		order.append(QUALITY_ORDER[i])
	for i in range(base + 1, 3):
		order.append(QUALITY_ORDER[i])
	for q in order:
		var pool := matrice_pool(q)
		if pool.is_empty():
			continue
		quality = q
		item_id = _weighted_pick(pool, rng)
		return


## Objets admissibles à l'affichage pour la qualité (débloqués, hors copies exclues, sous le plafond de possession).
static func matrice_pool(q: StringName, st: PlayerState = null) -> Array:
	var out: Array = []
	for id in ItemUnlocks.filter_unlocked(ItemDB.ids_of_quality(q)):
		var sid := StringName(id)
		if is_copy_excluded(sid) or _st(st).stacks(sid) >= Balance.MATRICE_MAX_OWNED:
			continue
		out.append(id)
	return out


func _weighted_pick(pool: Array, rng: RandomNumberGenerator) -> StringName:
	var tags := LootRoller.build_tags(_ps().items)
	var ws: Array[float] = []
	var total := 0.0
	for id in pool:
		var w := 1.0
		for t in tags_of(StringName(id)):
			if tags.has(str(t)):
				w = Balance.MATRICE_TAG_WEIGHT
				break
		ws.append(w)
		total += w
	var r := rng.randf() * total
	for i in pool.size():
		r -= ws[i]
		if r < 0.0:
			return StringName(pool[i])
	return StringName(pool[pool.size() - 1])


## Note de la carte si l'objet affiché est déjà au plafond de stats du build ("" sinon).
func matrice_note() -> String:
	return "plafond atteint" if item_id != &"" and is_capped(item_id, _ps()) else ""


func forge_scrap_reason() -> String:
	if kind != &"matrice":
		return "Pas une Matrice"
	if exhausted():
		return "Matrice épuisée"
	if item_id == &"":
		return "Aucun objet à forger"
	if _ps().scrap_of(quality) <= 0:
		return "Il faut 1 scorie %s ou 1 objet %s" % [SCRAP_NAMES.get(quality, ""), QUALITY_NAMES.get(quality, "")]
	return ""


## Raison de refus de payer la forge avec l'objet `id` ("" = permis).
func forge_item_reason(id: StringName) -> String:
	if kind != &"matrice":
		return "Pas une Matrice"
	if exhausted():
		return "Matrice épuisée"
	if item_id == &"":
		return "Aucun objet à forger"
	if _ps().stacks(id) <= 0:
		return "Objet non possédé"
	if quality_of(id) != quality:
		return "Il faut un objet %s" % QUALITY_NAMES.get(quality, "")
	if spendable_stacks(id, _ps()) <= 0:
		return "Phénix déjà consommé"
	return ""


## Forge l'objet affiché. `pay` : {"scrap": true} ou {"item": id}. Les scories passent avant les objets.
func forge(tree: SceneTree, pay: Dictionary) -> Dictionary:
	var given: Array = []
	if bool(pay.get("scrap", false)):
		var why := forge_scrap_reason()
		if why != "":
			return _fail(why)
		_ps().spend_scrap(quality)
		given = [StringName("scorie_%s" % quality)]
	else:
		var id := StringName(str(pay.get("item", "")))
		var why2 := forge_item_reason(id)
		if why2 != "":
			return _fail(why2)
		take_item(tree, id, _ps())
		given = [id]
	give_item(tree, item_id, _ps())
	_finish(&"forger", given, [item_id], 0.0)
	return {"ok": true, "reason": "", "item": item_id}


# --- Alambic ------------------------------------------------------------------------------------

## Raison de refus de distiller les objets `ids` (un id par exemplaire donné ; "" = permis).
func distill_reason(ids: Array) -> String:
	if kind != &"alambic":
		return "Pas un Alambic"
	if exhausted():
		return "Alambic épuisé"
	if ids.size() != Balance.ALAMBIC_INPUT:
		return "Il faut %d objets (%d/%d)" % [Balance.ALAMBIC_INPUT, ids.size(), Balance.ALAMBIC_INPUT]
	var counts := {}
	var q0: StringName = &""
	for raw in ids:
		var id := StringName(str(raw))
		counts[id] = int(counts.get(id, 0)) + 1
		if int(counts[id]) > spendable_stacks(id, _ps()):
			if _ps().stacks(id) <= 0:
				return "Objet non possédé"
			return "Phénix déjà consommé" if is_phenix(id) else "Pas assez d'exemplaires"
		var q := quality_of(id)
		if q0 == &"":
			q0 = q
		elif q != q0:
			return "Il faut 3 objets de même qualité"
	var up := next_quality(q0)
	if up == &"":
		return "Pas de qualité au-dessus"
	if up == &"legendaire" and not Balance.ALAMBIC_ALLOW_LEGENDARY:
		return "Pas de légendaire par l'alambic"
	if result_pool(ids, up, _ps()).is_empty():
		return "Aucun objet possible"
	return ""


static func next_quality(q: StringName) -> StringName:
	var i := QUALITY_ORDER.find(q)
	return QUALITY_ORDER[i + 1] if i >= 0 and i + 1 < QUALITY_ORDER.size() else &""


## Objets de la qualité `up` possibles : débloqués, pas déjà plafonnés, guidés par les tags des objets donnés
## (au moins un tag en commun) ; sans correspondance, tout le tirage de la qualité.
static func result_pool(ids: Array, up: StringName, st: PlayerState = null) -> Array:
	var base: Array = []
	for id in ItemUnlocks.filter_unlocked(ItemDB.ids_of_quality(up)):
		if not is_capped(StringName(id), st):
			base.append(id)
	if not Balance.ALAMBIC_TAG_GUIDED:
		return base
	var given_tags := {}
	for raw in ids:
		for t in tags_of(StringName(str(raw))):
			given_tags[str(t)] = true
	var guided: Array = []
	for id in base:
		for t in tags_of(StringName(id)):
			if given_tags.has(str(t)):
				guided.append(id)
				break
	return guided if not guided.is_empty() else base


func distill(tree: SceneTree, ids: Array, rng: RandomNumberGenerator = null) -> Dictionary:
	var why := distill_reason(ids)
	if why != "":
		return _fail(why)
	var r := rng if rng != null else RunState.rng
	var up := next_quality(quality_of(StringName(str(ids[0]))))
	var pool := result_pool(ids, up, _ps())
	var out := StringName(str(pool[r.randi_range(0, pool.size() - 1)]))
	var given: Array = []
	for raw in ids:
		var id := StringName(str(raw))
		take_item(tree, id, _ps())
		given.append(id)
	give_item(tree, out, _ps())
	_finish(&"distiller", given, [out], 0.0)
	return {"ok": true, "reason": "", "item": out}


# --- Enclume de bronze --------------------------------------------------------------------------

## Multiplicateur de prix des coffres qui s'applique aussi à l'Enclume : Faveur du marchand x présage de prix.
static func price_mult() -> float:
	return ItemEffects.chest_price_mult() * Omens.chest_price_mult()


## Prix du prochain exemplaire forgé de `id` (0 si l'objet n'est pas forgeable).
func enclume_price(id: StringName) -> float:
	return Balance.enclume_price(quality_of(id), uses_done, RunState.floor_start_d, RunState.stage, price_mult(), tags_of(id))


func enclume_reason(id: StringName) -> String:
	if kind != &"enclume":
		return "Pas une Enclume"
	if exhausted():
		return "Enclume épuisée"
	if _ps().stacks(id) <= 0:
		return "Objet non possédé"
	var q := quality_of(id)
	if not Balance.ENCLUME_PRICE_P.has(q):
		return "Les légendaires ne se forgent pas"
	if is_copy_excluded(id):
		return "Cet objet ne se copie pas"
	if is_capped(id, _ps()):
		return "Plafond atteint"
	var price := enclume_price(id)
	if not TestMode.inf_gold and _ps().gold < price:
		return "Il manque %d or" % int(ceil(price - _ps().gold))
	return ""


func forge_copy(tree: SceneTree, id: StringName) -> Dictionary:
	var why := enclume_reason(id)
	if why != "":
		return _fail(why)
	var price := enclume_price(id)
	if not _ps().spend_gold(price):
		return _fail("Il manque %d or" % int(ceil(price - _ps().gold)))
	give_item(tree, id, _ps())
	_finish(&"forger", [], [id], -price)
	return {"ok": true, "reason": "", "gold": -price}
