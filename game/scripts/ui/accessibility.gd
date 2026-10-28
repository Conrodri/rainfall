extends Node
## Autoload `Accessibility` (passe accessibilité 28/10/2026) : applique les réglages d'accessibilité qui ne se lisent pas
## « à la volée » ailleurs. Les valeurs vivent dans GameSettings (source unique) ; ce nœud :
##  - TAILLE DU TEXTE (100 / 115 / 130 %) : met à jour le thème commun (UiTheme.refresh_text_scale) puis multiplie les
##    tailles de police posées en surcharge (add_theme_font_size_override) sur tous les contrôles d'interface. Chaque
##    contrôle garde sa taille de base en méta : repasser à 100 % la restitue ; une surcharge reposée par le code
##    (mise en page du HUD) est reconnue (valeur différente de la dernière appliquée) et remise à l'échelle.
##    Les textes du monde (chiffres de dégâts, noms au sol hors couche d'interface) ne sont pas touchés : ils ont leur
##    propre réglage « Taille des chiffres de dégâts ».
##  - signal `changed` : émis à chaque réglage modifié depuis le panneau (palette daltonienne, texte...), pour les
##    éléments qui se construisent une fois (barre de PV du HUD).
## Rien n'est écrit ici : lecture seule de GameSettings.

signal changed

const POLL_S := 1.0
const FONT_NAMES: Array[StringName] = [&"font_size", &"normal_font_size", &"bold_font_size", &"italics_font_size",
	&"bold_italics_font_size", &"mono_font_size"]
const META := &"_a11y_fs"
const SKIP_META := &"a11y_skip" ## posée sur un nœud : lui et ses descendants sont ignorés (texte déjà dimensionné par le code)

var _pending: Dictionary = {} ## Control -> true, ajoutés depuis la dernière passe
var _flush_queued := false
var _poll := 0.0
var _touched := false ## au moins un contrôle porte une taille d'origine en méta (restitution nécessaire à 100 %)
var _last_k := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	get_tree().root.size_changed.connect(_queue_full)
	apply_text_scale()


## Taille appliquée au texte : 1,0 / 1,15 / 1,3.
static func text_k() -> float:
	return GameSettings.text_scale()


## Taille de police agrandie (pour les textes dessinés en `_draw`).
static func fs(px: int) -> int:
	return roundi(float(px) * text_k())


## Appelé par le panneau de réglages après chaque changement : relance l'application et prévient les écouteurs.
func notify_changed() -> void:
	apply_text_scale()
	changed.emit()


## Applique la taille de texte courante : thème partagé puis passe complète sur l'arbre.
func apply_text_scale() -> void:
	var k := text_k()
	UiTheme.refresh_text_scale()
	ThemeDB.fallback_font_size = roundi(16.0 * k)
	_last_k = k
	_scale_tree(get_tree().root, k, true)


func _queue_full() -> void:
	if _last_k == 1.0 and not _touched:
		return
	_poll = POLL_S # prochaine passe à la frame suivante


func _on_node_added(n: Node) -> void:
	if _last_k == 1.0 and not _touched:
		return
	if n is Control:
		_pending[n] = true
		if not _flush_queued:
			_flush_queued = true
			_flush.call_deferred()


func _flush() -> void:
	_flush_queued = false
	var k := text_k()
	for n in _pending.keys():
		if is_instance_valid(n) and (n as Node).is_inside_tree() and _in_ui(n):
			_scale_control(n as Control, k)
	_pending.clear()


func _process(delta: float) -> void:
	_poll += delta
	if _poll < POLL_S:
		return
	_poll = 0.0
	var k := text_k()
	if k != _last_k:
		apply_text_scale() # réglage modifié hors panneau (fichier injecté, test)
	elif k != 1.0 or _touched:
		_scale_tree(get_tree().root, k)


## Un contrôle est « d'interface » s'il a une CanvasLayer ou la fenêtre racine au-dessus de lui sans nœud 2D du monde entre deux.
func _in_ui(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p.has_meta(SKIP_META):
			return false
		if p is CanvasLayer or p is Window:
			return true
		if p is CanvasItem and not (p is Control):
			return false
		p = p.get_parent()
	return false


func _scale_tree(n: Node, k: float, refresh := false) -> void:
	if n.has_meta(SKIP_META) or n.is_in_group(&"enemies"):
		return
	if refresh and n.has_method(&"refresh_subtitle"):
		n.call(&"refresh_subtitle") # boutons de menu : marges recalculées sur la nouvelle taille
	if n is Control and _in_ui(n):
		_scale_control(n as Control, k)
	for c in n.get_children():
		_scale_tree(c, k, refresh)


func _scale_control(c: Control, k: float) -> void:
	for nm in FONT_NAMES:
		if not c.has_theme_font_size_override(nm):
			continue
		var cur := c.get_theme_font_size(nm)
		var meta: Dictionary = c.get_meta(META, {})
		var base := cur
		var ent: Variant = meta.get(nm)
		if ent != null and int(ent[1]) == cur:
			base = int(ent[0]) # taille posée par nous : repartir de la base d'origine
		var want := roundi(float(base) * k) if k != 1.0 else base
		if want != cur:
			c.add_theme_font_size_override(nm, want)
		if k != 1.0 or ent != null:
			meta[nm] = [base, want]
			c.set_meta(META, meta)
			_touched = true
