class_name CaptureUtil
extends RefCounted
## Enregistrement fiable des captures. Avec rendering/viewport/hdr_2d=true, l'image du viewport est
## linéaire : l'enregistrer telle quelle donne un PNG 2 à 3 fois trop sombre. On convertit en RGBA8
## puis on applique linear_to_srgb() quand le HDR 2D est actif.


## Lit l'image du viewport, la convertit en sRGB si besoin et l'enregistre en PNG. Retourne l'image
## enregistrée (ou null si le viewport n'a pas d'image) ; `path` vide = pas d'écriture.
static func save_viewport(vp: Viewport, path: String) -> Image:
	if vp == null:
		return null
	var img: Image = vp.get_texture().get_image()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	if bool(ProjectSettings.get_setting("rendering/viewport/hdr_2d", false)):
		img.linear_to_srgb()
	if path != "":
		img.save_png(path)
	return img
