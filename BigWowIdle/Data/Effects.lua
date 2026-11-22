-- Spell effects of the original game, for the 효과 check of /bwi model: per
-- spell the visual kits of its spell visual (precast = while casting, cast =
-- the release, impact = on the target) and the model files of its effects
-- (missile = what flies, hand = the glow in the hands, hit = the impact).
-- Kit ids and effect paths are the 1.12 client's (SpellVisual,
-- SpellVisualKit, SpellVisualEffectName); file ids come from the community
-- listfile (spells/<name>.m2).
-- self = it lands on the caster (a heal); omni = cast all around (anims
-- 52/54) instead of at the target (51/53).
local _, ns = ...

ns.SPELL_FX = {
	{ key = "lightning_bolt", name = "번개 화살", class = "SHAMAN", spell = 403,
		precast = 124, cast = 72, impact = 283, missile = 166497, hand = 166492, hit = 166496 },
	{ key = "fireball", name = "화염구", class = "MAGE", spell = 133,
		precast = 30, cast = 38, impact = 286, missile = 166129, hand = 166120, hit = 166583 },
	{ key = "frostbolt", name = "얼음 화살", class = "MAGE", spell = 116,
		precast = 194, cast = 202, impact = 4991, missile = 166214, hand = 166381, hit = 166370 },
	{ key = "shadow_bolt", name = "어둠의 화살", class = "WARLOCK", spell = 686,
		precast = 114, cast = 118, impact = 219, missile = 165891, hand = 166807, hit = 165890 },
	{ key = "wrath", name = "천벌", class = "DRUID", spell = 5176,
		precast = 3290, cast = 3291, impact = 3292, missile = 167213, hand = 167214, hit = 167212 },
	{ key = "arcane_shot", name = "신비한 사격", class = "HUNTER", spell = 3044,
		impact = 419, missile = 165592, hit = 166525 },
	{ key = "smite", name = "성스러운 일격", class = "PRIEST", spell = 585,
		precast = 184, cast = 119, impact = 291, hand = 166336, hit = 166354 },
	{ key = "heal", name = "치유", class = "PRIEST", spell = 2054, self = true, omni = true,
		precast = 99, cast = 270, impact = 232, hand = 166336, hit = 166292 },
	{ key = "healing_wave", name = "치유의 물결", class = "SHAMAN", spell = 331, self = true, omni = true,
		precast = 100, cast = 183, impact = 101, hand = 166605, hit = 166703 },
}
