local Custom=require("src.custom_levels")
local Deco=require("src.decorations")
local Editor={grid=24,view={x=176,y=128,w=768,h=324,scale=.6}}
Editor.tools={
    {id="ground",label="Terrain",hint="Drag a rectangle of solid terrain."},
    {id="ledge",label="Platform",hint="Drag horizontally for a jump-through platform."},
    {id="monkey",label="Monkey",hint="Click near a platform surface to place a monkey."},
    {id="bird",label="Bird",hint="Click to place a flying bird."},
    {id="icecube",label="Ice cube",hint="Click near a platform surface to place an ice cube."},
    {id="snowball",label="Snowball",hint="Click near a platform surface to place a snowball."},
    {id="coin",label="Coins",hint="Click or paint a trail of coins."},
    {id="ammo",label="Ammo",hint="Click to place an ammo pouch."},
    {id="spawn",label="Sid start",hint="Click near a surface to move Sid's starting point."},
    {id="goal",label="Finish flag",hint="Click near a surface to move the finish flag."},
    {id="checkpoint",label="Checkpoint",hint="Click near a surface to place the checkpoint."},
    {id="erase",label="Eraser",hint="Click an object to remove it. Right-click also erases."},
    {id="decoration",label="Decor",hint="Choose a decoration above the map, then click to place it. Packs are sold in the Shop."}
}
local function snap(n) return math.floor((n+.000001)/24)*24 end
function Editor.new(level,filename,owned)
    local e={level=Custom.copy(level or Custom.new()),filename=filename,tool="ground",camera=0,
        owned=owned or {},undoStack={},redoStack={},dirty=false,message="Build a trail, save it, then share its .sidlevel file."}
    e.level.decorations=e.level.decorations or {}
    e.decoration=Deco.available(e.owned)[1]
    return setmetatable(e,{__index=Editor})
end
function Editor:remember()
    self.undoStack[#self.undoStack+1]=Custom.copy(self.level)
    if #self.undoStack>50 then table.remove(self.undoStack,1) end
    self.redoStack={}; self.dirty=true
end
function Editor:undo()
    if #self.undoStack==0 then return end
    self.redoStack[#self.redoStack+1]=Custom.copy(self.level)
    self.level=table.remove(self.undoStack); self.dirty=true; self.drag=nil
end
function Editor:redo()
    if #self.redoStack==0 then return end
    self.undoStack[#self.undoStack+1]=Custom.copy(self.level)
    self.level=table.remove(self.redoStack); self.dirty=true; self.drag=nil
end
function Editor:scroll(delta)
    self.camera=math.max(0,math.min(math.max(0,self.level.width-Editor.view.w/Editor.view.scale),self.camera+delta))
end
function Editor:world(x,y)
    local v=Editor.view
    if x<v.x or x>=v.x+v.w or y<v.y or y>=v.y+v.h then return end
    return (x-v.x)/v.scale+self.camera,(y-v.y)/v.scale
end
function Editor:surface(x,foot,w)
    local best,dist=foot,49
    for _,p in ipairs(self.level.platforms) do
        if x>=p.x and x+w<=p.x+p.w and math.abs(p.y-foot)<dist then best=p.y; dist=math.abs(p.y-foot) end
    end
    return best
end
function Editor:erase(x,y)
    local function hit(o) return o and x>=o.x-4 and x<=o.x+(o.w or 23)+4 and y>=o.y-4 and y<=o.y+(o.h or 43)+4 end
    if hit(self.level.checkpoint) then self.level.checkpoint=nil; return true end
    -- Start and finish are moved with their tools rather than removed.
    for _,key in ipairs({"decorations","enemies","ammo","coins","platforms"}) do
        local items=self.level[key]
        for i=#items,1,-1 do if hit(items[i]) then table.remove(items,i); return true end end
    end
    return false
end
function Editor:place(tool,x,y)
    local l=self.level
    local gx=snap(x); local gy=snap(y)
    if tool=="decoration" then
        local pack=Deco.packFor(self.decoration)
        if not pack or not self.owned["deco_"..pack.id] then
            self.message="Buy a decoration pack in the Shop, then use the Decor selector above the map."; return false
        end
        if #l.platforms+#l.coins+#l.ammo+#l.enemies+#l.decorations>=Custom.maxObjects then self.message="The level already has 2000 objects."; return false end
        local size=Deco.sizes[self.decoration]; gx=math.min(gx,l.width-size[1])
        l.decorations[#l.decorations+1]={kind=self.decoration,x=gx,
            y=math.max(0,math.min(540-size[2],self:surface(gx,gy,size[1])-size[2])),w=size[1],h=size[2]}
        return true
    end
    if tool=="spawn" or tool=="goal" or tool=="checkpoint" then
        local w=tool=="spawn" and 23 or tool=="goal" and 42 or 18
        local h=tool=="spawn" and 43 or tool=="goal" and 92 or 60
        gx=math.min(gx,l.width-w)
        local foot=self:surface(gx,gy,w)
        l[tool]={x=gx,y=math.max(0,math.min(540-h,foot-h)),w=w,h=h}
        return true
    end
    local sizes={monkey={26,28},bird={28,20},icecube={30,30},snowball={24,24},coin={12,16},ammo={18,22}}
    local size=sizes[tool]
    if not size then return false end
    local key=tool=="coin" and "coins" or tool=="ammo" and "ammo" or "enemies"
    local px=math.min(gx+(tool=="coin" and 6 or 0),l.width-size[1])
    local py=tool=="coin" and gy+4 or tool=="bird" and gy or self:surface(px,gy,size[1])-size[2]
    py=math.max(0,math.min(540-size[2],py))
    for _,item in ipairs(l[key]) do if item.x==px and item.y==py and item.kind==(key=="enemies" and tool or nil) then return false end end
    local count=#l.platforms+#l.coins+#l.ammo+#l.enemies+#l.decorations
    if count>=Custom.maxObjects then self.message="The level already has 2000 objects."; return false end
    l[key][#l[key]+1]={x=px,y=py,w=size[1],h=size[2],kind=key=="enemies" and tool or nil}
    return true
end
function Editor:begin(x,y,erase)
    self.drag=nil
    local tool=erase and "erase" or self.tool
    self:remember()
    self.drag={tool=tool,x=snap(x),y=snap(y),toX=x,toY=y}
    if tool=="erase" then self:erase(x,y)
    elseif tool~="ground" and tool~="ledge" then self:place(tool,x,y) end
end
function Editor:move(x,y)
    if not self.drag then return end
    self.drag.toX=math.max(0,math.min(self.level.width-1,x)); self.drag.toY=math.max(0,math.min(539,y))
    if self.drag.tool=="coin" then self:place("coin",self.drag.toX,self.drag.toY) end
end
function Editor:rectangle()
    local d=self.drag
    if not d or (d.tool~="ground" and d.tool~="ledge") then return end
    local tx=snap(d.toX); local ty=snap(d.toY)
    local x=math.min(d.x,tx); local y=d.tool=="ledge" and d.y or math.min(d.y,ty)
    return {x=x,y=y,w=math.min(self.level.width-x,math.abs(tx-d.x)+24),
        h=d.tool=="ledge" and 15 or math.min(540-y,math.abs(ty-d.y)+24),kind=d.tool}
end
function Editor:finish()
    local r=self:rectangle()
    if r then
        if #self.level.platforms+#self.level.coins+#self.level.ammo+#self.level.enemies+#self.level.decorations<Custom.maxObjects then
            self.level.platforms[#self.level.platforms+1]=r
        else self.message="The level already has 2000 objects." end
    end
    self.drag=nil
end
function Editor:resize(delta)
    local width=math.max(960,math.min(15360,self.level.width+delta))
    if width==self.level.width then return end
    if width<self.level.width then
        for _,key in ipairs({"platforms","coins","ammo","enemies","decorations"}) do
            for _,o in ipairs(self.level[key]) do
                if o.x+o.w>width then self.message="Erase or shorten objects beyond the new edge first."; return end
            end
        end
        for _,key in ipairs({"spawn","goal","checkpoint"}) do
            local o=self.level[key]
            if o and o.x+(o.w or 23)>width then self.message="Move the markers inside the new width first."; return end
        end
    end
    self:remember(); self.level.width=width; self:scroll(0)
end
function Editor:theme()
    self:remember()
    for i,b in ipairs(Custom.biomes) do
        if b==self.level.biome then self.level.biome=Custom.biomes[i%#Custom.biomes+1]; return end
    end
end
function Editor:cycleDecoration()
    local available=Deco.available(self.owned)
    if #available==0 then self.message="Buy Woodland, Crystal or Trail signs packs in the Shop (50 coins each)."; return end
    for i,id in ipairs(available) do
        if id==self.decoration then self.decoration=available[i%#available+1]; self.tool="decoration"; return end
    end
    self.decoration=available[1]; self.tool="decoration"
end
function Editor:save(asCopy)
    self:finish()
    local filename,message=Custom.store(self.level,not asCopy and self.filename or nil)
    if filename then self.filename=filename; self.dirty=false; self.message="Saved: "..filename..". Open folder to share this file."
    else self.message=message end
    return filename
end
return Editor
