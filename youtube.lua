local YTStream = require("lib/YTStream")
local fUtils = require("lib/flippy-utils")
local args = {...}

YTStream.init({name="Flippy"})

function main()
    os.pullEvent = os.pullEventRaw
    while true do
        local selection = getSelection()
        YTStream.load(selection)
        YTStream.play()
        YTStream.waitForEnd()
        YTStream.resetState()
        fUtils.printC(colors.yellow, "Stream ended.")
        sleep(2)
    end
end

function getSelection()
    local results, selection
    while selection == nil do 
        term.clear()
        term.setCursorPos(1,1)
        fUtils.writeC(colors.red, "Search: ")
        local query = read()
        if query == "" then query = "LoFi" end
        results = YTStream.search(query, 5)
        selection = selectFromResults(results)
        term.clear()
        term.setCursorPos(1,1)
        sleep(.1)
    end
    return selection
end

function selectFromResults(results)
    fUtils.printC(colors.yellow, "Press a number to select a video:")
    for i, res in ipairs(results) do
        fUtils.writeC(colors.blue, ("[%d] "):format(i))
        fUtils.writeC(colors.green, res.title .. ' ')
        fUtils.writeC(colors.red, res.duration .. "\n")
    end
    fUtils.printC(colors.yellow, "Press 'q' to perform a new query")
    while true do
        local event, key = os.pullEvent("key")
        if key ~= nil then
            if key == keys.q then return nil end
            key = key - 48
            if key > 0 and key <= #results then
                return results[key]
            end
        end
    end
end

function manageInputs()
    os.pullEvent = os.pullEventRaw
    while true do
        if YTStream.loaded then
            local event, key, isHeld = os.pullEvent("key")
            if key == keys.space then 
                YTStream.togglePause()
            elseif key == keys.q then
                YTStream.stop()
            end
        end 
        coroutine.yield() 
    end
end

parallel.waitForAll(main, manageInputs, table.unpack(YTStream.playbackHandlers))