-- app/timerview.lua — WORK / BREAK screen:
--   outer ring  = 60-minute dial, lit segments = minutes left
--   inner ring  = 60 ticks, lit ticks = seconds left in the current minute
--   round LCD   = phase, icon and seven-segment digits
local ui    = require("kit.ui")
local loop  = require("kit.loop")
local theme = require("app.theme")
local seg7  = require("app.seg7")

local View = { lastKey = -1, tabs = true }
local c = theme.c

local CX, CY = 236, 220
local LCD_R = 110               -- round LCD radius
local S1, S2 = 117, 127         -- seconds ring
local R1, R2 = 136, 156         -- minutes ring
local RDOT, RLABEL = 167, 190   -- minute dots, numbers
local DIGITS_H = 54

-- dial geometry, computed once
local SEGMENTS, TICKS, DOTS, LABELS = {}, {}, {}, {}

local function ringPiece(r1, r2, a0, a1)
  local c0, s0, c1, s1 = math.cos(a0), math.sin(a0), math.cos(a1), math.sin(a1)
  return { CX + r1 * c0, CY + r1 * s0, CX + r2 * c0, CY + r2 * s0,
           CX + r2 * c1, CY + r2 * s1, CX + r1 * c1, CY + r1 * s1 }
end

for i = 0, 59 do
  local slot = math.pi / 30
  local start = -math.pi / 2 + i * slot
  SEGMENTS[i + 1] = ringPiece(R1, R2, start + 0.16 * slot, start + 0.84 * slot)
  TICKS[i + 1] = ringPiece(S1, S2, start + 0.30 * slot, start + 0.70 * slot)
  DOTS[i + 1] = { x = CX + RDOT * math.cos(start), y = CY + RDOT * math.sin(start),
                  dx = math.cos(start) * 5, dy = math.sin(start) * 5, major = (i % 5 == 0) }
  if i % 5 == 0 then
    LABELS[#LABELS + 1] = { text = string.format("%02d", i),
                            x = CX + RLABEL * math.cos(start), y = CY + RLABEL * math.sin(start) }
  end
end

local HINTS = {
  focus_running = { { "confirm", "PAUSE" }, { "back", "STOP" } },
  focus_paused  = { { "confirm", "RESUME" }, { "back", "STOP" } },
  break_running = { { "confirm", "PAUSE" }, { "back", "SKIP" } },
  break_paused  = { { "confirm", "RESUME" }, { "back", "SKIP" } },
}

local function mmss(seconds)
  local s = math.ceil(seconds)
  return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end

local function blinkOff(t)
  return t.state == "paused" and math.floor(love.timer.getTime() * 2) % 2 == 1
end

function View.enter(App)
  View.lastKey = -1
end

function View.update(App, dt)
  -- redraw when the displayed second changes, or the paused digits blink
  local t = App.timer
  local key = math.ceil(t:remaining()) * 2 + (blinkOff(t) and 1 or 0)
  if key ~= View.lastKey then
    View.lastKey = key
    loop.invalidate()
  end
end

function View.action(App, a)
  local t = App.timer
  if a == "confirm" then
    t:toggle()
  elseif a == "back" then
    if t.phase == "focus" then App.confirmStop() else App.finishBreak(false) end
  end
end

local function drawDial(App, t)
  -- minute dots, 5-minute ticks and numbers
  love.graphics.setLineWidth(2)
  for i = 1, 60 do
    local d = DOTS[i]
    if d.major then
      ui.setColor(c.line)
      love.graphics.line(d.x - d.dx, d.y - d.dy, d.x + d.dx, d.y + d.dy)
    else
      ui.setColor(c.line, 0.85)
      love.graphics.circle("fill", d.x, d.y, 1.7)
    end
  end
  love.graphics.setLineWidth(1)
  local f = ui.font(18)
  local ty = ui.capY(18, 0)
  for i = 1, #LABELS do
    local L = LABELS[i]
    ui.print(L.text, math.floor(L.x - f:getWidth(L.text) / 2 + 0.5), math.floor(L.y + ty + 0.5), 18, c.text)
  end

  local on = (t.state == "paused") and 0.5 or 1

  -- minutes ring: one segment per minute left, clockwise from 00
  local minutes = t:remaining() / App.secondsPerMinute
  local lit = math.min(60, math.ceil(minutes - 1e-6))
  for i = 1, 60 do
    local alpha = 0.07
    if i < lit then
      alpha = on
    elseif i == lit then
      alpha = on * (0.35 + 0.65 * (minutes - (lit - 1)))
    end
    ui.setColor(c.fill, alpha)
    love.graphics.polygon("fill", SEGMENTS[i])
  end

  -- seconds ring: seconds left in the current minute (25:00 = full, 24:59 = 59 ticks)
  local total = math.ceil(t:remaining())
  local secs = (total > 0) and ((total - 1) % 60 + 1) or 0
  for i = 1, 60 do
    local alpha = 0.08
    if i < secs then
      alpha = 0.8 * on
    elseif i == secs then
      alpha = on  -- leading tick, brightest
    end
    ui.setColor(c.fill, alpha)
    love.graphics.polygon("fill", TICKS[i])
  end
end

local function drawLcd(App, t)
  -- round LCD: soft glow, base, brighter middle, rim
  for i = 3, 1, -1 do
    ui.setColor(c.fill, 0.05)
    love.graphics.circle("fill", CX, CY, LCD_R + i * 2, 96)
  end
  ui.setColor(c.lcd)
  love.graphics.circle("fill", CX, CY, LCD_R, 96)
  for i = 1, 4 do
    ui.setColor(c.lcdHi, 0.16)
    love.graphics.circle("fill", CX, CY, LCD_R - i * 12, 96)
  end
  ui.setColor(c.lcdHi)
  love.graphics.setLineWidth(2)
  love.graphics.circle("line", CX, CY, LCD_R, 96)
  love.graphics.setLineWidth(1)

  local label = (t.state == "paused") and "PAUSED" or ((t.phase == "focus") and "WORK" or "BREAK")
  local f = ui.font(20)
  local pw = f:getWidth(label) + 28
  ui.rect(CX - pw / 2, CY - 78, pw, 28, c.ink, 6)
  ui.print(label, math.floor(CX - f:getWidth(label) / 2 + 0.5), ui.capY(20, CY - 64), 20, c.lcdHi)

  ui.rect(CX - 22, CY - 42, 44, 44, c.ink, 8)
  theme.icon((t.phase == "focus") and "work" or "break", CX, CY - 20, 38, c.lcdHi)

  local text = mmss(t:remaining())
  local w = seg7.width(text, DIGITS_H)
  local x = CX - w / 2 - seg7.slant * DIGITS_H / 2
  seg7.draw(text, x, CY + 68, DIGITS_H, c.ink, blinkOff(t) and 0.2 or 1, 0.07)
end

function View.draw(App)
  local t = App.timer
  theme.pageDots(App.stage())
  drawDial(App, t)
  drawLcd(App, t)
  theme.tabs("timer", 488, 150)

  local key = ((t.phase == "focus") and "focus_" or "break_") .. ((t.state == "paused") and "paused" or "running")
  ui.hintBar(HINTS[key])
  theme.cycle(App.cycleNumber(), App.CYCLES)
end

return View
