if GetResourceState('qbx_medical') ~= 'started' then return end

-- qbx_medical resets max health to 200 on revive
RegisterNetEvent('qbx_medical:client:playerRevived', function()
    ReapplyStats(true, 3000)
end)
