class_name CompanionSprite
extends AnimatedSprite2D
## S15 (Design_Personnages §3.3) : acteur visuel synchronisé sur le sprite du joueur (le Montreur de Rictus ;
## plus tard une variante Phénix d'Ardent). Rendu séparément dans Blender, assemblé ici :
## - même index de frame que le sprite suivi (`source`), anim `<anim>_<dir>` choisie par le kit ;
## - suspendu à `lift_u` u au-dessus du sol (Iso.lift_px), décalé de `screen_offset_u` (écran, haut-gauche) ;
## - alpha `alpha` (Rictus : 0,8, retour joueur), placé sous les projectiles (ordre des enfants du joueur : voir attach()).
## Assets absents : SpriteFrames de repli (celles du joueur) teintées `fallback_tint`.

var source: AnimatedSprite2D = null
var lift_u := 1.4
var screen_offset_u := Vector2(-0.3, -0.3) ## u à l'écran (x droite, y bas) ; normalisé à 0,3 u de long
var alpha := 0.55
var fallback_tint := Color("#9FC8C0")
var anim_base := &"hover" ## choisi par le kit chaque frame (hover / pull)
var using_fallback := false
var _dir := "s"


## Crée le compagnon sous `player`, juste après `source` (donc sous le conteneur des projectiles).
static func attach(player: Node2D, p_source: AnimatedSprite2D, frames_path: String, p_lift_u := 1.4,
		p_alpha := 0.55) -> CompanionSprite:
	var c := CompanionSprite.new()
	c.name = "Companion"
	c.source = p_source
	c.lift_u = p_lift_u
	c.alpha = p_alpha
	if frames_path != "" and ResourceLoader.exists(frames_path):
		c.sprite_frames = load(frames_path) as SpriteFrames
	if c.sprite_frames == null and p_source != null:
		c.sprite_frames = p_source.sprite_frames
		c.using_fallback = true
	player.add_child(c)
	if p_source != null and p_source.get_parent() == player:
		player.move_child(c, p_source.get_index() + 1)
	c._place()
	return c


func _place() -> void:
	if source != null:
		scale = source.scale
		offset = source.offset
	# hauteur et décalage en espace billboard (px), ramenés au plan logique du joueur (× UNSQUASH)
	var off := screen_offset_u.normalized() * 0.3 * Balance.UNIT_PX * Iso.SPRITE_K
	position = Vector2(off.x, Iso.lift_px(lift_u) + off.y) * Iso.UNSQUASH
	var col := fallback_tint if using_fallback else Color.WHITE
	self_modulate = Color(col.r, col.g, col.b, alpha)


## Direction (nom de planche) et anim de base ; la frame suit celle de la source.
func sync(dir_name: String, base: StringName) -> void:
	_dir = dir_name
	anim_base = base
	if sprite_frames == null:
		return
	var want := StringName("%s_%s" % [base, dir_name])
	if not sprite_frames.has_animation(want):
		want = base
	if not sprite_frames.has_animation(want):
		# repli : celles du joueur (idle_<dir>) tant que montreur.tres manque
		want = StringName("idle_" + dir_name)
	if not sprite_frames.has_animation(want):
		return
	if animation != want:
		animation = want
	stop() # la frame est imposée par la source
	var n := sprite_frames.get_frame_count(want)
	if n > 0 and source != null:
		frame = source.frame % n

