-- TalentKeeper tidy up: turn a spec's builds, however they were named, into a few core builds.
-- Reads each build's talents, hero tree and name (plus its group and tags), groups the builds
-- by hero tree and then by how close their talents are, keeps the build closest to the rest
-- of its group as the core, merges copies into it, keeps the rest as its swaps, and reads the
-- names for what each build is for (raid / M+ / delves, AoE / single target, dungeon and boss
-- names, abbreviations). Every core is a real saved build, so none can break the tree's rules.
-- The plan is shown in full before anything changes; applying keeps an undo.
local _, TK = ...
local B, C, UI = TK.builds, TK.compare, TK.ui
local T = {}
TK.tidy = T

T.GAP = 10  -- talents (nodes) from a core build and still one of its swaps
T.MERGE = 1 -- a build this close to its core with no place of its own merges into it

-- Reading names -------------------------------------------------------------------------------
local function norm(s) return ((s or ""):lower():gsub("[\226\128\153'`]", ""):gsub("[^%w%+]+", " ")) end
local function tokens(s)
    local out = {}
    for w in norm(s):gmatch("%S+") do out[#out + 1] = w end
    return out
end
T.tokens = tokens

local KEYWORDS = {
    mplus = { "m+", "m", "mplus", "mythic+", "mythicplus", "keys", "key", "dungeon", "dungeons", "push", "mm+" },
    raid = { "raid", "raiding", "hc", "heroic", "prog", "progression", "mythicraid" },
    delve = { "delve", "delves", "delving", "bountiful" },
    pvp = { "pvp", "arena", "arenas", "bg", "bgs", "rbg", "shuffle", "blitz" },
    world = { "open", "world", "ow", "farm", "farming", "solo", "questing", "leveling", "levelling" },
    aoe = { "aoe", "cleave", "multi", "multitarget", "funnel", "mt" },
    st = { "st", "single", "singletarget" },
    base = { "baseline", "base", "main", "core", "default", "standard", "general", "allround", "allrounder" },
    hybrid = { "hybrid", "mixed", "flex" },
}
local WORD = {}
for kind, list in pairs(KEYWORDS) do for _, w in ipairs(list) do WORD[w] = kind end end
local CONTENT_KEY = { mplus = "mplus", raid = "raid", delve = "delve" }
local CONTENT_NAME = { mplus = "M+", raid = "Raid", delve = "Delves", pvp = "PvP", world = "Open world" }
local TARGET_NAME = { aoe = "AoE", st = "ST", hybrid = "Hybrid" }
local STOP = { the = true, of = true, ["and"] = true, a = true, an = true }

-- Aliases for a place: its whole name, initials (with and without small words), each long word,
-- and the name with its punctuation squeezed out ("Kith'ix" -> "kithix").
local function aliases(place)
    local ws = tokens(place.name)
    local out = {}
    local full, squeezed = table.concat(ws, " "), table.concat(ws, "")
    out[full], out[squeezed] = 3, 3
    local i1, i2 = "", ""
    for _, w in ipairs(ws) do
        i2 = i2 .. w:sub(1, 1)
        if not STOP[w] then i1 = i1 .. w:sub(1, 1) end
    end
    if #ws > 1 then
        if #i1 >= 2 then out[i1] = out[i1] or 3 end
        if #i2 >= 2 then out[i2] = out[i2] or 3 end
    end
    for _, w in ipairs(ws) do if #w >= 5 and not STOP[w] then out[w] = out[w] or 2 end end
    return out, ws
end

-- What a name says: content / target / base counts, places it names (with how sure), season marks.
function T.read(name, places)
    local ws = tokens(name)
    local said = { kinds = {}, places = {}, season = nil, generic = false }
    local joined = table.concat(ws, " ")
    for _, w in ipairs(ws) do
        local k = WORD[w]
        if k then said.kinds[k] = (said.kinds[k] or 0) + 1 end
        if w:match("^s%d+$") or w == "season" then said.season = w end
    end
    if joined:match("^imported %d+$") or joined:match("^build %d+$") or joined:match("^%a+ %d+$") and not said.kinds.mplus then
        said.generic = true
    end
    for _, p in ipairs(places or {}) do
        local al, pws = p.aliases, p.words
        local best = 0
        if al[joined] then best = al[joined] end
        local hits, loose = {}, 0
        for i, w in ipairs(ws) do
            local score = al[w] or 0
            -- the start of one of the place's long words ("nym" for a longer name)
            if score == 0 and #w >= 3 and not WORD[w] then
                for _, pw in ipairs(pws) do if #pw >= 5 and pw:sub(1, #w) == w then score = 2 end end
            end
            hits[i] = score
            if score == 0 and not WORD[w] and not w:match("^s?%d+$") and not STOP[w] then loose = loose + 1 end
        end
        for i, w in ipairs(ws) do
            local score = hits[i]
            -- one word of a longer name ("fangs") only counts when nothing else in the build's name is
            -- unexplained: "Altar" is Altar of Fangs, "Twin Fangs" isn't
            if score == 2 and loose > 0 then score = 1 end
            if score > best then best = score end
        end
        -- a whole multi-word name inside the build's name
        if best < 3 and #pws > 1 and (" " .. joined .. " "):find(" " .. table.concat(pws, " ") .. " ", 1, true) then best = 3 end
        if best > 0 then said.places[#said.places + 1] = { place = p, score = best } end
    end
    table.sort(said.places, function(a, b) return a.score > b.score end)
    return said
end

function T.places(raw)
    local out = {}
    for _, p in ipairs(raw) do
        local al, ws = aliases(p)
        out[#out + 1] = { key = p.key, name = p.name, kind = p.kind, aliases = al, words = ws }
    end
    return out
end

-- Distance between two builds' picks.
local function dist(a, b)
    local n = 0
    for node, v in pairs(a) do if b[node] ~= v then n = n + 1 end end
    for node in pairs(b) do if a[node] == nil then n = n + 1 end end
    return n
end
T.dist = dist

-- The plan ------------------------------------------------------------------------------------
-- input: { { id, name, group, tags, hero, picks }, ... }; places: from T.places.
-- Returns { cores = { { core = id, name, group, content, target, tags = { key = name },
-- members = { { id, action = "core" | "merge" | "swap", d, tags, why } }, why } }, notes, counts }.
function T.plan(input, places)
    local notes = {}
    local byId, reads = {}, {}
    for _, x in ipairs(input) do
        byId[x.id] = x
        reads[x.id] = T.read((x.name or "") .. " " .. (x.group or ""), places)
    end
    -- hero tree first: builds on different hero trees are never one family
    local heroes, order = {}, {}
    for _, x in ipairs(input) do
        local h = x.hero or "?"
        if not heroes[h] then heroes[h] = {}; order[#order + 1] = h end
        table.insert(heroes[h], x)
    end
    local function prefer(a, b) -- tie-break: says baseline, has tags, not generic, earlier
        local ra, rb = reads[a.id], reads[b.id]
        local ka, kb = (ra.kinds.base or 0), (rb.kinds.base or 0)
        if ka ~= kb then return ka > kb end
        local ta, tb = next(a.tags or {}) and 1 or 0, next(b.tags or {}) and 1 or 0
        if ta ~= tb then return ta > tb end
        if ra.generic ~= rb.generic then return rb.generic end
        return a.id < b.id
    end
    local clusters = {}
    for _, h in ipairs(order) do
        local left = {}
        for _, x in ipairs(heroes[h]) do left[#left + 1] = x end
        while #left > 0 do
            -- the build with the most others within GAP starts a family
            local best, bestN, bestSum
            for _, x in ipairs(left) do
                local n, sum = 0, 0
                for _, y in ipairs(left) do
                    local d = dist(x.picks, y.picks)
                    if d <= T.GAP then n, sum = n + 1, sum + d end
                end
                if not best or n > bestN or (n == bestN and (sum < bestSum or (sum == bestSum and prefer(x, best)))) then
                    best, bestN, bestSum = x, n, sum
                end
            end
            local fam, rest = {}, {}
            for _, y in ipairs(left) do
                if dist(best.picks, y.picks) <= T.GAP then fam[#fam + 1] = y else rest[#rest + 1] = y end
            end
            -- the core: closest to the rest of its family
            local core, coreSum
            for _, x in ipairs(fam) do
                local sum = 0
                for _, y in ipairs(fam) do sum = sum + dist(x.picks, y.picks) end
                if not core or sum < coreSum or (sum == coreSum and prefer(x, core)) then core, coreSum = x, sum end
            end
            clusters[#clusters + 1] = { hero = h, core = core, fam = fam }
            left = rest
        end
    end
    -- what each build is for: its own tags, then places its name names
    local claims = {} -- key -> { { id, score, name } }
    local function claim(id, key, name, score)
        claims[key] = claims[key] or {}
        table.insert(claims[key], { id = id, score = score, name = name })
    end
    for _, x in ipairs(input) do
        for key, name in pairs(x.tags or {}) do claim(x.id, key, name, 10) end
        for _, m in ipairs(reads[x.id].places) do
            if m.score >= 2 then claim(x.id, m.place.key, m.place.name, m.score) end
        end
    end
    local plan = { cores = {}, notes = notes, counts = { builds = #input, cores = 0, swaps = 0, merges = 0 } }
    for _, cl in ipairs(clusters) do
        local entry = { core = cl.core.id, hero = cl.hero, members = {}, tags = {}, why = {} }
        -- votes from every name in the family (the core's count triple)
        -- (AoE / single target only from the core and its copies: swaps are where those differ)
        local votes = {}
        for _, x in ipairs(cl.fam) do
            local w = x == cl.core and 3 or 1
            local copy = x == cl.core or dist(cl.core.picks, x.picks) <= T.MERGE
            for k, n in pairs(reads[x.id].kinds) do
                if copy or not TARGET_NAME[k] then votes[k] = (votes[k] or 0) + n * w end
            end
            for key in pairs(x.tags or {}) do
                if CONTENT_KEY[key] then votes[key] = (votes[key] or 0) + 3 * w end
            end
        end
        local content, target
        for _, k in ipairs({ "mplus", "raid", "delve", "pvp", "world" }) do
            if (votes[k] or 0) > 0 and (not content or votes[k] > votes[content]) then content = k end
        end
        for _, k in ipairs({ "aoe", "st", "hybrid" }) do
            if (votes[k] or 0) > 0 and (not target or votes[k] > votes[target]) then target = k end
        end
        entry.content, entry.target = content, target
        for _, x in ipairs(cl.fam) do
            local d = dist(cl.core.picks, x.picks)
            local m = { id = x.id, d = d, tags = {}, why = {} }
            if x == cl.core then
                m.action = "core"
            else
                local own = false
                for key, list in pairs(claims) do for _, c in ipairs(list) do if c.id == x.id then own = true end end end
                if d == 0 then
                    m.action = "merge"; m.why[#m.why + 1] = "same talents"
                elseif d <= T.MERGE and not own then
                    m.action = "merge"; m.why[#m.why + 1] = ("%d talent off, nothing in its name or tags of its own"):format(d)
                else
                    m.action = "swap"; m.why[#m.why + 1] = ("%d talent%s off"):format(d, d == 1 and "" or "s")
                end
            end
            entry.members[#entry.members + 1] = m
        end
        plan.cores[#plan.cores + 1] = entry
    end
    -- hand out places: one build per place; a merged build's places go to its core
    local holderOf = {}
    for _, e in ipairs(plan.cores) do
        local core
        for _, m in ipairs(e.members) do if m.action == "core" then core = m end end
        for _, m in ipairs(e.members) do holderOf[m.id] = m.action == "merge" and core or m end
    end
    local function holder(id) return holderOf[id] end
    local held = {}
    for key, list in pairs(claims) do
        table.sort(list, function(a, b) return a.score > b.score end)
        local win = list[1]
        local m = holder(win.id)
        m.tags[key] = win.name
        held[key] = true
        local how = win.score >= 10 and "already tagged" or ("named \"%s\""):format(byId[win.id].name)
        m.why[#m.why + 1] = ("%s (%s)"):format(win.name, how)
        for i = 2, #list do
            local other = holder(list[i].id)
            if other ~= m then
                notes[#notes + 1] = ("%s: %s keeps it over %s"):format(win.name, byId[win.id].name, byId[list[i].id].name)
            end
        end
    end
    -- content tags: one core per spec gets each kind (the one whose names say it most)
    local content = {}
    for _, e in ipairs(plan.cores) do
        local key = e.content and CONTENT_KEY[e.content]
        if key and not held[key] then
            local core = e.members[1]
            for _, m in ipairs(e.members) do if m.action == "core" then core = m end end
            local strength = 0
            for _, x in ipairs(e.members) do strength = strength + (x.action ~= "swap" and 1 or 0) end
            if not content[key] or strength > content[key].strength then content[key] = { e = e, m = core, strength = strength } end
        end
    end
    for key, c in pairs(content) do
        if not c.m.tags[key] then c.m.tags[key] = CONTENT_NAME[c.e.content] end
    end
    -- names: "<hero> <content> <target>"; the same name twice gets a number
    local used = {}
    for _, e in ipairs(plan.cores) do
        local parts = { e.hero ~= "?" and e.hero or nil }
        if e.content then parts[#parts + 1] = CONTENT_NAME[e.content] end
        if e.target then parts[#parts + 1] = TARGET_NAME[e.target] end
        if not e.content and not e.target then
            -- nothing to go on: keep the build's own name if it has one ("Scissor"), else "core"
            local own = byId[e.core].name
            if reads[e.core].generic then own = "core" end
            if e.hero and own:lower():find(e.hero:lower(), 1, true) then parts = {} end
            parts[#parts + 1] = own
        end
        local name = table.concat(parts, " ")
        used[name] = (used[name] or 0) + 1
        e.name = used[name] > 1 and ("%s %d"):format(name, used[name]) or name
        e.group = e.content and CONTENT_NAME[e.content] or nil
        local core = byId[e.core]
        if reads[e.core].season then notes[#notes + 1] = ("%s names a season (%s): check it's still current"):format(core.name, reads[e.core].season) end
        plan.counts.cores = plan.counts.cores + 1
        for _, m in ipairs(e.members) do
            if m.action == "swap" then plan.counts.swaps = plan.counts.swaps + 1 end
            if m.action == "merge" then plan.counts.merges = plan.counts.merges + 1 end
        end
    end
    return plan
end

-- In game -------------------------------------------------------------------------------------
local function rawPlaces()
    local out = {}
    for _, d in ipairs(UI.seasonDungeons()) do out[#out + 1] = { key = d.key, name = d.name, kind = "dungeon" } end
    for _, r in ipairs(UI.seasonRaids()) do
        if r.key then out[#out + 1] = { key = r.key, name = r.name, kind = "raid" } end
        for _, b in ipairs(r.bosses) do out[#out + 1] = { key = b.key, name = b.name, kind = "boss" } end
    end
    return out
end

-- Plan for a spec, from its saved builds. Also kept in saved data (input and plan) for reports.
function T.planFor(specID)
    local list = B.list(specID)
    local input = {}
    for i, b in ipairs(list) do
        local picks = C.picks(b.text)
        if picks then
            local tags = {}
            for k, v in pairs(b.tags or {}) do tags[k] = v end
            input[#input + 1] = { id = i, name = b.name, group = b.group, tags = tags, hero = C.heroName(b.text), picks = picks }
        else
            TK.log("tidy: couldn't read '%s', left out", b.name)
        end
    end
    local raw = rawPlaces()
    local plan = T.plan(input, T.places(raw))
    TK.db.tidy = TK.db.tidy or {}
    TK.db.tidy[specID] = { input = input, places = raw, plan = plan, at = date("%Y-%m-%d %H:%M:%S") }
    TK.log("tidy plan (%s): %d builds -> %d core, %d swaps, %d merged", B.specName(specID), #input, plan.counts.cores, plan.counts.swaps, plan.counts.merges)
    for _, e in ipairs(plan.cores) do
        local parts = {}
        for _, m in ipairs(e.members) do parts[#parts + 1] = ("%s %s(%d)"):format(m.action, list[m.id].name, m.d) end
        TK.log("  %s [%s]: %s", e.name, e.group or "-", table.concat(parts, ", "))
    end
    return plan
end

local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

function T.apply(specID, plan)
    local list = B.list(specID)
    TK.db.undo = TK.db.undo or {}
    TK.db.undo[specID] = { list = copy(list), active = TK.db.active[specID], at = date("%Y-%m-%d %H:%M:%S") }
    local out, rename = {}, {}
    local function unique(name) return B.uniqueName(out, name) end
    for _, e in ipairs(plan.cores) do
        local coreM
        for _, m in ipairs(e.members) do if m.action == "core" then coreM = m end end
        local core = list[coreM.id]
        local name = unique(e.name)
        rename[core.name] = name
        core.name, core.main, core.changes, core.needsReview, core.group, core.outdated = name, nil, nil, nil, e.group, nil
        core.tags = next(coreM.tags) and coreM.tags or nil
        out[#out + 1] = core
        for _, m in ipairs(e.members) do
            local x = list[m.id]
            if m.action == "merge" then
                rename[x.name] = name
                core.gear = core.gear or x.gear
                core.pvp = core.pvp or x.pvp
            elseif m.action == "swap" then
                local swapName = unique(x.name)
                rename[x.name] = swapName
                x.name, x.main, x.group, x.needsReview = swapName, name, e.group, nil
                x.changes = B.changesFrom(core.text, x.text)
                x.tags = next(m.tags) and m.tags or nil
                out[#out + 1] = x
            end
        end
    end
    local placed = {}
    for _, x in ipairs(out) do placed[x] = true end
    for _, x in ipairs(list) do -- builds the plan couldn't read stay as they are
        local merged = false
        for _, e in ipairs(plan.cores) do for _, m in ipairs(e.members) do if list[m.id] == x then merged = true end end end
        if not placed[x] and not merged then out[#out + 1] = x end
    end
    TK.db.builds[specID] = out
    local active = TK.db.active[specID]
    if active then TK.db.active[specID] = rename[active] or active end
    TK.log("tidy applied (%s): %d builds -> %d", B.specName(specID), #list, #out)
    TK.chat(("Tidied %s: %d builds into %d core build%s and %d swap%s. |cff98ff98/tk undo|r puts them back.")
        :format(B.specName(specID), #list, plan.counts.cores, plan.counts.cores == 1 and "" or "s", plan.counts.swaps, plan.counts.swaps == 1 and "" or "s"))
    TK.changed()
end

function T.undo(specID)
    local u = TK.db.undo and TK.db.undo[specID]
    if not u then return TK.chat("Nothing to undo for " .. B.specName(specID) .. ".") end
    TK.db.builds[specID] = u.list
    TK.db.active[specID] = u.active
    TK.db.undo[specID] = nil
    TK.log("tidy undone (%s)", B.specName(specID))
    TK.chat(("Put %s's builds back as they were before tidying up."):format(B.specName(specID)))
    TK.changed()
end

TK.commands.undo = function() local s = B.specID() if s then T.undo(s) end end
TK.commands.tidy = function() local s = B.specID() if s then T.show(s) end end

-- The plan window -------------------------------------------------------------------------------
local win
local function line(i)
    win.lines[i] = win.lines[i] or win.content:CreateFontString(nil, "OVERLAY", "TalentKeeperFont")
    local l = win.lines[i]
    l:SetJustifyH("LEFT")
    l:SetWordWrap(true)
    l:SetWidth(470)
    return l
end

local ACTION = { core = "|cff98ff98core|r", swap = "|cff98ff98swap|r", merge = "|cff8c8c8cmerged in|r" }

local function render(specID, plan)
    local list = B.list(specID)
    for _, l in ipairs(win.lines) do l:Hide() end
    local y, n = -4, 0
    local function add(text, font, indent, gap)
        n = n + 1
        local l = line(n)
        l:SetFontObject(font or "TalentKeeperFont")
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", indent or 0, y - (gap or 0))
        l:SetWidth(470 - (indent or 0))
        l:SetText(text)
        l:Show()
        y = y - (gap or 0) - (tonumber(l:GetStringHeight()) or 12) - 3
    end
    local c = plan.counts
    add(("%d builds become %d core build%s with %d swap%s; %d merged into their core."):format(c.builds, c.cores,
        c.cores == 1 and "" or "s", c.swaps, c.swaps == 1 and "" or "s", c.merges), "TalentKeeperFont")
    add("Builds on different hero trees are never combined. Within a hero tree, builds a few talents apart are one family: the build closest to the rest is its core, the others are its swaps, and copies merge. Names, groups and tags tell what each build is for.", "TalentKeeperFontSmall", 0, 2)
    for _, e in ipairs(plan.cores) do
        local core
        for _, m in ipairs(e.members) do if m.action == "core" then core = m end end
        add(("|cffffffff%s|r  |cff8c8c8c(was %s)|r"):format(e.name, list[core.id].name), "TalentKeeperFontLarge", 0, 12)
        local meta = { e.group and ("group " .. e.group) or "no group" }
        local tagNames = {}
        for _, v in pairs(core.tags) do tagNames[#tagNames + 1] = v end
        table.sort(tagNames)
        if #tagNames > 0 then meta[#meta + 1] = "for " .. table.concat(tagNames, ", ") end
        add("|cff8c8c8c" .. table.concat(meta, "  ·  ") .. "|r", "TalentKeeperFontSmall", 0)
        for _, m in ipairs(e.members) do
            if m.action ~= "core" then
                local x = list[m.id]
                local why = table.concat(m.why, "; ")
                add(("%s  %s  |cff8c8c8c%s|r"):format(ACTION[m.action], x.name, why), "TalentKeeperFont", 14)
            end
        end
    end
    if #plan.notes > 0 then
        add("|cffffb84dWorth a look|r", "TalentKeeperFont", 0, 12)
        for _, note in ipairs(plan.notes) do add("|cffbdbdbd" .. note .. "|r", "TalentKeeperFontSmall", 14) end
    end
    win.content:SetHeight(-y + 8)
end

local function makeWindow()
    win = CreateFrame("Frame", "TalentKeeperTidy", UIParent)
    win:SetSize(520, 520)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    win:SetClampedToScreen(true)
    UI.fill(win, "BACKGROUND", 0.06, 0.06, 0.06, 0.98)
    UI.ring(win, 0)
    tinsert(UISpecialFrames, win:GetName())
    win.title = win:CreateFontString(nil, "OVERLAY", "TalentKeeperFontLarge")
    win.title:SetPoint("TOPLEFT", 12, -10)
    win.scroll = CreateFrame("ScrollFrame", nil, win, "ScrollFrameTemplate")
    win.scroll:SetPoint("TOPLEFT", 12, -36)
    win.scroll:SetPoint("BOTTOMRIGHT", -30, 46)
    win.content = CreateFrame("Frame", nil, win.scroll)
    win.content:SetSize(470, 10)
    win.scroll:SetScrollChild(win.content)
    win.lines = {}
    win.close = UI.button(win, "Cancel", 90, function() win:Hide() end)
    win.close:SetPoint("BOTTOMRIGHT", -12, 12)
    win.apply = UI.button(win, "Tidy up", 90, function()
        if win.plan then T.apply(win.spec, win.plan) end
        win:Hide()
    end)
    win.apply:SetPoint("RIGHT", win.close, "LEFT", -8, 0)
end

function T.show(specID)
    if not win then makeWindow() end
    local plan = T.planFor(specID)
    win.spec, win.plan = specID, plan
    win.title:SetText("Tidy up " .. B.specName(specID) .. " builds")
    render(specID, plan)
    win.scroll:SetVerticalScroll(0)
    win:Show()
end
