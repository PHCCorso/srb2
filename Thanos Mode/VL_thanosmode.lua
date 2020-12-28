/* 
  Author: PHCC
  Date: 28/12/2020

  Rules:
    - You should kill half of the enemies of the stage in order to proceeed
    - Once every chaos emerald is collected, you will be able to "snap your fingers" by pressing BT_CUSTOM1, but at a cost:
      - 200 rings or
      - For each missing 100 rings, you give a life in exchange (and you lose your rings, of course) 
*/

local canexit = false
local enemytable = {}
local enemyindex = 1
local enemiesonload = 0
local enemieskilled = 0 // This and the next one are used to handle levels with an increasing amount of enemies (e.g. Aerial Garden Zone)
local newenemieskilled = 0

local function isEnemy(mo)
  if ((mo.flags & MF_ENEMY and not(mo.flags & MF_SOLID)) or mo.flags & MF_BOSS) // A power so great that it can kill bosses... at a high cost
    return true
  end
  return false
end

local function setExitSectorEnabled(enabled) // Hacky stuff to disable the exit sector
  for sec in sectors.iterate do
    if (GetSecSpecial(sec.special,4) == 2 or GetSecSpecial(sec.special,4) == 10)
      if (enabled)
        sec.special = 2<<12
      else
        sec.special = 10<<12 // I hope no co-op levels use this
      end
    end
  end

  canexit = enabled // Used to avoid message spamming
end

local function enemiesLeft() // Dont question my math!
  local extraenemies = #enemytable - enemiesonload - newenemieskilled

  local left = (enemiesonload + extraenemies)/2 - enemieskilled

  if (left < 0)
    return 0
  end

  return left
end

local function snapFingers(player) // BEHOLD THE POWER OF THE CHAOS EMERALDS!!!
  if (not(All7Emeralds(emeralds)) and not(player.fingerssnapped)) return end

  if (player.rings < 200) // You either feed the power of chaos with enough rings or you pay for it with YOUR LIFE!
    local livestoremove = 2 - player.rings/100

    if (player.lives - livestoremove < 1) return end

    player.rings = 0
    player.lives = $ - livestoremove // How much did it cost?
  else
    player.rings = $ - 200 
  end

  P_BlackOw(player) // Why not give it some extra blast?

  while enemiesLeft()
    for _,enemy in ipairs(enemytable)
      if (enemy and P_RandomChance(FRACUNIT/2))
        P_KillMobj(enemy, player.mo)
      end

      if (not(enemiesLeft()))
        break
      end
    end
  end 

  player.fingerssnapped = true // only once per player
end

addHook("MobjSpawn", function(mo)
  if (not(gametype == GT_COOP) or G_IsSpecialStage()) return end

  if (isEnemy(mo))
    enemytable[enemyindex] = mo
    mo.enemyindex = enemyindex

    if (leveltime > 0)
      mo.newenemy = true
    end

    enemyindex = $ + 1
  end
end)

addHook("MobjDeath", function(target)
  if (not(gametype == GT_COOP) or G_IsSpecialStage()) return end
  if (not(isEnemy(target))) return end

  enemytable[target.enemyindex] = false

  if (target.newenemy)
    newenemieskilled = $ + 1
  else
    enemieskilled = $ + 1
  end
    
  if (enemiesLeft() == 0 and not(canexit))
    setExitSectorEnabled(true)
    print("You helped to bring balance to the universe and may now finish the level")
  elseif (enemiesLeft() > 0 and canexit) // Some new enemies popped up
    print("There are more enemies around, kill them first!")
    setExitSectorEnabled(false)
  end
end)

addHook("MapChange", function(gamemap) // Resetting
  canexit = false
  enemytable = {}
  enemyindex = 1
  enemiesonload = 0
  enemieskilled = 0
  newenemieskilled = 0
end)

addHook("MapLoad", function()
  enemiesonload = #enemytable

  if (enemiesonload % 2 == 1) 
    enemieskilled = -1 // because yes
  end

  for player in players.iterate
    player.fingerssnapped = false
  end

  setExitSectorEnabled(false)
end)

addHook("ThinkFrame", function()
  for player in players.iterate
    if (not(player.prevstate))
      player.prevstate = {}
    end

    if (player.cmd.buttons & BT_CUSTOM1 and not(player.prevstate.buttons & BT_CUSTOM1))
      snapFingers(player)
    end

    player.prevstate.buttons = player.cmd.buttons
  end
end)

local function drawcounter(drawfunc, p, c)
  if (not(gametype == GT_COOP) or G_IsSpecialStage()) return end

  drawfunc.drawString(258, 190, enemiesLeft(), V_SNAPTOBOTTOM|V_SNAPTORIGHT)
  drawfunc.drawString(288, 190, "left", V_SNAPTOBOTTOM|V_SNAPTORIGHT)
end

hud.add(drawcounter)