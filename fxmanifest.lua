fx_version 'cerulean'
game 'gta5'

name 'qbx_skills'
description 'Skill tree progression with live in-game editing'
repository 'https://github.com/Epixx1337/qbx_skills'
version '0.0.1'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}

ui_page 'web/build/index.html'

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/nui.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/migrate.lua',
    'server/main.lua',
    'server/editor.lua',
    'server/admin.lua',
    'server/exports.lua',
}

files {
    'config/shared.lua',
    'locales/*.json',
    'web/build/index.html',
    'web/build/**/*',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}

lua54 'yes'
use_experimental_fxv2_oal 'true'
