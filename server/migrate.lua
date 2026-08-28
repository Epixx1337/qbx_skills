local migrated = false

function AwaitMigration()
    while not migrated do Wait(50) end
end

local columns = {
    skills_trees = {
        jobs = 'LONGTEXT DEFAULT NULL',
    },
}

MySQL.ready(function()
    local sql = LoadResourceFile(cache.resource, 'skills.sql')
    if sql then
        for statement in sql:gmatch('[^;]+') do
            if statement:match('%S') then
                pcall(MySQL.query.await, statement)
            end
        end
    end

    for tableName, defs in pairs(columns) do
        local rows = MySQL.query.await('SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', {tableName})
        if rows and #rows > 0 then
            local have = {}
            for i = 1, #rows do have[rows[i].COLUMN_NAME] = true end

            for column, definition in pairs(defs) do
                if not have[column] then
                    local ok = pcall(MySQL.query.await, ('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tableName, column, definition))
                    if not ok then
                        lib.print.error(('could not add column %s.%s, run skills.sql by hand'):format(tableName, column))
                    end
                end
            end
        end
    end

    local requiredTables = { 'skills_trees', 'skills_nodes', 'skills_links', 'skills_players' }
    local missing = {}
    for i = 1, #requiredTables do
        local exists = MySQL.scalar.await('SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', {requiredTables[i]})
        if not exists then missing[#missing + 1] = requiredTables[i] end
    end

    if #missing > 0 then
        lib.print.error(('missing tables: %s — check that the database user may CREATE, or run skills.sql by hand'):format(table.concat(missing, ', ')))
    end

    migrated = true
end)
