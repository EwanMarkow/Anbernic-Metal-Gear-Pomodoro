-- app/setup.lua — home screen: SET SESSION panel (work + break length) and START SESSION.
local ui    = require("kit.ui")
local theme = require("app.theme")

local Setup = { row = 3, tabs = true }  -- row: 1 = work, 2 = break, 3 = start button
local c = theme.c

local PX, PY, PW, PH = 64, 104, 512, 186
local CHIP_W, CHIP_H, CHIP_GAP = 106, 42, 14
local CHIPS_X = PX + PW - 20 - (CHIP_W * 3 + CHIP_GAP * 2)
local ROW_CY = { 181, 251 }
local BTN_X, BTN_Y, BTN_W, BTN_H = 128, 320, 384, 50

local HINTS_ROW   = { { "dpad", "SELECT" }, { "confirm", "NEXT" }, { "x", "STATS" }, { "start", "MENU" }, { "back", "QUIT" } }
local HINTS_START = { { "dpad", "SELECT" }, { "confirm", "START" }, { "x", "STATS" }, { "start", "MENU" }, { "back", "QUIT" } }

function Setup.enter(App)
  Setup.row = 3
end

function Setup.action(App, a)
  local s = App.settings
  if a == "up" then
    Setup.row = (Setup.row - 2) % 3 + 1
  elseif a == "down" then
    Setup.row = Setup.row % 3 + 1
  elseif a == "left" or a == "right" then
    local d = (a == "left") and -1 or 1
    if Setup.row == 3 then Setup.row = 1 end  -- from START, left/right go straight to WORK
    if Setup.row == 1 then
      s.focusIndex = math.max(1, math.min(#App.FOCUS, s.focusIndex + d))
    elseif Setup.row == 2 then
      s.breakIndex = math.max(1, math.min(#App.BREAK, s.breakIndex + d))
    end
  elseif a == "confirm" then
    if Setup.row < 3 then Setup.row = Setup.row + 1 else App.startFocus() end
  elseif a == "back" then
    App.quit()
  end
end

local function row(index, label, values, selected)
  local cy = ROW_CY[index]
  local focused = (Setup.row == index)
  if focused then theme.triangle(PX + 18, cy, 14, c.fill) end
  ui.print(label, PX + 36, ui.capY(22, cy), 22, focused and c.fill or c.text)
  for i = 1, #values do
    local x = CHIPS_X + (i - 1) * (CHIP_W + CHIP_GAP)
    theme.chip(values[i], x, cy - CHIP_H / 2, CHIP_W, CHIP_H, i == selected, focused)
  end
end

function Setup.draw(App)
  local s = App.settings
  theme.header()

  theme.chamfer(PX, PY, PW, PH, 18)
  ui.print("SET SESSION", PX, ui.capY(22, PY + 24), 22, c.text, "center", PW)
  theme.hline(PX + 20, PX + PW - 20, PY + 46)
  row(1, "WORK", App.FOCUS, s.focusIndex)
  theme.hline(PX + 20, PX + PW - 20, 216)
  row(2, "BREAK", App.BREAK, s.breakIndex)

  theme.button("START SESSION", BTN_X, BTN_Y, BTN_W, BTN_H, Setup.row == 3)

  ui.hintBar(Setup.row == 3 and HINTS_START or HINTS_ROW)
  ui.setColor(c.line, 0.7)
  love.graphics.line(26, 466, 38, 452, 76, 452)
end

return Setup
