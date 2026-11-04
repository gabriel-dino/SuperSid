local Grenades={fuse=3,radius=140,damage=2}
function Grenades.new(player)
    return {x=player.x+player.w/2+player.facing*14,y=player.y+12,w=12,h=14,
        vx=player.facing*245,vy=-245,fuse=3,rotation=0}
end
function Grenades.update(g,dt,level)
    g.fuse=math.max(0,g.fuse-dt)
    g.rotation=g.rotation+g.vx*dt*.035
    local oldX=g.x
    g.x=g.x+g.vx*dt
    if g.x<0 then g.x=0; g.vx=math.abs(g.vx)*.45
    elseif g.x+g.w>level.width then g.x=level.width-g.w; g.vx=-math.abs(g.vx)*.45 end
    for _,p in ipairs(level.platforms) do
        if p.kind=="ground" and g.y+g.h>p.y+1 and g.y<p.y+p.h-1 and
            g.x+g.w>p.x and g.x<p.x+p.w then
            if oldX+g.w<=p.x+1 then g.x=p.x-g.w; g.vx=-math.abs(g.vx)*.45
            elseif oldX>=p.x+p.w-1 then g.x=p.x+p.w; g.vx=math.abs(g.vx)*.45 end
        end
    end
    local top,bottom=g.y,g.y+g.h
    g.vy=g.vy+700*dt; g.y=g.y+g.vy*dt
    local landing,ceiling
    for _,p in ipairs(level.platforms) do
        if g.x+g.w>p.x and g.x<p.x+p.w then
            if g.vy>=0 and bottom<=p.y+1 and g.y+g.h>=p.y then
                if not landing or p.y<landing.y then landing=p end
            elseif g.vy<0 and p.kind=="ground" and top>=p.y+p.h-1 and g.y<=p.y+p.h then
                if not ceiling or p.y+p.h>ceiling.y+ceiling.h then ceiling=p end
            end
        end
    end
    if landing then
        g.y=landing.y-g.h; g.vy=g.vy>110 and -g.vy*.34 or 0
        g.vx=g.vx*math.max(0,1-dt*7)
        if math.abs(g.vx)<8 then g.vx=0 end
    elseif ceiling then g.y=ceiling.y+ceiling.h; g.vy=math.abs(g.vy)*.3 end
    return g.fuse<=.000001
end
function Grenades.hits(x,y,enemy)
    local nearestX=math.max(enemy.x,math.min(x,enemy.x+enemy.w))
    local nearestY=math.max(enemy.y,math.min(y,enemy.y+enemy.h))
    return (nearestX-x)^2+(nearestY-y)^2<=Grenades.radius^2
end
return Grenades
