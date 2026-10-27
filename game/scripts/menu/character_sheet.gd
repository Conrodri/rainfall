class_name CharacterSheet
extends PanelContainer
## Fiche d'un personnage en gros plan (Nouvelle run, refonte du 23/10/2026) : AUCUN défilement.
## Tiers gauche : le modèle animé en grand sur un fond sobre (halo de l'accent du personnage ; scène d'aperçu : au
## clic sur un sort, son animation d'action et son VFX sont joués sans ennemi ni dégâts).
## Deux tiers droits : en-tête (nom, style, difficulté en losanges, passif à droite), les 4 sorts en grille 2×2
## (icône, nom, rôle, chiffres discrets, dégâts « Niv. 1 : X · +Y/niv. » ; variantes sous le texte), puis UNE seule
## zone de détail (nom, type, description complète du sort survolé / choisi). Les infobulles (passif, variantes) sont
## ancrées sur le tiers gauche : elles ne masquent jamais la grille. Jamais de défilement.
## Placeholder : icône de variante manquante = icône du sort de base désaturée (§7).

signal option_chosen(slot: int, spell_id: StringName)
## Un sort vient d'être joué en aperçu (clic, tap, A) : slot et id de l'option jouée.
signal spell_previewed(slot: int, spell_id: StringName)

const VariantUnlocks := preload("res://scripts/save/variant_unlocks.gd")
const PASSIVE_BADGE := preload("res://scripts/ui/passive_badge.gd")

const ROLE_TEXT := {"auto": "Auto", "cd": "Recharge", "ultime": "Ultime"}
const LONG_PRESS_S := 0.45
const ICON_BASE := 76
const ICON_VARIANT := 46
const COL_ROLE := Color("#FFB347")
const COL_BODY := Color(0.9, 0.9, 0.93)
const COL_DIM := Color(0.62, 0.64, 0.68)
## Cadrage générique de l'aperçu animé : part de la hauteur de la scène remplie par le personnage, marge sous les
## pieds (fractions de la hauteur), largeur maximale. Aucune valeur par personnage.
const PREVIEW_FILL := 0.86
const PREVIEW_FOOT_MARGIN := 0.07
const PREVIEW_MAX_WIDTH := 0.96
const IDLE_ANIMS: Array[StringName] = [&"idle_s", &"idle_se", &"idle"]
## Anims d'action essayées (dans l'ordre, suffixe de direction `_s` / `_se` ou nue) pour l'aperçu d'un sort, par slot.
## Aucune trouvée = squash générique du sprite (jamais d'erreur).
const ACTION_ANIMS := {
	1: [&"attack", &"slash", &"swing", &"shoot", &"draw"],
	2: [&"cast", &"throw", &"wave", &"flare", &"loop", &"net"],
	3: [&"cast", &"slam", &"plant", &"net", &"throw"],
	4: [&"cast_ult", &"ult", &"cast", &"volley", &"summon", &"lift"],
}
const ACTION_DIRS: Array[String] = ["_s", "_se", ""]
const PREVIEW_MAX_S := 1.6 ## durée maximale d'un aperçu (anim d'action ou VFX bouclé), puis retour à l'attente
const SQUASH := 0.08
## Boîte englobante des pixels opaques de l'animation idle, par SpriteFrames + animation (calculée une fois).
static var _bbox_cache: Dictionary = {}

var profile: Object
var tooltip: SpellTooltip
var character: Dictionary = {}
var locked := false
## slot (1-4) -> id du sort choisi pour la run (base par défaut).
var chosen: Dictionary = {}
var preview: AnimatedSprite2D
## Scène d'aperçu (parent de `preview` et de la couche d'effets).
var preview_stage: Control
## Vrai si au moins une variante du personnage est débloquée (sinon les variantes sont masquées).
var show_variants := false
## Bouton du passif (focusable : manette / clavier) ; null si la fiche est verrouillée.
var passive_button: Button
## Slot du sort mis en avant (dernier sort joué en aperçu), 0 = aucun.
var selected_slot := 0
## Hauteur allouée par l'écran (NewRunScreen) : la fiche doit y tenir sans défiler (needs_scroll).
var allotted_h := 0.0
## Échelle de texte appliquée par _fit_text() (1 = tailles nominales).
var text_scale := 1.0

var _root: HBoxContainer ## colonne gauche (scène + détail) puis colonne droite
var _right: VBoxContainer
var _grid: GridContainer
var arena: SpellPreview ## aperçu de jeu (mini-arène) ; null = repli sur l'ancienne animation + VFX
var _arena_token := 0
var _fx: Node2D ## couche d'effets de l'aperçu (frames de VFX, projectile), vidée à chaque sort
var _rows: Array = [] ## par slot : {buttons, name, role, desc, stats, dmg, cell, spell}
var _detail_name: Label
var _detail_tag: Label
var _detail_desc: Label
var _detail_stats: Label
var _detail_dmg: Label
var _head_row: HBoxContainer
var _glow: TextureRect
var _floor: TextureRect
var _passive_labels: Array[Label] = []
var _spell_data: Dictionary = {} ## id -> SpellData
var _press_token := 0
var _play_token := 0
var _tween: Tween
var _squash: Tween
var _fit_token := 0
var _fit_key := Vector2.ZERO
var _slim := false ## dernier recours : chiffres des cases masqués (ils restent dans le panneau de gauche)
var _compact := false
var _shrink_desc := false ## dernier recours du fit : descriptions de cases sur une seule ligne
const TEXT_SCALES: Array[float] = [1.0, 0.94, 0.88, 0.82]
const ROW_FONTS := {"name": 28, "role": 24, "desc": 20, "stats": 20, "dmg": 22}
const DETAIL_FONTS := {"name": 32, "tag": 22, "desc": 22, "stats": 20, "dmg": 22}
const PASSIVE_FONTS := {"name": 26, "text": 20}
const COL_DMG := Color("#9BE29B")
const COL_STATS := Color(0.72, 0.74, 0.8)


func _init() -> void:
	# Grand panneau DA (panel_9slice, comme le coffre et le récap) ; repli : plaque plate.
	var da := UiTheme.da_box("panel_9slice", 0.5)
	add_theme_stylebox_override("panel", da if da != null else CharacterCard.panel_box(Color("#1a1620"), CharacterCard.COL_BORDER, 2, 0.9, false))
	mouse_filter = Control.MOUSE_FILTER_PASS
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	_root = HBoxContainer.new()
	_root.add_theme_constant_override("separation", 26)
	resized.connect(_on_resized)
	margin.add_child(_root)


## Remplit la fiche et la fait apparaître (fondu + glissement 0,18 s).
func open(c: Dictionary, is_locked: bool, animate := true) -> void:
	character = c
	locked = is_locked
	chosen.clear()
	_rows.clear()
	_passive_labels.clear()
	passive_button = null
	selected_slot = 0
	_play_token += 1
	_compact = false
	_slim = false
	text_scale = 1.0
	_spell_data = _load_spell_data(String(c.get("id", "")))
	_drop_arena()
	for ch in _root.get_children():
		_root.remove_child(ch)
		ch.queue_free()
	_build_identity()
	if locked:
		_build_locked()
	else:
		_build_kit()
	if tooltip != null:
		tooltip.hide_tip()
	var was_visible := visible
	visible = true
	_fit_text.call_deferred()
	_arena_token += 1
	_start_arena.call_deferred(_arena_token)
	if animate and is_inside_tree():
		if _tween != null:
			_tween.kill()
		modulate.a = 0.0
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(self, "modulate:a", 1.0, 0.18)
		if not was_visible: # fiche déjà affichée (changement de perso) : simple fondu, le panneau ne saute pas
			var y := position.y
			position.y = y + 24
			_tween.tween_property(self, "position:y", y, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		modulate.a = 1.0


## Libère l'aperçu de jeu (changement de perso, fiche masquée ou détruite).
func _drop_arena() -> void:
	_arena_token += 1
	if arena != null and is_instance_valid(arena):
		arena.shutdown()
	arena = null


## Démarre l'aperçu de jeu une fois la fiche en place ; en cas d'échec, l'ancienne animation reste affichée.
func _start_arena(token: int) -> void:
	if token != _arena_token or arena == null or not is_instance_valid(arena) or not visible:
		return
	arena.start(character, chosen)
	if not arena.ready_to_cast:
		return
	for n in [_glow, _floor, preview]:
		if n != null and is_instance_valid(n):
			n.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_drop_arena()


func _exit_tree() -> void:
	_drop_arena()


## Boutons d'options par slot (base puis variantes), pour le câblage du focus.
func focus_rows() -> Array:
	var out: Array = []
	for r in _rows:
		out.append(r.buttons)
	return out


func chosen_spells() -> Dictionary:
	return chosen.duplicate()


## Taille de police effective : base × échelle de fit × facteur tactile, jamais sous le plancher (18 px PC / 26 px mobile).
func _font(base: int, k := -1.0) -> int:
	var kk := text_scale if k < 0.0 else k
	var touch_k := 1.3 if _big_text() else 1.0
	return maxi(int(round(base * kk * touch_k)), _font_floor())


static func _big_text() -> bool:
	var loop := Engine.get_main_loop() as SceneTree
	var p := loop.root.get_node_or_null("Platform") if loop != null else null
	return p != null and (bool(p.call("is_touch_mode")) or bool(p.call("is_mobile")))


static func _font_floor() -> int:
	return 26 if _big_text() else CharacterCard.MIN_FONT


# --- Construction ------------------------------------------------------------

func _build_identity() -> void:
	# Tiers gauche : le modèle seul, en grand, sur un fond sombre sobre (aucune boîte) avec un halo de l'accent.
	var left := VBoxContainer.new()
	left.name = "Left"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	_root.add_child(left)
	var acc := CharacterCard.accent_color(character)
	var stage := Control.new()
	stage.name = "PreviewStage"
	stage.custom_minimum_size = Vector2(160, 200)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	bg.name = "Backdrop"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0.035, 0.03, 0.045, 0.62)
	bgs.set_corner_radius_all(20)
	bg.add_theme_stylebox_override("panel", bgs)
	stage.add_child(bg)
	_glow = _blob(Color(COL_DIM if locked else acc, 0.1 if locked else 0.2))
	_glow.name = "Glow"
	stage.add_child(_glow)
	_floor = _blob(Color(0.0, 0.0, 0.0, 0.6))
	_floor.name = "FloorShadow"
	stage.add_child(_floor)
	left.add_child(stage)
	preview_stage = stage
	if SpellPreview.supported(character, locked):
		arena = SpellPreview.new()
		arena.name = "SpellPreview"
		stage.add_child(arena)
		stage.move_child(arena, 1) # juste au-dessus du fond
	preview = null
	var sf_path := String(character.get("sprite_frames", ""))
	var sf: SpriteFrames = load(sf_path) if sf_path != "" and ResourceLoader.exists(sf_path) else null
	var anim := idle_anim(sf)
	if anim != &"":
		preview = AnimatedSprite2D.new()
		preview.name = "Preview"
		preview.sprite_frames = sf
		preview.centered = true
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if locked:
			preview.material = CharacterCard.grayscale_material(0.4)
		else:
			preview.modulate = Color(1.3, 1.25, 1.2) # modèle éclairé : les rendus bruts sont sombres sur ce fond
		stage.add_child(preview)
		preview.play(anim)
	else:
		var q := CharacterCard.make_label("?", 90, COL_DIM)
		q.set_anchors_preset(Control.PRESET_FULL_RECT)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stage.add_child(q)
	stage.resized.connect(_frame_preview)
	_frame_preview()
	_fx = Node2D.new()
	_fx.name = "Fx"
	stage.add_child(_fx)
	# Deux tiers droits : en-tête (nom, style, difficulté + passif), puis sorts et détail (_build_kit) ou message verrouillé.
	_right = VBoxContainer.new()
	_right.name = "Right"
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.size_flags_stretch_ratio = 2.0
	_right.add_theme_constant_override("separation", 10)
	_root.add_child(_right)
	_head_row = HBoxContainer.new()
	_head_row.name = "HeadRow"
	_head_row.add_theme_constant_override("separation", 24)
	_right.add_child(_head_row)
	var head := VBoxContainer.new()
	head.name = "Head"
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_theme_constant_override("separation", 2)
	_head_row.add_child(head)
	var name_row := HFlowContainer.new() # nom puis difficulté ; la difficulté passe dessous si la place manque
	name_row.name = "NameRow"
	name_row.add_theme_constant_override("h_separation", 24)
	name_row.add_theme_constant_override("v_separation", 0)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(name_row)
	var nm := CharacterCard.make_label(String(character.get("name", "?")), maxi(46, _font_floor()), COL_DIM if locked else CharacterCard.COL_TEXT)
	nm.name = "Name"
	nm.add_theme_font_override("font", UiTheme.title_font())
	name_row.add_child(nm)
	var title := String(character.get("title", ""))
	var style := String(character.get("style", ""))
	var sub_txt := ("%s · %s" % [title, style]) if title != "" else style
	var cfg_txt := String(character.get("config", ""))
	if cfg_txt != "":
		sub_txt += " · " + cfg_txt
	var sub := CharacterCard.make_label(sub_txt, _font(22, 1.0), COL_DIM if locked else acc.lerp(CharacterCard.COL_TEXT, 0.35), 4)
	sub.name = "Subtitle"
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(120, 0)
	head.add_child(sub)
	var lvl := CharacterCard.difficulty_of(character)
	if lvl > 0:
		# Même badge que sur la carte de la liste : 3 losanges pleins jusqu'au niveau + libellé coloré.
		var drow := HBoxContainer.new()
		drow.name = "DifficultyRow"
		drow.add_theme_constant_override("separation", 12)
		drow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drow.size_flags_vertical = Control.SIZE_SHRINK_END
		drow.add_child(CharacterCard.make_difficulty_badge(lvl, 28.0, true, _font(24, 1.0)))
		name_row.add_child(drow)


## Tache radiale douce (halo, ombre au sol) : dégradé de `col` vers transparent, étirée sur son rectangle.
static func _blob(col: Color) -> TextureRect:
	var g := Gradient.new()
	g.colors = PackedColorArray([col, Color(col, col.a * 0.5), Color(col, col.a * 0.15), Color(col, 0.0)]) # chute douce, sans bord visible
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# --- Cadrage de l'aperçu ----------------------------------------------------------

## Animation d'attente utilisée pour l'aperçu (direction s, sinon se), &"" si aucune.
static func idle_anim(sf: SpriteFrames) -> StringName:
	if sf == null:
		return &""
	for a in IDLE_ANIMS:
		if sf.has_animation(a) and sf.get_frame_count(a) > 0:
			return a
	return &""


## Boîte des pixels opaques (alpha > 0,1), union de toutes les frames de `anim` (le personnage respire :
## le cadre ne saute pas d'une frame à l'autre), en pixels de frame. Mise en cache par personnage.
## Image illisible (rendu factice en headless, export) : relecture du PNG source, sinon frame entière.
static func content_rect(sf: SpriteFrames, anim: StringName) -> Rect2:
	var key := "%s#%d::%s" % [sf.resource_path, sf.get_instance_id() if sf.resource_path == "" else 0, anim]
	if _bbox_cache.has(key):
		return _bbox_cache[key]
	var union := Rect2()
	var has := false
	var fsize := Vector2.ZERO
	var sources := {} ## chemin PNG -> Image (relecture du fichier, une seule fois)
	for i in sf.get_frame_count(anim):
		var tex := sf.get_frame_texture(anim, i)
		if tex == null:
			continue
		fsize = tex.get_size()
		var img := _frame_image(tex, sources)
		if img == null:
			continue
		var r := Rect2(img.get_used_rect())
		if r.size.x < 1.0 or r.size.y < 1.0:
			continue
		union = r if not has else union.merge(r)
		has = true
	if not has:
		union = Rect2(Vector2.ZERO, fsize)
	_bbox_cache[key] = union
	return union


## Image (non compressée) de la frame : l'atlas entier est lu une seule fois (`sources`), puis découpé à la
## région de la frame (AtlasTexture.get_image échoue sur un atlas compressé).
static func _frame_image(tex: Texture2D, sources: Dictionary) -> Image:
	var base: Texture2D = (tex as AtlasTexture).atlas if tex is AtlasTexture else tex
	if base == null:
		return null
	var key: Variant = base.resource_path if base.resource_path != "" else base.get_instance_id()
	if not sources.has(key):
		var full: Image = base.get_image()
		if (full == null or full.is_empty()) and base.resource_path != "" and FileAccess.file_exists(base.resource_path):
			full = Image.load_from_file(ProjectSettings.globalize_path(base.resource_path))
		if full != null and not full.is_empty():
			if full.is_compressed():
				full = full.duplicate()
				full.decompress()
			if full.is_compressed() or full.detect_alpha() == Image.ALPHA_NONE:
				full = null
		else:
			full = null
		sources[key] = full
	var img: Image = sources[key]
	if img == null:
		return null
	if tex is AtlasTexture:
		var reg := Rect2i((tex as AtlasTexture).region).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		return img.get_region(reg) if reg.has_area() else null
	return img


## Échelle et position (sprite centré) qui posent `content` (pixels de frame `frame_size`) dans `box` :
## PREVIEW_FILL de la hauteur, centré en x, pieds à PREVIEW_FOOT_MARGIN du bas ; largeur bornée.
static func fit_transform(content: Rect2, frame_size: Vector2, box: Vector2) -> Dictionary:
	var k := PREVIEW_FILL * box.y / maxf(content.size.y, 1.0)
	k = minf(k, PREVIEW_MAX_WIDTH * box.x / maxf(content.size.x, 1.0))
	var half := frame_size * 0.5
	var pos := Vector2(box.x * 0.5 - (content.get_center().x - half.x) * k,
		box.y * (1.0 - PREVIEW_FOOT_MARGIN) - (content.end.y - half.y) * k)
	return {"scale": k, "position": pos}


func _frame_preview() -> void:
	if preview_stage == null:
		return
	var box := preview_stage.size
	if box.x < 2.0 or box.y < 2.0:
		box = preview_stage.custom_minimum_size
	if _glow != null and is_instance_valid(_glow):
		_glow.size = Vector2(box.x * 1.0, box.y * 0.95)
		_glow.position = Vector2(box.x * 0.5 - _glow.size.x * 0.5, box.y * 0.56 - _glow.size.y * 0.5)
	if _floor != null and is_instance_valid(_floor):
		_floor.size = Vector2(box.x * 0.8, box.y * 0.12)
		_floor.position = Vector2(box.x * 0.5 - _floor.size.x * 0.5, box.y * (1.0 - PREVIEW_FOOT_MARGIN) - _floor.size.y * 0.5)
	if preview == null or preview.sprite_frames == null:
		return
	var anim := preview.animation
	var tex := preview.sprite_frames.get_frame_texture(anim, 0)
	if tex == null:
		return
	var t := fit_transform(content_rect(preview.sprite_frames, anim), tex.get_size(), box)
	preview.scale = Vector2.ONE * float(t.scale)
	preview.position = t.position


## Boîte opaque de l'aperçu dans le repère du disque (tests de cadrage) ; Rect2() sans aperçu.
func preview_content_rect() -> Rect2:
	if preview == null:
		return Rect2()
	var tex := preview.sprite_frames.get_frame_texture(preview.animation, 0)
	var c := content_rect(preview.sprite_frames, preview.animation)
	var k := preview.scale.x
	return Rect2(preview.position + (c.position - tex.get_size() * 0.5) * k, c.size * k)


func _build_locked() -> void:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	_right.add_child(v)
	v.add_child(CharacterCard.make_label("Personnage verrouillé", 44, CharacterCard.COL_TEXT))
	var obj := ""
	if bool(character.get("hidden", false)):
		obj = "Objectif caché"
	elif not bool(character.get("unlocked", false)):
		obj = "Objectif : " + String(character.get("unlock_text", ""))
	if obj != "":
		var l := CharacterCard.make_label(obj, 32, COL_ROLE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	v.add_child(CharacterCard.make_label("Bientôt disponible", 32, COL_DIM))
	if (character.get("spells", []) as Array).is_empty():
		v.add_child(CharacterCard.make_label("Kit dévoilé prochainement.", 26, COL_DIM))


func _build_kit() -> void:
	var spells: Array = character.get("spells", [])
	if spells.is_empty():
		# Personnage ouvert dont le kit n'est pas encore décrit dans characters.json.
		var l := CharacterCard.make_label("Kit en préparation : les sorts apparaîtront ici.", 28, COL_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_right.add_child(l)
		return
	_build_passive()
	_grid = GridContainer.new()
	_grid.name = "Spells"
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_right.add_child(_grid)
	# Variantes masquées tant qu'aucune n'est débloquée (audit M8, divulgation progressive) : une seule ligne
	# de rappel ; dès qu'une variante du personnage est débloquée, toutes ses variantes apparaissent.
	show_variants = false
	var variant_count := 0
	for s in spells:
		for v in (s as Dictionary).get("variants", []):
			variant_count += 1
			if CharacterCard.is_variant_unlocked(profile, v):
				show_variants = true
	for i in spells.size():
		_grid.add_child(_build_row(i + 1, spells[i]))
	# Choix mémorisé pour ce personnage (Profile.loadout), seulement les variantes encore débloquées.
	var saved := resolve_loadout(profile, character)
	for r in _rows:
		var slot: int = r.buttons[0].get_meta("slot")
		if saved.has(slot) and saved[slot] != chosen.get(slot, &""):
			chosen[slot] = saved[slot]
			_refresh_row(r)
	if not show_variants and variant_count > 0:
		# Rappel sous le modèle (le tiers gauche a de la place ; la colonne droite est comptée au pixel).
		var note := CharacterCard.make_label("%d variante%s de sorts à débloquer en jouant" % [variant_count, "s" if variant_count > 1 else ""], _font_floor(), COL_DIM, 4)
		note.name = "VariantsNote"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.custom_minimum_size = Vector2(120, 0)
		(_root.get_node("Left") as VBoxContainer).add_child(note)
	_build_detail()
	_show_detail(1, _option_for_slot(1))


## Passif du personnage, à droite de l'en-tête : icône (bouton focusable, même taille et même style qu'une icône de
## sort) + résumé ; infobulle complète (ancrée sur le tiers gauche) au survol / focus / appui long.
func _build_passive() -> void:
	var info: Dictionary = PASSIVE_BADGE.info_for(StringName(String(character.get("id", ""))))
	if info.is_empty() or _head_row == null:
		return
	var box := PanelContainer.new()
	box.name = "Passive"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_stretch_ratio = 1.5
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_theme_stylebox_override("panel", _cell_box(false))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	box.add_child(h)
	var b := Button.new()
	b.name = "PassiveButton"
	b.custom_minimum_size = Vector2(ICON_BASE + 14, ICON_BASE + 14)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("focus", CharacterCard.focus_box())
	var pbox := _cell_box(false)
	if pbox is StyleBoxTexture:
		UiTheme.pad_box(pbox, 44)
	box.add_theme_stylebox_override("panel", pbox)
	var sb := CharacterCard.panel_box(Color("#1a1620"), Color(0.35, 0.38, 0.45), 1, 0.8, false) # = icône de sort non choisie
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	var tex: Texture2D = PASSIVE_BADGE.icon_for(info)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size = Vector2(ICON_BASE, ICON_BASE)
		tr.position = Vector2(7, 7)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tr)
	else: # placeholder en code : initiale du passif (remplacée par l'icône Codex)
		b.text = String(info.get("name", "?")).substr(0, 1).to_upper()
		b.add_theme_font_size_override("font_size", 44)
		var ac := CharacterCard.accent_color(character)
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(cn, ac)
	b.pressed.connect(_show_passive_tip.bind(b))
	b.focus_entered.connect(_show_passive_tip.bind(b))
	b.mouse_entered.connect(_show_passive_tip.bind(b))
	b.focus_exited.connect(_hide_tip_for.bind(b))
	b.mouse_exited.connect(_on_mouse_left.bind(b))
	b.gui_input.connect(_on_passive_input.bind(b))
	b.set_meta("info", info)
	h.add_child(b)
	passive_button = b
	var txt := VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	txt.add_theme_constant_override("separation", 0)
	h.add_child(txt)
	var nm := CharacterCard.make_label("Passif · " + String(info.get("name", "")), PASSIVE_FONTS.name, COL_ROLE)
	nm.name = "PassiveName"
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(60, 0)
	txt.add_child(nm)
	var summary := CharacterCard.make_label(String(info.get("intro", info.get("desc", ""))), PASSIVE_FONTS.text, COL_BODY, 4)
	summary.name = "PassiveText"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.max_lines_visible = 3
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.custom_minimum_size = Vector2(60, 0)
	txt.add_child(summary)
	_passive_labels = [nm, summary]
	_head_row.add_child(box)


## Zone de détail UNIQUE (bas de la colonne droite) : sort survolé / focalisé / joué, description complète.
## Sa hauteur est réservée pour le plus long texte du kit (_reserve_detail) : rien ne saute au survol.
func _build_detail() -> void:
	var box := PanelContainer.new()
	box.name = "Detail"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", _cell_box(false))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	v.add_child(top)
	_detail_name = CharacterCard.make_label("", DETAIL_FONTS.name, CharacterCard.COL_TEXT)
	_detail_name.name = "DetailName"
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_name.custom_minimum_size = Vector2(120, 0)
	_detail_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_detail_name)
	_detail_tag = CharacterCard.make_label("", DETAIL_FONTS.tag, COL_ROLE, 4)
	_detail_tag.name = "DetailTag"
	_detail_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_detail_tag)
	_detail_desc = CharacterCard.make_label("", DETAIL_FONTS.desc, COL_BODY, 4)
	_detail_desc.name = "DetailDesc"
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.custom_minimum_size = Vector2(120, 0)
	v.add_child(_detail_desc)
	_detail_stats = CharacterCard.make_label("", DETAIL_FONTS.stats, COL_STATS, 4)
	_detail_stats.name = "DetailStats"
	_detail_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_stats.custom_minimum_size = Vector2(120, 0)
	v.add_child(_detail_stats)
	_detail_dmg = CharacterCard.make_label("", DETAIL_FONTS.dmg, COL_DMG, 4)
	_detail_dmg.name = "DetailDamage"
	_detail_dmg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_dmg.custom_minimum_size = Vector2(120, 0)
	v.add_child(_detail_dmg)
	_right.add_child(box)


func _cell_box(selected: bool) -> StyleBox:
	var sb := CharacterCard.panel_box(CharacterCard.COL_PANEL, CharacterCard.COL_FOCUS if selected else Color(0.35, 0.38, 0.45), 3 if selected else 1, 0.7)
	if sb is StyleBoxTexture:
		UiTheme.pad_box(sb, 44) # le texte ne touche pas le trait du cadre
		if selected:
			(sb as StyleBoxTexture).modulate_color = Color(1.0, 0.85, 0.55)
	return sb


func _build_row(slot: int, spell: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.name = "Spell%d" % slot
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", _cell_box(false))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	box.add_child(h)
	var row := {"spell": spell, "buttons": [], "cell": box}
	var base_id := StringName(spell.get("id", ""))
	var base_icon := ArdentKit.spell_icon(base_id)
	var base_btn := _option_button(ICON_BASE, base_icon, false, null)
	base_btn.set_meta("slot", slot)
	base_btn.set_meta("option", spell)
	base_btn.set_meta("is_base", true)
	base_btn.name = "Base_" + String(base_id)
	base_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(base_btn)
	row.buttons.append(base_btn)

	var txt := VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.add_theme_constant_override("separation", 0)
	h.add_child(txt)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	txt.add_child(head)
	# Hiérarchie : nom + type en haut, chiffres discrets, dégâts en vert ; la description complète est dans la zone de détail.
	row.name = CharacterCard.make_label("", ROW_FONTS.name)
	row.name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # nom long + rôle sur un panneau étroit : retour à la ligne
	row.name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.name.custom_minimum_size = Vector2(60, 0)
	head.add_child(row.name)
	# « role » facultatif dans characters.json (Averse : « 20 d'eau ») remplace le type par défaut (« Recharge »)
	row.role = CharacterCard.make_label(String(spell.get("role", ROLE_TEXT.get(String(spell.get("slot", "")), ""))), ROW_FONTS.role, COL_ROLE)
	row.role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(row.role)
	row.desc = _short_label(ROW_FONTS.desc, COL_BODY, 2)
	row.desc.visible = false # description complète = zone de détail (plus de texte tronqué dans les cases)
	txt.add_child(row.desc)
	row.stats = _short_label(ROW_FONTS.stats, COL_STATS, 3)
	txt.add_child(row.stats)
	row.dmg = _short_label(ROW_FONTS.dmg, COL_DMG, 1)
	txt.add_child(row.dmg)
	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 6)
	txt.add_child(vrow)

	var variants: Array = spell.get("variants", []) if show_variants else []
	for v in variants:
		var vid := StringName(v.get("id", ""))
		var vlocked := not CharacterCard.is_variant_unlocked(profile, v)
		var icon := ArdentKit.spell_icon(vid)
		var placeholder := icon == null
		if placeholder:
			icon = base_icon # placeholder : icône de base désaturée
		var b := _option_button(ICON_VARIANT, icon, vlocked or placeholder, v)
		b.set_meta("slot", slot)
		b.set_meta("option", v)
		b.set_meta("is_base", false)
		b.set_meta("locked", vlocked)
		b.name = "Variant_" + String(vid)
		vrow.add_child(b)
		row.buttons.append(b)
	chosen[slot] = base_id
	_refresh_row(row)
	_rows.append(row)
	return box


## Libellé de case : retour à la ligne, `lines` lignes au plus (ellipse), le détail complet est dans le panneau de gauche.
func _short_label(font_size: int, col: Color, lines: int) -> Label:
	var l := CharacterCard.make_label("", font_size, col, 4)
	l.add_theme_constant_override("line_spacing", 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = lines
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(60, 0)
	return l


func _option_button(icon_size: int, icon: Texture2D, gray: bool, _variant: Variant) -> Button:
	var b := Button.new()
	var side := icon_size + 14
	b.custom_minimum_size = Vector2(side, side)
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("focus", CharacterCard.focus_box())
	var tr := TextureRect.new()
	tr.texture = icon
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size = Vector2(icon_size, icon_size)
	tr.position = Vector2((side - icon_size) * 0.5, (side - icon_size) * 0.5)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if gray:
		tr.material = CharacterCard.grayscale_material(0.5)
	b.add_child(tr)
	if icon == null:
		b.text = "?"
	b.pressed.connect(_on_option_pressed.bind(b))
	b.focus_entered.connect(_on_option_hover.bind(b))
	b.mouse_entered.connect(_on_option_hover.bind(b))
	b.focus_exited.connect(_on_option_unhover.bind(b))
	b.mouse_exited.connect(_on_mouse_left.bind(b))
	b.gui_input.connect(_on_option_input.bind(b))
	return b


func _refresh_row(row: Dictionary) -> void:
	var slot: int = row.buttons[0].get_meta("slot")
	var cur: StringName = chosen.get(slot, &"")
	var opt: Dictionary = row.spell
	for b in row.buttons:
		var o: Dictionary = b.get_meta("option")
		var is_cur := StringName(o.get("id", "")) == cur
		if is_cur:
			opt = o
		var border := CharacterCard.COL_FOCUS if is_cur else Color(0.35, 0.38, 0.45)
		var sb := CharacterCard.panel_box(Color("#1a1620"), border, 4 if is_cur else 1, 0.8, false)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		if bool(b.get_meta("locked", false)) and b.get_node_or_null("Lock") == null:
			_add_lock_badge(b)
	row.name.text = String(opt.get("name", ""))
	row.desc.text = String(opt.get("desc", ""))
	var sd: SpellData = _spell_data.get(StringName(opt.get("id", "")))
	row.stats.text = spell_stats_text(sd) if sd != null else ""
	row.stats.visible = row.stats.text != "" and not _slim
	row.dmg.text = scaling_text(sd, true) if sd != null else ""
	row.dmg.visible = row.dmg.text != "" and not _slim
	if _detail_name != null and selected_slot == slot:
		_show_detail(slot, opt)


## Option (base ou variante) actuellement choisie pour `slot`, {} sinon.
func _option_for_slot(slot: int) -> Dictionary:
	for r in _rows:
		if int(r.buttons[0].get_meta("slot")) != slot:
			continue
		for b in r.buttons:
			var o: Dictionary = b.get_meta("option")
			if StringName(o.get("id", "")) == chosen.get(slot, &""):
				return o
		return r.spell
	return {}


## Zone de détail : nom, type, description COMPLÈTE, chiffres et scaling de dégâts de l'option `o` du `slot`.
func _show_detail(slot: int, o: Dictionary) -> void:
	if _detail_name == null or o.is_empty():
		return
	var spells: Array = character.get("spells", [])
	var sp: Dictionary = spells[slot - 1] if slot >= 1 and slot <= spells.size() else {}
	var sd: SpellData = _spell_data.get(StringName(o.get("id", "")))
	var role := String(sp.get("role", ROLE_TEXT.get(String(sp.get("slot", "")), "")))
	_detail_name.text = String(o.get("name", ""))
	_detail_tag.text = "Sort %d · %s" % [slot, role] if role != "" else "Sort %d" % slot
	_detail_desc.text = String(o.get("desc", ""))
	_detail_stats.text = "" # chiffres de portée / recharge : déjà dans la case du sort (pas de doublon)
	_detail_dmg.text = scaling_text(sd, false) if sd != null else ""


## Dégâts d'un sort au niveau 1 et par niveau, depuis le coef du sort et Balance.player_base_damage (même base que le jeu).
static func scaling_text(sd: SpellData, short: bool) -> String:
	if sd == null or sd.coef <= 0.0:
		return ""
	var d1 := sd.coef * Balance.player_base_damage(1)
	var per := sd.coef * (Balance.player_base_damage(2) - Balance.player_base_damage(1))
	if short:
		return "Niv. 1 : %s · +%s/niv." % [CharacterCard.fmt_num(snappedf(d1, 0.1)), CharacterCard.fmt_num(snappedf(per, 0.1))]
	return "Dégâts : %s %% du dégât de base + bonus d'objets" % CharacterCard.fmt_num(snappedf(sd.coef * 100.0, 0.1))


## Met en avant les cases : bordure du sort `selected_slot`.
func _highlight() -> void:
	for r in _rows:
		var cell := r.get("cell") as PanelContainer
		if cell != null:
			cell.add_theme_stylebox_override("panel", _cell_box(int(r.buttons[0].get_meta("slot")) == selected_slot))


## Cadenas sur une variante verrouillée : `ui/menu/icon_lock.png` (§7) ou libellé en attendant.
func _add_lock_badge(b: Button) -> void:
	var side := b.custom_minimum_size.x
	# Icône (ou placeholder en formes) dans le coin bas-droit ; plus de libellé « Verrou » en 16 px.
	var lk := CharacterCard.make_lock_icon(36.0, CharacterCard.COL_FOCUS)
	lk.name = "Lock"
	lk.position = Vector2(side - 38, side - 38)
	b.add_child(lk)


# --- Interaction ---------------------------------------------------------------

func _on_option_pressed(b: Button) -> void:
	var o: Dictionary = b.get_meta("option")
	var slot: int = b.get_meta("slot")
	if bool(b.get_meta("locked", false)):
		CharacterCard.play_ui(&"ui.click", -8.0, 0.7)
		return
	chosen[slot] = StringName(o.get("id", ""))
	for r in _rows:
		if r.buttons.has(b):
			_refresh_row(r)
	option_chosen.emit(slot, chosen[slot])
	preview_spell(slot, o)
	# l'infobulle vient du survol / du focus / de l'appui long, jamais du clic : on rafraîchit seulement son état
	if tooltip != null and tooltip.visible and tooltip.anchor_control == b:
		_show_tip(b)


func _on_option_hover(b: Button) -> void:
	_show_detail(int(b.get_meta("slot")), b.get_meta("option"))
	if bool(b.get_meta("is_base", false)):
		if tooltip != null:
			tooltip.hide_tip()
		return
	_show_tip(b)


func _on_option_unhover(b: Button) -> void:
	if tooltip == null:
		return
	# Au focus clavier/manette, l'infobulle suit le focus ; à la souris elle suit le survol.
	if b.has_focus() and not _is_touch():
		return
	if _is_touch():
		return # tactile : reste affichée jusqu'au prochain appui
	tooltip.hide_tip(b)


func _on_option_input(ev: InputEvent, b: Button) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_press_token += 1
			var tok := _press_token
			if tooltip != null and tooltip.anchor_control != b:
				tooltip.hide_tip()
			get_tree().create_timer(LONG_PRESS_S, true).timeout.connect(func() -> void:
				if tok == _press_token and is_instance_valid(b):
					_show_tip(b))
		else:
			_press_token += 1


func _show_tip(b: Button) -> void:
	if tooltip == null or bool(b.get_meta("is_base", false)):
		return
	var o: Dictionary = b.get_meta("option")
	if bool(b.get_meta("locked", false)):
		tooltip.show_for(b, String(o.get("name", "")), "Quête de déblocage", variant_quest(profile, character, b.get_meta("slot"), o), _tip_area())
	else:
		var slot: int = b.get_meta("slot")
		var sel: bool = StringName(o.get("id", "")) == chosen.get(slot, &"")
		tooltip.show_for(b, String(o.get("name", "")), "Sélectionnée pour la run" if sel else "Débloquée · appuyer pour choisir", String(o.get("desc", "")), _tip_area())


## Infobulle du passif (survol, focus, appui long) : explication complète, chiffres lus dans le kit.
func _show_passive_tip(b: Button) -> void:
	if tooltip == null or not is_instance_valid(b):
		return
	var info: Dictionary = b.get_meta("info", {})
	tooltip.show_for(b, "Passif · " + String(info.get("name", "")), "", String(info.get("desc", "")), _tip_area())


## Zone à ne jamais recouvrir par les infobulles : le tiers gauche (aperçu animé des sorts). La bulle se pose près
## du bouton, hors de cette zone (le contrôle, pas son rectangle : la taille n'est pas fixée à l'ouverture de la fiche).
func _tip_area() -> Control:
	return preview_stage if preview_stage != null and is_instance_valid(preview_stage) else null


## La souris quitte un bouton : l'infobulle part avec elle, même si le clic lui a donné le focus.
func _on_mouse_left(b: Button) -> void:
	if tooltip != null and not _is_touch():
		tooltip.hide_tip(b)


func _hide_tip_for(b: Button) -> void:
	if tooltip != null and not _is_touch() and not b.has_focus():
		tooltip.hide_tip(b)


func _on_passive_input(ev: InputEvent, b: Button) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_press_token += 1
			var tok := _press_token
			get_tree().create_timer(LONG_PRESS_S, true).timeout.connect(func() -> void:
				if tok == _press_token and is_instance_valid(b):
					_show_passive_tip(b))
		else:
			_press_token += 1


# --- Aperçu d'un sort sur le modèle -------------------------------------------------

## Joue le sort `o` du `slot` sur le modèle : anim d'action du personnage (attack / cast / cast_ult… selon le slot),
## puis VFX du sort s'il existe (zone ou projectile) dans la scène d'aperçu. Ni ennemi ni dégâts. Sans anim ni VFX,
## repli propre : léger squash du sprite. Les effets précédents sont libérés avant (aucune fuite de nœuds).
func preview_spell(slot: int, o: Dictionary) -> void:
	selected_slot = slot
	_highlight()
	_show_detail(slot, o)
	_play_token += 1
	var tok := _play_token
	_clear_fx()
	var sd: SpellData = _spell_data.get(StringName(o.get("id", "")))
	if arena != null and is_instance_valid(arena) and arena.ready_to_cast and arena.play(slot, chosen):
		spell_previewed.emit(slot, StringName(o.get("id", "")))
		return
	var t := _play_action(slot)
	var tv := _play_vfx(sd)
	if is_inside_tree():
		var back := minf(maxf(t, tv), PREVIEW_MAX_S)
		get_tree().create_timer(back, true).timeout.connect(_back_to_idle.bind(tok))
	spell_previewed.emit(slot, StringName(o.get("id", "")))


func _clear_fx() -> void:
	if _fx == null:
		return
	for ch in _fx.get_children():
		_fx.remove_child(ch)
		ch.queue_free()


## Anim d'action du modèle pour ce slot ; retourne sa durée (s) ou celle du squash de repli.
func _play_action(slot: int) -> float:
	if preview == null or preview.sprite_frames == null:
		return 0.0
	var sf := preview.sprite_frames
	var anim := action_anim(sf, slot)
	if _squash != null:
		_squash.kill()
	_frame_preview()
	if anim != &"":
		preview.play(anim)
		var fps := sf.get_animation_speed(anim)
		var total := 0.0
		for i in sf.get_frame_count(anim):
			total += sf.get_frame_duration(anim, i)
		return total / fps if fps > 0.0 else 0.3
	# repli générique : squash du sprite (anim d'action absente)
	var k := preview.scale
	_squash = create_tween()
	_squash.tween_property(preview, "scale", Vector2(k.x * (1.0 + SQUASH), k.y * (1.0 - SQUASH)), 0.08)
	_squash.tween_property(preview, "scale", k, 0.14)
	return 0.3


## Anim d'action à jouer pour un slot (suffixes de direction essayés), &"" si le modèle n'en a aucune.
static func action_anim(sf: SpriteFrames, slot: int) -> StringName:
	if sf == null:
		return &""
	for name: StringName in ACTION_ANIMS.get(slot, []):
		for suf in ACTION_DIRS:
			var a := StringName(String(name) + suf)
			if sf.has_animation(a) and sf.get_frame_count(a) > 0:
				return a
	return &""


## VFX du sort dans la scène d'aperçu (zone : frames `vfx_frames` à l'échelle du rayon du sort ; sinon projectile
## qui traverse la scène). Retourne sa durée (s), 0 sans VFX.
func _play_vfx(sd: SpellData) -> float:
	if sd == null or _fx == null or preview_stage == null:
		return 0.0
	var path := sd.vfx_frames if sd.vfx_frames != "" else sd.projectile_frames
	if path == "" or not ResourceLoader.exists(path):
		return 0.0
	var frames := load(path) as SpriteFrames
	if frames == null:
		return 0.0
	var anim: StringName = &"default" if frames.has_animation(&"default") else &""
	if anim == &"":
		var names := frames.get_animation_names()
		if names.is_empty():
			return 0.0
		anim = StringName(names[0])
	if frames.get_frame_count(anim) == 0:
		return 0.0
	var box := preview_stage.size
	var cr := preview_content_rect()
	var center := cr.get_center() if cr.size.x > 0.0 else box * 0.5
	var px_u := maxf(cr.size.y if cr.size.y > 0.0 else box.y * 0.7, 1.0) # 1 u = hauteur du personnage
	var tex := frames.get_frame_texture(anim, 0)
	var fsize := tex.get_size() if tex != null else Vector2(128, 128)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = frames
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.position = center
	if sd.vfx_additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		spr.material = mat
	var dur := 0.0
	var fps := frames.get_animation_speed(anim)
	for i in frames.get_frame_count(anim):
		dur += frames.get_frame_duration(anim, i)
	dur = dur / fps if fps > 0.0 else 0.5
	if sd.vfx_frames != "":
		var s := (sd.radius_u * px_u / sd.vfx_radius_px) if (sd.radius_u > 0.0 and sd.vfx_radius_px > 0.0) else (px_u * 2.5 / maxf(fsize.x, 1.0))
		s = minf(s, box.x * 1.1 / maxf(fsize.x, 1.0))
		var aspect := sd.vfx_floor_aspect if sd.vfx_radius_px > 0.0 else 1.0
		spr.scale = Vector2(s, s * aspect)
		_fx.add_child(spr)
		spr.play(anim)
		get_tree().create_timer(minf(dur, PREVIEW_MAX_S), true).timeout.connect(_free_fx.bind(spr))
	else: # projectile : traverse la scène vers la droite
		var s2 := px_u * 0.6 / maxf(fsize.y, 1.0)
		spr.scale = Vector2.ONE * s2
		_fx.add_child(spr)
		spr.play(anim)
		var tw := spr.create_tween()
		tw.tween_property(spr, "position", Vector2(box.x * 0.98, center.y), 0.5)
		tw.tween_callback(_free_fx.bind(spr))
		dur = 0.5
	return dur


func _free_fx(n: Variant) -> void:
	if is_instance_valid(n) and (n as Node).get_parent() != null:
		(n as Node).get_parent().remove_child(n)
		(n as Node).queue_free()


func _back_to_idle(tok: int) -> void:
	if tok != _play_token or preview == null or not is_instance_valid(preview) or preview.sprite_frames == null:
		return
	var a := idle_anim(preview.sprite_frames)
	if a != &"" and preview.animation != a:
		preview.play(a)


static func _is_touch() -> bool:
	var loop := Engine.get_main_loop() as SceneTree
	var p := loop.root.get_node_or_null("Platform") if loop != null else null
	return p != null and bool(p.call("is_touch_mode"))


# --- Ajustement du texte ----------------------------------------------------------

## Réduit le texte (TEXT_SCALES, puis descriptions de cases sur une ligne) jusqu'à ce que la fiche tienne dans la
## hauteur allouée : jamais de défilement. Les libellés retournent à la ligne (autowrap) ; rien ne déborde.
func _fit_text() -> void:
	_fit_token += 1
	var tok := _fit_token
	if not is_inside_tree():
		return
	_fit_key = Vector2(size.x, allotted_h)
	await get_tree().process_frame # largeurs de libellés connues avant de réserver la hauteur du détail
	if tok != _fit_token or not is_instance_valid(self):
		return
	var steps: Array = []
	for k in TEXT_SCALES:
		steps.append([k, false, false])
	var kmin: float = TEXT_SCALES[TEXT_SCALES.size() - 1]
	steps.append([kmin, true, false]) # descriptions de cases sur une ligne
	steps.append([kmin, true, true, false]) # puis icônes plus petites
	steps.append([kmin, true, true, true]) # enfin, chiffres des cases masqués
	for st in steps:
		_shrink_desc = st[1]
		_set_compact(st[2])
		_set_slim(st.size() > 3 and st[3])
		_apply_text_scale(st[0])
		_reserve_detail()
		await get_tree().process_frame
		await get_tree().process_frame
		if tok != _fit_token or not is_instance_valid(self):
			return
		if not needs_scroll():
			return


## Réserve la hauteur du plus long texte de détail du kit (toutes les options : base et variantes), à la largeur
## courante : changer de sort ne fait ni sauter ni déborder la fiche.
func _reserve_detail() -> void:
	if _detail_desc == null:
		return
	var w := _detail_desc.size.x
	if w < 80.0:
		w = maxf(size.x * 0.5, 240.0)
	var hd := 0.0
	var hs := 0.0
	var hg := 0.0
	for r in _rows:
		for b in r.buttons:
			var o: Dictionary = b.get_meta("option")
			var sd: SpellData = _spell_data.get(StringName(o.get("id", "")))
			hd = maxf(hd, _text_h(_detail_desc, String(o.get("desc", "")), w))
			if sd != null:
				hg = maxf(hg, _text_h(_detail_dmg, scaling_text(sd, false), w))
	_detail_desc.custom_minimum_size.y = hd
	_detail_stats.custom_minimum_size.y = hs
	_detail_stats.visible = hs > 0.0
	_detail_dmg.custom_minimum_size.y = hg
	_detail_dmg.visible = hg > 0.0


static func _text_h(l: Label, t: String, w: float) -> float:
	if t == "":
		return 0.0
	var f := l.get_theme_font(&"font")
	var fs := l.get_theme_font_size(&"font_size")
	return f.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, TextServer.BREAK_WORD_BOUND | TextServer.BREAK_MANDATORY).y + 4.0


func _set_slim(on: bool) -> void:
	if on == _slim:
		return
	_slim = on
	# Dernier recours de hauteur : en-tête resserré (résumé du passif masqué, il reste dans l'infobulle ; sous-titre
	# sur 2 lignes ; nom plus petit) en plus des chiffres des cases.
	if _passive_labels.size() == 2 and _passive_labels[1].get_parent() != null:
		_passive_labels[1].visible = not on
		var pbox := _passive_labels[1].get_parent().get_parent().get_parent() as Control
		pbox.size_flags_stretch_ratio = 0.7 if on else 1.5
	var head := _head_row.get_node_or_null("Head") if _head_row != null else null
	if head != null:
		var sub := head.get_node_or_null("Subtitle") as Label
		if sub != null:
			sub.max_lines_visible = 2 if on else -1
			sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if on else TextServer.OVERRUN_NO_TRIMMING
		var nmr := head.find_child("Name", true, false) as Label
		if nmr != null:
			nmr.add_theme_font_size_override("font_size", maxi(38 if on else 46, _font_floor()))
	for r in _rows:
		r.stats.visible = r.stats.text != "" and not on
		r.dmg.visible = r.dmg.text != "" and not on


## Dernier recours du fit : icônes de sort réduites (base et variantes) pour gagner de la hauteur.
func _set_compact(on: bool) -> void:
	if on == _compact:
		return
	_compact = on
	if preview_stage != null:
		preview_stage.custom_minimum_size.y = 100.0 if on else 200.0
	for r in _rows:
		for b in r.buttons:
			var is_base: bool = bool(b.get_meta("is_base", false))
			var icon_px: int = (ICON_BASE if is_base else ICON_VARIANT) - (16 if on else 0)
			var side := icon_px + 14
			b.custom_minimum_size = Vector2(side, side)
			var tr := b.get_child(0) as TextureRect
			if tr != null:
				tr.size = Vector2(icon_px, icon_px)
				tr.position = Vector2((side - icon_px) * 0.5, (side - icon_px) * 0.5)
			var lk := b.get_node_or_null("Lock") as Control
			if lk != null:
				lk.position = Vector2(side - 38, side - 38)


func _on_resized() -> void:
	# Le fit change la hauteur minimale donc la taille de la fiche : on ne le relance que si la largeur ou la
	# hauteur allouée ont changé (sinon boucle infinie de paliers).
	var key := Vector2(size.x, allotted_h)
	if key == _fit_key:
		return
	_fit_key = key
	if visible and not _rows.is_empty():
		_fit_text.call_deferred()


func _apply_text_scale(k: float) -> void:
	text_scale = k
	for r in _rows:
		for key in ROW_FONTS:
			var l: Label = r.get(key)
			if l != null:
				l.add_theme_font_size_override("font_size", _font(ROW_FONTS[key], k))
		(r.stats as Label).max_lines_visible = 2 if _shrink_desc else 3
	var dl := {"name": _detail_name, "tag": _detail_tag, "desc": _detail_desc, "stats": _detail_stats, "dmg": _detail_dmg}
	for key in dl:
		if dl[key] != null:
			(dl[key] as Label).add_theme_font_size_override("font_size", _font(DETAIL_FONTS[key], k))
	if _passive_labels.size() == 2:
		_passive_labels[0].add_theme_font_size_override("font_size", _font(PASSIVE_FONTS.name, k))
		_passive_labels[1].add_theme_font_size_override("font_size", _font(PASSIVE_FONTS.text, k))
		_passive_labels[1].max_lines_visible = 2 if _shrink_desc else 3


## Vrai si le contenu dépasse la hauteur allouée à la fiche (la fiche ne défile pas : on réduit le texte).
func needs_scroll() -> bool:
	var h := allotted_h if allotted_h > 0.0 else size.y
	return get_combined_minimum_size().y > h + 0.5


# --- Données des sorts -----------------------------------------------------------

func _load_spell_data(char_id: String) -> Dictionary:
	var out := {}
	if char_id == "ardent" or CharacterData.has_kit(StringName(char_id)):
		var cd := CharacterData.for_id(StringName(char_id))
		if cd != null: # kit en cours d'écriture (script invalide) : fiche sans chiffres plutôt qu'un plantage
			for s in cd.spells:
				out[s.id] = s
			# Chiffres des variantes codées par le kit (`variant`), sans warning pour celles qui ne le sont pas.
			var spells: Array = character.get("spells", [])
			for i in spells.size():
				for v in (spells[i] as Dictionary).get("variants", []):
					var vid := StringName(str(v.get("id", "")))
					var sd := CharacterData.variant_spell(StringName(char_id), i + 1, vid, true)
					if sd != null:
						out[vid] = sd
	return out


## Sorts à utiliser pour `c` : {slot (int) -> id}, base par défaut, remplacé par le choix mémorisé du profil
## (`get_loadout`) seulement si c'est une variante de ce slot encore débloquée. Profil factice toléré.
static func resolve_loadout(profile: Object, c: Dictionary) -> Dictionary:
	var out := {}
	var spells: Array = c.get("spells", []) if c.get("spells") is Array else []
	var saved: Dictionary = {}
	if profile != null and profile.has_method(&"get_loadout"):
		var d: Variant = profile.call(&"get_loadout", StringName(str(c.get("id", ""))))
		saved = d if d is Dictionary else {}
	for i in spells.size():
		var sp: Dictionary = spells[i]
		var slot := i + 1
		out[slot] = StringName(str(sp.get("id", "")))
		if not saved.has(slot):
			continue
		var want := StringName(str(saved[slot]))
		for v in sp.get("variants", []):
			if StringName(str(v.get("id", ""))) == want and CharacterCard.is_variant_unlocked(profile, v):
				out[slot] = want
	return out


## Texte de quête d'une variante verrouillée (unlock_text ou règle) + avancement d'un compteur (« 120 / 500 »).
static func variant_quest(profile: Object, c: Dictionary, slot: int, v: Dictionary) -> String:
	var spells: Array = c.get("spells", []) if c.get("spells") is Array else []
	var sp: Dictionary = spells[slot - 1] if slot >= 1 and slot <= spells.size() else {}
	var txt := VariantUnlocks.quest_text(c, sp, v)
	var pr := VariantUnlocks.progress(profile, sp, v)
	if not pr.is_empty() and float(pr.target) > 0.0:
		txt += "
Progression : %s / %s" % [CharacterCard.fmt_num(minf(float(pr.value), float(pr.target))), CharacterCard.fmt_num(float(pr.target))]
	return txt


## Chiffres clés tirés de SpellData (rien d'inventé : un champ absent ou nul n'est pas affiché).
static func spell_stats_text(sd: SpellData) -> String:
	var parts: Array[String] = []
	# Pas de « Dégâts ×N » : la ligne de dégâts (scaling_text) donne déjà le coefficient et les dégâts par niveau.
	if sd.is_auto:
		parts.append("Tir toutes les %s s" % CharacterCard.fmt_num(sd.base_cooldown))
	elif sd.base_cooldown > 0.0:
		parts.append("Recharge %s s" % CharacterCard.fmt_num(sd.base_cooldown))
	if sd.behavior in [SpellData.Behavior.PROJECTILE, SpellData.Behavior.GROUND_ZONE, SpellData.Behavior.FAN]:
		parts.append("Portée %s u" % CharacterCard.fmt_num(sd.range_u))
	if sd.radius_u > 0.0:
		parts.append("Rayon %s u" % CharacterCard.fmt_num(sd.radius_u))
	if sd.duration > 0.0:
		parts.append("Durée %s s" % CharacterCard.fmt_num(sd.duration))
	if sd.pierce > 0:
		parts.append("Traverse %d" % sd.pierce)
	return " · ".join(parts)
