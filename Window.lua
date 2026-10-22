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
local TABS = -(32 + SPEC + 6) -- the Builds / This season tabs, under the spec buttons
local ROW, HEAD, TOP = 24, 22, TABS - 24
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
        self:SetAlpha(0.4) -- the row you picked up dims; a mint line shows where it will land
        pane:SetScript("OnUpdate", TK.safe(W.dragLine))
    end)
    r:SetScript("OnDragStop", TK.safe(function() W.drop() end))
    r:SetScript("OnEnter", TK.safe(function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.b.name)
        local hero = C.heroName(self.b.text)
        if hero then GameTooltip:AddLine(hero, 0.74, 0.74, 0.74) end
        local tags = B.tagNames(self.b)
        if #tags > 0 then GameTooltip:AddLine("For: " .. table.concat(tags, ", "), 0.596, 1, 0.596, true) end
        GameTooltip:AddLine("Click to preview on the tree, double-click to apply. Drag to reorder, or onto a group heading.", 0.55, 0.55, 0.55, true)
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

-- Where a dragged build would land: the row under the cursor (before it, or after it on its lower
-- half), or a group heading (into that group).
local function dropSpot()
    for _, r in ipairs(rows) do
        if r:IsShown() and r:IsMouseOver() then
            local _, y = GetCursorPosition()
            local _, cy = r:GetCenter()
            return r, y / r:GetEffectiveScale() < cy
        end
    end
end

function W.dragLine()
    if not W.dragging then pane:SetScript("OnUpdate", nil) return end
    local line = pane.insertLine
    if not line then
        line = pane.list:CreateTexture(nil, "OVERLAY", nil, 7)
        line:SetColorTexture(0.596, 1, 0.596, 1)
        line:SetHeight(2)
        pane.insertLine = line
    end
    local r, after = dropSpot()
    line:ClearAllPoints()
    if r and r.b ~= W.dragging then
        local edge = after and "BOTTOM" or "TOP"
        line:SetPoint(edge .. "LEFT", r, edge .. "LEFT", 4, 0)
        line:SetPoint(edge .. "RIGHT", r, edge .. "RIGHT", -4, 0)
        line:Show()
    else
        line:Hide()
    end
end

-- Drop a dragged build between builds (reorders it, taking that group), onto a group heading or
-- "+ New group".
function W.drop()
    local b = W.dragging
    W.dragging = nil
    pane:SetScript("OnUpdate", nil)
    if pane.insertLine then pane.insertLine:Hide() end
    for _, r in ipairs(rows) do r:SetAlpha(1) end
    if not b then return end
    local r, after = dropSpot()
    if r and r.b ~= b then return B.move(B.specID(), b, r.b, after) end
    local target -- nil: no drop target; false: no group
    for _, h in ipairs(heads) do if h:IsShown() and h:IsMouseOver() then target = h.group or false end end
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
    local staged = B.isStaged(b)
    if staged then parts[#parts] = "|cff98ff98pending: Apply changes to finish|r" end
    if b.outdated then parts[#parts + 1] = "|cffffb84doutdated|r" end
    local tags = UI.tagSummary(b)
    detail.info:SetText(table.concat(parts, " · ") .. "\n" .. (tags and ("For: " .. tags) or "|cff8c8c8cNot tagged for anything|r"))
    detail.apply:SetText(staged and "|cff98ff98Apply changes|r" or "Apply")
    detail.apply:SetEnabled(staged or (d ~= nil and #d > 0))
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
    -- Apply: the build goes in as pending changes (the game's own load); then Apply changes
    -- commits them, same as the talent window's button. Double-click a row applies right away.
    detail.apply = UI.button(detail, "Apply", 204, on(function(b)
        if B.isStaged(b) then return tf:ApplyConfig() end
        B.apply(b, true)
    end))
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
    if W.inSeason and W.inSeason() then W.hide() return W.refreshSeason() end -- no tree marks there
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
    if text == (W.override and W.override.text) then return end -- nothing changed (typing junk, say)
    W.override = text and { text = text } or nil
    W.refresh()
    if not text and not TK.selected then W.hide() end
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

-- Window size: the Options slider scales the talent window (kept between sessions). It shrinks
-- toward its middle: the game places it by its top-left corner (the same spot at any size), so
-- TalentKeeper moves it to where its middle would be at full size. A size change keeps its middle.
local function centerAt(f, x, y) -- screen pixels
    local eff = f:GetEffectiveScale()
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / eff, y / eff)
end

-- After the game placed it (TOPLEFT on UIParent's TOPLEFT): its middle as if at full size.
local function recenter()
    local f = PlayerSpellsFrame
    if not f or not f:IsShown() or InCombatLockdown() or not TK.db.windowScale then return end
    local point, rel, relPoint = f:GetPoint(1)
    if point ~= "TOPLEFT" or rel ~= UIParent or relPoint ~= "TOPLEFT" then return end -- not the game's spot
    local eff = f:GetEffectiveScale()
    local full = eff / f:GetScale()
    local left, top = f:GetLeft(), f:GetTop()
    if not left then return end
    centerAt(f, left * eff + f:GetWidth() * full / 2, top * eff - f:GetHeight() * full / 2)
end

-- now = true from the slider (back to 100% included); on open only a set size is applied
local function applyScale(now)
    local f = PlayerSpellsFrame
    if not f or InCombatLockdown() then return end
    local want = TK.db.windowScale or (now == true and 1)
    if not want then return end -- normal size: the game's own scale (it shrinks the window to fit small screens)
    if math.abs(f:GetScale() - want) < 0.001 then return recenter() end
    local x, y = f:GetCenter()
    local old = f:GetEffectiveScale()
    f:SetScale(want)
    if x then centerAt(f, x * old, y * old) end
end

-- This season: every place this season (Delves, the Mythic+ dungeons, each raid's bosses) with
-- the build each of your specs has tagged there. Click a place to tag one of this spec's builds.
-- A second way to tag: quickest for someone arriving with a pile of builds to sort out.
local season, seasonRows, seasonHeads, seasonOffset = nil, {}, {}, 0
local SROW, SHEAD = 22, 20

local function seasonPlaces()
    local out = { { heading = "Delves" }, { key = "delve", name = "Delves" } }
    local dungeons = UI.seasonDungeons()
    if #dungeons > 0 then
        out[#out + 1] = { heading = "Mythic+ dungeons" }
        for _, d in ipairs(dungeons) do out[#out + 1] = d end
    end
    for _, raid in ipairs(UI.seasonRaids()) do
        out[#out + 1] = { heading = raid.name }
        for _, boss in ipairs(raid.bosses) do out[#out + 1] = boss end
    end
    return out
end

-- this class's specs, and which build each has tagged for a place
local function classSpecs()
    local out = {}
    for i = 1, GetNumSpecializations() or 0 do
        local specID, name, _, icon = GetSpecializationInfo(i)
        if specID then out[#out + 1] = { id = specID, name = name, icon = icon } end
    end
    return out
end
local function taggedFor(specID, key)
    for _, b in ipairs(TK.db.builds[specID] or {}) do if b.tags and b.tags[key] then return b end end
end

local function seasonRow(i)
    if seasonRows[i] then return seasonRows[i] end
    local r = CreateFrame("Button", nil, season.list)
    r:SetHeight(SROW)
    r.stripe = UI.fill(r, "BACKGROUND", 1, 1, 1, 0.05)
    UI.fill(r, "HIGHLIGHT", 0.851, 0.851, 0.851, 0.15)
    r.icons = {}
    for k = 1, 4 do
        local t = r:CreateTexture(nil, "ARTWORK")
        t:SetSize(14, 14)
        t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.icons[k] = t
    end
    r.text = r:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    r.text:SetPoint("LEFT", 8, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.place.name)
        for _, sp in ipairs(classSpecs()) do
            local b = taggedFor(sp.id, self.place.key)
            GameTooltip:AddDoubleLine(sp.name, b and b.name or "nothing tagged", 0.74, 0.74, 0.74,
                b and 0.596 or 0.55, b and 1 or 0.55, b and 0.596 or 0.55)
        end
        GameTooltip:AddLine("Click to pick a build for any of your specs.", 0.55, 0.55, 0.55, true)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", GameTooltip_Hide)
    r:SetScript("OnClick", TK.safe(function(self)
        local place = self.place
        -- every spec's builds side by side: tag a build for a place whatever spec you're in now
        UI.picker(self, place.name, function()
            local items = {}
            for k, sp in ipairs(classSpecs()) do
                if k > 1 then items[#items + 1] = { column = true } end
                items[#items + 1] = { heading = sp.name }
                local list, cur = TK.db.builds[sp.id] or {}, taggedFor(sp.id, place.key)
                for _, b in ipairs(list) do
                    items[#items + 1] = { label = b.name, checked = function() return b.tags and b.tags[place.key] ~= nil end,
                        onClick = function()
                            if not (b.tags and b.tags[place.key]) then B.setTag(b, place.key, place.name, true)
                            else B.setTag(b, place.key, place.name, false) end -- clicking the ticked one clears it
                            W.refreshSeason()
                        end }
                end
                if #list == 0 then items[#items + 1] = { label = "No builds saved", disabled = true } end
            end
            return items
        end)
    end))
    seasonRows[i] = r
    return r
end

local function seasonHead(i)
    if seasonHeads[i] then return seasonHeads[i] end
    local h = season.list:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    h:SetTextColor(0.55, 0.55, 0.55)
    seasonHeads[i] = h
    return h
end

function W.refreshSeason()
    if not season or not season:IsShown() then return end
    for _, r in ipairs(seasonRows) do r:Hide() end
    for _, h in ipairs(seasonHeads) do h:Hide() end
    local specs, cur = classSpecs(), B.specID()
    local places, total, counts = seasonPlaces(), 0, {}
    local height = season.list:GetHeight()
    local y, nr, nh, n = 0, 0, 0, 0
    for _, it in ipairs(places) do y = y + (it.heading and SHEAD or SROW) end
    seasonOffset = math.max(0, math.min(seasonOffset, y - height))
    y = 0
    for _, it in ipairs(places) do
        local h = it.heading and SHEAD or SROW
        local top = y - seasonOffset
        local inView = top >= 0 and top + h <= height
        if it.heading then
            if inView then
                nh = nh + 1
                local fs = seasonHead(nh)
                fs:SetText(it.heading)
                fs:ClearAllPoints()
                fs:SetPoint("BOTTOMLEFT", season.list, "TOPLEFT", 8, -(top + h - 3))
                fs:Show()
            end
        else
            total, n = total + 1, n + 1
            local any = false
            for _, sp in ipairs(specs) do
                if taggedFor(sp.id, it.key) then counts[sp.id] = (counts[sp.id] or 0) + 1 any = true end
            end
            if inView then
                nr = nr + 1
                local r = seasonRow(nr)
                r.place = it
                r.stripe:SetShown(n % 2 == 0)
                -- places no spec has a build for read gray: the gaps; the icons say which specs have one
                r.text:SetText(it.name)
                if any then r.text:SetTextColor(1, 1, 1) else r.text:SetTextColor(0.55, 0.55, 0.55) end
                for k, t in ipairs(r.icons) do
                    local sp = specs[k]
                    t:SetShown(sp ~= nil)
                    if sp then
                        t:ClearAllPoints()
                        t:SetPoint("RIGHT", r, "RIGHT", -8 - (#specs - k) * 18, 0)
                        t:SetTexture(sp.icon)
                        local has = taggedFor(sp.id, it.key) ~= nil
                        t:SetDesaturated(not has)
                        t:SetAlpha(has and 1 or 0.25)
                    end
                end
                r.text:SetPoint("RIGHT", r, "RIGHT", -8 - #specs * 18, 0)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -top); r:SetPoint("TOPRIGHT", 0, -top)
                r:Show()
            end
        end
        y = y + h
    end
    local parts = {}
    for _, sp in ipairs(specs) do parts[#parts + 1] = ("%s %d"):format(sp.name, counts[sp.id] or 0) end
    season.summary:SetText(("Of %d places: %s"):format(total, table.concat(parts, " · ")))
end

function W.inSeason() return season ~= nil and season:IsShown() end

local function makeSeason()
    season = CreateFrame("Frame", nil, pane)
    season:SetPoint("TOPLEFT", 1, TOP); season:SetPoint("BOTTOMRIGHT", -1, 1)
    season:SetFrameLevel(pane:GetFrameLevel() + 15)
    season:EnableMouse(true)
    UI.fill(season, "BACKGROUND", 0.06, 0.06, 0.06, 1)
    season.summary = season:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    season.summary:SetPoint("BOTTOMLEFT", 8, 6); season.summary:SetPoint("BOTTOMRIGHT", -8, 6)
    season.summary:SetJustifyH("LEFT")
    season.summary:SetWordWrap(true)
    season.summary:SetTextColor(0.74, 0.74, 0.74)
    season.list = CreateFrame("Frame", nil, season)
    season.list:SetPoint("TOPLEFT", 0, -2); season.list:SetPoint("BOTTOMRIGHT", 0, 36)
    season.list:SetClipsChildren(true)
    season.list:EnableMouseWheel(true)
    season.list:SetScript("OnMouseWheel", function(_, delta) seasonOffset = seasonOffset - delta * SROW * 3 TK.safe(W.refreshSeason)() end)
    season:SetScript("OnShow", function() TK.safe(W.refreshSeason)() end)
    season:Hide()
end

-- Tabs under the spec buttons: muted text off, mint text and a 2px bar on.
local tabs = {}
local function showTab(which)
    if which == "season" and not season then makeSeason() end
    if season then season:SetShown(which == "season") end
    for _, t in ipairs(tabs) do
        local on = t.which == which
        t.text:SetTextColor(on and 0.596 or 0.55, on and 1 or 0.55, on and 0.596 or 0.55)
        t.bar:SetShown(on)
    end
    UI.hidePicker()
    if which == "season" then W.hide() else W.refresh() end
end

local function makeTabs()
    local x = 8
    for _, def in ipairs({ { "builds", "Builds" }, { "season", "This season" } }) do
        local t = CreateFrame("Button", nil, pane)
        t.which = def[1]
        t.text = t:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
        t.text:SetPoint("LEFT")
        t.text:SetText(def[2])
        t:SetSize(math.ceil(t.text:GetStringWidth()) + 4, 20)
        t:SetPoint("TOPLEFT", x, TABS)
        t.bar = t:CreateTexture(nil, "OVERLAY")
        t.bar:SetColorTexture(0.596, 1, 0.596, 1)
        t.bar:SetHeight(2)
        t.bar:SetPoint("BOTTOMLEFT"); t.bar:SetPoint("BOTTOMRIGHT")
        t:SetScript("OnEnter", function(self) if not self.bar:IsShown() then self.text:SetTextColor(1, 1, 1) end end)
        t:SetScript("OnLeave", function(self) if not self.bar:IsShown() then self.text:SetTextColor(0.55, 0.55, 0.55) end end)
        t:SetScript("OnClick", TK.safe(function(self) showTab(self.which) end))
        tabs[#tabs + 1] = t
        x = x + t:GetWidth() + 14
    end
    showTab("builds")
end

-- Checkbox: 16px well and gray ring, mint square when on; the label is part of the 24px target.
function W.checkbox(parent, label, tip, get, set)
    local cb = CreateFrame("Button", nil, parent)
    cb:SetSize(204, 24)
    local box = CreateFrame("Frame", nil, cb)
    box:SetSize(16, 16)
    box:SetPoint("LEFT")
    UI.fill(box, "BACKGROUND", 1, 1, 1, 0.08)
    local boxRing = UI.ring(box, 0.4)
    local tick = box:CreateTexture(nil, "ARTWORK")
    tick:SetPoint("TOPLEFT", 4, -4); tick:SetPoint("BOTTOMRIGHT", -4, 4)
    tick:SetColorTexture(0.596, 1, 0.596, 1)
    cb.text = cb:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    cb.text:SetPoint("LEFT", box, "RIGHT", 8, 0)
    cb.text:SetPoint("RIGHT")
    cb.text:SetJustifyH("LEFT")
    cb.text:SetWordWrap(false)
    cb.text:SetText(label)
    function cb.sync() tick:SetShown(get() and true or false) end
    cb:SetScript("OnClick", TK.safe(function() set(not get()) cb.sync() end))
    cb:SetScript("OnEnter", function(self)
        boxRing(0.7)
        if not tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(label)
        GameTooltip:AddLine(tip, 0.74, 0.74, 0.74, true)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() boxRing(0.4) GameTooltip_Hide() end)
    cb.sync()
    return cb
end

-- Bring your builds in: the first time the pane opens (and from Options), the builds found in
-- other talent addons and your game loadouts, ticked; one click copies them in.
local bring
local BW, BPAD, BHEAD, BFOOT = 300, 12, 26, 36

-- Lay the view out top to bottom; on its own it's as tall as what it shows.
local function layoutBring()
    local y = bring.inPane and -8 or -(BHEAD + 10)
    bring.title:ClearAllPoints(); bring.title:SetPoint("TOPLEFT", BPAD, y)
    y = y - bring.title:GetStringHeight() - 6
    bring.note:ClearAllPoints(); bring.note:SetPoint("TOPLEFT", BPAD, y); bring.note:SetPoint("RIGHT", -BPAD, 0)
    y = y - bring.note:GetStringHeight() - 10
    local n = 0
    for _, cb in ipairs(bring.checks) do
        if cb:IsShown() then
            n = n + 1
            cb.row:ClearAllPoints()
            cb.row:SetPoint("TOPLEFT", 1, y); cb.row:SetPoint("TOPRIGHT", -1, y)
            cb.row.stripe:SetShown(n % 2 == 0)
            y = y - 24
        end
    end
    if n > 0 then y = y - 8 end
    if not bring.inPane then bring:SetHeight(-y + BFOOT) end
end

local function makeBring()
    bring = CreateFrame("Frame", "TalentKeeperBring", UIParent)
    bring:SetFrameStrata("DIALOG") -- above another talent addon's panel in the same spot (pickers stay above)
    bring:EnableMouse(true)
    bring:SetClampedToScreen(true)
    bring:SetMovable(true)
    bring.bg = UI.fill(bring, "BACKGROUND", 0.031, 0.031, 0.031, 0.97)
    UI.ring(bring, 0)
    tinsert(UISpecialFrames, "TalentKeeperBring") -- Escape closes it; it asks again next login
    -- header: the suite's strip with the mark, the name and the version; drag it to move
    local head = CreateFrame("Frame", nil, bring)
    head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT")
    head:SetHeight(BHEAD)
    UI.fill(head, "BACKGROUND", 1, 1, 1, 0.035)
    local rule = head:CreateTexture(nil, "OVERLAY")
    rule:SetColorTexture(0, 0, 0, 1)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT")
    local mark = head:CreateTexture(nil, "ARTWORK")
    mark:SetSize(16, 16)
    mark:SetPoint("LEFT", 8, 0)
    mark:SetTexture("Interface\\AddOns\\TalentKeeper\\icon.png")
    local name = head:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    name:SetPoint("LEFT", mark, "RIGHT", 6, 0)
    name:SetText("|cff98ff98Talent|rKeeper")
    local ver = head:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    ver:SetPoint("BOTTOMLEFT", name, "BOTTOMRIGHT", 6, 1)
    local v = TK.version or ""
    ver:SetText(((v:find("^dev") or v:find("%-alpha") or v:find("%-beta")) and "|cffffb84d" or "|cff8c8c8c") .. v .. "|r")
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() bring:StartMoving() end)
    head:SetScript("OnDragStop", function() bring:StopMovingOrSizing() end)
    bring.head = head
    bring.title = bring:CreateFontString(nil, "OVERLAY", "TalentKeeperFontLarge")
    bring.title:SetText("Bring your builds in")
    bring.note = bring:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    bring.note:SetJustifyH("LEFT")
    bring.note:SetWordWrap(true)
    bring.note:SetTextColor(0.74, 0.74, 0.74)
    bring.checks = {}
    -- footer: the band with the actions on the right, the main one first
    local foot = CreateFrame("Frame", nil, bring)
    foot:SetPoint("BOTTOMLEFT"); foot:SetPoint("BOTTOMRIGHT")
    foot:SetHeight(BFOOT)
    UI.fill(foot, "BACKGROUND", 1, 1, 1, 0.035)
    local frule = foot:CreateTexture(nil, "OVERLAY")
    frule:SetColorTexture(0, 0, 0, 1)
    frule:SetHeight(1)
    frule:SetPoint("TOPLEFT"); frule:SetPoint("TOPRIGHT")
    bring.foot = foot
    local function place(list)
        local prev
        for k = #list, 1, -1 do -- right to left
            local bt = list[k]
            bt:ClearAllPoints()
            if prev then bt:SetPoint("RIGHT", prev, "LEFT", -8, 0) else bt:SetPoint("RIGHT", foot, "RIGHT", -8, 0) end
            bt:Show()
            prev = bt
        end
    end
    bring.place = function(list)
        for _, bt in ipairs({ bring.go, bring.later, bring.done, bring.off, bring.reload }) do bt:Hide() end
        place(list)
    end
    bring.go = UI.button(foot, "Bring them in", 112, function()
        local chosen = {}
        for _, cb in ipairs(bring.checks) do if cb:IsShown() and cb.on then chosen[#chosen + 1] = cb.source end end
        local added, skipped = B.bringIn(chosen)
        W.showBringResult(added, skipped)
    end)
    bring.later = UI.button(foot, "Not now", 76, function()
        TK.db.imported.offered = true
        TK.log("bring in: not now")
        bring:Hide()
    end)
    bring.done = UI.button(foot, "Done", 76, function() bring:Hide() end)
    -- after bringing builds in: the other talent addons can be turned off (their panels sit where
    -- TalentKeeper's does); it takes effect on the next reload
    bring.off = UI.button(foot, "Turn them off", 112, TK.safe(function()
        for _, a in ipairs(W.otherAddons()) do C_AddOns.DisableAddOn(a.folder) TK.log("bring in: turned off %s", a.name) end
        bring.note:SetText(bring.note:GetText() .. "\n\nTurned off from your next reload.")
        layoutBring()
        bring.place({ bring.reload, bring.done })
    end))
    bring.reload = UI.button(foot, "Reload now", 100, function() C_UI.Reload() end)
    bring:Hide()
end

-- A source row: checkbox, the source's name and its count; the tooltip says where it comes from.
local function sourceRow(i)
    local cb = bring.checks[i]
    if cb then return cb end
    local row = CreateFrame("Frame", nil, bring)
    row:SetHeight(24)
    row.stripe = UI.fill(row, "BACKGROUND", 1, 1, 1, 0.05)
    cb = W.checkbox(row, "", nil, function() return cb and cb.on end, function(on) cb.on = on end)
    cb:SetPoint("LEFT", BPAD - 1, 0)
    cb:SetPoint("RIGHT", -BPAD, 0)
    cb.count = cb:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    cb.count:SetPoint("RIGHT")
    cb.count:SetTextColor(0.55, 0.55, 0.55)
    cb.text:SetPoint("RIGHT", cb.count, "LEFT", -6, 0)
    cb:HookScript("OnEnter", function(self)
        if not self.source then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.source.name)
        GameTooltip:AddLine(self.source.about, 0.74, 0.74, 0.74, true)
        GameTooltip:Show()
    end)
    cb:HookScript("OnLeave", GameTooltip_Hide)
    cb.row = row
    hooksecurefunc(cb, "Show", function() row:Show() end)
    hooksecurefunc(cb, "Hide", function() row:Hide() end)
    bring.checks[i] = cb
    return cb
end

-- where: "login" (on its own, mid-screen: the talent window isn't open), else in the pane
function W.showBring(fromOptions, where)
    if not bring then makeBring() end
    bring:ClearAllPoints()
    bring.inPane = not (where == "login" or not (pane and pane:IsShown()))
    bring.head:SetShown(not bring.inPane)
    bring.bg:SetColorTexture(bring.inPane and 0.06 or 0.031, bring.inPane and 0.06 or 0.031, bring.inPane and 0.06 or 0.031, bring.inPane and 1 or 0.97)
    if bring.inPane then
        bring:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -27); bring:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    else
        bring:SetWidth(BW)
        bring:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    end
    local sources = B.sources()
    for _, cb in ipairs(bring.checks) do cb:Hide() end
    for i, src in ipairs(sources) do
        local cb = sourceRow(i)
        cb.source, cb.on = src, true
        cb.text:SetText(src.short or src.name)
        cb.count:SetText(("%d build%s"):format(#src.builds, #src.builds == 1 and "" or "s"))
        cb.sync()
        cb:Show()
    end
    bring.title:SetText("Bring your builds in")
    bring.note:SetText(#sources > 0 and "Copy your builds from elsewhere. Ones you already have are skipped, and nothing is removed."
        or "Nothing to bring in: no other talent addon's builds or game loadouts were found.")
    layoutBring()
    bring.place(#sources > 0 and { bring.go, bring.later } or { bring.done })
    TK.log("bring in: offered (%d sources)%s", #sources, fromOptions and " from Options" or where == "login" and " at login" or "")
    bring:Show()
    return #sources
end

-- Other talent addons that are on right now: { name, folder }.
function W.otherAddons()
    local out = {}
    for _, a in ipairs({ { name = "Talent Loadout Ex", folder = "TalentLoadoutsEx" },
        { name = "Talent Loadout Manager", folder = "TalentLoadoutManager" } }) do
        if C_AddOns.IsAddOnLoaded(a.folder) then out[#out + 1] = a end
    end
    return out
end

function W.showBringResult(added, skipped)
    for _, cb in ipairs(bring.checks) do cb:Hide() end
    local text = ("Brought in %d build%s. %d %s already here."):format(added, added == 1 and "" or "s",
        skipped, skipped == 1 and "was" or "were")
    local others = W.otherAddons()
    if #others > 0 then
        local names = {}
        for _, a in ipairs(others) do names[#names + 1] = a.name end
        text = text .. ("\n\n%s %s on, with its own panel where TalentKeeper's sits. Turn %s off?"):format(
            table.concat(names, " and "), #others == 1 and "is still" or "are still", #others == 1 and "it" or "them")
    end
    bring.title:SetText(added > 0 and "Your builds are in" or "All set")
    bring.note:SetText(text)
    layoutBring()
    bring.place(#others > 0 and { bring.off, bring.done } or { bring.done })
end

-- Options: a gear in the pane's header swaps the build list for this view ---------------------
local opt
local function scaleLabel(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end

local function makeOptions()
    opt = CreateFrame("Frame", nil, pane)
    opt:SetPoint("TOPLEFT", 1, -27); opt:SetPoint("BOTTOMRIGHT", -1, 1)
    opt:SetFrameLevel(pane:GetFrameLevel() + 20)
    opt:EnableMouse(true)
    UI.fill(opt, "BACKGROUND", 0.06, 0.06, 0.06, 1)
    local head = opt:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    head:SetPoint("TOPLEFT", 8, -10)
    head:SetTextColor(0.55, 0.55, 0.55)
    head:SetText("Talent window")
    local label = opt:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    label:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -8)
    label:SetText("Size")
    -- the slider: a well-filled track with the gray ring, a light thumb (mint while dragging)
    local s = CreateFrame("Slider", nil, opt)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    s:SetPoint("RIGHT", -8, 0)
    s:SetHeight(16)
    local value = opt:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    value:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", 0, 8)
    s:SetMinMaxValues(0.5, 1.2)
    s:SetValueStep(0.05)
    s:SetObeyStepOnDrag(true)
    s:SetHitRectInsets(0, 0, -4, -4)
    UI.fill(s, "BACKGROUND", 1, 1, 1, 0.08)
    local setRing = UI.ring(s, 0.4)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(10, 16)
    thumb:SetColorTexture(0.851, 0.851, 0.851, 1)
    s:SetThumbTexture(thumb)
    s:SetScript("OnEnter", function(self)
        setRing(0.7)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Talent window size")
        GameTooltip:AddLine("Drag to make the talent window smaller or bigger. It stays where it is on screen.", 0.74, 0.74, 0.74, true)
        GameTooltip:Show()
    end)
    s:SetScript("OnLeave", function() setRing(0.4) GameTooltip_Hide() end)
    -- applied on release: resizing while dragging moves the slider (the pane hangs off the window)
    -- under the cursor, which fed back into the value
    local pending
    s:SetScript("OnMouseDown", function() thumb:SetColorTexture(0.596, 1, 0.596, 1) end)
    s:SetScript("OnMouseUp", TK.safe(function()
        thumb:SetColorTexture(0.851, 0.851, 0.851, 1)
        if not pending then return end
        if InCombatLockdown() then pending = nil return TK.chat("|cffff8888Can't resize the talent window in combat.|r") end
        TK.db.windowScale = math.abs(pending - 1) > 0.001 and pending or nil
        pending = nil
        applyScale(true)
    end))
    s:SetScript("OnValueChanged", TK.safe(function(_, v, user)
        v = math.floor(v * 20 + 0.5) / 20
        value:SetText(scaleLabel(v))
        if user then pending = v end
    end))
    local normal = UI.button(opt, "Normal size", 98, function()
        if InCombatLockdown() then return end
        TK.db.windowScale = nil
        s:SetValue(1)
        applyScale(true)
    end)
    normal:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -10)
    opt.slider = s
    -- Prompts
    local head2 = opt:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    head2:SetPoint("TOPLEFT", normal, "BOTTOMLEFT", 0, -18)
    head2:SetTextColor(0.55, 0.55, 0.55)
    head2:SetText("Prompts")
    local delve = W.checkbox(opt, "Ask in delves",
        "Offer your Delves build when you enter a delve. Off: no prompt or ready check strip in delves.",
        function() return not TK.db.noDelvePrompt end,
        function(on) TK.db.noDelvePrompt = not on or nil TK.log("option: ask in delves %s", on and "on" or "off") end)
    delve:SetPoint("TOPLEFT", head2, "BOTTOMLEFT", 0, -4)
    -- Builds
    local head3 = opt:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    head3:SetPoint("TOPLEFT", delve, "BOTTOMLEFT", 0, -14)
    head3:SetTextColor(0.55, 0.55, 0.55)
    head3:SetText("Builds")
    local simc = W.checkbox(opt, "Add to /simc",
        "Your builds for this spec go into the SimulationCraft addon's /simc text as saved loadouts, so sim sites can pick them.",
        function() return not TK.db.noSimc end,
        function(on) TK.db.noSimc = not on or nil TK.log("option: add to /simc %s", on and "on" or "off") end)
    simc:SetPoint("TOPLEFT", head3, "BOTTOMLEFT", 0, -4)
    local bringBtn = UI.button(opt, "Bring builds in...", 140, function() opt:Hide() W.showBring(true) end)
    bringBtn:SetPoint("TOPLEFT", simc, "BOTTOMLEFT", 0, -6)
    local function sync() delve.sync() simc.sync() end
    opt.sync = sync
    opt:SetScript("OnShow", function() s:SetValue(TK.db.windowScale or 1) value:SetText(scaleLabel(TK.db.windowScale or 1)) sync() end)
    opt:Hide()
end

-- The gear: gray at rest, mint on hover and while the options are open.
local function gear()
    local g = CreateFrame("Button", nil, pane)
    g:SetSize(24, 24)
    g:SetPoint("TOPRIGHT", -2, -1)
    g.icon = g:CreateTexture(nil, "ARTWORK")
    g.icon:SetSize(16, 16)
    g.icon:SetPoint("CENTER")
    g.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    g.icon:SetDesaturated(true)
    local function tint(on) if on then g.icon:SetVertexColor(0.596, 1, 0.596) else g.icon:SetVertexColor(0.851, 0.851, 0.851) end end
    tint(false)
    g:SetScript("OnClick", TK.safe(function()
        if not opt then makeOptions() end
        opt:SetShown(not opt:IsShown())
        UI.hidePicker()
        tint(opt:IsShown())
    end))
    g:SetScript("OnEnter", function(self)
        tint(true)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(opt and opt:IsShown() and "Back to your builds" or "Options")
        GameTooltip:Show()
    end)
    g:SetScript("OnLeave", function() tint(opt and opt:IsShown()) GameTooltip_Hide() end)
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
    makeTabs()
    pane:Hide()
    tf:HookScript("OnShow", function()
        pane:Show()
        TK.safe(W.refresh)()
        if not TK.db.imported.offered then
            TK.safe(function() if W.showBring() == 0 then TK.db.imported.offered = true bring:Hide() end end)()
        end
    end)
    tf:HookScript("OnHide", function()
        W.hide() UI.hidePicker() pane:Hide()
        if bring and bring.inPane then bring:Hide() end -- it sits in the pane: goes with it
    end)
    PlayerSpellsFrame:HookScript("OnShow", function() applyScale() end)
    hooksecurefunc("UpdateUIPanelPositions", function() TK.safe(recenter)() end) -- another panel moved it
    gear()
    applyScale()
end))

-- The first login with builds elsewhere: ask right away, before any talent window (and another
-- addon's panel beside it) is open. Out of combat; otherwise opening talents asks instead.
TK.on("PLAYER_LOGIN", function()
    C_Timer.After(5, TK.safe(function()
        if TK.db.imported.offered or InCombatLockdown() then return end
        if W.showBring(nil, "login") == 0 then TK.db.imported.offered = true bring:Hide() end
    end))
end)
