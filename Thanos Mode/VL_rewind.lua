/* 
  Author: PHCC
  Date: 28/12/2020

  TIME POWAS!
  
  To be futurely used as the power for the green emerald (time stone)

  Press BT_CUSTOM2 to rewind!
    
*/

local MAX_REWIND_CHAIN_LENGTH = 10 * TICRATE
local TIMESTONE_DRAIN = 1

function A_GetPlayerState(player, stack) // Imma making every function global because local scope sucks
  local state = {}
  state.powers = {}

  // Only the relevant powers, we dont want to bring back shields/invincibility/etc
  state.powers[pw_flashing] = player.powers[pw_flashing]
  state.powers[pw_carry] = player.powers[pw_carry]
  state.powers[pw_tailsfly] = player.powers[pw_tailsfly]
  state.powers[pw_spacetime] = player.powers[pw_spacetime]
  state.powers[pw_underwater] = player.powers[pw_underwater]
  state.powers[pw_nocontrol] = 1<<15

  if (player.followmobj)
    state.followmobjstate = A_GetMobjState(player.followmobj, stack) // For Tails and Metal Sonic
  end

  state.pflags = player.pflags | PF_FULLSTASIS // stop moving

  // Interesting data to keep track of, not sure if this is necessary, though
  state.jumping = player.jumpingw
  state.secondjump = player.secondjump
  state.fly1 = player.fly1
  state.glidetime = player.glidetime
  state.climbing = player.climbing

  return state
end

function A_SetPlayerState(player, state, stack)
  player.powers[pw_flashing] = state.powers[pw_flashing]
  player.powers[pw_carry] = state.powers[pw_carry]
  player.powers[pw_tailsfly] = state.powers[pw_tailsfly]
  player.powers[pw_spacetime] = state.powers[pw_spacetime]
  player.powers[pw_underwater] = state.powers[pw_underwater]

  if (state.followmobjstate)
    A_SetMobjState(player.followmobj, state.followmobjstate, stack)
  end

  player.pflags = state.pflags
  player.jumping = state.jumping
  player.secondjump = state.secondjump
  player.fly1 = state.fly1
  player.glidetime = state.glidetime
  player.climbing = state.climbing
end

function A_GetMobjState(mo, stack)
  local state = {}
  if (not(stack)) // Yup, a stack. You will understand it later
    stack = {}
  end
  stack[mo] = state

  if (mo.player and not(stack[mo.player])) // avoid infinite recursion here
    state.player = A_GetPlayerState(mo.player, stack) // Yup, we pass the stack here because we call A_GetMobjState there too
  end

  // Alright, imma copy everything I can
  state.x = mo.x
  state.y = mo.y
  state.z = mo.z
  state.momx = mo.momx
  state.momy = mo.momy
  state.momz = mo.momz
  state.angle = mo.angle
  state.rollangle = mo.rollangle
  state.state = mo.state
  state.frame = mo.frame
  state.health = mo.health
  state.flags = mo.flags
  if (mo.type == MT_PLAYER)
    state.flags = $ | MF_NOCLIP // Lets make the player able to rewind through walls
  end
  state.flags2 = mo.flags2
  state.eflags = mo.eflags
  state.spawnpoint = mo.spawnpoint
  state.tics = mo.tics
  state.scale = mo.scale
  state.fuse = mo.fuse
  state.extravalue1 = mo.extravalue1
  state.extravalue2 = mo.extravalue2
  if (mo.tracer) // The tracer comes with us
    state.tracer = mo.tracer
    state.tracertype = mo.tracer.type
    if (stack[mo.tracer]) // This means we have already stored the state of that mobj. Avoid infinite recursion.
      state.tracerstate = stack[mo.tracer] 
    else
      state.tracerstate = A_GetMobjState(state.tracer, stack) // Why stop at the top level?
    end
  end
  if (mo.target) // Same thing for the target
    state.target = mo.target
    state.targettype = mo.target.type
    if (stack[mo.target])
      state.targetstate = stack[mo.target]
    else
      state.targetstate = A_GetMobjState(state.target, stack)
    end
  end

  return state
end

function A_SetMobjState(mo, state, stack)
  if (not(stack))
    stack = {} // Stack here again
  end
  stack[mo] = state

  if (mo.player)
    A_SetPlayerState(mo.player, state.player, stack)
  end

  P_TeleportMove(mo, state.x, state.y, state.z)
  mo.momx = state.momx
  mo.momy = state.momy
  mo.momz = state.momz
  mo.angle = state.angle
  mo.rollangle = state.rollangle
  mo.state = state.state
  mo.frame = state.frame
  mo.health = state.health
  mo.flags = state.flags
  mo.flags2 = state.flags2
  mo.eflags = state.eflags
  mo.spawnpoint = state.spawnpoint
  mo.tics = state.tics
  mo.scale = state.scale
  mo.fuse = state.fuse
  mo.extravalue1 = state.extravalue1
  mo.extravalue2 = state.extravalue2

  if (state.tracer and not(stack[state.tracer]))
    if (state.tracer.valid)
      A_SetMobjState(state.tracer, state.tracerstate, stack)
    elseif (mo.tracer and mo.tracer.valid) // If we spawned a new tracer from a previous state, then we get it from here
      A_SetMobjState(mo.tracer, state.tracerstate, stack)
    else // If the tracer is gone, spawn it back! Specially relevant for minecarts
      local newtracer = P_SpawnMobj(state.tracerstate.x, state.tracerstate.y, state.tracerstate.z, state.tracertype)
      A_SetMobjState(newtracer, state.tracerstate, stack)
      mo.tracer = newtracer
    end
  else
    mo.tracer = state.tracer // Probably nil, but leave it here
  end
  if (state.target and not(stack[state.target])) // Exact same thing done with the tracer, too lazy to make it generic
    if (state.target.valid)
      A_SetMobjState(state.target, state.targetstate, stack)
    elseif (mo.target and mo.target.valid)
      A_SetMobjState(mo.target, state.targetstate, stack)
    else
      local newtarget = P_SpawnMobj(state.targetstate.x, state.targetstate.y, state.targetstate.z, state.targettype)
      A_SetMobjState(newtarget, state.targetstate, stack)
      mo.target = newtarget
    end
  else
    mo.target = state.target
  end
end



local function addNewStateToPlayerChain(player, state) // If you dont understand linked lists, then what are you doing here?
  if (not(player.rewindchain))
    player.rewindchain = {}
  end

  local chain = player.rewindchain

  if (not(chain.laststate))
    state.prevstate = chain
    chain.nextstate = state
    chain.laststate = state
  else
    state.prevstate = chain.laststate
    chain.laststate.nextstate = state
    chain.laststate = state
  end

  if (not(chain.length))
    chain.length = 1
  else
    chain.length = $ + 1
  end	

  if (chain.length == MAX_REWIND_CHAIN_LENGTH) // Limit was reached, we do it FIFO and throw away the oldest state
    player.rewindchain = chain.nextstate
    player.rewindchain.length = chain.length - 1
    chain.nextstate.laststate = chain.laststate
    chain.nextstate.prevstate = nil // Clean references just to be sure
  end
end

local function rewind(player) // Where the magic happens
  if (player.rings - TIMESTONE_DRAIN <= 0) return end // No rings, no back in time. But we leave you a ring so you dont die
  
  if (player.rewindchain.length > 1 and player.rewindchain.length % TICRATE == 0) // We only drain rings every second
    player.rings = $ - TIMESTONE_DRAIN
  end

  local chainnode = player.rewindchain.laststate
  
  if (not(chainnode) or not(chainnode.prevstate)) return end

  A_SetMobjState(player.mo, chainnode) // But the real magic is here

  player.rewindchain.length = $ - 1
  player.rewindchain.laststate = chainnode.prevstate
  chainnode.prevstate.nextstate = nil // Clean references just to be sure 2
  chainnode.prevstate = nil // Clean references just to be sure 3
end

addHook("MobjDeath", function(target)
  //local tracer = {} // For debugging
  //if (target.tracer)
  //  tracer = target.tracer
  //end
  //print(string.format("target: %s, tracer: %s", tostring(target.type), tostring(tracer.type)))*/

  if (target.player and target.player.rewinding) // No dying while rewinding. Specially useful for minecarts.
    target.health = 1
    return true
  end
end)

addHook("ThinkFrame", function() // The intention is for this to work with all skins
  for player in players.iterate
    if (player.cmd.buttons & BT_CUSTOM2)
      player.rewinding = true
      rewind(player)
    else
      player.rewinding = false
      player.mo.flags = $ & ~MF_NOCLIP
      player.powers[pw_nocontrol] = 0
      addNewStateToPlayerChain(player, A_GetMobjState(player.mo))
    end
  end
end)

addHook("MapChange", function(gamemap)
  for player in players.iterate
    player.rewindchain = {} // Clean everything when map changes
  end
end)
