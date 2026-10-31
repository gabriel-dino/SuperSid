-- Pure Lua integration tests. Run from the project root: lua tests/run.lua
package.path="./?.lua;./?/init.lua;"..package.path
local files={}
love={filesystem={
    read=function(path) return files[path] end,
    write=function(path,value) files[path]=value; return true end,
    createDirectory=function() return true end,
    getInfo=function(path)
        if files[path] then return {type="file",size=#files[path]} end
        for name in pairs(files) do if name:sub(1,#path+1)==path.."/" then return {type="directory"} end end
    end,
    getDirectoryItems=function(path)
        local names={}
        for name in pairs(files) do
            if name:sub(1,#path+1)==path.."/" then names[#names+1]=name:sub(#path+2) end
        end
        return names
    end
}}
local Save=require("src.save")
local Shop=require("src.shop")
local Levels=require("src.levels")
local Game=require("src.game")
local Actors=require("src.actors")
local audio={play=function() end}
local passed=0
local function test(name,fn)
    local ok,message=pcall(fn)
    if not ok then io.stderr:write("FAIL "..name..": "..tostring(message).."\n"); os.exit(1) end
    passed=passed+1; print("PASS "..name)
end
local function newGame(level)
    local s=Save.defaults(); local g=Game.new(s,audio); g:start(level or 1); return g,s
end
test("twenty-five levels have distinct identities and valid placements",function()
    local names={}
    assert(Levels.count==25)
    for i=1,Levels.count do
        local l=Levels.create(i)
        assert(not names[l.name]); names[l.name]=true
        assert(#l.coins>20 and #l.ammo>2 and #l.enemies>2)
        assert(l.goal.x>l.checkpoint.x and l.checkpoint.x>500)
        for _,c in ipairs(l.coins) do assert(c.x>=0 and c.x<l.width) end
        local previous
        for _,p in ipairs(l.platforms) do
            if p.kind=="ground" then
                if previous then assert(p.x-previous.x-previous.w<=118) end
                previous=p
            end
        end
        assert(previous.x+previous.w==l.width)
    end
end)
test("all twenty-five trails are traversable without purchased gear",function()
    for index=1,Levels.count do
        for _,fps in ipairs({30,60,144}) do
            local g,s=newGame(index)
            g.level.enemies={}
            for frame=1,math.ceil(60*fps) do
                local p=g.player
                if p.onGround then
                    for _,ground in ipairs(g.level.platforms) do
                        if ground.kind=="ground" and math.abs(p.y+p.h-ground.y)<2 and
                            p.x+p.w>ground.x and p.x<ground.x+ground.w and
                            ground.x+ground.w<g.level.width and ground.x+ground.w-(p.x+p.w)<30 then g:jump() end
                    end
                end
                g:update(1/fps,{right=true})
                assert(not g.dead,"fell in level "..index.." at "..fps.." fps, x="..p.x)
                if g.finished then break end
            end
            assert(g.finished,"could not finish level "..index.." at "..fps.." fps")
            assert(s.unlocked>=math.min(Levels.count,index+1))
            if index==Levels.count then assert(s.completed)
            else assert(not s.completed and s.level==index+1) end
        end
    end
end)
test("five initial shots, cooldowns, empty ammo, and ammo collection",function()
    local g,s=newGame()
    for i=1,5 do g.player.fireTimer=0; g:shoot() end
    assert(s.ammo==0 and #g.shots==5)
    g.player.fireTimer=0; g:shoot(); assert(#g.shots==5)
    local a=g.level.ammo[1]
    g.player.x=a.x; g.player.y=a.y-10
    g:update(1/60,{})
    assert(a.taken and s.ammo==5)
    g.player.fireTimer=0; g:shoot(); g:shoot(); assert(s.ammo==4)
end)
test("coins, checkpoint, and pickups survive a retry without farming",function()
    local g,s=newGame()
    local c=g.level.coins[1]
    g.player.x=c.x; g.player.y=c.y; g:update(1/60,{})
    assert(s.coins==1)
    local cp=g.level.checkpoint
    g.player.x=cp.x; g.player.y=cp.y; g:update(1/60,{})
    assert(s.checkpoint)
    g:start(1,true)
    assert(g.level.coins[1].taken and s.coins==1)
    assert(math.abs(g.player.x-cp.x)<1)
end)
test("fireballs hit monkeys; frost freezes and a second hit defeats",function()
    for _,special in ipairs({"normal","frost"}) do
        local g,s=newGame(); s.equipped.special=special
        local e={kind="monkey",x=140,y=382,w=26,h=28,min=140,max=200,vx=0,hp=1,homeY=382}
        g.level.enemies={e}; g.player.x=100; g.player.y=383
        g:shoot()
        for i=1,12 do g:update(1/60,{}) end
        if special=="frost" then
            assert(e.hp==1 and e.frozen>0)
            g.player.fireTimer=0; g:shoot()
            for i=1,12 do g:update(1/60,{}) end
        end
        assert(e.hp==0)
    end
end)
test("stomping defeats enemies; contact damage respects immunity",function()
    local g=newGame()
    local e={kind="monkey",x=160,y=398,w=26,h=28,min=160,max=190,vx=0,hp=1,homeY=398}
    g.level.enemies={e}; g.player.x=160; g.player.y=353; g.player.vy=200
    g:update(1/60,{})
    assert(e.hp==0 and g.player.vy<0 and g.player.health==3)
    e.hp=1; g.player.y=383; g.player.vy=0
    g:update(1/60,{}); assert(g.player.health==2)
    g:update(1/60,{}); assert(g.player.health==2)
end)
test("enemy kills award bird and monkey coins exactly once for stomps and every fire type",function()
    for _,kind in ipairs({"bird","monkey","icecube","snowball"}) do
        local reward=kind=="bird" and 10 or kind=="monkey" and 5 or 0
        for _,method in ipairs({"stomp","normal","frost","spread","meteor","pierce"}) do
            local g,s=newGame()
            s.coins=20; s.equipped.special=method
            g.level.coins={}; g.level.ammo={}
            local e={kind=kind,x=160,y=398,w=26,h=28,min=150,max=200,vx=0,hp=1,
                homeY=398,phase=0,frozen=60}
            g.level.enemies={e}
            if method=="stomp" then
                g.player.x=160; g.player.y=353; g.player.vy=200
                g:update(1/60,{})
            else
                g.player.x=100; g.player.y=383
                g:shoot()
                for _=1,12 do g:update(1/60,{}) end
                if method=="frost" then
                    assert(e.hp==1 and s.coins==20 and g.earned==0 and g.kills==0,
                        "freezing an enemy must not award a kill bonus")
                    g.player.fireTimer=0; g:shoot()
                    for _=1,12 do g:update(1/60,{}) end
                end
            end
            assert(e.hp==0 and g.kills==1,kind.." must be defeated by "..method)
            assert(s.coins==20+reward and g.earned==reward,kind.." has an incorrect reward for "..method)
            g.player.x=100; g.player.y=383; g.player.fireTimer=0
            g:shoot()
            for _=1,30 do g:update(1/60,{}) end
            assert(s.coins==20+reward and g.earned==reward and g.kills==1,
                "a defeated enemy must not award coins again")
            assert(Save.write(s))
            assert(Save.load().coins==20+reward,"kill rewards must persist in saved coins")
        end
    end
end)

test("shop enforces balances, ownership, equipment, and consumables",function()
    local s=Save.defaults()
    local ok=Shop.buy(s,Shop.items[2]); assert(not ok and s.coins==0)
    s.coins=2000
    for _,item in ipairs(Shop.items) do
        local before=s.coins
        assert(Shop.buy(s,item)); assert(s.coins==before-item.cost)
        if item.kind=="decoration" then
            assert(s.owned[item.id] and Shop.equipped(s,item))
            local coins=s.coins
            Shop.buy(s,item); assert(s.owned[item.id] and s.coins==coins)
        elseif item.kind~="ammo" then
            assert(s.owned[item.id] and Shop.equipped(s,item))
            local coins=s.coins
            Shop.buy(s,item); assert(s.equipped[item.kind]==nil and s.coins==coins)
            Shop.buy(s,item); assert(Shop.equipped(s,item) and s.coins==coins)
        end
    end
    s.ammo=99; local before=s.coins
    assert(not Shop.buy(s,Shop.items[1])); assert(s.coins==before)
end)
test("special bullets and different gun speeds change combat",function()
    local g,s=newGame(); s.equipped.special="spread"; s.equipped.gun="turbo"
    g:shoot(); assert(#g.shots==3 and s.ammo==4 and g.player.fireTimer==.16)
    g.player.fireTimer=0; s.equipped.gun="quick"; g:shoot(); assert(g.player.fireTimer==.3)
end)
test("movement works both ways and world boundaries hold",function()
    local g=newGame()
    for i=1,30 do g:update(1/60,{left=true}) end
    assert(g.player.x==0 and g.player.facing==-1)
    for i=1,30 do g:update(1/60,{right=true}) end
    assert(g.player.x>90 and g.player.facing==1)
end)
test("save round trip, validation, and damaged-save recovery",function()
    local s=Save.defaults(); s.coins=87; s.owned.witch=true; s.equipped.hat="witch"; s.level=4; s.unlocked=4
    assert(Save.write(s)); local restored=Save.load()
    assert(restored.coins==87 and restored.owned.witch and restored.equipped.hat=="witch" and restored.level==4)
    s.coins=91; Save.write(s)
    files["progress.lua"]="invalid save file"
    assert(Save.load().coins==87)
    files["progress.bak"]=nil
    assert(Save.load().coins==0)
    files["progress.lua"]="return {version=2,coins=-2,ammo=500,level=88,unlocked=99}"
    restored=Save.load(); assert(restored.coins==0 and restored.ammo==99 and restored.level==Levels.count)
end)
test("every island has two raised tiers with rewards and safe step spacing",function()
    for index=1,Levels.count do
        local level=Levels.create(index)
        for _,ground in ipairs(level.platforms) do
            if ground.kind=="ground" then
                local tiers={}
                for _,tile in ipairs(level.platforms) do
                    if tile.kind=="ledge" and tile.x>=ground.x and tile.x+tile.w<=ground.x+ground.w then
                        assert(tile.y>=150 and tile.y<ground.y)
                        assert(tile.stepFrom and tile.stepFrom.y-tile.y<=96)
                        tiers[tile.tier]=true
                        local rewarded=false
                        for _,coin in ipairs(level.coins) do
                            if coin.x>=tile.x and coin.x+coin.w<=tile.x+tile.w and coin.y==tile.y-30 then rewarded=true end
                        end
                        assert(rewarded,"raised platform must have coins")
                    end
                end
                assert(tiers[1] and tiers[2],"missing stacked platforms in trail "..index)
            end
        end
    end
end)

test("Sid climbs every tier from its real preceding step and sits without drifting",function()
    for index=1,Levels.count do
        for _,fps in ipairs({30,60,144}) do
            local g=newGame(index); g.level.enemies={}
            g.level.goal={x=g.level.width+100,y=0,w=1,h=1}
            for _,tile in ipairs(g.level.platforms) do
                if tile.kind=="ledge" then
                    local p=g.player
                    local source=tile.stepFrom
                    local targetX=tile.x+(tile.w-p.w)/2
                    p.x=math.max(source.x+12,math.min(source.x+source.w-p.w-12,targetX))
                    p.y=source.y-p.h; p.vy=0; p.onGround=true
                    g:update(1/fps,{})
                    assert(p.platform==source,"climb must start on a real supporting platform")
                    g:jump()
                    local reached=false
                    for _=1,fps do
                        local dx=targetX-p.x
                        g:update(1/fps,{left=dx< -195/fps,right=dx>195/fps})
                        if p.platform==tile then reached=true; break end
                    end
                    assert(reached,"cannot reach ledge in trail "..index.." at "..fps.." FPS, x="..tile.x..", y="..tile.y)
                    local x,y=p.x,p.y
                    for _=1,fps do g:update(1/fps,{sit=true}) end
                    assert(p.sitting and p.onGround and p.x==x and p.y==y)
                    g:update(1/fps,{})
                    assert(not p.sitting and p.onGround and p.y==y)
                end
            end
        end
    end
end)
test("landing chooses the first crossed platform regardless of list order",function()
    local g=newGame(); g.level.enemies={}
    local upper={x=0,y=200,w=300,h=15,kind="ledge"}
    g.level.platforms={{x=0,y=215,w=300,h=300,kind="ground"},upper}
    g.player.y=150; g.player.vy=700
    g:update(1/30,{})
    assert(g.player.platform==upper and g.player.y+g.player.h==200)
end)
test("Sid and enemies turn with velocity and retain facing while idle",function()
    assert(Actors.facing(2)==1 and Actors.facing(-2)==-1)
    assert(Actors.facing(0,-1)==-1 and Actors.facing(0,1)==1)
    local g=newGame()
    for _,kind in ipairs({"monkey","bird","icecube","snowball"}) do
        local e={kind=kind,x=199,y=398,w=24,h=24,min=150,max=225,vx=80,hp=1,homeY=398,phase=0}
        g.level.enemies={e}
        g:update(1/30,{left=true})
        assert(e.vx<0 and e.facing==-1 and g.player.facing==-1,kind.." must turn left at the edge")
        e.x=e.min; e.vx=-80
        g:update(1/30,{right=true})
        assert(e.vx>0 and e.facing==1 and g.player.facing==1,kind.." must turn right at the edge")
    end
    g:update(1/60,{})
    assert(g.player.facing==1)
    g:update(1/60,{left=true}); g:update(1/60,{})
    assert(g.player.facing==-1)
end)
test("each monkey throws at most three bananas, including offscreen and freeze pauses",function()
    local g=newGame(15)
    local e={kind="monkey",x=120,y=398,w=26,h=28,min=110,max=500,vx=0,facing=1,hp=1,homeY=398,
        bananasLeft=3,bananasThrown=0,throwTimer=0,bananaCooldown=.2}
    g.level.enemies={e}; g.player.x=290; g.player.y=383; g.player.invincible=50
    e.frozen=1
    for _=1,30 do g:update(1/60,{}) end
    assert(e.bananasThrown==0,"frozen monkey must not throw")
    for _=1,600 do g:update(1/60,{}) end
    assert(e.bananasThrown==3 and e.bananasLeft==0)
    local count=#g.enemyShots
    g:throwBanana(e)
    assert(e.bananasThrown==3 and #g.enemyShots==count)
    for _=1,600 do g:update(1/60,{}) end
    assert(e.bananasThrown==3,"waiting must never refill banana ammunition")
end)
test("bananas hurt Sid, can be blocked, and can be destroyed by fire",function()
    local function banana(g,x,y)
        g.enemyShots={{x=x,y=y,w=12,h=9,vx=0,vy=0,life=2,rotation=0}}
    end
    local g=newGame(); g.level.enemies={}; g.player.y=383
    banana(g,g.player.x,g.player.y); g:update(1/60,{})
    assert(g.player.health==2 and #g.enemyShots==0)
    g.player.invincible=0; g.player.bananaShield=1
    banana(g,g.player.x,g.player.y); g:update(1/60,{})
    assert(g.player.health==2 and g.player.bananaShield==0)
    g.shots={{x=220,y=300,w=10,h=10,vx=0,vy=0,life=1,hit={},remainingHits=1,damage=1}}
    banana(g,220,300); g:update(1/60,{})
    assert(#g.enemyShots==0)
    banana(g,220,425); g:update(1/60,{})
    assert(#g.enemyShots==0,"terrain must stop bananas")
end)
test("new trails progressively increase gaps, speed, and enemy pressure",function()
    local previous=Levels.create(10)
    for i=11,15 do
        local l=Levels.create(i)
        assert(l.width>previous.width and l.difficulty.gap>previous.difficulty.gap)
        assert(l.difficulty.speed>previous.difficulty.speed)
        assert(l.difficulty.groundShrink>previous.difficulty.groundShrink)
        assert(l.difficulty.bananaCooldown<previous.difficulty.bananaCooldown)
        local kinds={}
        for _,e in ipairs(l.enemies) do kinds[e.kind]=(kinds[e.kind] or 0)+1 end
        assert(kinds.icecube and (i==11 or kinds.snowball))
        assert(#l.enemies>#previous.enemies,"later expansion trail must have more enemies")
        previous=l
    end
end)
test("ice enemies take damage, resist frost, and meteor melts cubes",function()
    for _,special in ipairs({"normal","frost","meteor"}) do
        local g,s=newGame(); s.equipped.special=special
        local e={kind="icecube",x=150,y=396,w=30,h=30,min=150,max=200,vx=0,hp=2,homeY=396,icy=true}
        g.level.enemies={e}; g.player.x=100; g.player.y=383
        g:shoot(); for _=1,15 do g:update(1/60,{}) end
        assert(e.hp==(special=="meteor" and 0 or 1))
        assert((e.frozen or 0)==0)
        if e.hp>0 then
            g.player.fireTimer=0; g:shoot()
            for _=1,15 do g:update(1/60,{}) end
            assert(e.hp==0)
        end
    end
    local g=newGame(12)
    local snow
    for _,e in ipairs(g.level.enemies) do if e.kind=="snowball" then snow=e; break end end
    assert(snow)
    g:update(1/60,{})
    assert(snow.y<=snow.homeY and snow.y>=snow.homeY-17)
end)
test("new gear, health charm, shield charge, and piercing fire have real effects",function()
    local g,s=newGame()
    s.equipped.charm="heart"; g:start(1,true)
    assert(g.player.health==4 and g.player.maxHealth==4)
    s.equipped.charm="shield"; g:start(1,true)
    assert(g.player.health==3 and g.player.bananaShield==1)
    g.player.onGround=true; g.player.y=383; g:jump(); g:update(1/60,{})
    local normal=g.player.vy
    s.equipped.boots="boots"; g:start(1,true); g.player.onGround=true; g:jump(); g:update(1/60,{})
    assert(g.player.vy<normal)
    s.equipped.special="pierce"; g:start(1,true); g.player.x=100; g.player.y=383
    g.level.enemies={}
    for i=1,3 do
        g.level.enemies[i]={kind="monkey",x=150+(i-1)*50,y=398,w=26,h=28,min=120,max=400,vx=0,hp=1,homeY=398}
    end
    g:shoot(); for _=1,40 do g:update(1/60,{}) end
    assert(g.level.enemies[1].hp==0 and g.level.enemies[2].hp==0 and g.level.enemies[3].hp==1)
end)
test("legacy champions unlock level eleven without losing coins or purchases",function()
    files["progress.lua"]="return {version=1,coins=123,ammo=9,level=10,unlocked=10,completed=true,checkpoint=true,collected={coin1=true},owned={witch=true},equipped={hat='witch'}}"
    local s=Save.load()
    assert(s.version==3 and s.level==11 and s.unlocked==11 and not s.completed and not s.checkpoint)
    assert(s.coins==123 and s.ammo==9 and s.owned.witch and s.equipped.hat=="witch" and not next(s.collected))
    Save.write(s); s=Save.load(); assert(s.level==11 and s.coins==123)
    files["progress.lua"]="return {version=1,coins=22,ammo=3,level=6,unlocked=6,completed=false,checkpoint=true,collected={coin1=true}}"
    s=Save.load(); assert(s.level==6 and s.checkpoint and s.collected.coin1 and s.coins==22)
end)
test("shop catalog spans three reachable pages with unique items",function()
    assert(#Shop.items==26 and Shop.pageCount()==3)
    assert(Shop.page(1)==1 and Shop.page(12)==1 and Shop.page(13)==2 and Shop.page(20)==2)
    assert(Shop.page(25)==3 and Shop.page(26)==3)
    local ids={}
    for _,item in ipairs(Shop.items) do assert(not ids[item.id]); ids[item.id]=true end
end)
require("tests.editor")(test)
require("tests.expansion")(test)
print("\n"..passed.." integration tests passed.")
