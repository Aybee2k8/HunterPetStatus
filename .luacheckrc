std = 'lua51'

exclude_files = { '.luarocks' }

-- Unused self-documenting arguments are idiomatic in event handlers.
unused_args = false

-- WoW globals the addon reads.
read_globals = {
  'CreateFrame',
  'GetBuildInfo',
  'UIParent',
  'UnitClass',
  'UnitExists',
  'UnitInVehicle',
  'UnitIsConnected',
  'UnitIsDeadOrGhost',
  'HasPetUI',
  'IsMounted',
  'InCombatLockdown',
  'GetTime',
  'UnitHealth',
  'UnitHealthMax',
  'UnitHealthPercent',
  'PetCanBeDismissed',
  'C_SpecializationInfo',
  'GetSpecialization',
  'GetSpecializationInfo',
  'Settings',
  'SettingsPanel',
  'HideUIPanel',
  'C_AddOns',
  'unpack',
}

-- Globals the addon defines.
globals = {
  'PetWatchDB',
  'PetWatch_OnAddonCompartmentClick',
  'UISpecialFrames',
  'SLASH_PETWATCH1',
  'SLASH_PETWATCH2',
  'SlashCmdList',
}

files['tests/state_spec.lua'] = {
  std = 'lua54',
  -- The test harness installs its own stand-ins for the client API.
  globals = {
    'UnitClass',
    'UnitExists',
    'UnitInVehicle',
    'UnitIsDeadOrGhost',
    'HasPetUI',
    'IsMounted',
    'C_SpecializationInfo',
  },
}
