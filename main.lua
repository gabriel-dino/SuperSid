local Save=require("src.save")
local Shop=require("src.shop")
local Levels=require("src.levels")
local Game=require("src.game")
local R=require("src.render")
local Audio=require("src.audio")
local Custom=require("src.custom_levels")
local Editor=require("src.editor")
local EditorView=require("src.editor_view")
local utf8=require("utf8")
local app={state="menu",buttons={},focus=1,time=0,shopSelection=1,shopReturn="menu",touches={}}
local smoke=false
local save,game,canvas
local openContrib,openEditor,leaveEditor,playCustom
local function persist() if save and not smoke then Save.write(save) end end
local function state(name) app.state=name; app.focus=1; app.buttons={} end
local function start(index,retry)
    game:start(index,retry); state("playing"); persist()
end
local function shop()
    if game.custom and app.state~="menu" then return end
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
local function closeDialog() app.dialog=nil; love.keyboard.setTextInput(false) end
local function openFolder()
    love.filesystem.createDirectory(Custom.directory)
    love.system.openURL("file://"..love.filesystem.getSaveDirectory().."/"..Custom.directory)
end
openContrib=function(message)
    app.contrib,app.contribErrors=Custom.list()
    app.contribPage=math.max(1,math.min(app.contribPage or 1,math.max(1,math.ceil(#app.contrib/4))))
    app.contribMessage=message or (#app.contribErrors>0 and (#app.contribErrors.." invalid file(s) skipped. "..app.contribErrors[1]) or "")
    state("contrib")
end
openEditor=function(level,filename)
    local function open()
        if level or not app.editor then app.editor=Editor.new(level,filename) end
        state("editor")
    end
    if level and app.editor and app.editor.dirty then state("editor"); leaveEditor(open)
    else open() end
end
leaveEditor=function(action)
    app.editor:finish()
    if app.editor.dirty then app.dialog={kind="leave",action=action}; app.focus=1
    else action() end
end
playCustom=function(level,returnTo)
    local candidate=Game.new(save,Audio)
    local ok,message=candidate:startCustom(level)
    if not ok then
        if returnTo=="editor" then app.editor.message=message else app.contribMessage=message end
        return
    end
    game=candidate; app.customReturn=returnTo; app.smokeSit=false; state("playing")
end
local function returnFromCustom()
    if app.customReturn=="editor" then state("editor") else openContrib() end
end
local function retry()
    if game.custom then game:startCustom(game.sourceCustom,true); state("playing")
    else start(game.level.index,true) end
end
local function back()
    if app.dialog then closeDialog(); return end
    if app.state=="playing" then state("paused"); persist()
    elseif app.state=="paused" then state("playing")
    elseif app.state=="shop" then state(app.shopReturn)
    elseif app.state=="editor" then leaveEditor(function() state("menu") end)
    elseif app.state=="route" or app.state=="help" or app.state=="contrib" then state("menu")
    elseif app.state=="dead" or app.state=="finished" or app.state=="won" then
        if game.custom then returnFromCustom() else state("menu") end
    end
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
    if smoke then love.filesystem.createDirectory("smoke"); Custom.directory="smoke/levels" end
end
function love.update(dt)
    app.time=app.time+dt
    if app.state=="editor" and not app.dialog then
        local pan=(love.keyboard.isDown("right","d") and 1 or 0)-(love.keyboard.isDown("left","a") and 1 or 0)
        app.editor:scroll(pan*640*dt)
    end
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
        elseif game.finished then state(not game.custom and game.level.index==Levels.count and "won" or "finished"); persist() end
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
        elseif n==96 then state("menu")
        elseif n>=104 then
            require("tests.editor_smoke")(n,app,save,{
                game=function() return game end,
                screenshotDone=function()
                    print("LOVE runtime smoke passed: campaign, shop, tiered platforms, editor drawing and text, save, custom play/retry/results, import, community library")
                end
            })
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
        button("Level editor",49,441,172,37,function() openEditor() end,true)
        button("Contrib levels",233,441,184,37,function() openContrib() end,true)
        button("?",874,403,38,36,function() state("help") end,true)
    elseif mode=="editor" then
        local e=app.editor
        EditorView.editor(e,app.time,button,{
            save=function() e:save() end,copy=function() e:save(true) end,
            test=function() e:finish(); playCustom(e.level,"editor") end,
            back=back,folder=openFolder,
            new=function() leaveEditor(function() app.editor=Editor.new(); state("editor") end) end,
            rename=function(field)
                app.dialog={kind="text",field=field,value=e.level[field]}
                app.focus=1
                love.keyboard.setTextInput(true)
            end
        })
    elseif mode=="contrib" then
        EditorView.contrib(app.contrib,app.contribPage,app.contribMessage,button,{
            import=function() app.dialog={kind="import"}; app.focus=1 end,folder=openFolder,
            create=function() openEditor() end,back=back,
            refresh=function() openContrib() end,
            page=function(delta) app.contribPage=math.max(1,math.min(math.max(1,math.ceil(#app.contrib/4)),app.contribPage+delta)) end,
            play=function(entry) playCustom(entry.level,"contrib") end,
            edit=function(entry) openEditor(entry.level,entry.filename) end
        })
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
        if game.level then R.world(game,game.save) end
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
            button(game.custom and "Restart level" or "Visit the shop",485,272,231,43,game.custom and retry or shop,true)
            button(game.custom and (app.customReturn=="editor" and "Back to editor" or "Back to Contrib levels") or "Back to camp",238,333,478,37,function()
                persist(); if game.custom then returnFromCustom() else state("menu") end
            end,true)
        elseif mode=="dead" then
            modal("Even heroes take a tumble.",game.save.checkpoint and "Your checkpoint is safe. Let's try that again." or "Dust off those claws. You've got this.")
            button("Try again",238,276,231,45,retry)
            button(game.custom and "Back to levels" or "Visit the shop",485,276,231,45,game.custom and returnFromCustom or shop,true)
            button("Back to camp",238,341,478,34,function() state("menu") end,true)
        elseif mode=="finished" or mode=="won" then
            modal(mode=="won" and "Small sloth. Big hero." or "One trail closer.",mode=="won" and "Fifteen trails behind you. A whole world ahead." or game.level.name.." — complete!")
            R.text(game.earned.." coins collected   /   "..game.kills.." enemies outsmarted",230,245,14,"8C783F",500,"center")
            button(game.custom and "Play again" or mode=="won" and "Back to camp" or "Next adventure  >",238,287,231,45,function()
                if game.custom then playCustom(game.sourceCustom,app.customReturn)
                elseif mode=="won" then state("menu") else start(save.level) end
            end)
            button(game.custom and (app.customReturn=="editor" and "Back to editor" or "Contrib levels") or "Treat yourself",485,287,231,45,game.custom and returnFromCustom or shop,true)
            R.text(game.custom and "A community adventure. Campaign progress stays separate." or "Progress saved. Your coins travel with you.",230,360,12,"859078",500,"center")
        end
    end
    if app.dialog then
        app.buttons={}
        local d=app.dialog
        if d.kind=="text" then
            modal(d.field=="name" and "Name your adventure" or "Level author","Type your text, then press Enter to apply.")
            R.rect(238,263,478,44,"E4E8D9",5)
            love.graphics.setScissor(250,270,454,30); R.text(d.value.."|",250,272,18); love.graphics.setScissor()
            button("Apply",238,333,231,40,function()
                if d.value:find("%S") then app.editor:remember(); app.editor.level[d.field]=d.value; closeDialog() end
            end)
            button("Cancel",485,333,231,40,closeDialog,true)
        elseif d.kind=="leave" then
            modal("Save your level?","You have changes in the editor.")
            button("Save & continue",238,272,231,43,function()
                if app.editor:save() then closeDialog(); d.action() else closeDialog() end
            end)
            button("Discard changes",485,272,231,43,function() app.editor=nil; closeDialog(); d.action() end,true)
            button("Keep editing",238,333,478,37,closeDialog,true)
        elseif d.kind=="import" then
            modal("Import a shared level","Drop a .sidlevel file anywhere onto this window.")
            R.text("Or open the levels folder, copy shared .sidlevel files\ninto it, then return here and press Refresh.",238,254,16,"718369",478,"center")
            button("Open levels folder",238,333,231,40,openFolder)
            button("Done / Refresh",485,333,231,40,function() closeDialog(); openContrib() end,true)
        end
    end
    local mx,my=coords(love.mouse.getPosition())
    for i,b in ipairs(app.buttons) do
        if not b.invisible then R.button(b,inside(b,mx,my),app.keyboardFocus and app.focus==i)
        elseif app.keyboardFocus and app.focus==i then
            R.color("D6A34A"); love.graphics.setLineWidth(3); love.graphics.rectangle("line",b.x+2,b.y+2,b.w-4,b.h-4,6,6)
        end
    end
    if mode=="editor" and not app.dialog then EditorView.editorFields(app.editor) end
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
    if app.dialog then
        if key=="escape" then closeDialog()
        elseif app.dialog.kind=="text" then
            if key=="backspace" then
                local offset=utf8.offset(app.dialog.value,-1)
                if offset then app.dialog.value=app.dialog.value:sub(1,offset-1) end
            elseif key=="return" then
                if app.dialog.value:find("%S") then
                    app.editor:remember(); app.editor.level[app.dialog.field]=app.dialog.value; closeDialog()
                end
            elseif key=="v" and love.keyboard.isDown("lctrl","rctrl") then love.textinput(love.system.getClipboardText()) end
        elseif key=="tab" or key=="right" or key=="down" then
            app.keyboardFocus=true; app.focus=app.focus%math.max(1,#app.buttons)+1
        elseif key=="left" or key=="up" then
            app.keyboardFocus=true; app.focus=(app.focus-2)%math.max(1,#app.buttons)+1
        elseif key=="return" and app.buttons[app.focus] then app.buttons[app.focus].action() end
        return
    end
    if key=="f11" then love.window.setFullscreen(not love.window.getFullscreen(),"desktop"); return end
    if key=="m" then Audio.enabled=not Audio.enabled; return end
    if key=="escape" or key=="p" and (app.state=="playing" or app.state=="paused") then back(); return end
    if app.state=="editor" then
        local e=app.editor
        local ctrl=love.keyboard.isDown("lctrl","rctrl")
        if ctrl and key=="s" then e:save(love.keyboard.isDown("lshift","rshift"))
        elseif ctrl and key=="z" then if love.keyboard.isDown("lshift","rshift") then e:redo() else e:undo() end
        elseif ctrl and key=="y" then e:redo()
        elseif key=="f5" then e:finish(); playCustom(e.level,"editor")
        elseif key=="home" then e:scroll(-e.level.width)
        elseif key=="end" then e:scroll(e.level.width)
        elseif key=="c" then e.tool="checkpoint"
        elseif key=="e" then e.tool="erase"
        else
            local number=tonumber(key)
            if number then e.tool=Editor.tools[number==0 and 10 or number].id end
        end
    elseif app.state=="playing" then
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
function love.textinput(text)
    local d=app.dialog
    if d and d.kind=="text" then
        text=text:gsub("[%z\1-\31\127]","")
        local limit=d.field=="name" and 64 or 48
        if #d.value+#text<=limit then d.value=d.value..text end
    end
end
function love.keyreleased(key)
    if app.state=="playing" and (key=="space" or key=="w" or key=="up") and game.player.vy< -170 then game.player.vy=-170 end
end
function love.mousemoved(x,y)
    app.keyboardFocus=false
    if app.state=="editor" and not app.dialog and app.editor.drag then
        x,y=coords(x,y)
        local wx,wy=app.editor:world(x,y)
        if wx then app.editor:move(wx,wy) end
    end
end
function love.mousepressed(x,y,mouseButton,isTouch)
    if isTouch then return end
    x,y=coords(x,y)
    if mouseButton==2 and app.state=="editor" and not app.dialog then
        local wx,wy=app.editor:world(x,y)
        if wx then app.editor:begin(wx,wy,true) end
        return
    end
    if mouseButton~=1 then return end
    if app.dialog then
        for _,b in ipairs(app.buttons) do if inside(b,x,y) then b.action(); break end end
        return
    end
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
    if app.state=="editor" then
        local wx,wy=app.editor:world(x,y)
        if wx then app.editor:begin(wx,wy) end
    end
end
function love.mousereleased(_,_,mouseButton)
    if app.state=="editor" and (mouseButton==1 or mouseButton==2) then app.editor:finish() end
end
function love.wheelmoved(_,dy)
    if app.dialog then return end
    if app.state=="editor" then app.editor:scroll(-dy*120)
    elseif app.state=="shop" and dy~=0 then changeShopPage(dy<0 and 1 or -1) end
end
function love.touchpressed(id,x,y)
    app.touchMode=true
    local tx,ty=coords(x,y); app.touches[id]={x=tx,y=ty}
    if app.state=="playing" and tx>=700 and tx<830 and ty>400 then game:jump()
    elseif app.state~="playing" or ty<400 then love.mousepressed(x,y,1) end
end
function love.touchmoved(id,x,y)
    local tx,ty=coords(x,y); app.touches[id]={x=tx,y=ty}
    if app.state=="editor" then love.mousemoved(x,y) end
end
function love.touchreleased(id)
    app.touches[id]=nil
    if app.state=="editor" then app.editor:finish() end
end
function love.filedropped(file)
    if app.state~="contrib" and app.state~="menu" then
        if app.state=="editor" then app.editor.message="Open Contrib levels to import shared files." end
        return
    end
    closeDialog()
    local filename=file:getFilename()
    if filename:lower():sub(-9)~=Custom.extension then openContrib("Choose a Super Sid .sidlevel file."); return end
    local opened=file:open("r")
    if not opened then openContrib("Could not open the dropped file."); return end
    if file:getSize()>Custom.maxBytes then file:close(); openContrib("Level files must be smaller than 256 KB."); return end
    local contents=file:read(); file:close()
    local stored,level=Custom.import(contents)
    closeDialog()
    openContrib(stored and ("Imported: "..level.name) or level)
end
function love.focus(focused)
    if not focused and app.state=="editor" then app.editor:finish() end
    if not focused and app.state=="playing" and not smoke then state("paused"); persist() end
end
function love.quit()
    if not smoke and app.editor and app.editor.dirty then
        state("editor")
        leaveEditor(function() app.editor=nil; love.event.quit() end)
        return true
    end
    persist()
end
local defaultErrorHandler=love.errorhandler
function love.errorhandler(message)
    if smoke then
        io.stderr:write(debug.traceback(tostring(message),2).."\n")
        return function() return 1 end
    end
    return defaultErrorHandler(message)
end
