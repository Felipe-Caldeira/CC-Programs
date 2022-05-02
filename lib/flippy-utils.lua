local pretty = require("cc.pretty")
local fUtils = {}


-- Basic Utils
fUtils.writeC = function(color, str)
    local oldTextColor = term.getTextColor()
    term.setTextColor(color)
    write(str)
    term.setTextColor(oldTextColor)
end

fUtils.printC = function(color, ...)
    local oldTextColor = term.getTextColor()
    term.setTextColor(color)
    print(...)
    term.setTextColor(oldTextColor)
end


-- Peripheral Utils
fUtils.peripheral = {}

fUtils.peripheral.wrapAll = function(type)
    local group = {}
    local allPeripheralNames = peripheral.getNames()
    for _, name in ipairs(allPeripheralNames) do
        if peripheral.getType(name) == type then
            group[name] = peripheral.wrap(name)
        end
    end

    assert(fUtils.table.size(group) > 1, "No peripherals of given type found.")

    local peripheralNames = fUtils.table.getKeys(group)
    local methodNames = peripheral.getMethods(peripheralNames[1])
    for _, method in ipairs(methodNames) do 
        group[method] = function(...)
            for _, name in ipairs(peripheralNames) do
                group[name][method](table.unpack(arg))
            end
        end
    end
    return group
end


-- Table Utils
fUtils.table = {}

fUtils.table.getKeys = function(t)
    local keys={}
    for key,_ in pairs(t) do
        table.insert(keys, key)
    end
    return keys
end

fUtils.table.getValues = function(t)
    local vals={}
    for _,val in pairs(t) do
        table.insert(vals, val)
    end
    return vals
end

fUtils.table.print = function(t)
    pretty.pretty_print(t)
end

fUtils.table.size = function(t)
    return #fUtils.table.getKeys(t)
end

return fUtils


