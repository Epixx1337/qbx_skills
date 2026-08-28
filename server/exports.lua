local sharedConfig = require 'config.shared'

---Add experience to the player's active tree. When category is given the
---experience only applies if the active tree belongs to that category.
---@param source number
---@param amount number
---@param category string?
---@return boolean applied
exports('AddXp', function(source, amount, category)
    return AddSkillXp(source, amount, nil, category)
end)

---Add experience to a specific tree regardless of which one is active.
---@param source number
---@param tree string
---@param amount number
---@return boolean applied
exports('AddTreeXp', function(source, tree, amount)
    return AddSkillXp(source, amount, tree)
end)

---@param source number
---@param skillName string
---@return boolean
exports('HasSkill', function(source, skillName)
    local data = GetPlayerSkills(source)
    local node = NodesByName[skillName]
    if not data or not node then return false end
    if not sharedConfig.inactivePerksApply and not IsTreeActiveFor(data, node.tree) then return false end

    local progress = data.trees[node.tree]
    return progress and progress.unlocked[skillName] == true or false
end)

---Sum of a bonus key across every unlocked skill that currently applies.
---@param source number
---@param bonus string
---@return number
exports('GetSkillBonus', function(source, bonus)
    local data = GetPlayerSkills(source)
    if not data then return 0 end

    local total = 0
    for tree, progress in pairs(data.trees) do
        if sharedConfig.inactivePerksApply or IsTreeActiveFor(data, tree) then
            for name in pairs(progress.unlocked) do
                local node = NodesByName[name]
                local value = node and node.tree == tree and node.bonuses[bonus]
                if type(value) == 'number' then total += value end
            end
        end
    end
    return total
end)

---@param source number
---@param tree string? defaults to the active tree (the only one, or none when several are active)
---@return integer level, integer xp, integer xpForNext
exports('GetLevel', function(source, tree)
    local data = GetPlayerSkills(source)
    tree = tree or data and ResolveActiveTree(data)
    local progress = data and tree and data.trees[tree]
    if not progress then return 0, 0, XpForNext(0) end
    return progress.level, progress.xp, XpForNext(progress.level)
end)

---@param source number
---@param category string? with activeTreePerCategory, the category to look up
---@return string?
exports('GetActiveTree', function(source, category)
    local data = GetPlayerSkills(source)
    return data and ResolveActiveTree(data, category) or nil
end)

---@param source number
---@return table<string, string> category mapped to the active tree name
exports('GetActiveTrees', function(source)
    local data = GetPlayerSkills(source)
    local actives = {}
    if data then
        for category, tree in pairs(data.actives) do actives[category] = tree end
    end
    return actives
end)

---@param source number
---@param tree string
---@return boolean
exports('SetActiveTree', function(source, tree)
    if type(tree) ~= 'string' then return false end
    return SetActiveTree(source, tree)
end)
