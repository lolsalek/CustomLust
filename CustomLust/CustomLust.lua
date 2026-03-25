local ADDON_NAME, NS = ...

-- ============================================================
-- Locals (declare early)
-- ============================================================
local active = false
local previewActive = false
local stopTimerId = 0

-- ============================================================
-- Defaults
-- ============================================================
local DEFAULTS = {
    enabled = true,

    soundPath = "Interface\\AddOns\\CustomLust\\media\\pedrolust.mp3",
    imagePath = "Interface\\AddOns\\CustomLust\\media\\pedro.tga",
    soundChannel = "Master",

    size = 256,
    locked = true,

    -- Spin (kept, but you can hard-code if you want)
    spin = true,
    spinSecondsPerTurn = 1.2,

    -- Sprite sheet (hard-coded ON in ApplyVisuals below)
    useSpriteSheet = true,
    alpha = 1.0, -- 0.1 to 1.0

    sheetCols = 4,
    sheetRows = 8,
    sheetFrames = 32,
    sheetFPS = 6,

    -- Debug
    debug = false,

    pos = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0
    },

    -- IDs based on your WA + common lusts
    lustBuffSpellIds = {2825, -- Bloodlust
    32182, -- Heroism
    80353, -- Time Warp
    264667, -- Primal Rage
    178207, -- Drums of Fury
    230935, -- Drums variant
    -- From your WA export (keep)
    272678, 160452, 256740, 292686, 386540, 390386, 381301},

    -- OPTIONAL: extra name fallbacks (case-insensitive).
    -- If Blizzard ever swaps IDs, this still catches it.
    lustBuffNames = {"Bloodlust", "Heroism", "Time Warp", "Primal Rage", "Drums of Fury", "Drums of the Mountain"}
}

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = dst[k] or {}
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

CustomLustDB = CustomLustDB or {}
CopyDefaults(CustomLustDB, DEFAULTS)

-- ============================================================
-- Print helper
-- ============================================================
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff99CustomLust|r: " .. tostring(msg))
end
NS.Print = Print

-- ============================================================
-- Build lookup sets (spellIDs + names)
-- ============================================================
local function NormalizeName(s)
    if not s then
        return nil
    end
    s = tostring(s):lower()
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

-- Hard fallback names (ALWAYS available). Stored normalized (lowercase).
local LUST_NAMES = {
    [NormalizeName("Bloodlust")] = true,
    [NormalizeName("Heroism")] = true,
    [NormalizeName("Time Warp")] = true,
    [NormalizeName("Primal Rage")] = true,
    [NormalizeName("Drums of Fury")] = true,
    [NormalizeName("Drums of the Mountain")] = true
}

-- Sated-like debuff IDs that are NOT private in combat (unlike lust buffs in Midnight).
-- If any of these are on the player, a lust effect was recently cast.
local SATED_DEBUFF_IDS = {
    [57723] = true, -- Exhaustion        (Heroism)
    [57724] = true, -- Sated             (Bloodlust)
    [80354] = true, -- Temporal Displacement (Time Warp)
    [95809] = true, -- Insanity           (Hunter pet Bloodlust)
    [160455] = true, -- Fatigued           (Hunter pet, variant 1)
    [264689] = true, -- Fatigued           (Hunter pet, variant 2)
    [390435] = true -- Exhaustion         (Evoker Fury)
}

local function EnsureNonEmptySpellList()
    if type(CustomLustDB.lustBuffSpellIds) ~= "table" or #CustomLustDB.lustBuffSpellIds == 0 then
        CustomLustDB.lustBuffSpellIds = {}
        for _, id in ipairs(DEFAULTS.lustBuffSpellIds) do
            table.insert(CustomLustDB.lustBuffSpellIds, id)
        end
    end
end

local function BuildBuffSets()
    EnsureNonEmptySpellList()

    NS.BUFF_SET_IDS = {}
    NS.BUFF_SET_NAMES = {}

    -- 1) Hard fallback names
    for n in pairs(LUST_NAMES) do
        NS.BUFF_SET_NAMES[n] = true
    end

    -- 2) SpellIDs + localized spell names (from the ID)
    for _, id in ipairs(CustomLustDB.lustBuffSpellIds or {}) do
        if type(id) == "number" then
            NS.BUFF_SET_IDS[id] = true

            local spellName
            if C_Spell and C_Spell.GetSpellInfo then
                local info = C_Spell.GetSpellInfo(id)
                spellName = info and info.name
            elseif GetSpellInfo then
                -- Legacy path for Classic / pre-11.0 clients
                spellName = GetSpellInfo(id)
            end
        end
    end

    -- 3) Optional extra fallback names (user list)
    for _, n in ipairs(CustomLustDB.lustBuffNames or {}) do
        n = NormalizeName(n)
        if n and n ~= "" then
            NS.BUFF_SET_NAMES[n] = true
        end
    end

    if CustomLustDB.debug then
        local idCount, nameCount = 0, 0
        for _ in pairs(NS.BUFF_SET_IDS) do
            idCount = idCount + 1
        end
        for _ in pairs(NS.BUFF_SET_NAMES) do
            nameCount = nameCount + 1
        end
        Print(("Tracking IDs: %d | Tracking names: %d"):format(idCount, nameCount))
    end
end

NS.RebuildBuffSet = BuildBuffSets

-- ============================================================
-- Frame
-- ============================================================
local Effect = CreateFrame("Frame", "CustomLustEffectFrame", UIParent, "BackdropTemplate")
Effect:SetFrameStrata("HIGH")
Effect:Hide()

local Tex = Effect:CreateTexture(nil, "ARTWORK")
Tex:SetAllPoints()
Tex:SetTexture(CustomLustDB.imagePath)
Tex:SetTexCoord(0, 1, 0, 1)

-- =========================
-- Countdown text
-- =========================
local timeText = Effect:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
timeText:SetFont(timeText:GetFont(), 18, "OUTLINE")
timeText:ClearAllPoints()
timeText:SetPoint("BOTTOM", Effect, "BOTTOM", 0, -20)
timeText:SetTextColor(1, 1, 1, 1)
timeText:SetShadowColor(0, 0, 0, 1)
timeText:SetShadowOffset(1, -1)
timeText:SetText("")
timeText:Hide()

local countdownTicker = nil
local countdownExpiration = nil

if Tex.SetSnapToPixelGrid then
    Tex:SetSnapToPixelGrid(true)
end
if Tex.SetTexelSnappingBias then
    Tex:SetTexelSnappingBias(0)
end

Effect:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16
})
Effect:SetBackdropBorderColor(0, 1, 0, 0)

-- Dragging
Effect:RegisterForDrag("LeftButton")
Effect:SetMovable(true)

Effect:SetScript("OnDragStart", function(self)
    if CustomLustDB.locked and not previewActive then
        return
    end
    self:StartMoving()
end)

Effect:SetScript("OnDragStop", function(self)
    if CustomLustDB.locked and not previewActive then
        return
    end
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    local p = CustomLustDB.pos
    p.point = point or "CENTER"
    p.relativePoint = relativePoint or "CENTER"
    p.x = math.floor((x or 0) + 0.5)
    p.y = math.floor((y or 0) + 0.5)
end)

Effect:SetScript("OnMouseDown", function(_, btn)
    if btn ~= "RightButton" then
        return
    end
    if CustomLustDB.locked and not previewActive then
        return
    end
    CustomLustDB.pos = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0
    }
    if NS.ApplyVisuals then
        NS.ApplyVisuals()
    end
    Print("Position reset.")
end)

-- ============================================================
-- Spin animation
-- ============================================================
local spinAG = Effect:CreateAnimationGroup()
local rot = spinAG:CreateAnimation("Rotation")
rot:SetOrder(1)
spinAG:SetLooping("REPEAT")

-- ============================================================
-- Sprite animation
-- ============================================================
local ticker
local frameIndex = 0

local function StopSprite()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    frameIndex = 0
    Tex:SetTexCoord(0, 1, 0, 1)
end

-- Atlas crop (your photoshop measurements)
local TEX_W, TEX_H = 1024, 2048
local USED_W, USED_H = 770, 1536
local U0, V0 = 0, 0
local U1, V1 = USED_W / TEX_W, USED_H / TEX_H

local function SetFrameTexCoord(i)
    local cols = math.max(1, tonumber(CustomLustDB.sheetCols) or 1)
    local rows = math.max(1, tonumber(CustomLustDB.sheetRows) or 1)

    local col = i % cols
    local row = math.floor(i / cols)
    if row >= rows then
        row = row % rows
    end

    local cellW = (U1 - U0) / cols
    local cellH = (V1 - V0) / rows

    local left = U0 + col * cellW
    local right = left + cellW
    local top = V0 + row * cellH
    local bottom = top + cellH

    local padU = 0.5 / TEX_W
    local padV = 0.5 / TEX_H

    left = left + padU
    right = right - padU
    top = top + padV
    bottom = bottom - padV

    Tex:SetTexCoord(left, right, top, bottom)
end

local function StartSprite()
    StopSprite()

    local fps = tonumber(CustomLustDB.sheetFPS) or 6
    if fps <= 0 then
        fps = 6
    end

    local frames = tonumber(CustomLustDB.sheetFrames) or 1
    if frames <= 0 then
        frames = 1
    end

    local cols = math.max(1, tonumber(CustomLustDB.sheetCols) or 1)
    local rows = math.max(1, tonumber(CustomLustDB.sheetRows) or 1)
    local maxFrames = cols * rows
    if frames > maxFrames then
        frames = maxFrames
    end

    frameIndex = 0
    SetFrameTexCoord(frameIndex)
    frameIndex = (frameIndex + 1) % frames

    ticker = C_Timer.NewTicker(1 / fps, function()
        SetFrameTexCoord(frameIndex)
        frameIndex = (frameIndex + 1) % frames
    end)
end

-- ============================================================
-- Visual apply
-- ============================================================
function NS.ApplyVisuals()
    Effect:SetSize(CustomLustDB.size, CustomLustDB.size)

    -- hard-code sprite mode ON (as requested)
    CustomLustDB.useSpriteSheet = true

    local imgOn = (CustomLustDB.imageEnabled ~= false)
    Tex:SetTexture(imgOn and CustomLustDB.imagePath or nil)
    Tex:SetAlpha(imgOn and 1 or 0)

    Tex:SetTexture(CustomLustDB.imagePath)

    local a = tonumber(CustomLustDB.alpha) or 1
    if a < 0.10 then
        a = 0.10
    end
    if a > 1.00 then
        a = 1.00
    end
    Effect:SetAlpha(a)

    Effect:ClearAllPoints()
    local p = CustomLustDB.pos
    Effect:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)

    if CustomLustDB.locked and not previewActive then
        Effect:SetBackdropBorderColor(0, 1, 0, 0)
        Effect:EnableMouse(false)
    else
        Effect:SetBackdropBorderColor(0, 1, 0, 1)
        Effect:EnableMouse(true)
    end

    if CustomLustDB.spin then
        rot:SetDuration(tonumber(CustomLustDB.spinSecondsPerTurn) or 1.2)
        rot:SetDegrees(360)
    end

    if Effect:IsShown() then
        StartSprite()
    end
end

local activeSoundHandle = nil

local function StopEffect()
    StopSprite()
    spinAG:Stop()
    Effect:Hide()
    if activeSoundHandle then
        StopSound(activeSoundHandle, 1000)
        activeSoundHandle = nil
    end
end
NS.StopEffect = StopEffect

local function StartEffect(opts)
    opts = opts or {}
    if not CustomLustDB.enabled then
        return
    end

    NS.ApplyVisuals()
    Effect:Show()

    -- Only run sprite animation and spin when the image overlay is active
    if CustomLustDB.imageEnabled ~= false then
        StartSprite()

        if CustomLustDB.spin then
            spinAG:Play()
        end
    end

    if not opts.silent then
        pcall(function()
            local _, handle = PlaySoundFile(CustomLustDB.soundPath, CustomLustDB.soundChannel or "Master")
            activeSoundHandle = handle
        end)
    end
end
NS.StartEffect = StartEffect

function NS.StartPreviewNoSound()
    previewActive = true
    NS.ApplyVisuals()
    StartEffect({
        silent = true
    })
end

function NS.StopPreviewNoSound()
    previewActive = false
    NS.ApplyVisuals()
    if not active then
        StopEffect()
    end
end

-- =========================
-- Aura detection (IDs + name fallback)
-- =========================

-- All sated-like debuffs last exactly 10 minutes (600 s).
-- Lust itself lasts 40 s. So if the debuff has more than (600 - 40) = 560 s
-- remaining it was applied within the last 40 s and the effect is still active.
local MAX_LUST_DISPLAY_SECONDS = 40
local SATED_DURATION = 600
local SATED_FRESHNESS_THRESHOLD = SATED_DURATION - MAX_LUST_DISPLAY_SECONDS -- 560

local function IsSatedFresh(expirationTime)
    return expirationTime and (expirationTime - GetTime()) > SATED_FRESHNESS_THRESHOLD
end

local function FindActiveTriggerAura()
    if not NS.BUFF_SET_IDS or not NS.BUFF_SET_NAMES then
        return false, nil, nil, nil
    end

    -- Modern retail API (C_UnitAuras)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        --    Scan HARMFUL auras for sated-like debuffs.
        --    These debuffs (Sated, Exhaustion, Temporal Displacement, etc.) are NOT
        --    private in combat, so they are always visible even under the Midnight
        --    aura restrictions. If present, a lust effect was just cast on the player.
        local i = 1
        while true do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HARMFUL")
            if not aura then
                break
            end

            -- aura.spellId may be a "secret" userdata for restricted auras;
            -- using it as a table key throws "table index is secret".
            -- pcall safely skips those auras.
            local ok, isSated = pcall(function() return SATED_DEBUFF_IDS[aura.spellId] end)
            if ok and isSated then
                local expTime = aura.expirationTime
                if not IsSatedFresh(expTime) then
                    return false, nil, nil, nil -- debuff is old; lust window has passed
                end
                return true, expTime, aura.spellId, aura.name
            end

            i = i + 1
        end

        return false, nil, nil, nil
    end

    -- Fallback (older clients / Classic): UnitBuff + UnitDebuff
    for i = 1, 40 do
        local name, _, _, _, _, expTime, _, _, _, spellId = UnitBuff("player", i)
        if not name then
            break
        end

        local nm = NormalizeName(name)
        if (spellId and NS.BUFF_SET_IDS[spellId]) or (nm and NS.BUFF_SET_NAMES[nm]) then
            return true, expTime, spellId, name
        end
    end

    -- Also check debuffs on the fallback path for sated effects
    for i = 1, 40 do
        local name, _, _, _, _, expTime, _, _, _, spellId = UnitDebuff("player", i)
        if not name then
            break
        end

        if spellId and SATED_DEBUFF_IDS[spellId] then
            if IsSatedFresh(expTime) then
                return true, expTime, spellId, name
            end
        end
    end

    return false, nil, nil, nil
end

local function ScheduleStop(expirationTime)
    stopTimerId = stopTimerId + 1
    local myId = stopTimerId
    if not (expirationTime and expirationTime > 0) then return end
    local remaining = math.min(expirationTime - GetTime(), MAX_LUST_DISPLAY_SECONDS)
    if remaining <= 0 then return end

    C_Timer.After(remaining + 0.05, function()
                if myId ~= stopTimerId then
                    return
                end
                active = false
                if not previewActive then
                    StopEffect()
                end
            end)
end

local function OnAuraChanged()
    local has, expirationTime, foundSpellId, foundName = FindActiveTriggerAura()

    if has then
        if not active then
            active = true
            StartEffect()

            if CustomLustDB.debug then
                Print(("Triggered by: %s (spellId: %s)"):format(tostring(foundName), tostring(foundSpellId)))
            end
        end
        ScheduleStop(expirationTime)

    elseif active then
        active = false
        if not previewActive then
            StopEffect()
        end
    end
end

-- =========================
-- Debug tools
-- =========================

local function DumpTrackedAuras()
    local idCount, nameCount = 0, 0
    for _ in pairs(NS.BUFF_SET_IDS or {}) do
        idCount = idCount + 1
    end
    for _ in pairs(NS.BUFF_SET_NAMES or {}) do
        nameCount = nameCount + 1
    end
    Print(("Tracking IDs: %d | Tracking names: %d"):format(idCount, nameCount))

    local has, exp, sid, nm = FindActiveTriggerAura()
    if has then
        Print(("MATCH RIGHT NOW: %s (spellId: %s) exp=%s"):format(tostring(nm), tostring(sid), tostring(exp)))
    else
        Print("No tracked lust buffs found on you right now.")
        Print("Tip: With Time Warp active, run /customlustdumpall to list ALL your HELPFUL auras.")
    end

    Print("---- end dump ----")
end

local function DumpAllHelpfulAuras()
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        Print("-- HELPFUL auras --")
        local i = 1
        while true do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not aura then
                break
            end
            Print(("[%02d] %s (spellId: %s)"):format(i, tostring(aura.name), tostring(aura.spellId)))
            i = i + 1
            if i > 80 then
                break
            end -- safety
        end

        Print("-- HARMFUL auras (sated-like debuffs highlighted) --")
        i = 1
        while true do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HARMFUL")
            if not aura then
                break
            end
            local tag = (aura.spellId and SATED_DEBUFF_IDS[aura.spellId]) and " <-- SATED" or ""
            Print(("[%02d] %s (spellId: %s)%s"):format(i, tostring(aura.name), tostring(aura.spellId), tag))
            i = i + 1
            if i > 80 then
                break
            end -- safety
        end
    else
        for i = 1, 40 do
            local name, _, _, _, _, _, _, _, _, spellId = UnitAura("player", i, "HELPFUL")
            if not name then
                break
            end
            Print(("[%02d] %s (spellId: %s)"):format(i, tostring(name), tostring(spellId)))
        end
        Print("-- HARMFUL (debuffs) --")
        for i = 1, 40 do
            local name, _, _, _, _, _, _, _, _, spellId = UnitAura("player", i, "HARMFUL")
            if not name then
                break
            end
            local tag = (spellId and SATED_DEBUFF_IDS[spellId]) and " <-- SATED" or ""
            Print(("[%02d] %s (spellId: %s)%s"):format(i, tostring(name), tostring(spellId), tag))
        end
    end

    Print("---- end list ----")
end

SLASH_CUSTOMLUSTDUMP1 = "/customlustdump"
SlashCmdList.CUSTOMLUSTDUMP = DumpTrackedAuras

SLASH_CUSTOMLUSTDUMPALL1 = "/customlustdumpall"
SlashCmdList.CUSTOMLUSTDUMPALL = DumpAllHelpfulAuras

-- ============================================================
-- Events
-- ============================================================
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterUnitEvent("UNIT_AURA", "player")

f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON_NAME then
            return
        end

        BuildBuffSets()
        NS.ApplyVisuals()

        Print("Loaded. /customlust to configure. /customlustdump for debug.")
        OnAuraChanged()

    elseif event == "PLAYER_ENTERING_WORLD" then
        OnAuraChanged()

    elseif event == "UNIT_AURA" then
        OnAuraChanged()
    end
end)

-- ============================================================
-- Test
-- ============================================================
SLASH_CUSTOMLUSTTEST1 = "/customlusttest"
SlashCmdList.CUSTOMLUSTTEST = function(msg)
    msg = (msg or ""):lower()

    if msg == "on" then
        NS.StartEffect()
        Print("Test ON (stays until /customlusttest off).")
        return
    end

    if msg == "off" then
        NS.StopEffect()
        Print("Test OFF.")
        return
    end

    NS.StartEffect()
    C_Timer.After(3, function()
        NS.StopEffect()
    end)
end
