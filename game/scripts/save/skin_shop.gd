class_name SkinShop
extends RefCounted
## Boutique de skins : prix en rubis lus dans data/shop.json (modifiables sans toucher au code). Purement cosmétique :
## aucun achat en argent réel, aucun effet sur le jeu. L'achat lui-même est Profile.buy_skin(skin_id) ; l'équipement reste
## Profile.set_selected_skin. Un skin peut s'obtenir par sa condition (Skins.rule_of, victoire en Difficile) OU s'acheter : les
## deux voies coexistent, la première qui aboutit le débloque (clé « skin:<id> », Profile.unlocked_skins).

const SHOP_PATH := "res://data/shop.json"
const FALLBACK_PRICE := 250

## Données injectables (tests) ; null = data/shop.json.
static var data_override: Variant = null


static func data() -> Dictionary:
	if data_override is Dictionary:
		return data_override
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHOP_PATH))
	return parsed if parsed is Dictionary else {}


## Prix en rubis du skin (>= 1).
static func price_of(skin_id: Variant) -> int:
	var d := data()
	var table: Variant = d.get("skin_prices", {})
	if table is Dictionary and (table as Dictionary).has(str(skin_id)):
		return maxi(int(table[str(skin_id)]), 1)
	return maxi(int(d.get("skin_default_price", FALLBACK_PRICE)), 1)
