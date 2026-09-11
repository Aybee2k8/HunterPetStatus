local ADDON, ns = ...

local compat = ns.compat
local state = ns.state
local display = ns.display
local options = ns.options

local DEFAULTS = {
  enabled = true,
  scale = 1.0,
  displayMode = 'both', -- 'icon' | 'text' | 'both'
  hideMounted = true,
  point = { 'CENTER', 'UIParent', 'CENTER', 0, 0 },
}

local db
local current = state.UNKNOWN
local unlocked = false
local inSettingsUI = false

local function say(message)
  print('|cff00ff00PetWatch|r: ' .. message)
end

local function copyDefaults(target, defaults)
  for key, value in pairs(defaults) do
    if target[key] == nil then
      if type(value) == 'table' then
        local copy = {}
        for i = 1, #value do
          copy[i] = value[i]
        end
        target[key] = copy
      else
        target[key] = value
      end
    end
  end
end

-- Bound on ADDON_LOADED rather than at parse time: the engine populates the
-- SavedVariables global after the Lua files are loaded, so a reference taken
-- any earlier would be to a table that gets replaced.
local function initDB()
  PetWatchDB = PetWatchDB or {}
  copyDefaults(PetWatchDB, DEFAULTS)
  db = PetWatchDB
end

local function refresh()
  current = state.Resolve(db, current)
  display.Update(current, db.displayMode)
end

local function onMoved(point)
  db.point = point
end

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

-- One place where a setting is changed, whatever asked for it. The panel and
-- the slash commands both go through here, so the two can never disagree about
-- what a change is supposed to do.

local settings = {}

function settings.SetEnabled(value)
  db.enabled = value and true or false
  refresh()
end

function settings.SetHideMounted(value)
  db.hideMounted = value and true or false
  refresh()
end

function settings.SetDisplayMode(mode)
  db.displayMode = mode
  refresh()
end

function settings.SetScale(value)
  db.scale = value
  display.ApplyScale(value)
end

function settings.SetUnlocked(value)
  unlocked = value and true or false
  display.SetUnlocked(unlocked, onMoved)

  if not unlocked then
    refresh()
  end
end

function settings.ToggleUnlocked()
  settings.SetUnlocked(not unlocked)
end

function settings.Reset()
  db.point = { unpack(DEFAULTS.point) }
  db.scale = DEFAULTS.scale
  db.displayMode = DEFAULTS.displayMode
  db.hideMounted = DEFAULTS.hideMounted
  db.enabled = DEFAULTS.enabled

  settings.SetUnlocked(false)
  display.ApplyScale(db.scale)
  display.ApplyPosition(db.point)
  refresh()
end

-- What the panel reads to fill in its widgets.
function settings.Snapshot()
  return {
    enabled = db.enabled,
    hideMounted = db.hideMounted,
    displayMode = db.displayMode,
    scale = db.scale,
    unlocked = unlocked,
  }
end

-- Prints what this client actually supports: which APIs and events resolved,
-- and whether the pet queries returned something readable or a secret value.
-- This is the report to attach to a bug report after a patch.
function settings.Diagnostics()
  local version, build = GetBuildInfo(), select(4, GetBuildInfo())

  say('diagnostics')
  print(('  build: %s (%s)'):format(version, build))
  print(('  spec ID: %s'):format(tostring(compat.GetSpecID())))
  print(('  resolved state: %s'):format(current))
  print(('  saw pet die: %s'):format(tostring(state.SawPetDie())))
  print(('  settings host: %s'):format(inSettingsUI and 'client settings UI' or 'standalone window'))

  for _, entry in ipairs(compat.probes) do
    print(('  [%s] %s'):format(entry.ok and '|cff00ff00ok|r' or '|cffff0000--|r', entry.name))
  end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- Events that mean the pet roster changed, and so invalidate our memory of
-- having seen the pet die.
local ROSTER_EVENTS = {
  PLAYER_ENTERING_WORLD = true,
  PLAYER_SPECIALIZATION_CHANGED = true,
  UNIT_PET = true,
}

local EVENTS = {
  'PLAYER_ENTERING_WORLD',
  'PLAYER_SPECIALIZATION_CHANGED',
  'PLAYER_MOUNT_DISPLAY_CHANGED',
  'UNIT_PET',
  'PET_BAR_UPDATE',
  'UNIT_ENTERED_VEHICLE',
  'UNIT_EXITED_VEHICLE',
}

-- Fired for every unit in the group, so these are registered unit-filtered.
local PET_UNIT_EVENTS = {
  'UNIT_HEALTH',
  'UNIT_FLAGS',
  'UNIT_CONNECTION',
}

local listener = CreateFrame('Frame')

listener:SetScript('OnEvent', function(_, event, arg1)
  if event == 'ADDON_LOADED' then
    if arg1 ~= ADDON then
      return
    end

    initDB()
    compat.ProbeOptional()

    display.Create()
    display.ApplyScale(db.scale)
    display.ApplyPosition(db.point)

    inSettingsUI = options.Create(settings)

    refresh()
    return
  end

  if not db then
    return
  end

  if ROSTER_EVENTS[event] then
    state.Invalidate()
  end

  refresh()
end)

compat.RegisterEvent(listener, 'ADDON_LOADED')

for i = 1, #EVENTS do
  compat.RegisterEvent(listener, EVENTS[i])
end

for i = 1, #PET_UNIT_EVENTS do
  compat.RegisterUnitEvent(listener, PET_UNIT_EVENTS[i], 'pet')
end

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

-- Kept as a shortcut for anything the panel can do. The panel is the primary
-- way in; a bare /pw opens it.

local commands = {}

function commands.unlock()
  settings.SetUnlocked(true)
  options.Refresh()
  say('unlocked - drag the icon, then /pw lock.')
end

function commands.lock()
  settings.SetUnlocked(false)
  options.Refresh()
  say('locked.')
end

function commands.on()
  settings.SetEnabled(true)
  options.Refresh()
  say('enabled.')
end

function commands.off()
  settings.SetEnabled(false)
  options.Refresh()
  say('disabled.')
end

function commands.reset()
  settings.Reset()
  options.Refresh()
  say('position and settings reset.')
end

function commands.scale(argument)
  local value = tonumber(argument)

  if not value or value < 0.3 or value > 4 then
    say('usage: /pw scale 1.0  (0.3 - 4.0)')
    return
  end

  settings.SetScale(value)
  options.Refresh()
  say(('scale set to %.2f'):format(value))
end

function commands.display(argument)
  if argument ~= 'icon' and argument ~= 'text' and argument ~= 'both' then
    say(('display mode is %s. usage: /pw display icon|text|both'):format(db.displayMode))
    return
  end

  settings.SetDisplayMode(argument)
  options.Refresh()
  say('display mode set to ' .. argument)
end

function commands.mounted(argument)
  if argument ~= 'show' and argument ~= 'hide' then
    say(('while mounted: %s. usage: /pw mounted show|hide'):format(db.hideMounted and 'hide' or 'show'))
    return
  end

  settings.SetHideMounted(argument == 'hide')
  options.Refresh()
  say('while mounted: ' .. argument)
end

function commands.diag()
  settings.Diagnostics()
end

function commands.help()
  say('commands')
  print('  /pw                        - open the settings panel')
  print('  /pw unlock | lock          - reposition the indicator')
  print('  /pw scale 1.0              - resize it')
  print('  /pw display icon|text|both - what to show')
  print('  /pw mounted show|hide      - behaviour while mounted')
  print('  /pw on | off               - enable or disable')
  print('  /pw reset                  - restore defaults')
  print('  /pw diag                   - report client API support')
end

SLASH_PETWATCH1 = '/pw'
SLASH_PETWATCH2 = '/petwatch'

SlashCmdList.PETWATCH = function(input)
  if not db then
    say('still loading - try again in a moment.')
    return
  end

  local command, argument = (input or ''):lower():match('^%s*(%S*)%s*(%S*)')

  if command == '' then
    if not options.Open() then
      say('could not open the settings panel - use /pw help for commands.')
    end
    return
  end

  local handler = commands[command] or commands.help
  handler(argument)
end
