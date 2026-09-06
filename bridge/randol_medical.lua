if GetResourceState('randol_medical') ~= 'started' then return end

-- randol_medical writes health after its own fades and animations, so every hook keeps
-- reapplying for a few seconds instead of racing it once
local function fullHeal()
    ReapplyStats(true, 4000)
end

AddEventHandler('randol_medical:onRevive', fullHeal)
AddEventHandler('randol_medical:onCheckIn', fullHeal)
RegisterNetEvent('randol_medical:client:onRespawn', fullHeal)
RegisterNetEvent('randol_medical:client:revivePlayer', fullHeal)

AddEventHandler('randol_medical:onBedExit', function()
    ReapplyStats(false, 2000)
end)

-- randol_medical restores persisted health and armour a couple of seconds after the character loads
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    ReapplyStats(false, 8000)
end)
