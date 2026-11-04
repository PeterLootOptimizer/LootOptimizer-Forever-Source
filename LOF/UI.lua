-- =============================================================
-- LOF (LootOptimizer Forever) -- UI.lua
-- Pure consumer: renders LOF.Resolver.GetDashboardSnapshot() and
-- forwards button clicks to LOF.Capture / LOF.Resolver.
-- No calculations or decisions in this file.
-- =============================================================
--
-- Changelog
-- ---------
-- v1.17.26: Swap-family popup 30 px wider (SWAP_WIDTH 420) so the large
--   quest note fits on one line; the 4 Make room buttons share the width.
-- v1.17.25: The quest note in Make room uses GameFontNormalLarge (Peter:
--   "much bigger, so it stands out"); other notes keep the small font.
-- v1.17.24: E7: a quest Make room shows the resolver's questNote ("Quest
--   reward needs 4 free slots - you have 2.") in gold instead of "Frees
--   one slot. Then try again ...".
-- v1.17.23: Make room hint: a blank line under "Cheapest Grey item ..." (Peter).
-- v1.17.22: Make room explains its choice when a cheaper item waits in a
--   higher quality (Resolver 0.10.8, d.cheaperItem): "Cheapest Grey item -
--   Grey goes first." / "Cheaper overall: White item X, 1s (AH)." / the
--   order line. Otherwise unchanged ("Cheapest item LOF may delete.").
-- v1.17.21: Notice one size larger again: GameFontNormalHuge (Peter).
-- v1.17.20: UI.ShowNotice has its own line directly under Blizzard's error
--   frame, one font size larger (GameFontNormalLarge), gold; 3 s visible,
--   then a 1 s fade; a new notice replaces the old one; clicks pass through
--   (Peter: larger text without touching Blizzard's own messages).
-- v1.17.19: UI.ShowNotice(text): one line in Blizzard's error frame (where
--   "Inventory is full" shows, fades by itself), gold. Used when the "Not
--   worth a swap" popup is switched off (Resolver 0.10.7). The popup title
--   NOTHING TO SWAP is now NOTHING AVAILABLE TO SWAP (Peter).
-- v1.17.18: Swap popup: "PROFIT" in capitals, word and amount in the
--   profit colour (green, red for a loss) so it stands out (Peter).
-- v1.17.17: E5 (Peter): the LOF upgrade block in item tooltips starts with
--   a blank line; one alt per line (indented, no word wrap), the stat line
--   directly under the first (best) alt; "also for" uses the same list.
--   StatLabel reads LOF's own label first (Data/StatProfiles statLabels):
--   "Weapon DPS" instead of the game's lowercase "damage per second".
-- v1.17.16: /lof version: a heading per layer (Core, Resolver, UI, Data),
--   one file per line, alphabetical within a group (Peter). The Info tab's
--   one-line version info uses the same order (same table).
-- v1.17.15: Comments only (release audit G5): Info tab and copy-box
--   comments describe the current layout; unused locals ax, ay removed.
-- v1.17.14: NOT WORTH A SWAP gets a red background (tint) next to its red
--   border (Peter: while playing it looked too much like a plain swap,
--   which has no colour). One value in POPUP_STYLES; the Guide's Colors
--   swatch follows by itself. NOTHING TO SWAP and LOOT LEFT BEHIND share
--   this style and get the red background too (Peter: fine).
-- v1.17.13: Info tab regrouped (Peter): About, Guide (Open Guide button
--   instead of the How to use text) and Support with website, Discord,
--   mail and version info, each in a copy box. Addresses come from
--   Data/Guide links (the mail constant here is gone); InfoHowToLines
--   removed (only the Info tab used it). Kit.CreateCopyBox shared.
-- v1.17.12: Release audit fixes. The tooltip error helper lives inside
--   InstallBagTooltipHook (was two top-level locals, against working
--   agreement 8: UI.lua's 200-local limit). /lof version chat header is
--   "LOF: 1.6.1 | WoW ..." (was "LOF: LOF 1.6.1").
-- v1.17.11: Versions (audit A7 + Peter: readable in chat). One list,
--   VERSION_GROUPS, with every part by name (DisenchantTable was missing,
--   the Data versions had no names). Two renderings of that one list:
--   UI.GetVersionInfo (one line, Info tab copy box) and
--   UI.GetVersionLines (chat: one line per layer, /lof version).
-- v1.17.10: "Not worth a swap" shows the resolver's loss (audit A6; the
--   UI no longer subtracts values itself).
-- v1.17.9: LOOT LEFT BEHIND shows its explanation again (buglist E3):
--   SetPopupMode hid the summary in mode "left", so the text "Your bag
--   slot is free. Open the corpse again ..." never appeared (since 1.1.x).
-- v1.17.8: UI.ShowLeftBehindPopup also prints the chat line "Bag slot is
--   free - open the corpse again to loot X." (moved from Capture, audit
--   A5), red from the RED constant.
-- v1.17.7: Tooltip errors are reported once per session (audit A4: every
--   hover printed a chat line, so one error could flood the chat; the
--   older SetBagItem hook swallowed errors silently). Both tooltip routes
--   use ReportTooltipError; red is the RED constant (was a third red).
-- v1.17.6: /lof upgrade scan runs the scan like the Scan button (audit
--   A2; Capture 1.9.3 removed the debug mode that printed raw codes).
-- v1.17.5: Quest loot texts come from the resolver (Resolver 0.10.1:
--   questTag, questSub, decision.questSummary per quest state). The swap
--   card and the summary line no longer choose a quest text themselves;
--   they render the resolver's text in GOLD.
-- v1.17.4: Kit.StatChangeLines = the one compact stat line (tooltips and
--   Send to alts); the tooltip's "upgrade for you" gain uses Kit.GainText
--   (missed in 1.17.0); WHITE is one constant (Kit.WHITE) instead of
--   literals in several files.
-- v1.17.3: RenderComparison is also used by Holdings > Gear for alts
--   (UIHoldings 0.9.4): UI.RenderComparison is exported, and the number
--   columns are placed from the right edge of f.innerWidth so the table
--   fits narrower panels.
-- v1.17.2: Make room popup (Peter): the title is short again ("MAKE ROOM
--   - bags full" / "MAKE ROOM NOW"); quality and position moved to the
--   caption line ("Delete from bag:  White  (1 of 12)"). The summary and
--   the note under the item are white instead of light grey.
-- v1.17.1: One Make room popup (Capture 1.9.0, Resolver 0.10.0). Bags
--   full outside the loot window shows the Make room now popup with
--   d.bagsFull: title "MAKE ROOM - bags full - White (1 of 12)" (style
--   room), the note "Frees one slot. Then try again ...", Delete /
--   Previous / Next / Cancel. UI.ShowMakeRoomPopup, popup mode "room"
--   and its Delete / WL / Cancel buttons are gone.
-- v1.17.0: Shared helpers in one place (Peter: functions exactly once).
--   Kit.ClassColored, Kit.GainText (empty slot / +x% / fallback, with an
--   optional name), Kit.GetPooled / HidePool, Kit.ShowConfirm /
--   HideConfirm (the one confirmation dialog) and
--   Kit.AskRemoveCharacter (the one "Remove from LOF" flow). UIHoldings,
--   UISettings, UIAltMail, UIGuide and UIReagents use them; their own
--   copies are gone. Swap popup, Upgrade popup and alt lines use
--   GainText. No visible change except the same gain wording everywhere.
-- v1.16.6: One comparison block (Peter: "everything in one place").
--   RenderComparison(f, x, y, gear, opts) draws Compared with / the stat
--   table / effects (New, Lost) / notes / hint for the Upgrade popup AND
--   the swap popup; the Upgrade popup's own copy and RenderSwapStats are
--   gone. Same data from the resolver, same look in both popups. The
--   swap popup now also shows the "Effects" head and the class hint.
-- v1.16.5: Effects of the item you would take off are labelled "Lost"
--   (red) with grey text, the new item's stay "New" in Blizzard green
--   (Peter: green "Equipped: Equip: +1 ..." read as a gain). Stat-only
--   Equip: lines no longer reach the UI (ResolverUpgrade 0.13.2).
--   Swap popup and Upgrade popup alike.
-- v1.16.4: Swap popup for an alt upgrade shows the same comparison as
--   for you ("Compared with: X (worn by Name)", table, effects, Based
--   on; Resolver 0.9.2). The summary line wraps to a second line for
--   every reason (Peter: the alt line ran out of the window); only the
--   plain Loot / Bag / Profit line stays on one line.
-- v1.16.3: "Not worth a swap" / "Nothing to swap": the countdown
--   ("closes in 9") is white and larger (Peter: hardly visible) and the
--   popup stays 10 seconds (was 6). Still paused while the mouse is on it.
-- v1.16.2: The resolver's note (d.navNote) also shows when there is only
--   one bag item that qualifies ("Only bag item worth less than the
--   loot ..."), without Previous / Next (Resolver 0.9.1).
-- v1.16.1: The style border (gold, orange, red, ...) no longer runs over
--   the coin portrait at the top left (Peter): it lies one frame strata
--   below the popup and 8 px outside it, so it shows as a coloured
--   outline around the window. Same for every popup that has one.
-- v1.16.0: One place for the colour language (Peter: "change it in one
--   place and every popup knows it"). POPUP_STYLES (top of this file)
--   holds per style the head word, border, tint and card colour;
--   ApplyPopupStyle(f, key, opts) is the only function that colours a
--   popup and always resets first. Used by the swap popup (gear,
--   trade-off, alt, quest, reagent, plain), Make room, Make room now
--   (+ question), Not worth a swap / Nothing to swap, Loot left behind
--   and the Upgrade popup. New: every coloured popup has a thick border
--   in its colour and a head in capitals: QUEST ITEM (gold), ALT
--   UPGRADE (orange), REAGENT (teal), MAKE ROOM / MAKE ROOM NOW
--   (bronze). The Upgrade popup for you now follows the item quality
--   colour too (was green). Kit.POPUP_STYLES / GetPopupStyleColors feed
--   the Guide's Colors tab; markup [bronze] comes from the table.
-- v1.15.1: /lof guide colors (also /lof colors) opens the Guide on its
--   new Colors tab (UIGuide 0.2.0).
-- v1.15.0: Colour language (Peter, beta: closer to Blizzard).
--   - Swap popup, gear upgrade for you (Resolver 0.9.0): title "GEAR
--     UPGRADE - bags full, swap?" (white, large; "GEAR TRADE-OFF" for a
--     trade-off), border and background in the loot's Blizzard quality
--     colour (grey, white, green, blue, purple), the loot card framed in
--     it, and under the summary the full comparison as in the Upgrade
--     popup: "Compared with", Stat / Equipped / New / Change, effects and
--     "Based on" (d.gearCompare). Alt upgrade stays orange.
--   - Make room, Make room now and its question: bronze (bag leather)
--     instead of purple, which is Blizzard's epic colour. Markup
--     [bronze]..[/] for the Guide.
--   - The swap popup is 390 wide (was 360) so the stat table fits.
-- v1.14.2: Kit.RemoveCharacterQuestion / RemoveCharacterDone: one text
--   for "Remove from LOF" in Holdings and Settings > Characters.
-- v1.14.1: The last-item note in the Swap popup is larger and white
--   (Peter: easier to notice), was small and grey.
-- v1.14.0: Previous / Next in the Swap popup (Capture 1.8.0, Resolver
--   0.8.0). With more than one bag item that qualifies (d.total > 1):
--   Swap · Previous · Next · WL · Wait (narrower buttons); Previous /
--   Next disabled when the resolver says so (canPrevious / canNext). On
--   the last qualifying item a grey note under the summary
--   (d.navNote). One qualifying item: Swap · WL · Wait as before.
-- v1.13.1: Minimap button via LibDBIcon (CurseForge request: minimap
--   button collectors like Leatrix Plus only gather LibDBIcon buttons).
--   Libs/ embeds LibStub, CallbackHandler, LibDataBroker, LibDBIcon.
--   At the minimap = the LibDBIcon button ("LootOptimizerForever";
--   LibDBIcon drags it along the edge, position in LOF.db.miniIcon
--   .minimapPos, taken over from the old angle). Loose = our own coin
--   as before (only while the dashboard is closed). Minimap <-> loose:
--   Shift-right-click on either icon (was Shift-drag). Same click,
--   right-click and tooltip on both; the free-slot count on both.
--   Without the libs the loose coin is the only icon.
-- v1.13.0: Guide (LOF 1.6.0, UIGuide.lua). UI.Kit.FormatMarkup turns
--   the data markup ([gold]..[/], [teal]..[/], ...) into colours. The
--   Info page "How to use" reads Data/Guide.lua (howTo) instead of its
--   own list. /lof guide. Version info lists UIGuide and Data/Guide.
-- v1.12.7: Two icon states only (Peter): at the minimap (always shown,
--   setting on) or loose (only while the dashboard is closed, setting
--   off). Shift-drag off the minimap = loose (setting goes off, chat
--   line explains); Shift-right-click the loose coin = back to the
--   minimap (setting on). The "loose but always shown" in-between state
--   (miniIcon.free) is gone. /lof reset: back to the minimap.
-- v1.12.6: "Show the LOF icon at the minimap" off (Peter: icon off and
--   dashboard closed left only /lof): the coin is never on the minimap
--   and shows only while the dashboard is closed (<, combat, /lof
--   hide), free on the screen (position "mini", first time at the
--   dashboard's top-right corner). Drag moves it freely; Shift-right-
--   click does nothing then and is not in the tooltip.
--   LOF.db.miniIcon.hidden now means "not at the minimap".
-- v1.12.5: The coin icon is a minimap icon (CurseForge request).
--   Always shown (setting "Show the LOF icon", LOF.db.miniIcon.hidden),
--   by default on the edge of the minimap (LOF.db.miniIcon.angle);
--   everyone starts there once. Click: dashboard open / closed;
--   right-click: Settings window; drag: along the minimap edge;
--   Shift-drag: anywhere (free, position "mini"); Shift-right-click:
--   back to the minimap. /lof reset puts it back on the minimap.
--   The dashboard's "<" only closes the dashboard. "No more Grey
--   items" -> lower case in the Make room now question.
-- v1.12.4: Released items get their own status back (Peter: a click
--   made a released upgrade "WL"). In All Items and the Swap section a
--   released upgrade (Ignored upgrades) or a reagent on normal rules:
--   click = protect it again (Unignore / keep as reagent), Shift-click
--   = whitelist permanently. Such rows show "· upg" / "· reag" after
--   the value. Plain items keep the whitelist toggle.
-- v1.12.3: Released items (Peter). All Items: a row protected as
--   "upgrade" can be clicked: the item goes on Ignored upgrades
--   (normal rules; undo with the Ignored button). The "Delete from bag"
--   card in Swap, Make room and Make room now adds "ignored upgrade" or
--   "reagent, normal rules" (resolver flags) to the grey line.
-- v1.12.2: Make room now in rounds per quality (Capture 1.7.7). Title
--   "Make room now - Grey (3 of 7)" with the quality in its colour, a
--   frame in the quality colour around the item, buttons Delete /
--   Previous / Next / Cancel (narrower, Delete keeps the plain delete
--   button). Lines under the item: teal reagent on normal rules, grey
--   "Crafting reagent - not in LOF's list", or "Cheapest item LOF may
--   delete.". Mode "roomask": "No more grey items. Continue with white
--   (common) items?" Yes / Stop, or the end text with OK.
-- v1.12.1: Make room now (LOF 1.6.0, Capture 1.7.6). Swap section
--   header: button "Room" (tooltip). /lof room. Popup mode "roomnow":
--   purple, title "Make room now (1 of 12)", the bag item, a teal line
--   when it is a profession reagent on normal rules, a grey note "One
--   item per click, so you always see what goes.", buttons Delete /
--   Next / Cancel (Next disabled on the last item).
-- v1.12.0: Settings window (LOF 1.6.0, Peter: the Settings tab kept
--   growing). The Settings page of the dashboard is gone; the Settings
--   tab opens the new window (UISettings.lua), like the Holdings tab.
--   /lof settings does the same. Kept here and shared through UI.Kit:
--   CreateCheck, DE_COLOR, ORANGE, and the help tooltips
--   (UI.ShowAuctionatorHelp / ShowDisenchantHelp /
--   ShowUpgradeAdvisorHelp). Moving leaves only the Info page.
--   SetAltAdvice / SetUpgradeAdvisor refresh the window. Info text and
--   version info updated (UISettings).
-- v1.11.1: Reagent texts (Peter: "Offer reagents for a swap" was
--   confusing). Setting "Keep profession reagents"; tooltip explains
--   kept = never deleted + offered for a swap, off = by value. All
--   Items: "Click: normal rules (this character)". Same behaviour.
-- v1.11.0: Reagents in the swap (LOF 1.6.0, Resolver 0.6.6,
--   ResolverReagents 0.1.0). Presentation only:
--   - Swap popup for swapReason REAGENT: teal tint, title "Bags full -
--     profession material?", loot card "Reagent", summary "Reagent for
--     Blacksmithing (45) - useful up to about 100" (wraps when long).
--   - All Items: a kept reagent reads "reagent" (teal); click: stop
--     keeping it for this character.
--   - Settings: new box "Reagents" with "Offer reagents for a swap" and
--     a button "Choose reagents..." (UIReagents.lua).
--   - Info: line about the teal popup. Version info lists Reagents,
--     UIReagents and Data/ProfessionReagents.
--   - RefreshNow also refreshes the Reagents window.
-- v1.10.9: 1.9.5 (tooltip stat lines, from main) merged.
-- v1.10.8: 1.9.4 (same New-card frame, from main) merged; code as 1.10.7.
-- v1.10.7: Framed New card: slot / type line ("Feet - Mail") in white
--   instead of grey (Peter).
-- v1.10.6: Upgrade popups: the New card stands out (Peter). 2 px border
--   plus a light tint in the popup colour: green for an upgrade for you,
--   orange for an upgrade for an alt; the Equipped card(s) slightly
--   dimmed. Trade-off verdicts (no tint) keep a neutral New card.
--   Presentation only (verdict / popup kind from the resolver).
-- v1.10.5: 1.9.3 (coin tooltip "Trainer at level X", from main) merged.
-- v1.10.4: Blank line between the value line ("Uses AH value" / "Uses
--   vendor value") and "Disenchant value" in the item tooltip (Peter).
--   Not when DE itself is the value used (the outcomes belong to it).
-- v1.10.3: 1.9.2 (support address, from main) merged. No other changes.
-- v1.10.2: Disenchant value on item tooltips outside the bags (Peter:
--   profession window, "is it worth making?"). Profession window, AH,
--   vendor, loot and chat links get only the disenchant lines ("LOF:
--   Disenchant value ~x", the outcomes with the price each, who can
--   disenchant it) when the resolver set info.de (conditions A-F, bound
--   by bind type). Vendor / AH prices are not repeated there.
-- v1.10.1: 1.9.1 (tabs and combat, from main) merged into the
--   disenchant version 1.10.0. No other changes.
-- v1.10.0: Disenchant value (ResolverValue 0.2.0, LOF 1.5.0). Renders
--   only what the resolver set:
--   - value source "DE" -> "(DE)" in light purple (lists, swap cards,
--     bag value tooltip);
--   - value block: "Uses disenchant value ~x" when DE won; the
--     outcomes ("80%  1-2 Strange Dust ... 3s each") and who can
--     disenchant it, also when DE did not win;
--   - dashboard bag value tooltip: "Disenchant (n items)" line;
--   - Settings, Auction House box: "Use disenchant value" check, shown
--     only when a character with Enchanting is known; disabled while
--     Auctionator prices are not active. Enchanter names under it, and
--     one rules line.
-- v1.9.5: Tooltip stat changes wrapped by LOF itself (Peter: the
--   game's word wrap lost the indent): at most 3 stats per line, each
--   line indented the same, no game wrap on these lines.
-- v1.9.4: Upgrade popups: the New card stands out (Peter). 2 px border
--   plus a light tint in the popup colour (green = upgrade for you,
--   orange = upgrade for an alt), slot / type line in white; the
--   Equipped card(s) slightly dimmed. Trade-off verdicts keep a neutral
--   New card. Presentation only.
-- v1.9.3: Coin icon tooltip shows "Trainer at level X" (grey) for a
--   profession that is ready for the next rank while the character
--   level is too low, same as the dashboard Professions tooltip (Peter:
--   Enchanting 51/75 at level 8 showed nothing).
-- v1.9.2: Support address on the Info tab is now
--   LOFCurseForge@DigitalFame.nl (Peter: one alias per channel).
-- v1.9.1: Tabs and combat (Capture 1.7.1, Peter):
--   - UI.LeaveInfoPagesOnMove(): the panel on Settings or Info goes
--     back to the LOF tab (called when you start moving).
--   - UI.IsDashboardOpen(): panel shown and not minimized (Capture
--     uses it to know what to restore after combat).
-- v1.9.0: Make room popup (Capture 1.7.0): the swap popup in mode
--   "room" with a purple background - "Bags full - make room?", the
--   cheapest safe bag item, "Frees one slot. Then try again ...",
--   Delete / WL / Cancel. Settings: box "Bags" with "Offer to make room
--   when bags are full" (Resolver.SetMakeRoomEnabled). How to use: one
--   line about it.
-- v1.8.2: Swap popup shows when the loot is an upgrade (Peter): muted
--   green background + "+x.x%" / "empty slot" next to the loot for an
--   upgrade for you; orange background + "Priestly +x.x%" / "Priestly
--   (empty slot)" for an upgrade for an alt (same colours as the
--   Upgrade popups). Otherwise the swap popup stays neutral. The bottom
--   line is unchanged (profit, or "Gear upgrade for ...").
-- v1.8.1: Info tab "How to use" mentions the Upgrade button (Send to
--   alts) for 1.4.0.
-- v1.8.0: Send to alts. Recent Loot header: Scan, Upgrade, Ignored;
--   "Upgrade" opens the Send to alts window (UIAltMail.lua). Settings,
--   Upgrade Advisor box: check "Open Send to alts at the mailbox"
--   (Resolver.Upgrade.SetAltMailAutoOpen). RefreshNow also refreshes
--   that window. Version line includes UIAltMail.
-- v1.7.0: Bigger list window (Peter): All Items / Whitelist / Ignored
--   scale with the screen, the same factor as Holdings (about 1.4 on
--   1080p). Shared helper Kit.ApplyAutoScale (moved here from
--   UIHoldings 0.8.0): 70% of the screen height for LOF's reference
--   window (Holdings, 860x538), min 1.0, max 1.6, never wider than 95%
--   of the screen. A saved position now also remembers its scale; at
--   another scale the window opens at its default spot once. Dashboard,
--   Swap and Upgrade popups keep their size.
-- v1.6.3: Orange alt popup also shows "For you: +x.x% (at level 11)"
--   when the item is an upgrade for you at a higher level
--   (verdict.futureSelf, ResolverUpgrade 0.10.2).
-- v1.6.2: "LOF: upgrade for you +x.x% (at level 14)" when only the
--   level requirement stops you (ResolverUpgrade 0.10.1).
-- v1.6.1: Upgrade lines in EVERY item tooltip (AH, vendor, loot, chat
--   links, LOF windows, bags; Peter): green "LOF: upgrade for you
--   +x.x%" with the stat changes under it ("+8 Armor  +1 Intellect",
--   down in red), orange "LOF: also for ..." / "LOF: upgrade for ..."
--   for alts (stat changes of the best alt when it is not for you).
--   Equipped items (character pane) get nothing. Data:
--   Resolver.Upgrade.GetTooltipInfo.
-- v1.6.0: Coin icon tooltip (Peter): under Free slots a dashed line,
--   then each profession with skill (green "Visit a trainer" when it can
--   be trained) and its materials in the bags ("Light Leather 10 (bank
--   20)", at most 4, "+N more"; grey "no materials"). Cooking / First
--   Aid / Fishing show only the skill. Data: Holdings.GetProfessionStatus.
-- v1.5.9: Colour language (Peter): upgrade for you = muted green
--   background, upgrade for an alt = orange, swap not worth it = red,
--   swap and trade-off = normal. The green is darker than the orange so
--   the green numbers in the table stay readable.
-- v1.5.8: Upgrade popup: own line "For you: +x.x%" above "Also an
--   upgrade for" (the title percent alone read as if it belonged to the
--   alt below). Orange popup title shows the best alt's percent:
--   "Gear upgrade for alt: +112.5%".
-- v1.5.7: Info tab "How to use" updated for 1.3.0 (weighted Upgrade
--   Advisor, alt upgrades, Holdings tab click, Gear for alts, advice
--   per character / alt in Settings).
-- v1.5.6: Upgrade Advisor per character (idea Nick): Settings shows
--   "Show upgrade advice" for the character you play (grey line "This
--   character: <name>") and below "Also advise for these alts:" one
--   check box per other character of the scope (class colour, class +
--   level). Alt boxes are grey while the main switch is off. Renders
--   Resolver.Upgrade.GetAdvisorSettings(); clicks go to SetEnabled /
--   SetAltEnabled. /lof upgrade on|off: this character.
-- v1.5.5: Holdings tab tooltip: orange line about Gear for alts
--   ("Check for possible Gear for alts: ...", wording by Peter).
-- v1.5.4: Holdings tab = shortcut (Peter): clicking the tab opens /
--   closes the Holdings window directly; the dashboard stays on the
--   page it was on. The explanation and the read times (characters,
--   bags read, bank read) moved to the tab's tooltip. The Holdings page
--   with the Query button is gone.
-- v1.5.3: Ignored upgrades list also shows the per-character ignores
--   from Holdings "Gear for alts" ("for <name>"); a click removes that
--   one ignore (Resolver.Upgrade.UnignoreFor).
-- v1.5.2: Reason TIE_BETTER_STATS: "Same score; better on stats that
--   do not count in the weights." (ResolverUpgrade 0.7.2).
-- v1.5.1: Bag tooltip: one orange line at the bottom when the item is
--   an upgrade for alts (Resolver.Upgrade.GetBagItemAltUpgrades):
--   "LOF: upgrade for Julian +12.3%, Soumix (empty slot)", at most three
--   names + "and N more", "(at level X)" when the alt is too low.
--   Independent of the Auctionator value line.
-- v1.5.0: Alt upgrades (ResolverUpgrade 0.7.0, Resolver 0.6.0).
--   - Upgrade for you AND for alts (popupKind SELF): extra lines under
--     the notes, "Also an upgrade for:" + one line per alt (class
--     colour, +x.x% or "empty slot", spec basis, "at level X").
--   - Only an upgrade for alts (popupKind ALT): a separate popup with
--     an orange background and orange title "Gear upgrade for alt",
--     the alt lines at the top, the stat table against the best alt's
--     gear (card label "Worn by <name>"), buttons OK and Ignore (no
--     Equip). Own saved position.
--   - Swap popup: loot that is an upgrade for an alt shows "Alt
--     upgrade"; swap reason GEAR_ALT reads "Gear upgrade for <name> -
--     worth more than X to you" in orange.
--   Everything shown before stays.
-- v1.4.0: Upgrade popup with stat weights (ResolverUpgrade 0.6.0):
--   title "Upgrade found: +8.3%" (percent from the weighted score),
--   under the table "Based on: Retribution (11 points)" or a mix
--   "Retribution 55% / Holy 45%" (default tree below level 10: "class
--   default, no talent points yet"), and "Effects not counted" when an
--   item has Equip / Use / proc effects. Everything shown before stays.
--   Version info lists Data/StatWeights.
-- v1.3.3: Inventory header: "Professions" next to the collapse button,
--   tooltip with each profession and skill (Resolver.Holdings.
--   GetProfessionStatus): white, green "Visit a trainer", or grey
--   "Trainer at level X". The word turns green when something can be
--   trained now. Hidden when the character has no professions.
-- v1.3.2: Dashboard 20px wider (320) for the coin icons in the rows.
-- v1.3.1: All money in the WoW coin format via LOF.FormatMoney (Core
--   0.3.0); FormatMoneyShort is gone.
-- v1.3.0: Holdings (LOF 1.1.2, phase 1). New tab "Holdings" (second
--   tab) with a short explanation, when bags/bank were last read and a
--   "Query" button that opens the Holdings window (UIHoldings.lua).
--   UI.Kit exposes the shared building blocks (styled panel, inset,
--   buttons, tooltip helpers, colours) to UIHoldings.lua. RefreshNow
--   also refreshes the Holdings window. Slash: /lof holdings. Version
--   info includes Holdings resolver + window.
-- v1.2.6: Settings tab: second box "Upgrade Advisor" with the check box
--   "Show upgrade advice" (Resolver.Upgrade.IsEnabled / SetEnabled) and
--   a tooltip that lists what "off" turns off. Turning it off closes an
--   open upgrade popup. The Scan button in Recent Loot is disabled
--   (grey, tooltip "Upgrade Advisor is off") while the Advisor is off.
--   /lof upgrade on|off keeps the check box and Scan button in sync.
-- v1.2.5: Swap popup for gear upgrades (Resolver 0.4.8): the loot card
--   reads "Upgrade" (green) or "Trade-off" (gold) instead of the value
--   when lootItem.gearVerdict says so. When the swap is offered because
--   of the gear (swapReason GEAR), the summary reads "Gear upgrade -
--   worth more than X to you" (or "Gear trade-off - ...").
-- v1.2.4: Recent Loot header holds the Upgrade Advisor buttons:
--   "Scan" (check bags for upgrades, quiet mode) and "Ignored" (moved
--   from the Swap header, which keeps All Items and WL). Header button
--   show/hide is generic (section.headerButtons).
-- v1.2.3: Upgrade popup: "Effects" block under the stat table with the
--   exact Equip / Use / Chance on hit text from Blizzard's tooltip, for
--   the new item and the equipped item(s), in the effect green. Only
--   shown when one of them has an effect; the popup grows with it.
-- v1.2.2: "Possible bag value" became "Possible total" (gold + bag
--   value), so it compares directly with Total (gold + vendor). The
--   tooltip starts with "+X compared to Total" and shows the possible
--   bag value with its AH / vendor split and top 10. Coin icon too.
-- v1.2.1: Swap popup for quest loot: the summary reads "Quest item -
--   worth more than 7c to you" instead of a red "Profit -7c" (the swap
--   is offered because you need the item, not for its value).
-- v1.2.0: Swap popup mode "left" (LOOT LEFT BEHIND): red alert border,
--   item card, "Your bag slot is free. Open the corpse again: LOF will
--   loot it for you automatically.", OK only, no countdown.
--   UI.ShowLeftBehindPopup / UI.HideLeftBehindPopup. HideSwapPopup no
--   longer hides this mode (only the safety net itself closes it, or
--   the player with OK / X).
-- v1.1.9: Settings: tooltip on "Use Auctionator prices" for first-time
--   users: what it does, Auctionator required (detected / not
--   installed), run a full scan regularly (one per 15 min), freshness
--   bands from the data layer, what "off" means. Works while the check
--   box is disabled; clicks on the label toggle the check box.
-- v1.1.8: Swap popup in Forever look & feel (like the dashboard):
--   Blizzard panel with the coin portrait, item cards with 40px icons
--   and quality border (shared with the upgrade popup), quality/count
--   sub line, value with (V)/(AH) on the card, card tooltip with the LOF
--   value block, larger buttons (100x24), X = Wait/Cancel/OK. All three
--   modes (decide / destroy / not worth) use it; the red alert border
--   stays for "not worth". Swap / Swap anyway stay template-free
--   buttons. Default position a bit higher (above the loot window).
-- v1.1.7: Inventory order Gold / Vendor / Total (guaranteed: gold +
--   vendor) / gap / "Possible bag value" / Session / Free slots. The
--   bag value tooltip starts with the difference compared to vendor.
-- v1.1.6: Inventory gets "Bag value" (only while the Auctionator
--   integration is active), order Gold / Vendor / Bag value / Total /
--   Session / Free slots. Hover on Bag value: AH part and vendor part
--   (value + item count) and the 10 most valuable items with (AH)/(V).
--   Coin icon tooltip shows Bag value too. Rendered from the snapshot;
--   Total is computed in the resolver.
-- v1.1.5: The AH age "(1 day)" now has the freshness colour too, like
--   the amount (green / orange / red).
-- v1.1.4: Value text as a small block instead of one wrapping line:
--   blank line, "LOF: White item" (the why), then a double line
--   "Uses vendor value ........ 20 x 15c = 3s" with the amount right
--   aligned like Auctionator's lines. AH data too old shows in red on
--   the first line.
-- v1.1.3: Tooltip value text reworked (evaluated with Peter): the
--   vendor / AH price lines are gone (Blizzard "Sell Price" and
--   Auctionator already show them). One line, same in the bag tooltip
--   and in LOF's windows, says which value LOF uses and why, e.g.
--   "LOF: White item, uses vendor value 17 x 1c = 17c",
--   "LOF: Green item, uses AH value 37c (today)",
--   "LOF: Soulbound / No AH price / AH data too old / AH below vendor,
--   uses vendor value ...". Quality word in quality colour, AH amount
--   in freshness colour; stacks show count x each = total.
-- v1.1.2: Bag tooltip line (only when the Auctionator integration is
--   active): "LOF: 37c (AH price is used)" with the amount in the
--   freshness colour, or "LOF: 7c (Vendor price is used)". Hooked via
--   TooltipDataProcessor (getter GetBagItem), fallback
--   hooksecurefunc(GameTooltip, "SetBagItem"). Value from
--   Resolver.GetBagSlotInfo; LOF's own windows are not affected.
-- v1.1.1: Settings tab: "Last AH visit" became "AH prices updated:
--   today 15:52 / yesterday / N days ago" (freshness colour, "scan the
--   auction house" when too old, "never" without an update yet).
-- v1.1.0: Auctionator integration (LOF 1.1.0).
--   - Third tab "Settings" (tabs: LOF / Settings / Info): Use
--     Auctionator prices, Auctionator status, last AH visit, value
--     source per quality (Vendor / AH) and the value rules in text.
--     Clicks go to Resolver.Value setters; nothing is decided here.
--   - Values show their source: "(V)" or "(AH)", AH coloured by the
--     freshness code (green / orange / red).
--   - Item tooltips (panel, lists, popups) get a value block: vendor
--     price, AH price + age, which value is used and why (reason code
--     -> text template VALUE_REASON_TEXT).
--   - Swap / "Not worth" popups show a note when AH data is too old.
--   - Version info includes ResolverValue and PriceRules.
-- v1.0.0: First public release (CurseForge). Removed the diagnostic
--   delete probe window and the /lof probe and /lof bags commands.
--   Name "LootOptimizer Forever" in panel title, Info page and icon.
-- v0.8.0: Tabs under the dashboard (Blizzard tab template): "LOF" and
--   "Info". Info page: About, How to use, Support with copyable e-mail
--   (loflite@digitalfame.nl) and copyable version info.
-- v0.7.4: "Not worth a swap" / "Nothing to swap" stand out: thick red
--   border, warning icon, large red title, loot value red vs bag value
--   green, "you would lose X", OK primary, auto-close after 6s (paused
--   while the mouse is over the popup).
-- v0.7.3: /lof bags diagnostic (bag index, name, slots, free, family).
-- v0.7.2: Swap and "Swap anyway" are template-free buttons
--   (CreatePlainButton): the probe proved DeleteCursorItem works from a
--   plain Button but not from the UIPanelButtonTemplate Swap button.
-- v0.7.1: Probe lists gear (weapons/armor) first.
-- v0.7.0: Delete probe window (/lof probe, diagnostic): swap candidates
--   as rows, one click destroys that item via Capture.ProbeDestroy.
-- v0.6.1: "<" button raised above the template border (was hidden
--   behind the NineSlice, but still clickable).
-- v0.6.0: Dashboard in Forever look & feel: portrait frame with coin
--   icon, title "LOF Lite vX", three inset sections with gold headers
--   and +/- collapse buttons, 28px item icons with quality border,
--   width 300. "<" sits where the X was. Template helpers moved above
--   the panel code (local scope order). Fallback to plain frames.
-- v0.5.0: "<" minimizes the panel to a draggable coin icon with a
--   free-slot counter (red at 0) and a Gold / Vendor / Free slots
--   tooltip; click restores. State in LOF_DB.minimized, own position
--   ("mini"). UI.ApplyVisibility decides panel vs icon. /lof mini.
-- v0.4.2: "Ignored" button next to WL in the panel (opens the ignored
--   upgrades list, same as /lof ignored).
-- v0.4.1: Second "Equipped" card for two-handers (main hand + off-hand);
--   REPLACES_BOTH note replaces OFFHAND_LOST.
-- v0.4.0: Upgrade popup rebuilt in Forever look & feel (pilot): Blizzard
--   panel template when available (ButtonFrameTemplate, fallback to the
--   LOF backdrop), item cards with 40px icons and quality border, stat
--   table Stat / Equipped / New / Change, larger buttons, X = Cancel.
-- v0.3.1: Upgrade popup gets a Cancel button (decide later, not ignored).
-- v0.3.0: Upgrade popup (UI.ShowUpgradePopup): equipped vs loot, reason
--   codes rendered via templates (REASON_TEXT / HINT_TEXT), Equip /
--   Ignore. List mode "ignored". Slash: /lof upgrade on|off|scan,
--   /lof ignored.
-- v0.2.2: Whitelist list shows default tools (blue "default", item
--   icon and tooltip); whitelist toggles pass the itemID.
-- v0.2.1: Third popup mode "info" (UI.ShowInfoPopup): not worth a
--   swap (loot vs cheapest bag item, Swap anyway / OK) or nothing in
--   the bags may be swapped (OK only).
-- v0.2.0: Swap popup has a second mode: destroy instructions with a
--   Cancel button (phase 2 of the swap, UI.ShowDestroyInstructions).
-- v0.1.1: Swap rows in the panel are now clickable (click = WL this
--   session, Shift-click = permanent, click again = remove). Shared
--   toggle for panel and All Items list. Panel title reads the addon
--   version from the .toc instead of Core.
-- v0.1.0: Initial version (LOF Lite).
--   - Panel with 3 collapsible sections: Inventory, Swap, Recent Loot.
--   - Swap decision popup (Swap / WL / Wait).
--   - List popup for All Items and Whitelist.
--   - Slash commands under /lof.
-- =============================================================

local LOF = LOF
LOF.VERSION_UI = "1.17.26"

-- The .toc is the single source for the addon version.
do
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local tocVersion = getMeta and getMeta(LOF.ADDON_NAME, "Version")
    if tocVersion and tocVersion ~= "" then
        LOF.VERSION = tocVersion
    end
end

local UI = {}
LOF.UI = UI

local Resolver = LOF.Resolver

local ROW_HEIGHT  = 18
local PAD         = 10

local GOLD  = "|cffffd100"
local GREEN = "|cff66ff66"
local RED   = "|cffff6666"
local GREY  = "|cff9d9d9d"
local ORANGE = "|cffff9933"
local TEAL   = "|cff33d6c2"   -- v1.11.0: profession reagent
local WHITE  = "|cffffffff"   -- v1.17.4: one white for every UI file (Kit.WHITE)

-- -------------------------------------------------------------
-- v1.16.0: POPUP STYLES - the ONE place for the colour language of
-- every popup (swap, make room, not worth a swap, upgrade) and of the
-- Guide's Colors tab. Presentation only: which style a popup gets is
-- read from the resolver's decision (swapReason, verdict, quality).
--   head   : word(s) in capitals at the start of the title
--   border : r, g, b of the thick border
--   tint   : r, g, b, a of the background
--   card   : r, g, b of the frame around the item card (default border)
--   quality: border / tint / card follow Blizzard's item quality colour
--            (tint alpha tintLow for grey / white, else tint alpha)
-- -------------------------------------------------------------
local POPUP_STYLES = {
    gear     = { head = "GEAR UPGRADE",   headRGB = { 1, 1, 1 }, quality = true, tintLow = 0.16, tintHigh = 0.30 },
    tradeoff = { head = "GEAR TRADE-OFF", headRGB = { 1, 1, 1 }, quality = true, tintLow = 0.10, tintHigh = 0.18 },
    alt      = { head = "ALT UPGRADE",  border = { 1, 0.5, 0 },        tint = { 1, 0.45, 0, 0.30 },        card = { 1, 0.6, 0.15 } },
    quest    = { head = "QUEST ITEM",   border = { 1, 0.82, 0 },       tint = { 1, 0.82, 0, 0.12 } },
    reagent  = { head = "REAGENT",      border = { 0.1, 0.65, 0.6 },   tint = { 0.1, 0.65, 0.6, 0.30 } },
    room     = { head = "MAKE ROOM",    border = { 0.72, 0.45, 0.20 }, tint = { 0.72, 0.45, 0.20, 0.34 } },
    roomnow  = { head = "MAKE ROOM NOW", border = { 0.72, 0.45, 0.20 }, tint = { 0.72, 0.45, 0.20, 0.34 } },
    notworth = { border = { 1, 0.12, 0.12 },       tint = { 1, 0.12, 0.12, 0.30 } },   -- v1.17.14
    plain    = {},
}

local function RGBCode(rgb)
    return string.format("|cff%02x%02x%02x", math.floor(rgb[1] * 255 + 0.5),
        math.floor(rgb[2] * 255 + 0.5), math.floor(rgb[3] * 255 + 0.5))
end

-- -------------------------------------------------------------
-- v1.17.0: shared text / list helpers (Kit) - the only copies.
-- -------------------------------------------------------------
-- A name in its class colour.
local function ClassColored(name, class)
    local c = class and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class]
    if c and c.colorStr then
        return "|c" .. c.colorStr .. tostring(name) .. "|r"
    end
    return tostring(name)
end

-- Gain of an upgrade: t = { emptySlot, percent } (resolver fields).
-- color: colour code; fallback: text without percentage ("" = nothing);
-- prefix: optional name in front ("Priestly +3.5%").
local function GainText(t, color, fallback, prefix)
    t = t or {}
    color = color or GREEN
    local body
    if t.emptySlot then
        body = prefix and (prefix .. " (empty slot)") or "empty slot"
    elseif t.percent then
        body = (prefix and (prefix .. " ") or "") .. string.format("+%.1f%%", t.percent)
    else
        if fallback == "" then return "" end
        body = fallback or "upgrade"
    end
    return color .. body .. "|r"
end

-- Pooled frames: pool = { used = 0 }; create(...) builds a new one.
local function GetPooled(pool, create, ...)
    pool.used = pool.used + 1
    local f = pool[pool.used]
    if not f then
        f = create(...)
        pool[pool.used] = f
    end
    f:Show()
    return f
end

local function HidePool(pool)
    for i = pool.used + 1, #pool do pool[i]:Hide() end
end

local BACKDROP = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- -------------------------------------------------------------
-- Generic helpers
-- -------------------------------------------------------------
local function SavePosition(frame, key)
    local point, _, _, x, y = frame:GetPoint(1)
    LOF.db.frames[key] = { point = point, x = x, y = y, scale = frame:GetScale() }
end

local function RestorePosition(frame, key, defPoint, defX, defY)
    local p = LOF.db.frames[key]
    frame:ClearAllPoints()
    if p and p.point then
        frame:SetPoint(p.point, UIParent, p.point, p.x or 0, p.y or 0)
    else
        frame:SetPoint(defPoint, UIParent, defPoint, defX, defY)
    end
end

-- v1.7.0: screen-relative scale for the bigger LOF windows (layout
-- only). One factor for all of them, so they keep their proportions.
local AUTO_REF_W, AUTO_REF_H = 860, 538   -- reference: Holdings window
local AUTO_FRACTION = 0.70
local AUTO_MIN, AUTO_MAX = 1.0, 1.6

local function AutoScale()
    local h = UIParent:GetHeight() or 0
    local w = UIParent:GetWidth() or 0
    if h <= 0 or w <= 0 then return 1 end
    local s = math.min(h * AUTO_FRACTION / AUTO_REF_H, w * 0.95 / AUTO_REF_W)
    if s < AUTO_MIN then s = AUTO_MIN end
    if s > AUTO_MAX then s = AUTO_MAX end
    return math.floor(s * 100 + 0.5) / 100
end

local function ApplyAutoScale(frame, key, defPoint, defX, defY)
    local s = AutoScale()
    local p = LOF.db.frames[key]
    if p and math.abs((p.scale or 1) - s) > 0.005 then
        LOF.db.frames[key] = nil   -- saved at another scale: default spot
    end
    frame:SetScale(s)
    RestorePosition(frame, key, defPoint, defX, defY)
end

local function CreatePanel(name, key, width, height, strata)
    local f = CreateFrame("Frame", name, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(width, height)
    f:SetFrameStrata(strata or "MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self, key)
    end)
    if f.SetBackdrop then
        f:SetBackdrop(BACKDROP)
        f:SetBackdropColor(0, 0, 0, 0.85)
        f:SetBackdropBorderColor(0.7, 0.55, 0.15, 1)
    end
    f.positionKey = key
    return f
end

local function CreateButton(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 60, 18)
    b:SetText(text)
    local fs = b:GetFontString()
    if fs then fs:SetFontObject("GameFontNormalSmall") end
    return b
end

-- v0.7.2: template-free button with the same red look. Used for every
-- button that destroys an item: on Forever DeleteCursorItem was blocked
-- from a UIPanelButtonTemplate click but allowed from a plain Button
-- (the probe rows), same item, same situation.
local function CreatePlainButton(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 60, height or 18)
    b:RegisterForClicks("LeftButtonUp")

    b:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
    b:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight", "ADD")
    for _, t in ipairs({ b:GetNormalTexture(), b:GetPushedTexture(), b:GetHighlightTexture() }) do
        if t then t:SetTexCoord(0, 0.625, 0, 0.6875) end
    end

    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER", b, "CENTER", 0, 1)
    fs:SetText(text)
    b:SetFontString(fs)
    return b
end

local function CreateDivider(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    t:SetColorTexture(0.7, 0.55, 0.15, 0.9)
    return t
end

-- -------------------------------------------------------------
-- Value presentation (v1.1.0). Renders the fields and codes set by
-- Resolver.Value; the rules themselves are not repeated here.
-- -------------------------------------------------------------
local FRESHNESS_COLOR = {
    FRESH = "|cff66ff66",   -- green
    AGING = "|cffff9933",   -- orange
    OLD   = "|cffff4444",   -- red
    STALE = "|cffff4444",   -- red (not used)
}

-- v1.10.0: disenchant value colour (light purple)
local DE_COLOR = "|cffc69bff"

local function AgeText(ageDays)
    local d = tonumber(ageDays)
    if d == nil then return "21+ days" end
    if d == 0 then return "today" end
    if d == 1 then return "1 day" end
    return d .. " days"
end

-- "12s 50c (V)" / "1g 20s (AH)". amountColor is optional; the AH tag
-- carries the freshness colour.
local function ValueText(item, amountColor)
    local amount = LOF.FormatMoney(item and item.value or 0)
    if amountColor then amount = amountColor .. amount .. "|r" end
    if item and item.valueSource == "AH" then
        local c = FRESHNESS_COLOR[item.freshness] or ""
        return amount .. " " .. c .. "(AH)" .. (c ~= "" and "|r" or "")
    end
    if item and item.valueSource == "DE" then
        return amount .. " " .. DE_COLOR .. "(DE)|r"
    end
    return amount .. " " .. (amountColor or "") .. "(V)" .. (amountColor and "|r" or "")
end

local function IsIntegrationReason(reason)
    return reason ~= nil and reason ~= "AH_OFF" and reason ~= "AH_UNAVAILABLE"
end

-- Adds the value block to GameTooltip (only when the integration is on).
-- Quality words for the value line (presentation only).
local QUALITY_WORD = {
    [0] = "Grey", [1] = "White", [2] = "Green", [3] = "Blue",
    [4] = "Purple", [5] = "Orange",
}

-- Amount part: "7c" for one item, "17 x 1c = 17c" for a stack.
local function ValueAmountText(v, color)
    local count = math.max(1, tonumber(v.count or 1) or 1)
    local total = LOF.FormatMoney(v.value or 0)
    local text
    if count > 1 then
        text = count .. " x " .. LOF.FormatMoney(v.valueEach or 0) .. " = " .. total
    else
        text = total
    end
    if color and color ~= "" then text = color .. text .. "|r" end
    return text
end

-- v1.1.4: which value LOF uses and why, as a small block (same in the
-- bag tooltip and in LOF's own windows):
--   (blank line)
--   LOF: White item
--   Uses vendor value              20 x 15c = 3s
-- Returns header, label, amount; nil when the Auctionator integration
-- is off (LOF then always uses vendor value).
local function BuildValueBlock(v)
    if not v or not IsIntegrationReason(v.valueReason) then return nil end
    local head = GOLD .. "LOF:|r "
    if (tonumber(v.value or 0) or 0) <= 0 then
        return head .. "No vendor or AH value", nil, nil
    end
    local r = v.valueReason
    local q = tonumber(v.quality)
    local qualityWord = LOF.ColorizeName(QUALITY_WORD[q] or "This", q) .. " item"
    if r == "DE_USED" then
        return head .. qualityWord, "Uses disenchant value",
            DE_COLOR .. "~" .. ValueAmountText(v) .. "|r"
    end
    if r == "AH_USED" then
        local c = FRESHNESS_COLOR[v.freshness] or ""
        return head .. qualityWord, "Uses AH value",
            c .. ValueAmountText(v) .. " (" .. AgeText(v.ahAgeDays) .. ")" .. (c ~= "" and "|r" or "")
    end
    local reason
    if r == "QUALITY_VENDOR" then
        reason = qualityWord
    elseif r == "SOULBOUND" then
        reason = "Soulbound"
    elseif r == "NO_AH_DATA" then
        reason = "No AH price"
    elseif r == "AH_STALE" then
        reason = RED .. "AH data too old - scan the AH|r"
    elseif r == "AH_BELOW_VENDOR" then
        reason = "AH price below vendor"
    else
        return nil
    end
    return head .. reason, "Uses vendor value", ValueAmountText(v)
end

-- v1.10.0: "80%" / "99.5%" and "1" / "1-2" (presentation only)
local function ChanceText(chance)
    local p = (tonumber(chance) or 0) * 100
    if math.abs(p - math.floor(p + 0.5)) < 0.05 then
        return string.format("%d%%", math.floor(p + 0.5))
    end
    return string.format("%.1f%%", p)
end

local function CountRangeText(min, max)
    if not max or max == min then return tostring(min or 1) end
    return tostring(min) .. "-" .. tostring(max)
end

-- v1.10.0: disenchant lines under the value block (v.de from the
-- resolver). The value line only when DE did not win (else it is the
-- block's own line).
local function AddDisenchantLines(tip, v, noValueLine)
    local de = v and v.de
    if not de then return end
    if v.valueReason ~= "DE_USED" and not noValueLine then
        tip:AddLine(" ")   -- v1.10.4
        tip:AddDoubleLine("Disenchant value", GREY .. "~" .. LOF.FormatMoney(de.stack or de.each or 0) .. "|r",
            0.8, 0.8, 0.8, 1, 1, 1)
    end
    for _, o in ipairs(de.outcomes or {}) do
        local left = "   " .. ChanceText(o.chance) .. "  " .. CountRangeText(o.min, o.max) .. " " .. tostring(o.name)
        local right
        if o.priced then
            right = LOF.FormatMoney(o.priceEach or 0) .. " each"
        else
            right = GREY .. "no AH price|r"
        end
        tip:AddDoubleLine(left, right, 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
    end
    if de.byCurrent then
        tip:AddLine("   You can disenchant this.", 0.78, 0.61, 1)
    elseif de.by then
        tip:AddLine("   Disenchant on: " .. tostring(de.by), 0.78, 0.61, 1)
    end
end

-- Adds the block to a tooltip; returns true when something was added.
local function AddValueBlock(tip, v)
    local header, label, amount = BuildValueBlock(v)
    if not header then return false end
    tip:AddLine(" ")
    tip:AddLine(header, 1, 1, 1)
    if label then
        tip:AddDoubleLine(label, amount, 1, 1, 1, 1, 1, 1)
    end
    AddDisenchantLines(tip, v)
    return true
end

local function AddValueLines(v)
    AddValueBlock(GameTooltip, v)
end

local function ShowItemTooltip(self)
    if not self.link then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(self.link)
    AddValueLines(self.valueInfo)
    if self.hint then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(self.hint, 0.6, 0.8, 1, true)
    end
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

-- Item row: [icon] name ......... value
local function CreateItemRow(parent, width)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)

    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.value:SetJustifyH("RIGHT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.name:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row:SetScript("OnEnter", ShowItemTooltip)
    row:SetScript("OnLeave", HideTooltip)
    row:SetScript("OnClick", function(self)
        if self.onClick then self.onClick(self) end
    end)
    return row
end

-- Click = whitelist for this session, Shift-click = permanent,
-- click on a whitelisted item = remove. Used by panel and list rows.
local function MakeWhitelistToggle(itemName, itemID)
    return function()
        if Resolver.IsWhitelisted(itemName, itemID) then
            Resolver.RemoveFromWhitelist(itemName, itemID)
        else
            Resolver.AddToWhitelist(itemName, IsShiftKeyDown())
        end
        LOF.RequestRefresh()
    end
end

-- v1.12.4: an item the player released from protection (resolver flags
-- ignoredUpgrade / reagentOff): click = protect it again, Shift-click =
-- whitelist permanently. Returns hint, onClick, mark (nil for others).
local function ReleasedRowAction(item)
    if not (item.ignoredUpgrade or item.reagentOff) then return nil end
    local itemID, itemName = item.itemID, item.name
    local hint, marks = {}, {}
    if item.ignoredUpgrade then
        hint[#hint + 1] = "Released upgrade (Ignored upgrades)."
        marks[#marks + 1] = "upg"
    end
    if item.reagentOff then
        hint[#hint + 1] = "Profession reagent on normal rules."
        marks[#marks + 1] = TEAL .. "reag|r"
    end
    local text = table.concat(hint, " ") .. " Click: protect it again. Shift-click: whitelist permanently."
    local ignored, reagentOff = item.ignoredUpgrade, item.reagentOff
    local onClick = function()
        if IsShiftKeyDown() then
            Resolver.AddToWhitelist(itemName, true)
        else
            if ignored then Resolver.Upgrade.Unignore(itemID) end
            if reagentOff then Resolver.Reagents.SetChoice(itemID, true) end
            Resolver.InvalidateCache()
        end
        LOF.RequestRefresh()
    end
    return text, onClick, GREY .. " · |r" .. table.concat(marks, GREY .. ", |r")
end

local WL_HINT_ADD    = "Click: whitelist this session. Shift-click: permanent."
local WL_HINT_REMOVE = "Click to remove from whitelist."

local function FillItemRow(row, name, quality, icon, count, valueText, link)
    row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local label = LOF.ColorizeName(name, quality)
    if (tonumber(count or 1) or 1) > 1 then
        label = label .. GREY .. " x" .. count .. "|r"
    end
    row.name:SetText(label)
    row.value:SetText(valueText or "")
    row.link = link
    row.valueInfo = nil
    row:Show()
end

-- -------------------------------------------------------------
-- Blizzard template helpers (shared by panel and popups)
-- -------------------------------------------------------------
-- Blizzard templates, most preferred first. Checked at runtime so a
-- beta change never breaks LOF.
local PANEL_TEMPLATES = { "ButtonFrameTemplate", "BasicFrameTemplateWithInset" }

local function TemplateExists(name)
    local C_XMLUtil = _G.C_XMLUtil
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        return C_XMLUtil.GetTemplateInfo(name) ~= nil
    end
    return false
end

local function CreateStyledPanel(name, key, width, height, strata, keepPortrait)
    local template
    for _, t in ipairs(PANEL_TEMPLATES) do
        if TemplateExists(t) then template = t break end
    end
    if not template then
        local f = CreatePanel(name, key, width, height, strata)
        f.styled = false
        return f
    end

    local f = CreateFrame("Frame", name, UIParent, template)
    f:SetSize(width, height)
    f:SetFrameStrata(strata or "DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self, key)
    end)
    if template == "ButtonFrameTemplate" then
        if not keepPortrait and ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(f) end
        if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(f) end
    end
    f.template = template
    f.positionKey = key
    f.styled = true
    return f
end

local function SetPanelTitle(f, text)
    if f.SetTitle then
        f:SetTitle(text)
    elseif f.TitleText then
        f.TitleText:SetText(text)
    elseif f.TitleContainer and f.TitleContainer.TitleText then
        f.TitleContainer.TitleText:SetText(text)
    else
        if not f.lofTitle then
            f.lofTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            f.lofTitle:SetPoint("TOP", f, "TOP", 0, -8)
        end
        f.lofTitle:SetText(text)
    end
end

local function GetQualityRGB(quality)
    local c = _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[tonumber(quality) or -1]
    if c then return c.r, c.g, c.b end
    return 0.6, 0.6, 0.6
end


-- -------------------------------------------------------------
-- Main panel (v0.6.0, Forever look & feel)
-- Portrait frame with coin icon, title "LOF Lite vX", three inset
-- sections (Inventory / Swap / Recent Loot), each collapsible.
-- Falls back to plain LOF frames when a template is missing.
-- -------------------------------------------------------------
local panel
local sections = {}
local SECTION_ORDER = { "inventory", "swap", "recent" }

local STYLED_WIDTH   = 320
local SECTION_GAP    = 6
local SECTION_HEAD_H = 28
local ITEM_ROW_H     = 32
local ITEM_ICON      = 28
local LABEL_ROW_H    = 17
local LABEL_GAP      = 6    -- extra space around "Possible total"
local COIN_ICON      = "Interface\\Icons\\INV_Misc_Coin_02"

local function IsCollapsed(key)
    return LOF.db.collapsed[key] == true
end

-- Inset box like the profession window sections.
local function CreateInset(parent)
    local box
    if TemplateExists("InsetFrameTemplate") then
        box = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    else
        box = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        if box.SetBackdrop then
            box:SetBackdrop(BACKDROP)
            box:SetBackdropColor(0, 0, 0, 0.5)
            box:SetBackdropBorderColor(0.5, 0.4, 0.2, 1)
        end
    end
    return box
end

-- Small +/- tree button (collapse / expand a section)
local function CreateCollapseButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(14, 14)
    b:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
    function b:SetCollapsed(collapsed)
        local tex = collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up"
        self:SetNormalTexture(tex)
        self:SetPushedTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Down" or "Interface\\Buttons\\UI-MinusButton-Down")
    end
    b:SetCollapsed(false)
    return b
end

-- Item row with a 28px icon and quality border (profession-list style)
local function CreateStyledItemRow(parent, width)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, ITEM_ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ITEM_ICON, ITEM_ICON)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)

    row.border = row:CreateTexture(nil, "OVERLAY")
    row.border:SetTexture("Interface\\Common\\WhiteIconFrame")
    row.border:SetAllPoints(row.icon)

    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.value:SetJustifyH("RIGHT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.name:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row:SetScript("OnEnter", ShowItemTooltip)
    row:SetScript("OnLeave", HideTooltip)
    row:SetScript("OnClick", function(self)
        if self.onClick then self.onClick(self) end
    end)
    return row
end

local function FillStyledItemRow(row, name, quality, icon, count, valueText, link)
    row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.border:SetVertexColor(GetQualityRGB(quality))
    row.border:SetShown(quality ~= nil)
    local label = LOF.ColorizeName(name, quality)
    if (tonumber(count or 1) or 1) > 1 then
        label = label .. GREY .. " x" .. count .. "|r"
    end
    row.name:SetText(label)
    row.value:SetText(valueText or "")
    row.link = link
    row.valueInfo = nil
end

-- v1.3.0: shared building blocks for UIHoldings.lua (presentation only).
UI.Kit = {
    CreateStyledPanel = CreateStyledPanel,
    SetPanelTitle     = SetPanelTitle,
    CreateInset       = CreateInset,
    CreateButton      = CreateButton,
    CreateDivider     = CreateDivider,
    RestorePosition   = RestorePosition,
    ApplyAutoScale    = ApplyAutoScale,
    HideTooltip       = HideTooltip,
    GetQualityRGB     = GetQualityRGB,
    AddValueLines     = AddValueLines,
    AgeText           = AgeText,
    FRESHNESS_COLOR   = FRESHNESS_COLOR,
    GOLD = GOLD, GREEN = GREEN, RED = RED, GREY = GREY,
    TEAL = TEAL,   -- v1.11.0
    ORANGE = ORANGE, DE_COLOR = DE_COLOR,   -- v1.12.0
    POPUP_STYLES = POPUP_STYLES, RGBCode = RGBCode,   -- v1.16.0
    ClassColored = ClassColored, GainText = GainText,   -- v1.17.0
    WHITE = WHITE,   -- v1.17.4
    GetPooled = GetPooled, HidePool = HidePool,
}

local function CreateSection(key, title, rowParentWidth)
    local s = { key = key, rows = {} }
    s.box = CreateInset(panel.content)
    s.header = s.box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    s.header:SetPoint("TOPLEFT", s.box, "TOPLEFT", 10, -9)
    s.header:SetText(title)
    s.toggle = CreateCollapseButton(s.box)
    s.toggle:SetPoint("LEFT", s.header, "RIGHT", 6, 0)
    s.toggle:SetScript("OnClick", function()
        LOF.db.collapsed[key] = not IsCollapsed(key) or nil
        UI.Layout()
    end)
    s.innerWidth = rowParentWidth
    sections[key] = s
    return s
end

local function CreateLabelRow(parent)
    local r = {}
    r.label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.label:SetJustifyH("LEFT")
    r.value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.value:SetJustifyH("RIGHT")
    return r
end

local function SetPortraitIcon(f, texturePath)
    if f.SetPortraitToAsset then
        f:SetPortraitToAsset(texturePath)
        return
    end
    local tex = f.portrait or (f.PortraitContainer and f.PortraitContainer.portrait)
    if tex then
        if SetPortraitToTexture then
            SetPortraitToTexture(tex, texturePath)
        else
            tex:SetTexture(texturePath)
        end
    end
end

-- -------------------------------------------------------------
-- Tabs + Info page (v0.8.0) + Settings page (v1.1.0)
-- Blizzard-style tabs under the panel: "LOF" (dashboard), "Settings"
-- (Auctionator integration) and "Info" (about, a Guide button, and
-- support: website, Discord, mail and version info to copy).
-- -------------------------------------------------------------
local TAB_TEMPLATES = { "PanelTabButtonTemplate", "CharacterFrameTabButtonTemplate" }

local INFO_ABOUT = "LootOptimizer Forever helps when your bags are full. It compares the loot "
    .. "with the cheapest item in your bags (vendor value, or auction house value with "
    .. "Auctionator) and swaps them with one click. It also tells you when new gear is "
    .. "an upgrade."

-- v1.13.0: markup of Data/Guide.lua -> colour codes (presentation only)
local MARKUP_COLORS = {
    gold = GOLD, teal = TEAL, orange = ORANGE, green = GREEN, red = RED, grey = GREY,
    purple = "|cffb980ff", white = WHITE,
    bronze = RGBCode(POPUP_STYLES.room.border),   -- v1.15.0 / v1.16.0: from the style table
}
UI.MARKUP_COLORS = MARKUP_COLORS

local function FormatMarkup(text)
    text = string.gsub(tostring(text or ""), "%[(%a+)%]", function(key)
        return MARKUP_COLORS[key] or ""
    end)
    return (string.gsub(text, "%[/%]", "|r"))
end
UI.Kit.FormatMarkup = FormatMarkup

-- v1.17.11: every part once, grouped per layer: { label, LOF field }.
-- v1.17.16: a heading per group, one part per chat line, alphabetical.
-- In a do-block: UI.lua's main chunk is at Lua 5.1's 200-local limit.
do
local VERSION_GROUPS = {   -- v1.17.16: per layer, alphabetical within a group
    { label = "Core", parts = { { "Capture", "VERSION_CAPTURE" }, { "Core", "VERSION_CORE" } } },
    { label = "Resolver", parts = { { "Holdings", "VERSION_RESOLVER_HOLDINGS" },
        { "Reagents", "VERSION_RESOLVER_REAGENTS" }, { "Resolver", "VERSION_RESOLVER" },
        { "Upgrade", "VERSION_RESOLVER_UPGRADE" }, { "Value", "VERSION_RESOLVER_VALUE" } } },
    { label = "UI", parts = { { "UI", "VERSION_UI" }, { "UIAltMail", "VERSION_UI_ALTMAIL" },
        { "UIGuide", "VERSION_UI_GUIDE" }, { "UIHoldings", "VERSION_UI_HOLDINGS" },
        { "UIReagents", "VERSION_UI_REAGENTS" }, { "UISettings", "VERSION_UI_SETTINGS" } } },
    { label = "Data", parts = { { "DisenchantTable", "VERSION_DATA_DISENCHANTTABLE" },
        { "Guide", "VERSION_DATA_GUIDE" }, { "PriceRules", "VERSION_DATA_PRICERULES" },
        { "ProfessionRanks", "VERSION_DATA_PROFESSIONRANKS" },
        { "ProfessionReagents", "VERSION_DATA_PROFESSIONREAGENTS" },
        { "StatProfiles", "VERSION_DATA_STATPROFILES" }, { "StatWeights", "VERSION_DATA_STATWEIGHTS" } } },
}

local function VersionPart(part)
    return part[1] .. " " .. tostring(LOF[part[2]])
end

local function VersionHeader()
    local version, build, _, tocVersion = GetBuildInfo()
    return "LOF " .. tostring(LOF.VERSION), string.format("WoW %s.%s (%s)",
        tostring(version), tostring(build), tostring(tocVersion))
end

-- One line (Info tab copy box, bug reports).
function UI.GetVersionInfo()
    local lof, wow = VersionHeader()
    local parts = {}
    for _, group in ipairs(VERSION_GROUPS) do
        for _, part in ipairs(group.parts) do parts[#parts + 1] = VersionPart(part) end
    end
    return lof .. " (" .. table.concat(parts, ", ") .. ") | " .. wow
end

-- Chat: a header line, then per group a heading and one line per part.
function UI.GetVersionLines()
    local _, wow = VersionHeader()
    local lines = { tostring(LOF.VERSION) .. " | " .. wow }   -- v1.17.12: after "LOF: "
    for _, group in ipairs(VERSION_GROUPS) do
        lines[#lines + 1] = "  " .. group.label   -- v1.17.16
        for _, part in ipairs(group.parts) do lines[#lines + 1] = "     " .. VersionPart(part) end
    end
    return lines
end
end   -- do (versions)

-- Read-only, copyable text box: click selects all, Ctrl+C copies.
local function CreateCopyBox(parent, width)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box:SetScript("OnMouseUp", function(self) self:SetFocus(); self:HighlightText() end)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput and self.fixedText then
            self:SetText(self.fixedText)
            self:HighlightText()
        end
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    function box:SetFixedText(text)
        self.fixedText = text
        self:SetText(text)
        self:SetCursorPosition(0)
    end
    return box
end
UI.Kit.CreateCopyBox = CreateCopyBox   -- v1.17.13: also the website box in Guide > How to use

local HOLDINGS_TAB_INDEX = 2   -- v1.5.4
local SETTINGS_TAB_INDEX = 3   -- v1.12.0

local function CreateTab(index, text)
    local template
    for _, t in ipairs(TAB_TEMPLATES) do
        if TemplateExists(t) then template = t break end
    end
    local tab
    if template then
        tab = CreateFrame("Button", "LOF_MainFrameTab" .. index, panel, template)
        panel.tabsTemplated = true
    else
        tab = CreateButton(panel, text, 70)
    end
    tab:SetID(index)
    tab:SetText(text)
    if template and PanelTemplates_TabResize then PanelTemplates_TabResize(tab, 0) end
    tab:SetScript("OnClick", function(self)
        -- v1.5.4: the Holdings tab opens the window instead of a page
        if self:GetID() == HOLDINGS_TAB_INDEX then
            if UI.ToggleHoldingsWindow then UI.ToggleHoldingsWindow() end
            return
        end
        -- v1.12.0: the Settings tab opens the Settings window
        if self:GetID() == SETTINGS_TAB_INDEX then
            if UI.ToggleSettingsWindow then UI.ToggleSettingsWindow() end
            return
        end
        UI.SelectTab(self:GetID())
    end)
    if index == HOLDINGS_TAB_INDEX then
        tab:SetScript("OnEnter", function(self) UI.ShowHoldingsTabTooltip(self) end)
        tab:SetScript("OnLeave", HideTooltip)
    end
    return tab
end

local function BuildInfoPage()
    local c = panel.content
    local inner = STYLED_WIDTH - 20 - 24
    local info = {}

    info.about = CreateInset(c)
    info.aboutHead = info.about:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    info.aboutHead:SetPoint("TOPLEFT", info.about, "TOPLEFT", 10, -9)
    info.aboutText = info.about:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    info.aboutText:SetPoint("TOPLEFT", info.about, "TOPLEFT", 12, -30)
    info.aboutText:SetWidth(inner)
    info.aboutText:SetJustifyH("LEFT")
    info.aboutText:SetSpacing(2)

    -- v1.17.13: Guide (button instead of the How to use text)
    info.guide = CreateInset(c)
    info.guideHead = info.guide:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    info.guideHead:SetPoint("TOPLEFT", info.guide, "TOPLEFT", 10, -9)
    info.guideHead:SetText("Guide")
    info.guideText = info.guide:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info.guideText:SetPoint("TOPLEFT", info.guide, "TOPLEFT", 12, -30)
    info.guideText:SetWidth(inner - 120)
    info.guideText:SetJustifyH("LEFT")
    info.guideText:SetText("How to use, What's new and what each colour means.")
    info.guideBtn = CreateButton(info.guide, "Open Guide", 110)
    info.guideBtn:SetHeight(22)
    info.guideBtn:SetPoint("TOPRIGHT", info.guide, "TOPRIGHT", -12, -26)
    info.guideBtn:SetScript("OnClick", function()
        if UI.ShowGuideWindow then UI.ShowGuideWindow("howto", false) end
    end)

    -- v1.17.13: Support - website, Discord, mail, version (copy boxes)
    info.support = CreateInset(c)
    info.supportHead = info.support:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    info.supportHead:SetPoint("TOPLEFT", info.support, "TOPLEFT", 10, -9)
    info.supportHead:SetText("Support")
    local SUPPORT_ROWS = {
        { key = "site",    label = "Everything about LOF, with pictures:" },
        { key = "discord", label = "Bugs and ideas: join our Discord (Ctrl+C to copy):" },
        { key = "mail",    label = "No Discord? Mail us:" },
        { key = "ver",     label = "Please include this version info in your post or mail:" },
    }
    info.rows = {}
    local anchor = info.support
    for i, r in ipairs(SUPPORT_ROWS) do
        local label = info.support:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if i == 1 then
            label:SetPoint("TOPLEFT", info.support, "TOPLEFT", 12, -30)
        else
            label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -6, -8)
        end
        label:SetText(r.label)
        local box = CreateCopyBox(info.support, inner - 6)
        box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 6, -4)
        info.rows[r.key] = box
        anchor = box
    end

    panel.info = info
end

-- Info page layout; mirrors UI.Layout for the dashboard.
local function LayoutInfo()
    local info = panel.info
    local x = 10
    local boxWidth = STYLED_WIDTH - 2 * x
    local y = panel.styled and -60 or -30

    info.aboutHead:SetText("About  " .. GREY .. "v" .. tostring(LOF.VERSION) .. "|r")
    info.aboutText:SetText(INFO_ABOUT)
    local h1 = 30 + info.aboutText:GetStringHeight() + 10
    info.about:ClearAllPoints()
    info.about:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    info.about:SetSize(boxWidth, h1)
    y = y - h1 - SECTION_GAP

    local h2 = math.max(30 + info.guideText:GetStringHeight() + 10, 58)   -- v1.17.13
    info.guide:ClearAllPoints()
    info.guide:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    info.guide:SetSize(boxWidth, h2)
    y = y - h2 - SECTION_GAP

    local links = LOF.Data.Guide and LOF.Data.Guide.links or {}   -- v1.17.13
    info.rows.site:SetFixedText(tostring(links.website or ""))
    info.rows.discord:SetFixedText(tostring(links.discord or ""))
    info.rows.mail:SetFixedText(tostring(links.email or ""))
    info.rows.ver:SetFixedText(UI.GetVersionInfo())
    local h3 = 30 + 4 * (14 + 4 + 20) + 3 * 8 + 10
    info.support:ClearAllPoints()
    info.support:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    info.support:SetSize(boxWidth, h3)
    y = y - h3 - SECTION_GAP

    panel:SetHeight(-y + 8)
end

-- -------------------------------------------------------------
-- Holdings tab (v1.3.0; v1.5.4: tooltip only, the tab opens the
-- window). Renders Resolver.Holdings.GetTabSnapshot(); the window
-- itself lives in UIHoldings.lua.
-- -------------------------------------------------------------
local HOLDINGS_INFO = "See what each of your characters owns, where it lies (bags, bank, mail, AH) "
    .. "and what it is worth. Only characters of this ruleset and faction are shown: "
    .. "they are the ones that can share items."

local function WhenText(t)
    if not t then return GREY .. "never|r" end
    local days = math.floor((time() - t) / 86400)
    if date("%Y%m%d", t) == date("%Y%m%d") then return "today " .. date("%H:%M", t) end
    if days <= 1 then return "yesterday " .. date("%H:%M", t) end
    return days .. " days ago"
end
UI.Kit.WhenText = WhenText

-- v1.14.2: shared texts for "Remove from LOF" (Holdings + Settings).
function UI.Kit.RemoveCharacterQuestion(name)
    return "Remove " .. GOLD .. tostring(name) .. "|r from LOF?\n\n"
        .. "Everything LOF stored for this character goes (bags, bank, mail, gear, settings). "
        .. "The character in the game is not touched. Log in with it again and LOF reads it anew."
end

function UI.Kit.RemoveCharacterDone(name)
    return tostring(name) .. " removed from LOF. Log in with it again and LOF reads it anew."
end

-- v1.17.0: THE confirmation dialog (dark, gold border, Yes / No), shown
-- on top of the window that asks (anchor). One frame for every window;
-- it closes when that window closes (moving, combat, X): nothing done.
local confirmDialog

local function BuildConfirmDialog()
    local f = CreateFrame("Frame", "LOF_ConfirmDialog", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(440, 170)
    f:SetFrameStrata("DIALOG")
    if f.SetToplevel then f:SetToplevel(true) end
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
    f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    f.bg:SetColorTexture(0.06, 0.05, 0.04, 1)
    if f.SetBackdrop then
        f:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropBorderColor(1, 0.82, 0, 1)
    end
    f:EnableMouse(true)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -18)
    f.text:SetWidth(404)
    f.text:SetJustifyH("LEFT")
    f.text:SetSpacing(2)
    f.yes = UI.Kit.CreateButton(f, "Yes", 110)
    f.yes:SetHeight(22)
    f.yes:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 16)
    f.yes:SetScript("OnClick", function()
        local onYes = f.onYes
        f:Hide()
        if onYes then onYes() end
    end)
    f.no = UI.Kit.CreateButton(f, "No", 110)
    f.no:SetHeight(22)
    f.no:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 16)
    f.no:SetScript("OnClick", function() f:Hide() end)
    f:SetScript("OnHide", function(self) self.onYes = nil; self.anchor = nil end)
    f:Hide()
    confirmDialog = f
end

-- opts: yes (label), x, y (offset from the anchor's centre)
function UI.Kit.ShowConfirm(anchor, text, onYes, opts)
    opts = opts or {}
    if not confirmDialog then BuildConfirmDialog() end
    local f = confirmDialog
    f.text:SetText(text)
    f.yes:SetText(opts.yes or "Yes")
    f.onYes = onYes
    f.anchor = anchor
    f:ClearAllPoints()
    f:SetPoint("CENTER", anchor or UIParent, "CENTER", opts.x or 0, opts.y or 0)
    if anchor and not anchor.lofConfirmHooked then
        anchor.lofConfirmHooked = true
        anchor:HookScript("OnHide", function(self)
            if confirmDialog and confirmDialog.anchor == self then confirmDialog:Hide() end
        end)
    end
    f:Show()
    if f.Raise then f:Raise() end
end

function UI.Kit.HideConfirm(anchor)
    if confirmDialog and confirmDialog:IsShown() and (anchor == nil or confirmDialog.anchor == anchor) then
        confirmDialog:Hide()
    end
end

-- v1.17.0: "Remove from LOF" - the one flow for Holdings and Settings.
-- onRemoved: optional, after a successful remove (e.g. Holdings view).
function UI.Kit.AskRemoveCharacter(anchor, name, onRemoved, opts)
    if not name then return end
    opts = opts or {}
    UI.Kit.ShowConfirm(anchor, UI.Kit.RemoveCharacterQuestion(name), function()
        if Resolver.Holdings.ForgetCharacter(name) then
            LOF.Print(UI.Kit.RemoveCharacterDone(name))
            if onRemoved then onRemoved(name) end
            LOF.RequestRefresh()
        end
    end, { yes = "Yes, remove", x = opts.x, y = opts.y })
end

-- v1.5.4: tooltip of the Holdings tab (explanation + read times).
function UI.ShowHoldingsTabTooltip(owner)
    local snap = Resolver.Holdings and Resolver.Holdings.GetTabSnapshot() or {}
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText("Holdings")
    GameTooltip:AddLine(HOLDINGS_INFO, 1, 1, 1, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Check for possible Gear for alts: Bind-on-Equip gear in bags, bank and mail "
        .. "of all your characters that is an upgrade for one of them (button in the Holdings window).",
        1, 0.6, 0.2, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Characters:", tostring(snap.characterCount or 0), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Bags read:", WhenText(snap.bagUpdated), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Bank read:", WhenText(snap.bankUpdated), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddLine("Open your bank to update it.", 0.7, 0.7, 0.7)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click to open Holdings.", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

-- -------------------------------------------------------------
-- Settings building blocks (v1.12.0: the Settings window itself is
-- UISettings.lua; it uses these through UI.Kit).
-- -------------------------------------------------------------
-- Template-free check box / radio button (Blizzard textures).
local function CreateCheck(parent, isRadio)
    local b = CreateFrame("CheckButton", nil, parent)
    if isRadio then
        b:SetSize(16, 16)
        local tex = "Interface\\Buttons\\UI-RadioButton"
        b:SetNormalTexture(tex)
        b:GetNormalTexture():SetTexCoord(0, 0.25, 0, 1)
        b:SetCheckedTexture(tex)
        b:GetCheckedTexture():SetTexCoord(0.25, 0.5, 0, 1)
        b:SetHighlightTexture(tex, "ADD")
        b:GetHighlightTexture():SetTexCoord(0.5, 0.75, 0, 1)
        b:SetDisabledCheckedTexture(tex)
        b:GetDisabledCheckedTexture():SetTexCoord(0.25, 0.5, 0, 1)
        b:GetDisabledCheckedTexture():SetDesaturated(true)
    else
        b:SetSize(24, 24)
        b:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        b:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
        b:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        b:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
    end
    return b
end

UI.Kit.CreateCheck = CreateCheck   -- v1.12.0

-- Tooltip on "Use disenchant value" (v1.10.0).
function UI.ShowDisenchantHelp(owner)
    local W = 1
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText("Use disenchant value", 1, 0.82, 0)
    GameTooltip:AddLine("An item is worth the highest of: vendor price, AH price, or what "
        .. "disenchanting it gives on average (AH prices of the dust, essences and shards).",
        W, W, W, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("When it counts", 1, 0.82, 0)
    GameTooltip:AddLine("- Green, blue and purple armor and weapons.", W, W, W, true)
    GameTooltip:AddLine("- Soulbound items only when the character you play has Enchanting.", W, W, W, true)
    GameTooltip:AddLine("- At least one material has a usable AH price.", W, W, W, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Items valued this way show (DE). They move down in the swap list, "
        .. "so LOF offers them later.", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("Your Enchanting skill level is not checked.", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

-- Tooltip on "Use Auctionator prices" (v1.1.9). Numbers come from the
-- settings snapshot (data layer), so the text follows Data/PriceRules.
function UI.ShowAuctionatorHelp(owner)
    local snap = Resolver.Value.GetSettingsSnapshot()
    local W = 1  -- white body text
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText("Use Auctionator prices", 1, 0.82, 0)
    GameTooltip:AddLine("Value items at their auction house price instead of the "
        .. "vendor price, where your Settings allow it.", W, W, W, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Requires the Auctionator addon", 1, 0.82, 0)
    GameTooltip:AddLine("Install Auctionator (free on CurseForge). LOF only reads "
        .. "Auctionator's prices; it never scans the auction house itself.", W, W, W, true)
    if snap.auctionatorLoaded then
        GameTooltip:AddLine("Auctionator: detected", 0.4, 1, 0.4)
    else
        GameTooltip:AddLine("Auctionator: not installed or not loaded", 1, 0.3, 0.3)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Keep your prices fresh", 1, 0.82, 0)
    GameTooltip:AddLine("Run a full scan in Auctionator regularly, ideally every day "
        .. "you play (Auctionator allows one full scan per 15 minutes). "
        .. "Searching for single items also updates their prices.", W, W, W, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(string.format("Freshness: %sgreen|r up to %d days, %sorange|r up to %d, "
        .. "%sred|r up to %d. Older prices are not used: LOF falls back to the vendor price.",
        FRESHNESS_COLOR.FRESH, snap.freshDays, FRESHNESS_COLOR.AGING, snap.agingDays,
        FRESHNESS_COLOR.OLD, snap.maxUsableDays), 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Off: LOF uses vendor prices only.", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

-- Tooltip on "Show upgrade advice" (v1.2.6).
function UI.ShowUpgradeAdvisorHelp(owner)
    local W = 1
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText("Upgrade Advisor", 1, 0.82, 0)
    GameTooltip:AddLine("Tells you when new gear is better than what you wear, "
        .. "with a stat comparison.", W, W, W, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("When off", 1, 0.82, 0)
    GameTooltip:AddLine("- No popup for new gear in your bags.", W, W, W, true)
    GameTooltip:AddLine("- No automatic check after a level-up.", W, W, W, true)
    GameTooltip:AddLine("- The Scan button is disabled.", W, W, W, true)
    GameTooltip:AddLine("- Full bags: the swap only looks at money value "
        .. "(no \"Gear upgrade\").", W, W, W, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Applies to this character only. Below: which alts you get advice for. "
        .. "Also: /lof upgrade on|off", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

-- v1.5.6: advice for one alt on/off (from the character you play).
function UI.SetAltAdvice(altName, enabled)
    Resolver.Upgrade.SetAltEnabled(altName, enabled)
    UI.Layout()
    LOF.RequestRefresh()
end

-- Turn the Upgrade Advisor on/off (v1.2.6): Settings window and slash.
function UI.SetUpgradeAdvisor(enabled)
    Resolver.Upgrade.SetEnabled(enabled)
    if not enabled and UI.HideUpgradePopup then UI.HideUpgradePopup() end
    UI.Layout()
    LOF.RequestRefresh()   -- v1.12.0: Settings window
end

-- Tab index -> page
local TAB_PAGES = { "main", "holdings", "settings", "info" }

local function SetPageShown(page)
    for _, key in ipairs(SECTION_ORDER) do
        sections[key].box:SetShown(page == "main")
    end
    local info = panel.info
    info.about:SetShown(page == "info")
    info.guide:SetShown(page == "info")   -- v1.17.13
    info.support:SetShown(page == "info")
end

function UI.SelectTab(index)
    panel.page = TAB_PAGES[index] or "main"
    if panel.tabsTemplated and PanelTemplates_SetTab then
        PanelTemplates_SetTab(panel, index)
    end
    UI.Layout()
    if panel.page == "main" then LOF.RequestRefresh() end
end

-- v1.9.1: start moving on Info -> back to the LOF tab
-- (v1.12.0: Settings is a window; Capture closes it on moving)
function UI.LeaveInfoPagesOnMove()
    if not panel or not panel:IsShown() then return end
    if panel.page == "info" then
        UI.SelectTab(1)
    end
end

local function BuildTabs()
    panel.Tabs = { CreateTab(1, "LOF"), CreateTab(2, "Holdings"), CreateTab(3, "Settings"), CreateTab(4, "Info") }
    panel.Tabs[1]:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 12, 2)
    for i = 2, #panel.Tabs do
        panel.Tabs[i]:SetPoint("LEFT", panel.Tabs[i - 1], "RIGHT", -14, 0)
    end
    if panel.tabsTemplated and PanelTemplates_SetNumTabs then
        PanelTemplates_SetNumTabs(panel, #panel.Tabs)
    end
    BuildInfoPage()
    UI.SelectTab(1)
end

local function BuildPanel()
    panel = CreateStyledPanel("LOF_MainFrame", "main", STYLED_WIDTH, 400, "MEDIUM", true)
    panel:SetFrameStrata("MEDIUM")

    -- Our sections are the insets; hide the template's own one.
    if panel.Inset then panel.Inset:Hide() end

    local c = CreateFrame("Frame", nil, panel)
    c:SetAllPoints(panel)
    c:SetFrameLevel(panel:GetFrameLevel() + 5)
    panel.content = c

    SetPanelTitle(panel, "LootOptimizer Forever v" .. LOF.VERSION)
    if panel.styled then SetPortraitIcon(panel, COIN_ICON) end

    -- "<" minimizes to the coin icon; it takes the place of the X.
    panel.minimize = CreateButton(panel, "<", 22)
    if panel.CloseButton then
        panel.minimize:SetPoint("CENTER", panel.CloseButton, "CENTER", 0, 0)
        panel.CloseButton:Hide()
    else
        panel.minimize:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
    end
    -- The template's border (NineSlice) is drawn on a high frame level;
    -- keep the button above it so it is visible, not only clickable.
    local borderLevel = panel.NineSlice and panel.NineSlice:GetFrameLevel() or panel:GetFrameLevel()
    panel.minimize:SetFrameLevel(math.max(borderLevel, c:GetFrameLevel()) + 5)
    panel.minimize:SetScript("OnClick", function() UI.SetMinimized(true) end)
    panel.minimize:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Minimize")
        GameTooltip:AddLine("Click the coin icon to open LOF again.", 1, 1, 1)
        GameTooltip:Show()
    end)
    panel.minimize:SetScript("OnLeave", HideTooltip)

    local inner = STYLED_WIDTH - 20 - 20   -- panel margin + inset padding

    -- Inventory
    local inv = CreateSection("inventory", "Inventory", inner)
    -- v1.3.3: "Professions" with training tooltip
    inv.profBtn = CreateFrame("Button", nil, inv.box)
    inv.profBtn:SetPoint("LEFT", inv.toggle, "RIGHT", 10, 0)
    inv.profBtn.text = inv.profBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    inv.profBtn.text:SetPoint("LEFT", inv.profBtn, "LEFT", 0, 0)
    inv.profBtn.text:SetText("Professions")
    inv.profBtn:SetSize(inv.profBtn.text:GetStringWidth() + 4, 16)
    inv.profBtn:SetScript("OnEnter", function(self) UI.ShowProfessionsTooltip(self) end)
    inv.profBtn:SetScript("OnLeave", HideTooltip)
    local labels = {
        { key = "gold",    text = GOLD .. "Gold on hand|r" },
        { key = "vendor",  text = GOLD .. "Vendor|r" },
        { key = "total",   text = GREEN .. "Total|r" },
        { key = "bagvalue", text = GOLD .. "Possible total|r", gapBefore = true, gapAfter = true },
        { key = "session", text = GOLD .. "Session +/-|r" },
        { key = "free",    text = GOLD .. "Free slots|r" },
    }
    inv.labelRows = {}
    for i, def in ipairs(labels) do
        local r = CreateLabelRow(inv.box)
        r.label:SetText(def.text)
        r.key = def.key
        r.gapBefore = def.gapBefore
        r.gapAfter = def.gapAfter
        inv.labelRows[i] = r
        if def.key == "bagvalue" then
            -- hover area for the breakdown tooltip
            r.hover = CreateFrame("Frame", nil, inv.box)
            r.hover:SetSize(inner, LABEL_ROW_H)
            r.hover:EnableMouse(true)
            r.hover:SetScript("OnEnter", function(self) UI.ShowBagValueTooltip(self) end)
            r.hover:SetScript("OnLeave", HideTooltip)
            r.hover:Hide()
        end
    end

    -- Swap (buttons right-aligned in the section header)
    local swap = CreateSection("swap", "Swap", inner)
    swap.btnWL = CreateButton(swap.box, "WL", 34)
    swap.btnWL:SetPoint("TOPRIGHT", swap.box, "TOPRIGHT", -8, -6)
    swap.btnWL:SetScript("OnClick", function() UI.ToggleList("wl") end)
    swap.btnAll = CreateButton(swap.box, "All Items", 64)
    swap.btnAll:SetPoint("RIGHT", swap.btnWL, "LEFT", -4, 0)
    swap.btnAll:SetScript("OnClick", function() UI.ToggleList("all") end)
    -- v1.12.1: Make room now
    swap.btnRoom = CreateButton(swap.box, "Room", 46)
    swap.btnRoom:SetPoint("RIGHT", swap.btnAll, "LEFT", -4, 0)
    swap.btnRoom:SetScript("OnClick", function() LOF.Capture.StartMakeRoomNow() end)
    swap.btnRoom:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Make room now")
        GameTooltip:AddLine("Go through the items LOF may delete, cheapest first: "
            .. "Delete, Next or Cancel.", 1, 1, 1, true)
        GameTooltip:AddLine("Quest items, whitelist, tools, upgrades and kept reagents are never offered.",
            0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    swap.btnRoom:SetScript("OnLeave", HideTooltip)
    swap.headerButtons = { swap.btnRoom, swap.btnAll, swap.btnWL }
    for i = 1, 3 do
        swap.rows[i] = CreateStyledItemRow(swap.box, inner)
    end
    swap.empty = swap.box:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    swap.empty:SetText("No swap candidates.")

    -- Recent Loot; header holds the Upgrade Advisor buttons (v1.2.4)
    local recent = CreateSection("recent", "Recent Loot", inner)
    recent.btnIgnored = CreateButton(recent.box, "Ignored", 58)
    recent.btnIgnored:SetPoint("TOPRIGHT", recent.box, "TOPRIGHT", -8, -6)
    recent.btnIgnored:SetScript("OnClick", function() UI.ToggleList("ignored") end)
    recent.btnIgnored:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Ignored upgrades")
        GameTooltip:AddLine("Items the Upgrade Advisor will not suggest again.", 1, 1, 1)
        GameTooltip:AddLine("Click an item in the list to undo.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    recent.btnIgnored:SetScript("OnLeave", HideTooltip)
    -- v1.8.0: Send to alts
    recent.btnAltMail = CreateButton(recent.box, "Upgrade", 58)
    recent.btnAltMail:SetPoint("RIGHT", recent.btnIgnored, "LEFT", -4, 0)
    recent.btnAltMail:SetScript("OnClick", function()
        if UI.ToggleAltMailWindow then UI.ToggleAltMailWindow() end
    end)
    recent.btnAltMail:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Send to alts")
        GameTooltip:AddLine("Gear in your bags that is an upgrade for one of your alts.", 1, 1, 1, true)
        GameTooltip:AddLine("At a mailbox: click an item to put it in the mail.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    recent.btnAltMail:SetScript("OnLeave", HideTooltip)
    recent.btnScan = CreateButton(recent.box, "Scan", 44)
    recent.btnScan:SetPoint("RIGHT", recent.btnAltMail, "LEFT", -4, 0)
    recent.btnScan:SetScript("OnClick", function() LOF.Capture.ScanBagsForUpgrades("button") end)
    -- v1.2.6: tooltip also while disabled (Upgrade Advisor off)
    if recent.btnScan.SetMotionScriptsWhileDisabled then
        recent.btnScan:SetMotionScriptsWhileDisabled(true)
    end
    recent.btnScan:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Scan for upgrades")
        if Resolver.Upgrade.IsEnabled() then
            GameTooltip:AddLine("Check your bags for gear upgrades.", 1, 1, 1)
            GameTooltip:AddLine("LOF also does this after every level-up.", 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine("Upgrade Advisor is off.", 1, 0.4, 0.4)
            GameTooltip:AddLine("Turn it on in Settings.", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    recent.btnScan:SetScript("OnLeave", HideTooltip)
    recent.headerButtons = { recent.btnScan, recent.btnAltMail, recent.btnIgnored }
    for i = 1, 3 do
        recent.rows[i] = CreateStyledItemRow(recent.box, inner)
    end
    recent.empty = recent.box:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    recent.empty:SetText("No loot yet.")

    RestorePosition(panel, "main", "CENTER", 300, 0)
    BuildTabs()
    UI.Layout()
end

-- Positions the inset sections top-down; collapsed sections keep only
-- their header. The panel height follows the content.
function UI.Layout()
    if not panel then return end
    if panel.info then
        SetPageShown(panel.page or "main")
        if panel.page == "info" then
            LayoutInfo()
            return
        end
    end
    local top = panel.styled and -60 or -30
    local x = 10
    local boxWidth = STYLED_WIDTH - 2 * x
    local y = top

    for _, key in ipairs(SECTION_ORDER) do
        local s = sections[key]
        local collapsed = IsCollapsed(key)
        s.toggle:SetCollapsed(collapsed)
        for _, b in ipairs(s.headerButtons or {}) do
            b:SetShown(not collapsed)
        end
        if s.btnScan then   -- v1.2.6
            if Resolver.Upgrade.IsEnabled() then s.btnScan:Enable() else s.btnScan:Disable() end
        end

        local inY = -SECTION_HEAD_H - 4   -- y inside the box

        if s.labelRows then
            for _, r in ipairs(s.labelRows) do
                if collapsed or r.hidden then
                    r.label:Hide(); r.value:Hide()
                    if r.hover then r.hover:Hide() end
                else
                    if r.gapBefore then inY = inY - LABEL_GAP end
                    r.label:ClearAllPoints()
                    r.label:SetPoint("TOPLEFT", s.box, "TOPLEFT", 12, inY)
                    r.value:ClearAllPoints()
                    r.value:SetPoint("TOPRIGHT", s.box, "TOPRIGHT", -12, inY)
                    r.label:Show(); r.value:Show()
                    if r.hover then
                        r.hover:ClearAllPoints()
                        r.hover:SetPoint("TOPLEFT", s.box, "TOPLEFT", 10, inY + 1)
                        r.hover:Show()
                    end
                    inY = inY - LABEL_ROW_H
                    if r.gapAfter then inY = inY - LABEL_GAP end
                end
            end
        end

        if #s.rows > 0 then
            local visible = 0
            for _, row in ipairs(s.rows) do
                if collapsed or not row.hasData then
                    row:Hide()
                else
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", s.box, "TOPLEFT", 10, inY)
                    row:Show()
                    inY = inY - ITEM_ROW_H
                    visible = visible + 1
                end
            end
            if not collapsed and visible == 0 then
                s.empty:ClearAllPoints()
                s.empty:SetPoint("TOPLEFT", s.box, "TOPLEFT", 12, inY - 2)
                s.empty:Show()
                inY = inY - 20
            else
                s.empty:Hide()
            end
        end

        local boxHeight = collapsed and SECTION_HEAD_H + 4 or (-inY + 6)
        s.box:ClearAllPoints()
        s.box:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
        s.box:SetSize(boxWidth, boxHeight)
        y = y - boxHeight - SECTION_GAP
    end

    panel:SetHeight(-y + 8)
end

-- v1.3.3: professions tooltip (renders Holdings.GetProfessionStatus)
function UI.ShowProfessionsTooltip(owner)
    local ps = Resolver.Holdings and Resolver.Holdings.GetProfessionStatus()
    if not ps then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText("Professions", 1, 0.82, 0)
    for _, p in ipairs(ps.rows) do
        local skill = p.level .. "/" .. p.max
        if p.status == "TRAIN" then
            GameTooltip:AddDoubleLine(p.name .. "  " .. skill, "Visit a trainer", 0.4, 1, 0.4, 0.4, 1, 0.4)
        elseif p.status == "TRAIN_LEVEL" then
            GameTooltip:AddDoubleLine(p.name .. "  " .. skill, "Trainer at level " .. tostring(p.requiredLevel),
                1, 1, 1, 0.6, 0.6, 0.6)
        else
            GameTooltip:AddDoubleLine(p.name, skill, 1, 1, 1, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function RenderPanel(snap)
    if not panel or not panel:IsShown() then return end
    if panel.page == "info" then return end

    local inv = sections.inventory
    panel.lastSnap = snap
    if inv.profBtn and Resolver.Holdings then
        local ps = Resolver.Holdings.GetProfessionStatus()
        inv.profBtn:SetShown(#ps.rows > 0)
        if ps.anyTrain then
            inv.profBtn.text:SetTextColor(0.4, 1, 0.4)
        else
            inv.profBtn.text:SetTextColor(1, 0.82, 0)
        end
    end
    for _, r in ipairs(inv.labelRows) do
        if r.key == "gold" then
            r.value:SetText(LOF.FormatMoney(snap.money))
        elseif r.key == "vendor" then
            r.value:SetText(LOF.FormatMoney(snap.vendorTotal))
        elseif r.key == "bagvalue" then
            r.hidden = not snap.valueActive
            r.value:SetText(LOF.FormatMoney(snap.possibleTotal or 0))
        elseif r.key == "total" then
            r.value:SetText(LOF.FormatMoney(snap.total))
        elseif r.key == "session" then
            local color = snap.sessionDelta < 0 and RED or ""
            local sign = snap.sessionDelta < 0 and "-" or ""
            r.value:SetText(color .. sign .. LOF.FormatMoney(snap.sessionDelta) .. (color ~= "" and "|r" or ""))
        elseif r.key == "free" then
            local free = tonumber(snap.freeSlots) or 0
            r.value:SetText((free == 0 and RED or "") .. free .. (free == 0 and "|r" or ""))
        end
    end

    local swap = sections.swap
    for i, row in ipairs(swap.rows) do
        local item = snap.swapTop[i]
        if item then
            local relHint, relClick, relMark = ReleasedRowAction(item)   -- v1.12.4
            FillStyledItemRow(row, item.name, item.quality, item.icon, item.count,
                ValueText(item, RED) .. (relMark or ""), item.link)
            row.valueInfo = item
            row.hint = relHint or WL_HINT_ADD
            row.onClick = relClick or MakeWhitelistToggle(item.name, item.itemID)
            row.hasData = true
        else
            row.hasData = false
            row.link = nil
            row.onClick = nil
        end
    end

    local recent = sections.recent
    for i, row in ipairs(recent.rows) do
        local item = snap.recentLoot[i]
        if item then
            local valueText = item.hasValue and ValueText(item) or (GREY .. "n/a|r")
            FillStyledItemRow(row, item.name, item.quality, item.icon, item.count, valueText, item.link)
            row.valueInfo = item
            row.hasData = true
        else
            row.hasData = false
            row.link = nil
        end
    end

    UI.Layout()
end

-- -------------------------------------------------------------
-- Bag value tooltip (v1.1.6): how the bag value is built up.
-- Renders the last dashboard snapshot; no calculations here.
-- -------------------------------------------------------------
function UI.ShowBagValueTooltip(owner)
    local snap = panel and panel.lastSnap
    if not snap then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText("Possible total", 1, 0.82, 0)
    local gain = tonumber(snap.bagValueGain or 0) or 0
    if gain > 0 then
        GameTooltip:AddLine(GREEN .. "+" .. LOF.FormatMoney(gain) .. "|r compared to Total", 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine("Same as Total (vendor value)", 0.6, 0.6, 0.6)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Gold on hand", LOF.FormatMoney(snap.money or 0), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Possible bag value", LOF.FormatMoney(snap.bagValue or 0), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("  AH  (" .. (snap.bagValueAHCount or 0) .. " items)",
        LOF.FormatMoney(snap.bagValueAH or 0), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("  Vendor  (" .. (snap.bagValueVendorCount or 0) .. " items)",
        LOF.FormatMoney(snap.bagValueVendor or 0), 0.8, 0.8, 0.8, 1, 1, 1)
    if (snap.bagValueDECount or 0) > 0 then
        GameTooltip:AddDoubleLine("  Disenchant  (" .. snap.bagValueDECount .. " items)",
            LOF.FormatMoney(snap.bagValueDE or 0), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    local top = snap.bagValueTop or {}
    if #top > 0 then
        GameTooltip:AddLine(" ")
        for _, item in ipairs(top) do
            local name = LOF.ColorizeName(item.name, item.quality)
            if (tonumber(item.count or 1) or 1) > 1 then
                name = name .. GREY .. " x" .. item.count .. "|r"
            end
            GameTooltip:AddDoubleLine(name, ValueText(item), 1, 1, 1, 1, 1, 1)
        end
        if (snap.bagValueMore or 0) > 0 then
            GameTooltip:AddLine("+ " .. snap.bagValueMore .. " more items", 0.6, 0.6, 0.6)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Values per your Settings: AH where allowed, otherwise vendor. "
        .. "Quest and whitelisted items are not counted.", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

-- -------------------------------------------------------------
-- Item cards (shared by the swap popup and the upgrade popup)
-- -------------------------------------------------------------
local CARD_HEIGHT   = 46
local ICON_SIZE     = 40

-- Item card: [icon with quality border]  Name (quality colour)   LABEL
--                                        Two-Hand - Staff
local function CreateItemCard(parent, width)
    local card = CreateFrame("Button", nil, parent)
    card:SetSize(width, CARD_HEIGHT)

    card.bg = card:CreateTexture(nil, "BACKGROUND")
    card.bg:SetAllPoints()
    card.bg:SetColorTexture(1, 1, 1, 0.04)

    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(ICON_SIZE, ICON_SIZE)
    card.icon:SetPoint("LEFT", card, "LEFT", 3, 0)

    card.border = card:CreateTexture(nil, "OVERLAY")
    card.border:SetTexture("Interface\\Common\\WhiteIconFrame")
    card.border:SetAllPoints(card.icon)

    card.label = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.label:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -6)

    card.name = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 8, -3)
    card.name:SetPoint("RIGHT", card.label, "LEFT", -6, 0)
    card.name:SetJustifyH("LEFT")
    card.name:SetWordWrap(false)

    card.sub = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.sub:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
    card.sub:SetJustifyH("LEFT")

    card:SetScript("OnEnter", ShowItemTooltip)
    card:SetScript("OnLeave", HideTooltip)
    return card
end

-- v1.10.6: coloured frame (2 px border + light tint) around a card.
-- Built on first use; r == nil hides it.
local CARD_EDGE = 2
local function SetCardHighlight(card, r, g, b)
    if not card.hl then
        local hl = {}
        hl.fill = card:CreateTexture(nil, "BORDER")
        hl.fill:SetAllPoints()
        local function Edge() return card:CreateTexture(nil, "OVERLAY") end
        hl.top, hl.bottom, hl.left, hl.right = Edge(), Edge(), Edge(), Edge()
        hl.top:SetPoint("TOPLEFT"); hl.top:SetPoint("TOPRIGHT"); hl.top:SetHeight(CARD_EDGE)
        hl.bottom:SetPoint("BOTTOMLEFT"); hl.bottom:SetPoint("BOTTOMRIGHT"); hl.bottom:SetHeight(CARD_EDGE)
        hl.left:SetPoint("TOPLEFT"); hl.left:SetPoint("BOTTOMLEFT"); hl.left:SetWidth(CARD_EDGE)
        hl.right:SetPoint("TOPRIGHT"); hl.right:SetPoint("BOTTOMRIGHT"); hl.right:SetWidth(CARD_EDGE)
        card.hl = hl
    end
    local hl = card.hl
    local show = r ~= nil
    for _, t in pairs(hl) do t:SetShown(show) end
    -- v1.10.7: white sub line on a framed card, grey (font default) otherwise
    if card.sub then
        if show then
            card.sub:SetTextColor(1, 1, 1)
        else
            local fo = _G.GameFontDisableSmall
            if fo and fo.GetTextColor then card.sub:SetTextColor(fo:GetTextColor())
            else card.sub:SetTextColor(0.5, 0.5, 0.5) end
        end
    end
    if not show then return end
    hl.fill:SetColorTexture(r, g, b, 0.14)
    for _, k in ipairs({ "top", "bottom", "left", "right" }) do
        hl[k]:SetColorTexture(r, g, b, 0.95)
    end
end

-- v1.16.0: the colours of a style (POPUP_STYLES); quality styles follow
-- Blizzard's item quality colour. Returns style, border, tint, card.
local function GetPopupStyleColors(key, quality)
    local st = POPUP_STYLES[key] or POPUP_STYLES.plain
    if st.quality then
        local r, g, b = GetQualityRGB(quality)
        local q = tonumber(quality) or 1
        return st, { r, g, b }, { r, g, b, (q <= 1) and st.tintLow or st.tintHigh }, { r, g, b }
    end
    return st, st.border, st.tint, st.card or st.border
end

-- The thick border a style draws (built on first use; the swap popup
-- hands in its own alert frame as f.styleBorder).
-- v1.16.1: the border lies BEHIND the popup (one frame strata lower,
-- Peter: it ran over the coin portrait). Only the part outside the
-- window shows, as a coloured outline; coin and frame stay on top.
local STRATA_ORDER = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN",
    "FULLSCREEN_DIALOG", "TOOLTIP" }

local function StrataBelow(strata)
    for i, s in ipairs(STRATA_ORDER) do
        if s == strata then return STRATA_ORDER[math.max(1, i - 1)] end
    end
    return "HIGH"
end

local function PlaceStyleBorder(f, b)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f, "TOPLEFT", -8, 8)
    b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 8, -8)
    b:SetFrameStrata(StrataBelow(f:GetFrameStrata()))
end

local function EnsureStyleBorder(f)
    if f.styleBorder then
        PlaceStyleBorder(f, f.styleBorder)
        return f.styleBorder
    end
    local b = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    PlaceStyleBorder(f, b)
    if b.SetBackdrop then
        b:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 26,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
    end
    b:EnableMouse(false)
    b:Hide()
    f.styleBorder = b
    return b
end

-- v1.16.0: THE function that gives a popup its look. Always resets
-- first (no border or tint left over from the previous popup).
-- opts: quality, card (item card to frame), cardRGB (override),
-- title (text after the head; "" = head only).
-- Returns the title text and whether it should be large.
local function ApplyPopupStyle(f, key, opts)
    opts = opts or {}
    local st, border, tint, card = GetPopupStyleColors(key, opts.quality)
    if f.tint then
        if tint then
            f.tint:SetColorTexture(tint[1], tint[2], tint[3], tint[4] or 0.3)
            f.tint:Show()
        else
            f.tint:Hide()
        end
    end
    local bf = EnsureStyleBorder(f)
    if border and bf.SetBackdropBorderColor then
        bf:SetBackdropBorderColor(border[1], border[2], border[3], 1)
        bf:Show()
    else
        bf:Hide()
    end
    if opts.card then
        local c = opts.cardRGB or card
        if c then SetCardHighlight(opts.card, c[1], c[2], c[3]) else SetCardHighlight(opts.card, nil) end
    end
    if opts.title == nil then return nil, false end
    if st.head then
        local head = RGBCode(st.headRGB or border or { 1, 1, 1 }) .. st.head .. "|r"
        if opts.title == "" then return head, true end
        return head .. " - " .. opts.title, true
    end
    return opts.title, false
end
UI.Kit.GetPopupStyleColors = GetPopupStyleColors   -- v1.16.0: Guide Colors tab

-- v1.10.6: Equipped card a little darker (new item stands out more)
local function SetCardDimmed(card, dimmed)
    card.bg:SetColorTexture(dimmed and 0 or 1, dimmed and 0 or 1, dimmed and 0 or 1, dimmed and 0.25 or 0.04)
end

local function SlotText(equipLoc, subType)
    local slot = equipLoc and _G[equipLoc]
    local parts = {}
    if type(slot) == "string" and slot ~= "" then parts[#parts + 1] = slot end
    if subType and subType ~= "" and subType ~= slot then parts[#parts + 1] = subType end
    return table.concat(parts, "  -  ")
end

local function FillItemCard(card, name, quality, icon, link, equipLoc, subType, label)
    card.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    card.border:SetVertexColor(GetQualityRGB(quality))
    card.border:SetShown(quality ~= nil)
    card.name:SetText(LOF.ColorizeName(name, quality))
    card.sub:SetText(SlotText(equipLoc, subType))
    card.label:SetText(label or "")
    card.link = link
end

-- -------------------------------------------------------------
-- Swap decision popup (v1.1.8: Forever look & feel)
-- Blizzard panel with the coin portrait, item cards with 40px icons,
-- larger buttons. Modes: "decide", "destroy", "info" (not worth a
-- swap, red alert border). Swap / Swap anyway stay template-free
-- buttons (CreatePlainButton): DeleteCursorItem is blocked from a
-- UIPanelButtonTemplate click on Forever.
-- -------------------------------------------------------------
local popup
local SWAP_WIDTH  = 420   -- v1.17.26: was 390 (quest note on one line); v1.15.0: was 360
local RenderComparison    -- v1.16.6: defined after the stat table helpers (one comparison block)
local SWAP_BTN_W  = 100
local SWAP_BTN_H  = 24
local NOTE_EXTRA_H = 16

local function SwapButton(parent, text)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(SWAP_BTN_W, SWAP_BTN_H)
    b:SetText(text)
    return b
end

local function SwapPlainButton(parent, text)
    local b = CreatePlainButton(parent, text, SWAP_BTN_W, SWAP_BTN_H)
    local fs = b:GetFontString()
    if fs then fs:SetFontObject("GameFontNormal") end
    return b
end

local function GetPopupTitleString(f)
    return (f.TitleContainer and f.TitleContainer.TitleText) or f.TitleText or f.lofTitle
end

-- "Uncommon  -  x20" / "Quest item"
local function SwapSubText(item)
    if item.questSub then return GOLD .. item.questSub .. "|r" end   -- v1.17.5: resolver text
    local q = tonumber(item.quality)
    local qName = q and _G["ITEM_QUALITY" .. q .. "_DESC"] or ""
    local count = tonumber(item.count or 1) or 1
    if count > 1 then
        return (qName ~= "" and (qName .. "  -  ") or "") .. "x" .. count
    end
    return qName
end

local function FillSwapCard(card, item, valueText)
    FillItemCard(card, item.name, item.quality, item.icon, item.link, nil, nil, valueText)
    -- v1.12.3: released from protection by the player (resolver flags)
    local sub = SwapSubText(item)
    local marks = {}
    if item.ignoredUpgrade then marks[#marks + 1] = "ignored upgrade" end
    if item.reagentOff then marks[#marks + 1] = TEAL .. "reagent, normal rules|r" end
    if #marks > 0 then
        sub = (sub ~= "" and (sub .. "  -  ") or "") .. table.concat(marks, ", ")
    end
    card.sub:SetText(sub)
    card.valueInfo = item
    card.hint = nil
end

local function BuildPopup()
    local f = CreateStyledPanel("LOF_SwapPopup", "popup", SWAP_WIDTH, 250, "DIALOG", true)
    if f.styled then SetPortraitIcon(f, COIN_ICON) end
    if f.Inset then f.Inset:Hide() end
    local inner = SWAP_WIDTH - 2 * 16
    f.innerWidth = inner
    f.top = f.styled and -64 or -30

    local c = CreateFrame("Frame", nil, f)
    c:SetAllPoints(f)
    c:SetFrameLevel(f:GetFrameLevel() + 10)
    f.content = c

    f.caption1 = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.card1 = CreateItemCard(c, inner)
    f.caption2 = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.caption2:SetWidth(inner)
    f.caption2:SetJustifyH("LEFT")
    f.card2 = CreateItemCard(c, inner)

    f.summary = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.summary:SetJustifyH("LEFT")

    -- v1.8.2: green (upgrade for you) / orange (for an alt) background
    f.tint = c:CreateTexture(nil, "BACKGROUND")
    f.tint:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -22)
    f.tint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    f.tint:Hide()

    -- note when an item's AH data is too old to be used
    f.note = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.note:SetWidth(inner)
    f.note:SetJustifyH("LEFT")
    f.note:SetTextColor(1, 0.3, 0.3)
    f.note:Hide()

    -- destroy instructions (phase 2)
    f.instr = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.instr:SetPoint("TOPLEFT", f, "TOPLEFT", 16, f.top)
    f.instr:SetWidth(inner)
    f.instr:SetJustifyH("LEFT")
    f.instr:SetSpacing(3)

    -- decide: Swap / WL / Wait
    f.btnSwap = SwapPlainButton(c, "Swap")
    f.btnSwap:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14)
    f.btnSwap:SetScript("OnClick", function() LOF.Capture.ExecuteSwap() end)

    f.btnWL = SwapButton(c, "WL")
    f.btnWL:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
    f.btnWL:SetScript("OnClick", function() LOF.Capture.WhitelistBagItem(IsShiftKeyDown()) end)
    f.btnWL:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Keep the bag item")
        GameTooltip:AddLine("Click: whitelist for this session.", 1, 1, 1)
        GameTooltip:AddLine("Shift-click: whitelist permanently.", 1, 1, 1)
        GameTooltip:Show()
    end)
    f.btnWL:SetScript("OnLeave", HideTooltip)

    f.btnWait = SwapButton(c, "Wait")
    f.btnWait:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    f.btnWait:SetScript("OnClick", function() LOF.Capture.CancelSession() end)

    -- v1.14.0: Previous / Next (only with more than one qualifying item)
    f.btnPrev = SwapButton(c, "Previous")
    f.btnPrev:SetScript("OnClick", function() LOF.Capture.SwapPrevious() end)
    f.btnNext = SwapButton(c, "Next")
    f.btnNext:SetScript("OnClick", function() LOF.Capture.SwapNext() end)
    f.btnNext:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Next bag item")
        GameTooltip:AddLine("Keeps this one for now (not whitelisted).", 1, 1, 1)
        GameTooltip:Show()
    end)
    f.btnNext:SetScript("OnLeave", HideTooltip)
    f.navNote = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")   -- v1.14.1: larger, white
    f.navNote:SetWidth(inner)
    f.navNote:SetJustifyH("LEFT")
    f.navNote:Hide()

    -- v1.17.1: the separate Make room buttons are gone (one Make room flow)
    -- v1.12.2 room now: Delete / Previous / Next / Cancel (narrower)
    -- + a grey note; question mode: Yes / Stop, end: OK
    local RN_GAP = 8
    local RN_W = math.floor((inner - 3 * RN_GAP) / 4)   -- v1.17.26: the 4 buttons fill the width
    local function RNPos(b, i)
        b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16 + (i - 1) * (RN_W + RN_GAP), 14)
    end
    f.rnDelete = CreatePlainButton(c, "Delete", RN_W, SWAP_BTN_H)
    RNPos(f.rnDelete, 1)
    f.rnDelete:SetScript("OnClick", function() LOF.Capture.ExecuteMakeRoom() end)
    f.rnPrev = SwapButton(c, "Previous")
    f.rnPrev:SetWidth(RN_W)
    RNPos(f.rnPrev, 2)
    f.rnPrev:SetScript("OnClick", function() LOF.Capture.MakeRoomNowPrevious() end)
    f.rnNext = SwapButton(c, "Next")
    f.rnNext:SetWidth(RN_W)
    RNPos(f.rnNext, 3)
    f.rnNext:SetScript("OnClick", function() LOF.Capture.MakeRoomNowNext() end)
    f.rnCancel = SwapButton(c, "Cancel")
    f.rnCancel:SetWidth(RN_W)
    RNPos(f.rnCancel, 4)
    f.rnCancel:SetScript("OnClick", function() LOF.Capture.CancelSession() end)
    f.rnYes = SwapButton(c, "Yes")
    f.rnYes:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14)
    f.rnYes:SetScript("OnClick", function() LOF.Capture.MakeRoomNowContinue() end)
    f.rnStop = SwapButton(c, "Stop")
    f.rnStop:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    f.rnStop:SetScript("OnClick", function() LOF.Capture.CancelSession() end)
    f.rnOK = SwapButton(c, "OK")
    f.rnOK:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
    f.rnOK:SetScript("OnClick", function() LOF.Capture.CancelSession() end)
    f.roomNote = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.roomNote:SetWidth(inner)
    f.roomNote:SetJustifyH("LEFT")
    f.roomNote:SetTextColor(1, 1, 1)   -- v1.17.2: white (was light grey)

    -- destroy: Cancel
    f.btnCancel = SwapButton(c, "Cancel")
    f.btnCancel:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
    f.btnCancel:SetScript("OnClick", function() LOF.Capture.CancelSession() end)

    -- info: Swap anyway (secondary, left) + OK (primary, right)
    f.btnAnyway = SwapPlainButton(c, "Swap anyway")
    f.btnAnyway:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14)
    f.btnAnyway:SetScript("OnClick", function() LOF.Capture.ExecuteSwap() end)

    f.btnOK = SwapButton(c, "OK")
    f.btnOK:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    f.btnOK:SetScript("OnClick", function()
        if f.mode == "left" then f:Hide() else LOF.Capture.CancelSession() end
    end)

    -- The template's X: same as Wait / Cancel / OK.
    if f.CloseButton then
        f.CloseButton:SetScript("OnClick", function()
            if f.mode == "left" then f:Hide() else LOF.Capture.CancelSession() end
        end)
    end

    -- Alert look for the info mode: thick red border, warning icon,
    -- large red title, auto-close countdown (paused on mouse-over).
    local alert = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    alert:SetPoint("TOPLEFT", f, "TOPLEFT", -6, 6)
    alert:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 6, -6)
    local borderLevel = f.NineSlice and f.NineSlice:GetFrameLevel() or f:GetFrameLevel()
    alert:SetFrameLevel(math.max(borderLevel, c:GetFrameLevel()) + 5)
    if alert.SetBackdrop then
        alert:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 26,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
    end   -- v1.16.0: colour comes from ApplyPopupStyle
    alert:EnableMouse(false)
    alert:Hide()
    f.alert = alert
    f.styleBorder = alert   -- v1.16.0: ApplyPopupStyle colours this border

    f.alertIcon = c:CreateTexture(nil, "OVERLAY")
    f.alertIcon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    f.alertIcon:SetSize(22, 22)
    f.alertIcon:Hide()   -- placed next to the title text in SetPopupTitle

    f.countdown = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")   -- v1.16.3: white, larger
    f.countdown:SetPoint("BOTTOM", f, "BOTTOM", 0, 20)
    f.countdown:Hide()

    f:SetScript("OnUpdate", function(self, elapsed)
        if not self.autoCloseAt then return end
        if self:IsMouseOver() then
            -- pause: push the deadline forward while the mouse is on it
            self.autoCloseAt = self.autoCloseAt + elapsed
            self.countdown:SetText("paused")
            return
        end
        local left = self.autoCloseAt - GetTime()
        if left <= 0 then
            self.autoCloseAt = nil
            LOF.Capture.CancelSession()
            return
        end
        self.countdown:SetText(string.format("closes in %d", math.ceil(left)))
    end)

    f:Hide()
    popup = f
end

local function SetPopupTitle(text, large)
    SetPanelTitle(popup, text)
    local t = GetPopupTitleString(popup)
    if t then
        if not popup.titleFont then popup.titleFont = t:GetFontObject() end
        t:SetFontObject(large and "GameFontNormalLarge" or popup.titleFont or "GameFontNormal")
        -- the title string may span the whole title bar: anchor the alert
        -- icon to the left edge of the visible text instead
        popup.alertIcon:ClearAllPoints()
        popup.alertIcon:SetPoint("RIGHT", t, "CENTER", -(t:GetStringWidth() / 2) - 4, 0)
    else
        popup.alertIcon:ClearAllPoints()
        popup.alertIcon:SetPoint("TOP", popup, "TOP", -80, -4)
    end
end

-- Popup modes:
--   "decide"  : phase 1, Swap / WL / Wait
--   "destroy" : phase 2, destroy instructions + Cancel
--   "info"    : not worth a swap, Swap anyway / OK
local function SetPopupMode(mode)
    local decide, destroy, info = mode == "decide", mode == "destroy", mode == "info"
    local left = mode == "left"
    local roomNow = mode == "roomnow"   -- v1.12.1
    local roomAsk = mode == "roomask"   -- v1.12.2
    popup.mode = mode
    popup.caption1:SetShown(decide or info or left or roomNow)
    popup.card1:SetShown(decide or info or left or roomNow)
    SetCardHighlight(popup.card1, nil)   -- v1.12.2: only room now frames it
    popup.caption2:SetShown(decide or info)
    popup.card2:SetShown(decide or info)
    popup.summary:SetShown(decide or info or left or roomNow or roomAsk)   -- v1.17.9: + left
    popup.btnSwap:SetShown(decide)
    popup.btnWL:SetShown(decide)
    popup.roomNote:SetShown(roomNow)
    popup.rnDelete:SetShown(roomNow)
    popup.rnPrev:SetShown(roomNow)
    popup.rnNext:SetShown(roomNow)
    popup.rnCancel:SetShown(roomNow)
    popup.rnYes:Hide(); popup.rnStop:Hide(); popup.rnOK:Hide()   -- roomask decides
    popup.btnWait:SetShown(decide)
    popup.btnPrev:Hide(); popup.btnNext:Hide(); popup.navNote:Hide()   -- v1.14.0: ShowSwapPopup decides
    popup.instr:SetShown(destroy)
    popup.btnCancel:SetShown(destroy)
    popup.btnAnyway:SetShown(info)
    popup.btnOK:SetShown(info or left)
    popup.note:Hide()
    popup.summary:SetWidth(0)
    popup.summary:SetWordWrap(false)

    ApplyPopupStyle(popup, "plain")   -- v1.16.0: no border / tint; each Show* styles it
    SetCardHighlight(popup.card2, nil)
    if RenderComparison then RenderComparison(popup, 0, 0, nil) end   -- v1.16.6: hidden
    popup.alertIcon:SetShown(info or left)
    popup.countdown:SetShown(info)
    if not info then popup.autoCloseAt = nil end
end

-- Places captions, cards, summary and note top-down; sizes the popup.
-- card2 may be hidden (nothing to swap): caption2 is then a text line.
-- v1.14.0: decide buttons, with or without Previous / Next.
local DECIDE_NAV = {   -- button, width (left to right, 328 wide)
    { "btnSwap", 60 }, { "btnPrev", 70 }, { "btnNext", 54 }, { "btnWL", 46 }, { "btnWait", 54 },
}

local function PlaceDecideButtons(nav)
    local f = popup
    for _, def in ipairs(DECIDE_NAV) do f[def[1]]:ClearAllPoints() end
    if nav then
        local used = 0
        for _, def in ipairs(DECIDE_NAV) do used = used + def[2] end
        local gap = (f.innerWidth - used) / (#DECIDE_NAV - 1)
        local x = 16
        for _, def in ipairs(DECIDE_NAV) do
            local b = f[def[1]]
            b:SetWidth(def[2])
            b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 14)
            x = x + def[2] + gap
        end
        f.btnPrev:Show(); f.btnNext:Show()
    else
        f.btnSwap:SetWidth(SWAP_BTN_W)
        f.btnSwap:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14)
        f.btnWL:SetWidth(SWAP_BTN_W)
        f.btnWL:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
        f.btnWait:SetWidth(SWAP_BTN_W)
        f.btnWait:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
        f.btnPrev:Hide(); f.btnNext:Hide()
    end
end

local function LayoutSwapPopup(showStaleNote, navNoteText, gear)
    local f = popup
    local x, y = 16, f.top
    f.caption1:ClearAllPoints()
    f.caption1:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    y = y - 18
    f.card1:ClearAllPoints()
    f.card1:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    y = y - CARD_HEIGHT - 10
    f.caption2:ClearAllPoints()
    f.caption2:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    y = y - 18
    if f.card2:IsShown() then
        f.card2:ClearAllPoints()
        f.card2:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        y = y - CARD_HEIGHT - 10
    else
        y = y - 4
    end
    f.summary:ClearAllPoints()
    f.summary:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    y = y - math.max(18, f.summary:GetStringHeight() + 6)   -- v1.11.0: may wrap
    if gear then y = RenderComparison(f, x, y, gear, { compared = true }) - 6 end   -- v1.16.6
    if showStaleNote then
        f.note:ClearAllPoints()
        f.note:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        f.note:Show()
        y = y - NOTE_EXTRA_H
    end
    if navNoteText then   -- v1.14.0
        f.navNote:SetText(navNoteText)
        f.navNote:ClearAllPoints()
        f.navNote:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        f.navNote:Show()
        y = y - f.navNote:GetStringHeight() - 8
    end
    f:SetHeight(-y + 14 + SWAP_BTN_H + 14)
end

-- True when the resolver marked a shown item's AH data as too old.
local function SetStaleNote(...)
    for i = 1, select("#", ...) do
        local item = select(i, ...)
        if item and item.valueReason == "AH_STALE" then
            popup.note:SetText(string.format("AH data older than %d days - scan the auction house.",
                LOF.Resolver.Value.GetMaxUsableDays()))
            return true
        end
    end
    return false
end

function UI.ShowDestroyInstructions(d)
    if not popup then BuildPopup() end
    local bag, loot = d.bagItem, d.lootItem
    local lootName = LOF.ColorizeName(loot.name, loot.quality)
    if (tonumber(loot.count or 1) or 1) > 1 then
        lootName = lootName .. " x" .. loot.count
    end

    SetPopupTitle("Destroy " .. LOF.ColorizeName(bag.name, bag.quality), false)
    popup.instr:SetText(
        "The item is now on your cursor.\n\n"
        .. GOLD .. "1.|r Click anywhere in the game world (not on a window).\n"
        .. GOLD .. "2.|r Confirm " .. GOLD .. "Destroy|r in the Blizzard dialog.\n\n"
        .. "LOF will then loot " .. lootName .. " for you.")
    SetPopupMode("destroy")
    popup:SetHeight(-popup.top + popup.instr:GetStringHeight() + 20 + SWAP_BTN_H + 14)
    popup:Show()
end

-- v1.11.0: "Reagent for Blacksmithing (45) - useful up to about 100"
local function ReagentText(r)
    local best = r and r.best
    if not best then
        return TEAL .. "Profession material|r - you chose to keep it"
    end
    local text = TEAL .. "Reagent for " .. tostring(best.name) .. " (" .. tostring(best.level) .. ")|r"
    if r.userSet and not best.useful then
        return text .. " - you chose to keep it"
    end
    if best.usefulTo then
        return text .. " - useful up to about " .. best.usefulTo
    end
    return text
end

-- v1.12.1 / v1.12.2: Make room now (Capture.ShowMakeRoomNow)
local QUALITY_WORD = { [0] = "Grey", [1] = "White", [2] = "Green", [3] = "Blue" }
local QUALITY_LONG = { [0] = "grey", [1] = "white (common)", [2] = "green (uncommon)", [3] = "blue (rare)" }
local QUALITY_LOWER = { [0] = "grey", [1] = "white", [2] = "green", [3] = "blue" }

-- mode: nil = "Grey" (title), true = "white (common)", "lower" = "white"
local function QualityWord(q, mode)
    local list = (mode == "lower" and QUALITY_LOWER) or (mode and QUALITY_LONG) or QUALITY_WORD
    local word = list[q] or ("quality " .. tostring(q))
    return LOF.ColorizeName(word, q)
end

local function ShowMakeRoomNowQuestion(d)
    SetPopupMode("roomask")
    -- v1.16.0 / v1.17.1: "MAKE ROOM - bags full" when the game said so
    local roomTitle, roomLarge = ApplyPopupStyle(popup, d.bagsFull and "room" or "roomnow",
        { title = d.bagsFull and "bags full" or "" })
    local f = popup
    f.summary:SetWidth(f.innerWidth)
    f.summary:SetWordWrap(true)
    if d.ask then
        SetPopupTitle(roomTitle, roomLarge)
        f.summary:SetText((d.hadAny and "No more " or "No ") .. QualityWord(d.doneQuality, "lower") .. " items.\n\n"
            .. "Continue with " .. QualityWord(d.nextQuality, true) .. " items?")
        f.rnYes:Show(); f.rnStop:Show()
    else
        SetPopupTitle(roomTitle, roomLarge)
        f.summary:SetText(tostring(d.message or "Nothing more LOF may delete."))
        f.rnOK:Show()
    end
    local y = f.top
    f.summary:ClearAllPoints()
    f.summary:SetPoint("TOPLEFT", f, "TOPLEFT", 16, y - 4)
    y = y - 4 - f.summary:GetStringHeight() - 14
    f:SetHeight(-y + 14 + SWAP_BTN_H + 14)
    RestorePosition(popup, "popup", "CENTER", 0, 180)
    popup:Show()
end

function UI.ShowMakeRoomNowPopup(d)
    if not popup then BuildPopup() end
    if not d.bagItem then
        ShowMakeRoomNowQuestion(d)
        return
    end
    SetPopupMode("roomnow")
    local f, bag = popup, d.bagItem
    -- v1.17.2: quality and position on their own line (the title was cut off)
    f.caption1:SetText("Delete from bag:  " .. QualityWord(d.quality)
        .. string.format(WHITE .. "  (%d of %d)|r", d.position or 1, d.total or 1))
    FillSwapCard(f.card1, bag, ValueText(bag))
    -- v1.16.0: bronze style; the item keeps its quality frame
    local r, g, b = GetQualityRGB(d.quality)
    SetPopupTitle(ApplyPopupStyle(popup, d.bagsFull and "room" or "roomnow", {   -- v1.17.1
        title = d.bagsFull and "bags full" or "",
        card = f.card1, cardRGB = { r, g, b },
    }))
    f.summary:SetWidth(f.innerWidth)
    f.summary:SetWordWrap(true)
    if d.reagent and d.reagent.best then
        local best = d.reagent.best
        f.summary:SetText(TEAL .. "Reagent for " .. tostring(best.name) .. " (" .. tostring(best.level)
            .. ")|r - normal rules")
    elseif d.craftingReagent then
        f.summary:SetText("Crafting reagent - not in LOF's list.")   -- v1.17.2: white
    elseif d.cheaperItem then   -- v1.17.22: explain why this one goes first
        local c = d.cheaperItem
        f.summary:SetText("Cheapest " .. QualityWord(d.quality) .. " item \226\128\147 "
            .. QualityWord(d.quality) .. " goes first.\n\n"   -- v1.17.23: blank line
            .. "Cheaper overall: " .. QualityWord(c.quality) .. " item "
            .. LOF.ColorizeName(c.name, c.quality) .. ", " .. ValueText(c) .. ".\n"
            .. GREY .. "Order:|r " .. QualityWord(0) .. GREY .. ", |r" .. QualityWord(1) .. GREY .. ", |r"
            .. QualityWord(2) .. GREY .. ", |r" .. QualityWord(3)
            .. GREY .. " \226\128\147 cheapest first within each.|r")
    else
        f.summary:SetText("Cheapest item LOF may delete.")
    end
    if d.questNote then   -- v1.17.24 (E7)
        f.roomNote:SetFontObject("GameFontNormalLarge")   -- v1.17.25: large, stands out
        f.roomNote:SetText(GOLD .. d.questNote .. "|r")
    else
        f.roomNote:SetFontObject("GameFontHighlightSmall")
        f.roomNote:SetTextColor(1, 1, 1)
        f.roomNote:SetText(d.bagsFull   -- v1.17.1
            and "Frees one slot. Then try again: cast, craft, take the quest reward or the item."
            or "One item per click, so you always see what goes.")
    end
    if d.canPrevious then f.rnPrev:Enable() else f.rnPrev:Disable() end
    local x, y = 16, f.top
    f.caption1:ClearAllPoints()
    f.caption1:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    y = y - 18
    f.card1:ClearAllPoints()
    f.card1:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    y = y - CARD_HEIGHT - 10
    f.summary:ClearAllPoints()
    f.summary:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    y = y - f.summary:GetStringHeight() - 8
    f.roomNote:ClearAllPoints()
    f.roomNote:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    y = y - f.roomNote:GetStringHeight() - 8
    f:SetHeight(-y + 14 + SWAP_BTN_H + 14)
    RestorePosition(popup, "popup", "CENTER", 0, 180)
    popup:Show()
end

function UI.ShowSwapPopup(d)
    if not popup then BuildPopup() end
    local isReagent = d.swapReason == "REAGENT"
    SetPopupTitle(isReagent and "Bags full - profession material?" or "Bags full - swap?", false)
    SetPopupMode("decide")
    local bag, loot = d.bagItem, d.lootItem
    local isGear = d.swapReason == "GEAR"   -- v1.15.0

    popup.caption1:SetText("Delete from bag")
    FillSwapCard(popup.card1, bag, ValueText(bag))
    popup.caption2:SetText("Loot")
    local lootValueText
    if loot.questTag then
        lootValueText = GOLD .. loot.questTag .. "|r"   -- v1.17.5: resolver text
    elseif loot.gearVerdict == "UPGRADE_CLEAR" then
        -- v1.8.2 / v1.17.0: Kit.GainText
        lootValueText = GainText({ emptySlot = loot.gearEmptySlot, percent = loot.gearPercent }, GREEN, "Upgrade")
    elseif loot.gearVerdict == "TRADE_OFF" then
        lootValueText = GOLD .. "Trade-off|r"
    elseif loot.isAltUpgrade then
        -- v1.8.2: who, and how much
        local a = loot.altUpgrade or {}
        local who = tostring(a.name or "Alt"):match("^(%S+)") or "Alt"
        lootValueText = GainText(a, ORANGE, "Alt upgrade", who)   -- v1.17.0
    elseif isReagent then
        lootValueText = TEAL .. "Reagent|r"
    else
        lootValueText = ValueText(loot)
    end
    FillSwapCard(popup.card2, loot, lootValueText)

    -- v1.16.0: the style follows the resolver's swap reason (POPUP_STYLES)
    local styleKey = "plain"
    if isGear then
        styleKey = (loot.gearVerdict == "TRADE_OFF") and "tradeoff" or "gear"
    elseif d.swapReason == "GEAR_ALT" then
        styleKey = "alt"
    elseif d.swapReason == "QUEST" then
        styleKey = "quest"
    elseif isReagent then
        styleKey = "reagent"
    end
    if styleKey ~= "plain" then
        SetPopupTitle(ApplyPopupStyle(popup, styleKey, {
            quality = d.lootQuality or loot.quality, card = popup.card2, title = "bags full, swap?",
        }))
    end

    if d.questSummary then
        -- v1.2.1: a quest item is swapped because you need it, not for
        -- its money value: no (red) profit line. v1.17.5: the text per
        -- quest state comes from the resolver; this only renders it.
        local qs = d.questSummary
        popup.summary:SetText(GOLD .. qs.label .. "|r" .. (qs.before or "")
            .. (qs.money and LOF.FormatMoney(qs.money) or "") .. (qs.after or ""))
    elseif d.swapReason == "GEAR" then
        -- v1.2.5: offered because the loot is better gear for you.
        local label = (d.gearVerdict == "TRADE_OFF") and (GOLD .. "Gear trade-off|r")
            or (GREEN .. "Gear upgrade|r")
        popup.summary:SetText(label .. " - worth more than "
            .. LOF.FormatMoney(d.bagValue) .. " to you")
    elseif d.swapReason == "GEAR_ALT" and d.altUpgrade then
        -- v1.5.0: offered because the loot is better gear for an alt.
        popup.summary:SetText(ORANGE .. "Gear upgrade for " .. tostring(d.altUpgrade.name)
            .. "|r - worth more than " .. LOF.FormatMoney(d.bagValue) .. " to you")
    elseif isReagent then
        popup.summary:SetText(ReagentText(d.reagent))
    else
        local profitColor = d.profit >= 0 and GREEN or RED
        local sign = d.profit >= 0 and "+" or "-"
        popup.summary:SetText(string.format("Loot %s     Bag %s     %sPROFIT %s%s|r",   -- v1.17.18
            LOF.FormatMoney(d.lootValue), LOF.FormatMoney(d.bagValue),
            profitColor, sign, LOF.FormatMoney(d.profit)))
    end

    -- v1.14.0: Previous / Next when more than one bag item qualifies
    local nav = (tonumber(d.total) or 0) > 1
    PlaceDecideButtons(nav)
    if nav then
        if d.canPrevious then popup.btnPrev:Enable() else popup.btnPrev:Disable() end
        if d.canNext then popup.btnNext:Enable() else popup.btnNext:Disable() end
    end
    -- v1.16.4: every reason line may wrap; the plain profit line stays on one
    if d.swapReason ~= "VALUE" then
        popup.summary:SetWidth(popup.innerWidth)
        popup.summary:SetWordWrap(true)
    end
    local showStats = (isGear or d.swapReason == "GEAR_ALT") and d.gearCompare or nil   -- v1.16.4
    LayoutSwapPopup(SetStaleNote(bag, loot), d.navNote, showStats)   -- v1.16.2: note also without nav
    RestorePosition(popup, "popup", "CENTER", 0, 180)
    popup:Show()
end

-- Info mode: loot on top, cheapest bag item below.
-- v1.17.19 / v1.17.20: a short notice on its own line directly under
-- Blizzard's messages: larger font, 3 s visible, 1 s fade, never stacks.
function UI.ShowNotice(text)
    local HOLD, FADE = 3, 1
    local f = UI.noticeFrame
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(900, 30)
        f:SetFrameStrata("HIGH")
        f:EnableMouse(false)
        local anchor = _G.UIErrorsFrame
        if anchor then
            f:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
        else
            f:SetPoint("TOP", UIParent, "TOP", 0, -180)
        end
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")   -- v1.17.21
        f.text:SetPoint("TOP", f, "TOP", 0, 0)
        f.text:SetTextColor(1, 0.82, 0)
        f:SetScript("OnUpdate", function(self, elapsed)
            self.t = (self.t or 0) + elapsed
            if self.t >= HOLD + FADE then
                self:Hide()
            elseif self.t > HOLD then
                self:SetAlpha(1 - (self.t - HOLD) / FADE)
            end
        end)
        f:Hide()
        UI.noticeFrame = f
    end
    f.text:SetText(tostring(text))
    f.t = 0
    f:SetAlpha(1)
    f:Show()
end

function UI.ShowInfoPopup(d)
    if not popup then BuildPopup() end
    SetPopupMode("info")
    ApplyPopupStyle(popup, "notworth")   -- v1.16.0
    local loot, bag = d.lootItem, d.bagItem
    local AUTO_CLOSE = 10   -- v1.16.3: was 6

    popup.caption1:SetText("Loot")
    local stale
    if d.infoKind == "nothing_swappable" or not bag then
        SetPopupTitle(RED .. "NOTHING AVAILABLE TO SWAP|r", true)   -- v1.17.19
        FillSwapCard(popup.card1, loot, ValueText(loot))
        popup.caption2:SetText(GREY .. "Your bags hold nothing LOF may swap.|r")
        popup.card2:Hide()
        popup.summary:SetText(GREY .. "(quest, whitelist or no value)|r")
        popup.btnAnyway:Hide()
        stale = SetStaleNote(loot)
    else
        SetPopupTitle(RED .. "NOT WORTH A SWAP|r", true)
        -- loot value red, bag value green
        FillSwapCard(popup.card1, loot, ValueText(loot, RED))
        popup.caption2:SetText("Your cheapest bag item")
        FillSwapCard(popup.card2, bag, ValueText(bag, GREEN))
        popup.summary:SetText(string.format("Loot %s < Bag %s  ->  %syou would lose %s|r",
            LOF.FormatMoney(loot.value), LOF.FormatMoney(bag.value),
            RED, LOF.FormatMoney(d.loss or 0)))   -- v1.17.10: resolver value
        stale = SetStaleNote(loot, bag)
    end

    LayoutSwapPopup(stale)
    popup.autoCloseAt = GetTime() + AUTO_CLOSE
    RestorePosition(popup, "popup", "CENTER", 0, 180)
    popup:Show()
end

-- v1.2.0: loot left behind on the corpse (safety net in Capture).
function UI.ShowLeftBehindPopup(item)
    -- v1.17.8: the chat line lives here (was a colour literal in Capture)
    LOF.Print(RED .. "Bag slot is free|r - open the corpse again to loot "
        .. LOF.ColorizeName(item.name, item.quality) .. ".")
    if not popup then BuildPopup() end
    SetPopupMode("left")
    ApplyPopupStyle(popup, "notworth")   -- v1.16.0
    SetPopupTitle(RED .. "LOOT LEFT BEHIND|r", true)
    local f = popup
    local x, y = 16, f.top
    f.caption1:SetText("Left on the corpse")
    f.caption1:ClearAllPoints()
    f.caption1:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    y = y - 18
    FillSwapCard(f.card1, item, ValueText(item))
    f.card1:ClearAllPoints()
    f.card1:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    y = y - CARD_HEIGHT - 10
    f.summary:SetWidth(f.innerWidth)
    f.summary:SetWordWrap(true)
    f.summary:SetText("Your bag slot is free. Open the corpse again:\n"
        .. "LOF will loot it for you automatically.")
    f.summary:ClearAllPoints()
    f.summary:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    y = y - f.summary:GetStringHeight() - 8
    f:SetHeight(-y + 14 + SWAP_BTN_H + 14)
    RestorePosition(f, "popup", "CENTER", 0, 180)
    f:Show()
end

function UI.HideLeftBehindPopup()
    if popup and popup.mode == "left" then popup:Hide() end
end

-- Hides the swap / destroy / info popup; the "loot left behind" popup
-- stays until the safety net or the player closes it.
function UI.HideSwapPopup()
    if popup and popup.mode ~= "left" then popup:Hide() end
end

-- -------------------------------------------------------------
-- List popup: All Items / Whitelist
-- -------------------------------------------------------------
local list
local LIST_WIDTH, LIST_HEIGHT = 300, 320

local function BuildList()
    list = CreatePanel("LOF_ListPopup", "list", LIST_WIDTH, LIST_HEIGHT, "HIGH")

    list.title = list:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    list.title:SetPoint("TOPLEFT", list, "TOPLEFT", PAD, -8)

    list.hint = list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    list.hint:SetPoint("TOPLEFT", list.title, "BOTTOMLEFT", 0, -2)

    list.close = CreateFrame("Button", nil, list, "UIPanelCloseButton")
    list.close:SetSize(22, 22)
    list.close:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, 0)

    list.scroll = CreateFrame("ScrollFrame", nil, list, "UIPanelScrollFrameTemplate")
    list.scroll:SetPoint("TOPLEFT", list, "TOPLEFT", PAD, -42)
    list.scroll:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -30, 10)

    list.content = CreateFrame("Frame", nil, list.scroll)
    list.content:SetSize(LIST_WIDTH - PAD - 30, 10)
    list.scroll:SetScrollChild(list.content)

    list.rows = {}
    list.empty = list.content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    list.empty:SetPoint("TOPLEFT", list.content, "TOPLEFT", 0, 0)

    RestorePosition(list, "list", "CENTER", -40, 0)
    list:Hide()
end

local function GetListRow(i)
    local row = list.rows[i]
    if not row then
        row = CreateItemRow(list.content, LIST_WIDTH - PAD - 34)
        row:SetPoint("TOPLEFT", list.content, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        list.rows[i] = row
    end
    return row
end

local function RenderAllItems(snap)
    list.title:SetText("All Items (" .. snap.candidateCount .. " swappable)")
    list.hint:SetText("Click: whitelist (session)  Shift: permanent  again: remove")
    local n = 0
    for _, item in ipairs(snap.allRows) do
        n = n + 1
        local row = GetListRow(n)
        local valueText
        local isReagent = item.excludeReason == Resolver.EXCLUDE_REAGENT   -- v1.11.0
        local relHint, relClick, relMark   -- v1.12.4: released items
        if item.isSwapCandidate then
            relHint, relClick, relMark = ReleasedRowAction(item)
            valueText = ValueText(item) .. (relMark or "")
        elseif isReagent then
            valueText = TEAL .. Resolver.GetExclusionLabel(item.excludeReason) .. "|r"
        else
            valueText = GREY .. Resolver.GetExclusionLabel(item.excludeReason) .. "|r"
        end
        FillItemRow(row, item.name, item.quality, item.icon, item.count, valueText, item.link)
        row.valueInfo = item
        row.hint = nil
        row.onClick = nil
        local canToggle = item.isSwapCandidate or item.excludeReason == Resolver.EXCLUDE_WHITELIST
        if isReagent then
            row.hint = "Kept as a profession reagent. Click: normal rules (this character)."
            local itemID = item.itemID
            row.onClick = function()
                Resolver.Reagents.SetChoice(itemID, false)
                LOF.RequestRefresh()
            end
        elseif item.excludeReason == Resolver.EXCLUDE_UPGRADE then   -- v1.12.3
            row.hint = "Protected as an upgrade. Click: normal rules (adds it to Ignored upgrades)."
            local itemID, itemName = item.itemID, item.name
            row.onClick = function()
                Resolver.Upgrade.Ignore(itemID, itemName)
                LOF.RequestRefresh()
            end
        elseif relClick then   -- v1.12.4
            row.hint = relHint
            row.onClick = relClick
        elseif canToggle then
            row.hint = item.whitelistStatus and WL_HINT_REMOVE or WL_HINT_ADD
            row.onClick = MakeWhitelistToggle(item.name, item.itemID)
        end
    end
    return n
end

local BLUE = "|cff66ccff"

local function RenderWhitelist()
    local rows = Resolver.GetWhitelistRows()
    list.title:SetText("Whitelist (" .. #rows .. ")")
    list.hint:SetText("Click an item to remove it.")
    for i, wl in ipairs(rows) do
        local row = GetListRow(i)
        local statusText
        if wl.status == "persistent" then
            statusText = GREEN .. "permanent|r"
        elseif wl.status == "default" then
            statusText = BLUE .. "default|r"
        else
            statusText = GREY .. "session|r"
        end
        local link = wl.itemID and ("item:" .. wl.itemID) or nil
        FillItemRow(row, wl.name, wl.quality, wl.icon or "Interface\\Icons\\INV_Misc_Note_01",
            1, statusText, link)
        row.hint = "Click to remove from whitelist."
        local itemName, itemID = wl.name, wl.itemID
        row.onClick = function()
            Resolver.RemoveFromWhitelist(itemName, itemID)
            LOF.RequestRefresh()
        end
    end
    return #rows
end

local function RenderIgnored()
    local rows = Resolver.Upgrade.GetIgnoredRows()
    list.title:SetText("Ignored upgrades (" .. #rows .. ")")
    list.hint:SetText("Click an item to suggest it again.")
    for i, ig in ipairs(rows) do
        local row = GetListRow(i)
        local status = ig.forName and (GREY .. "for " .. tostring(ig.forName) .. "|r") or (GREY .. "ignored|r")
        FillItemRow(row, ig.name, ig.quality, ig.icon, 1, status, "item:" .. ig.itemID)
        row.hint = "Click to remove from ignored upgrades."
        local itemID, forName = ig.itemID, ig.forName
        row.onClick = function()
            if forName then
                Resolver.Upgrade.UnignoreFor(itemID, forName)
            else
                Resolver.Upgrade.Unignore(itemID)
            end
            LOF.RequestRefresh()
        end
    end
    return #rows
end

local LIST_EMPTY_TEXT = {
    wl = "Whitelist is empty.",
    all = "Bags are empty.",
    ignored = "No ignored upgrades.",
}

local function RenderList(snap)
    if not list or not list:IsShown() then return end
    local n
    if list.mode == "wl" then
        n = RenderWhitelist()
    elseif list.mode == "ignored" then
        n = RenderIgnored()
    else
        n = RenderAllItems(snap)
    end
    for i = n + 1, #list.rows do
        list.rows[i]:Hide()
    end
    list.empty:SetText(LIST_EMPTY_TEXT[list.mode] or "")
    list.empty:SetShown(n == 0)
    list.content:SetHeight(math.max(10, n * ROW_HEIGHT))
end

function UI.ToggleList(mode)
    if not list then BuildList() end
    if list:IsShown() and list.mode == mode then
        list:Hide()
        return
    end
    if not list:IsShown() then
        ApplyAutoScale(list, "list", "CENTER", -40, 0)
    end
    list.mode = mode
    list:Show()
    LOF.RequestRefresh()
end

-- -------------------------------------------------------------
-- Upgrade popup (v0.4.0, Forever look & feel)
-- Renders a verdict from Resolver.Upgrade. Reason codes -> text via
-- templates; no decisions here. Uses Blizzard's own panel template
-- when the client has it, else falls back to the LOF backdrop.
-- -------------------------------------------------------------
local upgradePopups = {}   -- v1.5.0: [popupKind] = frame (SELF / ALT)
local UPGRADE_WIDTH = 390
local STAT_ROW_H    = 17

-- Numbers: whole numbers without decimals, DPS with one decimal.
local function FormatStatNumber(value)
    if math.abs(value - math.floor(value + 0.5)) < 0.05 then
        return tostring(math.floor(value + 0.5))
    end
    return string.format("%.1f", value)
end

local function FormatStatChange(value)
    if math.abs(value) < 0.05 then return GREY .. "=|r" end
    local text = (value > 0 and "+" or "-") .. FormatStatNumber(math.abs(value))
    return (value > 0 and GREEN or RED) .. text .. "|r"
end

local function StatLabel(key)
    local own = LOF.Data and LOF.Data.StatProfiles and LOF.Data.StatProfiles.statLabels   -- v1.17.17
    if own and own[key] then return own[key] end
    local label = _G[key]
    if type(label) ~= "string" or label == "" then label = key end
    return label
end

-- Reason templates (non-stat reasons shown under the table)
local REASON_TEXT = {
    EMPTY_SLOT = function()
        return GREEN .. "Nothing equipped in this slot.|r"
    end,
    -- v1.4.0: what the weighted verdict is based on
    WEIGHT_BASIS = function(r)
        local parts = {}
        local basis = r.basis or {}
        if r.source == "default" and basis[1] then
            return GREY .. "Based on: " .. tostring(basis[1].name) .. " (class default, no talent points yet).|r"
        end
        if #basis == 1 then
            return GREY .. "Based on: " .. tostring(basis[1].name) .. " (" .. tostring(basis[1].points) .. " points).|r"
        end
        for _, b in ipairs(basis) do
            parts[#parts + 1] = tostring(b.name) .. " " .. math.floor((b.share or 0) * 100 + 0.5) .. "%"
        end
        return GREY .. "Based on: " .. table.concat(parts, " / ") .. ".|r"
    end,
    TIE_BETTER_STATS = function()
        return GREEN .. "Same score; better on stats that do not count in the weights.|r"
    end,
    EFFECTS_NOT_COUNTED = function()
        return GREY .. "Effects not counted in the score.|r"
    end,
    REPLACES_BOTH = function(r)
        return GOLD .. "Two-hander: compared with main hand + off-hand.|r\n"
            .. GREY .. string.format("Off-hand damage counted at %d%% (beta data).",
                math.floor((tonumber(r.factor) or 0.5) * 100 + 0.5)) .. "|r"
    end,
}

local HINT_TEXT = {
    MAIN_STAT = function(h)
        local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[h.class]) or h.class
        local text = StatLabel(h.key) .. " is the main stat for " .. tostring(className) .. "."
        if h.confidence == "beta" then
            text = text .. " (beta data)"
        end
        return text
    end,
}

-- v1.5.0: one line per alt (text only; the resolver decided).
-- v1.17.0: ClassColored / GainText are the Kit helpers (top of file).

local function AltBasisText(a)
    local basis = a.basis or {}
    if a.source == "default" or not basis[1] then return "class default" end
    if #basis == 1 then return tostring(basis[1].name) end
    local parts = {}
    for _, b in ipairs(basis) do
        parts[#parts + 1] = tostring(b.name) .. " " .. math.floor((b.share or 0) * 100 + 0.5) .. "%"
    end
    return table.concat(parts, " / ")
end

local function AltLineText(a)
    local gain = GainText(a, GREEN, "upgrade")
    local text = ClassColored(a.name, a.class) .. "  " .. gain .. GREY .. "  (" .. AltBasisText(a) .. ")|r"
    if a.tooLow then
        text = text .. GOLD .. "  at level " .. tostring(a.needLevel) .. "|r"
    end
    return text
end

local STAT_COLS = { name = 0, old = 170, new = 235, change = 300 }
local STAT_COL_W = 60

local function CreateStatRow(parent)
    local r = {}
    r.name = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.name:SetJustifyH("LEFT")
    r.name:SetWidth(STAT_COLS.old - 8)
    r.old = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.old:SetJustifyH("RIGHT")
    r.old:SetWidth(STAT_COL_W)
    r.new = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.new:SetJustifyH("RIGHT")
    r.new:SetWidth(STAT_COL_W)
    r.change = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.change:SetJustifyH("RIGHT")
    r.change:SetWidth(STAT_COL_W)
    return r
end

-- v1.17.3: the number columns hang from the right edge of f.innerWidth,
-- so the same table fits a popup (358) and the Holdings panel (318).
local function PlaceStatRow(f, r, x, y)
    local w = tonumber(f.innerWidth) or (STAT_COLS.change + STAT_COL_W)
    local change = w - STAT_COL_W
    local new = change - (STAT_COLS.change - STAT_COLS.new)
    local old = new - (STAT_COLS.new - STAT_COLS.old)
    r.name:SetWidth(old - 8)
    r.name:ClearAllPoints();   r.name:SetPoint("TOPLEFT", f, "TOPLEFT", x + STAT_COLS.name, y)
    r.old:ClearAllPoints();    r.old:SetPoint("TOPLEFT", f, "TOPLEFT", x + old, y)
    r.new:ClearAllPoints();    r.new:SetPoint("TOPLEFT", f, "TOPLEFT", x + new, y)
    r.change:ClearAllPoints(); r.change:SetPoint("TOPLEFT", f, "TOPLEFT", x + change, y)
end

local function ShowStatRow(r, shown)
    r.name:SetShown(shown); r.old:SetShown(shown); r.new:SetShown(shown); r.change:SetShown(shown)
end

-- v1.16.6: THE comparison block (one function for every popup: the
-- Upgrade popup and the swap popup). gear = the resolver's comparison
-- (statRows, equippedItems, newEffects, reasons, hint, compareName);
-- nil hides it. opts.compared: show the "Compared with" line (the
-- Upgrade popup shows the equipped item as a card instead).
-- Draws: Compared with / Stat - Equipped - New - Change / Effects (New
-- green, Lost red + grey) / notes (Based on, ...) / hint. Returns new y.
RenderComparison = function(f, x, y, gear, opts)
    opts = opts or {}
    local g = f.cmp
    if not g then
        if not gear then return y end
        local c = f.content
        local width = f.innerWidth
        g = { rows = {}, effects = {} }
        g.compared = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        g.compared:SetJustifyH("LEFT")
        g.compared:SetWidth(width)
        g.header = CreateStatRow(c)
        for _, k in ipairs({ "name", "old", "new", "change" }) do g.header[k]:SetFontObject("GameFontNormalSmall") end
        g.header.name:SetText("Stat"); g.header.old:SetText("Equipped")
        g.header.new:SetText("New");   g.header.change:SetText("Change")
        g.divider = c:CreateTexture(nil, "ARTWORK")
        g.divider:SetHeight(1)
        g.divider:SetColorTexture(0.7, 0.55, 0.15, 0.8)
        g.effectsHead = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        g.effectsHead:SetText("Effects")
        g.notes = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        g.notes:SetJustifyH("LEFT")
        g.notes:SetWidth(width)
        g.notes:SetSpacing(3)
        g.hint = c:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        g.hint:SetJustifyH("LEFT")
        g.hint:SetWidth(width)
        f.cmp = g
    end
    -- hide everything first
    g.compared:Hide(); ShowStatRow(g.header, false); g.divider:Hide()
    g.effectsHead:Hide(); g.notes:Hide(); g.hint:Hide()
    for _, r in ipairs(g.rows) do ShowStatRow(r, false) end
    for _, e in ipairs(g.effects) do e.label:Hide(); e.text:Hide() end
    if not gear then return y end
    local width = f.innerWidth

    if opts.compared then
        y = y - 4
        local names = {}
        for _, e in ipairs(gear.equippedItems or {}) do
            names[#names + 1] = LOF.ColorizeName(e.name, e.quality)
        end
        local worn = gear.compareName and (ORANGE .. " (worn by " .. tostring(gear.compareName) .. ")|r") or ""
        g.compared:ClearAllPoints()
        g.compared:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        g.compared:SetText(GOLD .. "Compared with:|r " .. (#names > 0 and (table.concat(names, " + ") .. worn)
            or (GREY .. "nothing equipped in this slot|r" .. worn)))
        g.compared:Show()
        y = y - g.compared:GetStringHeight() - 8
    end

    -- stat table
    PlaceStatRow(f, g.header, x, y)
    ShowStatRow(g.header, true)
    y = y - 16
    g.divider:ClearAllPoints()
    g.divider:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    g.divider:SetWidth(width)
    g.divider:Show()
    y = y - 5
    local rows = gear.statRows or {}
    for i, data in ipairs(rows) do
        local r = g.rows[i]
        if not r then r = CreateStatRow(f.content); g.rows[i] = r end
        PlaceStatRow(f, r, x, y)
        r.name:SetText(StatLabel(data.key))
        r.old:SetText(data.hasOld and FormatStatNumber(data.old) or (GREY .. "-|r"))
        r.new:SetText(data.hasNew and FormatStatNumber(data.new) or (GREY .. "-|r"))
        r.change:SetText(FormatStatChange(data.delta))
        ShowStatRow(r, true)
        y = y - STAT_ROW_H
    end
    if #rows == 0 then
        local r = g.rows[1] or CreateStatRow(f.content)
        g.rows[1] = r
        PlaceStatRow(f, r, x, y)
        r.name:SetText(GREY .. "No stats on these items.|r")
        r.old:SetText(""); r.new:SetText(""); r.change:SetText("")
        ShowStatRow(r, true)
        y = y - STAT_ROW_H
    end

    -- effects (Blizzard's exact text, not counted in the score):
    -- the new item's in green ("New"), the ones you lose in grey ("Lost")
    local effectRows = {}
    for _, e in ipairs(gear.newEffects or {}) do
        effectRows[#effectRows + 1] = { label = GREEN .. "New|r", text = e }
    end
    for _, item in ipairs(gear.equippedItems or {}) do
        for _, e in ipairs(item.effects or {}) do
            effectRows[#effectRows + 1] = { label = RED .. "Lost|r", text = e, lost = true }
        end
    end
    if #effectRows > 0 then
        y = y - 10
        g.effectsHead:ClearAllPoints()
        g.effectsHead:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        g.effectsHead:Show()
        y = y - 16
    end
    local LABEL_W = 62
    for i, row in ipairs(effectRows) do
        local e = g.effects[i]
        if not e then
            e = {}
            e.label = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            e.label:SetJustifyH("LEFT")
            e.text = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            e.text:SetJustifyH("LEFT")
            g.effects[i] = e
        end
        e.label:ClearAllPoints(); e.label:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        e.label:SetText(row.label)
        e.text:ClearAllPoints(); e.text:SetPoint("TOPLEFT", f, "TOPLEFT", x + LABEL_W, y)
        e.text:SetWidth(width - LABEL_W)
        e.text:SetText(row.text)
        if row.lost then e.text:SetTextColor(0.6, 0.6, 0.6) else e.text:SetTextColor(0.12, 1, 0) end
        e.label:Show(); e.text:Show()
        y = y - e.text:GetStringHeight() - 4
    end

    -- non-stat reasons (Based on, empty slot, effects not counted, ...)
    local notes = {}
    for _, r in ipairs(gear.reasons or {}) do
        local fn = REASON_TEXT[r.code]
        if fn then notes[#notes + 1] = fn(r) end
    end
    if #notes > 0 then
        y = y - 8
        g.notes:ClearAllPoints()
        g.notes:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        g.notes:SetText(table.concat(notes, "\n"))
        g.notes:Show()
        y = y - g.notes:GetStringHeight() - 6
    end

    -- hint from the data layer (main stat of the class)
    local hintFn = gear.hint and HINT_TEXT[gear.hint.code]
    if hintFn then
        g.hint:ClearAllPoints()
        g.hint:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        g.hint:SetText(hintFn(gear.hint))
        g.hint:Show()
        y = y - g.hint:GetStringHeight() - 6
    end
    return y
end
UI.RenderComparison = function(...) return RenderComparison(...) end   -- v1.17.3: Holdings

-- kind: "SELF" (upgrade for you) or "ALT" (only for alts, orange).
local function BuildUpgradePopup(kind)
    local isAlt = kind == "ALT"
    local f = CreateStyledPanel(isAlt and "LOF_AltUpgradePopup" or "LOF_UpgradePopup",
        isAlt and "altupgrade" or "upgrade", UPGRADE_WIDTH, 330, "DIALOG")
    local inner = UPGRADE_WIDTH - 2 * 16
    f.kind = kind

    -- Content layer above the template's Inset (child frames draw over
    -- the parent's own regions, so everything lives on this frame).
    local c = CreateFrame("Frame", nil, f)
    c:SetAllPoints(f)
    c:SetFrameLevel(f:GetFrameLevel() + 10)
    f.content = c

    -- v1.5.0: orange background for the alt popup
    -- v1.5.9: muted green for an upgrade for you (shown per verdict)
    f.tint = c:CreateTexture(nil, "BACKGROUND")
    f.tint:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -22)
    f.tint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    f.tint:Hide()   -- v1.16.0: ApplyPopupStyle colours it

    -- v1.5.8: "For you: +x.x%"
    f.selfLine = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.selfLine:SetJustifyH("LEFT")

    -- v1.5.0: alt lines ("Also an upgrade for:" / "Upgrade for:")
    f.altHead = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.altHead:SetJustifyH("LEFT")
    f.altLines = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.altLines:SetJustifyH("LEFT")
    f.altLines:SetWidth(inner)
    f.altLines:SetSpacing(3)

    f.eqCard = CreateItemCard(c, inner)
    f.eqCard2 = CreateItemCard(c, inner)   -- off-hand, for two-handers
    f.newCard = CreateItemCard(c, inner)

    -- v1.16.6: stat table, effects, notes and hint: RenderComparison
    f.innerWidth = inner

    local function Btn(text)
        local b = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        b:SetSize(112, 26)
        b:SetText(text)
        return b
    end

    if not isAlt then
        f.btnEquip = Btn("Equip")
        f.btnEquip:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 12)
        f.btnEquip:SetScript("OnClick", function() LOF.Capture.EquipUpgrade() end)
    end

    -- Alt popup: OK = close, same as Cancel (not ignored).
    f.btnCancel = Btn(isAlt and "OK" or "Cancel")
    if isAlt then
        f.btnCancel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 12)
    else
        f.btnCancel:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
    end
    f.btnCancel:SetScript("OnClick", function() LOF.Capture.CancelUpgrade() end)
    f.btnCancel:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(isAlt and "Got it" or "Decide later")
        GameTooltip:AddLine("Keeps the item in your bag. Not ignored:", 1, 1, 1)
        GameTooltip:AddLine("/lof upgrade scan shows it again.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    f.btnCancel:SetScript("OnLeave", HideTooltip)

    f.btnIgnore = Btn("Ignore")
    f.btnIgnore:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 12)
    f.btnIgnore:SetScript("OnClick", function() LOF.Capture.IgnoreUpgrade() end)
    f.btnIgnore:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(isAlt and "Not interested" or "Don't equip")
        GameTooltip:AddLine("LOF will not suggest this item again.", 1, 1, 1)
        GameTooltip:AddLine("Manage with /lof ignored.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    f.btnIgnore:SetScript("OnLeave", HideTooltip)

    -- The template's close button (X) means: decide later.
    if f.CloseButton then
        f.CloseButton:SetScript("OnClick", function() LOF.Capture.CancelUpgrade() end)
    end

    f:Hide()
    upgradePopups[kind] = f
end

-- v1.5.0: the alt lines block; returns the new y.
local function PlaceAltBlock(f, x, y, header, alts)
    if not alts or #alts == 0 then
        f.altHead:Hide()
        f.altLines:Hide()
        return y
    end
    f.altHead:ClearAllPoints()
    f.altHead:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    f.altHead:SetText(header)
    f.altHead:Show()
    y = y - 16
    local lines = {}
    for _, a in ipairs(alts) do lines[#lines + 1] = AltLineText(a) end
    f.altLines:ClearAllPoints()
    f.altLines:SetPoint("TOPLEFT", f, "TOPLEFT", x + 8, y)
    f.altLines:SetText(table.concat(lines, "\n"))
    f.altLines:Show()
    return y - f.altLines:GetStringHeight() - 8
end

function UI.ShowUpgradePopup(v)
    local kind = (v.popupKind == "ALT") and "ALT" or "SELF"
    if not upgradePopups[kind] then BuildUpgradePopup(kind) end
    local f = upgradePopups[kind]
    -- only one upgrade popup at a time
    local other = upgradePopups[kind == "ALT" and "SELF" or "ALT"]
    if other then other:Hide() end
    local x = 16
    local y = f.styled and -32 or -30

    -- v1.16.0: one style function (POPUP_STYLES): alt orange, upgrade
    -- for you in the item's quality colour, trade-off plain. New card
    -- framed in the style colour, Equipped dimmed.
    local styleKey = (kind == "ALT") and "alt"
        or ((v.verdict == Resolver.Upgrade.UPGRADE_CLEAR) and "gear" or "plain")
    ApplyPopupStyle(f, styleKey, { quality = v.quality, card = f.newCard })
    SetCardDimmed(f.eqCard, true)
    SetCardDimmed(f.eqCard2, true)

    if f.selfLine then f.selfLine:Hide() end
    if kind == "ALT" then
        local top = v.alts and v.alts[1]
        if top and top.percent then
            SetPanelTitle(f, ORANGE .. string.format("Gear upgrade for alt: +%.1f%%", top.percent) .. "|r")
        else
            SetPanelTitle(f, ORANGE .. "Gear upgrade for alt|r")
        end
        -- v1.6.3: also for you, at a higher level
        local fs = v.futureSelf
        if fs then
            local gain
            if fs.emptySlot then
                gain = "empty slot"
            elseif fs.percent then
                gain = string.format("+%.1f%%", fs.percent)
            else
                gain = "upgrade"
            end
            f.selfLine:ClearAllPoints()
            f.selfLine:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
            f.selfLine:SetText(GOLD .. "For you:|r  " .. GREEN .. gain .. "|r" .. GOLD
                .. "  at level " .. tostring(fs.needLevel) .. "|r")
            f.selfLine:Show()
            y = y - f.selfLine:GetStringHeight() - 8
        end
        y = PlaceAltBlock(f, x, y, ORANGE .. "Upgrade for:|r", v.alts)
    elseif v.verdict == Resolver.Upgrade.UPGRADE_CLEAR then
        if v.percent then
            SetPanelTitle(f, string.format("Upgrade found: +%.1f%%", v.percent))
        else
            SetPanelTitle(f, "Upgrade found")
        end
    else
        SetPanelTitle(f, "Trade-off: you decide")
    end

    -- Item cards
    local equipped = v.equippedItems or {}
    f.eqCard:ClearAllPoints()
    f.eqCard:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    local eqLabel = "Equipped"
    if kind == "ALT" and v.compareName then
        eqLabel = ORANGE .. "Worn by " .. tostring(v.compareName) .. "|r"
    end
    local e1 = equipped[1]
    if e1 then
        FillItemCard(f.eqCard, e1.name, e1.quality, e1.icon, e1.link, e1.equipLoc, e1.subType, eqLabel)
    else
        FillItemCard(f.eqCard, GREY .. "(empty slot)|r", nil,
            "Interface\\PaperDoll\\UI-Backpack-EmptySlot", nil, nil, nil, eqLabel)
    end
    y = y - CARD_HEIGHT - 6

    local e2 = equipped[2]
    if e2 then
        f.eqCard2:ClearAllPoints()
        f.eqCard2:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        FillItemCard(f.eqCard2, e2.name, e2.quality, e2.icon, e2.link, e2.equipLoc, e2.subType, eqLabel)
        f.eqCard2:Show()
        y = y - CARD_HEIGHT - 6
    else
        f.eqCard2:Hide()
    end

    f.newCard:ClearAllPoints()
    f.newCard:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    FillItemCard(f.newCard, v.name, v.quality, v.icon, v.link, v.equipLoc, v.subType, GREEN .. "New|r")
    y = y - CARD_HEIGHT - 12

    -- v1.16.6: the one comparison block (same as the swap popup)
    y = RenderComparison(f, x, y, v)

    -- v1.5.8: what it means for you
    if kind == "SELF" and v.verdict == Resolver.Upgrade.UPGRADE_CLEAR then
        local emptySlot = false   -- v1.17.0: Kit.GainText
        for _, r in ipairs(v.reasons or {}) do
            if r.code == "EMPTY_SLOT" then emptySlot = true end
        end
        local gain = GainText({ percent = v.percent, emptySlot = (not v.percent) and emptySlot }, GREEN, "upgrade")
        f.selfLine:ClearAllPoints()
        f.selfLine:SetPoint("TOPLEFT", f, "TOPLEFT", x, y - 4)
        f.selfLine:SetText(GOLD .. "For you:|r  " .. gain)
        f.selfLine:Show()
        y = y - 4 - f.selfLine:GetStringHeight() - 8
    end

    -- v1.5.0: also an upgrade for alts (extra lines, nothing removed)
    if kind == "SELF" then
        y = PlaceAltBlock(f, x, y - 4, GOLD .. "Also an upgrade for:|r", v.alts)
    end

    f:SetHeight(-y + 50)
    RestorePosition(f, f.positionKey or (kind == "ALT" and "altupgrade" or "upgrade"), "CENTER", 0, 160)
    f:Show()
end

function UI.HideUpgradePopup()
    for _, f in pairs(upgradePopups) do f:Hide() end
end

-- -------------------------------------------------------------
-- Minimized state (v0.5.0): coin icon with free-slot counter.
-- LOF.db.shown     = LOF visible at all (/lof toggles this)
-- LOF.db.minimized = panel folded into the icon
-- -------------------------------------------------------------
local mini          -- the loose coin (our own frame)
local MINI_SIZE = 36
local ICON_NAME = "LootOptimizerForever"   -- v1.13.1: LibDBIcon name
local minimapButton   -- v1.13.1: the LibDBIcon button (nil without the libs)

-- v1.12.5 / v1.13.1: icon settings, also the LibDBIcon db table
-- (minimapPos in degrees, hide). hidden = loose (not at the minimap).
local MINI_DEFAULT_ANGLE = 200

local function MiniSettings()
    local m = LOF.db.miniIcon
    if type(m) ~= "table" then
        m = {}   -- everyone starts on the minimap
        LOF.db.miniIcon = m
    end
    if m.minimapPos == nil then
        m.minimapPos = tonumber(m.angle) or MINI_DEFAULT_ANGLE   -- v1.13.1: keep the old spot
    end
    return m
end

local function GetIconLib()
    local LibStub = _G.LibStub
    return LibStub and LibStub("LibDBIcon-1.0", true), LibStub and LibStub("LibDataBroker-1.1", true)
end

-- v1.12.6: loose on the screen; first time where the dashboard's
-- top-right corner is.
local function PlaceFree()
    if LOF.db.frames.mini then
        RestorePosition(mini, "mini", "CENTER", 300, 0)
        return
    end
    mini:ClearAllPoints()
    local right, top = panel and panel:GetRight(), panel and panel:GetTop()
    if right and top then
        mini:SetPoint("TOPLEFT", UIParent, "TOPLEFT", right - MINI_SIZE, top - UIParent:GetTop())
        SavePosition(mini, "mini")
    else
        mini:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    end
end

-- v1.13.1: the tooltip of both icons. loose = the loose coin.
local function FillIconTooltip(tip, loose)
    local snap = Resolver.GetDashboardSnapshot()
    tip:AddLine("LootOptimizer Forever")
    tip:AddDoubleLine("Gold on hand:", LOF.FormatMoney(snap.money), 1, 0.82, 0, 1, 1, 1)
    tip:AddDoubleLine("Vendor:", LOF.FormatMoney(snap.vendorTotal), 1, 0.82, 0, 1, 1, 1)
    tip:AddDoubleLine("Total:", LOF.FormatMoney(snap.total), 0.4, 1, 0.4, 1, 1, 1)
    if snap.valueActive then
        tip:AddDoubleLine("Possible total:", LOF.FormatMoney(snap.possibleTotal or 0), 1, 0.82, 0, 1, 1, 1)
    end
    local fr, fg, fb = 1, 1, 1
    if snap.freeSlots == 0 then fr, fg, fb = 1, 0.4, 0.4 end
    tip:AddDoubleLine("Free slots:", tostring(snap.freeSlots), 1, 0.82, 0, fr, fg, fb)
    -- v1.6.0: professions + materials
    local ps = Resolver.Holdings and Resolver.Holdings.GetProfessionStatus()
    local DASH = "- - - - - - - - - - - - - - - - - - - -"
    if ps and #ps.rows > 0 then
        tip:AddLine(DASH, 0.5, 0.5, 0.5)
        for _, p in ipairs(ps.rows) do
            local skill = p.level .. "/" .. p.max
            if p.status == "TRAIN" then
                tip:AddDoubleLine(p.name .. "  " .. skill, "Visit a trainer", 1, 0.82, 0, 0.4, 1, 0.4)
            elseif p.status == "TRAIN_LEVEL" then   -- v1.9.3
                tip:AddDoubleLine(p.name .. "  " .. skill, "Trainer at level " .. tostring(p.requiredLevel),
                    1, 0.82, 0, 0.6, 0.6, 0.6)
            else
                tip:AddDoubleLine(p.name, skill, 1, 0.82, 0, 1, 1, 1)
            end
            if p.hasMaterials then
                if #p.materials == 0 then
                    tip:AddLine("   no materials", 0.6, 0.6, 0.6)
                end
                for _, m in ipairs(p.materials) do
                    local text = "   " .. LOF.ColorizeName(m.name or m.link or "?", m.quality) .. "  " .. m.bag
                    if (m.bank or 0) > 0 then text = text .. GREY .. "  (bank " .. m.bank .. ")|r" end
                    tip:AddLine(text, 1, 1, 1)
                end
                if (p.moreMaterials or 0) > 0 then
                    tip:AddLine("   +" .. p.moreMaterials .. " more", 0.6, 0.6, 0.6)
                end
            end
        end
    end
    tip:AddLine(DASH, 0.5, 0.5, 0.5)
    tip:AddLine("Click: open / close LOF    Right-click: Settings", 0.7, 0.7, 0.7)
    if loose then
        tip:AddLine("Drag: move    Shift-right-click: back to the minimap", 0.7, 0.7, 0.7)
    else
        tip:AddLine("Drag: move along the minimap", 0.7, 0.7, 0.7)
        tip:AddLine("Shift-right-click: place it loose (shows while LOF is closed)", 0.7, 0.7, 0.7)
    end
end

-- v1.13.1: minimap <-> loose
local function SetLoose(loose)
    MiniSettings().hidden = loose and true or nil
    if loose then
        LOF.Print("LOF icon placed loose: it shows while the dashboard is closed. "
            .. "Shift-right-click it to put it back on the minimap.")
    end
    UI.ApplyVisibility()
end

local function IconClick(button)
    if button == "RightButton" then
        if IsShiftKeyDown() then
            SetLoose(not MiniSettings().hidden)
        elseif UI.ToggleSettingsWindow then
            UI.ToggleSettingsWindow()
        end
        return
    end
    UI.ToggleDashboard()
end

-- v1.13.1: the minimap button via LibDataBroker + LibDBIcon, so minimap
-- button collectors (Leatrix Plus and others) can gather it.
local function BuildMinimapButton()
    local icon, ldb = GetIconLib()
    if not (icon and ldb) then return end
    local obj = ldb:GetDataObjectByName(ICON_NAME) or ldb:NewDataObject(ICON_NAME, {
        type = "launcher",
        label = "LootOptimizer Forever",
        icon = COIN_ICON,
        OnClick = function(_, button) IconClick(button) end,
        OnTooltipShow = function(tip) FillIconTooltip(tip, false) end,
    })
    if not icon:IsRegistered(ICON_NAME) then
        local m = MiniSettings()
        m.hide = m.hidden and true or nil   -- LibDBIcon reads db.hide at Register
        icon:Register(ICON_NAME, obj, m)
    end
    minimapButton = icon:GetMinimapButton(ICON_NAME)
    if minimapButton and not minimapButton.lofCount then
        minimapButton.lofCount = minimapButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        minimapButton.lofCount:SetPoint("BOTTOMRIGHT", minimapButton, "BOTTOMRIGHT", 0, 0)
    end
end

local function BuildMini()
    local b = CreateFrame("Button", "LOF_MiniButton", UIParent)
    b:SetSize(MINI_SIZE, MINI_SIZE)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:SetClampedToScreen(true)
    b:SetMovable(true)
    b:RegisterForDrag("LeftButton")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexture(COIN_ICON)
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    if b.icon.SetMask then
        b.icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    end

    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b.border:SetSize(MINI_SIZE * 1.6, MINI_SIZE * 1.6)
    b.border:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)

    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)

    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    -- the loose coin: drag moves it freely
    b:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:StartMoving()
    end)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self, "mini")
        C_Timer.After(0, function() self.dragging = false end)
    end)
    b:SetScript("OnClick", function(self, button)
        if self.dragging then return end
        IconClick(button)
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        FillIconTooltip(GameTooltip, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", HideTooltip)

    b:Hide()
    mini = b
    BuildMinimapButton()   -- v1.13.1
end

local function SetCount(fs, free)
    if not fs then return end
    fs:SetText(tostring(free))
    if free == 0 then fs:SetTextColor(1, 0.25, 0.25) else fs:SetTextColor(1, 1, 1) end
end

-- v1.13.1: is any LOF icon on screen (for the refresh)
local function IconsShown()
    return (mini and mini:IsShown()) or (minimapButton and minimapButton:IsShown()) or false
end

local function RenderMini(snap)
    local free = tonumber(snap.freeSlots) or 0
    if mini and mini:IsShown() then SetCount(mini.count, free) end
    if minimapButton then SetCount(minimapButton.lofCount, free) end
end

-- Single place that decides what is on screen.
-- v1.13.1: at the minimap = the LibDBIcon button (always shown); loose
-- = our coin, only while the dashboard is closed. Without the libs the
-- loose coin is the only icon.
function UI.ApplyVisibility()
    if not panel then return end
    if not mini then BuildMini() end
    local dashboardOpen = LOF.db.shown and not LOF.db.minimized
    local loose = MiniSettings().hidden or not minimapButton
    -- only on a real change: a collector (Leatrix ...) may have hidden
    -- the button in its own bag, and Show would pull it out again
    local icon = GetIconLib()
    if icon and minimapButton and loose ~= minimapButton.lofLoose then
        if minimapButton.lofLoose ~= nil or loose then
            if loose then icon:Hide(ICON_NAME) else icon:Show(ICON_NAME) end
        end
        minimapButton.lofLoose = loose
        MiniSettings().hide = loose and true or nil
    end
    if loose and not dashboardOpen then
        PlaceFree()
        mini:Show()
    else
        mini:Hide()
    end
    panel:SetShown(dashboardOpen and true or false)
    LOF.RequestRefresh()
end

-- v1.13.1: /lof reset - back to the minimap, default spot
local function ResetIcon()
    local m = MiniSettings()
    m.hidden = nil
    m.hide = nil
    m.minimapPos = MINI_DEFAULT_ANGLE
    local icon = GetIconLib()
    if icon and icon:IsRegistered(ICON_NAME) then icon:Refresh(ICON_NAME, m) end
end

function UI.ToggleDashboard()
    if LOF.db.shown and not LOF.db.minimized then
        LOF.db.minimized = true
    else
        LOF.db.shown = true
        LOF.db.minimized = nil
    end
    UI.ApplyVisibility()
end

function UI.IsMinimapIconShown()
    return not MiniSettings().hidden
end

function UI.SetMinimapIconShown(shown)
    MiniSettings().hidden = (not shown) or nil
    UI.ApplyVisibility()
end

-- v1.9.1
function UI.IsDashboardOpen()
    return panel ~= nil and LOF.db.shown and not LOF.db.minimized and true or false
end

function UI.SetMinimized(minimized)
    LOF.db.minimized = minimized and true or nil
    UI.ApplyVisibility()
end

-- -------------------------------------------------------------
-- Bag tooltip line (v1.1.2)
-- One short line on the tooltip of an item in the player's bags:
-- which value LOF uses. Shown only while the Auctionator integration
-- is active (otherwise LOF always uses the vendor price, which the
-- game tooltip already shows).
-- -------------------------------------------------------------
local function AddBagValueLine(tip, bag, slot)
    if not Resolver.Value.IsActive() then return end
    local info = Resolver.GetBagSlotInfo(bag, slot)
    if not info or not info.infoReady then return end
    if AddValueBlock(tip, info) then tip:Show() end
end

-- v1.5.1: "LOF: upgrade for ..." (text only; the resolver decided).
local ALT_TOOLTIP_MAX = 3

local function AltTooltipName(a)
    local text = tostring(a.name)
    if a.emptySlot then
        text = text .. " (empty slot)"
    elseif a.percent then
        text = text .. string.format(" +%.1f%%", a.percent)
    end
    if a.tooLow then
        text = text .. " (at level " .. tostring(a.needLevel) .. ")"
    end
    return text
end

-- v1.6.1: stat changes "+8 Armor  +1 Intellect"
-- v1.9.5: returned as a list of lines, at most STATS_PER_LINE each,
-- every line with the same indent (no game word wrap).
local STATS_PER_LINE = 3
-- v1.17.4: THE compact stat line ("+6.2 damage per second   +1 Spell Power"),
-- for item tooltips and lists (Send to alts). Full tables: RenderComparison.
-- indent: text in front of every line (tooltip default 5 spaces).
local function StatChangeText(rows, indent)
    indent = indent or "     "
    local parts = {}
    for _, r in ipairs(rows or {}) do
        local d = tonumber(r.delta) or 0
        if math.abs(d) >= 0.05 then
            local c = d > 0 and GREEN or RED
            parts[#parts + 1] = c .. (d > 0 and "+" or "-") .. FormatStatNumber(math.abs(d)) .. " " .. StatLabel(r.key) .. "|r"
        end
    end
    if #parts == 0 then return nil end
    local lines = {}
    for i = 1, #parts, STATS_PER_LINE do
        local chunk = {}
        for j = i, math.min(i + STATS_PER_LINE - 1, #parts) do chunk[#chunk + 1] = parts[j] end
        lines[#lines + 1] = indent .. table.concat(chunk, "   ")
    end
    return lines
end
UI.Kit.StatChangeLines = StatChangeText   -- v1.17.4: Send to alts uses the same lines

local function AddStatLines(tip, rows)
    local lines = StatChangeText(rows)
    for _, line in ipairs(lines or {}) do tip:AddLine(line, 1, 1, 1, false) end
end

-- v1.17.17 (E5): one alt per line; rows (if given) go under the first,
-- best alt. Replaces AltNamesText (comma list that wrapped unindented).
local function AddAltLines(tip, alts, rows)
    for i = 1, math.min(#alts, ALT_TOOLTIP_MAX) do
        tip:AddLine("     " .. AltTooltipName(alts[i]), 1, 0.6, 0.2, false)
        if i == 1 and rows then
            for _, line in ipairs(StatChangeText(rows, "        ") or {}) do tip:AddLine(line, 1, 1, 1, false) end
        end
    end
    if #alts > ALT_TOOLTIP_MAX then
        tip:AddLine("     and " .. (#alts - ALT_TOOLTIP_MAX) .. " more", 1, 0.6, 0.2, false)
    end
end

-- v1.6.1: LOF upgrade lines for any item tooltip
local function AddUpgradeLines(tip, link, bag, slot)
    local info = Resolver.Upgrade.GetTooltipInfo(link, bag, slot)
    if not info then return end
    local added = false
    if info.self then
        local gain = GainText(info.self, "", "upgrade")   -- v1.17.4: the Kit helper
        if info.self.tooLow then gain = gain .. " (at level " .. tostring(info.self.needLevel) .. ")" end
        tip:AddLine(" ")   -- v1.17.17 (E5)
        tip:AddLine("LOF: upgrade for you " .. gain, 0.4, 1, 0.4, true)
        AddStatLines(tip, info.self.rows)
        if #info.alts > 0 then
            tip:AddLine("LOF: also for", 1, 0.6, 0.2)
            AddAltLines(tip, info.alts)
        end
        added = true
    elseif #info.alts > 0 then
        tip:AddLine(" ")   -- v1.17.17 (E5)
        tip:AddLine("LOF: upgrade for", 1, 0.6, 0.2)
        AddAltLines(tip, info.alts, info.altRows)
        added = true
    end
    if added then tip:Show() end
end

local function AddBagLines(tip, bag, slot)
    AddBagValueLine(tip, bag, slot)
    local c = LOF.GetContainerItemInfo(bag, slot)
    if c and c.hyperlink then AddUpgradeLines(tip, c.hyperlink, bag, slot) end
end

-- v1.6.1: tooltips that are not a bag item (AH, vendor, loot, links).
-- Equipped gear (character pane) is skipped: comparing with itself.
local SKIP_GETTERS = { GetInventoryItem = true }

-- v1.10.2: only the disenchant lines (value from the resolver)
local function AddLinkDisenchantLines(tip, link)
    if not Resolver.Value.IsDisenchantActive() then return end
    local v = Resolver.BuildItemInfo(link, 1)
    if not v or not v.de then return end
    tip:AddLine(" ")
    tip:AddDoubleLine(GOLD .. "LOF:|r Disenchant value",
        DE_COLOR .. "~" .. LOF.FormatMoney(v.de.each or 0) .. "|r", 1, 1, 1, 1, 1, 1)
    AddDisenchantLines(tip, v, true)
    tip:Show()
end

local function AddItemLines(tip, data, info)
    if info and SKIP_GETTERS[info.getterName or ""] then return end
    local link
    if tip.GetItem then
        local _, l = tip:GetItem()
        link = l
    end
    link = link or (data and data.hyperlink)
    if link then
        AddLinkDisenchantLines(tip, link)
        AddUpgradeLines(tip, link)
    end
end

local function InstallBagTooltipHook()
    -- v1.17.7: one chat line per session for a tooltip error (both routes).
    -- v1.17.12: inside this function (UI.lua's 200-local limit).
    local tooltipErrorShown = false
    local function ReportTooltipError(ok, err)
        if ok or tooltipErrorShown then return end
        tooltipErrorShown = true
        LOF.Print(RED .. "tooltip error (shown once):|r " .. tostring(err))
    end
    local TDP = _G.TooltipDataProcessor
    local ItemType = _G.Enum and _G.Enum.TooltipDataType and _G.Enum.TooltipDataType.Item
    if TDP and TDP.AddTooltipPostCall and ItemType and _G.C_TooltipInfo then
        TDP.AddTooltipPostCall(ItemType, function(tip, data)
            if tip ~= GameTooltip and tip ~= _G.ItemRefTooltip then return end
            local info = tip.info or tip.processingInfo
            local ok, err
            if info and info.getterName == "GetBagItem" and info.getterArgs then
                ok, err = pcall(AddBagLines, tip, info.getterArgs[1], info.getterArgs[2])
            else
                ok, err = pcall(AddItemLines, tip, data, info)   -- v1.6.1
            end
            ReportTooltipError(ok, err)   -- v1.17.7
        end)
    elseif GameTooltip.SetBagItem and hooksecurefunc then
        hooksecurefunc(GameTooltip, "SetBagItem", function(tip, bag, slot)
            ReportTooltipError(pcall(AddBagLines, tip, bag, slot))   -- v1.17.7
        end)
    end
end

-- -------------------------------------------------------------
-- Refresh (throttled)
-- -------------------------------------------------------------
local refreshPending = false

function UI.RefreshNow()
    refreshPending = false
    if UI.RefreshHoldingsWindow then UI.RefreshHoldingsWindow() end
    if UI.RefreshAltMailWindow then UI.RefreshAltMailWindow() end   -- v1.8.0
    if UI.RefreshSettingsWindow then UI.RefreshSettingsWindow() end   -- v1.12.0
    local panelShown = panel and panel:IsShown()
    local listShown = list and list:IsShown()
    local miniShown = IconsShown()   -- v1.13.1: loose coin or minimap button
    if not panelShown and not listShown and not miniShown then return end
    local snap = Resolver.GetDashboardSnapshot()
    RenderPanel(snap)
    RenderList(snap)
    RenderMini(snap)
end

function LOF.RequestRefresh()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0.1, UI.RefreshNow)
end

-- -------------------------------------------------------------
-- Init + slash commands
-- -------------------------------------------------------------
LOF.OnInit(function()
    BuildPanel()
    UI.ApplyVisibility()
    InstallBagTooltipHook()
end)

local function ResetPositions()
    LOF.db.frames = {}
    if panel then RestorePosition(panel, "main", "CENTER", 300, 0) end
    if popup then RestorePosition(popup, "popup", "CENTER", 0, 180) end
    if list then RestorePosition(list, "list", "CENTER", -40, 0) end
    for _, f in pairs(upgradePopups) do RestorePosition(f, f.positionKey, "CENTER", 0, 160) end
    ResetIcon()   -- v1.13.1: icon back on the minimap
    if panel then UI.ApplyVisibility() end
    LOF.Print("Window positions reset.")
end

SLASH_LOF1 = "/lof"
SlashCmdList["LOF"] = function(msg)
    msg = string.lower(strtrim(msg or ""))
    if msg == "" or msg == "toggle" then
        LOF.db.shown = not LOF.db.shown
        if LOF.db.shown then LOF.db.minimized = nil end
        UI.ApplyVisibility()
    elseif msg == "show" then
        LOF.db.shown = true
        LOF.db.minimized = nil
        UI.ApplyVisibility()
    elseif msg == "hide" then
        LOF.db.shown = false
        UI.ApplyVisibility()
    elseif msg == "mini" then
        LOF.db.shown = true
        UI.SetMinimized(true)
    elseif msg == "reset" then
        ResetPositions()
    elseif msg == "all" then
        UI.ToggleList("all")
    elseif msg == "wl" then
        UI.ToggleList("wl")
    elseif msg == "ignored" then
        UI.ToggleList("ignored")
    elseif msg == "upgrade on" then
        UI.SetUpgradeAdvisor(true)
        LOF.Print("Upgrade Advisor on (this character).")
    elseif msg == "upgrade off" then
        UI.SetUpgradeAdvisor(false)
        LOF.Print("Upgrade Advisor off (this character).")
    elseif msg == "upgrade scan" then
        LOF.Capture.ScanBagsForUpgrades("button")
    elseif msg == "upgrade" then
        LOF.Print("Upgrade Advisor is " .. (Resolver.Upgrade.IsEnabled() and "on" or "off")
            .. ". /lof upgrade on|off|scan")
    elseif msg == "holdings" then
        if UI.ToggleHoldingsWindow then UI.ToggleHoldingsWindow() end
    elseif msg == "guide" or msg == "news" then   -- v1.13.0
        if UI.ToggleGuideWindow then UI.ToggleGuideWindow("whatsnew") end
    elseif msg == "guide colors" or msg == "colors" then   -- v1.15.1
        if UI.ShowGuideWindow then UI.ShowGuideWindow("colors", false) end
    elseif msg == "room" then   -- v1.12.1
        LOF.Capture.StartMakeRoomNow()
    elseif msg == "settings" then   -- v1.12.0
        if UI.ToggleSettingsWindow then UI.ToggleSettingsWindow() end
    elseif msg == "version" then
        -- v1.17.11: one line per layer
        local lines = UI.GetVersionLines()
        LOF.Print(lines[1])
        for i = 2, #lines do print(lines[i]) end
    else
        LOF.Print("/lof [show|hide|toggle|mini]  -  panel / coin icon")
        LOF.Print("/lof all  -  all bag items    /lof wl  -  whitelist")
        LOF.Print("/lof upgrade on|off|scan  -  Upgrade Advisor    /lof ignored  -  ignored upgrades")
        LOF.Print("/lof room  -  make room now    /lof holdings    /lof settings    /lof guide")
        LOF.Print("/lof reset  -  reset window positions    /lof version")
    end
end
