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
    color = { 1, 0.35, 0.35 },
  },
  [state.MISSING] = {
    icon = ICON_MISSING,
    text = 'Pet missing',
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
