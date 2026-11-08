extends AmbientEffect
## « Coulée » : les props fixes `prop` (défaut `crucible`) pulsent orange. Modulation du masque d'émission `_e` du
## prop livré par Codex (self_modulate de l'enfant « Emission », aucun matériau ni texture créé), plus une lumière
## `light_preset` (défaut `crucible_glow`, catégorie decor : plafonnée par LightRig selon Bas / Moyen / Haut, 0 en
## Bas) dont la pulsation vient du préréglage. Fondu d'entrée `fade_s`.
## Paramètres : "prop", "color" ("#FFB070"), "hz" (0,3), "amp" (0,45 : ± sur l'intensité), "gain" (1,8 : intensité
## moyenne du masque pendant l'événement), "light_preset", "light_offset_u" (hauteur de la lueur, 0,8), "fade_s" (3).

var sprites: Array[Sprite2D] = []
var lights: Array = [] ## LightRig.Handle
var _ems: Array[CanvasItem] = []
var _base: Array[Color] = []
var _t := 0.0
var _fade := 0.0
var _color := Color(1.0, 0.69, 0.44)


func setup() -> void:
	_color = Color.from_string(String(def.get("color", "#FFB070")), _color)
	if fixed_props(String(def.get("prop", "crucible"))).is_empty():
		note_missing("props_fixed « %s » absent de la carte ou texture non livrée" % String(def.get("prop", "crucible")))


func start() -> void:
	_t = 0.0
	_fade = 0.0
	sprites = fixed_props(String(def.get("prop", "crucible")))
	_ems.clear()
	_base.clear()
	for s in sprites:
		var em := emission_of(s)
		if em != null:
			_ems.append(em)
			_base.append(em.self_modulate)
	var preset := StringName(def.get("light_preset", "crucible_glow"))
	if LightRig.has_preset(preset):
		var off := Vector2(0.0, -float(def.get("light_offset_u", 0.8)) * U)
		for s in sprites:
			var h := LightRig.attach(s, preset, {"offset": off, "fade": 1.5})
			h.set_energy(1.0)
			lights.append(h)


func process(delta: float) -> void:
	_t += delta
	_fade = minf(_fade + delta / maxf(float(def.get("fade_s", 3.0)), 0.01), 1.0)
	if _ems.is_empty():
		return
	var w := 1.0 + float(def.get("amp", 0.45)) * sin(_t * TAU * float(def.get("hz", 0.3)))
	var g := lerpf(1.0, float(def.get("gain", 1.8)) * w, _fade)
	for i in _ems.size():
		var em := _ems[i]
		if is_instance_valid(em):
			var b := _base[i]
			var c := b.lerp(Color(b.r * _color.r, b.g * _color.g, b.b * _color.b, b.a), _fade)
			em.self_modulate = Color(c.r * g, c.g * g, c.b * g, c.a)


## Les lueurs suivent les props (LightRig.attach), pas les sources de la carte : rien à refaire.
func refresh() -> void:
	pass


func stop() -> void:
	for i in _ems.size():
		if is_instance_valid(_ems[i]):
			_ems[i].self_modulate = _base[i]
	_ems.clear()
	_base.clear()
	for h in lights:
		(h as LightRig.Handle).release()
	lights.clear()
	sprites.clear()


func describe() -> Dictionary:
	var d := super.describe()
	d["props"] = sprites.size()
	d["emissions"] = _ems.size()
	d["lights"] = lights.size()
	return d
