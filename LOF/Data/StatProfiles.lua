-- =============================================================
-- LOF (LootOptimizer Forever) -- Data/StatProfiles.lua
-- Reference data ONLY (no logic). Read by ResolverUpgrade.lua to
-- enrich the upgrade explanation. Update this table when better
-- data becomes available; the explanation follows automatically.
-- =============================================================
--
-- Changelog
-- ---------
-- v0.3.6: E28: weaponSkills: weapon subclass -> the skill spell that
--   teaches it (IsPlayerSpell, measured on Forever 11 Nov: maces 198 known,
--   staves 227 not yet) and the skill's English name for "(train Staves)".
-- v0.3.5: E24: futureUpgradeLevels = 5: an upgrade for a later level
--   (level requirement, or an armor / weapon type from a level) only
--   counts within this many levels.
-- v0.3.4: E20: statLabels for damage of one school ("Shadow Damage"
--   ...), so the comparison table never shows a stat key.
-- v0.3.3: E21: weapons.excludedSubclasses (fishing pole) removed; the
--   Upgrade Advisor's default Ignored list covers the fishing poles now.
-- v0.3.2: statLabels: LOF's own player label for a stat key, where the
--   game's label does not fit a table (Peter, 16 Oct): Blizzard's
--   "damage per second" is lowercase (written for inside a sentence) ->
--   "Weapon DPS", the same word as on the website. UI.lua falls back to
--   the game's label for every other key.
-- v0.3.1: statAliases: Forever reports a resistance under two keys
--   (e.g. ITEM_MOD_FROST_RESISTANCE_SHORT and RESISTANCE4_NAME, seen on
--   Avala's Binding, 2 Oct 2026). The alias is merged into the key the
--   game has a label for, so the stat shows (and counts) once.
-- v0.3.0: usability section (LOF 1.3.0, alt upgrades): which armor
--   types and weapon types each class can use, so LOF can judge gear
--   for characters that are not logged in (no tooltip to read).
--   Classic rules: Warrior/Paladin plate from level 40, Hunter/Shaman
--   mail from level 40. Weapon types a class can learn (the alt may not
--   have trained the skill yet). Beta: adjust when Forever differs.
-- v0.2.0: weapons section: offHandDamageFactor (0.5, beta) and
--   excludedSubclasses (Fishing Pole).
-- v0.1.0: Initial version (Upgrade Advisor).
--   - Main stat per class. Hybrid classes (Paladin, Shaman, Druid)
--     have no main stat yet: it depends on the spec, and Forever
--     talents are still in beta.
--   - Stat keys are the WoW global string keys used by
--     C_Item.GetItemStats (e.g. ITEM_MOD_AGILITY_SHORT).
-- =============================================================

local LOF = LOF
LOF.VERSION_DATA_STATPROFILES = "0.3.6"

LOF.Data = LOF.Data or {}

LOF.Data.StatProfiles = {
    meta = {
        source     = "Warcraft Tavern Forever stats guide + class guides",
        date       = "2026-09-26",
        confidence = "beta",   -- beta | confirmed
        note       = "WoW: Forever is in beta; stat values may still change.",
    },

    -- mainStat: stat key, or nil when it depends on the spec.
    classes = {
        WARRIOR = { mainStat = "ITEM_MOD_STRENGTH_SHORT" },
        ROGUE   = { mainStat = "ITEM_MOD_AGILITY_SHORT" },
        HUNTER  = { mainStat = "ITEM_MOD_AGILITY_SHORT" },
        MAGE    = { mainStat = "ITEM_MOD_INTELLECT_SHORT" },
        WARLOCK = { mainStat = "ITEM_MOD_INTELLECT_SHORT" },
        PRIEST  = { mainStat = "ITEM_MOD_INTELLECT_SHORT" },
        PALADIN = { mainStat = nil, note = "depends on spec" },
        SHAMAN  = { mainStat = nil, note = "depends on spec" },
        DRUID   = { mainStat = nil, note = "depends on spec" },
    },

    -- v0.3.5 (E24): an upgrade for a later level counts only this many
    -- levels ahead (e.g. 5: a level-40 item from level 35).
    futureUpgradeLevels = 5,

    -- v0.3.6 (E28): weapon subclass -> skill spell + name (Classic IDs).
    -- Subclasses without an entry (Miscellaneous, Fishing Pole) need no
    -- training.
    weaponSkills = {
        [0]  = { spell = 196,   name = "One-Handed Axes" },
        [1]  = { spell = 197,   name = "Two-Handed Axes" },
        [2]  = { spell = 264,   name = "Bows" },
        [3]  = { spell = 266,   name = "Guns" },
        [4]  = { spell = 198,   name = "One-Handed Maces" },
        [5]  = { spell = 199,   name = "Two-Handed Maces" },
        [6]  = { spell = 200,   name = "Polearms" },
        [7]  = { spell = 201,   name = "One-Handed Swords" },
        [8]  = { spell = 202,   name = "Two-Handed Swords" },
        [10] = { spell = 227,   name = "Staves" },
        [13] = { spell = 15590, name = "Fist Weapons" },
        [15] = { spell = 1180,  name = "Daggers" },
        [16] = { spell = 2567,  name = "Thrown" },
        [18] = { spell = 5011,  name = "Crossbows" },
        [19] = { spell = 5009,  name = "Wands" },
    },

    -- Weapons (v0.2.0)
    weapons = {
        -- In vanilla the off-hand deals 50% damage; talents (e.g. Dual
        -- Wield Specialization) raise that. Used to compare a two-hander
        -- with main hand + off-hand.
        offHandDamageFactor = 0.5,
        confidence          = "beta",
    },

    -- Usability per class (v0.3.0), for alts (no tooltip available).
    -- armor:   armor subclass ID -> minimum character level
    --          (0 misc, 1 cloth, 2 leather, 3 mail, 4 plate, 6 shield,
    --           7 libram, 8 idol, 9 totem)
    -- weapons: weapon subclass ID -> true
    --          (0 1H axe, 1 2H axe, 2 bow, 3 gun, 4 1H mace, 5 2H mace,
    --           6 polearm, 7 1H sword, 8 2H sword, 10 staff, 13 fist,
    --           14 misc, 15 dagger, 16 thrown, 18 crossbow, 19 wand)
    -- dualWieldLevel: level from which the class can dual wield
    --          (nil = never). The stored value of the character itself
    --          wins when LOF has read it.
    usability = {
        confidence = "beta",
        classes = {
            WARRIOR = {
                armor = { [0] = 1, [1] = 1, [2] = 1, [3] = 1, [4] = 40, [6] = 1 },
                weapons = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true,
                            [6] = true, [7] = true, [8] = true, [10] = true, [13] = true, [14] = true,
                            [15] = true, [16] = true, [18] = true },
                dualWieldLevel = 20,
            },
            PALADIN = {
                armor = { [0] = 1, [1] = 1, [2] = 1, [3] = 1, [4] = 40, [6] = 1, [7] = 1 },
                weapons = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = true,
                            [7] = true, [8] = true, [14] = true },
            },
            HUNTER = {
                armor = { [0] = 1, [1] = 1, [2] = 1, [3] = 40 },
                weapons = { [0] = true, [1] = true, [2] = true, [3] = true, [6] = true, [7] = true,
                            [8] = true, [10] = true, [13] = true, [14] = true, [15] = true,
                            [16] = true, [18] = true },
                dualWieldLevel = 20,
            },
            ROGUE = {
                armor = { [0] = 1, [1] = 1, [2] = 1 },
                weapons = { [2] = true, [3] = true, [4] = true, [7] = true, [13] = true, [14] = true,
                            [15] = true, [16] = true, [18] = true },
                dualWieldLevel = 1,
            },
            PRIEST = {
                armor = { [0] = 1, [1] = 1 },
                weapons = { [4] = true, [10] = true, [14] = true, [15] = true, [19] = true },
            },
            MAGE = {
                armor = { [0] = 1, [1] = 1 },
                weapons = { [7] = true, [10] = true, [14] = true, [15] = true, [19] = true },
            },
            WARLOCK = {
                armor = { [0] = 1, [1] = 1 },
                weapons = { [7] = true, [10] = true, [14] = true, [15] = true, [19] = true },
            },
            SHAMAN = {
                armor = { [0] = 1, [1] = 1, [2] = 1, [3] = 40, [6] = 1, [9] = 1 },
                weapons = { [0] = true, [1] = true, [4] = true, [5] = true, [10] = true,
                            [13] = true, [14] = true, [15] = true },
            },
            DRUID = {
                armor = { [0] = 1, [1] = 1, [2] = 1, [8] = 1 },
                weapons = { [4] = true, [5] = true, [10] = true, [13] = true, [14] = true, [15] = true },
            },
        },
    },

    -- Duplicate stat keys (v0.3.1): alias -> the key that is kept.
    statAliases = {
        ITEM_MOD_HOLY_RESISTANCE_SHORT   = "RESISTANCE1_NAME",
        ITEM_MOD_FIRE_RESISTANCE_SHORT   = "RESISTANCE2_NAME",
        ITEM_MOD_NATURE_RESISTANCE_SHORT = "RESISTANCE3_NAME",
        ITEM_MOD_FROST_RESISTANCE_SHORT  = "RESISTANCE4_NAME",
        ITEM_MOD_SHADOW_RESISTANCE_SHORT = "RESISTANCE5_NAME",
        ITEM_MOD_ARCANE_RESISTANCE_SHORT = "RESISTANCE6_NAME",
    },

    -- v0.3.2: player labels that replace the game's label for a stat key.
    statLabels = {
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "Weapon DPS",
        -- v0.3.4 (E20)
        ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT = "Shadow Damage",
        ITEM_MOD_FIRE_DAMAGE_DONE_SHORT   = "Fire Damage",
        ITEM_MOD_FROST_DAMAGE_DONE_SHORT  = "Frost Damage",
        ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT = "Arcane Damage",
        ITEM_MOD_NATURE_DAMAGE_DONE_SHORT = "Nature Damage",
        ITEM_MOD_HOLY_DAMAGE_DONE_SHORT   = "Holy Damage",
    },

    -- Display order of stats in the explanation (others follow).
    displayOrder = {
        "RESISTANCE0_NAME",                  -- Armor
        "ITEM_MOD_DAMAGE_PER_SECOND_SHORT",  -- Weapon DPS
        "ITEM_MOD_STRENGTH_SHORT",
        "ITEM_MOD_AGILITY_SHORT",
        "ITEM_MOD_STAMINA_SHORT",
        "ITEM_MOD_INTELLECT_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
    },
}
