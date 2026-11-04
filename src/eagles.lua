local Eagles={width=40,height=28}
local function clamp(x,lo,hi) return math.max(lo,math.min(hi,x)) end
function Eagles.new(x,y,min,max,speed,phase)
    return {kind="eagle",x=x,y=y,w=40,h=28,min=min,max=max,vx=speed,hp=2,
        homeY=y,phase=phase or 0,attackTimer=1.6,state="patrol"}
end
function Eagles.update(e,dt,time,player)
    if e.state=="windup" then
        e.windup=e.windup-dt
        if e.windup<=0 then
            e.state="dive"; e.diveTime=0; e.startX=e.x; e.startY=e.y
            e.targetX=clamp(player.x+player.w/2-e.w/2,e.min,e.max-e.w)
            e.targetY=clamp(player.y+8,e.homeY,290)
            e.facing=e.targetX>=e.x and 1 or -1
        end
    elseif e.state=="dive" then
        e.diveTime=e.diveTime+dt
        local t=math.min(1,e.diveTime/1.2)
        e.x=clamp(e.startX+(e.targetX-e.startX)*math.min(1,t*2)+
            e.facing*math.abs(e.vx)*math.max(0,t-.5)*.4,e.min,e.max-e.w)
        e.y=e.startY+(e.targetY-e.startY)*math.sin(t*math.pi)
        if t>=1 then e.state="patrol"; e.attackTimer=2.2; e.vx=e.facing*math.abs(e.vx) end
    else
        e.state="patrol"; e.x=e.x+e.vx*dt
        if e.x<e.min then e.x=e.min; e.vx=math.abs(e.vx)
        elseif e.x+e.w>e.max then e.x=e.max-e.w; e.vx=-math.abs(e.vx) end
        e.facing=e.vx>=0 and 1 or -1
        e.y=e.homeY+math.sin(time*2+(e.phase or 0))*10
        e.attackTimer=math.max(0,(e.attackTimer or 1.6)-dt)
        if e.attackTimer==0 and player.y+player.h<320 and math.abs(player.x-e.x)<250 then
            e.state="windup"; e.windup=.5
        end
    end
end
return Eagles
