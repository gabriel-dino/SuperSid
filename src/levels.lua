local Levels = {}
Levels.names = {
    "A slow beginning", "Fernwood trail", "The broken bridge", "Cloudberry cliffs",
    "Monkey business", "Moonlit marsh", "The amber canyon", "Pumpkin hollow",
    "Frostbite ridge", "The last little leap", "Icebox foothills", "Snowball scramble",
    "Glacier gauntlet", "Blizzard crossing", "The frozen summit"
}
Levels.count=#Levels.names
Levels.biomes = {"meadow", "forest", "meadow", "ridge", "forest", "night", "canyon", "halloween", "snow", "sunset",
    "snow", "snow", "glacier", "blizzard", "summit"}

function Levels.difficulty(index)
    local extra=math.max(0,index-10)
    return {gap=68+math.min(30,index*3)+extra*4,groundShrink=extra*22,
        speed=37+index*3+extra*4,bananaCooldown=math.max(.95,2.4-index*.08),
        iceCubes=extra>0 and 1 or 0,snowballs=extra>=2 and (extra>=4 and 2 or 1) or 0,
        extraBird=extra>=3}
end

function Levels.create(index)
    assert(index >= 1 and index <= Levels.count, "Level must be between 1 and "..Levels.count)
    local difficulty=Levels.difficulty(index)
    local level = {index=index, name=Levels.names[index], biome=Levels.biomes[index],
        width=2700 + index*210, height=540, platforms={}, coins={}, ammo={}, enemies={}, decorations={},difficulty=difficulty}
    local id = 0
    local sections = {}
    local function platform(x,y,w,h,kind)
        local p = {x=x,y=y,w=w,h=h or 110,kind=kind or "ground"}
        table.insert(level.platforms,p)
        return p
    end
    local function coin(x,y)
        id=id+1
        table.insert(level.coins,{x=x,y=y,w=12,h=16,id="coin"..id})
    end
    local x, section = 0, 0
    while x < level.width do
        section=section+1
        local width = section == 1 and 610 or (390 + (section*73 + index*29)%160-difficulty.groundShrink)
        width=math.min(width,level.width-x)
        local y = 426 - ((section+index)%3)*14
        if section==1 then y=426 end
        if level.width - (x+width) < 240 then width=level.width-x end
        local ground=platform(x,y,width,540-y)
        ground.tier=0
        local route={ground=ground}
        sections[#sections+1]=route
        for cx=x+100,x+width-40,62 do coin(cx,y-38) end
        if width>310 then
            local upper=platform(x+math.min(150,width-180),y-96,132-math.max(0,index-10)*5,15,"ledge")
            upper.tier=1; upper.stepFrom=ground; route.lower=upper
            for cx=upper.x+16,upper.x+upper.w-10,32 do coin(cx,upper.y-30) end
            table.insert(level.ammo,{x=x+width-80,y=y-25,w=18,h=22,id="ammo"..section})
        end
        if section>1 then
            table.insert(level.enemies,{kind="monkey",x=x+width-150,y=y-28,w=26,h=28,
                min=x+35,max=x+width-35,vx=-difficulty.speed,hp=1,homeY=y-28,
                bananasLeft=3,bananasThrown=0,throwTimer=1,bananaCooldown=difficulty.bananaCooldown})
            if difficulty.iceCubes>0 then
                table.insert(level.enemies,{kind="icecube",x=x+70,y=y-30,w=30,h=30,
                    min=x+20,max=x+width-20,vx=difficulty.speed*.75,hp=2,homeY=y-30,icy=true})
            end
            for n=1,difficulty.snowballs do
                table.insert(level.enemies,{kind="snowball",x=x+width*.5+(n-1)*66,y=y-24,w=24,h=24,
                    min=x+20,max=x+width-20,vx=(n%2==0 and -1 or 1)*(difficulty.speed+28),hp=1,homeY=y-24,icy=true,phase=n+section})
            end
        end
        if section%2==0 or difficulty.extraBird and section>1 then
            table.insert(level.enemies,{kind="bird",x=x+100,y=y-95,w=28,h=20,
                min=x+20,max=x+width-20,vx=48+index*3,hp=1,homeY=y-95,phase=section})
        end
        for dx=x+35,x+width-20,100 do
            table.insert(level.decorations,{x=dx,y=y,variant=(section+math.floor(dx))%4})
        end
        x=x+width
        if x<level.width then x=x+difficulty.gap end
    end
    -- Keep the original pickup IDs stable for campaigns already in progress.
    -- Add the new routes after the original terrain and pickups are generated.
    for _,route in ipairs(sections) do
        local ground=route.ground
        local lower=route.lower
        if not lower then
            lower=platform(ground.x+math.min(150,ground.w-180),ground.y-96,
                132-math.max(0,index-10)*5,15,"ledge")
            lower.tier=1; lower.stepFrom=ground
            for cx=lower.x+16,lower.x+lower.w-10,32 do coin(cx,lower.y-30) end
        end
        -- An 88-pixel rise is reachable without buying spring boots.
        local upperWidth=156-math.max(0,index-10)*4
        local upper=platform(math.min(lower.x+92,ground.x+ground.w-upperWidth-20),
            lower.y-88,upperWidth,15,"ledge")
        upper.tier=2; upper.stepFrom=lower
        for cx=upper.x+16,upper.x+upper.w-10,32 do coin(cx,upper.y-30) end
        -- Wider islands get a second step for descending or climbing from the right.
        local descentX=ground.x+ground.w-140
        if descentX>=lower.x+lower.w+32 then
            local descent=platform(descentX,lower.y,math.min(120,lower.w),15,"ledge")
            descent.tier=1; descent.stepFrom=ground
            for cx=descent.x+16,descent.x+descent.w-10,32 do coin(cx,descent.y-30) end
        end
    end
    local last=level.platforms[#level.platforms]
    -- Locate the final ground, since decorative ledges are also platforms.
    for _,p in ipairs(level.platforms) do
        if p.kind=="ground" then last=p end
    end
    level.goal={x=level.width-100,y=last.y-92,w=42,h=92}
    local checkpointGround=level.platforms[1]
    for _,p in ipairs(level.platforms) do
        if p.kind=="ground" and p.x<level.width*.55 then checkpointGround=p end
    end
    level.checkpoint={x=checkpointGround.x+50,y=checkpointGround.y-60,w=18,h=60,active=false}
    level.spawn={x=55,y=350}
    return level
end
return Levels
