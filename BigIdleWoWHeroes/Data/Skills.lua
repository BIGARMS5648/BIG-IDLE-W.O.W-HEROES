-- Active skills. Every value is { base, perLevel }; level 1-5 comes from skill
-- points, 6-10 only from "+All Skill Levels" gear.
--
-- act:  "count" = fires every n basic attacks, "cd" = cooldown, "aura" = always on.
-- kind: dmg | dot | field | heal | shield | buff | debuff | aura | revive
local _, ns = ...

-- Passive-only stats that the talent trees use.
ns.AFFIX.regenPct = { t = "regenPct", l = "flat", n = { "초당 최대 생명력 회복", "Max Health Regen/s" }, f = "pct2" }
ns.AFFIX.hpkPct   = { t = "hpkPct",   l = "flat", n = { "처치 시 최대 생명력 회복", "Max Health per Kill" }, f = "pct2" }

ns.SKILL_MAX = 5
ns.SKILL_CAP = 10

-- Status ailments. power is interpreted per kind (see Systems/Combat.lua).
ns.STATUS = {
	chill   = { name = { "냉기 둔화", "Chilled" },  dur = 4,   power = 30, hex = "80c0ff" },
	freeze  = { name = { "빙결", "Frozen" },        dur = 1.5, hex = "a0e0ff" },
	stun    = { name = { "기절", "Stunned" },       dur = 2,   hex = "ffff80" },
	ignite  = { name = { "발화", "Ignited" },       dur = 4,   power = 25, school = "fire", hex = "ff8040" },
	bleed   = { name = { "출혈", "Bleeding" },      dur = 6,   power = 20, school = "phys", hex = "ff4040" },
	poison  = { name = { "중독", "Poisoned" },      dur = 6,   school = "nature", hex = "70e070" },
	corrupt = { name = { "부패", "Corrupted" },     dur = 9,   school = "shadow", hex = "b080ff" },
	shock   = { name = { "감전", "Shocked" },       dur = 6,   power = 20, hex = "ffe060" },
	weaken  = { name = { "약화", "Weakened" },      dur = 8,   hex = "c0a080" },
	curse   = { name = { "저주", "Cursed" },        dur = 10,  hex = "9060c0" },
}

ns.SKILLS = {}

local function S(id, t)
	t.id = id
	ns.SKILLS[id] = t
end

------------------------------------------------------------------------ Warrior
S("shield_slam", { name = { "방패 밀쳐내기", "Shield Slam" }, icon = "INV_Shield_05",
	act = "count", n = 4, kind = "dmg", school = "phys", v = { 220, 20 }, targets = 1, status = { "stun", 0.3 },
	desc = { "기본 공격 4회마다 대상에게 %s%% 물리 피해를 주고 30%% 확률로 기절시킵니다.", "Every 4th attack deals %s%% physical damage with a 30%% chance to stun." } })
S("thunder_clap", { name = { "천둥벼락", "Thunder Clap" }, icon = "Spell_Nature_ThunderClap",
	act = "cd", cd = 9, kind = "dmg", school = "phys", v = { 110, 12 }, targets = 5, status = { "chill", 1 },
	desc = { "주위 적 5명에게 %s%% 물리 피해를 주고 공격 속도를 늦춥니다.", "Deals %s%% physical damage to 5 enemies and slows their attacks." } })
S("revenge", { name = { "복수", "Revenge" }, icon = "Ability_Warrior_Revenge",
	act = "count", n = 3, kind = "dmg", school = "phys", v = { 160, 15 }, targets = 3,
	desc = { "기본 공격 3회마다 적 3명에게 %s%% 물리 피해를 줍니다.", "Every 3rd attack deals %s%% physical damage to 3 enemies." } })
S("commanding_shout", { name = { "지휘의 외침", "Commanding Shout" }, icon = "Ability_Warrior_BattleShout",
	act = "aura", kind = "aura", mods = { { "hpPct", 6, 1.5 } },
	desc = { "장착하는 동안 파티 전원의 최대 생명력이 %s%% 증가합니다.", "While equipped, the party has %s%% more maximum health." } })
S("shield_wall", { name = { "방패의 벽", "Shield Wall" }, icon = "Ability_Warrior_ShieldWall",
	act = "cd", cd = 35, kind = "buff", target = "self", dur = 8, mods = { { "dr", 35, 3 } }, when = { self = 0.6 },
	desc = { "생명력이 60%% 아래로 떨어지면 8초 동안 받는 피해가 %s%% 감소합니다.", "Below 60%% health: take %s%% less damage for 8 sec." } })
S("last_stand", { name = { "최후의 저항", "Last Stand" }, icon = "Spell_Holy_AshesToAshes",
	act = "cd", cd = 45, kind = "heal", target = "self", v = { 30, 4 }, when = { self = 0.4 },
	desc = { "생명력이 40%% 아래로 떨어지면 최대 생명력의 %s%%를 즉시 회복합니다.", "Below 40%% health: instantly restore %s%% of maximum health." } })

------------------------------------------------------------------------ Druid
S("maul", { name = { "후려갈기기", "Maul" }, icon = "Ability_Druid_Maul",
	act = "count", n = 3, kind = "dmg", school = "phys", v = { 200, 18 }, targets = 1,
	desc = { "기본 공격 3회마다 대상에게 %s%% 물리 피해를 줍니다.", "Every 3rd attack deals %s%% physical damage." } })
S("swipe", { name = { "휘둘러치기", "Swipe" }, icon = "INV_Misc_MonsterClaw_03",
	act = "cd", cd = 6, kind = "dmg", school = "phys", v = { 90, 10 }, targets = 4, status = { "bleed", 0.5 },
	desc = { "적 4명에게 %s%% 물리 피해를 주고 50%% 확률로 출혈을 일으킵니다.", "Deals %s%% physical damage to 4 enemies; 50%% chance to bleed." } })
S("demo_roar", { name = { "위협의 포효", "Demoralizing Roar" }, icon = "Ability_Druid_DemoralizingRoar",
	act = "cd", cd = 18, kind = "debuff", status = "weaken", v = { 20, 2 }, dur = 8, targets = 99,
	desc = { "8초 동안 모든 적이 주는 피해가 %s%% 감소합니다.", "All enemies deal %s%% less damage for 8 sec." } })
S("thorns", { name = { "가시", "Thorns" }, icon = "Spell_Nature_Thorns",
	act = "aura", kind = "aura", mods = { { "thorns", 60, 15 } },
	desc = { "장착하는 동안 파티원을 근접 공격한 적이 공격력의 %s%%만큼 자연 피해를 입습니다.", "While equipped, melee attackers take nature damage equal to %s%% of the victim's attack." } })
S("frenzied_regen", { name = { "광포한 재생력", "Frenzied Regeneration" }, icon = "Ability_BullRush",
	act = "cd", cd = 30, kind = "heal", target = "self", v = { 4, 0.5 }, hot = 8, when = { self = 0.6 },
	desc = { "생명력이 60%% 아래로 떨어지면 8초 동안 매초 최대 생명력의 %s%%를 회복합니다.", "Below 60%% health: restore %s%% of maximum health every sec for 8 sec." } })
S("barkskin", { name = { "나무 껍질", "Barkskin" }, icon = "Spell_Nature_StoneClawTotem",
	act = "cd", cd = 40, kind = "buff", target = "party", dur = 8, mods = { { "dr", 15, 2 } }, when = { ally = 0.6 },
	desc = { "파티원이 위험해지면 8초 동안 파티 전원이 받는 피해가 %s%% 감소합니다.", "When an ally is in danger, the party takes %s%% less damage for 8 sec." } })

------------------------------------------------------------------------ Priest
S("heal", { name = { "치유", "Heal" }, icon = "Spell_Holy_Heal",
	act = "cd", cd = 5, kind = "heal", target = "lowest", v = { 22, 3 }, when = { ally = 0.8 },
	desc = { "생명력이 가장 낮은 아군의 최대 생명력의 %s%%를 회복시킵니다.", "Restores %s%% of maximum health to the most injured ally." } })
S("fortitude", { name = { "신의 권능: 인내", "Power Word: Fortitude" }, icon = "Spell_Holy_WordFortitude",
	act = "aura", kind = "aura", mods = { { "hpPct", 8, 2 } },
	desc = { "장착하는 동안 파티 전원의 최대 생명력이 %s%% 증가합니다.", "While equipped, the party has %s%% more maximum health." } })
S("holy_nova", { name = { "신성한 폭발", "Holy Nova" }, icon = "Spell_Holy_HolyNova",
	act = "cd", cd = 10, kind = "dmg", school = "holy", v = { 120, 12 }, targets = 99, healAll = { 6, 1 },
	desc = { "모든 적에게 %s%% 신성 피해를 주고 파티 전원의 생명력을 조금 회복시킵니다.", "Deals %s%% holy damage to all enemies and lightly heals the party." } })
S("pw_shield", { name = { "신의 권능: 보호막", "Power Word: Shield" }, icon = "Spell_Holy_PowerWordShield",
	act = "cd", cd = 12, kind = "shield", target = "lowest", v = { 18, 3 }, dur = 10, when = { ally = 0.9 },
	desc = { "가장 위험한 아군에게 최대 생명력의 %s%%만큼 피해를 흡수하는 보호막을 씌웁니다.", "Shields the most injured ally for %s%% of their maximum health." } })
S("prayer_of_healing", { name = { "치유의 기원", "Prayer of Healing" }, icon = "Spell_Holy_PrayerOfHealing02",
	act = "cd", cd = 14, kind = "heal", target = "all", v = { 14, 2 }, when = { ally = 0.7 },
	desc = { "파티 전원의 최대 생명력의 %s%%를 회복시킵니다.", "Restores %s%% of maximum health to the whole party." } })
S("resurrection", { name = { "부활", "Resurrection" }, icon = "Spell_Holy_Resurrection",
	act = "cd", cd = 45, kind = "revive", v = { 30, 5 },
	desc = { "쓰러진 파티원을 최대 생명력의 %s%% 상태로 되살립니다.", "Revives a fallen party member at %s%% health." } })

------------------------------------------------------------------------ Paladin
S("holy_light", { name = { "성스러운 빛", "Holy Light" }, icon = "Spell_Holy_HolyBolt",
	act = "cd", cd = 6, kind = "heal", target = "lowest", v = { 26, 3.5 }, when = { ally = 0.75 },
	desc = { "생명력이 가장 낮은 아군의 최대 생명력의 %s%%를 회복시킵니다.", "Restores %s%% of maximum health to the most injured ally." } })
S("devotion_aura", { name = { "헌신의 오라", "Devotion Aura" }, icon = "Spell_Holy_DevotionAura",
	act = "aura", kind = "aura", mods = { { "armorPct", 12, 3 } },
	desc = { "장착하는 동안 파티 전원의 방어도가 %s%% 증가합니다.", "While equipped, the party has %s%% more armor." } })
S("judgement", { name = { "심판", "Judgement" }, icon = "Spell_Holy_RighteousFury",
	act = "count", n = 4, kind = "dmg", school = "holy", v = { 240, 20 }, targets = 1, status = { "stun", 0.2 },
	desc = { "기본 공격 4회마다 대상에게 %s%% 신성 피해를 주고 20%% 확률로 기절시킵니다.", "Every 4th attack deals %s%% holy damage with a 20%% chance to stun." } })
S("blessing_of_might", { name = { "힘의 축복", "Blessing of Might" }, icon = "Spell_Holy_FistOfJustice",
	act = "aura", kind = "aura", mods = { { "atkPct", 8, 2 } },
	desc = { "장착하는 동안 파티 전원의 공격력이 %s%% 증가합니다.", "While equipped, the party has %s%% more attack." } })
S("lay_on_hands", { name = { "신의 축복", "Lay on Hands" }, icon = "Spell_Holy_LayOnHands",
	act = "cd", cd = 60, cdPer = -5, kind = "heal", target = "lowest", v = { 100, 0 }, when = { ally = 0.3 },
	desc = { "생명력이 30%% 아래인 아군을 즉시 %s%% 회복시킵니다. 레벨마다 재사용 대기시간이 5초 감소합니다.", "Fully heals (%s%%) an ally below 30%% health. Cooldown drops by 5 sec per level." } })
S("divine_protection", { name = { "신의 가호", "Divine Protection" }, icon = "Spell_Holy_DivineIntervention",
	act = "cd", cd = 50, kind = "shield", target = "all", v = { 20, 3 }, dur = 6, when = { ally = 0.5 },
	desc = { "파티원이 위험해지면 전원에게 최대 생명력의 %s%%를 흡수하는 보호막을 씌웁니다.", "When an ally is in danger, shields everyone for %s%% of their maximum health." } })

------------------------------------------------------------------------ Hunter
S("multi_shot", { name = { "일제 사격", "Multi-Shot" }, icon = "Ability_UpwardArrow",
	act = "count", n = 4, kind = "dmg", school = "phys", v = { 130, 12 }, targets = 3,
	desc = { "기본 공격 4회마다 적 3명에게 %s%% 물리 피해를 줍니다.", "Every 4th attack deals %s%% physical damage to 3 enemies." } })
S("aimed_shot", { name = { "조준 사격", "Aimed Shot" }, icon = "INV_Spear_07",
	act = "cd", cd = 7, kind = "dmg", school = "phys", v = { 320, 35 }, targets = 1, critBonus = 50,
	desc = { "대상에게 %s%% 물리 피해를 줍니다. 치명타 확률이 50%% 높습니다.", "Deals %s%% physical damage with +50%% crit chance." } })
S("serpent_sting", { name = { "독사 쐐기", "Serpent Sting" }, icon = "Ability_Hunter_Quickshot",
	act = "count", n = 5, kind = "dot", school = "nature", status = "poison", v = { 40, 6 }, dur = 6, targets = 1,
	desc = { "기본 공격 5회마다 대상을 중독시켜 6초 동안 매초 %s%% 자연 피해를 줍니다.", "Every 5th attack poisons the target for %s%% nature damage per sec for 6 sec." } })
S("rapid_fire", { name = { "속사", "Rapid Fire" }, icon = "Ability_Hunter_RunningShot",
	act = "cd", cd = 30, kind = "buff", target = "self", dur = 8, mods = { { "aspdMult", 40, 6 } },
	desc = { "8초 동안 공격 속도가 %s%% 증가합니다.", "Attack speed increased by %s%% for 8 sec." } })
S("volley", { name = { "연발 사격", "Volley" }, icon = "Ability_Marksmanship",
	act = "cd", cd = 14, kind = "field", school = "phys", v = { 45, 6 }, tick = 0.5, dur = 4, targets = 99,
	desc = { "4초 동안 0.5초마다 모든 적에게 %s%% 물리 피해를 줍니다.", "Rains arrows for 4 sec, dealing %s%% physical damage to all enemies every 0.5 sec." } })
S("call_beast", { name = { "야수의 격노", "Bestial Wrath" }, icon = "Ability_Druid_FerociousBite",
	act = "cd", cd = 40, kind = "field", school = "phys", v = { 100, 15 }, tick = 1, dur = 12, targets = 1,
	desc = { "야수를 불러 12초 동안 매초 %s%% 물리 피해를 줍니다.", "Calls a beast that deals %s%% physical damage every sec for 12 sec." } })

------------------------------------------------------------------------ Mage
S("fireball", { name = { "화염구", "Fireball" }, icon = "Spell_Fire_FlameBolt",
	act = "cd", cd = 4, kind = "dmg", school = "fire", v = { 260, 25 }, targets = 3, status = { "ignite", 0.4 },
	desc = { "폭발하는 화염구로 적 3명에게 %s%% 화염 피해를 줍니다. 40%% 확률로 발화시킵니다.", "An exploding fireball deals %s%% fire damage to 3 enemies; 40%% chance to ignite." } })
S("frost_nova", { name = { "얼음 회오리", "Frost Nova" }, icon = "Spell_Frost_FrostNova",
	act = "cd", cd = 10, kind = "dmg", school = "frost", v = { 100, 10 }, targets = 99, status = { "freeze", 0.6 },
	desc = { "모든 적에게 %s%% 냉기 피해를 주고 60%% 확률로 얼립니다.", "Deals %s%% frost damage to all enemies; 60%% chance to freeze." } })
S("arcane_missiles", { name = { "신비한 화살", "Arcane Missiles" }, icon = "Spell_Nature_StarFall",
	act = "count", n = 3, kind = "dmg", school = "arcane", v = { 70, 8 }, targets = 1, hits = 3,
	desc = { "기본 공격 3회마다 대상에게 %s%% 비전 피해를 3번 줍니다.", "Every 3rd attack fires 3 missiles for %s%% arcane damage each." } })
S("blizzard", { name = { "눈보라", "Blizzard" }, icon = "Spell_Frost_IceStorm",
	act = "cd", cd = 14, kind = "field", school = "frost", v = { 50, 6 }, tick = 0.5, dur = 4, targets = 99, status = { "chill", 0.5 },
	desc = { "4초 동안 0.5초마다 모든 적에게 %s%% 냉기 피해를 주고 둔화시킵니다.", "For 4 sec, deals %s%% frost damage to all enemies every 0.5 sec and chills them." } })
S("flamestrike", { name = { "불기둥", "Flamestrike" }, icon = "Spell_Fire_SelfDestruct",
	act = "cd", cd = 12, kind = "dmg", school = "fire", v = { 380, 40 }, targets = 5, status = { "ignite", 0.5 },
	desc = { "적 5명에게 %s%% 화염 피해를 줍니다. 50%% 확률로 발화시킵니다.", "Deals %s%% fire damage to 5 enemies; 50%% chance to ignite." } })
S("pyroblast", { name = { "불덩이 작렬", "Pyroblast" }, icon = "Spell_Fire_Fireball02",
	act = "cd", cd = 18, kind = "dmg", school = "fire", v = { 900, 90 }, targets = 1, status = { "ignite", 1 },
	desc = { "대상에게 %s%% 화염 피해를 주고 발화시킵니다.", "Deals %s%% fire damage to one enemy and ignites it." } })

------------------------------------------------------------------------ Rogue
S("sinister_strike", { name = { "사악한 일격", "Sinister Strike" }, icon = "Spell_Shadow_RitualOfSacrifice",
	act = "count", n = 3, kind = "dmg", school = "phys", v = { 190, 18 }, targets = 1,
	desc = { "기본 공격 3회마다 대상에게 %s%% 물리 피해를 줍니다.", "Every 3rd attack deals %s%% physical damage." } })
S("blade_flurry", { name = { "폭풍의 칼날", "Blade Flurry" }, icon = "Ability_Warrior_PunishingBlow",
	act = "cd", cd = 25, kind = "buff", target = "self", dur = 10, mods = { { "multi", 60, 8 }, { "aspdMult", 15, 2 } },
	desc = { "10초 동안 연속 타격 확률이 %s%% 증가하고 공격이 빨라집니다.", "For 10 sec, multistrike chance is increased by %s%% and attacks are faster." } })
S("rupture", { name = { "파열", "Rupture" }, icon = "Ability_Rogue_Rupture",
	act = "count", n = 5, kind = "dot", school = "phys", status = "bleed", v = { 60, 8 }, dur = 8, targets = 1,
	desc = { "기본 공격 5회마다 대상을 찢어 8초 동안 매초 %s%% 물리 피해를 줍니다.", "Every 5th attack makes the target bleed for %s%% physical damage per sec for 8 sec." } })
S("evasion", { name = { "회피", "Evasion" }, icon = "Spell_Shadow_ShadowWard",
	act = "cd", cd = 30, kind = "buff", target = "self", dur = 8, mods = { { "dodge", 40, 4 } }, when = { self = 0.7 },
	desc = { "생명력이 70%% 아래로 떨어지면 8초 동안 회피 확률이 %s%% 증가합니다.", "Below 70%% health: dodge chance increased by %s%% for 8 sec." } })
S("eviscerate", { name = { "절개", "Eviscerate" }, icon = "Ability_Rogue_Eviscerate",
	act = "count", n = 6, kind = "dmg", school = "phys", v = { 520, 50 }, targets = 1,
	desc = { "기본 공격 6회마다 대상에게 %s%% 물리 피해를 줍니다.", "Every 6th attack deals %s%% physical damage." } })
S("adrenaline_rush", { name = { "아드레날린 촉진", "Adrenaline Rush" }, icon = "Spell_Shadow_ShadowWordDominate",
	act = "cd", cd = 45, kind = "buff", target = "self", dur = 10, mods = { { "aspdMult", 50, 8 } },
	desc = { "10초 동안 공격 속도가 %s%% 증가합니다.", "Attack speed increased by %s%% for 10 sec." } })

------------------------------------------------------------------------ Warlock
S("shadow_bolt", { name = { "어둠의 화살", "Shadow Bolt" }, icon = "Spell_Shadow_ShadowBolt",
	act = "count", n = 2, kind = "dmg", school = "shadow", v = { 230, 22 }, targets = 1,
	desc = { "기본 공격 2회마다 대상에게 %s%% 암흑 피해를 줍니다.", "Every 2nd attack deals %s%% shadow damage." } })
S("corruption", { name = { "부패", "Corruption" }, icon = "Spell_Shadow_AbominationExplosion",
	act = "cd", cd = 6, kind = "dot", school = "shadow", status = "corrupt", v = { 45, 6 }, dur = 9, targets = 3,
	desc = { "적 3명을 부패시켜 9초 동안 매초 %s%% 암흑 피해를 줍니다.", "Corrupts 3 enemies for %s%% shadow damage per sec for 9 sec." } })
S("rain_of_fire", { name = { "불의 비", "Rain of Fire" }, icon = "Spell_Shadow_RainOfFire",
	act = "cd", cd = 13, kind = "field", school = "fire", v = { 45, 5 }, tick = 0.5, dur = 4, targets = 99, status = { "ignite", 0.15 },
	desc = { "4초 동안 0.5초마다 모든 적에게 %s%% 화염 피해를 줍니다.", "For 4 sec, deals %s%% fire damage to all enemies every 0.5 sec." } })
S("summon_imp", { name = { "임프 소환", "Summon Imp" }, icon = "Spell_Shadow_SummonImp",
	act = "cd", cd = 30, kind = "field", school = "fire", v = { 90, 12 }, tick = 1, dur = 15, targets = 1,
	desc = { "임프를 소환해 15초 동안 매초 %s%% 화염 피해를 줍니다.", "Summons an imp that deals %s%% fire damage every sec for 15 sec." } })
S("drain_life", { name = { "생명력 흡수", "Drain Life" }, icon = "Spell_Shadow_LifeDrain02",
	act = "cd", cd = 9, kind = "dmg", school = "shadow", v = { 250, 25 }, targets = 1, drain = 100,
	desc = { "대상에게 %s%% 암흑 피해를 주고 준 피해만큼 자신의 생명력을 회복합니다.", "Deals %s%% shadow damage and heals you for the damage dealt." } })
S("curse_of_elements", { name = { "원소의 저주", "Curse of the Elements" }, icon = "Spell_Shadow_ChillTouch",
	act = "cd", cd = 20, kind = "debuff", status = "curse", v = { 15, 2 }, dur = 10, targets = 99,
	desc = { "10초 동안 모든 적이 받는 피해가 %s%% 증가합니다.", "All enemies take %s%% more damage for 10 sec." } })

------------------------------------------------------------------------ Shaman
S("lightning_bolt", { name = { "번개 화살", "Lightning Bolt" }, icon = "Spell_Nature_Lightning",
	act = "count", n = 2, kind = "dmg", school = "nature", v = { 210, 20 }, targets = 1, status = { "shock", 0.25 },
	desc = { "기본 공격 2회마다 대상에게 %s%% 자연 피해를 줍니다. 25%% 확률로 감전시킵니다.", "Every 2nd attack deals %s%% nature damage; 25%% chance to shock." } })
S("chain_lightning", { name = { "연쇄 번개", "Chain Lightning" }, icon = "Spell_Nature_ChainLightning",
	act = "cd", cd = 7, kind = "dmg", school = "nature", v = { 170, 17 }, targets = 4, status = { "shock", 0.3 },
	desc = { "적 4명에게 튀는 번개로 %s%% 자연 피해를 줍니다.", "Lightning arcs to 4 enemies for %s%% nature damage." } })
S("earth_shock", { name = { "대지 충격", "Earth Shock" }, icon = "Spell_Nature_EarthShock",
	act = "cd", cd = 8, kind = "dmg", school = "nature", v = { 240, 24 }, targets = 1, status = { "stun", 0.4 },
	desc = { "대상에게 %s%% 자연 피해를 주고 40%% 확률로 기절시킵니다.", "Deals %s%% nature damage with a 40%% chance to stun." } })
S("windfury_totem", { name = { "질풍의 토템", "Windfury Totem" }, icon = "Spell_Nature_Windfury",
	act = "aura", kind = "aura", mods = { { "aspd", 6, 1.5 } },
	desc = { "장착하는 동안 파티 전원의 공격 속도가 %s%% 증가합니다.", "While equipped, the party attacks %s%% faster." } })
S("searing_totem", { name = { "불타는 토템", "Searing Totem" }, icon = "Spell_Fire_SearingTotem",
	act = "cd", cd = 20, kind = "field", school = "fire", v = { 80, 10 }, tick = 1, dur = 15, targets = 1,
	desc = { "토템을 세워 15초 동안 매초 %s%% 화염 피해를 줍니다.", "Drops a totem that deals %s%% fire damage every sec for 15 sec." } })
S("bloodlust", { name = { "피의 욕망", "Bloodlust" }, icon = "Spell_Nature_Bloodlust",
	act = "cd", cd = 60, kind = "buff", target = "party", dur = 10, mods = { { "aspdMult", 30, 4 }, { "atkPct", 10, 1 } },
	desc = { "10초 동안 파티 전원의 공격 속도가 %s%% 증가하고 공격력이 오릅니다.", "For 10 sec the whole party attacks %s%% faster and hits harder." } })

------------------------------------------------------------------------
-- Value of a skill at a level, and its description text.
------------------------------------------------------------------------
function ns.SkillValue(id, lvl)
	local sk = ns.SKILLS[id]
	local v = sk.v or (sk.mods and { sk.mods[1][2], sk.mods[1][3] }) or { 0, 0 }
	return v[1] + v[2] * (math.max(1, lvl) - 1)
end

function ns.SkillCooldown(id, lvl)
	local sk = ns.SKILLS[id]
	if not sk.cd then return 0 end
	return math.max(5, sk.cd + (sk.cdPer or 0) * (math.max(1, lvl) - 1))
end

function ns.SkillDesc(id, lvl)
	local sk = ns.SKILLS[id]
	return string.format(ns.N(sk.desc), ns.U.num(ns.SkillValue(id, lvl), 1))
end

function ns.SkillActText(id, lvl)
	local sk = ns.SKILLS[id]
	if sk.act == "aura" then
		return ns.T("지속 효과", "Aura")
	elseif sk.act == "count" then
		return string.format(ns.T("기본 공격 %d회마다 발동", "Every %d basic attacks"), sk.n)
	end
	return string.format(ns.T("재사용 대기시간 %s초", "%s sec cooldown"), ns.U.num(ns.SkillCooldown(id, lvl), 1))
end
