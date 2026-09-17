-- DontRelease
-- Gates the release button after a raid wipe until you hold modifier key
-- auto clears on incoming res

local ADDON = ...

-- Defaults / SavedVariables

local defaults = {
    enabled = true,
    modifier = "SHIFT",
    onlyInRaid = true,
    wipeThreshold = 3,
    skipIfSelfRes= true,
    lockedText = "DO NOT RELEASE",
    unlockedText = "Thank the Healer Rez incoming",
    rezIncomingText = "Thank you Healer"
}

local db

local SELF_RES_SPELLS = {
    20707,
    20608,
    319352,
}

local function HasSelfRes()
    if not db.skipIfSelfRes then return false end

    for _, spellID in ipairs (SELF_RES_SPELLS) do
        if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
            local name = C_Spell.GetSpellName(spellID)
            if name and AuraUtil and AuraUtil.FindAuraByName then
                local aura = AuraUtil.FindAuraByName(name, "player", "HELPFUL")
                if aura then return true end
            end
        end
    
        local cd = C_Spell.GetSpellCooldown(spellID)
            if cd and cd.isEnabled and cd.duration == 0 then
            return tru
        end
    end

    return false
end

-- State

local gateActive = false
local wipeConfirmed = false

local hint = CreateFrame("Frame", "DontReleaseHint", UIParent)
hint:SetSize(360, 50)
hint:SetPoint("TOP", UIParent, "TOP", 0, -160)
hint:Hide()
hint:SetFrameStrata("HIGH")

local hintBg = hint:CreateTexture(nil, "BACKGROUND")
hintBg:SetAllPoints()
hintBg:SetColorTexture(0, 0, 0, 0.6)

local hintText = hint:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
hintText:SetPoint("CENTER")
hintText:SetTextColor(1, 0.15, 0.15)

local function ModifierHeld()
    if db.modifier == "CTRL" then return IsControlKeyDown()
    elseif db.modifier == "ALT" then return IsAltKeyDown()
    else return IsShiftKeyDown() end
end

-- Poput button gating

local function GetDeathPopupButton()
    local popup = StaticPopup_Visible and StaticPopup_Visible("DEATH")
    if not popup then return nil end
    return _G[popup .. "Button1"], popup
end

local function ApplyLock()
    local btn = GetDeathPopupButton()
    if btn then
        btn:Disable()
        if btn.SetAlpha then btn:SetAlpha(0.4) end
    end
end

-- Supress the Enter-Key accelerator on the death popup while gated

local enterSupressed = false

local function SupressEnter()
    if enterSupressed then return end
    local popup = StaticPopup_Visible and StaticPopup_Visible("DEATH")
    if popup then
        local frame = _G[popup]
        if frame then
            frame:SetPropagateKeyboardInput(false)
            enterSupressed = true
        end
    end
end

local function RestoreEnter()
    if not enterSupressed then return end
    local popup = StaticPopup_Visible and StaticPopup_Visible("DEATH")
    if popup then
        local frame = _G[popup]
        if frame then
            frame:SetPropagateKeyboardInput(true)
        end
    end
    enterSupressed = false
end

-- Gate Lifecycle

local ticker = CreateFrame("Frame")

local function StopTicker()
    ticker:SetScript("OnUpdate", nil)
end

local function ClearGate(reasonText, r, g, b)
    if not gateActive and not hint:IsShown() then return end
    gateActive = false
    StopTicker()
    RestoreEnter()
    ApplyUnlock()

    if reasonText then
        hintText:SetText(reasonText)
        hintText:SetTextColor(r or 0.3, g or 1, b or 0.3)
        C_Rimer.After(3, function()
            if not gateActive then hint:Hide() end
        end)
    else
        hint:Hide()
    end
end

local function TickGate()
    if not UnitIsDeadOrGhost("player") then
        ClearGate()
        return
    end

    if ModifierHeld() then
        ApplyUnlock()
        hintText:SetText(db.unlockedText)
        hintText:SetTextColor(0.3, 1, 0.3)
    else
        ApplyLock()
        SuppressEnter()
        hintText:SetText(db.lockedText .. "\n(hold " .. db.modifier .. " to release)")
        hintText:SetTextColor(1, 0.15, 0.15)
    end
end

local function StartGate()
    if HasSelfRes() then
        -- a self-res is ready; don't bother gating
        return
    end
    gateActive = true
    hint:Show()
    ticker:SetScript("OnUpdate", TickGate)
    TickGate()
end

-- Wipe Detection

local function CountDeadRaid()
    if not IsInRaid() then return 0 end
    local dead = 0
    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        if UnitExists(unit) and UnitIsDeadOrGhost(unit) then
            dead = dead + 1
        end
    end
    return dead
end

local function ShouldGate()
    if not db.enabled then return false end
    if db.onlyInRaid and not IsInRaid() then return false end
    return true
end

local function EvaluateWipe()
    if not ShouldGate() then return end
    if not UnitIsDeadOrGhost("player") then return end

    if CountDeadRaid() >= db.wipeThreshold then
        wipeConfirmed = true
        if not gateActive then StartGate() end
    end
end

-- Events

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_UNGHOST")
frame:RegisterEvent("RESURRECT_REQUEST")
frame:RegisterEvent("ENCOUNTER_END")

-- Poll once a second while dead so a wipe that develops after our own death
-- (or a trash-pull wipe with no ENCOUNTER_END) still gets caught.
local wipeWatcher = CreateFrame("Frame")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= ADDON then return end
        DontReleaseDB = DontReleaseDB or {}
        for k, v in pairs(defaults) do
            if DontReleaseDB[k] == nil then DontReleaseDB[k] = v end
        end
        db = DontReleaseDB

    elseif event == "PLAYER_DEAD" then
        wipeConfirmed = false
        if ShouldGate() then
            -- single deaths don't gate on their own; start watching for a wipe
            wipeWatcher:SetScript("OnUpdate", function()
                EvaluateWipe()
            end)
            EvaluateWipe() -- catch the case where the raid was already mostly dead
        end

    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        wipeConfirmed = false
        wipeWatcher:SetScript("OnUpdate", nil)
        ClearGate()

    elseif event == "RESURRECT_REQUEST" then
        -- a rez is incoming right now; get out of the way immediately,
        -- regardless of gate state
        if gateActive then
            ClearGate(db.rezIncomingText, 0.3, 1, 0.3)
        end

    elseif event == "ENCOUNTER_END" then
        local _, _, _, _, success = ...
        if success == 0 and UnitIsDeadOrGhost("player") then
            wipeConfirmed = true
            if ShouldGate() then StartGate() end
        end
    end
end)

-- Slash commands

SLASH_DONTRELEASE1 = "/dnr"
SLASH_DONTRELEASE2 = "/dontrelease"

SlashCmdList["DONTRELEASE"] = function(msg)
    msg = msg:lower():trim()
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")

    if cmd == "toggle" or cmd == "" then
        db.enabled = not db.enabled
        print("|cffff6060DontRelease|r: " .. (db.enabled and "enabled" or "disabled"))

    elseif cmd == "modifier" then
        rest = rest:upper()
        if rest == "SHIFT" or rest == "CTRL" or rest == "ALT" then
            db.modifier = rest
            print("|cffff6060DontRelease|r: modifier set to " .. rest)
        else
            print("|cffff6060DontRelease|r: usage /dnr modifier <shift|ctrl|alt>")
        end

    elseif cmd == "threshold" then
        local n = tonumber(rest)
        if n and n > 0 then
            db.wipeThreshold = n
            print("|cffff6060DontRelease|r: wipe threshold set to " .. n)
        else
            print("|cffff6060DontRelease|r: usage /dnr threshold <number>")
        end

    elseif cmd == "raidonly" then
        db.onlyInRaid = not db.onlyInRaid
        print("|cffff6060DontRelease|r: raid-only is now " .. (db.onlyInRaid and "on" or "off"))

    elseif cmd == "selfres" then
        db.skipIfSelfRes = not db.skipIfSelfRes
        print("|cffff6060DontRelease|r: skip-if-self-res is now " .. (db.skipIfSelfRes and "on" or "off"))

    elseif cmd == "status" then
        print("|cffff6060DontRelease|r status:")
        print("  enabled: " .. tostring(db.enabled))
        print("  modifier: " .. db.modifier)
        print("  onlyInRaid: " .. tostring(db.onlyInRaid))
        print("  wipeThreshold: " .. tostring(db.wipeThreshold))
        print("  skipIfSelfRes: " .. tostring(db.skipIfSelfRes))

    else
        print("|cffff6060DontRelease|r commands:")
        print("  /dnr toggle - enable/disable")
        print("  /dnr modifier <shift|ctrl|alt>")
        print("  /dnr threshold <number> - dead raiders needed to count as a wipe")
        print("  /dnr raidonly - only gate while in a raid")
        print("  /dnr selfres - toggle skipping the gate when you have a self-res ready")
        print("  /dnr status")
    end
end



