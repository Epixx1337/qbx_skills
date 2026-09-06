if GetResourceState('randol_medical') ~= 'started' then return end

local function reapply()
    SetTimeout(250, ReapplyStats)
end

AddEventHandler('randol_medical:onRevive', reapply)
AddEventHandler('randol_medical:onCheckIn', reapply)
AddEventHandler('randol_medical:onBedExit', reapply)
RegisterNetEvent('randol_medical:client:onRespawn', reapply)

-- randol_medical restores persisted health and armour a couple of seconds after the character loads
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(3000, ReapplyStats)
end)
