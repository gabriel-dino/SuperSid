local Custom=require("src.custom_levels")
local Editor=require("src.editor")
local R=require("src.render")
local Shop=require("src.shop")
local Deco=require("src.decorations")
local function press(app,label)
    for _,b in ipairs(app.buttons) do
        if b.label==label and not b.disabled then b.action(); return end
    end
    error("Missing UI button: "..label)
end
local function window(x,y)
    local w,h=love.graphics.getDimensions(); local s=math.min(w/960,h/540)
    return x*s+(w-960*s)/2,y*s+(h-540*s)/2
end
local function click(x,y)
    x,y=window(x,y); love.mousepressed(x,y,1); love.mousereleased(x,y,1)
end
local function draw(e,tool,x1,y1,x2,y2)
    e.tool=tool
    local v=Editor.view
    local x,y=window(v.x+(x1-e.camera)*v.scale,v.y+y1*v.scale)
    love.mousepressed(x,y,1)
    if x2 then
        x,y=window(v.x+(x2-e.camera)*v.scale,v.y+y2*v.scale)
        love.mousemoved(x,y)
    end
    love.mousereleased(x,y,1)
end
return function(n,app,save,api)
    if n==104 then
        assert(R.fallbacks[18]:hasGlyphs("ăâîșțĂÂÎȘȚ"),"Level names need Romanian glyphs")
        press(app,"Level editor"); assert(app.state=="editor")
        app.editor.filename="editor-smoke.sidlevel"
    elseif n==112 then
        local e=app.editor
        draw(e,"ledge",240,336,480,336)
        draw(e,"ground",960,384,1080,432)
        draw(e,"coin",260,300,290,300)
        draw(e,"monkey",650,420)
        draw(e,"bird",750,220)
        draw(e,"icecube",800,420)
        draw(e,"snowball",900,420)
        draw(e,"ammo",550,420)
        draw(e,"spawn",72,432)
        draw(e,"goal",1140,432)
        draw(e,"checkpoint",600,432)
        click(310,100); assert(app.dialog and app.dialog.kind=="text")
        for _=1,#app.dialog.value do love.keypressed("backspace") end
        love.textinput("Smoke shared trail"); love.keypressed("return")
        assert(e.level.name=="Smoke shared trail" and #e.level.enemies==4 and #e.level.coins==2)
    elseif n==120 then
        press(app,"Save"); assert(not app.editor.dirty and Custom.load("editor-smoke.sidlevel"))
        press(app,"Test"); assert(app.state=="playing" and api.game().custom)
        assert(api.game().player.x==72)
    elseif n==128 then
        local g=api.game(); local original=save.coins
        local coin=g.level.coins[1]; g.player.x=coin.x; g.player.y=coin.y; g:update(1/60,{})
        assert(g.save.coins>original and save.coins==original)
        g.player.x=g.level.goal.x; g.player.y=g.level.goal.y; g:update(1/60,{})
        assert(g.finished)
    elseif n==136 then
        assert(app.state=="finished"); press(app,"Back to editor"); assert(app.state=="editor")
        assert(app.editor.level.enemies[1].hp==nil,"test play must not edit the source level")
    elseif n==144 then love.keypressed("escape"); assert(app.state=="menu")
    elseif n==152 then press(app,"Contrib levels"); assert(app.state=="contrib" and #app.contrib>0)
    elseif n==160 then press(app,"Import level"); assert(app.dialog and app.dialog.kind=="import")
    elseif n==168 then
        local shared=Custom.copy(app.editor.level); shared.name="Imported shared trail"
        local data=assert(Custom.encode(shared))
        love.filedropped({getFilename=function() return "friend.sidlevel" end,open=function() return true end,
            getSize=function() return #data end,read=function() return data end,close=function() end})
        assert(app.state=="contrib" and not app.dialog and app.contribMessage:find("Imported"))
    elseif n==176 then press(app,"Play"); assert(api.game().custom and app.customReturn=="contrib")
    elseif n==184 then
        local g=api.game(); g.player.health=1; g.player.invincible=0; g:hurt()
    elseif n==192 then assert(app.state=="dead"); press(app,"Try again"); assert(app.state=="playing" and not api.game().dead)
    elseif n==200 then love.keypressed("escape"); assert(app.state=="paused")
    elseif n==208 then press(app,"Back to Contrib levels"); assert(app.state=="contrib")
    elseif n==216 then
        press(app,"Edit"); assert(app.state=="editor")
        app.editor:theme(); love.keypressed("escape")
        assert(app.dialog and app.dialog.kind=="leave")
    elseif n==224 then press(app,"Keep editing"); assert(not app.dialog and app.editor.dirty)
    elseif n==232 then press(app,"New"); assert(app.dialog and app.dialog.kind=="leave")
    elseif n==240 then
        love.keypressed("tab"); love.keypressed("return")
        assert(not app.dialog and not app.editor.dirty and app.editor.level.name=="My little adventure")
    elseif n==248 then
        click(310,100); assert(app.dialog and app.dialog.kind=="text")
        for _=1,#app.dialog.value do love.keypressed("backspace") end
        love.textinput("Trail ă")
    elseif n==256 then
        love.keypressed("backspace"); assert(app.dialog.value=="Trail ")
        love.keypressed("escape"); assert(not app.dialog and app.editor.level.name=="My little adventure")
        love.keypressed("escape"); assert(app.state=="menu")
    elseif n==264 then press(app,"Shop"); save.coins=1000
    elseif n==272 then
        love.keypressed("pagedown"); assert(Shop.page(app.shopSelection)==3)
        app.shopSelection=26; love.keypressed("return"); assert(save.owned.deco_trail)
        love.keypressed("left"); love.keypressed("return"); assert(save.owned.deco_crystals)
    elseif n==280 then
        love.keypressed("pageup")
        for _=1,8 do love.keypressed("right") end
        assert(app.shopSelection==21)
        love.keypressed("return"); assert(save.equipped.magnet=="magnet")
        love.keypressed("right"); love.keypressed("return"); assert(save.equipped.parachute=="parachute")
        love.keypressed("right"); love.keypressed("return"); assert(save.equipped.companion=="chick")
        love.keypressed("right"); love.keypressed("return"); assert(save.owned.deco_woodland)
    elseif n==288 then love.keypressed("escape"); assert(app.state=="menu")
    elseif n==296 then press(app,"Level editor")
    elseif n==304 then
        press(app,"Decor: buy packs")
        local e=app.editor; assert(e.decoration=="mushroom")
        for i,id in ipairs(Deco.available(save.owned)) do
            e.decoration=id; draw(e,"decoration",i*96+96,432)
        end
        e.filename="decor-smoke.sidlevel"; press(app,"Save")
        local stored=assert(Custom.load(e.filename)); assert(#stored.decorations==9)
    elseif n==312 then press(app,"Test"); assert(#api.game().level.decorations==9)
    elseif n==320 then
        local g=api.game(); g.player.y=210; g.player.vy=170; g.player.onGround=false
        app.smokeGlide=true; g:update(1/60,{glide=true}); assert(g.player.gliding)
    elseif n==336 then app.smokeGlide=false; api.start(16)
    elseif n==344 then api.start(17)
    elseif n==352 then api.start(18)
    elseif n==360 then api.start(25)
    elseif n==368 then api.route()
    elseif n==376 then api.screenshotDone(); love.event.quit(0)
    end
end
