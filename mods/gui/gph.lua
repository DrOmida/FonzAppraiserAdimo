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

do
  local frame = CreateFrame("Frame", "FonzAppraiserGphFrame", UIParent)
  M.frame = frame
  gui.styles["panel"](frame)
  gui.setSize(frame, 200, 80)
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
  label:SetPoint("TOPLEFT", frame, 8, -8)
  label:SetText(L["Hourly:"])
  
  local value = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  M.value = value
  value:SetPoint("TOPRIGHT", frame, -8, -8)
  value:SetJustifyH("RIGHT")
  value.updateDisplay = function(self, v)
    v = v and util.formatMoneyFull(v, true, nil, true) or "-"
    self:SetText(v)
  end

  local label_session = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  label_session:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
  label_session:SetText(L["Session:"])
  
  local value_session = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  M.value_session = value_session
  value_session:SetPoint("TOPRIGHT", value, "BOTTOMRIGHT", 0, -4)
  value_session:SetJustifyH("RIGHT")
  value_session.updateDisplay = function(self, v)
    v = v and util.formatMoneyFull(v, true, nil, true) or "-"
    self:SetText(v)
  end
end

do
  local start_pause_button = gui.button(frame, nil, 90, 20, 
    L["Start Session"])
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
  
  local stop_button = gui.button(frame, nil, 90, 20, L["Stop Session"])
  M.stop_button = stop_button
  stop_button:SetPoint("BOTTOMRIGHT", frame, -6, 6)
  stop_button.onClick = function()
    session.stopSession()
  end
end

do
  local elapsed = 0
  
  frame:SetScript("OnUpdate", function()
    elapsed = elapsed + arg1
    if elapsed >= 1 then
      elapsed = 0
      if frame:IsVisible() then
        M.update()
      end
    end
  end)
end

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
  M.update()
end

function M.toggleWindow()
  local db = A.getCharConfig("fa.gui.gph")
  db.show = not db.show
  M.update()
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

function M.update()
  local db = A.getCharConfig("fa.gui.gph")
  if db.show then
    frame:Show()
  else
    frame:Hide()
  end
  
  value:updateDisplay(session.getCurrentPerHourValue())
  value_session:updateDisplay(session.getCurrentTotalValue())
  
  if not session.isCurrent() then
    start_pause_button:SetText(L["Start Session"])
    stop_button:Disable()
  elseif session.isPaused() then
    start_pause_button:SetText(L["Resume Session"])
    stop_button:Enable()
  else
    start_pause_button:SetText(L["Pause Session"])
    stop_button:Enable()
  end
end
