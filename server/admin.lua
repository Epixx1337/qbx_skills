local sharedConfig = require 'config.shared'

local function isAdmin(source)
    return exports.qbx_core:HasPermission(source, 'admin')
end

---@param player table
---@return string
local function charName(player)
    local info = player.PlayerData.charinfo
    return ('%s %s'):format(info.firstname, info.lastname)
end

lib.callback.register('qbx_skills:callback:admin:getPlayers', function(source)
    if not isAdmin(source) then return end

    local list = {}
    for src, player in pairs(exports.qbx_core:GetQBPlayers()) do
        local data = GetPlayerSkills(src)
        local labels, level, points = {}, 0, 0
        if data then
            for _, tree in pairs(data.actives) do
                labels[#labels + 1] = Trees[tree] and Trees[tree].label or tree
                local progress = data.trees[tree]
                if progress then
                    level = math.max(level, progress.level)
                    points += progress.points
                end
            end
            table.sort(labels)
        end
        list[#list + 1] = {
            id = src,
            name = charName(player),
            citizenid = player.PlayerData.citizenid,
            active = labels[1] ~= nil,
            activeLabel = #labels > 0 and table.concat(labels, ', ') or nil,
            level = level,
            points = points,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end)

lib.callback.register('qbx_skills:callback:admin:getPlayer', function(source, target)
    if not isAdmin(source) or type(target) ~= 'number' then return end

    local player = exports.qbx_core:GetPlayer(target)
    local data = GetPlayerSkills(target)
    if not player or not data then return end

    local trees = {}
    for _, def in pairs(Trees) do
        local progress = data.trees[def.name]
        local skills = {}
        if progress then
            for name in pairs(progress.unlocked) do
                local node = NodesByName[name]
                skills[#skills + 1] = node and node.label or name
            end
            table.sort(skills)
        end
        trees[#trees + 1] = {
            name = def.name,
            label = def.label,
            category = def.category,
            sort = def.sort,
            xp = progress and progress.xp or 0,
            level = progress and progress.level or 0,
            points = progress and progress.points or 0,
            next = XpForNext(progress and progress.level or 0),
            skills = skills,
        }
    end
    table.sort(trees, function(a, b)
        if a.sort ~= b.sort then return a.sort < b.sort end
        return a.name < b.name
    end)

    return {
        id = target,
        name = charName(player),
        citizenid = player.PlayerData.citizenid,
        actives = data.actives,
        maxLevel = sharedConfig.xp.maxLevel,
        trees = trees,
    }
end)

lib.callback.register('qbx_skills:callback:admin:give', function(source, data)
    if not isAdmin(source) or type(data) ~= 'table' then return false end

    local target = type(data.id) == 'number' and math.floor(data.id) or nil
    local amount = type(data.amount) == 'number' and math.floor(data.amount) or nil
    local tree = type(data.tree) == 'string' and data.tree or nil
    if not target or not amount or amount == 0 or not tree or not Trees[tree] then return false end

    local player = exports.qbx_core:GetPlayer(target)
    if not player then return false end

    local ok
    if data.type == 'xp' then
        ok = AddSkillXp(target, amount, tree)
    elseif data.type == 'levels' then
        ok = AddSkillLevels(target, tree, amount)
    elseif data.type == 'points' then
        ok = AddSkillPoints(target, tree, amount)
    else
        return false
    end

    if ok then
        local admin = exports.qbx_core:GetPlayer(source)
        lib.logger(source, 'qbx_skills:server:adminGive', ('%s gave %d %s to %s on %s'):format(
            admin and admin.PlayerData.citizenid or source, amount, data.type, player.PlayerData.citizenid, tree))
    end
    return ok
end)
