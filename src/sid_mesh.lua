local Animation=require("src.sid_animation")
local Skin={}
function Skin.new(image,left,top,width,height)
    local columns,rows=32,64
    local tw,th=image:getDimensions()
    local vertices,points,indices={},{},{}
    local aspect=width/height
    local rest=Animation.pose(0,false)
    for row=0,rows do
        for column=0,columns do
            local u,v=column/columns,row/rows
            local x,y=Animation.vertex(u,v,rest,aspect)
            vertices[#vertices+1]={x,y,(left+u*width)/tw,(top+v*height)/th,1,1,1,1}
            points[#points+1]={u,v}
        end
    end
    for row=0,rows-1 do
        for column=0,columns-1 do
            local a=row*(columns+1)+column+1; local b=a+1; local c=a+columns+1; local d=c+1
            for _,index in ipairs({a,c,b,b,c,d}) do indices[#indices+1]=index end
        end
    end
    local mesh=love.graphics.newMesh(vertices,"triangles","stream")
    mesh:setVertexMap(indices); mesh:setTexture(image)
    return setmetatable({mesh=mesh,vertices=vertices,points=points,aspect=aspect},{__index=Skin})
end
function Skin:draw(height,phase)
    if self.phase~=phase then
        local pose=Animation.pose(phase,true)
        for i,point in ipairs(self.points) do
            local x,y=Animation.vertex(point[1],point[2],pose,self.aspect)
            self.vertices[i][1]=x; self.vertices[i][2]=y
        end
        self.mesh:setVertices(self.vertices)
        self.phase=phase
    end
    love.graphics.draw(self.mesh,0,0,0,height,height)
end
return Skin
