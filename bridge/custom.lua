-- Template for a medical script qbx_skills has no bridge for. Replace the resource name with
-- yours, then call ReapplyStats() after every point where your script rewrites the ped's
-- health, max health or armour. The first argument asks for a full heal — pass true on revive,
-- respawn and hospital check-in so health fills up to the boosted maximum instead of stopping
-- at the script's own 200, leave it false for a persisted health restore on load. The second
-- is a settle window in ms: the stats are reapplied every 500 ms for that long, which beats
-- scripts that write health after their own fades and animations.
if GetResourceState('your_medical') ~= 'started' then return end

RegisterNetEvent('your_medical:client:revived', function()
    ReapplyStats(true, 3000)
end)
