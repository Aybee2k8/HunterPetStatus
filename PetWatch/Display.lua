local _, ns = ...

local state = ns.state
local compat = ns.compat

local display = {}
ns.display = display

local ICON_DEAD = 132163    -- Ability_Hunter_BeastSoothe
local ICON_MISSING = 132179 -- Ability_Hunter_MendPet

local APPEARANCE = {
  [state.DEAD] = {
    icon = ICON_DEAD,
    text = 'Pet dead',
    alert = 'Pet Dead!',
    color = { 1, 0.35, 0.35 },
  },
  [state.MISSING] = {
    icon = ICON_MISSING,
    text = 'Pet missing',
    alert = 'Pet Missing!',
    color = { 1, 0.82, 0.25 },
  },
}

local frame, texture, label

function display.Create()
  if frame then
    return frame
  end

  -- BackdropTemplate is what supplies SetBackdrop, used by the unlocked mode.
  frame = CreateFrame('Frame', 'PetWatchFrame', UIParent, 'BackdropTemplate')
  frame:SetSize(36, 36)
  frame:SetMovable(true)
  frame:EnableMouse(false)
  frame:RegisterForDrag('LeftButton')
  frame:Hide()

  texture = frame:CreateTexture(nil, 'ARTWORK')
  texture:SetAllPoints(frame)

  label = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
  label:SetJustifyH('CENTER')

  return frame
end

function display.Frame()
  return frame
end

function display.ApplyScale(scale)
  frame:SetScale(scale)
end

function display.ApplyPosition(point)
  frame:ClearAllPoints()
  frame:SetPoint(point[1] or 'CENTER', UIParent, point[3] or 'CENTER', point[4] or 0, point[5] or 0)
end

-- Positions the icon and the caption relative to each other for the given mode.
local function layout(mode)
  label:ClearAllPoints()

  if mode == 'text' then
    texture:Hide()
    label:Show()
    label:SetPoint('CENTER', frame, 'CENTER', 0, 0)
    return
  end

  texture:Show()
  label:SetShown(mode ~= 'icon')
  label:SetPoint('TOP', frame, 'BOTTOM', 0, -2)
end

function display.Update(current, mode)
  local appearance = APPEARANCE[current]

  if not appearance then
    frame:Hide()
    return
  end

  texture:SetTexture(appearance.icon)
  label:SetText(appearance.text)
  label:SetTextColor(appearance.color[1], appearance.color[2], appearance.color[3])
  layout(mode)
  frame:Show()
end

--------------------------------------------------------------------------------
-- Centre-screen alert
--------------------------------------------------------------------------------

-- A brief flash near the middle of the screen when the pet's state changes to
-- something that needs action. The persistent indicator is easy to miss in a
-- busy fight; this is the part you cannot miss, which is also why it fades
-- instead of staying.

local alert, alertLabel

local ALERT_HOLD = 1.5   -- seconds at full opacity
local ALERT_FADE = 1.25  -- seconds fading out

-- The huge font object has been around for many expansions, but a missing font
-- object is a hard error at construction, and this runs during setup.
local function bigFontString(parent)
  local ok, font = pcall(parent.CreateFontString, parent, nil, 'OVERLAY', 'GameFontNormalHuge')
  if ok and font then
    return font
  end

  return parent:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
end

function display.CreateAlert()
  if alert then
    return alert
  end

  alert = CreateFrame('Frame', nil, UIParent)
  alert:SetSize(1, 1)
  -- Above centre: the middle of the screen is where the character stands, and
  -- covering that is how you lose a fight rather than win one.
  alert:SetPoint('CENTER', UIParent, 'CENTER', 0, 160)
  alert:SetFrameStrata('HIGH')
  alert:Hide()

  alertLabel = bigFontString(alert)
  alertLabel:SetPoint('CENTER')

  return alert
end

-- Flashes the alert for the given state. Does nothing for states that need no
-- action, so callers do not have to filter.
function display.Flash(current)
  local appearance = APPEARANCE[current]

  if not alert or not appearance or not appearance.alert then
    return false
  end

  alertLabel:SetText(appearance.alert)
  alertLabel:SetTextColor(appearance.color[1], appearance.color[2], appearance.color[3])

  alert.elapsed = 0
  alert:SetAlpha(1)
  alert:Show()

  -- Driven by OnUpdate rather than an animation group: one less API surface to
  -- be wrong about, and the timing is trivial.
  alert:SetScript('OnUpdate', function(self, delta)
    self.elapsed = self.elapsed + delta

    if self.elapsed <= ALERT_HOLD then
      return
    end

    local remaining = 1 - (self.elapsed - ALERT_HOLD) / ALERT_FADE
    if remaining <= 0 then
      self:SetScript('OnUpdate', nil)
      self:Hide()
      return
    end

    self:SetAlpha(remaining)
  end)

  return true
end

function display.SetUnlocked(unlocked, onMoved)
  frame:EnableMouse(unlocked)

  -- Visibility is not decided here. Unlocking only adds the drag affordance;
  -- what the indicator shows -- including having something to drag at all --
  -- comes from the preview state Core drives through Update.
  if unlocked then
    frame:SetBackdrop({ bgFile = 'Interface\\Buttons\\WHITE8x8' })
    frame:SetBackdropColor(0, 0, 0, 0.35)
  else
    frame:SetBackdrop(nil)
  end

  frame:SetScript('OnDragStart', unlocked and function(self)
    if compat.InCombatLockdown() then
      return
    end
    self:StartMoving()
  end or nil)

  frame:SetScript('OnDragStop', unlocked and function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    onMoved({ point, 'UIParent', relativePoint, math.floor(x + 0.5), math.floor(y + 0.5) })
  end or nil)
end
