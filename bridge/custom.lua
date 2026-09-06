-- Template for a medical script qbx_skills has no bridge for. Replace the resource name with
-- yours, then call ReapplyStats() after every point where your script rewrites the ped's
-- health, max health or armour. Pass true when the moment is a full heal (revive, respawn,
-- hospital check-in) so health fills up to the boosted maximum instead of stopping at the
-- script's own 200; leave it out for things like a persisted health restore on load. A short
-- delay lets the medical script finish first.
if GetResourceState('your_medical') ~= 'started' then return end

RegisterNetEvent('your_medical:client:revived', function()
    SetTimeout(250, function()
        ReapplyStats(true)
    end)
end)
