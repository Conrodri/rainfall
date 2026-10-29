class_name SecretWall
extends Area2D
## Mur fissuré (déclencheur « wall ») : la porte `D` d'une salle secrète paraît un mur à peine lézardé. Les sorts du
## joueur qui la touchent (projectiles : Projectile._on_hit ; zones : ZoneEffect._apply) l'entament ; seuls les dégâts
## du joueur comptent (les monstres ne la touchent pas). Elle cède après Balance.SECRET_WALL_SECONDS de dégâts « par
## seconde » de référence (PV fixés à l'armement, voir hp_for_level). Couche 3 (comme les ennemis) pour que les
## projectiles la détectent ; invisible pour tout le reste.

signal damaged(ratio: float)
signal broken

var hp_max := 1.0
var hp := 1.0
var done := false
var size_px := Vector2(128.0, 128.0)


## PV d'un mur fissuré : SECRET_WALL_SECONDS × SECRET_WALL_COEF_PER_S coups de référence au niveau `level`.
static func hp_for_level(level: int) -> float:
	return Balance.SECRET_WALL_SECONDS * Balance.SECRET_WALL_COEF_PER_S * Balance.player_base_damage(level)


func _init() -> void:
	collision_layer = 1 << 2
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group(&"secret_wall")


func setup(p_size_px: Vector2, p_hp: float) -> void:
	size_px = p_size_px
	hp_max = maxf(p_hp, 1.0)
	hp = hp_max
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = size_px + Vector2(32.0, 32.0) # un peu plus large que la porte : touchée avant l'arrêt sur le mur
	cs.shape = sh
	add_child(cs)


## Part de dégâts subis (0 = intact, 1 = cédé).
func ratio() -> float:
	return clampf(1.0 - hp / hp_max, 0.0, 1.0)


func take_hit(amount: float) -> void:
	if done or amount <= 0.0:
		return
	hp -= amount
	damaged.emit(ratio())
	if hp <= 0.0:
		hp = 0.0
		done = true
		remove_from_group(&"secret_wall")
		set_deferred(&"monitorable", false)
		broken.emit()


## Restauration d'une sauvegarde : part de dégâts déjà subie.
func restore_ratio(r: float) -> void:
	hp = hp_max * (1.0 - clampf(r, 0.0, 0.999))
