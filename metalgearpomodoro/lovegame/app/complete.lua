-- app/complete.lua — SESSION COMPLETE: what this cycle did, set totals, NEXT CYCLE.
local ui    = require("kit.ui")
local theme = require("app.theme")

local View = { tabs = true }
local c = theme.c

local PX, PY, PW, PH = 24, 46, 436, 274
local HINTS = { { "confirm", "CONTINUE" }, { "back", "QUIT" } }

local function minutesText(seconds)
  local m = math.floor(seconds / 60 + 0.5)
  if m < 120 then return string.format("%d min", m) end
  return string.format("%dh %02dm", math.floor(m / 60), m % 60)
end

function View.action(App, a)
  if a == "confirm" then
    App.startFocus()
  elseif a == "back" then
    App.completePending = false
    App.switch("setup")
  end
end

local function phaseRow(label, minutes, ok, cy)
  ui.print(label, PX + 132, ui.capY(20, cy), 20, c.text)
  ui.print(string.format("%d min", minutes), PX + 236, ui.capY(20, cy), 20, c.text)
  if ok then
    theme.icon("check", PX + 372, cy, 24, c.text)
  else
    ui.print("SKIPPED", PX + 346, ui.capY(16, cy), 16, c.dim)
  end
end

local function statRow(label, value, cy)
  ui.print(label, PX + 40, ui.capY(18, cy), 18, c.text)
  ui.print(value, PX, ui.capY(18, cy), 18, c.text, "right", PW - 40)
end

function View.draw(App)
  local s, ses = App.settings, App.session
  local setDone = s.setDone >= App.CYCLES

  theme.chamfer(PX, PY, PW, PH, 18)
  ui.print(setDone and "SET COMPLETE" or "SESSION COMPLETE", PX, ui.capY(26, PY + 30), 26, c.text, "center", PW)
  theme.hline(PX + 20, PX + PW - 20, PY + 58)

  ui.outline(PX + 32, PY + 76, 72, 72, 10, c.line, 2)
  theme.icon("check", PX + 68, PY + 112, 60, c.text)
  phaseRow("WORK", ses.focusMin, ses.focusOk, PY + 94)
  phaseRow("BREAK", ses.breakMin, ses.breakOk, PY + 132)

  theme.hline(PX + 20, PX + PW - 20, PY + 168)
  statRow("SESSIONS", string.format("%d / %d", math.min(s.setDone, App.CYCLES), App.CYCLES), PY + 192)
  statRow("FOCUS TIME", minutesText(s.setFocus), PY + 220)
  statRow("TOTAL TIME", minutesText(s.setTotal), PY + 248)

  local label = setDone and string.format("NEW SET (1/%d)", App.CYCLES)
                         or string.format("NEXT CYCLE (%d/%d)", s.setDone + 1, App.CYCLES)
  theme.button(label, PX, 338, PW, 50, true)

  theme.tabs("timer")
  ui.hintBar(HINTS)
end

return View
