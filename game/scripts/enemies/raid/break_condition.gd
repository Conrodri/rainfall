class_name BreakCondition
extends RefCounted
## Condition de rupture d'un bouclier de phase (docs/Design_Boss_Raid.md §1.1). Simple compteur : BossShield
## pose les objets de la condition (orbes, adds, points faibles, zones, props) et appelle add() à chaque progrès.
## Paramètres (dictionnaire, défauts du doc) :
##   ORBS          count 3, throw_r_u 6, spread_deg 120, pickup_u 0.8, label "ORBES"
##   ULTIMATE_HIT  hits 1 (le garde-fou du bouclier passe à BOSS_SHIELD_BACKSTOP_ULT_S), label
##   TIMER         s 5
##   KILL_ADDS     count 2, add_hp_frac 0.07, walk_u 2.0, heal_frac RAID_ADD_HEAL_FRAC, heal_cap_frac, prefix &"stoker_", tier 1,
##                 respawn true (un add arrivé au boss est remplacé : seuls les morts font avancer la condition)
##   WEAK_POINT    points 1, hp_frac 0.05, offsets_u [Vector2(-1.6, 0)] (dos), exposed_arc_deg 120
##   SOAK          zones 2, r_u 2.5, hold_s 1.5, ring_u 5, positions [] (sinon en anneau autour du boss)
##   INTERACT      props 2, hold_s 0.6, ring_u 6, positions [], label "RALLUMER"

enum Kind { ORBS, ULTIMATE_HIT, TIMER, KILL_ADDS, WEAK_POINT, SOAK, INTERACT }

const KIND_IDS := [&"orbs", &"ultimate_hit", &"timer", &"kill_adds", &"weak_point", &"soak", &"interact"]
const LABELS := ["ORBES", "FRAPPEZ AVEC L'ULTIME", "TENEZ", "SERVITEURS", "POINT FAIBLE", "ABSORBER", "RALLUMER"]

var kind := Kind.TIMER
var params := {}
var total := 1
var done := 0
var consumed := 0 ## KILL_ADDS : adds arrivés au boss (soin + salve du cerveau ; NE comptent PAS pour la rupture)
var elapsed := 0.0 ## TIMER : temps écoulé sous bouclier actif
var label := ""


## Depuis un dictionnaire {kind: Kind | &"orbs"…, …paramètres}. Kind inconnu : TIMER de 5 s.
static func from_dict(d: Dictionary) -> BreakCondition:
	var c := BreakCondition.new()
	var k: Variant = d.get("kind", Kind.TIMER)
	if k is StringName or k is String:
		var i := KIND_IDS.find(StringName(k))
		c.kind = (i if i >= 0 else Kind.TIMER) as Kind
	else:
		c.kind = clampi(int(k), 0, Kind.size() - 1) as Kind
	c.params = d
	match c.kind:
		Kind.ORBS:
			c.total = int(d.get("count", 3))
		Kind.ULTIMATE_HIT:
			c.total = int(d.get("hits", 1))
		Kind.TIMER:
			c.total = 1
		Kind.KILL_ADDS:
			c.total = int(d.get("count", 2))
		Kind.WEAK_POINT:
			c.total = int(d.get("points", 1))
		Kind.SOAK:
			c.total = int(d.get("zones", 2))
		Kind.INTERACT:
			c.total = int(d.get("props", 2))
	c.total = maxi(c.total, 1)
	c.label = String(d.get("label", LABELS[c.kind]))
	return c


func kind_id() -> StringName:
	return KIND_IDS[kind]


func timer_s() -> float:
	return float(params.get("s", 5.0))


func add(n := 1) -> void:
	done = mini(done + n, total)


## Remplie : compteur plein (TIMER : temps écoulé) ; KILL_ADDS : tous TUÉS (les adds arrivés au boss ne comptent pas).
func is_met() -> bool:
	if kind == Kind.TIMER:
		return elapsed >= timer_s()
	if kind == Kind.KILL_ADDS:
		return done >= total
	return done >= total


## Rupture méritée (fenêtre bonus) : toujours, pour une condition remplie (KILL_ADDS : par les morts seules).
func rewards() -> bool:
	return true


func progress() -> float:
	if kind == Kind.TIMER:
		return clampf(elapsed / maxf(timer_s(), 0.01), 0.0, 1.0)
	if kind == Kind.KILL_ADDS:
		return clampf(float(done) / float(total), 0.0, 1.0)
	return clampf(float(done) / float(total), 0.0, 1.0)


## Étiquette de la barre de boss : « CLOCHES 1/3 », « TENEZ 3 s », « FRAPPEZ AVEC L'ULTIME ».
func text() -> String:
	match kind:
		Kind.TIMER:
			return "%s %d s" % [label, ceili(maxf(timer_s() - elapsed, 0.0))]
		Kind.ULTIMATE_HIT:
			return label if total <= 1 else "%s %d/%d" % [label, done, total]
		Kind.KILL_ADDS:
			return "%s %d/%d" % [label, done, total]
	return "%s %d/%d" % [label, done, total]
