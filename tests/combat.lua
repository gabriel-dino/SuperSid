local Game=require("src.game")
local Save=require("src.save")
local Levels=require("src.levels")
local Custom=require("src.custom_levels")
local Editor=require("src.editor")
local Eagles=require("src.eagles")
local Grenades=require("src.grenades")
local Viewport=require("src.viewport")
local function game()
    local s=Save.defaults(); local g=Game.new(s,{play=function() end}); g:start(1)
    g.level.enemies={}; g.level.coins={}; g.level.ammo={}; g.level.hearts={}; g.level.grenades={}
    g.player.x=55; g.player.y=383; g.player.onGround=true
    return g,s
end
return function(test)
test("all campaign trails have upper-route eagles and reachable hearts and grenades",function()
    for i=1,Levels.count do
        local l=Levels.create(i); local count=0
        for _,e in ipairs(l.enemies) do
            if e.kind=="eagle" then
                count=count+1; assert(e.hp==2 and e.y>=100 and e.y<200 and e.x>610)
                assert(e.min<=e.x and e.x+e.w<=e.max)
            end
        end
        assert(count>0 and #l.hearts>0 and #l.grenades>0)
        for _,items in ipairs({l.hearts,l.grenades}) do
            for _,item in ipairs(items) do
                local reachable=false
                for _,p in ipairs(l.platforms) do
                    if p.kind=="ground" and item.x>=p.x and item.x+item.w<=p.x+p.w and item.y+item.h<=p.y and p.y-item.y<=40 then reachable=true end
                end
                assert(reachable)
            end
        end
    end
end)
test("eagles take exactly two hits from every bullet type, including meteor and frost",function()
    for _,special in ipairs({"normal","frost","meteor","spread","pierce"}) do
        local g,s=game(); s.equipped.special=special
        local e=Eagles.new(160,214,140,300,0,0); e.frozen=60
        g.level.enemies={e}
        for hit=1,2 do
            g.player.x=100; g.player.y=200; g.player.vy=0; g.player.fireTimer=0
            g:shoot()
            if special=="spread" then g.shots={g.shots[2]} end
            for _=1,12 do g:update(1/60,{}) end
            assert(e.hp==2-hit,special.." must deal exactly one hit to an eagle")
            assert(g.kills==(hit==2 and 1 or 0) and s.coins==(hit==2 and 10 or 0))
        end
    end
end)
test("eagles warn before diving at the upper route and leave the ground route alone",function()
    local p={x=200,y=180,w=23,h=43}
    local e=Eagles.new(180,130,100,500,90,0); e.attackTimer=0
    Eagles.update(e,.01,0,p); assert(e.state=="windup" and e.windup==.5)
    for _=1,31 do Eagles.update(e,1/60,0,p) end
    assert(e.state=="dive")
    local target=e.targetX; p.x=420; p.y=383
    local deepest=0
    for _=1,73 do Eagles.update(e,1/60,0,p); deepest=math.max(deepest,e.y) end
    assert(e.state=="patrol" and e.targetX==target and deepest>180 and deepest<290)
    e.attackTimer=0
    for _=1,180 do Eagles.update(e,1/60,0,p); assert(e.state=="patrol" and e.y<150) end
    local g=game(); g.player.x=200; g.player.y=180
    e=Eagles.new(180,130,100,500,90,0); e.frozen=1; e.attackTimer=0; g.level.enemies={e}
    local x=e.x; for _=1,30 do g:update(1/60,{}) end
    assert(e.x==x and e.state=="patrol","frozen eagles must pause")
end)
test("hearts heal one point up to the equipped maximum and remain when health is full",function()
    for _,charm in ipairs({"normal","heart"}) do
        local g,s=game(); s.equipped.charm=charm; g:start(1,true); g.level.enemies={}
        g.player.x=55; g.player.y=383; g.player.onGround=true
        local heart={x=55,y=399,w=20,h=18,id="test-heart"}; g.level.hearts={heart}
        local maximum=charm=="heart" and 4 or 3
        g:update(1/60,{}); assert(g.player.health==maximum and not heart.taken)
        g.player.health=maximum-1; g:update(1/60,{})
        assert(g.player.health==maximum and heart.taken and s.collected[heart.id] and s.coins==0)
        g:update(1/60,{}); assert(g.player.health==maximum)
        g.player.health=0; g.dead=true; g:update(1/60,{})
        assert(g.player.health==0,"hearts cannot resurrect a finished death")
    end
end)
test("only one unarmed grenade can be carried and inventory survives saving and retries",function()
    local g,s=game()
    local one={x=55,y=400,w=14,h=18,id="grenade-test-1"}
    local two={x=55,y=400,w=14,h=18,id="grenade-test-2"}
    g.level.grenades={one,two}; g:update(1/60,{})
    assert(s.grenades==1 and one.taken and not two.taken and #g.thrownGrenades==0)
    assert(Save.write(s)); assert(Save.load().grenades==1)
    assert(g:throwGrenade() and s.grenades==0 and #g.thrownGrenades==1)
    assert(not g:throwGrenade() and #g.thrownGrenades==1)
    g:update(1/60,{}); assert(two.taken and s.grenades==1)
    g.player.facing=-1; assert(g:throwGrenade() and g.thrownGrenades[2].vx<0)
    g:start(1,true); assert(s.grenades==0 and #g.thrownGrenades==0)
end)
test("grenade fuse lasts three simulation seconds at 30, 60 and 144 FPS",function()
    for _,fps in ipairs({30,60,144}) do
        local g,s=game(); s.grenades=1; assert(g:throwGrenade())
        for _=1,3*fps-1 do g:update(1/fps,{}) end
        assert(#g.thrownGrenades==1 and #g.explosions==0)
        g:update(1/fps,{})
        assert(#g.thrownGrenades==0 and #g.explosions==1 and g.player.health==3)
        for _=1,fps do g:update(1/fps,{}) end
        assert(#g.explosions==0)
    end
end)
test("grenade splash hits enemy bodies inside a circular radius, scores once and spares Sid",function()
    local g,s=game()
    local enemies={
        {kind="monkey",x=250,y=398,w=26,h=28,hp=1},
        {kind="bird",x=320,y=380,w=28,h=20,hp=1},
        {kind="eagle",x=230,y=315,w=40,h=28,hp=2},
        {kind="icecube",x=260,y=350,w=30,h=30,hp=2},
        {kind="monkey",x=347,y=400,w=26,h=28,hp=1}}
    g.level.enemies=enemies; g.player.x=205; g.player.y=383
    g:explodeGrenade({x=200,y=400,w=12,h=14})
    for i=1,4 do assert(enemies[i].hp==0) end
    assert(enemies[5].hp==1 and g.player.health==3 and g.kills==4 and s.coins==25)
    assert(Grenades.hits(0,0,{x=140,y=0,w=20,h=20}))
    assert(not Grenades.hits(0,0,{x=141,y=0,w=20,h=20}))
    assert(not Grenades.hits(0,0,{x=110,y=110,w=20,h=20}),"square corners must not count as the blast circle")
end)
test("grenades bounce on ground and ledges and collide with solid walls and ceilings",function()
    local level={width=960,platforms={{x=0,y=300,w=600,h=15,kind="ledge"}}}
    local g={x=100,y=280,w=12,h=14,vx=0,vy=300,fuse=3,rotation=0}
    Grenades.update(g,1/30,level); assert(g.y==286 and g.vy<0)
    level.platforms={{x=200,y=200,w=24,h=100,kind="ground"}}
    g={x=180,y=220,w=12,h=14,vx=245,vy=0,fuse=3,rotation=0}
    Grenades.update(g,1/30,level); assert(g.x==188 and g.vx<0)
    level.platforms={{x=0,y=250,w=600,h=24,kind="ground"}}
    g={x=100,y=280,w=12,h=14,vx=0,vy=-300,fuse=3,rotation=0}
    Grenades.update(g,1/30,level); assert(g.y==274 and g.vy>0)
end)
test("editor and level sharing round trip eagles, hearts and grenades with safe bounds",function()
    local e=Editor.new()
    for _,tool in ipairs({"eagle","heart","grenade"}) do e.tool=tool; e:begin(120,tool=="eagle" and 160 or 420); e:finish() end
    assert(#e.level.enemies==1 and #e.level.hearts==1 and #e.level.grenades==1)
    local encoded=assert(Custom.encode(e.level)); assert(encoded:find("SUPER_SID_LEVEL\t3"))
    local decoded=assert(Custom.decode(encoded)); local runtime=assert(Custom.runtime(decoded))
    assert(runtime.enemies[1].kind=="eagle" and runtime.enemies[1].hp==2 and runtime.enemies[1].state=="patrol")
    assert(runtime.hearts[1].id and runtime.grenades[1].id)
    e:undo(); assert(#e.level.grenades==0); e:redo(); assert(#e.level.grenades==1)
    e:begin(120,420,true); e:finish(); assert(#e.level.hearts==0 or #e.level.grenades==0)
    decoded.enemies[1].y=400; assert(not Custom.validate(decoded))
    assert(#Custom.decode(assert(Custom.encode(Custom.new()))).hearts==0)
end)
test("campaign heart and grenade pickup IDs stay collected after retries",function()
    local g=Game.new(Save.defaults(),{play=function() end}); g:start(1)
    g.level.enemies={}
    local heart=g.level.hearts[1]; local grenade=g.level.grenades[1]
    g.player.health=2; g.player.x=heart.x; g.player.y=heart.y; g:update(1/60,{})
    g.player.x=grenade.x; g.player.y=grenade.y; g:update(1/60,{})
    assert(heart.taken and grenade.taken and g.save.grenades==1)
    g:start(1,true)
    assert(g.level.hearts[1].taken and g.level.grenades[1].taken and g.save.grenades==1)
end)
test("viewport uses native pixel density for ordinary, maximized and high-DPI displays",function()
    for _,size in ipairs({{960,540,960,540},{1600,900,1600,900},{1920,1017,1920,1017},{1280,720,2560,1440}}) do
        local w,h,pw,ph=size[1],size[2],size[3],size[4]
        local v=Viewport.fit(w,h,pw,ph)
        assert(math.abs(v.density-math.min(pw/960,ph/540))<.000001)
        local x,y=Viewport.toGame(v.x+377*v.scale,v.y+222*v.scale,w,h)
        assert(math.abs(x-377)<.00001 and math.abs(y-222)<.00001)
        assert(v.x>=0 and v.y>=0)
    end
end)
end
