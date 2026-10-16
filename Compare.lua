-- TalentKeeper compare: a build is its talent picks, not its string. Reads a string into
-- picks (node -> rank / choice), finds builds with the same picks, near matches, and
-- describes differences by talent name.
local _, TK = ...
local B = TK.builds
local C = {}
TK.compare = C

local NEAR = 6 -- builds this many talents apart or fewer count as near matches

-- picks[nodeID] = "rank:choice" (rank 0 = all ranks; choice 0 = not a choice node).
-- Free (granted) nodes are left out, so they never count as a difference.
local cache = {}
function C.picks(text)
    text = strtrim(text or "")
    if cache[text] ~= nil then return cache[text] or nil end
    local spec = B.stringSpec(text)
    local treeID = spec and C_ClassTalents.GetTraitTreeForSpec(spec)
    local nodes = treeID and C_Traits.GetTreeNodes(treeID)
    local picks
    if nodes then
        local M = B.mixin()
        local stream = ExportUtil.MakeImportDataStream(text)
        M:ReadLoadoutHeader(stream)
        local ok, records = pcall(M.ReadLoadoutContent, M, stream, treeID)
        if ok and records then
            picks = {}
            for i, r in ipairs(records) do
                if nodes[i] and r.isNodeSelected and not r.isNodeGranted then
                    picks[nodes[i]] = (r.isPartiallyRanked and r.partialRanksPurchased or 0) .. ":" .. (r.isChoiceNode and r.choiceNodeSelection or 0)
                end
            end
        end
    end
    cache[text] = picks or false
    return picks
end

-- Nodes that differ: { { node, from, to }, ... }, from / to nil where a side doesn't take it.
function C.diff(textA, textB)
    local a, b = C.picks(textA), C.picks(textB)
    if not a or not b then return nil end
    local out = {}
    for node, v in pairs(a) do if b[node] ~= v then out[#out + 1] = { node = node, from = v, to = b[node] } end end
    for node, v in pairs(b) do if a[node] == nil then out[#out + 1] = { node = node, to = v } end end
    table.sort(out, function(x, y) return x.node < y.node end)
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
    local entryID = info and info.entryIDs and info.entryIDs[choice > 0 and choice or 1]
    local entry = entryID and C_Traits.GetEntryInfo(cfg, entryID)
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
        if not c.from then lines[#lines + 1] = "+ " .. talentName(c.node, c.to)
        elseif not c.to then lines[#lines + 1] = "- " .. talentName(c.node, c.from)
        elseif c.from:match(":(%d+)$") ~= c.to:match(":(%d+)$") then
            lines[#lines + 1] = talentName(c.node, c.from) .. " -> " .. talentName(c.node, c.to)
        else
            lines[#lines + 1] = ("%s (rank %s -> %s)"):format(talentName(c.node, c.to), rank(c.from), rank(c.to))
        end
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

-- An earlier build in the list with the same talents, for the "same as X" mark.
function C.sameAsEarlier(list, b)
    for _, other in ipairs(list) do
        if other == b then return nil end
        local d = C.diff(other.text, b.text)
        if d and #d == 0 then return other end
    end
end
