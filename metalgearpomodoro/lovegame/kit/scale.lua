-- kit/scale.lua — draw a fixed-size layout into any window (640×480 panel, PC window, HDMI),
-- centred with black bars.
--   scale.init{ w = 640, h = 480 }               UI mode: smooth fractional scaling
--   scale.init{ w = 320, h = 240, pixel = true } pixel art: canvas + nearest + integer scale
-- In love.draw:  scale.begin()  ...draw in layout coordinates...  scale.finish()
-- In love.resize(w, h): scale.resize(w, h)
local scale = { w = 640, h = 480, pixel = false, s = 1, ox = 0, oy = 0 }

function scale.init(opts)
  opts = opts or {}
  scale.w, scale.h = opts.w or 640, opts.h or 480
  scale.pixel = opts.pixel or false
  if scale.pixel then
    love.graphics.setDefaultFilter("nearest", "nearest")
    scale.canvas = love.graphics.newCanvas(scale.w, scale.h)
  end
  scale.resize(love.graphics.getDimensions())
end

function scale.resize(windowW, windowH)
  local s = math.min(windowW / scale.w, windowH / scale.h)
  if scale.pixel and s >= 1 then s = math.floor(s) end
  scale.s = s
  scale.ox = math.floor((windowW - scale.w * s) / 2)
  scale.oy = math.floor((windowH - scale.h * s) / 2)
end

function scale.begin()
  if scale.pixel then
    love.graphics.setCanvas(scale.canvas)
    love.graphics.clear(0, 0, 0, 1)
  else
    love.graphics.setScissor(scale.ox, scale.oy, math.ceil(scale.w * scale.s), math.ceil(scale.h * scale.s))
    love.graphics.push()
    love.graphics.translate(scale.ox, scale.oy)
    love.graphics.scale(scale.s)
  end
end

function scale.finish()
  if scale.pixel then
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(scale.canvas, scale.ox, scale.oy, 0, scale.s, scale.s)
  else
    love.graphics.pop()
    love.graphics.setScissor()
  end
end

return scale
