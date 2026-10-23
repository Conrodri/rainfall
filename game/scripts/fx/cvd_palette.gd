class_name CvdPalette
extends RefCounted
## Palettes par mode daltonien (lot UX A11y-L1, docs/ux/Audit_Entrees_Accessibilite.md §3.2) + outils de simulation.
## Le mode vient de `GameSettings.colorblind()` (0 aucun, 1 deutéranopie, 2 protanopie, 3 tritanopie), LU SEULEMENT :
## ce fichier n'écrit jamais de réglage. La lecture du réglage ouvre un fichier : elle est mise en cache
## (rafraîchie toutes les REFRESH_MS) pour pouvoir être appelée à chaque image sans coût.
## Règle : la couleur ne porte jamais seule le sens (pictogrammes, motifs d'aura, signe « − » des dégâts subis) ;
## la palette alternative n'est qu'un renfort. Cibles vérifiées par tests/colorblind_test.gd (ΔE2000 en simulation
## Machado 2009, sévérité 1,0) : statuts >= 20 dans le mode visé, dégât subi / critique >= 20 dans les 4 vues.

const NONE := 0
const DEUTAN := 1
const PROTAN := 2
const TRITAN := 3
const REFRESH_MS := 500

## Statuts de monde : mode -> {burn, poison, frost}. Les deux modes rouge-vert partagent la palette (audit).
const STATUS_RG := {
	&"burn": Color("#F07A2A"),
	&"poison": Color("#9A5CE0"), ## violet : la brûlure et le poison ne se confondent plus
	&"frost": Color("#A8E4FA"),
}
const STATUS_TRI := {
	&"burn": Color("#F0503C"),
	&"poison": Color("#5FA83A"),
	&"frost": Color("#F2F6FA"),
}
## Éclair (chiffres de dégâts), par palette : le violet par défaut entrerait en conflit avec le poison RG.
const LIGHTNING_DEFAULT := Color(0.80, 0.70, 1.0)
const LIGHTNING_RG := Color("#BBD2B9")
const LIGHTNING_TRI := Color("#A5DCC9")

## Chiffres de dégâts : critique or, dégât subi cramoisi (teinte nettement distincte dans les 4 vues).
const CRIT := Color("#FFD13B")
const HURT := Color("#C0020F")

## Matrices de simulation Machado et al. 2009 (sévérité 1,0), espace RGB LINÉAIRE.
const SIM_DEUTAN := [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]
const SIM_PROTAN := [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]
const SIM_TRITAN := [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]]

## Tests : force le mode (>= 0) sans toucher au réglage ; -1 = lire GameSettings.
static var override_mode := -1
static var _cached := 0
static var _cached_at := -1000000
static var _cached_path := ""
static var _cached_mtime := -1


## Mode daltonien courant (0..3), lecture seule du réglage, mise en cache.
static func mode() -> int:
	if override_mode >= 0:
		return clampi(override_mode, 0, 3)
	var now := Time.get_ticks_msec()
	if now - _cached_at >= REFRESH_MS or _cached_at > now:
		_cached_at = now
		# perf (réparation vague 3) : relit le fichier seulement s'il a changé (chemin ou date) ; une date de moins
		# de 2 s est relue quand même (précision d'une seconde de la date de modification).
		var path := GameSettings.cfg_path
		var mt := FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0
		if path != _cached_path or mt != _cached_mtime or Time.get_unix_time_from_system() - mt < 2.0:
			_cached_path = path
			_cached_mtime = mt
			_cached = clampi(GameSettings.colorblind(), 0, 3)
	return _cached


## Oublie le cache (tests qui injectent un autre fichier de réglages).
static func clear_cache() -> void:
	_cached_at = -1000000
	_cached_path = ""


## Couleur d'un statut de monde dans le mode `m` (-1 = mode courant). Hors brûlure / poison / gel : couleur du HpBarStyle.
static func status(id: StringName, m: int = -1) -> Color:
	var mm := mode() if m < 0 else m
	var tab: Dictionary = {}
	if mm == DEUTAN or mm == PROTAN:
		tab = STATUS_RG
	elif mm == TRITAN:
		tab = STATUS_TRI
	if tab.has(id):
		return tab[id]
	return HpBarStyle.STATUS_COL.get(id, Color.WHITE)


## Couleur d'un affixe d'élite (burn / slow / poison) : suit la palette des statuts, alpha d'aura conservé.
static func affix(id: StringName, m: int = -1) -> Color:
	var mm := mode() if m < 0 else m
	if mm == NONE:
		return EnemyAura.AFFIX_COLORS.get(id, Color.WHITE)
	var base := status(&"frost" if id == &"slow" else id, mm)
	return Color(base.r, base.g, base.b, 0.85)


## Couleur d'un élément pour les chiffres de dégâts, dans le mode `m` (-1 = courant).
static func element(el: StringName, m: int = -1) -> Color:
	var mm := mode() if m < 0 else m
	if mm == NONE:
		return DamageNumbers.ELEMENT_COLORS.get(el, DamageNumbers.BASE_COLOR)
	match el:
		&"fire":
			return status(&"burn", mm)
		&"ice":
			return status(&"frost", mm)
		&"poison":
			return status(&"poison", mm)
		&"lightning":
			return LIGHTNING_TRI if mm == TRITAN else LIGHTNING_RG
	return DamageNumbers.BASE_COLOR


## Tous les statuts / éléments d'un mode, pour les tests : id -> Color.
static func status_set(m: int) -> Dictionary:
	return {&"burn": status(&"burn", m), &"poison": status(&"poison", m), &"frost": status(&"frost", m)}


# --- Simulation et distance de couleur (tests, outils) -----------------------------------------------------

static func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


## Couleur sRGB vue par un daltonien de type `kind` (DEUTAN / PROTAN / TRITAN ; NONE = inchangée), en sRGB linéaire.
static func simulate_linear(c: Color, kind: int) -> Vector3:
	var l := Vector3(_lin(c.r), _lin(c.g), _lin(c.b))
	var m: Array
	match kind:
		DEUTAN:
			m = SIM_DEUTAN
		PROTAN:
			m = SIM_PROTAN
		TRITAN:
			m = SIM_TRITAN
		_:
			return l
	var out := Vector3.ZERO
	for i in 3:
		var row: Array = m[i]
		out[i] = clampf(float(row[0]) * l.x + float(row[1]) * l.y + float(row[2]) * l.z, 0.0, 1.0)
	return out


## CIELAB (D65) depuis du RGB linéaire.
static func lab_from_linear(v: Vector3) -> Vector3:
	var x := 0.4124564 * v.x + 0.3575761 * v.y + 0.1804375 * v.z
	var y := 0.2126729 * v.x + 0.7151522 * v.y + 0.0721750 * v.z
	var z := 0.0193339 * v.x + 0.1191920 * v.y + 0.9503041 * v.z
	var fx := _f(x / 0.95047)
	var fy := _f(y)
	var fz := _f(z / 1.08883)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


## ΔE2000 (Sharma, Wu, Dalal 2005) entre deux couleurs sRGB vues par `kind`.
static func delta_e(a: Color, b: Color, kind: int = NONE) -> float:
	return delta_e2000(lab_from_linear(simulate_linear(a, kind)), lab_from_linear(simulate_linear(b, kind)))


static func delta_e2000(p: Vector3, q: Vector3) -> float:
	var c1 := Vector2(p.y, p.z).length()
	var c2 := Vector2(q.y, q.z).length()
	var cb := (c1 + c2) * 0.5
	var cb7 := pow(cb, 7.0)
	var g := 0.5 * (1.0 - sqrt(cb7 / (cb7 + pow(25.0, 7.0))))
	var ap1 := (1.0 + g) * p.y
	var ap2 := (1.0 + g) * q.y
	var cp1 := sqrt(ap1 * ap1 + p.z * p.z)
	var cp2 := sqrt(ap2 * ap2 + q.z * q.z)
	var hp1 := fposmod(rad_to_deg(atan2(p.z, ap1)), 360.0)
	var hp2 := fposmod(rad_to_deg(atan2(q.z, ap2)), 360.0)
	var dl := q.x - p.x
	var dc := cp2 - cp1
	var dh := 0.0
	if cp1 * cp2 != 0.0:
		dh = hp2 - hp1
		if dh > 180.0:
			dh -= 360.0
		elif dh < -180.0:
			dh += 360.0
	var dhh := 2.0 * sqrt(cp1 * cp2) * sin(deg_to_rad(dh * 0.5))
	var lb := (p.x + q.x) * 0.5
	var cpb := (cp1 + cp2) * 0.5
	var hb := hp1 + hp2
	if cp1 * cp2 != 0.0:
		hb = (hp1 + hp2) * 0.5
		if absf(hp1 - hp2) > 180.0:
			hb += 180.0 if hp1 + hp2 < 360.0 else -180.0
	var t := 1.0 - 0.17 * cos(deg_to_rad(hb - 30.0)) + 0.24 * cos(deg_to_rad(2.0 * hb)) \
			+ 0.32 * cos(deg_to_rad(3.0 * hb + 6.0)) - 0.20 * cos(deg_to_rad(4.0 * hb - 63.0))
	var dth := 30.0 * exp(-pow((hb - 275.0) / 25.0, 2.0))
	var cpb7 := pow(cpb, 7.0)
	var rc := 2.0 * sqrt(cpb7 / (cpb7 + pow(25.0, 7.0)))
	var sl := 1.0 + 0.015 * pow(lb - 50.0, 2.0) / sqrt(20.0 + pow(lb - 50.0, 2.0))
	var sc := 1.0 + 0.045 * cpb
	var sh := 1.0 + 0.015 * cpb * t
	var rt := -sin(deg_to_rad(2.0 * dth)) * rc
	var a := dl / sl
	var b := dc / sc
	var c := dhh / sh
	return sqrt(maxf(a * a + b * b + c * c + rt * b * c, 0.0))
