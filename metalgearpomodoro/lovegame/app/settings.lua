-- app/settings.lua — SETTINGS list. D-pad left/right (or A) changes the focused row.
local ui    = require("kit.ui")
local input = require("kit.input")
local theme = require("app.theme")

local Settings = { row = 1, ownsStart = true }
local c = theme.c

local PX, PY, PW, PH = 64, 86, 512, 330
local ROW_H, Y0 = 36, 136
local HINTS = { { "dpad", "CHANGE" }, { "confirm", "TOGGLE" }, { "back", "DONE" } }

local function onOff(v) return v and "ON" or "OFF" end

local rows = {
  {
    label = "CONFIRM BUTTON",
    value = function(s) return s.confirmOnB and "B" or "A" end,
    change = function(s) s.confirmOnB = not s.confirmOnB; input.setSwap(s.confirmOnB) end,
    help = function() return "The other face button goes back." end,
  },
  {
    label = "BUTTON CHECK",
    value = function() return "RUN" end,
    open = "splash",
    learn = true,
    help = function() return "Replays the intro; its A press relearns your buttons." end,
  },
  {
    label = "SOUND",
    value = function(s) return onOff(s.sound) end,
    change = function(s) s.sound = not s.sound end,
    help = function() return "Alarms when work, a round or a set ends." end,
  },
  {
    label = "MENU SOUNDS",
    value = function(s) return onOff(s.menuSounds) end,
    change = function(s) s.menuSounds = not s.menuSounds end,
    help = function() return "Click when moving through menus and lists." end,
  },
  {
    label = "LID CLOSED",
    value = function(s) return (s.lidMode == "keep") and "KEEP COUNTING" or "PAUSE TIMER" end,
    change = function(s) s.lidMode = (s.lidMode == "keep") and "pause" or "keep" end,
    help = function(s)
      if s.lidMode == "keep" then return "Real time keeps passing while the lid is shut." end
      return "The timer waits until you open the lid."
    end,
  },
  {
    label = "SCANLINES",
    value = function(s) return onOff(s.scanlines) end,
    change = function(s) s.scanlines = not s.scanlines end,
    help = function() return "CRT-style lines across the screen." end,
  },
  {
    label = "BACK",
    back = true,
    help = function() return "" end,
  },
}

function Settings.enter(App)
  Settings.row = 1
end

local function leave(App)
  App.save()
  App.back()
end

function Settings.action(App, a)
  local row = rows[Settings.row]
  if a == "up" then
    Settings.row = (Settings.row - 2) % #rows + 1
  elseif a == "down" then
    Settings.row = Settings.row % #rows + 1
  elseif a == "left" or a == "right" or a == "confirm" then
    if row.back then
      if a == "confirm" then leave(App) end
    elseif row.open then
      if a == "confirm" then
        App.save()
        if row.learn then App.splashLearn = true end
        App.open(row.open)
      end
    else
      row.change(App.settings)
    end
  elseif a == "back" or a == "start" then
    leave(App)
  end
end

function Settings.draw(App)
  local s = App.settings
  theme.header()
  theme.pageDots(App.stage())
  theme.chamfer(PX, PY, PW, PH, 18)
  ui.print("SETTINGS", PX, ui.capY(22, PY + 22), 22, c.text, "center", PW)
  theme.hline(PX + 20, PX + PW - 20, PY + 42)

  local x, w = PX + 16, PW - 32
  for i = 1, #rows do
    local row = rows[i]
    local y = Y0 + (i - 1) * ROW_H
    local cy = y + (ROW_H - 6) / 2
    local focused = (i == Settings.row)
    if focused then
      ui.rect(x, y, w, ROW_H - 6, c.panelHi, 6)
      ui.focusRing(x, y, w, ROW_H - 6, 6)
    end
    ui.print(row.label, x + 16, ui.capY(20, cy), 20, focused and c.text or c.dim)
    if row.value then
      local value = row.value(s)
      if focused and not row.open then value = "<  " .. value .. "  >" end
      ui.print(value, x, ui.capY(20, cy), 20, focused and c.fill or c.dim, "right", w - 16)
    end
  end

  ui.print(rows[Settings.row].help(s), PX, ui.capY(16, PY + PH - 16), 16, c.dim, "center", PW)
  ui.hintBar(HINTS)
end

return Settings
