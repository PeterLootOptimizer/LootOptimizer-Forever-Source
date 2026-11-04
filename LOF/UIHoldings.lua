-- =============================================================
-- LOF (LootOptimizer Forever) -- UIHoldings.lua
-- Pure consumer: the Holdings window. Renders
-- LOF.Resolver.Holdings.GetWindowSnapshot() and forwards the choices
-- (character, location, value mode, selected item) back to it.
-- No calculations or decisions in this file.
-- =============================================================
--
-- Changelog
-- ---------
-- v0.9.5: ORANGE comes from the Kit (one constant).
-- v0.9.4: Gear for alts: under "Upgrade for" the full comparison of the
--   selected item for its top character (Peter: only "+3.5%" before):
--   UI.RenderComparison in a box in the right panel, the same table as
--   the popups (ResolverHoldings 0.11.1).
-- v0.9.3: Kit helpers instead of own copies (UI 1.17.0): ClassColored,
--   GainText, DE_COLOR and the Remove from LOF confirmation
--   (Kit.AskRemoveCharacter: one dialog, one flow for Holdings and
--   Settings).
-- v0.9.2: "Forget" is now "Remove from LOF" (Peter: says what happens;
--   the character in the game is not touched). Wider button, the
--   confirmation asks "Remove X from LOF?" with Yes, remove / No, the
--   same text as the new Settings topic Characters (UISettings 0.2.0).
-- v0.9.1: The Forget confirmation is drawn above the item list (Peter:
--   the rows showed through it): its own frame on the DIALOG strata
--   with an opaque dark background and a gold border, larger, and it
--   catches the mouse.
-- v0.9.0: Forget a character (CurseForge request). With one other
--   character chosen (not the current one) a "Forget" button stands
--   next to the character list; it asks inside the window (Forget /
--   Cancel) and calls Resolver.Holdings.ForgetCharacter, then shows the
--   current character again. The character list shows "last seen" in
--   grey for the other characters.
-- v0.8.5: Disenchant value (LOF 1.5.0): value source "DE" renders as
--   "DE" (light purple) in the list and "(Disenchant)" on the item
--   card, with who can disenchant it.
-- v0.8.4: Combat (Capture 1.7.1): UI.HideHoldingsForCombat() hides the
--   window and reports whether it was open; UI.RestoreHoldingsAfterCombat()
--   shows it again with the same view.
-- v0.8.3: Holdings may be dragged partly off the screen (Peter: with the
--   larger window the mailbox stayed hidden behind it): up to 45% of
--   its width past the left or right edge and down to the title bar at
--   the bottom; the title bar always stays on screen (clamp insets).
-- v0.8.2: Item Analysis, Holdings by Character: under a character with
--   the item in the mail, one white line per sender: "(2) from Julian"
--   (holder.mailFrom, ResolverHoldings 0.10.0).
-- v0.8.1: The scale calculation moved to UI 1.7.0 (Kit.ApplyAutoScale),
--   shared with the All Items / Whitelist / Ignored list; same result
--   (about 1.4 on 1080p). Saved positions stay valid.
-- v0.8.0: Bigger and easier to read. The window scales itself every
--   time it opens: 70% of the screen height (min 1.0, max 1.6, never
--   wider than 95% of the screen), so text, icons, rows, buttons and
--   the dropdowns all grow together (about 1.4 on 1080p). The "updated"
--   line (Bag / Bank / Equipped / Mail / AH) moved from under the item
--   list to the bottom of the whole window, full width; it no longer
--   runs over the edge, and when it needs two lines the panels make
--   room. Saved position keeps the scale it was saved at; at another
--   scale (first open after this update, other screen) the window
--   opens centred.
-- v0.7.1: Gear for alts detail: the spec moved from the first line to
--   the second line ("Shadow Magic (class default) - replaces X"), so
--   the first line is no longer cut off by the Ignore button.
-- v0.7.0: Gear for alts (B). Button "Gear for alts" next to the value
--   switch (second click: back to the items). The left list then shows
--   snap.gear.rows: item + who holds it, where (Bag / Bank / Mail) and
--   for whom (class colour, +x.x% / empty, best first). Character =
--   "for whom", Location = where it lies (Bag / Bank / Mail).
--   Right: "Upgrade for" with one block per character (gain, spec, at
--   level X, "holds it", what it replaces, gear age when older than a
--   day) and a small Ignore button per character
--   (Resolver.Upgrade.IgnoreFor), then "Where" with the holders.
-- v0.6.0: Profile line shows the spec after "Mage 10" (snap.profile.
--   spec from ResolverHoldings): "Fire 5 pts", "Holy 6 / Retribution 5
--   pts", grey "Fire (class default)" without points, grey "Spec not
--   read" when the talents were never read. Hovering the profile line
--   lists every tree with its points: "Used by the Upgrade Advisor for
--   this character."
-- v0.5.0: Location Mail shows "Gold in the mail" under the items: one
--   row per mail with money (AH sale: item, count; player: sender),
--   net amount in green, and a large green total at the bottom.
--   Clicking a row shows the breakdown on the right (sold for, AH fee,
--   deposit back, net; or sender and amount) and when the mail expires.
-- v0.4.1: Empty list per location: Mail says "No items in the mail."
--   plus the gold in the mail; AH says "No items on the AH." plus the
--   AH incoming money (Peter: the gold was only in the profile line).
-- v0.4.0: AH (Holdings step 4): "On AH: N listed, buyout X, expires
--   in Yh" in Item Analysis ("expired - in your mail" in red), per
--   character "(AH expires in Yh)" / "(AH expired)", "AH incoming" in
--   the profile and summary line.
-- v0.3.0: Mail (Holdings step 3): "Mail expires in N days" in Item
--   Analysis (red when the resolver flags it as soon), per character
--   "(mail expires in N days)" / "(sent)", gold in the mail in the
--   profile and summary line.
-- v0.2.1: Professions on their own second line (a character with all
--   professions did not fit on one line). The line keeps its space when
--   empty, so the window does not jump when switching characters.
-- v0.2.0: Profile line under the header (Holdings step 2): one
--   character -> class/level, gold, free bag/bank slots, professions;
--   All Characters -> number of characters, gold, item value, total.
--   Location "Equipped".
-- v0.1.2: Item Analysis: one text field per line (Value and Holdings
--   by Character). In one multi-line field the coin icons shifted away
--   from their numbers; single-line fields render them like the
--   dashboard does.
-- v0.1.1: Money in the WoW coin format (Core 0.3.0 LOF.FormatMoney);
--   value column and window a bit wider for the coin icons.
-- v0.1.0: Initial version (LOF 1.1.2, Holdings phase 1).
--   - Window like LOC's "Bag Holdings": header with Character and
--     Location dropdowns and a Swap Value / Vendor Value switch; left
--     "Items" (icon, name, count, source, location, value), right
--     "Item Analysis" (value per item, held, total value, holdings by
--     character and location). No market history (yet).
--   - Simple own dropdown menus (the lists are short), Escape closes.
--   - The character choice starts at the logged-in character every
--     time the window opens.
-- =============================================================

local LOF = LOF
LOF.VERSION_UI_HOLDINGS = "0.9.5"

local UI = LOF.UI
local Resolver = LOF.Resolver
local Kit = UI.Kit

local GOLD, GREEN, GREY = Kit.GOLD, Kit.GREEN, Kit.GREY
local ORANGE = Kit.ORANGE   -- v0.9.5: from the Kit

local WIN_W, WIN_H = 860, 538
local FOOTER_PAD = 10          -- v0.8.0: window edge -> footer text
local OFFSCREEN_SIDE = 0.45    -- v0.8.3: part of the width allowed off screen
local TITLE_KEEP = 40          -- v0.8.3: height that always stays on screen
local LEFT_W       = 490
local ROW_H        = 22
local ICON         = 18
local VALUE_W      = 110   -- value column (coin icons)

local LOCATION_LABEL = {
    ALL = "All Locations", bag = "Bag", bank = "Bank", equipped = "Equipped",
    mail = "Mail", ah = "AH", MULTI = "Multi",
}

local win
local view = { character = "current", location = "ALL", valueMode = "SWAP", selectedKey = nil,
               gearMode = false }   -- v0.7.0

-- -------------------------------------------------------------
-- Small presentation helpers
-- -------------------------------------------------------------
local ClassColored = Kit.ClassColored   -- v0.9.3: the Kit helper
local DE_COLOR = Kit.DE_COLOR           -- v0.8.5 / v0.9.3: from the Kit

local function SourceText(row)
    if row.valueSource == "AH" then
        local c = Kit.FRESHNESS_COLOR[row.freshness] or ""
        return c .. "AH" .. (c ~= "" and "|r" or "")
    end
    if row.valueSource == "DE" then
        return DE_COLOR .. "DE|r"
    end
    return "Vendor"
end

local function PartsText(parts)
    local out = {}
    for _, code in ipairs(Resolver.Holdings.LOCATIONS) do
        local n = parts and parts[code]
        if n and n > 0 then
            out[#out + 1] = n .. " " .. string.lower(LOCATION_LABEL[code] or code)
        end
    end
    return table.concat(out, ", ")
end

-- -------------------------------------------------------------
-- Dropdown (button + small option list)
-- -------------------------------------------------------------
local openMenu

local function CloseMenu()
    if openMenu then openMenu:Hide() end
    openMenu = nil
end

local function CreateDropdown(parent, width)
    local b = Kit.CreateButton(parent, "", width)
    b:SetHeight(22)
    local menu = CreateFrame("Frame", nil, b, BackdropTemplateMixin and "BackdropTemplate" or nil)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
    menu:SetWidth(width + 40)
    if menu.SetBackdrop then
        menu:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        menu:SetBackdropColor(0, 0, 0, 0.95)
        menu:SetBackdropBorderColor(0.7, 0.55, 0.15, 1)
    end
    menu:Hide()
    menu.items = {}
    b.menu = menu

    -- options: { { value = x, text = "..." }, ... }; onPick(value)
    function b:SetOptions(options, onPick)
        for i, opt in ipairs(options) do
            local item = menu.items[i]
            if not item then
                item = CreateFrame("Button", nil, menu)
                item:SetHeight(18)
                item:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6 - (i - 1) * 18)
                item:SetPoint("RIGHT", menu, "RIGHT", -6, 0)
                item:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                item.text = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                item.text:SetPoint("LEFT", item, "LEFT", 4, 0)
                menu.items[i] = item
            end
            item.text:SetText(opt.text)
            item:SetScript("OnClick", function()
                CloseMenu()
                onPick(opt.value)
            end)
            item:Show()
        end
        for i = #options + 1, #menu.items do menu.items[i]:Hide() end
        menu:SetHeight(12 + #options * 18)
    end

    b:SetScript("OnClick", function(self)
        if openMenu == self.menu then CloseMenu() return end
        CloseMenu()
        self.menu:Show()
        openMenu = self.menu
    end)
    return b
end

-- -------------------------------------------------------------
-- Build
-- -------------------------------------------------------------
local function CreateListRow(parent, width)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, ROW_H)
    row:RegisterForClicks("LeftButtonUp")

    row.sel = row:CreateTexture(nil, "BACKGROUND")
    row.sel:SetAllPoints(row)
    row.sel:SetColorTexture(1, 0.82, 0, 0.18)
    row.sel:Hide()
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)

    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.value:SetWidth(VALUE_W)
    row.value:SetJustifyH("RIGHT")

    row.loc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.loc:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
    row.loc:SetWidth(50)
    row.loc:SetJustifyH("LEFT")

    row.source = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.source:SetPoint("RIGHT", row.loc, "LEFT", -6, 0)
    row.source:SetWidth(50)
    row.source:SetJustifyH("LEFT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row.source, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row:SetScript("OnEnter", function(self)
        if not self.data or not self.data.link or self.data.isMoney then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.data.link)
        if not self.data.targets then Kit.AddValueLines(self.data) end   -- v0.7.0: gear rows
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", Kit.HideTooltip)
    row:SetScript("OnClick", function(self)
        if not self.data then return end
        view.selectedKey = self.data.key
        UI.RefreshHoldingsWindow()
    end)
    return row
end

local function Text(parent, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

local function BuildWindow()
    win = Kit.CreateStyledPanel("LOF_HoldingsFrame", "holdings", WIN_W, WIN_H, "HIGH")
    win:SetFrameStrata("HIGH")
    if win.Inset then win.Inset:Hide() end
    if not win.CloseButton then
        win.close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
        win.close:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0)
    end
    if _G.UISpecialFrames then tinsert(_G.UISpecialFrames, "LOF_HoldingsFrame") end
    win:SetScript("OnHide", CloseMenu)
    -- v0.8.3: partly off screen allowed, title bar always visible
    win:SetClampedToScreen(true)
    local side = math.floor(WIN_W * OFFSCREEN_SIDE)
    win:SetClampRectInsets(side, -side, 0, WIN_H - TITLE_KEEP)

    local top = win.styled and -32 or -12

    -- Header
    win.charLabel = Text(win, "GameFontNormal")
    win.charLabel:SetPoint("TOPLEFT", win, "TOPLEFT", 16, top - 6)
    win.charLabel:SetText("Character")
    win.charDrop = CreateDropdown(win, 170)
    win.charDrop:SetPoint("LEFT", win.charLabel, "RIGHT", 8, 0)

    -- v0.9.0: Forget (one other character chosen) + confirmation
    -- v0.9.2: "Remove from LOF"
    win.forgetBtn = Kit.CreateButton(win, "Remove from LOF", 124)
    win.forgetBtn:SetHeight(22)
    win.forgetBtn:SetPoint("LEFT", win.charDrop, "RIGHT", 6, 0)
    win.forgetBtn:SetScript("OnClick", function()   -- v0.9.3: Kit.AskRemoveCharacter
        Kit.AskRemoveCharacter(win, win.forgetName, function()
            view.character = "current"
            view.selectedKey = nil
        end, { y = 40 })
    end)
    win.forgetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Remove this character from LOF")
        GameTooltip:AddLine("For a character you deleted or no longer play. "
            .. "The game never tells an addon a character is gone.", 1, 1, 1, true)
        GameTooltip:AddLine("Also in Settings > Characters.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    win.forgetBtn:SetScript("OnLeave", Kit.HideTooltip)
    win.forgetBtn:Hide()

    -- v0.9.3: the confirmation is Kit.ShowConfirm (UI.lua), one dialog for all windows

    win.locLabel = Text(win, "GameFontNormal")
    win.locLabel:SetPoint("LEFT", win.charDrop, "RIGHT", 24, 0)
    win.locLabel:SetText("Location")
    win.locDrop = CreateDropdown(win, 120)
    win.locDrop:SetPoint("LEFT", win.locLabel, "RIGHT", 8, 0)

    win.modeBtn = Kit.CreateButton(win, "", 120)
    win.modeBtn:SetHeight(22)
    win.modeBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", -16, top - 1)
    win.modeBtn:SetScript("OnClick", function()
        view.valueMode = (view.valueMode == "VENDOR") and "SWAP" or "VENDOR"
        UI.RefreshHoldingsWindow()
    end)
    win.modeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Value")
        GameTooltip:AddLine(GOLD .. "Swap Value|r: as LOF values your items (Settings: "
            .. "vendor, or Auctionator prices where allowed).", 1, 1, 1, true)
        GameTooltip:AddLine(GOLD .. "Vendor Value|r: what a vendor pays, no AH prices.", 1, 1, 1, true)
        GameTooltip:AddLine("Click to switch.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    win.modeBtn:SetScript("OnLeave", Kit.HideTooltip)

    -- v0.7.0: Gear for alts
    win.gearBtn = Kit.CreateButton(win, "Gear for alts", 120)
    win.gearBtn:SetHeight(22)
    win.gearBtn:SetPoint("RIGHT", win.modeBtn, "LEFT", -8, 0)
    win.gearBtn:SetScript("OnClick", function()
        view.gearMode = not view.gearMode
        view.selectedKey = nil
        if view.gearMode and view.location ~= "ALL" and view.location ~= "bag"
            and view.location ~= "bank" and view.location ~= "mail" then
            view.location = "ALL"
        end
        UI.RefreshHoldingsWindow()
    end)
    win.gearBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Gear for alts")
        GameTooltip:AddLine("Bind-on-Equip gear in bags, bank and mail of all your characters "
            .. "that is an upgrade for one of them.", 1, 1, 1, true)
        GameTooltip:AddLine("Character = for whom, Location = where it lies.", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("Click again to go back to the items.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    win.gearBtn:SetScript("OnLeave", Kit.HideTooltip)

    -- v0.2.0: profile / summary line
    win.profile = Text(win, "GameFontHighlight")
    win.profile:SetPoint("TOPLEFT", win, "TOPLEFT", 16, top - 34)
    win.profile:SetPoint("RIGHT", win, "RIGHT", -16, 0)
    win.profile:SetWordWrap(false)
    -- v0.6.0: hover area over the profile line (spec tooltip)
    win.profileHover = CreateFrame("Frame", nil, win)
    win.profileHover:SetPoint("TOPLEFT", win.profile, "TOPLEFT", 0, 2)
    win.profileHover:SetPoint("BOTTOMRIGHT", win.profile, "BOTTOMRIGHT", 0, -2)
    win.profileHover:EnableMouse(true)
    win.profileHover:SetScript("OnEnter", function(self)
        local spec = self.spec
        if not spec then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Spec")
        if #(spec.trees or {}) > 0 then
            for _, t in ipairs(spec.trees) do
                GameTooltip:AddDoubleLine(tostring(t.name), tostring(t.points) .. " pts", 1, 1, 1, 1, 0.82, 0)
            end
        else
            GameTooltip:AddLine("Talents not read yet: log in on this character once.", 0.7, 0.7, 0.7, true)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Used by the Upgrade Advisor for this character.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    win.profileHover:SetScript("OnLeave", Kit.HideTooltip)
    win.profs = Text(win, "GameFontHighlight")
    win.profs:SetPoint("TOPLEFT", win, "TOPLEFT", 16, top - 52)
    win.profs:SetPoint("RIGHT", win, "RIGHT", -16, 0)
    win.profs:SetWordWrap(false)

    local bodyTop = top - 74

    -- Left: Items
    win.left = Kit.CreateInset(win)
    win.left:SetPoint("TOPLEFT", win, "TOPLEFT", 10, bodyTop)
    win.left:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 10, FOOTER_PAD + 18)
    win.left:SetWidth(LEFT_W)

    win.leftTitle = Text(win.left, "GameFontNormal")
    win.leftTitle:SetPoint("TOPLEFT", win.left, "TOPLEFT", 10, -9)
    win.leftTitle:SetText("Items")
    win.leftSub = Text(win.left)
    win.leftSub:SetPoint("TOPLEFT", win.leftTitle, "BOTTOMLEFT", 0, -4)

    local colY = -46
    local listW = LEFT_W - 20 - 26
    win.colName = Text(win.left, "GameFontNormalSmall")
    win.colName:SetPoint("TOPLEFT", win.left, "TOPLEFT", 12, colY)
    win.colName:SetText("Item")
    win.colValue = Text(win.left, "GameFontNormalSmall", "RIGHT")
    win.colValue:SetPoint("TOPLEFT", win.left, "TOPLEFT", 10 + listW - VALUE_W, colY)
    win.colValue:SetWidth(VALUE_W - 2)
    win.colValue:SetText("Value")
    win.colLoc = Text(win.left, "GameFontNormalSmall")
    win.colLoc:SetPoint("TOPLEFT", win.left, "TOPLEFT", 10 + listW - VALUE_W - 56, colY)
    win.colLoc:SetText("Location")
    win.colSource = Text(win.left, "GameFontNormalSmall")
    win.colSource:SetPoint("TOPLEFT", win.left, "TOPLEFT", 10 + listW - VALUE_W - 56 - 56, colY)
    win.colSource:SetText("Source")

    -- v0.8.0: footer under the whole window, full width
    win.footer = Text(win)
    win.footer:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 16, FOOTER_PAD)
    win.footer:SetWidth(WIN_W - 32)

    win.scroll = CreateFrame("ScrollFrame", nil, win.left, "UIPanelScrollFrameTemplate")
    win.scroll:SetPoint("TOPLEFT", win.left, "TOPLEFT", 10, colY - 16)
    win.scroll:SetPoint("BOTTOMRIGHT", win.left, "BOTTOMRIGHT", -28, 8)
    win.content = CreateFrame("Frame", nil, win.scroll)
    win.content:SetSize(listW, 10)
    win.scroll:SetScrollChild(win.content)
    win.rows = {}
    win.listW = listW
    win.empty = Text(win.content, "GameFontDisableSmall")
    win.empty:SetPoint("TOPLEFT", win.content, "TOPLEFT", 4, -4)
    win.moneyHead = Text(win.content, "GameFontNormal")
    win.moneyHead:SetText("Gold in the mail")
    win.moneyTotal = Text(win.content, "GameFontNormalLarge")
    win.empty:SetWidth(listW - 8)

    -- Right: Item Analysis
    win.right = Kit.CreateInset(win)
    win.right:SetPoint("TOPLEFT", win.left, "TOPRIGHT", 8, 0)
    win.right:SetPoint("BOTTOMLEFT", win.left, "BOTTOMRIGHT", 8, 0)
    win.right:SetPoint("RIGHT", win, "RIGHT", -10, 0)

    local r = win.right
    win.rightTitle = Text(r, "GameFontNormal")
    win.rightTitle:SetPoint("TOPLEFT", r, "TOPLEFT", 10, -9)
    win.rightTitle:SetText("Item Analysis")

    win.cardIcon = r:CreateTexture(nil, "ARTWORK")
    win.cardIcon:SetSize(36, 36)
    win.cardIcon:SetPoint("TOPLEFT", r, "TOPLEFT", 12, -32)
    win.cardBorder = r:CreateTexture(nil, "OVERLAY")
    win.cardBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    win.cardBorder:SetAllPoints(win.cardIcon)
    win.cardName = Text(r, "GameFontHighlight")
    win.cardName:SetPoint("TOPLEFT", win.cardIcon, "TOPRIGHT", 10, -2)
    win.cardName:SetPoint("RIGHT", r, "RIGHT", -10, 0)
    win.cardName:SetWordWrap(false)
    win.cardSub = Text(r)
    win.cardSub:SetPoint("TOPLEFT", win.cardName, "BOTTOMLEFT", 0, -4)

    win.cardHover = CreateFrame("Frame", nil, r)
    win.cardHover:SetPoint("TOPLEFT", win.cardIcon, "TOPLEFT")
    win.cardHover:SetPoint("BOTTOMRIGHT", win.cardIcon, "BOTTOMRIGHT")
    win.cardHover:EnableMouse(true)
    win.cardHover:SetScript("OnEnter", function(self)
        if not self.data or not self.data.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.data.link)
        Kit.AddValueLines(self.data)
        GameTooltip:Show()
    end)
    win.cardHover:SetScript("OnLeave", Kit.HideTooltip)

    win.divider = Kit.CreateDivider(r)
    win.divider:SetPoint("TOPLEFT", r, "TOPLEFT", 10, -76)
    win.divider:SetPoint("TOPRIGHT", r, "TOPRIGHT", -10, -76)

    win.valueHead = Text(r, "GameFontNormal")
    win.valueHead:SetPoint("TOPLEFT", r, "TOPLEFT", 12, -88)
    win.valueHead:SetText("Value")
    win.valueLines = {}

    win.holdHead = Text(r, "GameFontNormal")
    win.holdHead:SetText("Holdings by Character")
    win.holdLines = {}
    win.gearTargets = {}   -- v0.7.0: { main, sub, btn } per character

    win:Hide()
end

-- -------------------------------------------------------------
-- v0.8.0: footer layout (presentation only; scale: Kit.ApplyAutoScale)
-- -------------------------------------------------------------

local function SetFooter(text)
    win.footer:SetText(text)
    local h = win.footer:GetStringHeight() or 0
    if h < 10 then h = 10 end
    win.left:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 10, FOOTER_PAD + h + 6)
end

local function GetRow(i)
    local row = win.rows[i]
    if not row then
        row = CreateListRow(win.content, win.listW)
        win.rows[i] = row
    end
    return row
end

-- One single-line text field per line, stacked under `anchor`.
-- Returns the last field shown (or the anchor when there are none).
local LINE_GAP = 5

local function SetLines(pool, anchor, lines)
    local prev = anchor
    for i, text in ipairs(lines) do
        local fs = pool[i]
        if not fs then
            fs = Text(win.right)
            fs:SetWordWrap(false)
            pool[i] = fs
        end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -6 or -LINE_GAP)
        fs:SetPoint("RIGHT", win.right, "RIGHT", -12, 0)
        fs:SetText(text)
        fs:Show()
        prev = fs
    end
    for i = #lines + 1, #pool do pool[i]:Hide() end
    return prev
end

-- -------------------------------------------------------------
-- Render
-- -------------------------------------------------------------
local function UpdatedText(snap)
    local parts = {}
    for _, code in ipairs(snap.locations) do
        local u = snap.updated[code] or {}
        local label = LOCATION_LABEL[code] or code
        local when
        if snap.isAll then
            when = u.oldest and ("oldest " .. Kit.WhenText(u.oldest)) or (GREY .. "never|r")
            if u.oldest and (u.missing or 0) > 0 then
                when = when .. GREY .. " (" .. u.missing .. " never)|r"
            end
        else
            when = Kit.WhenText(u.newest)
        end
        parts[#parts + 1] = GOLD .. label .. ":|r " .. when
    end
    return table.concat(parts, "   ")
end

local function RenderHeader(snap)
    local charText
    if snap.isAll then
        charText = "All Characters"
    else
        charText = tostring(snap.character or "?")
        if snap.character == snap.currentName then charText = charText .. " (current)" end
    end
    if snap.gearMode then
        Kit.SetPanelTitle(win, "LootOptimizer Forever - Holdings - Gear for alts - for " .. charText)
    else
        Kit.SetPanelTitle(win, "LootOptimizer Forever - Holdings - " .. charText)
    end
    win.charDrop:SetText(charText)
    -- v0.9.0: Forget only for one other character
    local canForget = not snap.isAll and snap.character ~= nil and snap.character ~= snap.currentName
    win.forgetName = canForget and snap.character or nil
    win.forgetBtn:SetShown(canForget)
    if not canForget then Kit.HideConfirm(win) end
    win.locLabel:ClearAllPoints()
    win.locLabel:SetPoint("LEFT", win.charDrop, "RIGHT", canForget and 154 or 24, 0)

    local charOptions = { { value = "ALL", text = GOLD .. "All Characters|r" } }
    for _, c in ipairs(snap.characters) do
        local t = ClassColored(c.name, c.class)
        if c.isCurrent then
            t = t .. GREY .. " (current)|r"
        elseif c.lastSeen and Kit.WhenText then   -- v0.9.0
            t = t .. GREY .. "  " .. Kit.WhenText(c.lastSeen) .. "|r"
        end
        charOptions[#charOptions + 1] = { value = c.isCurrent and "current" or c.name, text = t }
    end
    win.charDrop:SetOptions(charOptions, function(value)
        view.character = value
        view.selectedKey = nil
        UI.RefreshHoldingsWindow()
    end)

    win.locDrop:SetText(LOCATION_LABEL[snap.location] or snap.location)
    local locOptions = { { value = "ALL", text = GOLD .. "All Locations|r" } }
    for _, code in ipairs(snap.gearMode and snap.gear.locations or snap.locations) do
        locOptions[#locOptions + 1] = { value = code, text = LOCATION_LABEL[code] or code }
    end
    win.locDrop:SetOptions(locOptions, function(value)
        view.location = value
        view.selectedKey = nil
        UI.RefreshHoldingsWindow()
    end)

    win.modeBtn:SetText(snap.valueMode == "VENDOR" and "Vendor Value" or "Swap Value")
    win.modeBtn:SetShown(not snap.gearMode)
    win.gearBtn:SetText(snap.gearMode and "Show items" or "Gear for alts")

    -- column headers
    if snap.gearMode then
        win.leftTitle:SetText(ORANGE .. "Gear for alts|r")
        win.colSource:SetText("")
        win.colLoc:SetText("Where")
        win.colValue:SetText("For")
    else
        win.leftTitle:SetText("Items")
        win.colSource:SetText("Source")
        win.colLoc:SetText("Location")
        win.colValue:SetText("Value")
    end
end

local SEP = GREY .. "   |   |r"

local function TimeLeft(seconds)
    seconds = math.max(0, tonumber(seconds or 0) or 0)
    if seconds >= 86400 then return math.floor(seconds / 86400) .. "d" end
    if seconds >= 3600 then return math.floor(seconds / 3600) .. "h" end
    return math.max(1, math.floor(seconds / 60)) .. "m"
end

local function MailDays(days)
    if days <= 0 then return "less than a day" end
    if days == 1 then return "1 day" end
    return days .. " days"
end

-- v0.6.0: spec text (the resolver decided what it is)
local function SpecText(spec)
    if not spec then return nil end
    local basis = spec.basis or {}
    if spec.source == "unknown" then
        return GREY .. "Spec not read|r"
    end
    if spec.source == "default" or not basis[1] then
        return GREY .. tostring(basis[1] and basis[1].name or "?") .. " (class default)|r"
    end
    local names, points = {}, {}
    for _, b in ipairs(basis) do
        names[#names + 1] = tostring(b.name)
        points[#points + 1] = tostring(b.points)
    end
    if #basis == 1 then
        return names[1] .. " " .. GOLD .. points[1] .. "|r pts"
    end
    local parts = {}
    for i = 1, #names do parts[i] = names[i] .. " " .. GOLD .. points[i] .. "|r" end
    return table.concat(parts, " / ") .. " pts"
end

local function RenderProfile(snap)
    local parts = {}
    win.profileHover.spec = snap.profile and snap.profile.spec or nil
    if snap.summary then
        local m = snap.summary
        parts[#parts + 1] = GOLD .. m.characters .. (m.characters == 1 and " character|r" or " characters|r")
        parts[#parts + 1] = "Gold " .. LOF.FormatMoney(m.gold)
        if (m.mailGold or 0) > 0 then parts[#parts + 1] = "Mail " .. LOF.FormatMoney(m.mailGold) end
        if (m.ahIncoming or 0) > 0 then parts[#parts + 1] = "AH incoming " .. LOF.FormatMoney(m.ahIncoming) end
        parts[#parts + 1] = "Items " .. LOF.FormatMoney(m.itemValue)
        parts[#parts + 1] = "Total " .. GREEN .. LOF.FormatMoney(m.total) .. "|r"
    elseif snap.profile then
        local p = snap.profile
        local who = ClassColored(p.name, p.class)
        if p.className or p.level then
            who = who .. "  " .. GREY .. tostring(p.className or "") .. " " .. tostring(p.level or "") .. "|r"
        end
        local specText = SpecText(p.spec)
        if specText then who = who .. "  " .. specText end
        parts[#parts + 1] = who
        parts[#parts + 1] = p.gold and LOF.FormatMoney(p.gold) or (GREY .. "gold unknown|r")
        if (p.mailGold or 0) > 0 then parts[#parts + 1] = "Mail " .. LOF.FormatMoney(p.mailGold) end
        if (p.ahIncoming or 0) > 0 then parts[#parts + 1] = "AH incoming " .. LOF.FormatMoney(p.ahIncoming) end
        parts[#parts + 1] = "Bags " .. (p.freeBag and (p.freeBag .. " free") or "?")
        parts[#parts + 1] = "Bank " .. (p.freeBank and (p.freeBank .. " free") or (GREY .. "not read|r"))
    end
    win.profile:SetText(table.concat(parts, SEP))

    local profs = {}
    for _, prof in ipairs((snap.profile and snap.profile.professions) or {}) do
        profs[#profs + 1] = prof.name .. " " .. GOLD .. tostring(prof.level) .. "|r/" .. tostring(prof.max)
    end
    win.profs:SetText(table.concat(profs, SEP))
end

local COIN_ICON = "Interface\\Icons\\INV_Misc_Coin_01"

local function PlaceRow(row, y)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", win.content, "TOPLEFT", 0, y)
    row:Show()
end

local function RenderList(snap)
    win.leftSub:SetText(string.format("Items: %d   |   Total: %s",
        snap.totals.items, LOF.FormatMoney(snap.totals.value)))
    SetFooter(UpdatedText(snap))

    local y, n = 0, 0
    for _, data in ipairs(snap.rows) do
        n = n + 1
        local row = GetRow(n)
        row.data = data
        row.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local label = LOF.ColorizeName(data.name, data.quality)
        if (data.count or 1) > 1 then label = label .. GREY .. " x" .. data.count .. "|r" end
        row.name:SetText(label)
        row.source:SetText(SourceText(data))
        row.loc:SetText(LOCATION_LABEL[data.location] or "")
        row.value:SetText(LOF.FormatMoney(data.value or 0))
        row.sel:SetShown(snap.selected ~= nil and snap.selected.key == data.key)
        PlaceRow(row, y)
        y = y - ROW_H
    end

    local money = snap.mailMoney or {}
    if #snap.rows == 0 then
        local text
        if snap.location == "mail" then
            text = "No items in the mail."
        elseif snap.location == "ah" then
            local info = snap.profile or snap.summary or {}
            text = "No items on the AH."
            if (info.ahIncoming or 0) > 0 then
                text = text .. "  AH incoming: " .. LOF.FormatMoney(info.ahIncoming)
            end
        else
            text = "Nothing found for this selection. Bags are read automatically; "
                .. "open your bank once on each character to add the bank."
        end
        win.empty:SetText(text)
        win.empty:Show()
        y = y - (win.empty:GetStringHeight() + 10)
    else
        win.empty:Hide()
    end

    -- v0.5.0: gold in the mail, one row per mail
    if #money > 0 then
        win.moneyHead:ClearAllPoints()
        win.moneyHead:SetPoint("TOPLEFT", win.content, "TOPLEFT", 4, y - 8)
        win.moneyHead:Show()
        y = y - 30
        for _, m in ipairs(money) do
            n = n + 1
            local row = GetRow(n)
            row.data = m
            row.icon:SetTexture(m.icon or COIN_ICON)
            local label
            if m.kind == "ah" then
                label = LOF.ColorizeName(m.item or "?", m.quality)
                if (m.count or 0) > 1 then label = label .. GREY .. " x" .. m.count .. "|r" end
            else
                label = "From " .. tostring(m.from or "?")
            end
            if snap.isAll then label = label .. GREY .. "  (" .. tostring(m.character) .. ")|r" end
            row.name:SetText(label)
            row.source:SetText(m.kind == "ah" and "AH sale" or "Player")
            row.loc:SetText("Mail")
            row.value:SetText(GREEN .. LOF.FormatMoney(m.net) .. "|r")
            row.sel:SetShown(snap.selectedMoney ~= nil and snap.selectedMoney.key == m.key)
            PlaceRow(row, y)
            y = y - ROW_H
        end
        win.moneyTotal:ClearAllPoints()
        win.moneyTotal:SetPoint("TOPLEFT", win.content, "TOPLEFT", 4, y - 8)
        win.moneyTotal:SetText(GREEN .. "Total gold in the mail: " .. LOF.FormatMoney(snap.mailMoneyTotal) .. "|r")
        win.moneyTotal:Show()
        y = y - 34
    else
        win.moneyHead:Hide()
        win.moneyTotal:Hide()
    end

    for i = n + 1, #win.rows do
        win.rows[i]:Hide()
        win.rows[i].data = nil
    end
    win.content:SetHeight(math.max(10, -y))
end

-- v0.5.0: breakdown of a mail with money
local function RenderMoneyAnalysis(m)
    win.cardHover.data = nil
    win.cardIcon:SetTexture(m.icon or COIN_ICON)
    if m.quality then
        win.cardBorder:SetVertexColor(Kit.GetQualityRGB(m.quality))
        win.cardBorder:Show()
    else
        win.cardBorder:Hide()
    end
    if m.kind == "ah" then
        win.cardName:SetText(LOF.ColorizeName(m.item or "?", m.quality))
        win.cardSub:SetText(GREY .. "AH sale   |   Mail   |   " .. tostring(m.character) .. "|r")
        win.valueHead:SetText("AH sale")
    else
        win.cardName:SetText("From " .. tostring(m.from or "?"))
        win.cardSub:SetText(GREY .. "Money   |   Mail   |   " .. tostring(m.character) .. "|r")
        win.valueHead:SetText("Money")
    end

    local lines = {}
    if m.kind == "ah" then
        if m.gross then
            lines[#lines + 1] = GOLD .. "Sold for:|r  " .. LOF.FormatMoney(m.gross)
                .. ((m.count or 0) > 0 and (GREY .. "  (" .. m.count .. " items)|r") or "")
        end
        if m.fee and m.fee > 0 then
            lines[#lines + 1] = GOLD .. "AH fee:|r  " .. Kit.RED .. "-" .. LOF.FormatMoney(m.fee) .. "|r"
        end
        if m.deposit and m.deposit > 0 then
            lines[#lines + 1] = GOLD .. "Deposit back:|r  +" .. LOF.FormatMoney(m.deposit)
        end
    elseif m.sent then
        lines[#lines + 1] = GREY .. "Sent by you (booked by LOF)|r"
    end
    lines[#lines + 1] = GOLD .. "In the mail:|r  " .. GREEN .. LOF.FormatMoney(m.net) .. "|r"
    if m.expiresDays then
        local c = m.expiringSoon and Kit.RED or ""
        lines[#lines + 1] = c .. "Mail expires in " .. MailDays(m.expiresDays) .. (c ~= "" and "|r" or "")
    end
    SetLines(win.valueLines, win.valueHead, lines)
    win.holdHead:Hide()
    SetLines(win.holdLines, win.holdHead, {})
end

local function RenderAnalysis(snap)
    if snap.selectedMoney then
        RenderMoneyAnalysis(snap.selectedMoney)
        return
    end
    win.valueHead:SetText("Value")
    local d = snap.selected
    win.cardHover.data = d
    if not d then
        win.cardIcon:SetTexture(nil)
        win.cardBorder:Hide()
        win.cardName:SetText(GREY .. "Select an item|r")
        win.cardSub:SetText("")
        SetLines(win.valueLines, win.valueHead, {})
        win.holdHead:Hide()
        SetLines(win.holdLines, win.holdHead, {})
        return
    end
    win.cardIcon:SetTexture(d.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    win.cardBorder:SetVertexColor(Kit.GetQualityRGB(d.quality))
    win.cardBorder:Show()
    win.cardName:SetText(LOF.ColorizeName(d.name, d.quality))
    win.cardSub:SetText(GREY .. "Held: " .. tostring(d.count) .. "   |   "
        .. (LOCATION_LABEL[d.location] or "") .. "|r")

    local lines = {}
    local each
    if d.valueSource == "AH" then
        local c = Kit.FRESHNESS_COLOR[d.freshness] or ""
        each = LOF.FormatMoney(d.valueEach or 0) .. "  " .. c .. "(AH, "
            .. Kit.AgeText(d.ahAgeDays) .. ")" .. (c ~= "" and "|r" or "")
    elseif d.valueSource == "DE" then
        local who = ""
        if d.de and d.de.by then who = ", " .. tostring(d.de.by) end
        each = LOF.FormatMoney(d.valueEach or 0) .. "  " .. DE_COLOR .. "(Disenchant" .. who .. ")|r"
    else
        each = LOF.FormatMoney(d.valueEach or d.vendorEach or 0) .. "  (Vendor)"
    end
    lines[#lines + 1] = GOLD .. "Per item:|r  " .. each
    lines[#lines + 1] = GOLD .. "Held:|r  " .. tostring(d.count)
    lines[#lines + 1] = GOLD .. "Total value:|r  " .. GREEN .. LOF.FormatMoney(d.value or 0) .. "|r"
    if (d.boundCount or 0) > 0 then
        lines[#lines + 1] = GREY .. "Soulbound: " .. d.boundCount .. " (vendor value)|r"
    end
    if snap.valueMode == "VENDOR" then
        lines[#lines + 1] = GREY .. "Vendor Value: AH prices not used.|r"
    end
    if d.ahListed then
        local line = GOLD .. "On AH:|r " .. d.ahListed .. " listed, buyout " .. LOF.FormatMoney(d.ahBuyout or 0)
        if d.ahExpired then
            line = line .. Kit.RED .. "  expired - in your mail|r"
        elseif d.ahExpiresIn then
            line = line .. ", expires in " .. TimeLeft(d.ahExpiresIn)
        end
        lines[#lines + 1] = line
    end
    if d.mailExpiresDays then
        local c = d.mailExpiringSoon and Kit.RED or ""
        lines[#lines + 1] = c .. "Mail expires in " .. MailDays(d.mailExpiresDays) .. (c ~= "" and "|r" or "")
    end
    local lastValue = SetLines(win.valueLines, win.valueHead, lines)

    win.holdHead:ClearAllPoints()
    win.holdHead:SetPoint("TOPLEFT", lastValue, "BOTTOMLEFT", 0, -16)
    win.holdHead:Show()
    local hl = {}
    hl[#hl + 1] = GOLD .. "Held total:|r " .. tostring(d.count) .. "  (" .. #d.holders
        .. (#d.holders == 1 and " character)" or " characters)")
    for _, h in ipairs(d.holders) do
        local name = ClassColored(h.name, h.class)
        if h.isCurrent then name = name .. GREY .. " (current)|r" end
        local line = name .. "  -  " .. PartsText(h.parts)
        if h.parts.bank and h.updated and h.updated.bank then
            line = line .. GREY .. "  (bank read " .. Kit.WhenText(h.updated.bank) .. ")|r"
        end
        if h.mailExpiresDays then
            local c = h.mailExpiringSoon and Kit.RED or GREY
            line = line .. c .. "  (mail expires in " .. MailDays(h.mailExpiresDays) .. ")|r"
        end
        if h.ahExpired then
            line = line .. Kit.RED .. "  (AH expired)|r"
        elseif h.ahExpiresIn then
            line = line .. GREY .. "  (AH expires in " .. TimeLeft(h.ahExpiresIn) .. ")|r"
        end
        if h.mailSent then
            line = line .. GREY .. "  (" .. h.mailSent .. " sent)|r"
        end
        hl[#hl + 1] = line
        for _, f in ipairs(h.mailFrom or {}) do   -- v0.8.2
            hl[#hl + 1] = "    |cffffffff(" .. f.count .. ") from " .. tostring(f.name) .. "|r"
        end
    end
    SetLines(win.holdLines, win.holdHead, hl)
end

-- -------------------------------------------------------------
-- v0.7.0: Gear for alts (texts only; the resolver decided)
-- -------------------------------------------------------------
local function FirstName(name)
    return (tostring(name):match("^(%S+)")) or tostring(name)
end

local function GainText(t)   -- v0.9.3: Kit.GainText
    return Kit.GainText(t, GREEN, "upgrade")
end

local function RenderGearList(snap)
    local gear = snap.gear
    win.leftSub:SetText("Upgrades: " .. #gear.rows)
    SetFooter(UpdatedText(snap))
    win.moneyHead:Hide()
    win.moneyTotal:Hide()

    local y, n = 0, 0
    for _, data in ipairs(gear.rows) do
        n = n + 1
        local row = GetRow(n)
        row.data = data
        row.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local h = data.holders[1]
        local label = LOF.ColorizeName(data.name, data.quality)
        if h then
            label = label .. GREY .. "  (" .. FirstName(h.name)
                .. (#data.holders > 1 and (" +" .. (#data.holders - 1)) or "") .. ")|r"
        end
        row.name:SetText(label)
        row.source:SetText("")
        row.loc:SetText(h and (#data.holders > 1 and "Multi" or (LOCATION_LABEL[h.location] or "")) or "")
        local t = data.shown
        local who = ClassColored(FirstName(t.name), t.class) .. " " .. GainText(t)
        if #data.targets > 1 and snap.isAll then who = who .. GREY .. " +" .. (#data.targets - 1) .. "|r" end
        row.value:SetText(who)
        row.sel:SetShown(gear.selected ~= nil and gear.selected.key == data.key)
        PlaceRow(row, y)
        y = y - ROW_H
    end

    if #gear.rows == 0 then
        local text
        if gear.advisorOff then
            text = "The Upgrade Advisor is off (Settings), so LOF does not compare gear."
        elseif gear.pending > 0 then
            text = "Loading item data..."
        else
            text = "No gear upgrades for your characters in bags, bank or mail."
        end
        win.empty:SetText(text)
        win.empty:Show()
        y = y - (win.empty:GetStringHeight() + 10)
    else
        win.empty:Hide()
    end

    for i = n + 1, #win.rows do
        win.rows[i]:Hide()
        win.rows[i].data = nil
    end
    win.content:SetHeight(math.max(10, -y))
end

local function GetGearTarget(i)
    local g = win.gearTargets[i]
    if g then return g end
    g = {}
    g.main = Text(win.right)
    g.main:SetWordWrap(false)
    g.sub = Text(win.right)
    g.sub:SetWordWrap(false)
    g.btn = Kit.CreateButton(win.right, "Ignore", 56)
    g.btn:SetHeight(18)
    g.btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Ignore for " .. tostring(self.charName))
        GameTooltip:AddLine("LOF will not suggest this item for this character again.", 1, 1, 1, true)
        GameTooltip:AddLine("Manage with /lof ignored.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    g.btn:SetScript("OnLeave", Kit.HideTooltip)
    g.btn:SetScript("OnClick", function(self)
        Resolver.Upgrade.IgnoreFor(self.itemID, self.itemName, self.charName)
        view.selectedKey = nil
        UI.RefreshHoldingsWindow()
    end)
    win.gearTargets[i] = g
    return g
end

local function HideGearTargets(from)
    for i = from, #win.gearTargets do
        local g = win.gearTargets[i]
        g.main:Hide(); g.sub:Hide(); g.btn:Hide()
    end
end

local function RenderGearAnalysis(snap)
    local d = snap.gear.selected
    win.cardHover.data = d
    SetLines(win.valueLines, win.valueHead, {})
    if not d then
        if win.cmpBox then win.cmpBox:Hide() end   -- v0.9.4
        win.cardIcon:SetTexture(nil)
        win.cardBorder:Hide()
        win.cardName:SetText(GREY .. "Select an item|r")
        win.cardSub:SetText("")
        win.valueHead:SetText("")
        win.holdHead:Hide()
        SetLines(win.holdLines, win.holdHead, {})
        HideGearTargets(1)
        return
    end
    win.cardIcon:SetTexture(d.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    win.cardBorder:SetVertexColor(Kit.GetQualityRGB(d.quality))
    win.cardBorder:Show()
    win.cardName:SetText(LOF.ColorizeName(d.name, d.quality))
    win.cardSub:SetText(GREY .. "Bind on Equip   |   can be given to another character|r")
    win.valueHead:SetText(ORANGE .. "Upgrade for|r")

    local prev = win.valueHead
    for i, t in ipairs(d.targets) do
        local g = GetGearTarget(i)
        local line = ClassColored(t.name, t.class) .. "  " .. GainText(t)
        if t.tooLow then line = line .. GOLD .. "  at level " .. tostring(t.needLevel) .. "|r" end
        if t.isHolder then line = line .. GREY .. "  (holds it)|r" end
        g.main:ClearAllPoints()
        g.main:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -6 or -8)
        g.main:SetPoint("RIGHT", win.right, "RIGHT", -74, 0)
        g.main:SetText(line)
        g.main:Show()

        local spec = SpecText({ source = t.source, basis = t.basis })
        local sub = spec and (spec .. GREY .. "  -  |r") or ""
        if t.replacesLink then
            sub = sub .. GREY .. "replaces|r " .. t.replacesLink
            if t.replacesOffLink then sub = sub .. " + " .. t.replacesOffLink end
        else
            sub = sub .. GREY .. "nothing equipped there|r"
        end
        if (t.gearAgeDays or 0) >= 1 then
            sub = sub .. GREY .. "   gear read " .. t.gearAgeDays .. (t.gearAgeDays == 1 and " day ago|r" or " days ago|r")
        end
        g.sub:ClearAllPoints()
        g.sub:SetPoint("TOPLEFT", g.main, "BOTTOMLEFT", 10, -3)
        g.sub:SetPoint("RIGHT", win.right, "RIGHT", -12, 0)
        g.sub:SetText(sub)
        g.sub:Show()

        g.btn:ClearAllPoints()
        g.btn:SetPoint("RIGHT", win.right, "RIGHT", -12, 0)
        g.btn:SetPoint("TOP", g.main, "TOP", 0, 3)
        g.btn.itemID, g.btn.itemName, g.btn.charName = d.itemID, d.name, t.name
        g.btn:Show()

        prev = g.main
        -- next block below the sub line
        prev = g.sub
    end
    HideGearTargets(#d.targets + 1)

    -- v0.9.4: the full comparison for the top character (UI.RenderComparison,
    -- the same table as the Upgrade and swap popups)
    local box = win.cmpBox
    if not box then
        box = CreateFrame("Frame", nil, win.right)
        box.content = box
        box.innerWidth = WIN_W - LEFT_W - 28 - 24
        box:SetWidth(box.innerWidth)
        win.cmpBox = box
    end
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", -10, -10)
    local h = -(UI.RenderComparison(box, 0, 0, d.comparison, { compared = true }) or 0)
    box:SetHeight(math.max(1, h))
    box:SetShown(d.comparison ~= nil)
    if d.comparison then prev = box end

    win.holdHead:ClearAllPoints()
    win.holdHead:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", d.comparison and 0 or -10, -16)
    win.holdHead:SetText("Where")
    win.holdHead:Show()
    local hl = {}
    for _, h in ipairs(d.holders) do
        local name = ClassColored(h.name, h.class)
        if h.isCurrent then name = name .. GREY .. " (current)|r" end
        local line = name .. "  -  " .. tostring(h.count) .. " " .. string.lower(LOCATION_LABEL[h.location] or h.location)
        if h.updated then line = line .. GREY .. "  (read " .. Kit.WhenText(h.updated) .. ")|r" end
        hl[#hl + 1] = line
    end
    SetLines(win.holdLines, win.holdHead, hl)
end

function UI.RefreshHoldingsWindow()
    if not win or not win:IsShown() then return end
    if not Resolver.Holdings then return end
    local snap = Resolver.Holdings.GetWindowSnapshot(view)
    if snap.gearMode then
        view.selectedKey = snap.gear.selected and snap.gear.selected.key or nil
        RenderHeader(snap)
        RenderProfile(snap)
        RenderGearList(snap)
        RenderGearAnalysis(snap)
        return
    end
    if snap.selectedMoney then
        view.selectedKey = snap.selectedMoney.key
    elseif snap.selected then
        view.selectedKey = snap.selected.key
    end
    HideGearTargets(1)
    if win.cmpBox then win.cmpBox:Hide() end   -- v0.9.4: only in Gear for alts
    win.holdHead:SetText("Holdings by Character")
    RenderHeader(snap)
    RenderProfile(snap)
    RenderList(snap)
    RenderAnalysis(snap)
end

-- v0.8.4: combat hide / restore (Capture decides when)
function UI.HideHoldingsForCombat()
    if not (win and win:IsShown()) then return false end
    win:Hide()
    return true
end

function UI.RestoreHoldingsAfterCombat()
    if not win or win:IsShown() then return end
    win:Show()
    UI.RefreshHoldingsWindow()
end

function UI.ToggleHoldingsWindow()
    if not win then BuildWindow() end
    if win:IsShown() then
        win:Hide()
        return
    end
    view.character = "current"
    view.selectedKey = nil
    Kit.ApplyAutoScale(win, "holdings", "CENTER", 0, 40)
    win:Show()
    UI.RefreshHoldingsWindow()
end
