-- Runs the pet-state logic outside the game, against a stubbed client API.
--
--   lua5.4 tests/state_spec.lua
--
-- State.lua is the only file with logic worth testing and the only one that
-- touches no frames, so it loads cleanly here. Display.lua and Core.lua need a
-- real client.
--
-- One caveat: a genuine secret value is a client-side type that raises on
-- comparison, and plain Lua has no way to reproduce that. The "unreadable"
-- cases below stub the API to raise instead, which exercises the same branch in
-- compat.SafeFlag -- but only a live client can confirm which queries actually
-- hand back secrets.

package.path = './?.lua;' .. package.path

local ns = {}

loadfile('Compat.lua')('PetWatch', ns)
loadfile('State.lua')('PetWatch', ns)

local state = ns.state

--------------------------------------------------------------------------------
-- Stubs
--------------------------------------------------------------------------------

local client = {}

local function secret()
  error('attempt to use a secret value', 0)
end

local function reset(overrides)
  client = {
    class = 'HUNTER',
    specIndex = 1,
    specID = 253,
    mounted = false,
    inVehicle = false,
    petExists = false,
    petDead = false,
    petUI = false,
    petUIIsHunter = false,
  }

  for key, value in pairs(overrides or {}) do
    client[key] = value
  end

  state.Invalidate()
end

local function call(value)
  if value == 'secret' then
    return secret()
  end
  return value
end

_G.UnitClass = function()
  return 'Class', client.class
end

_G.C_SpecializationInfo = {
  GetSpecialization = function()
    return client.specIndex
  end,
  GetSpecializationInfo = function()
    return client.specID
  end,
}

_G.IsMounted = function()
  return call(client.mounted)
end

_G.UnitInVehicle = function()
  return call(client.inVehicle)
end

_G.UnitExists = function(unit)
  assert(unit == 'pet')
  return call(client.petExists)
end

_G.UnitIsDeadOrGhost = function(unit)
  assert(unit == 'pet')
  return call(client.petDead)
end

_G.HasPetUI = function()
  if client.petUI == 'secret' then
    return secret()
  end
  return client.petUI, client.petUIIsHunter
end

--------------------------------------------------------------------------------
-- Harness
--------------------------------------------------------------------------------

local failures = 0
local db = { enabled = true, hideMounted = true }

local function check(description, expected, actual)
  if expected == actual then
    print(('  ok    %s'):format(description))
  else
    failures = failures + 1
    print(('  FAIL  %s -- expected %s, got %s'):format(description, expected, actual))
  end
end

--------------------------------------------------------------------------------
-- Applicability
--------------------------------------------------------------------------------

print('applicability')

reset({ class = 'WARRIOR' })
check('non-hunter is hidden', state.HIDDEN, state.Resolve(db, nil))

reset({ specID = 254 })
check('marksmanship is hidden', state.HIDDEN, state.Resolve(db, nil))

reset({ mounted = true })
check('mounted is hidden when hideMounted is set', state.HIDDEN, state.Resolve(db, nil))

reset({ mounted = true })
check('mounted is evaluated when hideMounted is unset', state.MISSING,
  state.Resolve({ enabled = true, hideMounted = false }, nil))

reset({ inVehicle = true })
check('in a vehicle is hidden', state.HIDDEN, state.Resolve(db, nil))

reset()
check('disabled is hidden', state.HIDDEN, state.Resolve({ enabled = false }, nil))

reset({ specID = nil })
check('unknown spec still reports', state.MISSING, state.Resolve(db, nil))

--------------------------------------------------------------------------------
-- Live pet unit
--------------------------------------------------------------------------------

print('live pet unit')

reset({ petExists = true, petDead = false })
check('alive pet reports ok', state.OK, state.Resolve(db, nil))

reset({ petExists = true, petDead = true })
check('dead pet reports dead', state.DEAD, state.Resolve(db, nil))

reset({ petExists = false })
check('no pet reports missing', state.MISSING, state.Resolve(db, nil))

--------------------------------------------------------------------------------
-- Death memory
--------------------------------------------------------------------------------
-- The original addon latched on "dead" and never cleared it, so once a pet had
-- died the indicator stayed stuck on DEAD for the rest of the session. These
-- are the cases that has to get right.

print('death memory')

reset({ petExists = true, petDead = true })
state.Resolve(db, nil)
client.petExists = false
check('pet that died then despawned still reports dead', state.DEAD, state.Resolve(db, state.DEAD))

reset({ petExists = true, petDead = true })
state.Resolve(db, nil)
client.petExists = false
state.Invalidate()
check('dismissing after a death reports missing, not dead', state.MISSING, state.Resolve(db, state.DEAD))

reset({ petExists = true, petDead = true })
state.Resolve(db, nil)
check('memory is set while the pet is dead', true, state.SawPetDie())

client.petDead = false
state.Resolve(db, state.DEAD)
check('reviving clears the memory', false, state.SawPetDie())
check('revived pet reports ok', state.OK, state.Resolve(db, state.DEAD))

--------------------------------------------------------------------------------
-- HasPetUI as a tiebreaker
--------------------------------------------------------------------------------

print('pet UI tiebreaker')

reset({ petExists = false, petUI = true, petUIIsHunter = true })
check('lingering hunter pet UI reports dead', state.DEAD, state.Resolve(db, nil))

reset({ petExists = false, petUI = true, petUIIsHunter = false })
check('non-hunter pet UI reports missing', state.MISSING, state.Resolve(db, nil))

reset({ petExists = false, petUI = 'secret' })
check('unreadable pet UI reports missing', state.MISSING, state.Resolve(db, nil))

--------------------------------------------------------------------------------
-- Unreadable queries
--------------------------------------------------------------------------------
-- An unreadable query must hold the previous state rather than collapse to a
-- wrong one, so a secret value cannot make the indicator flicker.

print('unreadable queries')

reset({ petExists = 'secret' })
check('unreadable existence holds the previous state', state.OK, state.Resolve(db, state.OK))

reset({ petExists = 'secret' })
check('unreadable existence with no history is unknown', state.UNKNOWN, state.Resolve(db, nil))

reset({ petExists = true, petDead = 'secret' })
check('unreadable condition holds the previous state', state.OK, state.Resolve(db, state.OK))

reset({ petExists = true, petDead = true })
state.Resolve(db, nil)
client.petDead = 'secret'
check('unreadable condition falls back to the death memory', state.DEAD, state.Resolve(db, state.OK))

--------------------------------------------------------------------------------

print('')
if failures == 0 then
  print('all checks passed')
  os.exit(0)
end

print(('%d check(s) failed'):format(failures))
os.exit(1)
