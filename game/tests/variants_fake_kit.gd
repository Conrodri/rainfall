extends RefCounted
## Kit factice du variants_test (CharacterData.kit_paths) : base Ardent + une variante codée au slot 2.

static func character() -> CharacterData:
	var c := ArdentKit.variant_a()
	c.id = &"fake"
	return c


## Contrat « Variantes de sorts » : SpellData de la variante, null si non codée.
static func variant(slot: int, variant_id: StringName) -> SpellData:
	if slot == 2 and variant_id == &"fake_nova_b":
		var s := SpellData.new()
		s.id = &"fake_nova_b"
		s.display_name = "Nova factice"
		s.behavior = SpellData.Behavior.NOVA
		s.coef = 4.0
		s.base_cooldown = 9.0
		s.radius_u = 2.0
		return s
	return null
