local ADDON, ns = ...

local compat = ns.compat
local state = ns.state
local display = ns.display

local DEFAULTS = {
  enabled = true,
  scale = 1.0,
  displayMode = 'both', -- 'icon' | 'text' | 'both'
  hideMounted = true,
  point = { 'CENTER', 'UIParent', 'CENTER', 0, 0 },
}

local db
local current = state.UNKNOWN

local function say(message)
  print('|cff00ff00HunterPetStatus|r: ' .. message)
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
  HunterPetStatusDB = HunterPetStatusDB or {}
  copyDefaults(HunterPetStatusDB, DEFAULTS)
  db = HunterPetStatusDB
end

local function refresh()
  current = state.Resolve(db, current)
  display.Update(current, db.displayMode)
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

local function onMoved(point)
  db.point = point
end

local commands = {}

function commands.unlock()
  display.SetUnlocked(true, onMoved)
  say('unlocked - drag the icon, then /hps lock.')
end

function commands.lock()
  display.SetUnlocked(false, onMoved)
  refresh()
  say('locked.')
end

function commands.on()
  db.enabled = true
  refresh()
  say('enabled.')
end

function commands.off()
  db.enabled = false
  refresh()
  say('disabled.')
end

function commands.reset()
  db.point = { unpack(DEFAULTS.point) }
  db.scale = DEFAULTS.scale
  db.displayMode = DEFAULTS.displayMode
  db.hideMounted = DEFAULTS.hideMounted

  display.SetUnlocked(false, onMoved)
  display.ApplyScale(db.scale)
  display.ApplyPosition(db.point)
  refresh()
  say('position and settings reset.')
end

function commands.scale(argument)
  local value = tonumber(argument)

  if not value or value < 0.3 or value > 4 then
    say('usage: /hps scale 1.0  (0.3 - 4.0)')
    return
  end

  db.scale = value
  display.ApplyScale(value)
  say(('scale set to %.2f'):format(value))
end

function commands.display(argument)
  if argument ~= 'icon' and argument ~= 'text' and argument ~= 'both' then
    say(('display mode is %s. usage: /hps display icon|text|both'):format(db.displayMode))
    return
  end

  db.displayMode = argument
  refresh()
  say('display mode set to ' .. argument)
end

function commands.mounted(argument)
  if argument ~= 'show' and argument ~= 'hide' then
    say(('while mounted: %s. usage: /hps mounted show|hide'):format(db.hideMounted and 'hide' or 'show'))
    return
  end

  db.hideMounted = (argument == 'hide')
  refresh()
  say('while mounted: ' .. argument)
end

-- Prints what this client actually supports. This is the report to attach to a
-- bug report after a patch: it says which APIs and events resolved, and whether
-- the pet queries returned something readable or a secret value.
function commands.diag()
  say('diagnostics')
  print(('  build: %s (%s)'):format(select(1, GetBuildInfo()), select(4, GetBuildInfo())))
  print(('  spec ID: %s'):format(tostring(compat.GetSpecID())))
  print(('  resolved state: %s'):format(current))
  print(('  saw pet die: %s'):format(tostring(state.SawPetDie())))

  for _, entry in ipairs(compat.probes) do
    print(('  [%s] %s'):format(entry.ok and '|cff00ff00ok|r' or '|cffff0000--|r', entry.name))
  end
end

function commands.help()
  say('commands')
  print('  /hps unlock | lock          - reposition the indicator')
  print('  /hps scale 1.0              - resize it')
  print('  /hps display icon|text|both - what to show')
  print('  /hps mounted show|hide      - behaviour while mounted')
  print('  /hps on | off               - enable or disable')
  print('  /hps reset                  - restore defaults')
  print('  /hps diag                   - report client API support')
end

SLASH_HUNTERPETSTATUS1 = '/hps'
SLASH_HUNTERPETSTATUS2 = '/hunterpetstatus'

SlashCmdList.HUNTERPETSTATUS = function(input)
  if not db then
    say('still loading - try again in a moment.')
    return
  end

  local command, argument = (input or ''):lower():match('^%s*(%S*)%s*(%S*)')
  local handler = commands[command] or commands.help

  handler(argument)
end
