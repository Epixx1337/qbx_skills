local function isAdmin(source)
    return exports.qbx_core:HasPermission(source, 'admin')
end

---@param source number
---@return string
local function cid(source)
    local player = exports.qbx_core:GetPlayer(source)
    return player and player.PlayerData.citizenid or tostring(source)
end

---@param value any
---@return string?
local function slug(value)
    if type(value) ~= 'string' then return end
    value = value:lower():gsub('%s+', '_')
    if not value:match('^[a-z0-9_]+$') or #value > 50 then return end
    return value
end

---@param bonuses any
---@return string
local function encodeBonuses(bonuses)
    local clean = {}
    if type(bonuses) == 'table' then
        for key, value in pairs(bonuses) do
            local name = slug(key)
            if name and type(value) == 'number' then clean[name] = value end
        end
    end
    return json.encode(clean)
end

---@param parentId integer
---@param childId integer
---@return boolean
local function wouldCycle(parentId, childId)
    local links = MySQL.query.await('SELECT parent, child FROM skills_links') or {}
    local parentsOf = {}
    for i = 1, #links do
        local link = links[i]
        parentsOf[link.child] = parentsOf[link.child] or {}
        parentsOf[link.child][#parentsOf[link.child] + 1] = link.parent
    end

    local queue, visited = { parentId }, {}
    while #queue > 0 do
        local current = table.remove(queue)
        if current == childId then return true end
        if not visited[current] then
            visited[current] = true
            local parents = parentsOf[current] or {}
            for i = 1, #parents do queue[#queue + 1] = parents[i] end
        end
    end
    return false
end

lib.callback.register('qbx_skills:callback:editor:saveTree', function(source, data)
    if not isAdmin(source) or type(data) ~= 'table' then return false end

    local name = slug(data.name)
    if not name or type(data.label) ~= 'string' or #data.label == 0 then return false end
    local category = slug(data.category) or 'civilian'
    local description = type(data.description) == 'string' and data.description or nil
    local color = type(data.color) == 'string' and data.color:match('^#%x%x%x%x%x%x$') and data.color or nil
    local sort = type(data.sort) == 'number' and math.floor(data.sort) or 0
    local enabled = data.enabled ~= false and 1 or 0

    local jobs = nil
    if type(data.jobs) == 'table' then
        local clean = {}
        for job, grade in pairs(data.jobs) do
            local jobName = slug(job)
            if jobName and type(grade) == 'number' and grade >= 0 then clean[jobName] = math.floor(grade) end
        end
        if next(clean) then jobs = json.encode(clean) end
    end

    local original = slug(data.originalName)
    if original and original ~= name then
        if Trees[name] then return false end
        MySQL.query.await('UPDATE skills_trees SET name = ? WHERE name = ?', {name, original})
        MySQL.query.await('UPDATE skills_nodes SET tree = ? WHERE tree = ?', {name, original})
        MySQL.query.await('UPDATE skills_players SET tree = ? WHERE tree = ?', {name, original})
    end

    MySQL.query.await('INSERT INTO skills_trees (name, label, category, description, color, sort, enabled, jobs) VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE label = VALUES(label), category = VALUES(category), description = VALUES(description), color = VALUES(color), sort = VALUES(sort), enabled = VALUES(enabled), jobs = VALUES(jobs)',
        {name, data.label, category, description, color, sort, enabled, jobs})

    lib.logger(source, 'qbx_skills:server:saveTree', ('%s %s tree %s (%s)'):format(cid(source), original and 'updated' or 'created', name, category))
    RefreshTrees()
    return true
end)

lib.callback.register('qbx_skills:callback:editor:deleteTree', function(source, name)
    if not isAdmin(source) then return false end
    name = slug(name)
    if not name or not Trees[name] then return false end

    MySQL.query.await('DELETE l FROM skills_links l JOIN skills_nodes n ON n.id = l.parent OR n.id = l.child WHERE n.tree = ?', {name})
    MySQL.query.await('DELETE FROM skills_nodes WHERE tree = ?', {name})
    MySQL.query.await('DELETE FROM skills_players WHERE tree = ?', {name})
    MySQL.query.await('DELETE FROM skills_trees WHERE name = ?', {name})

    lib.logger(source, 'qbx_skills:server:deleteTree', ('%s deleted tree %s including all player progress'):format(cid(source), name))
    RefreshTrees()
    return true
end)

lib.callback.register('qbx_skills:callback:editor:saveNode', function(source, data)
    if not isAdmin(source) or type(data) ~= 'table' then return false end

    local name = slug(data.name)
    if not name or type(data.label) ~= 'string' or #data.label == 0 then return false end
    if type(data.tree) ~= 'string' or not Trees[data.tree] then return false end

    local existing = NodesByName[name]
    local id = type(data.id) == 'number' and math.floor(data.id) or nil
    if existing and existing.id ~= id then return false end

    local description = type(data.description) == 'string' and data.description or nil
    local icon = type(data.icon) == 'string' and #data.icon > 0 and data.icon:sub(1, 50) or 'star'
    local x = type(data.x) == 'number' and math.floor(data.x) or 0
    local y = type(data.y) == 'number' and math.floor(data.y) or 0
    local cost = type(data.cost) == 'number' and math.max(1, math.floor(data.cost)) or 1
    local bonuses = encodeBonuses(data.bonuses)

    if id then
        local row = MySQL.single.await('SELECT name FROM skills_nodes WHERE id = ?', {id})
        if not row then return false end
        if row.name ~= name then
            MySQL.query.await('UPDATE skills_players SET unlocked = REPLACE(unlocked, ?, ?)', {('"%s"'):format(row.name), ('"%s"'):format(name)})
        end
        MySQL.query.await('UPDATE skills_nodes SET name = ?, label = ?, description = ?, icon = ?, x = ?, y = ?, cost = ?, bonuses = ? WHERE id = ?',
            {name, data.label, description, icon, x, y, cost, bonuses, id})
    else
        id = MySQL.insert.await('INSERT INTO skills_nodes (tree, name, label, description, icon, x, y, cost, bonuses) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            {data.tree, name, data.label, description, icon, x, y, cost, bonuses})
        if not id then return false end
    end

    lib.logger(source, 'qbx_skills:server:saveNode', ('%s %s skill %s on %s (cost %d, bonuses %s)'):format(cid(source), data.id and 'updated' or 'created', name, data.tree, cost, bonuses))
    RefreshTrees()
    return { id = id }
end)

lib.callback.register('qbx_skills:callback:editor:deleteNode', function(source, id)
    if not isAdmin(source) or type(id) ~= 'number' then return false end

    local row = MySQL.single.await('SELECT name, tree FROM skills_nodes WHERE id = ?', {id})
    if not row then return false end

    MySQL.query.await('DELETE FROM skills_links WHERE parent = ? OR child = ?', {id, id})
    MySQL.query.await('DELETE FROM skills_nodes WHERE id = ?', {id})

    lib.logger(source, 'qbx_skills:server:deleteNode', ('%s deleted skill %s from %s'):format(cid(source), row.name, row.tree))
    RefreshTrees()
    return true
end)

lib.callback.register('qbx_skills:callback:editor:moveNode', function(source, data)
    if not isAdmin(source) or type(data) ~= 'table' then return false end
    if type(data.id) ~= 'number' or type(data.x) ~= 'number' or type(data.y) ~= 'number' then return false end

    MySQL.query.await('UPDATE skills_nodes SET x = ?, y = ? WHERE id = ?', {math.floor(data.x), math.floor(data.y), data.id})

    lib.logger(source, 'qbx_skills:server:moveNode', ('%s moved skill %d to %d,%d'):format(cid(source), data.id, math.floor(data.x), math.floor(data.y)))
    RefreshTrees()
    return true
end)

lib.callback.register('qbx_skills:callback:editor:toggleLink', function(source, data)
    if not isAdmin(source) or type(data) ~= 'table' then return false end
    if type(data.parent) ~= 'number' or type(data.child) ~= 'number' or data.parent == data.child then return false end

    local parent = MySQL.single.await('SELECT id, tree FROM skills_nodes WHERE id = ?', {data.parent})
    local child = MySQL.single.await('SELECT id, tree FROM skills_nodes WHERE id = ?', {data.child})
    if not parent or not child or parent.tree ~= child.tree then return false end

    local exists = MySQL.scalar.await('SELECT 1 FROM skills_links WHERE parent = ? AND child = ?', {data.parent, data.child})
    if exists then
        MySQL.query.await('DELETE FROM skills_links WHERE parent = ? AND child = ?', {data.parent, data.child})
    else
        if wouldCycle(data.parent, data.child) then return false end
        MySQL.query.await('INSERT INTO skills_links (parent, child) VALUES (?, ?)', {data.parent, data.child})
    end

    lib.logger(source, 'qbx_skills:server:toggleLink', ('%s %s link %d -> %d on %s'):format(cid(source), exists and 'removed' or 'added', data.parent, data.child, parent.tree))
    RefreshTrees()
    return true
end)
