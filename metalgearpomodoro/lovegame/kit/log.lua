-- kit/log.lua — timestamped logging plus a friendly crash screen.
-- print() goes to stdout; the PortMaster launch script tees stdout into <app>/log.txt.
local log = {}

io.stdout:setvbuf("no")  -- unbuffered, so nothing is lost if the app is killed

function log.write(level, ...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  print(("[%s] %s %s"):format(os.date("%H:%M:%S"), level, table.concat(parts, " ")))
end

function log.info(...) log.write("INFO", ...) end
function log.warn(...) log.write("WARN", ...) end
function log.error(...) log.write("ERROR", ...) end

-- Replaces LÖVE's blue error screen: logs the traceback, shows a readable message,
-- and exits on any button. Self-contained on purpose (other modules may be what broke).
function log.installCrashScreen(appName)
  function love.errorhandler(msg)
    msg = tostring(msg)
    log.error(debug.traceback("Error: " .. msg, 2))

    if not (love.window and love.graphics and love.event) then return end
    if not love.graphics.isCreated() or not love.window.isOpen() then
      if not pcall(love.window.setMode, 640, 480) then return end
    end
    if love.audio then love.audio.stop() end
    love.graphics.reset()

    local fontTitle = love.graphics.newFont(28)
    local fontBody = love.graphics.newFont(20)
    local fontSmall = love.graphics.newFont(16)
    local detail = msg:gsub("\t", "  ")
    if #detail > 400 then detail = detail:sub(1, 400) .. "..." end
    local openedAt = love.timer and love.timer.getTime() or 0

    local function draw()
      local w, h = love.graphics.getDimensions()
      local s = math.min(w / 640, h / 480)
      love.graphics.clear(0.07, 0.07, 0.09)
      love.graphics.push()
      love.graphics.translate((w - 640 * s) / 2, (h - 480 * s) / 2)
      love.graphics.scale(s)
      love.graphics.setColor(0.92, 0.33, 0.25)
      love.graphics.setFont(fontTitle)
      love.graphics.printf(appName .. " hit a snag", 24, 60, 592, "left")
      love.graphics.setColor(0.96, 0.96, 0.96)
      love.graphics.setFont(fontBody)
      love.graphics.printf("The details were saved to log.txt in the app folder.\nPress any button to exit.", 24, 120, 592, "left")
      love.graphics.setColor(0.66, 0.66, 0.72)
      love.graphics.setFont(fontSmall)
      love.graphics.printf(detail, 24, 220, 592, "left")
      love.graphics.pop()
      love.graphics.present()
    end

    return function()
      love.event.pump()
      for name in love.event.poll() do
        if name == "quit" then return 1 end
        local armed = not love.timer or love.timer.getTime() - openedAt > 0.6
        if armed and (name == "keypressed" or name == "gamepadpressed" or name == "joystickpressed") then
          return 1
        end
      end
      draw()
      if love.timer then love.timer.sleep(0.1) end
    end
  end
end

return log
