/* 
  Author: PHCC
  Date: 03/01/2021

  CREATION POWAS!
  
  To be futurely used as the power for the red emerald (reality stone)

  This power allows you to bring to reality a power-up of your choice (and a 10-ring monitor, for irony).
  It has a variable cost — depends on what you want to create
  
  Press BT_CUSTOM2 to enter the creation state, then press jump to go forward or spint to go back. When
  finished, press BT_CUSTOM2 again.
    
*/

local REALITYSTONECOSTS = {
  [MT_SNEAKERS_BOX] = 5,
  [MT_GRAVITY_BOX] = 10,
  [MT_RING_BOX] = 12, // HA HA
  [MT_MYSTERY_BOX] = 15,
  [MT_PITY_BOX] = 15,
  [MT_ATTRACT_BOX] = 20,
  [MT_THUNDERCOIN_BOX] = 20,
  [MT_FORCE_BOX] = 20,
  [MT_WHIRLWIND_BOX] = 20,
  [MT_FLAMEAURA_BOX] = 20,
  [MT_BUBBLEWRAP_BOX] = 20,
  [MT_ELEMENTAL_BOX] = 25,
  [MT_ARMAGEDDON_BOX] = 25,
  [MT_INVULN_BOX] = 28
}

local ITEM_LIST = {
  MT_SNEAKERS_BOX, MT_GRAVITY_BOX, MT_RING_BOX, 
  MT_MYSTERY_BOX, MT_PITY_BOX, MT_ATTRACT_BOX,
  MT_THUNDERCOIN_BOX, MT_FORCE_BOX, MT_WHIRLWIND_BOX,
  MT_FLAMEAURA_BOX, MT_BUBBLEWRAP_BOX, MT_ELEMENTAL_BOX,
  MT_ARMAGEDDON_BOX, MT_INVULN_BOX
}


local function handleCreationPower(player)
  if (player.cmd.buttons & BT_CUSTOM2 and not(player.prevcmd & BT_CUSTOM2))
    if (player.mo.momx > 0 or player.mo.momy > 0 or player.mo.momz > 0) return end // Just do it while standing still

    if (not(player.creating))
      player.prevcreationcmd = 0
      player.creating = true
    else
      player.creating = false
    end
    
    player.choiceindex = 1
  end
end

addHook("PreThinkFrame", function()
  for player in players.iterate
    if (player.mo and player.mo.valid and player.creating)
      if (player.choiceindex > 1 and player.cmd.buttons & BT_SPIN and not(player.prevcreationcmd & BT_SPIN))
        player.choiceindex = $ - 1
      elseif (player.choiceindex < #ITEM_LIST and player.cmd.buttons & BT_JUMP and not(player.prevcreationcmd & BT_JUMP))
        player.choiceindex = $ + 1
      end

      if (player.choiceitem)
        P_RemoveMobj(player.choiceitem)
      end

      player.choiceitem = P_SpawnMobj(player.mo.x + 64*FRACUNIT, player.mo.y + 64*FRACUNIT, player.mo.z, ITEM_LIST[player.choiceindex])

      player.prevcreationcmd = player.cmd.buttons
      player.cmd.buttons = $ & ~BT_SPIN & ~BT_JUMP
    end
	end
end)

addHook("ThinkFrame", function()
  for player in players.iterate
    if (player.mo and player.mo.valid)

      handleCreationPower(player)

      player.prevcmd = player.cmd.buttons
    end
	end
end)


