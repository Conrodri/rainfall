class_name Palette
extends RefCounted
## Palette SÉMANTIQUE centralisée (passe accessibilité 28/10/2026) : raretés d'objets, PV du joueur, télégraphes.
## Le mode daltonien vient de CvdPalette.mode() (0 aucun, 1 deutéranopie, 2 protanopie, 3 tritanopie ; lecture seule,
## mis en cache). Pas de filtre plein écran : seules les couleurs qui portent un sens changent. Les statuts, éléments
## et chiffres de dégâts restent dans CvdPalette (déjà vérifiés par tests/colorblind_test.gd).
## Règle : la couleur ne porte jamais seule le sens. Rareté : mot + rang (suffixe) + forme du fond (rank_corner / rank_border).

const RARITY_ORDER: Array[StringName] = [&"commun", &"peu_commun", &"rare", &"legendaire"]

## Mode « aucun » (couleurs historiques).
const RARITY_NONE := {
	&"commun": Color(0.78, 0.78, 0.8),
	&"peu_commun": Color(0.35, 0.82, 0.4),
	&"rare": Color(0.33, 0.6, 1.0),
	&"legendaire": Color(1.0, 0.65, 0.12),
}
## Rouge-vert (deutéranopie, protanopie) : gris / bleu / rose-carmin / jaune (plus de vert ni d orange).
const RARITY_RG := {
	&"commun": Color("#C9CBD0"),
	&"peu_commun": Color("#1E90FF"),
	&"rare": Color("#E0306E"),
	&"legendaire": Color("#FFE23A"),
}
## Tritanopie (bleu-jaune) : gris / vert / bleu moyen / orange (ΔE2000 >= 19 en tritanopie).
const RARITY_TRI := {
	&"commun": Color("#C9CBD0"),
	&"peu_commun": Color("#2FE04A"),
	&"rare": Color("#4A8FE0"),
	&"legendaire": Color("#FF9A1C"),
}

const HP_NONE := Color("#52C45A")
const HP_LOW_NONE := Color("#D9483A")
const HP_RG := Color("#3FB4E8") ## PV : bleu clair (le vert devient indiscernable du rouge)
const HP_LOW_RG := Color("#FFA21F") ## PV bas : orange vif
## Télégraphes ennemis : rouge d'origine, orange vif en rouge-vert (le rouge sombre disparaît en protanopie).
const TEL_NONE := Color(0.95, 0.10, 0.10)
const TEL_RG := Color(1.0, 0.60, 0.04)

static var override_mode := -1 ## tests : force le mode (>= 0)


static func mode() -> int:
	return clampi(override_mode, 0, 3) if override_mode >= 0 else CvdPalette.mode()


static func _table(m: int) -> Dictionary:
	if m == CvdPalette.DEUTAN or m == CvdPalette.PROTAN:
		return RARITY_RG
	if m == CvdPalette.TRITAN:
		return RARITY_TRI
	return RARITY_NONE


## Couleur d'une rareté d'objet (id : commun, peu_commun, rare, legendaire) dans le mode `m` (-1 = courant).
static func rarity(q: Variant, m: int = -1) -> Color:
	var tab := _table(mode() if m < 0 else m)
	return tab.get(StringName(str(q)), Color.WHITE)


## Rang 0..3 d'une rareté.
static func rank(q: Variant) -> int:
	return maxi(RARITY_ORDER.find(StringName(str(q))), 0)


## Redondance non colorée : vrai si les repères de forme / rang doivent s'afficher (un mode daltonien est actif).
static func shapes_on() -> bool:
	return mode() != CvdPalette.NONE


## Suffixe de rang ajouté au mot de rareté (« RARE · 3/4 ») ; vide hors mode daltonien.
static func rank_suffix(q: Variant) -> String:
	return " · %d/4" % (rank(q) + 1) if shapes_on() else ""


## Rayon des coins du fond de rareté : de plus en plus anguleux avec le rang (forme redondante), `base` hors mode daltonien.
static func rank_corner(q: Variant, base: int) -> int:
	if not shapes_on():
		return base
	return [18, 12, 5, 0][rank(q)]


## Épaisseur de la bordure du fond de rareté : 3 px de base, plus épaisse avec le rang en mode daltonien.
static func rank_border(q: Variant, base: int = 3) -> int:
	if not shapes_on():
		return base
	return base + rank(q) * 2


static func hp(m: int = -1) -> Color:
	var mm := mode() if m < 0 else m
	return HP_RG if mm == CvdPalette.DEUTAN or mm == CvdPalette.PROTAN else HP_NONE


static func hp_low(m: int = -1) -> Color:
	var mm := mode() if m < 0 else m
	return HP_LOW_RG if mm == CvdPalette.DEUTAN or mm == CvdPalette.PROTAN else HP_LOW_NONE


## Teinte de base d'un télégraphe (rouge ou orange) : l'alpha est celui de l'appelant.
static func telegraph_tint(m: int = -1) -> Color:
	var mm := mode() if m < 0 else m
	return TEL_RG if mm == CvdPalette.DEUTAN or mm == CvdPalette.PROTAN else TEL_NONE


## Applique la teinte du mode à une couleur de télégraphe rouge (alpha conservé).
static func telegraph(c: Color) -> Color:
	var t := telegraph_tint()
	return Color(t.r, t.g, t.b, c.a)
