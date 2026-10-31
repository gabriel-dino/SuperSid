local Deco={}
Deco.packs={
    {id="woodland",name="Woodland",items={"mushroom","fern","flower"}},
    {id="crystals",name="Crystals",items={"crystal","iceflower","sparkle"}},
    {id="trail",name="Trail signs",items={"sign","lantern","banner"}}
}
Deco.sizes={mushroom={32,32},fern={32,32},flower={24,32},crystal={32,48},iceflower={32,32},
    sparkle={24,24},sign={40,40},lantern={24,48},banner={32,48}}
function Deco.packFor(kind)
    for _,pack in ipairs(Deco.packs) do
        for _,id in ipairs(pack.items) do if id==kind then return pack end end
    end
end
function Deco.available(owned)
    local items={}
    for _,pack in ipairs(Deco.packs) do
        if owned and owned["deco_"..pack.id] then for _,id in ipairs(pack.items) do items[#items+1]=id end end
    end
    return items
end
return Deco
