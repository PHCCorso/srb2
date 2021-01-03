/* 
  Author: PHCC
  Date: 29/12/2020

  ENERGY POWAS!
  
  To be futurely used as the power for the purple emerald (power stone)

  Press BT_CUSTOM2 to summon an energy ball that will follow you around, destroying all nearby enemies
    
*/

local POWERSTONE_DRAIN = 0
local POWERBALL_LIFE = 500*TICRATE
local POWERBALL_RADIUS = 192
local POWERBALL_ROTSPEED = 1<<24
local POWERBALL_SPEED = 256*FRACUNIT
local POWERBALL_RANGE = 768*FRACUNIT

local SPECIAL_MOBJS = { // Oh, there are always special cases
  [MT_EGGSHIELD] = true,
  [MT_THOK] = true
}

addHook("ShouldDamage", function(player, inflictor) 
  if (player.powerball and player.powerball == inflictor) // The player who summoned it cannot be damaged
    return false
  end
end, MT_PLAYER)

addHook("MobjDeath", function(powerball) 
  if (powerball.life and powerball.life > 0) // The powerball is UNKILLABLE!!!
    powerball.health = 1
    return true
  end
end, MT_ENERGYBALL)

local function summonPowerBall(player)
  if (player.rings - POWERSTONE_DRAIN < 0) return end
  player.rings = $ - POWERSTONE_DRAIN
  A_PlaySound(player.mo, 162)

  local powerball = P_SpawnMobj(player.mo.x, player.mo.y, player.mo.z + player.mo.height, MT_ENERGYBALL)
  powerball.target = player.mo
  powerball.scale = $/4
  powerball.life = POWERBALL_LIFE
  powerball.flags = $ | MF_NOCLIP | MF_NOGRAVITY | MF_NOCLIPTHING
  player.mo.powerball = powerball
end

local function isCloseEnough(mobjA, mobjB, hthreshold) // I dont know what I am doing
  local dx = abs(mobjA.x - mobjB.x)
  local dy = abs(mobjA.y - mobjB.y)
  
  local hdist = P_AproxDistance(dx, dy)
  local dz = abs(mobjA.z - mobjB.z)
  local maxradius = max(mobjA.radius, mobjB.radius)
  local maxheight = max(mobjA.height, mobjB.height)

  if (hdist - maxradius - hthreshold <= 0 and dz - maxheight <= 0)
    return true
  end

  return false
end

local function isInRange(n, lowerlimit, upperlimit)
  if (n >= lowerlimit and n <= upperlimit)
    return true
  end
  return false
end

local function isIn3dRange(x, y, z, limits)
  if (not(isInRange(x, limits.lower_x, limits.upper_x)))
    return false
  elseif (not(isInRange(y, limits.lower_y, limits.upper_y)))
    return false
  elseif (not(isInRange(z, limits.lower_z, limits.upper_z)))
    return false
  end

  return true
end

local function searchEnemy(powerball, player)
  local target

  local limits = {
    lower_x = player.mo.x - POWERBALL_RANGE,
    upper_x = player.mo.x + POWERBALL_RANGE,
    lower_y = player.mo.y - POWERBALL_RANGE,
    upper_y = player.mo.y + POWERBALL_RANGE,
    lower_z = player.mo.z - POWERBALL_RANGE/2,
    upper_z = player.mo.z + POWERBALL_RANGE/2
  }

  searchBlockmap("objects", function(_, object) 
    if (object.valid 
      and (object.flags & (MF_ENEMY|MF_BOSS) or SPECIAL_MOBJS[object.type])
      and isIn3dRange(object.x, object.y, object.z, limits)
      and (powerball.prevtarget ~= object)) // The previous one (if not dead) is still flickering
      target = object
      return true
    end
  end, player.mo, limits.lower_x, limits.upper_x, limits.lower_y, limits.upper_y)

  return target
end

local function searchWallsToBreak(powerball, player)
  local target

  local limits = {
    lower_x = player.mo.x - POWERBALL_RANGE/4,
    upper_x = player.mo.x + POWERBALL_RANGE/4,
    lower_y = player.mo.y - POWERBALL_RANGE/4,
    upper_y = player.mo.y + POWERBALL_RANGE/4,
    lower_z = player.mo.z - POWERBALL_RANGE,
    upper_z = player.mo.z + POWERBALL_RANGE
  }

  // Lets find some bustable blocks
  searchBlockmap("lines", function(_, line) 
    if (line.valid)
      local x = (line.v1.x + line.v2.x)/2 
      local y = (line.v1.y + line.v2.y)/2 

      if (line.frontsector and line.frontsector.valid)
        for rover in line.frontsector.ffloors()
          if (rover.valid and rover.flags & FF_BUSTUP and rover.flags & FF_EXISTS)
            local middlez = (rover.topheight + rover.bottomheight)/2 

            if (isIn3dRange(x, y, middlez, limits)
             or isIn3dRange(x, y, rover.topheight, limits)
             or isIn3dRange(x, y, rover.bottomheight, limits))
              target = {}
              target.v1 = line.v1
              target.v2 = line.v2
              target.bustsec = line.frontsector
              target.bustrover = rover
              return true
            end
          end
        end
      end

      if (line.backsector and line.backsector.valid)
        for rover in line.backsector.ffloors()
          if (rover.valid and rover.flags & FF_BUSTUP and rover.flags & FF_EXISTS)
            local middlez = (rover.topheight + rover.bottomheight)/2 

            if (isIn3dRange(x, y, middlez, limits)
             or isIn3dRange(x, y, rover.topheight, limits)
             or isIn3dRange(x, y, rover.bottomheight, limits))
              target = {}
              target.v1 = line.v1
              target.v2 = line.v2
              target.bustsec = line.frontsector
              target.bustrover = rover
              return true
            end
          end
        end
      end
    end
  end, player.mo, limits.lower_x, limits.upper_x, limits.lower_y, limits.upper_y)

  if (target)
    local x = (target.v1.x + target.v2.x)/2 
    local y = (target.v1.y + target.v2.y)/2 
    local z = (target.bustrover.topheight + target.bustrover.bottomheight)/2 

    // We spawn a mobj on the middle point
    local dummyMobj = P_SpawnMobj(x, y, z, MT_THOK)
    dummyMobj.flags2 = MF2_DONTDRAW
    dummyMobj.bustsec = target.bustsec
    dummyMobj.bustrover = target.bustrover

    target = dummyMobj
  end

  return target
end

local function returnToMaster(powerball, player)
  if (isCloseEnough(powerball, player.mo, FixedMul(POWERBALL_RADIUS*FRACUNIT, powerball.scale) + powerball.height))
    powerball.onplayerradius = true // This is due to Z distance shit
  end

  if (powerball.onplayerradius)
    powerball.prevtarget = nil
    // If in radius, float around player
    A_Custom3DRotate(powerball, POWERBALL_RADIUS, POWERBALL_ROTSPEED)
  else
    A_HomingChase(powerball, POWERBALL_SPEED, 0) // Go back to the player... graciously
  end
end

local function chaseAndDestroyTarget(powerball, player)
  powerball.onplayerradius = false
  A_HomingChase(powerball, POWERBALL_SPEED, 1) // Hunt down those f*ers

  local target = powerball.tracer
  if (isCloseEnough(powerball, target, powerball.height))
    P_DamageMobj(target, powerball, player.mo)
    if (SPECIAL_MOBJS[target.type])
      if (target.bustsec and target.bustsec.valid and target.bustrover and target.bustrover.valid)
        EV_CrumbleChain(target.bustsec, target.bustrover) // Break it!
      end
      P_KillMobj(target) // If cannot damage, kill it
    end

    // Slow down, friend!
    powerball.momx = 0
    powerball.momy = 0
    powerball.momz = 0

    // Keep from hitting the same enemy again
    powerball.prevtarget = powerball.tracer
    powerball.tracer = nil
  end
end

local function powerBallThinker(powerball)
  if (not(powerball.valid)) return end

  local player = powerball.target.player

  if (powerball.life <= 0) // Your time is over
    S_StartSound(powerball, 120)
    P_KillMobj(powerball)
    player.mo.powerball = nil
    return
  end
  powerball.life = $ - 1

  S_StartSoundAtVolume(powerball, 30, 100)

  if (not(powerball.tracer and powerball.tracer.valid)) // We do not have a target yet
    if (not(P_CheckSight(powerball, player.mo)))
      returnToMaster(powerball, player) // Dont leave me alone
      return
    end

    local target = searchEnemy(powerball, player, limits)

    if (not(target))
      // Ok, we did not find enemies, so we look for something to break
      target = searchWallsToBreak(powerball, player, limits)
    end

    if (target)
      S_StartSound(powerball, 109)
      powerball.tracer = target
    else
      // Nothing to destroy =´(
      returnToMaster(powerball, player)
    end
  else
    chaseAndDestroyTarget(powerball, player)
  end
end

addHook("ThinkFrame", function()
  for player in players.iterate
    if (player.mo and player.mo.valid)

      if (player.cmd.buttons & BT_CUSTOM2 and not(player.prevcmd & BT_CUSTOM2))
        if (not(player.mo.powerball and player.mo.powerball.valid))
          summonPowerBall(player)
        end
      end

      if (player.mo.powerball)
        powerBallThinker(player.mo.powerball)
      end

      player.prevcmd = player.cmd.buttons
    end
	end
end)


