class_name SoftEnrage
extends RefCounted
## Enrage doux (docs/Design_Boss_Raid.md §1.8). L'enrage existant (Balance.boss_enrage_mult(fight_time), 90 s,
## +1,5 %/s, lu par Enemy.current_damage) ne compte plus que le temps VULNÉRABLE : le cerveau appelle
## tick(delta, frozen) à chaque image APRÈS l'incrément de Enemy.fight_time (Enemy.tick le fait avant brain.tick) ;
## `frozen` = bouclier ou transition en cours (BossShield.freezes_enrage()). L'horloge du boss est réécrite :
## boss.fight_time = vulnerable_s. Avertissement à BOSS_ENRAGE_WARN_S (signal `warned`, son, tag de barre), enrage
## à BOSS_ENRAGE_AFTER_S (signal `enraged`, liseré rouge). N'accélère jamais les télégraphes ni les récupérations
## (BossPace inchangé) : seuls la cadence choisie par le cerveau et les dégâts montent.

signal warned
signal enraged

var boss: Node2D = null
var vulnerable_s := 0.0
var frozen_s := 0.0
var is_warned := false
var is_enraged := false
var _aura: Node2D = null


static func create(p_boss: Node2D) -> SoftEnrage:
	var s := SoftEnrage.new()
	s.boss = p_boss
	return s


func tick(delta: float, frozen: bool) -> void:
	if frozen:
		frozen_s += delta
	else:
		vulnerable_s += delta
	if boss != null and is_instance_valid(boss):
		boss.set(&"fight_time", vulnerable_s)
	if not is_warned and vulnerable_s >= Balance.BOSS_ENRAGE_WARN_S:
		is_warned = true
		RaidFx.sfx(&"enemy.raid_enrage_warn.heavy", boss.global_position if is_instance_valid(boss) else Vector2.ZERO)
		warned.emit()
	if not is_enraged and vulnerable_s >= Balance.BOSS_ENRAGE_AFTER_S:
		is_enraged = true
		_show_aura()
		enraged.emit()


func enrage_mult() -> float:
	return Balance.boss_enrage_mult(vulnerable_s)


## Étiquette de barre (BossHealthBar, kind &"enrage") : vide avant l'avertissement.
func state_tag() -> Dictionary:
	if is_enraged:
		return {"text": "ENRAGÉ", "color": RaidFx.DANGER, "kind": &"enrage", "progress": 1.0}
	if is_warned:
		var k := clampf((vulnerable_s - Balance.BOSS_ENRAGE_WARN_S) / maxf(Balance.BOSS_ENRAGE_AFTER_S - Balance.BOSS_ENRAGE_WARN_S, 0.01), 0.0, 1.0)
		return {"text": "ENRAGE IMMINENT", "color": RaidFx.WARM, "kind": &"enrage_warn", "progress": k}
	return {}


func _show_aura() -> void:
	if boss == null or not is_instance_valid(boss) or _aura != null:
		return
	var r: float = float(boss.get(&"radius_px")) if boss.get(&"radius_px") != null else 64.0
	_aura = RaidFx.visual(&"enrage_aura", RaidFx.Kind.ENRAGE, RaidFx.DANGER, r * 1.3)
	_aura.z_index = -1
	boss.add_child(_aura)


func clear() -> void:
	if _aura != null and is_instance_valid(_aura):
		_aura.queue_free()
	_aura = null
