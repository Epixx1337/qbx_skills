local sharedConfig = require 'config.shared'

local synced = { actives = {}, trees = {}, bonuses = {} }
local radialAdded = false

---@param tree string
---@return boolean
local function treeIsActive(tree)
    for _, active in pairs(synced.actives) do
        if active == tree then return true end
    end
    return false
end

local function pushData()
    local data = lib.callback.await('qbx_skills:callback:getData', false)
    if not data then
        if IsUIOpen() then CloseUI() end
        return
    end
    SendUI('skills:init', data)
end

function OpenSkills()
    OpenUI()
    pushData()
end

local function addRadial()
    radialAdded = true
    lib.addRadialItem({
        id = sharedConfig.radial.id,
        label = locale('radial.skills'),
        icon = sharedConfig.radial.icon,
        onSelect = OpenSkills,
    })
end

local function removeRadial()
    if not radialAdded then return end
    radialAdded = false
    lib.removeRadialItem(sharedConfig.radial.id)
end

local function applyStats(fullHeal)
    local stats = sharedConfig.stats
    if not stats.enabled or not LocalPlayer.state.isLoggedIn then return end

    local maxHealth = stats.baseHealth + math.min(math.max(synced.bonuses.max_health or 0, 0), stats.healthCap)
    local maxArmour = stats.baseArmour + math.min(math.max(synced.bonuses.max_armour or 0, 0), stats.armourCap)
    local stamina = math.min(100, stats.baseStamina + math.min(math.max(synced.bonuses.stamina or 0, 0), stats.staminaCap))

    SetEntityMaxHealth(cache.ped, maxHealth)
    SetPedMaxHealth(cache.ped, maxHealth)
    if fullHeal or GetEntityHealth(cache.ped) > maxHealth then SetEntityHealth(cache.ped, maxHealth) end
    SetPlayerMaxArmour(cache.playerId, maxArmour)
    if GetPedArmour(cache.ped) > maxArmour then SetPedArmour(cache.ped, maxArmour) end
    StatSetInt(`MP0_STAMINA`, stamina, true)

    LocalPlayer.state:set('qbx_skills_stats', { maxHealth = maxHealth, maxArmour = maxArmour, stamina = stamina }, true)
end

RegisterNetEvent('qbx_skills:client:sync', function(data)
    synced = data

    local trees = {}
    for tree, progress in pairs(data.trees) do
        local unlocked = {}
        for i = 1, #progress.unlocked do unlocked[progress.unlocked[i]] = true end
        trees[tree] = { xp = progress.xp, level = progress.level, points = progress.points, unlocked = unlocked }
    end
    synced.trees = trees

    applyStats()
    if IsUIOpen() then pushData() end
end)

AddEventHandler('playerSpawned', function()
    applyStats()
end)

---Medical bridges call this after their script touched the ped's health or armour
---@param fullHeal boolean? also fill health up to the new maximum, for revives and heals
---@param settleMs number? keep reapplying for this long so the medical script's own delayed writes cannot undo it
function ReapplyStats(fullHeal, settleMs)
    applyStats(fullHeal == true)
    if not settleMs then return end

    local deadline = GetGameTimer() + settleMs
    CreateThread(function()
        while GetGameTimer() < deadline do
            Wait(500)
            applyStats(fullHeal == true)
        end
    end)
end

RegisterNetEvent('qbx_skills:client:treesChanged', function()
    if IsUIOpen() then pushData() end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    addRadial()
    applyStats()
end)

-- qbx_radialmenu wipes every radial item on death/revive and on its own restart; re-add ours after it rebuilds
RegisterNetEvent('radialmenu:client:deadradial', function(isDead)
    if isDead or not radialAdded then return end
    SetTimeout(100, addRadial)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= 'qbx_radialmenu' or not radialAdded then return end
    SetTimeout(100, addRadial)
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    removeRadial()
    if IsUIOpen() then CloseUI() end
    synced = { actives = {}, trees = {}, bonuses = {} }
    LocalPlayer.state:set('qbx_skills_stats', nil, true)
end)

RegisterNUICallback('unlock', function(data, cb)
    cb(1)
    if type(data) ~= 'table' or type(data.name) ~= 'string' then return end
    if not lib.callback.await('qbx_skills:callback:unlock', false, data.name) then
        lib.notify({ type = 'error', description = locale('notify.unlock_failed') })
    end
end)

RegisterNUICallback('selectTree', function(data, cb)
    cb(1)
    if type(data) ~= 'table' or type(data.tree) ~= 'string' then return end
    lib.callback.await('qbx_skills:callback:selectTree', false, data.tree)
end)

RegisterNUICallback('admin:getPlayers', function(_, cb)
    cb(lib.callback.await('qbx_skills:callback:admin:getPlayers', false) or {})
end)

RegisterNUICallback('admin:getPlayer', function(data, cb)
    cb(lib.callback.await('qbx_skills:callback:admin:getPlayer', false, type(data) == 'table' and data.id or nil) or false)
end)

RegisterNUICallback('admin:give', function(data, cb)
    local ok = lib.callback.await('qbx_skills:callback:admin:give', false, data)
    cb(ok and 1 or 0)
    if not ok then
        lib.notify({ type = 'error', description = locale('notify.editor_failed') })
    end
end)

local editorCallbacks = { 'saveTree', 'deleteTree', 'saveNode', 'deleteNode', 'moveNode', 'toggleLink' }
for i = 1, #editorCallbacks do
    local name = editorCallbacks[i]
    RegisterNUICallback('editor:' .. name, function(data, cb)
        local result = lib.callback.await('qbx_skills:callback:editor:' .. name, false, data)
        cb(result or 0)
        if not result then
            lib.notify({ type = 'error', description = locale('notify.editor_failed') })
        end
    end)
end

---@param skillName string
---@return boolean
exports('HasSkill', function(skillName)
    for tree, progress in pairs(synced.trees) do
        if (sharedConfig.inactivePerksApply or treeIsActive(tree)) and progress.unlocked[skillName] then
            return true
        end
    end
    return false
end)

---@param bonus string
---@return number
exports('GetSkillBonus', function(bonus)
    return synced.bonuses[bonus] or 0
end)

---@param category string?
---@return string?
local function resolveActive(category)
    if category then return synced.actives[category] end

    local only
    for _, active in pairs(synced.actives) do
        if only then return nil end
        only = active
    end
    return only
end

---@param tree string? defaults to the active tree (the only one, or none when several are active)
---@return integer level
exports('GetLevel', function(tree)
    local progress = synced.trees[tree or resolveActive() or '']
    return progress and progress.level or 0
end)

---@param category string? with activeTreePerCategory, the category to look up
---@return string?
exports('GetActiveTree', function(category)
    return resolveActive(category)
end)

---@return table<string, string> category mapped to the active tree name
exports('GetActiveTrees', function()
    local actives = {}
    for category, tree in pairs(synced.actives) do actives[category] = tree end
    return actives
end)

---The stat values currently applied to the ped, also published on the
---qbx_skills_stats player statebag for huds
---@return { maxHealth: number, maxArmour: number, stamina: number }?
exports('GetStats', function()
    return LocalPlayer.state.qbx_skills_stats
end)

exports('OpenSkills', OpenSkills)

---Reapply the stat perks from another resource, e.g. a medical script's own open handlers
---@param fullHeal boolean?
---@param settleMs number?
exports('ReapplyStats', function(fullHeal, settleMs)
    ReapplyStats(fullHeal, settleMs)
end)

CreateThread(function()
    if LocalPlayer.state.isLoggedIn then addRadial() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    removeRadial()
end)
