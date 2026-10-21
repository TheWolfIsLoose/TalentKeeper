-- TalentKeeper ready check: a small strip under Blizzard's ready check popup (or where you put
-- it) that says whether you're on the build tagged for what's next: the dungeon or delve you're
-- in, or in a raid the boss TalentKeeper expects. Switch, use your build there, or correct the
-- boss (which teaches it that room). No pop-ups anywhere else in raids.
local _, TK = ...
local B, UI, P = TK.builds, TK.ui, TK.prompt
local R = {}
TK.readycheck = R

local strip, manual -- manual: { boss, inst }, the boss picked by hand in this raid, until the next kill

-- Raid bosses ------------------------------------------------------------------------------
-- This raid's bosses in journal order, from the season list ({ key = "boss:<id>", name }).
local function raidBosses(name)
    for _, raid in ipairs(UI.seasonRaids()) do
        if raid.name == name then return raid.bosses end
    end
    return {}
end

local function killed(instID, diffID, key)
    local enc = tonumber(key:match("^boss:(%d+)$"))
    local ok, done = pcall(C_RaidLocks.IsEncounterComplete, instID, enc, diffID)
    return ok and done
end

-- A room: the subzone you're in, unless it's empty or just the raid's own name.
local function room(raidName)
    local sub = GetSubZoneText()
    if not sub or sub == "" or sub == raidName then return nil end
    return sub
end

-- The boss to expect: picked by hand, else the room it's pulled in, else the first boss your
-- lockout hasn't killed, else the first boss. Returns { key, name }, how ("picked" / "room" /
-- "lockout" / "first").
function R.expectedBoss()
    local name, _, diffID, _, _, _, _, instID = GetInstanceInfo()
    local bosses = raidBosses(name)
    if #bosses == 0 then return nil end
    if manual and manual.inst == instID then return manual.boss, "picked" end
    local rooms = TK.db.rooms[instID] or {}
    local here = room(name)
    local enc = here and rooms[here]
    if enc then
        for _, b in ipairs(bosses) do if b.key == "boss:" .. enc then return b, "room" end end
    end
    for _, b in ipairs(bosses) do
        if not killed(instID, diffID, b.key) then return b, "lockout" end
    end
    return bosses[1], "first"
end

-- Remember which boss belongs to the room you're in (a pull, or a correction).
local function learnRoom(enc, why)
    local name, kind, _, _, _, _, _, instID = GetInstanceInfo()
    if kind ~= "raid" then return end -- dungeons have one build for the whole run
    local here = room(name)
    if not here or not enc then return end
    TK.db.rooms[instID] = TK.db.rooms[instID] or {}
    if TK.db.rooms[instID][here] ~= enc then
        TK.db.rooms[instID][here] = enc
        TK.log("readycheck: room '%s' -> boss %s (%s)", here, tostring(enc), why)
    end
end

-- The strip --------------------------------------------------------------------------------
local function place()
    strip:ClearAllPoints()
    local pos = TK.db.readyCheckPos
    if pos then
        strip:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    elseif ReadyCheckFrame and ReadyCheckFrame:IsShown() then
        strip:SetPoint("TOP", ReadyCheckFrame, "BOTTOM", 0, -4)
    else
        strip:SetPoint("TOP", UIParent, "TOP", 0, -200)
    end
end

local function makeStrip()
    strip = CreateFrame("Frame", "TalentKeeperReadyCheck", UIParent)
    strip:SetSize(300, 50)
    strip:SetFrameStrata("DIALOG")
    strip:SetClampedToScreen(true)
    strip:SetMovable(true)
    strip:EnableMouse(true)
    strip:RegisterForDrag("LeftButton")
    UI.fill(strip, "BACKGROUND", 0.06, 0.06, 0.06, 0.98)
    UI.ring(strip, 0)
    -- shift-drag to move; the spot is kept
    strip:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
    strip:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        TK.db.readyCheckPos = { point = point, x = x, y = y }
    end)
    strip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("TalentKeeper")
        GameTooltip:AddLine("Shift-drag to move.", 0.74, 0.74, 0.74)
        GameTooltip:Show()
    end)
    strip:SetScript("OnLeave", GameTooltip_Hide)
    local mark = strip:CreateTexture(nil, "ARTWORK")
    mark:SetSize(16, 16)
    mark:SetPoint("TOPLEFT", 8, -8)
    mark:SetTexture("Interface\\AddOns\\TalentKeeper\\icon.png")
    -- the situation; in a raid the boss name is a button that opens the boss list
    strip.what = CreateFrame("Button", nil, strip)
    strip.what:SetHeight(16)
    strip.what:SetPoint("LEFT", mark, "RIGHT", 6, 0)
    strip.what.text = strip.what:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    strip.what.text:SetPoint("LEFT")
    strip.what:SetScript("OnEnter", function(self) if self.pick then self.text:SetTextColor(0.596, 1, 0.596) end end)
    strip.what:SetScript("OnLeave", function(self) self.text:SetTextColor(1, 1, 1) end)
    strip.status = strip:CreateFontString(nil, "OVERLAY", "TalentKeeperFontSmall")
    strip.status:SetPoint("TOPLEFT", mark, "BOTTOMLEFT", 0, -6)
    strip.btn = UI.button(strip, "", 70, function() end)
    strip.btn:SetPoint("RIGHT", -8, 0)
end

-- The situation for this ready check: { key, name, pick? }, or nil where there's nothing to say.
local function situation()
    local name, kind = GetInstanceInfo()
    if kind == "raid" then
        local boss, how = R.expectedBoss()
        if not boss then return nil end
        return { key = boss.key, name = boss.name, pick = true, how = how }
    end
    local here = B.here()
    return P.taggable(here) and here or nil
end

local hooked -- ReadyCheckFrame's OnHide hooked once
-- Once per boss (or dungeon / delve): after that the player has made their call, so wipes and
-- reloads don't bring it back. Saved per instance and place; forgotten after 16 hours.
local FORGET = 16 * 3600
function R.show(check)
    local here = situation()
    if not here then return R.hide() end
    if check then
        local seen, now = TK.db.readySeen, time()
        for k, at in pairs(seen) do if now - at >= FORGET then seen[k] = nil end end
        local id = select(8, GetInstanceInfo()) .. ":" .. here.key
        if seen[id] then return TK.log("readycheck: %s, already shown", here.name) end
        seen[id] = now
    end
    if not strip then makeStrip() end
    local hits = B.forHere(here)
    if here.content == "delve" and #hits == 0 then here = { key = "delve", name = "Delves" } end
    local hit = hits[1]
    strip.what.text:SetText(here.name .. (here.pick and " |cff8c8c8c(change)|r" or ""))
    strip.what:SetWidth(strip.what.text:GetStringWidth())
    strip.what.pick = here.pick
    strip.what:SetScript("OnClick", here.pick and TK.safe(function(self) R.pickBoss(self) end) or nil)
    local status, button
    if hit and P.onBuild(hit.b, hit.specID) then
        status = "|cff98ff98On " .. hit.b.name .. "|r"
    elseif hit then
        local spec = hit.specID ~= B.specID() and (" (" .. B.specName(hit.specID) .. ")") or ""
        status = "|cffffb84dWrong build:|r " .. hit.b.name .. spec .. " is tagged here"
        button = { "Switch", function() P.switch(hit.b, hit.specID) R.hide() end }
    else
        status = "|cff8c8c8cNothing tagged here|r"
        button = { "Choose...", function(bt) P.chooseFor(here, bt, R.refresh) end }
    end
    strip.status:SetText(status)
    strip.btn:SetShown(button ~= nil)
    if button then
        strip.btn:SetText(button[1])
        strip.btn:SetWidth(math.max(64, strip.btn:GetTextWidth() + 20))
        strip.btn:SetScript("OnClick", TK.safe(function() button[2](strip.btn) end))
    end
    local w = 8 + 16 + 6 + math.max(strip.what.text:GetStringWidth(), strip.status:GetStringWidth()) + 16
        + (button and strip.btn:GetWidth() + 8 or 0)
    strip:SetWidth(math.ceil(math.max(200, w)))
    place()
    strip:Show()
    -- answering the ready check (or it timing out) closes Blizzard's popup: the strip goes with it
    if ReadyCheckFrame and not hooked then
        hooked = true
        ReadyCheckFrame:HookScript("OnHide", function() R.hide("answered") end)
    end
    TK.log("readycheck: %s%s, %s", here.name, here.how and (" (" .. here.how .. ")") or "",
        hit and (P.onBuild(hit.b, hit.specID) and ("on '" .. hit.b.name .. "'") or ("tagged '" .. hit.b.name .. "'")) or "nothing tagged")
end

function R.refresh() if strip and strip:IsShown() then R.show() end end
function R.hide(why)
    if not strip or not strip:IsShown() then return end
    strip:Hide()
    if why then TK.log("readycheck: strip closed (%s)", why) end
end

-- Correct the boss: this raid's bosses still alive this lockout; the choice teaches the room.
function R.pickBoss(owner)
    local name, _, diffID, _, _, _, _, instID = GetInstanceInfo()
    UI.picker(owner, "Which boss is next?", function()
        local items = {}
        for _, b in ipairs(raidBosses(name)) do
            if not killed(instID, diffID, b.key) then
                items[#items + 1] = { label = b.name, checked = function() return (R.expectedBoss()) == b end,
                    onClick = function()
                        manual = { boss = b, inst = instID }
                        learnRoom(tonumber(b.key:match("%d+")), "picked")
                        TK.log("readycheck: boss picked: %s", b.name)
                        R.refresh()
                    end }
            end
        end
        if #items == 0 then items[1] = { label = "Every boss is down.", disabled = true } end
        return items
    end)
end

TK.on("READY_CHECK", function() C_Timer.After(0.1, TK.safe(function() R.show(true) end)) end) -- after Blizzard's popup shows
TK.on("READY_CHECK_FINISHED", function() R.hide("finished") end) -- everyone answered or it timed out (also for whoever started it, who gets no popup)
TK.on("ENCOUNTER_START", function(enc) learnRoom(enc, "pull") end)
TK.on("ENCOUNTER_END", function(_, _, _, _, success) if success == 1 then manual = nil end end)
TK.on("ADDON_LOADED", function(name) if name == "TalentKeeper" then TK.db.rooms = TK.db.rooms or {} TK.db.readySeen = TK.db.readySeen or {} end end)
