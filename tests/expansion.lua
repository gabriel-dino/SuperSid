local Save=require("src.save")
local Shop=require("src.shop")
local Game=require("src.game")
local Custom=require("src.custom_levels")
local Editor=require("src.editor")
local Deco=require("src.decorations")
local Levels=require("src.levels")
local audio={play=function() end}
local function game()
    local s=Save.defaults(); local g=Game.new(s,audio); g:start(1)
    g.level.enemies={}; g.level.coins={}; g.level.ammo={}
    return g,s
end
return function(test)
test("coin magnet attracts nearby coins, expires, and never refills by toggling gear",function()
    local g,s=game(); s.equipped.magnet="magnet"
    g.player.x=100; g.player.y=383
    local coin={x=180,y=395,w=12,h=16,id="magnet-coin"}
    local far={x=500,y=395,w=12,h=16,id="far-coin"}
    g.level.coins={coin,far}
    for _=1,30 do g:update(1/60,{}) end
    assert(coin.taken and s.coins==1 and g.earned==1 and far.x==500)
    assert(g.player.magnetTime<30)
    local remaining=g.player.magnetTime
    s.equipped.magnet=nil; g:update(1/60,{}); assert(g.player.magnetTime==remaining)
    s.equipped.magnet="magnet"; g.player.magnetTime=.001; g:update(1/60,{})
    assert(g.player.magnetTime==0)
    g.level.coins={{x=180,y=395,w=12,h=16,id="expired"}}
    for _=1,30 do g:update(1/60,{}) end
    assert(g.level.coins[1].x==180 and s.coins==1)
    g:start(1,true); assert(g.player.magnetTime==30)
end)
test("leaf parachute requires equipment and held jump, slows descent, and closes on landing",function()
    for _,fps in ipairs({30,60,144}) do
        local g,s=game()
        g.player.y=170; g.player.vy=300
        g:update(1/fps,{glide=true}); assert(not g.player.gliding and g.player.vy>300)
        s.equipped.parachute="parachute"
        g:update(1/fps,{glide=true}); assert(g.player.gliding and g.player.vy<=95)
        local y=g.player.y
        for _=1,fps do g:update(1/fps,{glide=true}) end
        assert(g.player.y-y<=96 and g.player.gliding)
        g:update(1/fps,{}); assert(not g.player.gliding and g.player.vy>95)
        g.player.y=200; g.player.vy=-300
        g:update(1/fps,{glide=true}); assert(not g.player.gliding and g.player.vy<0)
        g.player.x=55; g.player.y=426-g.player.h-1; g.player.vy=100; g.player.onGround=false
        for _=1,4 do g:update(1/fps,{glide=true}) end
        assert(g.player.onGround and not g.player.gliding)
    end
end)
test("companion follows Sid in both directions without affecting health, coins or combat",function()
    local g,s=game(); s.equipped.companion="chick"
    local start=g.companion.x
    for _=1,60 do g:update(1/60,{right=true}) end
    assert(g.companion.x>start and g.companion.x<g.player.x and g.player.health==3 and s.coins==0 and g.kills==0)
    for _=1,30 do g:update(1/60,{left=true}) end
    assert(g.companion.x>g.player.x and g.player.facing==-1)
    local x=g.companion.x; s.equipped.companion=nil; g:update(1/60,{})
    assert(g.companion.x==x)
end)
test("decoration packs charge once, persist, and unlock all nine editor objects",function()
    local s=Save.defaults(); s.coins=500
    local e=Editor.new(nil,nil,s.owned)
    assert(not e:place("decoration",100,432) and #e.level.decorations==0)
    local total=0
    for _,item in ipairs(Shop.items) do
        if item.kind=="decoration" then
            assert(Shop.buy(s,item)); total=total+item.cost
            local balance=s.coins; assert(Shop.buy(s,item) and s.coins==balance)
        end
    end
    assert(s.coins==500-total and total==150 and #Deco.available(s.owned)==9)
    assert(Save.write(s)); local restored=Save.load(); assert(#Deco.available(restored.owned)==9)
    for i,id in ipairs(Deco.available(s.owned)) do
        e.decoration=id; assert(e:place("decoration",i*96,432))
    end
    assert(#e.level.decorations==9 and Custom.validate(e.level))
    e.tool="decoration"; e:begin(1100,432); e:finish(); assert(#e.level.decorations==10)
    e:undo(); assert(#e.level.decorations==9); e:redo(); assert(#e.level.decorations==10)
    local d=e.level.decorations[1]; e:begin(d.x+3,d.y+3,true); e:finish(); assert(#e.level.decorations==9)
end)
test("decorations survive sharing and play without a pack and have no collision",function()
    local l=Custom.new()
    l.decorations={{kind="crystal",x=48,y=384,w=32,h=48}}
    local encoded=assert(Custom.encode(l)); assert(encoded:find("SUPER_SID_LEVEL\t2"))
    local decoded=assert(Custom.decode(encoded)); assert(decoded.decorations[1].kind=="crystal")
    local s=Save.defaults(); local g=Game.new(s,audio); assert(g:startCustom(decoded))
    assert(#g.level.decorations==1 and not next(s.owned))
    for _=1,30 do g:update(1/60,{right=true}) end
    assert(g.player.x>100 and g.player.health==3 and decoded.decorations[1].x==48)
    assert(not Custom.decode(encoded:gsub("decoration\tcrystal","decoration\tunknown")))
    local legacy=Custom.encode(Custom.new()); assert(Custom.decode(legacy).decorations)
end)
test("fifteen-level champions resume at sixteen and current champions stay complete",function()
    love.filesystem.write("progress.lua","return {version=2,coins=234,ammo=12,level=15,unlocked=15,completed=true,checkpoint=true,collected={coin1=true},owned={boots=true},equipped={boots='boots'}}")
    local s=Save.load()
    assert(s.version==3 and s.level==16 and s.unlocked==16 and not s.completed and not s.checkpoint and not next(s.collected))
    assert(s.coins==234 and s.ammo==12 and s.owned.boots and s.equipped.boots=="boots")
    s.level=25; s.unlocked=25; s.completed=true; assert(Save.write(s))
    s=Save.load(); assert(s.level==25 and s.completed and s.coins==234)
    love.filesystem.write("progress.lua","return {version=2,coins=12,ammo=5,level=8,unlocked=9,completed=false,checkpoint=true,collected={coin1=true}}")
    s=Save.load(); assert(s.level==8 and s.unlocked==9 and s.checkpoint and s.collected.coin1)
end)
test("ten new trails have scenery identities, safe geometry and optional decoration themes",function()
    local previous=Levels.create(15)
    for i=16,25 do
        local l=Levels.create(i)
        assert(l.width>previous.width and l.difficulty.speed>previous.difficulty.speed and l.difficulty.gap<=118)
        local themed=false
        for _,d in ipairs(l.decorations) do if d.kind then assert(Deco.sizes[d.kind]); themed=true end end
        assert(themed)
        for _,p in ipairs(l.platforms) do assert(p.w>=100 and p.x>=0 and p.x+p.w<=l.width) end
        previous=l
    end
end)
end
