-- app/splash.lua — title screen: CRT power-on, radar sweep, codec typing, glitchy
-- METAL GEAR, slamming POMODORO, "!" alert, then a blinking PRESS (A) in the footer.
-- The A press doubles as the button check: with App.splashLearn set (first launch, or
-- Settings > BUTTON CHECK) it learns whether this controller reports A as "a" or "b".
local ui    = require("kit.ui")
local input = require("kit.input")
local loop  = require("kit.loop")
local theme = require("app.theme")

local View = { ownsStart = true, noStatus = true, t = 0, leaving = nil }
local c = theme.c

local CX, RY = ui.W / 2, 236               -- screen centre, radar centre y
local LEAVE_TIME = 0.32
local GLITCH = "#$%&*@?/<>"

local CODEC = {
  { at = 0.50, text = "> CODEC LINK ........ OK" },
  { at = 0.95, text = "> FREQ 25.00" },
  { at = 1.30, text = "> MISSION: STAY FOCUSED" },
}

-- radar blips, fixed positions (angle, radius)
local BLIPS = { { 0.6, 70 }, { 1.9, 150 }, { 2.7, 110 }, { 3.9, 165 }, { 4.6, 55 }, { 5.5, 130 } }

local function clamp01(x) return math.max(0, math.min(1, x)) end
local function easeOut(x) x = clamp01(x); return 1 - (1 - x) ^ 3 end

-- Text with extra letter spacing; draws the first `count` characters, centred on the full width.
-- glitchLast = true makes the newest character flicker through random symbols.
local function spaced(text, size, cy, spacing, count, color, alpha, glitchLast)
  local f = ui.font(size)
  local width = f:getWidth(text) + spacing * (#text - 1)
  local x = CX - width / 2
  local y = ui.capY(size, cy)
  love.graphics.setFont(f)
  for i = 1, math.min(count, #text) do
    local ch = text:sub(i, i)
    local shown = ch
    if glitchLast and i == count and ch ~= " " then
      local k = math.random(#GLITCH)
      shown = GLITCH:sub(k, k)
    end
    ui.setColor(color, alpha)
    love.graphics.print(shown, math.floor(x + 0.5), y)
    x = x + f:getWidth(ch) + spacing
  end
end

local function finish(App, positional)
  App.splashLearn = false
  App.settings.buttonsChecked = true
  App.save()
  if positional then App.toast("BUTTONS FIXED (THEY WERE SWAPPED)", 3) end
  App.back()
end

function View.enter(App)
  View.t, View.leaving, View.swapped = 0, nil, false
  ui.font(64)  -- preload the big title size
  input.captureNext(function(button, source)
    if button ~= "a" and button ~= "b" then return false end  -- wait for A (or B)
    if App.splashLearn and source == "pad" then
      local positional = (button == "b")
      App.settings.positional = positional
      input.setPositional(positional)
      View.swapped = positional
    end
    App.navSound()
    View.leaving = View.t
    return true
  end)
end

function View.update(App, dt)
  View.t = View.t + dt
  loop.invalidate()  -- animated screen: redraw every frame (30 fps cap)
  if View.leaving and View.t - View.leaving >= LEAVE_TIME then
    View.leaving = nil
    finish(App, View.swapped)
  end
end

function View.action(App, a)
  -- Start does nothing here on purpose; A (captured above) continues, Start+Select still quits.
end

local function drawRadar(t)
  local alpha = 0.18 * easeOut((t - 0.2) / 0.6)
  if alpha <= 0 then return end
  love.graphics.setLineWidth(1)
  for r = 60, 180, 60 do
    ui.setColor(c.line, alpha)
    love.graphics.circle("line", CX, RY, r, 64)
  end
  ui.setColor(c.line, alpha * 0.8)
  love.graphics.line(CX - 190, RY, CX + 190, RY)
  love.graphics.line(CX, RY - 190, CX, RY + 190)

  -- sweep: a fading wedge behind the leading edge
  local a = t * 1.6
  local steps, span = 8, 0.7
  for i = 0, steps - 1 do
    local a0 = a - span * i / steps
    local a1 = a - span * (i + 1) / steps
    ui.setColor(c.fill, alpha * 0.9 * (1 - i / steps))
    love.graphics.polygon("fill", CX, RY,
      CX + 185 * math.cos(a0), RY + 185 * math.sin(a0),
      CX + 185 * math.cos(a1), RY + 185 * math.sin(a1))
  end
  -- blips glow right after the sweep passes them
  for i = 1, #BLIPS do
    local ba, br = BLIPS[i][1], BLIPS[i][2]
    local behind = (a - ba) % (2 * math.pi)
    local glow = math.max(0, 1 - behind / 2.5)
    if glow > 0 then
      ui.setColor(c.fill, glow * alpha * 5)
      love.graphics.circle("fill", CX + br * math.cos(ba), RY + br * math.sin(ba), 3)
    end
  end
end

local function drawCodec(t)
  local f = ui.font(16)
  love.graphics.setFont(f)
  local last = 0
  for i = 1, #CODEC do
    local line = CODEC[i]
    local n = math.floor((t - line.at) * 40)
    if n > 0 then
      ui.setColor(c.dim)
      love.graphics.print(line.text:sub(1, n), 40, ui.capY(16, 40 + i * 22))
      last = i
    end
  end
  if last > 0 and math.floor(t * 3) % 2 == 0 then  -- blinking block cursor
    local line = CODEC[last]
    local n = math.min(#line.text, math.floor((t - line.at) * 40))
    ui.rect(40 + f:getWidth(line.text:sub(1, n)) + 4, 40 + last * 22 - 7, 9, 14, c.dim, 0)
  end
end

local function drawAlert(t)
  local p = (t - 2.75) / 0.25
  if p <= 0 then return end
  local fade = 1 - clamp01((t - 3.9) / 0.4)
  if fade <= 0 then return end
  local s = (p < 1) and (1.35 * easeOut(p)) or (1 + 0.35 * math.max(0, 1 - (p - 1) * 4))
  love.graphics.push()
  love.graphics.translate(512, 150)
  love.graphics.scale(s)
  ui.rect(-7, -26, 14, 30, c.ink, 3, fade)
  ui.rect(-5, -24, 10, 26, c.fill, 2, fade)
  ui.rect(-7, 8, 14, 14, c.ink, 3, fade)
  ui.rect(-5, 10, 10, 10, c.fill, 2, fade)
  love.graphics.pop()
end

local function drawTitle(t)
  -- METAL GEAR types in with a glitch on the newest letter
  local mg = "METAL GEAR"
  local count = math.floor((t - 1.15) / 0.07)
  if count > 0 then
    spaced(mg, 26, 176, 10, count, c.text, 1, count < #mg)
  end

  -- POMODORO slams in (shrinks from big, fades in), shakes on impact
  local p = (t - 1.95) / 0.22
  if p > 0 then
    local e = easeOut(p)
    local s = 1 + 0.7 * (1 - e)
    local shake = (t - 2.17 > 0 and t - 2.17 < 0.18) and 4 or 0
    local dx = shake > 0 and math.random(-shake, shake) or 0
    local dy = shake > 0 and math.random(-shake, shake) or 0
    love.graphics.push()
    love.graphics.translate(CX + dx, 236 + dy)
    love.graphics.scale(s)
    local f = ui.font(64)
    love.graphics.setFont(f)
    ui.setColor(c.fill, e)
    love.graphics.print("POMODORO", math.floor(-f:getWidth("POMODORO") / 2), ui.capY(64, 0))
    love.graphics.pop()
  end

  -- underline grows out from the centre, tagline fades in
  local u = easeOut((t - 2.25) / 0.3)
  if u > 0 then
    local half = 200 * u
    ui.setColor(c.line)
    love.graphics.setLineWidth(2)
    love.graphics.line(CX - half, 281, CX + half, 281)
    love.graphics.setLineWidth(1)
    ui.rect(CX - half - 3, 278, 6, 6, c.fill, 1)
    ui.rect(CX + half - 3, 278, 6, 6, c.fill, 1)
  end
  local tag = clamp01((t - 2.45) / 0.4)
  if tag > 0 then
    spaced("TACTICAL FOCUS ACTION", 16, 304, 4, 99, c.dim, tag)
  end
end

local function drawFlash(t)
  local q = (t - 2.17) / 0.35
  if q > 0 and q < 1 then
    ui.setColor(c.fill, 0.35 * (1 - q))
    love.graphics.rectangle("fill", 0, 0, ui.W, ui.H)
  end
end

local function drawFooter(t)
  local y = ui.H - ui.HINT_H
  ui.setColor(c.line)
  love.graphics.setLineWidth(1)
  love.graphics.line(20, y + 0.5, 616, y + 0.5)
  if t < 2.9 then return end
  local alpha = (math.floor((t - 2.9) * 2.4) % 2 == 0) and 1 or 0.25
  if View.leaving then alpha = 1 end
  local f = ui.font(18)
  local left, right = "PRESS", "TO START"
  local w = f:getWidth(left) + 8 + 24 + 8 + f:getWidth(right)
  local x = math.floor(CX - w / 2)
  local cy = y + ui.HINT_H / 2
  local ty = ui.capY(18, cy)
  love.graphics.setFont(f)
  ui.setColor(c.text, alpha)
  love.graphics.print(left, x, ty)
  x = x + f:getWidth(left) + 8
  love.graphics.circle("fill", x + 12, cy, 12)
  if alpha == 1 then ui.glyphLetter("A", x + 12, cy, 16, c.ink) end
  x = x + 24 + 8
  love.graphics.setFont(f)
  ui.setColor(c.text, alpha)
  love.graphics.print(right, x, ty)
end

-- CRT power-on (a line that opens into the picture) and power-off when leaving.
local function drawCrt(t)
  if t < 0.15 then
    ui.rect(0, 0, ui.W, ui.H, c.bg, 0)
    local w = ui.W * easeOut(t / 0.15)
    ui.rect(CX - w / 2, ui.H / 2 - 1, w, 2, c.fill, 0)
  elseif t < 0.4 then
    local band = ui.H * easeOut((t - 0.15) / 0.25)
    local cover = (ui.H - band) / 2
    ui.rect(0, 0, ui.W, cover, c.bg, 0)
    ui.rect(0, ui.H - cover, ui.W, cover, c.bg, 0)
  end
  if View.leaving then
    local q = clamp01((t - View.leaving) / LEAVE_TIME)
    local cover = (ui.H / 2) * easeOut(q)
    ui.rect(0, 0, ui.W, cover, c.bg, 0)
    ui.rect(0, ui.H - cover, ui.W, cover, c.bg, 0)
    if q > 0.6 then ui.rect(0, ui.H / 2 - 1, ui.W, 2, c.fill, 0, 1 - q) end
  end
end

function View.draw(App)
  local t = View.t
  drawRadar(t)
  drawCodec(t)
  drawTitle(t)
  drawAlert(t)
  drawFlash(t)
  drawFooter(t)
  drawCrt(t)
end

return View
