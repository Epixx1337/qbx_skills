local sharedConfig = require 'config.shared'

Trees = {}
NodesByName = {}
local players = {}

---oxmysql returns TINYINT(1) columns as booleans
---@param value any
---@return boolean
local function toBool(value)
    return value == true or value == 1
end

---@param level integer
---@return integer
function XpForNext(level)
    return math.floor(sharedConfig.xp.base * sharedConfig.xp.growth ^ level)
end

function LoadTrees()
    local trees, byName, byId = {}, {}, {}

    local treeRows = MySQL.query.await('SELECT * FROM skills_trees ORDER BY sort, name') or {}
    for i = 1, #treeRows do
        local row = treeRows[i]
        local ok, jobs = pcall(json.decode, row.jobs or 'null')
        if not ok or type(jobs) ~= 'table' or not next(jobs) then jobs = nil end
        trees[row.name] = {
            name = row.name,
            label = row.label,
            category = row.category,
            description = row.description,
            color = row.color,
            sort = row.sort,
            enabled = toBool(row.enabled),
            jobs = jobs,
            nodes = {},
            links = {},
        }
    end

    local nodeRows = MySQL.query.await('SELECT * FROM skills_nodes') or {}
    for i = 1, #nodeRows do
        local row = nodeRows[i]
        local tree = trees[row.tree]
        if tree then
            local ok, bonuses = pcall(json.decode, row.bonuses or '{}')
            local node = {
                id = row.id,
                tree = row.tree,
                name = row.name,
                label = row.label,
                description = row.description,
                icon = row.icon,
                x = row.x,
                y = row.y,
                cost = row.cost,
                bonuses = ok and bonuses or {},
                parents = {},
            }
            tree.nodes[#tree.nodes + 1] = node
            byName[node.name] = node
            byId[node.id] = node
        end
    end

    local linkRows = MySQL.query.await('SELECT parent, child FROM skills_links') or {}
    for i = 1, #linkRows do
        local parent, child = byId[linkRows[i].parent], byId[linkRows[i].child]
        if parent and child and parent.tree == child.tree then
            local tree = trees[parent.tree]
            tree.links[#tree.links + 1] = { parent = parent.id, child = child.id }
            child.parents[#child.parents + 1] = parent.name
        end
    end

    Trees = trees
    NodesByName = byName
end

---@param data table
---@param tree string
---@return boolean
function IsTreeActiveFor(data, tree)
    local def = Trees[tree]
    return def ~= nil and data.actives[def.category] == tree
end

---Resolve which tree an unqualified call targets: the category's active tree,
---or the only active tree when exactly one is active.
---@param data table
---@param category string?
---@return string?
function ResolveActiveTree(data, category)
    if category then return data.actives[category] end

    local only
    for _, active in pairs(data.actives) do
        if only then return nil end
        only = active
    end
    return only
end

---@param data table
---@param tree string
---@return table
local function treeProgress(data, tree)
    local progress = data.trees[tree]
    if not progress then
        progress = { xp = 0, level = 0, points = 0, unlocked = {} }
        data.trees[tree] = progress
    end
    return progress
end

---@param data table
---@param tree string
local function saveProgress(data, tree)
    local progress = data.trees[tree]
    local unlocked = {}
    for name in pairs(progress.unlocked) do unlocked[#unlocked + 1] = name end
    MySQL.query.await('INSERT INTO skills_players (citizenid, tree, xp, level, points, unlocked, active) VALUES (?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE xp = VALUES(xp), level = VALUES(level), points = VALUES(points), unlocked = VALUES(unlocked), active = VALUES(active)',
        {data.citizenid, tree, progress.xp, progress.level, progress.points, json.encode(unlocked), IsTreeActiveFor(data, tree) and 1 or 0})
end

---@param data table
---@return table<string, number>
local function computeBonuses(data)
    local bonuses = {}
    for tree, progress in pairs(data.trees) do
        if sharedConfig.inactivePerksApply or IsTreeActiveFor(data, tree) then
            for name in pairs(progress.unlocked) do
                local node = NodesByName[name]
                if node and node.tree == tree then
                    for bonus, value in pairs(node.bonuses) do
                        bonuses[bonus] = (bonuses[bonus] or 0) + value
                    end
                end
            end
        end
    end
    return bonuses
end

---@param source number
function SyncPlayer(source)
    local data = players[source]
    if not data then return end

    local trees = {}
    for tree, progress in pairs(data.trees) do
        local unlocked = {}
        for name in pairs(progress.unlocked) do unlocked[#unlocked + 1] = name end
        trees[tree] = { xp = progress.xp, level = progress.level, points = progress.points, unlocked = unlocked }
    end

    TriggerClientEvent('qbx_skills:client:sync', source, {
        actives = data.actives,
        trees = trees,
        bonuses = computeBonuses(data),
    })
end

---@param source number
---@return table?
function GetPlayerSkills(source)
    return players[source]
end

---@param source number
---@param tree string
---@return boolean
function TreeAllowed(source, tree)
    local def = Trees[tree]
    if not def then return false end
    if not def.jobs then return true end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    local minGrade = def.jobs[player.PlayerData.job.name]
    return minGrade ~= nil and player.PlayerData.job.grade.level >= minGrade
end

---@param source number
local function loadPlayer(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    local rows = MySQL.query.await('SELECT * FROM skills_players WHERE citizenid = ?', {player.PlayerData.citizenid}) or {}
    local data = { citizenid = player.PlayerData.citizenid, actives = {}, trees = {} }
    local demoted = {}
    for i = 1, #rows do
        local row = rows[i]
        local ok, list = pcall(json.decode, row.unlocked or '[]')
        local unlocked = {}
        if ok then
            for j = 1, #list do unlocked[list[j]] = true end
        end
        data.trees[row.tree] = { xp = row.xp, level = row.level, points = row.points, unlocked = unlocked }

        local def = toBool(row.active) and Trees[row.tree]
        if def then
            local taken
            if sharedConfig.activeTreePerCategory then
                taken = data.actives[def.category] ~= nil
            else
                taken = next(data.actives) ~= nil
            end
            if taken then
                demoted[#demoted + 1] = row.tree
            else
                data.actives[def.category] = row.tree
            end
        end
    end

    players[source] = data

    for category, tree in pairs(data.actives) do
        if not TreeAllowed(source, tree) then
            data.actives[category] = nil
            demoted[#demoted + 1] = tree
            lib.logger(source, 'qbx_skills:server:jobLock', ('%s lost access to %s, tree deactivated'):format(data.citizenid, tree))
        end
    end
    for i = 1, #demoted do
        saveProgress(data, demoted[i])
    end

    SyncPlayer(source)
end

---@param source number
---@param amount number
---@param tree string? defaults to the matching active tree
---@param category string? only apply when the target tree belongs to this category
---@return boolean applied
function AddSkillXp(source, amount, tree, category)
    local data = players[source]
    if not data or type(amount) ~= 'number' or amount <= 0 then return false end

    tree = tree or ResolveActiveTree(data, category)
    local def = tree and Trees[tree]
    if not def or not def.enabled then return false end
    if category and def.category ~= category then return false end
    if def.jobs and not TreeAllowed(source, tree) then return false end

    local progress = treeProgress(data, tree)
    if progress.level >= sharedConfig.xp.maxLevel then return false end

    local boost = computeBonuses(data).xp_bonus or 0
    progress.xp += math.floor(amount * math.max(0, 1 + boost))
    local levelled = false
    while progress.level < sharedConfig.xp.maxLevel and progress.xp >= XpForNext(progress.level) do
        progress.xp -= XpForNext(progress.level)
        progress.level += 1
        progress.points += sharedConfig.pointsPerLevel
        levelled = true
    end
    if progress.level >= sharedConfig.xp.maxLevel then progress.xp = 0 end

    saveProgress(data, tree)
    SyncPlayer(source)

    if levelled then
        lib.logger(source, 'qbx_skills:server:levelUp', ('%s reached level %d on %s'):format(data.citizenid, progress.level, tree))
        if sharedConfig.notifyOnLevelUp then
            exports.qbx_core:Notify(source, locale('notify.level_up', def.label, progress.level), 'success')
        end
    end
    return true
end

---@param source number
---@param tree string
---@param amount integer negative amounts remove levels, points from gained levels are granted
---@return boolean
function AddSkillLevels(source, tree, amount)
    local data = players[source]
    if not data or not Trees[tree] or type(amount) ~= 'number' or amount == 0 then return false end

    local progress = treeProgress(data, tree)
    local before = progress.level
    progress.level = math.max(0, math.min(sharedConfig.xp.maxLevel, progress.level + math.floor(amount)))
    if progress.level == before then return false end

    local gained = progress.level - before
    if gained > 0 then
        progress.points += gained * sharedConfig.pointsPerLevel
    end
    if progress.level >= sharedConfig.xp.maxLevel then progress.xp = 0 end

    saveProgress(data, tree)
    SyncPlayer(source)
    return true
end

---@param source number
---@param tree string
---@param amount integer negative amounts remove points
---@return boolean
function AddSkillPoints(source, tree, amount)
    local data = players[source]
    if not data or not Trees[tree] or type(amount) ~= 'number' or amount == 0 then return false end

    local progress = treeProgress(data, tree)
    progress.points = math.max(0, progress.points + math.floor(amount))

    saveProgress(data, tree)
    SyncPlayer(source)
    return true
end

---@param source number
---@param nodeName string
---@return boolean
function UnlockSkill(source, nodeName)
    local data = players[source]
    local node = NodesByName[nodeName]
    if not data or not node or not IsTreeActiveFor(data, node.tree) then return false end

    local progress = treeProgress(data, node.tree)
    if progress.unlocked[nodeName] or progress.points < node.cost then return false end

    if #node.parents > 0 then
        local owned = 0
        for i = 1, #node.parents do
            if progress.unlocked[node.parents[i]] then owned += 1 end
        end
        if sharedConfig.linkRequirement == 'all' then
            if owned < #node.parents then return false end
        elseif owned == 0 then
            return false
        end
    end

    progress.points -= node.cost
    progress.unlocked[nodeName] = true
    saveProgress(data, node.tree)
    SyncPlayer(source)
    lib.logger(source, 'qbx_skills:server:unlock', ('%s unlocked %s on %s for %d point(s)'):format(data.citizenid, nodeName, node.tree, node.cost))
    return true
end

---@param source number
---@param tree string
---@return boolean
function SetActiveTree(source, tree)
    local data = players[source]
    local def = Trees[tree]
    if not data or not def or not def.enabled then return false end
    if def.jobs and not TreeAllowed(source, tree) then
        exports.qbx_core:Notify(source, locale('notify.tree_job_locked'), 'error')
        return false
    end
    if IsTreeActiveFor(data, tree) then return true end

    local previous
    if sharedConfig.activeTreePerCategory then
        previous = data.actives[def.category]
    else
        previous = ResolveActiveTree(data)
    end

    if previous then
        local current = treeProgress(data, previous)
        if sharedConfig.switchRequiresMaxLevel and current.level < sharedConfig.xp.maxLevel then
            exports.qbx_core:Notify(source, locale('notify.switch_requires_max'), 'error')
            return false
        end
        if sharedConfig.abandonResetsProgress then
            data.trees[previous] = { xp = 0, level = 0, points = 0, unlocked = {} }
            lib.logger(source, 'qbx_skills:server:abandonTree', ('%s abandoned %s at level %d, progress reset'):format(data.citizenid, previous, current.level))
        end
        data.actives[Trees[previous].category] = nil
        saveProgress(data, previous)
    end

    data.actives[def.category] = tree
    treeProgress(data, tree)
    saveProgress(data, tree)
    SyncPlayer(source)
    lib.logger(source, 'qbx_skills:server:selectTree', ('%s activated %s'):format(data.citizenid, tree))
    return true
end

---@param source number
---@return table
function BuildUIData(source)
    local data = players[source]
    local trees = {}
    local categories, seen = {}, {}

    for _, tree in pairs(Trees) do
        trees[#trees + 1] = tree
        if not seen[tree.category] then
            seen[tree.category] = true
            categories[#categories + 1] = tree.category
        end
    end
    table.sort(trees, function(a, b)
        if a.sort ~= b.sort then return a.sort < b.sort end
        return a.name < b.name
    end)
    table.sort(categories)

    local progress = {}
    if data then
        for tree, row in pairs(data.trees) do
            local unlocked = {}
            for name in pairs(row.unlocked) do unlocked[#unlocked + 1] = name end
            progress[tree] = { xp = row.xp, level = row.level, points = row.points, unlocked = unlocked }
        end
    end

    local qualifies = {}
    for i = 1, #trees do
        qualifies[trees[i].name] = not trees[i].jobs or TreeAllowed(source, trees[i].name)
    end

    return {
        qualifies = qualifies,
        trees = trees,
        categories = categories,
        player = { actives = data and data.actives or {}, trees = progress },
        xp = { base = sharedConfig.xp.base, growth = sharedConfig.xp.growth, maxLevel = sharedConfig.xp.maxLevel, pointsPerLevel = sharedConfig.pointsPerLevel },
        policy = { linkRequirement = sharedConfig.linkRequirement, abandonResets = sharedConfig.abandonResetsProgress, switchRequiresMax = sharedConfig.switchRequiresMaxLevel, perCategory = sharedConfig.activeTreePerCategory },
        isAdmin = exports.qbx_core:HasPermission(source, 'admin'),
    }
end

function RefreshTrees()
    LoadTrees()
    for source in pairs(players) do
        loadPlayer(source)
    end
    TriggerClientEvent('qbx_skills:client:treesChanged', -1)
end

lib.callback.register('qbx_skills:callback:getData', function(source)
    return BuildUIData(source)
end)

lib.callback.register('qbx_skills:callback:unlock', function(source, nodeName)
    if type(nodeName) ~= 'string' then return false end
    return UnlockSkill(source, nodeName)
end)

lib.callback.register('qbx_skills:callback:selectTree', function(source, tree)
    if type(tree) ~= 'string' then return false end
    return SetActiveTree(source, tree)
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local source = source --[[@as number]]
    loadPlayer(source)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    players[source] = nil
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(source, _)
    local data = players[source]
    if not data then return end

    local changed = false
    for category, tree in pairs(data.actives) do
        local def = Trees[tree]
        if def and def.jobs and not TreeAllowed(source, tree) then
            data.actives[category] = nil
            saveProgress(data, tree)
            changed = true
            exports.qbx_core:Notify(source, locale('notify.tree_job_lost', def.label), 'error')
            lib.logger(source, 'qbx_skills:server:jobLock', ('%s lost access to %s, tree deactivated'):format(data.citizenid, tree))
        end
    end
    if changed then SyncPlayer(source) end
end)

AddEventHandler('playerDropped', function()
    players[source] = nil
end)

CreateThread(function()
    AwaitMigration()
    LoadTrees()
    local online = GetPlayers()
    for i = 1, #online do
        local source = tonumber(online[i]) --[[@as number]]
        if exports.qbx_core:GetPlayer(source) then loadPlayer(source) end
    end
end)
