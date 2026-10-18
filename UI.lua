-- TalentKeeper UI: fonts, buttons, the save / import dialog, the tag and group menus, the
-- quick build menu (key binding, /tk), and one small text window (copy a string, read the log).
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

-- Save / import dialog -----------------------------------------------------------------
-- One step: the talent string (import only), the build's name and its group.
local dlg
local function editBox(parent, multi)
    local box = CreateFrame("Frame", nil, parent)
    box:SetHeight(24)
    fill(box, "BACKGROUND", 1, 1, 1, 0.08)
    local setRing = ring(box, 0.4)
    local e = CreateFrame("EditBox", nil, box)
    e:SetFontObject(ChatFontNormal)
    e:SetAutoFocus(false)
    e:SetMultiLine(multi or false)
    e:SetPoint("TOPLEFT", 6, -4); e:SetPoint("BOTTOMRIGHT", -6, 4)
    e:SetScript("OnEditFocusGained", function() setRing(0.596) end)
    e:SetScript("OnEditFocusLost", function() setRing(0.4) end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() dlg:Hide() end)
    e:SetScript("OnTabPressed", function(self) if self.next then self.next:SetFocus() end end)
    box:SetScript("OnMouseDown", function() e:SetFocus() end)
    box.edit = e
    return box
end

local function caption(parent, text, anchor)
    local fs = parent:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    fs:SetTextColor(0.55, 0.55, 0.55)
    fs:SetText(text)
    fs:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 3)
    return fs
end

local function makeDialog()
    dlg = CreateFrame("Frame", "TalentKeeperBuildDialog", UIParent)
    dlg:SetWidth(380)
    dlg:SetPoint("CENTER")
    dlg:SetFrameStrata("DIALOG")
    dlg:SetMovable(true); dlg:EnableMouse(true); dlg:RegisterForDrag("LeftButton")
    dlg:SetScript("OnDragStart", dlg.StartMoving)
    dlg:SetScript("OnDragStop", dlg.StopMovingOrSizing)
    dlg:SetClampedToScreen(true)
    fill(dlg, "BACKGROUND", 0.031, 0.031, 0.031, 0.97)
    ring(dlg, 0)
    tinsert(UISpecialFrames, dlg:GetName())
    dlg.title = dlg:CreateFontString(nil, "OVERLAY", "TalentKeeperFontLarge")
    dlg.title:SetPoint("TOPLEFT", 12, -10)
    dlg.text = editBox(dlg, true)
    dlg.text:SetHeight(64)
    dlg.text:SetPoint("TOPLEFT", 12, -54); dlg.text:SetPoint("TOPRIGHT", -12, -54)
    dlg.textCap = caption(dlg, "Talent string", dlg.text)
    dlg.name = editBox(dlg)
    dlg.nameCap = caption(dlg, "Name", dlg.name)
    dlg.group = editBox(dlg)
    dlg.group:SetPoint("TOPLEFT", dlg.name, "BOTTOMLEFT", 0, -22)
    dlg.group:SetPoint("TOPRIGHT", dlg.name, "BOTTOMRIGHT", -30, -22)
    caption(dlg, "Group (blank for none)", dlg.group)
    dlg.pick = button(dlg, "...", 24, function(self)
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateButton("No group", function() dlg.group.edit:SetText("") end)
            for _, g in ipairs(B.groups(B.specID())) do
                root:CreateButton(g, function() dlg.group.edit:SetText(g) end)
            end
        end)
    end)
    dlg.pick:SetPoint("LEFT", dlg.group, "RIGHT", 6, 0)
    dlg.text.edit.next, dlg.name.edit.next, dlg.group.edit.next = dlg.name.edit, dlg.group.edit, nil
    dlg.cancel = button(dlg, "Cancel", 80, function() dlg:Hide() end)
    dlg.cancel:SetPoint("BOTTOMRIGHT", -12, 12)
    dlg.ok = button(dlg, "Save", 80, function()
        local text, name, group = dlg.text.edit:GetText(), strtrim(dlg.name.edit:GetText()), strtrim(dlg.group.edit:GetText())
        group = group ~= "" and group or nil
        dlg:Hide()
        TK.lastGroup = group
        if dlg.import then B.importString(text, name, group) else B.saveCurrent(name, group) end
    end)
    dlg.ok:SetPoint("RIGHT", dlg.cancel, "LEFT", -8, 0)
    for _, box in ipairs({ dlg.name, dlg.group }) do
        box.edit:SetScript("OnEnterPressed", function() dlg.ok:Click() end)
    end
    dlg:SetScript("OnHide", function() dlg.text.edit:ClearFocus() dlg.name.edit:ClearFocus() dlg.group.edit:ClearFocus() end)
end

-- import = true: paste a string; otherwise save your current talents.
function UI.buildDialog(import)
    local specID = B.specID()
    if not specID then return TK.chat("Pick a specialization first.") end
    if not dlg then makeDialog() end
    dlg.import = import
    dlg.title:SetText(import and "Import a build" or "Save your current talents")
    dlg.text:SetShown(import)
    dlg.textCap:SetShown(import)
    dlg.name:ClearAllPoints()
    local top = import and -148 or -54
    dlg.name:SetPoint("TOPLEFT", 12, top); dlg.name:SetPoint("TOPRIGHT", -12, top)
    dlg:SetHeight(-top + 24 + 22 + 24 + 56)
    dlg.text.edit:SetText("")
    dlg.name.edit:SetText(import and "" or ("%s %d"):format(B.specName(specID), #B.list(specID) + 1))
    local sel = TK.selected
    dlg.group.edit:SetText((sel and sel.group) or TK.lastGroup or "")
    dlg.ok:SetText(import and "Import" or "Save")
    dlg:Show()
    local first = import and dlg.text.edit or dlg.name.edit
    first:SetFocus()
    first:HighlightText()
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
        EJ_SelectInstance(journalID) -- the journal lists a raid's bosses only once it's selected
        for j = 1, 20 do
            local boss, _, _, _, _, _, encounterID = EJ_GetEncounterInfoByIndex(j, journalID)
            if not boss then break end
            if encounterID then raid.bosses[#raid.bosses + 1] = { key = "boss:" .. encounterID, name = boss } end
        end
        out[#out + 1] = raid
    end
    if prev then EJ_SelectTier(prev) end
    local bosses, names = 0, {}
    for _, r in ipairs(out) do bosses = bosses + #r.bosses names[#names + 1] = ("%s (%d)"):format(r.name, #r.bosses) end
    TK.log("journal: raids %s", #names > 0 and table.concat(names, ", ") or "none")
    if #out > 0 and bosses > 0 then raids = out end -- keep asking until the journal has the bosses
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

-- One flat list: here, content, this season's dungeons, then each raid and its bosses.
function UI.tagEntries(root, b)
    local here = B.here()
    if here then tagBox(root, b, here, here.name .. " |cff8c8c8c(here)|r") end
    for _, s in ipairs(CONTENT) do tagBox(root, b, s) end
    local dungeons = seasonDungeons()
    if #dungeons > 0 then
        root:CreateTitle("Mythic+ dungeons")
        for _, s in ipairs(dungeons) do tagBox(root, b, s) end
    end
    for _, raid in ipairs(seasonRaids()) do
        root:CreateTitle(raid.name)
        if raid.key then tagBox(root, b, { key = raid.key, name = raid.name }, "Whole raid") end
        for _, s in ipairs(raid.bosses) do tagBox(root, b, s) end
    end
end

function UI.tagMenu(owner, b)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(b.name .. " is for")
        UI.tagEntries(root, b)
    end)
end

-- "Raid +2"
function UI.tagSummary(b)
    local names = B.tagNames(b)
    if #names == 0 then return nil end
    return names[1] .. (#names > 1 and (" +" .. (#names - 1)) or "")
end

function UI.groupMenu(owner, specID, b)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("Move " .. b.name .. " to")
        root:CreateRadio("No group", function() return not b.group end, function() B.setGroup(b, nil) end)
        for _, g in ipairs(B.groups(specID)) do
            root:CreateRadio(g, function() return b.group == g end, function() B.setGroup(b, g) end)
        end
        root:CreateButton("New group...", function()
            UI.textWindow({ title = "New group for " .. b.name, singleLine = true, okText = "Move",
                onOK = function(name) if strtrim(name) ~= "" then B.setGroup(b, name) end end })
        end)
    end)
end

-- Quick menu (key binding, /tk): this spec's builds; click one to apply it -------------------
local function generator(_, root)
    local specID = B.specID()
    if not specID then return root:CreateTitle("TalentKeeper") end
    root:CreateTitle("TalentKeeper: " .. B.specName(specID))
    local any = false
    for _, line in ipairs(B.ordered(specID)) do
        if line.header then
            root:CreateTitle(line.header)
        elseif line.build then
            any = true
            local b = line.build
            local tags = UI.tagSummary(b)
            root:CreateRadio(b.name .. (tags and ("  |cff8c8c8c" .. tags .. "|r") or ""),
                function() return TK.db.active[specID] == b.name end,
                function() B.apply(b) return MenuResponse.Close end)
        end
    end
    if not any then root:CreateButton("|cff8c8c8cNo builds saved for this spec yet|r"):SetEnabled(false) end
end

function UI.openMenu(owner)
    if not B.specID() then return TK.chat("Pick a specialization first.") end
    MenuUtil.CreateContextMenu(owner or UIParent, generator)
end

-- Key binding (Bindings.xml)
BINDING_HEADER_TALENTKEEPER = "TalentKeeper"
BINDING_NAME_TALENTKEEPER_MENU = "Open your builds"
function TalentKeeper_OpenMenu() TK.safe(UI.openMenu)() end
