local _, ns = ...

local compat = ns.compat

-- Pet state resolution.
--
-- The awkward part of this addon is telling a dead pet apart from a dismissed
-- one. A dead pet can stop answering to the "pet" unit token, which makes it
-- look identical to having no pet at all -- and the two need different advice
-- (revive vs. call).
--
-- The way through is to remember that we saw the pet die, but to bound that
-- memory strictly: it is cleared by every event that means "the pet situation
-- changed" (UNIT_PET, zoning, spec change). An unbounded latch would stick on
-- DEAD forever, which is worse than being wrong for a moment.

local state = {}
ns.state = state

state.OK = 'ok'             -- pet is alive; nothing to show
state.DEAD = 'dead'         -- pet is dead and needs reviving
state.MISSING = 'missing'   -- no pet; needs calling
state.HIDDEN = 'hidden'     -- addon does not apply right now
state.UNKNOWN = 'unknown'   -- the client would not tell us

-- Beast Mastery and Survival. Marksmanship is petless by design, so the
-- indicator would be noise there.
local PET_SPECS = {
  [253] = true, -- Beast Mastery
  [255] = true, -- Survival
}

local sawPetDie = false

-- Called for anything that means the pet roster changed. Dropping the memory
-- here is what keeps DEAD from becoming permanent.
function state.Invalidate()
  sawPetDie = false
end

function state.SawPetDie()
  return sawPetDie
end

local function isHunter()
  local _, class = UnitClass('player')
  return class == 'HUNTER'
end

local function hasPetSpec()
  local specID = compat.GetSpecID()
  if not specID then
    -- No spec learned yet, or the API moved. Showing the indicator is the
    -- friendlier failure: a hunter with no pet still wants to know.
    return true
  end
  return PET_SPECS[specID] == true
end

-- Whether the client still considers a hunter pet active, even if the "pet"
-- unit token has stopped answering.
--
-- This is deliberately only a tiebreaker. HasPetUI is known to linger after a
-- pet dies on some builds, so it is trusted to say "something is still there"
-- and never to say "the pet is fine".
local function petUIActive()
  if type(_G.HasPetUI) ~= 'function' then
    return false
  end

  local ok, hasUI, isHunterPet = pcall(_G.HasPetUI)
  if not ok then
    return false
  end

  local usable
  ok, usable = pcall(function()
    return (hasUI and isHunterPet) and true or false
  end)

  return ok and usable or false
end

-- Resolves the current pet state.
--
-- `db` supplies the user's settings; `previous` is the last resolved state and
-- is returned unchanged when the client refuses to answer, so a single
-- unreadable query does not make the indicator flicker.
function state.Resolve(db, previous)
  if not db or not db.enabled then
    return state.HIDDEN
  end

  if not isHunter() or not hasPetSpec() then
    return state.HIDDEN
  end

  if db.hideMounted and compat.IsMounted() then
    return state.HIDDEN
  end

  if compat.InVehicle() then
    return state.HIDDEN
  end

  local exists = compat.SafeFlag(_G.UnitExists, 'pet')
  if exists == nil then
    return previous or state.UNKNOWN
  end

  if exists then
    local dead = compat.SafeFlag(_G.UnitIsDeadOrGhost, 'pet')

    if dead == nil then
      -- The unit is there but its condition is unreadable. Our memory of the
      -- death is the only thing left to go on.
      return sawPetDie and state.DEAD or (previous or state.UNKNOWN)
    end

    if dead then
      sawPetDie = true
      return state.DEAD
    end

    sawPetDie = false
    return state.OK
  end

  -- No pet unit. Either it died and stopped answering, or there genuinely
  -- isn't one.
  if sawPetDie or petUIActive() then
    return state.DEAD
  end

  return state.MISSING
end
