-- app/stats.lua — session history and daily totals, stored in stats.json.
-- data.days["2026-11-10"] = { f = focus seconds, d = work sessions finished, s = work sessions started }
-- data.log = { { t = start time, k = "w"|"b", m = planned minutes, e = elapsed seconds, ok = finished }, ... }
--
-- A period is what the stats screen shows: a whole range, one day or one month.
--   { kind = "range" | "day" | "month",
--     key = "2026-11-10" (day) | "2026-11" (month),
--     from, to = unix times (either may be nil = open-ended),
--     title = "LAST 7 DAYS" | "TUE 10 NOV" | "NOV 2026" }
local save = require("kit.save")

local stats = { FILE = "stats.json", LOG_MAX = 2000 }

local MONTHS = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }
local WEEKDAYS = { "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" }  -- os.date wday: 1 = Sunday
local RANGE_TITLES = { week = "LAST 7 DAYS", month = "LAST 30 DAYS", all = "ALL TIME" }
local CHART_TITLES = { week = "FOCUS TIME (LAST 7 DAYS)", month = "FOCUS TIME (LAST 30 DAYS)",
                       all = "FOCUS TIME (LAST 6 MONTHS)" }

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

-- Periods -------------------------------------------------------------------------

-- range: "week" | "month" | "all"
function stats.rangePeriod(range)
  local from = nil
  if range == "week" then from = dayTime(6, 0) elseif range == "month" then from = dayTime(29, 0) end
  return { kind = "range", from = from, title = RANGE_TITLES[range] or "ALL TIME" }
end

-- The day `offset` days before today.
local function dayPeriod(offset)
  local d = os.date("*t", dayTime(offset))
  return {
    kind = "day", key = dayKey(dayTime(offset)),
    from = dayTime(offset, 0), to = dayTime(offset - 1, 0),
    title = string.format("%s %d %s", WEEKDAYS[d.wday], d.day, MONTHS[d.month]),
  }
end

local function monthPeriod(year, month)
  return {
    kind = "month", key = string.format("%04d-%02d", year, month),
    from = os.time({ year = year, month = month, day = 1, hour = 0 }),
    to = os.time({ year = year, month = month + 1, day = 1, hour = 0 }),  -- month 13 rolls over
    title = string.format("%s %d", MONTHS[month], year),
  }
end

-- Focus time and work sessions (finished / started) in a period.
function stats.totals(p)
  local out = { focus = 0, done = 0, started = 0 }
  local first = (p.kind == "range" and p.from) and dayKey(p.from) or nil
  for key, day in pairs(data.days) do
    local inside
    if p.kind == "day" then
      inside = (key == p.key)
    elseif p.kind == "month" then
      inside = (key:sub(1, 7) == p.key)
    else
      inside = (first == nil) or (key >= first)  -- ISO dates compare as strings
    end
    if inside then
      out.focus = out.focus + (day.f or 0)
      out.done = out.done + (day.d or 0)
      out.started = out.started + (day.s or 0)
    end
  end
  return out
end

-- Chart for a range, oldest bar first: 7 or 30 days, or the last 6 months for "all".
-- Returns { title, bars = { focus seconds }, labels = { text | false }, periods = { period } }
function stats.chart(range)
  local out = { title = CHART_TITLES[range] or CHART_TITLES.all, bars = {}, labels = {}, periods = {} }
  local function add(p, label)
    local n = #out.periods + 1
    out.periods[n] = p
    out.bars[n] = stats.totals(p).focus
    out.labels[n] = label
  end

  if range == "week" or range == "month" then
    local n = (range == "week") and 7 or 30
    for offset = n - 1, 0, -1 do
      local d = os.date("*t", dayTime(offset))
      local label
      if n == 7 then label = WEEKDAYS[d.wday] else label = (offset % 7 == 0) and tostring(d.day) or false end
      add(dayPeriod(offset), label)
    end
  else
    local now = os.date("*t")
    for back = 5, 0, -1 do
      local y, m = now.year, now.month - back
      if m < 1 then m, y = m + 12, y - 1 end
      add(monthPeriod(y, m), MONTHS[m])
    end
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

-- Log entries in a period, newest first, at most `max` of them.
-- The log keeps the last LOG_MAX entries, so very old periods can be incomplete.
function stats.entries(p, max)
  local from, to = p.from, p.to
  local out = {}
  local log = data.log
  for i = #log, 1, -1 do
    local e = log[i]
    local t = e.t or 0
    if from and t < from then break end
    if not to or t < to then
      out[#out + 1] = e
      if max and #out >= max then break end
    end
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
