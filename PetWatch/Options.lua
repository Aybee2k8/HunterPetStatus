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

local PANEL_WIDTH = 720
local COLUMN_TWO = 380
local PADDING = 16

-- Mirrors display.FONTS; kept here because only the panel needs the labels.
local FONT_LABELS = {
  { value = 'default', label = 'Default' },
  { value = 'arial', label = 'Arial' },
  { value = 'skurri', label = 'Skurri' },
  { value = 'morpheus', label = 'Morpheus' },
}

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

local function description(parent, text, anchor, gap, width)
  local font = parent:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
  font:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -(gap or 4))
  if width then
    font:SetWidth(width)
  else
    font:SetPoint('RIGHT', parent, 'RIGHT', -PADDING, 0)
  end
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
local function radioRow(parent, choices, anchor, gap, onSelect, width)
  local buttons = {}
  local previous

  for index = 1, #choices do
    local choice = choices[index]
    local button = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
    button:SetSize(width or 90, 22)
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

-- A labelled slider for the second column: the existing slider() anchors below
-- its anchor, which is all the first column needs.
local function labelledSlider(parent, text, anchor, gap, minimum, maximum, step, format, onChange)
  local caption = parent:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
  caption:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -(gap or 16))
  caption:SetText(text)

  local frame = CreateFrame('Slider', nil, parent)
  frame:SetPoint('TOPLEFT', caption, 'BOTTOMLEFT', 0, -8)
  frame:SetSize(200, 16)
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
    value:SetText(format:format(newValue))
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
  content:SetSize(PANEL_WIDTH, 470)
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

  widgets.alert = checkbox(content, 'Flash a warning in the middle of the screen',
    widgets.hideMounted, 4, function(checked)
      api.SetAlert(checked)
    end)

  local displayHeading = heading(content, 'Display', widgets.alert, 16)
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

  local previewHeading = heading(content, 'Preview', widgets.scale, 26)
  description(content,
    'Shows the indicator without waiting for the pet to die. Closes this panel '
    .. 'so you can see it. Not saved -- it ends when you zone or reload.',
    previewHeading, 2)

  widgets.preview = radioRow(content, {
    { value = 'dead', label = 'Dead' },
    { value = 'missing', label = 'Missing' },
    { value = 'off', label = 'Off' },
  }, previewHeading, 34, function(mode)
    api.SetPreview(mode)
    options.Refresh()

    -- Nothing to look at while the panel is covering it.
    if mode ~= 'off' then
      options.Close()
    end
  end)

  widgets.move = actionButton(content, 'Move indicator', 130,
    widgets.preview.buttons.dead, 'TOPLEFT', 'BOTTOMLEFT', 0, -22, function()
      api.ToggleUnlocked()
      options.Refresh()

      -- Unlocking turns the preview on, so there is something to drag; the
      -- panel has to get out of the way for that to be usable.
      if api.Snapshot().unlocked then
        options.Close()
      end
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

  ------------------------------------------------------------------------------
  -- Second column: how the alert looks
  ------------------------------------------------------------------------------
  -- A second column rather than a longer page: a canvas settings category does
  -- not scroll, so anything past the bottom is simply unreachable.

  local alertHeading = content:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
  alertHeading:SetPoint('TOPLEFT', content, 'TOPLEFT', COLUMN_TWO, -PADDING)
  alertHeading:SetText('Alert appearance')

  description(content,
    'How the centre-screen warning looks. Move it, then preview to see it.',
    alertHeading, 4, PANEL_WIDTH - COLUMN_TWO - PADDING)

  local fontHeading = content:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
  fontHeading:SetPoint('TOPLEFT', alertHeading, 'BOTTOMLEFT', 0, -34)
  fontHeading:SetText('Font')

  local fontChoices = {}
  for index = 1, #FONT_LABELS do
    fontChoices[index] = FONT_LABELS[index]
  end

  widgets.alertFont = radioRow(content, fontChoices, fontHeading, 8, function(font)
    api.SetAlertFont(font)
    options.Refresh()
  end, 76)

  widgets.alertSize = labelledSlider(content, 'Size', widgets.alertFont.buttons.default, 16,
    12, 72, 1, '%d', function(value)
      api.SetAlertSize(value)
    end)

  widgets.alertRed = labelledSlider(content, 'Red', widgets.alertSize, 18, 0, 1, 0.05, '%.2f',
    function(value)
      api.SetAlertColor(value, widgets.alertGreen:GetValue(), widgets.alertBlue:GetValue())
    end)

  widgets.alertGreen = labelledSlider(content, 'Green', widgets.alertRed, 12, 0, 1, 0.05, '%.2f',
    function(value)
      api.SetAlertColor(widgets.alertRed:GetValue(), value, widgets.alertBlue:GetValue())
    end)

  widgets.alertBlue = labelledSlider(content, 'Blue', widgets.alertGreen, 12, 0, 1, 0.05, '%.2f',
    function(value)
      api.SetAlertColor(widgets.alertRed:GetValue(), widgets.alertGreen:GetValue(), value)
    end)

  widgets.alertMove = actionButton(content, 'Move alert', 130,
    widgets.alertBlue, 'TOPLEFT', 'BOTTOMLEFT', 0, -26, function()
      api.ToggleAlertUnlocked()
      options.Refresh()

      -- Same reason as the indicator: the panel covers the thing being placed.
      if api.Snapshot().alertUnlocked then
        options.Close()
      end
    end)

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
  window:SetSize(PANEL_WIDTH, 490)
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
  widgets.alert:SetChecked(settings.alert)
  widgets.alertFont.Select(settings.alertFont)
  widgets.alertSize:SetValue(settings.alertSize)
  widgets.alertSize.valueText:SetText(('%d'):format(settings.alertSize))
  widgets.alertMove:SetText(settings.alertUnlocked and 'Lock alert' or 'Move alert')

  local color = settings.alertColor or { 1, 1, 1 }
  widgets.alertRed:SetValue(color[1])
  widgets.alertGreen:SetValue(color[2])
  widgets.alertBlue:SetValue(color[3])
  widgets.alertRed.valueText:SetText(('%.2f'):format(color[1]))
  widgets.alertGreen.valueText:SetText(('%.2f'):format(color[2]))
  widgets.alertBlue.valueText:SetText(('%.2f'):format(color[3]))
  widgets.display.Select(settings.displayMode)
  widgets.preview.Select(settings.preview)
  widgets.scale:SetValue(settings.scale)
  widgets.scale.valueText:SetText(('%.2f'):format(settings.scale))
  widgets.move:SetText(settings.unlocked and 'Lock indicator' or 'Move indicator')
end

-- Closes the panel, wherever it ended up living.
--
-- Needed because the panel covers the screen: previewing the indicator or
-- moving it is pointless while the thing you are looking at is hidden behind
-- the settings UI.
function options.Close()
  if window then
    window:Hide()
    return true
  end

  local panel = _G.SettingsPanel
  if not panel then
    return false
  end

  if _G.HideUIPanel and pcall(_G.HideUIPanel, panel) then
    return true
  end

  return pcall(panel.Hide, panel)
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
