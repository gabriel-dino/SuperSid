local Actors=require("src.actors")
local Levels=require("src.levels")
local Shop=require("src.shop")
local R={W=960,H=540}
local palettes={
    meadow={sky="F4F0E5",mount="DDE4D6",far="C2D0BB",ground="456A52",edge="77976B",ink="243D35"},
    forest={sky="E9EEE0",mount="CEDCC5",far="A8C0A0",ground="355B46",edge="749165",ink="20392F"},
    ridge={sky="EAF1EF",mount="D7E3DF",far="B8CCC5",ground="4A6D65",edge="85A696",ink="273F3B"},
    night={sky="202F3D",mount="2D4250",far="3C5660",ground="50736A",edge="8BAD8C",ink="EFF0DF"},
    canyon={sky="F4E7CC",mount="E8CCAB",far="D7B090",ground="89644D",edge="BB9266",ink="493D32"},
    halloween={sky="E9DFCB",mount="D3CAB5",far="B9B79C",ground="56604D",edge="A7AB7D",ink="383F32"},
    snow={sky="EDF3F0",mount="DDE7E2",far="C0D5CE",ground="56736E",edge="F9FBEE",ink="2B443D"},
    sunset={sky="F3DFCB",mount="E9C9B2",far="D2B7A2",ground="596954",edge="A6AD7A",ink="3C4536"},
    glacier={sky="E2F0EF",mount="C9DFE3",far="A0C5CF",ground="456B7D",edge="ECF8F3",ink="274A57"},
    blizzard={sky="C5D6DF",mount="ADC5D1",far="88A6BA",ground="3F5970",edge="E4F1F2",ink="263E52"},
    summit={sky="28394E",mount="3E5670",far="526E85",ground="577A91",edge="ECF8F3",ink="E6F1ED"}
}
function R.color(hex,a)
    if type(hex)=="table" then love.graphics.setColor(hex[1],hex[2],hex[3],a or hex[4] or 1)
    else love.graphics.setColor(tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255,a or 1) end
end
function R.rect(x,y,w,h,c,r)
    R.color(c); love.graphics.rectangle("fill",math.floor(x),math.floor(y),w,h,r or 0,r or 0)
end
function R.text(s,x,y,size,c,width,align)
    love.graphics.setFont(R.fonts[size] or R.fonts[16]); R.color(c or "243D35")
    if width then love.graphics.printf(s,math.floor(x),math.floor(y),width,align or "left")
    else love.graphics.print(s,math.floor(x),math.floor(y)) end
end
function R.load()
    R.fonts={}; R.fallbacks={}
    for _,size in ipairs({10,11,12,13,14,16,18,20,24,28,32,38,48,64,88}) do
        R.fonts[size]=love.graphics.newFont(size)
        if love.filesystem.getInfo("assets/DejaVuSans.ttf") then
            R.fallbacks[size]=love.graphics.newFont("assets/DejaVuSans.ttf",size)
            R.fonts[size]:setFallbacks(R.fallbacks[size])
        end
    end
    if love.filesystem.getInfo("assets/sid.png") then
        local data=love.image.newImageData("assets/sid.png")
        R.sprite=love.graphics.newImage(data); R.sprite:setFilter("nearest","nearest")
        local minX,minY,maxX,maxY=data:getWidth(),data:getHeight(),0,0
        for y=0,data:getHeight()-1 do
            for x=0,data:getWidth()-1 do
                local _,_,_,a=data:getPixel(x,y)
                if a>.15 then minX=math.min(minX,x); minY=math.min(minY,y); maxX=math.max(maxX,x); maxY=math.max(maxY,y) end
            end
        end
        if maxX>minX and maxY>minY then
            R.spriteW=maxX-minX+1; R.spriteH=maxY-minY+1
            R.quad=love.graphics.newQuad(minX,minY,R.spriteW,R.spriteH,data:getWidth(),data:getHeight())
        else R.sprite=nil end
    end
end
function R.cloud(x,y,scale,color)
    love.graphics.push(); love.graphics.translate(math.floor(x),math.floor(y)); love.graphics.scale(scale)
    R.rect(0,8,60,12,color); R.rect(10,0,22,12,color); R.rect(30,4,20,12,color)
    love.graphics.pop()
end
function R.background(biome,camera,time)
    local p=palettes[biome] or palettes.meadow
    R.rect(0,0,960,540,p.sky)
    R.rect(773-camera*.025,99,47,47,biome=="night" and "ECE8CC" or "E6B562")
    for i=-1,6 do
        local x=i*230-(camera*.08)%230
        R.cloud(x,95+(i%3)*38,1.2,p.mount)
    end
    for layer=1,2 do
        local speed=layer==1 and .12 or .24
        local col=layer==1 and p.mount or p.far
        for i=-1,7 do
            local x=i*190-(camera*speed)%190
            local y=layer==1 and 230+(i%3)*25 or 305+(i%2)*23
            R.rect(x,y+60,200,260,col)
            R.rect(x+20,y+35,160,60,col)
            R.rect(x+45,y+15,110,40,col)
            R.rect(x+75,y,50,25,col)
        end
    end
    if biome=="night" or biome=="summit" then
        for i=1,28 do R.rect((i*137)%960,(i*53)%230,2,2,"ECE8CC",0) end
    elseif biome=="snow" or biome=="glacier" or biome=="blizzard" then
        local windy=biome=="blizzard"
        for i=1,windy and 55 or 25 do R.rect((i*139+time*(windy and 86 or 12))%960,(i*67+time*24)%540,windy and 6 or 3,3,"FFFFFF") end
    end
    return p
end
function R.sloth(x,y,height,facing,time,equipped,moving,sitting)
    equipped=equipped or {}
    local tint=equipped.color=="mint" and "90C9A2" or equipped.color=="berry" and "BE9ABC" or equipped.color=="ember" and "E7B65B" or equipped.color=="arctic" and "91CFDF" or "FFFFFF"
    love.graphics.push(); love.graphics.translate(math.floor(x),math.floor(y))
    -- Animate around the feet so standing or sitting never lifts Sid off a platform.
    love.graphics.scale(Actors.facing(0,facing),sitting and .72 or moving and (1+math.sin(time*15)*.018) or 1)
    if R.sprite then
        R.color(tint)
        local scale=height/R.spriteH
        love.graphics.draw(R.sprite,R.quad,-R.spriteW*scale/2,-height,0,scale,scale)
    else
        -- Also keeps development checkouts playable before art is available.
        local scale=height/58
        love.graphics.push(); love.graphics.scale(scale)
        R.rect(-12,-31,23,24,"B7AA8A"); R.rect(-5,-48,10,28,"B7AA8A")
        R.rect(-8,-58,24,18,"D5C9A9"); R.rect(8,-51,12,7,"483E32")
        R.rect(-5,-57,6,6,"FFFFFF"); R.rect(9,-58,6,6,"FFFFFF")
        R.rect(-2,-55,3,3,"243D35"); R.rect(12,-56,3,3,"243D35")
        R.rect(-10,-10,6,10,"B7AA8A"); R.rect(6,-10,6,10,"B7AA8A")
        R.rect(-19,-29,8,5,"B7AA8A"); R.rect(10,-30,12,5,"B7AA8A")
        love.graphics.pop()
    end
    local h=height
    if equipped.outfit=="pumpkin" then
        R.rect(-h*.19,-h*.48,h*.4,h*.3,"D98A37",3)
        R.rect(-h*.1,-h*.43,4,4,"4C4632"); R.rect(h*.1,-h*.43,4,4,"4C4632")
        R.rect(-h*.07,-h*.34,h*.17,3,"4C4632")
    elseif equipped.outfit=="scarf" then
        R.rect(-h*.12,-h*.71,h*.3,h*.075,"BC6C57")
        R.rect(-h*.18,-h*.67,h*.1,h*.25,"BC6C57")
        R.rect(-h*.18,-h*.44,h*.1,h*.035,"E4BB80")
    end
    if equipped.boots=="boots" then
        R.rect(-h*.18,-h*.06,h*.17,h*.06,"B99143")
        R.rect(h*.05,-h*.06,h*.2,h*.06,"B99143")
    end
    if equipped.gun then
        R.rect(h*.12,-h*.4,h*.32,h*.08,"435449")
        R.rect(h*.2,-h*.33,h*.07,h*.1,"6F7052")
        R.rect(h*.39,-h*.4,h*.06,h*.08,equipped.gun=="turbo" and "D6A34A" or "A5B191")
    end
    if equipped.hat=="beanie" then
        R.rect(-h*.17,-h-2,h*.36,h*.12,"BE7358"); R.rect(-h*.21,-h+h*.09,h*.44,h*.06,"875242")
        R.rect(-3,-h-h*.07,8,8,"BE7358")
    elseif equipped.hat=="explorer" then
        R.rect(-h*.17,-h,h*.33,h*.13,"B29458"); R.rect(-h*.28,-h+h*.12,h*.59,h*.06,"806C44")
    elseif equipped.hat=="witch" then
        R.color("493E59"); love.graphics.polygon("fill",-h*.22,-h+h*.1,h*.03,-h-h*.35,h*.2,-h+h*.1)
        R.rect(-h*.3,-h+h*.08,h*.62,h*.07,"493E59"); R.rect(-h*.15,-h,h*.29,h*.06,"D9A544")
    elseif equipped.hat=="crown" then
        R.rect(-h*.2,-h,h*.42,h*.1,"D7AA44")
        for i=0,2 do R.rect(-h*.2+i*h*.17,-h-h*.09,h*.08,h*.12,"D7AA44") end
        R.rect(-h*.04,-h+h*.025,h*.06,h*.05,"BC6C57")
    end
    love.graphics.pop()
end
function R.coin(x,y,time,scale)
    scale=scale or 1
    love.graphics.push(); love.graphics.translate(math.floor(x),math.floor(y)); love.graphics.scale(scale)
    local width=8+math.abs(math.cos(time*3))*4
    R.rect(-width/2,-7,width,14,"C99532"); R.rect(-width/2+2,-5,math.max(2,width-4),10,"F1C965")
    R.rect(-1,-3,2,6,"B78129"); love.graphics.pop()
end
function R.enemy(e,time)
    if e.hp<=0 then return end
    local facing=Actors.facing(e.vx,e.facing)
    love.graphics.push()
    love.graphics.translate(math.floor(e.x)+(facing==-1 and e.w or 0),math.floor(e.y))
    love.graphics.scale(facing,1)
    local x,y=0,0
    local c=(e.frozen or 0)>0 and "8FC6CD" or "705C48"
    if e.kind=="monkey" then
        R.rect(x+4,y+8,19,15,c); R.rect(x+7,y,18,13,c)
        R.rect(x+11,y+4,14,8,"D1B98D"); R.rect(x+20,y+3,3,3,"253B33")
        local step=math.sin(time*10)*3
        R.rect(x+3,y+20+math.max(0,step),6,8-math.max(0,step),c)
        R.rect(x+17,y+20+math.max(0,-step),6,8-math.max(0,-step),c)
        R.rect(x-5,y+7,5,15,c); R.rect(x-2,y+18,9,4,c)
        if e.throwWindup then
            R.rect(x+20,y-6,5,14,c); R.rect(x+23,y-8,9,4,"E2BA4D")
        end
        for i=1,e.bananasLeft or 0 do R.rect(5+(i-1)*7,-7,4,3,"D6AD42") end
    elseif e.kind=="bird" then
        R.rect(x+6,y+6,19,10,c); R.rect(x+21,y+3,9,10,c)
        R.rect(x+27,y+8,7,4,"C59840"); R.rect(x+25,y+5,2,2,"F4F0E5")
        local flap=math.sin(time*12)>0
        R.rect(x+7,y+(flap and -5 or 12),12,10,c); R.rect(x,y+8,8,5,c)
    elseif e.kind=="icecube" then
        R.rect(1,0,28,30,"547E95",2); R.rect(3,2,24,25,"A3D4DF")
        R.rect(5,4,6,11,"D8F0F0"); R.rect(7,23,18,3,"77B4CA")
        R.rect(12,8,6,8,"F5FCF7"); R.rect(21,8,6,8,"F5FCF7")
        R.rect(15,10,3,5,"294759"); R.rect(24,10,3,5,"294759")
        R.rect(16,20,7,2,"547E95")
        local wave=math.sin(time*7)>0 and 0 or 3
        R.rect(-5,12+wave,7,4,"77B4CA"); R.rect(-9,10+wave,5,9,"BCE6EA")
        R.rect(28,13-wave,7,4,"77B4CA"); R.rect(34,10-wave,5,9,"BCE6EA")
        if e.hp>1 then R.rect(10,-5,10,2,"77B4CA") end
    elseif e.kind=="snowball" then
        R.rect(5,0,14,24,"B0CDD9"); R.rect(0,5,24,14,"B0CDD9")
        R.rect(3,4,18,16,"F5FCF7"); R.rect(6,2,12,20,"F5FCF7")
        R.rect(6,5,5,3,"FFFFFF"); R.rect(12,8,3,5,"294759"); R.rect(19,8,3,5,"294759")
        R.rect(15,16,5,2,"95B7C7")
    end
    love.graphics.pop()
end
function R.decoration(d,time)
    local x,y=d.x,d.y
    if d.kind=="mushroom" then
        R.rect(x+12,y+16,8,16,"DCCDA6"); R.rect(x+3,y+9,26,12,"BC6C57",3)
        R.rect(x+8,y+3,16,10,"BC6C57",3); R.rect(x+8,y+11,5,4,"FFF3D3"); R.rect(x+21,y+8,4,4,"FFF3D3")
    elseif d.kind=="fern" then
        R.rect(x+15,y+4,3,28,"456A52")
        for i=0,3 do R.rect(x+3+i*3,y+6+i*6,13-i*2,4,"77976B"); R.rect(x+18,y+7+i*6,12-i*2,4,"84A073") end
    elseif d.kind=="flower" or d.kind=="iceflower" then
        local ice=d.kind=="iceflower"; local center=ice and 16 or 12
        R.rect(x+center-1,y+14,3,18,ice and "77B4CA" or "77976B")
        for _,offset in ipairs({{-9,6},{5,6},{-2,0},{-2,12}}) do R.rect(x+center+offset[1],y+offset[2],8,8,ice and "D8F0F0" or "BE9ABC",2) end
        R.rect(x+center-2,y+7,7,7,"E6B562",2)
    elseif d.kind=="crystal" then
        R.color("77B4CA"); love.graphics.polygon("fill",x+16,y,x+28,y+15,x+25,y+44,x+9,y+48,x+4,y+17)
        R.color("D8F0F0"); love.graphics.polygon("fill",x+16,y+3,x+16,y+41,x+9,y+43,x+8,y+17)
        R.rect(x+23,y+27,8,17,"91CFDF")
    elseif d.kind=="sparkle" then
        local color=math.sin(time*3+x)>.2 and "FFF3D3" or "D6A34A"
        R.rect(x+10,y,4,24,color); R.rect(x,y+10,24,4,color); R.rect(x+6,y+6,12,12,color)
    elseif d.kind=="sign" then
        R.rect(x+16,y+14,5,26,"806C44"); R.rect(x,y+2,36,20,"B29458",2)
        R.rect(x+8,y+10,15,4,"FFF3D3"); R.color("FFF3D3"); love.graphics.polygon("fill",x+22,y+6,x+29,y+12,x+22,y+18)
    elseif d.kind=="lantern" then
        R.rect(x+10,y,4,48,"806C44"); R.rect(x+2,y+2,20,4,"806C44")
        R.rect(x+1,y+9,22,25,"76613F",3); R.rect(x+5,y+12,14,19,"E6B562",3)
        R.rect(x+9,y+16,6,11,"FFF3D3",2)
    elseif d.kind=="banner" then
        R.rect(x+2,y,4,48,"806C44"); R.rect(x+6,y+2,25,27,"BE7358")
        R.rect(x+14,y+8,9,12,"F1C965"); R.rect(x+10,y+12,17,4,"F1C965")
    end
end
function R.companion(x,y,facing,time)
    love.graphics.push(); love.graphics.translate(math.floor(x),math.floor(y)); love.graphics.scale(facing,1)
    R.rect(-9,2,17,13,"E6B562",3); R.rect(-2,-4,13,14,"F1C965",3)
    R.rect(6,-1,3,3,"243D35"); R.rect(10,3,6,4,"CC7B3B")
    R.rect(-8,math.sin(time*10)>0 and 0 or 6,8,7,"D6A34A",2)
    R.rect(-5,15,5,3,"CC7B3B"); R.rect(3,15,5,3,"CC7B3B")
    love.graphics.pop()
end
function R.world(game,save)
    local p=R.background(game.level.biome,game.camera,game.time)
    love.graphics.push(); love.graphics.translate(-math.floor(game.camera),0)
    for _,tile in ipairs(game.level.platforms) do
        if tile.x+tile.w>game.camera-30 and tile.x<game.camera+990 then
            R.rect(tile.x,tile.y,tile.w,tile.h,p.ground)
            R.rect(tile.x,tile.y,tile.w,7,p.edge)
            if tile.kind=="ground" then
                for i=1,math.floor(tile.w/39) do
                    R.rect(tile.x+i*37,tile.y+22+(i%3)*17,7,3,p.edge)
                end
            else
                R.rect(tile.x+8,tile.y+15,tile.w-16,4,p.far)
            end
        end
    end
    for _,d in ipairs(game.level.decorations) do
        if d.x>game.camera-20 and d.x<game.camera+980 then
            if d.kind then R.decoration(d,game.time)
            elseif game.level.biome=="halloween" and d.variant%2==0 then
                R.rect(d.x,d.y-17,21,16,"CC8A43",3); R.rect(d.x+9,d.y-22,4,6,p.ground)
                R.rect(d.x+4,d.y-12,4,4,"3A4335"); R.rect(d.x+14,d.y-12,4,4,"3A4335")
            else
                R.rect(d.x,d.y-13,3,13,p.edge); R.rect(d.x-5,d.y-9,5,3,p.edge); R.rect(d.x+3,d.y-12,5,3,p.edge)
            end
        end
    end
    for _,coin in ipairs(game.level.coins) do
        if not coin.taken and math.abs(coin.x-game.camera-480)<510 then R.coin(coin.x+6,coin.y+8,game.time+coin.x) end
    end
    for _,a in ipairs(game.level.ammo) do
        if not a.taken then
            R.rect(a.x,a.y+3+math.sin(game.time*3)*2,18,18,"C38746",3)
            R.rect(a.x+4,a.y-1+math.sin(game.time*3)*2,10,6,"76613F")
            R.text("+",a.x+4,a.y+3+math.sin(game.time*3)*2,14,"FFF3D3")
        end
    end
    local cp=game.level.checkpoint
    if cp then
        R.rect(cp.x,cp.y,3,60,p.ink)
        R.rect(cp.x+3,cp.y,25,17,cp.active and "DBAB4F" or p.far)
    end
    local goal=game.level.goal
    R.rect(goal.x+16,goal.y,4,92,p.ink)
    R.rect(goal.x+20,goal.y,39,26,"D9AB4F")
    R.rect(goal.x+24,goal.y+5,8,8,"F9F2DE"); R.rect(goal.x+40,goal.y+13,8,8,"F9F2DE")
    R.rect(goal.x+7,goal.y+89,24,4,p.ink)
    for _,e in ipairs(game.level.enemies) do if math.abs(e.x-game.camera-480)<550 then R.enemy(e,game.time) end end
    local player=game.player
    if save.equipped.companion=="chick" then R.companion(game.companion.x,game.companion.y,player.facing,game.time) end
    if player.gliding then
        local cx=player.x+player.w/2; local y=player.y-46
        R.rect(cx-28,y+9,56,10,"77976B",3); R.rect(cx-20,y,40,14,"84A073",3)
        R.rect(cx-7,y-5,14,16,"A8C0A0",2)
        R.color("806C44"); love.graphics.setLineWidth(2)
        love.graphics.line(cx-25,y+18,cx-8,player.y+18); love.graphics.line(cx+25,y+18,cx+8,player.y+18)
    end
    if player.invincible==0 or math.floor(player.invincible*12)%2==0 then
        R.sloth(player.x+player.w/2,player.y+player.h,61,player.facing,game.time,save.equipped,player.onGround and player.vx~=0,player.sitting)
    end
    for _,s in ipairs(game.shots) do
        R.rect(s.x-5*(s.vx>0 and 1 or -1),s.y+2,9,6,s.frost and "D1EAE5" or "EDC05F")
        R.rect(s.x,s.y,10,10,s.frost and "8BC5CC" or s.meteor and "BA4A30" or "CB6F32",2)
        R.rect(s.x+3,s.y+3,4,4,"FFF0C0")
    end
    for _,banana in ipairs(game.enemyShots) do
        love.graphics.push(); love.graphics.translate(banana.x+6,banana.y+4); love.graphics.rotate(banana.rotation)
        R.rect(-6,-4,3,7,"E8BC47"); R.rect(-4,1,9,4,"E8BC47"); R.rect(3,-2,3,5,"E8BC47")
        R.rect(-6,-5,3,2,"76663E"); R.rect(-2,2,5,1,"FFF0AE")
        love.graphics.pop()
    end
    for _,q in ipairs(game.particles) do R.rect(q.x,q.y,3,3,q.color) end
    love.graphics.pop()
    -- HUD stays readable in every biome.
    R.rect(20,18,920,62,"FBF8EE",10)
    R.rect(37,33,36,32,"E8EDDE",5)
    R.text(game.custom and "C" or string.format("%02d",game.level.index),41,35,20)
    love.graphics.setScissor(85,23,335,29)
    R.text(game.level.name,85,29,18)
    love.graphics.setScissor()
    R.text(game.custom and "CONTRIB LEVEL / PRACTICE COINS" or "THE GREAT LITTLE ADVENTURE",86,53,10,"7D8C7E")
    for i=1,player.maxHealth do
        local x=435+(i-1)*21
        local col=i<=player.health and "BE7257" or "E0DFD1"
        R.rect(x,39,7,7,col); R.rect(x+8,39,7,7,col); R.rect(x+2,43,11,8,col); R.rect(x+5,51,5,4,col)
    end
    if player.bananaShield>0 then R.text("SHIELD",437,60,10,"6A9CA6") end
    R.coin(548,48,game.time,1.1); R.text(tostring(save.coins),562,36,20)
    R.rect(637,41,10,15,"CC7B3B"); R.text(string.format("%02d",save.ammo),658,36,20)
    R.rect(733,44,86,5,"E3E6D8"); R.rect(733,44,86*math.min(1,player.x/game.level.width),5,"75916E")
    if save.equipped.magnet=="magnet" then
        R.rect(21,86,132,22,"FBF8EE",4)
        R.text("MAGNET  "..math.ceil(player.magnetTime).."s",31,90,11,"8C783F")
    end
    if game.noticeTime and game.noticeTime>0 then
        R.rect(190,99,580,32,"FBF8EE",6); R.text(game.notice,200,107,13,"516950",560,"center")
    end
    R.rect(0,505,960,35,p.sky)
    R.text(game.custom and "A D / ARROWS   WALK      SPACE   JUMP      S / DOWN   SIT      ALT / X   FIRE      ESC   PAUSE" or
        "A D / ARROWS   WALK      SPACE   JUMP      S / DOWN   SIT      ALT / X   FIRE      B   SHOP      ESC   PAUSE",20,516,11,p.ink,920,"center")
end
function R.button(button,hover,focus)
    local active=hover or focus
    R.rect(button.x,button.y,button.w,button.h,button.disabled and "DADFD0" or active and "DDAE52" or button.secondary and "E4E8D9" or "355B46",6)
    R.text(button.label,button.x,button.y+(button.h-18)/2-1,16,button.disabled and "87947F" or active and "243D35" or button.secondary and "355B46" or "FBF8EE",button.w,"center")
end
function R.menu(save,time)
    R.background("meadow",time*7,time)
    R.rect(0,457,960,83,"456A52"); R.rect(0,457,960,7,"84A073")
    R.text("HERO  /  A GABRIEL DINO GAME",48,35,12,"697E69")
    R.rect(49,110,83,4,"D6A34A")
    R.text("SUPER",44,136,38)
    R.text("SID",40,165,88)
    R.text("Small steps. A great big adventure.",49,278,20)
    R.text(Levels.count.." trails. A pocketful of sparks.\nOne very determined sloth.",50,316,16,"697E69")
    R.rect(622,360,230,97,"456A52"); R.rect(622,360,230,7,"84A073")
    R.rect(578,393,44,64,"456A52"); R.rect(578,393,44,7,"84A073")
    R.sloth(730,361,179,1,time,save.equipped,true)
    for i=1,3 do R.coin(810+i*35,283-i*14,time+i,1.4) end
    R.rect(840,362,18,16,"C68A45",3); R.rect(845,357,7,7,"6C7148")
    R.text("TAKE YOUR TIME. SAVE THE DAY.",48,492,11,"D8E2C8")
    R.text(Levels.count.." LEVELS  /  AUTO-SAVED  /  MADE WITH LOVE",480,492,11,"D8E2C8",432,"right")
    R.rect(764,30,148,32,"FBF8EE",5); R.coin(782,46,time); R.text(save.coins.." coins",799,37,14)
end
function R.panel(title,subtitle)
    R.rect(0,0,960,540,"F4F0E5")
    R.text("HERO / SUPER SID",32,24,11,"7D8C7E")
    R.text(title,32,51,32)
    R.text(subtitle,33,94,13,"768770")
end
function R.shop(save,items,selected,time,message)
    R.panel("A little something for the trail.","Buy once, wear forever. Select an owned item to equip or take it off.")
    R.rect(762,48,166,38,"E4E8D9",6); R.coin(784,67,time); R.text(save.coins.." coins",805,56,18)
    local page=Shop.page(selected)
    local first=(page-1)*Shop.pageSize+1
    for i=first,math.min(#items,first+Shop.pageSize-1) do
        local item=items[i]
        local col=(i-first)%4; local row=math.floor((i-first)/4)
        local x,y=32+col*230,133+row*115
        local chosen=selected==i
        R.rect(x,y,214,103,chosen and "E0E7D5" or "FBF8EE",7)
        if chosen then R.rect(x,y,3,103,"75916E") end
        local equipped=Shop.equipped(save,item)
        R.text(item.category,x+12,y+10,10,"819071")
        R.text(item.name,x+12,y+26,18)
        R.text(item.description,x+12,y+51,11,"74816D",188)
        local label=item.kind=="decoration" and save.owned[item.id] and "UNLOCKED / EDITOR" or equipped and "EQUIPPED" or save.owned[item.id] and "OWNED / EQUIP" or item.cost.." COINS"
        R.text(label,x+12,y+82,11,equipped and "567653" or "B18736")
    end
    R.text(message or "ARROWS  SELECT    ENTER  BUY / EQUIP\nPGUP / PGDN  MORE FINDS    ESC  BACK",33,486,11,"6B7F66",550)
    R.text(page.." / "..Shop.pageCount(),649,492,12,"6B7F66",50,"center")
end
function R.routeCard(index)
    return {x=32+((index-1)%5)*181,y=133+math.floor((index-1)/5)*65,w=169,h=60}
end
function R.route(save,names,time)
    R.panel("Every adventure starts with a step.","Follow Sid's trail. Finish each level to unlock the next.")
    for i,name in ipairs(names) do
        local card=R.routeCard(i)
        local x,y=card.x,card.y
        local unlocked=i<=save.unlocked
        R.rect(x,y,card.w,card.h,unlocked and "E4E8D9" or "EAE8DD",6)
        R.text(string.format("%02d",i),x+8,y+7,14,unlocked and "456A52" or "B8BEAE")
        R.text(name,x+35,y+7,13,unlocked and "243D35" or "9DA692",126)
        R.text(not unlocked and "LOCKED" or (i<save.unlocked or save.completed and i==Levels.count) and "COMPLETED" or "READY TO EXPLORE",x+8,y+44,10,"819071")
    end
end
return R
