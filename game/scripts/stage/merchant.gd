class_name Merchant
extends Node2D
## Marchand de l'étage 3 (demande du joueur, 01/11/2026) : un par run, sur toutes les cartes de l'étage 3 (A et B). Propose
## 4 objets, un par rareté (commun, peu commun, rare, légendaire), tirés dans les tables normales à l'arrivée sur l'étage ;
## prix = petit coffre de l'étage x Balance.MERCHANT_PRICE_MULT[rareté] (formule de Chest.price_of : Faveur du marchand et
## Présages compris, relue à chaque image). Chaque objet s'achète une seule fois. S'active par « interagir » (jamais au
## contact) et ouvre l'écran vitrine (ShowcaseUI, mode SHOP) ; l'état (objets vendus) est sauvegardé par StageManager.
## Visuel PROVISOIRE : le guichet de la Cité de rouille (props/rust_city/ticket_booth.png) ; l'étal définitif est une
## consigne Codex (art/tools/props/_marchand.txt) déposée sous props/merchant/merchant_stall.png (même nœud, rien d'autre ne change).

signal closed

const SPRITE := "res://assets/sprites/props/merchant/merchant_stall.png"
const FALLBACK_SPRITE := "res://assets/sprites/props/rust_city/ticket_booth.png"
const RENDER_PX_PER_U := 90.51 ## rendu iso MAP (art/tools/night/f3p_build.py)
const FOOT_Y_FRAC := 162.0 / 192.0 ## socle du guichet à 162 px sur 192
const RANGE_U := 2.4
const QUALITY_ORDER: Array[StringName] = [&"commun", &"peu_commun", &"rare", &"legendaire"]

var stage := 3
## [{id: String, quality: String, sold: bool, sold_by: Array[int]}], ordre des raretés. Coop : l'étal est PAR JOUEUR (même
## stock tiré par la graine, chacun achète le sien) : `sold_by` liste les emplacements qui ont acheté l'objet, `sold` ne vaut
## vrai qu'en solo (ou quand tous les joueurs de la partie l'ont acheté).
var stock: Array = []
var _ui: ShowcaseUI = null
var _sprite: Sprite2D = null
var _buyer: PlayerState = null ## joueur dont l'écran est ouvert


func setup(p_stock: Array, p_stage: int) -> void:
	stage = p_stage
	stock = []
	for e in p_stock:
		var d := e as Dictionary
		var entry := {"id": String(d.get("id", "")), "quality": String(d.get("quality", "commun")), "sold": bool(d.get("sold", false))}
		if d.get("sold_by") is Array:
			var by: Array = []
			for sl in d["sold_by"]:
				by.append(int(sl))
			entry["sold_by"] = by
		stock.append(entry)


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"merchants")
	_build_visual()


## Tirage du stock : un objet par rareté dans la table normale des coffres (`LootRoller.available_ids` : objets débloqués),
## jamais deux fois le même. RNG au choix de l'appelant (StageManager : graine propre ; ne touche pas RunState.rng).
static func roll_stock(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var taken: Array = []
	for q in QUALITY_ORDER:
		var ids: Array = LootRoller.pick_n(q, RunState.items, taken, rng, 1)
		if ids.is_empty():
			continue
		taken.append(ids[0])
		out.append({"id": String(ids[0]), "quality": String(q), "sold": false})
	return out


## Prix d'un objet de cette rareté au moment de l'achat : petit coffre de l'étage x multiplicateur.
func price_for(quality: StringName) -> float:
	return price_of(quality, stage)


static func price_of(quality: StringName, p_stage: int) -> float:
	return Chest.price_of(&"petit", RunState.floor_start_d, p_stage) * float(Balance.MERCHANT_PRICE_MULT.get(quality, 1.0))


func _build_visual() -> void:
	var path := SPRITE if ResourceLoader.exists(SPRITE) else FALLBACK_SPRITE
	if not ResourceLoader.exists(path):
		var poly := Polygon2D.new() # dernier repli : bloc coloré
		poly.polygon = PackedVector2Array([Vector2(-40, 0), Vector2(40, 0), Vector2(40, -90), Vector2(-40, -90)])
		poly.color = Color(0.55, 0.42, 0.25)
		add_child(poly)
		return
	var tex := load(path) as Texture2D
	_sprite = Sprite2D.new()
	_sprite.name = &"Sprite"
	_sprite.texture = tex
	_sprite.scale = Iso.UNSQUASH * (64.0 / RENDER_PX_PER_U) # billboard iso, 64 px/u
	_sprite.offset = Vector2(0.0, -float(tex.get_height()) * (FOOT_Y_FRAC - 0.5))
	add_child(_sprite)


func _near_player() -> Node2D:
	return CoopRules.nearest_within(global_position, RANGE_U * Balance.UNIT_PX) if is_inside_tree() else null


func player_near() -> bool:
	return _near_player() != null


## Objets encore à vendre à ce joueur (null : le plus proche dans la portée, sinon le joueur local).
func unsold_count(st: PlayerState = null) -> int:
	var slot := (st if st != null else CoopRules.state_of(_near_player())).slot
	var n := 0
	for e: Dictionary in stock:
		if not is_sold_to(e, slot):
			n += 1
	return n


## L'objet `e` est vendu pour le joueur d'emplacement `slot` (coop : sold_by ; solo : sold).
static func is_sold_to(e: Dictionary, slot: int) -> bool:
	if bool(e.get("sold", false)) and not e.has("sold_by"):
		return true
	return (e.get("sold_by", []) as Array).has(slot)


## Étal vu par ce joueur : même stock, `sold` propre à lui (c'est ce que lit l'écran ShowcaseUI en mode SHOP).
func stock_view(st: PlayerState) -> Array:
	var out: Array = []
	for e: Dictionary in stock:
		out.append({"id": e["id"], "quality": e["quality"], "sold": is_sold_to(e, st.slot)})
	return out


func is_open() -> bool:
	return _ui != null and is_instance_valid(_ui)


func can_interact() -> bool:
	return not is_open() and player_near()


func interact_label() -> String:
	return "Marchand" if unsold_count() > 0 else "Marchand (tout vendu)"


func interact_state() -> Dictionary:
	return {"visible": can_interact(), "enabled": true, "label": interact_label(), "hold_s": 0.0}


func interact_priority() -> int:
	return 2


## Ouvre l'écran du marchand. Faux s'il est déjà ouvert ou hors de portée.
func interact(who: Node = null) -> bool:
	if not can_interact():
		return false
	return open_shop(who)


## Ouvre l'étal pour `who` (null = joueur le plus proche, sinon le local). Un seul écran à la fois.
## Contrat UI : `ShowcaseUI` doit débiter et créditer le joueur de méta `buyer_slot` (Players.state_of), pas le joueur 1.
func open_shop(who: Node = null) -> bool:
	if is_open() or stock.is_empty():
		return false
	var actor: Node = who if who != null else _near_player()
	_buyer = CoopRules.state_of(actor)
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	_ui = ShowcaseUI.new()
	_ui.set_meta(&"buyer_slot", _buyer.slot)
	host.add_child(_ui)
	_ui.open_shop(stock_view(_buyer), price_for, "MARCHAND")
	_ui.item_taken.connect(_on_item_taken)
	_ui.finished.connect(func() -> void: closed.emit())
	return true


func _on_item_taken(index: int, _id: StringName) -> void:
	if index >= 0 and index < stock.size():
		var e: Dictionary = stock[index]
		var buyer := _buyer if _buyer != null else RunState.local()
		var by: Array = e.get("sold_by", [])
		if not by.has(buyer.slot):
			by.append(buyer.slot)
		e["sold_by"] = by
		e["sold"] = by.size() >= maxi(Players.count(), 1) # solo : vendu dès le premier achat
		buyer.add_counter("merchant.buys")


func to_dict() -> Dictionary:
	return {"x": position.x, "y": position.y, "stock": stock.duplicate(true)}
