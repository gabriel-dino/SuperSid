local Custom=require("src.custom_levels")
local Editor=require("src.editor")
local Game=require("src.game")
local Save=require("src.save")
local audio={play=function() end}
return function(test)
test("custom files round trip all terrain, markers, scenery, pickups and enemy kinds",function()
    local l=Custom.new(); l.name="Pădurea lui Sid"; l.author="Creator"; l.biome="forest"
    l.platforms[#l.platforms+1]={x=240,y=336,w=240,h=15,kind="ledge"}
    l.coins={{x=260,y=300,w=12,h=16}}; l.ammo={{x=560,y=410,w=18,h=22}}
    l.checkpoint={x=1440,y=372,w=18,h=60}
    for i,kind in ipairs({"monkey","bird","icecube","snowball"}) do
        local sizes={{26,28},{28,20},{30,30},{24,24}}
        l.enemies[i]={kind=kind,x=600+i*96,y=432-sizes[i][2],w=sizes[i][1],h=sizes[i][2]}
    end
    local encoded=assert(Custom.encode(l)); local decoded=assert(Custom.decode(encoded:gsub("\n","\r\n")))
    assert(Custom.encode(decoded)==encoded and decoded.name==l.name)
    local runtime=assert(Custom.runtime(decoded))
    assert(runtime.custom and runtime.index==0 and #runtime.enemies==4)
    assert(runtime.enemies[1].bananasLeft==3 and runtime.enemies[3].hp==2 and runtime.enemies[4].icy)
    assert(runtime.enemies[1].min==0 and runtime.enemies[1].max==2880)
    runtime.enemies[1].hp=0; runtime.coins[1].taken=true
    assert(decoded.enemies[1].hp==nil and not decoded.coins[1].taken,"play must not mutate the editor data")
end)
test("shared level parsing rejects executable, malformed, oversized and unsupported data",function()
    local good=assert(Custom.encode(Custom.new()))
    for _,data in ipairs({"return os.execute('bad')",good.."lua\tos.execute('bad')\n",
        good.."width\t3000\n",good:gsub("width\t2880","width\tinf"),
        good:gsub("spawn\t48\t389\n",""),good:gsub("ground\t0","ground\t-1"),
        good:gsub("My little adventure",string.char(255)),string.rep("x",Custom.maxBytes+1),
        good.."monkey\t600\t100\n"}) do
        local value,message=Custom.decode(data)
        assert(not value and type(message)=="string")
    end
    local l=Custom.new(); l.spawn=7; assert(not Custom.validate(l))
    l=Custom.new(); l.spawn.y=440; assert(not Custom.validate(l))
    l=Custom.new(); l.goal.y=0; assert(not Custom.validate(l))
    l=Custom.new()
    for i=1,Custom.maxObjects do l.coins[i]={x=100,y=300,w=12,h=16} end
    assert(not Custom.validate(l))
end)
test("custom library saves, imports without overwriting, skips bad files and blocks path traversal",function()
    local previous=Custom.directory; Custom.directory="test-levels"
    local l=Custom.new(); l.name="Shared level"
    local filename=assert(Custom.store(l))
    assert(filename=="shared-level.sidlevel")
    assert(Custom.load(filename).name==l.name)
    local imported=assert(Custom.import(assert(Custom.encode(l))))
    assert(imported~=filename)
    assert(not Custom.store(l,"../progress.lua") and not Custom.load("../progress.lua"))
    love.filesystem.write(Custom.directory.."/broken.sidlevel","not a level")
    local entries,errors=Custom.list(); assert(#entries==2 and #errors==1)
    assert(not Custom.import("broken") and #Custom.list()==2)
    Custom.directory=previous
end)
test("editor draws snapped rectangles, paints once per cell, and undoes or redoes whole strokes",function()
    local e=Editor.new(); e.tool="ground"
    e:begin(490,200); e:move(400,250); e:finish()
    local p=e.level.platforms[2]
    assert(p.x==384 and p.y==192 and p.w==120 and p.h==72)
    e.tool="ledge"; e:begin(260,300); e:move(385,380); e:finish()
    p=e.level.platforms[3]; assert(p.x==240 and p.y==288 and p.w==168 and p.h==15)
    e.tool="coin"; e:begin(100,300); e:move(101,301); e:move(125,300); e:finish()
    assert(#e.level.coins==2)
    e:undo(); assert(#e.level.coins==0 and #e.level.platforms==3)
    e:redo(); assert(#e.level.coins==2)
    e:begin(220,200); e:finish(); assert(#e.redoStack==0)
end)
test("editor snaps walking enemies and markers to real platforms and erases objects before terrain",function()
    local e=Editor.new()
    for _,tool in ipairs({"monkey","icecube","snowball","ammo","spawn","goal","checkpoint"}) do
        e.tool=tool; e:begin(96,415); e:finish()
    end
    assert(e.level.enemies[1].y+28==432 and e.level.enemies[2].y+30==432)
    assert(e.level.spawn.y+43==432 and e.level.goal.y+92==432 and e.level.checkpoint.y+60==432)
    assert(Custom.validate(e.level))
    e:begin(100,410,true); e:finish(); assert(not e.level.checkpoint)
    e:begin(100,410,true); e:finish(); assert(#e.level.enemies==2 and #e.level.platforms==1)
    e:undo(); assert(#e.level.enemies==3)
end)
test("editor respects canvas coordinates, width bounds and failed saves",function()
    local e=Editor.new()
    assert(not e:world(100,200))
    local x,y=e:world(176+60,128+120); assert(x==100 and y==200)
    e:scroll(100000); assert(e.camera==1600)
    e:resize(-480); assert(e.level.width==2880,"shrinking must not clip existing terrain")
    e:resize(480); assert(e.level.width==3360 and e.dirty)
    local before=love.filesystem.write
    love.filesystem.write=function() return false,"disk full" end
    assert(not e:save() and not e.filename and e.dirty)
    love.filesystem.write=before
    assert(e:save() and not e.dirty and e.filename)
end)
test("custom play uses placed spawn, rewards and checkpoints while preserving the campaign",function()
    local s=Save.defaults(); s.level=4; s.unlocked=7; s.coins=123; s.ammo=12; s.checkpoint=true
    s.collected={coin1=true}; s.best[4]=18; s.owned.beanie=true; s.equipped.hat="beanie"
    local l=Custom.new()
    l.coins={{x=48,y=410,w=12,h=16}}
    l.checkpoint={x=48,y=372,w=18,h=60}
    l.enemies={{kind="monkey",x=160,y=404,w=26,h=28}}
    local g=Game.new(s,audio); assert(g:startCustom(l))
    assert(g.player.x==48 and g.player.y==389 and g.save~=s and g.player.facing==1)
    g:update(1/60,{}); assert(g.save.coins==124 and g.save.checkpoint and g.level.coins[1].taken)
    g.player.x=160; g.player.y=359; g.player.vy=200; g.level.enemies[1].frozen=1
    g:update(1/60,{}); assert(g.kills==1 and g.save.coins==129)
    assert(g:startCustom(l,true))
    assert(g.level.coins[1].taken and g.level.checkpoint.active and g.save.coins==129)
    g.player.x=l.goal.x; g.player.y=l.goal.y; g:update(1/60,{})
    assert(g.finished)
    assert(s.level==4 and s.unlocked==7 and s.coins==123 and s.ammo==12 and s.checkpoint)
    assert(s.collected.coin1 and s.best[4]==18 and s.equipped.hat=="beanie" and not s.completed)
    g:start(4,true); assert(not g.custom and g.save==s and g.level.index==4)
end)
test("solid terrain blocks upward jumps while one-way platforms remain jump-through",function()
    for _,kind in ipairs({"ground","ledge"}) do
        local g=Game.new(Save.defaults(),audio); g:start(1)
        g.level.enemies={}; g.level.coins={}
        g.level.platforms={{x=0,y=300,w=600,h=24,kind=kind}}
        g.player.y=330; g.player.vy=-530
        g:update(1/30,{})
        if kind=="ground" then assert(g.player.y==324 and g.player.vy==0)
        else assert(g.player.y<324 and g.player.vy<0) end
    end
end)
end
