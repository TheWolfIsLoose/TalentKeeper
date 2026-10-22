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

local function currentString()
    return C_Traits.GenerateImportString(C_ClassTalents.GetActiveConfigID())
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
local UNSAVED = "|cffffb84dYour talent window has changes that aren't applied yet.|r Apply or undo them first."
local UNSPENT = "|cffffb84dYou have talent points left to spend.|r Spend them and apply first."
local function cantSave()
    if B.unsaved() then TK.chat(UNSAVED) return true end
    if B.unspent() then TK.chat(UNSPENT) return true end
end

function B.saveCurrent(name, group, tags)
    local specID = B.specID()
    if cantSave() then return end
    local text = currentString()
    if not text or text == "" then return TK.chat("|cffff8888Couldn't read your talents.|r Open the talent window once and try again.") end
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
    if not spec then return TK.chat("|cffff8888" .. err .. "|r") end
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

-- Move a build into a group (nil = no group).
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
    if B.findSpec(b) ~= specID then return TK.chat("|cffff8888That build is for another spec.|r") end
    local text = currentString()
    if not text then return TK.chat("|cffff8888Couldn't read your talents.|r") end
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
        TK.chat(("|cffffb84dApplied %s, but %d of its talents didn't come out as saved|r (%s). Re-save it once you've fixed them.")
            :format(b.name, #d, table.concat(TK.compare.describe(d, 3), ", ")))
    end
end

-- The game cancelled the change (it fires once per config; one is enough). Its staged changes stay
-- in the talent window and make a check read as if the build landed, so drop them first, then
-- check what you really have.
TK.on("CONFIG_COMMIT_FAILED", function(configID)
    local a = lastApply
    if not a or a.failed or not B.muteUntil or GetTime() > B.muteUntil then return end
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
        TK.chat(("|cffff8888%s wasn't applied:|r the game cancelled the talent change%s. Click it again to retry.")
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
    if unit == "player" and lastApply and lastApply.committed and not lastApply.timed then
        TK.log("apply '%s': your cast %s was interrupted", lastApply.b.name, tostring(spellID))
    end
end)

-- After the talents are in: PvP talents, and the check 5 s later.
local function finish(b, specID)
    if lastApply and lastApply.b == b then lastApply.committed = true end -- the next config update times the apply
    TK.changed()
    setPvp(b)
    C_Timer.After(5, TK.safe(function() verify(b) end))
end

-- Load the freshly imported loadout. A load error right after import is usually timing,
-- so the same loadout is loaded once more a second later before giving up.
local function load(id, p)
    local specID = B.specID()
    local r, changeError = C_ClassTalents.LoadConfig(id, true)
    TK.log("apply '%s': LoadConfig %s %s%s", p.b.name, resultName[r] or tostring(r), changeError or "", p.retried and " (retry)" or "")
    if r == Enum.LoadConfigResult.Error then
        if not p.retried then
            -- the game often loads it anyway; only load again if the talents didn't land
            p.retried = true
            return C_Timer.After(1.5, TK.safe(function()
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
        return TK.chat(("|cffff8888Couldn't apply %s.|r %s"):format(p.b.name, changeError or "Try again in a moment."))
    end
    C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, id)
    finish(p.b, specID)
end

-- In place: when TalentKeeper's loadout is the selected one, change only the talents that
-- differ on the live tree and commit once (no new loadout, no load). Matching talents are
-- left alone, so the hero tree is only touched when the build's hero talents differ.
local TYPE = Enum.TraitNodeType
local function isChoice(info) return info.type ~= TYPE.Single and info.type ~= TYPE.Tiered end

local function inPlace(b, e, specID, slot)
    local cfg = C_ClassTalents.GetActiveConfigID()
    local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
    if not cfg or not treeID then return false end
    -- what the build wants per node (a multi-rank apex talent can come as several entries)
    local want = {}
    for _, x in ipairs(e) do
        local w = want[x.nodeID]
        if w then w.ranks = w.ranks + x.ranksPurchased
        else want[x.nodeID] = { ranks = x.ranksPurchased, entry = x.selectionEntryID } end
    end
    -- the tree's visible nodes, top row first, left to right
    local ids = {}
    for _, id in ipairs(C_Traits.GetTreeNodes(treeID)) do
        local info = C_Traits.GetNodeInfo(cfg, id)
        if info and (info.isVisible or want[id]) then ids[#ids + 1] = { id = id, y = info.posY or 0, x = info.posX or 0 } end
    end
    table.sort(ids, function(a, c) if a.y ~= c.y then return a.y < c.y end return a.x < c.x end)
    local function granted(info) return (info.activeRank or 0) > (info.ranksPurchased or 0) end
    local function done(info)
        if info.type == TYPE.SubTreeSelection then -- the hero tree choice
            local w = want[info.ID]
            return not w or (info.activeEntry and info.activeEntry.entryID == w.entry) or false
        end
        if granted(info) then return true end -- free for this spec: nothing to buy or refund
        local w = want[info.ID]
        if not w or w.ranks == 0 then return info.ranksPurchased == 0 end
        if isChoice(info) then return info.activeEntry and info.activeEntry.entryID == w.entry or false end
        return info.ranksPurchased == w.ranks
    end
    -- a different hero tree: clear the hero talents; otherwise they're diffed like the rest
    local heroChanged = false
    for _, n in ipairs(ids) do
        local info = C_Traits.GetNodeInfo(cfg, n.id)
        if info.type == TYPE.SubTreeSelection and want[n.id] and not done(info) then heroChanged = true end
    end
    if heroChanged then
        for _, sub in ipairs(C_ClassTalents.GetHeroTalentSpecsForClassSpec() or {}) do
            local s = C_Traits.GetSubTreeInfo(cfg, sub)
            if s and s.traitCurrencyID then C_Traits.ResetTreeByCurrency(cfg, treeID, s.traitCurrencyID) end
        end
    end
    -- refund what the build doesn't have (bottom row first), then buy what's missing (top row
    -- first); repeat, since a refund can wait on a purchase (another path to a talent) and back
    local function refundPass()
        local progress = false
        for i = #ids, 1, -1 do
            local info = C_Traits.GetNodeInfo(cfg, ids[i].id)
            local w = want[info.ID]
            if info.ranksPurchased > 0 and not done(info) then
                if not w or w.ranks == 0 then
                    if isChoice(info) then progress = C_Traits.SetSelection(cfg, info.ID, nil) or progress
                    else progress = C_Traits.RefundAllRanks(cfg, info.ID) or progress end
                elseif not isChoice(info) and info.ranksPurchased > w.ranks then
                    for _ = w.ranks + 1, info.ranksPurchased do progress = C_Traits.RefundRank(cfg, info.ID) or progress end
                end
            end
        end
        return progress
    end
    local function buyPass()
        local progress = false
        for _, n in ipairs(ids) do
            local info = C_Traits.GetNodeInfo(cfg, n.id)
            local w = want[n.id]
            if w and w.ranks > 0 and not done(info) then
                if isChoice(info) then
                    progress = C_Traits.SetSelection(cfg, n.id, w.entry) or progress
                else
                    while info.ranksPurchased < w.ranks and C_Traits.PurchaseRank(cfg, n.id) do
                        progress = true
                        info = C_Traits.GetNodeInfo(cfg, n.id)
                    end
                end
            end
        end
        return progress
    end
    local function off()
        local list = {}
        for _, n in ipairs(ids) do
            local info = C_Traits.GetNodeInfo(cfg, n.id)
            if not done(info) then list[#list + 1] = info end
        end
        return list
    end
    local function settle()
        for _ = 1, 30 do
            local progress = refundPass()
            progress = buyPass() or progress
            if #off() == 0 or not progress then break end
        end
        return off()
    end
    local left, rebuilt = settle(), false
    if #left > 0 then
        -- the changes can't be made one by one: clear the class and spec talents and buy them
        -- all again top to bottom (the hero tree keeps its own points)
        rebuilt = true
        TK.log("apply '%s': %d talents wouldn't change one by one; rebuilding", b.name, #left)
        local cur = C_Traits.GetTreeCurrencyInfo(cfg, treeID, false) or {}
        for i = 1, 2 do if cur[i] then C_Traits.ResetTreeByCurrency(cfg, treeID, cur[i].traitCurrencyID) end end
        left = settle()
    end
    local missing = #left
    if missing > 0 then
        local what = {}
        for _, info in ipairs(left) do
            local w = want[info.ID]
            what[#what + 1] = ("%d has %d/%s want %s"):format(info.ID, info.ranksPurchased,
                info.activeEntry and tostring(info.activeEntry.entryID) or "-", w and (w.ranks .. "/" .. tostring(w.entry)) or "none")
        end
        TK.log("apply '%s': in place left %s", b.name, table.concat(what, "; "))
    end
    if missing > 0 then
        C_Traits.RollbackConfig(cfg)
        TK.log("apply '%s': in place couldn't take %d talents; importing instead", b.name, missing)
        return false
    end
    if not C_Traits.ConfigHasStagedChanges(cfg) then
        TK.log("apply '%s': already your talents", b.name)
        if lastApply then lastApply.timed = true end
        finish(b, specID)
        return true
    end
    local ok = C_ClassTalents.CommitConfig(slot)
    TK.log("apply '%s' (%s): in place%s, hero tree %s, commit %s", b.name, B.specName(specID), rebuilt and " (rebuilt)" or "", heroChanged and "changed" or "kept", tostring(ok))
    if not ok then C_Traits.RollbackConfig(cfg) return false end
    finish(b, specID)
    return true
end

B.inPlace = inPlace -- for the offline tests

function B.apply(b)
    if InCombatLockdown() then return TK.chat("|cffff8888Can't change talents in combat.|r") end
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
        return TK.chat("|cffff8888Can't change talents right now.|r " .. (changeError or ""))
    end
    local e, err = entries(b.text)
    if not e then return TK.chat("|cffff8888" .. err .. "|r") end
    local specID = B.specID()
    local prev = TK.db.active[specID]
    TK.db.active[specID] = b.name
    lastApply = { b = b, t0 = debugprofilestop(), prev = prev }
    B.muteUntil = GetTime() + 10
    local old = findSlot(specID)
    if old and C_ClassTalents.GetLastSelectedSavedConfigID(specID) == old then
        local ok, done = pcall(inPlace, b, e, specID, old)
        if ok and done then return end
        if not ok then
            TK.log("apply '%s': in place failed: %s", b.name, tostring(done))
            C_Traits.RollbackConfig(C_ClassTalents.GetActiveConfigID())
        end
    end
    if old then C_ClassTalents.DeleteConfig(old) end
    pending = { b = b, prev = prev }
    local ok, importErr = C_ClassTalents.ImportLoadout(C_ClassTalents.GetActiveConfigID(), e, SLOT, strtrim(b.text))
    TK.log("apply '%s' (%s): import %s %s", b.name, B.specName(specID), tostring(ok), importErr or "")
    if not ok then
        pending, B.muteUntil = nil, 0
        TK.db.active[specID] = prev
        TK.chat(("|cffff8888Couldn't apply %s.|r %s"):format(b.name, importErr or ""))
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

-- One-time import from another talent addon's saved builds ------------------------------
-- Its saved data: [classFile][specIndex] = rows; a row with a string is a build, a row
-- without one is a group heading, and builds flagged isInGroup sit under the last heading.
function B.importOther()
    local src = _G.TalentLoadoutEx
    if type(src) ~= "table" then return 0 end
    local classIDs = {}
    for i = 1, GetNumClasses() do
        local _, file, id = GetClassInfo(i)
        if file then classIDs[file] = id end
    end
    local added = 0
    for classFile, specs in pairs(src) do
        local classID = classIDs[classFile]
        if classID and type(specs) == "table" then
            for specIndex, rows in pairs(specs) do
                local specID = type(specIndex) == "number" and GetSpecializationInfoForClassID(classID, specIndex)
                if specID and type(rows) == "table" then
                    local heading
                    for _, row in ipairs(rows) do
                        if type(row) == "table" and type(row.text) == "string" and row.text ~= "" then
                            local pvp = (row.pvp1 or row.pvp2 or row.pvp3) and { row.pvp1, row.pvp2, row.pvp3 } or nil
                            if B.add(specID, { name = row.name, text = row.text, pvp = pvp, group = row.isInGroup and heading or nil }) then
                                added = added + 1
                            end
                        elseif type(row) == "table" and row.name then
                            heading = row.name
                        end
                    end
                end
            end
        end
    end
    TK.log("imported %d builds from Talent Loadout Ex", added)
    return added
end

TK.on("PLAYER_LOGIN", function()
    if TK.db.imported.other or type(_G.TalentLoadoutEx) ~= "table" then return end
    TK.db.imported.other = true
    local n = B.importOther()
    if n > 0 then TK.chat(("Brought over %d builds from Talent Loadout Ex."):format(n)) end
end)

TK.commands.save = function(name) B.saveCurrent(name) end
TK.commands.import = function() TK.ui.buildDialog(true) end
