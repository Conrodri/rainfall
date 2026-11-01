class_name EpreuveRelay
extends SecretLever
## Relais (vanne) du Rituel : réutilise le levier de secret (SecretLever : sprites `lever_<biome>_{off,on}`, portée, `pull`,
## signal `activated`) avec un MAINTIEN de Balance.RITUAL_HOLD_S s (le HUD gère le maintien : annulé si le joueur s'éloigne ;
## jamais annulé par un dégât). Actif seulement tant que le Rituel est en cours.

var epreuve: Node = null ## EpreuveRitual propriétaire (non typé : pas de dépendance circulaire de classes)


func can_interact() -> bool:
	return not used and epreuve != null and is_instance_valid(epreuve) and epreuve.call(&"is_running") and player_near()


func interact_label() -> String:
	return "Fermer la vanne"


func interact_state() -> Dictionary:
	return {"visible": can_interact(), "enabled": true, "label": interact_label(), "hold_s": Balance.RITUAL_HOLD_S}


func interact(_who: Node = null) -> bool:
	if not can_interact():
		return false
	pull(false)
	return true
