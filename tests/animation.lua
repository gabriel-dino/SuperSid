local Animation=require("src.sid_animation")
local Game=require("src.game")
local Save=require("src.save")
local Shop=require("src.shop")
local function game()
    local s=Save.defaults(); local g=Game.new(s,{play=function() end}); g:start(1)
    g.level.enemies={}; g.level.coins={}; g.level.ammo={}
    g.player.x=55; g.player.y=383; g.player.onGround=true
    return g,s
end
local function item(id)
    for _,entry in ipairs(Shop.items) do if entry.id==id then return entry end end
    error("Unknown item "..id)
end
return function(test)
test("walk motion follows distance at different frame rates and stops when resting or blocked",function()
    local phase
    for _,fps in ipairs({30,60,144}) do
        local g=game(); local p=g.player
        for _=1,fps/2 do g:update(1/fps,{right=true}) end
        assert(p.walking and p.onGround and p.w==23 and p.h==43)
        assert(math.abs(p.walkPhase-((p.x-55)/Animation.stride*math.pi*2)%(math.pi*2))<.00001)
        if phase then assert(math.abs(p.walkPhase-phase)<.00001) end
        phase=p.walkPhase
        g:update(1/fps,{sit=true}); assert(p.sitting and not p.walking and p.walkPhase==0)
        p.x=0; g:update(1/fps,{left=true}); assert(not p.walking and p.walkPhase==0)
        p.x=55; g:jump(); g:update(1/fps,{right=true}); assert(not p.walking and not p.onGround)
    end
end)
test("walk mesh moves both hands, both feet and head independently with a planted foot",function()
    local rest=Animation.pose(3,false); local a=Animation.pose(math.pi/2,true); local b=Animation.pose(math.pi*1.5,true)
    for _,point in ipairs({{.6,.1},{.9,.65},{.75,.76},{.25,1},{.65,1}}) do
        local u,v=point[1],point[2]
        local x,y=Animation.vertex(u,v,rest,.56)
        assert(math.abs(x-(u-.5)*.56)<.000001 and math.abs(y-(v-1))<.000001)
        local ax,ay=Animation.vertex(u,v,a,.56); local bx,by=Animation.vertex(u,v,b,.56)
        assert(math.abs(ax-bx)+math.abs(ay-by)>.005,"a requested body part is not animated")
    end
    for step=0,32 do
        local pose=Animation.pose(step/32*math.pi*2,true)
        local _,left=Animation.vertex(.25,1,pose,.56); local _,right=Animation.vertex(.65,1,pose,.56)
        assert(left<=0 and right<=0 and math.max(left,right)==0,"one foot must stay on the platform")
    end
end)
test("cloud step allows one extra air jump and replenishes only on landing",function()
    local g,s=game(); s.coins=500; assert(Shop.buy(s,item("doublejump")))
    g:jump(); g:update(1/60,{})
    assert(g.player.vy<0 and g.player.airJumpsUsed==0)
    for _=1,12 do g:update(1/60,{}) end
    g:jump(); g:update(1/60,{})
    assert(g.player.airJumpsUsed==1 and g.player.vy< -470)
    for _=1,4 do g:update(1/60,{}) end
    local vy=g.player.vy
    g:jump(); g:update(1/60,{})
    assert(g.player.airJumpsUsed==1 and g.player.vy>vy,"third jump must not reset upward velocity")
    for _=1,90 do g:update(1/60,{}) end
    assert(g.player.onGround and g.player.airJumpsUsed==0)
    s.equipped.ability=nil; g:jump(); g:update(1/60,{})
    for _=1,12 do g:update(1/60,{}) end
    vy=g.player.vy; g:jump(); g:update(1/60,{})
    assert(g.player.vy>vy and g.player.airJumpsUsed==0)
end)
test("trail runners increase actual movement and can be swapped with spring boots",function()
    local g,s=game(); s.coins=200; assert(Shop.buy(s,item("sprint")))
    local start=g.player.x
    for _=1,30 do g:update(1/60,{right=true}) end
    assert(math.abs(g.player.x-start-120)<.001 and g.player.walking)
    assert(Shop.buy(s,item("boots")) and s.equipped.boots=="boots")
    g:jump(); g:update(1/60,{})
    assert(g.player.vy< -540)
end)
test("lucky coin doubles collectible value and keeps enemy rewards unchanged",function()
    local g,s=game(); s.equipped.charm="lucky"
    g.level.coins={{x=55,y=398,w=12,h=16,id="lucky-coin"}}
    g:update(1/60,{}); assert(s.coins==2 and g.earned==2)
    g:update(1/60,{}); assert(s.coins==2)
    g:defeat({kind="bird",hp=1}); g:defeat({kind="monkey",hp=1})
    assert(s.coins==17 and g.earned==17 and g.kills==2)
    g:start(1,true); assert(g.player.maxHealth==3 and g.player.bananaShield==0)
end)
test("big ammo pouch caps ammo, charges per purchase, and new gear survives saving",function()
    local s=Save.defaults(); s.coins=1000; s.ammo=5
    assert(Shop.buy(s,item("ammo15")) and s.ammo==20 and s.coins==980)
    s.ammo=95; assert(Shop.buy(s,item("ammo15")) and s.ammo==99)
    local before=s.coins; assert(not Shop.buy(s,item("ammo15")) and s.coins==before)
    for _,id in ipairs({"doublejump","sprint","lucky","tophat","flowerhat","ocean","lavender","raincoat","comet"}) do assert(Shop.buy(s,item(id))) end
    assert(Save.write(s)); local restored=Save.load()
    assert(restored.owned.tophat and restored.owned.raincoat and restored.equipped.ability=="doublejump")
    assert(restored.equipped.trail=="comet" and restored.equipped.hat=="flowerhat")
end)
test("comet footsteps are cosmetic, appear only while walking and expire",function()
    local g,s=game(); s.equipped.trail="comet"
    for _=1,18 do g:update(1/60,{right=true}) end
    local stars=0
    for _,p in ipairs(g.particles) do if p.kind=="star" then stars=stars+1 end end
    assert(stars>0 and s.coins==0 and g.player.health==3 and g.kills==0)
    for _=1,60 do g:update(1/60,{sit=true}) end
    assert(#g.particles==0 and not g.player.walking)
end)
end
