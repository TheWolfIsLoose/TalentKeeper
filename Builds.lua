-- TalentKeeper builds: saved data, reading talent strings, save / apply / rename / delete,
-- and the one-time import of builds saved by another talent addon.
local _, TK = ...
local B = {}
TK.builds = B

local SLOT = "TalentKeeper"  -- the one Blizzard loadout per spec that TalentKeeper applies into

-- Saved data ----------------------------------------------------------------
function B.specID() return PlayerUtil.GetCurrentSpecID() end

function B.specName(specID)
    return select(2, GetSpecializationInfoByID(specID)) or ("spec " .. tostring(specID))
end

function B.list(specID)
    specID = specID or B.specID()
    TK.db.builds[specID] = TK.db.builds[specID] or {}
    return TK.db.builds[specID]
end

local function find(list, name)
    for i, b in ipairs(list) do if b.name == name then return b, i end end
end

-- Names are unique per spec: "Raid", "Raid (2)", ...
function B.uniqueName(list, name, except)
    name = strtrim(name or "")
    if name == "" then name = "Build" end
    local try, n = name, 1
    while true do
        local other = find(list, try)
        if not other or other == except then return try end
        n = n + 1
        try = ("%s (%d)"):format(name, n)
    end
end

-- Adds a build unless the same talents are already saved for that spec. The new build's
-- tags (b.tags) are set on whichever build ends up holding the talents, taking them off the
-- spec's other builds. Returns the build, or nil plus the existing build it matched.
function B.add(specID, b)
    b.text = strtrim(b.text)
    local list = B.list(specID)
    local tags = b.tags
    b.tags = nil
    local into
    for _, other in ipairs(list) do
        if strtrim(other.text) == b.text then into = other break end
    end
    into = into or TK.compare.same(list, b.text)  -- same talents, different string
    if not into then
        b.name = B.uniqueName(list, b.name)
        b.added = b.added or time()
        list[#list + 1] = b
    end
    for key, name in pairs(tags or {}) do B.setTag(into or b, key, name, true) end
    TK.flash(into or b)
    if into then return nil, into end
    return b
end

-- Reading talent strings ---------------------------------------------------------
-- Blizzard's own reader (ClassTalentImportExportMixin), called on the mixin itself.
local function mixin()
    C_AddOns.LoadAddOn("Blizzard_PlayerSpells")
    return ClassTalentImportExportMixin
end
B.mixin = mixin

-- Which spec a string is for, without needing to be on that spec.
function B.stringSpec(text)
    text = strtrim(text or "")
    if text == "" then return nil, "That box is empty." end
    local ok, ver, spec = mixin():ReadLoadoutHeader(ExportUtil.MakeImportDataStream(text))
    if not ok or not spec or spec == 0 then return nil, "That isn't a talent string." end
    if ver ~= C_Traits.GetLoadoutSerializationVersion() then
        return nil, "That string was made for a different version of the game."
    end
    return spec
end

-- The string's picks, ready for ImportLoadout. Only for the current spec.
local function entries(text)
    local M = mixin()
    local specID = B.specID()
    local spec, err = B.stringSpec(text)
    if not spec then return nil, err end
    if spec ~= specID then return nil, ("That build is for %s."):format(B.specName(spec)) end
    local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
    local stream = ExportUtil.MakeImportDataStream(strtrim(text))
    M:ReadLoadoutHeader(stream)
    return M:ConvertToImportLoadoutEntryInfo(C_ClassTalents.GetActiveConfigID(), treeID, M:ReadLoadoutContent(stream, treeID))
end

-- The game's export is slow and comparing calls it once per build: keep it for the frame
-- (GetTime() is fixed within a frame, so a change shows up on the next one).
local curText, curAt, curCfg
local function currentString()
    local cfg, now = C_ClassTalents.GetActiveConfigID(), GetTime()
    if curAt ~= now or curCfg ~= cfg then
        curText, curAt, curCfg = C_Traits.GenerateImportString(cfg), now, cfg
    end
    return curText
end
B.currentString = currentString

local function currentPvp()
    local ids = C_SpecializationInfo.GetAllSelectedPvpTalentIDs and C_SpecializationInfo.GetAllSelectedPvpTalentIDs()
    return ids and #ids > 0 and { ids[1], ids[2], ids[3] } or nil
end

-- Save, import, rename, delete ------------------------------------------------------
-- True while the talent window holds changes that aren't applied yet (saving then would
-- save talents you don't actually have).
function B.unsaved()
    local cfg = C_ClassTalents.GetActiveConfigID()
    return cfg and C_Traits.ConfigHasStagedChanges and C_Traits.ConfigHasStagedChanges(cfg) or false
end
-- Points left to spend (saving then would save a build short of points, which can't be applied).
-- Class, spec and the hero tree you have on: the other hero tree's points always sit unspent.
function B.unspent()
    local cfg = C_ClassTalents.GetActiveConfigID()
    local treeID = cfg and C_ClassTalents.GetTraitTreeForSpec(B.specID())
    local hero = C_ClassTalents.GetActiveHeroTalentSpec and C_ClassTalents.GetActiveHeroTalentSpec()
    local heroInfo = hero and C_Traits.GetSubTreeInfo(cfg, hero)
    local heroCurrency = heroInfo and heroInfo.traitCurrencyID
    for i, c in ipairs(treeID and C_Traits.GetTreeCurrencyInfo(cfg, treeID, false) or {}) do
        if (i <= 2 or c.traitCurrencyID == heroCurrency) and (c.quantity or 0) > 0 then
            TK.log("unspent: currency %s has %d", tostring(c.traitCurrencyID), c.quantity)
            return true
        end
    end
    return false
end
local UNSAVED = "|cffffd84aYour talent window has changes that aren't applied yet.|r Apply or undo them first."
local UNSPENT = "|cffffd84aYou have talent points left to spend.|r Spend them and apply first."
local function cantSave()
    if B.unsaved() then TK.chat(UNSAVED) return true end
    if B.unspent() then TK.chat(UNSPENT) return true end
end

function B.saveCurrent(name, group, tags)
    local specID = B.specID()
    if cantSave() then return end
    local text = currentString()
    if not text or text == "" then return TK.chat("|cffff6666Couldn't read your talents.|r Open the talent window once and try again.") end
    local list = B.list(specID)
    local b, same = B.add(specID, {
        name = name ~= "" and name or ("%s %d"):format(B.specName(specID), #list + 1),
        text = text, pvp = currentPvp(), group = group, tags = tags,
    })
    if not b then return B.same(same, tags) end
    TK.db.active[specID] = b.name
    TK.log("saved '%s' (%s)", b.name, B.specName(specID))
    TK.chat(("Saved |cffffffff%s|r.%s"):format(b.name, TK.compare.nearNote(list, b)))
    TK.selected = b
    TK.changed()
end

function B.importString(text, name, group, tags)
    local spec, err = B.stringSpec(text)
    if not spec then return TK.chat("|cffff6666" .. err .. "|r") end
    local list = B.list(spec)
    local b, same = B.add(spec, {
        name = name and name ~= "" and name or ("Imported %d"):format(#list + 1),
        text = strtrim(text), group = group, tags = tags,
    })
    if not b then return B.same(same, tags) end
    TK.log("imported '%s' (%s)", b.name, B.specName(spec))
    TK.chat(("Saved |cffffffff%s|r for %s.%s"):format(b.name, B.specName(spec), TK.compare.nearNote(list, b)))
    TK.selected = b
    TK.changed()
end

function B.rename(specID, b, name)
    local old = b.name
    b.name = B.uniqueName(B.list(specID), name, b)
    if TK.db.active[specID] == old then TK.db.active[specID] = b.name end
    TK.log("renamed '%s' to '%s'", old, b.name)
    TK.changed()
end

-- Move a build to just before (or after) another in the list, taking that build's group.
function B.move(specID, b, target, after)
    local list = B.list(specID)
    if b == target then return end
    for i, x in ipairs(list) do if x == b then table.remove(list, i) break end end
    local at = #list + 1
    for i, x in ipairs(list) do if x == target then at = after and i + 1 or i break end end
    table.insert(list, at, b)
    b.group = target.group
    TK.flash(b)
    TK.log("'%s' moved %s '%s'", b.name, after and "after" or "before", target.name)
    TK.changed()
end

-- Move a build into a group (nil = no group).
-- Gear set: the name of one of the game's equipment sets, put on whenever the build is applied
-- (nil: none). Stored by name, as the game's sets are; a renamed or deleted set is reported.
function B.setGear(b, name)
    b.gear = name
    TK.log("'%s' gear set: %s", b.name, name or "none")
    TK.changed()
end

-- The game's own gear set for a spec (Equipment Manager > assign to spec), or nil. When a
-- spec has one, the game swaps gear itself on spec change and TalentKeeper leaves gear alone.
function B.specGearSet(specID)
    if not (C_EquipmentSet and C_EquipmentSet.GetEquipmentSetForSpec) then return end
    for i = 1, GetNumSpecializations() do
        if GetSpecializationInfo(i) == specID then
            local id = C_EquipmentSet.GetEquipmentSetForSpec(i)
            return id and (C_EquipmentSet.GetEquipmentSetInfo(id)) or nil
        end
    end
end

-- Put on the build's gear set unless it's already worn. Out of combat only (applies are too).
local toldSpecSet = {} -- spec -> said once this session that its own gear set wins
function B.equipGear(b)
    if not b.gear or not C_EquipmentSet then return end
    local specID = B.findSpec(b) or B.specID()
    local own = B.specGearSet(specID)
    if own then
        TK.log("gear set '%s' for '%s': skipped, the spec has '%s' assigned in the Equipment Manager", b.gear, b.name, own)
        if not toldSpecSet[specID] then
            toldSpecSet[specID] = true
            TK.chat(("|cffffd84aGear set not changed:|r %s has %s assigned in the Equipment Manager, so TalentKeeper leaves its gear alone."):format(B.specName(specID), own))
        end
        return
    end
    local id = C_EquipmentSet.GetEquipmentSetID(b.gear)
    if not id then
        TK.log("gear set '%s' for '%s' not found", b.gear, b.name)
        return TK.chat(("|cffffd84aGear set %s not found|r (renamed or deleted?)."):format(b.gear))
    end
    local isEquipped = select(4, C_EquipmentSet.GetEquipmentSetInfo(id))
    if isEquipped then return TK.log("gear set '%s': already on", b.gear) end
    if InCombatLockdown() then return TK.log("gear set '%s': skipped, in combat", b.gear) end
    C_EquipmentSet.UseEquipmentSet(id)
    TK.log("gear set '%s' put on for '%s'", b.gear, b.name)
end

function B.setGroup(b, group)
    group = group and strtrim(group) or nil
    b.group = group ~= "" and group or nil
    TK.flash(b)
    TK.log("'%s' moved to %s", b.name, b.group or "no group")
    TK.changed()
end

function B.groups(specID)
    local out, seen = {}, {}
    for _, b in ipairs(B.list(specID)) do
        if b.group and not seen[b.group] then seen[b.group] = true out[#out + 1] = b.group end
    end
    return out
end

function B.renameGroup(specID, old, new)
    new = strtrim(new or "")
    if new == "" or new == old then return end
    for _, b in ipairs(B.list(specID)) do if b.group == old then b.group = new end end
    TK.log("group '%s' renamed to '%s'", old, new)
    TK.changed()
end

-- Delete a group and every build in it.
function B.deleteGroup(specID, group)
    local list, kept, n = B.list(specID), {}, 0
    for _, b in ipairs(list) do
        if b.group == group then
            n = n + 1
            if TK.db.active[specID] == b.name then TK.db.active[specID] = nil end
        else kept[#kept + 1] = b end
    end
    TK.db.builds[specID] = kept
    TK.log("deleted group '%s' (%d builds)", group, n)
    TK.chat(("Deleted %s and its %d build%s."):format(group, n, n == 1 and "" or "s"))
    TK.changed()
end

function B.findSpec(b)
    for specID, list in pairs(TK.db.builds) do
        for _, x in ipairs(list) do if x == b then return specID end end
    end
end

-- Builds as lines in display order: each group (first seen first) as { header = name } then
-- its builds, then { header = false } and the builds without a group.
function B.ordered(specID)
    local groups, order, loose = {}, {}, {}
    for _, b in ipairs(specID and B.list(specID) or {}) do
        local into = loose
        if b.group then
            if not groups[b.group] then groups[b.group] = {}; order[#order + 1] = b.group end
            into = groups[b.group]
        end
        into[#into + 1] = b
    end
    local lines = {}
    for _, g in ipairs(order) do
        lines[#lines + 1] = { header = g }
        for _, b in ipairs(groups[g]) do lines[#lines + 1] = { build = b } end
    end
    lines[#lines + 1] = { header = false }
    for _, b in ipairs(loose) do lines[#lines + 1] = { build = b } end
    return lines
end

-- Replace a build's talents with your current ones.
function B.updateToCurrent(b)
    local specID = B.specID()
    if cantSave() then return end
    if B.findSpec(b) ~= specID then return TK.chat("|cffff6666That build is for another spec.|r") end
    local text = currentString()
    if not text then return TK.chat("|cffff6666Couldn't read your talents.|r") end
    b.text, b.pvp, b.outdated = text, currentPvp(), nil
    TK.db.active[specID] = b.name
    TK.log("updated '%s' to current talents", b.name)
    TK.chat(("Updated |cffffffff%s|r to your current talents."):format(b.name))
    TK.changed()
end

-- Situations a build is for ----------------------------------------------------------
-- b.tags[key] = name. Keys: "delve" (delves and the open world), "zone:<instanceID>" (a
-- dungeon, raid or delve), "boss:<encounterID>". One build per spec per situation; one
-- situation can point at builds in several specs.
-- A situation points at one build per spec: tagging a build takes the tag off the spec's others.
function B.setTag(b, key, name, on)
    b.tags = b.tags or {}
    if on and b.tags[key] then if not next(b.tags) then b.tags = nil end return end -- already there
    if on then
        for _, x in ipairs(B.list(B.findSpec(b))) do
            if x ~= b and x.tags and x.tags[key] then
                x.tags[key] = nil
                if not next(x.tags) then x.tags = nil end
                TK.log("'%s' untagged %s (moved to '%s')", x.name, name, b.name)
                TK.chat(("%s moved from |cffffffff%s|r to |cffffffff%s|r."):format(name, x.name, b.name))
            end
        end
    end
    b.tags[key] = on and name or nil
    if on then TK.flash(b) end
    TK.log("'%s' %s %s", b.name, on and "tagged for" or "untagged", name)
    if not next(b.tags) then b.tags = nil end
    TK.changed()
end

function B.toggleTag(b, key, name) B.setTag(b, key, name, not (b.tags and b.tags[key])) end

function B.tagNames(b)
    local out = {}
    for _, name in pairs(b.tags or {}) do out[#out + 1] = name end
    table.sort(out)
    return out
end

-- Where you are, as a situation: the instance, or the open world; content = its content tag (delves).
local DELVE = 208
function B.here()
    local name, kind, difficulty, _, _, _, _, id = GetInstanceInfo()
    if not id or kind == "none" or kind == nil then return { key = "delve", name = "Delves" } end -- the open world shares the Delves build
    local content = difficulty == DELVE and "delve" or nil
    return { key = "zone:" .. id, name = name, content = content, difficulty = difficulty }
end

-- Builds of your class tagged for where you are: those tagged for this instance, or else those
-- tagged for its kind of content. { { b, specID }, ... }, your current spec's first.
function B.forHere(here)
    local classID = select(3, UnitClass("player"))
    local exact, content = {}, {}
    for i = 1, GetNumSpecializationsForClassID(classID) or 0 do
        local specID = GetSpecializationInfoForClassID(classID, i)
        for _, b in ipairs(specID and TK.db.builds[specID] or {}) do
            local t = b.tags or {}
            local into = t[here.key] and exact or (here.content and t[here.content] and content)
            if into then
                local mine = specID == B.specID()
                table.insert(into, mine and 1 or #into + 1, { b = b, specID = specID })
            end
        end
    end
    return #exact > 0 and exact or content
end

-- The saved build whose talents are the ones committed in the tree now (nil: not a saved build).
-- ponytail: diffs every build of the spec on each call; cache on the talent string if lists get long
function B.onNow(specID)
    local cur = currentString()
    if not cur or cur == "" then return end
    for _, b in ipairs(B.list(specID)) do
        local d = TK.compare.diff(cur, b.text)
        if d and #d == 0 then return b end
    end
end

-- Saving or importing talents you already have as a build: point at that build instead
-- (B.add already gave it the tags the new one was for).
function B.same(same, tags)
    local names = {}
    for _, name in pairs(tags or {}) do names[#names + 1] = name end
    table.sort(names)
    local tagged = #names > 0 and (" Tagged it for %s."):format(table.concat(names, ", ")) or ""
    TK.chat(("Same talents as |cffffffff%s|r, so nothing new to save.%s It's selected in the list."):format(same.name, tagged))
    TK.selected = same
    TK.changed()
end

function B.delete(specID, b)
    local list = B.list(specID)
    local _, i = find(list, b.name)
    if not i then return end
    table.remove(list, i)
    if TK.db.active[specID] == b.name then TK.db.active[specID] = nil end
    if TK.selected == b then TK.selected = nil end
    TK.log("deleted '%s' (%s)", b.name, B.specName(specID))
    TK.chat(("Deleted |cffffffff%s|r."):format(b.name))
    TK.changed()
end

-- Apply --------------------------------------------------------------------------
-- Import the build into TalentKeeper's own Blizzard loadout (replacing the last one),
-- load it, set PvP talents, then check the talents came out as saved.
local pending, waitID
local resultName = tInvert(Enum.LoadConfigResult)

local function findSlot(specID)
    for _, id in ipairs(C_ClassTalents.GetConfigIDsBySpecID(specID) or {}) do
        local info = C_Traits.GetConfigInfo(id)
        if info and info.name == SLOT then return id end
    end
end

local function setPvp(b)
    for i = 1, 3 do
        local want, slot = b.pvp and b.pvp[i], C_SpecializationInfo.GetPvpTalentSlotInfo(i)
        if want and slot and slot.enabled and slot.selectedTalentID ~= want then
            local ok, err = pcall(LearnPvpTalent, want, i)
            TK.debug("PvP slot %d -> %d: %s", i, want, ok and "sent" or tostring(err))
        end
    end
end

local lastApply -- { b, failed } for the build being applied, so a refused commit isn't reported as outdated

local function verify(b)
    -- skip when another build was applied since (it's checked instead)
    if not lastApply or lastApply.b ~= b then return end
    lastApply.timed = true -- the apply is over either way
    if lastApply.failed then return end -- the refusal handler checked it once the change was dropped
    local d = TK.compare.diff(b.text, currentString())
    if not d then return TK.log("check '%s': couldn't read talents", b.name) end
    local names = TK.compare.describe(d)
    TK.log("check '%s': %d differences%s", b.name, #d, #d > 0 and (": " .. table.concat(names, ", ")) or "")
    b.outdated = #d > 0 and #d or nil
    TK.changed()
    if #d > 0 then
        TK.chat(("|cffffd84aApplied %s, but %d of its talents didn't come out as saved|r (%s). Fix them, then More... > Update to my talents.")
            :format(b.name, #d, table.concat(TK.compare.describe(d, 3), ", ")))
    end
end

-- The game cancelled the change (it fires once per config; one is enough). Its staged changes stay
-- in the talent window and make a check read as if the build landed, so drop them first, then
-- check what you really have.
TK.on("CONFIG_COMMIT_FAILED", function(configID)
    local a = lastApply
    if not a or a.failed or not B.muteUntil or GetTime() > B.muteUntil then return end
    if not a.committed then -- a load that errored and is about to be retried
        return TK.log("apply '%s': the game cancelled a load (config %s); retrying", a.b.name, tostring(configID))
    end
    a.failed = true
    TK.log("apply '%s': the game cancelled the change (config %s)%s after %d ms", a.b.name, tostring(configID),
        a.why and (", " .. a.why) or "", debugprofilestop() - a.t0)
    C_Timer.After(0.2, TK.safe(function()
        if lastApply ~= a then return end
        if B.unsaved() then C_Traits.RollbackConfig(C_ClassTalents.GetActiveConfigID()) end
        local d = TK.compare.diff(a.b.text, currentString())
        a.timed, B.muteUntil = true, 0
        if d and #d == 0 then return TK.log("apply '%s': landed anyway", a.b.name) end
        TK.db.active[B.specID()] = a.prev
        TK.changed()
        TK.chat(("|cffff6666%s wasn't applied:|r the game cancelled the talent change%s. Click it again to retry.")
            :format(a.b.name, a.why and (" (" .. a.why .. ")") or ""))
    end))
end)

-- What can cancel a talent change while it goes through: moving, or combat starting.
local function during(why)
    local a = lastApply
    if a and a.committed and not a.timed and not a.why then
        a.why = why
        TK.log("apply '%s': %s %d ms after the click", a.b.name, why, debugprofilestop() - a.t0)
    end
end
TK.on("PLAYER_STARTED_MOVING", function() during("you moved") end)
TK.on("PLAYER_REGEN_DISABLED", function() during("combat started") end)
TK.on("UNIT_SPELLCAST_INTERRUPTED", function(unit, _, spellID)
    if unit == "player" and lastApply and lastApply.committed and not lastApply.timed and not lastApply.interrupted then
        lastApply.interrupted = true -- the game sends it several times
        TK.log("apply '%s': your cast %s was interrupted", lastApply.b.name, tostring(spellID))
    end
end)

-- After the talents are in: PvP talents, and the check 5 s later.
local function finish(b, specID)
    if lastApply and lastApply.b == b then lastApply.committed = true end -- the next config update times the apply
    TK.changed()
    setPvp(b)
    B.equipGear(b)
    C_Timer.After(5, TK.safe(function() verify(b) end))
end

-- Load the freshly imported loadout. A load error right after import is usually timing,
-- so the same loadout is loaded once more a second later before giving up.
local function load(id, p)
    local specID = B.specID()
    local r, changeError = C_ClassTalents.LoadConfig(id, true)
    TK.log("apply '%s': LoadConfig %s %s%s", p.b.name, resultName[r] or tostring(r), changeError or "", p.retried and " (retry)" or "")
    if r == Enum.LoadConfigResult.Error then
        p.tries = (p.tries or 0) + 1
        if p.tries < 2 then
            -- the game often loads it anyway; only load again if the talents didn't land
            p.retried = true
            return C_Timer.After(1.5, TK.safe(function() -- sooner can cut off a load the game did start
                local d = TK.compare.diff(p.b.text, currentString())
                if d and #d == 0 then
                    TK.log("apply '%s': landed despite the error", p.b.name)
                    C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, id)
                    return finish(p.b, specID)
                end
                load(id, p)
            end))
        end
        TK.db.active[specID], B.muteUntil = p.prev, 0
        return TK.chat(("|cffff6666Couldn't apply %s.|r %s"):format(p.b.name, changeError or "Try again in a moment."))
    end
    C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, id)
    finish(p.b, specID)
end


-- Apply b through the game's own load: TalentKeeper's loadout is replaced with the build, then
-- loaded. One thing every time: the Apply button, double-click, the quick list and the prompts.
function B.apply(b)
    if InCombatLockdown() then return TK.chat("|cffff6666Can't change talents in combat.|r") end
    -- a second apply mid-cast would cut the first one off
    if lastApply and not lastApply.timed and B.muteUntil and GetTime() < B.muteUntil then
        return TK.chat(("Still applying |cffffffff%s|r."):format(lastApply.b.name))
    end
    -- changes left staged in the talent window (e.g. a refused commit) block every apply; drop them
    if B.unsaved() then
        TK.log("apply '%s': dropping changes the talent window still held", b.name)
        C_Traits.RollbackConfig(C_ClassTalents.GetActiveConfigID())
    end
    local okCheck, canChange, _, changeError = pcall(C_ClassTalents.CanChangeTalents)
    if okCheck and canChange == false then
        TK.log("apply '%s': refused, can't change talents (%s)", b.name, tostring(changeError))
        return TK.chat("|cffff6666Can't change talents right now.|r " .. (changeError or ""))
    end
    local e, err = entries(b.text)
    if not e then return TK.chat("|cffff6666" .. err .. "|r") end
    local specID = B.specID()
    local d = TK.compare.diff(currentString(), b.text)
    if d and #d == 0 then
        TK.db.active[specID] = b.name
        TK.log("apply '%s': already your talents", b.name)
        B.equipGear(b) -- the gear may still differ
        return TK.changed()
    end
    local prev = TK.db.active[specID]
    TK.db.active[specID] = b.name
    lastApply = { b = b, t0 = debugprofilestop(), prev = prev }
    B.muteUntil = GetTime() + 10
    local old = findSlot(specID)
    if old then C_ClassTalents.DeleteConfig(old) end
    pending = { b = b, prev = prev }
    local ok, importErr = C_ClassTalents.ImportLoadout(C_ClassTalents.GetActiveConfigID(), e, SLOT, strtrim(b.text))
    TK.log("apply '%s' (%s): import %s %s", b.name, B.specName(specID), tostring(ok), importErr or "")
    if not ok then
        pending, B.muteUntil = nil, 0
        TK.db.active[specID] = prev
        TK.chat(("|cffff6666Couldn't apply %s.|r %s"):format(b.name, importErr or ""))
    end
end

-- How long an apply took, click to talents committed (logged for comparing methods).
TK.on("TRAIT_CONFIG_UPDATED", function(id)
    if lastApply and lastApply.committed and not lastApply.logged and id == C_ClassTalents.GetActiveConfigID() then
        lastApply.logged = true
        TK.log("apply '%s': talents in after %d ms", lastApply.b.name, debugprofilestop() - lastApply.t0)
    end
end)

-- Loading in the same frame the loadout appears fails more often than not; wait a moment.
local function loadPending(id)
    local p = pending
    pending, waitID = nil, nil
    C_Timer.After(0.3, TK.safe(function() load(id, p) end))
end

TK.on("TRAIT_CONFIG_CREATED", function(info)
    if not pending or info.name ~= SLOT then return end
    local populated = C_ClassTalents.IsConfigPopulated(info.ID)
    TK.debug("created loadout %d, populated %s", info.ID, tostring(populated))
    if populated then loadPending(info.ID) else waitID = info.ID end
end)

TK.on("TRAIT_CONFIG_UPDATED", function(id)
    if waitID and id == waitID then loadPending(id) end
end)
-- While a build applies, hide the game's "You have learned / unlearned ..." lines.
local function pattern(fmt) return "^" .. fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", ".+") .. "$" end
local spam = {}
for _, key in ipairs({ "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S", "ERR_LEARN_PASSIVE_S", "ERR_SPELL_UNLEARNED_S",
    "ERR_PET_LEARN_ABILITY_S", "ERR_PET_SPELL_UNLEARNED_S" }) do
    if type(_G[key]) == "string" then spam[#spam + 1] = pattern(_G[key]) end
end
local addFilter = ChatFrame_AddMessageEventFilter or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
if addFilter then
    addFilter("CHAT_MSG_SYSTEM", function(_, _, msg)
        if not B.muteUntil or GetTime() > B.muteUntil or type(msg) ~= "string" then return false end
        if issecretvalue and issecretvalue(msg) then return false end
        for _, p in ipairs(spam) do if msg:find(p) then return true end end
        return false
    end)
end

-- Bringing builds in from elsewhere -----------------------------------------------------------
-- Sources: Talent Loadout Ex (import strings), Talent Loadout Manager (talent lists: the string is
-- written here, in the game's own format), and this character's own game loadouts. Each gives
-- { specID, name, text, group }. Rules (player, 2026-10-22): same talents as a build you have:
-- skipped (yours stays); same name, other talents: "<name> (TLE)"; each source lands in its own
-- group unless it had headings of its own; game loadouts are copied, never deleted.
local LTT = LibStub and LibStub("LibTalentTree-1.0", true)
local HEADER_VERSION, HEADER_SPEC = 8, 16

local function classIDs()
    local out = {}
    for i = 1, GetNumClasses() do
        local _, file, id = GetClassInfo(i)
        if file then out[file] = id end
    end
    return out
end

local function fromTLE()
    local src, out = _G.TalentLoadoutEx, {}
    if type(src) ~= "table" then return out end
    local ids = classIDs()
    for classFile, specs in pairs(src) do
        local classID = ids[classFile]
        if classID and type(specs) == "table" then
            for specIndex, rows in pairs(specs) do
                local specID = type(specIndex) == "number" and GetSpecializationInfoForClassID(classID, specIndex)
                if specID and type(rows) == "table" then
                    local heading
                    for _, row in ipairs(rows) do
                        if type(row) == "table" and type(row.text) == "string" and row.text ~= "" then
                            local pvp = (row.pvp1 or row.pvp2 or row.pvp3) and { row.pvp1, row.pvp2, row.pvp3 } or nil
                            out[#out + 1] = { specID = specID, name = row.name, text = row.text, pvp = pvp,
                                group = row.isInGroup and heading or "From TLE" }
                        elseif type(row) == "table" and row.name then
                            heading = row.name
                        end
                    end
                end
            end
        end
    end
    return out
end

-- A talent list ("nodeID_entryID_spellID_rank" lines) as an import string for specID, written
-- the way the game writes its own (header with a zero tree hash, which the game accepts, then
-- every node of the class tree in the game's order). nil when the tree data isn't there.
function B.listToString(classID, specID, list)
    local treeID = LTT and LTT:GetClassTreeID(classID)
    local nodes = treeID and C_Traits.GetTreeNodes(treeID)
    if not nodes or #nodes == 0 then return nil end
    local picked = {}
    for line in tostring(list):gmatch("[^\n]+") do
        local node, entry, _, rank = line:match("^(%d+)_(%d+)_(%d+)_(%d+)$")
        if node then picked[tonumber(node)] = { entry = tonumber(entry), rank = tonumber(rank) } end
    end
    local out = ExportUtil.MakeExportDataStream()
    out:AddValue(HEADER_VERSION, C_Traits.GetLoadoutSerializationVersion())
    out:AddValue(HEADER_SPEC, specID)
    for _ = 1, 16 do out:AddValue(8, 0) end -- tree hash left blank
    for _, nodeID in ipairs(nodes) do
        local info, p = LTT:GetLibNodeInfo(nodeID), picked[nodeID]
        local granted = info and LTT:IsNodeGrantedForSpec(specID, nodeID)
        if granted then
            out:AddValue(1, 1); out:AddValue(1, 0) -- selected, not purchased (given free)
        elseif p and info and p.rank > 0 then
            out:AddValue(1, 1); out:AddValue(1, 1)
            local partial = info.maxRanks and p.rank ~= info.maxRanks
            out:AddValue(1, partial and 1 or 0)
            if partial then out:AddValue(6, p.rank) end
            local choice = info.type == Enum.TraitNodeType.Selection or info.type == Enum.TraitNodeType.SubTreeSelection
            out:AddValue(1, choice and 1 or 0)
            if choice then
                local index = 1
                for k, e in ipairs(info.entryIDs or {}) do if e == p.entry then index = k end end
                out:AddValue(2, index - 1)
            end
        else
            out:AddValue(1, 0)
        end
    end
    return out:GetExportString()
end

local function fromTLM()
    local db, out = _G.TalentLoadoutManagerDB, {}
    if type(db) ~= "table" or type(db.customLoadouts) ~= "table" then return out end
    local blizz = type(db.blizzardLoadouts) == "table" and db.blizzardLoadouts or {}
    for classID, specs in pairs(db.customLoadouts) do
        if type(classID) == "number" and type(specs) == "table" then
            for specID, loadouts in pairs(specs) do
                if type(specID) == "number" and type(loadouts) == "table" then
                    for _, l in pairs(loadouts) do
                        if type(l) == "table" and type(l.selectedNodes) == "string" and l.selectedNodes ~= "" then
                            local ok, text = pcall(B.listToString, classID, specID, l.selectedNodes)
                            if ok and text then
                                -- linked to a game loadout: group under that loadout's name (base + variants)
                                local group = "From TLM"
                                for _, configID in pairs(type(l.parentMapping) == "table" and l.parentMapping or {}) do
                                    for _, byChar in pairs(type(blizz[classID]) == "table" and type(blizz[classID][specID]) == "table" and blizz[classID][specID] or {}) do
                                        local parent = type(byChar) == "table" and byChar[configID]
                                        if type(parent) == "table" and parent.name then group = parent.name end
                                    end
                                end
                                out[#out + 1] = { specID = specID, name = l.name, text = text, group = group }
                            end
                        end
                    end
                end
            end
        end
    end
    return out
end

-- The game exports every loadout with your current spec in the string; another spec's needs its
-- spec patched (header: version 8 bits, spec 16, then the rest copied through).
local function withSpec(text, specID)
    local inS, outS = ExportUtil.MakeImportDataStream(text), ExportUtil.MakeExportDataStream()
    outS:AddValue(HEADER_VERSION, inS:ExtractValue(HEADER_VERSION))
    inS:ExtractValue(HEADER_SPEC)
    outS:AddValue(HEADER_SPEC, specID)
    local left = inS:GetNumberOfBits() - HEADER_VERSION - HEADER_SPEC
    while left > 0 do
        local n = math.min(left, 6)
        outS:AddValue(n, inS:ExtractValue(n))
        left = left - n
    end
    return outS:GetExportString()
end

local function fromGame()
    local out = {}
    for i = 1, GetNumSpecializations() or 0 do
        local specID = GetSpecializationInfo(i)
        for _, configID in ipairs(specID and C_ClassTalents.GetConfigIDsBySpecID(specID) or {}) do
            local info = C_Traits.GetConfigInfo(configID)
            if info and info.name ~= SLOT then
                local ok, text = pcall(C_Traits.GenerateImportString, configID)
                if ok and text and text ~= "" then
                    ok, text = pcall(withSpec, text, specID)
                    if ok then out[#out + 1] = { specID = specID, name = info.name, text = text, group = "Blizzard loadouts" } end
                end
            end
        end
    end
    return out
end

-- { { key, name, tag, builds = { ... } }, ... } for the sources that have anything.
function B.sources()
    local out = {}
    for _, s in ipairs({
        { key = "tle", name = "Talent Loadout Ex", tag = "TLE", get = fromTLE,
          about = "Every build saved in Talent Loadout Ex, all classes. Its headings become groups." },
        { key = "tlm", name = "Talent Loadout Manager", tag = "TLM", get = fromTLM,
          about = "Every build saved in Talent Loadout Manager, all classes, in a From TLM group." },
        { key = "game", name = "Game loadouts", tag = "game", get = fromGame,
          about = "This character's saved loadouts in the game, every spec, copied into a Blizzard loadouts group. The loadouts stay as they are." },
    }) do
        local ok, builds = pcall(s.get)
        if ok and #builds > 0 then s.builds = builds out[#out + 1] = s
        elseif not ok then TK.log("bring in: %s couldn't be read: %s", s.name, tostring(builds)) end
    end
    return out
end

-- Bring the chosen sources in. Returns added, skipped (already here).
function B.bringIn(sources)
    local added, skipped = 0, 0
    for _, s in ipairs(sources) do
        for _, c in ipairs(s.builds) do
            local list = B.list(c.specID)
            local name = c.name and c.name ~= "" and c.name or "Build"
            for _, x in ipairs(list) do
                if x.name == name then name = ("%s (%s)"):format(name, s.tag) break end
            end
            if B.add(c.specID, { name = name, text = c.text, pvp = c.pvp, group = c.group }) then
                added = added + 1
            else
                skipped = skipped + 1
            end
        end
        TK.log("bring in: %s, %d builds", s.name, #s.builds)
    end
    TK.db.imported.offered = true
    TK.log("bring in: %d added, %d already here", added, skipped)
    TK.changed()
    return added, skipped
end

-- SimulationCraft: TalentKeeper's builds for your spec go into the /simc text the way the game's
-- own saved loadouts do ("# Saved Loadout: <name>" then "# talents=<string>"), after them. The
-- profile ends in a checksum of everything above it, so it's worked out again (adler32, as the
-- SimulationCraft addon does) or sim sites would see an edited profile.
local function adler32(str)
    local a, b = 1, 0
    for i = 1, #str do
        a = (a + str:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end

-- One TalentKeeper block after all of SimulationCraft's talent lines: this spec's builds as saved
-- loadouts, then (only when SimulationCraft's own Offspec Talent Loadouts box is ticked) the other
-- specs' builds as offspec loadouts, each spec under its own "### TalentKeeper: <spec>" heading.
function B.simcLines(offspec)
    local lines, cur = {}, B.specID()
    local function block(specID, specName, other)
        local list = TK.db.builds[specID] or {}
        if #list == 0 then return end
        lines[#lines + 1] = ""
        lines[#lines + 1] = "### TalentKeeper: " .. specName .. (other and " (offspec)" or "")
        for _, b in ipairs(list) do
            lines[#lines + 1] = (other and "# Offspec Loadout: " or "# Saved Loadout: ") .. b.name
            lines[#lines + 1] = (other and "# offspec_talents=" or "# talents=") .. strtrim(b.text)
        end
    end
    local specs = {}
    for i = 1, GetNumSpecializations() or 0 do
        local specID, specName = GetSpecializationInfo(i)
        if specID == cur then table.insert(specs, 1, { specID, specName }) elseif specID and offspec then specs[#specs + 1] = { specID, specName, true } end
    end
    for _, sp in ipairs(specs) do block(sp[1], sp[2], sp[3]) end
    return lines
end

local simcAddon
function B.addToSimc(profile)
    if type(profile) ~= "string" or TK.db.noSimc then return profile end
    local body = profile:gsub("# Checksum: %x+%s*$", "")
    if body == profile then return profile end -- not the shape we know: leave it alone
    -- the game's "TalentKeeper" loadout is only the slot builds are applied through: drop it, and
    -- any offspec heading it leaves empty
    body = body:gsub("\n# Saved Loadout: " .. SLOT .. "\n# talents=[^\n]*", "")
    body = body:gsub("\n# Offspec Loadout: " .. SLOT .. "\n# offspec_talents=[^\n]*", "")
    local n
    repeat body, n = body:gsub("\n### Offspec Loadouts: [^\n]*\n\n", "\n") until n == 0
    body = body:gsub("\n\n\n+", "\n\n") -- no double blank line where they were
    -- after the last of SimulationCraft's talent lines (yours, saved loadouts, offspec loadouts)
    local insertAt
    for _, pat in ipairs({ "\ntalents=[^\n]*", "\n# talents=[^\n]*", "\n# offspec_talents=[^\n]*" }) do
        local pos = 1
        while true do
            local s, e = body:find(pat, pos)
            if not s then break end
            if not insertAt or e > insertAt then insertAt = e end
            pos = e + 1
        end
    end
    if not insertAt then return profile end
    local db = simcAddon and simcAddon.db
    local lines = B.simcLines(db and db.profile and db.profile.offspecLoadouts)
    if #lines > 0 then body = body:sub(1, insertAt) .. "\n" .. table.concat(lines, "\n") .. body:sub(insertAt + 1) end
    return body .. ("# Checksum: %x"):format(adler32((body:gsub("||", "|"))))
end

local function hookSimc()
    -- the addon keeps itself in a local; it's registered with AceAddon by name
    local ace = LibStub and LibStub("AceAddon-3.0", true)
    local simc = _G.Simulationcraft or (ace and ace:GetAddon("Simulationcraft", true))
    if not simc or simc.TalentKeeperHooked or type(simc.GetSimcProfile) ~= "function" then return end
    simc.TalentKeeperHooked, simcAddon = true, simc
    local original = simc.GetSimcProfile
    simc.GetSimcProfile = function(...)
        local profile, err = original(...)
        local ok, withOurs = pcall(B.addToSimc, profile)
        return ok and withOurs or profile, err
    end
    TK.log("SimulationCraft: TalentKeeper builds go into /simc")
end
TK.on("PLAYER_LOGIN", hookSimc)
TK.on("ADDON_LOADED", function(name) if name == "Simulationcraft" and TK.db then hookSimc() end end)

TK.commands.save = function(name) B.saveCurrent(name) end
TK.commands.import = function() TK.ui.buildDialog(true) end
