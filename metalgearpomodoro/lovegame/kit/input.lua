-- kit/input.lua — one input layer for gamepad (SDL GameController), keyboard and gptokeyb.
--
-- Physical buttons (Nintendo labels): a b x y up down left right l1 r1 l2 r2 start select menu
-- Actions sent to input.onAction(action, isRepeat):
--   up down left right    auto-repeat while held
--   confirm back          A / B (input.setSwap(true) makes B confirm and A go back)
--   x y l1 r1 l2 r2 menu  passed through by name
--   start select          sent on RELEASE, so a Start+Select press never triggers them
--   quit                  Start+Select together, or Esc on a keyboard
--
-- PC keys: arrows = D-pad, X = A, Z = B, S = X, A = Y, Q/W = L1/R1, 1/2 = L2/R2,
--          Enter = Start, Right Shift = Select, Esc = quit.
--
-- SDL names gamepad buttons by POSITION (Xbox layout: "a" = bottom). Some controller configs
-- report the Nintendo LABELS instead. input.setPositional(true) remaps a<->b and x<->y for the
-- gamepad so that "a" is always the button labelled A. Use input.captureNext() for a one-time
-- "press A" check to find out which one you have.

local input = {
  repeatDelay = 0.35,  -- seconds before a held direction starts repeating
  repeatRate  = 0.09,  -- seconds between repeats
  dedupWindow = 0.08,  -- same button from pad AND keyboard (gptokeyb) within this = one press
}

local PAD = {
  a = "a", b = "b", x = "x", y = "y",
  dpup = "up", dpdown = "down", dpleft = "left", dpright = "right",
  leftshoulder = "l1", rightshoulder = "r1",
  start = "start", back = "select", guide = "menu",
}

local KEYS = {
  up = "up", down = "down", left = "left", right = "right",
  x = "a", z = "b", s = "x", a = "y",
  q = "l1", w = "r1", ["1"] = "l2", ["2"] = "r2",
  ["return"] = "start", kpenter = "start", rshift = "select",
}

local DIRECTIONS = { up = true, down = true, left = true, right = true }
local FACE = { a = true, b = true, x = true, y = true }
local POSITION_SWAP = { a = "b", b = "a", x = "y", y = "x" }

local held = {}        -- button -> true while down
local lastTime = {}    -- button -> time of last accepted press
local lastSource = {}  -- button -> "pad" | "key"
local swap = false
local positional = false
local capture = nil
local comboFired = false
local repeatButton, repeatTimer = nil, 0

function input.onAction(action, isRepeat) end  -- replace this in your app

local function emit(action, isRepeat)
  input.onAction(action, isRepeat or false)
end

local function actionFor(button)
  if button == "a" then return swap and "back" or "confirm" end
  if button == "b" then return swap and "confirm" or "back" end
  return button
end

local function padButton(sdlButton)
  local b = PAD[sdlButton]
  if b and positional and POSITION_SWAP[b] then b = POSITION_SWAP[b] end
  return b
end

local function press(button, source)
  local now = love.timer.getTime()
  if lastSource[button] and lastSource[button] ~= source and now - lastTime[button] < input.dedupWindow then
    return
  end
  if held[button] then return end
  held[button] = true
  lastTime[button], lastSource[button] = now, source

  if button == "start" or button == "select" then
    if held.start and held.select then
      comboFired = true
      emit("quit")
    end
    return
  end
  if DIRECTIONS[button] then repeatButton, repeatTimer = button, input.repeatDelay end
  emit(actionFor(button))
end

local function release(button)
  if not held[button] then return end
  held[button] = nil
  if button == "start" or button == "select" then
    if not comboFired then emit(button) end
    if not held.start and not held.select then comboFired = false end
    return
  end
  if repeatButton == button then repeatButton = nil end
end

function input.update(dt)
  if repeatButton and held[repeatButton] then
    repeatTimer = repeatTimer - dt
    if repeatTimer <= 0 then
      repeatTimer = input.repeatRate
      emit(repeatButton, true)
    end
  end
end

function input.isDown(button) return held[button] == true end

-- Forget held buttons (call after sleep/resume or focus loss so nothing sticks).
function input.reset()
  for k in pairs(held) do held[k] = nil end
  repeatButton, comboFired = nil, false
end

-- Preference: B confirms, A goes back.
function input.setSwap(on) swap = on and true or false end
function input.getSwap() return swap end

-- Controller fix: the gamepad reports positions, not labels (see top of file).
function input.setPositional(on) positional = on and true or false end
function input.getPositional() return positional end

-- Call fn(button, source) for the next face-button press instead of sending an action.
-- button is the raw name ("a" "b" "x" "y", before setPositional), source is "pad" or "key".
-- Return false from fn to keep listening. input.captureNext(nil) cancels.
function input.captureNext(fn) capture = fn end

-- Button letter to show in hints for an action: "confirm" -> "A" (or "B" when swapped)
function input.labelFor(action)
  if action == "confirm" then return swap and "B" or "A" end
  if action == "back" then return swap and "A" or "B" end
  return string.upper(action)
end

-- LÖVE callbacks ------------------------------------------------------------
function input.keypressed(key)
  if key == "escape" then emit("quit") return end
  local b = KEYS[key]
  if capture and b and FACE[b] then
    if capture(b, "key") ~= false then capture = nil end
    return
  end
  if b then press(b, "key") end
end

function input.keyreleased(key)
  local b = KEYS[key]
  if b then release(b) end
end

function input.gamepadpressed(_, button)
  local raw = PAD[button]
  if capture and raw and FACE[raw] then
    if capture(raw, "pad") ~= false then capture = nil end
    return
  end
  local b = padButton(button)
  if b then press(b, "pad") end
end

function input.gamepadreleased(_, button)
  local b = padButton(button)
  if b then release(b) end
end

function input.gamepadaxis(_, axis, value)
  local b = (axis == "triggerleft" and "l2") or (axis == "triggerright" and "r2") or nil
  if not b then return end
  if value > 0.5 then press(b, "pad") elseif value < 0.3 then release(b) end
end

-- Route LÖVE's input callbacks here. Call once from love.load.
function input.install()
  love.keypressed = input.keypressed
  love.keyreleased = input.keyreleased
  love.gamepadpressed = input.gamepadpressed
  love.gamepadreleased = input.gamepadreleased
  love.gamepadaxis = input.gamepadaxis
end

return input
