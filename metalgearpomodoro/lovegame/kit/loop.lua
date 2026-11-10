-- kit/loop.lua — battery-friendly main loop.
-- Caps the frame rate and only redraws when something changed:
--   * any input/window event redraws automatically
--   * call loop.invalidate() when your state changes on its own (a clock tick, an animation)
--   * a safety redraw happens every `idleRedraw` seconds
local loop = { fps = 30, idleRedraw = 1.0 }

local dirty = true
local sinceDraw = 0

function loop.invalidate() dirty = true end

-- Call once at the top of main.lua (replaces love.run).
function loop.install(opts)
  opts = opts or {}
  loop.fps = opts.fps or loop.fps
  loop.idleRedraw = opts.idleRedraw or loop.idleRedraw

  function love.run()
    if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
    love.timer.step()

    return function()
      local frameStart = love.timer.getTime()

      love.event.pump()
      for name, a, b, c, d, e, f in love.event.poll() do
        if name == "quit" then
          if not love.quit or not love.quit() then return a or 0 end
        end
        love.handlers[name](a, b, c, d, e, f)
        dirty = true
      end

      local dt = love.timer.step()
      if love.update then love.update(dt) end

      sinceDraw = sinceDraw + dt
      if (dirty or sinceDraw >= loop.idleRedraw) and love.graphics.isActive() then
        love.graphics.origin()
        love.graphics.clear(0, 0, 0, 1)
        if love.draw then love.draw() end
        love.graphics.present()
        dirty, sinceDraw = false, 0
      end

      local spare = 1 / loop.fps - (love.timer.getTime() - frameStart)
      if spare > 0 then love.timer.sleep(spare) end
    end
  end
end

return loop
