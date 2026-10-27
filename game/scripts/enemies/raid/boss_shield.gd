class_name BossShield
extends RefCounted
## Bouclier de phase d'un boss façon raid (docs/Design_Boss_Raid.md §1.1). Créé UNE fois par le cerveau du boss
## (`BossShield.create(e)`), armé à chaque transition retenue (`arm(conditions, opts)`), avancé par `tick(delta)`
## dans brain.tick, libéré par `clear()` dans brain.clear().
##
## Déroulé : TRANSITION (`transition_s` 0,9 : boss figé, le cerveau joue `trans_pN` et appelle pace.cancel())
## -> SETUP (`setup_s` 1,2 : les objets de la condition apparaissent, télégraphés) -> ACTIVE (jusqu'à la rupture,
## garde-fou `backstop_s` : 25 s, 20 s si la condition principale est ULTIMATE_HIT) -> BREAKING (`break_s` 0,5,
## éclat) -> EXPOSED (`exposed_s` 2,5, dégâts reçus × `exposed_mult` 1,3, boss sonné) -> IDLE.
## Garde-fou atteint : le bouclier tombe SANS fenêtre (Events.raid_mechanic_failed(boss, &"shield_backstop") : le
## HUD affiche « Le bouclier cède »), aucune autre pénalité. Jamais de blocage.
## Plusieurs conditions : la première remplie gagne (ex. [{kind: &"orbs", count: 3}, {kind: &"timer", s: 25}]).
##
## Duck typing attendu du cerveau (Enemy le lit) : is_invulnerable() -> shield.is_invulnerable() ;
## damage_taken_mult() -> (mult de phase) × shield.damage_taken_mult() ; boss_state_tag() -> shield.state_tag()
## s'il n'est pas vide ; enrage : SoftEnrage.tick(delta, shield.freezes_enrage()).
## Attaques : can_attack() faux pendant transition, mise en place, rupture et fenêtre ; slow_only() vrai sous
## bouclier actif (sauf condition TIMER, où le boss attaque normalement : survivre est l'épreuve) ; le seul sort
## lent permis passe par take_slow_spell() (cadence BOSS_SHIELD_SLOW_SPELL_S).
## Signaux globaux : Events.boss_shield_changed / boss_shield_progress / raid_mechanic_failed.

signal state_changed(state: int)
signal progressed(done: int, total: int)
signal broken(rewarded: bool)

enum State { IDLE, TRANSITION, SETUP, ACTIVE, BREAKING, EXPOSED }

const ORB_FALL_S := 1.0
const SFX_BREAK_GENERIC := &"enemy.raid_shield_break.heavy"
const SFX_HUM := &"enemy.shield_hum.loop"
## Sons d'armement / de rupture par boss (ids de la consigne audio art/tools/audio/_raid_sfx.txt). &"" = pas de son propre
## (le cerveau joue déjà le sien : Canonnier = gunner_shield_up, Roi de sel = crust_*). Surcharge : opts sfx_up / sfx_break
## (ids complets) ou sfx_prefix (-> enemy.<prefix>_shield_up.heavy / _shield_break.heavy) dans arm().
const SFX_BY_BOSS := {
	&"drowned_idol": {"up": &"enemy.idol_shield_up.heavy", "break": &"enemy.idol_shield_break.heavy"},
	&"flood_gunner": {"up": &"", "break": SFX_BREAK_GENERIC},
	&"salt_king": {"up": &"", "break": &""},
}

var boss: Node2D = null
var state := State.IDLE
var conditions: Array[BreakCondition] = []
var winner: BreakCondition = null
var rewarded := false
var by_backstop := false
var armed_count := 0 ## boucliers armés depuis la création (2e transition : conditions plus dures)
var t := 0.0 ## temps dans l'état courant
var active_t := 0.0 ## temps sous bouclier actif (garde-fou)
var transition_s := Balance.BOSS_SHIELD_TRANSITION_S
var setup_s := Balance.BOSS_SHIELD_SETUP_S
var backstop_s := Balance.BOSS_SHIELD_BACKSTOP_S
var break_s := Balance.BOSS_SHIELD_BREAK_S
var exposed_s := Balance.BOSS_SHIELD_EXPOSED_S
var exposed_mult := Balance.BOSS_SHIELD_EXPOSED_MULT
var best_hit := 0.0 ## meilleur coup de sort vu (option « coups lourds » de ULTIMATE_HIT)
var heavy_hits := 0
var cracks := 0 ## fissures visuelles de la bulle (0..3)
var adds: PriorityAdds = null
var objects: Array[Node] = [] ## orbes, points faibles, zones, props posés par la condition
var _slow_t := 0.0
var _caster: Object = null
var _bubble: Node2D = null
var _sfx_up: StringName = &""
var _sfx_break: StringName = &""
var _hum: Dictionary = {}


static func create(p_boss: Node2D) -> BossShield:
	var s := BossShield.new()
	s.boss = p_boss
	s._bind_caster()
	return s


## Faut-il armer un bouclier à ce passage de phase ? (nouvelle phase, et quota BOSS_SHIELDS du boss non atteint)
static func should_arm(prev_phase: int, new_phase: int, armed: int, boss_id: StringName) -> bool:
	return new_phase > prev_phase and armed < Balance.boss_shield_count(boss_id)


## Arme le bouclier. `conds` : Array de dictionnaires (BreakCondition.from_dict). opts : transition_s, setup_s,
## backstop_s, exposed_s, exposed_mult. Refusé (false) si un bouclier est déjà levé.
func arm(conds: Array, opts: Dictionary = {}) -> bool:
	if is_invulnerable() or state == State.BREAKING:
		return false
	_cleanup()
	conditions.clear()
	for d in conds:
		conditions.append(BreakCondition.from_dict(d))
	if conditions.is_empty():
		conditions.append(BreakCondition.from_dict({"kind": BreakCondition.Kind.TIMER, "s": 5.0}))
	transition_s = float(opts.get("transition_s", Balance.BOSS_SHIELD_TRANSITION_S))
	setup_s = float(opts.get("setup_s", Balance.BOSS_SHIELD_SETUP_S))
	var ult := conditions[0].kind == BreakCondition.Kind.ULTIMATE_HIT
	backstop_s = float(opts.get("backstop_s", Balance.BOSS_SHIELD_BACKSTOP_ULT_S if ult else Balance.BOSS_SHIELD_BACKSTOP_S))
	exposed_s = float(opts.get("exposed_s", Balance.BOSS_SHIELD_EXPOSED_S))
	exposed_mult = float(opts.get("exposed_mult", Balance.BOSS_SHIELD_EXPOSED_MULT))
	winner = null
	rewarded = false
	by_backstop = false
	active_t = 0.0
	heavy_hits = 0
	cracks = 0
	armed_count += 1
	_resolve_sfx(opts)
	_set_state(State.TRANSITION)
	_show_bubble()
	_bind_caster()
	Events.boss_shield_changed.emit(boss, true, primary_kind())
	if _sfx_up != &"":
		RaidFx.sfx(_sfx_up, _boss_pos())
	return true


func primary() -> BreakCondition:
	return conditions[0] if not conditions.is_empty() else null


func primary_kind() -> StringName:
	return conditions[0].kind_id() if not conditions.is_empty() else &""


func tick(delta: float) -> void:
	if state == State.IDLE:
		return
	if boss == null or not is_instance_valid(boss) or not bool(boss.get(&"active")):
		clear()
		return
	t += delta
	match state:
		State.TRANSITION:
			if t >= transition_s:
				_set_state(State.SETUP)
				_spawn_objects()
		State.SETUP, State.ACTIVE:
			if state == State.SETUP and t >= setup_s:
				_set_state(State.ACTIVE)
			if state == State.ACTIVE:
				active_t += delta
				for c in conditions:
					if c.kind == BreakCondition.Kind.TIMER:
						c.elapsed += delta
				_slow_t += delta
			for c in conditions:
				if c.is_met():
					_break(c)
					return
			if state == State.ACTIVE and active_t >= backstop_s:
				by_backstop = true
				Events.raid_mechanic_failed.emit(boss, &"shield_backstop")
				_break(null)
		State.BREAKING:
			if t >= break_s:
				_set_state(State.EXPOSED if rewarded else State.IDLE)
		State.EXPOSED:
			if t >= exposed_s:
				_set_state(State.IDLE)


# --- Lecture (cerveau, barre, tests)
func is_invulnerable() -> bool:
	return state == State.TRANSITION or state == State.SETUP or state == State.ACTIVE


func is_exposed() -> bool:
	return state == State.EXPOSED


func is_busy() -> bool:
	return state != State.IDLE


func freezes_enrage() -> bool:
	return is_invulnerable() or state == State.BREAKING


func damage_taken_mult() -> float:
	if is_invulnerable():
		return 0.0
	return exposed_mult if state == State.EXPOSED else 1.0


func can_attack() -> bool:
	return state == State.IDLE or (state == State.ACTIVE and not slow_only())


## Sous bouclier actif, seul un sort lent est permis (sauf condition TIMER principale).
func slow_only() -> bool:
	return state == State.ACTIVE and primary_kind() != &"timer"


## Le sort lent est-il dû ? (consomme l'échéance : au plus un toutes les BOSS_SHIELD_SLOW_SPELL_S)
func take_slow_spell() -> bool:
	if state != State.ACTIVE or _slow_t < Balance.BOSS_SHIELD_SLOW_SPELL_S:
		return false
	_slow_t = 0.0
	return true


## Progrès de la condition la plus avancée (0..1).
func progress() -> float:
	var best := 0.0
	for c in conditions:
		best = maxf(best, c.progress())
	return best


## Étiquette de barre de boss : kind &"shield" (texte de la condition, progress 0..1) ou &"exposed" ; {} sinon.
func state_tag() -> Dictionary:
	match state:
		State.TRANSITION, State.SETUP, State.ACTIVE:
			var c := primary()
			return {"text": c.text() if c != null else "", "color": RaidFx.STEEL, "kind": &"shield", "progress": progress()}
		State.BREAKING:
			return {"text": "LE BOUCLIER CÈDE" if by_backstop else "BOUCLIER BRISÉ", "color": RaidFx.STEEL, "kind": &"shield", "progress": 1.0}
		State.EXPOSED:
			return {"text": "EXPOSÉ — DÉGÂTS +%d %%" % roundi((exposed_mult - 1.0) * 100.0), "color": RaidFx.WARM, "kind": &"exposed",
				"progress": clampf(1.0 - t / maxf(exposed_s, 0.01), 0.0, 1.0)}
	return {}


# --- Progrès externes
## Coup d'ultime sur le boss (appelé automatiquement via SpellCaster.spell_hit ; à appeler à la main par un kit dont
## l'ultime ne passe pas par deal_damage).
func note_ultimate_hit() -> void:
	if state != State.SETUP and state != State.ACTIVE:
		return
	_crack(3)
	_add_kind(BreakCondition.Kind.ULTIMATE_HIT, 1)


## Coup lourd (>= RAID_HEAVY_HIT_FRAC du meilleur coup) : fissure visuelle ; compte comme un coup d'ultime toutes les
## RAID_ULT_ALT_HEAVY_HITS si l'option est ouverte (question ouverte 4).
func note_heavy_hit() -> void:
	if state != State.SETUP and state != State.ACTIVE:
		return
	_crack(cracks + 1)
	var need := Balance.RAID_ULT_ALT_HEAVY_HITS
	if need <= 0 and not Balance.RAID_ULT_REQUIRED:
		need = 2
	if need > 0:
		heavy_hits += 1
		if heavy_hits >= need:
			heavy_hits = 0
			_add_kind(BreakCondition.Kind.ULTIMATE_HIT, 1)


## Force la rupture (tests, scénario) : `reward` = fenêtre bonus.
func force_break(reward := true) -> void:
	if not is_invulnerable():
		return
	var c := primary()
	if c != null and not reward:
		by_backstop = true
	_break(c if reward else null)


## Libère tout (mort du boss, fin de combat).
func clear() -> void:
	_stop_hum()
	_cleanup()
	_hide_bubble()
	if is_invulnerable():
		Events.boss_shield_changed.emit(boss, false, primary_kind())
	state = State.IDLE
	if _caster != null and is_instance_valid(_caster) and _caster.is_connected(&"spell_hit", _on_spell_hit):
		_caster.disconnect(&"spell_hit", _on_spell_hit)
	_caster = null


# --- Interne
func _set_state(s: State) -> void:
	state = s
	t = 0.0
	if s == State.ACTIVE:
		_slow_t = 0.0
		_start_hum()
	elif s != State.SETUP:
		_stop_hum()
	state_changed.emit(s)


func _break(c: BreakCondition) -> void:
	winner = c
	rewarded = c != null and c.rewards() and not by_backstop
	_cleanup()
	_hide_bubble()
	_set_state(State.BREAKING)
	Events.boss_shield_changed.emit(boss, false, primary_kind())
	if _sfx_break != &"":
		RaidFx.sfx(_sfx_break, _boss_pos())
	broken.emit(rewarded)


func _add_kind(k: BreakCondition.Kind, n: int) -> void:
	for c in conditions:
		if c.kind == k:
			c.add(n)
			_emit_progress(c)


func _emit_progress(c: BreakCondition) -> void:
	var done := c.done + (c.consumed if c.kind == BreakCondition.Kind.KILL_ADDS else 0)
	Events.boss_shield_progress.emit(boss, done, c.total)
	progressed.emit(done, c.total)
	RaidFx.sfx(&"ui.raid_progress", _boss_pos())


func _on_cond(_node: Node, c: BreakCondition) -> void:
	if not is_invulnerable():
		return
	c.add(1)
	_emit_progress(c)


func _on_add_reached(_e: Enemy, c: BreakCondition) -> void:
	c.consumed += 1
	_emit_progress(c)


func _spawn_objects() -> void:
	var world := RaidKit.world_of(boss)
	var pl := RaidKit.player_of(world)
	var bpos := boss.global_position
	var toward := (pl.global_position - bpos).angle() if pl != null else 0.0
	for c in conditions:
		var p := c.params
		match c.kind:
			BreakCondition.Kind.ORBS:
				var radii: Array = p.get("radii_u", []) ## rayon de jet propre à chaque orbe (ex. cloche fêlée plus loin)
				var spread := deg_to_rad(float(p.get("spread_deg", 120.0)))
				for i in c.total:
					var a := toward + (0.0 if c.total == 1 else spread * (float(i) / float(c.total - 1) - 0.5))
					var r := (float(radii[i]) if i < radii.size() else float(p.get("throw_r_u", 6.0))) * RaidKit.U
					var to := RaidKit.place(boss, bpos + Vector2.from_angle(a) * r)
					objects.append(RaidOrb.throw(world, boss, bpos, to, pl, _on_cond.bind(c),
						backstop_s + setup_s, float(p.get("pickup_u", 0.8)), ORB_FALL_S))
			BreakCondition.Kind.KILL_ADDS:
				adds = PriorityAdds.create(boss)
				adds.heal_frac = float(p.get("heal_frac", Balance.RAID_ADD_HEAL_FRAC))
				adds.add_killed.connect(_on_cond.bind(c))
				adds.add_reached.connect(_on_add_reached.bind(c))
				var n := adds.spawn(c.total, p, pl.global_position if pl != null else Vector2.INF)
				c.total = maxi(n, 1) if n > 0 else c.total
				if n == 0: # aucun add possible (pool plein) : la condition ne doit pas bloquer
					c.add(c.total)
			BreakCondition.Kind.WEAK_POINT:
				var offs: Array = p.get("offsets_u", [Vector2(-1.6, 0.0), Vector2(0.0, 1.6), Vector2(0.0, -1.6)])
				for i in c.total:
					var off: Vector2 = offs[i % offs.size()]
					objects.append(WeakPoint.attach(boss, off, float(p.get("hp_frac", 0.05)),
						float(p.get("exposed_arc_deg", 120.0)), _on_cond.bind(c)))
			BreakCondition.Kind.SOAK:
				var pos: Array = p.get("positions", [])
				var ring := float(p.get("ring_u", 5.0)) * RaidKit.U
				for i in c.total:
					var at: Vector2 = pos[i] if i < pos.size() else bpos + Vector2.from_angle(toward + TAU * i / c.total) * ring
					var opts := {"r_u": p.get("r_u", 2.5), "hold_s": p.get("hold_s", 1.5), "life_s": backstop_s + setup_s, "fail": &"none"}
					objects.append(SoakZone.spawn(boss, at, opts, _on_cond.bind(c)))
			BreakCondition.Kind.INTERACT:
				var ppos: Array = p.get("positions", [])
				var pring := float(p.get("ring_u", 6.0)) * RaidKit.U
				for i in c.total:
					var at2: Vector2 = ppos[i] if i < ppos.size() else bpos + Vector2.from_angle(toward + PI + TAU * i / c.total) * pring
					objects.append(RaidProp.spawn(boss, at2, p, _on_cond.bind(c)))


func _cleanup() -> void:
	for o in objects:
		if is_instance_valid(o):
			if o.has_method(&"release"):
				o.release()
			else:
				o.queue_free()
	objects.clear()
	if adds != null and is_instance_valid(adds):
		adds.release()
	adds = null


func _bind_caster() -> void:
	if _caster != null and is_instance_valid(_caster):
		return
	var pl := RaidKit.player_of(boss)
	var sc: Object = pl.get(&"spells") if pl != null else null
	if sc != null and sc.has_signal(&"spell_hit"):
		_caster = sc
		if not sc.is_connected(&"spell_hit", _on_spell_hit):
			sc.connect(&"spell_hit", _on_spell_hit)


func _on_spell_hit(s: Object, enemy: Node, amount: float) -> void:
	var heavy := best_hit > 0.0 and amount >= best_hit * Balance.RAID_HEAVY_HIT_FRAC
	best_hit = maxf(best_hit, amount)
	if enemy != boss:
		return
	var slot: int = int(s.get(&"slot")) if s != null and s.get(&"slot") != null else -1
	if slot == ArdentKit.ULTIMATE_SLOT:
		note_ultimate_hit()
	elif heavy:
		note_heavy_hit()


func _show_bubble() -> void:
	if _bubble != null and is_instance_valid(_bubble):
		return
	var r: float = float(boss.get(&"radius_px")) if boss.get(&"radius_px") != null else 64.0
	_bubble = RaidFx.visual(&"shield_bubble", RaidFx.Kind.BUBBLE, RaidFx.STEEL, r * 1.35)
	boss.add_child(_bubble)


func _crack(n: int) -> void:
	cracks = clampi(n, 0, 3)
	if _bubble != null and is_instance_valid(_bubble):
		RaidFx.set_state(_bubble, cracks)


func _hide_bubble() -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = null


func _resolve_sfx(opts: Dictionary) -> void:
	var d: Dictionary = SFX_BY_BOSS.get(_boss_id(), {"up": &"", "break": SFX_BREAK_GENERIC})
	_sfx_up = StringName(d.get("up", &""))
	_sfx_break = StringName(d.get("break", &""))
	if opts.has("sfx_prefix"):
		_sfx_up = StringName("enemy.%s_shield_up.heavy" % opts["sfx_prefix"])
		_sfx_break = StringName("enemy.%s_shield_break.heavy" % opts["sfx_prefix"])
	if opts.has("sfx_up"):
		_sfx_up = StringName(opts["sfx_up"])
	if opts.has("sfx_break"):
		_sfx_break = StringName(opts["sfx_break"])


## Bourdon du bouclier actif (boucle, coupé à la rupture / au clear / à la sortie du boss de l'arbre).
func _start_hum() -> void:
	_stop_hum()
	if boss != null and is_instance_valid(boss) and boss.is_inside_tree():
		_hum = Audio.play_loop(SFX_HUM, boss, -18.0)


func _stop_hum() -> void:
	if not _hum.is_empty():
		Audio.stop_loop(_hum)
	_hum = {}


func _boss_id() -> StringName:
	if boss != null and is_instance_valid(boss) and boss.has_method(&"boss_id"):
		var id: StringName = boss.boss_id()
		if id != &"":
			return id
	return &"boss"


func _boss_pos() -> Vector2:
	return boss.global_position if boss != null and is_instance_valid(boss) else Vector2.ZERO
