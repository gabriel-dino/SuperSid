local Animation={stride=82}
local function smooth(a,b,x)
    local t=math.max(0,math.min(1,(x-a)/(b-a)))
    return t*t*(3-2*t)
end
function Animation.pose(phase,moving)
    local swing=moving and math.sin(phase or 0) or 0
    local bounce=moving and (1-math.cos((phase or 0)*2))*.5 or 0
    return {headAngle=swing*.065,headX=swing*.009,headY=-bounce*.006,bodyY=-bounce*.012,
        farArm=swing*.28,nearArm=-swing*.24,
        farFootX=swing*.066,nearFootX=-swing*.066,
        farFootY=-math.max(0,swing)*.048,nearFootY=-math.max(0,-swing)*.048}
end
local function rotate(x,y,px,py,angle)
    local c,s=math.cos(angle),math.sin(angle)
    local dx,dy=x-px,y-py
    return px+dx*c-dy*s,py+dx*s+dy*c
end
-- Deform a textured mesh in units of character height. Idle is exactly the
-- original sprite; the two feet, two hands and head have independent motion.
function Animation.vertex(u,v,pose,aspect)
    local x,y=(u-.5)*aspect,v-1
    local bodyWeight=1-smooth(.80,.98,v)
    local dx,dy=0,pose.bodyY*bodyWeight
    local headWeight=1-smooth(.24,.46,v)
    if headWeight>0 then
        local hx,hy=rotate(x,y,.04*aspect,-.73,pose.headAngle)
        dx=dx+(hx-x+pose.headX)*headWeight
        dy=dy+(hy-y+pose.headY)*headWeight
    end
    local armWeight=smooth(.43,.70,u)*smooth(.49,.60,v)*(1-smooth(.77,.83,v))
    if armWeight>0 then
        local far=1-smooth(.515+.20*u,.55+.20*u,v)
        local angle=pose.farArm*far+pose.nearArm*(1-far)
        local ax,ay=rotate(x,y,-.08*aspect,-.44,angle)
        dx=dx+(ax-x)*armWeight; dy=dy+(ay-y)*armWeight
    end
    local legWeight=smooth(.80,.96,v)
    if legWeight>0 then
        local near=smooth(.40,.49,u)
        dx=dx+(pose.farFootX*(1-near)+pose.nearFootX*near)*legWeight
        dy=dy+(pose.farFootY*(1-near)+pose.nearFootY*near)*legWeight
    end
    return x+dx,y+dy
end
function Animation.head(pose,height,aspect)
    local x,y=Animation.vertex(.5,0,pose,aspect or .56)
    return x*height,(y+1)*height,pose.headAngle
end
return Animation
