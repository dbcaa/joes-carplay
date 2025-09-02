local isCarPlayOpen = false
local currentVehicle = nil
local lastCommandTime = 0
local activeMusicTags = {}
local currentSoundTag = nil
local currentQueue = {
    songs = {},
    currentIndex = 0,
    shuffle = false,
    repeat_mode = 'none'
}

-- Register key mapping for F7
RegisterKeyMapping(Config.OpenCommand, 'Open CarPlay Interface', 'keyboard', Config.OpenKey)

-- Command to open CarPlay
RegisterCommand(Config.OpenCommand, function()
    local currentTime = GetGameTimer()
    
    -- Check cooldown
    if currentTime - lastCommandTime < Config.CommandCooldown then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = true,
            args = {"CarPlay", Config.Lang['cooldown_active']}
        })
        return
    end
    
    lastCommandTime = currentTime
    
    -- Check if player is in vehicle
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if vehicle == 0 then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = true,
            args = {"CarPlay", Config.Lang['not_in_vehicle']}
        })
        return
    end
    
    currentVehicle = vehicle
    OpenCarPlay()
end, false)

-- Function to open CarPlay interface
function OpenCarPlay()
    if isCarPlayOpen then return end
    
    isCarPlayOpen = true
    
    -- Properly set NUI focus and cursor
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    
    -- Disable HUD components that might interfere
    DisplayRadar(false)
    
    -- Get current queue from server
    TriggerServerEvent('carplay:getQueue')
    
    -- Check if there's currently playing music and update UI
    local playingState = false
    local songInfo = nil
    
    if currentSoundTag and exports.xsound:soundExists(currentSoundTag) then
        playingState = exports.xsound:isPlaying(currentSoundTag)
        local soundInfo = exports.xsound:getInfo(currentSoundTag)
        if soundInfo then
            songInfo = {
                isPlaying = playingState,
                isPaused = exports.xsound:isPaused(currentSoundTag),
                volume = math.floor(soundInfo.volume * 100),
                currentTime = exports.xsound:getTimeStamp(currentSoundTag) or 0,
                duration = exports.xsound:getMaxDuration(currentSoundTag) or 180,
                url = exports.xsound:getLink(currentSoundTag) or ""
            }
        end
    end
    
    -- Send message to NUI with proper data structure
    SendNUIMessage({
        type = 'openCarPlay',
        config = {
            volume = Config.DefaultVolume,
            range = Config.DefaultRange,
            colors = Config.Colors
        },
        currentState = {
            isPlaying = playingState,
            songInfo = songInfo
        },
        queue = currentQueue
    })
end

-- Function to close CarPlay interface
function CloseCarPlay()
    if not isCarPlayOpen then return end
    
    isCarPlayOpen = false
    
    -- Properly restore NUI focus
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    
    -- Re-enable HUD components
    DisplayRadar(true)
    
    -- Send close message to NUI
    SendNUIMessage({
        type = 'closeCarPlay'
    })
end

-- NUI Callback: Play Music
RegisterNUICallback('playMusic', function(data, cb)
    if not currentVehicle or currentVehicle == 0 then
        cb({success = false, error = Config.Lang['not_in_vehicle']})
        return
    end
    
    local url = data.url
    local volume = data.volume or Config.DefaultVolume
    local range = data.range or Config.DefaultRange
    local loop = data.loop or false
    local playNow = data.playNow ~= false -- Default to true
    
    -- Basic URL validation
    if not url or url == "" then
        cb({success = false, error = Config.Lang['invalid_url']})
        return
    end
    
    -- Send to server for processing
    TriggerServerEvent('carplay:playMusic', url, volume, range, loop, playNow)
    cb({success = true})
end)

-- NUI Callback: Add to Queue
RegisterNUICallback('addToQueue', function(data, cb)
    if not currentVehicle or currentVehicle == 0 then
        cb({success = false, error = Config.Lang['not_in_vehicle']})
        return
    end
    
    local url = data.url
    local volume = data.volume or Config.DefaultVolume
    local range = data.range or Config.DefaultRange
    local loop = data.loop or false
    
    if not url or url == "" then
        cb({success = false, error = Config.Lang['invalid_url']})
        return
    end
    
    TriggerServerEvent('carplay:addToQueue', url, volume, range, loop)
    cb({success = true})
end)

-- NUI Callback: Play Next
RegisterNUICallback('playNext', function(data, cb)
    TriggerServerEvent('carplay:playNext')
    cb({success = true})
end)

-- NUI Callback: Remove from Queue
RegisterNUICallback('removeFromQueue', function(data, cb)
    local index = data.index
    if index then
        TriggerServerEvent('carplay:removeFromQueue', index)
        cb({success = true})
    else
        cb({success = false, error = "Invalid index"})
    end
end)

-- NUI Callback: Clear Queue
RegisterNUICallback('clearQueue', function(data, cb)
    TriggerServerEvent('carplay:clearQueue')
    cb({success = true})
end)

-- NUI Callback: Toggle Shuffle
RegisterNUICallback('toggleShuffle', function(data, cb)
    TriggerServerEvent('carplay:toggleShuffle')
    cb({success = true})
end)

-- NUI Callback: Set Repeat Mode
RegisterNUICallback('setRepeatMode', function(data, cb)
    local mode = data.mode or 'none'
    TriggerServerEvent('carplay:setRepeatMode', mode)
    cb({success = true})
end)

-- NUI Callback: Stop Music
RegisterNUICallback('stopMusic', function(data, cb)
    TriggerServerEvent('carplay:stopMusic')
    cb({success = true})
end)

-- NUI Callback: Pause Music
RegisterNUICallback('pauseMusic', function(data, cb)
    if currentSoundTag and exports.xsound:soundExists(currentSoundTag) then
        exports.xsound:Pause(currentSoundTag)
        SendNUIMessage({
            type = 'musicPaused'
        })
        cb({success = true})
    else
        cb({success = false, error = "No music playing"})
    end
end)

-- NUI Callback: Resume Music
RegisterNUICallback('resumeMusic', function(data, cb)
    if currentSoundTag and exports.xsound:soundExists(currentSoundTag) then
        exports.xsound:Resume(currentSoundTag)
        SendNUIMessage({
            type = 'musicResumed'
        })
        cb({success = true})
    else
        cb({success = false, error = "No music to resume"})
    end
end)

-- NUI Callback: Seek Music
RegisterNUICallback('seekMusic', function(data, cb)
    if currentSoundTag and exports.xsound:soundExists(currentSoundTag) then
        local seekTime = data.time or 0
        exports.xsound:setTimeStamp(currentSoundTag, seekTime)
        cb({success = true})
    else
        cb({success = false, error = "No music playing"})
    end
end)

-- NUI Callback: Set Volume
RegisterNUICallback('setVolume', function(data, cb)
    if currentSoundTag and exports.xsound:soundExists(currentSoundTag) then
        local volume = (data.volume or 50) / 100
        exports.xsound:setVolumeMax(currentSoundTag, volume)
        cb({success = true})
    else
        cb({success = false, error = "No music playing"})
    end
end)

-- NUI Callback: Close Interface
RegisterNUICallback('close', function(data, cb)
    CloseCarPlay()
    cb({success = true})
end)

-- Event: Start Music (from server to all clients)
RegisterNetEvent('carplay:startMusic')
AddEventHandler('carplay:startMusic', function(soundTag, url, volume, range, loop, owner)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if vehicle ~= 0 then
        local coords = GetEntityCoords(vehicle)
        
        -- Play music using xsound with position and loop
        exports.xsound:PlayUrlPos(soundTag, url, volume / 100, coords, loop, {
            onPlayStart = function()
                print(string.format("[CarPlay] Music started: %s", soundTag))
                currentSoundTag = soundTag
                
                -- Send real-time info to UI
                CreateThread(function()
                    while exports.xsound:soundExists(soundTag) and exports.xsound:isPlaying(soundTag) do
                        if isCarPlayOpen then
                            local currentTime = exports.xsound:getTimeStamp(soundTag) or 0
                            local duration = exports.xsound:getMaxDuration(soundTag) or 180
                            local isPaused = exports.xsound:isPaused(soundTag)
                            
                            SendNUIMessage({
                                type = 'updateProgress',
                                currentTime = currentTime,
                                duration = duration,
                                isPaused = isPaused
                            })
                        end
                        Wait(1000)
                    end
                end)
            end,
            onPlayEnd = function()
                print(string.format("[CarPlay] Music ended: %s", soundTag))
                currentSoundTag = nil
                if isCarPlayOpen then
                    SendNUIMessage({
                        type = 'musicStopped'
                    })
                end
                
                -- Notify server that song ended for auto-play
                TriggerServerEvent('carplay:songEnded')
            end,
            onPlayPause = function()
                print(string.format("[CarPlay] Music paused: %s", soundTag))
                if isCarPlayOpen then
                    SendNUIMessage({
                        type = 'musicPaused'
                    })
                end
            end,
            onPlayResume = function()
                print(string.format("[CarPlay] Music resumed: %s", soundTag))
                if isCarPlayOpen then
                    SendNUIMessage({
                        type = 'musicResumed'
                    })
                end
            end,
            onLoading = function()
                print(string.format("[CarPlay] Music loading: %s", soundTag))
                if isCarPlayOpen then
                    SendNUIMessage({
                        type = 'musicLoading'
                    })
                end
            end
        })
        
        exports.xsound:Distance(soundTag, range)
        
        -- Store the tag for cleanup
        activeMusicTags[soundTag] = {
            vehicle = vehicle,
            owner = owner
        }
        
        -- Update position thread
        CreateThread(function()
            while activeMusicTags[soundTag] and exports.xsound:soundExists(soundTag) do
                if DoesEntityExist(vehicle) then
                    local newCoords = GetEntityCoords(vehicle)
                    exports.xsound:Position(soundTag, newCoords)
                else
                    -- Vehicle no longer exists, clean up
                    exports.xsound:Destroy(soundTag)
                    activeMusicTags[soundTag] = nil
                    if currentSoundTag == soundTag then
                        currentSoundTag = nil
                    end
                    break
                end
                Wait(250)
            end
        end)
        
        print(string.format("[CarPlay] Started music: %s (Loop: %s)", soundTag, tostring(loop)))
    end
end)

-- Event: Destroy Sound (from server to all clients)
RegisterNetEvent('carplay:destroySound')
AddEventHandler('carplay:destroySound', function(soundTag)
    if activeMusicTags[soundTag] then
        exports.xsound:Destroy(soundTag)
        activeMusicTags[soundTag] = nil
        if currentSoundTag == soundTag then
            currentSoundTag = nil
        end
        print(string.format("[CarPlay] Destroyed sound: %s", soundTag))
    end
end)

-- Server Events
RegisterNetEvent('carplay:musicStarted')
AddEventHandler('carplay:musicStarted', function(songInfo)
    SendNUIMessage({
        type = 'musicStarted',
        songInfo = songInfo
    })
    
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        multiline = true,
        args = {"CarPlay", Config.Lang['music_started']}
    })
end)

RegisterNetEvent('carplay:musicStopped')
AddEventHandler('carplay:musicStopped', function()
    currentSoundTag = nil
    SendNUIMessage({
        type = 'musicStopped'
    })
    
    TriggerEvent('chat:addMessage', {
        color = {255, 255, 0},
        multiline = true,
        args = {"CarPlay", Config.Lang['music_stopped']}
    })
end)

RegisterNetEvent('carplay:queueUpdated')
AddEventHandler('carplay:queueUpdated', function(queueData)
    currentQueue = queueData
    if isCarPlayOpen then
        SendNUIMessage({
            type = 'queueUpdated',
            queue = queueData
        })
    end
end)

RegisterNetEvent('carplay:notification')
AddEventHandler('carplay:notification', function(message)
    if isCarPlayOpen then
        SendNUIMessage({
            type = 'notification',
            message = message
        })
    end
    
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        multiline = true,
        args = {"CarPlay", message}
    })
end)

RegisterNetEvent('carplay:error')
AddEventHandler('carplay:error', function(error)
    SendNUIMessage({
        type = 'error',
        message = error
    })
    
    TriggerEvent('chat:addMessage', {
        color = {255, 0, 0},
        multiline = true,
        args = {"CarPlay", error}
    })
end)

-- Close CarPlay when exiting vehicle
CreateThread(function()
    while true do
        Wait(1000)
        
        if isCarPlayOpen then
            local playerPed = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            
            if vehicle == 0 then
                CloseCarPlay()
                currentVehicle = nil
            end
        end
    end
end)

-- Clean up sounds when resource stops
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for soundTag, _ in pairs(activeMusicTags) do
            exports.xsound:Destroy(soundTag)
        end
        activeMusicTags = {}
        currentSoundTag = nil
    end
end)
