-- app/theme.lua — the green LCD look: palette, font, frame, header, panels, tabs, icons, scanlines.
local ui    = require("kit.ui")
local input = require("kit.input")

local theme = {
  FONT = "assets/fonts/Tektur-Medium.ttf",  -- OFL font, see assets/fonts/Tektur-OFL.txt
  FONT_CAP = 0.70,                          -- Tektur cap height / em
}

local c = {
  bg      = { 0.047, 0.067, 0.035 },
  panel   = { 0.075, 0.100, 0.055 },
  panelHi = { 0.140, 0.180, 0.095 },
  text    = { 0.810, 0.880, 0.600 },
  dim     = { 0.560, 0.630, 0.390 },
  ink     = { 0.060, 0.085, 0.040 },
  fill    = { 0.780, 0.850, 0.550 },
  line    = { 0.700, 0.780, 0.500 },
  lcd     = { 0.600, 0.680, 0.400 },
  lcdHi   = { 0.760, 0.830, 0.540 },
}
theme.c = c

-- Call once from love.load. Returns false if the font file is missing (built-in font is used).
function theme.apply()
  ui.color.bg, ui.color.panel, ui.color.panelHi = c.bg, c.panel, c.panelHi
  ui.color.text, ui.color.dim, ui.color.dark = c.text, c.dim, c.ink
  ui.color.accent, ui.color.line = c.fill, c.line
  ui.HINT_H = 48
  ui.hintStyle = { align = "right", line = true, x0 = 20, x1 = 616, size = 18 }
  local hasFont = ui.setFontFile(theme.FONT, theme.FONT_CAP)
  ui.init({ 16, 18, 20, 22, 24, 26, 30 })

  -- scanlines: a 1×3 texture with one dark row, tiled over the whole screen in one draw
  local data = love.image.newImageData(1, 3)
  data:setPixel(0, 0, 0, 0, 0, 1)
  theme.scanImage = love.graphics.newImage(data)
  theme.scanImage:setFilter("nearest", "nearest")
  theme.scanImage:setWrap("repeat", "repeat")
  theme.scanQuad = love.graphics.newQuad(0, 0, ui.W, ui.H, 1, 3)
  return hasFont
end

-- Text helpers ------------------------------------------------------------------
-- Baseline that centres capital letters of `size` on cy.
function theme.baseline(cy, size)
  return cy + ui.capRatio * size / 2
end

-- Print with the text's baseline at `baseline`. Returns the text width.
function theme.textAt(text, size, x, baseline, color)
  local f = ui.font(size)
  ui.print(text, math.floor(x + 0.5), math.floor(baseline - f:getAscent() + 0.5), size, color)
  return f:getWidth(text)
end

-- Layout shared by several screens ---------------------------------------------
-- Centre of the timer dial. The TIMER / STATS tabs keep one spot on every screen,
-- with their divider level with the dial's centre (the "15" label).
theme.DIAL_CX, theme.DIAL_CY = 236, 220

-- Frame, header -----------------------------------------------------------------
function theme.frame()
  ui.outline(6, 6, ui.W - 12, ui.H - 12, 14, c.line, 2, 0.8)
end

-- Three slanted bars, `h` pixels tall, top-left at (x, y).
function theme.logo(x, y, h)
  h = h or 22
  local k = h / 22
  ui.setColor(c.text)
  for i = 0, 2 do
    local bx = x + i * 11 * k
    love.graphics.polygon("fill", bx, y + h, bx + 7 * k, y + h, bx + 15 * k, y, bx + 8 * k, y)
  end
end

-- METAL GEAR (small) over POMODORO (big).
function theme.header()
  theme.logo(24, 21, 36)
  ui.print("METAL GEAR", 98, ui.capY(18, 24), 18, c.dim)
  theme.textAt("POMODORO", 30, 96, theme.baseline(48, 30), c.text)
end

-- "POMODORO  2/4" plus cycle squares, bottom-left (draw after ui.hintBar).
function theme.cycle(n, total)
  local cy = ui.H - ui.HINT_H / 2
  local text = "POMODORO  " .. n .. "/" .. total
  ui.print(text, 24, ui.capY(18, cy), 18, c.text)
  local x = 24 + ui.font(18):getWidth(text) + 18
  for i = 1, total do
    if i <= n then
      ui.rect(x, cy - 6, 12, 12, c.fill, 1)
    else
      ui.outline(x + 0.5, cy - 5.5, 11, 11, 1, c.line, 1.5)
    end
    x = x + 18
  end
end

-- Panels and lines ----------------------------------------------------------------
-- Panel with cut corners. fillColor = false draws only the outline.
function theme.chamfer(x, y, w, h, cut, fillColor)
  local pts = { x + cut, y, x + w - cut, y, x + w, y + cut, x + w, y + h - cut,
                x + w - cut, y + h, x + cut, y + h, x, y + h - cut, x, y + cut }
  if fillColor ~= false then
    ui.setColor(fillColor or c.panel)
    love.graphics.polygon("fill", pts)
  end
  ui.setColor(c.line)
  love.graphics.setLineWidth(2)
  love.graphics.polygon("line", pts)
  love.graphics.setLineWidth(1)
end

function theme.hline(x0, x1, y, alpha)
  ui.setColor(c.line, alpha or 0.55)
  love.graphics.setLineWidth(1)
  love.graphics.line(x0, y + 0.5, x1, y + 0.5)
end

function theme.vline(x, y0, y1, alpha)
  ui.setColor(c.line, alpha or 0.55)
  love.graphics.setLineWidth(1)
  love.graphics.line(x + 0.5, y0, x + 0.5, y1)
end

-- Soft glow around a lit element.
function theme.glow(x, y, w, h, r)
  for i = 3, 1, -1 do
    local g = i * 2
    ui.rect(x - g, y - g, w + g * 2, h + g * 2, c.fill, r + g, 0.05)
  end
end

function theme.triangle(x, cy, size, color)
  ui.setColor(color)
  love.graphics.polygon("fill", x, cy - size / 2, x + size * 0.8, cy, x, cy + size / 2)
end

-- Controls ------------------------------------------------------------------------
-- Big action button: "▶ LABEL". Focused = lit.
function theme.button(label, x, y, w, h, focused)
  if focused then
    theme.glow(x, y, w, h, 6)
    ui.rect(x, y, w, h, c.fill, 6)
  else
    ui.rect(x, y, w, h, c.panel, 6)
    ui.outline(x, y, w, h, 6, c.line, 2)
  end
  local color = focused and c.ink or c.text
  local tw = ui.font(24):getWidth(label)
  local gx = math.floor(x + (w - (14 + 14 + tw)) / 2)
  local cy = y + h / 2
  theme.triangle(gx, cy, 18, color)
  ui.print(label, gx + 28, ui.capY(24, cy), 24, color)
end

-- Duration chip: big number + small "min". Selected = lit; focused adds a ring.
function theme.chip(minutes, x, y, w, h, selected, focused)
  if selected then
    if focused then theme.glow(x, y, w, h, 6) end
    ui.rect(x, y, w, h, c.fill, 6)
    if focused then ui.focusRing(x, y, w, h, 6) end
  else
    ui.rect(x, y, w, h, c.panel, 6)
    ui.outline(x, y, w, h, 6, c.line, 1.5, focused and 1 or 0.7)
  end
  local num = tostring(minutes)
  local wNum = ui.font(22):getWidth(num)
  local wUnit = ui.font(16):getWidth(" min")
  local tx = x + (w - wNum - wUnit) / 2
  local base = theme.baseline(y + h / 2, 22)
  local color = selected and c.ink or c.text
  theme.textAt(num, 22, tx, base, color)
  theme.textAt(" min", 16, tx + wNum, base, color)
end

-- Round button badge, e.g. the (Y) in a tab. inverted = dark badge on a lit background.
function theme.badge(letter, cx, cy, r, inverted)
  ui.setColor(inverted and c.ink or c.text)
  love.graphics.circle("fill", cx, cy, r)
  ui.glyphLetter(letter, cx, cy, 16, inverted and c.fill or c.ink)
end

-- Y TIMER / X STATS tabs, right of the dial. active = "timer" | "stats"
local TABS = { { "y", "TIMER", "timer" }, { "x", "STATS", "stats" } }
local TABS_X, TABS_W, TABS_ROW = 488, 132, 50

function theme.tabs(active)
  local x, y, w, rowH = TABS_X, theme.DIAL_CY - TABS_ROW, TABS_W, TABS_ROW
  ui.rect(x, y, w, rowH * 2, c.panel, 10)
  for i = 1, 2 do
    local tab = TABS[i]
    local ry = y + (i - 1) * rowH
    local on = (tab[3] == active)
    if on then
      theme.glow(x + 4, ry + 4, w - 8, rowH - 8, 6)
      ui.rect(x + 4, ry + 4, w - 8, rowH - 8, c.fill, 6)
    end
    local cy = ry + rowH / 2
    theme.badge(input.labelFor(tab[1]), x + 26, cy, 12, on)
    ui.print(tab[2], x + 46, ui.capY(20, cy), 20, on and c.ink or c.text)
  end
  theme.hline(x + 8, x + w - 8, y + rowH, 0.5)
  ui.outline(x, y, w, rowH * 2, 10, c.line, 1.5)
end

function theme.checkbox(x, cy, size, checked)
  ui.outline(x, cy - size / 2, size, size, 2, c.line, 1.5)
  if checked then theme.icon("check", x + size / 2, cy, size, c.text) end
end

-- Icons, drawn centred on (cx, cy) inside a box of size s ----------------------------
function theme.icon(name, cx, cy, s, color)
  local lg = love.graphics
  ui.setColor(color)
  lg.setLineWidth(math.max(2, s * 0.07))
  if name == "work" then
    local r = s * 0.42
    lg.polygon("fill", cx, cy - r, cx + r, cy, cx, cy + r, cx - r, cy)
    ui.setColor(c.ink)
    lg.line(cx, cy - r, cx, cy + r)
    lg.line(cx - r, cy, cx + r, cy)
    local q = r * 0.5
    lg.polygon("line", cx, cy - q, cx + q, cy, cx, cy + q, cx - q, cy)
  elseif name == "break" then
    lg.polygon("fill", cx - s * 0.30, cy, cx + s * 0.20, cy, cx + s * 0.14, cy + s * 0.27, cx - s * 0.24, cy + s * 0.27)
    lg.circle("line", cx + s * 0.25, cy + s * 0.10, s * 0.08)
    lg.line(cx - s * 0.38, cy + s * 0.35, cx + s * 0.30, cy + s * 0.35)
    for i = -1, 1 do
      local x = cx - s * 0.06 + i * s * 0.13
      lg.line(x, cy - s * 0.08, x + s * 0.04, cy - s * 0.16, x, cy - s * 0.24, x + s * 0.04, cy - s * 0.32)
    end
  elseif name == "check" then
    lg.setLineWidth(math.max(2, s * 0.11))
    lg.line(cx - s * 0.30, cy + s * 0.02, cx - s * 0.08, cy + s * 0.24, cx + s * 0.32, cy - s * 0.22)
  elseif name == "target" then
    lg.setLineWidth(2)
    lg.circle("line", cx, cy, s * 0.30)
    lg.line(cx, cy - s * 0.50, cx, cy - s * 0.14)
    lg.line(cx, cy + s * 0.14, cx, cy + s * 0.50)
    lg.line(cx - s * 0.50, cy, cx - s * 0.14, cy)
    lg.line(cx + s * 0.14, cy, cx + s * 0.50, cy)
  elseif name == "box" then
    lg.setLineWidth(2)
    lg.rectangle("line", cx - s * 0.42, cy - s * 0.42, s * 0.84, s * 0.84, 2, 2)
    lg.line(cx - s * 0.22, cy, cx - s * 0.05, cy + s * 0.17, cx + s * 0.24, cy - s * 0.18)
  elseif name == "flame" then
    lg.polygon("fill", cx, cy - s * 0.48, cx + s * 0.18, cy - s * 0.18, cx + s * 0.30, cy + s * 0.08,
               cx + s * 0.27, cy + s * 0.27, cx + s * 0.14, cy + s * 0.42, cx, cy + s * 0.47,
               cx - s * 0.14, cy + s * 0.42, cx - s * 0.27, cy + s * 0.27, cx - s * 0.30, cy + s * 0.08,
               cx - s * 0.18, cy - s * 0.18)
    ui.setColor(c.bg)
    lg.polygon("fill", cx, cy + s * 0.02, cx + s * 0.12, cy + s * 0.22, cx + s * 0.10, cy + s * 0.36,
               cx, cy + s * 0.41, cx - s * 0.10, cy + s * 0.36, cx - s * 0.12, cy + s * 0.22)
  elseif name == "bars" then
    local bw = s * 0.22
    lg.rectangle("fill", cx - s * 0.40, cy + s * 0.10, bw, s * 0.35)
    lg.rectangle("fill", cx - s * 0.11, cy - s * 0.12, bw, s * 0.57)
    lg.rectangle("fill", cx + s * 0.18, cy - s * 0.40, bw, s * 0.85)
  end
  lg.setLineWidth(1)
end

-- CRT scanlines over everything (one draw call).
function theme.scanlines()
  love.graphics.setColor(1, 1, 1, 0.22)
  love.graphics.draw(theme.scanImage, theme.scanQuad, 0, 0)
end

return theme
