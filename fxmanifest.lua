fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'dbca.'
description 'A complete CarPlay-inspired music system for FiveM with xsound integration'
version '1.0.0'

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js'
}

dependencies {
    'xsound'
}
