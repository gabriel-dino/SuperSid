local R=require("src.render")
local Editor=require("src.editor")
local View={}
local function clippedText(s,x,y,w,size,color)
    love.graphics.setScissor(x,y,w,26)
    R.text(s,x,y,size,color)
    love.graphics.setScissor()
end
function View.editor(e,time,button,actions)
    R.rect(0,0,960,540,"F4F0E5")
    R.text("SUPER SID / CREATE & SHARE",16,12,11,"7D8C7E")
    R.text("Level editor",16,32,28)
    clippedText((e.dirty and "* " or "")..(e.filename or "New level"),224,43,365,13,"718369")
    button("Save",600,22,74,36,actions.save)
    button("Save copy",682,22,98,36,actions.copy,true)
    button("Test",788,22,68,36,actions.test)
    button("Back",864,22,80,36,actions.back,true)
    R.text("LEVEL NAME",176,68,10,"7D8C7E"); R.text("AUTHOR",526,68,10,"7D8C7E")
    button("",176,84,340,32,function() actions.rename("name") end,true)
    button("",526,84,190,32,function() actions.rename("author") end,true)
    -- Field contents are drawn by main after buttons, so they remain visible.
    R.text("Click name or author to edit",728,93,11,"718369")
    for i,tool in ipairs(Editor.tools) do
        local shortcut=i<=9 and tostring(i) or i==10 and "0" or i==11 and "C" or "E"
        button(shortcut.."  "..tool.label,16,128+(i-1)*27,144,24,function() e.tool=tool.id end,e.tool~=tool.id)
    end
    local v=Editor.view
    love.graphics.setScissor(v.x,v.y,v.w,v.h)
    R.rect(v.x,v.y,v.w,v.h,"DDE4D6")
    love.graphics.push(); love.graphics.translate(v.x,v.y); love.graphics.scale(v.scale)
    local paletteColors=R.background(e.level.biome,e.camera,time)
    love.graphics.push(); love.graphics.translate(960,0)
    R.background(e.level.biome,e.camera+960,time)
    love.graphics.pop()
    love.graphics.translate(-e.camera,0)
    R.color(paletteColors.ink,.15); love.graphics.setLineWidth(1/v.scale)
    for x=math.floor(e.camera/24)*24,math.min(e.level.width,e.camera+v.w/v.scale),24 do love.graphics.line(x,0,x,540) end
    for y=0,540,24 do love.graphics.line(e.camera,y,e.camera+v.w/v.scale,y) end
    for _,p in ipairs(e.level.platforms) do
        R.rect(p.x,p.y,p.w,p.h,p.kind=="ground" and "456A52" or "628575")
        R.rect(p.x,p.y,p.w,6,p.kind=="ground" and "84A073" or "D9BD75")
    end
    for _,c in ipairs(e.level.coins) do R.coin(c.x+6,c.y+8,time) end
    for _,a in ipairs(e.level.ammo) do R.rect(a.x,a.y,a.w,a.h,"C38746",3); R.text("+",a.x+3,a.y+1,16,"FFF3D3") end
    for _,e2 in ipairs(e.level.enemies) do
        local enemy={}; for k,val in pairs(e2) do enemy[k]=val end
        enemy.hp=enemy.kind=="icecube" and 2 or 1; enemy.vx=40
        R.enemy(enemy,time)
    end
    local s=e.level.spawn
    R.sloth(s.x+11,s.y+43,61,1,time,{},false)
    R.text("START",s.x-9,s.y-34,12,"D6A34A")
    for _,key in ipairs({"goal","checkpoint"}) do
        local m=e.level[key]
        if m then
            R.rect(m.x+8,m.y,4,m.h,"243D35")
            R.rect(m.x+12,m.y,30,18,key=="goal" and "D6A34A" or "8BC5CC")
            R.text(key=="goal" and "FINISH" or "CHECKPOINT",m.x-8,m.y-24,12,"243D35")
        end
    end
    local preview=e:rectangle()
    if preview then
        R.color("D6A34A",.6); love.graphics.rectangle("fill",preview.x,preview.y,preview.w,preview.h)
    end
    R.rect(e.level.width,0,24,540,"BE7257")
    love.graphics.pop(); love.graphics.setScissor()
    R.color("77976B"); love.graphics.setLineWidth(1); love.graphics.rectangle("line",v.x,v.y,v.w,v.h)
    R.text("24 px grid\nRight-click: erase\nCtrl+S: save\nF5: test\nArrows / wheel: pan",16,464,11,"718369",144)
    button("Theme: "..e.level.biome,176,464,171,28,function() e:theme() end,true)
    R.text(e.level.width.." px",359,471,13,"718369")
    button("-",443,464,30,28,function() e:resize(-480) end,true)
    button("+",479,464,30,28,function() e:resize(480) end,true)
    button("<",523,464,34,28,function() e:scroll(-240) end,true)
    button(">",563,464,34,28,function() e:scroll(240) end,true)
    button("Undo",613,464,72,28,function() e:undo() end,true,#e.undoStack==0)
    button("Redo",693,464,72,28,function() e:redo() end,true,#e.redoStack==0)
    button("Folder",773,464,80,28,actions.folder,true)
    button("New",861,464,83,28,actions.new,true)
    for _,tool in ipairs(Editor.tools) do if tool.id==e.tool then R.text(tool.hint,176,500,12,"718369",768) end end
    clippedText(e.message or "",176,521,768,11,"8C783F")
end
function View.editorFields(e)
    clippedText(e.level.name,188,91,316,16,"355B46")
    clippedText(e.level.author,538,91,166,16,"355B46")
end
function View.contrib(entries,page,message,button,actions)
    R.panel("Contrib levels","Create, exchange and play trails made by the community.")
    button("Import level",624,28,142,38,actions.import,true)
    button("Open folder",778,28,150,38,actions.folder,true)
    local first=(page-1)*4+1
    if #entries==0 then
        R.rect(32,140,896,275,"FBF8EE",8)
        R.text("Your next adventure could be someone's creation.",70,184,24,"355B46",820,"center")
        R.text("Drop a .sidlevel file onto this window to import it.\nYou can also copy files into the levels folder and press Refresh.\nBuild your own trail in Level editor, save it and share the file.",110,243,16,"718369",740,"center")
        button("Create a level",363,343,234,42,actions.create)
    else
        for i=first,math.min(first+3,#entries) do
            local entry=entries[i]; local y=132+(i-first)*76
            R.rect(32,y,896,66,"FBF8EE",6)
            clippedText(entry.level.name,48,y+9,450,18,"355B46")
            clippedText("by "..entry.level.author.."  /  "..entry.level.biome.."  /  "..entry.level.width.." px",48,y+37,580,12,"718369")
            button("Play",656,y+14,118,36,function() actions.play(entry) end)
            button("Edit",786,y+14,122,36,function() actions.edit(entry) end,true)
        end
        R.text("Drop a .sidlevel file here to add a shared level. Saved editor levels appear here too.",33,447,12,"718369")
    end
    R.text(message or "",33,480,11,"8C783F",520)
    local pages=math.max(1,math.ceil(#entries/4))
    button("<",570,484,36,32,function() actions.page(-1) end,true,page==1)
    R.text(page.." / "..pages,612,493,12,"718369",70,"center")
    button(">",688,484,36,32,function() actions.page(1) end,true,page==pages)
    button("Refresh",736,484,100,32,actions.refresh,true)
    button("Back",848,484,80,32,actions.back,true)
end
return View
