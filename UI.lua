-- TalentKeeper UI: fonts, the button by Blizzard's loadout dropdown, the build menu,
-- and one small text window (name a build, paste / copy a string, read the log).
local addonName, TK = ...
local B = TK.builds
local UI = {}
TK.ui = UI

-- Fonts and colors (suite style guide) ---------------------------------------------
local FONT = "Interface\\AddOns\\" .. addonName .. "\\Media\\BarlowSemiCondensed-Medium.ttf"
local SIZES = { TalentKeeperFontSmall = 10, TalentKeeperFont = 12, TalentKeeperFontLarge = 16, TalentKeeperFontDisabled = 12 }
local fonts = {}
for name, size in pairs(SIZES) do fonts[name] = CreateFont(name) fonts[name]:SetFont(FONT, size, "") end
local disabledFont = fonts.TalentKeeperFontDisabled
disabledFont:SetTextColor(0.55, 0.55, 0.55)
-- Expressway when another addon has registered it with LibSharedMedia (it can't ship here).
TK.on("PLAYER_LOGIN", function()
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    local face = lsm and lsm:Fetch("font", "Expressway", true)
    if face then for name, size in pairs(SIZES) do fonts[name]:SetFont(face, size, "") end end
end)

local function fill(frame, layer, r, g, b, a)
    local t = frame:CreateTexture(nil, layer)
    t:SetAllPoints()
    t:SetColorTexture(r, g, b, a)
    return t
end

-- 1px ring around a frame.
local function ring(frame, gray)
    local edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(gray, gray, gray, 1)
        t:SetTexelSnappingBias(0); t:SetSnapToPixelGrid(false)
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT"); t:SetHeight(1)
        else
            t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side); t:SetWidth(1)
        end
        edges[#edges + 1] = t
    end
    return function(g) for _, t in ipairs(edges) do t:SetColorTexture(g, g, g, 1) end end
end

-- Flat button: face at rest, gray ring, hover wash.
local function button(parent, label, width, onClick)
    local bt = CreateFrame("Button", nil, parent)
    bt:SetSize(width, 24)
    fill(bt, "BACKGROUND", 1, 1, 1, 0.07)
    local setRing = ring(bt, 0.4)
    local hover = fill(bt, "HIGHLIGHT", 0.851, 0.851, 0.851, 0.15)
    hover:SetBlendMode("BLEND")
    bt:SetNormalFontObject(TalentKeeperFont)
    bt:SetDisabledFontObject(disabledFont)
    bt:SetText(label)
    bt:SetScript("OnEnter", function() setRing(0.7) end)
    bt:SetScript("OnLeave", function() setRing(0.4) end)
    bt:SetScript("OnClick", TK.safe(onClick))
    return bt
end

UI.fill, UI.ring, UI.button = fill, ring, button

-- Text window --------------------------------------------------------------------
-- UI.textWindow{ title, text, okText?, onOK?(text), readOnly?, singleLine? }
local win
local function makeWindow()
    win = CreateFrame("Frame", "TalentKeeperTextWindow", UIParent)
    win:SetSize(460, 260)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    win:SetClampedToScreen(true)
    fill(win, "BACKGROUND", 0.031, 0.031, 0.031, 0.97)
    ring(win, 0)
    tinsert(UISpecialFrames, win:GetName()) -- Escape closes it

    win.title = win:CreateFontString(nil, "OVERLAY", "TalentKeeperFontLarge")
    win.title:SetPoint("TOPLEFT", 12, -10)

    win.box = CreateFrame("Frame", nil, win)
    win.box:SetPoint("TOPLEFT", 12, -36)
    win.box:SetPoint("BOTTOMRIGHT", -12, 44)
    fill(win.box, "BACKGROUND", 1, 1, 1, 0.08)
    win.setRing = ring(win.box, 0.4)

    win.scroll = CreateFrame("ScrollFrame", nil, win.box, "ScrollFrameTemplate")
    win.scroll:SetPoint("TOPLEFT", 6, -6)
    win.scroll:SetPoint("BOTTOMRIGHT", -24, 6)
    win.edit = CreateFrame("EditBox", nil, win.scroll)
    win.edit:SetFontObject(ChatFontNormal)
    win.edit:SetAutoFocus(false)
    win.edit:SetSize(400, 20)
    win.scroll:SetScrollChild(win.edit)
    -- An edit box inside a scroll frame draws nothing until it has a size: track the scroll area.
    win.scroll:SetScript("OnSizeChanged", function(_, w, h) win.edit:SetWidth(w) win.edit:SetHeight(h) end)
    win.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); win:Hide() end)
    win.edit:SetScript("OnEditFocusGained", function() win.setRing(0.596) end)
    win.edit:SetScript("OnEditFocusLost", function() win.setRing(0.4) end)
    win.edit:SetScript("OnEnterPressed", function(self)
        if win.single and win.ok:IsShown() then win.ok:Click() end
    end)
    win.edit:SetScript("OnTextChanged", function(self, user)
        if user and win.readOnly then self:SetText(win.fixedText) self:HighlightText() end
    end)
    win.box:SetScript("OnMouseDown", function() win.edit:SetFocus() end)

    win.close = button(win, "Close", 80, function() win:Hide() end)
    win.close:SetPoint("BOTTOMRIGHT", -12, 12)
    win.ok = button(win, "Save", 80, function()
        local text = win.edit:GetText()
        win:Hide()
        if win.onOK then win.onOK(text) end
    end)
    win.ok:SetPoint("RIGHT", win.close, "LEFT", -8, 0)
    win:SetScript("OnHide", function() win.edit:ClearFocus() end)
end

function UI.textWindow(opts)
    if not win then makeWindow() end
    win.title:SetText(opts.title)
    win.onOK, win.readOnly, win.single, win.fixedText = opts.onOK, opts.readOnly, opts.singleLine, opts.text or ""
    win.edit:SetMultiLine(not opts.singleLine)
    win:SetHeight(opts.singleLine and 120 or 260)
    win.ok:SetText(opts.okText or "Save")
    win.ok:SetShown(opts.onOK ~= nil)
    win.edit:SetText(opts.text or "")
    win:Show()
    win.edit:SetFocus()
    win.edit:HighlightText()
    if opts.readOnly then win.edit:SetCursorPosition(#win.fixedText) win.edit:HighlightText() end
end

-- Build menu ---------------------------------------------------------------------------
local armed -- the build whose Delete was clicked once (second click within 3 s deletes)

-- How a build differs from the talents you have now, as the top of its submenu.
local function diffLines(entry, current, b)
    local C = TK.compare
    local d = current and C.diff(current, b.text)
    if not d then return end
    local hero = C.heroName(b.text)
    if hero then entry:CreateTitle(hero) end
    if #d == 0 then
        entry:CreateTitle("|cff98ff98Matches your current talents|r")
    else
        entry:CreateTitle(("Differs from your current talents by %d:"):format(#d))
        for _, line in ipairs(C.describe(d, 8)) do
            entry:CreateButton("|cffbdbdbd" .. line .. "|r"):SetEnabled(false)
        end
    end
    if b.outdated then
        entry:CreateButton(("|cffffb84dOutdated: %d talent%s no longer fit your tree|r"):format(b.outdated, b.outdated == 1 and "" or "s")):SetEnabled(false)
    end
    entry:CreateDivider()
end

local function label(list, b)
    local text = b.main and ("|cff8c8c8c·|r " .. b.name) or b.name
    local same = TK.compare.sameAsEarlier(list, b)
    if same then text = text .. "  |cff8c8c8csame as " .. same.name .. "|r" end
    if b.outdated then text = text .. "  |cffffb84dOutdated|r" end
    if b.needsReview then text = text .. "  |cffffb84dNeeds review|r" end
    return text
end

-- Gear set picker: the player's Blizzard equipment sets, or none.
function UI.gearMenu(parent, b, flat)
    local sub = flat and parent or parent:CreateButton("Gear set" .. (b.gear and (": " .. b.gear) or ""))
    sub:CreateRadio("None", function() return b.gear == nil end, function() B.setGear(b, nil) end)
    for _, id in ipairs(C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs() or {}) do
        local name = C_EquipmentSet.GetEquipmentSetInfo(id)
        if name then sub:CreateRadio(name, function() return b.gear == name end, function() B.setGear(b, name) end) end
    end
end

-- A variant's changes from its main build, by talent name.
local function variantLines(entry, b)
    if not b.main then return end
    local n = b.changes and #b.changes or 0
    entry:CreateTitle(("Variant of %s: %d change%s"):format(b.main, n, n == 1 and "" or "s"))
    for _, line in ipairs(TK.compare.describe(b.changes or {}, 6)) do
        entry:CreateButton("|cffbdbdbd" .. line .. "|r"):SetEnabled(false)
    end
    if b.needsReview then
        entry:CreateButton("|cffffb84dNeeds review: its main build changed a talent this variant changes too|r"):SetEnabled(false)
    end
    entry:CreateDivider()
end

local function buildEntry(parent, specID, b, list, current)
    local entry = parent:CreateRadio(label(list, b),
        function() return TK.db.active[specID] == b.name end,
        function() B.apply(b) return MenuResponse.Close end)
    variantLines(entry, b)
    diffLines(entry, current, b)
    UI.buildActions(entry, specID, b)
end

-- Tags: the situations a build is for ----------------------------------------------------
-- This season's raids and their bosses, from the dungeon journal (read once it has them).
local raids
local function seasonRaids()
    if raids or not EJ_GetNumTiers then return raids or {} end
    local out, prev = {}, EJ_GetCurrentTier()
    EJ_SelectTier(EJ_GetNumTiers())
    for i = 1, 20 do
        local journalID, name = EJ_GetInstanceByIndex(i, true)
        if not journalID then break end
        local mapID = select(10, EJ_GetInstanceInfo(journalID))
        local raid = { name = name, key = mapID and ("zone:" .. mapID), bosses = {} }
        for j = 1, 20 do
            local boss, _, _, _, _, _, encounterID = EJ_GetEncounterInfoByIndex(j, journalID)
            if not boss then break end
            if encounterID then raid.bosses[#raid.bosses + 1] = { key = "boss:" .. encounterID, name = boss } end
        end
        out[#out + 1] = raid
    end
    if prev then EJ_SelectTier(prev) end
    if #out > 0 then raids = out end
    return out
end

local function seasonDungeons()
    local out = {}
    for _, id in ipairs(C_ChallengeMode and C_ChallengeMode.GetMapTable() or {}) do
        local name, _, _, _, _, mapID = C_ChallengeMode.GetMapUIInfo(id)
        if name and mapID then out[#out + 1] = { key = "zone:" .. mapID, name = name } end
    end
    table.sort(out, function(a, c) return a.name < c.name end)
    return out
end

UI.seasonRaids, UI.seasonDungeons = seasonRaids, seasonDungeons

local CONTENT = { { key = "raid", name = "Raid" }, { key = "mplus", name = "Mythic+" }, { key = "delve", name = "Delves" } }

local function tagBox(parent, b, s, label)
    parent:CreateCheckbox(label or s.name, function() return b.tags and b.tags[s.key] ~= nil end,
        function() B.toggleTag(b, s.key, s.name) end)
end

function UI.tagEntries(parent, b)
    local here = B.here()
    if here then tagBox(parent, b, here, here.name .. " |cff8c8c8c(here)|r") end
    for _, s in ipairs(CONTENT) do tagBox(parent, b, s) end
    local dungeons = seasonDungeons()
    if #dungeons > 0 then
        local sub = parent:CreateButton("Mythic+ dungeons")
        for _, s in ipairs(dungeons) do tagBox(sub, b, s) end
    end
    for _, raid in ipairs(seasonRaids()) do
        local sub = parent:CreateButton(raid.name)
        if raid.key then tagBox(sub, b, { key = raid.key, name = raid.name }, "Whole raid") end
        for _, s in ipairs(raid.bosses) do tagBox(sub, b, s) end
    end
end

-- "Tags: Raid +2"
function UI.tagSummary(b)
    local names = B.tagNames(b)
    if #names == 0 then return nil end
    return names[1] .. (#names > 1 and (" +" .. (#names - 1)) or "")
end

-- After saving a build you already have: a menu to tag that build instead.
function UI.offerTags(b)
    MenuUtil.CreateContextMenu(UIParent, function(_, root)
        root:CreateTitle("Tag " .. b.name .. " for")
        UI.tagEntries(root, b)
    end)
end

-- What you can do with a build: in its submenu here and in the talent window's side pane.
function UI.buildActions(entry, specID, b)
    local summary = UI.tagSummary(b)
    UI.tagEntries(entry:CreateButton("Tags" .. (summary and (": " .. summary) or "")), b)
    entry:CreateButton("Update to current talents", function() B.updateToCurrent(b) end)
    entry:CreateButton("Save current talents as a variant", function()
        local main = b.main or b.name
        UI.textWindow({ title = "Save variant of " .. main, singleLine = true, okText = "Save", text = main .. " variant",
            onOK = function(name) B.saveVariant(b, name) end })
    end)
    local of = entry:CreateButton("Variant of" .. (b.main and (": " .. b.main) or ""))
    of:CreateRadio("None (a main build)", function() return not b.main end, function() B.setMain(b, nil) end)
    for _, x in ipairs(B.list(specID)) do
        if x ~= b and not x.main then
            of:CreateRadio(x.name, function() return b.main == x.name end, function() B.setMain(b, x) end)
        end
    end
    UI.gearMenu(entry, b)
    local move = entry:CreateButton("Group" .. (b.group and (": " .. b.group) or ""))
    move:CreateRadio("No group", function() return not b.group end, function() B.setGroup(b, nil) end)
    local seen = {}
    for _, x in ipairs(B.list(specID)) do
        if x.group and not seen[x.group] then
            seen[x.group] = true
            local g = x.group
            move:CreateRadio(g, function() return b.group == g end, function() B.setGroup(b, g) end)
        end
    end
    move:CreateButton("New group...", function()
        UI.textWindow({ title = "New group for " .. b.name, singleLine = true, okText = "Move",
            onOK = function(name) if strtrim(name) ~= "" then B.setGroup(b, name) end end })
    end)
    entry:CreateButton("Rename", function()
        UI.textWindow({ title = "Rename build", text = b.name, singleLine = true, okText = "Rename",
            onOK = function(name) B.rename(specID, b, name) end })
    end)
    entry:CreateButton("Copy talent string", function()
        UI.textWindow({ title = "Talent string: " .. b.name, text = b.text, readOnly = true })
    end)
    local del = entry:CreateButton("Delete", function()
        if armed == b then
            armed = nil
            B.delete(specID, b)
            return MenuResponse.CloseAll
        end
        armed = b
        C_Timer.After(3, function() if armed == b then armed = nil end end)
        return MenuResponse.Refresh
    end)
    del:AddInitializer(function(frame)
        frame.fontString:SetText(armed == b and "|cffff8888Sure?|r" or "Delete")
    end)
end

local function generator(_, root)
    local specID = B.specID()
    if not specID then return root:CreateTitle("TalentKeeper") end
    root:CreateTitle("TalentKeeper: " .. B.specName(specID))
    local list = B.list(specID)
    local current = B.currentString()
    if #list == 0 then
        local none = root:CreateButton("|cff8c8c8cNo builds saved for this spec yet|r")
        none:SetEnabled(false)
    end
    -- main builds in list order, each followed by its variants
    local names = {}
    for _, b in ipairs(list) do names[b.name] = true end
    local function isVariant(b) return b.main and names[b.main] end
    local function family(parent, b)
        buildEntry(parent, specID, b, list, current)
        for _, v in ipairs(B.variantsOf(specID, b.name)) do buildEntry(parent, specID, v, list, current) end
    end
    local groups, order = {}, {}
    for _, b in ipairs(list) do
        if not isVariant(b) then
            if b.group then
                if not groups[b.group] then groups[b.group] = {}; order[#order + 1] = b.group end
                table.insert(groups[b.group], b)
            else
                family(root, b)
            end
        end
    end
    for _, name in ipairs(order) do
        local g = root:CreateButton(name)
        for _, b in ipairs(groups[name]) do family(g, b) end
    end
    root:CreateDivider()
    root:CreateButton("Save current talents", function()
        UI.textWindow({ title = "Save current talents", singleLine = true, okText = "Save",
            text = ("%s %d"):format(B.specName(specID), #list + 1),
            onOK = function(name) B.saveCurrent(name) end })
    end)
    root:CreateButton("Import a talent string", TK.commands.import)
end

function UI.openMenu(owner)
    if not B.specID() then return TK.chat("Pick a specialization first.") end
    armed = nil
    MenuUtil.CreateContextMenu(owner or UIParent, generator)
end

-- Key binding (Bindings.xml)
BINDING_HEADER_TALENTKEEPER = "TalentKeeper"
BINDING_NAME_TALENTKEEPER_MENU = "Open your builds"
function TalentKeeper_OpenMenu() TK.safe(UI.openMenu)() end

-- Button beside Blizzard's loadout dropdown --------------------------------------------
EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", TK.safe(function()
    local tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not tf or not tf.LoadSystem then return TK.log("talent window: no loadout dropdown found") end
    local bt = CreateFrame("Button", nil, tf)
    bt:SetSize(24, 24)
    bt:SetPoint("RIGHT", tf.LoadSystem, "LEFT", -4, 0)
    local icon = bt:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\AddOns\\" .. addonName .. "\\icon.png")
    local hover = fill(bt, "HIGHLIGHT", 0.851, 0.851, 0.851, 0.15)
    hover:SetBlendMode("ADD")
    bt:SetScript("OnClick", TK.safe(function(self) UI.openMenu(self) end))
    bt:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("TalentKeeper")
        GameTooltip:AddLine("Your saved builds for this spec.", 0.74, 0.74, 0.74, true)
        GameTooltip:Show()
    end)
    bt:SetScript("OnLeave", GameTooltip_Hide)
end))
