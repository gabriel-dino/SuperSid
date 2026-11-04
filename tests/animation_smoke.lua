local R=require("src.render")
local Shop=require("src.shop")
local Smoke={}
function Smoke.draw(time)
    R.panel("Sid is on the move.","Alternating feet, swinging hands and a moving head. All eight poses use the original character artwork.")
    for i=0,7 do
        local x=80+i*114; local phase=i/8*math.pi*2
        R.rect(x-43,311,86,5,"77976B")
        R.sloth(x,311,145,1,time,{},true,false,phase)
        R.text(string.format("STEP %02d",i+1),x-42,326,11,"718369",84,"center")
    end
    local looks={{hat="tophat",outfit="raincoat",color="ocean",boots="sprint"},
        {hat="flowerhat",color="lavender"},{hat="witch",outfit="scarf",boots="boots"},{hat="crown",gun="turbo"}}
    for i,gear in ipairs(looks) do
        local x=155+(i-1)*220
        R.rect(x-60,485,120,5,"77976B")
        R.sloth(x,485,105,i%2==0 and -1 or 1,time,gear,true,false,time*12)
    end
    R.text("Accessories follow the walk. Left and right use the same animation.",33,514,12,"718369",895,"center")
end
local function capture()
    local canvas=love.graphics.newCanvas(320,240,{dpiscale=1})
    local function frame(phase,moving,time)
        love.graphics.push("all"); love.graphics.setCanvas(canvas); love.graphics.clear()
        R.rect(0,0,320,240,"F4F0E5"); R.text("SID / WALK CYCLE",20,17,14,"718369")
        R.rect(25,216,270,5,"77976B")
        R.sloth(160,216,165,1,time or 0,{},moving,false,phase)
        love.graphics.pop()
        return canvas:newImageData()
    end
    local restA=frame(0,false,0); local restB=frame(0,false,7)
    assert(restA:getString()==restB:getString(),"idle must not shuffle feet or move the head")
    local neutral,stepping
    for i=0,31 do
        local data=frame(i/32*math.pi*2,true)
        data:encode("png",string.format("smoke/walk-%02d.png",i))
        if i==0 then neutral=data elseif i==8 then stepping=data end
    end
    for _,region in ipairs({{140,43,85,64,"head"},{160,130,72,55,"hands"},{115,183,90,34,"feet"}}) do
        local changed=0
        for y=region[2],region[2]+region[4]-1 do
            for x=region[1],region[1]+region[3]-1 do
                local r,g,b=neutral:getPixel(x,y); local r2,g2,b2=stepping:getPixel(x,y)
                if math.abs(r-r2)+math.abs(g-g2)+math.abs(b-b2)>.1 then changed=changed+1 end
            end
        end
        assert(changed>20,"the rendered "..region[5].." must actually animate")
    end
    print("GPU walk check passed: head, hands and feet change independently; idle stays still.")
end
function Smoke.update(n,app,save,api)
    if n==376 then api.view("walk-gallery")
    elseif n==384 then
        capture(); save.coins=2000; app.shopSelection=27; api.view("shop")
    elseif n==392 then
        for i=27,36 do
            app.shopSelection=i; love.keypressed("return")
            if Shop.items[i].kind~="ammo" then assert(save.owned[Shop.items[i].id]) end
        end
        assert(save.equipped.ability=="doublejump" and save.equipped.boots=="sprint" and save.equipped.trail=="comet")
    elseif n==400 then
        app.smokeSit=false; app.smokeWalkRight=true; api.start(1); api.game().level.enemies={}
        api.game().player.x=200
        for _=1,18 do api.game():update(1/60,{right=true}) end
    elseif n==408 then
        local g=api.game(); g:jump(); g:update(1/60,{right=true})
        for _=1,10 do g:update(1/60,{right=true}) end
        g:jump(); g:update(1/60,{right=true})
        assert(g.player.airJumpsUsed==1 and g.player.vy<0)
    elseif n==416 then app.smokeWalkRight=false; api.view("walk-gallery")
    end
end
return Smoke
