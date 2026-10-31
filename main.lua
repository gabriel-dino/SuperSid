local Save=require("src.save")
local Shop=require("src.shop")
local Levels=require("src.levels")
local Game=require("src.game")
local R=require("src.render")
local Audio=require("src.audio")
local app={state="menu",buttons={},focus=1,time=0,shopSelection=1,shopReturn="menu",touches={}}
local smoke=false
local save,game,canvas
local function persist() if save and not smoke then Save.write(save) end end
local function state(name) app.state=name; app.focus=1; app.buttons={} end
local function start(index,retry)
    game:start(index,retry); state("playing"); persist()
end
local function shop()
    app.shopReturn=app.state; state("shop"); app.message=nil
end
local function buy(index)
    app.shopSelection=index
    local ok,message=Shop.buy(save,Shop.items[index])
    app.message=message; Audio.play(ok and "coin" or "click"); persist()
end
local function changeShopPage(delta)
    local page=math.max(1,math.min(Shop.pageCount(),Shop.page(app.shopSelection)+delta))
    app.shopSelection=math.min(#Shop.items,(page-1)*Shop.pageSize+(app.shopSelection-1)%Shop.pageSize+1)
    app.message=nil
end
local function button(label,x,y,w,h,action,secondary,disabled)
    app.buttons[#app.buttons+1]={label=label,x=x,y=y,w=w,h=h,action=action,secondary=secondary,disabled=disabled}
end
local function coords(x,y)
    local width,height=love.graphics.getDimensions()
    local scale=math.min(width/960,height/540)
    return (x-(width-960*scale)/2)/scale,(y-(height-540*scale)/2)/scale
end
local function inside(b,x,y) return x>=b.x and y>=b.y and x<=b.x+b.w and y<=b.y+b.h end
local function back()
    if app.state=="playing" then state("paused"); persist()
    elseif app.state=="paused" then state("playing")
    elseif app.state=="shop" then state(app.shopReturn)
    elseif app.state=="route" or app.state=="help" then state("menu")
    elseif app.state=="dead" or app.state=="finished" or app.state=="won" then state("menu") end
end
function love.load(args)
    for _,arg in ipairs(args or {}) do if arg=="--smoke" then smoke=true end end
    love.graphics.setDefaultFilter("nearest","nearest")
    love.keyboard.setKeyRepeat(true)
    canvas=love.graphics.newCanvas(960,540)
    R.load(); Audio.load()
    save=smoke and Save.defaults() or Save.load()
    game=Game.new(save,Audio)
    app.saveTimer=0
    if smoke then love.filesystem.createDirectory("smoke") end
end
function love.update(dt)
    app.time=app.time+dt
    if app.state=="playing" then
        local left,right,shooting,sitting=false,false,false,false
        for _,t in pairs(app.touches) do
            if t.x<125 and t.y>400 then left=true
            elseif t.x<240 and t.y>400 then right=true
            elseif t.x>=600 and t.x<700 and t.y>400 then sitting=true
            elseif t.x>830 and t.y>400 then shooting=true end
        end
        game:update(dt,{left=left or love.keyboard.isDown("a","left"),right=right or love.keyboard.isDown("d","right"),
            shoot=shooting or love.keyboard.isDown("lalt","ralt","x"),sit=sitting or love.keyboard.isDown("s","down") or smoke and app.smokeSit})
        app.saveTimer=app.saveTimer+dt
        if app.saveTimer>2 then persist(); app.saveTimer=0 end
        if game.dead then state("dead"); persist()
        elseif game.finished then state(game.level.index==Levels.count and "won" or "finished"); persist() end
    end
    if smoke then
        app.smokeFrames=(app.smokeFrames or 0)+1
        local n=app.smokeFrames
        if n==8 then
            start(1)
            for _=1,60 do game:update(1/60,{}) end
            assert(game.player.onGround,"Sid must land on the first platform")
            love.keypressed("space"); game:update(1/60,{})
            assert(game.player.vy<0,"Space must jump")
            love.keyreleased("space")
            for _=1,60 do game:update(1/60,{}) end
            love.keypressed("b"); assert(app.state=="shop","B must open the shop")
            love.keypressed("escape"); assert(app.state=="playing","Shop back must resume play")
            love.keypressed("escape"); assert(app.state=="paused","Escape must pause")
            love.keypressed("escape"); assert(app.state=="playing","Escape must resume")
        elseif n==16 then
            save.coins=125; save.owned.witch=true; save.equipped.hat="witch"
            shop()
        elseif n==24 then
            love.keypressed("right"); assert(app.shopSelection==2)
            love.keypressed("return"); assert(save.owned.beanie and save.equipped.hat=="beanie")
            love.keypressed("return"); assert(save.equipped.hat==nil)
            local before=save.coins
            local width,height=love.graphics.getDimensions()
            local scale=math.min(width/960,height/540)
            love.mousepressed(45*scale+(width-960*scale)/2,145*scale+(height-540*scale)/2,1)
            assert(save.ammo==10 and save.coins==before-8,"Mouse must buy exactly one ammo pack")
            save.unlocked=3
            state("route")
        elseif n==32 then start(8); game.player.x=900; game.camera=600
        elseif n==40 then state("paused")
        elseif n==48 then state("finished")
        elseif n==56 then start(Levels.count); state("won")
        elseif n==64 then state("help")
        elseif n==72 then
            state("shop"); app.shopSelection=1
            love.keypressed("pagedown"); assert(app.shopSelection==13,"Page down must reveal new items")
            save.coins=500
            love.keypressed("return"); assert(save.equipped.color=="arctic")
            love.keypressed("right"); love.keypressed("return"); assert(save.equipped.hat=="crown")
            love.keypressed("right"); love.keypressed("return"); assert(save.equipped.outfit=="scarf")
            love.keypressed("right"); love.keypressed("return"); assert(save.equipped.special=="meteor")
        elseif n==80 then
            start(11)
            game.level.enemies={
                {kind="monkey",x=230,y=398,w=26,h=28,min=220,max=500,vx=30,hp=1,homeY=398,bananasLeft=3,throwTimer=0},
                {kind="icecube",x=340,y=396,w=30,h=30,min=300,max=500,vx=-30,hp=2,homeY=396,icy=true},
                {kind="snowball",x=440,y=402,w=24,h=24,min=400,max=550,vx=40,hp=1,homeY=402,icy=true}}
            game.player.x=150
            for _=1,60 do game:update(1/60,{}) end
            game:jump()
            for _=1,50 do game:update(1/60,{}) end
            assert(game.player.onGround and game.player.platform.kind=="ledge","Sid must reach the raised ledge")
            local lower=game.player.platform
            local upper
            for _,tile in ipairs(game.level.platforms) do
                if tile.tier==2 and tile.stepFrom==lower then upper=tile; break end
            end
            assert(upper,"A second raised tier must be available")
            game:jump()
            for _=1,50 do game:update(1/60,{right=game.player.x<upper.x+30}) end
            assert(game.player.platform==upper,"Sid must climb from the first ledge to the second tier")
            game:update(1/60,{sit=true}); assert(game.player.sitting)
            app.smokeSit=true
            game:throwBanana(game.level.enemies[1])
        elseif n==88 then state("gallery")
        elseif n==96 then
            print("LOVE runtime smoke passed: 15-level route, paginated shop, input, two-tier climb and stable sitting, ice enemies, facing gallery, results, controls")
            love.event.quit(0)
        end
    end
end
local function modal(title,subtitle)
    R.color("243D35",.58); love.graphics.rectangle("fill",0,0,960,540)
    R.rect(205,126,550,282,"FBF8EE",12)
    R.text(title,230,157,32,"243D35",500,"center")
    R.text(subtitle,238,207,16,"718369",484,"center")
end
function love.draw()
    love.graphics.setCanvas(canvas); love.graphics.clear(); app.buttons={}
    local mode=app.state
    if mode=="menu" then
        R.menu(save,app.time)
        button(save.completed and "Walk the trail again" or (save.unlocked>1 or save.checkpoint) and "Continue adventure" or "Let's adventure  >",49,384,222,45,function()
            if save.completed then save.level=1; save.collected={}; save.checkpoint=false; save.completed=false end
            start(save.level)
        end)
        button("The trail",281,384,118,45,function() state("route") end,true)
        button("Shop",409,384,86,45,shop,true)
        button("?",874,403,38,36,function() state("help") end,true)
    elseif mode=="shop" then
        R.shop(save,Shop.items,app.shopSelection,app.time,app.message)
        button("<",600,482,44,34,function() changeShopPage(-1) end,true,Shop.page(app.shopSelection)==1)
        button(">",710,482,44,34,function() changeShopPage(1) end,true,Shop.page(app.shopSelection)==Shop.pageCount())
        button("Back",822,482,106,34,back,true)
    elseif mode=="route" then
        R.route(save,Levels.names,app.time)
        for i=1,Levels.count do
            local index=i
            -- Invisible buttons preserve the visual route cards and keyboard navigation.
            local card=R.routeCard(i)
            card.label=""; card.action=function() start(index) end
            card.disabled=i>save.unlocked; card.invisible=true
            app.buttons[#app.buttons+1]=card
        end
        button("Back",811,468,118,40,back,true)
        R.text("ARROWS / TAB  SELECT     ENTER  EXPLORE",33,480,12,"768770")
    elseif mode=="help" then
        R.panel("Slower hero. Bigger heart.","Everything you need for a great little adventure.")
        local rows={{"A D / LEFT RIGHT","Walk in either direction"},{"SPACE / W / UP","Hold for a higher jump. Land on enemies to stomp."},
            {"S / DOWN","Sit and rest on the ground or a raised platform."},
            {"ALT / X","Fire. Hold to keep shooting; each shot uses ammo."},{"B","Visit the shop. Spend coins and equip your finds."},
            {"ESC / P","Pause and take a breath."},{"M / F11","Toggle sound / fullscreen"}}
        for i,row in ipairs(rows) do
            local y=137+(i-1)*35
            R.rect(32,y,235,31,"E4E8D9",4); R.text(row[1],45,y+8,12); R.text(row[2],286,y+6,16)
        end
        R.text("15 trails await. Monkeys have only 3 bananas each. Ice cubes take 2 normal hits.\nStart with 5 sparks. Find ammo pouches. Coins, purchases, and checkpoints save automatically.",33,410,14,"718369",850)
        button("Ready to wander",710,479,218,38,back)
    elseif mode=="gallery" and smoke then
        R.panel("Facing and platform verification","All artwork faces right locally, then mirrors with movement. Sid's feet stay on the platform.")
        for row,facing in ipairs({1,-1}) do
            local y=215+(row-1)*135
            R.text(facing==1 and "RIGHT  >" or "<  LEFT",32,y,14)
            for i,kind in ipairs({"monkey","bird","icecube","snowball"}) do
                R.enemy({kind=kind,x=160+i*125,y=y,w=kind=="icecube" and 30 or 28,h=30,hp=2,vx=facing*20,bananasLeft=3},app.time)
                R.text(kind,136+i*125,y+43,12)
            end
            R.sloth(805,y+32,76,facing,app.time,save.equipped,true)
        end
        R.rect(684,463,230,10,"456A52")
        R.sloth(800,463,86,-1,app.time,save.equipped,false,true)
        R.text("Sitting / feet anchored",698,483,12)
    else
        if game.level then R.world(game,save) end
        if mode=="playing" then
            button("II",855,30,68,36,function() state("paused"); persist() end,true)
            if app.touchMode then
                for _,b in ipairs({{25,"<"},{135,">"},{600,"SIT"},{718,"JUMP"},{836,"FIRE"}}) do
                    R.color("FBF8EE",.75); love.graphics.rectangle("fill",b[1],431,98,63,7,7)
                    R.text(b[2],b[1],453,14,"243D35",98,"center")
                end
            end
        elseif mode=="paused" then
            modal("A well-earned breather.","Your next small step is waiting.")
            button("Keep going",238,272,231,43,function() state("playing") end)
            button("Visit the shop",485,272,231,43,shop,true)
            button("Back to camp",238,333,478,37,function() persist(); state("menu") end,true)
        elseif mode=="dead" then
            modal("Even heroes take a tumble.",save.checkpoint and "Your checkpoint is safe. Let's try that again." or "Dust off those claws. You've got this.")
            button("Try again",238,276,231,45,function() start(game.level.index,true) end)
            button("Visit the shop",485,276,231,45,shop,true)
            button("Back to camp",238,341,478,34,function() state("menu") end,true)
        elseif mode=="finished" or mode=="won" then
            modal(mode=="won" and "Small sloth. Big hero." or "One trail closer.",mode=="won" and "Fifteen trails behind you. A whole world ahead." or game.level.name.." — complete!")
            R.text(game.earned.." coins collected   /   "..game.kills.." enemies outsmarted",230,245,14,"8C783F",500,"center")
            button(mode=="won" and "Back to camp" or "Next adventure  >",238,287,231,45,function()
                if mode=="won" then state("menu") else start(save.level) end
            end)
            button("Treat yourself",485,287,231,45,shop,true)
            R.text("Progress saved. Your coins travel with you.",230,360,12,"859078",500,"center")
        end
    end
    local mx,my=coords(love.mouse.getPosition())
    for i,b in ipairs(app.buttons) do
        if not b.invisible then R.button(b,inside(b,mx,my),app.keyboardFocus and app.focus==i)
        elseif app.keyboardFocus and app.focus==i then
            R.color("D6A34A"); love.graphics.setLineWidth(3); love.graphics.rectangle("line",b.x+2,b.y+2,b.w-4,b.h-4,6,6)
        end
    end
    if not Audio.enabled then R.text("SOUND OFF",842,6,10,"9BA58E") end
    love.graphics.setCanvas()
    local width,height=love.graphics.getDimensions()
    local scale=math.min(width/960,height/540)
    love.graphics.clear(.12,.18,.15,1); love.graphics.setColor(1,1,1,1)
    love.graphics.draw(canvas,(width-960*scale)/2,(height-540*scale)/2,0,scale,scale)
    if smoke and app.smokeFrames%8==6 then
        local filename="smoke/"..app.smokeFrames.."-"..mode..".png"
        canvas:newImageData():encode("png",filename)
        print("Screenshot: "..love.filesystem.getSaveDirectory().."/"..filename)
    end
end
function love.keypressed(key)
    if key=="f11" then love.window.setFullscreen(not love.window.getFullscreen(),"desktop"); return end
    if key=="m" then Audio.enabled=not Audio.enabled; return end
    if key=="escape" or key=="p" then back(); return end
    if app.state=="playing" then
        if key=="space" or key=="w" or key=="up" then game:jump()
        elseif key=="b" then shop() end
    elseif app.state=="shop" then
        if key=="pagedown" or key=="]" then changeShopPage(1)
        elseif key=="pageup" or key=="[" then changeShopPage(-1)
        elseif key=="right" then app.shopSelection=app.shopSelection%#Shop.items+1
        elseif key=="left" then app.shopSelection=(app.shopSelection-2)%#Shop.items+1
        elseif key=="down" then app.shopSelection=(app.shopSelection+3)%#Shop.items+1
        elseif key=="up" then app.shopSelection=(app.shopSelection-5)%#Shop.items+1
        elseif key=="return" or key=="space" then buy(app.shopSelection) end
    else
        app.keyboardFocus=true
        if key=="tab" or key=="down" or key=="right" then app.focus=app.focus%math.max(1,#app.buttons)+1
        elseif key=="up" or key=="left" then app.focus=(app.focus-2)%math.max(1,#app.buttons)+1
        elseif key=="return" or key=="space" then
            local b=app.buttons[app.focus]
            if b and not b.disabled then b.action(); Audio.play("click") end
        end
    end
end
function love.keyreleased(key)
    if app.state=="playing" and (key=="space" or key=="w" or key=="up") and game.player.vy< -170 then game.player.vy=-170 end
end
function love.mousemoved() app.keyboardFocus=false end
function love.mousepressed(x,y,mouseButton,isTouch)
    if mouseButton~=1 or isTouch then return end
    x,y=coords(x,y)
    if app.state=="shop" and y>=133 and y<466 then
        local col=math.floor((x-32)/230); local row=math.floor((y-133)/115)
        if col>=0 and col<4 and (x-32)%230<=214 and (y-133)%115<=103 then
            local index=(Shop.page(app.shopSelection)-1)*Shop.pageSize+row*4+col+1
            if index<=#Shop.items then buy(index) end
            return
        end
    end
    for _,b in ipairs(app.buttons) do
        if not b.disabled and inside(b,x,y) then b.action(); Audio.play("click"); return end
    end
end
function love.wheelmoved(_,dy)
    if app.state=="shop" and dy~=0 then changeShopPage(dy<0 and 1 or -1) end
end
function love.touchpressed(id,x,y)
    app.touchMode=true
    local tx,ty=coords(x,y); app.touches[id]={x=tx,y=ty}
    if app.state=="playing" and tx>=700 and tx<830 and ty>400 then game:jump()
    elseif app.state~="playing" or ty<400 then love.mousepressed(x,y,1) end
end
function love.touchmoved(id,x,y) local tx,ty=coords(x,y); app.touches[id]={x=tx,y=ty} end
function love.touchreleased(id) app.touches[id]=nil end
function love.focus(focused)
    if not focused and app.state=="playing" and not smoke then state("paused"); persist() end
end
function love.quit() persist() end
local defaultErrorHandler=love.errorhandler
function love.errorhandler(message)
    if smoke then
        io.stderr:write(debug.traceback(tostring(message),2).."\n")
        return function() return 1 end
    end
    return defaultErrorHandler(message)
end
