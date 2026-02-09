local A = FonzAppraiser
local L = A.locale

A.module 'fa.gui.gph'

local util = A.requires(
  'util.money',
  'util.time'
)
local gui = A.require 'fa.gui'
local session = A.require 'fa.session'

-- 1. Configuration Defaults
local defaults = {
  show = true,
  locked = false,
  point = "CENTER",
  relative = "UIParent",
  relativePoint = "CENTER",
  x = 0,
  y = 0,
}
A.registerCharConfigDefaults("fa.gui.gph", defaults)

-- 2. Module Local Variables
local frame
local value, value_session, value_time
local start_pause_button, stop_button, close_button, config_button
local update -- Forward declaration

-- 3. Local Helper: Safe Simple Button Factory
-- Completely self-contained to avoid dependencies on external factories
local function CreateSafeButton(parent, width, height, text, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(width)
    b:SetHeight(height)
    
    -- Background (Simulated)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(b)
    bg:SetTexture(0, 0, 0, 0.5)
    b.bg = bg
    
    -- Highlight
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetTexture(1, 1, 1, 0.2)
    b:SetHighlightTexture(hl)
    
    -- Text
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("CENTER", b, "CENTER", 0, 0)
    fs:SetText(text or "")
    b:SetFontString(fs)
    
    -- Visual Feedback
    b:SetScript("OnMouseDown", function()
        if b:IsEnabled() == 1 then 
            bg:SetTexture(0.5, 0.5, 0.5, 0.5)
            fs:SetPoint("CENTER", b, "CENTER", 1, -1)
        end
    end)
    
    b:SetScript("OnMouseUp", function()
        bg:SetTexture(0, 0, 0, 0.5)
        fs:SetPoint("CENTER", b, "CENTER", 0, 0)
    end)
    
    -- Click Handler
    b:SetScript("OnClick", function()
        if onClick then onClick() end
    end)
    
    return b
end

-- 4. Main HUD Frame Construction
do
    -- Create the main container frame
    frame = CreateFrame("Frame", "FonzAppraiserHUD", UIParent)
    M.frame = frame
    
    -- Basic Layout
    frame:SetWidth(120)
    frame:SetHeight(85)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG") -- High strata to float above standard UI
    frame:SetToplevel(true)
    
    -- Backdrop (Hardcoded for stability, independent of gui.styles)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    
    -- Drag Logic
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    
    frame:SetScript("OnDragStart", function()
        if not A.getCharConfig("fa.gui.gph").locked then
            this:StartMoving()
        end
    end)
    
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        -- Save position safely
        local db = A.getCharConfig("fa.gui.gph")
        if db then
            local point, relativeTo, relativePoint, x, y = this:GetPoint()
            db.point = point
            db.relative = "UIParent" -- Always relative to UIParent for consistency
            db.relativePoint = relativePoint
            db.x = x
            db.y = y
        end
    end)
    
    -- Prevent background clicks from doing anything weird
    frame:SetScript("OnMouseDown", function() end)
    frame:SetScript("OnMouseUp", function() end)

    -- Data Display Labels
    local function CreateRow(labelText, yOffset)
        local l = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        l:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, yOffset)
        l:SetText(labelText)
        
        local v = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        v:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, yOffset)
        v:SetJustifyH("RIGHT")
        return v
    end
    
    value = CreateRow(L["Per Hour:"] or "Per Hour:", -12)
    M.value = value
    
    value_session = CreateRow(L["Session:"] or "Session:", -27)
    M.value_session = value_session
    
    value_time = CreateRow(L["Duration:"] or "Duration:", -42)
    M.value_time = value_time
    
    -- Value Update Methods
    value.updateDisplay = function(self, v) 
        self:SetText(v and util.formatMoneyFull(v, true, nil, true) or "-") 
    end
    value_session.updateDisplay = function(self, v) 
        self:SetText(v and util.formatMoneyFull(v, true, nil, true) or "-") 
    end
    value_time.updateDisplay = function(self, v) 
        self:SetText(v and util.formatDurationFull(v) or "-") 
    end
    
    -- Control Buttons
    -- Start/Pause (>)
    start_pause_button = CreateSafeButton(frame, 20, 20, ">", function()
        if not session.isCurrent() then
            session.startSessionConfirm()
        elseif session.isPaused() then
            session.resumeSession()
        else
            session.pauseSession()
        end
    end)
    start_pause_button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
    M.start_pause_button = start_pause_button
    
    -- Stop (S)
    stop_button = CreateSafeButton(frame, 20, 20, "S", function()
        session.stopSession()
    end)
    stop_button:SetPoint("LEFT", start_pause_button, "RIGHT", 4, 0)
    M.stop_button = stop_button
    
    -- Config (O)
    config_button = CreateSafeButton(frame, 20, 20, "O", function()
        A.toggleMainWindow()
    end)
    config_button:SetPoint("LEFT", stop_button, "RIGHT", 4, 0)
    M.config_button = config_button
    
    -- Close (X)
    close_button = CreateSafeButton(frame, 20, 20, "X", function()
        local db = A.getCharConfig("fa.gui.gph")
        if db then db.show = false end
        update()
    end)
    close_button:SetPoint("LEFT", config_button, "RIGHT", 4, 0)
    M.close_button = close_button
    
    -- Tooltip Handlers
    local function SetTooltip(btn, getMsg)
        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(getMsg())
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    
    SetTooltip(start_pause_button, function()
        local t = start_pause_button:GetText()
        if t == ">" then return L["Start Session"]
        elseif t == "P" then return L["Pause Session"]
        else return L["Resume Session"] end
    end)
    SetTooltip(stop_button, function() return L["Stop Session"] end)
    SetTooltip(config_button, function() return L["Open Configuration"] end)
    SetTooltip(close_button, function() return L["Hide HUD"] end)
end

-- 5. Update Function
update = function()
    local db = A.getCharConfig("fa.gui.gph")
    if not db then return end
    
    if db.show then
        frame:Show()
        -- Restore position if available
        if db.point then
            frame:ClearAllPoints()
            frame:SetPoint(db.point, db.relative or "UIParent", db.relativePoint or "CENTER", db.x or 0, db.y or 0)
        end
    else
        frame:Hide()
    end
    
    -- Update Data
    if value then value:updateDisplay(session.getCurrentPerHourValue()) end
    if value_session then value_session:updateDisplay(session.getCurrentTotalValue()) end
    
    -- Update Duration
    local currentSession = session.getCurrentSession()
    local duration = 0
    if currentSession then
         -- Using session.sessionDuration logic locally if needed, but assuming session module handles it
         -- We need to check if session.sessionDuration exists, otherwise implement simple calc
         if session.sessionDuration then
             duration = session.sessionDuration(currentSession)
         end
    end
    if value_time then value_time:updateDisplay(duration) end
    
    -- Update Button State
    if start_pause_button then
        if session.isPaused() then
            start_pause_button:SetText("R")
        elseif session.isCurrent() then
            start_pause_button:SetText("P")
        else
            start_pause_button:SetText(">")
        end
    end
end

M.update = update
M.applySettings = update -- Added to fix core.lua dependency
