class_name BarrageEmitter
extends Node2D
## Barrage d'un boss façon raid (docs/Design_Boss_Raid.md §1.2) : « des centaines de projectiles pendant X s », le
## joueur se cache derrière les pylônes (ShelterPylon). Réutilise EnemyProjectilePool (aucune instanciation) :
## au plus `max_live` (RAID_BARRAGE_MAX_LIVE = 160) projectiles vivants tirés par ce barrage.
## Déroulé : start() -> télégraphe `telegraph_s` (>= RAID_BARRAGE_TELEGRAPH_S, 1,5 s : cône(s) rouge(s), sirène,
## Events.raid_barrage(boss, true)) -> émission `duration_s` à `rate` projectiles/s dans `cones` cônes de `arc_deg`
## (qui tournent à `turn_deg_s`), vitesse `speed_u`, portée `range_u` -> fin (Events.raid_barrage(boss, false)).
## Variante « rechargement » : `reload_every_s` > 0 -> `reload_s` sans émission toutes les reload_every_s.
## Refus : avec un ShelterPylon lié, start() rend false tant que moins de RAID_BARRAGE_MIN_PYLONS pylônes sont
## debout (le cerveau doit planter d'abord). Dégâts par projectile : RAID_BARRAGE_COEF × dégâts courants du boss.
## Pendant tout le barrage, les ombres des pylônes sont protégées et dessinées (set_shadow_origin).

signal started(emitter: BarrageEmitter)
signal ended(emitter: BarrageEmitter)

enum State { IDLE, TELEGRAPH, FIRING }

var boss: Node2D = null
var shelters: ShelterPylon = null
var rate := 26.0
var duration_s := 5.5
var arc_deg := 120.0
var cones := 1
var turn_deg_s := 0.0
var speed_u := 9.0
var range_u := 14.0
var reload_every_s := 0.0
var reload_s := 2.0
var telegraph_s := Balance.RAID_BARRAGE_TELEGRAPH_S
var max_live := Balance.RAID_BARRAGE_MAX_LIVE
var aim := 0.0 ## direction (rad) du premier cône
var state := State.IDLE
var t := 0.0
var fired_total := 0
var peak_live := 0
var _acc := 0.0
var _origin := Vector2.INF
var _teles: Array[EnemyTelegraph] = []
var _rng := RandomNumberGenerator.new()


static func create(p_boss: Node2D, p_shelters: ShelterPylon = null) -> BarrageEmitter:
	var b := BarrageEmitter.new()
	b.name = &"BarrageEmitter"
	b.boss = p_boss
	b.shelters = p_shelters
	RaidKit.world_of(p_boss).add_child(b)
	return b


func is_busy() -> bool:
	return state != State.IDLE


func is_firing() -> bool:
	return state == State.FIRING


## Lance un barrage vers `aim_angle` (rad). opts : rate, duration_s, arc_deg, cones, turn_deg_s, speed_u, range_u,
## reload_every_s, reload_s, telegraph_s (jamais sous RAID_BARRAGE_TELEGRAPH_S), max_live. Rend false si refusé.
func start(aim_angle: float, opts: Dictionary = {}) -> bool:
	if state != State.IDLE or boss == null or not is_instance_valid(boss):
		return false
	if shelters != null and is_instance_valid(shelters) and shelters.live_count() < Balance.RAID_BARRAGE_MIN_PYLONS:
		return false
	for k in ["rate", "duration_s", "arc_deg", "turn_deg_s", "speed_u", "range_u", "reload_every_s", "reload_s", "telegraph_s"]:
		if opts.has(k):
			set(k, float(opts[k]))
	cones = maxi(int(opts.get("cones", cones)), 1)
	max_live = mini(int(opts.get("max_live", max_live)), Balance.RAID_BARRAGE_MAX_LIVE)
	telegraph_s = maxf(telegraph_s, Balance.RAID_BARRAGE_TELEGRAPH_S)
	aim = aim_angle
	state = State.TELEGRAPH
	t = 0.0
	_acc = 0.0
	fired_total = 0
	peak_live = 0
	_sync_origin(true)
	for i in cones:
		var tele := _tele(i)
		tele.show_cone(_origin, _cone_angle(i), range_u * RaidKit.U, deg_to_rad(arc_deg) * 0.5)
	Events.raid_barrage.emit(boss, true)
	RaidFx.sfx(&"enemy.raid_barrage_warn.heavy", _origin)
	started.emit(self)
	return true


func stop() -> void:
	if state == State.IDLE:
		return
	state = State.IDLE
	for tele in _teles:
		if is_instance_valid(tele):
			tele.hide_telegraph()
	if shelters != null and is_instance_valid(shelters):
		shelters.clear_shadow()
	Events.raid_barrage.emit(boss, false)
	ended.emit(self)


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if state == State.IDLE:
		return
	if boss == null or not is_instance_valid(boss) or not bool(boss.get(&"active")):
		stop()
		return
	t += delta
	_sync_origin(false)
	if state == State.TELEGRAPH:
		for i in cones:
			_teles[i].set_progress(clampf(t / telegraph_s, 0.0, 1.0))
		if t >= telegraph_s:
			state = State.FIRING
			t = 0.0
			for tele in _teles:
				tele.hide_telegraph()
		return
	aim += deg_to_rad(turn_deg_s) * delta
	if t >= duration_s:
		stop()
		return
	if reload_every_s > 0.0 and fmod(t, reload_every_s + reload_s) >= reload_every_s:
		_acc = 0.0 # rechargement : le canon fume, aucune émission
		return
	_acc += rate * delta
	if _acc < 1.0:
		return
	var pool := RaidKit.pool_of(boss)
	if pool == null:
		_acc = 0.0
		return
	var live := pool.count_from(self)
	var dmg: float = (boss as Enemy).current_damage() * Balance.RAID_BARRAGE_COEF if boss is Enemy else 1.0
	var spd := speed_u * RaidKit.U
	var r0: float = float(boss.get(&"radius_px")) if boss.get(&"radius_px") != null else 32.0
	var half := deg_to_rad(arc_deg) * 0.5
	while _acc >= 1.0:
		_acc -= 1.0
		if live >= max_live:
			continue # plafond : le tir est perdu (pas de rattrapage en rafale)
		var a := _cone_angle(fired_total % cones) + _rng.randf_range(-half, half)
		var dir := Vector2.from_angle(a)
		var p := pool.fire(self, _origin + dir * r0, dir * spd, dmg)
		(p as EnemyProjectilePool.Projectile).life = range_u / maxf(speed_u, 0.1)
		fired_total += 1
		live += 1
	peak_live = maxi(peak_live, live)


func _cone_angle(i: int) -> float:
	return aim + TAU * float(i) / float(maxi(cones, 1))


## Origine = position du boss ; l'ombre des pylônes n'est recalculée que si le boss a bougé de plus de 4 px.
func _sync_origin(force: bool) -> void:
	var o := boss.global_position
	if force or o.distance_squared_to(_origin) > 16.0:
		_origin = o
		global_position = o
		if shelters != null and is_instance_valid(shelters):
			shelters.set_shadow_origin(o)


func _tele(i: int) -> EnemyTelegraph:
	while _teles.size() <= i:
		var tele := EnemyTelegraph.new()
		add_child(tele)
		_teles.append(tele)
	return _teles[i]


func release() -> void:
	stop()
	queue_free()
