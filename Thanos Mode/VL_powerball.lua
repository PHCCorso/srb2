/* 
  Author: PHCC
  Date: 29/12/2020

  ENERGY POWAS!
  
  To be futurely used as the power for the purple emerald (power stone)

  Press BT_CUSTOM2 to summon an energy ball that will follow you around, destroying all nearby enemies
    
*/

local POWERSTONE_DRAIN = 15
local POWERBALL_LIFE = 12*TICRATE
local POWERBALL_RADIUS = 192
local POWERBALL_ROTSPEED = 1<<24
local POWERBALL_SPEED = 256*FRACUNIT
local POWERBALL_RANGE = 1024*FRACUNIT

local SPECIAL_MOBJS = { // Oh, there are always special cases
  [MT_EGGSHIELD] = true
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

local function powerBallThinker(powerball)
  if (not(powerball.valid)) return end

  local player = powerball.target.player

  if (powerball.life <= 0)
    S_StartSound(powerball, 120)
    P_KillMobj(powerball)
    player.mo.powerball = nil
    return
  end
  powerball.life = $ - 1

  S_StartSoundAtVolume(powerball, 30, 100)

  if (not(powerball.tracer and powerball.tracer.valid))
    local target

    searchBlockmap("objects", function(_, object) 
      if(object.valid 
         and (object.flags & (MF_ENEMY|MF_BOSS) or SPECIAL_MOBJS[object.type])
         and (powerball.prevtarget ~= object)) // The previous one (if not dead) is still flickering
        target = object
        return true
      end
    end, player.mo, player.mo.x - POWERBALL_RANGE, player.mo.x + POWERBALL_RANGE, player.mo.y - POWERBALL_RANGE/2, player.mo.y + POWERBALL_RANGE/2)

    if (target)
      S_StartSound(powerball, 109)
      powerball.tracer = target
    else
      if (isCloseEnough(powerball, player.mo, FixedMul(POWERBALL_RADIUS*FRACUNIT, powerball.scale) + powerball.height))
        powerball.onplayerradius = true // This is due to Z distance shit
      end

      if (powerball.onplayerradius)
        powerball.prevtarget = nil
        A_Custom3DRotate(powerball, POWERBALL_RADIUS, POWERBALL_ROTSPEED)
      else
        A_HomingChase(powerball, POWERBALL_SPEED, 0) // Go back to the player... graciously
      end
    end
  else
    powerball.onplayerradius = false
    A_HomingChase(powerball, POWERBALL_SPEED, 1) // Hunt down those f*ers
    if (isCloseEnough(powerball, powerball.tracer, powerball.height))
        P_DamageMobj(powerball.tracer, powerball, player.mo)
        if (SPECIAL_MOBJS[powerball.tracer.type])
          P_KillMobj(powerball.tracer) // If cannot damage, kill it
        end

        // Slow down, friend!
        powerball.momx = 0
        powerball.momy = 0
        powerball.momz = 0

        // Keep froom hitting the same enemy again
        powerball.prevtarget = powerball.tracer
        powerball.tracer = nil
    end
  end
end

addHook("ThinkFrame", function()
  for player in players.iterate
    if(player.mo and player.mo.valid)

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


