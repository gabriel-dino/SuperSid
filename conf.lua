function love.conf(t)
    t.identity = "hero-supersid"
    t.version = "11.5"
    t.console = false
    t.window.title = "Hero • Super Sid"
    t.window.width = 1152
    t.window.height = 648
    t.window.minwidth = 768
    t.window.minheight = 432
    t.window.resizable = true
    t.window.vsync = 1
    t.modules.joystick = false
    t.modules.physics = false
end
