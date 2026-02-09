local A = FonzAppraiser
local L = A.locale

A.module 'fa.gui.gph'

local util = A.require 'util.money'
local gui = A.require 'fa.gui'
local session = A.require 'fa.session'

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

-- File-scope locals for internal access (bypassing module proxy)
local frame
local value, value_session
local start_pause_button, stop_button
local close_button
local update -- Forward declaration

do
  frame = CreateFrame("Frame", "FonzAppraiserGphFrame", UIParent)
  M.frame = frame
  gui.styles["panel"](frame)
  gui.setSize(frame, 130, 70) -- Reduced width and height
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetFrameStrata("LOW")
  
  frame:SetScript("OnDragStart", function()
    local db = A.getCharConfig("fa.gui.gph")
    if not db.locked then
      this:StartMoving()
    end
  end)
  frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local db = A.getCharConfig("fa.gui.gph")
    local point, relativeTo, relativePoint, x, y = this:GetPoint(1)
    db.point = point
    db.relative = relativeTo and relativeTo:GetName() or "UIParent"
    db.relativePoint = relativePoint
    db.x = x
    db.y = y
  end)
end

do
  local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  label:SetPoint("TOPLEFT", frame, 6, -6)
  label:SetText(L["Hr:"])
  
  value = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  M.value = value
  value:SetPoint("TOPRIGHT", frame, -6, -6)
  value:SetJustifyH("RIGHT")
  value.updateDisplay = function(self, v)
    v = v and util.formatMoneyFull(v, true, nil, true) or "-"
    self:SetText(v)
  end

  local label_session = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  label_session:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
  label_session:SetText(L["Ses:"])
  
  value_session = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  M.value_session = value_session
  value_session:SetPoint("TOPRIGHT", value, "BOTTOMRIGHT", 0, -2)
  value_session:SetJustifyH("RIGHT")
  value_session.updateDisplay = function(self, v)
    v = v and util.formatMoneyFull(v, true, nil, true) or "-"
    self:SetText(v)
  end
end

do
  -- Start/Pause Button (P)
  start_pause_button = gui.button(frame, nil, 20, 20, "Start")
  M.start_pause_button = start_pause_button
  start_pause_button:SetPoint("BOTTOMLEFT", frame, 6, 6)
  start_pause_button.onClick = function()
    if not session.isCurrent() then
      session.startSessionConfirm()
    elseif session.isPaused() then
      session.resumeSession()
    else
      session.pauseSession()
    end
  end
  start_pause_button:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    local text = this:GetText()
    if text == "Start" or text == ">" then
        GameTooltip:SetText(L["Start Session"])
    elseif text == "P" then
        GameTooltip:SetText(L["Pause Session"])
    elseif text == "R" then
        GameTooltip:SetText(L["Resume Session"])
    end
    GameTooltip:Show()
  end)
  start_pause_button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  
  -- Stop Button (S)
  stop_button = gui.button(frame, nil, 20, 20, "S")
  M.stop_button = stop_button
  stop_button:SetPoint("LEFT", start_pause_button, "RIGHT", 2, 0)
  stop_button.onClick = function()
    session.stopSession()
  end
  stop_button:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Stop Session"])
    GameTooltip:Show()
  end)
  stop_button:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Close button (X)
  close_button = gui.button(frame, nil, 20, 20, "X")
  close_button:SetPoint("LEFT", stop_button, "RIGHT", 2, 0)
  close_button.onClick = function()
    local db = A.getCharConfig("fa.gui.gph")
    db.show = false
    update()
  end
  close_button:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Hide HUD"])
    GameTooltip:Show()
  end)
  close_button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Define update function locally first
update = function()
  local db = A.getCharConfig("fa.gui.gph")
  if db.show then
    frame:Show()
  else
    frame:Hide()
  end
  
  value:updateDisplay(session.getCurrentPerHourValue())
  value_session:updateDisplay(session.getCurrentTotalValue())
  
  if not session.isCurrent() then
    start_pause_button:SetText(">")
    stop_button:Disable()
  elseif session.isPaused() then
    start_pause_button:SetText("R")
    stop_button:Enable()
  else
    start_pause_button:SetText("P")
    stop_button:Enable()
  end
end
M.update = update

function M.applySettings()
  local db = A.getCharConfig("fa.gui.gph")
  frame:ClearAllPoints()
  local relative = _G[db.relative] or UIParent
  frame:SetPoint(db.point or "CENTER", relative, 
    db.relativePoint or "CENTER", db.x or 0, db.y or 0)
  if db.show then
    frame:Show()
  else
    frame:Hide()
  end
  update()
end

function M.toggleWindow()
  local db = A.getCharConfig("fa.gui.gph")
  db.show = not db.show
  update()
end

function M.showWindow()
  local db = A.getCharConfig("fa.gui.gph")
  db.show = true
  update()
end

function M.hideWindow()
  local db = A.getCharConfig("fa.gui.gph")
  db.show = false
  update()
end

function M.toggleLock()
  local db = A.getCharConfig("fa.gui.gph")
  db.locked = not db.locked
  if db.locked then
    A.info(L["GPH HUD locked."])
  else
    A.info(L["GPH HUD unlocked."])
  end
end

do
  local elapsed = 0
  
  frame:SetScript("OnUpdate", function()
    elapsed = elapsed + arg1
    if elapsed >= 1 then
      elapsed = 0
      if frame:IsVisible() then
        update() -- Call local update function
      end
    end
  end)
end
