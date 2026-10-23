class_name RenderStyle
extends RefCounted
## Style de rendu des sprites : « cel » (DÉFAUT depuis le 22/10/2026, DA validée par le joueur) ou « 3d »
## (ancien rendu, gardé tant que la migration cel n'est pas finie : art/briefs/STYLE_cel.md, PLAN_SUITE.md).
## Contrat `_cel` (CONTRACTS.md) : en style cel, un fichier `<dossier>/<f>` est remplacé par
## `<dossier>_cel/<f>` quand ce dernier existe ; sinon l'original est gardé (repli silencieux).
## Règle générique, aucune liste de sujets : tout dossier de sprites peut avoir son frère `_cel`.
## Point unique de résolution : `RenderStyle.resolve(path)` (chargeurs de SpriteFrames du joueur
## et des monstres). Réglage persistant `[graphics] render_style` (GameSettings), bascule à chaud
## avec F7 (Player) : les nœuds du groupe GROUP reçoivent `apply_render_style()`.

const STYLE_3D := &"3d"
const STYLE_CEL := &"cel"
const DEFAULT := STYLE_CEL ## style quand le réglage est absent (fichier vide, réinitialisation)
const SUFFIX := "_cel"
const GROUP := &"render_style" ## nœuds rechargés à chaud (méthode apply_render_style())
const META_SRC := &"render_src" ## chemin du .tres d'origine posé par EmissiveOverlay.apply
const META_ENERGY := &"render_energy"
const TOGGLE_KEY := KEY_F7

static var _style: StringName = &"" ## &"" = pas encore lu dans les réglages
static var version := 0 ## incrémenté à chaque changement (les caches de SpriteFrames s'y recalent)
static var _resolved: Dictionary = {} ## chemin -> chemin résolu (style courant)
## Test d'existence injectable (tests) ; vide = ResourceLoader.exists.
static var exists_fn: Callable = Callable()


static func style() -> StringName:
	if _style == &"":
		_style = STYLE_3D if GameSettings.render_style() == String(STYLE_3D) else STYLE_CEL
	return _style


static func is_cel() -> bool:
	return style() == STYLE_CEL


static func _exists(path: String) -> bool:
	if exists_fn.is_valid():
		return bool(exists_fn.call(path))
	return ResourceLoader.exists(path)


## Chemin du sibling `_cel` (sans test d'existence) : res://a/b/x.tres -> res://a/b_cel/x.tres.
static func cel_path(path: String) -> String:
	var dir := path.get_base_dir()
	if dir == "" or dir.ends_with(SUFFIX):
		return path
	return dir + SUFFIX + "/" + path.get_file()


## Chemin d'origine d'un chemin éventuellement déjà `_cel`.
static func original_path(path: String) -> String:
	var dir := path.get_base_dir()
	if not dir.ends_with(SUFFIX):
		return path
	return dir.left(dir.length() - SUFFIX.length()) + "/" + path.get_file()


## Résout un chemin de sprite pour le style courant (cel : sibling `_cel` s'il existe).
static func resolve(path: String) -> String:
	if path == "" or not is_cel():
		return path
	if _resolved.has(path):
		return _resolved[path]
	var cand := cel_path(path)
	var out := cand if cand != path and _exists(cand) else path
	_resolved[path] = out
	return out


## Change le style. `persist` : écrit le réglage (GameSettings, chemin injecté en test).
## `tree` : les nœuds du groupe GROUP se rechargent aussitôt.
static func set_style(s: StringName, tree: SceneTree = null, persist: bool = true) -> void:
	s = STYLE_CEL if s == STYLE_CEL else STYLE_3D
	if persist:
		GameSettings.set_render_style(String(s))
	if s == _style:
		return
	_style = s
	version += 1
	_resolved.clear()
	if tree != null:
		tree.call_group(GROUP, &"apply_render_style")


static func toggle(tree: SceneTree = null) -> StringName:
	set_style(STYLE_3D if is_cel() else STYLE_CEL, tree)
	return _style


## Oublie le style lu et le cache de résolution (tests, réinitialisation des réglages).
static func reload() -> void:
	_style = &""
	version += 1
	_resolved.clear()


static func is_toggle_event(event: InputEvent) -> bool:
	var k := event as InputEventKey
	return k != null and k.pressed and not k.echo and k.keycode == TOGGLE_KEY


## Recharge les SpriteFrames d'un AnimatedSprite2D branché par EmissiveOverlay.apply pour le style
## courant, en gardant l'animation, la frame, la progression et la lecture. Renvoie la nouvelle
## ressource d'origine, ou null si rien n'a changé (pas de `_cel`, déjà au bon style).
static func restyle_sprite(anim: AnimatedSprite2D) -> SpriteFrames:
	if anim == null or not anim.has_meta(META_SRC):
		return null
	var src := String(anim.get_meta(META_SRC))
	if src == "":
		return null
	var want := resolve(original_path(src))
	if want == src or not _exists(want):
		return null
	var f := load(want) as SpriteFrames
	if f == null:
		return null
	var cur := anim.animation
	var fr := anim.frame
	var prog := anim.frame_progress
	var playing := anim.is_playing()
	var custom := anim.get_playing_speed() / anim.speed_scale if playing and anim.speed_scale != 0.0 else 1.0
	EmissiveOverlay.apply(anim, f, float(anim.get_meta(META_ENERGY, 2.0)))
	if f.has_animation(cur):
		if playing:
			anim.play(cur, custom)
		else:
			anim.animation = cur
		var n := f.get_frame_count(cur)
		if n > 0:
			anim.set_frame_and_progress(mini(fr, n - 1), prog)
	return f
