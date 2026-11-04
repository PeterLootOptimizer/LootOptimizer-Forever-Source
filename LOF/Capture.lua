-- =============================================================
-- LOF (LootOptimizer Forever) -- Capture.lua
-- Event wiring, loot-window bookkeeping and the swap session flow.
-- Decisions are delegated to LOF.Resolver; rendering to LOF.UI.
-- =============================================================
--
-- Changelog
-- ---------
-- v1.9.13: E10 fix. QUEST_COMPLETE tells the resolver the reward window
--   is open (Resolver.QuestRewardShown); QUEST_FINISHED already clears it.
-- v1.9.12: E7 probe removed (Peter's test: free API, empty slots and
--   LOF's count were equal after every delete).
-- v1.9.11: E7 fix, second try. The quest Make room counts again on
--   BAG_UPDATE_DELAYED (fallback 2 s) instead of after 0.15 s, which was
--   still too early. A temporary probe printed the free-slot API vs empty slots.
-- v1.9.10: E7 fix. After a delete in quest Make room LOF waits
--   LOF.SWAP_DELAY before it counts the free slots and shows the next
--   item; the count was one delete behind (found in Peter's test video).
-- v1.9.9: E7 quest reward room. QUEST_PROGRESS -> Resolver.RememberQuest
--   TurnIn; QUEST_COMPLETE -> if Resolver.GetQuestRewardRoom().short > 0,
--   Make room opens in quest mode (StartMakeRoomNow(true, true)); after
--   each delete LOF checks again and stops with the resolver's "Enough
--   room" notice; QUEST_FINISHED forgets and closes a quest Make room.
--   "Inventory is full" with the reward window open uses quest mode too.
-- v1.9.8: A low_value decision with a notice (the "Not worth a swap" popup
--   is switched off) shows that line via UI.ShowNotice instead of the
--   popup, once per loot window, and ends the session.
-- v1.9.7: GET_ITEM_INFO_RECEIVED passes itemID and success on to
--   Resolver.Upgrade.OnItemDataReceived (release audit G1).
-- v1.9.6: E4 fix (ResolverUpgrade 0.13.4). GET_ITEM_INFO_RECEIVED also
--   tells Resolver.Upgrade.OnItemDataReceived (pending comparisons are
--   recomputed); after PLAYER_LOGIN + ALT_GEAR_PRELOAD_DELAY Capture calls
--   Resolver.Upgrade.PreloadAltGear (alts' worn gear loaded before loot).
-- v1.9.5: LOOT LEFT BEHIND: the chat line moved to UI.ShowLeftBehindPopup
--   (audit A5: Capture held a colour literal). Capture only calls it.
-- v1.9.4: A failed swap check prints the resolver's player text instead
--   of the internal code (audit A3, Resolver 0.10.3).
-- v1.9.3: /lof upgrade scan = the Scan button (audit A2). The old debug
--   mode "verbose" printed raw verdict codes (NOT_BETTER, UPGRADE_CLEAR)
--   per gear item; it is gone, with its counter. Modes left: "button"
--   (default: popups or one "no upgrades" line) and "silent".
-- v1.9.2: Blocked-call probe removed (since v0.1.1; a player saw
--   "LOF: ADDON_ACTION_BLOCKED: addon=MapUtils ..." and blamed LOF). It
--   printed every addon's blocked calls under the LOF name; lastBlocked
--   was never read and the swap handles a blocked delete itself.
--   Gone: ReportBlocked, both event registrations, lastBlocked,
--   quietUntil and Capture.SuppressBlockedReport (+ its two calls).
-- v1.9.1: Moving and combat close an open confirmation (Kit.HideConfirm;
--   Peter: the Remove from LOF question stayed open in Holdings while
--   walking). Nothing is removed then.
-- v1.9.0: One Make room flow (Peter: the automatic popup could not
--   browse). "Inventory is full" outside the loot window now starts Make
--   room now with bagsFull (Capture.StartMakeRoomNow(true), round from
--   Resolver.NewMakeRoomRound): same popup, Delete / Previous / Next /
--   Cancel, starting at the lowest quality present; quiet when it cannot
--   open (session, combat, loot window, free slot) and a chat line when
--   nothing is safe to delete. Capture.ShowMakeRoom and session mode
--   "room" are gone; setting and 10 s pause unchanged.
-- v1.8.0: Previous / Next in the Swap popup (Resolver 0.8.0). The skip
--   list (swapSkip: keys + order, Resolver.GetSlotKey) lives as long as
--   the loot window: a new LOOT_OPENED starts an empty one, it stays
--   after a swap for the next loot item. Capture.SwapNext() skips the
--   bag item shown (not a whitelist), Capture.SwapPrevious() brings back
--   the last one skipped. Both only while the popup waits for the player
--   (not busy). WL and the swap itself pass the same skip list to the
--   resolver; when the resolver dropped all skips (skipReset) the list
--   is emptied.
-- v1.7.8: Guide (LOF 1.6.0). After login (PLAYER_LOGIN + 6 s) Capture
--   asks Resolver.GetGuideTrigger(); when it names a tab and the moment
--   is quiet (no combat, no swap / make room session, no loot window,
--   no Upgrade popup) the Guide opens by itself and the version is
--   marked seen; otherwise it tries again (every 5 s, at most 2
--   minutes). Moving closes a Guide the
--   player opened himself; combat hides it and an automatic one comes
--   back after the fight (LOF.db.combatHidden.guide).
-- v1.7.7: Make room now in rounds per quality (Resolver 0.6.8):
--   session.room = { quality, skipped, seen, order }. After the last
--   item of a quality the popup asks "Continue with <next>?" (Yes:
--   Capture.MakeRoomNowContinue, Stop). Previous
--   (Capture.MakeRoomNowPrevious) brings back the last item skipped
--   with Next in this quality. Nothing left: a short end popup (OK).
-- v1.7.6: Make room now (LOF 1.6.0, Reddit request). Capture
--   .StartMakeRoomNow() (Room button, /lof room): the purple popup on
--   the player's own initiative, also with free slots and with the
--   Make room setting off. Delete (same direct delete as Make room,
--   one item per click) shows the next item; Next skips this one
--   (session.roomSkipped); Cancel stops. The deleted / skipped item
--   is never shown again in this round. Not with a loot window, a
--   swap or in combat. Looting stops it (Swap takes over).
-- v1.7.5: Settings window (UISettings, LOF 1.6.0): moving and combat
--   close it (UI.CloseSettingsWindow). It does not come back after
--   combat: it is not remembered in LOF.db.combatHidden.
-- v1.7.4: Upgrade popups once per item per session, none while fishing
--   (ResolverUpgrade 0.12.0). Queue entries carry `force` (Scan button,
--   level-up scan, popup parked for combat); a popup shown marks the
--   item as advised.
-- v1.7.3: Combat also closes an open Upgrade popup (Peter): the item
--   goes back to the front of the upgrade queue and the same popup
--   returns after combat (PLAYER_REGEN_ENABLED already processes the
--   queue). Nothing is lost.
-- v1.7.2: Combat also closes the swap popup, "Not worth a swap" and the
--   Make room popup (Peter): the session stops when it is only waiting
--   for the player (awaitingUser, not busy). A swap or delete already
--   running is left to finish. LOOT LEFT BEHIND and the Upgrade popup
--   are not touched. Nothing comes back after combat: looting again
--   starts LOF again.
-- v1.7.1: Tabs and combat (Peter):
--   - PLAYER_STARTED_MOVING: the panel leaves Settings / Info for the
--     LOF tab (UI.LeaveInfoPagesOnMove).
--   - PLAYER_REGEN_DISABLED (combat starts): LOF minimizes the dashboard
--     and hides Holdings and Send to alts when open, and remembers what
--     IT hid (LOF.db.combatHidden). PLAYER_REGEN_ENABLED (combat ends)
--     brings back only that: what you closed yourself stays closed, and
--     a dashboard you opened again during combat is left alone. After a
--     reload outside combat the dashboard comes back too. Popups (swap,
--     make room, upgrade) are not touched.
-- v1.7.0: Make room. "Inventory is full" while no loot window is open
--   (conjure, craft, quest reward, vendor, mail) offers the purple
--   Make room popup with the cheapest safe bag item
--   (Resolver.BuildMakeRoomDecision): Delete (same direct delete as
--   Swap: ClearCursor -> Pickup -> DeleteCursorItem in the click; when
--   Blizzard asks for confirmation LOF waits for the dialog), WL (next
--   candidate), Cancel. At most once per 10 s, never while another LOF
--   popup or session is open; a loot window closes it (Swap takes
--   over). Setting: Resolver.IsMakeRoomEnabled.
-- v1.6.1: Send to alts on the Inbox tab: when the resolver's action
--   says switchTab, LOF first opens the Send Mail tab (Blizzard's
--   MailFrameTab_OnClick, else a click on MailFrameTab2); when that
--   fails nothing happens (code NO_SEND_TAB). Send Mail shown / hidden
--   (also when the player switches tabs) refreshes the window.
-- v1.6.0: Send to alts. Capture.AttachUpgradeToMail(bag, slot, link,
--   altName) asks Resolver.Upgrade.GetMailAction first and only acts on
--   ATTACH: fills in the recipient when needed and puts the item in the
--   free attachment slot (C_Container.PickupContainerItem +
--   ClickSendMailItemButton; measured with LOFProbe 0.2.0 on Forever).
--   Nothing is ever sent: the player presses Send. Returns the action,
--   the UI turns its code into text. MAIL_SHOW opens the window when
--   Resolver.Upgrade.ShouldAutoOpenAltMail(); MAIL_CLOSED lets the UI
--   close it again (only when it opened by itself);
--   MAIL_SEND_INFO_UPDATE (attachments changed) refreshes it.
-- v1.5.3: Alt upgrades (ResolverUpgrade 0.7.0): /lof upgrade scan
--   adds "(upgrade for alt: Name +x.x%)" to the chat line. The silent
--   scan after a level-up skips popups that are only for alts (the
--   level-up is yours, not theirs).
-- v1.5.2: Equip now works like dragging (measured with Peter): pick
--   the item up from its bag slot and drop it on the target slot
--   (PickupContainerItem + EquipCursorItem). While the item hangs on
--   the cursor Forever keeps the "will bind" dialog open. Falls back
--   to EquipItemByName when the item is no longer in the bags. When
--   the item did not end up equipped (e.g. Cancel in the dialog) the
--   chat line is a neutral "<item> not equipped."
-- v1.5.1: Bug (Peter, BoE wand): Equip did nothing for Bind-on-Equip
--   gear. LOF called ClearCursor() before EquipItemByName; the cursor
--   event of that arrives a moment later and Forever's own UI
--   (Blizzard_Game/Camelot, HandleCursorChanged) then closes the
--   "will bind" dialog it had just shown. ClearCursor() now only runs
--   when something is actually on the cursor.
-- v1.5.0: Holdings step 4 (AH): when the auction house opens, LOF
--   asks the server for the own auctions (QueryOwnedAuctions); every
--   OWNED_AUCTIONS_UPDATED while open leads to a bundled read. Also
--   asked again after posting or cancelling an auction. Reading waits
--   for the server's answer, so an empty list is never stored early.
-- v1.4.0: Holdings step 3 (mailbox): the bundled scan also reads the
--   inbox while the mailbox is open (MAIL_SHOW, MAIL_INBOX_UPDATE).
--   Mail to an own alt: SendMail is hooked to remember the attachments
--   and money; on MAIL_SEND_SUCCESS they are booked in that alt's mail
--   (Resolver.Holdings.RecordSentMail). A failed send books nothing.
-- v1.3.2: Bug (Peter): the scan at PLAYER_LOGOUT read an already torn
--   down character (no bags, gear or gold) and stored that over the
--   good data. Removed: every change is stored within a second anyway.
-- v1.3.1: Holdings step 2: the bundled scan reads the whole character
--   (bags, equipped, gold, professions: Resolver.Holdings.ScanCharacter)
--   and also runs after equipment and skill changes; gold is stored on
--   every PLAYER_MONEY.
-- v1.3.0: Holdings phase 1 (LOF 1.1.2). Capture only decides WHEN to
--   read; Resolver.Holdings reads and stores:
--   - bags: 2s after entering the world, 1s after bag changes
--     (bundled), and once more at logout;
--   - bank: 0.3s after the bank opens and after every bag/bank change
--     while it is open (a closed bank cannot be read).
-- v1.2.1: Upgrade scan has modes: "verbose" (/lof upgrade scan),
--   "button" (Scan button: popups or one "No gear upgrades" line) and
--   "silent" (automatic after PLAYER_LEVEL_UP, so items that were too
--   high level are suggested once they can be worn). No duplicate
--   queue entries.
-- v1.2.0: Bug (found by Nick): moving right after Swap closed the loot
--   window before LOF looted, so the bag item was destroyed but the
--   loot stayed on the corpse. Two fixes:
--   1. The loot is now requested in the same click, right after the
--      delete (the server handles both in order). The old delayed loot
--      stays as a second attempt. Tested on Forever: delete + loot land
--      together, running away right after the click is fine.
--   Chat: one line "Swapped X for Y." once the bag item is gone and the
--   loot is in the bags (replaces "Destroyed X", which was skipped when
--   the loot window closed first).
--   2. Safety net "loot left behind": if the loot window closes after
--      the delete but before the loot arrived, LOF remembers the item
--      and its corpse (loot source GUID), shows a chat line and the red
--      "LOOT LEFT BEHIND" popup, and loots the item automatically when
--      that corpse is opened again. Expires after 3 minutes; cleared
--      when the item reaches the bags.
-- v1.1.3: Bug: the destroy instructions flashed briefly after a
--   successful one-click swap. 0.2s after the delete the bag slot can
--   still be locked while the server processes it, which counted as
--   "pending". Now a pending "locked" state is watched silently; the
--   instructions only appear when the player must act (item on the
--   cursor or Blizzard's Destroy? dialog open).
-- v1.1.2: Bug: an item looted via Swap did not appear in Recent Loot
--   when it arrived in the bags later than 0.3s after the loot window
--   closed (destroy + loot = two server steps; the pending list was
--   dropped after one check). Pending loot now stays active up to 5s
--   after LOOT_CLOSED: every BAG_UPDATE_DELAYED commits what arrived;
--   the list is closed when everything arrived, after 5s, or when a new
--   loot window opens (old list is committed first). Counts per item
--   are capped, so nothing is recorded twice.
-- v1.1.1: Registers with Auctionator's official API v1
--   RegisterForDBUpdate at PLAYER_LOGIN (pcall; nothing happens
--   without Auctionator). Every "new prices stored" callback records
--   the time (Resolver.Value.RecordPriceUpdate) and refreshes, again
--   3s later. Closing the AH only re-reads values, it no longer counts
--   as a visit.
-- v1.1.0: Auctionator integration (LOF 1.1.0). AUCTION_HOUSE_CLOSED
--   records the AH visit (Resolver.Value.RecordAHVisit), drops cached
--   values and refreshes; once more 3s later, because Auctionator may
--   still be processing a scan when the window closes. Values are also
--   re-read at PLAYER_ENTERING_WORLD (Auctionator's database may not
--   be ready at the first bag scan).
-- v1.0.0: First public release. Diagnostic delete probe removed
--   (Capture.ProbeDestroy); blocked-call reporting kept for bug reports.
-- v0.5.1: Swap uses the exact probe sequence (ClearCursor -> Pickup ->
--   DeleteCursorItem, nothing in between); cursor check and hiding the
--   popup moved after the delete. v0.5.0 got blocked on an item the
--   probe could delete.
-- v0.5.0: One-click swap with safety net. Swap now calls DeleteCursorItem
--   straight from the click (probe proved one item per click works on
--   Forever, also with the loot window open). 0.2s later: destroyed ->
--   loot + next decision; still pending (blocked / confirm dialog) ->
--   phase 2 instructions as before; returned -> stop. Blocked report is
--   silenced for that attempt.
-- v0.4.0: Delete probe (Capture.ProbeDestroy): one DeleteCursorItem per
--   click, Dejunk-style, reporting DELETED / BLOCKED / CONFIRM DIALOG
--   with item quality and loot-window state. Diagnostic only.
-- v0.3.2: Upgrade trigger is now a bag diff (Resolver.Upgrade.FindNewGear)
--   after BAG_UPDATE_DELAYED instead of the loot path: quest rewards,
--   vendor, mail and trades trigger it too. Excluded: items taken off
--   in the last 5s, changes while the bank is open, login/reload
--   (5s baseline window after PLAYER_ENTERING_WORLD).
-- v0.3.1: Capture.CancelUpgrade (decide later, not ignored).
-- v0.3.0: Upgrade Advisor flow. Looted gear is queued and evaluated by
--   Resolver.Upgrade after the loot window closes and out of combat;
--   one popup at a time. Equip (EquipItemByName from the click) with a
--   2s result check (by itemID) + PLAYER_EQUIPMENT_CHANGED, fallback instruction
--   when it did not work. Ignore stores the itemID per character.
--   Capture.ScanBagsForUpgrades for /lof upgrade scan.
-- v0.2.1: Info popup instead of a chat line when the loot is not worth
--   a swap or nothing may be swapped; once per loot window. OK closes
--   it, "Swap anyway" runs the normal two-phase swap.
-- v0.2.0: Two-phase swap. Probe confirmed ADDON_ACTION_BLOCKED on
--   DeleteCursorItem for addons on Forever. Swap now puts the bag item
--   on the cursor and shows instructions; the player destroys it via
--   Blizzard's dialog. A 0.1s ticker (Resolver.GetDestroyState) then
--   loots the swap item, or stops on put-back / 30s timeout / loot
--   window closed. StopSession never leaves an item on the cursor.
--   Blocked-call probe kept to verify LootSlot from a timer.
-- v0.1.1: Bug: on Forever the delete silently failed, LootSlot hit a
--   full bag and the same decision came back (loop). Now the bag slot
--   (and the cursor) is checked 0.2s after the delete; an item still
--   on the cursor counts as NOT deleted. If the item is still there the
--   cursor is cleared and the session stops. Probe output on failure
--   plus ADDON_ACTION_BLOCKED/FORBIDDEN reporting (all addons, with
--   addon name and function, since the blame on Forever is unclear).
-- v0.1.0: Initial version (LOF Lite).
--   - Bag-full detection on UI_ERROR_MESSAGE via the ERR_INV_FULL
--     text (the numeric error type differs between clients).
--   - Swap flow ported from LootOptimizer-Classic 1.8.1, with one
--     safety change: the bag item is deleted from the button click,
--     the LootSlot follows 0.2s later, and the next decision is only
--     built after that. Prevents a second delete when the server has
--     not freed the slot yet.
--   - Resolver.ValidateSwap is checked right before every delete.
--   - Recent Loot: loot is recorded only once it really arrived in
--     the bags (baseline/gain logic from LootCapture.lua).
-- =============================================================

local LOF = LOF
LOF.VERSION_CAPTURE = "1.9.13"

local Capture = {}
LOF.Capture = Capture

local Resolver = LOF.Resolver

local function Refresh()
    if LOF.RequestRefresh then LOF.RequestRefresh() end
end

-- -------------------------------------------------------------
-- Pending loot records (for Recent Loot)
-- -------------------------------------------------------------
local pendingLoot = nil

local function BuildPendingLoot()
    pendingLoot = {}
    for lootSlot = 1, (GetNumLootItems() or 0) do
        local info = Resolver.ResolveLootSlot(lootSlot)
        if info and info.itemID then
            pendingLoot[#pendingLoot + 1] = {
                itemID = info.itemID, link = info.link,
                count = info.count, committed = 0,
            }
        end
    end
end

-- Records whatever part of the pending loot has actually arrived.
-- Returns the number of records still (partly) outstanding.
local function CommitPendingLoot()
    if not pendingLoot or #pendingLoot == 0 then return 0 end

    local allocatedByItem = {}
    local outstanding = 0
    local recorded = false

    for _, rec in ipairs(pendingLoot) do
        local gained = math.max(0, Resolver.CountItemInBags(rec.itemID) - Resolver.GetLootBaseline(rec.itemID))
        local allocated = allocatedByItem[rec.itemID] or 0
        local mine = math.min(rec.count, math.max(0, gained - allocated))
        allocatedByItem[rec.itemID] = allocated + mine

        local newCount = mine - rec.committed
        if newCount > 0 then
            Resolver.RecordLoot(rec.link, newCount)
            rec.committed = mine
            recorded = true
        end
        if rec.committed < rec.count then
            outstanding = outstanding + 1
        end
    end

    if recorded then Refresh() end
    return outstanding
end

-- v1.1.2: after LOOT_CLOSED the pending list stays active for a while,
-- because a swapped item can reach the bags later than the window
-- closes. Closed when complete, after PENDING_GRACE, or on a new window.
local PENDING_GRACE = 5
local lootWindowOpen = false

local function FinishPendingLoot()
    CommitPendingLoot()
    pendingLoot = nil
    Resolver.ClearLootBaseline()
end

-- -------------------------------------------------------------
-- Swap session
-- -------------------------------------------------------------
-- Phase 1 ("decide"): popup with Swap / WL / Wait.
-- Phase 2 ("destroy"): the bag item hangs on the cursor and the
--   player destroys it via Blizzard's own dialog (addons may not call
--   DeleteCursorItem on Mainline). A ticker watches the outcome.
local DESTROY_POLL_INTERVAL = 0.1
local DESTROY_TIMEOUT = 30
local DIRECT_CHECK_DELAY = 0.2

local session = {
    active = false,
    awaitingUser = false,
    decision = nil,
    messageShown = false,
    busy = false,       -- between pickup and next decision
    phase = nil,        -- nil | "destroy"
    countBefore = 0,
    destroyStartedAt = 0,
}

local destroyTicker = nil


-- Increments per loot window (LOOT_OPENED), so a late LOOT_CLOSED
-- timer never clears the state of a newer window, and the info popup
-- shows only once per window.
local lootGeneration = 0
local infoShownForWindow = -1

-- v1.8.0: bag items skipped with Next, per loot window.
local swapSkip = { gen = -1, keys = {}, order = {} }

local function GetSwapSkip()
    if swapSkip.gen ~= lootGeneration then
        swapSkip = { gen = lootGeneration, keys = {}, order = {} }
    end
    return swapSkip
end

local function BuildSwapDecision()
    local skip = GetSwapSkip()
    local d = Resolver.BuildSwapDecision(skip)
    if d and d.skipReset then
        skip.keys, skip.order = {}, {}
    end
    return d
end

local function StopDestroyWatch()
    if destroyTicker then
        destroyTicker:Cancel()
        destroyTicker = nil
    end
end

function Capture.IsSessionActive()
    return session.active
end

function Capture.StopSession()
    StopDestroyWatch()
    -- Never leave the bag item hanging on the cursor.
    if (session.phase == "destroy" or session.phase == "direct") and CursorHasItem() then
        ClearCursor()
    end
    session.phase = nil
    session.mode = nil   -- v1.7.0
    session.room = nil   -- v1.7.6 / v1.7.7
    session.questRecount = nil   -- v1.9.11 (E7)
    session.active = false
    session.awaitingUser = false
    session.decision = nil
    session.busy = false
    session.swapInfo = nil
    if LOF.UI and LOF.UI.HideSwapPopup then
        LOF.UI.HideSwapPopup()
    end
end

local function ShowOrStop(decision)
    session.decision = decision
    if decision and decision.shouldShowPopup then
        session.awaitingUser = true
        LOF.UI.ShowSwapPopup(decision)
        return
    end
    -- Not worth a swap / nothing swappable: info popup, once per window.
    if decision and decision.infoKind and decision.lootItem
        and infoShownForWindow ~= lootGeneration then
        infoShownForWindow = lootGeneration
        if decision.notice then   -- v1.9.8: popup off (Resolver decided)
            if LOF.UI.ShowNotice then LOF.UI.ShowNotice(decision.notice) end
            Capture.StopSession()
            return
        end
        session.awaitingUser = true
        LOF.UI.ShowInfoPopup(decision)
        return
    end
    if decision and decision.message and not session.messageShown then
        LOF.Print(decision.message)
        session.messageShown = true
    end
    Capture.StopSession()
end

function Capture.StartSession()
    if session.awaitingUser or session.busy then return end
    session.active = true
    session.messageShown = false
    ShowOrStop(BuildSwapDecision())
end

local function ContinueSession()
    if not session.active then return end
    session.busy = false
    session.awaitingUser = false
    ShowOrStop(BuildSwapDecision())
end

-- The bag item is gone: loot the swap item into the freed slot and
-- move on to the next decision.
local function OnBagItemDestroyed(decision)
    local bagItem, lootItem = decision.bagItem, decision.lootItem
    LOF.UI.HideSwapPopup()
    -- Second loot attempt (the first one is sent from the click).
    if (GetNumLootItems() or 0) > 0 and LootSlotHasItem(lootItem.lootSlot) then
        LootSlot(lootItem.lootSlot)
    end
    C_Timer.After(LOF.SWAP_DELAY, ContinueSession)
end

-- Polls until the item on the cursor is destroyed or put back.
local function OnDestroyTick()
    local decision = session.decision
    if session.phase ~= "destroy" or not decision then
        StopDestroyWatch()
        return
    end

    local state, why = Resolver.GetDestroyState(decision.bagItem, session.countBefore)
    if state == "pending" then
        -- Instructions only when the player has to act.
        if why ~= "locked" and not session.instructionsShown then
            session.instructionsShown = true
            LOF.UI.ShowDestroyInstructions(decision)
        end
        if GetTime() - session.destroyStartedAt > DESTROY_TIMEOUT then
            LOF.Print("No destroy within " .. DESTROY_TIMEOUT .. "s, item put back.")
            Capture.StopSession()
        end
        return
    end

    StopDestroyWatch()
    session.phase = nil
    Resolver.InvalidateCache()

    if state == "returned" then
        LOF.Print("Swap cancelled, " .. tostring(decision.bagItem.name) .. " kept.")
        Capture.StopSession()
        return
    end

    OnBagItemDestroyed(decision)
end

-- Called from the Swap button OnClick (hardware event).
function Capture.ExecuteSwap()
    local decision = session.decision
    local ok, _, text = Resolver.ValidateSwap(decision)
    if not ok then
        LOF.Print(text)   -- v1.9.4: resolver text, no internal code
        ContinueSession()
        return
    end

    session.awaitingUser = false
    session.busy = true

    local bagItem, lootItem = decision.bagItem, decision.lootItem
    local countBefore = Resolver.CountItemInBags(bagItem.itemID)
    -- v1.2.0: everything the "loot left behind" safety net needs.
    session.swapInfo = {
        lootItem       = lootItem,
        lootCountBefore = Resolver.CountItemInBags(lootItem.itemID),
        sourceGUID     = Resolver.GetLootSourceGUID(lootItem.lootSlot),
        bagItemID      = bagItem.itemID,
        bagCount       = bagItem.count,
        bagCountBefore = countBefore,
        clickedAt      = GetTime(),
        bagItem        = bagItem,
    }
    Capture.TrackSwapResult(session.swapInfo)

    -- v0.5.1: EXACTLY the probe sequence: ClearCursor -> Pickup ->
    -- DeleteCursorItem with nothing in between (v0.5.0 checked the
    -- cursor and hid the popup in between and got blocked, while the
    -- probe with the same item succeeded). All other work happens
    -- before ClearCursor or after DeleteCursorItem.
    session.countBefore = countBefore
    session.phase = "direct"

    ClearCursor()
    LOF.PickupContainerItem(bagItem.bag, bagItem.slot)
    DeleteCursorItem()

    -- v1.2.0: request the loot in the same click, right after the delete
    -- (the server handles both in order), so running away right after
    -- the click no longer leaves the loot behind.
    if LootSlotHasItem(lootItem.lootSlot) then
        LootSlot(lootItem.lootSlot)
    end

    LOF.UI.HideSwapPopup()

    C_Timer.After(DIRECT_CHECK_DELAY, function()
        if not session.active or session.decision ~= decision then return end
        local state, why = Resolver.GetDestroyState(bagItem, countBefore)
        session.phase = nil
        if state == "destroyed" then
            Resolver.InvalidateCache()
            OnBagItemDestroyed(decision)
        elseif state == "pending" then
            -- Blocked or Blizzard asks for confirmation (cursor / dialog):
            -- phase 2 with instructions. Only locked: the server is still
            -- processing the delete, keep watching without a window.
            session.instructionsShown = false
            if why == "cursor" then
                LOF.Print("Direct destroy not allowed for this item, please confirm manually.")
            end
            session.phase = "destroy"
            session.destroyStartedAt = GetTime()
            if why ~= "locked" then
                session.instructionsShown = true
                LOF.UI.ShowDestroyInstructions(decision)
            end
            StopDestroyWatch()
            destroyTicker = C_Timer.NewTicker(DESTROY_POLL_INTERVAL, OnDestroyTick)
        else
            LOF.Print("Swap cancelled, " .. tostring(bagItem.name) .. " kept.")
            Capture.StopSession()
        end
    end)
end

-- Called from the WL button OnClick. Shift = permanent.
function Capture.WhitelistBagItem(isPersistent)
    local decision = session.decision
    if decision and decision.bagItem then
        Resolver.AddToWhitelist(decision.bagItem.name, isPersistent)
        Refresh()
    end
    if session.mode == "roomnow" then   -- v1.7.6
        Resolver.InvalidateCache()
        Capture.ShowMakeRoomNow()
        return
    end
    ContinueSession()
end

function Capture.CancelSession()
    Capture.StopSession()
end

-- v1.8.0: only in the Swap popup, while it waits for the player.
local function CanBrowseSwap()
    local d = session.decision
    return session.active and session.mode == nil and session.awaitingUser
        and not session.busy and d ~= nil and d.shouldShowPopup and d.bagItem ~= nil
end

-- Next: keep this bag item for now (no whitelist), show the next one.
function Capture.SwapNext()
    if not CanBrowseSwap() or not session.decision.canNext then return end
    local skip = GetSwapSkip()
    local key = Resolver.GetSlotKey(session.decision.bagItem)
    if not skip.keys[key] then
        skip.keys[key] = true
        table.insert(skip.order, key)
    end
    ContinueSession()
end

-- Previous: the last bag item skipped with Next again.
function Capture.SwapPrevious()
    if not CanBrowseSwap() then return end
    local skip = GetSwapSkip()
    if #skip.order == 0 then return end
    local key = table.remove(skip.order)
    skip.keys[key] = nil
    ContinueSession()
end

-- -------------------------------------------------------------
-- v1.7.0: Make room (bags full outside the loot window)
-- -------------------------------------------------------------
local MAKE_ROOM_COOLDOWN = 10
local makeRoomQuietUntil = 0
local makeRoomTicker = nil

local function StopMakeRoomWatch()
    if makeRoomTicker then
        makeRoomTicker:Cancel()
        makeRoomTicker = nil
    end
end

function Capture.OfferMakeRoom()
    if not Resolver.IsMakeRoomEnabled() then return end
    if session.active or session.awaitingUser or session.busy then return end
    if (GetNumLootItems() or 0) > 0 then return end
    local now = GetTime()
    if now < makeRoomQuietUntil then return end
    makeRoomQuietUntil = now + MAKE_ROOM_COOLDOWN
    C_Timer.After(0.2, function()
        if session.active or session.awaitingUser or session.busy then return end
        if (GetNumLootItems() or 0) > 0 then return end
        -- v1.9.9 (E7): reward window open and too few slots -> quest mode
        local q = Resolver.GetQuestRewardRoom and Resolver.GetQuestRewardRoom()
        Capture.StartMakeRoomNow(true, q ~= nil and q.short > 0)   -- v1.9.0: one Make room flow
    end)
end

local function IsRoomMode()   -- v1.9.0: there is one Make room mode
    return session.mode == "roomnow"
end

-- v1.7.6 / v1.7.7: Make room now - the next item of this round, a
-- question for the next quality, or the end.
local function RoomSkip(item)
    local room = session.room
    if not room or not item then return end
    local key = Resolver.GetSlotKey(item)
    if room.skipped[key] then return end
    room.skipped[key] = true
    room.order[room.quality] = room.order[room.quality] or {}
    table.insert(room.order[room.quality], key)
end

function Capture.ShowMakeRoomNow()
    local room = session.room
    if not room then return end
    local d = Resolver.BuildMakeRoomNowDecision(room)
    if not d then
        Capture.StopSession()
        return
    end
    session.active = true
    session.mode = "roomnow"
    session.decision = d
    session.awaitingUser = true
    session.busy = false
    if d.bagItem then
        room.seen[room.quality] = true
        local order = room.order[room.quality]
        d.canPrevious = order ~= nil and #order > 0
    end
    LOF.UI.ShowMakeRoomNowPopup(d)
end

-- bagsFull: opened by "Inventory is full" (OfferMakeRoom), quietly
-- skipped when not possible; otherwise the Room button / /lof room.
function Capture.StartMakeRoomNow(bagsFull, forQuest)
    if session.active or session.busy then
        if session.mode == "roomnow" then return end   -- already open
        if not bagsFull then LOF.Print("Finish the swap first.") end
        return
    end
    if InCombatLockdown() then
        if not bagsFull then LOF.Print("Not during combat.") end
        return
    end
    if (GetNumLootItems() or 0) > 0 then
        if not bagsFull then LOF.Print("Close the loot window first.") end
        return
    end
    Resolver.InvalidateCache()
    local room = Resolver.NewMakeRoomRound(bagsFull, forQuest)   -- v1.9.0 / v1.9.9
    if not room then return end   -- a slot is free after all
    if bagsFull then
        local d = Resolver.BuildMakeRoomNowDecision(room)
        if d and d.nothing then
            LOF.Print(d.message)
            return
        end
    end
    session.room = room
    Capture.ShowMakeRoomNow()
end

-- Next: keep this item, show the next one (or the question).
function Capture.MakeRoomNowNext()
    local d = session.decision
    if session.mode ~= "roomnow" or not d or not d.bagItem then return end
    RoomSkip(d.bagItem)
    Capture.ShowMakeRoomNow()
end

-- Previous: the last item skipped with Next in this quality again.
function Capture.MakeRoomNowPrevious()
    local room = session.room
    if session.mode ~= "roomnow" or not room then return end
    local order = room.order[room.quality]
    if not order or #order == 0 then return end
    local key = table.remove(order)
    room.skipped[key] = nil
    Capture.ShowMakeRoomNow()
end

-- Yes on "Continue with <quality>?"
function Capture.MakeRoomNowContinue()
    local d, room = session.decision, session.room
    if session.mode ~= "roomnow" or not room or not d or not d.ask then return end
    room.quality = d.nextQuality
    Capture.ShowMakeRoomNow()
end

-- v1.9.11 (E7): after a delete in quest mode, count again once the bags
-- have settled; stop with the "Enough room" notice or show the next item.
local QUEST_RECOUNT_FALLBACK = 2
function Capture.QuestRoomRecount()
    local room = session.questRecount
    session.questRecount = nil
    if not room or not IsRoomMode() or session.room ~= room then return end
    local q = Resolver.GetQuestRewardRoom()
    if not q or q.short <= 0 then
        if q and LOF.UI.ShowNotice then LOF.UI.ShowNotice(q.doneText) end
        Capture.StopSession()
        Refresh()
        return
    end
    Refresh()
    Capture.ShowMakeRoomNow()
end

local function MakeRoomDone(bagItem, state)
    StopMakeRoomWatch()
    if not IsRoomMode() then return end   -- Swap took over meanwhile
    session.phase = nil
    Resolver.InvalidateCache()
    -- v1.7.6 / v1.9.0: on to the next item (one Make room flow)
    if state == "destroyed" then
        local text = LOF.ColorizeName(bagItem.name, bagItem.quality) .. " deleted."
        local forQuest = session.room and session.room.forQuest
        if session.room and session.room.bagsFull and not forQuest then
            text = text .. " One slot free: try again (cast, craft, quest reward ...)."
        end
        LOF.Print(text)
        -- v1.9.9 (E7): quest mode stops as soon as the reward fits.
        -- v1.9.11: count only when the game reports the bags settled
        -- (BAG_UPDATE_DELAYED, fallback QUEST_RECOUNT_FALLBACK s); a
        -- fixed 0.15 s was too early (1.9.10, Peter's test).
        if forQuest then
            local room = session.room
            session.questRecount = room
            C_Timer.After(QUEST_RECOUNT_FALLBACK, function()
                if session.questRecount == room then Capture.QuestRoomRecount() end
            end)
            return
        end
    else
        RoomSkip(bagItem)
    end
    Refresh()
    Capture.ShowMakeRoomNow()
end

-- Called from the Delete button OnClick (hardware event).
function Capture.ExecuteMakeRoom()
    local decision = session.decision
    local ok = Resolver.ValidateMakeRoom(decision)
    if not ok then
        LOF.Print("Bags changed - checking again.")
        Resolver.InvalidateCache()
        Capture.ShowMakeRoomNow()   -- v1.9.0
        return
    end
    session.awaitingUser = false
    session.busy = true
    local bagItem = decision.bagItem
    local countBefore = Resolver.CountItemInBags(bagItem.itemID)
    session.countBefore = countBefore
    session.phase = "direct"

    -- Same sequence as the swap (v0.5.1): nothing in between.
    ClearCursor()
    LOF.PickupContainerItem(bagItem.bag, bagItem.slot)
    DeleteCursorItem()

    LOF.UI.HideSwapPopup()

    C_Timer.After(DIRECT_CHECK_DELAY, function()
        if session.decision ~= decision then return end
        local state, why = Resolver.GetDestroyState(bagItem, countBefore)
        if state ~= "pending" then
            MakeRoomDone(bagItem, state)
            return
        end
        if why == "cursor" then
            -- Not allowed here: put it back, the player decides.
            ClearCursor()
            LOF.Print("Could not delete " .. tostring(bagItem.name) .. " automatically - delete it by hand.")
            session.phase = nil
            Capture.StopSession()
            return
        end
        -- Blizzard's confirmation dialog (or the server is still busy).
        if why == "dialog" then
            LOF.Print("Confirm the delete in the Blizzard dialog.")
        end
        session.phase = "destroy"
        local startedAt = GetTime()
        StopMakeRoomWatch()
        makeRoomTicker = C_Timer.NewTicker(DESTROY_POLL_INTERVAL, function()
            if not IsRoomMode() then StopMakeRoomWatch() return end
            local st = Resolver.GetDestroyState(bagItem, countBefore)
            if st ~= "pending" then
                MakeRoomDone(bagItem, st)
            elseif GetTime() - startedAt > DESTROY_TIMEOUT then
                MakeRoomDone(bagItem, "returned")
            end
        end)
    end)
end

-- -------------------------------------------------------------
-- Upgrade Advisor flow (v0.3.0)
-- Looted gear is queued; one popup at a time, never in combat,
-- never while the loot window or a swap session is open.
-- -------------------------------------------------------------
local Upgrade = Resolver.Upgrade
local upgradeQueue = {}
local currentUpgrade = nil
local pendingEquip = nil
local processScheduled = false
local EQUIP_CHECK_DELAY = 2

local function CanShowUpgrade()
    if InCombatLockdown() then return false end
    if (GetNumLootItems() or 0) > 0 then return false end
    if session.active or currentUpgrade or pendingEquip then return false end
    return true
end

function Capture.ProcessUpgradeQueue()
    processScheduled = false
    if not Upgrade.IsEnabled() then
        upgradeQueue = {}
        return
    end
    while #upgradeQueue > 0 and CanShowUpgrade() do
        local entry = table.remove(upgradeQueue, 1)
        local bag, slot = Upgrade.FindInBags(entry.link, entry.itemID)
        if bag then
            local verdict = Upgrade.Evaluate(bag, slot)
            if Upgrade.ShouldPrompt(verdict, entry.force) then
                currentUpgrade = verdict
                Upgrade.MarkAdvised(verdict.itemID)   -- v1.7.4
                LOF.UI.ShowUpgradePopup(verdict)
                return
            end
        end
    end
end

local function ScheduleUpgradeProcessing(delay)
    if processScheduled then return end
    processScheduled = true
    C_Timer.After(delay or 0.5, Capture.ProcessUpgradeQueue)
end

function Capture.QueueUpgrade(link, itemID)
    if not Upgrade.IsEnabled() or not Upgrade.IsGearLink(link) then return end
    if Upgrade.IsIgnored(itemID) then return end
    for _, e in ipairs(upgradeQueue) do
        if e.link == link then return end
    end
    upgradeQueue[#upgradeQueue + 1] = { link = link, itemID = itemID }
    ScheduleUpgradeProcessing(0.5)
end

-- New-gear detection (v0.3.2): compare the bag gear before/after each
-- bag update. Source does not matter (loot, quest, vendor, mail).
-- Not new: items just taken off (tracked per itemID for a few
-- seconds), bag/bank moves, the state at login or /reload.
local UNEQUIP_GRACE = 5
local gearSnapshot = nil
local equippedIDs = {}          -- [slot] = itemID
local recentlyUnequipped = {}   -- [itemID] = GetTime()
local bankOpen = false
local diffScheduled = false
local LOGIN_GRACE = 5           -- bags may still be filling after login
local baselineUntil = 0

local function SnapshotEquipment()
    for slot = 1, 19 do
        equippedIDs[slot] = GetInventoryItemID("player", slot)
    end
end

local function GetUnequipExclusions()
    local now, ex = GetTime(), {}
    for itemID, t in pairs(recentlyUnequipped) do
        if now - t <= UNEQUIP_GRACE then
            ex[itemID] = true
        else
            recentlyUnequipped[itemID] = nil
        end
    end
    return ex
end

local function RunGearDiff()
    diffScheduled = false
    local current = Upgrade.GetBagGearSnapshot()
    if gearSnapshot and not bankOpen and GetTime() >= baselineUntil then
        for _, g in ipairs(Upgrade.FindNewGear(gearSnapshot, current, GetUnequipExclusions())) do
            Capture.QueueUpgrade(g.link, g.itemID)
        end
    end
    gearSnapshot = current
end

-- Small delay so PLAYER_EQUIPMENT_CHANGED is processed first.
local function ScheduleGearDiff()
    if diffScheduled then return end
    diffScheduled = true
    C_Timer.After(0.3, RunGearDiff)
end

-- Evaluate every gear item in the bags and queue the ones worth a popup.
-- mode: "button" (default; Scan button and /lof upgrade scan: popups,
--                 or one "no upgrades" line),
--       "silent" (after a level-up: popups only, no chat at all).
function Capture.ScanBagsForUpgrades(mode)
    mode = mode or "button"
    if not Upgrade.IsEnabled() then
        if mode ~= "silent" then
            LOF.Print("Upgrade Advisor is off. /lof upgrade on")
        end
        return
    end
    local prompts = 0
    for bag = 0, LOF.GetLastBagIndex() do
        for slot = 1, LOF.GetContainerNumSlots(bag) do
            local c = LOF.GetContainerItemInfo(bag, slot)
            if c and c.hyperlink and Upgrade.IsGearLink(c.hyperlink) then
                local v = Upgrade.Evaluate(bag, slot)
                if v then
                    if Upgrade.ShouldPrompt(v, true) and not (mode == "silent" and v.popupKind == "ALT") then
                        prompts = prompts + 1
                        local queued = false
                        for _, e in ipairs(upgradeQueue) do
                            if e.link == v.link then e.force = true queued = true break end
                        end
                        if not queued then
                            upgradeQueue[#upgradeQueue + 1] = { link = v.link, itemID = v.itemID, force = true }
                        end
                    end
                end
            end
        end
    end
    if mode == "button" and prompts == 0 then
        LOF.Print("No gear upgrades in your bags.")
    end
    ScheduleUpgradeProcessing(0.2)
end

local function FinishUpgrade()
    currentUpgrade = nil
    LOF.UI.HideUpgradePopup()
    ScheduleUpgradeProcessing(0.3)
end

-- Called from the Equip button OnClick (hardware event).
function Capture.EquipUpgrade()
    local v = currentUpgrade
    if not v then return end
    -- v1.5.1: a ClearCursor on an empty cursor still fires CURSOR_CHANGED,
    -- which makes Forever close the bind dialog: only clear when needed.
    if GetCursorInfo() then ClearCursor() end
    -- v1.5.2: pick up + drop on the slot (keeps the bind dialog open)
    local bag, slot = Upgrade.FindInBags(v.link, v.itemID)
    if bag and slot and _G.EquipCursorItem then
        LOF.PickupContainerItem(bag, slot)
        EquipCursorItem(v.targetSlot)
    else
        local equipFn = (_G.C_Item and _G.C_Item.EquipItemByName) or _G.EquipItemByName
        equipFn(v.link, v.targetSlot)
    end
    pendingEquip = { itemID = v.itemID, name = v.name, quality = v.quality, slot = v.targetSlot }
    currentUpgrade = nil
    LOF.UI.HideUpgradePopup()

    -- Bind-on-Equip items wait for Blizzard's confirm dialog; the
    -- result is reported via PLAYER_EQUIPMENT_CHANGED or this check.
    local function CheckEquip(attempt)
        local p = pendingEquip
        if not p then return end
        if GetInventoryItemID("player", p.slot) == p.itemID then
            LOF.Print("Equipped " .. LOF.ColorizeName(p.name, p.quality) .. ".")
            pendingEquip = nil
        elseif attempt < 15 and StaticPopup_Visible
            and (StaticPopup_Visible("EQUIP_BIND") or StaticPopup_Visible("AUTOEQUIP_BIND")) then
            -- player still deciding in Blizzard's dialog: check again
            C_Timer.After(EQUIP_CHECK_DELAY, function() CheckEquip(attempt + 1) end)
            return
        else
            LOF.Print(LOF.ColorizeName(p.name, p.quality) .. " not equipped.")
            pendingEquip = nil
        end
        ScheduleUpgradeProcessing(0.3)
    end
    C_Timer.After(EQUIP_CHECK_DELAY, function() CheckEquip(1) end)
end

-- v1.7.3: combat starts while an Upgrade popup is open: hide it and put
-- the item back at the front of the queue (no reschedule: the queue is
-- processed again on PLAYER_REGEN_ENABLED).
function Capture.ParkUpgradeForCombat()
    local v = currentUpgrade
    if not v then return end
    currentUpgrade = nil
    LOF.UI.HideUpgradePopup()
    if v.link then
        table.insert(upgradeQueue, 1, { link = v.link, itemID = v.itemID, force = true })
    end
end

-- Cancel: close without ignoring; the item stays in the bag and can be
-- suggested again (next loot of it, or /lof upgrade scan).
function Capture.CancelUpgrade()
    FinishUpgrade()
end

function Capture.IgnoreUpgrade()
    local v = currentUpgrade
    if v then Upgrade.Ignore(v.itemID, v.name) end
    FinishUpgrade()
end

-- -------------------------------------------------------------
-- Loot left behind (v1.2.0 safety net)
-- The bag item was destroyed but the loot window closed before the
-- loot arrived (e.g. the player moved). LOF remembers the item and its
-- corpse and loots it automatically when that corpse is opened again.
-- -------------------------------------------------------------
local OWED_TTL = 180          -- seconds
local OWED_CHECK_DELAY = 1.5  -- after LOOT_CLOSED: let late items arrive
local owed = nil

local function LootArrived(info)
    return Resolver.CountItemInBags(info.lootItem.itemID) > info.lootCountBefore
end

local function BagItemGone(info)
    return Resolver.CountItemInBags(info.bagItemID) <= info.bagCountBefore - (info.bagCount or 1)
end

local function ClearOwed()
    owed = nil
    if LOF.UI and LOF.UI.HideLeftBehindPopup then LOF.UI.HideLeftBehindPopup() end
end

local function SetOwed(info)
    owed = info
    LOF.UI.ShowLeftBehindPopup(info.lootItem)   -- v1.9.5: popup + chat line
    C_Timer.After(OWED_TTL, function()
        if owed == info then ClearOwed() end
    end)
end

-- Swap result line (v1.2.0): "Swapped X for Y." as soon as the bag
-- item is gone and the loot is in the bags, whether or not the loot
-- window is still open. Dropped after SWAP_RESULT_TIMEOUT (the safety
-- net reports a loot left behind).
local SWAP_RESULT_TIMEOUT = 10
local swapResults = {}

function Capture.TrackSwapResult(info)
    swapResults[#swapResults + 1] = info
end

local function CheckSwapResults()
    for i = #swapResults, 1, -1 do
        local info = swapResults[i]
        if BagItemGone(info) and LootArrived(info) then
            local b, l = info.bagItem, info.lootItem
            LOF.Print("Swapped " .. LOF.ColorizeName(b.name, b.quality)
                .. " for " .. LOF.ColorizeName(l.name, l.quality) .. ".")
            table.remove(swapResults, i)
        elseif GetTime() - info.clickedAt > SWAP_RESULT_TIMEOUT then
            table.remove(swapResults, i)
        end
    end
end

-- Called from LOOT_CLOSED while a swap was running.
local function CheckLeftBehind(info)
    C_Timer.After(OWED_CHECK_DELAY, function()
        if owed then return end
        if BagItemGone(info) and not LootArrived(info) then
            SetOwed(info)
        end
    end)
end

-- Called from LOOT_OPENED: same corpse again? Then loot the item.
local function TryLootOwed()
    if not owed then return end
    local slot = Resolver.FindLootSlot(owed.lootItem.link, owed.sourceGUID)
    if not slot then return end
    local item = owed.lootItem
    ClearOwed()
    LOF.Print("Looting " .. LOF.ColorizeName(item.name, item.quality) .. " (left behind).")
    C_Timer.After(0.1, function()
        if (GetNumLootItems() or 0) > 0 and LootSlotHasItem(slot) then
            LootSlot(slot)
        end
    end)
end

-- -------------------------------------------------------------
-- Holdings (v1.3.0): when to read bags and bank. One pending timer;
-- a newer request replaces the older one (bundling).
-- -------------------------------------------------------------
local holdingsTimerID = 0
local holdingsWantBank = false
local mailOpen = false
local ahOpen = false
local ahOwnedReady = false   -- server answered with the owned auctions

local function ScheduleHoldingsScan(delay, withBank)
    if withBank then holdingsWantBank = true end
    holdingsTimerID = holdingsTimerID + 1
    local id = holdingsTimerID
    C_Timer.After(delay, function()
        if id ~= holdingsTimerID then return end
        local H = Resolver.Holdings
        if not H then return end
        H.ScanCharacter()
        if holdingsWantBank and bankOpen then H.ScanBank() end
        if mailOpen and H.ScanMail then H.ScanMail() end
        if ahOpen and ahOwnedReady and H.ScanAuctions then H.ScanAuctions() end
        holdingsWantBank = false
        Refresh()
    end)
end

-- -------------------------------------------------------------
-- Events
-- -------------------------------------------------------------
LOF.On("PLAYER_ENTERING_WORLD", function()
    -- Baseline only: nothing in the bags at login/reload is "new".
    SnapshotEquipment()
    gearSnapshot = Upgrade.GetBagGearSnapshot()
    baselineUntil = GetTime() + LOGIN_GRACE
    Resolver.InitSessionMoney()
    Resolver.Value.Invalidate()
    ScheduleHoldingsScan(2)
    Refresh()
end)

local startScheduled = false

LOF.On("LOOT_OPENED", function()
    -- A previous window may still be waiting for late items: record
    -- what arrived and close that list before the new baseline.
    if pendingLoot then FinishPendingLoot() end
    if IsRoomMode() then Capture.StopSession() end   -- v1.7.0 / v1.7.6: Swap takes over
    lootWindowOpen = true
    lootGeneration = lootGeneration + 1
    Resolver.CaptureLootBaseline()
    BuildPendingLoot()
    TryLootOwed()
end)

-- v1.9.9 (E7): quest reward room
LOF.On("QUEST_PROGRESS", function()
    Resolver.RememberQuestTurnIn()
end)

LOF.On("QUEST_COMPLETE", function()
    Resolver.QuestRewardShown()   -- v1.9.13 (E10)
    C_Timer.After(0.1, function()
        if not Resolver.IsMakeRoomEnabled() then return end
        if session.active or session.awaitingUser or session.busy then return end
        Resolver.InvalidateCache()
        local q = Resolver.GetQuestRewardRoom()
        if q and q.short > 0 then Capture.StartMakeRoomNow(true, true) end
    end)
end)

LOF.On("QUEST_FINISHED", function()
    Resolver.ForgetQuestTurnIn()
    if IsRoomMode() and session.room and session.room.forQuest and not session.busy then
        Capture.StopSession()
    end
end)

LOF.On("UI_ERROR_MESSAGE", function(_, _, message)
    if message ~= ERR_INV_FULL then return end
    if (GetNumLootItems() or 0) <= 0 then
        Capture.OfferMakeRoom()   -- v1.7.0: bags full outside the loot window
        return
    end
    if startScheduled or session.awaitingUser or session.busy then return end
    -- Autoloot fires ERR_INV_FULL once per item: start only once.
    startScheduled = true
    C_Timer.After(LOF.SWAP_DELAY, function()
        startScheduled = false
        Capture.StartSession()
    end)
end)

LOF.On("LOOT_CLOSED", function()
    -- A swap was running (delete sent): check whether the loot made it.
    local swapInfo = session.busy and session.swapInfo or nil
    Capture.StopSession()
    if swapInfo then CheckLeftBehind(swapInfo) end
    lootWindowOpen = false
    local gen = lootGeneration
    -- Items can land in the bags just after the window closes.
    C_Timer.After(0.3, function()
        if gen ~= lootGeneration then return end
        if CommitPendingLoot() == 0 then
            FinishPendingLoot()
        end
        ScheduleUpgradeProcessing(0.2)
    end)
    -- Last chance for late items (e.g. looted via Swap).
    C_Timer.After(PENDING_GRACE, function()
        if gen ~= lootGeneration or lootWindowOpen then return end
        if pendingLoot then FinishPendingLoot() end
    end)
end)

-- v1.2.1: after a level-up, items that were too high level may now be
-- usable: silent scan (popups only). Short delay so the new level is
-- reflected in the item tooltips.
local LEVELUP_SCAN_DELAY = 2

LOF.On("PLAYER_LEVEL_UP", function()
    C_Timer.After(LEVELUP_SCAN_DELAY, function()
        Capture.ScanBagsForUpgrades("silent")
    end)
end)

LOF.On("PLAYER_REGEN_ENABLED", function()
    ScheduleUpgradeProcessing(0.5)
end)

-- -------------------------------------------------------------
-- v1.7.1: tabs and combat
-- -------------------------------------------------------------
LOF.On("PLAYER_STARTED_MOVING", function()
    if LOF.UI.LeaveInfoPagesOnMove then LOF.UI.LeaveInfoPagesOnMove() end
    if LOF.UI.CloseSettingsWindow then LOF.UI.CloseSettingsWindow() end   -- v1.7.5
    if LOF.UI.CloseGuideWindow then LOF.UI.CloseGuideWindow() end         -- v1.7.8
    if LOF.UI.Kit.HideConfirm then LOF.UI.Kit.HideConfirm() end          -- v1.9.1: no question left open
end)

function Capture.HideForCombat()
    local UI = LOF.UI
    local hidden = {}
    if UI.IsDashboardOpen and UI.IsDashboardOpen() then
        UI.SetMinimized(true)
        hidden.dashboard = true
    end
    if UI.HideHoldingsForCombat and UI.HideHoldingsForCombat() then hidden.holdings = true end
    if UI.HideAltMailForCombat and UI.HideAltMailForCombat() then hidden.altmail = true end
    if UI.CloseSettingsWindow then UI.CloseSettingsWindow() end   -- v1.7.5: not restored
    if UI.HideGuideForCombat and UI.HideGuideForCombat() then hidden.guide = true end   -- v1.7.8
    if UI.Kit.HideConfirm then UI.Kit.HideConfirm() end   -- v1.9.1: a question never survives combat
    if next(hidden) then LOF.db.combatHidden = hidden end
    -- v1.7.2: a popup that only waits for the player goes away
    if session.active and session.awaitingUser and not session.busy then
        Capture.StopSession()
    end
    -- v1.7.3: open Upgrade popup -> back in the queue, shown after combat
    if Capture.ParkUpgradeForCombat then Capture.ParkUpgradeForCombat() end
end

function Capture.RestoreAfterCombat()
    local h = LOF.db.combatHidden
    if not h then return end
    LOF.db.combatHidden = nil
    local UI = LOF.UI
    if h.dashboard and LOF.db.shown and LOF.db.minimized then UI.SetMinimized(false) end
    if h.holdings and UI.RestoreHoldingsAfterCombat then UI.RestoreHoldingsAfterCombat() end
    if h.altmail and UI.RestoreAltMailAfterCombat then UI.RestoreAltMailAfterCombat() end
    if h.guide and UI.RestoreGuideAfterCombat then UI.RestoreGuideAfterCombat() end   -- v1.7.8
end

LOF.On("PLAYER_REGEN_DISABLED", function() Capture.HideForCombat() end)
LOF.On("PLAYER_REGEN_ENABLED", function() Capture.RestoreAfterCombat() end)
LOF.On("PLAYER_ENTERING_WORLD", function()
    -- reload / logout during combat: bring the dashboard back once out of it
    if LOF.db.combatHidden and not UnitAffectingCombat("player") then
        LOF.db.combatHidden.holdings, LOF.db.combatHidden.altmail = nil, nil
        Capture.RestoreAfterCombat()
    end
end)

LOF.On("PLAYER_EQUIPMENT_CHANGED", function(_, slot)
    -- Whatever left this slot is not "new" when it lands in the bags.
    local oldID = equippedIDs[slot]
    local newID = GetInventoryItemID("player", slot)
    if oldID and oldID ~= newID then
        recentlyUnequipped[oldID] = GetTime()
    end
    equippedIDs[slot] = newID

    local p = pendingEquip
    if p and slot == p.slot and GetInventoryItemID("player", slot) == p.itemID then
        LOF.Print("Equipped " .. LOF.ColorizeName(p.name, p.quality) .. ".")
        pendingEquip = nil
        ScheduleUpgradeProcessing(0.3)
    end
end)

LOF.On("BAG_UPDATE_DELAYED", function()
    if session.questRecount then Capture.QuestRoomRecount() end   -- v1.9.11 (E7)
    if #swapResults > 0 then CheckSwapResults() end
    if owed and LootArrived(owed) then ClearOwed() end
    local outstanding = CommitPendingLoot()
    if pendingLoot and not lootWindowOpen and outstanding == 0 then
        FinishPendingLoot()
    end
    ScheduleGearDiff()
    ScheduleHoldingsScan(1, bankOpen)
    Refresh()
end)

LOF.On("BANKFRAME_OPENED", function()
    bankOpen = true
    ScheduleHoldingsScan(0.3, true)
end)
LOF.On("BANKFRAME_CLOSED", function()
    bankOpen = false
    gearSnapshot = Upgrade.GetBagGearSnapshot()
end)
LOF.On("PLAYERBANKSLOTS_CHANGED", function()
    if bankOpen then ScheduleHoldingsScan(1, true) end
end)
LOF.On("PLAYERREAGENTBANKSLOTS_CHANGED", function()
    if bankOpen then ScheduleHoldingsScan(1, true) end
end)
LOF.On("PLAYER_MONEY", function()
    if Resolver.Holdings then Resolver.Holdings.ScanMoney() end
end)

-- v1.4.0: mailbox
LOF.On("MAIL_SHOW", function()
    mailOpen = true
    ScheduleHoldingsScan(0.5)
    -- v1.6.0: Send to alts opens by itself when there is something to send
    C_Timer.After(0.3, function()
        if mailOpen and Upgrade.ShouldAutoOpenAltMail() and LOF.UI.ShowAltMailWindow then
            LOF.UI.ShowAltMailWindow(true)
        end
    end)
end)
LOF.On("MAIL_INBOX_UPDATE", function()
    if mailOpen then ScheduleHoldingsScan(0.5) end
end)
LOF.On("MAIL_CLOSED", function()
    mailOpen = false
    if LOF.UI.OnMailClosed then LOF.UI.OnMailClosed() end
end)
LOF.On("MAIL_SEND_INFO_UPDATE", function() Refresh() end)

-- v1.6.1: tab switches fire no event; watch the Send Mail form itself.
local sendMailHooked = false
local function HookSendMailFrame()
    local f = _G.SendMailFrame
    if sendMailHooked or not (f and f.HookScript) then return end
    f:HookScript("OnShow", function() Refresh() end)
    f:HookScript("OnHide", function() Refresh() end)
    sendMailHooked = true
end
HookSendMailFrame()
LOF.On("MAIL_SHOW", HookSendMailFrame)

local function OpenSendMailTab()
    local f = _G.SendMailFrame
    if f and f:IsShown() then return true end
    if type(_G.MailFrameTab_OnClick) == "function" then
        pcall(_G.MailFrameTab_OnClick, _G.MailFrameTab2, 2)
    end
    if not (f and f:IsShown()) and _G.MailFrameTab2 and _G.MailFrameTab2.Click then
        pcall(_G.MailFrameTab2.Click, _G.MailFrameTab2)
    end
    return f ~= nil and f:IsShown()
end

-- v1.6.0: put an alt upgrade from the bags into the Send Mail form.
-- The resolver decides; this only carries it out. Nothing is sent.
function Capture.AttachUpgradeToMail(bag, slot, link, altName)
    local action = Upgrade.GetMailAction(bag, slot, link, altName)
    if action.code ~= "ATTACH" then return action end
    if action.switchTab and not OpenSendMailTab() then   -- v1.6.1
        return { code = "NO_SEND_TAB" }
    end
    if action.setRecipient and _G.SendMailNameEditBox then
        SendMailNameEditBox:SetText(altName)
    end
    if CursorHasItem() then ClearCursor() end
    LOF.PickupContainerItem(bag, slot)
    if CursorHasItem() then
        ClickSendMailItemButton(action.index)
    end
    if CursorHasItem() then
        ClearCursor()
        return { code = "FAILED" }
    end
    C_Timer.After(0.3, Refresh)
    return action
end

-- v1.5.0: own auctions
local function QueryOwnedAuctions()
    local AH = _G.C_AuctionHouse
    if AH and AH.QueryOwnedAuctions then pcall(AH.QueryOwnedAuctions, {}) end
end

LOF.On("AUCTION_HOUSE_SHOW", function()
    ahOpen = true
    ahOwnedReady = false
    QueryOwnedAuctions()
end)
LOF.On("AUCTION_HOUSE_CLOSED", function()
    ahOpen = false
    ahOwnedReady = false
end)
LOF.On("OWNED_AUCTIONS_UPDATED", function()
    if not ahOpen then return end
    ahOwnedReady = true
    ScheduleHoldingsScan(0.3)
end)
LOF.On("AUCTION_HOUSE_AUCTION_CREATED", function()
    if ahOpen then C_Timer.After(1, QueryOwnedAuctions) end
end)
LOF.On("AUCTION_CANCELED", function()
    if ahOpen then C_Timer.After(1, QueryOwnedAuctions) end
end)

-- Mail to an own alt: remember what is attached when SendMail is
-- called, book it only when the server confirms the send.
local pendingSend = nil

local function OnSendMail(recipient)
    local items = {}
    local maxSend = tonumber(_G.ATTACHMENTS_MAX_SEND or 12) or 12
    for i = 1, maxSend do
        local link = _G.GetSendMailItemLink and GetSendMailItemLink(i)
        if link then
            local _, _, _, count = GetSendMailItem(i)
            items[#items + 1] = { link = link, count = tonumber(count or 1) or 1 }
        end
    end
    local money = (_G.GetSendMailMoney and GetSendMailMoney()) or 0
    local cod = (_G.GetSendMailCOD and GetSendMailCOD()) or 0
    if (tonumber(cod or 0) or 0) > 0 then money = 0 end
    pendingSend = { recipient = recipient, items = items, money = tonumber(money or 0) or 0 }
end

if _G.SendMail then
    hooksecurefunc("SendMail", function(recipient) pcall(OnSendMail, recipient) end)
end
LOF.On("MAIL_SEND_SUCCESS", function()
    local p = pendingSend
    pendingSend = nil
    if p and Resolver.Holdings and Resolver.Holdings.RecordSentMail then
        Resolver.Holdings.RecordSentMail(p.recipient, p.items, p.money)
        Refresh()
    end
end)
LOF.On("MAIL_FAILED", function() pendingSend = nil end)
LOF.On("PLAYER_EQUIPMENT_CHANGED", function() ScheduleHoldingsScan(1, bankOpen) end)
LOF.On("SKILL_LINES_CHANGED", function() ScheduleHoldingsScan(2, bankOpen) end)

-- New auction data. Auctionator may still be storing prices when it
-- reports or when the window closes, so values are read again 3s later.
local AH_SETTLE_DELAY = 3

local function RereadValues()
    Resolver.InvalidateCache()
    Refresh()
    C_Timer.After(AH_SETTLE_DELAY, function()
        Resolver.Value.Invalidate()
        Refresh()
    end)
end

LOF.On("AUCTION_HOUSE_CLOSED", RereadValues)

-- Auctionator's official "new prices stored" callback (API v1).
local priceUpdateRegistered = false

LOF.On("PLAYER_LOGIN", function()
    if priceUpdateRegistered then return end
    local api = _G.Auctionator and _G.Auctionator.API and _G.Auctionator.API.v1
    if not api or type(api.RegisterForDBUpdate) ~= "function" then return end
    local ok = pcall(api.RegisterForDBUpdate, LOF.Data.PriceRules.auctionatorCallerID, function()
        Resolver.Value.RecordPriceUpdate()
        RereadValues()
    end)
    priceUpdateRegistered = ok
end)

-- v1.7.8: the Guide opens by itself once per version (Resolver decides)
local GUIDE_FIRST_DELAY, GUIDE_RETRY, GUIDE_MAX_TRIES = 6, 5, 24
local guideTries = 0

local function GuideMomentIsQuiet()
    if InCombatLockdown() then return false end
    if session.active or session.busy then return false end
    if (GetNumLootItems() or 0) > 0 then return false end
    if currentUpgrade then return false end
    return true
end

function Capture.TryShowGuide()
    local tab = Resolver.GetGuideTrigger()
    if not tab or not LOF.UI.ShowGuideWindow then return end
    if not GuideMomentIsQuiet() then
        guideTries = guideTries + 1
        if guideTries < GUIDE_MAX_TRIES then C_Timer.After(GUIDE_RETRY, Capture.TryShowGuide) end
        return
    end
    Resolver.MarkGuideSeen()
    LOF.UI.ShowGuideWindow(tab, true)
end

LOF.On("PLAYER_LOGIN", function()
    C_Timer.After(GUIDE_FIRST_DELAY, Capture.TryShowGuide)
end)

LOF.On("PLAYER_MONEY", Refresh)
-- v1.9.6 (E4): pending upgrade comparisons first, then the refresh
LOF.On("GET_ITEM_INFO_RECEIVED", function(_, itemID, success)
    if Resolver.Upgrade and Resolver.Upgrade.OnItemDataReceived then
        Resolver.Upgrade.OnItemDataReceived(itemID, success)   -- v1.9.7
    end
    Refresh()
end)

-- v1.9.6 (E4): load the alts' worn gear before the first loot
local ALT_GEAR_PRELOAD_DELAY = 3
LOF.On("PLAYER_LOGIN", function()
    C_Timer.After(ALT_GEAR_PRELOAD_DELAY, function()
        if Resolver.Upgrade and Resolver.Upgrade.PreloadAltGear then
            Resolver.Upgrade.PreloadAltGear()
        end
    end)
end)
