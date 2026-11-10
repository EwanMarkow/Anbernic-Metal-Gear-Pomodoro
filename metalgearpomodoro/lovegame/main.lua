-- main.lua — Metal Gear Pomodoro for the Anbernic RG35XXSP (LÖVE 11.5 via PortMaster)
-- Flow: SET SESSION -> WORK -> BREAK (starts by itself) -> SESSION COMPLETE -> next round (set of 4)
-- PC test:     love lovegame --fast          (--fast: 1 minute = 1 second)
-- Device test: POMODORO_FAST=1 bash "Metal Gear Pomodoro.sh"
local log = require("kit.log")
log.installCrashScreen("Metal Gear Pomodoro")

local loop      = require("kit.loop")
local input     = require("kit.input")
local ui        = require("kit.ui")
local scale     = require("kit.scale")
local save      = require("kit.save")
local suspend   = require("kit.suspend")
local keepawake = require("kit.keepawake")
local status    = require("kit.status")
local Timer     = require("app.timer")
local chime     = require("app.chime")
local theme     = require("app.theme")
local stats     = require("app.stats")
local statusbar = require("app.statusbar")

loop.install({ fps = 30, idleRedraw = 1.0 })

local SETTINGS_FILE = "settings.json"

local DEFAULTS = {
  focusIndex = 2,          -- 30 min
  breakIndex = 2,          -- 10 min
  confirmOnB = false,      -- B confirms, A goes back
  buttonsChecked = false,  -- the one-time "press A" check has run
  positional = false,      -- gamepad reports Xbox positions (A/B and X/Y swapped)
  sound = true,            -- session, break, round, set and game-over sounds
  menuSounds = true,       -- click on every other button press
  lidMode = "keep",        -- "keep" | "pause"
  scanlines = true,
  setDate = "",            -- today's set of 4 cycles
  setDone = 0,
  setFocus = 0,            -- seconds
  setTotal = 0,            -- seconds (work + break)
}

local App = {
  FOCUS = { 15, 30, 60 },
  BREAK = { 5, 10, 20 },
  CYCLES = 4,
  secondsPerMinute = 60,
  settings = {},
  screens = {},
  screen = nil,
  screenName = nil,
  returnTo = {},           -- screen to go back to, per screen
  menu = nil,
  timer = nil,
  completePending = false, -- the SESSION COMPLETE screen is waiting
  historyRange = nil,
  splashLearn = false,     -- the title screen's A press also learns the button layout
  soundPlayed = false,     -- the current button press already made a sound
  quitStart = nil,         -- GAME OVER sequence: when it started
  quitAt = nil,            -- ... and when the app closes
  session = { focusStart = 0, focusMin = 0, focusOk = false, breakStart = 0, breakMin = 0, breakOk = false },
  toast = ui.toast,
}

App.screens.setup    = require("app.setup")
App.screens.timer    = require("app.timerview")
App.screens.complete = require("app.complete")
App.screens.stats    = require("app.statsview")
App.screens.history  = require("app.history")
App.screens.settings = require("app.settings")
App.screens.splash   = require("app.splash")

-- Settings ------------------------------------------------------------------------
function App.loadSettings()
  local loaded = save.load(SETTINGS_FILE, {})
  for key, default in pairs(DEFAULTS) do
    local value = loaded[key]
    App.settings[key] = (type(value) == type(default)) and value or default
  end
  local s = App.settings
  s.focusIndex = math.max(1, math.min(#App.FOCUS, math.floor(s.focusIndex)))
  s.breakIndex = math.max(1, math.min(#App.BREAK, math.floor(s.breakIndex)))
  s.setDone = math.max(0, math.min(App.CYCLES, math.floor(s.setDone)))
  if s.lidMode ~= "keep" and s.lidMode ~= "pause" then s.lidMode = "keep" end
end

function App.save()
  save.write(SETTINGS_FILE, App.settings)
end

function App.minutes(phase)
  local s = App.settings
  if phase == "focus" then return App.FOCUS[s.focusIndex] end
  return App.BREAK[s.breakIndex]
end

function App.toggleSound()
  App.settings.sound = not App.settings.sound
  ui.toast(App.settings.sound and "SOUND ON" or "SOUND OFF")
  App.save()
end

-- Event sounds (SOUND setting). Marks the press as handled, so it gets no extra click.
function App.playChime(which)
  App.soundPlayed = true
  if App.settings.sound then chime.play(which) end
end

-- The default click (MENU SOUNDS setting).
function App.navSound()
  if App.settings.menuSounds then chime.play("nav") end
end

-- Screens ---------------------------------------------------------------------------
function App.switch(name)
  App.screen = App.screens[name]
  App.screenName = name
  if App.screen.enter then App.screen.enter(App) end
  loop.invalidate()
end

-- Open a screen and remember where to come back to.
function App.open(name)
  App.returnTo[name] = App.screenName
  App.switch(name)
end

function App.back()
  App.switch(App.returnTo[App.screenName] or "setup")
end

function App.openMenu(menu)
  App.menu = menu
  loop.invalidate()
end

function App.timerActive()
  local state = App.timer.state
  return state == "running" or state == "paused"
end

-- Where Y (TIMER) leads.
function App.timerScreen()
  if App.timerActive() then return "timer" end
  if App.completePending then return "complete" end
  return "setup"
end

-- "POMODORO n/4"
function App.cycleNumber()
  local s = App.settings
  if s.setDate ~= os.date("%Y-%m-%d") then return 1 end
  if App.completePending then return math.max(1, s.setDone) end
  return math.min(App.CYCLES, s.setDone + 1)
end

-- Session flow ----------------------------------------------------------------------
-- Seconds the current phase actually ran (in real-world seconds, also in fast mode).
local function elapsedSeconds()
  local t = App.timer
  return (t.duration - t:remaining()) * 60 / App.secondsPerMinute
end

function App.startFocus()
  local s = App.settings
  local today = os.date("%Y-%m-%d")
  if s.setDate ~= today or s.setDone >= App.CYCLES then
    s.setDate, s.setDone, s.setFocus, s.setTotal = today, 0, 0, 0
  end
  App.completePending = false
  local minutes = App.minutes("focus")
  App.timer:start("focus", minutes * App.secondsPerMinute)
  local ses = App.session
  ses.focusStart, ses.focusMin, ses.focusOk = os.time(), minutes, false
  ses.breakMin, ses.breakOk = App.minutes("break"), false
  App.save()
  App.playChime("sessionStart")
  log.info(("work %d min, cycle %d/%d"):format(minutes, s.setDone + 1, App.CYCLES))
  App.switch("timer")
end

local function startBreak()
  local minutes = App.minutes("break")
  App.timer:start("break", minutes * App.secondsPerMinute)
  App.session.breakStart, App.session.breakMin = os.time(), minutes
  App.switch("timer")
end

local function endFocus(ok)
  local s, ses = App.settings, App.session
  local seconds = elapsedSeconds()
  if ok or seconds >= 60 then  -- ignore accidental starts
    stats.record("focus", ses.focusStart, ses.focusMin, seconds, ok)
  end
  ses.focusOk = ok
  if ok then
    s.setFocus = s.setFocus + seconds
    s.setTotal = s.setTotal + seconds
  end
end

local function endBreak(ok)
  local s, ses = App.settings, App.session
  local seconds = elapsedSeconds()
  stats.record("break", ses.breakStart, ses.breakMin, seconds, ok)
  ses.breakOk = ok
  s.setTotal = s.setTotal + seconds
  if ses.focusOk then s.setDone = math.min(App.CYCLES, s.setDone + 1) end
end

local function focusFinished(whileAsleep)
  endFocus(true)
  App.save()
  App.playChime("restStart")
  App.menu = nil
  log.info("work finished" .. (whileAsleep and " (lid was closed)" or ""))
  startBreak()
  ui.toast(whileAsleep and "WORK ENDED WHILE THE LID WAS CLOSED" or "BREAK TIME", 3)
end

-- Break over: ok = ran to the end, false = skipped.
function App.finishBreak(ok, whileAsleep)
  endBreak(ok)
  App.timer:stop()
  App.completePending = true
  App.save()
  if App.session.focusOk then  -- the round counts (even with a skipped break)
    App.playChime((App.settings.setDone >= App.CYCLES) and "streak" or "round")
  end
  App.menu = nil
  log.info(ok and "break finished" or "break skipped")
  App.switch("complete")
  if whileAsleep then ui.toast("BREAK ENDED WHILE THE LID WAS CLOSED", 3) end
end

-- Record the running session as unfinished and stop the clock.
local function abortSession()
  local t = App.timer
  if t.phase == "focus" then endFocus(false) else endBreak(false) end
  t:stop()
  App.completePending = false
  App.save()
  log.info("session aborted")
end

function App.stopSession()
  abortSession()
  App.playChime("gameOver")
  App.switch("setup")
  ui.toast("SESSION ABORTED", 2.5)
end

-- Menu QUIT: mid-session it plays GAME OVER first, then closes.
function App.quit()
  if not App.timerActive() then
    love.event.quit()  -- love.quit() below saves
    return
  end
  abortSession()
  App.playChime("gameOver")
  local wait = App.settings.sound and math.min(4, chime.duration("gameOver")) or 0
  App.quitStart = love.timer.getTime()
  App.quitAt = App.quitStart + math.max(1.2, wait)
end

-- Start+Select / Esc: close right away, but still record an unfinished session.
local function quitNow()
  if App.timerActive() then abortSession() end
  love.event.quit()
end

-- Menus -----------------------------------------------------------------------------
local MENU_HINTS = { { "dpad", "MOVE" }, { "confirm", "SELECT" }, { "back", "CLOSE" } }

local function onMainMenu(id)
  if id == "settings" then
    App.open("settings")
  elseif id == "quit" then
    App.quit()
  end
end

function App.openMainMenu()
  local items = { { id = "settings", label = "SETTINGS" }, { id = "quit", label = "QUIT" } }
  App.openMenu(ui.newMenu({ title = "MENU", items = items, cancel = "close", onChoose = onMainMenu, hints = MENU_HINTS }))
end

function App.confirmStop()
  App.openMenu(ui.newMenu({
    title = "STOP THIS SESSION?",
    items = { { id = "keep", label = "KEEP GOING" }, { id = "stop", label = "STOP AND GO HOME" } },
    cancel = "keep",
    hints = MENU_HINTS,
    onChoose = function(id)
      if id == "stop" then App.stopSession() end
    end,
  }))
end

-- Input -----------------------------------------------------------------------------
local function handle(a, isRepeat)
  if App.menu then
    local menu = App.menu
    local id = menu:action(a)
    if id then
      App.menu = nil
      menu.onChoose(id)
    end
    return
  end

  local screen = App.screen
  if a == "select" then App.toggleSound() return end
  if a == "start" and not screen.ownsStart then App.openMainMenu() return end
  if screen.tabs then
    if a == "x" and App.screenName ~= "stats" and App.screenName ~= "history" then App.open("stats") return end
    if a == "y" then App.switch(App.timerScreen()) return end
  end
  screen.action(App, a, isRepeat)
end

local function onAction(a, isRepeat)
  if a == "quit" then quitNow() return end
  if App.quitAt then return end  -- GAME OVER is playing
  loop.invalidate()
  App.soundPlayed = false
  handle(a, isRepeat)
  if not App.soundPlayed then App.navSound() end  -- every press without its own sound clicks
end

-- Lid / sleep -----------------------------------------------------------------------
local function formatAway(seconds)
  if seconds < 60 then return ("%d SEC"):format(seconds) end
  return ("%d MIN"):format(math.floor(seconds / 60))
end

local function handleWake(asleep, missed)
  input.reset()
  status.refresh()
  loop.invalidate()
  log.info(("woke up after about %d s asleep"):format(asleep))
  local t = App.timer
  if t.state ~= "running" then return end
  if App.settings.lidMode == "pause" then
    t:shift(-(asleep - missed))  -- give back whatever the clock counted while asleep
    t:pause()
    ui.toast("PAUSED WHILE THE LID WAS CLOSED", 3)
  else
    t:shift(missed)              -- the real time that passed counts
    if t:remaining() > 0 then ui.toast("LID WAS CLOSED FOR " .. formatAway(asleep), 3) end
  end
end

-- GAME OVER overlay while the quit sound plays.
local function drawGameOver()
  local p = math.min(1, (love.timer.getTime() - App.quitStart) / 0.6)
  ui.setColor(ui.color.dark, 0.88 * p)
  love.graphics.rectangle("fill", 0, 0, ui.W, ui.H)
  local f = ui.font(64)
  love.graphics.setFont(f)
  ui.setColor(theme.c.fill, p)
  love.graphics.print("GAME OVER", math.floor((ui.W - f:getWidth("GAME OVER")) / 2), ui.capY(64, 220))
  local g = ui.font(18)
  love.graphics.setFont(g)
  ui.setColor(theme.c.dim, p)
  love.graphics.print("MISSION ABORTED", math.floor((ui.W - g:getWidth("MISSION ABORTED")) / 2), ui.capY(18, 282))
end

-- LÖVE callbacks --------------------------------------------------------------------
function love.load(args)
  love.mouse.setVisible(false)
  for _, a in ipairs(args or {}) do
    if a == "--fast" then App.secondsPerMinute = 1 end
  end
  if os.getenv("POMODORO_FAST") == "1" then App.secondsPerMinute = 1 end

  local major, minor, revision = love.getVersion()
  local renderer, rversion = love.graphics.getRendererInfo()
  log.info(("Metal Gear Pomodoro starting | LOVE %d.%d.%d | %s | %s %s%s"):format(
    major, minor, revision, love.system.getOS(), renderer, rversion,
    App.secondsPerMinute == 1 and " | FAST MODE" or ""))

  if not theme.apply() then log.warn("font " .. theme.FONT .. " missing, using the built-in font") end
  scale.init({ w = 640, h = 480 })
  chime.load()
  App.loadSettings()
  stats.load()
  keepawake.init()
  status.update()
  App.timer = Timer.new()

  input.install()
  input.setSwap(App.settings.confirmOnB)
  input.setPositional(App.settings.positional)
  input.onAction = onAction

  suspend.reset()
  App.switch("setup")
  App.splashLearn = not App.settings.buttonsChecked
  App.open("splash")
end

function love.update(dt)
  dt = math.min(dt, 1 / 20)  -- animations never jump (the countdown uses its own clock)
  input.update(dt)

  if App.quitAt then
    loop.invalidate()
    if love.timer.getTime() >= App.quitAt then love.event.quit() end
    return
  end

  local asleep, missed = suspend.check()
  if asleep then handleWake(asleep, missed) end

  if App.timer:update() then
    if App.timer.phase == "focus" then focusFinished(asleep ~= nil) else App.finishBreak(true, asleep ~= nil) end
  end
  keepawake.set(App.timer.state == "running")  -- screen stays on only while the clock runs
  if status.update() then loop.invalidate() end
  if statusbar.update(status, not App.screen.noStatus) then loop.invalidate() end
  if ui.updateToasts(dt) then loop.invalidate() end
  if App.screen.update then App.screen.update(App, dt) end
end

function love.draw()
  scale.begin()
  ui.rect(0, 0, ui.W, ui.H, ui.color.bg, 0)
  App.screen.draw(App)
  if not App.screen.noStatus then statusbar.draw(status) end
  theme.frame()
  if App.menu then App.menu:draw() end
  ui.drawToasts()
  if App.quitAt then drawGameOver() end
  if App.settings.scanlines then theme.scanlines() end
  scale.finish()
end

function love.resize(w, h)
  scale.resize(w, h)
end

function love.focus(focused)
  if not focused then input.reset() end
end

function love.joystickadded(joystick)
  log.info(("controller: %s | gamepad mapping: %s | GUID %s"):format(
    joystick:getName(), joystick:isGamepad() and "yes" or "NO", joystick:getGUID()))
end

function love.quit()
  keepawake.set(false)
  App.save()
  log.info("bye")
  return false
end
