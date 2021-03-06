-- Taken from bb template
if AbilityLevels == nil then
    DebugPrint ( 'creating new ability level requirement object.' )
    AbilityLevels = class({})
    Debug.EnabledModules["abilities:*"] = true
end

function AbilityLevels:Init ()
  FilterManager:AddFilter(FilterManager.ExecuteOrder, self, Dynamic_Wrap(self, "FilterAbilityUpgradeOrder"))
  GameEvents:OnPlayerLevelUp(partial(self.CheckAbilityLevels, self))
  GameEvents:OnPlayerLearnedAbility(partial(self.CheckAbilityLevels, self))
  CustomGameEventManager:RegisterListener("check_level_up_selection", function(_, keys)
    -- Change the player ID to an entity index
    keys.player = PlayerResource:GetPlayer(keys.PlayerID):entindex()
    self:CheckAbilityLevels(keys)
  end)
end

function AbilityLevels:CheckAbilityLevels (keys)
  local player = EntIndexToHScript(keys.player)
  local level = keys.level
  local hero
  if keys.selectedEntity then
    hero = EntIndexToHScript(keys.selectedEntity)
  else
    hero = player:GetAssignedHero()
  end
  if not level then
    level = hero:GetLevel()
  end
  local canLevelUp = {}

  for index = 0, hero:GetAbilityCount() - 1 do
    local ability = hero:GetAbilityByIndex(index)
    if ability and not ability:IsHidden() then
      local abilityName = ability:GetAbilityName()
      table.insert(canLevelUp, self:GetRequiredLevel(hero, abilityName))
    end
  end

  CustomGameEventManager:Send_ServerToPlayer(player, "check_level_up", {
    level = level,
    canLevelUp = canLevelUp
  })
end

function AbilityLevels:GetRequiredLevel (hero, abilityName)
  -- Ability hero level requirements
  local basicReqs = {0, 0, 0, 0, 28, 40}
  local ultimateReqs = {0, 0, 0, 37, 49}

  local invokerAbilityReqs = {0, 0, 0, 0, 0, 0, 0, 26, 28, 30, 32, 34, 36, 38}
  -- Ability hero level requirements for abilities that don't follow the default pattern
  local exceptionAbilityReqs = {invoker_quas = invokerAbilityReqs,
                                invoker_wex = invokerAbilityReqs,
                                invoker_exort = invokerAbilityReqs}

  local ability = hero:FindAbilityByName(abilityName)
  local abilityLevel = ability:GetLevel()
  local abilityType = ability:GetAbilityType()
  local reqTable = basicReqs

  if exceptionAbilityReqs[abilityName] then -- Ability doesn't follow default requirement pattern
    reqTable = exceptionAbilityReqs[abilityName]
  elseif abilityType == 1 then -- Ability is DOTA_ABILITY_TYPE_ULTIMATE
    reqTable = ultimateReqs
  end

  if abilityLevel >= #reqTable then
    return -1
  end

  return reqTable[abilityLevel+1]
end

function AbilityLevels:FilterAbilityUpgradeOrder (keys)
  -- Immediately return true if intercepted order isn't an ability upgrade order
  if keys.order_type ~= DOTA_UNIT_ORDER_TRAIN_ABILITY then
    return true
  end

  local ability = EntIndexToHScript(keys.entindex_ability)
  local abilityName = ability:GetAbilityName()
  local player = PlayerResource:GetPlayer(keys.issuer_player_id_const)
  local hero = EntIndexToHScript(keys.units["0"])
  local heroLevel = hero:GetLevel()

  local requirement = AbilityLevels:GetRequiredLevel(hero, abilityName)

  if heroLevel >= requirement then
    return true
  else
    -- Send event to client to display error message about hero level requirement
    CustomGameEventManager:Send_ServerToPlayer(player, "ability_level_error", {requiredLevel = requirement})
    -- Return false to reject ability upgrade order
    return false
  end
end
