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
        -- the build's hero tree over the game's own name for the current one (the eye button is below)
        local current = tf.HeroTalentsContainer.HeroSpecLabel
        m.label:ClearAllPoints()
        if current then m.label:SetPoint("BOTTOM", current, "TOP", 0, 4) else m.label:SetPoint("BOTTOM", m, "TOP", 0, 26) end
        m.label:SetTextColor(0.1, 1, 0.1) -- green: the tree this build takes
        m.label:SetText(C.heroName(b.text) or "")
    end
    return d, hidden
end

-- A talent string on the tree before it's saved (the import form); nil puts back the selected build.
function W.preview(text)
    if text then W.show({ text = text }) else W.refresh() end
end

-- The side pane of builds -----------------------------------------------------------------
-- Docked to the window's right edge, at our own scale (parented to UIParent, in the window's strata
-- and level, shown with the talent window). Every control in one block at the top: a strip of spec tiles (always in the
-- class's spec order, so each sits in the same spot; the strip's width is shared out, so there's no
-- gap for three specs or crowding for four), then Apply / Tags... / More... and Save current /
-- Import across the full width; under it what's in the tree now and the build you're previewing;
-- then the Builds / Tag Overview tabs and the list, which scrolls.
local pane, rows, heads = nil, {}, {}
local PANE_W = 220
local DECK_Y, TILE_H, GAP = -34, 40, 4 -- the spec strip
local COL_X, COL_W = 8, PANE_W - 16
local ROW1 = DECK_Y - TILE_H - 6         -- Apply / Tags... / More...
local ROW2 = ROW1 - 24                   -- Save current / Import
local DETAIL_Y = ROW2 - 20 - 10          -- in the tree now / previewing
local TABS = DETAIL_Y - 52               -- the Builds / Tag Overview tabs
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
    r.sel = UI.fill(r, "BACKGROUND", 1, 1, 1, 0.12)
    UI.fill(r, "HIGHLIGHT", 0.851, 0.851, 0.851, 0.15)
    r.status = r:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    r.status:SetPoint("RIGHT", -8, 0)
    r.bar = r:CreateTexture(nil, "OVERLAY")
    r.bar:SetColorTexture(1, 1, 1, 1)
    r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(2)
    r.text = r:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    r.text:SetPoint("LEFT", 8, 0)
    r.text:SetPoint("RIGHT", r.status, "LEFT", -6, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    -- Shimmer: one soft white band sweeps across the row (once, two seconds), clipped to it.
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
        local none, peak = CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.15)
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
        if TK.db.noMotion then return end
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
        self:SetAlpha(0.4) -- the row you picked up dims; a white line shows where it will land
        pane:SetScript("OnUpdate", TK.safe(W.dragLine))
    end)
    r:SetScript("OnDragStop", TK.safe(function() W.drop() end))
    r:SetScript("OnEnter", TK.safe(function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.b.name)
        local hero = C.heroName(self.b.text)
        if hero then GameTooltip:AddLine(hero, 0.74, 0.74, 0.74) end
        local tags = B.tagNames(self.b)
        if #tags > 0 then GameTooltip:AddLine("Tags: " .. table.concat(tags, ", "), 1, 1, 1, true) end
        if self.b.gear then GameTooltip:AddLine("Gear set: " .. self.b.gear, 1, 1, 1) end
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
                { armed = function() return armedGroup == g end, label = function()
                    return armedGroup == g and ("|cffff6666Sure? Deletes %d build%s|r"):format(n, n == 1 and "" or "s") or "Delete it and its builds"
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
        line:SetColorTexture(1, 1, 1, 1)
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

-- The selected build under the control block: its name and what it is. Its buttons (Apply,
-- Tags..., More...) are always there, grayed until a build is picked.
local armedBuild
local lastNow -- the build in the tree at the last refresh: a change shimmers its row
local function refreshDetail(specID, now)
    local b = TK.selected
    if b and B.findSpec(b) ~= specID then b, TK.selected = nil, nil end
    for _, bt in ipairs(detail.buttons) do bt:SetEnabled(b ~= nil) end
    -- what's committed in the tree: a saved build, or talents you haven't saved
    if now then
        detail.name:SetText("|cff8c8c8cNow:|r " .. now.name)
        local hero, tags = C.heroName(now.text), UI.tagSummary(now)
        detail.nowInfo:SetText((hero and (hero .. " · ") or "") .. (tags and ("Tags: " .. tags) or "|cff8c8c8cNo tags yet|r"))
    else
        detail.name:SetText("|cff8c8c8cNow:|r winging it")
        detail.nowInfo:SetText("|cff8c8c8cThese talents aren't a saved build. Save current keeps them.|r")
    end
    if not b then
        detail.info:SetText("|cff8c8c8cClick a build to preview it on the tree.|r")
        W.hide()
        return
    end
    local d = W.show(b)
    local what
    if not d then what = "|cffff6666can't read it|r"
    elseif #d == 0 then what = "what you have now"
    else what = ("%d change%s marked"):format(#d, #d == 1 and "" or "s") end
    if b.outdated then what = what .. " · |cffffd84aoutdated|r" end
    detail.info:SetText(("|cffffffffPreview:|r %s · %s"):format(b.name, what))
    detail.apply:SetEnabled(d ~= nil and #d > 0)
end

-- More...: the build's less frequent actions, in the suite's picker.
local function moreItems(b, owner)
    local specID = B.specID()
    return {
        { label = "Group...", onClick = function() UI.groupMenu(owner, specID, b) return "keep" end },
        { label = "Gear set...", onClick = function() UI.gearMenu(owner, b) return "keep" end },
        { label = "Rename...", onClick = function()
            UI.textWindow({ title = "Rename build", text = b.name, singleLine = true, okText = "Rename",
                onOK = function(name) B.rename(specID, b, name) end })
        end },
        { label = "Copy talent string", onClick = function()
            UI.textWindow({ title = "Talent string: " .. b.name, text = b.text, readOnly = true })
        end },
        { label = "Update to my talents", onClick = function() B.updateToCurrent(b) end },
        { armed = function() return armedBuild == b end,
          label = function() return armedBuild == b and "|cffff6666Sure? Click again|r" or "|cffff6666Delete|r" end,
          onClick = function()
            if armedBuild == b then armedBuild = nil B.delete(specID, b) return end
            armedBuild = b
            C_Timer.After(3, function() if armedBuild == b then armedBuild = nil UI.refreshPicker() end end)
            return "keep"
        end },
    }
end

local function tip(bt, title, body)
    bt:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(TK.selected and body or "Pick a build first.", 0.74, 0.74, 0.74, true)
        GameTooltip:Show()
    end)
    bt:HookScript("OnLeave", GameTooltip_Hide)
end

local function hoverTip(bt, title, body)
    bt:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(body, 0.74, 0.74, 0.74, true)
        GameTooltip:Show()
    end)
    bt:HookScript("OnLeave", GameTooltip_Hide)
end

local function makeDetail()
    -- the control rows under the spec strip: the build's actions, then the list's
    local function on(fn) return function(self) local b = TK.selected if b then fn(b, self) end end end
    local third = math.floor((COL_W - 2 * GAP) / 3)
    detail = CreateFrame("Frame", nil, pane)
    detail.apply = UI.button(pane, "Apply", third, on(function(b) B.apply(b) end))
    detail.apply:SetPoint("TOPLEFT", COL_X, ROW1)
    tip(detail.apply, "Apply", "Changes your talents to the build you're previewing (same as double-clicking it).")
    local tagsBtn = UI.button(pane, "Tags...", third, on(function(b, self) UI.tagMenu(self, b) end))
    tagsBtn:SetPoint("LEFT", detail.apply, "RIGHT", GAP, 0)
    tip(tagsBtn, "Tags", "The dungeons, delves and bosses this build is for.")
    local more = UI.button(pane, "More...", COL_W - 2 * (third + GAP), on(function(b, self)
        UI.picker(self, b.name, function() return moreItems(b, self) end)
    end))
    more:SetPoint("LEFT", tagsBtn, "RIGHT", GAP, 0)
    tip(more, "More", "Group, rename, copy the talent string, update to your talents, delete.")
    local half = math.floor((COL_W - GAP) / 2)
    local save = UI.button(pane, "Save current", half, function() UI.buildDialog(false) end)
    save:SetPoint("TOPLEFT", COL_X, ROW2)
    hoverTip(save, "Save current", "Save your talents now as a new build.")
    local import = UI.button(pane, "Import", COL_W - half - GAP, function() UI.buildDialog(true) end)
    import:SetPoint("LEFT", save, "RIGHT", GAP, 0)
    hoverTip(import, "Import", "Paste a talent string; it shows on the tree before you save it.")
    detail.buttons = { detail.apply, tagsBtn, more }
    -- under the block: what's in the tree now, then the build you're previewing
    detail:SetPoint("TOPLEFT", 0, DETAIL_Y); detail:SetPoint("TOPRIGHT", 0, DETAIL_Y)
    detail:SetHeight(48)
    local rule = detail:CreateTexture(nil, "OVERLAY")
    rule:SetColorTexture(0, 0, 0, 1)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT")
    local function line(font, y)
        local fs = detail:CreateFontString(nil, "OVERLAY", font)
        fs:SetPoint("TOPLEFT", 8, y); fs:SetPoint("TOPRIGHT", -8, y)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        fs:SetTextColor(0.74, 0.74, 0.74)
        return fs
    end
    detail.name = line("TalentKeeperFont", 0)
    detail.name:SetTextColor(1, 1, 1)
    detail.nowInfo = line("TalentKeeperFontSmall", -16)
    detail.info = line("TalentKeeperFontSmall", -30)
end

function W.refresh()
    if not pane or not pane:IsShown() then return end
    W.refreshSpecs()
    if W.inSeason and W.inSeason() then W.hide() return W.refreshSeason() end -- no tree marks there
    for _, r in ipairs(rows) do r:Hide() end
    for _, h in ipairs(heads) do h:Hide() end
    local specID = B.specID()
    local now = specID and B.onNow(specID)
    pane.head.version:SetText(UI.versionText())
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
            if b.outdated then r.status:SetTextColor(1, 0.847, 0.29) else r.status:SetTextColor(0.55, 0.55, 0.55) end
            r.stripe:SetShown(n % 2 == 0)
            r.sel:SetShown(b == TK.selected)
            local isOn = b == now
            if isOn and lastNow ~= nil and lastNow ~= now then r.Shimmer() end -- it just went in the tree
            r.text:SetTextColor(1, 1, 1)
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
    refreshDetail(specID, now)
    if lastNow ~= nil and lastNow ~= (now or false) then UIFrameFadeIn(detail.name, 0.4, 0, 1) end
    lastNow = now or false
end

local prev = TK.onChange
TK.onChange = function()
    if prev then prev() end
    TK.safe(W.refresh)()
end
TK.on("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", function() TK.selected = nil offset = 0 TK.safe(W.refresh)() end)
-- your talents changed (an apply landed, a click in the tree): redraw the preview
TK.on("TRAIT_CONFIG_UPDATED", function() TK.safe(W.refresh)() end)

-- Spec tiles: one strip across the top, in the class's spec order (each spec always in the same
-- spot), the width shared out so three or four fill it alike; yours lit with the white ring, the
-- others gray. Click one to change spec; it fills like a cast bar while the change casts.
local specs = {}

local function stopCast(b)
    b.fill:Hide()
    b:SetScript("OnUpdate", nil)
end

function W.refreshSpecs()
    local cur = GetSpecialization and GetSpecialization()
    for i, b in ipairs(specs) do
        local on = i == cur
        b.icon:SetDesaturated(not on)
        b.icon:SetAlpha(on and 1 or 0.6)
        b.ring(on and 1 or 0.4)
        if on then stopCast(b) end
    end
end

local function specButtons()
    local n = GetNumSpecializations() or 0
    local w = math.floor((COL_W - GAP * (n - 1)) / math.max(n, 1))
    -- crop the square icon to the tile's shape (top and bottom trimmed), inside the usual border trim
    local keep = 0.84 * TILE_H / w
    local top = 0.5 - keep / 2
    for i = 1, n do
        local specID, name, _, icon = GetSpecializationInfo(i)
        local b = CreateFrame("Button", nil, pane)
        b:SetSize(i == n and (COL_W - (n - 1) * (w + GAP)) or w, TILE_H) -- the last takes any rounding
        b:SetPoint("TOPLEFT", COL_X + (i - 1) * (w + GAP), DECK_Y)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 1, -1); b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        b.icon:SetTexture(icon)
        b.icon:SetTexCoord(0.08, 0.92, top, top + keep)
        b.fill = b:CreateTexture(nil, "OVERLAY")
        b.fill:SetColorTexture(1, 1, 1, 0.35)
        b.fill:SetPoint("BOTTOMLEFT", 1, 1); b.fill:SetPoint("BOTTOMRIGHT", -1, 1)
        b.fill:Hide()
        b.ring = UI.ring(b, 0.4)
        UI.fill(b, "HIGHLIGHT", 1, 1, 1, 0.15)
        b:SetScript("OnClick", TK.safe(function(self)
            if i == GetSpecialization() then return end
            if InCombatLockdown() then return TK.chat("|cffff6666Can't change spec in combat.|r") end
            TK.log("spec change to %s", name)
            C_SpecializationInfo.SetSpecialization(i)
            -- fill like a cast bar while the change casts; stop when it ends or never starts
            local t0, seen = GetTime(), false
            self:SetScript("OnUpdate", function(me)
                local _, _, _, startMs, endMs = UnitCastingInfo("player")
                if startMs and endMs and endMs > startMs then
                    seen = true
                    local p = math.min(1, (GetTime() * 1000 - startMs) / (endMs - startMs))
                    me.fill:SetHeight(math.max(1, (TILE_H - 2) * p))
                    me.fill:Show()
                elseif seen or GetTime() - t0 > 1.5 then
                    stopCast(me)
                end
            end)
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

-- This season: every place this season (Miscellaneous, the Mythic+ dungeons, each raid's bosses) with
-- the build each of your specs has tagged there. Click a place to tag one of this spec's builds.
-- A second way to tag: quickest for someone arriving with a pile of builds to sort out.
local season, seasonRows, seasonHeads, seasonOffset = nil, {}, {}, 0
local SROW, SHEAD = 22, 20

local function seasonPlaces()
    local out = { { heading = "Miscellaneous" } }
    for _, c in ipairs(UI.CONTENT) do out[#out + 1] = c end
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
    -- tree lines from the heading down to each place, as the suite's filter lists draw them
    r.trunk = r:CreateTexture(nil, "ARTWORK")
    r.trunk:SetColorTexture(0.3, 0.3, 0.3, 1)
    r.trunk:SetWidth(1)
    r.trunk:SetPoint("TOP", r, "TOPLEFT", 11, 3) -- up to the heading above
    r.branch = r:CreateTexture(nil, "ARTWORK")
    r.branch:SetColorTexture(0.3, 0.3, 0.3, 1)
    r.branch:SetSize(5, 1)
    r.branch:SetPoint("LEFT", 11, 0)
    r.text = r:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    r.text:SetPoint("LEFT", 18, 0) -- indented under its heading
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.place.name)
        for _, sp in ipairs(classSpecs()) do
            local b = taggedFor(sp.id, self.place.key)
            GameTooltip:AddDoubleLine(sp.name, b and b.name or "nothing tagged", 0.74, 0.74, 0.74,
                b and 1 or 0.55, b and 1 or 0.55, b and 1 or 0.55)
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

-- A heading folds its places away on click ("+" folded, "-" open); remembered across sessions.
local function seasonHead(i)
    if seasonHeads[i] then return seasonHeads[i] end
    local h = CreateFrame("Button", nil, season.list)
    h:SetHeight(SHEAD)
    h.text = h:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    h.text:SetPoint("BOTTOMLEFT", 8, 3)
    h.text:SetTextColor(0.55, 0.55, 0.55)
    h:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
    h:SetScript("OnLeave", function(self) self.text:SetTextColor(0.55, 0.55, 0.55) end)
    h:SetScript("OnClick", TK.safe(function(self)
        TK.db.seasonClosed = TK.db.seasonClosed or {}
        TK.db.seasonClosed[self.name] = not TK.db.seasonClosed[self.name] or nil
        W.refreshSeason()
    end))
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
    local closed = TK.db.seasonClosed or {}
    local y, nr, nh, n, shut = 0, 0, 0, 0, false
    for _, it in ipairs(places) do
        if it.heading then shut = closed[it.heading] end
        if it.heading or not shut then y = y + (it.heading and SHEAD or SROW) end
    end
    seasonOffset = math.max(0, math.min(seasonOffset, y - height))
    y, shut = 0, false
    for idx, it in ipairs(places) do
        if it.heading then shut = closed[it.heading] end
        local h = (it.heading or not shut) and (it.heading and SHEAD or SROW) or 0
        local top = y - seasonOffset
        local inView = top >= 0 and top + h <= height
        if it.heading then
            if inView then
                nh = nh + 1
                local hb = seasonHead(nh)
                hb.name = it.heading
                hb.text:SetText((shut and "+ " or "- ") .. it.heading)
                hb:ClearAllPoints()
                hb:SetPoint("TOPLEFT", 0, -top); hb:SetPoint("TOPRIGHT", 0, -top)
                hb:Show()
            end
        else
            total = total + 1
            if not shut then n = n + 1 end -- stripes alternate over what shows
            local any = false
            for _, sp in ipairs(specs) do
                if taggedFor(sp.id, it.key) then counts[sp.id] = (counts[sp.id] or 0) + 1 any = true end
            end
            if inView and not shut then
                nr = nr + 1
                local r = seasonRow(nr)
                r.place = it
                r.stripe:SetShown(n % 2 == 0)
                local last = not places[idx + 1] or places[idx + 1].heading -- the trunk ends at the last place
                r.trunk:SetPoint("BOTTOM", r, last and "LEFT" or "BOTTOMLEFT", 11, 0)
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

-- Tabs under the spec buttons: muted text off, white text and a 2px bar on.
local tabs = {}
local function showTab(which)
    if which == "season" and not season then makeSeason() end
    if season then season:SetShown(which == "season") end
    for _, t in ipairs(tabs) do
        local on = t.which == which
        t.text:SetTextColor(on and 1 or 0.55, on and 1 or 0.55, on and 1 or 0.55)
        t.bar:SetShown(on)
    end
    UI.hidePicker()
    if which == "season" then W.hide() else W.refresh() end
end

local function makeTabs()
    local x = 8
    for _, def in ipairs({ { "builds", "Builds" }, { "season", "Tag Overview" } }) do
        local t = CreateFrame("Button", nil, pane)
        t.which = def[1]
        t.text = t:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
        t.text:SetPoint("LEFT")
        t.text:SetText(def[2])
        t:SetSize(math.ceil(t.text:GetStringWidth()), 20) -- the bar spans the word, no overhang
        t:SetPoint("TOPLEFT", x, TABS)
        t.bar = t:CreateTexture(nil, "OVERLAY")
        t.bar:SetColorTexture(1, 1, 1, 1)
        t.bar:SetHeight(2)
        t.bar:SetPoint("BOTTOMLEFT"); t.bar:SetPoint("BOTTOMRIGHT")
        t:SetScript("OnEnter", function(self)
            if not self.bar:IsShown() then self.text:SetTextColor(1, 1, 1) end
            if self.which ~= "season" then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Tag Overview")
            GameTooltip:AddLine("This season's dungeons, delves and raid bosses, with the build tagged for each of your specs. The gaps stand out; click a place to tag one.", 0.74, 0.74, 0.74, true)
            GameTooltip:Show()
        end)
        t:SetScript("OnLeave", function(self) if not self.bar:IsShown() then self.text:SetTextColor(0.55, 0.55, 0.55) end GameTooltip_Hide() end)
        t:SetScript("OnClick", TK.safe(function(self) showTab(self.which) end))
        tabs[#tabs + 1] = t
        x = x + t:GetWidth() + 14
    end
    showTab("builds")
end

-- Checkbox: 16px well and gray ring, white square when on; the label is part of the 24px target.
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
    tick:SetColorTexture(1, 1, 1, 1)
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
    local head = UI.header(bring)
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
    local foot = UI.footBand(bring, BFOOT)
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
        W.showConflicts(nil)
    end)
    bring.done = UI.button(foot, "Done", 76, function() bring:Hide() end)
    -- after bringing builds in: the other talent addons can be turned off (their panels sit where
    -- TalentKeeper's does); it takes effect on the next reload
    bring.off = UI.button(foot, "Later", 76, function() TK.log("other addons: later") bring:Hide() end)
    bring.reload = UI.button(foot, "Reload now", 100, function() TK.log("other addons: reload") C_UI.Reload() end)
    bring:Hide()
end

-- A source row: checkbox, the source's name and its count; the tooltip says where it comes from.
local function sourceRow(i)
    local cb = bring.checks[i]
    if cb then return cb end
    local row = CreateFrame("Frame", nil, bring)
    row:SetHeight(24)
    row.stripe = UI.fill(row, "BACKGROUND", 1, 1, 1, 0.05)
    cb = W.checkbox(row, "", nil, function() return cb and cb.on end, function(on)
        cb.on = on
        if cb.addon then -- an other-addon row: on / off from the next reload
            if on then C_AddOns.EnableAddOn(cb.addon.folder) else C_AddOns.DisableAddOn(cb.addon.folder) end
            TK.log("other addons: %s %s from next reload", cb.addon.name, on and "on" or "off")
        end
    end)
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
        cb.source, cb.on, cb.addon = src, true, nil
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

-- After bringing builds in (or skipping it): the other talent addons, ticked while they're on.
-- Untick one to turn it off from the next reload (their panels sit where TalentKeeper's does).
function W.showConflicts(result)
    local others = W.otherAddons()
    if #others == 0 then
        if not result then return bring:Hide() end
        bring.title:SetText("Your builds are in")
        bring.note:SetText(result)
        for _, cb in ipairs(bring.checks) do cb:Hide() end
        layoutBring()
        return bring.place({ bring.done })
    end
    local names = {}
    for _, a in ipairs(others) do names[#names + 1] = a.name end
    bring.title:SetText(("Turn off %s?"):format(#others == 1 and others[1].name or "the other talent addons"))
    bring.note:SetText((result and (result .. "\n\n") or "") .. ("%s %s its own panel where TalentKeeper's sits. Untick to turn %s off from your next reload."):format(
        table.concat(names, " and "), #others == 1 and "has" or "have", #others == 1 and "it" or "them"))
    for _, cb in ipairs(bring.checks) do cb:Hide() end
    for i, a in ipairs(others) do
        local cb = sourceRow(i)
        cb.source = { name = a.name, about = "Ticked: on. Untick to turn it off from your next reload; its saved builds stay where they are." }
        cb.on = true
        cb.text:SetText(a.name)
        cb.count:SetText("")
        cb.addon = a
        cb.sync()
        cb:Show()
    end
    layoutBring()
    bring.place({ bring.reload, bring.off })
    TK.log("other addons: asked (%s)", table.concat(names, ", "))
end

function W.showBringResult(added, skipped)
    W.showConflicts(("Brought in %d build%s. %d %s already here."):format(added, added == 1 and "" or "s",
        skipped, skipped == 1 and "was" or "were"))
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
    -- the slider: a well-filled track with the gray ring, a light thumb (white while dragging)
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
    s:SetScript("OnMouseDown", function() thumb:SetColorTexture(1, 1, 1, 1) end)
    s:SetScript("OnMouseUp", TK.safe(function()
        thumb:SetColorTexture(0.851, 0.851, 0.851, 1)
        if not pending then return end
        if InCombatLockdown() then pending = nil return TK.chat("|cffff6666Can't resize the talent window in combat.|r") end
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
    local motion = W.checkbox(opt, "Animate what changed",
        "The prompt's button and the ready check strip's Switch pulse when they appear; saved, tagged, moved and newly live builds shimmer once.",
        function() return not TK.db.noMotion end,
        function(on) TK.db.noMotion = not on or nil TK.log("option: animate what changed %s", on and "on" or "off") end)
    motion:SetPoint("TOPLEFT", delve, "BOTTOMLEFT", 0, 0)
    -- Builds
    local head3 = opt:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    head3:SetPoint("TOPLEFT", motion, "BOTTOMLEFT", 0, -14)
    head3:SetTextColor(0.55, 0.55, 0.55)
    head3:SetText("Builds")
    local simc = W.checkbox(opt, "Add to /simc",
        "Your builds for this spec go into the SimulationCraft addon's /simc text as saved loadouts, so sim sites can pick them.",
        function() return not TK.db.noSimc end,
        function(on) TK.db.noSimc = not on or nil TK.log("option: add to /simc %s", on and "on" or "off") end)
    simc:SetPoint("TOPLEFT", head3, "BOTTOMLEFT", 0, -4)
    local bringBtn = UI.button(opt, "Bring builds in...", 140, function() opt:Hide() W.showBring(true) end)
    bringBtn:SetPoint("TOPLEFT", simc, "BOTTOMLEFT", 0, -6)
    local function sync() delve.sync() motion.sync() simc.sync() end
    opt.sync = sync
    opt:SetScript("OnShow", function() s:SetValue(TK.db.windowScale or 1) value:SetText(scaleLabel(TK.db.windowScale or 1)) sync() end)
    opt:Hide()
end

-- Settings & Activity: the suite's drawn three-bar icon in the pane's header. It shows or hides
-- the options view (a toggle: white while open); light gray at rest, white on hover.
local function gear()
    local g = CreateFrame("Button", nil, pane)
    g:SetSize(24, 24)
    g:SetPoint("TOPRIGHT", -2, -1)
    local bars = {}
    for i, y in ipairs({ 4, 0, -4 }) do
        bars[i] = g:CreateTexture(nil, "ARTWORK")
        bars[i]:SetSize(12, 2)
        bars[i]:SetPoint("CENTER", 0, y)
    end
    local function tint(on) local c = on and 1 or 0.7 for _, t in ipairs(bars) do t:SetColorTexture(c, c, c, 1) end end
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
        GameTooltip:SetText("Settings & Activity")
        GameTooltip:Show()
    end)
    g:SetScript("OnLeave", function() tint(opt and opt:IsShown()) GameTooltip_Hide() end)
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", TK.safe(function()
    tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not tf or not tf.GetTalentButtonByNodeID then return TK.log("talent window: no talent buttons found") end
    pane = CreateFrame("Frame", nil, UIParent)
    -- follow the window's strata and level (it's raised on click, another addon may restack it), so
    -- other windows overlap both alike. Not parented to it: that joins Blizzard's anchor family and
    -- breaks the hero talent layout.
    pane:SetScript("OnUpdate", function()
        local f = PlayerSpellsFrame
        if pane:GetFrameStrata() ~= f:GetFrameStrata() then pane:SetFrameStrata(f:GetFrameStrata()) end
        if pane:GetFrameLevel() ~= f:GetFrameLevel() then pane:SetFrameLevel(f:GetFrameLevel()) end
    end)
    -- the suite's side panel: opaque panel fill, black edge, a 26px header over a black rule
    pane:SetWidth(PANE_W)
    pane:SetPoint("TOPLEFT", PlayerSpellsFrame, "TOPRIGHT", 1, 0)
    pane:SetPoint("BOTTOMLEFT", PlayerSpellsFrame, "BOTTOMRIGHT", 1, 0)
    UI.pane = pane
    pane:EnableMouse(true)
    UI.fill(pane, "BACKGROUND", 0.06, 0.06, 0.06, 1)
    UI.ring(pane, 0)
    pane.head = UI.header(pane)
    makeDetail()
    -- the scrolling list between the spec buttons and the selected build's panel
    pane.list = CreateFrame("Frame", nil, pane)
    pane.list:SetPoint("TOPLEFT", 0, TOP); pane.list:SetPoint("TOPRIGHT", 0, TOP)
    pane.list:SetPoint("BOTTOM", pane, "BOTTOM", 0, 1)
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
