Config = {}

-- Default Settings
Config.DefaultVolume = 50
Config.DefaultRange = 15
Config.MaxVolume = 100
Config.MaxRange = 50

-- Cooldown Settings
Config.CommandCooldown = 2000 -- 2 seconds
Config.PlayCooldown = 1000 -- 1 second

-- Queue Settings
Config.MaxQueueSize = 50
Config.AutoPlayNext = true
Config.SaveQueueOnDisconnect = true

-- UI Configuration
Config.UISize = {
    width = 800,
    height = 500
}

-- Language Strings
Config.Lang = {
    ['not_in_vehicle'] = 'You must be in a vehicle to use CarPlay',
    ['cooldown_active'] = 'Please wait before using this command again',
    ['invalid_url'] = 'Invalid YouTube URL provided',
    ['music_started'] = 'Music started playing',
    ['music_stopped'] = 'Music stopped',
    ['error_occurred'] = 'An error occurred while processing your request',
    ['youtube_not_supported'] = 'YouTube URLs require additional setup. Playing test audio instead.',
    ['direct_url_required'] = 'Please use direct audio stream URLs (mp3, wav, etc.)',
    ['queue_full'] = 'Queue is full! Maximum ' .. Config.MaxQueueSize .. ' songs allowed.',
    ['added_to_queue'] = 'Song added to queue',
    ['queue_cleared'] = 'Queue cleared',
    ['no_next_song'] = 'No next song in queue'
}

-- Color Schemes
Config.Colors = {
    primary = '#0a84ff',
    secondary = '#2c2c2e',
    background = '#1c1c1e',
    text = '#ffffff',
    accent = '#ff9500'
}

-- Key Mapping
Config.OpenKey = 'F7'
Config.OpenCommand = 'carplay'

-- Audio Settings
Config.Audio = {
    fadeTime = 1000,
    defaultTitle = 'YouTube Audio',
    defaultArtist = 'Streaming',
    simulateProgress = true
}
