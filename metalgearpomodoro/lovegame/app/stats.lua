-- app/stats.lua — session history and daily totals, stored in stats.json.
-- data.days["2026-11-10"] = { f = focus seconds, d = work sessions finished, s = work sessions started }
-- data.log = { { t = start time, k = "w"|"b", m = planned minutes, e = elapsed seconds, ok = finished }, ... }
local save = require("kit.save")

local stats = { FILE = "stats.json", LOG_MAX = 400 }

local MONTHS = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }
local WEEKDAYS = { "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" }  -- os.date wday: 1 = Sunday

local data = { days = {}, log = {} }

function stats.load()
  data = save.load(stats.FILE, {})
  if type(data.days) ~= "table" then data.days = {} end
  if type(data.log) ~= "table" then data.log = {} end
  data.version = 1
end

function stats.save()
  save.write(stats.FILE, data)
end

local function dayKey(t) return os.date("%Y-%m-%d", t) end

-- Unix time of local noon / midnight `offset` days before today.
local function dayTime(offset, hour)
  local t = os.date("*t")
  t.day, t.hour, t.min, t.sec, t.isdst = t.day - offset, hour or 12, 0, 0, nil
  return os.time(t)
end

-- kind: "focus" | "break"; startedAt: os.time() when it began; plannedMin: chosen length;
-- elapsed: seconds it actually ran; ok: ran to the end.
function stats.record(kind, startedAt, plannedMin, elapsed, ok)
  elapsed = math.floor(elapsed + 0.5)
  local log = data.log
  log[#log + 1] = { t = startedAt, k = (kind == "focus") and "w" or "b", m = plannedMin, e = elapsed, ok = ok and true or false }
  while #log > stats.LOG_MAX do table.remove(log, 1) end
  if kind == "focus" then
    local key = dayKey(os.time())
    local day = data.days[key]
    if not day then
      day = { f = 0, d = 0, s = 0 }
      data.days[key] = day
    end
    day.f = (day.f or 0) + elapsed
    day.s = (day.s or 0) + 1
    if ok then day.d = (day.d or 0) + 1 end
  end
  stats.save()
end

-- range: "week" | "month" | "all". Returns totals plus chart bars (seconds) and labels.
function stats.summary(range)
  local out = { focus = 0, done = 0, started = 0, bars = {}, labels = {} }
  local function add(day)
    if not day then return end
    out.focus = out.focus + (day.f or 0)
    out.done = out.done + (day.d or 0)
    out.started = out.started + (day.s or 0)
  end

  if range == "all" then
    for _, day in pairs(data.days) do add(day) end
    local now = os.date("*t")
    for back = 5, 0, -1 do  -- last six months, one bar each
      local y, m = now.year, now.month - back
      if m < 1 then m, y = m + 12, y - 1 end
      local prefix = string.format("%04d-%02d", y, m)
      local sum = 0
      for key, day in pairs(data.days) do
        if key:sub(1, 7) == prefix then sum = sum + (day.f or 0) end
      end
      out.bars[#out.bars + 1] = sum
      out.labels[#out.labels + 1] = MONTHS[m]
    end
    out.title = "FOCUS TIME (LAST 6 MONTHS)"
  else
    local n = (range == "week") and 7 or 30
    for offset = n - 1, 0, -1 do
      local t = dayTime(offset)
      local day = data.days[dayKey(t)]
      add(day)
      out.bars[#out.bars + 1] = day and day.f or 0
      local d = os.date("*t", t)
      if n == 7 then
        out.labels[#out.labels + 1] = WEEKDAYS[d.wday]
      else
        out.labels[#out.labels + 1] = (offset % 7 == 0) and tostring(d.day) or false
      end
    end
    out.title = (n == 7) and "FOCUS TIME (LAST 7 DAYS)" or "FOCUS TIME (LAST 30 DAYS)"
  end
  return out
end

-- Days in a row with at least one finished work session (today may still be pending).
function stats.streak()
  local offset, count = 0, 0
  local today = data.days[dayKey(dayTime(0))]
  if not (today and (today.d or 0) > 0) then offset = 1 end
  while offset < 4000 do
    local day = data.days[dayKey(dayTime(offset))]
    if not (day and (day.d or 0) > 0) then break end
    count = count + 1
    offset = offset + 1
  end
  return count
end

-- Log entries newest first, limited to the range and to `max` entries.
function stats.entries(range, max)
  local since = nil
  if range == "week" then since = dayTime(6, 0) elseif range == "month" then since = dayTime(29, 0) end
  local out = {}
  local log = data.log
  for i = #log, 1, -1 do
    local e = log[i]
    if since and (e.t or 0) < since then break end
    out[#out + 1] = e
    if max and #out >= max then break end
  end
  return out
end

-- "Today 14:30" / "09 NOV 18:45"
function stats.when(t)
  local hm = os.date("%H:%M", t)
  if dayKey(t) == dayKey(dayTime(0)) then return "Today " .. hm end
  local d = os.date("*t", t)
  return string.format("%02d %s %s", d.day, MONTHS[d.month], hm)
end

-- "25 min" (finished) or "12/25 min" (stopped early)
function stats.duration(e)
  if e.ok then return string.format("%d min", e.m or 0) end
  return string.format("%d/%d min", math.floor((e.e or 0) / 60), e.m or 0)
end

return stats
