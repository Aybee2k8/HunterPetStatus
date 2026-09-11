local _, ns = ...

-- The settings panel.
--
-- The widgets are built from bare frame primitives rather than named Blizzard
-- templates. Template names and their child-widget layouts churn between
-- expansions, and a missing template is a hard error at construction time --
-- which, for a settings panel, would take the whole addon down with it. The
-- primitives used here (CheckButton art, Slider thumbs, UIPanelButtonTemplate)
-- have been stable for many expansions.
--
-- The same content frame is used for both hosts: it is parented into the
-- Settings category when the client offers one, and into a standalone window
-- when it does not. Only the host differs, never the widgets.

local options = {}
ns.options = options

local PANEL_WIDTH = 560
local PADDING = 16

local api      -- callbacks supplied by Core
local content  -- the frame holding every widget
local window   -- standalone fallback host, built on demand
local category -- Settings category ID, if registration succeeded
local widgets = {}

--------------------------------------------------------------------------------
-- Widget helpers
--------------------------------------------------------------------------------

local function heading(parent, text, anchor, gap)
  local font = parent:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
  font:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -(gap or 16))
  font:SetText(text)
  return font
end

local function description(parent, text, anchor, gap)
  local font = parent:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
  font:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -(gap or 4))
  font:SetPoint('RIGHT', parent, 'RIGHT', -PADDING, 0)
  font:SetJustifyH('LEFT')
  font:SetText(text)
  return font
end

local function checkbox(parent, label, anchor, gap, onToggle)
  local button = CreateFrame('CheckButton', nil, parent, 'UICheckButtonTemplate')
  button:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -(gap or 10))
  button:SetSize(26, 26)

  -- The template's own label is reached differently across expansions, so the
  -- text is ours.
  local text = button:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
  text:SetPoint('LEFT', button, 'RIGHT', 4, 0)
  text:SetText(label)

  button:SetScript('OnClick', function(self)
    onToggle(self:GetChecked() and true or false)
  end)

  return button
end

-- A row of buttons behaving as a radio group. Used instead of a dropdown: the
-- dropdown API has been rewritten more than once, and three options do not
-- justify the risk.
local function radioRow(parent, choices, anchor, gap, onSelect)
  local buttons = {}
  local previous

  for index = 1, #choices do
    local choice = choices[index]
    local button = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
    button:SetSize(90, 22)
    button:SetText(choice.label)

    if previous then
      button:SetPoint('LEFT', previous, 'RIGHT', 6, 0)
    else
      button:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -(gap or 10))
    end

    button:SetScript('OnClick', function()
      onSelect(choice.value)
    end)

    buttons[choice.value] = button
    previous = button
  end

  -- Marks the active choice by colouring its label; the button stays clickable
  -- so a stale visual can always be corrected by clicking again.
  local function select(value)
    for key, button in pairs(buttons) do
      local font = button:GetFontString()
      if key == value then
        font:SetTextColor(1, 0.82, 0)
      else
        font:SetTextColor(1, 1, 1)
      end
    end
  end

  return { buttons = buttons, Select = select, last = previous }
end

local function slider(parent, anchor, gap, minimum, maximum, step, onChange)
  local frame = CreateFrame('Slider', nil, parent)
  frame:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -(gap or 22))
  frame:SetSize(240, 16)
  frame:SetOrientation('HORIZONTAL')
  frame:SetMinMaxValues(minimum, maximum)
  frame:SetValueStep(step)
  frame:SetThumbTexture('Interface\\Buttons\\UI-SliderBar-Button-Horizontal')
  pcall(frame.SetObeyStepOnDrag, frame, true)

  local track = frame:CreateTexture(nil, 'BACKGROUND')
  track:SetColorTexture(0, 0, 0, 0.5)
  track:SetPoint('LEFT')
  track:SetPoint('RIGHT')
  track:SetHeight(4)

  local value = frame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
  value:SetPoint('LEFT', frame, 'RIGHT', 12, 0)

  frame.valueText = value

  frame:SetScript('OnValueChanged', function(self, newValue, byUser)
    value:SetText(('%.2f'):format(newValue))
    if byUser then
      onChange(newValue)
    end
  end)

  return frame
end

local function actionButton(parent, label, width, anchor, point, relativePoint, x, y, onClick)
  local button = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
  button:SetSize(width, 22)
  button:SetPoint(point, anchor, relativePoint, x, y)
  button:SetText(label)
  button:SetScript('OnClick', onClick)
  return button
end

--------------------------------------------------------------------------------
-- Content
--------------------------------------------------------------------------------

local function build()
  content = CreateFrame('Frame', nil, UIParent)
  content:SetSize(PANEL_WIDTH, 360)
  content:Hide()

  local title = content:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
  title:SetPoint('TOPLEFT', PADDING, -PADDING)
  title:SetText('PetWatch')

  local subtitle = description(content, 'Shows an indicator when your hunter pet is missing or dead.', title, 6)

  widgets.enabled = checkbox(content, 'Enable PetWatch', subtitle, 14, function(checked)
    api.SetEnabled(checked)
  end)

  widgets.hideMounted = checkbox(content, 'Hide while mounted', widgets.enabled, 4, function(checked)
    api.SetHideMounted(checked)
  end)

  local displayHeading = heading(content, 'Display', widgets.hideMounted, 16)
  description(content, 'What the indicator shows.', displayHeading, 2)

  widgets.display = radioRow(content, {
    { value = 'icon', label = 'Icon' },
    { value = 'text', label = 'Text' },
    { value = 'both', label = 'Both' },
  }, displayHeading, 30, function(mode)
    api.SetDisplayMode(mode)
    widgets.display.Select(mode)
  end)

  local sizeHeading = heading(content, 'Size', widgets.display.buttons.icon, 20)

  widgets.scale = slider(content, sizeHeading, 22, 0.3, 4.0, 0.05, function(value)
    api.SetScale(value)
  end)

  widgets.move = actionButton(content, 'Move indicator', 130,
    widgets.scale, 'TOPLEFT', 'BOTTOMLEFT', 0, -28, function()
      api.ToggleUnlocked()
      options.Refresh()
    end)

  actionButton(content, 'Reset to defaults', 130,
    widgets.move, 'LEFT', 'RIGHT', 8, 0, function()
      api.Reset()
      options.Refresh()
    end)

  actionButton(content, 'Report API support', 140,
    widgets.move, 'TOPLEFT', 'BOTTOMLEFT', 0, -8, function()
      api.Diagnostics()
    end)

  description(content,
    'Report API support prints what this client supports to chat. Run it after a '
    .. 'game patch, and include it in a bug report.',
    widgets.move, 38)

  content:SetScript('OnShow', options.Refresh)

  return content
end

--------------------------------------------------------------------------------
-- Hosts
--------------------------------------------------------------------------------

-- Registers the panel with the client's own settings UI. Returns the category
-- ID, or nil if this client does not offer the API.
local function registerWithSettings()
  if type(Settings) ~= 'table'
    or type(Settings.RegisterCanvasLayoutCategory) ~= 'function'
    or type(Settings.RegisterAddOnCategory) ~= 'function' then
    return nil
  end

  local ok, result = pcall(Settings.RegisterCanvasLayoutCategory, content, 'PetWatch')
  if not ok or not result then
    return nil
  end

  -- Older signatures return the category object; newer ones carry the ID on it.
  result.ID = result.ID or 'PetWatch'

  if not pcall(Settings.RegisterAddOnCategory, result) then
    return nil
  end

  return result
end

-- Standalone window, used when the client has no settings UI to register with.
local function buildWindow()
  window = CreateFrame('Frame', 'PetWatchOptionsFrame', UIParent, 'BackdropTemplate')
  window:SetSize(PANEL_WIDTH, 380)
  window:SetPoint('CENTER')
  window:SetFrameStrata('DIALOG')
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag('LeftButton')
  window:SetScript('OnDragStart', window.StartMoving)
  window:SetScript('OnDragStop', window.StopMovingOrSizing)
  window:SetBackdrop({
    bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
    edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border',
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  window:Hide()

  local close = CreateFrame('Button', nil, window, 'UIPanelCloseButton')
  close:SetPoint('TOPRIGHT', -4, -4)

  content:SetParent(window)
  content:ClearAllPoints()
  content:SetPoint('TOPLEFT')
  content:Show()

  -- Let Escape close it, the same as any other addon window.
  if type(UISpecialFrames) == 'table' then
    UISpecialFrames[#UISpecialFrames + 1] = 'PetWatchOptionsFrame'
  end

  return window
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function options.Create(callbacks)
  api = callbacks
  build()
  category = registerWithSettings()

  if not category then
    buildWindow()
  end

  return category ~= nil
end

-- Pushes the current saved settings into the widgets. Called whenever the panel
-- is shown and after any action that changes several values at once, so the
-- panel can never drift from what the addon is actually doing.
function options.Refresh()
  if not content or not api then
    return
  end

  local settings = api.Snapshot()

  widgets.enabled:SetChecked(settings.enabled)
  widgets.hideMounted:SetChecked(settings.hideMounted)
  widgets.display.Select(settings.displayMode)
  widgets.scale:SetValue(settings.scale)
  widgets.scale.valueText:SetText(('%.2f'):format(settings.scale))
  widgets.move:SetText(settings.unlocked and 'Lock indicator' or 'Move indicator')
end

-- Opens the panel, wherever it ended up living.
function options.Open()
  if category then
    if pcall(Settings.OpenToCategory, category:GetID()) then
      return true
    end
    if pcall(Settings.OpenToCategory, category.ID) then
      return true
    end
    return false
  end

  if window then
    options.Refresh()
    window:Show()
    return true
  end

  return false
end
