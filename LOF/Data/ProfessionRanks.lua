-- =============================================================
-- LOF (LootOptimizer Forever) -- Data/ProfessionRanks.lua
-- Reference data ONLY (no logic). Read by ResolverHoldings.lua.
-- Profession ranks: when can the next rank be trained.
-- =============================================================
--
-- Changelog
-- ---------
-- v0.2.0: materials per profession (LOF 1.3.0, coin icon tooltip):
--   which Trade Goods subclasses count as materials for a profession.
--   Item class 7 (Trade Goods), subclass measured on Forever (3 Oct
--   2026): Leather 6 (Light Leather, Leather Scraps), Cloth 5 (Linen),
--   Metal & Stone 7 (Copper Ore), Enchanting 12 (Strange Dust). Herb 9
--   and Parts 1 as on Retail (not measured yet). Keyed by skill line,
--   with the English name as fallback. Cooking, First Aid and Fishing
--   have no entry (not shown).
-- v0.1.0: Initial version (LOF 1.1.2). Vanilla ranks: the next rank
--   can be learned in the last `trainWindow` points before the rank's
--   maximum, from a minimum character level. If Forever differs,
--   change the numbers here only.
-- =============================================================

local LOF = LOF
LOF.VERSION_DATA_PROFESSIONRANKS = "0.2.0"

LOF.Data = LOF.Data or {}

LOF.Data.ProfessionRanks = {
    -- Training for the next rank is possible from (max - trainWindow).
    trainWindow = 25,

    -- Keyed by the rank's maximum skill. nextMinLevel = character level
    -- needed for the NEXT rank; nil = highest rank (nothing to train).
    ranks = {
        [75]  = { name = "Apprentice", nextMinLevel = 10 },
        [150] = { name = "Journeyman", nextMinLevel = 20 },
        [225] = { name = "Expert",     nextMinLevel = 35 },
        [300] = { name = "Artisan" },
    },

    -- v0.2.0: materials (item class + subclasses) per profession
    materialClass = 7,          -- Trade Goods
    maxMaterials = 4,           -- per profession in the tooltip
    materials = {
        [197] = { 5 },          -- Tailoring: Cloth
        [165] = { 6 },          -- Leatherworking: Leather
        [393] = { 6 },          -- Skinning: Leather
        [186] = { 7 },          -- Mining: Metal & Stone
        [164] = { 7 },          -- Blacksmithing: Metal & Stone
        [202] = { 7, 1 },       -- Engineering: Metal & Stone, Parts
        [182] = { 9 },          -- Herbalism: Herb
        [171] = { 9 },          -- Alchemy: Herb
        [333] = { 12 },         -- Enchanting: Enchanting
    },
    materialsByName = {
        Tailoring = { 5 }, Leatherworking = { 6 }, Skinning = { 6 }, Mining = { 7 },
        Blacksmithing = { 7 }, Engineering = { 7, 1 }, Herbalism = { 9 }, Alchemy = { 9 },
        Enchanting = { 12 },
    },
}
