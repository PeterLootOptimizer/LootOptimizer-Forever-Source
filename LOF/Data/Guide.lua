-- =============================================================
-- LOF (LootOptimizer Forever) -- Data/Guide.lua
-- Reference data ONLY (no logic). Texts of the Guide window
-- (UIGuide.lua) and the support links (Info tab in UI.lua, website box
-- in Guide > How to use).
-- =============================================================
--
-- Changelog
-- ---------
-- v0.7.0: What's new 1.6.5 "Spell Damage and Spell Healing count" (Peter,
--   21 Oct).
-- v0.6.0: What's new 1.6.4 "Quest rewards, protected ammo & quieter full
--   bags" (Peter, 19 Oct).
-- v0.5.0: What's new 1.6.3 "Safer alt upgrades & clearer popups" (Peter,
--   15 Oct).
-- v0.4.1: links = { website, discord, email }: the one place for LOF's
--   addresses (Info tab and the Guide's website box read them; Peter, 15 Oct).
-- v0.4.0: What's new 1.6.2 "Clear popups: colours, browsing & one Make
--   room" (Peter, 14 Oct).
-- v0.3.3: What's new 1.6.0 (Room) and 1.5.0 (Make room) in bronze, the
--   colour Make room has now (audit A8; Colors tab says bronze too).
-- v0.3.2: Colors text for Make room: one popup for bags full and the
--   Room button, with Previous / Next (Capture 1.9.0).
-- v0.3.1: Swatch keys are the popup style keys of UI.lua (POPUP_STYLES:
--   gear, alt, quest, reagent, room, notworth, plain), so the Colors tab
--   shows exactly what the popups use.
-- v0.3.0: colors: the Guide tab "Colors" (Peter: what does each popup
--   colour mean). Per line a swatch key (presentation in UIGuide), a
--   title and a short text. Keys: quality, orange, gold, teal, bronze,
--   red, plain.
-- v0.2.1: How to use: make room in [bronze] (UI 1.15.0, was purple).
-- v0.2.0: What's new 1.6.1 (forget a character, minimap button
--   collectors, Shift-right-click for loose / minimap).
-- v0.1.1: 1.6.0 reagent lines rewritten (Peter): "never deleted" first,
--   then the swap, then the Settings line.
-- v0.1.0: Initial version (LOF 1.6.0, Guide window).
--   - howTo: short lines for players. Markup, turned into colours by
--     the UI: [gold]text[/], [teal]..[/], [orange]..[/], [purple]..[/],
--     [green]..[/], [red]..[/], [grey]..[/].
--   - whatsNew: newest version first. Per version a title and items
--     { color = "teal" | "purple" | "green" | "orange" | "gold" |
--       "red" | "grey" | "white", text = "..." } (same markup).
--   - Player language, short. The technical CHANGELOG.md stays for
--     GitHub and CurseForge.
-- =============================================================

local LOF = LOF
LOF.VERSION_DATA_GUIDE = "0.7.0"

LOF.Data = LOF.Data or {}

LOF.Data.Guide = {
    -- v0.4.1: the one place for LOF's addresses
    links = {
        website = "https://lootoptimizer.digitalfame.nl",
        discord = "https://discord.gg/zUJRbeEFaF",
        email   = "LOFCurseForge@DigitalFame.nl",
    },

    howTo = {
        "Bags full? Click [gold]Swap[/]: LOF deletes the cheapest item in your bags and loots.",
        "Click an item in Swap or All Items to keep it (whitelist). [gold]Shift-click[/]: permanent.",
        "New gear is compared with what you wear, weighted for your spec (Upgrade Advisor).",
        "[orange]Orange[/] popup or tooltip line: gear that is an upgrade for one of your alts.",
        "[gold]Scan[/]: check your bags for gear upgrades. [gold]Ignored[/]: upgrades you declined.",
        "[gold]Upgrade[/]: gear in your bags for your alts. At a mailbox one click puts it in the mail.",
        "[teal]Teal[/] popup: a profession material you still need. LOF keeps those (Settings > Reagents).",
        "Bags full while conjuring or taking a quest reward? LOF offers to [bronze]make room[/].",
        "[gold]Room[/] (Swap section): empty your bags yourself, grey items first, one item per click.",
        "[gold]Holdings[/] tab: what every character owns, where it lies and what it is worth.",
        "[gold]Coin icon[/] at the minimap: click opens or closes LOF, right-click opens Settings.",
        "[gold]Settings[/]: Auctionator prices, disenchant value, upgrade advice, make room, reagents.",
    },

    -- v0.3.0: the Colors tab, in the order players meet them. v0.3.1: the
    -- swatch key is the popup style key (UI.lua POPUP_STYLES).
    colors = {
        { swatch = "gear", title = "Gear upgrade for you",
          text = "GEAR UPGRADE in the title. Border and background in the item's quality colour: grey, white, green, blue or purple. Below it the comparison with what you wear." },
        { swatch = "alt", title = "Gear upgrade for an alt",
          text = "ALT UPGRADE in the title. Bind-on-Equip gear that is better for one of your other characters, with the name and the gain." },
        { swatch = "quest", title = "Quest item",
          text = "QUEST ITEM in the title. A quest item is always worth the slot." },
        { swatch = "reagent", title = "Profession reagent you keep",
          text = "REAGENT in the title. A material your profession still needs, offered for a swap even when it is worth less." },
        { swatch = "room", title = "Make room",
          text = "MAKE ROOM in the title (MAKE ROOM NOW with the Room button). Inventory full outside the loot window: LOF offers the cheapest safe item to delete; Previous / Next to browse." },
        { swatch = "notworth", title = "Not worth a swap",
          text = "The loot is worth less than everything LOF may delete. Swap anyway is still possible." },
        { swatch = "plain", title = "Plain swap",
          text = "No colour: the loot is simply worth more than your cheapest bag item." },
    },

    whatsNew = {
        {
            version = "1.6.5",
            title = "Spell Damage and Spell Healing count",
            items = {
                { color = "green", text = "The Upgrade Advisor now counts [green]Spell Damage[/] for damage specs, and [green]Spell Healing[/] for healers (Holy Paladin, Discipline, Holy Priest, Restoration)." },
                { color = "white", text = "Before, gear with these stats could be called an upgrade when it was not, and healing gear was not always protected. Stat weights 0.2.3 (beta)." },
            },
        },
        {
            version = "1.6.4",
            title = "Quest rewards, protected ammo & quieter full bags",
            items = {
                { color = "bronze", text = "[bronze]Make room[/] before you turn in a quest: if the reward does not fit, it opens on the reward screen (\"Quest reward needs 2 free slots - you have 0\") and closes with \"Enough room for the quest reward.\"" },
                { color = "gold", text = "Arrows and bullets are on the default whitelist, also in a normal bag: Swap and Make room never offer them (remove them with [gold]/lof wl[/])." },
                { color = "red", text = "Settings > General: switch off the [red]Not worth a swap[/] popup; you then get a short gold line under \"Inventory is full\"." },
                { color = "white", text = "[gold]NOTHING AVAILABLE TO SWAP[/] is the new title; Make room explains its order (Grey, White, Green, Blue) when a cheaper item waits." },
                { color = "green", text = "Stat weights 0.2.1 (beta), retuned for WoW: Forever. Tooltips: one alt per line and [gold]Weapon DPS[/]. [green]PROFIT[/] in capitals." },
            },
        },
        {
            version = "1.6.3",
            title = "Safer alt upgrades & clearer popups",
            items = {
                { color = "orange", text = "Fix: [orange]ALT UPGRADE[/] never compares with gear LOF has not loaded yet (no more \"Compared with: Unknown\"). Your alts' gear is loaded right after login." },
                { color = "red", text = "[red]Not worth a swap[/] now has a red background, so you tell it apart from a plain swap at a glance." },
                { color = "gold", text = "The swap note says it plainly: \"The only item in your bags worth less than this loot.\"" },
                { color = "white", text = "Info tab: website, Discord and mail to copy, and an [gold]Open Guide[/] button. Guide > How to use links to the website." },
            },
        },
        {
            version = "1.6.2",
            title = "Clear popups: colours, browsing & one Make room",
            items = {
                { color = "white", text = "Every popup has its own colour: [gold]GEAR UPGRADE[/] in the item's quality colour, [orange]ALT UPGRADE[/], [gold]QUEST ITEM[/], [teal]REAGENT[/], [bronze]MAKE ROOM[/]. Guide > [gold]Colors[/] explains them." },
                { color = "gold", text = "Swap: browse your bag items with [gold]Previous[/] and [gold]Next[/]. LOF tells you when it is the last or only item." },
                { color = "green", text = "Gear upgrades show the full stat comparison in the popup, also for alts and in Holdings, with [green]New[/] and [red]Lost[/] effects." },
                { color = "bronze", text = "One [bronze]Make room[/] popup for bags full and the [gold]Room[/] button: Delete, Previous, Next, Cancel." },
                { color = "gold", text = "Quest loot: LOF tells you whether you have the quest, whether the item starts one, or that no quest of yours needs it now." },
                { color = "red", text = "[red]Not worth a swap[/] stays 10 seconds; the countdown pauses while your mouse is on it." },
                { color = "white", text = "Remove a character from LOF: Settings > [gold]Characters[/], or Holdings > [gold]Remove from LOF[/]." },
                { color = "orange", text = "[gold]Send to alts[/] shows what changes per stat." },
                { color = "white", text = "Fixes: LOOT LEFT BEHIND explains what to do again; LOF no longer repeats other addons' errors in chat." },
            },
        },
        {
            version = "1.6.1",
            title = "Forget a character & minimap button collectors",
            items = {
                { color = "white", text = "Deleted a character? [gold]Holdings[/]: choose it and click [gold]Forget[/]. The list also shows when LOF last saw each character." },
                { color = "gold", text = "The minimap button now works with [gold]minimap button collectors[/] (Leatrix Plus and others): it joins their combined button." },
                { color = "gold", text = "Place the coin loose with [gold]Shift-right-click[/] (was Shift-drag); Shift-right-click the loose coin puts it back on the minimap." },
            },
        },
        {
            version = "1.6.0",
            title = "Profession reagents, Make room now & Settings window",
            items = {
                { color = "teal", text = "[teal]Profession reagents[/] your profession still needs are [gold]never deleted[/] from your bags, unless you choose so in Settings > Reagents." },
                { color = "teal", text = "Loot a reagent you still need while your bags are full? LOF offers a [gold]swap[/] (teal popup), even when it is worth less than your cheapest bag item." },
                { color = "teal", text = "Settings > Reagents: per material [gold]always keep[/] or [gold]normal rules[/]. Green range: skill points possible, white: needs more skill, grey: no more skill points." },
                { color = "bronze", text = "[gold]Room[/] button: empty your bags yourself, grey items first, then white, green and blue after a question. Delete, Previous, Next or Cancel." },
                { color = "green", text = "Gear that will be an upgrade for you at a later level is now protected too." },
                { color = "gold", text = "Released an upgrade or reagent? All Items shows [grey]· upg[/] or [grey]· reag[/]: click to protect it again." },
                { color = "white", text = "New [gold]Settings window[/]: Values, Upgrade Advisor, General and Reagents, with a short line under every option." },
                { color = "gold", text = "The [gold]coin icon[/] sits at the minimap: click opens LOF, right-click Settings. Shift-drag places it loose." },
                { color = "white", text = "This [gold]Guide[/]: What's new after an update, How to use for new players. Settings > General or /lof guide." },
            },
        },
        {
            version = "1.5.0",
            title = "Make room & disenchant value",
            items = {
                { color = "bronze", text = "[bronze]Make room[/]: bags full while conjuring, crafting or taking a quest reward? LOF offers the cheapest safe item to delete." },
                { color = "white", text = "Disenchant value: with an enchanter among your characters, items are worth the highest of vendor, AH and disenchanting." },
                { color = "green", text = "Upgrade popups: the new item stands out with a frame; one popup per item per session; none while you hold a fishing pole." },
                { color = "orange", text = "Swap popup: [green]green[/] when the loot is an upgrade for you, [orange]orange[/] when it is one for an alt." },
                { color = "red", text = "Combat: LOF folds the dashboard and closes its popups; after the fight it brings back what it closed." },
            },
        },
        {
            version = "1.4.0",
            title = "Send to alts",
            items = {
                { color = "orange", text = "[gold]Send to alts[/]: at a mailbox one click puts an upgrade for an alt in the mail, recipient filled in." },
                { color = "white", text = "Holdings and the lists scale with your screen; Holdings shows who sent the items in your mail." },
            },
        },
    },
}
