class_name TagIcons
extends RefCounted
## Pictos des étiquettes d'objets (Feu, Crit, Givre, Poison, Zone, Survie, Auto, Recharge), lot UX-G.
## Toujours accompagnés du texte « [Étiquette] » : l'icône aide le balayage visuel, elle ne remplace pas le mot
## (daltonisme, lecteurs d'écran). Sans fichier livré, `texture()` rend null et l'appelant garde le texte seul.

const DIR := "res://assets/sprites/ui/icons/tags/"
const TAGS: Array[String] = ["Feu", "Crit", "Givre", "Poison", "Zone", "Survie", "Auto", "Recharge"]


static func path(tag: String) -> String:
	return DIR + "tag_" + tag.to_lower() + ".png"


## Texture du picto de l'étiquette `tag`, null si absente (étiquette sans picto ou fichier non livré).
static func texture(tag: String) -> Texture2D:
	var p := path(tag)
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


## Rangée de pastilles carrées de `px` pixels pour `tags` (sans doublon, ordre conservé). Vide si aucun picto.
## Ignore la souris ; à placer par l'appelant.
static func row(tags: Array, px: float, tint := Color(0.78, 0.88, 1.0)) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.name = "TagIcons"
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 4)
	var seen := {}
	for raw in tags:
		var t := str(raw)
		if seen.has(t):
			continue
		seen[t] = true
		var tex := texture(t)
		if tex == null:
			continue
		var r := TextureRect.new()
		r.name = "Tag_" + t
		r.texture = tex
		r.tooltip_text = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(px, px)
		r.modulate = tint
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(r)
	return h
