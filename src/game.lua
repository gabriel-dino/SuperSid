local Levels=require("src.levels")
local Actors=require("src.actors")
local Custom=require("src.custom_levels")
local Game={}
Game.__index=Game
local function overlaps(a,b)
    return a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h
end
Game.overlaps=overlaps
function Game.new(save,audio)
    return setmetatable({save=save,audio=audio,time=0,particles={},shots={},camera=0,touch={},jumpBuffer=0},Game)
end
function Game:start(index,retry)
    if self.campaignSave then self.save=self.campaignSave; self.campaignSave=nil end
    self.custom=false; self.sourceCustom=nil
    if not retry and index~=self.save.level then self.save.collected={}; self.save.checkpoint=false end
    self.save.level=index
    self.level=Levels.create(index)
    self:resetPlayer()
end
function Game:startCustom(level,retry)
    local runtime,message=Custom.runtime(level)
    if not runtime then return nil,message end
    if not self.campaignSave then self.campaignSave=self.save end
    if not retry then
        self.save=Custom.copy(self.campaignSave)
        self.save.collected={}; self.save.checkpoint=false
    end
    self.custom=true; self.sourceCustom=Custom.copy(level); self.level=runtime
    self:resetPlayer()
    return true
end
function Game:resetPlayer()
    local maxHealth=self.save.equipped.charm=="heart" and 4 or 3
    self.player={x=self.level.spawn.x,y=self.level.spawn.y,w=23,h=43,vx=0,vy=0,facing=1,health=maxHealth,maxHealth=maxHealth,
        onGround=false,coyote=0,invincible=0,fireTimer=0,sitting=false,
        bananaShield=self.save.equipped.charm=="shield" and 1 or 0}
    if self.save.checkpoint and self.level.checkpoint then
        self.player.x=self.level.checkpoint.x
        self.player.y=self.level.checkpoint.y-10
        self.level.checkpoint.active=true
    end
    self.camera=math.max(0,math.min(self.level.width-960,self.player.x-250))
    self.shots={}; self.enemyShots={}; self.particles={}; self.time=0; self.jumpBuffer=0
    self.finished=false; self.dead=false; self.earned=0; self.kills=0
    self.save.ammo=math.max(5,self.save.ammo)
    for _,e in ipairs(self.level.enemies) do e.facing=Actors.facing(e.vx) end
    for _,items in ipairs({self.level.coins,self.level.ammo}) do
        for _,item in ipairs(items) do item.taken=self.save.collected[item.id]==true end
    end
end
function Game:burst(x,y,color,count)
    for i=1,count or 8 do
        self.particles[#self.particles+1]={x=x,y=y,vx=(i%2==0 and -1 or 1)*(25+i*12),vy=-40-i*13,life=.55,max=.55,color=color}
    end
end
function Game:jump() self.jumpBuffer=.14 end
function Game:shoot()
    local p=self.player
    if p.fireTimer>0 then return end
    if self.save.ammo<=0 then p.fireTimer=.25; self.notice="Out of sparks! Find an ammo pouch or visit the shop."; self.noticeTime=2; return end
    self.save.ammo=self.save.ammo-1
    local gun=self.save.equipped.gun
    p.fireTimer=gun=="turbo" and .16 or gun=="quick" and .3 or .55
    local special=self.save.equipped.special
    local count=special=="spread" and 3 or 1
    for i=1,count do
        self.shots[#self.shots+1]={x=p.x+p.w/2+p.facing*15,y=p.y+14,w=10,h=10,vx=p.facing*400,
            vy=count==3 and (i-2)*105 or 0,life=1.6,frost=special=="frost",meteor=special=="meteor",
            damage=special=="meteor" and 2 or 1,remainingHits=special=="pierce" and 2 or 1,hit={}}
    end
    self.audio.play("shoot")
end
function Game:throwBanana(e)
    if (e.bananasLeft or 0)<=0 then return end
    local facing=Actors.facing(e.vx,e.facing)
    self.enemyShots[#self.enemyShots+1]={x=e.x+e.w/2+facing*17,y=e.y+7,w=12,h=9,
        vx=facing*(160+self.level.index*4),vy=-105,life=2.4,rotation=0}
    e.bananasLeft=e.bananasLeft-1; e.bananasThrown=(e.bananasThrown or 0)+1
    e.throwTimer=e.bananaCooldown or self.level.difficulty.bananaCooldown
end
function Game:hurt()
    local p=self.player
    if p.invincible>0 then return end
    p.health=p.health-1; p.invincible=1.5; p.vy=-220
    self.audio.play("hurt"); self:burst(p.x,p.y,{.8,.28,.2},10)
    if p.health<=0 then self.dead=true end
end
function Game:defeat(e)
    if e.hp<=0 then return end
    e.hp=0; self.kills=self.kills+1
    local reward=e.kind=="bird" and 10 or e.kind=="monkey" and 5 or 0
    self.save.coins=self.save.coins+reward
    self.earned=self.earned+reward
    if reward>0 then self.audio.play("coin") end
end
function Game:update(dt,input)
    if self.dead or self.finished then return end
    dt=math.min(dt,1/30)
    self.time=self.time+dt
    local p=self.player
    p.invincible=math.max(0,p.invincible-dt)
    p.fireTimer=math.max(0,p.fireTimer-dt)
    self.jumpBuffer=math.max(0,self.jumpBuffer-dt)
    self.noticeTime=math.max(0,(self.noticeTime or 0)-dt)
    if p.onGround then p.coyote=.11 else p.coyote=math.max(0,p.coyote-dt) end
    local direction=(input.right and 1 or 0)-(input.left and 1 or 0)
    p.vx=direction*195
    p.facing=Actors.facing(p.vx,p.facing)
    if self.jumpBuffer>0 and p.coyote>0 then
        p.vy=self.save.equipped.boots=="boots" and -575 or -530
        p.onGround=false; p.coyote=0; self.jumpBuffer=0; self.audio.play("jump")
    end
    if input.shoot then self:shoot() end
    p.x=p.x+p.vx*dt
    p.x=math.max(0,math.min(self.level.width-p.w,p.x))
    for _,tile in ipairs(self.level.platforms) do
        if tile.kind=="ground" and overlaps(p,tile) then
            if p.vx>0 then p.x=tile.x-p.w elseif p.vx<0 then p.x=tile.x+tile.w end
        end
    end
    local top=p.y
    local bottom=p.y+p.h
    p.vy=p.vy+1260*dt
    p.y=p.y+p.vy*dt
    p.onGround=false; p.platform=nil
    local landing
    local ceiling
    for _,tile in ipairs(self.level.platforms) do
        if p.vy>=0 and p.x+p.w>tile.x and p.x<tile.x+tile.w and bottom<=tile.y+1 and p.y+p.h>=tile.y then
            if not landing or tile.y<landing.y then landing=tile end
        end
        if p.vy<0 and tile.kind=="ground" and p.x+p.w>tile.x and p.x<tile.x+tile.w and
            top>=tile.y+tile.h-1 and p.y<=tile.y+tile.h then
            if not ceiling or tile.y+tile.h>ceiling.y+ceiling.h then ceiling=tile end
        end
    end
    if landing then p.y=landing.y-p.h; p.vy=0; p.onGround=true; p.platform=landing end
    if ceiling then p.y=ceiling.y+ceiling.h; p.vy=0 end
    p.sitting=input.sit==true and p.onGround and direction==0
    if p.y>590 then p.health=0; self.dead=true; self.audio.play("hurt") end
    for _,coin in ipairs(self.level.coins) do
        if not coin.taken and overlaps(p,coin) then
            coin.taken=true; self.save.collected[coin.id]=true
            self.save.coins=self.save.coins+1; self.earned=self.earned+1
            self.audio.play("coin"); self:burst(coin.x+6,coin.y,{.91,.62,.13},5)
        end
    end
    for _,ammo in ipairs(self.level.ammo) do
        if not ammo.taken and self.save.ammo<99 and overlaps(p,ammo) then
            ammo.taken=true; self.save.collected[ammo.id]=true
            self.save.ammo=math.min(99,self.save.ammo+5); self.audio.play("ammo")
            self.notice="+5 fireballs. Make them count!"; self.noticeTime=2
        end
    end
    for _,e in ipairs(self.level.enemies) do
        if e.hp>0 then
            e.frozen=math.max(0,(e.frozen or 0)-dt)
            if e.frozen==0 then
                -- A short wind-up makes each of the monkey's three throws readable.
                if not e.throwWindup then e.x=e.x+e.vx*dt end
                if e.x<e.min then e.x=e.min; e.vx=math.abs(e.vx)
                elseif e.x+e.w>e.max then e.x=e.max-e.w; e.vx=-math.abs(e.vx) end
                e.facing=Actors.facing(e.vx,e.facing)
                if e.kind=="bird" then e.y=e.homeY+math.sin(self.time*2+e.phase)*24
                elseif e.kind=="snowball" then e.y=e.homeY-math.abs(math.sin(self.time*4+(e.phase or 0)))*17 end
                if e.kind=="monkey" then
                    if e.bananasLeft==nil then e.bananasLeft=3; e.throwTimer=1 end
                    if e.throwWindup then
                        e.throwWindup=e.throwWindup-dt
                        if e.throwWindup<=0 then self:throwBanana(e); e.throwWindup=nil end
                    else
                        e.throwTimer=math.max(0,(e.throwTimer or 0)-dt)
                        local distance=p.x+p.w/2-(e.x+e.w/2)
                        if e.bananasLeft>0 and e.throwTimer==0 and distance*e.facing>35 and
                            math.abs(distance)<330 and math.abs(p.y-e.y)<100 then e.throwWindup=.32 end
                    end
                end
            end
            if overlaps(p,e) then
                if p.vy>50 and bottom<=e.y+12 then
                    self:defeat(e); p.vy=-310; self:burst(e.x,e.y,{.23,.36,.3},8); self.audio.play("hurt")
                else self:hurt() end
            end
        end
    end
    for i=#self.shots,1,-1 do
        local s=self.shots[i]
        s.x=s.x+s.vx*dt; s.y=s.y+s.vy*dt; s.life=s.life-dt
        for _,e in ipairs(self.level.enemies) do
            if e.hp>0 and not s.hit[e] and overlaps(s,e) then
                s.hit[e]=true
                if s.frost and not e.icy and not e.chilled then e.frozen=3; e.chilled=true
                else
                    if e.hp<=s.damage then self:defeat(e)
                    else e.hp=e.hp-s.damage end
                end
                s.remainingHits=s.remainingHits-1
                if s.remainingHits==0 then s.life=0 end
                self:burst(e.x+12,e.y+10,s.frost and {.4,.8,.9} or {.92,.5,.18},8)
                if s.life<=0 then break end
            end
        end
        for _,tile in ipairs(self.level.platforms) do
            if overlaps(s,tile) then s.life=0; break end
        end
        if s.life<=0 then table.remove(self.shots,i) end
    end
    for i=#self.enemyShots,1,-1 do
        local s=self.enemyShots[i]
        s.x=s.x+s.vx*dt; s.y=s.y+s.vy*dt; s.vy=s.vy+330*dt
        s.rotation=s.rotation+dt*9; s.life=s.life-dt
        for _,fire in ipairs(self.shots) do
            if overlaps(s,fire) then s.life=0; self:burst(s.x,s.y,{.93,.72,.2},5); break end
        end
        for _,tile in ipairs(self.level.platforms) do if overlaps(s,tile) then s.life=0; break end end
        if s.life>0 and overlaps(p,s) then
            s.life=0
            if p.bananaShield>0 then
                p.bananaShield=p.bananaShield-1; self:burst(p.x,p.y,{.5,.8,.8},8)
                self.notice="Banana blocked! Your umbrella saved the day."; self.noticeTime=2
            else self:hurt() end
        end
        if s.life<=0 then table.remove(self.enemyShots,i) end
    end
    for i=#self.particles,1,-1 do
        local q=self.particles[i]
        q.life=q.life-dt; q.x=q.x+q.vx*dt; q.y=q.y+q.vy*dt; q.vy=q.vy+380*dt
        if q.life<=0 then table.remove(self.particles,i) end
    end
    local checkpoint=self.level.checkpoint
    if checkpoint and not checkpoint.active and overlaps(p,checkpoint) then
        checkpoint.active=true; self.save.checkpoint=true
        self.notice="Checkpoint! A little closer to home."; self.noticeTime=3
        self.audio.play("ammo")
    end
    if not self.dead and overlaps(p,self.level.goal) then
        self.finished=true; self.audio.play("win")
        if not self.custom then
            self.save.best[self.level.index]=math.max(tonumber(self.save.best[self.level.index]) or 0,self.earned)
            self.save.unlocked=math.max(self.save.unlocked,math.min(Levels.count,self.level.index+1))
            self.save.checkpoint=false; self.save.collected={}
            if self.level.index==Levels.count then self.save.completed=true
            else self.save.level=self.level.index+1 end
        end
    end
    local target=math.max(0,math.min(self.level.width-960,p.x-300))
    self.camera=self.camera+(target-self.camera)*math.min(1,dt*7)
end
return Game
