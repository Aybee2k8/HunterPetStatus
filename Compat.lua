local _, ns = ...

-- Every client-API difference this addon has to cope with lives here, so the
-- rest of the addon can be written against one stable surface.
--
-- Two things drive this file:
--
--   * Patch 12.0 moved a number of globals into C_* namespaces. Which of the
--     two spellings a given build answers to is not something we can know
--     ahead of time, so we resolve lazily and remember what we found.
--   * Patch 12.0 introduced "secret values". Tainted code -- which is what an
--     addon is -- may store one and pass it along, but comparing or branching
--     on one raises a Lua error. Any unit query can hand us one, so none of
--     them are called directly.
--
-- Everything probed here is recorded, and /pw diag prints the record. That
-- report is the fastest way to find out what a new build actually changed.

local compat = {}
ns.compat = compat

local probes = {}
compat.probes = probes

local function probe(name, ok, detail)
  probes[#probes + 1] = { name = name, ok = ok and true or false, detail = detail }
end

--------------------------------------------------------------------------------
-- Secret values
--------------------------------------------------------------------------------

local function toBoolean(value)
  return value and true or false
end

-- Calls fn and reduces its first return to a plain boolean.
--
-- Returns nil when the answer cannot be trusted: the function is absent, it
-- errored, or its result was a secret value we are not allowed to branch on.
-- Callers must treat nil as "unknown" and not as "false" -- the difference
-- between "no pet" and "cannot tell" is the whole point.
function compat.SafeFlag(fn, ...)
  if type(fn) ~= 'function' then
    return nil
  end

  local ok, value = pcall(fn, ...)
  if not ok then
    return nil
  end

  local converted
  ok, converted = pcall(toBoolean, value)
  if not ok then
    return nil
  end

  return converted
end

--------------------------------------------------------------------------------
-- Specialization
--------------------------------------------------------------------------------

local specIndexFn, specInfoFn
local specResolved = false

local function resolveSpecAPI()
  if specResolved then
    return
  end
  specResolved = true

  local C = _G.C_SpecializationInfo

  specIndexFn = (C and C.GetSpecialization) or _G.GetSpecialization
  specInfoFn = (C and C.GetSpecializationInfo) or _G.GetSpecializationInfo

  probe('C_SpecializationInfo.GetSpecialization', C and C.GetSpecialization)
  probe('GetSpecialization (global)', _G.GetSpecialization)
  probe('C_SpecializationInfo.GetSpecializationInfo', C and C.GetSpecializationInfo)
  probe('GetSpecializationInfo (global)', _G.GetSpecializationInfo)
end

-- Returns the player's current specialization ID, or nil if it cannot be
-- determined (no spec learned yet, or the API moved again).
function compat.GetSpecID()
  resolveSpecAPI()

  if type(specIndexFn) ~= 'function' or type(specInfoFn) ~= 'function' then
    return nil
  end

  local ok, index = pcall(specIndexFn)
  if not ok or not index then
    return nil
  end

  local specID
  ok, specID = pcall(specInfoFn, index)
  if not ok then
    return nil
  end

  return specID
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

-- RegisterEvent throws on an unknown event name, and these calls happen at load
-- time -- one renamed event would stop the whole addon from loading. Each
-- registration is therefore isolated, and failures are reported rather than
-- fatal.

function compat.RegisterEvent(frame, event)
  local ok = pcall(frame.RegisterEvent, frame, event)
  probe('event ' .. event, ok)
  return ok
end

-- Registers a unit-filtered event, falling back to the unfiltered form if the
-- filtered registration is rejected. Returns whether filtering is in effect, so
-- the handler knows if it still has to check arg1 itself.
function compat.RegisterUnitEvent(frame, event, unit)
  local ok = pcall(frame.RegisterUnitEvent, frame, event, unit)
  if ok then
    probe('event ' .. event .. ' (unit: ' .. unit .. ')', true)
    return true
  end

  probe('event ' .. event .. ' (unit filter rejected)', false)
  return false, compat.RegisterEvent(frame, event)
end

--------------------------------------------------------------------------------
-- Misc client APIs
--------------------------------------------------------------------------------

function compat.IsMounted()
  return compat.SafeFlag(_G.IsMounted)
end

function compat.InVehicle()
  return compat.SafeFlag(_G.UnitInVehicle, 'player')
end

function compat.InCombatLockdown()
  return compat.SafeFlag(_G.InCombatLockdown)
end

-- Records the state of APIs we depend on but do not wrap, so /pw diag covers
-- them too.
function compat.ProbeOptional()
  probe('HasPetUI', _G.HasPetUI)
  probe('UnitExists', _G.UnitExists)
  probe('UnitIsDeadOrGhost', _G.UnitIsDeadOrGhost)
  probe('UnitIsConnected', _G.UnitIsConnected)
  probe('PetCanBeDismissed', _G.PetCanBeDismissed)

  -- Whether these return a secret value is the single most important unknown
  -- for this addon, and it can only be answered on a live client.
  probe('UnitExists("pet") readable', compat.SafeFlag(_G.UnitExists, 'pet') ~= nil)
  probe('UnitIsDeadOrGhost("pet") readable', compat.SafeFlag(_G.UnitIsDeadOrGhost, 'pet') ~= nil)
end
