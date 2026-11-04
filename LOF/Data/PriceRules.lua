-- =============================================================
-- LOF (LootOptimizer Forever) -- Data/PriceRules.lua
-- Reference data ONLY (no logic). Read by ResolverValue.lua.
-- Change the numbers here; the value rules follow automatically.
-- =============================================================
--
-- Changelog
-- ---------
-- v0.1.0: Initial version (Auctionator integration, LOF 1.1.0).
--   - Freshness bands for Auctionator prices, in days since the item
--     was last seen on the auction house (Auctionator API v1
--     GetAuctionAgeBy*: 0 = today, nil = never seen or > 21 days).
--   - Default value source per item quality (as in LootOptimizer
--     Classic): Poor/Common = vendor, Uncommon and up = auction house.
-- =============================================================

local LOF = LOF
LOF.VERSION_DATA_PRICERULES = "0.1.0"

LOF.Data = LOF.Data or {}

LOF.Data.PriceRules = {
    -- Name LOF passes to Auctionator as callerID.
    auctionatorCallerID = "LootOptimizer Forever",

    -- Freshness bands (inclusive upper limits, in days).
    --   age <= fresh    -> FRESH  (green)
    --   age <= aging    -> AGING  (orange)
    --   age <= maxUsable-> OLD    (red, still used)
    --   older / unknown -> STALE  (not used: vendor value)
    freshness = {
        fresh     = 3,
        aging     = 7,
        maxUsable = 14,
    },

    -- Default value source per quality: "VENDOR" or "AH".
    qualityDefaults = {
        [0] = "VENDOR",  -- Poor
        [1] = "VENDOR",  -- Common
        [2] = "AH",      -- Uncommon
        [3] = "AH",      -- Rare
        [4] = "AH",      -- Epic
    },

    -- Qualities shown in the Settings tab, in this order.
    qualityOrder = { 0, 1, 2, 3, 4 },

    qualityLabels = {
        [0] = "Poor (grey)",
        [1] = "Common (white)",
        [2] = "Uncommon (green)",
        [3] = "Rare (blue)",
        [4] = "Epic (purple)",
    },
}
