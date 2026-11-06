extends Node
## Bus de signaux global. Les systèmes émettent ici au lieu de se référencer directement.

signal enemy_killed(enemy: Node2D, position: Vector2, tier: int, is_elite: bool)
signal enemy_damaged(enemy: Node2D, amount: float, is_crit: bool, element: StringName)
signal player_damaged(amount: float, source: Node)
signal player_died
signal pickup_collected(kind: StringName, amount: float)
signal chest_opened(chest: Node, quality: StringName, offered_items: Array)
signal item_chosen(item_id: StringName)
signal run_saved
signal boss_spawned(boss: Node2D, is_floor_boss: bool)
signal boss_killed(boss: Node2D, is_floor_boss: bool)
signal pillar_state_changed(pillar: Node, state: StringName)
## Paratonnerre dévié : le joueur a dévié le gros pilier (boss d'étage affixé, 2 coffres de boss) ; `affix` = burn | slow | poison.
signal pillar_deviated(pillar: Node, affix: StringName)
signal floor_started(stage: int)
signal floor_cleared(stage: int)
## Changement d'étage : l'or restant (bourse + sol) a été converti en XP (RunState.convert_gold_to_xp).
signal gold_converted(gold: float, xp: float)
## Foudre (décor ou gameplay) : intensité 0..1 et position monde (Vector2.INF = hors écran / ciel).
signal lightning_struck(intensity: float, pos: Vector2)
## Changement de palier de la jauge de difficulté (Calme, Tendu, Hostile, Furieux, Cataclysme).
signal difficulty_tier_changed(tier_name: StringName, D: float)
## Progression de charge d'un gros pilier (0..1), émise pendant que la charge avance.
signal pillar_charge_progress(pillar: Node, ratio: float)
## --- Boss façon raid (docs/Design_Boss_Raid.md §1.9, scripts/enemies/raid/) ---
## Bouclier de phase armé (active = true, dès la transition) ou tombé (active = false, rupture ou garde-fou).
## kind : condition principale (&"orbs", &"ultimate_hit", &"timer", &"kill_adds", &"weak_point", &"soak", &"interact").
signal boss_shield_changed(boss: Node2D, active: bool, kind: StringName)
## Progrès de la condition de rupture du bouclier (orbes ramassées, adds tués…).
signal boss_shield_progress(boss: Node2D, done: int, total: int)
## Mécanique de raid ratée (pénalité appliquée) : &"soak", &"sector", &"add_reached", &"shield_backstop"…
signal raid_mechanic_failed(boss: Node2D, kind: StringName)
## Barrage de projectiles (BarrageEmitter) : true au début du télégraphe, false à la fin de l'émission.
signal raid_barrage(boss: Node2D, active: bool)
## --- Cycle de vie de la run (journal de run local, scripts/telemetry/) ---
## Run lancée dans la scène de jeu (Main._ready, après RunState.start_run ou from_dict, avant le premier floor_started).
## resumed = reprise d'une sauvegarde. Émis aussi en mode test (les écouteurs testent TestMode.active).
signal run_started(resumed: bool)
## Run terminée (Main.end_run) : victoire, mort ou abandon (reason : &"victory" | &"death" | &"abandon").
## Émis avant le récap ; aussi en mode test (fin sans récap).
signal run_finished(victory: bool, reason: StringName)
## --- Ateliers (docs/Ateliers_Chiffres.md) : un usage d'atelier vient d'être fait. id : &"fondoir" | &"matrice" |
## &"alambic" | &"enclume" ; kind : verbe (&"fondre", &"forger", &"distiller") ; given / received : ids d'objets ou
## &"scorie_<qualité>" ; gold : or reçu (> 0) ou dépensé (< 0).
signal station_used(id: StringName, kind: StringName, given: Array, received: Array, gold: float)
## --- Forge (docs/Design_Forge.md) : un objet exclusif vient d'être forgé par le joueur `player_id` (emplacement 0-3) ;
## `ingredients` = ids consommés, `stage` = étage de la run. Écouté par le journal de run (événement « craft »).
signal item_crafted(player_id: int, item_id: StringName, ingredients: Array, stage: int)
## --- Présages d'étage (scripts/omens/, docs/Ateliers_Chiffres.md §9) ---
## Présage actif changé : choisi à l'arrivée, retiré au téléporteur (id vide) ou imposé par le mode test.
## id = &"ciel_clair" quand le joueur refuse tout présage. `stage` : étage concerné.
signal omen_changed(id: StringName, stage: int)
## --- Épreuves (prototype « Les Épreuves », scripts/stage/epreuve*.gd, docs/Boucle_Etage_Refonte.md §5.3) ---
## Une épreuve démarre (&"escorte" | &"rituel").
signal epreuve_started(kind: StringName)
## Une épreuve se termine (avant le mini-boss) : note (&"parfait" | &"bien" | &"fait"), durée (s de jeu actif), or versé.
signal epreuve_finished(kind: StringName, grade: StringName, elapsed_s: float, gold: float)

## --- Coop 1-4 (étape 1 « Contrats », docs/multi/Archi_Reseau.md §3) ---------------------------------------------
## Identité du joueur, de façon rétrocompatible : les signaux historiques ci-dessus ne changent PAS de signature (un
## paramètre de plus casserait chaque écouteur, les signaux GDScript n'ayant pas de valeur par défaut). Chaque signal
## « joueur » a un jumeau suffixé qui porte `player_id` (emplacement 0-3 du registre Players ; NO_PLAYER = inconnu,
## environnement). Les émetteurs passent par les fonctions emit_* ci-dessous, qui émettent l'ancien ET le nouveau
## signal : les écouteurs solo existants restent branchés, les nouveaux (kits, HUD par joueur) filtrent sur player_id.
const NO_PLAYER := -1

## Monstre tué ; `player_id` = le tueur (NO_PLAYER : dégât d'environnement, de zone sans auteur, ou inconnu).
signal enemy_killed_by(player_id: int, enemy: Node2D, position: Vector2, tier: int, is_elite: bool)
## Dégât infligé à un monstre ; `player_id` = le tireur (hit["by"] ; NO_PLAYER : environnement ou inconnu). Émis une
## fois par coup par Enemy.take_damage, juste après enemy_damaged (chiffres de dégâts filtrés en coop).
signal enemy_damaged_by(player_id: int, enemy: Node2D, amount: float, is_crit: bool, element: StringName)
signal player_damaged_by(player_id: int, amount: float, source: Node)
signal player_died_by(player_id: int)
signal pickup_collected_by(player_id: int, kind: StringName, amount: float)
signal chest_opened_by(player_id: int, chest: Node, quality: StringName, offered_items: Array)
signal item_chosen_by(player_id: int, item_id: StringName)
## Mort en coop (décision du joueur, 01/11/2026) : le joueur devient spectateur jusqu'au début de l'étage suivant.
signal player_spectating(player_id: int)
## Début d'étage : un spectateur revient en jeu.
signal player_resurrected(player_id: int)
## Tous les joueurs de la partie sont morts : défaite (en solo, la mort reste signalée par player_died).
signal party_wiped
## Registre Players modifié (inscription, départ) : `count` = joueurs inscrits.
signal party_changed(count: int)


func emit_enemy_killed(enemy: Node2D, position: Vector2, tier: int, is_elite: bool, player_id: int = NO_PLAYER) -> void:
	enemy_killed.emit(enemy, position, tier, is_elite)
	enemy_killed_by.emit(player_id, enemy, position, tier, is_elite)


func emit_enemy_damaged(enemy: Node2D, amount: float, is_crit: bool, element: StringName, player_id: int = NO_PLAYER) -> void:
	enemy_damaged.emit(enemy, amount, is_crit, element)
	enemy_damaged_by.emit(player_id, enemy, amount, is_crit, element)


func emit_player_damaged(amount: float, source: Node, player_id: int = 0) -> void:
	player_damaged.emit(amount, source)
	player_damaged_by.emit(player_id, amount, source)


func emit_player_died(player_id: int = 0) -> void:
	player_died.emit()
	player_died_by.emit(player_id)


func emit_pickup_collected(kind: StringName, amount: float, player_id: int = 0) -> void:
	pickup_collected.emit(kind, amount)
	pickup_collected_by.emit(player_id, kind, amount)


func emit_chest_opened(chest: Node, quality: StringName, offered_items: Array, player_id: int = 0) -> void:
	chest_opened.emit(chest, quality, offered_items)
	chest_opened_by.emit(player_id, chest, quality, offered_items)


func emit_item_chosen(item_id: StringName, player_id: int = 0) -> void:
	item_chosen.emit(item_id)
	item_chosen_by.emit(player_id, item_id)
