-- kit/suspend.lua — notice when the device was asleep (lid closed, power button).
-- LÖVE's timer uses a monotonic clock that normally stops while the device sleeps, while the
-- wall clock (os.time) keeps going. A wall-clock jump of several seconds between two frames
-- (which are ~33 ms apart) means the app was frozen.
local suspend = { threshold = 4 }

local lastWall, lastMono

function suspend.reset()
  lastWall, lastMono = os.time(), love.timer.getTime()
end

-- Call once per frame. Returns nil normally. Right after a sleep it returns:
--   asleep  seconds of real time that passed while frozen
--   missed  seconds of that the monotonic clock did NOT count (usually == asleep)
function suspend.check()
  local wall, mono = os.time(), love.timer.getTime()
  if not lastWall then
    lastWall, lastMono = wall, mono
    return nil
  end
  local dWall, dMono = wall - lastWall, mono - lastMono
  lastWall, lastMono = wall, mono
  if dWall >= suspend.threshold then
    return dWall, math.max(0, dWall - dMono)
  end
  return nil
end

return suspend
