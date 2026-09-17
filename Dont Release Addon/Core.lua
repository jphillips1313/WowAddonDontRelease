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

local hint = CreateFrame("Frame", "DontReleaseHint", UIParent, "BackdropTemplate")
hint:SetSize(360, 50)
hint:SetPoint("TOP", UIParent, "TOP", 0. -160)
hint:Hide()
hint:SetFrameStrata("HIGH")

if hint.SetBackdrop then
    hint.SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    hint:SetBackdropColor(0, 0, 0, 0.6)
end

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


