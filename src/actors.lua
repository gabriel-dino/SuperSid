local Actors={}
-- Every character is drawn facing right in local coordinates.
function Actors.facing(velocity,previous)
    if velocity<0 then return -1 elseif velocity>0 then return 1 end
    return previous==-1 and -1 or 1
end
return Actors
