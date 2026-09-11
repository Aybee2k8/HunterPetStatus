-- Builds the settings panel against a stubbed frame API.
--
--   lua5.4 tests/options_spec.lua
--
-- This cannot prove the panel looks right -- only the client can. What it does
-- prove is that the panel constructs without error, that every widget is
-- anchored to something that exists, and that clicking a widget reaches the
-- right callback with the right value. Those are the failures that would
-- otherwise only show up as a Lua error on someone's screen.

package.path = './PetWatch/?.lua;' .. package.path

local failures = 0

local function check(description, expected, actual)
  if expected == actual then
    print(('  ok    %s'):format(description))
  else
    failures = failures + 1
    print(('  FAIL  %s -- expected %s, got %s'):format(description, tostring(expected), tostring(actual)))
  end
end

local function checkNoError(description, fn, ...)
  local ok, err = pcall(fn, ...)
  if ok then
    print(('  ok    %s'):format(description))
  else
    failures = failures + 1
    print(('  FAIL  %s -- %s'):format(description, err))
  end
end

--------------------------------------------------------------------------------
-- Frame stub
--------------------------------------------------------------------------------

local Frame = {}

-- Anything the panel calls that this stub does not model becomes a no-op. The
-- point is not to emulate the client, only to let construction run to the end
-- so real mistakes surface.
Frame.__index = function(self, key)
  local defined = rawget(Frame, key)
  if defined then
    return defined
  end

  return function()
    return self
  end
end

function Frame.new(kind)
  return setmetatable({
    kind = kind,
    scripts = {},
    shown = false,
    checked = false,
    value = 0,
    text = '',
  }, Frame)
end

-- The mistake worth catching: anchoring a widget to one that does not exist
-- yet, which reaches SetPoint as a nil relativeTo.
function Frame:SetPoint(point, relativeTo, ...)
  assert(type(point) == 'string', 'SetPoint needs an anchor point')

  if select('#', ...) > 0 then
    assert(relativeTo ~= nil, 'SetPoint given a nil frame to anchor to')
    assert(type(relativeTo) ~= 'string', 'SetPoint given a string where a frame belongs')
  end

  return self
end

function Frame:SetScript(name, handler)
  self.scripts[name] = handler
  return self
end

function Frame:GetScript(name)
  return self.scripts[name]
end

function Frame:Click()
  local handler = assert(self.scripts.OnClick, 'widget has no OnClick')
  handler(self)
end

function Frame:SetChecked(value)
  self.checked = value and true or false
end

function Frame:GetChecked()
  return self.checked
end

function Frame:SetText(value)
  self.text = value
  return self
end

function Frame:GetText()
  return self.text
end

function Frame:SetValue(value, byUser)
  self.value = value
  local handler = self.scripts.OnValueChanged
  if handler then
    handler(self, value, byUser and true or false)
  end
end

function Frame:GetValue()
  return self.value
end

function Frame:CreateFontString()
  return Frame.new('FontString')
end

function Frame:CreateTexture()
  return Frame.new('Texture')
end

function Frame:GetFontString()
  -- rawget, because the permissive __index above answers every unknown field
  -- with a function -- so a plain `self.fontString` would never read as nil.
  local existing = rawget(self, 'fontString')
  if existing then
    return existing
  end

  local font = Frame.new('FontString')
  rawset(self, 'fontString', font)
  return font
end

function Frame:Show()
  self.shown = true
end

function Frame:Hide()
  self.shown = false
end

function Frame:IsShown()
  return self.shown
end

_G.UIParent = Frame.new('UIParent')
_G.UISpecialFrames = {}

-- Every frame the panel builds, so the tests can reach widgets the panel keeps
-- private -- the same way the client reaches them, by running their handlers.
local created = {}

_G.CreateFrame = function(kind)
  local frame = Frame.new(kind)
  created[#created + 1] = frame
  return frame
end

local function byKind(kind, index)
  local seen = 0
  for i = 1, #created do
    if created[i].kind == kind then
      seen = seen + 1
      if seen == index then
        return created[i]
      end
    end
  end
end

local function byText(text)
  for i = 1, #created do
    if created[i].text == text then
      return created[i]
    end
  end
end

--------------------------------------------------------------------------------
-- Callback spy
--------------------------------------------------------------------------------

local calls
local snapshot

local function spy(name)
  return function(value)
    calls[#calls + 1] = { name = name, value = value }
  end
end

local function lastCall()
  return calls[#calls] or {}
end

local api = {
  SetEnabled = spy('SetEnabled'),
  SetHideMounted = spy('SetHideMounted'),
  SetDisplayMode = spy('SetDisplayMode'),
  SetScale = spy('SetScale'),
  ToggleUnlocked = spy('ToggleUnlocked'),
  Reset = spy('Reset'),
  Diagnostics = spy('Diagnostics'),
  Snapshot = function()
    return snapshot
  end,
}

local function load()
  local ns = {}
  loadfile('PetWatch/Options.lua')('PetWatch', ns)

  calls = {}
  created = {}
  snapshot = {
    enabled = true,
    hideMounted = true,
    displayMode = 'both',
    scale = 1.0,
    unlocked = false,
  }

  return ns.options
end

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------

print('construction')

_G.Settings = nil

local options = load()

local registered
checkNoError('builds without a client settings API', function()
  registered = options.Create(api)
end)

check('falls back to the standalone window', false, registered)
check('registers the window for Escape', 'PetWatchOptionsFrame', _G.UISpecialFrames[1])

--------------------------------------------------------------------------------
-- Settings API host
--------------------------------------------------------------------------------

print('client settings host')

_G.UISpecialFrames = {}

local registerCalls = {}
_G.Settings = {
  RegisterCanvasLayoutCategory = function(_, name)
    registerCalls[#registerCalls + 1] = name
    return { ID = 'category-id', GetID = function() return 'category-id' end }
  end,
  RegisterAddOnCategory = function()
    return true
  end,
  OpenToCategory = function(id)
    registerCalls[#registerCalls + 1] = 'open:' .. tostring(id)
    return true
  end,
}

local hosted = load()
checkNoError('registers with the client settings API', function()
  registered = hosted.Create(api)
end)

check('reports the client host', true, registered)
check('registers under the addon name', 'PetWatch', registerCalls[1])
check('opens through the client settings UI', true, hosted.Open())
check('opened the registered category', 'open:category-id', registerCalls[2])

--------------------------------------------------------------------------------
-- A settings API that rejects registration
--------------------------------------------------------------------------------

print('degraded settings host')

_G.UISpecialFrames = {}
_G.Settings = {
  RegisterCanvasLayoutCategory = function()
    error('category registration refused', 0)
  end,
  RegisterAddOnCategory = function()
    return true
  end,
}

local degraded = load()
checkNoError('survives a settings API that errors', function()
  registered = degraded.Create(api)
end)

check('falls back to the standalone window', false, registered)
check('still opens', true, degraded.Open())

--------------------------------------------------------------------------------
-- Wiring
--------------------------------------------------------------------------------

print('wiring')

_G.Settings = nil
_G.UISpecialFrames = {}

options = load()
options.Create(api)
options.Refresh()

local enabledBox = byKind('CheckButton', 1)
local mountedBox = byKind('CheckButton', 2)
local scaleSlider = byKind('Slider', 1)
local moveButton = byText('Move indicator')

check('the enable checkbox reflects the saved setting', true, enabledBox:GetChecked())
check('the mounted checkbox reflects the saved setting', true, mountedBox:GetChecked())
check('the slider reflects the saved scale', 1.0, scaleSlider:GetValue())
check('the move button reads as unlocked', 'Move indicator', moveButton and moveButton.text)

enabledBox:SetChecked(false)
enabledBox:Click()
check('unchecking enable reaches SetEnabled', 'SetEnabled', lastCall().name)
check('unchecking enable passes false', false, lastCall().value)

mountedBox:SetChecked(false)
mountedBox:Click()
check('unchecking mounted reaches SetHideMounted', 'SetHideMounted', lastCall().name)
check('unchecking mounted passes false', false, lastCall().value)

byText('Icon'):Click()
check('the Icon button reaches SetDisplayMode', 'SetDisplayMode', lastCall().name)
check('the Icon button passes its mode', 'icon', lastCall().value)

byText('Text'):Click()
check('the Text button passes its mode', 'text', lastCall().value)

byText('Both'):Click()
check('the Both button passes its mode', 'both', lastCall().value)

-- byUser is what separates a drag from the panel writing the value back during
-- a refresh; only a drag should be saved.
scaleSlider:SetValue(2.5, true)
check('dragging the slider reaches SetScale', 'SetScale', lastCall().name)
check('dragging the slider passes the value', 2.5, lastCall().value)

calls = {}
scaleSlider:SetValue(1.75, false)
check('a programmatic slider change is not saved', nil, lastCall().name)

byText('Reset to defaults'):Click()
check('the reset button reaches Reset', 'Reset', lastCall().name)

byText('Report API support'):Click()
check('the diagnostics button reaches Diagnostics', 'Diagnostics', lastCall().name)

moveButton:Click()
check('the move button reaches ToggleUnlocked', 'ToggleUnlocked', lastCall().name)

-- The panel refreshes after the toggle, so the label has to follow the state
-- Core reports rather than being flipped locally.
snapshot.unlocked = true
options.Refresh()
check('the move button reads as locked once unlocked', 'Lock indicator', moveButton.text)

--------------------------------------------------------------------------------
-- Refresh before create
--------------------------------------------------------------------------------

print('refresh before create')

local bare = {}
loadfile('PetWatch/Options.lua')('PetWatch', bare)
checkNoError('refresh is a no-op before create', bare.options.Refresh)
check('open reports failure before create', false, bare.options.Open())

--------------------------------------------------------------------------------

print('')
if failures == 0 then
  print('all checks passed')
  os.exit(0)
end

print(('%d check(s) failed'):format(failures))
os.exit(1)
