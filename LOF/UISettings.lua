-- =============================================================
-- LOF (LootOptimizer Forever) -- UISettings.lua
-- Pure consumer: the Settings window. Renders the resolver snapshots
-- (Resolver.Value.GetSettingsSnapshot, Resolver.Upgrade
-- .GetAdvisorSettings, Resolver.IsMakeRoomEnabled, Resolver.Reagents)
-- and forwards clicks to their setters. No calculations or decisions.
-- =============================================================
--
-- Changelog
-- ---------
-- v0.3.2: General > Bags: "Show the 'Not worth a swap' popup"
--   (Resolver.IsNotWorthPopupEnabled / Set; Peter, 17 Oct).
-- v0.3.1: Kit helpers (UI 1.17.0): ClassColored and the Remove from LOF
--   confirmation (Kit.AskRemoveCharacter); the own dialog is gone.
-- v0.3.0: Topic "Guide" (Peter): "Show What's new after an update" and
--   three buttons that open the Guide on a tab: What's new, How to use,
--   Colors (UIGuide 0.2.0). The Guide block left General (minimap icon
--   and Make room stay there).
-- v0.2.1: Make room texts say "bronze popup" (UI 1.15.0, was purple).
-- v0.2.0: Topic "Characters" (CurseForge request: the Forget button in
--   Holdings was hard to find). "Remove a character from LOF": the
--   other characters of this realm / ruleset and faction (Resolver
--   .Holdings.GetCharacters; not the one you play) with class colour,
--   level, class, last seen and a Remove button. Remove asks on top of
--   the window ("Remove X from LOF?", Yes, remove / No; the same text as
--   Holdings) and calls Resolver.Holdings.ForgetCharacter. The question
--   closes with the window (moving, combat, X): nothing is removed then.
-- v0.1.5: Icon tooltip: Shift-right-click switches between the minimap
--   and loose (UI 1.13.1, LibDBIcon).
-- v0.1.4: The window comes to the front when clicked (SetToplevel) and
--   UI.GetSettingsFrame() lets the Guide open next to it.
-- v0.1.3: General: block "Guide" with "Show What's new after an
--   update" (Resolver.Is/SetWhatsNewEnabled) and a button "Open Guide"
--   (UIGuide.lua). Icon tooltip: Shift-drag places it loose.
-- v0.1.2: Option "Show the LOF icon at the minimap"; off: the coin only
--   shows while the dashboard is closed (UI 1.12.6).
-- v0.1.1: Topic "Bags" is now "General": block "Minimap icon" with
--   "Show the LOF icon" (UI.SetMinimapIconShown, UI 1.12.5) above the
--   Bags block (Make room).
-- v0.1.0: Initial version (LOF 1.6.0, Peter: the Settings tab kept
--   growing; "a window like Holdings: easy to read, clear text, and
--   it closes when you start moving or are attacked").
--   - Topics on the left (Values, Upgrade Advisor, Bags, Reagents),
--     the chosen topic on the right. Fixed size; a new topic is one
--     more line on the left. The last topic is remembered
--     (LOF.db.settingsTopic).
--   - Under every option one grey line saying what it does; the long
--     explanation stays in the tooltip (and the "?" at Auction House).
--   - Reagents: "Keep profession reagents" with the list per
--     profession right under it (UIReagents.lua panel).
--   - Opened by the Settings tab (like Holdings) or /lof settings.
--     Closes with X, Escape, moving and combat (Capture); it does not
--     come back after combat.
-- =============================================================

local LOF = LOF
LOF.VERSION_UI_SETTINGS = "0.3.2"

local UI = LOF.UI
local Resolver = LOF.Resolver
local Kit = UI.Kit

local GOLD, GREEN, RED, GREY = Kit.GOLD, Kit.GREEN, Kit.RED, Kit.GREY
local DE_COLOR = Kit.DE_COLOR
local FRESHNESS_COLOR = Kit.FRESHNESS_COLOR

local WIN_W, WIN_H = 560, 470
local NAV_W   = 140
local NAV_H   = 26
local PAGE_W  = WIN_W - 10 - NAV_W - 8 - 10   -- page inset width
local INNER_W = PAGE_W - 12 - 30              -- scroll child width
local OPT_GAP = 10                            -- space between options
local ROW_H   = 20                            -- quality table / alt rows
local COL_V   = 230                           -- Vendor column centre
local COL_AH  = 290                           -- AH column centre

local TOPICS = {
    { key = "values",   label = "Values" },
    { key = "advisor",  label = "Upgrade Advisor" },
    { key = "bags",     label = "General" },   -- v0.1.1
    { key = "guide",    label = "Guide" },     -- v0.3.0
    { key = "reagents", label = "Reagents" },
    { key = "chars",    label = "Characters" },   -- v0.2.0
}

local win

-- -------------------------------------------------------------
-- Small building blocks
-- -------------------------------------------------------------
local ClassName = Kit.ClassColored   -- v0.3.1: the Kit helper

local function Head(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text)
    return fs
end

local function Line(parent, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(2)
    return fs
end

-- Check box + label + grey description line under it. The hover frame
-- over box and label shows the tooltip also while the box is disabled
-- and forwards a left click to the box.
local function Option(parent, label, onClick, onEnter)
    local o = {}
    o.check = Kit.CreateCheck(parent, false)
    o.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    o.label:SetPoint("LEFT", o.check, "RIGHT", 2, 1)
    o.label:SetText(label)
    o.desc = Line(parent, INNER_W - 30)
    o.desc:SetPoint("TOPLEFT", o.check, "BOTTOMLEFT", 28, 0)
    o.desc:SetTextColor(0.62, 0.62, 0.62)
    o.check:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
    o.hover = CreateFrame("Frame", nil, parent)
    o.hover:SetPoint("TOPLEFT", o.check, "TOPLEFT", 0, 0)
    o.hover:SetPoint("BOTTOMRIGHT", o.label, "BOTTOMRIGHT", 4, -4)
    o.hover:SetFrameLevel(o.check:GetFrameLevel() + 1)
    o.hover:EnableMouse(true)
    if onEnter then
        o.hover:SetScript("OnEnter", onEnter)
        o.hover:SetScript("OnLeave", Kit.HideTooltip)
    end
    o.hover:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and o.check:IsEnabled() then o.check:Click() end
    end)
    return o
end

local function SetOptionEnabled(o, enabled)
    if enabled then
        o.check:Enable()
        o.label:SetTextColor(1, 1, 1)
    else
        o.check:Disable()
        o.label:SetTextColor(0.5, 0.5, 0.5)
    end
end

-- Places an option at y (inside its page) and returns the next y.
local function PlaceOption(o, page, y)
    o.check:ClearAllPoints()
    o.check:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
    local descH = (o.desc:GetText() and o.desc:GetText() ~= "") and o.desc:GetStringHeight() or 0
    return y - 24 - descH - OPT_GAP
end

local function SimpleTooltip(title, body, note)
    return function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(body, 1, 1, 1, true)
        if note then GameTooltip:AddLine(note, 0.7, 0.7, 0.7, true) end
        GameTooltip:Show()
    end
end

-- -------------------------------------------------------------
-- Page: Values (Auction House + disenchant)
-- -------------------------------------------------------------
local function ShowValueRules(owner)
    local snap = Resolver.Value.GetSettingsSnapshot()
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText("How LOF values items", 1, 0.82, 0)
    GameTooltip:AddLine("- AH value is never lower than vendor value.", 1, 1, 1, true)
    GameTooltip:AddLine("- Soulbound items always use vendor value.", 1, 1, 1, true)
    GameTooltip:AddLine(string.format("- AH prices: %sgreen|r up to %d days, %sorange|r up to %d, %sred|r up to %d days.",
        FRESHNESS_COLOR.FRESH, snap.freshDays, FRESHNESS_COLOR.AGING, snap.agingDays,
        FRESHNESS_COLOR.OLD, snap.maxUsableDays), 1, 1, 1, true)
    GameTooltip:AddLine(string.format("- AH data older than %d days is not used: vendor value.", snap.maxUsableDays), 1, 1, 1, true)
    if snap.deAvailable then
        GameTooltip:AddLine("- " .. DE_COLOR .. "Disenchant value|r: the highest of vendor, AH and disenchant counts.", 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function BuildValues(p)
    local v = {}
    v.head = Head(p, "Auction House")
    v.help = CreateFrame("Button", nil, p)
    v.help:SetSize(18, 18)
    v.help:SetPoint("LEFT", v.head, "RIGHT", 6, 0)
    v.help.text = v.help:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    v.help.text:SetPoint("CENTER")
    v.help.text:SetText("(?)")
    v.help:SetScript("OnEnter", ShowValueRules)
    v.help:SetScript("OnLeave", Kit.HideTooltip)

    v.use = Option(p, "Use Auctionator prices", function(on)
        Resolver.Value.SetEnabled(on)
        LOF.RequestRefresh()
    end, function(self) UI.ShowAuctionatorHelp(self) end)

    v.tableHead = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    v.tableHead:SetText("Value per quality")
    v.colV = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    v.colV:SetText("Vendor")
    v.colAH = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    v.colAH:SetText("AH")
    v.rows = {}
    for i = 1, #LOF.Data.PriceRules.qualityOrder do
        local row = {}
        row.label = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.vendor = Kit.CreateCheck(p, true)
        row.ah = Kit.CreateCheck(p, true)
        row.vendor:SetScript("OnClick", function()
            Resolver.Value.SetQualityMode(row.quality, "VENDOR")
            LOF.RequestRefresh()
        end)
        row.ah:SetScript("OnClick", function()
            Resolver.Value.SetQualityMode(row.quality, "AH")
            LOF.RequestRefresh()
        end)
        v.rows[i] = row
    end
    v.rules = Line(p, INNER_W)
    v.rules:SetTextColor(0.62, 0.62, 0.62)

    v.deHead = Head(p, "Disenchant")
    v.de = Option(p, "Use disenchant value", function(on)
        Resolver.Value.SetDisenchantEnabled(on)
        LOF.RequestRefresh()
    end, function(self) UI.ShowDisenchantHelp(self) end)
    return v
end

local function PriceUpdatedText(snap)
    if not snap.lastPriceUpdate then return GREY .. "never|r" end
    local c = FRESHNESS_COLOR[snap.lastPriceUpdateFresh] or ""
    local d = snap.lastPriceUpdateDays or 0
    local txt
    if d == 0 then
        txt = "today " .. date("%H:%M", snap.lastPriceUpdate)
    elseif d == 1 then
        txt = "yesterday " .. date("%H:%M", snap.lastPriceUpdate)
    else
        txt = d .. " days ago"
    end
    local out = c .. txt .. "|r"
    if snap.lastPriceUpdateFresh == "STALE" then
        out = out .. RED .. " - scan the auction house|r"
    end
    return out
end

local function RenderValues(v, p)
    local snap = Resolver.Value.GetSettingsSnapshot()
    local y = -4
    v.head:ClearAllPoints()
    v.head:SetPoint("TOPLEFT", p, "TOPLEFT", 4, y)
    y = y - 22

    v.use.check:SetChecked(snap.enabled)
    SetOptionEnabled(v.use, snap.auctionatorLoaded)
    local status = snap.auctionatorLoaded and ("Auctionator: " .. GREEN .. "detected|r")
        or ("Auctionator: " .. RED .. "not installed or not loaded|r")
    v.use.desc:SetText(status .. "\nAH prices updated: " .. PriceUpdatedText(snap))
    y = PlaceOption(v.use, p, y)

    local active = snap.active
    v.tableHead:ClearAllPoints()
    v.tableHead:SetPoint("TOPLEFT", p, "TOPLEFT", 8, y)
    v.tableHead:SetTextColor(active and 1 or 0.5, active and 0.82 or 0.5, active and 0 or 0.5)
    v.colV:ClearAllPoints()
    v.colV:SetPoint("TOP", p, "TOPLEFT", COL_V, y)
    v.colAH:ClearAllPoints()
    v.colAH:SetPoint("TOP", p, "TOPLEFT", COL_AH, y)
    y = y - 16
    for i, row in ipairs(v.rows) do
        local def = snap.qualityRows[i]
        if def then
            row.quality = def.quality
            row.label:ClearAllPoints()
            row.label:SetPoint("TOPLEFT", p, "TOPLEFT", 8, y - 2)
            row.label:SetText(active and LOF.ColorizeName(def.label, def.quality) or (GREY .. def.label .. "|r"))
            row.vendor:ClearAllPoints()
            row.vendor:SetPoint("TOP", p, "TOPLEFT", COL_V, y)
            row.ah:ClearAllPoints()
            row.ah:SetPoint("TOP", p, "TOPLEFT", COL_AH, y)
            row.vendor:SetChecked(def.mode == "VENDOR")
            row.ah:SetChecked(def.mode == "AH")
            if active then row.vendor:Enable(); row.ah:Enable()
            else row.vendor:Disable(); row.ah:Disable() end
            y = y - ROW_H
        end
    end
    y = y - 4
    v.rules:ClearAllPoints()
    v.rules:SetPoint("TOPLEFT", p, "TOPLEFT", 8, y)
    v.rules:SetText(string.format("AH value is never lower than vendor value. Prices older than %d days "
        .. "are not used. More: (?) at Auction House.", snap.maxUsableDays))
    y = y - v.rules:GetStringHeight() - 16

    -- Disenchant: only when one of your characters has Enchanting
    local deShown = snap.deAvailable == true
    v.deHead:SetShown(deShown)
    v.de.check:SetShown(deShown)
    v.de.label:SetShown(deShown)
    v.de.desc:SetShown(deShown)
    v.de.hover:SetShown(deShown)
    if deShown then
        v.deHead:ClearAllPoints()
        v.deHead:SetPoint("TOPLEFT", p, "TOPLEFT", 4, y)
        y = y - 22
        v.de.check:SetChecked(snap.deEnabled)
        SetOptionEnabled(v.de, active)
        local who = table.concat(snap.deEnchanters or {}, ", ")
        local text = "Enchanting: " .. who
        if not active then text = text .. "\n" .. RED .. "Needs Auctionator prices (above).|r" end
        v.de.desc:SetText(text)
        y = PlaceOption(v.de, p, y)
    end
    return -y
end

-- -------------------------------------------------------------
-- Page: Upgrade Advisor
-- -------------------------------------------------------------
local function BuildAdvisor(p)
    local a = {}
    a.head = Head(p, "Upgrade Advisor")
    a.use = Option(p, "Show upgrade advice", function(on)
        UI.SetUpgradeAdvisor(on)
    end, function(self) UI.ShowUpgradeAdvisorHelp(self) end)
    a.altHead = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    a.altHead:SetText("Also advise for these alts:")
    a.altEmpty = Line(p, INNER_W - 16)
    a.altEmpty:SetTextColor(0.62, 0.62, 0.62)
    a.altEmpty:SetText("No other characters known yet: log in once on each.")
    a.alts = {}
    a.mail = Option(p, "Open Send to alts at the mailbox", function(on)
        Resolver.Upgrade.SetAltMailAutoOpen(on)
        LOF.RequestRefresh()
    end, SimpleTooltip("Send to alts",
        "When you open a mailbox and your bags hold upgrades for your alts, "
            .. "the Send to alts window opens next to the mail.",
        "Recent Loot > Upgrade opens it any time."))
    return a
end

local function GetAltRow(a, p, i)
    local r = a.alts[i]
    if r then return r end
    r = {}
    r.check = Kit.CreateCheck(p, false)
    r.label = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.label:SetPoint("LEFT", r.check, "RIGHT", 2, 1)
    r.check:SetScript("OnClick", function(self)
        UI.SetAltAdvice(self.altName, self:GetChecked() and true or false)
    end)
    r.check:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tostring(self.altName))
        GameTooltip:AddLine("Advice for gear that is an upgrade for this character "
            .. "(popup, bag tooltip, swap, Gear for alts).", 1, 1, 1, true)
        GameTooltip:AddLine("Only while you play the character named at the top.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    r.check:SetScript("OnLeave", Kit.HideTooltip)
    a.alts[i] = r
    return r
end

local function RenderAdvisor(a, p)
    local snap = Resolver.Upgrade.GetAdvisorSettings()
    local y = -4
    a.head:ClearAllPoints()
    a.head:SetPoint("TOPLEFT", p, "TOPLEFT", 4, y)
    y = y - 22

    a.use.check:SetChecked(snap.enabled)
    a.use.desc:SetText("This character: " .. tostring(snap.name or "?")
        .. "\nNew gear is compared with what you wear, weighted for your spec.")
    y = PlaceOption(a.use, p, y)

    a.altHead:ClearAllPoints()
    a.altHead:SetPoint("TOPLEFT", p, "TOPLEFT", 8, y)
    a.altHead:SetTextColor(snap.enabled and 1 or 0.5, snap.enabled and 0.82 or 0.5, snap.enabled and 0 or 0.5)
    y = y - 18
    for i, alt in ipairs(snap.alts) do
        local r = GetAltRow(a, p, i)
        r.check.altName = alt.name
        r.check:ClearAllPoints()
        r.check:SetPoint("TOPLEFT", p, "TOPLEFT", 10, y + 2)
        r.check:SetChecked(alt.enabled)
        if snap.enabled then
            r.check:Enable()
            r.label:SetText(ClassName(alt.name, alt.class) .. GREY .. "  "
                .. tostring(alt.className or "") .. " " .. tostring(alt.level or "") .. "|r")
        else
            r.check:Disable()
            r.label:SetText(GREY .. tostring(alt.name) .. "|r")
        end
        r.check:Show(); r.label:Show()
        y = y - ROW_H
    end
    for i = #snap.alts + 1, #a.alts do
        a.alts[i].check:Hide(); a.alts[i].label:Hide()
    end
    if #snap.alts == 0 then
        a.altEmpty:ClearAllPoints()
        a.altEmpty:SetPoint("TOPLEFT", p, "TOPLEFT", 14, y)
        a.altEmpty:Show()
        y = y - a.altEmpty:GetStringHeight() - 4
    else
        a.altEmpty:Hide()
    end
    y = y - 14

    a.mail.check:SetChecked(snap.mailAutoOpen)
    a.mail.desc:SetText("Opens next to the mail when your bags hold upgrades for your alts.")
    y = PlaceOption(a.mail, p, y)
    return -y
end

-- -------------------------------------------------------------
-- Page: Bags
-- -------------------------------------------------------------
local function BuildBags(p)
    local b = {}
    -- v0.1.1: minimap icon
    b.iconHead = Head(p, "Minimap icon")
    b.icon = Option(p, "Show the LOF icon at the minimap", function(on)
        UI.SetMinimapIconShown(on)
    end, SimpleTooltip("LOF icon",
        "The coin at the edge of the minimap. Click: open or close LOF. Right-click: Settings. "
            .. "Drag: move along the minimap. Shift-right-click: place it loose (it then shows while LOF "
            .. "is closed); Shift-right-click the loose coin: back to the minimap.",
        "Off: the coin only shows while the dashboard is closed, anywhere on the screen."))
    b.head = Head(p, "Bags")
    b.room = Option(p, "Offer to make room when bags are full", function(on)
        Resolver.SetMakeRoomEnabled(on)
        LOF.RequestRefresh()
    end, SimpleTooltip("Make room",
        "Bags full while conjuring, crafting, taking a quest reward, buying or "
            .. "taking mail? LOF offers to delete the cheapest safe bag item (bronze popup).",
        "Quest items, whitelist, tools, upgrades and kept reagents are never offered."))
    -- v0.3.2
    b.notWorth = Option(p, "Show the 'Not worth a swap' popup", function(on)
        Resolver.SetNotWorthPopupEnabled(on)
    end, SimpleTooltip("Not worth a swap",
        "Bags full and the loot is worth less than everything LOF may delete: the red popup "
            .. "shows what you would lose, with Swap anyway.",
        "Off: no popup, only a short line under Blizzard's \"Inventory is full\"."))
    return b   -- v0.3.0: the Guide block has its own topic
end

local function RenderBags(b, p)
    local y = -4
    b.iconHead:ClearAllPoints()
    b.iconHead:SetPoint("TOPLEFT", p, "TOPLEFT", 4, y)
    y = y - 22
    b.icon.check:SetChecked(UI.IsMinimapIconShown())
    b.icon.desc:SetText("Off: the coin only shows while the dashboard is closed.")
    y = PlaceOption(b.icon, p, y) - 6
    b.head:ClearAllPoints()
    b.head:SetPoint("TOPLEFT", p, "TOPLEFT", 4, y)
    y = y - 22
    b.room.check:SetChecked(Resolver.IsMakeRoomEnabled())
    b.room.desc:SetText("\"Inventory is full\" outside the loot window: a bronze popup offers the "
        .. "cheapest safe item. Delete frees one slot; then try again.")
    y = PlaceOption(b.room, p, y) - 6
    b.notWorth.check:SetChecked(Resolver.IsNotWorthPopupEnabled())   -- v0.3.2
    b.notWorth.desc:SetText("Off: a short line under Blizzard's \"Inventory is full\" instead.")
    y = PlaceOption(b.notWorth, p, y)
    return -y
end

-- -------------------------------------------------------------
-- Page: Guide (v0.3.0)
-- -------------------------------------------------------------
local GUIDE_TABS = {
    { tab = "whatsnew", label = "What's new" },
    { tab = "howto",    label = "How to use" },
    { tab = "colors",   label = "Colors" },
}

local function BuildGuide(p)
    local g = {}
    g.head = Head(p, "Guide")
    g.news = Option(p, "Show What's new after an update", function(on)
        Resolver.SetWhatsNewEnabled(on)
    end, SimpleTooltip("What's new",
        "The first time you log in with a new LOF version, the Guide shows what changed.",
        "Open it any time with the buttons below or /lof guide."))
    g.openHead = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    g.openHead:SetText("Open the Guide:")
    g.buttons = {}
    for i, t in ipairs(GUIDE_TABS) do
        local b = Kit.CreateButton(p, t.label, 104)
        b:SetHeight(22)
        b:SetScript("OnClick", function()
            if UI.ShowGuideWindow then UI.ShowGuideWindow(t.tab, false) end
        end)
        g.buttons[i] = b
    end
    g.help = Line(p, INNER_W - 8)
    g.help:SetTextColor(0.62, 0.62, 0.62)
    g.help:SetText("What's new: what changed per version. How to use: the basics for new players. "
        .. "Colors: what each popup colour means. Also: /lof guide, /lof guide colors.")
    return g
end

local function RenderGuide(g, p)
    local y = -4
    g.head:ClearAllPoints()
    g.head:SetPoint("TOPLEFT", p, "TOPLEFT", 4, y)
    y = y - 22
    g.news.check:SetChecked(Resolver.IsWhatsNewEnabled())
    g.news.desc:SetText("Opens once per new LOF version, at a quiet moment after login.")
    y = PlaceOption(g.news, p, y) - 4
    g.openHead:ClearAllPoints()
    g.openHead:SetPoint("TOPLEFT", p, "TOPLEFT", 8, y)
    y = y - 18
    for i, b in ipairs(g.buttons) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", p, "TOPLEFT", 8 + (i - 1) * 110, y)
    end
    y = y - 22 - 12
    g.help:ClearAllPoints()
    g.help:SetPoint("TOPLEFT", p, "TOPLEFT", 8, y)
    y = y - g.help:GetStringHeight() - 10
    return -y
end

-- -------------------------------------------------------------
-- Page: Reagents (option + the list from UIReagents.lua)
-- -------------------------------------------------------------
local function BuildReagents(p)
    local r = {}
    r.head = Head(p, "Profession reagents")
    r.head:SetPoint("TOPLEFT", p, "TOPLEFT", 4, -4)
    r.keep = Option(p, "Keep profession reagents", function(on)
        Resolver.Reagents.SetEnabled(on)
        Resolver.InvalidateCache()
        LOF.RequestRefresh()
    end, SimpleTooltip("Profession reagents",
        "Reagents you keep are never deleted. Bags full? The loot is offered for a swap "
            .. "(teal popup), even when it is worth less than your cheapest item.",
        "Off: reagents are handled like any other item, by value."))
    r.keep.check:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -26)
    r.panel = UI.BuildReagentsPanel(p, PAGE_W - 20, -58)
    return r
end

local function RenderReagents(r)
    r.keep.check:SetChecked(Resolver.Reagents.IsEnabled())
    UI.RenderReagentsPanel(r.panel)
end

-- -------------------------------------------------------------
-- Page: Characters (v0.2.0) - remove a character from LOF
-- -------------------------------------------------------------
local CHAR_ROW_H = 36
local REMOVE_W   = 80

local function AskRemove(name)   -- v0.3.1: Kit.AskRemoveCharacter (one flow)
    if win and name then Kit.AskRemoveCharacter(win, name, nil, { x = 40, y = 20 }) end
end

local function BuildChars(p)
    local c = {}
    c.head = Head(p, "Remove a character from LOF")
    c.rows = {}
    c.empty = Line(p, INNER_W - 16)
    c.empty:SetTextColor(0.62, 0.62, 0.62)
    c.empty:SetText("No other characters of this realm and faction yet.")
    c.help = Line(p, INNER_W - 8)
    c.help:SetTextColor(0.62, 0.62, 0.62)
    c.help:SetText("Deleted a character, or one you no longer play? Remove it here. LOF forgets what "
        .. "it stored for it (bags, bank, mail, gear, settings). Your character in the game is not "
        .. "touched. Log in with it again and LOF reads it anew.\n\n"
        .. "Only characters of this realm / ruleset and faction are listed, not the one you play.")
    return c
end

local function GetCharRow(c, p, i)
    local r = c.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, p)
    r:SetSize(INNER_W - 8, CHAR_ROW_H)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints(r)
    r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0.06)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -4)
    r.info = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.info:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
    r.info:SetTextColor(0.62, 0.62, 0.62)
    r.remove = Kit.CreateButton(r, "Remove", REMOVE_W)
    r.remove:SetHeight(22)
    r.remove:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    r.remove:SetScript("OnClick", function(self) AskRemove(self.charName) end)
    r.remove:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Remove " .. tostring(self.charName) .. " from LOF")
        GameTooltip:AddLine("LOF asks first.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    r.remove:SetScript("OnLeave", Kit.HideTooltip)
    c.rows[i] = r
    return r
end

local function RenderChars(c, p)
    local y = -4
    c.head:ClearAllPoints()
    c.head:SetPoint("TOPLEFT", p, "TOPLEFT", 4, y)
    y = y - 24
    local n = 0
    for _, ch in ipairs(Resolver.Holdings.GetCharacters()) do
        if not ch.isCurrent then
            n = n + 1
            local r = GetCharRow(c, p, n)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", p, "TOPLEFT", 4, y)
            r.name:SetText(ClassName(ch.name, ch.class))
            local info = {}
            if ch.level then info[#info + 1] = "Level " .. tostring(ch.level) end
            if ch.className then info[#info + 1] = tostring(ch.className) end
            info[#info + 1] = "last seen " .. (ch.lastSeen and Kit.WhenText(ch.lastSeen) or "unknown")
            r.info:SetText(table.concat(info, "  -  "))
            r.remove.charName = ch.name
            r:Show()
            y = y - CHAR_ROW_H - 2
        end
    end
    for i = n + 1, #c.rows do c.rows[i]:Hide() end
    if n == 0 then
        c.empty:ClearAllPoints()
        c.empty:SetPoint("TOPLEFT", p, "TOPLEFT", 8, y)
        c.empty:Show()
        y = y - c.empty:GetStringHeight() - 4
    else
        c.empty:Hide()
    end
    y = y - 12
    c.help:ClearAllPoints()
    c.help:SetPoint("TOPLEFT", p, "TOPLEFT", 8, y)
    y = y - c.help:GetStringHeight() - 10
    return -y
end

-- -------------------------------------------------------------
-- Window
-- -------------------------------------------------------------
local function SelectTopic(key)
    LOF.db.settingsTopic = key
    UI.RefreshSettingsWindow()
end

local function BuildNav()
    win.nav = Kit.CreateInset(win)
    win.nav:SetPoint("TOPLEFT", win, "TOPLEFT", 10, win.top)
    win.nav:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 10, 12)
    win.nav:SetWidth(NAV_W)
    win.navButtons = {}
    for i, t in ipairs(TOPICS) do
        local b = CreateFrame("Button", nil, win.nav)
        b:SetSize(NAV_W - 12, NAV_H)
        b:SetPoint("TOPLEFT", win.nav, "TOPLEFT", 6, -8 - (i - 1) * (NAV_H + 2))
        b.sel = b:CreateTexture(nil, "BACKGROUND")
        b.sel:SetAllPoints(b)
        b.sel:SetColorTexture(1, 0.82, 0, 0.18)
        b.bar = b:CreateTexture(nil, "ARTWORK")
        b.bar:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
        b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
        b.bar:SetWidth(3)
        b.bar:SetColorTexture(1, 0.82, 0, 0.9)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints(b)
        b.hl:SetColorTexture(1, 1, 1, 0.08)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.text:SetPoint("LEFT", b, "LEFT", 10, 0)
        b.text:SetText(t.label)
        b.key = t.key
        b:SetScript("OnClick", function(self) SelectTopic(self.key) end)
        win.navButtons[i] = b
    end
end

local function BuildPages()
    win.pageBox = Kit.CreateInset(win)
    win.pageBox:SetPoint("TOPLEFT", win.nav, "TOPRIGHT", 8, 0)
    win.pageBox:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -10, 12)

    -- Values / Upgrade Advisor / Bags: one shared scroll area
    win.scroll = CreateFrame("ScrollFrame", nil, win.pageBox, "UIPanelScrollFrameTemplate")
    win.scroll:SetPoint("TOPLEFT", win.pageBox, "TOPLEFT", 12, -10)
    win.scroll:SetPoint("BOTTOMRIGHT", win.pageBox, "BOTTOMRIGHT", -30, 10)
    win.scroll.scrollBarHideable = true   -- Blizzard: no bar while it fits
    win.child = CreateFrame("Frame", nil, win.scroll)
    win.child:SetSize(INNER_W, 10)
    win.scroll:SetScrollChild(win.child)

    win.pages = {}
    local function ScrollPage(key, build, render)
        local f = CreateFrame("Frame", nil, win.child)
        f:SetPoint("TOPLEFT", win.child, "TOPLEFT", 0, 0)
        f:SetSize(INNER_W, 10)
        local data = build(f)
        win.pages[key] = { frame = f, scroll = true, render = function() return render(data, f) end }
    end
    ScrollPage("values", BuildValues, RenderValues)
    ScrollPage("advisor", BuildAdvisor, RenderAdvisor)
    ScrollPage("bags", BuildBags, RenderBags)
    ScrollPage("guide", BuildGuide, RenderGuide)   -- v0.3.0
    ScrollPage("chars", BuildChars, RenderChars)   -- v0.2.0

    -- Reagents: no outer scroll, the list scrolls itself
    local rf = CreateFrame("Frame", nil, win.pageBox)
    rf:SetPoint("TOPLEFT", win.pageBox, "TOPLEFT", 12, -10)
    rf:SetPoint("BOTTOMRIGHT", win.pageBox, "BOTTOMRIGHT", -8, 10)
    local rdata = BuildReagents(rf)
    win.pages.reagents = { frame = rf, scroll = false, render = function() RenderReagents(rdata) end }
end

local function BuildWindow()
    win = Kit.CreateStyledPanel("LOF_SettingsFrame", "settings", WIN_W, WIN_H, "HIGH")
    win:SetFrameStrata("HIGH")
    if win.SetToplevel then win:SetToplevel(true) end   -- v0.1.4
    if win.Inset then win.Inset:Hide() end
    if not win.CloseButton then
        win.close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
        win.close:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0)
    end
    if _G.UISpecialFrames then tinsert(_G.UISpecialFrames, "LOF_SettingsFrame") end
    Kit.SetPanelTitle(win, "LootOptimizer Forever - Settings")
    win.top = win.styled and -28 or -10
    BuildNav()
    BuildPages()
    win:Hide()
end

local function CurrentTopic()
    local key = LOF.db.settingsTopic
    for _, t in ipairs(TOPICS) do
        if t.key == key then return key end
    end
    return TOPICS[1].key
end

function UI.RefreshSettingsWindow()
    if not win or not win:IsShown() then return end
    local current = CurrentTopic()
    for _, b in ipairs(win.navButtons) do
        local on = b.key == current
        b.sel:SetShown(on)
        b.bar:SetShown(on)
        if on then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(1, 0.82, 0) end
    end
    local page = win.pages[current]
    for key, pg in pairs(win.pages) do
        pg.frame:SetShown(key == current)
    end
    win.scroll:SetShown(page.scroll)
    local h = page.render()
    if page.scroll then
        h = math.max(10, tonumber(h) or 10)
        page.frame:SetHeight(h)
        win.child:SetHeight(h)
        if h <= (win.scroll:GetHeight() or 0) then win.scroll:SetVerticalScroll(0) end
    end
end

-- v0.1.4: for the Guide (open next to Settings)
function UI.GetSettingsFrame()
    return win
end

function UI.ToggleSettingsWindow()
    if not win then BuildWindow() end
    if win:IsShown() then
        win:Hide()
        return
    end
    Kit.ApplyAutoScale(win, "settings", "CENTER", 0, 0)
    win:Show()
    UI.RefreshSettingsWindow()
end

-- Capture: moving or combat closes the window (it does not come back).
function UI.CloseSettingsWindow()
    if win and win:IsShown() then win:Hide() end
end
