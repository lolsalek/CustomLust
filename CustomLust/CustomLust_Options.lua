local ADDON_NAME, NS = ...

-- ============================================================
-- Helpers
-- ============================================================
local function Print(msg)
  if NS and NS.Print then NS.Print(msg) end
end

local function Apply()
  if NS and NS.ApplyVisuals then NS.ApplyVisuals() end
end

local function Clamp(n, lo, hi)
  n = tonumber(n)
  if not n then return lo end
  if n < lo then return lo end
  if n > hi then return hi end
  return n
end

local function Round(n)
  n = tonumber(n) or 0
  return math.floor(n + 0.5)
end

-- ============================================================
-- Addon metadata (Version)
-- ============================================================
local VERSION =
  (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version"))
  or GetAddOnMetadata(ADDON_NAME, "Version")
  or "Unknown"

-- ============================================================
-- Shell (ElvUI-ish)
-- ============================================================
local UI = CreateFrame("Frame", "CustomLustOptionsFrame", UIParent, "BackdropTemplate")
UI:SetSize(720, 720)   -- taller to fit sound + image sections
UI:SetPoint("CENTER")
UI:SetFrameStrata("DIALOG")
UI:Hide()

UI:SetBackdrop({
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 8, edgeSize = 12,
  insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
UI:SetBackdropColor(0.06, 0.06, 0.07, 0.95)
UI:SetBackdropBorderColor(1, 1, 1, 0.15)

local close = CreateFrame("Button", nil, UI, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

-- Header bar
local header = CreateFrame("Frame", nil, UI, "BackdropTemplate")
header:SetPoint("TOPLEFT", 10, -10)
header:SetPoint("TOPRIGHT", -10, -10)
header:SetHeight(42)
header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
header:SetBackdropColor(0.10, 0.10, 0.12, 0.95)

local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("LEFT", 12, 0)
title:SetText("CustomLust")

local byline = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
byline:SetPoint("LEFT", title, "RIGHT", 8, -2)
byline:SetText("|cffbbbbbbby Salek|r")

local sub = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
sub:SetPoint("LEFT", byline, "RIGHT", 12, -2)
sub:SetText(("Lust / Custom overlay  |  v%s"):format(VERSION))

-- Drag window (HEADER ONLY)
UI:SetMovable(true)
UI:SetClampedToScreen(true)
header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function() UI:StartMoving() end)
header:SetScript("OnDragStop", function() UI:StopMovingOrSizing() end)

-- Sidebar
local sidebar = CreateFrame("Frame", nil, UI, "BackdropTemplate")
sidebar:SetPoint("TOPLEFT", 10, -56)
sidebar:SetPoint("BOTTOMLEFT", 10, 10)
sidebar:SetWidth(160)
sidebar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
sidebar:SetBackdropColor(0.09, 0.09, 0.10, 0.95)

-- Content area
local content = CreateFrame("Frame", nil, UI, "BackdropTemplate")
content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
content:SetPoint("BOTTOMRIGHT", -10, 10)
content:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
content:SetBackdropColor(0.08, 0.08, 0.09, 0.95)

local function MakeLine(parent, a1, a2)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 1, 1, 0.07)
  line:SetPoint(unpack(a1))
  line:SetPoint(unpack(a2))
  line:SetHeight(1)
  return line
end
MakeLine(UI, {"TOPLEFT", 10, -56}, {"TOPRIGHT", -10, -56})

-- ============================================================
-- Widgets
-- ============================================================
local function Label(parent, text, x, y, template)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetText(text)
  return fs
end

local function Hint(parent, text, x, y, w)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetWidth(w or 520)
  fs:SetJustifyH("LEFT")
  fs:SetText(text)
  return fs
end

local function Button(parent, text, x, y, w, h)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetPoint("TOPLEFT", x, y)
  b:SetSize(w or 140, h or 24)
  b:SetText(text)
  return b
end

local function Check(parent, text, x, y)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", x, y)
  cb.Text:SetText(text)
  return cb
end

local function MakeSlider(parent, x, y, width, minv, maxv, step, titleText, lowText, highText)
  local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  s:SetPoint("TOPLEFT", x, y)
  s:SetWidth(width or 420)
  s:SetMinMaxValues(minv, maxv)
  s:SetValueStep(step or 1)
  s:SetObeyStepOnDrag(true)

  local name = s:GetName()
  if name then
    local t = _G[name .. "Text"]
    local lo = _G[name .. "Low"]
    local hi = _G[name .. "High"]
    if t then t:SetText("") end
    if lo then lo:SetText("") end
    if hi then hi:SetText("") end
  end

  local tLab = Label(parent, titleText, x + 140, y + 2, "GameFontHighlightSmall")
  tLab:SetJustifyH("CENTER")
  tLab:SetWidth(width or 420)

  Label(parent, lowText, x, y + 12, "GameFontHighlightSmall")
  Label(parent, highText, x + (width or 420) - 20, y + 12, "GameFontHighlightSmall")

  return s
end

-- ============================================================
-- EditBox helper (single-line, styled)
-- ============================================================
local function MakeEditBox(parent, x, y, w, h)
  local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  eb:SetPoint("TOPLEFT", x, y)
  eb:SetSize(w or 320, h or 22)
  eb:SetAutoFocus(false)
  eb:SetFontObject("GameFontHighlightSmall")
  eb:SetMaxLetters(512)
  eb:SetTextInsets(6, 6, 2, 2)

  eb:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize = 8, edgeSize = 10,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  eb:SetBackdropColor(0.05, 0.05, 0.06, 0.95)
  eb:SetBackdropBorderColor(0.4, 0.4, 0.45, 0.9)

  eb:SetScript("OnEditFocusGained", function(self)
    self:SetBackdropBorderColor(0.4, 0.7, 1.0, 1.0)
  end)
  eb:SetScript("OnEditFocusLost", function(self)
    self:SetBackdropBorderColor(0.4, 0.4, 0.45, 0.9)
    self:HighlightText(0, 0)
  end)
  eb:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)

  return eb
end

-- ============================================================
-- Tabs
-- ============================================================
local pages = {}
local tabButtons = {}
local activeTab

local function CreatePage()
  local p = CreateFrame("Frame", nil, content)
  p:SetAllPoints()
  p:Hide()
  return p
end

local function SetTab(name)
  if activeTab == name then return end
  for _, p in pairs(pages) do p:Hide() end
  for k, b in pairs(tabButtons) do
    b.selected = (k == name)
    b.bg:SetAlpha(b.selected and 0.18 or 0.0)
    b.text:SetTextColor(b.selected and 0.25 or 1, b.selected and 0.85 or 1, b.selected and 1 or 1)
  end
  pages[name]:Show()
  activeTab = name
end

local function TabButton(text, y, key)
  local b = CreateFrame("Button", nil, sidebar)
  b:SetPoint("TOPLEFT", 8, y)
  b:SetPoint("TOPRIGHT", -8, y)
  b:SetHeight(30)

  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(0.35, 0.55, 1.0, 1.0)
  b.bg:SetAlpha(0.0)

  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.text:SetPoint("LEFT", 10, 0)
  b.text:SetText(text)

  b:SetScript("OnClick", function() SetTab(key) end)

  tabButtons[key] = b
  return b
end

pages.General = CreatePage()
pages.Debug   = CreatePage()
pages.About   = CreatePage()

local CX, CY = 16, -16

-- ============================================================
-- General
-- ============================================================
local pG = pages.General

local cbEnabled = Check(pG, "Enable CustomLust", CX, CY + 10)

local btnEdit = Button(pG, "Enter Edit Mode", CX, CY - 30, 160, 24)
local btnResetPos = Button(pG, "Reset Position", CX + 170, CY - 30, 140, 24)

-- Preview button (inside box, top-right)
local btnPreview = Button(pG, "Preview (10s)", 380, CY + 10, 140, 24)

local editHint = Hint(pG,
  "Edit Mode shows selected image (silent) and lets you drag it.\n" ..
  "• Drag with left mouse.\n" ..
  "• Right-click selected image while editing to reset.\n",
  CX, CY - 66, 520
)

local lockedHint = Hint(pG,
  "Tip: Enter Edit Mode to adjust size/transparency.\n" ..
  "Preview is always available.\n",
  CX, CY - 66, 520
)

Label(pG, "Size", CX, CY - 130)
local sizeSlider = MakeSlider(pG, CX, CY - 170, 460, 64, 512, 1, "", "64", "512")

Label(pG, "Transparency", CX, CY - 230)
local alphaSlider = MakeSlider(pG, CX, CY - 270, 460, 0.10, 1.00, 0.01, "", "10%", "100%")

local alphaValueText = pG:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
alphaValueText:SetPoint("LEFT", alphaSlider, "RIGHT", 12, 0)
alphaValueText:SetText("")

-- ============================================================
-- Sound File section
-- ============================================================

-- Section divider
local soundDivider = pG:CreateTexture(nil, "ARTWORK")
soundDivider:SetColorTexture(1, 1, 1, 0.07)
soundDivider:SetPoint("TOPLEFT", CX, CY - 320)
soundDivider:SetPoint("TOPRIGHT", -CX, CY - 320)
soundDivider:SetHeight(1)

Label(pG, "Sound File", CX, CY - 335, "GameFontNormal")

Hint(pG,
  "Path must be relative to the WoW directory.\n" ..
  "Example:  Interface\\AddOns\\CustomLust\\media\\mylust.mp3\n" ..
  "Supported formats: mp3, ogg, wav",
  CX, CY - 353, 520
)

-- EditBox for the sound path
local soundPathBox = MakeEditBox(pG, CX, CY - 400, 370, 22)

-- Test sound button
local btnTestSound = Button(pG, "Test Sound (10s)", CX + 380, CY - 400, 100, 22)

-- Sound channel label + dropdown
Label(pG, "Channel", CX, CY - 436)

-- UIDropDownMenu for sound channel (Master / Music / SFX / Ambience / Dialog)
local SOUND_CHANNELS = { "Master", "Music", "SFX", "Ambience", "Dialog" }

local channelDropdown = CreateFrame("Frame", "CustomLustChannelDropdown", pG, "UIDropDownMenuTemplate")
channelDropdown:SetPoint("TOPLEFT", CX + 54, CY - 424)
UIDropDownMenu_SetWidth(channelDropdown, 120)

local function ChannelDropdown_Initialize(_, level)
  level = level or 1
  for _, ch in ipairs(SOUND_CHANNELS) do
    local info = UIDropDownMenu_CreateInfo()
    info.text     = ch
    info.value    = ch
    info.checked  = (CustomLustDB and CustomLustDB.soundChannel == ch)
    info.func     = function()
      CustomLustDB.soundChannel = ch
      UIDropDownMenu_SetSelectedValue(channelDropdown, ch)
      Print("Sound channel set to " .. ch .. ".")
    end
    UIDropDownMenu_AddButton(info, level)
  end
end

UIDropDownMenu_Initialize(channelDropdown, ChannelDropdown_Initialize)

-- ============================================================
-- Image File section
-- ============================================================

-- Section divider
local imageDivider = pG:CreateTexture(nil, "ARTWORK")
imageDivider:SetColorTexture(1, 1, 1, 0.07)
imageDivider:SetPoint("TOPLEFT", CX, CY - 468)
imageDivider:SetPoint("TOPRIGHT", -CX, CY - 468)
imageDivider:SetHeight(1)

Label(pG, "Image File", CX, CY - 483, "GameFontNormal")

local cbImageEnabled = Check(pG, "Enable image overlay", CX + 300, CY - 493)

Hint(pG,
  "Path must be relative to the WoW directory.\n" ..
  "Example:  Interface\\AddOns\\CustomLust\\media\\myimage.tga\n" ..
  "Supported formats: tga, blp, png",
  CX, CY - 501, 520
)

-- EditBox for the image path
local imagePathBox = MakeEditBox(pG, CX, CY - 548, 370, 22)

-- Small thumbnail preview to the right of the box
local imgPreviewBorder = CreateFrame("Frame", nil, pG, "BackdropTemplate")
imgPreviewBorder:SetSize(52, 52)
imgPreviewBorder:SetPoint("TOPLEFT", CX + 484, CY - 552)
imgPreviewBorder:SetBackdrop({
  bgFile   = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 8, edgeSize = 10,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
imgPreviewBorder:SetBackdropColor(0.05, 0.05, 0.06, 0.95)
imgPreviewBorder:SetBackdropBorderColor(0.4, 0.4, 0.45, 0.9)

local imgPreviewTex = imgPreviewBorder:CreateTexture(nil, "ARTWORK")
imgPreviewTex:SetPoint("TOPLEFT", 4, -4)
imgPreviewTex:SetPoint("BOTTOMRIGHT", -4, 4)

-- Apply image button
local btnApplyImage = Button(pG, "Apply Image", CX + 380, CY - 548, 100, 22)

-- Reset image to default button
local btnResetImage = Button(pG, "Reset Default", CX + 380, CY - 574, 100, 22)

-- ============================================================
-- Debug
-- ============================================================
local pD = pages.Debug
local cbDebug = Check(pD, "Enable debug prints", CX, CY - 20)
local btnDump = Button(pD, "Run /customlustdump", CX, CY - 60, 200, 24)
local btnDumpAll = Button(pD, "Run /customlustdumpall", CX + 210, CY - 60, 220, 24)

Hint(pD,
  "If trigger doesn't fire:\n" ..
  "1) Pop Time Warp\n" ..
  "2) Run /customlustdump\n" ..
  "3) If still nothing: run /customlustdumpall and paste the lust lines\n",
  CX, CY - 98, 520
)

-- ============================================================
-- Tabs
-- ============================================================
TabButton("General", -14, "General")
TabButton("Debug",   -48, "Debug")

-- ============================================================
-- Controls enable/disable (sliders only)
-- ============================================================
local function SetControlsEnabled(editing)
  sizeSlider:SetEnabled(editing)
  alphaSlider:SetEnabled(editing)

  local a = editing and 1 or 0.35
  if sizeSlider.SetAlpha then sizeSlider:SetAlpha(a) end
  if alphaSlider.SetAlpha then alphaSlider:SetAlpha(a) end
end

-- Dim / enable every image-section control based on imageEnabled flag.
-- Called from RefreshAll and from the checkbox OnClick handler.
local function SetImageControlsEnabled(enabled)
  local a = enabled and 1.0 or 0.35
  imagePathBox:SetEnabled(enabled)
  imagePathBox:SetAlpha(a)
  btnApplyImage:SetEnabled(enabled)
  btnApplyImage:SetAlpha(a)
  btnResetImage:SetEnabled(enabled)
  btnResetImage:SetAlpha(a)
  imgPreviewBorder:SetAlpha(a)
end

-- ============================================================
-- Edit mode preview handling
-- ============================================================
local function EnterEditMode()
  CustomLustDB.locked = false
  if NS and NS.StartPreviewNoSound then NS.StartPreviewNoSound() end
  Print("Edit mode ON (drag image).")
end

local function ExitEditMode()
  CustomLustDB.locked = true
  if NS and NS.StopPreviewNoSound then NS.StopPreviewNoSound() end
  Print("Edit mode OFF (locked).")
end

-- ============================================================
-- Sound path helpers
-- ============================================================

-- Returns the addon-relative default prefix so users have a starting template
local function DefaultSoundPrefix()
  return "Interface\\AddOns\\CustomLust\\media\\"
end

-- Sanitise: strip leading/trailing whitespace, normalise forward-slashes to back
local function SanitisePath(raw)
  if not raw or raw == "" then return "" end
  raw = raw:match("^%s*(.-)%s*$") -- trim
  raw = raw:gsub("/", "\\")
  return raw
end

-- Validate that the path looks like something WoW can play
-- (non-empty, ends with mp3/ogg/wav, no path traversal)
local function ValidateSoundPath(path)
  if not path or path == "" then
    return false, "Path is empty."
  end
  if path:find("%.%.") then
    return false, "Path may not contain '..'."
  end
  if not path:match("%.[Mm][Pp]3$")
  and not path:match("%.[Oo][Gg][Gg]$")
  and not path:match("%.[Ww][Aa][Vv]$") then
    return false, "File must be .mp3, .ogg, or .wav."
  end
  return true, nil
end

-- ============================================================
-- Image path helpers
-- ============================================================

local DEFAULT_IMAGE_PATH = "Interface\\AddOns\\CustomLust\\media\\pedro.tga"

local function DefaultImagePrefix()
  return "Interface\\AddOns\\CustomLust\\media\\"
end

-- Validate that the path looks like something WoW can render as a texture
local function ValidateImagePath(path)
  if not path or path == "" then
    return false, "Path is empty."
  end
  if path:find("%.%.") then
    return false, "Path may not contain '..'."
  end
  if not path:match("%.[Tt][Gg][Aa]$")
  and not path:match("%.[Bb][Ll][Pp]$")
  and not path:match("%.[Pp][Nn][Gg]$") then
    return false, "File must be .tga, .blp, or .png."
  end
  return true, nil
end

-- Refresh the thumbnail in the options panel
local function RefreshImageThumbnail(path)
  if path and path ~= "" then
    imgPreviewTex:SetTexture(path)
    imgPreviewBorder:SetBackdropBorderColor(0.4, 0.4, 0.45, 0.9)
  else
    imgPreviewTex:SetTexture(nil)
  end
end

-- Commit whatever is in the image EditBox to the DB and live effect
local function CommitImagePath()
  local raw  = imagePathBox:GetText()
  local path = SanitisePath(raw)

  local ok, err = ValidateImagePath(path)
  if not ok then
    Print("Invalid image path: " .. (err or "unknown error"))
    return false
  end

  CustomLustDB.imagePath = path
  imagePathBox:SetText(path)
  RefreshImageThumbnail(path)
  Apply()  -- hot-reload the live effect texture immediately
  Print("Image path saved: " .. path)
  return true
end

-- ============================================================
-- Sound path helpers (commit)
-- ============================================================
local function CommitSoundPath()
  local raw  = soundPathBox:GetText()
  local path = SanitisePath(raw)

  local ok, err = ValidateSoundPath(path)
  if not ok then
    Print("Invalid sound path: " .. (err or "unknown error"))
    return false
  end

  CustomLustDB.soundPath = path
  soundPathBox:SetText(path) -- normalise display too
  Print("Sound path saved: " .. path)
  return true
end

-- ============================================================
-- Refresh
-- ============================================================
local function RefreshAll()
  cbEnabled:SetChecked(CustomLustDB.enabled and true or false)
  cbDebug:SetChecked(CustomLustDB.debug and true or false)

  if CustomLustDB.locked then
    btnEdit:SetText("Enter Edit Mode")
  else
    btnEdit:SetText("Exit Edit Mode")
  end

  local editing = not CustomLustDB.locked
  SetControlsEnabled(editing)

  lockedHint:SetShown(CustomLustDB.locked and true or false)
  editHint:SetShown(not CustomLustDB.locked and true or false)

  local s = tonumber(CustomLustDB.size) or 256
  sizeSlider:SetValue(s)

  local a = tonumber(CustomLustDB.alpha) or 1
  alphaSlider:SetValue(a)
  alphaValueText:SetText(("%d%%"):format(math.floor(a * 100 + 0.5)))

  -- Sound path
  local sp = CustomLustDB.soundPath or DefaultSoundPrefix()
  soundPathBox:SetText(sp)

  -- Channel dropdown
  local ch = CustomLustDB.soundChannel or "Master"
  UIDropDownMenu_SetSelectedValue(channelDropdown, ch)
  UIDropDownMenu_SetText(channelDropdown, ch)

  -- Image path
  local ip = CustomLustDB.imagePath or DefaultImagePrefix()
  imagePathBox:SetText(ip)
  RefreshImageThumbnail(ip)

  -- Image enabled checkbox + dim sub-controls accordingly
  local imgOn = (CustomLustDB.imageEnabled ~= false)  -- default true
  cbImageEnabled:SetChecked(imgOn)
  SetImageControlsEnabled(imgOn)

  Apply()
end

-- ============================================================
-- Wiring
-- ============================================================
cbEnabled:SetScript("OnClick", function(self)
  CustomLustDB.enabled = self:GetChecked() and true or false
  Print(CustomLustDB.enabled and "Enabled." or "Disabled.")
end)

btnEdit:SetScript("OnClick", function()
  if CustomLustDB.locked then
    EnterEditMode()
  else
    ExitEditMode()
  end
  RefreshAll()
end)

btnResetPos:SetScript("OnClick", function()
  CustomLustDB.pos = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
  Apply()
  Print("Position reset.")
end)

sizeSlider:SetScript("OnValueChanged", function(_, value)
  if CustomLustDB.locked then return end
  local v = Round(Clamp(value, 64, 512))
  CustomLustDB.size = v
  Apply()
end)

alphaSlider:SetScript("OnValueChanged", function(_, value)
  if CustomLustDB.locked then return end
  local v = tonumber(value) or 1
  if v < 0.10 then v = 0.10 end
  if v > 1.00 then v = 1.00 end
  CustomLustDB.alpha = v
  alphaValueText:SetText(("%d%%"):format(math.floor(v * 100 + 0.5)))
  Apply()
end)

btnPreview:SetScript("OnClick", function()
  if NS and NS.StartPreviewNoSound then
    NS.StartPreviewNoSound()
    C_Timer.After(10, function()
      if CustomLustDB.locked and NS and NS.StopPreviewNoSound then
        NS.StopPreviewNoSound()
      end
    end)
  else
    if NS and NS.StartEffect then NS.StartEffect({ silent = true }) end
    C_Timer.After(10, function() if NS and NS.StopEffect then NS.StopEffect() end end)
  end
end)

-- ---- Image enabled checkbox ----
cbImageEnabled:SetScript("OnClick", function(self)
  local enabled = self:GetChecked() and true or false
  CustomLustDB.imageEnabled = enabled
  SetImageControlsEnabled(enabled)
  Apply()
  Print(enabled and "Image overlay enabled." or "Image overlay disabled.")
end)

-- ---- Sound path box ----
-- Commit on Enter key
soundPathBox:SetScript("OnEnterPressed", function(self)
  self:ClearFocus()
  CommitSoundPath()
end)

-- Also commit when focus is lost so typing then clicking works naturally
soundPathBox:SetScript("OnEditFocusLost", function(self)
  self:SetBackdropBorderColor(0.4, 0.4, 0.45, 0.9)
  self:HighlightText(0, 0)
  CommitSoundPath()
end)

-- ---- Test sound button ----
btnTestSound:SetScript("OnClick", function()
  -- Commit whatever is typed first so we always test the live value
  CommitSoundPath()

  local path = CustomLustDB.soundPath or ""
  local ok, err = ValidateSoundPath(path)
  if not ok then
    Print("Cannot test: " .. (err or "invalid path"))
    return
  end

  local channel = CustomLustDB.soundChannel or "Master"

  local played, handle = PlaySoundFile(path, channel)

  if played then
    Print("Playing: " .. path .. " [" .. channel .. "]")
  else
    Print("PlaySoundFile failed – check the path is correct and the file exists in the media folder.")
  end

  C_Timer.After(10, function() StopSound(handle, 1000) end)
end)

-- ---- Image path box ----
imagePathBox:SetScript("OnEnterPressed", function(self)
  self:ClearFocus()
  CommitImagePath()
end)

imagePathBox:SetScript("OnEditFocusLost", function(self)
  self:SetBackdropBorderColor(0.4, 0.4, 0.45, 0.9)
  self:HighlightText(0, 0)
  CommitImagePath()
end)

-- ---- Apply image button ----
btnApplyImage:SetScript("OnClick", function()
  CommitImagePath()
end)

-- ---- Reset image to addon default ----
btnResetImage:SetScript("OnClick", function()
  CustomLustDB.imagePath = DEFAULT_IMAGE_PATH
  imagePathBox:SetText(DEFAULT_IMAGE_PATH)
  RefreshImageThumbnail(DEFAULT_IMAGE_PATH)
  Apply()
  Print("Image path reset to default.")
end)

cbDebug:SetScript("OnClick", function(self)
  CustomLustDB.debug = self:GetChecked() and true or false
  Print(CustomLustDB.debug and "Debug enabled." or "Debug disabled.")
end)

btnDump:SetScript("OnClick", function()
  if SlashCmdList and SlashCmdList.CUSTOMLUSTDUMP then
    SlashCmdList.CUSTOMLUSTDUMP()
  else
    Print("Dump command not available.")
  end
end)

btnDumpAll:SetScript("OnClick", function()
  if SlashCmdList and SlashCmdList.CUSTOMLUSTDUMPALL then
    SlashCmdList.CUSTOMLUSTDUMPALL()
  else
    Print("DumpAll command not available.")
  end
end)

-- ============================================================
-- Slash command
-- ============================================================
SLASH_CUSTOMLUST1 = "/customlust"
SLASH_CUSTOMLUST2 = "/CustomLust"
SLASH_CUSTOMLUST3 = "/cl"
SlashCmdList.CUSTOMLUST = function()
  if UI:IsShown() then
    UI:Hide()
    if CustomLustDB and not CustomLustDB.locked and NS and NS.StopPreviewNoSound then
      NS.StopPreviewNoSound()
    end
  else
    UI:ClearAllPoints()
    UI:SetPoint("CENTER")
    RefreshAll()
    UI:Show()
    if not activeTab then SetTab("General") end

    if CustomLustDB and not CustomLustDB.locked and NS and NS.StartPreviewNoSound then
      NS.StartPreviewNoSound()
    end
  end
end
