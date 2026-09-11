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
  alert = true,
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

-- What went wrong during setup, by part. Reported in chat once and repeated by
-- /pw diag, because Lua errors are hidden by default in Retail: an unguarded
-- failure leaves the addon doing nothing with nothing on screen to say why.
local setupError = {}

-- Runs fn and returns its error message, or nil if it succeeded.
local function guard(fn)
  local ok, err = pcall(fn)
  if ok then
    return nil
  end
  return tostring(err)
end

local refreshBroken = false

-- Forces the indicator to show a given state regardless of the pet.
--
-- Without this there is no way to see the indicator, or place it, unless the
-- pet happens to be dead -- and a working addon shows nothing at all, which is
-- indistinguishable from a broken one. Deliberately not saved: it is a look at
-- something, not a setting, and nobody should find a fake indicator waiting for
-- them after a relog.
local preview
local previewFromUnlock = false

-- What the indicator last showed, which is what a transition is measured
-- against. Kept apart from `current` because a preview changes what is on
-- screen without changing what the pet is doing.
local lastShown

-- Alerts are held back briefly after a loading screen. While the world loads,
-- the pet unit can read as absent even though the pet is out, and flashing
-- "Pet Missing!" at someone whose pet is standing next to them is worse than
-- staying quiet.
local alertsQuietUntil = 0

local function alertsQuiet()
  return GetTime() < alertsQuietUntil
end

local function refresh()
  if refreshBroken then
    return
  end

  local err = guard(function()
    current = state.Resolve(db, current)

    local shown = preview or current
    display.Update(shown, db.displayMode)

    if db.alert and not alertsQuiet() and state.ShouldAlert(lastShown, shown) then
      display.Flash(shown)
    end

    lastShown = shown
  end)

  if not err then
    return
  end

  -- Updating on every pet event means a recurring error would spam the chat
  -- frame, so it is reported once and then left alone.
  refreshBroken = true
  setupError.refresh = err
  say('|cffff0000stopped updating the indicator:|r ' .. err)
  say('settings and /pw diag still work. Please report this.')
end

local function reportSetup()
  for _, part in ipairs({ 'display', 'options' }) do
    if setupError[part] then
      say(('|cffff0000%s failed to start:|r %s'):format(part, setupError[part]))
    end
  end

  if setupError.options then
    say('the settings panel is unavailable; /pw help lists the commands.')
  end
end

local function onMoved(point)
  db.point = point
end

-- The panel is optional: it may have failed to build, or been built against a
-- client whose settings API behaves differently. Neither is a reason for a
-- slash command to stop working, so every call into it is isolated.
local function refreshPanel()
  local err = guard(options.Refresh)
  if err and not setupError.options then
    setupError.options = err
  end
end

local function openPanel()
  local opened
  local err = guard(function()
    opened = options.Open()
  end)

  if err then
    setupError.options = setupError.options or err
    return false
  end

  return opened
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

function settings.SetAlert(value)
  db.alert = value and true or false
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

local PREVIEW_STATES = {
  dead = state.DEAD,
  missing = state.MISSING,
  off = false,
}

-- mode is 'dead', 'missing' or 'off'.
function settings.SetPreview(mode)
  local resolved = PREVIEW_STATES[mode]
  if resolved == nil then
    return false
  end

  preview = resolved or nil
  previewFromUnlock = false
  refresh()

  -- A preview is someone asking to see what this looks like, so it shows the
  -- alert too -- and unconditionally, since refresh only flashes on a change
  -- and previewing the same state twice is not one.
  if preview and db.alert then
    guard(function()
      display.Flash(preview)
    end)
  end

  return true
end

function settings.SetUnlocked(value)
  unlocked = value and true or false
  display.SetUnlocked(unlocked, onMoved)

  -- Unlocking with a live pet would otherwise offer nothing to drag, so it
  -- turns the preview on -- and takes it away again on lock, but only if it was
  -- the one that turned it on.
  if unlocked then
    if not preview then
      preview = state.MISSING
      previewFromUnlock = true
    end
  elseif previewFromUnlock then
    preview = nil
    previewFromUnlock = false
  end

  refresh()
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

  preview = nil
  previewFromUnlock = false

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
    alert = db.alert,
    displayMode = db.displayMode,
    scale = db.scale,
    unlocked = unlocked,
    preview = (preview == state.DEAD and 'dead')
      or (preview == state.MISSING and 'missing')
      or 'off',
  }
end

-- Prints what this client actually supports: which APIs and events resolved,
-- and whether the pet queries returned something readable or a secret value.
-- This is the report to attach to a bug report after a patch.
function settings.Diagnostics()
  local version, build = GetBuildInfo(), select(4, GetBuildInfo())

  -- GetAddOnMetadata only exposes Author, Version and X-* fields; Interface is
  -- not among them, so there is no way to read back what the TOC declared. The
  -- addon list already marks a mismatch, and the client's own number is here.
  local addonVersion = '?'
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    addonVersion = C_AddOns.GetAddOnMetadata(ADDON, 'Version') or '?'
  end

  say('diagnostics')
  print(('  addon: %s'):format(addonVersion))
  print(('  build: %s (interface %s)'):format(version, build))
  print(('  spec ID: %s'):format(tostring(compat.GetSpecID())))
  print(('  resolved state: %s%s'):format(current, preview and (' (preview: ' .. preview .. ')') or ''))
  print(('  saw pet die: %s'):format(tostring(state.SawPetDie())))
  print(('  settings host: %s'):format(inSettingsUI and 'client settings UI' or 'standalone window'))

  -- The values themselves, not just whether they were readable. Whether the pet
  -- unit keeps answering once the pet is dead is the one thing the harnesses
  -- cannot settle, and this is the line that answers it.
  print(('  pet: exists=%s dead=%s hunterPetUI=%s'):format(
    tostring(compat.SafeFlag(_G.UnitExists, 'pet')),
    tostring(compat.SafeFlag(_G.UnitIsDeadOrGhost, 'pet')),
    tostring(compat.HunterPetUI())))

  for _, part in ipairs({ 'display', 'options', 'refresh' }) do
    if setupError[part] then
      print(('  |cffff0000%s failed:|r %s'):format(part, setupError[part]))
    end
  end

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

    -- Each part of the setup is isolated, so a failure in one does not take the
    -- rest of the addon with it. Lua errors are hidden by default in Retail, so
    -- an unguarded error here would leave the addon doing nothing at all with
    -- nothing on screen to say why -- the worst thing to hand someone.
    -- Whatever survives, survives; what did not is named in chat and in
    -- /pw diag.
    setupError.display = guard(function()
      display.Create()
      display.CreateAlert()
      display.ApplyScale(db.scale)
      display.ApplyPosition(db.point)
    end)

    -- The first resolution after login should not flash: it reports a state
    -- that has been true all along rather than one that just changed.
    alertsQuietUntil = GetTime() + 5

    setupError.options = guard(function()
      inSettingsUI = options.Create(settings)
    end)

    refresh()
    reportSetup()
    return
  end

  if not db then
    return
  end

  if ROSTER_EVENTS[event] then
    state.Invalidate()
  end

  -- A preview is a look at something, not a setting. Zoning or reloading ends
  -- it, so nobody is left staring at a fake indicator wondering why their pet
  -- is reported dead.
  if event == 'PLAYER_ENTERING_WORLD' then
    preview = nil
    previewFromUnlock = false
    settings.SetUnlocked(false)
    alertsQuietUntil = GetTime() + 5
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

function commands.preview(argument)
  if not settings.SetPreview(argument) then
    say(('preview is %s. usage: /pw preview dead|missing|off'):format(settings.Snapshot().preview))
    return
  end

  refreshPanel()
  say(argument == 'off' and 'preview off - showing the real pet state.'
    or ('previewing "%s" - /pw preview off to stop.'):format(argument))
end

-- "test" is what people reach for; keep it as an alias rather than a surprise.
commands.test = commands.preview

function commands.unlock()
  settings.SetUnlocked(true)
  refreshPanel()
  say('unlocked - drag the icon, then /pw lock.')
end

function commands.lock()
  settings.SetUnlocked(false)
  refreshPanel()
  say('locked.')
end

function commands.on()
  settings.SetEnabled(true)
  refreshPanel()
  say('enabled.')
end

function commands.off()
  settings.SetEnabled(false)
  refreshPanel()
  say('disabled.')
end

function commands.reset()
  settings.Reset()
  refreshPanel()
  say('position and settings reset.')
end

function commands.scale(argument)
  local value = tonumber(argument)

  if not value or value < 0.3 or value > 4 then
    say('usage: /pw scale 1.0  (0.3 - 4.0)')
    return
  end

  settings.SetScale(value)
  refreshPanel()
  say(('scale set to %.2f'):format(value))
end

function commands.display(argument)
  if argument ~= 'icon' and argument ~= 'text' and argument ~= 'both' then
    say(('display mode is %s. usage: /pw display icon|text|both'):format(db.displayMode))
    return
  end

  settings.SetDisplayMode(argument)
  refreshPanel()
  say('display mode set to ' .. argument)
end

function commands.alert(argument)
  if argument ~= 'on' and argument ~= 'off' then
    say(('centre-screen alert: %s. usage: /pw alert on|off'):format(db.alert and 'on' or 'off'))
    return
  end

  settings.SetAlert(argument == 'on')
  refreshPanel()
  say('centre-screen alert: ' .. argument)
end

function commands.mounted(argument)
  if argument ~= 'show' and argument ~= 'hide' then
    say(('while mounted: %s. usage: /pw mounted show|hide'):format(db.hideMounted and 'hide' or 'show'))
    return
  end

  settings.SetHideMounted(argument == 'hide')
  refreshPanel()
  say('while mounted: ' .. argument)
end

function commands.diag()
  settings.Diagnostics()
end

function commands.help()
  say('commands')
  print('  /pw                        - open the settings panel')
  print('  /pw preview dead|missing|off - show the indicator without waiting for a dead pet')
  print('  /pw unlock | lock          - reposition the indicator')
  print('  /pw scale 1.0              - resize it')
  print('  /pw display icon|text|both - what to show')
  print('  /pw alert on|off           - flash a warning in the middle of the screen')
  print('  /pw mounted show|hide      - behaviour while mounted')
  print('  /pw on | off               - enable or disable')
  print('  /pw reset                  - restore defaults')
  print('  /pw diag                   - report client API support')
end

-- Clicking the addon's entry in the minimap compartment opens the panel. Named
-- in the TOC, so it has to be a global.
function PetWatch_OnAddonCompartmentClick()
  if not db then
    say('still loading - try again in a moment.')
    return
  end

  if not openPanel() then
    say('could not open the settings panel - use /pw help for commands.')
  end
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
    if not openPanel() then
      say('could not open the settings panel - use /pw help for commands.')
    end
    return
  end

  local handler = commands[command] or commands.help
  handler(argument)
end
