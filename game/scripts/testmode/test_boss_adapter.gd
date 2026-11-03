class_name TestBossAdapter
extends RefCounted
## Mode test : adaptateur « forcer une attaque de boss » pour les bulles de test (TestBubbles). Les cerveaux de boss n'ont
## pas d'API commune : chacun expose des `_start_*` aux paramètres différents. L'adaptateur lit le script du cerveau
## (méthodes, constantes SPELL_CYCLE / Spell / S) et remplit les arguments par leur nom (dir, ppos, player, has_los…).
## Tolérant : un boss ou une attaque non supportés donnent une entrée grisée (ok = false), jamais d'erreur.
## À RETIRER OU MASQUER AVANT LA SORTIE avec le mode test.

## Attaques directes par cerveau (nom de fichier sans extension) : [libellé, méthode]. Les sorts à cycle sont déduits du script.
const AUTOS := {
	"cerf_brain": [["tir", "_start_auto"], ["coup", "_start_gore"]],
	"crane_brain": [["crochet", "_start_hook"]],
	"crystal_mother_brain": [["éclat", "_start_shard"]],
	"deep_eel_brain": [["morsure", "_start_bite"], ["émerg.", "_start_emergence"], ["décharge", "_start_discharge"], ["eau vive", "_start_live_water"]],
	"drowned_idol_brain": [["paume", "_start_palm"]],
	"eclusier_brain": [["vanne", "_start_gate"]],
	"flood_gunner_brain": [["culasse", "_start_breech"], ["mine", "_start_plant"], ["salve", "_start_volley"], ["obus", "_start_shell"]],
	"hermit_cedar_brain": [["branche", "_start_branch"], ["vrille", "_start_tendril"]],
	"jar_bearer_brain": [["jet", "_start_throw"]],
	"ox_herder_brain": [["cornes", "_start_horns"]],
	"rain_sower_brain": [["fouet", "_start_lash"], ["tourb.", "_start_whirl"]],
	"recluse_brain": [["bâton", "_start_staff"]],
	"salt_king_brain": [["auto", "_start_auto"], ["cortège", "_start_procession"], ["stèles", "_start_steles"], ["édit", "_start_edict"]],
	"smelter_brain": [["louche", "_start_ladle"]],
	"sonneur_brain": [["marteau", "_start_hammer"]],
	"weaver_brain": [["morsure", "_start_bite"], ["fils", "_start_threads"]],
}
## Cerveaux dont les sorts se lancent par debug_cast(sp, ppos) (un sort par valeur de l'enum Spell).
const DEBUG_CAST := ["drowned_idol_brain"]
const IDLE_STATES := ["CHASE", "SWIM"]


## Boss et mini-boss vivants avec un cerveau, du plus proche du joueur au plus loin.
static func bosses(tree: SceneTree) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for n in tree.get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e != null and e.active and e.is_boss and e.brain != null and not e.test_dummy:
			out.append(e)
	var p := TestTools.player_of(tree)
	if p != null:
		out.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.global_position.distance_squared_to(p.global_position) < b.global_position.distance_squared_to(p.global_position))
	return out


static func brain_name(boss: Enemy) -> String:
	if boss == null or boss.brain == null or boss.brain.get_script() == null:
		return ""
	return (boss.brain.get_script() as Script).resource_path.get_file().get_basename()


## Nom affiché du boss.
static func title(boss: Enemy) -> String:
	var id := String(boss.boss_id())
	var names := TestTools._boss_names()
	return String(names.get(id, id if id != "" else brain_name(boss)))


## Signature de ce qui change la liste des attaques (boss, phase) : les bulles se reconstruisent si elle bouge.
static func signature(boss: Enemy) -> String:
	if boss == null or boss.brain == null:
		return ""
	return "%s:%d:%d" % [brain_name(boss), boss.get_instance_id(), int(boss.brain.get("phase"))]


## Attaques proposées : [{id, label, tip, ok, kind, ...}].
static func attacks(boss: Enemy) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if boss == null or boss.brain == null:
		return out
	var br: Object = boss.brain
	var bn := brain_name(boss)
	if br is MiniBossBrain:
		for p in (br as MiniBossBrain).patterns():
			var pid := String((p as Dictionary).get("id", ""))
			var auto := bool((p as Dictionary).get("auto", false))
			out.append({"id": "force:%s" % pid, "label": pid.substr(0, 7), "tip": "%s (%s)" % [pid, "auto" if auto else "sort"], "ok": true, "kind": &"force", "pattern": StringName(pid)})
		_add_phases(out, br)
		return out
	var consts: Dictionary = (br.get_script() as Script).get_script_constant_map()
	var auto_list: Array = AUTOS.get(bn, [])
	for a in auto_list:
		var m := String(a[1])
		out.append({"id": "auto:%s" % m, "label": a[0], "tip": "Attaque : %s (%s)" % [a[0], m], "ok": br.has_method(m), "kind": &"method", "method": m})
	if bn in DEBUG_CAST and br.has_method(&"debug_cast") and consts.get("Spell") is Dictionary:
		var spell_enum: Dictionary = consts["Spell"]
		for k in spell_enum:
			out.append({"id": "dbg:%s" % k, "label": _short(String(k)), "tip": "Sort : %s" % k, "ok": true, "kind": &"debug", "spell": int(spell_enum[k])})
	elif br.has_method(&"_start_spell"):
		var names := _spell_names(br, consts)
		for i in names.size():
			out.append({"id": "spell:%d" % i, "label": names[i], "tip": "Sort %s (cycle %d)" % [names[i], i], "ok": true, "kind": &"spell", "cycle": i})
	_add_phases(out, br)
	return out


static func _spell_names(br: Object, consts: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var ph := maxi(int(br.get("phase")), 1)
	var enum_names := {}
	if consts.get("Spell") is Dictionary:
		for k in (consts["Spell"] as Dictionary):
			enum_names[int((consts["Spell"] as Dictionary)[k])] = String(k)
	if consts.get("SPELL_CYCLE") is Array:
		var cyc: Array = consts["SPELL_CYCLE"]
		var cur: Variant = cyc[clampi(ph - 1, 0, cyc.size() - 1)]
		if cur is Array:
			for i in (cur as Array).size():
				out.append(_short(String(enum_names.get(int((cur as Array)[i]), "sort %d" % (i + 1)))))
			return out
	out.append("A")
	out.append("B")
	return out


static func _short(s: String) -> String:
	return s.capitalize().substr(0, 7)


static func _add_phases(out: Array[Dictionary], br: Object) -> void:
	var ph := int(br.get("phase"))
	if br.has_method(&"_enter_phase"):
		for n in [2, 3]:
			if n > ph:
				out.append({"id": "phase:%d" % n, "label": "P%d" % n, "tip": "Passer à la phase %d" % n, "ok": true, "kind": &"phase", "phase": n})
	elif br.has_method(&"_enter_phase2") and ph < 2:
		out.append({"id": "phase:2", "label": "P2", "tip": "Passer à la phase 2", "ok": true, "kind": &"phase", "phase": 2})


## Force l'attaque. Retourne vrai si elle a été lancée. `ppos` : position du joueur.
static func fire(boss: Enemy, attack: Dictionary, ppos: Vector2) -> bool:
	if boss == null or not boss.active or boss.brain == null or not bool(attack.get("ok", false)):
		return false
	var br: Object = boss.brain
	var kind: StringName = attack.get("kind", &"")
	if kind == &"phase":
		if br.has_method(&"_enter_phase"):
			br.call(&"_enter_phase", int(attack.phase))
		elif br.has_method(&"_enter_phase2"):
			br.call(&"_enter_phase2")
		return true
	if kind == &"force":
		br.call(&"force", attack.pattern)
		return true
	if not _make_idle(boss, br):
		return false
	var dir := (ppos - boss.position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	match kind:
		&"debug":
			br.call(&"debug_cast", int(attack.spell), ppos)
			return true
		&"spell":
			br.set(&"_cycle", int(attack.cycle))
			return _call_by_names(br, &"_start_spell", dir, ppos, boss)
		&"method":
			return _call_by_names(br, StringName(attack.method), dir, ppos, boss)
	return false


## Remet le cerveau au repos (sans toucher à ses objets) pour qu'une attaque forcée parte proprement. Faux = impossible (intro...).
static func _make_idle(boss: Enemy, br: Object) -> bool:
	var consts: Dictionary = (br.get_script() as Script).get_script_constant_map()
	var s_enum: Variant = consts.get("S")
	if not (s_enum is Dictionary):
		return false
	var idle := -1
	for nm in IDLE_STATES:
		if (s_enum as Dictionary).has(nm):
			idle = int((s_enum as Dictionary)[nm])
			break
	if idle < 0:
		return false
	if (s_enum as Dictionary).has("INTRO") and int(br.get("state")) == int((s_enum as Dictionary)["INTRO"]):
		return false
	if int(br.get("state")) != idle:
		boss.telegraph.hide_telegraph()
		br.set(&"state", idle)
	return true


## Appelle `method` en remplissant ses paramètres requis par leur nom ; faux si un nom est inconnu.
static func _call_by_names(br: Object, method: StringName, dir: Vector2, ppos: Vector2, boss: Enemy) -> bool:
	if not br.has_method(method):
		return false
	var info: Dictionary = {}
	for m in (br.get_script() as Script).get_script_method_list():
		if StringName(m["name"]) == method:
			info = m
			break
	if info.is_empty():
		return false
	var args: Array = []
	var margs: Array = info.get("args", [])
	var required := margs.size() - (info.get("default_args", []) as Array).size()
	for i in required:
		match String(margs[i]["name"]):
			"dir", "to_p", "p_dir":
				args.append(dir)
			"ppos", "target":
				args.append(ppos)
			"player":
				args.append(TestTools.player_of(boss.get_tree()))
			"has_los":
				args.append(true)
			"windup":
				args.append(1.0)
			_:
				return false
	br.callv(method, args)
	return true
