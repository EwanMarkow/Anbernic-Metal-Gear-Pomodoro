-- app/statsview.lua — STATS: range tabs, three cards, focus-time chart, completion ring,
-- recent sessions. D-pad left/right (or L1/R1) changes the range, A opens the full history.
local ui    = require("kit.ui")
local theme = require("app.theme")
local seg7  = require("app.seg7")
local stats = require("app.stats")

local View = { range = 1, tabs = true }
local c = theme.c

local RANGES = {
  { id = "week",  label = "7 DAYS" },
  { id = "month", label = "30 DAYS" },
  { id = "all",   label = "ALL TIME" },
}
local HINTS = { { "dpad", "RANGE" }, { "confirm", "DETAILS" }, { "back", "BACK" } }

local PX, PY, PW, PH = 16, 76, 460, 352
local CARD_Y, CARD_W, CARD_H = 128, 140, 66
local PLOT_X, PLOT_Y, PLOT_W, PLOT_H = 72, 230, 230, 54
local RCX, RCY, RR1, RR2, RN = 395, 262, 31, 42, 36

-- completion ring segments, computed once
local RING = {}
for i = 0, RN - 1 do
  local a0 = -math.pi / 2 + (i + 0.15) * 2 * math.pi / RN
  local a1 = -math.pi / 2 + (i + 0.85) * 2 * math.pi / RN
  local c0, s0, c1, s1 = math.cos(a0), math.sin(a0), math.cos(a1), math.sin(a1)
  RING[i + 1] = { RCX + RR1 * c0, RCY + RR1 * s0, RCX + RR2 * c0, RCY + RR2 * s0,
                  RCX + RR2 * c1, RCY + RR2 * s1, RCX + RR1 * c1, RCY + RR1 * s1 }
end

-- data for the current range, rebuilt only when the range changes
local summary, streak, recent

local function refresh()
  local id = RANGES[View.range].id
  summary = stats.summary(id)
  streak = stats.streak()
  recent = stats.entries(id, 3)
end

function View.enter(App)
  refresh()
end

function View.action(App, a)
  if a == "left" or a == "l1" then
    View.range = (View.range - 2) % #RANGES + 1
    refresh()
  elseif a == "right" or a == "r1" then
    View.range = View.range % #RANGES + 1
    refresh()
  elseif a == "confirm" then
    App.historyRange = RANGES[View.range]
    App.open("history")
  elseif a == "back" then
    App.back()
  end
end

-- Seven-segment number(s) with small units, centred on cx and shrunk to fit maxW:
-- a ua [b ub]   e.g. "12" "h" "30" "m"
local function valueGroup(cx, base, maxW, a, ua, b, ub)
  local fu = ui.font(16)
  local function width(h)
    local w = seg7.width(a, h) + 3 + fu:getWidth(ua)
    if b then w = w + 8 + seg7.width(b, h) + 3 + fu:getWidth(ub) end
    return w + seg7.slant * h
  end
  local h = 26
  while h > 14 and width(h) > maxW do h = h - 2 end
  local x = cx - width(h) / 2
  x = x + seg7.draw(a, x, base, h, c.text) + 3
  x = x + theme.textAt(ua, 16, x, base, c.text)
  if b then
    x = x + 8
    x = x + seg7.draw(b, x, base, h, c.text) + 3
    theme.textAt(ub, 16, x, base, c.text)
  end
end

local function card(i, icon, title)
  local x = PX + 12 + (i - 1) * (CARD_W + 8)
  theme.chamfer(x, CARD_Y, CARD_W, CARD_H, 8)
  local tw = ui.font(16):getWidth(title) + 24
  local tx = x + (CARD_W - tw) / 2
  theme.icon(icon, tx + 8, CARD_Y + 16, 16, c.text)
  ui.print(title, math.floor(tx + 24), ui.capY(16, CARD_Y + 16), 16, c.text)
  return x + CARD_W / 2, CARD_Y + 56
end

local function drawCards()
  local maxW = CARD_W - 20
  local cx, base = card(1, "target", "FOCUS TIME")
  local hours, mins = math.floor(summary.focus / 3600), math.floor(summary.focus % 3600 / 60)
  if hours > 0 then
    valueGroup(cx, base, maxW, tostring(hours), "h", string.format("%02d", mins), "m")
  else
    valueGroup(cx, base, maxW, tostring(mins), "m")
  end

  cx, base = card(2, "box", "COMPLETED")
  valueGroup(cx, base, maxW, summary.done .. "/" .. summary.started, "")

  cx, base = card(3, "flame", "STREAK")
  valueGroup(cx, base, maxW, tostring(streak), (streak == 1) and " day" or " days")
end

local function niceStep(maxHours)
  local steps = { 0.5, 1, 2, 5, 10, 20, 50, 100, 200, 500 }
  for i = 1, #steps do
    if maxHours / steps[i] <= 3 then return steps[i] end
  end
  return 1000
end

local function hoursLabel(v)
  if v < 1 then return string.format("%dm", v * 60) end
  return string.format("%d h", v)
end

local function drawChart()
  ui.print(summary.title, PX + 12, ui.capY(16, 210), 16, c.text)

  local maxSec = 0
  for i = 1, #summary.bars do maxSec = math.max(maxSec, summary.bars[i]) end
  local step = niceStep(maxSec / 3600)
  local top = math.max(step, step * math.ceil(maxSec / 3600 / step - 1e-9))

  -- dashed grid lines + y labels
  local f16 = ui.font(16)
  for v = step, top + 1e-9, step do
    local y = math.floor(PLOT_Y + PLOT_H - v / top * PLOT_H) + 0.5
    ui.setColor(c.line, 0.45)
    for x = PLOT_X + 2, PLOT_X + PLOT_W - 4, 7 do
      love.graphics.line(x, y, x + 3, y)
    end
    local label = hoursLabel(v)
    ui.print(label, PLOT_X - 6 - f16:getWidth(label), ui.capY(16, y), 16, c.text)
  end
  ui.print("0", PLOT_X - 6 - f16:getWidth("0"), ui.capY(16, PLOT_Y + PLOT_H), 16, c.text)
  ui.setColor(c.line)
  love.graphics.line(PLOT_X + 0.5, PLOT_Y - 4, PLOT_X + 0.5, PLOT_Y + PLOT_H + 0.5, PLOT_X + PLOT_W, PLOT_Y + PLOT_H + 0.5)

  -- bars
  local n = #summary.bars
  local slot = PLOT_W / n
  local bw = math.max(2, math.floor(slot * 0.62))
  local short = false  -- use 2-letter labels for all if any 3-letter one doesn't fit
  for i = 1, n do
    local label = summary.labels[i]
    if label and f16:getWidth(label) > slot - 2 then short = true end
  end
  for i = 1, n do
    local sx = PLOT_X + (i - 1) * slot
    local h = summary.bars[i] / (top * 3600) * PLOT_H
    if h > 0 then
      ui.rect(math.floor(sx + (slot - bw) / 2 + 1), PLOT_Y + PLOT_H - h, bw, h, c.fill, 0, 0.9)
    end
    local label = summary.labels[i]
    if label then
      if short and #label > 2 then label = label:sub(1, 2) end
      ui.print(label, math.floor(sx + slot / 2 - f16:getWidth(label) / 2 + 0.5), ui.capY(16, PLOT_Y + PLOT_H + 13), 16, c.text)
    end
  end
end

local function drawRing()
  ui.print("COMPLETION", RCX - 80, ui.capY(16, 210), 16, c.text, "center", 160)
  local started = summary.started
  local pct = (started > 0) and summary.done / started or 0
  local lit = math.floor(pct * RN + 0.5)
  for i = 1, RN do
    ui.setColor(c.fill, (i <= lit) and 1 or 0.13)
    love.graphics.polygon("fill", RING[i])
  end
  local text = (started > 0) and tostring(math.floor(pct * 100 + 0.5)) or "--"
  local f16 = ui.font(16)
  local w = seg7.width(text, 20) + 2 + f16:getWidth("%")
  local x = RCX - w / 2
  x = x + seg7.draw(text, x, RCY + 4, 20, c.text) + 2
  theme.textAt("%", 16, x, RCY + 4, c.text)
  local sub = summary.done .. "/" .. started
  if f16:getWidth(sub) <= RR1 * 2 - 8 then
    ui.print(sub, RCX - 40, ui.capY(16, RCY + 18), 16, c.text, "center", 80)
  end
end

local function drawRecent()
  ui.print("RECENT SESSIONS", PX + 22, ui.capY(18, 328), 18, c.text)
  if #recent == 0 then
    ui.print("Finish a work session to see it here.", PX, ui.capY(16, 376), 16, c.dim, "center", PW)
    return
  end
  for i = 1, #recent do
    local e = recent[i]
    local cy = 328 + i * 24
    theme.checkbox(PX + 20, cy, 14, e.ok)
    ui.print((e.k == "w") and "Work" or "Break", PX + 46, ui.capY(16, cy), 16, c.text)
    ui.print(stats.duration(e), PX + 170, ui.capY(16, cy), 16, c.text, "center", 120)
    ui.print(stats.when(e.t or 0), PX, ui.capY(16, cy), 16, c.text, "right", PW - 14)
    if i < #recent then theme.hline(PX + 46, PX + PW - 14, cy + 12, 0.3) end
  end
end

local function drawRangeTabs()
  local f = ui.font(16)
  local x = PX + PW - 12
  for i = #RANGES, 1, -1 do
    local label = RANGES[i].label
    local w = f:getWidth(label) + 20
    x = x - w
    if i == View.range then
      ui.rect(x, 86, w, 26, c.fill, 4)
      ui.print(label, x + 10, ui.capY(16, 99), 16, c.ink)
    else
      ui.outline(x, 86, w, 26, 4, c.line, 1.5, 0.7)
      ui.print(label, x + 10, ui.capY(16, 99), 16, c.text)
    end
    x = x - 6
  end
end

function View.draw(App)
  theme.header()
  theme.pageDots(App.stage())
  theme.chamfer(PX, PY, PW, PH, 16)

  theme.icon("bars", PX + 22, 99, 20, c.text)
  ui.print("STATS", PX + 40, ui.capY(24, 99), 24, c.text)
  drawRangeTabs()
  theme.hline(PX + 12, PX + PW - 12, 120)

  drawCards()
  drawChart()
  theme.vline(314, 202, 302)
  drawRing()
  theme.hline(PX + 12, PX + PW - 12, 312)
  drawRecent()

  theme.tabs("stats", 488, 96)
  ui.hintBar(HINTS)
  theme.cycle(App.cycleNumber(), App.CYCLES)
end

return View
