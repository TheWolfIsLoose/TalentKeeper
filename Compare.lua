-- TalentKeeper compare: a build is its talent picks, not its string. Reads a string into
-- picks (node -> rank / choice), finds builds with the same picks, near matches, and
-- describes differences by talent name.
local _, TK = ...
local B = TK.builds
local C = {}
TK.compare = C

local NEAR = 6 -- builds this many talents apart or fewer count as near matches

-- Tree data for every class, so builds for specs and classes you aren't on read too.
local LTT = LibStub and LibStub("LibTalentTree-1.0", true)
local function libNode(node) return LTT and LTT:GetLibNodeInfo(node) end

-- picks[nodeID] = "rank:choice" (rank 0 = all ranks; choice 0 = not a choice node).
-- Free (granted) nodes are left out, so they never count as a difference.
local cache, grantedIn = {}, {}
function C.picks(text)
    text = strtrim(text or "")
    if cache[text] ~= nil then return cache[text] or nil end
    local spec = B.stringSpec(text)
    local treeID = spec and C_ClassTalents.GetTraitTreeForSpec(spec)
    if spec and not treeID and LTT then treeID = LTT:GetClassTreeID(select(6, GetSpecializationInfoByID(spec))) end
    local nodes = treeID and C_Traits.GetTreeNodes(treeID)
    if not nodes then return nil end -- the tree isn't loaded yet: don't remember the string as unreadable
    local picks
    if nodes then
        local M = B.mixin()
        local stream = ExportUtil.MakeImportDataStream(text)
        M:ReadLoadoutHeader(stream)
        local ok, records = pcall(M.ReadLoadoutContent, M, stream, treeID)
        if ok and records then
            picks, grantedIn[text] = {}, {}
            for i, r in ipairs(records) do
                if nodes[i] and r.isNodeGranted then grantedIn[text][nodes[i]] = true end
                if nodes[i] and r.isNodeSelected and not r.isNodeGranted then
                    picks[nodes[i]] = (r.isPartiallyRanked and r.partialRanksPurchased or 0) .. ":" .. (r.isChoiceNode and r.choiceNodeSelection or 0)
                end
            end
        end
    end
    cache[text] = picks or false
    return picks
end

-- Reading a string is the slow part of comparing builds, and a check right after login reads every
-- build at once (once took long enough for the game to stop it). So after login every build of
-- the class is read in the background, one per frame; checks wait while C.warming.
TK.on("PLAYER_LOGIN", function()
    local texts = { B.currentString() } -- nil this early is fine: the builds then start at [1]
    for i = 1, GetNumSpecializations() or 0 do
        for _, b in ipairs(TK.db.builds[GetSpecializationInfo(i)] or {}) do texts[#texts + 1] = b.text end
    end
    C.warming = true
    local i = 0
    local function step()
        i = i + 1
        if not texts[i] then C.warming = nil return end
        pcall(C.picks, texts[i])
        C_Timer.After(0, step)
    end
    step()
end)

-- Nodes free for this spec today, read from the game's own export of your current talents.
-- An older string may list a node as bought that a patch has since made free.
local function freeNow()
    local current = B.currentString()
    if current and C.picks(current) then return grantedIn[strtrim(current)] or {} end
    return {}
end

-- Nodes that differ: { { node, from, to }, ... }, from / to nil where a side doesn't take it.
function C.diff(textA, textB)
    local a, b = C.picks(textA), C.picks(textB)
    if not a or not b then return nil end
    local spec = B.stringSpec(textA)
    local free = (spec == B.specID()) and freeNow() or {}
    local function skip(node) return free[node] or (LTT and spec and LTT:IsNodeGrantedForSpec(spec, node)) end
    local out = {}
    for node, v in pairs(a) do if b[node] ~= v and not skip(node) then out[#out + 1] = { node = node, from = v, to = b[node] } end end
    for node, v in pairs(b) do if a[node] == nil and not skip(node) then out[#out + 1] = { node = node, to = v } end end
    -- spec tree first, then hero, then class tree
    local function group(node) local n = libNode(node) return not n and 0 or n.isClassNode and 2 or n.subTreeID and 1 or 0 end
    for _, c in ipairs(out) do c.group = group(c.node) end
    table.sort(out, function(x, y) if x.group ~= y.group then return x.group < y.group end return x.node < y.node end)
    return out
end

function C.same(list, text, except)
    for _, other in ipairs(list) do
        if other ~= except then
            local d = C.diff(other.text, text)
            if d and #d == 0 then return other end
        end
    end
end

-- Closest other build within NEAR talents: build, its differences.
function C.closest(list, b)
    local best, bestDiff
    for _, other in ipairs(list) do
        if other ~= b then
            local d = C.diff(other.text, b.text)
            if d and #d > 0 and #d <= NEAR and (not bestDiff or #d < #bestDiff) then best, bestDiff = other, d end
        end
    end
    return best, bestDiff
end

-- Talent names --------------------------------------------------------------------------
local function talentName(node, v)
    local choice = tonumber(v and v:match(":(%d+)$")) or 0
    local cfg = C_ClassTalents.GetActiveConfigID()
    local info = cfg and C_Traits.GetNodeInfo(cfg, node)
    if not (info and info.entryIDs and #info.entryIDs > 0) then info = libNode(node) end -- another class's tree
    local entryID = info and info.entryIDs and info.entryIDs[choice > 0 and choice or 1]
    local entry = entryID and (C_Traits.GetEntryInfo(cfg, entryID) or (LTT and LTT:GetEntryInfo(entryID)))
    if entry and entry.subTreeID then -- the hero tree choice: its options are hero trees, not spells
        local sub = C_Traits.GetSubTreeInfo(cfg, entry.subTreeID) or (LTT and LTT:GetSubTreeInfo(entry.subTreeID))
        if sub and sub.name then return sub.name end
    end
    local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
    local name = def and (def.overrideName or (def.spellID and C_Spell.GetSpellName(def.spellID)))
    return name or ("talent " .. node)
end

local function rank(v) local r = tonumber(v:match("^(%d+)")) return r == 0 and "max" or tostring(r) end

-- One line per change, from A's point of view to B's: "+ Name", "- Name", "Old -> New".
function C.describe(changes, max)
    local lines = {}
    for i, c in ipairs(changes) do
        if max and i > max then lines[#lines + 1] = ("and %d more"):format(#changes - max) break end
        local line
        if not c.from then line = "+ " .. talentName(c.node, c.to)
        elseif not c.to then line = "- " .. talentName(c.node, c.from)
        elseif c.from:match(":(%d+)$") ~= c.to:match(":(%d+)$") then
            line = talentName(c.node, c.from) .. " -> " .. talentName(c.node, c.to)
        else
            line = ("%s (rank %s -> %s)"):format(talentName(c.node, c.to), rank(c.from), rank(c.to))
        end
        if c.group == 2 then line = line .. " (class)" elseif c.group == 1 then line = line .. " (hero)" end
        lines[#lines + 1] = line
    end
    return lines
end

-- " Close to X: 2 talents apart (A -> B, + C)." or "" — appended to save / import messages.
function C.nearNote(list, b)
    local other, d = C.closest(list, b)
    if not other then return "" end
    return (" |cff8c8c8cClose to %s: %d talent%s apart (%s).|r"):format(other.name, #d, #d == 1 and "" or "s",
        table.concat(C.describe(d, 3), ", "))
end

-- The hero tree a build takes: its name and emblem atlas (nil if unknown). Remembered per string,
-- since the list asks for every row on each redraw.
local heroCache = {}
function C.hero(text)
    if not text then return nil end
    local hit = heroCache[text]
    if hit ~= nil then return hit or nil end
    local picks = LTT and C.picks(text)
    for node, v in pairs(picks or {}) do
        local n = libNode(node)
        if n and n.isSubTreeSelection then
            local choice = tonumber(v:match(":(%d+)$")) or 0
            local entry = n.entryIDs and LTT:GetEntryInfo(n.entryIDs[choice > 0 and choice or 1])
            hit = entry and entry.subTreeID and LTT:GetSubTreeInfo(entry.subTreeID)
            break
        end
    end
    heroCache[text] = hit and { name = hit.name, atlas = hit.iconElementID } or false
    return heroCache[text] or nil
end

function C.heroName(text) local h = C.hero(text) return h and h.name end
