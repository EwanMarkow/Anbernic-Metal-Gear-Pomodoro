-- app/chime.lua — all app sounds.
--   "sessionStart"  a work session starts            assets/sounds/session_start.ogg
--   "restStart"     the break starts                 assets/sounds/rest_start.ogg
--   "round"         a round (work + break) is done   assets/sounds/finishing_round.ogg
--   "streak"        all rounds of the set are done   assets/sounds/finishing_streak.ogg
--   "gameOver"      a session is abandoned           assets/sounds/game_over.ogg
--   "nav"           any other button press           assets/sounds/menu_navigation.ogg
-- A missing file falls back to a synthesized bell (or silence for "nav").
local log = require("kit.log")

local chime = {}
local RATE = 22050
local TWO_PI = 2 * math.pi

-- Volumes per sound, to balance the files against each other (0..1).
local FILES = {
  sessionStart = { path = "assets/sounds/session_start.ogg",    volume = 1.0 },
  restStart    = { path = "assets/sounds/rest_start.ogg",       volume = 0.8 },
  round        = { path = "assets/sounds/finishing_round.ogg",  volume = 1.0 },
  streak       = { path = "assets/sounds/finishing_streak.ogg", volume = 0.7 },
  gameOver     = { path = "assets/sounds/game_over.ogg",        volume = 0.8 },
  nav          = { path = "assets/sounds/menu_navigation.ogg",  volume = 0.8 },
}

local sources = {}

-- notes: frequencies (Hz) struck one after another, `gap` seconds apart, each ringing out
local function render(notes, gap, decay, volume)
  local length = gap * (#notes - 1) + 1.5
  local count = math.floor(length * RATE)
  local data = love.sound.newSoundData(count, RATE, 16, 1)
  for i = 0, count - 1 do
    local t = i / RATE
    local v = 0
    for n = 1, #notes do
      local lt = t - (n - 1) * gap
      if lt >= 0 then
        local f = notes[n]
        local env = math.exp(-lt * decay) * math.min(1, lt * 200)  -- 5 ms attack, long ring
        v = v + env * (math.sin(TWO_PI * f * lt)
                     + 0.30 * math.sin(TWO_PI * f * 2 * lt)
                     + 0.10 * math.sin(TWO_PI * f * 3.01 * lt))
      end
    end
    v = v * volume
    if v > 1 then v = 1 elseif v < -1 then v = -1 end
    data:setSample(i, v)
  end
  return love.audio.newSource(data)
end

function chime.load()
  local ok, err = pcall(function()
    sources.fallback = render({ 659.25, 880.00, 1046.50 }, 0.22, 3.0, 0.28)  -- bell for missing files
  end)
  if not ok then log.warn("chime: audio unavailable (" .. tostring(err) .. ")") end

  for name, info in pairs(FILES) do
    if love.filesystem.getInfo(info.path, "file") then
      local loaded, src = pcall(love.audio.newSource, info.path, "static")
      if loaded then
        src:setVolume(info.volume)
        sources[name] = src
      else
        log.warn("chime: can't load " .. info.path .. " (" .. tostring(src) .. ")")
      end
    else
      log.warn("chime: missing " .. info.path)
    end
  end
end

local function find(which)
  local src = sources[which]
  if not src and which ~= "nav" then src = sources.fallback end
  return src
end

-- which: "sessionStart" | "restStart" | "round" | "streak" | "gameOver" | "nav"
function chime.play(which)
  local src = find(which)
  if not src then return end
  src:stop()
  src:play()
end

-- Length of a sound in seconds (0 if there is none).
function chime.duration(which)
  local src = find(which)
  return src and src:getDuration("seconds") or 0
end

return chime
