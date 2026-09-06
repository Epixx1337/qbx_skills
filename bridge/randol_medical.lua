if GetResourceState('randol_medical') ~= 'started' then return end

---@param fullHeal boolean?
local function reapply(fullHeal)
    SetTimeout(250, function()
        ReapplyStats(fullHeal)
    end)
end

AddEventHandler('randol_medical:onRevive', function() reapply(true) end)
AddEventHandler('randol_medical:onCheckIn', function() reapply(true) end)
RegisterNetEvent('randol_medical:client:onRespawn', function() reapply(true) end)
AddEventHandler('randol_medical:onBedExit', function() reapply() end)

-- randol_medical restores persisted health and armour a couple of seconds after the character loads
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(3000, ReapplyStats)
end)
