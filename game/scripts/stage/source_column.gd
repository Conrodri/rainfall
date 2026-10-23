class_name SourceColumn
extends Node2D
## Colonne de pluie de la Source (docs/Design_Etages.md §4) : la pluie tombe en une seule colonne au centre
## de l'arène, sur le paratonnerre-mère. Posée par StageManager à l'étage final.
## - VFX Codex livré (art/tools/night/requests_floor45.md §5) : `assets/sprites/vfx/source/rain_column.png`
##   (planche horizontale de 12 cellules 256 × 1024, + `_n` / `_e`), jouée en boucle, pied au sol ;
## - sinon PLACEHOLDER temporaire : particules de gouttes (texture Blender `drop_32` d'AmbianceTextures)
##   qui tombent dans un disque de COLUMN_RADIUS_U, quantité selon le palier de qualité.
## Lumière froide de la colonne : profil d'ambiance la_source.tres (point_lights au centre).

const SHEET := "res://assets/sprites/vfx/source/rain_column.png"
const SHEET_FPS := 12.0
const SHEET_PX_PER_U := 90.51 ## rig CREA / TOP iso (comme les props)
const SHEET_FOOT_Y := 0.92 ## pied de la colonne à 92 % de la hauteur de frame
const SHEET_CELL_ASPECT := 4.0 ## cellule hauteur / largeur (256 × 1024)
const COLUMN_RADIUS_U := 2.2
const COLUMN_HEIGHT_U := 9.0 ## hauteur de chute visible (écran)
const AMOUNT := [24, 48, 80] ## Bas, Moyen, Haut
const U := 64.0

var _sheet: Sprite2D = null
var _t := 0.0


func _ready() -> void:
	name = &"SourceColumn"
	if ResourceLoader.exists(SHEET):
		_build_sheet()
	else:
		_build_particles()


func _build_sheet() -> void:
	var tex := load(SHEET) as Texture2D
	_sheet = Sprite2D.new()
	_sheet.texture = tex
	var h := float(tex.get_height())
	_sheet.hframes = maxi(int(round(tex.get_width() / (h / SHEET_CELL_ASPECT))), 1)
	_sheet.scale = Iso.UNSQUASH * (U / SHEET_PX_PER_U)
	_sheet.offset = Vector2(0.0, -h * (SHEET_FOOT_Y - 0.5))
	add_child(_sheet)
	NormalMaps.apply_to_sprite(_sheet)


func _process(delta: float) -> void:
	if _sheet != null and _sheet.hframes > 1:
		_t += delta
		_sheet.frame = int(_t * SHEET_FPS) % _sheet.hframes


func _build_particles() -> void:
	var p := CPUParticles2D.new()
	p.name = &"Drops"
	var tier := 2
	var q := get_node_or_null(^"/root/Quality")
	if q != null and &"tier" in q:
		tier = clampi(int(q.get(&"tier")), 0, 2)
	p.amount = AMOUNT[tier]
	p.lifetime = 0.55
	p.preprocess = 0.6
	p.local_coords = true
	p.texture = AmbianceTextures.get_tex(&"drop_32")
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = COLUMN_RADIUS_U * U
	# repère logique : la caméra iso écrase y de moitié -> chute « verticale à l'écran » = -y logique × 2
	p.position = Vector2(0.0, -COLUMN_HEIGHT_U * U * 2.0)
	p.direction = Vector2(0.0, 1.0)
	p.spread = 2.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = COLUMN_HEIGHT_U * U * 2.0 / 0.55 * 0.9
	p.initial_velocity_max = COLUMN_HEIGHT_U * U * 2.0 / 0.55 * 1.1
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	p.color = Color(0.82, 0.93, 1.0, 0.55)
	add_child(p)
