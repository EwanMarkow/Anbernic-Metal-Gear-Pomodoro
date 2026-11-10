-- app/statusbar.lua — top-right status: date, time and battery, left of the page squares.
local ui    = require("kit.ui")
local theme = require("app.theme")

local statusbar = {}
local c = theme.c

local RIGHT, CY = ui.W - 82, 24

local function bolt(cx, cy, color)
  ui.setColor(color)
  love.graphics.polygon("fill", cx + 1, cy - 5, cx - 3, cy + 1, cx + 1, cy)
  love.graphics.polygon("fill", cx - 1, cy + 5, cx + 3, cy - 1, cx - 1, cy)
end

local function battery(x, cy, st)
  ui.outline(x, cy - 6, 22, 12, 2, c.line, 1.5)
  ui.rect(x + 22, cy - 3, 3, 6, c.line, 1)
  local blinkOff = st.low and os.time() % 2 == 1  -- low battery: fill blinks once a second
  if not blinkOff then
    ui.rect(x + 2, cy - 4, math.max(1, math.floor(18 * st.percent / 100 + 0.5)), 8, c.fill, 1)
  end
  if st.charging then
    bolt(x + 11, cy, (st.percent >= 50) and c.ink or c.text)
  end
end

function statusbar.draw(st)
  local f = ui.font(16)
  local ty = ui.capY(16, CY)
  local x = RIGHT
  if st.percent then
    local text = st.percent .. "%"
    x = x - f:getWidth(text)
    ui.print(text, x, ty, 16, c.text)
    x = x - 32
    battery(x, CY, st)
    x = x - 14
  end
  if st.time ~= "" then
    x = x - f:getWidth(st.time)
    ui.print(st.time, x, ty, 16, c.text)
    x = x - 12 - f:getWidth(st.date)
    ui.print(st.date, x, ty, 16, c.dim)
  end
end

return statusbar
