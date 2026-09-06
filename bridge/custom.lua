-- Template for a medical script qbx_skills has no bridge for. Replace the resource name with
-- yours, then call ReapplyStats() after every point where your script rewrites the ped's
-- health, max health or armour: revive, respawn, hospital check-in, a persisted health restore
-- on load. A short delay lets the medical script finish first.
if GetResourceState('your_medical') ~= 'started' then return end

RegisterNetEvent('your_medical:client:revived', function()
    SetTimeout(250, ReapplyStats)
end)
