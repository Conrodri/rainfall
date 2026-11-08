extends AmbientEffect
## « Orage » : un éclair de décor toutes les `interval_s` [min, max] secondes (défaut 10-20 s), flash, directionnelle
## et tonnerre compris (AmbianceLightning : le tonnerre suit le signal `thunder` de l'AmbianceManager, branché sur
## Audio.thunder_after par la scène de jeu ; sons amb.thunder_close / amb.thunder_far livrés).
## Si le profil de la carte planifie déjà des éclairs au moins aussi fréquents à ce palier (cas de la Cité de rouille
## et de la Fonderie à Furieux : 10-20 s), l'effet laisse faire le profil : il ne sert que de filet.
## Garde-fous photosensibles inchangés (>= 4 s entre deux éclairs, <= 3 par 10 s, option Flashs).
## Paramètres : "interval_s" [10, 20], "intensity" (0,6).

var strikes := 0 ## éclairs déclenchés par l'effet (tests)
var _wait := 0.0


func start() -> void:
	_wait = rand_range_of(def.get("interval_s"), Vector2(10.0, 20.0))


## Vrai si le profil courant planifie déjà des éclairs à cette cadence (l'effet n'ajoute rien).
func profile_covers() -> bool:
	var p: Dictionary = mgr.current_params()
	var mx := float(p.get(&"lightning_interval_max", 0.0))
	var iv: Variant = def.get("interval_s")
	var want_max := float(iv[1]) if iv is Array and (iv as Array).size() >= 2 else 20.0
	return mx > 0.0 and float(p.get(&"lightning_flash", 0.0)) > 0.0 and mx <= want_max + 0.001


func process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = rand_range_of(def.get("interval_s"), Vector2(10.0, 20.0))
	if profile_covers() or mgr.lightning == null:
		return
	if mgr.lightning.strike_ambient(float(def.get("intensity", 0.6))):
		strikes += 1
	else:
		_wait = 1.0 # garde-fou photosensible : on réessaie bientôt


func describe() -> Dictionary:
	var d := super.describe()
	d["strikes"] = strikes
	d["profile_covers"] = mgr != null and not mgr.current_params().is_empty() and profile_covers()
	return d
