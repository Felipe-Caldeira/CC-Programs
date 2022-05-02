Buffer = {arr = {}, size = 0}

function Buffer:new (o, arr)
   o = o or {}
   setmetatable(o, self)
   self.arr = arr or {}
   self.__index = self
   return o
end

Buffer.__len = function(buff)
    return #buff.arr
end

function Buffer:push(t)
    for _,v in ipairs(t) do 
        table.insert(self.arr, v)
    end
    self.size = self.size + #t
end

function Buffer:pull(size)
    local chunk = {unpack(self.arr, 1, size)}
    self.arr = {unpack(self.arr, size + 1)}
    self.size = math.max(self.size - size, 0)
    return chunk
end

function Buffer:clear(t)
    self.arr = {}
    self.size = 0
end

function Buffer:print()
    io.write("{ ")
    for i = 1, #self.arr do
        io.write(self.arr[i], " ")
    end
    print("}")
end


-- function printTable(t)
--     print(table.unpack(t))
-- end

-- local a = Buffer:new()
-- a:push({1,2,3,4,5,6,7,8,9})
-- print(#a)
-- a:print()
-- printTable(a:pull(4))
-- a:print()
-- printTable(a:pull(4))
-- a:print()
-- printTable(a:pull(4))
-- a:print()
-- printTable(a:pull(4))
-- a:print()
-- a:push({1,3,5,7,9})
-- a:print()
-- printTable(a:pull(4))
-- a:print()

return Buffer