-- =============================================================
-- LOF (LootOptimizer Forever) -- Data/StatWeights.lua
-- Reference data ONLY (no logic). Read by ResolverUpgrade.lua.
-- Stat weights per class and talent tree: score = sum(stat x weight).
-- Change the numbers here; the Upgrade Advisor follows automatically.
-- =============================================================
--
-- Changelog
-- ---------
-- v0.2.5: Blizzard development notes of 2 and 3 Nov 2026 (launch tuning;
--   Peter, 4 Nov). Only changes with a Blizzard source (stat weights watch
--   3 and 4 Nov). Retribution Int 0.3 -> 0.5, SP/Dmg 0.7 -> 0.8 (Champion
--   of the Light back to 60% of Int). Holy Paladin Crit 8 -> 9.5 (Holy
--   Power: +50% critical healing). Resto Druid Spi 0.6 -> 0.8 (Bloom heals
--   100% of Spirit). Feral DPS 3.0 -> 3.5, AP 0.5 -> 0.55 (Shred/Claw/
--   Ravage weapon damage up). Enhancement Int 0.7 -> 0.9 (Mental
--   Dexterity 150% of Int as AP), DPS 3.2 -> 3.5 (Stormstrike 150%).
--   Hunter AP 0.45 -> 0.5. Rogue AP 0.5 -> 0.55 (poison AP doubled).
--   Arcane Int 0.9 -> 0.85 (Arcane Blast 12%). Fire Crit 11 -> 10
--   (Critical Mass max 6%). Demonology Sta 0.5 -> 0.4 (pet HP per Sta
--   down). Not changed: Warrior Revenge AP scaling (datamine only).
-- v0.2.4: Hit and Crit come as RATING on Forever (measured 23 Oct, Peter:
--   Band of Accuria HIT_RATING 9 = "0.9%", Quick Strike Ring CRIT_RATING
--   7 = "0.5%"). The weights stay per 1%; the rating keys move to
--   `related` with factor 1/10 (hit) and 1/14 (crit). Before, 9 hit
--   rating counted as 9% (10-14x too much). Spell hit / spell crit
--   rating: not measured yet, count 0 until measured. Branch, after
--   launch.
-- v0.2.3: Spell Damage gets its own column Dmg (audit 1.6.5, Peter 21 Oct).
--   Forever reports one "damage and healing" effect as BOTH keys
--   (Glowing Copper Boots: healing 9, damage 3), so healers counted it
--   twice in 0.2.2. Dmg = the SP weight for the 12 non-healer trees with
--   SP; healers count only Heal. SP is Spell Power only again.
-- v0.2.2: Spell Damage and Spell Healing counted (Peter, 21 Oct 2026).
--   Keys measured on Forever (Glowing Copper Boots): SPELL_DAMAGE_DONE
--   counts as SP for every tree; SPELL_HEALING_DONE is the new column
--   Heal, weighted only for the five healer trees (= their SP weight).
--   Before: both keys counted 0, so a Retribution alt was told +61.1%
--   for boots that lose 3 Spell Damage (now -16%, no advice).
-- v0.2.1: Blizzard beta development notes of 15 Oct 2026 (Peter, 16 Oct):
--   Champion of the Light 10/20/30% of Int (was 20/40/60%) -> Retribution
--   Int 0.4 -> 0.3; Consecration coefficient 0.042 (was 0.095) ->
--   Retribution SP 0.8 -> 0.7; Arcane Blast now stacks on Intellect ->
--   Arcane Int 0.8 -> 0.9.
-- v0.2.0: Forever research of 15 Oct 2026 (Blizzard notes, Icy Veins,
--   Warcraft Tavern, wow.gg, Mobalytics; project doc
--   LOF_stat_weights_research_2026-10-15.md). Only changes backed by 2+
--   sources or a Blizzard mechanic (Peter, 16 Oct). No source publishes
--   numbers yet; these follow the published stat ORDER.
--   Feral DPS 0.1 -> 3.0 (weapon damage counts in Cat/Bear Form).
--   Enhancement Int 0.2 -> 0.7 (Mental Dexterity: 1 AP per Int).
--   Holy/Disc Priest: SP 1.0, Int 0.6, Spirit 0.8 / 0.7, Crit 5 / 6
--   (Healing Power > MP5 > Spirit > Int > Crit).
--   Shadow: Crit 6 -> 9, Hit 10 -> 8 (Shadowform doubles shadow crits).
--   Warlock: Spirit 0.5 (Life Tap scales with Spirit), Stamina 0.4 / 0.5
--   / 0.4, Affliction Crit 4 -> 8 (DoTs can crit).
--   Mage Spirit: Arcane 0.7, Fire 0.6, Frost 0.6.
--   Retribution: SP 0.45 -> 0.8, Int 0.2 -> 0.4, Hit 10 -> 12.
--   Resto Shaman: SP 1.0, Int 0.9. Resto Druid: SP 1.0, Spirit 0.6.
--   Not yet (sources disagree or one source): Prot Warrior, Prot Paladin,
--   Hunter BM/SV, Holy Paladin; new stats (Expertise, Haste, MP5, Defense).
-- v0.1.3: Forever Paladin changes (Peter, 8 Oct 2026): Holy Strike
--   (42.9% spell power), Seal of Righteousness with better spell power
--   scaling that can crit, Judgement no longer consumes the seal, Seal
--   of Fury (shield / taunt hit scale with spell power).
--   Retribution SP 0.2 -> 0.45, Protection SP 0.4 -> 0.5. Holy unchanged
--   (Spell Healing follows separately, after its stat key is measured).
--   Estimate, to be checked by Nick.
-- v0.1.2: Every tree has a melee DPS weight (Peter): trees without one
--   got DPS = 0.1 (wand 1.5, warrior 3.0 for comparison). A caster's
--   better melee weapon now gets a percentage instead of only the
--   equal-score rule; stats like Intellect still weigh far more.
-- v0.1.1: Every tree has an Armor weight (Peter): trees without one got
--   Armor = 0.01 (as Rogue / Hunter). Armor-only starter gear no longer
--   scores 0 for casters, so "grey -> green" upgrades get a percentage
--   (0 -> N has no finite percentage). Calico vs Heavy Linen stays
--   NOT_BETTER for casters.
-- v0.1.0: Initial version (LOF 1.3.0, document "LOF stat weights
--   (Forever) - voorstel v0.1", 2 Oct 2026).
--   - No published weights exist for WoW: Forever yet (also not in
--     Pawn, whose Forever scales are still empty). These are LOF's own
--     beta numbers: the known stat order per tree, adjusted for the
--     Forever changes (one Hit and Crit for everything, Spell Power on
--     caster weapons, wands no longer scale with Spell Power).
--   - Trees per class in the order of the talent window (left to
--     right); the names shown come from the game itself.
--   - Rogue order checked by Peter (Agility > AP > Strength); wand
--     weight 1.5 for casters checked by Peter.
-- =============================================================

local LOF = LOF
LOF.VERSION_DATA_STATWEIGHTS = "0.2.5"

LOF.Data = LOF.Data or {}

LOF.Data.StatWeights = {
    meta = {
        version    = "v0.2",
        date       = "2026-11-04",
        confidence = "beta",
        note       = "LOF's own weights; no published Forever weights exist yet.",
    },

    -- Column -> stat key(s) as C_Item.GetItemStats returns them on
    -- Forever (measured 2 Oct 2026). Hit and Crit come as rating (measured
    -- 23 Oct 2026); see `related` (v0.2.4).
    keys = {
        Str   = { "ITEM_MOD_STRENGTH_SHORT" },
        Agi   = { "ITEM_MOD_AGILITY_SHORT" },
        Sta   = { "ITEM_MOD_STAMINA_SHORT" },
        Int   = { "ITEM_MOD_INTELLECT_SHORT" },
        Spi   = { "ITEM_MOD_SPIRIT_SHORT" },
        AP    = { "ITEM_MOD_ATTACK_POWER_SHORT" },
        SP    = { "ITEM_MOD_SPELL_POWER_SHORT" },
        Dmg   = { "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" },
        Heal  = { "ITEM_MOD_SPELL_HEALING_DONE_SHORT" },
        Armor = { "RESISTANCE0_NAME" },
        -- Hit and Crit: no direct keys. Their rating keys are in `related`
        -- below (weights are per 1%, items give rating).
    },

    -- Weapon DPS (ITEM_MOD_DAMAGE_PER_SECOND_SHORT) uses the column:
    --   Wand     for a wand in the ranged slot,
    --   RangedDPS for other ranged weapons (bow, gun, crossbow, thrown),
    --   DPS      for melee weapons (off-hand counted at 50%, StatProfiles).
    -- A tree without RangedDPS uses DPS for ranged weapons too.

    -- Stats that count as a share of another column.
    related = {
        ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT = { of = "AP", factor = 0.25 },
        -- v0.2.4: rating -> percent (measured: 10 hit rating = 1%,
        -- 14 crit rating = 1%). Spell hit / spell crit: not measured.
        ITEM_MOD_HIT_RATING_SHORT  = { of = "Hit",  factor = 1 / 10 },
        ITEM_MOD_CRIT_RATING_SHORT = { of = "Crit", factor = 1 / 14 },
    },

    -- Everything else (resistances, unknown stats) counts 0.

    classes = {
        WARRIOR = { default = 1, trees = {
            { name = "Arms",       Str = 1.0, Agi = 0.6, Sta = 0.3, AP = 0.5, Hit = 12, Crit = 12, Armor = 0.01, DPS = 3.0 },
            { name = "Fury",       Str = 1.0, Agi = 0.6, Sta = 0.3, AP = 0.5, Hit = 13, Crit = 12, Armor = 0.01, DPS = 3.0 },
            { name = "Protection", Str = 0.6, Agi = 0.6, Sta = 1.0, AP = 0.3, Hit = 6,  Crit = 4,  Armor = 0.08, DPS = 1.5 },
        } },
        PALADIN = { default = 3, trees = {
            { name = "Holy",        Sta = 0.3, Int = 1.0, Spi = 0.4, SP = 0.8, Heal = 0.8, Crit = 9.5, Armor = 0.01, DPS = 0.1 },
            { name = "Protection",  Str = 0.6, Agi = 0.4, Sta = 1.0, Int = 0.3, AP = 0.2, SP = 0.5, Dmg = 0.5, Hit = 6, Crit = 3, Armor = 0.08, DPS = 1.0 },
            { name = "Retribution", Str = 1.0, Agi = 0.5, Sta = 0.3, Int = 0.5, AP = 0.5, SP = 0.8, Dmg = 0.8, Hit = 12, Crit = 12, Armor = 0.01, DPS = 3.0 },
        } },
        HUNTER = { default = 1, trees = {
            { name = "Beast Mastery", Agi = 1.0, Sta = 0.4, Int = 0.3, AP = 0.5, Hit = 10, Crit = 10, Armor = 0.01, RangedDPS = 2.5, DPS = 0.5 },
            { name = "Marksmanship",  Agi = 1.0, Sta = 0.3, Int = 0.3, AP = 0.5, Hit = 12, Crit = 12, Armor = 0.01, RangedDPS = 2.8, DPS = 0.5 },
            { name = "Survival",      Agi = 1.0, Sta = 0.3, Int = 0.3, AP = 0.5, Hit = 12, Crit = 12, Armor = 0.01, RangedDPS = 2.5, DPS = 0.5 },
        } },
        ROGUE = { default = 2, trees = {
            { name = "Assassination", Str = 0.45, Agi = 1.0, Sta = 0.3, AP = 0.55, Hit = 13, Crit = 12, Armor = 0.01, DPS = 2.8 },
            { name = "Combat",        Str = 0.45, Agi = 1.0, Sta = 0.3, AP = 0.55, Hit = 14, Crit = 11, Armor = 0.01, DPS = 3.5 },
            { name = "Subtlety",      Str = 0.45, Agi = 1.0, Sta = 0.3, AP = 0.55, Hit = 12, Crit = 12, Armor = 0.01, DPS = 3.0 },
        } },
        PRIEST = { default = 3, trees = {
            { name = "Discipline", Sta = 0.3, Int = 0.6, Spi = 0.7, SP = 1.0, Heal = 1.0, Crit = 6, Wand = 1.5, Armor = 0.01, DPS = 0.1 },
            { name = "Holy",       Sta = 0.3, Int = 0.6, Spi = 0.8, SP = 1.0, Heal = 1.0, Crit = 5, Wand = 1.5, Armor = 0.01, DPS = 0.1 },
            { name = "Shadow",     Sta = 0.3, Int = 0.6, Spi = 0.6, SP = 1.0, Dmg = 1.0, Hit = 8, Crit = 9, Wand = 1.5, Armor = 0.01, DPS = 0.1 },
        } },
        MAGE = { default = 2, trees = {
            { name = "Arcane", Sta = 0.3,  Int = 0.85, Spi = 0.7, SP = 1.0, Dmg = 1.0, Hit = 12, Crit = 8,  Wand = 1.5, Armor = 0.01, DPS = 0.1 },
            { name = "Fire",   Sta = 0.3,  Int = 0.7, Spi = 0.6, SP = 1.0, Dmg = 1.0, Hit = 12, Crit = 10, Wand = 1.5, Armor = 0.01, DPS = 0.1 },
            { name = "Frost",  Sta = 0.35, Int = 0.7, Spi = 0.6, SP = 1.0, Dmg = 1.0, Hit = 12, Crit = 8,  Wand = 1.5, Armor = 0.01, DPS = 0.1 },
        } },
        WARLOCK = { default = 1, trees = {
            { name = "Affliction",  Sta = 0.4, Int = 0.5, Spi = 0.5, SP = 1.0, Dmg = 1.0, Hit = 12, Crit = 8,  Wand = 1.5, Armor = 0.01, DPS = 0.1 },
            { name = "Demonology",  Sta = 0.4, Int = 0.5, Spi = 0.5, SP = 1.0, Dmg = 1.0, Hit = 10, Crit = 5,  Wand = 1.5, Armor = 0.01, DPS = 0.1 },
            { name = "Destruction", Sta = 0.4, Int = 0.5, Spi = 0.5, SP = 1.0, Dmg = 1.0, Hit = 12, Crit = 10, Wand = 1.5, Armor = 0.01, DPS = 0.1 },
        } },
        SHAMAN = { default = 2, trees = {
            { name = "Elemental",   Sta = 0.3, Int = 0.7, Spi = 0.2, SP = 1.0, Dmg = 1.0, Hit = 10, Crit = 10, Armor = 0.01, DPS = 0.1 },
            { name = "Enhancement", Str = 1.0, Agi = 0.6, Sta = 0.3, Int = 0.9, AP = 0.5, SP = 0.1, Dmg = 0.1, Hit = 11, Crit = 11, Armor = 0.01, DPS = 3.5 },
            { name = "Restoration", Sta = 0.3, Int = 0.9, Spi = 0.3, SP = 1.0, Heal = 1.0, Crit = 6, Armor = 0.01, DPS = 0.1 },
        } },
        DRUID = { default = 2, trees = {
            { name = "Balance",      Sta = 0.3, Int = 0.7, Spi = 0.4, SP = 1.0, Dmg = 1.0, Hit = 10, Crit = 8, Armor = 0.01, DPS = 0.1 },
            { name = "Feral Combat", Str = 1.0, Agi = 0.9, Sta = 0.5, AP = 0.55, Hit = 10, Crit = 10, Armor = 0.05, DPS = 3.5 },
            { name = "Restoration",  Sta = 0.3, Int = 1.0, Spi = 0.8, SP = 1.0, Heal = 1.0, Crit = 6, Armor = 0.01, DPS = 0.1 },
        } },
    },
}
