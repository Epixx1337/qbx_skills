if GetResourceState('qbx_medical') ~= 'started' then return end

-- qbx_medical resets max health to 200 on revive
RegisterNetEvent('qbx_medical:client:playerRevived', function()
    SetTimeout(250, function()
        ReapplyStats(true)
    end)
end)
