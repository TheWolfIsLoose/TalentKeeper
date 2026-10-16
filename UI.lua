-- TalentKeeper UI: fonts, the button by Blizzard's loadout dropdown, the build menu,
-- and one small text window (name a build, paste / copy a string, read the log).
local addonName, TK = ...
local B = TK.builds
local UI = {}
TK.ui = UI

-- Fonts and colors (suite style guide) ---------------------------------------------
local FONT = "Interface\\AddOns\\" .. addonName .. "\\Media\\BarlowSemiCondensed-Medium.ttf"
for name, size in pairs({ TalentKeeperFontSmall = 10, TalentKeeperFont = 12, TalentKeeperFontLarge = 16 }) do
    CreateFont(name):SetFont(FONT, size, "")
end

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
    bt:SetText(label)
    bt:SetScript("OnEnter", function() setRing(0.7) end)
    bt:SetScript("OnLeave", function() setRing(0.4) end)
    bt:SetScript("OnClick", TK.safe(onClick))
    return bt
end

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
    win.edit:SetWidth(400)
    win.scroll:SetScrollChild(win.edit)
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

local function buildEntry(parent, specID, b)
    local entry = parent:CreateRadio(b.name,
        function() return TK.db.active[specID] == b.name end,
        function() B.apply(b) return MenuResponse.Close end)
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
    if #list == 0 then
        local none = root:CreateButton("|cff8c8c8cNo builds saved for this spec yet|r")
        none:SetEnabled(false)
    end
    local groups, order = {}, {}
    for _, b in ipairs(list) do
        if b.group then
            if not groups[b.group] then groups[b.group] = {}; order[#order + 1] = b.group end
            table.insert(groups[b.group], b)
        else
            buildEntry(root, specID, b)
        end
    end
    for _, name in ipairs(order) do
        local g = root:CreateButton(name)
        for _, b in ipairs(groups[name]) do buildEntry(g, specID, b) end
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
