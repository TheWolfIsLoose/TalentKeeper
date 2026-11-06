-- TalentKeeper and atrocityEssentials (AES): AES carries TalentKeeper as its own Talent Builds.
-- An AES build with it, switched on, does TalentKeeper's whole job: TalentKeeper steps aside
-- (no pane, prompts or ready check card) and offers, at login, to turn itself off. Only reads
-- AES's state.
local addonName, TK = ...

local AES = {}
TK.aes = AES

-- An AES whose Talent Builds carries TalentKeeper's (it says so with `mergedBuilds`), switched on.
function AES.merged()
    local ae = _G.atrocityEssentials
    if type(ae) ~= "table" or not ae.GetModule then return false end
    local ok, m = pcall(ae.GetModule, ae, "TalentBuilds", true)
    local db = ok and type(m) == "table" and m.mergedBuilds ~= nil and type(m.db) == "table" and m.db
    return db and db.Enabled == true or false
end

StaticPopupDialogs.TALENTKEEPER_MERGED = {
    text = "atrocityEssentials' Talent Builds now does everything TalentKeeper does, and it's on. Your builds came with it.\n\nTurn TalentKeeper off? (The game reloads.)",
    button1 = "Turn Off TalentKeeper",
    button2 = "Not Now",
    OnAccept = function()
        TK.log("turned off for AES Talent Builds")
        C_AddOns.DisableAddOn(addonName)
        C_UI.Reload()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function AES.notice()
    TK.chat("atrocityEssentials' Talent Builds is on, so TalentKeeper is staying out of its way. Your builds are under |cffffffff/aes talents|r.")
end

-- At login (TalentKeeper.lua calls this instead of its own start): say so and offer to turn
-- TalentKeeper off, every login until it is.
function AES.stepAside()
    C_Timer.After(3, function()
        AES.notice()
        StaticPopup_Show("TALENTKEEPER_MERGED")
    end)
end
