-- app/statusbar.lua — top-right status line: "> TUE 10 NOV  23:16  [battery] 87%".
-- Every minute, and whenever the bar appears, the line types itself out like the
-- title screen's codec lines: 40 characters a second with a block cursor at the end.
--   statusbar.update(st, visible)  call every frame; true while the animation needs redraws
--   statusbar.draw(st)
local ui    = require("kit.ui")
local theme = require("app.theme")

local statusbar = {}
local c = theme.c

local RIGHT, CY, SIZE = ui.W - 24, 24, 16
local SPEED = 40       -- characters per second (same as the title screen)
local HOLD = 1.0       -- the cursor keeps blinking this long after the line is typed
local BATTERY_W = 25   -- outline + nub

-- The line as pieces, left to right. A text piece costs one typing step per character,
-- the battery icon costs one step. Rebuilt only when the status text changes.
local line, lineW, steps = {}, 0, 0
local builtTime, builtDate, builtPercent = nil, nil, false

local shownTime = nil  -- the clock text the last animation started for
local startedAt = nil  -- nil = not animating (the whole line is shown)

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

local function rebuild(st)
  builtTime, builtDate, builtPercent = st.time, st.date, st.percent
  line, lineW, steps = {}, 0, 0
  if st.time == "" then return end
  local f = ui.font(SIZE)
  local function text(s, color, gap)
    line[#line + 1] = { text = s, color = color, w = f:getWidth(s), gap = gap }
  end
  text("> " .. st.date, c.dim, 12)
  text(st.time, c.text, 14)
  if st.percent then
    line[#line + 1] = { battery = true, w = BATTERY_W, gap = 7 }
    text(st.percent .. "%", c.text, 0)
  end
  for i = 1, #line do
    local p = line[i]
    lineW = lineW + p.w + p.gap
    steps = steps + (p.battery and 1 or #p.text)
  end
end

function statusbar.update(st, visible)
  if not visible then  -- hidden (title screen): type the line out again when it comes back
    shownTime, startedAt = nil, nil
    return false
  end
  if st.time ~= builtTime or st.date ~= builtDate or st.percent ~= builtPercent then rebuild(st) end
  local now = love.timer.getTime()
  if st.time ~= shownTime then
    shownTime, startedAt = st.time, now
  end
  if startedAt and now - startedAt >= steps / SPEED + HOLD then
    startedAt = nil
    return true  -- one more redraw, without the cursor
  end
  return startedAt ~= nil
end

function statusbar.draw(st)
  if #line == 0 then return end
  local f = ui.font(SIZE)
  local ty = ui.capY(SIZE, CY)
  local age = startedAt and (love.timer.getTime() - startedAt) or nil
  local budget = age and math.floor(age * SPEED) or steps
  local x = math.floor(RIGHT - lineW + 0.5)
  local endX = x
  for i = 1, #line do
    if budget <= 0 then break end
    local p = line[i]
    if p.battery then
      battery(x, CY, st)
      budget = budget - 1
      endX = x + p.w
    else
      local n = math.min(#p.text, budget)
      local shown = (n < #p.text) and p.text:sub(1, n) or p.text
      ui.print(shown, x, ty, SIZE, p.color)
      budget = budget - n
      endX = x + ((n < #p.text) and f:getWidth(shown) or p.w)
    end
    x = x + p.w + p.gap
  end
  -- block cursor: solid while typing, then blinking until the animation ends
  if age and (age * SPEED < steps or math.floor(age * 3) % 2 == 0) then
    ui.rect(math.floor(endX) + 3, CY - 7, 8, 14, c.dim, 0)
  end
end

return statusbar
