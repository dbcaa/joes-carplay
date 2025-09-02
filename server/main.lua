local activeSounds = {}
local playerCooldowns = {}
local playerQueues = {} -- Store player queues

-- Function to extract video ID from YouTube URL
function ExtractVideoId(url)
    local videoId = nil

    -- Standard YouTube URL
    videoId = string.match(url, "youtube%.com/watch%?v=([%w%-_]+)")
    if videoId then return videoId end

    -- Short YouTube URL
    videoId = string.match(url, "youtu%.be/([%w%-_]+)")
    if videoId then return videoId end

    return nil
end

-- Function to clean extracted text
function CleanExtractedText(text)
    if not text then return nil end

    -- Decode HTML entities
    text = string.gsub(text, "&quot;", '"')
    text = string.gsub(text, "&amp;", "&")
    text = string.gsub(text, "&lt;", "<")
    text = string.gsub(text, "&gt;", ">")
    text = string.gsub(text, "&#39;", "'")
    text = string.gsub(text, "&nbsp;", " ")
    text = string.gsub(text, "\\u0026", "&")
    text = string.gsub(text, "\\\"", '"')
    text = string.gsub(text, "\\n", "")
    text = string.gsub(text, "\\r", "")

    -- Remove extra whitespace
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    text = string.gsub(text, "%s+", " ")

    return text
end

-- Function to get YouTube video info using oEmbed
function GetYouTubeVideoInfo(url, callback)
    local videoId = ExtractVideoId(url)
    if not videoId then
        callback(nil)
        return
    end

    local oembedUrl = "https://www.youtube.com/oembed?format=json&url=https://www.youtube.com/watch?v=" .. videoId

    PerformHttpRequest(oembedUrl, function(statusCode, response, headers)
        if statusCode == 200 and response then
            local success, data = pcall(json.decode, response)
            if not success or not data or not data.title then
                callback(nil)
                return
            end

            local videoInfo = {
                title = CleanExtractedText(data.title),
                artist = data.author_name or "Unknown Artist",
                duration = 180, -- fallback duration
                thumbnail = "https://img.youtube.com/vi/" .. videoId .. "/maxresdefault.jpg",
            }

            print(string.format("[CarPlay] Extracted via oEmbed - Title: '%s', Artist: '%s'", videoInfo.title, videoInfo.artist))
            callback(videoInfo)
        else
            print("[CarPlay] oEmbed request failed: " .. tostring(statusCode))
            callback(nil)
        end
    end, 'GET', '', {
        ['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    })
end

-- Function to check player cooldown
function IsPlayerOnCooldown(playerId)
    local currentTime = GetGameTimer()
    local lastTime = playerCooldowns[playerId] or 0

    return (currentTime - lastTime) < Config.PlayCooldown
end

-- Function to set player cooldown
function SetPlayerCooldown(playerId)
    playerCooldowns[playerId] = GetGameTimer()
end

-- Queue Management Functions
function InitializePlayerQueue(playerId)
    if not playerQueues[playerId] then
        playerQueues[playerId] = {
            songs = {},
            currentIndex = 0, -- Changed to 0-based indexing
            shuffle = false,
            repeat_mode = 'none', -- 'none', 'one', 'all'
            shuffleOrder = {}
        }
    end
end

function AddToQueue(playerId, songInfo)
    InitializePlayerQueue(playerId)
    
    if #playerQueues[playerId].songs >= Config.MaxQueueSize then
        return false, Config.Lang['queue_full']
    end
    
    table.insert(playerQueues[playerId].songs, songInfo)
    
    -- Update shuffle order if shuffle is enabled
    if playerQueues[playerId].shuffle then
        UpdateShuffleOrder(playerId)
    end
    
    return true, Config.Lang['added_to_queue']
end

function GetNextSong(playerId)
    InitializePlayerQueue(playerId)
    local queue = playerQueues[playerId]
    
    if #queue.songs == 0 then
        return nil
    end
    
    if queue.repeat_mode == 'one' and queue.currentIndex > 0 then
        -- Repeat current song
        return queue.songs[queue.currentIndex]
    end
    
    local nextIndex
    if queue.shuffle and #queue.shuffleOrder > 0 then
        -- Find current position in shuffle order
        local currentShufflePos = 1
        for i, idx in ipairs(queue.shuffleOrder) do
            if idx == queue.currentIndex then
                currentShufflePos = i
                break
            end
        end
        
        if currentShufflePos < #queue.shuffleOrder then
            nextIndex = queue.shuffleOrder[currentShufflePos + 1]
        elseif queue.repeat_mode == 'all' then
            nextIndex = queue.shuffleOrder[1]
        else
            return nil
        end
    else
        -- Normal order
        if queue.currentIndex > 0 and queue.currentIndex < #queue.songs then
            nextIndex = queue.currentIndex + 1
        elseif queue.repeat_mode == 'all' then
            nextIndex = 1
        else
            return nil
        end
    end
    
    queue.currentIndex = nextIndex
    return queue.songs[nextIndex]
end

function UpdateShuffleOrder(playerId)
    local queue = playerQueues[playerId]
    queue.shuffleOrder = {}
    
    for i = 1, #queue.songs do
        table.insert(queue.shuffleOrder, i)
    end
    
    -- Fisher-Yates shuffle
    for i = #queue.shuffleOrder, 2, -1 do
        local j = math.random(i)
        queue.shuffleOrder[i], queue.shuffleOrder[j] = queue.shuffleOrder[j], queue.shuffleOrder[i]
    end
end

-- Fixed RemoveFromQueue function
function RemoveFromQueue(playerId, index)
    InitializePlayerQueue(playerId)
    local queue = playerQueues[playerId]
    
    -- Convert to 1-based index if needed
    local realIndex = index
    if realIndex > 0 and realIndex <= #queue.songs then
        table.remove(queue.songs, realIndex)
        
        -- Adjust current index if necessary
        if queue.currentIndex >= realIndex then
            queue.currentIndex = math.max(0, queue.currentIndex - 1)
        end
        
        -- Update shuffle order
        if queue.shuffle then
            UpdateShuffleOrder(playerId)
        end
        
        return true
    end
    
    return false
end

function ClearQueue(playerId)
    InitializePlayerQueue(playerId)
    playerQueues[playerId].songs = {}
    playerQueues[playerId].currentIndex = 0
    playerQueues[playerId].shuffleOrder = {}
end

-- Event: Add to Queue
RegisterNetEvent('carplay:addToQueue')
AddEventHandler('carplay:addToQueue', function(url, volume, range, loop)
    local source = source
    local playerId = tostring(source)

    if IsPlayerOnCooldown(playerId) then
        TriggerClientEvent('carplay:error', source, Config.Lang['cooldown_active'])
        return
    end

    SetPlayerCooldown(playerId)

    if not url or url == "" then
        TriggerClientEvent('carplay:error', source, Config.Lang['invalid_url'])
        return
    end

    -- Get song info and add to queue
    if string.match(url, "youtube%.com") or string.match(url, "youtu%.be") then
        GetYouTubeVideoInfo(url, function(videoInfo)
            local songInfo = videoInfo or {
                title = "YouTube Video",
                artist = "Unknown Artist",
                duration = 180,
                thumbnail = "/placeholder.svg?height=300&width=300"
            }
            
            songInfo.url = url
            songInfo.volume = volume or Config.DefaultVolume
            songInfo.range = range or Config.DefaultRange
            songInfo.loop = loop or false
            
            local success, message = AddToQueue(playerId, songInfo)
            if success then
                TriggerClientEvent('carplay:queueUpdated', source, playerQueues[playerId])
                TriggerClientEvent('carplay:notification', source, message)
            else
                TriggerClientEvent('carplay:error', source, message)
            end
        end)
    else
        local songInfo = {
            title = "Audio Stream",
            artist = "Direct URL",
            duration = 180,
            thumbnail = "/placeholder.svg?height=300&width=300",
            url = url,
            volume = volume or Config.DefaultVolume,
            range = range or Config.DefaultRange,
            loop = loop or false
        }
        
        local success, message = AddToQueue(playerId, songInfo)
        if success then
            TriggerClientEvent('carplay:queueUpdated', source, playerQueues[playerId])
            TriggerClientEvent('carplay:notification', source, message)
        else
            TriggerClientEvent('carplay:error', source, message)
        end
    end
end)

-- Event: Play Next Song
RegisterNetEvent('carplay:playNext')
AddEventHandler('carplay:playNext', function()
    local source = source
    local playerId = tostring(source)
    
    local nextSong = GetNextSong(playerId)
    if nextSong then
        -- Stop current music first
        if activeSounds[playerId] then
            local oldTag = activeSounds[playerId].tag
            TriggerClientEvent('carplay:destroySound', -1, oldTag)
            activeSounds[playerId] = nil
        end
        
        -- Play next song
        local soundTag = "carplay_" .. playerId .. "_" .. GetGameTimer()
        
        activeSounds[playerId] = {
            tag = soundTag,
            url = nextSong.url,
            volume = nextSong.volume,
            range = nextSong.range,
            loop = nextSong.loop,
            owner = source
        }
        
        TriggerClientEvent('carplay:startMusic', -1, soundTag, nextSong.url, nextSong.volume, nextSong.range, nextSong.loop, source)
        TriggerClientEvent('carplay:musicStarted', source, nextSong)
        TriggerClientEvent('carplay:queueUpdated', source, playerQueues[playerId])
    else
        TriggerClientEvent('carplay:error', source, Config.Lang['no_next_song'])
    end
end)

-- Event: Get Queue
RegisterNetEvent('carplay:getQueue')
AddEventHandler('carplay:getQueue', function()
    local source = source
    local playerId = tostring(source)
    
    InitializePlayerQueue(playerId)
    TriggerClientEvent('carplay:queueUpdated', source, playerQueues[playerId])
end)

-- Event: Remove from Queue (Fixed indexing)
RegisterNetEvent('carplay:removeFromQueue')
AddEventHandler('carplay:removeFromQueue', function(index)
    local source = source
    local playerId = tostring(source)
    
    if RemoveFromQueue(playerId, index) then
        TriggerClientEvent('carplay:queueUpdated', source, playerQueues[playerId])
        TriggerClientEvent('carplay:notification', source, "Removed from queue")
    else
        TriggerClientEvent('carplay:error', source, "Failed to remove song from queue")
    end
end)

-- Event: Clear Queue
RegisterNetEvent('carplay:clearQueue')
AddEventHandler('carplay:clearQueue', function()
    local source = source
    local playerId = tostring(source)
    
    ClearQueue(playerId)
    TriggerClientEvent('carplay:queueUpdated', source, playerQueues[playerId])
    TriggerClientEvent('carplay:notification', source, Config.Lang['queue_cleared'])
end)

-- Event: Toggle Shuffle
RegisterNetEvent('carplay:toggleShuffle')
AddEventHandler('carplay:toggleShuffle', function()
    local source = source
    local playerId = tostring(source)
    
    InitializePlayerQueue(playerId)
    local queue = playerQueues[playerId]
    queue.shuffle = not queue.shuffle
    
    if queue.shuffle then
        UpdateShuffleOrder(playerId)
    end
    
    TriggerClientEvent('carplay:queueUpdated', source, queue)
end)

-- Event: Set Repeat Mode
RegisterNetEvent('carplay:setRepeatMode')
AddEventHandler('carplay:setRepeatMode', function(mode)
    local source = source
    local playerId = tostring(source)
    
    InitializePlayerQueue(playerId)
    playerQueues[playerId].repeat_mode = mode
    
    TriggerClientEvent('carplay:queueUpdated', source, playerQueues[playerId])
end)

-- Modified Play Music Event to work with queue
RegisterNetEvent('carplay:playMusic')
AddEventHandler('carplay:playMusic', function(url, volume, range, loop, playNow)
    local source = source
    local playerId = tostring(source)

    print(string.format("[CarPlay] Player %s requested music: %s (Play Now: %s)", source, url, tostring(playNow)))

    if IsPlayerOnCooldown(playerId) then
        TriggerClientEvent('carplay:error', source, Config.Lang['cooldown_active'])
        return
    end

    SetPlayerCooldown(playerId)

    volume = math.max(0, math.min(volume or Config.DefaultVolume, Config.MaxVolume))
    range = math.max(1, math.min(range or Config.DefaultRange, Config.MaxRange))
    loop = loop or false
    playNow = playNow ~= false -- Default to true

    if not url or url == "" then
        TriggerClientEvent('carplay:error', source, Config.Lang['invalid_url'])
        return
    end

    if playNow then
        -- Stop current music and play immediately
        if activeSounds[playerId] then
            local oldTag = activeSounds[playerId].tag
            TriggerClientEvent('carplay:destroySound', -1, oldTag)
            activeSounds[playerId] = nil
        end

        local soundTag = "carplay_" .. playerId .. "_" .. GetGameTimer()

        activeSounds[playerId] = {
            tag = soundTag,
            url = url,
            volume = volume,
            range = range,
            loop = loop,
            owner = source
        }

        TriggerClientEvent('carplay:startMusic', -1, soundTag, url, volume, range, loop, source)

        if string.match(url, "youtube%.com") or string.match(url, "youtu%.be") then
            GetYouTubeVideoInfo(url, function(videoInfo)
                local songInfo = videoInfo or {
                    title = "YouTube Video",
                    artist = "Unknown Artist",
                    duration = 180,
                    thumbnail = "/placeholder.svg?height=300&width=300"
                }
                songInfo.url = url
                songInfo.loop = loop
                songInfo.volume = volume
                TriggerClientEvent('carplay:musicStarted', source, songInfo)
                
                -- Update current song in queue if there's a queue
                InitializePlayerQueue(playerId)
                local queue = playerQueues[playerId]
                if #queue.songs > 0 then
                    -- Set current index to playing song or add it
                    if queue.currentIndex > 0 and queue.currentIndex <= #queue.songs then
                        queue.songs[queue.currentIndex] = songInfo
                    else
                        table.insert(queue.songs, 1, songInfo)
                        queue.currentIndex = 1
                    end
                    TriggerClientEvent('carplay:queueUpdated', source, queue)
                end
            end)
        else
            local songInfo = {
                title = "Audio Stream",
                artist = "Direct URL",
                duration = 180,
                thumbnail = "/placeholder.svg?height=300&width=300",
                url = url,
                loop = loop,
                volume = volume
            }
            TriggerClientEvent('carplay:musicStarted', source, songInfo)
            
            -- Update current song in queue if there's a queue
            InitializePlayerQueue(playerId)
            local queue = playerQueues[playerId]
            if #queue.songs > 0 then
                if queue.currentIndex > 0 and queue.currentIndex <= #queue.songs then
                    queue.songs[queue.currentIndex] = songInfo
                else
                    table.insert(queue.songs, 1, songInfo)
                    queue.currentIndex = 1
                end
                TriggerClientEvent('carplay:queueUpdated', source, queue)
            end
        end

        print(string.format("[CarPlay] Music started with tag: %s", soundTag))
    else
        -- Add to queue instead of playing immediately
        TriggerEvent('carplay:addToQueue', url, volume, range, loop)
    end
end)

-- Event: Stop Music (modified to handle queue)
RegisterNetEvent('carplay:stopMusic')
AddEventHandler('carplay:stopMusic', function()
    local source = source
    local playerId = tostring(source)

    print(string.format("[CarPlay] Player %s stopped music", source))

    if activeSounds[playerId] then
        local soundTag = activeSounds[playerId].tag
        TriggerClientEvent('carplay:destroySound', -1, soundTag)
        TriggerClientEvent('carplay:musicStopped', source)
        activeSounds[playerId] = nil
        print(string.format("[CarPlay] Destroyed sound: %s", soundTag))
    end
end)

-- Auto-play next song when current ends
RegisterNetEvent('carplay:songEnded')
AddEventHandler('carplay:songEnded', function()
    local source = source
    local playerId = tostring(source)
    
    -- Clear current sound
    if activeSounds[playerId] then
        activeSounds[playerId] = nil
    end
    
    if Config.AutoPlayNext then
        -- Small delay before playing next song
        SetTimeout(1000, function()
            local nextSong = GetNextSong(playerId)
            if nextSong then
                TriggerEvent('carplay:playMusic', nextSong.url, nextSong.volume, nextSong.range, nextSong.loop, true)
            end
        end)
    end
end)

-- Clean up sounds when player disconnects
AddEventHandler('playerDropped', function(reason)
    local source = source
    local playerId = tostring(source)

    if activeSounds[playerId] then
        local soundTag = activeSounds[playerId].tag
        TriggerClientEvent('carplay:destroySound', -1, soundTag)
        activeSounds[playerId] = nil
        print(string.format("[CarPlay] Cleaned up sound for disconnected player: %s", playerId))
    end

    -- Clean up queue if not saving
    if not Config.SaveQueueOnDisconnect then
        playerQueues[playerId] = nil
    end
    
    playerCooldowns[playerId] = nil
end)

-- Server command for debugging
RegisterCommand('carplay_debug', function(source, args, rawCommand)
    if source == 0 then
        print("[CarPlay Debug] Active sounds:")
        local count = 0
        for playerId, soundData in pairs(activeSounds) do
            print(string.format("  Player %s: %s (Owner: %s, Loop: %s)", playerId, soundData.tag, soundData.owner, tostring(soundData.loop)))
            count = count + 1
        end
        print(string.format("[CarPlay Debug] Total active sounds: %d", count))
        
        print("[CarPlay Debug] Player queues:")
        for playerId, queueData in pairs(playerQueues) do
            print(string.format("  Player %s: %d songs, current: %d, shuffle: %s, repeat: %s", 
                playerId, #queueData.songs, queueData.currentIndex, 
                tostring(queueData.shuffle), queueData.repeat_mode))
        end
    end
end, true)

-- Test command to check video info extraction
RegisterCommand('carplay_test_info', function(source, args, rawCommand)
    if source == 0 and args[1] then
        print("[CarPlay] Testing video info extraction for: " .. args[1])
        GetYouTubeVideoInfo(args[1], function(videoInfo)
            if videoInfo then
                print(string.format("[CarPlay] Title: '%s'", videoInfo.title))
                print(string.format("[CarPlay] Artist: '%s'", videoInfo.artist))
                print(string.format("[CarPlay] Duration: %s seconds", videoInfo.duration))
                print(string.format("[CarPlay] Thumbnail: %s", videoInfo.thumbnail))
            else
                print("[CarPlay] Failed to extract video info")
            end
        end)
    end
end, true)