-- kit/status.lua — battery level and local date/time for a status bar.
--   status.update()   call every frame; cheap. Returns true when something visible changed.
--   status.refresh()  force a battery re-read (e.g. after waking from sleep)
-- Battery: on Linux the first /sys/class/power_supply/* entry with type "Battery" (found once),
-- elsewhere love.system.getPowerInfo(). Re-read every 30 s. Clock strings are rebuilt only
-- when the minute changes.
local status = {
  percent = nil,    -- 0..100, nil when unknown / no battery
  charging = false, -- plugged in (charging or full)
  low = false,      -- <= 15 % and not plugged in
  time = "",        -- "23:16"
  date = "",        -- "TUE 10 NOV"
}

local WEEKDAYS = { "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" }
local MONTHS = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }
local BATTERY_EVERY = 30

local sysfs = false  -- false = not searched yet, nil = none found, string = battery folder
local lastBattery = -math.huge
local lastMinute = -1

local function readLine(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*l")
  f:close()
  return s
end

local function findSysfsBattery()
  if love.system.getOS() ~= "Linux" then return nil end
  local p = io.popen("ls /sys/class/power_supply 2>/dev/null")
  if not p then return nil end
  local found = nil
  for name in p:lines() do
    local base = "/sys/class/power_supply/" .. name
    if not found and readLine(base .. "/type") == "Battery" and readLine(base .. "/capacity") then
      found = base
    end
  end
  p:close()
  return found
end

local function readBattery()
  if sysfs == false then sysfs = findSysfsBattery() end
  if sysfs then
    local capacity = tonumber(readLine(sysfs .. "/capacity") or "")
    if capacity then
      local state = readLine(sysfs .. "/status") or ""
      status.percent = math.max(0, math.min(100, math.floor(capacity + 0.5)))
      status.charging = (state == "Charging" or state == "Full")
      return
    end
  end
  local state, percent = love.system.getPowerInfo()
  if percent and state ~= "nobattery" and state ~= "unknown" then
    status.percent = percent
    status.charging = (state == "charging" or state == "charged")
  else
    status.percent, status.charging = nil, false
  end
end

function status.refresh()
  lastBattery = -math.huge
end

function status.update()
  local changed = false
  local now = love.timer.getTime()
  if now - lastBattery >= BATTERY_EVERY then
    lastBattery = now
    local percent, charging = status.percent, status.charging
    readBattery()
    status.low = (status.percent ~= nil) and status.percent <= 15 and not status.charging
    changed = (percent ~= status.percent) or (charging ~= status.charging)
  end
  local minute = math.floor(os.time() / 60)
  if minute ~= lastMinute then
    lastMinute = minute
    local t = os.date("*t")
    status.time = string.format("%02d:%02d", t.hour, t.min)
    status.date = string.format("%s %02d %s", WEEKDAYS[t.wday], t.day, MONTHS[t.month])
    changed = true
  end
  return changed
end

return status
