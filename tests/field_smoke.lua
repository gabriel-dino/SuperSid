local Eagles=require("src.eagles")
local Editor=require("src.editor")
local Custom=require("src.custom_levels")
local R=require("src.render")
local function click(x,y)
    local w,h=love.graphics.getDimensions(); local s=math.min(w/960,h/540)
    x=x*s+(w-960*s)/2; y=y*s+(h-540*s)/2
    love.mousepressed(x,y,1); love.mousereleased(x,y,1)
end
local function checkResolution(api,name)
    local pw,ph=love.graphics.getPixelDimensions()
    local density=math.min(pw/960,ph/540)
    local canvas=api.renderInfo(); local cw,ch=canvas:getPixelDimensions()
    assert(math.abs(cw-960*density)<=1 and math.abs(ch-540*density)<=1,string.format("canvas %dx%d must match screen %dx%d at density %.3f",cw,ch,pw,ph,density))
    assert(math.abs(R.fonts[16]:getDPIScale()-density)<.001,"text must be rasterized at the actual display density")
    assert(R.fallbacks[16]:hasGlyphs("ăâîșțĂÂÎȘȚ"))
    love.graphics.captureScreenshot("smoke/"..name..".png")
    print(string.format("Display check %s: screen %dx%d, game %dx%d, font density %.3f",name,pw,ph,cw,ch,density))
end
return function(n,app,save,api)
    if n==424 then
        app.smokeWalkRight=false; app.smokeGlide=false; api.start(1)
        local g=api.game(); local tile
        for _,p in ipairs(g.level.platforms) do if p.tier==2 then tile=p; break end end
        g.level.coins={}; g.level.ammo={}; g.level.enemies={Eagles.new(470,140,220,700,90,0)}
        g.level.enemies[1].attackTimer=0
        g.player.x=260; g.player.y=tile.y-g.player.h; g.player.health=2; g.player.invincible=10
        g.level.hearts={{x=260,y=g.player.y+12,w=20,h=18,id="smoke-heart"}}
        g.level.grenades={{x=270,y=g.player.y+25,w=14,h=18,id="smoke-grenade"}}
        save.grenades=0; g:update(1/60,{})
        assert(g.player.health==3 and save.grenades==1 and g.level.hearts[1].taken)
    elseif n==432 then
        local g=api.game(); for _=1,32 do g:update(1/60,{}) end
        assert(g.level.enemies[1].state=="dive")
    elseif n==440 then
        love.keypressed("g"); love.keypressed("g",nil,true)
        assert(#api.game().thrownGrenades==1 and save.grenades==0)
    elseif n==448 then
        local g=api.game(); while g.thrownGrenades[1].fuse>.15 do g:update(1/60,{}) end
        local grenade=g.thrownGrenades[1]; grenade.x=300; grenade.y=228; grenade.vx=0; grenade.vy=0
        g.level.enemies={
            {kind="eagle",x=360,y=140,w=40,h=28,hp=2,frozen=4,vx=0},
            {kind="monkey",x=350,y=214,w=26,h=28,hp=1,frozen=4,vx=0},
            {kind="bird",x=410,y=205,w=28,h=20,hp=1,frozen=4,vx=0},
            {kind="icecube",x=370,y=212,w=30,h=30,hp=2,frozen=4,vx=0}}
    elseif n==456 then
        local g=api.game(); while #g.thrownGrenades>0 do g:update(1/60,{}) end
        assert(g.kills==4 and g.player.health==3 and #g.explosions==1)
    elseif n==464 then
        api.view("editor"); app.editor=Editor.new(nil,nil,save.owned)
        love.keypressed("r"); click(176+600*.6,128+160*.6)
        love.keypressed("h"); click(176+200*.6,128+420*.6)
        love.keypressed("g"); click(176+240*.6,128+420*.6)
        app.editor.filename="field-smoke.sidlevel"; assert(app.editor:save())
        local stored=assert(Custom.load(app.editor.filename))
        assert(#stored.hearts==1 and #stored.grenades==1 and stored.enemies[1].kind=="eagle")
    elseif n==480 then love.window.setMode(960,540,{resizable=true,highdpi=true,vsync=1})
    elseif n==488 then checkResolution(api,"window-960")
    elseif n==496 then love.window.setMode(1600,900,{resizable=true,highdpi=true,vsync=1})
    elseif n==504 then checkResolution(api,"window-1600")
    elseif n==512 then love.window.maximize()
    elseif n==520 then checkResolution(api,"window-maximized")
    elseif n==528 then love.window.setFullscreen(true,"desktop")
    elseif n==536 then checkResolution(api,"window-fullscreen")
    elseif n==544 then
        love.window.setFullscreen(false); love.window.setMode(1152,648,{resizable=true,highdpi=true,vsync=1})
    elseif n==552 then api.screenshotDone(); love.event.quit(0)
    end
end
