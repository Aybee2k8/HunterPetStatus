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

-- The fonts offered in the settings. Shipping none of our own keeps the addon
-- dependency-free; these paths are the client's own and have been stable for
-- many expansions. 'default' is whatever the font object came with, captured at
-- creation -- locales that do not use a Latin font get theirs without a special
-- case.
local FONT_PATHS = {
  arial = 'Fonts\\ARIALN.TTF',
  skurri = 'Fonts\\skurri.ttf',
  morpheus = 'Fonts\\MORPHEUS.TTF',
}

display.FONTS = { 'default', 'arial', 'skurri', 'morpheus' }

local defaultFontPath

function display.CreateAlert()
  if alert then
    return alert
  end

  alert = CreateFrame('Frame', nil, UIParent)
  alert:SetSize(400, 60)
  alert:SetFrameStrata('HIGH')
  alert:SetMovable(true)
  alert:EnableMouse(false)
  alert:RegisterForDrag('LeftButton')
  alert:Hide()

  alertLabel = bigFontString(alert)
  alertLabel:SetPoint('CENTER')

  defaultFontPath = alertLabel:GetFont()

  return alert
end

-- Places the alert. Defaults to above centre: the middle of the screen is where
-- the character stands, and covering that is how a fight is lost rather than
-- won.
function display.ApplyAlertPosition(point)
  if not alert then
    return
  end

  point = point or {}
  alert:ClearAllPoints()
  alert:SetPoint(point[1] or 'CENTER', UIParent, point[3] or 'CENTER',
    point[4] or 0, point[5] or 160)
end

-- Applies font, size and colour. Returns false if the requested font was
-- refused, having fallen back to the default -- the caller reports that rather
-- than leaving someone with invisible text and no explanation.
function display.ApplyAlertStyle(font, size, color)
  if not alertLabel then
    return false
  end

  local path = FONT_PATHS[font] or defaultFontPath
  local _, _, flags = alertLabel:GetFont()

  local applied = alertLabel:SetFont(path, size, flags or 'OUTLINE')
  if not applied and path ~= defaultFontPath then
    alertLabel:SetFont(defaultFontPath, size, flags or 'OUTLINE')
  end

  if color then
    alertLabel:SetTextColor(color[1], color[2], color[3])
  end

  return applied and true or false
end

-- Shows the alert permanently with sample text so it can be dragged, and makes
-- it draggable. The alert is only ever on screen for a moment, so there would
-- otherwise be nothing to grab.
function display.SetAlertUnlocked(unlocked, onMoved)
  if not alert then
    return
  end

  alert:EnableMouse(unlocked)

  alert:SetScript('OnDragStart', unlocked and function(self)
    if compat.InCombatLockdown() then
      return
    end
    self:StartMoving()
  end or nil)

  alert:SetScript('OnDragStop', unlocked and function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    onMoved({ point, 'UIParent', relativePoint, math.floor(x + 0.5), math.floor(y + 0.5) })
  end or nil)

  if unlocked then
    alert:SetScript('OnUpdate', nil)
    alertLabel:SetText('Pet Missing!')
    alert:SetAlpha(1)
    alert:Show()
  else
    alert:Hide()
  end
end

-- Flashes the alert for the given state. Does nothing for states that need no
-- action, so callers do not have to filter.
function display.Flash(current)
  local appearance = APPEARANCE[current]

  if not alert or not appearance or not appearance.alert then
    return false
  end

  -- The text is per state; the colour is the user's, set by ApplyAlertStyle.
  alertLabel:SetText(appearance.alert)

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
