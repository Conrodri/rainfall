class_name AdHook
extends RefCounted
## Point d'accès à la pub récompensée. Factice : réussit immédiatement.
## Remplacer `show_rewarded` par le SDK réel plus tard ; ne jamais l'appeler sans appui explicite.

static var no_ads_purchased := false ## « Sans pub » : la relance reste disponible sans regarder de pub
static var available := true ## false = aucune pub dispo (le bouton bascule alors sur la relance à l'or)


## Relance sans pub (décision du joueur, 21/10/2026) : PC (jeu payant), pass « Sans pub » acheté, ou phase de
## test (passes pas encore implémentés : FREE_FOR_TESTS à repasser à false quand la pub et le pass existeront).
const FREE_FOR_TESTS := true


static func is_free() -> bool:
	return FREE_FOR_TESTS or no_ads_purchased or Platform.is_pc()


static func is_available() -> bool:
	return available or is_free()


## Appelle on_done(success: bool). Factice : succès immédiat.
static func show_rewarded(on_done: Callable) -> void:
	on_done.call(true)
