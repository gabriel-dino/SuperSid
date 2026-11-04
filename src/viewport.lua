local Viewport={width=960,height=540}
function Viewport.fit(width,height,pixelWidth,pixelHeight)
    local scale=math.min(width/960,height/540)
    return {scale=scale,x=(width-960*scale)/2,y=(height-540*scale)/2,
        density=math.min((pixelWidth or width)/960,(pixelHeight or height)/540)}
end
function Viewport.toGame(x,y,width,height)
    local view=Viewport.fit(width,height)
    return (x-view.x)/view.scale,(y-view.y)/view.scale
end
return Viewport
