local Shop = {}
Shop.items = {
    {id="ammo",name="Pocket fire",category="SUPPLIES",description="Five more fireballs. Ready to go.",cost=8,kind="ammo",icon="ammo"},
    {id="beanie",name="Cozy beanie",category="HATS",description="A little warmth for a long walk.",cost=18,kind="hat",icon="hat"},
    {id="explorer",name="Trail explorer",category="HATS",description="Adventure looks good on you.",cost=30,kind="hat",icon="hat"},
    {id="mint",name="Mint condition",category="COLORS",description="A fresh coat of forest green.",cost=20,kind="color",icon="color"},
    {id="berry",name="Berry brave",category="COLORS",description="A very sweet shade of purple.",cost=20,kind="color",icon="color"},
    {id="ember",name="Golden hour",category="COLORS",description="Bring your own sunshine.",cost=20,kind="color",icon="color"},
    {id="quick",name="Quick spark",category="BLASTERS",description="Fire every 0.30s instead of 0.55s.",cost=45,kind="gun",icon="gun"},
    {id="turbo",name="Wildfire",category="BLASTERS",description="A speedy 0.16s between shots.",cost=80,kind="gun",icon="gun"},
    {id="spread",name="Triple trouble",category="SPECIAL FIRE",description="Three fireballs for one ammo.",cost=55,kind="special",icon="special"},
    {id="frost",name="Frost spark",category="SPECIAL FIRE",description="Freeze enemies with icy fire.",cost=40,kind="special",icon="special"},
    {id="witch",name="Midnight witch",category="HALLOWEEN",description="A pointy hat. A magical attitude.",cost=35,kind="hat",icon="witch"},
    {id="pumpkin",name="Pumpkin party",category="HALLOWEEN",description="The coziest costume in the patch.",cost=45,kind="outfit",icon="pumpkin"},
    {id="arctic",name="Arctic blue",category="COLORS",description="A cool new look for the summit.",cost=25,kind="color",icon="color"},
    {id="crown",name="Little royalty",category="HATS",description="A golden crown for a small hero.",cost=50,kind="hat",icon="hat"},
    {id="scarf",name="Winter wanderer",category="OUTFITS",description="A long, cozy scarf for snowy days.",cost=30,kind="outfit",icon="scarf"},
    {id="meteor",name="Meteor spark",category="SPECIAL FIRE",description="Double damage. Melt ice in one hit.",cost=65,kind="special",icon="special"},
    {id="pierce",name="Trailblazer",category="SPECIAL FIRE",description="Each fireball hits up to two foes.",cost=60,kind="special",icon="special"},
    {id="boots",name="Spring boots",category="GEAR",description="Jump higher to reach lofty ledges.",cost=55,kind="boots",icon="boots"},
    {id="heart",name="Brave heart",category="CHARMS",description="Start each attempt with 4 hearts.",cost=70,kind="charm",icon="heart"},
    {id="shield",name="Banana umbrella",category="CHARMS",description="Block one banana per attempt.",cost=45,kind="charm",icon="shield"},
}
Shop.pageSize=12
function Shop.page(index) return math.floor((index-1)/Shop.pageSize)+1 end
function Shop.pageCount() return math.ceil(#Shop.items/Shop.pageSize) end
function Shop.equipped(save,item)
    return item.kind~="ammo" and save.equipped[item.kind]==item.id
end
function Shop.buy(save,item)
    if item.kind=="ammo" then
        if save.ammo>=99 then return false,"Your pockets are full." end
        if save.coins<item.cost then return false,"Collect a few more coins first." end
        save.coins=save.coins-item.cost
        save.ammo=math.min(99,save.ammo+5)
        return true,"Five sparks, coming right up!"
    end
    if save.owned[item.id] then
        if Shop.equipped(save,item) then save.equipped[item.kind]=nil
        else save.equipped[item.kind]=item.id end
        return true,Shop.equipped(save,item) and "Looking good, Sid." or "Back to the classics."
    end
    if save.coins<item.cost then return false,"Collect a few more coins first." end
    save.coins=save.coins-item.cost
    save.owned[item.id]=true
    save.equipped[item.kind]=item.id
    return true,"Yours! Equipped and ready."
end
return Shop
