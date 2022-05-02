local json = require("lib/json")
local Buffer = require("lib/Buffer")
local fUtils = require("lib/flippy-utils")
local default_speaker = peripheral.find("speaker")

local loadPackets, playAudioBuffer
local oldPullEvent = os.pullEvent
os.pullEvent = os.pullEventRaw

local YTStream = {
    ws = nil,
    buffer = Buffer:new(),
    speakers = nil,

    loaded = false,
    primed = false,
    paused = true,
    finishedLoading = false,
    finishedPlaying = false,

    currentTime = 0,
    nextPacketId = 0,
    playbackHandlers = nil,
    config = {}
}

YTStream.config = {
    host = "ws://127.0.0.1:3000",
    name = "ccCLient",
    bufferSize = 10, -- in seconds
    primedFactor = 0.75
}

YTStream.init = function(opts, speakers)
    -- Change config variables using given opts
    if opts then
        for k, v in pairs(opts) do
            YTStream.config[k] = v
        end
    end

    -- Set speaker to default speaker if none were provided
    if speakers ~= nil then 
        YTStream.speakers = speakers
    else
        YTStream.speakers = default_speaker
    end

    -- Convert bufferSize from seconds to bytes
    YTStream.config.bufferSize = 48000 * YTStream.config.bufferSize

    -- Connect to WebSocket
    fUtils.printC(colors.yellow, "Connecting to remote server...")
    YTStream.ws = http.websocket(YTStream.config.host)

    if not YTStream.ws then
        error("Could not connect to Websocket.")
    end
    
    -- Identify self as ccClient
    YTStream.ws.send(json.encode({
        type = "initialize",
        client = YTStream.config.name
    }))
    
    fUtils.printC(colors.yellow, "Connection successful.")
end

YTStream.search = function(query, numResults)
    YTStream.ws.send(json.encode({type = "searchYouTube", query = query, numResults = numResults}))
    local msg = YTStream.ws.receive()
    if msg == nil then error("Could not execute search.") end
    return json.decode(msg)
end

YTStream.load = function(selection)
    fUtils.writeC(colors.yellow, "Requesting stream for")
    fUtils.writeC(colors.green, selection.title .. '\n')
    YTStream.ws.send(json.encode({type = "requestStream", videoInfo = selection}))
    YTStream.loaded = true
end

YTStream.stop = function()
    YTStream.buffer:clear()
    YTStream.speakers.stop()
    YTStream.ws.send(json.encode({type = "endStream"}))
end

YTStream.stopCheck = function()
    if YTStream.finishedLoading and #YTStream.buffer == 0 then
        YTStream.finishedPlaying = true
        sleep(.5)
    end
end

YTStream.play = function()
    YTStream.paused = false
end

YTStream.pause = function()
    YTStream.paused = true
end

YTStream.togglePause = function()
    YTStream.paused = not YTStream.paused
end

YTStream.resetState = function()
    YTStream.loaded = false
    YTStream.primed = false
    YTStream.paused = true
    YTStream.finishedLoading = false
    YTStream.finishedPlaying = false
    YTStream.currentTime = 0
    YTStream.nextPacketId = 0
end

YTStream.waitForEnd = function()
    while not YTStream.finishedPlaying do
        coroutine.yield()
    end
end

YTStream.rewind = function()

end

YTStream.forward = function()

end

YTStream.close = function()
    YTStream.ws.close()
    fUtils.printC(colors.yellow, ("Connection closed."))
end





-- Playback Handlers
function loadPackets()
    os.pullEvent = os.pullEventRaw
    while true do
        local msg

        -- Only request more packets the stream is loaded and while the buffer is not full, until it is done loading.
        if YTStream.loaded and #YTStream.buffer < YTStream.config.bufferSize and not YTStream.finishedLoading then
            YTStream.ws.send(json.encode({type = "requestPacket", packetId = YTStream.nextPacketId}))
            msg = YTStream.ws.receive()
        end

        -- Process the received packet
        if msg ~= nil then 
            local data = json.decode(msg)
            YTStream.ws.send(json.encode({type = "packetReceived", packetId = data.i}))

            -- Check if the stream is done downloading
            if data.i == -1 and data.p == nil then 
                YTStream.finishedLoading = true
                fUtils.printC(colors.yellow, ("Finished loading stream."))

            -- Push packet to buffer if it is the expected packet
            elseif data.i == YTStream.nextPacketId then 
                YTStream.buffer:push(data.p)
                YTStream.nextPacketId = (YTStream.nextPacketId + 1) % 128
                local bufferPct = ("%.2f%%"):format((#YTStream.buffer / YTStream.config.bufferSize) * 100)
                local bufferTimeLen = ("%.2fs"):format(#YTStream.buffer/48000)
                local currentTimeStr = (YTStream.currentTime >= 3600) and os.date("%H:%M:%S", YTStream.currentTime) or os.date("%M:%S", YTStream.currentTime)
                print(data.i, #data.p, bufferPct, currentTimeStr)
            else
                -- print("PACKET", YTStream.nextPacketId, "MISSED") 
            end

            -- Mark the stream as "primed" if more than [primedFactor * 100]% of the buffer is filled. OR, if the stream is done loading
            if not YTStream.primed and #YTStream.buffer > YTStream.config.bufferSize * YTStream.config.primedFactor or YTStream.finishedLoading then YTStream.primed = true end
        end
        coroutine.yield()
    end
end

function playAudioBuffer()
    os.pullEvent = os.pullEventRaw
    while true do
        local chunk = {}
        -- Pull chunk from buffer only if the stream is loaded, primed, and not paused
        if YTStream.loaded and YTStream.primed and not YTStream.paused then
            chunk = YTStream.buffer:pull(1024*12)
        end
        -- Send chunk to CC's audio buffer if it's not empty
        if #chunk > 0 then
            while not YTStream.speakers.playAudio(chunk) do
                -- fUtils.printC(colors.yellow, "BUFFER WAS FULL")
                os.pullEvent("speaker_audio_empty")
            end
            YTStream.currentTime = YTStream.currentTime + #chunk / 48000
            sleep(#chunk / 48000)

            -- Mark the end of the stream if it's done loading and buffer is empty
            YTStream.stopCheck()
        else
            YTStream.stopCheck()
            coroutine.yield()
        end
    end
end

function closeOnTerminate()
    os.pullEvent = os.pullEventRaw
    while true do
        local event = os.pullEventRaw()
        if event == "terminate" then
            if YTStream.ws then YTStream.close() end
            os.pullEvent = oldPullEvent
            error("Terminated", 0)
            return
        end
    end
end

YTStream.playbackHandlers = {loadPackets, playAudioBuffer, closeOnTerminate}


return YTStream

