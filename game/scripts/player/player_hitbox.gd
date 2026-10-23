class_name PlayerHitbox
extends RefCounted
## Rayon de DÉGÂTS du joueur : source unique (22/10/2026) pour tout ce qui teste « le joueur est-il touché ? »
## par une distance : contact des monstres (Enemy), projectiles ennemis (EnemyProjectilePool), attaques des boss
## et mini-boss (cerveaux `PLAYER_R`, MiniBossPatterns `PR`), pièges (Floor1Hazards, SmelterSlag, WeaverSnare,
## MiniBossHazards, orage du Sonneur). Le rayon des ATTAQUES ne change pas : seul le rayon du joueur s'y ajoute.
## Suit `Player.set_hitbox_u(u)` (kits : `hitbox_u` 0,45-0,6 ; toupie de Rictus ; Bourbe rétrécit avec ses mottes).
## Référence : `hitbox_u` 0,5 (forme de la scène) = 26 px, l'ancien rayon de contact.
## Lecture : `Player.hit_radius_px()` ou `PlayerHitbox.radius_px` (statique : fonctions statiques, boucles).
## Boucle chaude du Director : `Enemy.PLAYER_RADIUS_PX` (statique propre à Enemy, recopié ici, lecture la moins chère).

const BASE_PX := 26.0 ## rayon de dégâts à hitbox_u = REF_U (et des personnages sans hitbox_u)
const REF_U := 0.5

static var radius_px := BASE_PX
static var _owner_id := 0 ## joueur qui a posé le rayon (un joueur qui sort ne remet pas à zéro celui d'un autre)


## Rayon de dégâts (px) pour une hitbox de `u` unités (0 ou moins : référence).
static func px_for_u(u: float) -> float:
	return BASE_PX * u / REF_U if u > 0.0 else BASE_PX


static func set_radius(px: float, owner_id := 0) -> void:
	radius_px = maxf(px, 1.0)
	_owner_id = owner_id
	Enemy.PLAYER_RADIUS_PX = radius_px


## Fin de vie du joueur `owner_id` : retour à la référence s'il était le dernier à poser le rayon.
static func release(owner_id: int) -> void:
	if owner_id == _owner_id:
		set_radius(BASE_PX, 0)
