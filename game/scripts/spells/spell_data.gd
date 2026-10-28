class_name SpellData
extends Resource
## Description data-driven d'un sort. Les variantes B et les autres personnages = d'autres SpellData.

## S7 : ARC (demi-cercle instantané orienté vers l'ennemi le plus proche), FAN (N projectiles en éventail),
## SPIN et DECOYS (états du personnage : délégués au kit du joueur, voir CharacterData.kit_script).
## KIT : sort entièrement délégué au kit (kit.cast_spell(s, aim) -> bool), sans sémantique imposée.
enum Behavior { PROJECTILE, NOVA, GROUND_ZONE, ARC, FAN, SPIN, DECOYS, KIT }

@export var id: StringName = &""
@export var display_name := ""
@export_range(1, 4) var slot := 1
@export var behavior: Behavior = Behavior.PROJECTILE
@export var is_auto := false ## slot 1 : tire seul, cadence = Balance.attack_interval
@export var coef := 0.8
@export var base_cooldown := 0.6 ## s (intervalle d'attaque pour un sort auto)
@export var range_u := 9.0 ## portée de ciblage / de vie du projectile, en unités
@export var radius_u := 0.0 ## rayon de zone, en unités (zones)
@export var pierce := 0 ## ennemis traversés en plus du premier (projectiles)
@export var duration := 0.0 ## s, zone persistante (0 = instantanée)
@export var tick := 0.5 ## s entre deux ticks d'une zone persistante
@export var is_zone := true ## compte pour zone_damage_add
@export var proc_coef := 1.0 ## proc coefficient RoR2 : multiplie les chances de proc des items (zones à ticks rapides < 1)
@export var trigger_range_u := 6.0 ## auto-cast : lance si un ennemi est à cette distance
@export var color := Color(1.0, 0.45, 0.1)
## Couleur du contour des zones persistantes au sol (ZoneOutline) ; alpha 0 = couleur du sort (`color`), puis accent du personnage.
@export var zone_outline_color := Color(0, 0, 0, 0)
@export var element: StringName = &"fire"
## Preset LightRig du sort (éclat, zone, projectile en vol) ; vide = aucune lumière de sort (projectile : « ember »).
@export var light_preset: StringName = &""

@export_group("Comportements S7")
@export var count := 1 ## FAN : nombre de projectiles
@export var spread_deg := 0.0 ## FAN : ouverture totale ; ARC : angle total du demi-cercle
@export var speed_u := 0.0 ## vitesse propre des projectiles (u/s) ; 0 = Balance.projectile_speed_px
@export var item_pierce := true ## la stat `pierce` des items s'applique (Pointe perforante : sort 1 seulement)
@export var rests_on_ground := false ## le projectile en fin de course est confié au kit (couteaux plantés, S6)
@export var hit_force := -1.0 ## force de coup imposée (recul) ; < 0 = Balance.hit_force
## S5 : cible automatique quand rien n'est visé (tactile, stick au repos) : &"nearest" ou &"densest".
@export var target_mode: StringName = &"nearest"
## SpriteFrames du projectile (vide = éclat de braise de la scène).
@export var projectile_frames := ""

@export_group("VFX de zone (rendu Blender)")
## SpriteFrames de l'effet de zone (ZoneEffect) ; vide ou absent sur disque = repli dessiné (contour fin).
## Anims : `default` (gerbe ou boucle), `end` facultative (extinction d'une zone persistante).
@export var vfx_frames := ""
## Rayon de l'empreinte au sol de l'effet, en px de la frame (le cercle de gameplay y est calé, × zone_size_add).
@export var vfx_radius_px := 0.0
## Hauteur / largeur d'un disque au sol dans la frame (rendu iso 30° = 0,5 ; anciens rendus 55° ≈ 0,67).
## Le sprite reçoit l'échelle (k, k / aspect) en repère logique : l'empreinte retombe sur le sol iso 2:1.
@export var vfx_floor_aspect := 0.5
## Le diffus aussi en additif (effets purement lumineux) ; sinon diffus normal + passe _e additive (EmissiveOverlay).
@export var vfx_additive := false
## Effet dont les flammes montent haut (px de la frame, au-dessus du sol, 0 = pas de plafond). Si le rayon de jeu
## imposerait des flammes plus hautes que vfx_flame_cap_u, ZoneEffect pave la zone de copies plus petites
## (sol iso 2:1 intact, hauteur plafonnée) au lieu d'étirer un seul sprite.
@export var vfx_flame_h_px := 0.0
@export var vfx_flame_cap_u := 2.0
