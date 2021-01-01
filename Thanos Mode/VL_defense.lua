/* 
  Author: PHCC
  Date: 30/12/2020

  DEFENSE POWAS!
  
  To be futurely used as the power for the light blue emerald (there is no infinity stone for it, but anyway...)

  This is both a passive and active power. It will ocasionally protect you from some kinds of damage at the cost 
  of 1 ring per defense.
  
  Press BT_CUSTOM2 to stay invulnerable for 3 seconds at the cost of 5 rings
    
*/

local DEFENSESTONE_DRAIN = 5
local DEFENSESTONE_PROTECTION_DRAIN = 1
local INV_DURATION = 3*TICRATE

local function detectThreats(player)
  local shouldDefend = false

  searchBlockmap("objects", function(mo, object) // There is quite a lot of objects with NO_BLOCKMAP flag that can hurt you, and I am not gonna fix that
    if (object.valid)
      if ((object.flags & (MF_ENEMY|MF_BOSS))
          and player.mo.state ~= S_PLAY_DASH
          and player.mo.state ~= S_PLAY_ROLL
          and player.mo.state ~= S_PLAY_JUMP
          and player.mo.state ~= S_PLAY_SPINDASH)
          shouldDefend = true
      end

      if (object.flags & (MF_PAIN|MF_MISSILE|MF_FIRE))
          shouldDefend = true
      end

      return shouldDefend
    end
  end, player.mo, player.mo.x - player.mo.radius, player.mo.x + player.mo.radius, player.mo.y - player.mo.height, player.mo.y + player.mo.height)

  return shouldDefend
end

local function handlePlayerDefense(player)
  if (player.powers[pw_shield] and not(player.powers[pw_shield] == SH_PITY)) return end 
  if (player.powers[pw_flashing] > 2) return end 
  if (player.powers[pw_invulnerability] > 2) return end 

  if (not(player.powers[pw_shield])) 
    player.isdefending = false
  end 

  if (detectThreats(player))
    if (player.rings - DEFENSESTONE_PROTECTION_DRAIN < 0 or player.isdefending) return end
    player.rings = $ - DEFENSESTONE_PROTECTION_DRAIN
    A_PlaySound(player.mo, 162)

    player.powers[pw_shield] = SH_PITY
    P_SpawnShieldOrb(player)
    player.isdefending = true
  elseif (player.isdefending)
    player.isdefending = false
    player.powers[pw_shield] = SH_NONE
  end  
end

local function handleInvulnerability(player)
  if (player.cmd.buttons & BT_CUSTOM2 and not(player.prevcmd & BT_CUSTOM2))
    if (player.powers[pw_flashing] == 0)
      if (player.rings - DEFENSESTONE_DRAIN < 0) return end
      player.rings = $ - DEFENSESTONE_DRAIN
      A_PlaySound(player.mo, 162)

      player.powers[pw_flashing] = INV_DURATION
      player.powers[pw_flashing] = $ - 1
    end 
  end
end

addHook("ThinkFrame", function()
  for player in players.iterate
    if (player.mo and player.mo.valid)

      handlePlayerDefense(player)
      handleInvulnerability(player)

      player.prevcmd = player.cmd.buttons
    end
	end
end)


