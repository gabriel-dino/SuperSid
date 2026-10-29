local Audio = {enabled=true,sounds={}}
function Audio.load()
    local specs={jump={340,.11},coin={880,.08},shoot={180,.09},hurt={95,.18},win={660,.4},click={560,.04},ammo={480,.13}}
    for name,spec in pairs(specs) do
        local rate,duration=22050,spec[2]
        local data=love.sound.newSoundData(math.floor(rate*duration),rate,16,1)
        for i=0,data:getSampleCount()-1 do
            local t=i/rate
            local frequency=spec[1]*(name=="jump" and (1+t*5) or 1)
            local wave=math.sin(t*frequency*math.pi*2)>0 and 1 or -1
            data:setSample(i,wave*.11*(1-t/duration)^2)
        end
        Audio.sounds[name]=love.audio.newSource(data,"static")
    end
end
function Audio.play(name)
    if Audio.enabled and Audio.sounds[name] then Audio.sounds[name]:stop(); Audio.sounds[name]:play() end
end
return Audio
