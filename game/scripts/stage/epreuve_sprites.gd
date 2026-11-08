class_name EpreuveSprites
extends RefCounted
## Sprites Codex des objets du monde des Épreuves (docs/Design_Epreuves.md §9, lots EP-A..EP-E). Aide commune : charge une
## texture `res://assets/sprites/<dossier>/<fichier>` (style cel résolu), monte un billboard iso (échelle UNSQUASH, 64 px/u,
## pied à `base_y` de la hauteur du cadre) avec l'enfant d'émission `_e` quand il existe. Texture absente : retourne null et
## l'appelant garde sa forme de repli dessinée en code.

const PROPS_DIR := "res://assets/sprites/props/epreuve/"
const VFX_DIR := "res://assets/sprites/vfx/epreuve/"
const PX_PER_U := 64.0 ## tous les lots sont rendus à 1 u = 64 px (ortho = taille du cadre / 64)


static func tex(dir: String, file: String) -> Texture2D:
	var path := RenderStyle.resolve(dir + file)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Billboard iso prêt à l'emploi ; `hframes` > 1 : planche horizontale (frame réglée par l'appelant).
static func make(texture: Texture2D, base_y: float, hframes: int = 1) -> Sprite2D:
	if texture == null:
		return null
	var s := Sprite2D.new()
	s.texture = texture
	s.hframes = hframes
	s.scale = Iso.UNSQUASH * (Balance.UNIT_PX / PX_PER_U)
	s.offset = Vector2(0.0, -float(texture.get_height()) * (base_y - 0.5))
	return s


## Change la texture d'un billboard déjà monté et recale l'émission (enfant `_e` dépend de la texture).
static func set_tex(s: Sprite2D, texture: Texture2D, base_y: float, hframes: int = 1) -> void:
	if s == null or texture == null:
		return
	s.texture = texture
	s.hframes = hframes
	s.offset = Vector2(0.0, -float(texture.get_height()) * (base_y - 0.5))
	var em := s.get_node_or_null(NodePath(NormalMaps.EMISSION_NODE))
	if em != null:
		em.queue_free()
	NormalMaps.apply_to_sprite(s)


## Anneau au sol Codex (`ring_zone.png` / `ring_wave.png`, vue verticale, anneau à `ring_frac` du bord) dessiné sur l'overlay
## en repère carte (l'iso l'écrase). Retourne false si la texture manque : l'appelant trace alors son repli `draw_arc`.
static func draw_ring(c: CanvasItem, file: String, center: Vector2, radius: float, col: Color, ring_frac: float = 0.96) -> bool:
	var t := tex(VFX_DIR, file)
	if t == null:
		return false
	var half := radius / ring_frac
	c.draw_texture_rect(t, Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), false, col)
	return true


## Lumière de Poursuite (planche `chase_light_<skin>.png`, frames carrées) en billboard iso sur l'overlay ; false si absente.
static func draw_light(c: CanvasItem, skin: String, center: Vector2, size_px: float, alpha: float) -> bool:
	var t := tex(VFX_DIR, "chase_light_%s.png" % skin)
	if t == null:
		return false
	var fw := float(t.get_height())
	var fr := int(Time.get_ticks_msec() / 100) % maxi(int(t.get_width() / fw), 1)
	c.draw_set_transform(center, 0.0, Iso.UNSQUASH)
	c.draw_texture_rect_region(t, Rect2(-size_px * 0.5, -size_px * 0.5, size_px, size_px), Rect2(fr * fw, 0.0, fw, fw), Color(1, 1, 1, alpha))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


## Indice 0-7 (e, ne, n, nw, w, sw, s, se) de la direction à l'écran d'un cap exprimé dans le repère de la carte.
static func dir8(heading_map: Vector2) -> int:
	var logical := Iso.map_xform().basis_xform(heading_map)
	var a := Iso.to_screen_dir(logical).angle() # y vers le bas : e = 0, s = +90°
	return posmod(int(roundf(-a / (PI * 0.25))), 8)
