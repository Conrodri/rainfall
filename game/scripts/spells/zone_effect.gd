extends Node2D
## Zone au sol (nova instantanée ou zone persistante). Dégâts via caster.deal_damage par distance
## aux nœuds du groupe "enemies".
## Visuel : SpriteFrames rendu dans Blender (SpellData.vfx_frames, nœud « Vfx »), calé sur le rayon réel
## (zone_size_add compris) et posé au sol iso (échelle (k, k / vfx_floor_aspect) en repère logique) ;
## diffus + passe _e additive (EmissiveOverlay). Sans asset : repli dessiné en _draw (contour fin de télégraphe).
## Nova / Brasier : gerbe `default` jouée une fois (la zone vit jusqu'à la fin de l'anim, dégâts au lancement).
## Cendres : `default` en boucle pendant la durée, puis `end` si livrée, sinon fondu.
## Demi-lune (ARC) : asset `dagger_arc` rendu vu de dessus (rig TOP, aspect 1, arc centré sur +X), tourné vers arc_dir.

const VFX_FADE_IN_S := 0.12
const VFX_FADE_OUT_S := 0.4 ## extinction d'une zone persistante sans anim `end`
const VFX_Z := -1 ## sous les personnages, au-dessus du sol (comme les télégraphes)
const FALLBACK_WIDTH := 2.0 ## contour fin (px logiques)
const TILE_CLEAR_PX := 77.0 ## pavage : aucune copie à moins de 1,2 u du centre
const TILE_INNER_SCALE := 0.6 ## copies intérieures plus basses
const TILE_INNER_ALPHA := 0.45
const ARC_ANIM_S := 0.25 ## repli de la demi-lune : durée du balayage

var caster: Object = null
var spell: SpellData = null
var radius := 160.0
var duration := 0.0
var tick := 0.5
var _t := 0.0
var _tick_t := 0.0
var _anim := 0.35
## Secteur (sort ARC, demi-lune) : seuls les ennemis à moins de arc_half de arc_dir sont touchés.
## arc_half >= PI = disque complet (novas, zones).
var arc_dir := Vector2.RIGHT
var arc_half := PI
## Effet rendu (null = repli dessiné).
var vfx: AnimatedSprite2D = null
var outline: ZoneOutline = null ## contour de la zone persistante (null : instantanée, secteur, ou sans couche)
var _vfx_len := 0.0 ## durée de l'anim `default` (s)
var _tiles: Array[AnimatedSprite2D] = [] ## copies de pavage (flammes plafonnées), voir SpellData.vfx_flame_h_px
var _tile_a: Array[float] = []
var _zone_scale := Vector2.ZERO ## échelle nominale (une seule copie calée sur le rayon)
var _ending := false ## zone persistante finie : anim `end` en cours, plus de dégâts


func setup(new_caster: Object, new_spell: SpellData, pos: Vector2, radius_px: float) -> void:
	caster = new_caster
	spell = new_spell
	global_position = pos
	radius = radius_px
	duration = new_spell.duration
	tick = maxf(new_spell.tick, 0.05)
	if arc_half < PI:
		_anim = ARC_ANIM_S
	_setup_vfx()
	_setup_outline()
	_apply()
	if duration <= 0.0:
		duration = 0.0


## Zone persistante (durée > 0, disque complet) : contour ZoneOutline de la couleur du sort, au rayon réel.
func _setup_outline() -> void:
	if duration <= 0.0 or arc_half < PI or spell == null:
		return
	outline = ZoneOutline.attach(self, radius, ZoneOutline.color_for(spell, caster), duration)


## Instancie le SpriteFrames du sort s'il existe ; sinon le _draw de repli reste seul.
func _setup_vfx() -> void:
	if spell == null or spell.vfx_frames == "" or not ResourceLoader.exists(spell.vfx_frames):
		return
	var frames := load(spell.vfx_frames) as SpriteFrames
	if frames == null or not frames.has_animation(&"default") or frames.get_frame_count(&"default") == 0:
		return
	vfx = AnimatedSprite2D.new()
	vfx.name = "Vfx"
	z_index = VFX_Z
	add_child(vfx)
	EmissiveOverlay.apply(vfx, frames)
	if spell.vfx_additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		vfx.material = m
	var k := radius / maxf(spell.vfx_radius_px, 1.0) if spell.vfx_radius_px > 0.0 else 1.0
	var asp := clampf(spell.vfx_floor_aspect, 0.1, 1.0)
	vfx.scale = Vector2(k, k / asp)
	_zone_scale = vfx.scale
	var k_cap := _flame_k_cap()
	if k_cap > 0.0 and k > k_cap and arc_half >= PI:
		_tile_vfx(frames, k_cap, asp)
	if arc_half < PI:
		vfx.rotation = arc_dir.angle() # rig TOP (aspect 1) : la rotation au sol reste exacte
	_vfx_len = anim_length(vfx.sprite_frames, &"default")
	vfx.play(&"default")
	if duration <= 0.0:
		_anim = maxf(_anim, _vfx_len) # gerbe : la zone vit jusqu'au bout de l'anim (dégâts déjà appliqués)
	vfx.modulate.a = 0.0 if duration > 0.0 else 1.0
	_set_tiles_alpha(vfx.modulate.a)


## Échelle maximale d'une copie pour que les flammes ne dépassent pas vfx_flame_cap_u (0 = pas de plafond).
## Écran : hauteur = h_px × k (le sol iso écrase y de moitié, annulé par k / aspect) ; 72 px écran / u.
func _flame_k_cap() -> float:
	if spell == null or spell.vfx_flame_h_px <= 0.0 or spell.vfx_radius_px <= 0.0:
		return 0.0
	return spell.vfx_flame_cap_u * Iso.SCREEN_PX_PER_U / spell.vfx_flame_h_px


## Habille la zone de copies à l'échelle k_cap sans masquer ce qui brûle dedans : anneau de flammes sur le bord,
## quelques copies plus basses et translucides à l'intérieur, centre (joueur) dégagé. Max 12 copies.
func _tile_vfx(frames: SpriteFrames, k_cap: float, asp: float) -> void:
	vfx.visible = false # la copie centrale ne sert plus que d'horloge d'anim
	var tile_r := spell.vfx_radius_px * k_cap # rayon de l'empreinte d'une copie (px logiques)
	var edge_r := maxf(radius - tile_r * 0.6, 0.0)
	var specs: Array = []
	var n_edge := 9
	for i in n_edge:
		specs.append([Vector2.from_angle(TAU * i / n_edge + 0.3) * edge_r, 1.0, 1.0])
	var in_r := clampf(edge_r * 0.5, TILE_CLEAR_PX, edge_r)
	for i in 3:
		specs.append([Vector2.from_angle(TAU * (i + 0.5) / 3.0 + 1.1) * in_r, TILE_INNER_SCALE, TILE_INNER_ALPHA])
	var idx := 0
	for sp in specs:
		idx += 1
		var s := AnimatedSprite2D.new()
		s.name = "VfxTile%d" % idx
		s.position = sp[0]
		var kk: float = k_cap * float(sp[1])
		s.scale = Vector2(kk * (1.0 if idx % 2 == 0 else -1.0), kk / asp)
		s.material = vfx.material
		add_child(s)
		EmissiveOverlay.apply(s, frames)
		s.play(&"default")
		s.set_frame_and_progress(0, 0.0) # même phase que la gerbe
		_tiles.append(s)
		_tile_a.append(float(sp[2]))


## Opacité des copies de pavage = a × leur facteur propre (intérieur translucide).
func _set_tiles_alpha(a: float) -> void:
	for i in _tiles.size():
		_tiles[i].modulate.a = a * _tile_a[i]


## Durée d'une anim d'un SpriteFrames (somme des durées relatives / fps), 0 si absente.
static func anim_length(frames: SpriteFrames, anim: StringName) -> float:
	if frames == null or not frames.has_animation(anim):
		return 0.0
	var fps := frames.get_animation_speed(anim)
	if fps <= 0.0:
		return 0.0
	var total := 0.0
	for i in frames.get_frame_count(anim):
		total += frames.get_frame_duration(anim, i)
	return total / fps


## Échelle appliquée au VFX (tests) : Vector2.ZERO sans VFX.
## Zone persistante finie (anim `end` en cours, plus de dégâts).
func is_ending() -> bool:
	return _ending


func vfx_scale() -> Vector2:
	return _zone_scale if vfx != null else Vector2.ZERO


func step(delta: float) -> void: ## public pour les tests sans boucle de rendu
	_t += delta
	if duration > 0.0:
		if _ending:
			if vfx == null or not vfx.is_playing() or _t >= duration + anim_length(vfx.sprite_frames, &"end") + 0.05:
				queue_free()
			return
		_tick_t += delta
		while _tick_t >= tick:
			_tick_t -= tick
			_apply()
		_update_persistent_vfx()
		if _t >= duration:
			if vfx != null and vfx.sprite_frames.has_animation(&"end"):
				_ending = true
				vfx.modulate.a = 1.0
				vfx.play(&"end")
			else:
				queue_free()
	elif _t >= _anim:
		queue_free()
	if vfx == null or not _tiles.is_empty():
		queue_redraw()


## Zone persistante : apparition en fondu, extinction en fondu si l'asset n'a pas d'anim `end`.
func _update_persistent_vfx() -> void:
	if vfx == null:
		return
	var a := clampf(_t / VFX_FADE_IN_S, 0.0, 1.0)
	if not vfx.sprite_frames.has_animation(&"end"):
		a = minf(a, clampf((duration - _t) / VFX_FADE_OUT_S, 0.0, 1.0))
	vfx.modulate.a = a
	_set_tiles_alpha(a)


func _process(delta: float) -> void:
	step(delta)


func _apply() -> void:
	if caster == null or not is_instance_valid(caster):
		return
	# nova (instantanée) = coup direct, recul radial depuis le centre ; zone persistante (Cendres) = DoT
	var hit := {"is_dot": true} if duration > 0.0 or (spell != null and spell.duration > 0.0) else {"source_pos": global_position}
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and e.has_method("take_damage") and e.global_position.distance_to(global_position) <= radius:
			if arc_half < PI:
				var v: Vector2 = e.global_position - global_position
				if v.length_squared() > 1.0 and absf(arc_dir.angle_to(v)) > arc_half:
					continue
			caster.deal_damage(e, spell, hit)
	for w in get_tree().get_nodes_in_group(&"secret_wall"): # mur fissuré d'une salle secrète (SecretWall)
		if w is Node2D and w.global_position.distance_to(global_position) <= radius + 64.0:
			w.call(&"take_hit", caster.compute_damage(spell, null, false))


## Repli sans asset (placeholder, à remplacer par le VFX rendu) : contour fin au rayon réel.
func _draw() -> void:
	if spell == null:
		return
	if vfx != null:
		if not _tiles.is_empty(): # flammes clairsemées : la lueur au sol et le contour disent la zone réelle
			var f := 1.0 - clampf(_t / maxf(_anim, 0.1), 0.0, 1.0) * 0.6
			var g := Color(1.0, 0.45, 0.12)
			draw_circle(Vector2.ZERO, radius, Color(g.r, g.g, g.b, 0.12 * f))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(g.r, g.g, g.b, 0.45 * f), 2.0)
		return
	var c := spell.color
	if duration > 0.0:
		if outline != null:
			return # le contour (ZoneOutline) remplace l'ancien voile + cercle de points
		var a := clampf(1.0 - _t / duration, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(c.r, c.g, c.b, 0.08 * a + 0.04))
		# grammaire des formes au sol (GroundShapes) : zone alliée persistante = cercle de points fins, remplissage <= 0,12
		GroundShapes.draw_dotted_circle(self, radius, Color(c.r, c.g, c.b, 0.55 * a + 0.2), clampi(int(radius / 9.0), 16, 64), 2.4)
	elif arc_half < PI:
		_draw_arc_fallback(c)
	else:
		var k := clampf(_t / _anim, 0.0, 1.0)
		var ease_k := 1.0 - pow(1.0 - k, 3.0)
		draw_arc(Vector2.ZERO, radius * (0.25 + 0.75 * ease_k), 0.0, TAU, 64, Color(c.r, c.g, c.b, 0.8 * (1.0 - k)), FALLBACK_WIDTH)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(c.r, c.g, c.b, 0.3 * (1.0 - k)), 1.0)


## Demi-lune sans `dagger_arc` : croissant qui balaie le secteur (bord d'attaque net, traîne qui s'efface)
## et trois traits de lame décalés, dans la couleur du sort en HDR léger.
func _draw_arc_fallback(c: Color) -> void:
	if c.a <= 0.0: # couleur transparente = VFX rendu porté ailleurs (ex. coffre_arc d'Avare) : aucun croissant
		return
	var k := clampf(_t / _anim, 0.0, 1.0)
	var sweep := minf(k * 1.6, 1.0) # le balayage finit à 60 % de l'anim, le reste s'efface
	var fade := 1.0 - clampf((k - 0.5) / 0.5, 0.0, 1.0)
	var a0 := arc_dir.angle() - arc_half
	var a1 := a0 + 2.0 * arc_half * sweep
	var hdr := Color(c.r * 1.6, c.g * 1.6, c.b * 1.6, 1.0)
	var n := 24
	var r_out := radius * 0.95
	var r_in := radius * 0.55
	if sweep > 0.02: # croissant en quadrilatères convexes (pas de triangulation de polygone concave)
		for i in n:
			var t0 := float(i) / n
			var t1 := float(i + 1) / n
			var g0 := lerpf(a0, a1, t0)
			var g1 := lerpf(a0, a1, t1)
			var o0 := Vector2.from_angle(g0) * r_out
			var o1 := Vector2.from_angle(g1) * r_out
			var i0 := Vector2.from_angle(g0) * lerpf(r_out - 2.0, r_in, t0)
			var i1 := Vector2.from_angle(g1) * lerpf(r_out - 2.0, r_in, t1)
			var c0 := Color(hdr.r, hdr.g, hdr.b, 0.55 * fade * t0 * t0)
			var c1 := Color(hdr.r, hdr.g, hdr.b, 0.55 * fade * t1 * t1)
			var ci0 := Color(hdr.r, hdr.g, hdr.b, 0.25 * fade * t0 * t0)
			var ci1 := Color(hdr.r, hdr.g, hdr.b, 0.25 * fade * t1 * t1)
			draw_primitive(PackedVector2Array([o0, o1, i1, i0]), PackedColorArray([c0, c1, ci1, ci0]), PackedVector2Array())
	for j in 3: # traits de lame : trois rayons d'arc légèrement décalés
		var rr := radius * (0.7 + 0.12 * j)
		var lag := 0.18 * j
		var s1 := clampf(sweep - lag * 0.3, 0.0, 1.0)
		if s1 <= 0.02:
			continue
		var b1 := a0 + 2.0 * arc_half * s1
		var b0 := maxf(a0, b1 - 2.0 * arc_half * 0.35)
		draw_arc(Vector2.ZERO, rr, b0, b1, 16, Color(hdr.r, hdr.g, hdr.b, 0.9 * fade), 2.5 - 0.5 * j)
