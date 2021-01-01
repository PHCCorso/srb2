/* 
  Author: PHCC
  Date: 30/12/2020

  MIND/SOUL POWAS!
  
  To be futurely used as the power for the orange emerald (mind stone & sould stone combined)

  With this power, you will be able to project yourself out of your body. Be careful that your body will be vulnerable
  to attacks. Plus, you cannot go that far: you have 35 seconds to do your things. While outside of your body, you will
  not be able to kill enemies or pop monitors, but you will be able to catch rings! Also, you will be intangible to any
  wall and invulnerable to any hazards.

  Ah, and that will cost you 20 rings. So use it wisely.
    
*/

local MINDSTONE_DRAIN = 0
local PROJECTION_DURATION = 35*TICRATE

local function doAstralProjection(player) // Disembody yourself
  local mo = player.mo
  local body = P_SpawnMobj(mo.x, mo.y, mo.z, MT_PLAYER)

  // mobj info
  body.angle = mo.angle
  body.sprite = mo.sprite
  body.sprite2 = mo.sprite2
  body.state = S_PLAY_STND
  body.flags = mo.flags & ~MF_SOLID
  body.flags2 = mo.flags2
  body.eflags = mo.eflags
  body.tics = -1
  body.skin = mo.skin
  body.color = mo.color
  body.colorized = mo.colorized

  // player info
  body.powers = {}
  body.powers[pw_spacetime] = player.powers[pw_spacetime]
  body.powers[pw_underwater] = player.powers[pw_underwater]
  body.charflags = player.charflags

  // Connect our ghost to our body, and our body to our ghost
  body.projection = mo
  player.body = body

  P_Thrust(mo, mo.angle, 20*FRACUNIT)
end

local function endAstralProjection(body) // We are bringing our ghost/soul back to our body
  local player = body.projection.player
  local mo = player.mo

  P_TeleportMove(mo, body.x, body.y, body.z)
  mo.angle = body.angle
  mo.sprite = body.sprite
  mo.sprite2 = body.sprite2
  mo.state = body.state
  mo.frame = body.frame
  mo.flags = body.flags
  mo.flags2 = body.flags2
  mo.eflags = body.eflags
  player.powers[pw_spacetime] = body.powers[pw_spacetime]
  player.powers[pw_underwater] = body.powers[pw_underwater]
  P_SpawnShieldOrb(player)

  player.pflags = $ & ~PF_NOCLIP

  player.body = nil
  P_RemoveMobj(body)
end

local function spawnBodyBubbles(body) // Shamelessly stolen from srb2 sourcecode (why do it again when already done?)
  local x = body.x
	local y = body.y
	local z = body.z

	if (not(body.eflags & MFE_UNDERWATER) or body.powers[pw_shield] & SH_PROTECTWATER)
    return
  end

	if (body.charflags & SF_MACHINE)
		if (body.powers[pw_underwater] and P_RandomChance((128-(body.powers[pw_underwater]/4))*FRACUNIT/256))
			r = body.radius>>FRACBITS
			x = $ + (P_RandomRange(r, -r)<<FRACBITS)
			y = $ + (P_RandomRange(r, -r)<<FRACBITS)
			z = $ + (P_RandomKey(body.height>>FRACBITS)<<FRACBITS)
			P_SpawnMobj(x, y, z, MT_WATERZAP)
			S_StartSound(bubble, sfx_beelec)
    end
	else
		if (body.eflags & MFE_VERTICALFLIP)
			z = $ + body.height - FixedDiv(body.height,5*(FRACUNIT/4))
		else
      z = $ + FixedDiv(body.height,5*(FRACUNIT/4))
    end

		if (P_RandomChance(FRACUNIT/16))
			P_SpawnMobj(x, y, z, MT_SMALLBUBBLE)
		elseif (P_RandomChance(3*FRACUNIT/256))
      P_SpawnMobj(x, y, z, MT_MEDIUMBUBBLE)
    end
	end
end

local function handleBodyDrowning(player)
  // If body was left underwater or in space, then let the counter run
  if (player.body.powers[pw_spacetime])
    player.body.powers[pw_spacetime] = $ - 1
    if (player.body.powers[pw_spacetime] <= 0) // Time is up, so you die
      P_KillMobj(player.body)
      P_KillMobj(player.mo, nil, nil, DMG_SPACEDROWN)
    end
  end
  if (player.body.powers[pw_underwater])
    player.body.powers[pw_underwater] = $ - 1
    if (player.body.powers[pw_underwater] <= 0)
      P_KillMobj(player.body)
      P_KillMobj(player.mo, nil, nil, DMG_DROWNED)
    end
  end

  // Setting the timers for our player as well
  player.powers[pw_spacetime] = player.body.powers[pw_spacetime]
  player.powers[pw_underwater] = player.body.powers[pw_underwater]

  // Why not also spawn some bubbles?
  spawnBodyBubbles(player.body)
end

local function handlePlayerProjection(player)

  // If button pressed
  if (player.cmd.buttons & BT_CUSTOM2 and not(player.prevcmd & BT_CUSTOM2))
    local mo = player.mo
    if (mo.momx > 0 or mo.momy > 0 or mo.momz > 0) return end // Just do it while stopped
    
    if (not(player.body))
      if (player.rings - MINDSTONE_DRAIN < 0) return end // Not enough rings, stop it
      doAstralProjection(player)
    else
      endAstralProjection(player.body)
    end
  end

  // Actual handling
  if (player.body and player.body.valid)
    // For space or underwater situations
    handleBodyDrowning(player)

    // Turning the player into a ghost
    player.mo.frame = $ & ~FF_TRANSMASK
    player.mo.frame = $ | TR_TRANS60
    player.pflags = $ | PF_NOCLIP

    searchBlockmap("objects", function(mo, object) 
      if (object.valid)
      // We want our ghost to be able to grab collectibles (rings and such), so we are not always intangible
        if (not(object.flags & (MF_ENEMY|MF_BOSS|MF_PUSHABLE|MF_SOLID)))
          player.pflags = $ & ~PF_NOCLIP
          return true
        end
      end
    end, player.mo, player.mo.x - player.mo.radius, player.mo.x + player.mo.radius, player.mo.y - player.mo.height/2, player.mo.y + player.mo.height/2)
  end
end

// Start: main "ghost mode" handlers

addHook("MobjDeath", function(mo, inflictor, source, damagetype)
  if (mo.valid and mo.player and mo.player.valid)
    if (damagetype == DMG_DROWNED or damagetype == DMG_SPACEDROWN) return end // If our "true body" drowns, then we also die
    local player = mo.player
    if (player.body and player.body.valid)
      return true // Our own "god mode" for the ghost player
    end
  end
end)

addHook("ShouldDamage", function(mo) // Ghost player cannot be damaged
  if (mo.valid and mo.player and mo.player.valid)
    local player = mo.player
    if (player.body and player.body.valid)
      return false
    end
  end
end)

addHook("PlayerCanDamage", function(player, object) // Ghost player also cannot damage anything
    if (player.mo and player.mo.valid)
      if (player.body and player.body.valid)
        return false
      end
    end
end)

addHook("MobjThinker", function(mo) 
  if (mo.target and mo.target.valid)
    local target = mo.target
    if (target.player and target.player.valid)
      if (target.player.body and target.player.body.valid)
        mo.target = target.player.body // Do not target our ghost, target our body!
      end
    end
  end
end)

// Handling damage for our vulnerable body
addHook("MobjMoveCollide", function(toucher, touched)
  if (toucher.valid and touched.valid)
    if (toucher.flags & (MF_ENEMY|MF_BOSS|MF_PAIN|MF_MISSILE|MF_FIRE)
    and touched.projection and touched.projection.valid)
      P_DamageMobj(touched.projection, toucher) // If our body was hit, then we damage the player connected to it
      endAstralProjection(touched) // You got hit, go back to your body
    end
  end
end)

// End: main "ghost mode" handlers

addHook("MapChange", function(player, object)
  for player in players.iterate
    if (player.mo and player.mo.valid)
      player.body = nil
      resetPlayerFlags(player)
    end
	end
end)

addHook("ThinkFrame", function()
  for player in players.iterate
    if (player.mo and player.mo.valid)

      handlePlayerProjection(player)

      player.prevcmd = player.cmd.buttons
    end
	end
end)


