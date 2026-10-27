extends Node
## Mode test (autoload `TestMode`) : arène vide où l'on invoque monstres et boss, ajoute / retire des objets, change de
## personnage et de skin en un clic, active des triches (PV illimités, recharge nulle, portée infinie, or infini) et règle
## la difficulté D pour mesurer les dégâts. Voir scripts/testmode/ (panneau, outils, lanceur tactile).
##
## À RETIRER OU MASQUER AVANT LA SORTIE (comme RAINFALL_UNLOCK_ALL_VARIANTS dans profile.gd) : bouton « Mode test » de
## l'écran titre (scripts/menu/title_screen.gd), argument `-- --test-mode`, ce script, scripts/testmode/ et la carte
## scenes/stage/test/. Le mode test n'écrit RIEN dans le profil : Profile.begin_sandbox() fige l'écriture et rend l'état
## d'avant à la sortie ; aucune sauvegarde de run, aucun récap de fin.
##
## Les drapeaux de triche vivent ici, à un seul endroit ; ils sont lus par Player (PV), SpellCaster (recharge, portée),
## RunState (or, difficulté, minuterie), Enemy (IA figée), Director (apparitions) et Skins (apparence forcée). Tous sont
## remis à zéro par begin() et end() : hors mode test, ils valent faux et ne coûtent rien.

signal changed ## un réglage a bougé (panneau, HUD)
signal panel_requested ## TAB, bouton de manette ou bouton tactile : ouvre / ferme le panneau

const ARG := "--test-mode"
## Portée « infinie » (px) : au-delà de tout écran (≈ 125 u). Les projectiles s'éteignent à cette distance.
const INF_RANGE_PX := 8000.0
const ARENA_SCENE := "res://scenes/stage/test/test_arena.tscn"
const D_MIN := 1.0
const D_MAX := 30.0
const GOLD_FLOOR := 99999.0 ## or affiché en mode « or infini »

var active := false
## Triches (chacune indépendante).
var god := false ## PV illimités : le coup est encaissé (chiffre, flash, son), aucun PV perdu
var cdr_full := false ## recharge à 0 : un sort se relance sans attendre
var inf_range := false ## portée des sorts et ciblage automatique sans limite
var inf_gold := false ## or infini : les achats ne coûtent rien
## Monstres.
var freeze_ai := false ## IA figée : les monstres ne bougent ni n'attaquent (les DoT et les coups reçus continuent)
var spawns := false ## le director fait apparaître ses vagues
var freeze_time := true ## la minuterie de run est arrêtée (la difficulté vient du réglage D)
## Panneau.
var pause_on_open := true ## le jeu est mis en pause tant que le panneau est ouvert
var d_value := 1.0 ## difficulté D imposée (RunState.difficulty())
## Apparence forcée : id de personnage (texte) -> id de skin ("" = apparence par défaut). Lu par Skins.equipped().
var skin_override := {}


## `-- --test-mode` : le jeu démarre directement en mode test (App).
static func requested_by_arg() -> bool:
	return OS.get_cmdline_user_args().has(ARG)


## Entre en mode test : profil mis en bac à sable, réglages par défaut.
func begin() -> void:
	if active:
		return
	_reset_flags()
	active = true
	Profile.begin_sandbox()
	changed.emit()


## Sort du mode test : profil rendu tel qu'avant, triches coupées.
func end() -> void:
	if not active:
		return
	active = false
	_reset_flags()
	Profile.end_sandbox()
	changed.emit()


func _reset_flags() -> void:
	god = false
	cdr_full = false
	inf_range = false
	inf_gold = false
	freeze_ai = false
	spawns = false
	freeze_time = true
	pause_on_open = true
	d_value = D_MIN
	skin_override = {}


## Pose un drapeau par son nom (panneau) et prévient les écouteurs.
func set_flag(flag: StringName, value: bool) -> void:
	if not (flag in self):
		push_warning("TestMode : drapeau inconnu « %s »" % flag)
		return
	set(flag, value)
	if flag == &"inf_gold" and value:
		RunState.gold = maxf(RunState.gold, GOLD_FLOOR)
		RunState.gold_changed.emit(RunState.gold)
	changed.emit()


## Règle la difficulté D (bornée) ; RunState.difficulty() la renvoie tant que le mode test est actif.
func set_difficulty(d: float) -> void:
	d_value = clampf(snappedf(d, 0.05), D_MIN, D_MAX)
	var tier := Balance.difficulty_tier_name(d_value)
	RunState.difficulty_changed.emit(d_value, tier)
	Events.difficulty_tier_changed.emit(tier, d_value)
	changed.emit()


## Apparence d'un personnage en mode test ("" = défaut). Indépendante des déblocages du profil.
func set_skin(cid: StringName, skin_id: String) -> void:
	skin_override[String(cid)] = skin_id
	changed.emit()


## Demande d'ouverture du panneau (touche, manette, bouton tactile).
func request_panel() -> void:
	if active:
		panel_requested.emit()
