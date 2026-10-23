extends AverseKit
## TEMPORAIRE (mesure équilibrage Crue 23/10) : AverseKit instrumenté (dégâts effectifs par slot, Crues lancées,
## eau de carte simulée par un cycle, Crue auto seulement amphore pleine). Supprimé après mesure.

static var dmg := {}
static var crues := 0
static var crue_water := 0.0
static var map_duty := 0.0 ## part du temps dans l'eau de la carte (cycle de 10 s)
static var full_only := false
var _clock := 0.0


static func reset_stats() -> void:
	dmg = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0}
	crues = 0
	crue_water = 0.0


func on_spell_hit(s: SpellData, enemy: Node, amount: float) -> void:
	var hp_after: float = float(enemy.get(&"hp")) if is_instance_valid(enemy) else 0.0
	var key: Variant = 5 if s.has_meta(&"crue") else s.slot
	dmg[key] = float(dmg.get(key, 0.0)) + maxf(amount + minf(hp_after, 0.0), 0.0)
	super.on_spell_hit(s, enemy, amount)


var _in_crue := false


func _crue(s: SpellData, spent: float) -> void:
	crues += 1
	crue_water += spent
	_in_crue = true
	super._crue(s, spent)
	_in_crue = false


func spawn_puddle(s: SpellData, at: Vector2) -> Node2D:
	if _in_crue:
		s = s.duplicate() as SpellData
		s.set_meta(&"crue", true)
	return super.spawn_puddle(s, at)


func is_map_water(_pos: Vector2) -> bool:
	return fmod(_clock, 10.0) < map_duty * 10.0


func tick(delta: float) -> void:
	_clock += delta
	super.tick(delta)


func auto_cast_ok(slot: int) -> bool:
	if slot == 4 and full_only:
		if water >= WATER_MAX - 0.5:
			return true
		return player != null and player.max_hp > 0.0 and water >= CRUE_MIN and player.hp / player.max_hp <= AUTO_CRUE_LOW_HP
	return super.auto_cast_ok(slot)
