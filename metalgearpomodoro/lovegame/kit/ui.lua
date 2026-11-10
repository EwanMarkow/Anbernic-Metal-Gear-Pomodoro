-- kit/ui.lua — theme, cached fonts, hint bar, toasts and a list menu for a 640×480 layout.
-- Restyle it from your app: change ui.color, ui.HINT_H, ui.hintStyle, and call ui.setFontFile().
local input = require("kit.input")

local ui = {
  W = 640, H = 480, MARGIN = 16, HINT_H = 40,
  hintStyle = nil,   -- default options for ui.hintBar (see below)
  capRatio = 0.72,   -- cap height / font size of the current font
}

ui.color = {
  bg      = { 0.07, 0.07, 0.09 },
  panel   = { 0.15, 0.15, 0.19 },
  panelHi = { 0.22, 0.22, 0.28 },
  text    = { 0.96, 0.96, 0.96 },
  dim     = { 0.66, 0.66, 0.72 },
  dark    = { 0.07, 0.07, 0.09 },
  accent  = { 1.00, 0.80, 0.25 },  -- focus highlight
  line    = { 0.40, 0.40, 0.48 },  -- outlines and dividers
}

-- Fonts -----------------------------------------------------------------------
local fonts = {}
local fontFile = nil

-- Use a TTF/OTF for every size. Falls back to LÖVE's built-in font if the file is missing.
-- capRatio = the font's cap height / em (OS/2 sCapHeight / unitsPerEm). Returns true if loaded.
function ui.setFontFile(path, capRatio)
  if path and love.filesystem.getInfo(path, "file") then
    fontFile = path
    ui.capRatio = capRatio or ui.capRatio
  else
    fontFile = nil
  end
  fonts = {}
  return fontFile ~= nil
end

function ui.font(size)
  local f = fonts[size]
  if not f then
    f = fontFile and love.graphics.newFont(fontFile, size) or love.graphics.newFont(size)
    fonts[size] = f
  end
  return f
end

-- Preload font sizes once at startup (no allocations while drawing).
function ui.init(sizes)
  for _, size in ipairs(sizes or { 16, 18, 20, 24, 28 }) do ui.font(size) end
end

-- The y to print at so that CAPITAL letters are vertically centred on cy.
function ui.capY(size, cy)
  return math.floor(cy - ui.font(size):getAscent() + ui.capRatio * size / 2 + 0.5)
end

-- Button letters (A B X Y) always use LÖVE's built-in font, so they stay unambiguous
-- whatever display font the app uses.
local glyphFonts = {}

function ui.glyphFont(size)
  local f = glyphFonts[size]
  if not f then
    f = love.graphics.newFont(size)
    glyphFonts[size] = f
  end
  return f
end

-- Draw one button letter centred on (cx, cy).
function ui.glyphLetter(letter, cx, cy, size, color)
  local f = ui.glyphFont(size)
  love.graphics.setFont(f)
  ui.setColor(color)
  love.graphics.print(letter, math.floor(cx - f:getWidth(letter) / 2 + 0.5),
                      math.floor(cy - f:getAscent() + 0.73 * size / 2 + 0.5))
end

-- Drawing helpers -------------------------------------------------------------
function ui.setColor(c, alpha)
  love.graphics.setColor(c[1], c[2], c[3], alpha or c[4] or 1)
end

-- ui.print(text, x, y, size, color)                 plain
-- ui.print(text, x, y, size, color, align, width)   aligned inside [x, x + width]
function ui.print(text, x, y, size, color, align, width)
  love.graphics.setFont(ui.font(size or 20))
  ui.setColor(color or ui.color.text)
  if align then
    love.graphics.printf(text, x, y, width or (ui.W - x), align)
  else
    love.graphics.print(text, x, y)
  end
end

function ui.rect(x, y, w, h, color, radius, alpha)
  ui.setColor(color, alpha)
  love.graphics.rectangle("fill", x, y, w, h, radius or 8, radius or 8)
end

function ui.outline(x, y, w, h, radius, color, width, alpha)
  ui.setColor(color or ui.color.line, alpha)
  love.graphics.setLineWidth(width or 2)
  love.graphics.rectangle("line", x, y, w, h, radius or 8, radius or 8)
  love.graphics.setLineWidth(1)
end

-- Visible focus outline around a box.
function ui.focusRing(x, y, w, h, radius)
  radius = radius or 8
  ui.setColor(ui.color.accent)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", x - 3, y - 3, w + 6, h + 6, radius + 3, radius + 3)
  love.graphics.setLineWidth(1)
end

-- Button glyphs -------------------------------------------------------------
-- kind: "dpad" (cross) | "confirm" "back" "x" "y" (round) | "start" "select" "l1" ... (pill)
local function isRound(kind)
  return kind == "confirm" or kind == "back" or #kind == 1
end

function ui.glyphWidth(kind)
  if kind == "dpad" or isRound(kind) then return 24 end
  return ui.font(16):getWidth(string.upper(kind)) + 16
end

-- Draws a glyph with its left edge at x, centred on cy. Returns its width.
function ui.glyph(kind, x, cy)
  local c = ui.color
  local f = ui.font(16)
  ui.setColor(c.text)
  if kind == "dpad" then
    love.graphics.rectangle("fill", x + 8, cy - 12, 8, 24, 2, 2)
    love.graphics.rectangle("fill", x, cy - 4, 24, 8, 2, 2)
    return 24
  end
  if isRound(kind) then
    love.graphics.circle("fill", x + 12, cy, 12)
    ui.glyphLetter(input.labelFor(kind), x + 12, cy, 16, c.dark)
    return 24
  end
  local label = string.upper(kind)
  local w = f:getWidth(label) + 16
  love.graphics.rectangle("fill", x, cy - 11, w, 22, 11, 11)
  love.graphics.setFont(f)
  ui.setColor(c.dark)
  love.graphics.print(label, x + 8, ui.capY(16, cy))
  return w
end

-- Bottom hint bar. items = { {"confirm", "Select"}, {"back", "Back"}, {"start", "Menu"} }
-- opts (defaults to ui.hintStyle):
--   align = "right"   right-align the hints (default: left)
--   line = true       a separator line on a plain background instead of a filled panel
--   x0, x1            horizontal extent of the bar
--   size              label font size (default 18)
function ui.hintBar(items, opts)
  opts = opts or ui.hintStyle or {}
  local y = ui.H - ui.HINT_H
  local x0, x1 = opts.x0 or 0, opts.x1 or ui.W
  local size = opts.size or 18
  local f = ui.font(size)

  if opts.line then
    ui.rect(x0, y + 2, x1 - x0, ui.HINT_H - 8, ui.color.bg, 0)
    ui.setColor(ui.color.line)
    love.graphics.setLineWidth(1)
    love.graphics.line(x0, y + 0.5, x1, y + 0.5)
  else
    ui.rect(0, y, ui.W, ui.HINT_H, ui.color.panel, 0)
  end

  local x = x0 + ui.MARGIN
  if opts.align == "right" then
    local total = 0
    for i = 1, #items do
      total = total + ui.glyphWidth(items[i][1]) + 6 + f:getWidth(items[i][2])
      if i < #items then total = total + 20 end
    end
    x = x1 - total
  end

  local cy = y + ui.HINT_H / 2
  local ty = ui.capY(size, cy)
  for i = 1, #items do
    local kind, label = items[i][1], items[i][2]
    x = x + ui.glyph(kind, x, cy) + 6
    love.graphics.setFont(f)
    ui.setColor(ui.color.text)
    love.graphics.print(label, x, ty)
    x = x + f:getWidth(label) + 20
  end
end

-- Toasts (one at a time, newest wins) ----------------------------------------
local toast = { text = nil, t = 0, dur = 0 }

function ui.toast(text, seconds)
  toast.text, toast.t, toast.dur = text, 0, seconds or 1.8
end

-- Returns true while a toast is on screen (so the caller keeps redrawing).
function ui.updateToasts(dt)
  if not toast.text then return false end
  toast.t = toast.t + dt
  if toast.t >= toast.dur then toast.text = nil end
  return true
end

function ui.drawToasts()
  if not toast.text then return end
  local alpha = math.min(1, (toast.dur - toast.t) / 0.3)
  local f = ui.font(18)
  local w = f:getWidth(toast.text) + 32
  local x, y = math.floor((ui.W - w) / 2), ui.H - ui.HINT_H - 52
  ui.rect(x, y, w, 40, ui.color.panelHi, 20, 0.95 * alpha)
  ui.outline(x, y, w, 40, 20, ui.color.line, 1.5, alpha)
  love.graphics.setFont(f)
  ui.setColor(ui.color.text, alpha)
  love.graphics.print(toast.text, x + 16, ui.capY(18, y + 20))
end

-- Menu: a vertical list in a modal panel ------------------------------------
-- local m = ui.newMenu{ title = "Menu", items = { {id = "quit", label = "Quit"} },
--                       cancel = "close", onChoose = function(id) ... end,
--                       hints = { {"confirm", "Select"}, ... } }      -- hints optional
-- m:action(a) returns an item id on confirm, `cancel` on B/Start, otherwise nil.
local Menu = {}
Menu.__index = Menu

local MENU_HINTS = { { "dpad", "Move" }, { "confirm", "Select" }, { "back", "Close" } }

function ui.newMenu(opts)
  return setmetatable({
    title = opts.title or "Menu",
    items = opts.items,
    cancel = opts.cancel or "cancel",
    onChoose = opts.onChoose or function() end,
    index = opts.index or 1,
    hints = opts.hints or MENU_HINTS,
  }, Menu)
end

function Menu:action(a)
  local n = #self.items
  if a == "up" then
    self.index = (self.index - 2) % n + 1
  elseif a == "down" then
    self.index = self.index % n + 1
  elseif a == "confirm" then
    return self.items[self.index].id
  elseif a == "back" or a == "start" then
    return self.cancel
  end
  return nil
end

function Menu:draw()
  local c = ui.color
  ui.setColor(c.dark, 0.78)
  love.graphics.rectangle("fill", 0, 0, ui.W, ui.H - ui.HINT_H)

  local itemH, w = 46, 400
  local h = 64 + #self.items * itemH + 12
  local x, y = (ui.W - w) / 2, math.floor((ui.H - ui.HINT_H - h) / 2)
  ui.rect(x, y, w, h, c.panel, 12)
  ui.outline(x, y, w, h, 12, c.line, 2)
  ui.print(self.title, x + 20, ui.capY(24, y + 32), 24, c.text)

  for i = 1, #self.items do
    local iy = y + 64 + (i - 1) * itemH
    local focused = (i == self.index)
    if focused then
      ui.rect(x + 12, iy, w - 24, itemH - 6, c.panelHi, 8)
      ui.focusRing(x + 12, iy, w - 24, itemH - 6, 8)
    end
    ui.print(self.items[i].label, x + 28, ui.capY(20, iy + (itemH - 6) / 2), 20, focused and c.text or c.dim)
  end
  ui.hintBar(self.hints)
end

return ui
