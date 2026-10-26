class_name RaidFx
extends Node2D
## Visuels de la boîte à outils des boss façon raid (docs/Design_Boss_Raid.md §1).
## Chaque mécanique pose UN nœud visuel nommé « Visual » par objet, obtenu par RaidFx.visual(anim, kind) :
## - si la planche Codex `res://assets/sprites/vfx/raid/raid.tres` (consigne art/tools/night/_raid_kit.txt) contient
##   l'anim `anim`, c'est un AnimatedSprite2D (billboard ou sol selon l'anim) ;
## - sinon, une forme PROVISOIRE dessinée ici (CLAUDE.md : formes en code = placeholders temporaires).
## L'échange contre les rendus Blender ne touche donc que ce nœud. Toutes les formes sont non éclairées
## (light_mask 0, matériau unshaded) et ne sont redessinées que si un paramètre change (set_value / set_state).
## Couleurs (consigne du kit) : cyan = utile au joueur (teinté à l'accent du biome par le code), rouge = danger,
## blanc = neutre.

const FRAMES_PATH := "res://assets/sprites/vfx/raid/raid.tres"
const CYAN := Color(0.749, 0.957, 1.0) ## #BFF4FF
const DANGER := Color(0.878, 0.275, 0.235) ## #E0463C
const NEUTRAL := Color(1.0, 1.0, 1.0)
const STEEL := Color(0.62, 0.68, 0.74) ## bouclier (barre de boss, bulle)
const WARM := Color(1.0, 0.62, 0.25) ## fenêtre de vulnérabilité
## Groupe des objets de raid à signaler hors écran (OffscreenCues, catégorie `raid` à brancher côté UI).
const CUE_GROUP := &"raid_cues"

## Anims « sol » de la planche (vues de dessus : échelle 1, centrées) ; les autres sont des billboards (pied en bas).
const GROUND_ANIMS := [&"soak_zone", &"soak_fill", &"soak_burst", &"safe_sector", &"danger_sheet", &"sector_arrow",
	&"fixate_mark", &"fixate_link", &"shelter_shadow"]

enum Kind { ORB, BUBBLE, SOAK, SECTOR, FIXATE, LINK, WEAK, PYLON, SHADOW, ENRAGE, PROP, RING }

static var _frames: SpriteFrames = null
static var _frames_tried := false

var kind := Kind.ORB
var radius := 32.0 ## rayon (px logiques) ; LINK / SHADOW : longueur ; SECTOR : rayon de l'arène
var width := 64.0 ## SHADOW : largeur ; LINK : épaisseur
var color := CYAN
var value := 0.0 ## SOAK : remplissage 0..1 ; SECTOR : demi-angle (rad) ; PYLON : usure 0..2 ; FIXATE : 0 verrouillage / 1 verrouillé
var state := 0 ## WEAK : 0 gardé, 1 exposé ; BUBBLE : fissures 0..3 ; PROP : 0 éteint, 1 allumé
var _drawn_value := -1.0


## Planche du kit (null tant que Codex ne l'a pas livrée). Chargée une fois.
static func frames() -> SpriteFrames:
	if not _frames_tried:
		_frames_tried = true
		if ResourceLoader.exists(FRAMES_PATH):
			_frames = load(FRAMES_PATH) as SpriteFrames
	return _frames


## Le nœud visuel d'un objet : sprite du kit si l'anim existe, sinon forme provisoire `p_kind`.
static func visual(anim: StringName, p_kind: Kind, p_color: Color = CYAN, p_radius := 32.0) -> Node2D:
	var sf := frames()
	if sf != null and sf.has_animation(anim):
		var s := AnimatedSprite2D.new()
		s.name = &"Visual"
		s.sprite_frames = sf
		s.light_mask = 0
		s.material = EnemyTelegraph.unshaded_material()
		if anim == &"fixate_link" or anim == &"shelter_shadow": # bandes vers +x : départ à l'origine du nœud
			s.centered = false
			var tex0 := sf.get_frame_texture(anim, 0)
			if tex0 != null:
				s.offset = Vector2(0.0, -tex0.get_height() * 0.5)
		elif anim in GROUND_ANIMS:
			s.centered = true
		else: # billboard : pied au bas de la cellule (iso_rig), écrasement compensé
			s.scale = Iso.UNSQUASH * Iso.SPRITE_K
			var tex := sf.get_frame_texture(anim, 0)
			if tex != null:
				s.offset = Vector2(0.0, -tex.get_height() * 0.5)
		if p_color != CYAN and p_color != DANGER and p_color != NEUTRAL:
			s.modulate = p_color # teinte à l'accent du biome
		s.play(anim)
		return s
	var f := RaidFx.new()
	f.name = &"Visual"
	f.kind = p_kind
	f.color = p_color
	f.radius = p_radius
	f.light_mask = 0
	f.material = EnemyTelegraph.unshaded_material()
	return f


## Valeur affichée d'un visuel (jauge, usure…) : sprite -> frame (soak_fill : frame selon la progression),
## forme -> redessin seulement si la valeur a bougé de plus de 1/32.
static func set_value(v: Node, p: float) -> void:
	if v is RaidFx:
		var f := v as RaidFx
		f.value = p
		if absf(f._drawn_value - p) >= 1.0 / 32.0 or (p == 0.0) != (f._drawn_value == 0.0):
			f._drawn_value = p
			f.queue_redraw()
	elif v is AnimatedSprite2D:
		var s := v as AnimatedSprite2D
		if s.animation == &"soak_fill":
			var n := s.sprite_frames.get_frame_count(&"soak_fill")
			s.pause()
			s.frame = clampi(int(p * float(n - 1) + 0.5), 0, n - 1)


static func set_state(v: Node, st: int) -> void:
	if v is RaidFx and (v as RaidFx).state != st:
		(v as RaidFx).state = st
		(v as RaidFx).queue_redraw()
	elif v is AnimatedSprite2D:
		var s := v as AnimatedSprite2D
		# états multiples d'une même anim (weak_point, fixate_mark, shield_crack) : 6 frames par état
		var per := 6 if s.animation != &"shield_crack" else 4
		var n := s.sprite_frames.get_frame_count(s.animation)
		if n >= per * 2:
			s.frame = clampi(st * per, 0, n - 1)


## Son d'une mécanique (Audio.play, sans budget : événements rares).
static func sfx(id: StringName, pos: Vector2, vol_db := 0.0) -> void:
	Audio.play(id, pos, vol_db)


## Pose un visuel « sol » d'une mécanique immobile sous la couche des télégraphes (ni éclairé ni étalonné : lisible
## dans le noir des Cryptes), à la position de `mech` ; libéré avec `mech`. Repli (tests) : enfant de `mech`.
static func attach_ground(mech: Node2D, v: Node2D, z := -1) -> Node2D:
	v.z_index = z
	RecluseFx.add_to_tele_layer(v, mech)
	if v.get_parent() != mech:
		v.global_position = mech.global_position
	return v


func _draw() -> void:
	match kind:
		Kind.ORB:
			draw_circle(Vector2.ZERO, radius, Color(color, 0.25))
			draw_circle(Vector2(0, -radius * 0.9), radius * 0.6, Color(color, 0.9))
			draw_circle(Vector2(0, -radius * 0.9), radius * 0.3, Color.WHITE)
		Kind.BUBBLE:
			draw_arc(Vector2(0, -radius), radius, 0.0, TAU, 24, Color(STEEL, 0.75), 4.0)
			draw_circle(Vector2(0, -radius), radius, Color(STEEL, 0.12))
			for k in state: # fissures
				var a := TAU * (0.15 + 0.31 * k)
				draw_line(Vector2(0, -radius), Vector2(0, -radius) + Vector2.from_angle(a) * radius, Color.WHITE, 2.0)
		Kind.SOAK:
			RecluseFx.draw_disc(self, radius, Color(color, 0.12), Color(color, 0.95), 4.0)
			if value > 0.0:
				draw_circle(Vector2.ZERO, radius * clampf(value, 0.0, 1.0), Color(color, 0.35))
			draw_arc(Vector2.ZERO, radius * 0.35, -PI * 0.5, -PI * 0.5 + TAU * clampf(value, 0.0, 1.0), 24, Color.WHITE, 6.0)
		Kind.SECTOR: # disque rouge + coin sûr cyan (demi-angle `value`) vers +x : le nœud est tourné par le code
			draw_circle(Vector2.ZERO, radius, Color(DANGER, 0.22))
			var pts := PackedVector2Array([Vector2.ZERO])
			var steps := 16
			for k in steps + 1:
				pts.append(Vector2.from_angle(-value + 2.0 * value * k / steps) * radius)
			draw_colored_polygon(pts, Color(color, 0.35))
			pts.append(Vector2.ZERO)
			draw_polyline(pts, Color(color, 1.0), 4.0)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(DANGER, 0.9), 3.0)
		Kind.FIXATE:
			var c := NEUTRAL if value < 0.5 else DANGER
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, c, 4.0)
			var d := radius * 0.6
			draw_line(Vector2(-d, -d), Vector2(d, d), c, 5.0)
			draw_line(Vector2(-d, d), Vector2(d, -d), c, 5.0)
		Kind.LINK:
			var n := int(radius / 24.0)
			for k in n:
				draw_line(Vector2(k * 24.0, 0), Vector2(k * 24.0 + 12.0, 0), Color(NEUTRAL, 0.7), width)
		Kind.WEAK:
			var cw := color if state == 1 else Color(0.6, 0.6, 0.6)
			if state == 1:
				draw_circle(Vector2.ZERO, radius, Color(cw, 0.35))
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, cw, 4.0)
			else:
				for k in 12:
					draw_arc(Vector2.ZERO, radius, TAU * k / 12.0, TAU * (k + 0.5) / 12.0, 4, cw, 3.0)
		Kind.PYLON:
			var wear := clampi(int(value), 0, 2)
			var body := Color(0.32, 0.34, 0.38).lerp(Color(0.2, 0.18, 0.18), wear * 0.5)
			draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.35))
			draw_rect(Rect2(-radius * 0.45, -radius * 4.0, radius * 0.9, radius * 4.0), body)
			draw_circle(Vector2(0, -radius * 4.0), radius * 0.35, Color(color, 1.0 - wear * 0.35))
		Kind.SHADOW: # bande protégée vers +x (longueur radius, largeur width)
			draw_rect(Rect2(0.0, -width * 0.5, radius, width), Color(color, 0.3))
			draw_line(Vector2(0, -width * 0.5), Vector2(radius, -width * 0.5), Color(color, 0.8), 2.0)
			draw_line(Vector2(0, width * 0.5), Vector2(radius, width * 0.5), Color(color, 0.8), 2.0)
		Kind.ENRAGE:
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(DANGER, 0.85), 5.0)
		Kind.PROP:
			var cp := color if state == 1 else Color(0.45, 0.45, 0.5)
			draw_rect(Rect2(-radius * 0.4, -radius * 2.0, radius * 0.8, radius * 2.0), Color(0.25, 0.25, 0.28))
			draw_circle(Vector2(0, -radius * 2.0), radius * 0.45, cp)
		Kind.RING:
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, color, 5.0)
