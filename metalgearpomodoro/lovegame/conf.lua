-- conf.lua — LÖVE settings, read before main.lua
function love.conf(t)
  t.identity = "pomodoro"        -- save folder name (kept from v1, so old saves still load)
  t.version = "11.5"
  t.console = false

  t.window.title = "Metal Gear Pomodoro"
  t.window.width = 640
  t.window.height = 480
  t.window.resizable = true      -- on a PC: resize the window to preview HDMI letterboxing
  t.window.minwidth = 320
  t.window.minheight = 240
  t.window.vsync = 1

  t.modules.physics = false
  t.modules.video = false
  t.modules.touch = false
end
