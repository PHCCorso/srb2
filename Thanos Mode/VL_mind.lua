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
  
  Press BT_CUSTOM2 to disembody yourself
*/

local MINDSTONE_DRAIN = 0
local PROJECTION_DURATION = 35*TICRATE
local GASPSTATETICS = TICRATE/2

local function doAstralProjection(player) // Disembody yourself (inspired on P_SpawnGhostMobj)
  local mo = player.mo
  local body = P_SpawnMobj(mo.x, mo.y, mo.z, MT_PLAYER)

  // mobj info
  body.angle = mo.angle
  body.scale = mo.scale
  body.sprite = mo.sprite
  body.sprite2 = mo.sprite2
  body.state = S_PLAY_STND
  body.flags = mo.flags & ~MF_SOLID
  body.flags2 = mo.flags2
  body.eflags = mo.eflags
  body.skin = mo.skin
  body.color = mo.color
  body.colorized = mo.colorized

  // player info
  body.powers = {}
  body.powers[pw_spacetime] = player.powers[pw_spacetime]
  body.powers[pw_underwater] = player.powers[pw_underwater]
  body.powers[pw_shield] = player.powers[pw_shield]
  body.charflags = player.charflags

  // random thing
  body.gaspstatetics = 0

  if (player.followmobj)
    local followmobj = P_SpawnMobj(player.followmobj.x, player.followmobj.y, player.followmobj.z, player.followitem)
    followmobj.angle = player.followmobj.angle
    followmobj.sprite = player.followmobj.sprite
    followmobj.sprite2 = player.followmobj.sprite2
    followmobj.state = player.followmobj.state
    followmobj.flags = player.followmobj.flags & ~MF_SOLID
    followmobj.eflags = player.followmobj.eflags
    followmobj.skin = player.followmobj.skin
    followmobj.color = player.followmobj.color
    followmobj.colorized = player.followmobj.colorized

    followmobj.flags2 = player.followmobj.flags2 & ~MF2_LINKDRAW // Solving dispoffset issues

    followmobj.target = body
    followmobj.target = body
    body.tracer = followmobj

    body.followmobj = followmobj
  end

  // Connect our ghost to our body, and our body to our ghost
  body.projection = mo
  player.body = body

  P_Thrust(mo, mo.angle, 20*FRACUNIT)
end

local function endAstralProjection(body, damaged) // We are bringing our ghost/soul back to our body
  local player = body.projection.player
  local mo = player.mo

  P_TeleportMove(mo, body.x, body.y, body.z)
  mo.angle = body.angle
  mo.scale = body.scale
  mo.sprite = body.sprite
  mo.sprite2 = body.sprite2
  mo.state = body.state
  mo.frame = body.frame
  mo.flags = body.flags
  mo.flags2 = body.flags2
  mo.eflags = body.eflags
  player.powers[pw_spacetime] = body.powers[pw_spacetime]
  player.powers[pw_underwater] = body.powers[pw_underwater]

  if(not(damaged)) // To handle special cases
    player.powers[pw_shield] = body.powers[pw_shield] // Give back the shield
  end
  P_SpawnShieldOrb(player)

  player.pflags = $ & ~PF_NOCLIP

  player.body = nil

  if (body.followmobj)
    P_RemoveMobj(body.followmobj)
  end
  if (body.shield)
    P_RemoveMobj(body.shield)
  end
  P_RemoveMobj(body)
end

local function spawnBodyBubbles(body) // Shamelessly stolen from srb2 sourcecode — P_DoBubbleBreath (why do it again when already done?)
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
  local body = player.body

  // If body was left underwater or in space, then let the counter run
  if (body.powers[pw_spacetime])
    body.powers[pw_spacetime] = $ - 1
    if (body.powers[pw_spacetime] <= 0) // Time is up, so you die
      endAstralProjection(body, true)
      P_KillMobj(player.mo, nil, nil, DMG_SPACEDROWN)
      return
    end
  end
  if (body.powers[pw_underwater])
    body.powers[pw_underwater] = $ - 1
    if (body.powers[pw_underwater] <= 0)
      endAstralProjection(body, true)
      P_KillMobj(player.mo, nil, nil, DMG_DROWNED)
      return
    end
  end

  // Setting the timers for the player as well
  player.powers[pw_spacetime] = body.powers[pw_spacetime]
  player.powers[pw_underwater] = body.powers[pw_underwater]

  // Spawn some bubbles to make it look real
  spawnBodyBubbles(body)

  if (body.gaspstatetics == GASPSTATETICS) // We just breathed an air bubble
    body.state = S_PLAY_GASP
    S_StartSound(body, 13)
    body.powers[pw_underwater] = underwatertics
    body.gaspstatetics = $ - 1
  elseif (body.gaspstatetics > 0)
    body.gaspstatetics = $ - 1
  else
    body.state = S_PLAY_STND
  end
end

local function handlePlayerProjection(player)

  // If button pressed
  if (player.cmd.buttons & BT_CUSTOM2 and not(player.prevcmd & BT_CUSTOM2))
    local mo = player.mo
    if (mo.momx > 0 or mo.momy > 0 or mo.momz > 0) return end // Just do it while standing still
    
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

    if (player.followmobj)
      player.followmobj.frame = $ & ~FF_TRANSMASK
      player.followmobj.frame = $ | TR_TRANS60
    end

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

local function handleShieldShit(body, shield)
  body.shield = P_SpawnMobj(body.x, body.y, body.z, MT_THOK)
  body.shield.state = shield.state
  body.shield.dispoffset = 2
  if (shield.tracer and shield.tracer.valid)
    body.shield.tracer = P_SpawnMobj(body.x, body.y, body.z, shield.tracer.type)
    body.shield.tracer.target = body.shield
    body.shield.tracer.state = shield.tracer.state
  end
  
  // Keep those tails inside that shield!!
  body.shield.dispoffset = 3

  // Once we have the shield, remove it from the player, we add it back later
  body.projection.player.powers[pw_shield] = SH_NONE 
end

addHook("MobjThinker", function(mo) 
  if (mo.target and mo.target.valid)
    local target = mo.target
    if (target.player and target.player.valid)
      if (target.player.body and target.player.body.valid)
        local body = target.player.body

        // Exception for shields
        if (mo.flags2 & MF2_SHIELD)
          handleShieldShit(body, mo)
          return
        end

        if (P_CheckSight(mo, body))
          mo.target = body // Do not target our ghost, target our body!
        else
          mo.target = nil // If you cannot see our real body, then stop targetting us
        end
      end
    end
  end
end)

addHook("MobjMoveCollide", function(toucher, touched)
  if (toucher.valid and touched.valid)
    if (touched.projection and touched.projection.valid)
      if (toucher.flags & (MF_ENEMY|MF_BOSS|MF_PAIN|MF_MISSILE|MF_FIRE)) // Handling damage for our vulnerable body
        local player = touched.projection.player
        player.powers[pw_shield] = touched.powers[pw_shield] // We give back the shield beforehand so it is handled correctly
        P_DamageMobj(touched.projection, toucher) // If our body was hit, then we damage the player connected to it
        endAstralProjection(touched) // You got hit, go back to your body
      end

      if (toucher.type == MT_EXTRALARGEBUBBLE and toucher.z >= touched.z + touched.height/2) // Handling breathing if left on an air bubble patch
        P_RemoveMobj(toucher)
        touched.gaspstatetics = GASPSTATETICS // wait a little to return to stand state
      end
    end
  end
end)

// End: main "ghost mode" handlers

addHook("MapChange", function(player, object)
  for player in players.iterate
    if (player.mo and player.mo.valid)
      player.body = nil
      player.pflags = $ & ~PF_NOCLIP
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


