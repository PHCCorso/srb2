/* 
  Author: PHCC
  Date: 28/12/2020

  SPACE POWAS!
  
  To be futurely used as the power for the blue emerald (space stone)

  Press BT_CUSTOM2 to bind yourself to a point in space, then press it again to teleport back there!
    
*/

local SPACESTONE_DRAIN = 20
local currentmap

local function createPortal(player)
  if (player.rings - SPACESTONE_DRAIN < 0) return end
  player.rings = $ - SPACESTONE_DRAIN

  local mo = player.mo
  local portal = {}

  portal.x = mo.x
  portal.y = mo.y
  portal.z = mo.z
  portal.playsound = true
  player.portal = portal

  A_PlaySound(mo, 162)
end

local function usePortal(player)
  local portal = player.portal

  P_TeleportMove(player.mo, portal.x, portal.y, portal.z)

  A_PlaySound(portal.player, 198)
  player.portal = nil
end

local function spawnPortalSparkle(portal)
  local playerscale = portal.player.scale
  local sparkle = P_SpawnMobj(portal.x + P_RandomRange(-12,12)*playerscale, portal.y + P_RandomRange(-12,12)*playerscale, portal.z + P_RandomKey(42)*playerscale, MT_BOXSPARKLE)
  
  if (portal.playsound)
    A_PlaySound(sparkle, 184)
    portal.playsound = false
  end
end

addHook("ThinkFrame", function()
  for player in players.iterate
    if (player.portal)
      player.portal.player = player.mo // Yeah, I need it to play the sound
      spawnPortalSparkle(player.portal)

      if (player.cmd.buttons & BT_TOSSFLAG and not(player.prevcmd & BT_TOSSFLAG))
        A_PlaySound(player.mo, 143)
        player.portal = nil
      end
    end

    if (player.cmd.buttons & BT_CUSTOM2 and not(player.prevcmd & BT_CUSTOM2))
      if (not(player.portal))
        createPortal(player)
      else
        usePortal(player)
      end
    end

    player.prevcmd = player.cmd.buttons
  end

  currentmap = gamemap
end)

addHook("MapChange", function(mapnum)
  if (currentmap ~= mapnum) // Keep the portal even after dead
    for player in players.iterate
      player.portal = {} // Clean everything when map changes
    end
  end
end)
