-- app/history.lua — DETAILS: every logged session in the chosen range, newest first.
local ui    = require("kit.ui")
local theme = require("app.theme")
local stats = require("app.stats")

local View = { tabs = true, index = 1, top = 1 }
local c = theme.c

local PX, PY, PW, PH = 16, 76, 460, 352
local ROWS, ROW_H, Y0 = 10, 29, 128
local HINTS = { { "dpad", "SCROLL" }, { "back", "BACK" } }

local list = {}
local title = ""

function View.enter(App)
  local range = App.historyRange or { id = "week", label = "7 DAYS" }
  title = (range.id == "all") and "ALL TIME" or ("LAST " .. range.label)
  list = stats.entries(range.id)
  View.index, View.top = 1, 1
end

local function move(delta)
  if #list == 0 then return end
  View.index = math.max(1, math.min(#list, View.index + delta))
  if View.index < View.top then View.top = View.index end
  if View.index > View.top + ROWS - 1 then View.top = View.index - ROWS + 1 end
end

function View.action(App, a)
  if a == "up" then move(-1)
  elseif a == "down" then move(1)
  elseif a == "l1" or a == "left" then move(-ROWS)
  elseif a == "r1" or a == "right" then move(ROWS)
  elseif a == "back" then App.back()
  end
end

function View.draw(App)
  theme.header()
  theme.pageDots(App.stage())
  theme.chamfer(PX, PY, PW, PH, 16)

  ui.print("HISTORY", PX + 18, ui.capY(24, 99), 24, c.text)
  local info = title .. "  (" .. #list .. ")"
  ui.print(info, PX, ui.capY(16, 99), 16, c.dim, "right", PW - 16)
  theme.hline(PX + 12, PX + PW - 12, 120)

  if #list == 0 then
    ui.print("No sessions in this range yet.", PX, ui.capY(18, 270), 18, c.dim, "center", PW)
  end
  for r = 0, ROWS - 1 do
    local i = View.top + r
    local e = list[i]
    if not e then break end
    local y = Y0 + r * ROW_H
    local cy = y + ROW_H / 2
    if i == View.index then
      ui.rect(PX + 10, y + 2, PW - 26, ROW_H - 4, c.panelHi, 4)
      ui.focusRing(PX + 10, y + 2, PW - 26, ROW_H - 4, 4)
    end
    theme.checkbox(PX + 20, cy, 14, e.ok)
    ui.print((e.k == "w") and "Work" or "Break", PX + 46, ui.capY(18, cy), 18, c.text)
    ui.print(stats.duration(e), PX + 170, ui.capY(16, cy), 16, c.text, "center", 120)
    ui.print(stats.when(e.t or 0), PX, ui.capY(16, cy), 16, c.text, "right", PW - 24)
  end

  -- scrollbar
  if #list > ROWS then
    local trackH = ROWS * ROW_H
    local thumbH = math.max(16, trackH * ROWS / #list)
    local thumbY = Y0 + (trackH - thumbH) * (View.top - 1) / (#list - ROWS)
    ui.rect(PX + PW - 10, Y0, 3, trackH, c.line, 1, 0.25)
    ui.rect(PX + PW - 10, thumbY, 3, thumbH, c.fill, 1)
  end

  theme.tabs("stats", 488, 96)
  ui.hintBar(HINTS)
end

return View
