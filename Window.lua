-- TalentKeeper on the talent window: your builds in a side pane beside it. Click one to preview
-- it on the tree; the panel under the list applies, tags, groups, renames, copies or deletes it.
local _, TK = ...
local B, C, UI = TK.builds, TK.compare, TK.ui
local W = {}
TK.window = W

local tf, marks = nil, {}

-- Marks on the tree ----------------------------------------------------------------------
-- Drawn in the talent window's own language, from each button's own art set: a talent the
-- build adds glows green like one you can take; one it drops glows red, with the red border
-- and a dim veil, like a talent you'd lose; another choice shows the build's pick on the node. Plus
-- and minus signs only in colorblind mode.
local function mark(i)
    if marks[i] then return marks[i] end
    local m = CreateFrame("Frame", nil, tf)
    m.mask = m:CreateMaskTexture()
    m.mask:SetPoint("CENTER")
    m.veil = m:CreateTexture(nil, "ARTWORK", nil, 1)
    m.veil:SetPoint("CENTER")
    m.veil:SetColorTexture(0, 0, 0, 0.55)
    m.veil:AddMaskTexture(m.mask)
    m.icon = m:CreateTexture(nil, "ARTWORK", nil, 2)
    m.icon:SetPoint("CENTER")
    m.icon:AddMaskTexture(m.mask)
    m.border = m:CreateTexture(nil, "OVERLAY", nil, 1)
    m.border:SetPoint("CENTER")
    m.glow = m:CreateTexture(nil, "OVERLAY", nil, 2)
    m.glow:SetPoint("CENTER")
    m.glow:SetBlendMode("ADD")
    m.text = m:CreateFontString(nil, "OVERLAY", "SystemFont16_Shadow_ThickOutline")
    m.text:SetPoint("BOTTOMRIGHT", 4, -4)
    m.label = m:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    m.label:SetPoint("TOP", m, "BOTTOM", 0, -6)
    marks[i] = m
    return m
end

function W.hide()
    for _, m in ipairs(marks) do m:Hide() end
end

-- How a node changes from your talents to the build's.
local function kind(c) return not c.from and "add" or not c.to and "rem" or "swap" end

local LTT = LibStub and LibStub("LibTalentTree-1.0", true)
local function lib(node) return LTT and LTT:GetLibNodeInfo(node) end

-- The icon of the build's pick on a choice node ("rank:choice").
local function choiceIcon(node, pick)
    local choice = tonumber((pick or ""):match(":(%d+)$")) or 0
    local cfg = C_ClassTalents.GetActiveConfigID()
    local info = choice > 0 and cfg and C_Traits.GetNodeInfo(cfg, node)
    local entry = info and info.entryIDs and C_Traits.GetEntryInfo(cfg, info.entryIDs[choice])
    local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
    if not def then return end
    return def.overrideIcon or (def.spellID and C_Spell.GetSpellTexture(def.spellID))
end

local function sizeOf(region, w, h)
    if region and region.GetSize then local rw, rh = region:GetSize() if rw and rw > 0 then return rw, rh end end
    return w, h
end

local function place(m, button, c)
    local k = c and kind(c) or "swap"
    local art = button.artSet or { glow = "talents-node-circle-greenglow" }
    local w, h = button:GetSize()
    m:SetFrameStrata(button:GetFrameStrata())
    m:SetFrameLevel(button:GetFrameLevel() + 10)
    m:ClearAllPoints()
    m:SetPoint("CENTER", button)
    m:SetSize(w, h)
    local iw, ih = sizeOf(button.Icon, w, h)
    m.mask:SetSize(iw, ih)
    if art.iconMask then m.mask:SetAtlas(art.iconMask, TextureKitConstants.IgnoreAtlasSize) else m.mask:SetTexture("Interface\\Buttons\\WHITE8X8") end
    m.veil:SetSize(iw, ih)
    m.icon:SetSize(iw, ih)
    m.border:SetSize(sizeOf(button.StateBorder, w, h))
    m.glow:SetSize(sizeOf(button.Glow, w * 1.6, h * 1.6))
    m.glow:SetAtlas(art.glow)
    m.veil:SetShown(k == "rem")
    m.border:SetShown(k == "rem" and art.displayError ~= nil)
    if art.displayError then m.border:SetAtlas(art.displayError) end
    -- the game has no red glow: its green one, desaturated and tinted (additive, so it stays a glow)
    m.glow:SetDesaturated(k == "rem")
    if k == "rem" then m.glow:SetVertexColor(1, 0.25, 0.25) else m.glow:SetVertexColor(1, 1, 1) end
    local icon = k == "swap" and c and choiceIcon(c.node, c.to)
    m.icon:SetShown(icon and true or false) -- icon is false, not nil, off a choice node
    if icon then m.icon:SetTexture(icon) end
    -- a rank change shows the build's rank; colorblind mode adds a sign
    local rank = k == "swap" and c and not icon and tonumber((c.to or ""):match("^(%d+)"))
    local sign = GetCVarBool("colorblindMode") and ((k == "add" and "+") or (k == "rem" and "-")) or nil
    m.text:SetText(rank and rank > 0 and tostring(rank) or sign or "")
    m.label:SetText("")
    m:Show()
end

-- Mark what applying b would change; returns the changes and how many have no button on show.
-- Another hero tree is one mark on the hero tree's emblem, not a mark on every hero talent.
function W.show(b)
    W.hide()
    if not tf or not tf:IsVisible() then return end
    local d = C.diff(B.currentString(), b.text)
    if not d then return end
    local heroSwap = false
    for _, c in ipairs(d) do local n = lib(c.node) if n and n.isSubTreeSelection then heroSwap = true end end
    local hidden, n = 0, 0
    for _, c in ipairs(d) do
        local info = lib(c.node)
        if not (heroSwap and info and (info.subTreeID or info.isSubTreeSelection)) then
            local button = tf:GetTalentButtonByNodeID(c.node)
            if button and button:IsVisible() then
                n = n + 1
                place(mark(n), button, c)
            else
                hidden = hidden + 1
            end
        end
    end
    local emblem = tf.HeroTalentsContainer and tf.HeroTalentsContainer.HeroSpecButton
    if heroSwap and emblem and emblem:IsVisible() then
        n = n + 1
        local m = mark(n)
        place(m, emblem, nil)
        m.label:SetText(C.heroName(b.text) or "")
    end
    return d, hidden
end

-- The side pane of builds -----------------------------------------------------------------
-- Docked to the window's right edge, at our own scale (parented to UIParent, shown with the
-- talent window). Groups as headings; the list scrolls; the selected build's panel sits below.
local pane, rows, heads = nil, {}, {}
-- spec buttons: one row across the pane, sized so four fit (the most any class has)
local PANE_W, SPEC_GAP = 220, 6
local SPEC = math.floor((PANE_W - 16 - 3 * SPEC_GAP) / 4)
local ROW, HEAD, TOP = 24, 22, -(32 + SPEC + 8)
local SHIMMER_W = 90
local offset = 0
local detail -- the selected build's panel

local function selectBuild(b)
    TK.selected = (TK.selected ~= b) and b or nil
    W.refresh()
end

local function row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, pane.list)
    r:SetHeight(ROW)
    r.stripe = UI.fill(r, "BACKGROUND", 1, 1, 1, 0.05)
    r.sel = UI.fill(r, "BACKGROUND", 0.596, 1, 0.596, 0.12)
    UI.fill(r, "HIGHLIGHT", 0.851, 0.851, 0.851, 0.15)
    r.status = r:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    r.status:SetPoint("RIGHT", -8, 0)
    r.bar = r:CreateTexture(nil, "OVERLAY")
    r.bar:SetColorTexture(0.596, 1, 0.596, 1)
    r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(2)
    r.text = r:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    r.text:SetPoint("LEFT", 8, 0)
    r.text:SetPoint("RIGHT", r.status, "LEFT", -6, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    -- Shimmer: one soft mint band sweeps across the row (once, two seconds), clipped to it.
    local clip = CreateFrame("Frame", nil, r)
    clip:SetAllPoints()
    clip:SetClipsChildren(true)
    local band = CreateFrame("Frame", nil, clip)
    band:SetSize(SHIMMER_W, ROW)
    band:SetPoint("RIGHT", clip, "LEFT")
    for half = 1, 2 do
        local t = band:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(1, 1, 1, 1)
        t:SetSize(SHIMMER_W / 2, ROW)
        t:SetPoint(half == 1 and "LEFT" or "RIGHT")
        local none, peak = CreateColor(0.596, 1, 0.596, 0), CreateColor(0.596, 1, 0.596, 0.22)
        t:SetGradient("HORIZONTAL", half == 1 and none or peak, half == 1 and peak or none)
    end
    band:Hide()
    local sweep = band:CreateAnimationGroup()
    sweep.move = sweep:CreateAnimation("Translation")
    sweep.move:SetDuration(2)
    sweep.move:SetSmoothing("IN_OUT")
    sweep:SetScript("OnPlay", function() band:Show() end)
    sweep:SetScript("OnFinished", function() band:Hide() end)
    sweep:SetScript("OnStop", function() band:Hide() end)
    r.Shimmer = function()
        sweep:Stop()
        sweep.move:SetOffset(r:GetWidth() + SHIMMER_W, 0)
        sweep:Play()
    end
    r.StopShimmer = function() sweep:Stop() end
    r:RegisterForDrag("LeftButton")
    r:SetScript("OnClick", TK.safe(function(self)
        if self.dragged then self.dragged = nil return end
        selectBuild(self.b)
    end))
    r:SetScript("OnDoubleClick", TK.safe(function(self)
        TK.selected = self.b
        B.apply(self.b)
    end))
    r:SetScript("OnDragStart", function(self)
        self.dragged, W.dragging = true, self.b
        GameTooltip:Hide()
        SetCursor("Interface\\Cursor\\UI-Cursor-Move")
    end)
    r:SetScript("OnDragStop", TK.safe(function() W.drop() end))
    r:SetScript("OnEnter", TK.safe(function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.b.name)
        local hero = C.heroName(self.b.text)
        if hero then GameTooltip:AddLine(hero, 0.74, 0.74, 0.74) end
        local tags = B.tagNames(self.b)
        if #tags > 0 then GameTooltip:AddLine("For: " .. table.concat(tags, ", "), 0.596, 1, 0.596, true) end
        GameTooltip:AddLine("Click to preview on the tree, double-click to apply. Drag onto a group to move it.", 0.55, 0.55, 0.55, true)
        GameTooltip:Show()
    end))
    r:SetScript("OnLeave", GameTooltip_Hide)
    rows[i] = r
    return r
end

-- Group headings: click for the group's own menu (rename, delete).
local armedGroup
local function head(i)
    if heads[i] then return heads[i] end
    local h = CreateFrame("Button", nil, pane.list)
    h:SetHeight(HEAD)
    h.text = h:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    h.text:SetPoint("LEFT", 8, -3)
    h.text:SetTextColor(0.55, 0.55, 0.55)
    h:SetScript("OnEnter", function(self) if self.group then self.text:SetTextColor(1, 1, 1) end end)
    h:SetScript("OnLeave", function(self) self.text:SetTextColor(0.55, 0.55, 0.55) end)
    h:SetScript("OnClick", TK.safe(function(self)
        local g, specID = self.group, B.specID()
        if not g then return end
        armedGroup = nil
        UI.picker(self, g, function()
            local n = 0
            for _, b in ipairs(B.list(specID)) do if b.group == g then n = n + 1 end end
            return {
                { label = "Rename group", onClick = function()
                    UI.textWindow({ title = "Rename group", text = g, singleLine = true, okText = "Rename",
                        onOK = function(name) B.renameGroup(specID, g, name) end })
                end },
                { label = "Ungroup its builds", onClick = function()
                    for _, b in ipairs(B.list(specID)) do if b.group == g then b.group = nil end end
                    TK.changed()
                end },
                { label = function()
                    return armedGroup == g and ("|cffff8888Sure? Deletes %d build%s|r"):format(n, n == 1 and "" or "s") or "Delete it and its builds"
                end, onClick = function()
                    if armedGroup == g then armedGroup = nil B.deleteGroup(specID, g) return end
                    armedGroup = g
                    C_Timer.After(3, function() if armedGroup == g then armedGroup = nil UI.refreshPicker() end end)
                    return "keep"
                end },
            }
        end)
    end))
    heads[i] = h
    return h
end

-- Drop a dragged build onto a group heading, a build (its group) or "+ New group".
function W.drop()
    local b = W.dragging
    W.dragging = nil
    ResetCursor()
    if not b then return end
    local target -- nil: no drop target; false: no group
    for _, h in ipairs(heads) do if h:IsShown() and h:IsMouseOver() then target = h.group or false end end
    for _, r in ipairs(rows) do if r:IsShown() and r:IsMouseOver() then target = r.b.group or false end end
    if pane.newGroup:IsShown() and pane.newGroup:IsMouseOver() then
        return UI.textWindow({ title = "New group for " .. b.name, singleLine = true, okText = "Move",
            onOK = function(name) if strtrim(name) ~= "" then B.setGroup(b, name) end end })
    end
    if target ~= nil and (target or nil) ~= b.group then B.setGroup(b, target or nil) end
end

-- The selected build's panel -----------------------------------------------------------------
local armedBuild
local function refreshDetail(specID)
    local b = TK.selected
    if b and B.findSpec(b) ~= specID then b, TK.selected = nil, nil end
    for _, bt in ipairs(detail.buttons) do bt:SetShown(b ~= nil) end
    if not b then
        detail.name:SetText("")
        detail.info:SetText("Click a build to preview it on the tree.")
        W.hide()
        return
    end
    detail.name:SetText(b.name)
    local d, hidden = W.show(b)
    local parts = {}
    local hero = C.heroName(b.text)
    if hero then parts[#parts + 1] = hero end
    if not d then parts[#parts + 1] = "|cffff8888can't read it|r"
    elseif #d == 0 then parts[#parts + 1] = "|cff98ff98your talents now|r"
    else parts[#parts + 1] = ("%d change%s marked"):format(#d, #d == 1 and "" or "s") end
    if b.outdated then parts[#parts + 1] = "|cffffb84doutdated|r" end
    local tags = UI.tagSummary(b)
    detail.info:SetText(table.concat(parts, " · ") .. "\n" .. (tags and ("For: " .. tags) or "|cff8c8c8cNot tagged for anything|r"))
    detail.apply:SetEnabled(d ~= nil and #d > 0)
    detail.delete:SetText(armedBuild == b and "|cffff8888Sure?|r" or "Delete")
end

local function makeDetail()
    detail = CreateFrame("Frame", nil, pane)
    detail:SetPoint("BOTTOMLEFT", 0, 36); detail:SetPoint("BOTTOMRIGHT", 0, 36)
    detail:SetHeight(128)
    local rule = detail:CreateTexture(nil, "OVERLAY")
    rule:SetColorTexture(0, 0, 0, 1)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT"); rule:SetPoint("TOPRIGHT")
    detail.name = detail:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    detail.name:SetPoint("TOPLEFT", 8, -8); detail.name:SetPoint("TOPRIGHT", -8, -8)
    detail.name:SetJustifyH("LEFT")
    detail.name:SetWordWrap(false)
    detail.info = detail:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    detail.info:SetPoint("TOPLEFT", 8, -24); detail.info:SetPoint("TOPRIGHT", -8, -24)
    detail.info:SetJustifyH("LEFT")
    detail.info:SetTextColor(0.74, 0.74, 0.74)
    detail.info:SetSpacing(2)
    local W3 = 64
    local function on(fn) return function(self) local b = TK.selected if b then fn(b, self) end end end
    detail.apply = UI.button(detail, "Apply", 204, on(function(b) B.apply(b) end))
    detail.apply:SetPoint("TOPLEFT", 8, -54)
    local tags = UI.button(detail, "Tags", W3, on(function(b, self) UI.tagMenu(self, b) end))
    tags:SetPoint("TOPLEFT", 8, -82)
    local group = UI.button(detail, "Group", W3, on(function(b, self) UI.groupMenu(self, B.specID(), b) end))
    group:SetPoint("LEFT", tags, "RIGHT", 6, 0)
    local rename = UI.button(detail, "Rename", W3, on(function(b)
        UI.textWindow({ title = "Rename build", text = b.name, singleLine = true, okText = "Rename",
            onOK = function(name) B.rename(B.specID(), b, name) end })
    end))
    rename:SetPoint("LEFT", group, "RIGHT", 6, 0)
    local copy = UI.button(detail, "Copy", W3, on(function(b)
        UI.textWindow({ title = "Talent string: " .. b.name, text = b.text, readOnly = true })
    end))
    copy:SetPoint("TOPLEFT", 8, -108)
    local update = UI.button(detail, "Resave", W3, on(function(b) B.updateToCurrent(b) end))
    update:SetPoint("LEFT", copy, "RIGHT", 6, 0)
    update:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Resave")
        GameTooltip:AddLine("Replace this build's talents with the ones you have now.", 0.74, 0.74, 0.74, true)
        GameTooltip:Show()
    end)
    update:SetScript("OnLeave", GameTooltip_Hide)
    detail.delete = UI.button(detail, "Delete", W3, on(function(b)
        if armedBuild == b then
            armedBuild = nil
            B.delete(B.specID(), b)
            return
        end
        armedBuild = b
        C_Timer.After(3, function() if armedBuild == b then armedBuild = nil TK.safe(W.refresh)() end end)
        W.refresh()
    end))
    detail.delete:SetPoint("LEFT", update, "RIGHT", 6, 0)
    detail.buttons = { detail.apply, tags, group, rename, copy, update, detail.delete }
end

function W.refresh()
    if not pane or not pane:IsShown() then return end
    for _, r in ipairs(rows) do r:Hide() end
    for _, h in ipairs(heads) do h:Hide() end
    local specID = B.specID()
    local active = specID and TK.db.active[specID]
    local v = TK.version or ""
    pane.version:SetText(((v:find("^dev") or v:find("%-alpha") or v:find("%-beta")) and "|cffffb84d" or "|cff8c8c8c") .. v .. "|r")
    W.refreshSpecs()
    -- lay out every line, then show the ones inside the list's window
    local lines, y = {}, 0
    for _, line in ipairs(B.ordered(specID)) do
        if line.header ~= nil then
            if line.header or #lines > 0 then -- "No group" only when something came before it
                lines[#lines + 1] = { header = line.header, y = y }
                y = y + HEAD
            end
        else
            lines[#lines + 1] = { build = line.build, y = y }
            y = y + ROW
        end
    end
    local height = pane.list:GetHeight()
    for _, line in ipairs(lines) do -- scroll a build that just changed into view
        if line.build and TK.flashing[line.build] then
            offset = math.min(math.max(offset, line.y + ROW - height), line.y)
            break
        end
    end
    offset = math.max(0, math.min(offset, y + 28 - height))
    local nr, nh, n = 0, 0, 0
    local function visible(ly, h) return ly - offset >= 0 and ly - offset + h <= height end
    for _, line in ipairs(lines) do
        if line.build then n = n + 1 end
        if line.header ~= nil and visible(line.y, HEAD) then
            nh = nh + 1
            local h = head(nh)
            h.text:SetText(line.header or "No group")
            h.group = line.header or nil
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 0, -(line.y - offset)); h:SetPoint("TOPRIGHT", 0, -(line.y - offset))
            h:Show()
        elseif line.build and visible(line.y, ROW) then
            nr = nr + 1
            local b, r = line.build, row(nr)
            if r.b ~= b then r.StopShimmer() end -- the frame now shows another build
            r.b = b
            if TK.flashing[b] then r.Shimmer() end
            r.text:SetText(b.name)
            r.status:SetText(b.outdated and "Outdated" or UI.tagSummary(b) or "")
            if b.outdated then r.status:SetTextColor(1, 0.722, 0.302) else r.status:SetTextColor(0.55, 0.55, 0.55) end
            r.stripe:SetShown(n % 2 == 0)
            r.sel:SetShown(b == TK.selected)
            local isOn = b.name == active
            r.text:SetTextColor(isOn and 0.596 or 1, 1, isOn and 0.596 or 1)
            r.bar:SetShown(isOn)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -(line.y - offset)); r:SetPoint("TOPRIGHT", 0, -(line.y - offset))
            r:Show()
        end
    end
    wipe(TK.flashing) -- drawn or not, a change shimmers only right after it happens
    pane.newGroup:ClearAllPoints()
    pane.newGroup:SetPoint("TOPLEFT", 8, -(y - offset + 6))
    pane.newGroup:SetShown(n > 0 and visible(y + 6, 20))
    if n == 0 then
        local h = head(1)
        h.text:SetText("No builds for this spec yet.")
        h.group = nil
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 0, 0); h:SetPoint("TOPRIGHT", 0, 0)
        h:Show()
    end
    refreshDetail(specID)
    if W.override then W.show(W.override) end -- a string being imported shows on the tree instead
end

-- Preview a talent string on the tree while it's being imported (nil: back to the selected build).
function W.preview(text)
    W.override = text and { text = text } or nil
    W.refresh()
end

local prev = TK.onChange
TK.onChange = function()
    if prev then prev() end
    TK.safe(W.refresh)()
end
TK.on("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", function() TK.selected = nil offset = 0 TK.safe(W.refresh)() end)
-- your talents changed (an apply landed, a click in the tree): redraw the preview
TK.on("TRAIT_CONFIG_UPDATED", function() TK.safe(W.refresh)() end)

-- Spec buttons under the header: click one to change spec without leaving the talents.
local specs = {}
function W.refreshSpecs()
    local cur = GetSpecialization and GetSpecialization()
    for i, b in ipairs(specs) do
        local on = i == cur
        b.icon:SetDesaturated(not on)
        b.icon:SetAlpha(on and 1 or 0.7)
        b.ring(on and 0.596 or 0)
    end
end

local function specButtons()
    local n = GetNumSpecializations() or 0
    local step = n > 1 and (PANE_W - 16 - SPEC) / (n - 1) or 0 -- spread across the width
    for i = 1, n do
        local specID, name, _, icon = GetSpecializationInfo(i)
        local b = CreateFrame("Button", nil, pane)
        b:SetSize(SPEC, SPEC)
        b:SetPoint("TOPLEFT", math.floor(8 + (i - 1) * step), -32)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 1, -1); b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        b.icon:SetTexture(icon)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.ring = UI.ring(b, 0)
        UI.fill(b, "HIGHLIGHT", 1, 1, 1, 0.15)
        b:SetScript("OnClick", TK.safe(function()
            if i == GetSpecialization() then return end
            if InCombatLockdown() then return TK.chat("|cffff8888Can't change spec in combat.|r") end
            TK.log("spec change to %s", name)
            C_SpecializationInfo.SetSpecialization(i)
        end))
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(name)
            local n = #(TK.db.builds[specID] or {})
            GameTooltip:AddLine(i == GetSpecialization() and "Your spec now." or ("Click to change to %s (%d build%s)."):format(name, n, n == 1 and "" or "s"), 0.74, 0.74, 0.74, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        specs[i] = b
    end
    W.refreshSpecs()
end

-- Window size: drag the corner grip to scale the talent window (kept between sessions).
local function applyScale()
    if PlayerSpellsFrame and not InCombatLockdown() then PlayerSpellsFrame:SetScale(TK.db.windowScale or 1) end
end

-- Where you moved the window: kept in screen pixels (so a size change doesn't throw it off) and put
-- back whenever the game places it (opening, or another panel opening beside it). Out of combat.
local function applyPos()
    local p, f = TK.db.windowPos, PlayerSpellsFrame
    if not p or not f or not f:IsShown() or InCombatLockdown() then return end
    local s = f:GetEffectiveScale()
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x / s, p.y / s)
end

local function savePos()
    local f = PlayerSpellsFrame
    local s = f:GetEffectiveScale()
    TK.db.windowPos = { x = f:GetLeft() * s, y = f:GetTop() * s }
end

local function mover()
    local f = PlayerSpellsFrame
    f:SetClampedToScreen(true)
    local d = CreateFrame("Frame", nil, f) -- over the title bar, short of the close button
    d:SetPoint("TOPLEFT", 0, 0); d:SetPoint("TOPRIGHT", -28, 0)
    d:SetHeight(22)
    d:EnableMouse(true)
    d:RegisterForDrag("LeftButton")
    d:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        f:SetMovable(true)
        f:StartMoving()
    end)
    d:SetScript("OnDragStop", TK.safe(function()
        f:StopMovingOrSizing()
        f:SetUserPlaced(false) -- the game's layout cache stays out of it; TalentKeeper puts it back
        savePos()
        TK.log("talent window moved")
    end))
    d:SetScript("OnMouseUp", function(_, button)
        if button ~= "RightButton" or not TK.db.windowPos then return end
        TK.db.windowPos = nil
        TK.chat("The talent window opens in the game's spot again from next time.")
    end)
    d:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Talent window")
        GameTooltip:AddLine("Drag to move it; it opens there next time. Right-click to go back to the game's spot.", 0.74, 0.74, 0.74, true)
        GameTooltip:Show()
    end)
    d:SetScript("OnLeave", GameTooltip_Hide)
    f:HookScript("OnShow", function() C_Timer.After(0, TK.safe(applyPos)) end)
    hooksecurefunc("UpdateUIPanelPositions", function() C_Timer.After(0, TK.safe(applyPos)) end)
end

local function grip()
    local g = CreateFrame("Button", nil, PlayerSpellsFrame)
    g:SetSize(16, 16)
    g:SetPoint("BOTTOMRIGHT", -2, 2)
    g:SetFrameLevel(PlayerSpellsFrame:GetFrameLevel() + 50)
    g:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    g:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    g:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    g:RegisterForClicks("RightButtonUp")
    g:SetScript("OnClick", function() if InCombatLockdown() then return end TK.db.windowScale = nil applyScale() end)
    g:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or InCombatLockdown() then return end
        self:SetScript("OnUpdate", function()
            local f = PlayerSpellsFrame
            local x = GetCursorPosition()
            local px = UIParent:GetEffectiveScale()
            local width = x - f:GetLeft() * f:GetEffectiveScale()
            local s = math.max(0.5, math.min(1.2, width / (f:GetWidth() * px)))
            TK.db.windowScale = math.floor(s * 100 + 0.5) / 100
            applyScale()
        end)
    end)
    g:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        if TK.db.windowPos then savePos() end -- keep the moved spot where you see it now
    end)
    g:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Talent window size")
        GameTooltip:AddLine("Drag to make the window smaller or bigger. Right-click for the normal size.", 0.74, 0.74, 0.74, true)
        GameTooltip:Show()
    end)
    g:SetScript("OnLeave", GameTooltip_Hide)
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", TK.safe(function()
    tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not tf or not tf.GetTalentButtonByNodeID then return TK.log("talent window: no talent buttons found") end
    pane = CreateFrame("Frame", nil, UIParent)
    -- the suite's side panel: opaque panel fill, black edge, a 26px header over a black rule
    pane:SetWidth(PANE_W)
    pane:SetPoint("TOPLEFT", PlayerSpellsFrame, "TOPRIGHT", 1, 0)
    pane:SetPoint("BOTTOMLEFT", PlayerSpellsFrame, "BOTTOMRIGHT", 1, 0)
    pane:SetFrameStrata(PlayerSpellsFrame:GetFrameStrata())
    pane:EnableMouse(true)
    UI.fill(pane, "BACKGROUND", 0.06, 0.06, 0.06, 1)
    UI.ring(pane, 0)
    local mark = pane:CreateTexture(nil, "ARTWORK")
    mark:SetSize(16, 16)
    mark:SetPoint("LEFT", pane, "TOPLEFT", 8, -13)
    mark:SetTexture("Interface\\AddOns\\TalentKeeper\\icon.png")
    -- name and version, as the suite's other headers: mint first half, version in Small,
    -- amber while it's a dev, alpha or beta build
    local title = pane:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    title:SetPoint("LEFT", mark, "RIGHT", 6, 0)
    title:SetText("|cff98ff98Talent|rKeeper")
    pane.version = pane:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    pane.version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 6, 1)
    local rule = pane:CreateTexture(nil, "OVERLAY")
    rule:SetColorTexture(0, 0, 0, 1)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, -26); rule:SetPoint("TOPRIGHT", 0, -26)
    makeDetail()
    -- the scrolling list between the spec buttons and the selected build's panel
    pane.list = CreateFrame("Frame", nil, pane)
    pane.list:SetPoint("TOPLEFT", 0, TOP); pane.list:SetPoint("TOPRIGHT", 0, TOP)
    pane.list:SetPoint("BOTTOM", detail, "TOP", 0, 2)
    pane.list:SetClipsChildren(true)
    pane.list:EnableMouseWheel(true)
    pane.list:SetScript("OnMouseWheel", function(_, delta) offset = offset - delta * ROW * 3 TK.safe(W.refresh)() end)
    pane.list:SetScript("OnSizeChanged", function() TK.safe(W.refresh)() end)
    pane.newGroup = CreateFrame("Frame", nil, pane.list)
    pane.newGroup:SetSize(180, 20)
    local ng = pane.newGroup:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    ng:SetPoint("LEFT")
    ng:SetText("+ New group (drop a build here)")
    ng:SetTextColor(0.55, 0.55, 0.55)
    local save = UI.button(pane, "Save current", 98, function() UI.buildDialog(false) end)
    save:SetPoint("BOTTOMLEFT", 8, 8)
    local import = UI.button(pane, "Import", 98, function() UI.buildDialog(true) end)
    import:SetPoint("BOTTOMRIGHT", -8, 8)
    specButtons()
    pane:Hide()
    tf:HookScript("OnShow", function() pane:Show() TK.safe(W.refresh)() end)
    tf:HookScript("OnHide", function() W.hide() UI.hidePicker() pane:Hide() end)
    PlayerSpellsFrame:HookScript("OnShow", applyScale)
    grip()
    mover()
    applyScale()
end))
