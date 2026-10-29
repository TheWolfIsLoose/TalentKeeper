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
    local here = room(name)
    local enc = here and ((TK.db.rooms[instID] or {})[here] or (R.KNOWN[instID] or {})[here])
    for _, need in ipairs(enc and R.AFTER[enc] or {}) do
        if not killed(instID, diffID, "boss:" .. need) then enc = nil break end -- not up yet
    end
    if enc then
        for _, b in ipairs(bosses) do if b.key == "boss:" .. enc then return b, "room" end end
    end
    for _, b in ipairs(bosses) do
        if not killed(instID, diffID, b.key) then return b, "lockout" end
    end
    return bosses[1], "first"
end

-- Rooms that ship with TalentKeeper: [instanceID][subzone] = encounterID, learned in play
-- (English subzone names). Your own pulls and corrections fill in the rest and win over these.
R.KNOWN = {
    [3004] = { -- The Venomous Abyss
        ["The Soulcoil Well"] = 3470,        -- Nek'zali the Soulcoiler
        ["The Venomducts"] = 3445,           -- Entombed Sentinels
        ["Mor'zahi's Tomb"] = 3497,          -- The Lost Explorers
        ["Altar of the Six Winds"] = 3420,   -- Sszorak
        ["The Coiled Altar"] = 3429,         -- The Coiled Altar
        ["The Tomb of Ula'tek"] = 3492,      -- Ula'tek
        ["The Chamber of Virulence"] = 3455, -- Vashnik the Malignant
        ["Pit of Fangs"] = 3421,             -- The Twin Fangs (see R.AFTER)
    },
    [3095] = { -- The Unbinding of Kith'ix
        ["Kith'ix's Prison"] = 3513,         -- Kith'ix
    },
}

-- Bosses that only appear once others are down: their room means them only after that. The Pit
-- of Fangs is the hub of the Venomous Abyss's three wings, crossed all night before the Twin Fangs
-- show up (after Vashnik and Sszorak, and an interaction after each).
R.AFTER = { [3421] = { 3455, 3420 } }

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
local function placeStrip()
    strip:ClearAllPoints()
    local pos = TK.db.readyCheckPos
    if pos then
        strip:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    elseif ReadyCheckFrame and ReadyCheckFrame:IsShown() then
        strip:SetPoint("TOP", ReadyCheckFrame, "BOTTOM", 0, 1) -- flush: the edges overlap
    else
        strip:SetPoint("TOP", UIParent, "TOP", 0, -200)
    end
end

local function makeStrip()
    strip = UI.card("TalentKeeperReadyCheck")
    strip:SetMovable(true)
    strip:RegisterForDrag("LeftButton")
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
    strip.where:SetScript("OnEnter", function(self) if self.pick then strip.sub:SetTextColor(1, 1, 1) end end)
    strip.where:SetScript("OnLeave", function() strip.sub:SetTextColor(0.74, 0.74, 0.74) end)
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
-- On the build this spec has tagged here: say so. On another of this spec's builds: name the tagged
-- one, with Switch (every ready check: a wipe is when people forget). Nothing tagged for this spec:
-- ask once per play session to tag what you're on, with the other spec's tagged build beside it.
function R.show(check)
    local here = situation()
    if not here then return R.hide() end
    if here.content == "delve" then
        if TK.db.noDelvePrompt then return R.hide() end
        here = { key = "delve", name = "Delves", content = "delve" }
    end
    local mine, other, cur = P.plan(here)
    local spec = B.specID()
    local place = here.name .. (here.pick and " |cff8c8c8c(change)|r" or "")
    local card, what -- what: for the log
    if mine and P.onBuild(mine, spec) then -- a quiet confirmation
        card = { specID = spec, text = mine.text, title = mine.name, sub = place .. " · ready" }
        what = "on '" .. mine.name .. "'"
    elseif mine then
        card = { specID = spec, text = mine.text, title = mine.name, sub = place .. " · |cffffd84anot on it|r",
            one = { "Switch", function() P.switch(mine, spec) R.hide() end } }
        what = "tagged '" .. mine.name .. "'"
    else
        if check and P.asked(here) then return TK.log("readycheck: %s, already asked this session", here.name) end
        if check then P.markAsked(here) end
        local one, two = P.tagButtons(here, cur, other, R.refresh)
        local show = other and other.b or cur -- another spec's tagged build, or what you're on
        card = { specID = other and other.specID or spec, text = show and show.text or B.currentString(),
            title = other and ("%s: %s"):format(B.specName(other.specID), other.b.name) or (cur and ("Use %s here?"):format(cur.name) or "Nothing tagged"),
            sub = place .. " · nothing for " .. B.specName(spec), one = one, two = two }
        what = "nothing for this spec" .. (other and (", " .. B.specName(other.specID) .. " has '" .. other.b.name .. "'") or "")
    end
    if not strip then makeStrip() end
    -- flush under Blizzard's popup and as wide, so it reads as part of it
    card.minWidth = not TK.db.readyCheckPos and ReadyCheckFrame and ReadyCheckFrame:IsShown() and ReadyCheckFrame:GetWidth() or nil
    strip:Set(card)
    strip.where.pick = here.pick
    strip.where:SetScript("OnClick", here.pick and TK.safe(function(self) R.pickBoss(self) end) or nil)
    placeStrip()
    if mine and not P.onBuild(mine, spec) then strip.btn1.pulse() end -- on the wrong build: Switch pulses
    -- answering the ready check (or it timing out) closes Blizzard's popup: the strip goes with it
    if ReadyCheckFrame and not hooked then
        hooked = true
        ReadyCheckFrame:HookScript("OnHide", function() R.hide("answered") end)
    end
    TK.log("readycheck: %s%s, %s", here.name, here.how and (" (" .. here.how .. ")") or "", what)
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
TK.on("ADDON_LOADED", function(name) if name == "TalentKeeper" then TK.db.rooms = TK.db.rooms or {} end end)
