local Levels=require("src.levels")
local Save = {}
function Save.defaults()
    return {version=2,coins=0,ammo=5,level=1,unlocked=1,completed=false,owned={},equipped={},collected={},checkpoint=false,best={}}
end
local function encode(value)
    if type(value)=="number" then return tostring(value)
    elseif type(value)=="boolean" then return tostring(value)
    elseif type(value)=="string" then return string.format("%q",value)
    elseif type(value)=="table" then
        local parts={"{"}
        for k,v in pairs(value) do parts[#parts+1]="["..encode(k).."]="..encode(v).."," end
        parts[#parts+1]="}"
        return table.concat(parts)
    end
    error("Unsupported save value")
end
function Save.write(data)
    local ok=love.filesystem.write("progress.tmp","return "..encode(data))
    if not ok then return false end
    -- Keep the previous complete save as a recovery file.
    local previous=love.filesystem.read("progress.lua")
    if previous then love.filesystem.write("progress.bak",previous) end
    return love.filesystem.write("progress.lua","return "..encode(data))
end
local function read(path)
    local contents=love.filesystem.read(path)
    if not contents then return nil end
    local fn
    if loadstring then
        fn=loadstring(contents,"save")
        if fn then setfenv(fn,{}) end
    else fn=load(contents,"save","t",{}) end
    if not fn then return nil end
    local ok,data=pcall(fn)
    if not ok or type(data)~="table" or (data.version~=1 and data.version~=2) then return nil end
    local result=Save.defaults()
    for _,key in ipairs({"coins","ammo","level","unlocked"}) do
        local n=data[key]
        if type(n)~="number" or n~=n or n==math.huge or n==-math.huge then return nil end
        result[key]=math.floor(n)
    end
    result.coins=math.max(0,result.coins)
    result.ammo=math.max(0,math.min(99,result.ammo))
    result.level=math.max(1,math.min(Levels.count,result.level))
    result.unlocked=math.max(result.level,math.min(Levels.count,result.unlocked))
    result.completed=data.completed==true
    result.checkpoint=data.checkpoint==true
    for _,key in ipairs({"owned","equipped","collected","best"}) do
        if type(data[key])=="table" then result[key]=data[key] end
    end
    if data.version==1 and result.completed then
        -- Former ten-level champions continue directly into the expansion.
        result.level=11; result.unlocked=math.max(11,result.unlocked)
        result.completed=false; result.checkpoint=false; result.collected={}
    end
    return result
end
function Save.load() return read("progress.lua") or read("progress.bak") or Save.defaults() end
return Save
