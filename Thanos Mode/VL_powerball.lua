/* 
  Author: PHCC
  Date: 29/12/2020

  ENERGY POWAS!
  
  To be futurely used as the power for the purple emerald (space stone)

  Press BT_CUSTOM2 to summon an energy ball that will follow you around, destroying all nearby enemies
    
*/

local POWERSTONE_DRAIN = 15
local POWERBALL_LIFE = 20*TICRATE
local POWERBALL_RADIUS = 192
local POWERBALL_ROTSPEED = 1<<24
local POWERBALL_SPEED = 256*FRACUNIT
local POWERBALL_RANGE = 1024*FRACUNIT

local SPECIAL_MOBJS = {
  [MT_EGGSHIELD] = true
}

addHook("ShouldDamage", function(player, inflictor) 
  if (player.powerball == inflictor)
    return false
  end
end, MT_PLAYER)

local function summonPowerBall(player)
  if (player.rings - POWERSTONE_DRAIN < 0) return end
  player.rings = $ - POWERSTONE_DRAIN
  A_PlaySound(player.mo, 162)

  local powerball = P_SpawnMobj(player.mo.x, player.mo.y, player.mo.z + player.mo.height, MT_ENERGYBALL)
  powerball.target = player.mo
  powerball.scale = $/4
  powerball.life = POWERBALL_LIFE
  player.mo.powerball = powerball
end

local function isCloseEnough(mobjA, mobjB, hthreshold)
  local dx = mobjA.x - mobjB.x
  local dy = mobjA.y - mobjB.y
  
  local hdist = P_AproxDistance(dx, dy)
  local dz = mobjA.z - mobjB.z

  if (hdist - hthreshold <= 0 and dz - mobjA.height <= 0)
    return true
  end

  return false
end

local function powerBallThinker(powerball)
  if (not(powerball.valid)) return end

  local player = powerball.target.player

  if (powerball.life == 0)
    P_KillMobj(powerball)
    player.mo.powerball = nil
    return
  end
  powerball.life = $ - 1

  S_StartSoundAtVolume(powerball, 30, 100)

  if (not(powerball.tracer and powerball.tracer.valid))
    local target

    searchBlockmap("objects", function(player, object) 
      if(object.valid and (object.flags & (MF_ENEMY|MF_BOSS) or SPECIAL_MOBJS[object.type]))
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
        A_Custom3DRotate(powerball, POWERBALL_RADIUS, POWERBALL_ROTSPEED)
      else
        A_HomingChase(powerball, POWERBALL_SPEED, 0)
      end
    end
  else
    powerball.onplayerradius = false
    A_HomingChase(powerball, POWERBALL_SPEED, 1)
    if (isCloseEnough(powerball, powerball.tracer, powerball.height))
        P_DamageMobj(powerball.tracer, powerball, player.mo)
        if (SPECIAL_MOBJS[powerball.tracer.type])
          P_KillMobj(powerball.tracer)
        end
        powerball.tracer = nil
    end
  end
end

addHook("ThinkFrame", function()
  for player in players.iterate
    if(player.mo and player.mo.valid)

      if (player.cmd.buttons & BT_CUSTOM2 and not(player.prevcmd & BT_CUSTOM2))
        if (not(player.mo.powerball))
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


