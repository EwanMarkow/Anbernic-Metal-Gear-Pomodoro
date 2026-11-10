-- app/seg7.lua — italic seven-segment digits drawn as polygons (no digit font needed).
-- Supports 0-9 : / - . and spaces.
--   seg7.width(text, height)                                 -> width in pixels
--   seg7.draw(text, x, baseline, height, color, alpha, ghost) -> width (ghost = alpha of unlit segments)
local seg7 = { slant = 0.12 }

-- geometry in units of digit height (baseline at y = 0, top at y = -1)
local W, T, G = 0.52, 0.12, 0.014    -- digit width, stroke thickness, gap between segments
local SPACING = 0.14                 -- space after each digit
local ADV = { colon = 0.26, slash = 0.42, dot = 0.22, space = 0.30 }

local function hseg(x0, x1, y)
  x0, x1 = x0 + G, x1 - G
  local h = T / 2
  return { x0, y, x0 + h, y - h, x1 - h, y - h, x1, y, x1 - h, y + h, x0 + h, y + h }
end

local function vseg(x, y0, y1)
  y0, y1 = y0 + G, y1 - G
  local h = T / 2
  return { x, y0, x + h, y0 + h, x + h, y1 - h, x, y1, x - h, y1 - h, x - h, y0 + h }
end

local xL, xR, yT, yM, yB = T / 2, W - T / 2, -1 + T / 2, -0.5, -T / 2
local SEGMENTS = {
  hseg(xL, xR, yT),  -- a top
  vseg(xR, yT, yM),  -- b upper right
  vseg(xR, yM, yB),  -- c lower right
  hseg(xL, xR, yB),  -- d bottom
  vseg(xL, yM, yB),  -- e lower left
  vseg(xL, yT, yM),  -- f upper left
  hseg(xL, xR, yM),  -- g middle
}
local SLASH = { 0, 0, T * 1.1, 0, 0.36, -1, 0.36 - T * 1.1, -1 }

-- lit segments per character, indexed by byte
local LIT = {}
local PATTERNS = {
  ["0"] = "abcdef", ["1"] = "bc", ["2"] = "abdeg", ["3"] = "abcdg", ["4"] = "bcfg",
  ["5"] = "acdfg", ["6"] = "acdefg", ["7"] = "abc", ["8"] = "abcdefg", ["9"] = "abcdfg",
  ["-"] = "g",
}
for ch, pattern in pairs(PATTERNS) do
  local on = {}
  for i = 1, 7 do on[i] = pattern:find(string.char(96 + i), 1, true) ~= nil end
  LIT[ch:byte()] = on
end

local COLON, SLASH_B, DOT = (":"):byte(), ("/"):byte(), ("."):byte()

local function advance(b)
  if LIT[b] then return W + SPACING end
  if b == COLON then return ADV.colon end
  if b == SLASH_B then return ADV.slash end
  if b == DOT then return ADV.dot end
  return ADV.space
end

function seg7.width(text, height)
  local w = 0
  for i = 1, #text do w = w + advance(text:byte(i)) end
  if #text > 0 and LIT[text:byte(#text)] then w = w - SPACING end
  return w * height
end

function seg7.draw(text, x, baseline, height, color, alpha, ghost)
  local lg = love.graphics
  alpha = alpha or 1
  lg.push()
  lg.translate(x, baseline)
  lg.shear(-seg7.slant, 0)
  lg.scale(height)
  local cx = 0
  for i = 1, #text do
    local b = text:byte(i)
    local on = LIT[b]
    if on then
      lg.push()
      lg.translate(cx, 0)
      for s = 1, 7 do
        if on[s] then
          lg.setColor(color[1], color[2], color[3], alpha)
          lg.polygon("fill", SEGMENTS[s])
        elseif ghost then
          lg.setColor(color[1], color[2], color[3], ghost)
          lg.polygon("fill", SEGMENTS[s])
        end
      end
      lg.pop()
    elseif b == COLON then
      lg.setColor(color[1], color[2], color[3], alpha)
      lg.rectangle("fill", cx + 0.05, -0.30 - T / 2, T, T)
      lg.rectangle("fill", cx + 0.05, -0.70 - T / 2, T, T)
    elseif b == SLASH_B then
      lg.setColor(color[1], color[2], color[3], alpha)
      lg.push()
      lg.translate(cx + 0.02, 0)
      lg.polygon("fill", SLASH)
      lg.pop()
    elseif b == DOT then
      lg.setColor(color[1], color[2], color[3], alpha)
      lg.rectangle("fill", cx + 0.04, -T, T, T)
    end
    cx = cx + advance(b)
  end
  lg.pop()
  return seg7.width(text, height)
end

return seg7
