-- app/timer.lua — Pomodoro countdown on LÖVE's monotonic clock. Pure logic, no drawing.
-- States: "idle" -> "running" <-> "paused" -> "done"
local Timer = {}
Timer.__index = Timer

-- clock: function returning seconds (defaults to love.timer.getTime; tests pass a fake)
function Timer.new(clock)
  return setmetatable({
    clock = clock or love.timer.getTime,
    state = "idle",
    phase = "focus",   -- "focus" | "break"
    duration = 0,      -- seconds
    deadline = 0,      -- clock() value when the phase ends (while running)
    frozen = 0,        -- remaining seconds (while paused)
  }, Timer)
end

function Timer:start(phase, seconds)
  self.phase, self.duration = phase, seconds
  self.deadline = self.clock() + seconds
  self.state = "running"
end

function Timer:remaining()
  if self.state == "running" then return math.max(0, self.deadline - self.clock()) end
  if self.state == "paused" then return self.frozen end
  if self.state == "done" then return 0 end
  return self.duration
end

-- 0 at the start of the phase, 1 at the end
function Timer:progress()
  if self.duration <= 0 then return 0 end
  return 1 - self:remaining() / self.duration
end

function Timer:pause()
  if self.state ~= "running" then return end
  self.frozen = self:remaining()
  self.state = "paused"
end

function Timer:resume()
  if self.state ~= "paused" then return end
  self.deadline = self.clock() + self.frozen
  self.state = "running"
end

function Timer:toggle()
  if self.state == "running" then self:pause() elseif self.state == "paused" then self:resume() end
end

function Timer:stop()
  self.state = "idle"
end

-- Take `seconds` off a running timer (negative gives time back).
function Timer:shift(seconds)
  if self.state == "running" then self.deadline = self.deadline - seconds end
end

-- Returns true exactly once: on the frame the phase ends.
function Timer:update()
  if self.state == "running" and self.clock() >= self.deadline then
    self.state = "done"
    return true
  end
  return false
end

return Timer
