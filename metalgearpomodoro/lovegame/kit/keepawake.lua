-- kit/keepawake.lua — keep the screen on (no dimming, no auto-sleep) while something runs.
--   keepawake.init()      once at startup (repairs timeouts left behind by a crash or power cut)
--   keepawake.set(true)   while e.g. a timer runs; keepawake.set(false) when it stops / on quit
--
-- What it does:
--   * all platforms: SDL screensaver off (love.window.setDisplaySleepEnabled)
--   * muOS: the display dims / the device sleeps after N seconds without button presses. While
--     active, the timeouts in /run/muos/global/settings/power/{idle_display,idle_sleep} are raised
--     to 12 h, then put back. The original values are saved first (keepawake.json in the save
--     folder), so they get restored on the next launch even after a crash.
--   * other firmwares: the muOS files don't exist, so only the SDL part applies.
local save = require("kit.save")
local log  = require("kit.log")

local keepawake = {
  dir = "/run/muos/global/settings/power/",
  files = { "idle_display", "idle_sleep" },
  long = "43200",  -- seconds (12 h)
  active = false,
}

local BACKUP = "keepawake.json"

local function readNumber(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*l")
  f:close()
  return s and s:match("^%s*(%d+)%s*$")
end

local function write(path, value)
  local f = io.open(path, "w")
  if not f then return false end
  f:write(value)
  f:close()
  return true
end

local function restore()
  local backup = save.load(BACKUP, nil)
  if not (backup and backup.values) then return end
  for name, value in pairs(backup.values) do
    if write(keepawake.dir .. name, value) then log.info("keepawake: restored " .. name .. " = " .. value) end
  end
  save.write(BACKUP, {})
end

function keepawake.init()
  restore()
end

function keepawake.set(on)
  on = on and true or false
  if on == keepawake.active then return end
  keepawake.active = on
  if love.window and love.window.setDisplaySleepEnabled then
    love.window.setDisplaySleepEnabled(not on)
  end
  if not on then
    restore()
    return
  end
  local values, found = {}, false
  for _, name in ipairs(keepawake.files) do
    local value = readNumber(keepawake.dir .. name)
    if value and value ~= keepawake.long then
      values[name] = value
      found = true
    end
  end
  if found then
    save.write(BACKUP, { values = values })  -- back up before changing anything
    for name in pairs(values) do write(keepawake.dir .. name, keepawake.long) end
    log.info("keepawake: on (muOS idle timeouts raised)")
  end
end

return keepawake
