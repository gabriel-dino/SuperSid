local Levels=require("src.levels")
local utf8=require("utf8")
local Custom={directory="levels",extension=".sidlevel",maxBytes=262144,maxObjects=2000}
Custom.biomes={"meadow","forest","ridge","night","canyon","halloween","snow","sunset","glacier","blizzard","summit"}
local enemySizes={monkey={26,28},bird={28,20},icecube={30,30},snowball={24,24}}
local function copy(value)
    if type(value)~="table" then return value end
    local out={}; for k,v in pairs(value) do out[k]=copy(v) end; return out
end
Custom.copy=copy
local function integer(n,lo,hi)
    return type(n)=="number" and n==math.floor(n) and n>=lo and n<=hi
end
local function text(s,limit)
    return type(s)=="string" and #s>0 and #s<=limit and s:find("%S") and
        not s:find("[%z\1-\31\127]") and utf8.len(s)~=nil
end
local function rect(r,width)
    return type(r)=="table" and integer(r.x,0,width-1) and integer(r.y,0,539) and
        integer(r.w,1,width) and integer(r.h,1,540) and r.x+r.w<=width and r.y+r.h<=540
end
function Custom.validate(level)
    if type(level)~="table" then return nil,"Invalid level data." end
    if not text(level.name,64) or not text(level.author,48) then return nil,"Enter a name (1-64 bytes) and author (1-48 bytes)." end
    if not integer(level.width,960,15360) then return nil,"Level width must be between 960 and 15360 pixels." end
    local biomeOK=false
    for _,biome in ipairs(Custom.biomes) do if level.biome==biome then biomeOK=true end end
    if not biomeOK then return nil,"Unknown scenery theme." end
    local total=0
    for _,key in ipairs({"platforms","coins","ammo","enemies"}) do
        if type(level[key])~="table" then return nil,"Missing level objects." end
        total=total+#level[key]
        if total>Custom.maxObjects then return nil,"A level can contain at most 2000 objects." end
        for _,item in ipairs(level[key]) do
            if not rect(item,level.width) then return nil,"An object is outside the level or has an invalid size." end
            if key=="platforms" and item.kind~="ground" and item.kind~="ledge" then return nil,"Unknown terrain type." end
            if key=="enemies" and not enemySizes[item.kind] then return nil,"Unknown enemy type." end
        end
    end
    if #level.platforms==0 then return nil,"Add some terrain or platforms first." end
    if type(level.spawn)~="table" or not rect({x=level.spawn.x,y=level.spawn.y,w=23,h=43},level.width) then return nil,"Place Sid's start inside the level." end
    if not rect(level.goal,level.width) then return nil,"Place the finish flag inside the level." end
    if level.checkpoint and not rect(level.checkpoint,level.width) then return nil,"Place the checkpoint inside the level." end
    local function supported(marker,w,h)
        local feet=marker.y+h
        for _,p in ipairs(level.platforms) do
            if marker.x+w>p.x and marker.x<p.x+p.w and feet<=p.y and p.y-feet<=96 then return true end
        end
    end
    if not supported(level.spawn,23,43) then return nil,"Sid's start needs a platform no more than 96 pixels below it." end
    if not supported(level.goal,level.goal.w,level.goal.h) then return nil,"The finish flag needs terrain beneath it." end
    if level.checkpoint and not supported(level.checkpoint,level.checkpoint.w,level.checkpoint.h) then return nil,"The checkpoint needs terrain beneath it." end
    for _,p in ipairs(level.platforms) do
        if p.kind=="ground" and level.spawn.x+23>p.x and level.spawn.x<p.x+p.w and
            level.spawn.y+43>p.y and level.spawn.y<p.y+p.h then return nil,"Sid's start is inside solid terrain." end
    end
    for _,e in ipairs(level.enemies) do
        if e.kind~="bird" then
            local onPlatform=false
            for _,p in ipairs(level.platforms) do
                if e.x>=p.x and e.x+e.w<=p.x+p.w and e.y+e.h==p.y then onPlatform=true; break end
            end
            if not onPlatform then return nil,"Walking enemies need a platform directly under their feet." end
        end
    end
    return true
end
function Custom.new()
    return {name="My little adventure",author="Player",biome="meadow",width=2880,height=540,
        platforms={{x=0,y=432,w=2880,h=108,kind="ground"}},coins={},ammo={},enemies={},
        spawn={x=48,y=389},goal={x=2760,y=340,w=42,h=92}}
end
function Custom.encode(level)
    local ok,message=Custom.validate(level)
    if not ok then return nil,message end
    local rows={"SUPER_SID_LEVEL\t1"}
    local function row(...) local fields={...}; for i,v in ipairs(fields) do fields[i]=tostring(v) end; rows[#rows+1]=table.concat(fields,"\t") end
    row("name",level.name); row("author",level.author); row("biome",level.biome); row("width",level.width)
    row("spawn",level.spawn.x,level.spawn.y); row("goal",level.goal.x,level.goal.y)
    if level.checkpoint then row("checkpoint",level.checkpoint.x,level.checkpoint.y) end
    for _,p in ipairs(level.platforms) do row(p.kind=="ground" and "ground" or "platform",p.x,p.y,p.w,p.h) end
    for _,c in ipairs(level.coins) do row("coin",c.x,c.y) end
    for _,a in ipairs(level.ammo) do row("ammo",a.x,a.y) end
    for _,e in ipairs(level.enemies) do row(e.kind,e.x,e.y) end
    return table.concat(rows,"\n").."\n"
end
function Custom.decode(data)
    if type(data)~="string" or #data>Custom.maxBytes then return nil,"Level file is missing or larger than 256 KB." end
    local level={height=540,platforms={},coins={},ammo={},enemies={}}
    local seen={}; local count=0
    for line in (data.."\n"):gmatch("([^\n]*)\n") do
        line=line:gsub("\r$","")
        if line~="" then
            count=count+1
            if count>Custom.maxObjects+10 then return nil,"Too many level records." end
            local f={}; for field in (line.."\t"):gmatch("([^\t]*)\t") do f[#f+1]=field end
            local tag=f[1]
            if count==1 then
                if line~="SUPER_SID_LEVEL\t1" then return nil,"This is not a Super Sid .sidlevel file (version 1)." end
            elseif tag=="name" or tag=="author" or tag=="biome" or tag=="width" then
                if #f~=2 or seen[tag] then return nil,"Invalid or duplicate level metadata." end
                seen[tag]=true; level[tag]=tag=="width" and tonumber(f[2]) or f[2]
            elseif tag=="spawn" or tag=="goal" or tag=="checkpoint" then
                if #f~=3 or seen[tag] then return nil,"Invalid or duplicate level marker." end
                seen[tag]=true
                level[tag]={x=tonumber(f[2]),y=tonumber(f[3]),w=tag=="goal" and 42 or 18,h=tag=="goal" and 92 or 60}
            elseif tag=="ground" or tag=="platform" then
                if #f~=5 then return nil,"Invalid terrain record." end
                level.platforms[#level.platforms+1]={x=tonumber(f[2]),y=tonumber(f[3]),w=tonumber(f[4]),h=tonumber(f[5]),kind=tag=="ground" and "ground" or "ledge"}
            elseif tag=="coin" or tag=="ammo" or enemySizes[tag] then
                if #f~=3 then return nil,"Invalid object record." end
                local size=enemySizes[tag] or (tag=="coin" and {12,16} or {18,22})
                local key=tag=="coin" and "coins" or tag=="ammo" and "ammo" or "enemies"
                level[key][#level[key]+1]={kind=enemySizes[tag] and tag or nil,x=tonumber(f[2]),y=tonumber(f[3]),w=size[1],h=size[2]}
            else return nil,"Unknown level record: "..tostring(tag) end
        end
    end
    if not seen.spawn or not seen.goal then return nil,"The level needs a start and a finish flag." end
    local ok,message=Custom.validate(level)
    if not ok then return nil,message end
    return level
end
function Custom.runtime(level)
    local ok,message=Custom.validate(level)
    if not ok then return nil,message end
    local out=copy(level)
    out.index=0; out.custom=true; out.height=540; out.decorations={}; out.difficulty=Levels.difficulty(1)
    for _,key in ipairs({"coins","ammo"}) do
        for i,item in ipairs(out[key]) do item.id=key..i; item.taken=false end
    end
    if out.checkpoint then out.checkpoint.active=false end
    for i,e in ipairs(out.enemies) do
        e.hp=e.kind=="icecube" and 2 or 1; e.icy=e.kind=="icecube" or e.kind=="snowball"
        e.min=math.max(0,e.x-120); e.max=math.min(out.width,e.x+e.w+120)
        if e.kind~="bird" then
            for _,p in ipairs(out.platforms) do
                if e.x>=p.x and e.x+e.w<=p.x+p.w and math.abs(e.y+e.h-p.y)<=1 then
                    e.min=p.x; e.max=p.x+p.w; break
                end
            end
        end
        e.vx=e.kind=="bird" and 51 or 40; e.homeY=e.y; e.phase=i
        if e.kind=="monkey" then e.bananasLeft=3; e.bananasThrown=0; e.throwTimer=1; e.bananaCooldown=2.32 end
    end
    return out
end
local function safeFilename(filename)
    return type(filename)=="string" and filename:match("^[%w_-]+%.sidlevel$")~=nil and #filename<=100
end
local function uniqueName(name)
    local stem=name:lower():gsub("[^%w_-]","-"):gsub("-+","-"):sub(1,45)
    if stem=="" then stem="level" end
    local filename=stem..Custom.extension; local n=1
    while love.filesystem.getInfo(Custom.directory.."/"..filename) do n=n+1; filename=stem.."-"..n..Custom.extension end
    return filename
end
function Custom.store(level,filename)
    local data,message=Custom.encode(level)
    if not data then return nil,message end
    if not love.filesystem.createDirectory(Custom.directory) then return nil,"Could not create the levels folder." end
    if filename and not safeFilename(filename) then return nil,"Invalid level filename." end
    filename=filename or uniqueName(level.name)
    local ok,err=love.filesystem.write(Custom.directory.."/"..filename,data)
    if not ok then return nil,"Could not save level: "..tostring(err) end
    return filename
end
function Custom.import(data)
    local level,message=Custom.decode(data)
    if not level then return nil,message end
    local filename,err=Custom.store(level)
    if not filename then return nil,err end
    return filename,level
end
function Custom.load(filename)
    if not safeFilename(filename) then return nil,"Invalid level filename." end
    local path=Custom.directory.."/"..filename
    local info=love.filesystem.getInfo(path)
    if not info or info.type~="file" or info.size>Custom.maxBytes then return nil,"Missing level file or file too large." end
    return Custom.decode(love.filesystem.read(path))
end
function Custom.list()
    local list={}; local errors={}
    if not love.filesystem.getInfo(Custom.directory) then return list,errors end
    for _,filename in ipairs(love.filesystem.getDirectoryItems(Custom.directory)) do
        if filename:lower():sub(-9)==Custom.extension then
            local level,message=Custom.load(filename)
            if level then list[#list+1]={filename=filename,level=level}
            else errors[#errors+1]=filename..": "..message end
        end
    end
    table.sort(list,function(a,b) if a.level.name==b.level.name then return a.filename<b.filename end; return a.level.name<b.level.name end)
    return list,errors
end
return Custom
