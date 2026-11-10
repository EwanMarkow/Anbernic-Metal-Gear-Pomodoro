-- kit/save.lua — atomic JSON saves in LÖVE's save folder.
-- On the device the launch script sets XDG_DATA_HOME=$GAMEDIR/conf, so files land in
--   <app folder>/conf/love/<identity>/<name>
-- On macOS: ~/Library/Application Support/LOVE/<identity>/<name>
local json = require("kit.json")
local log = require("kit.log")

local save = {}

local function realPath(name)
  return love.filesystem.getSaveDirectory() .. "/" .. name
end

-- Returns the decoded table, or `fallback` if the file is missing or unreadable.
function save.load(name, fallback)
  local file = name
  if not love.filesystem.getInfo(file, "file") then
    -- power was cut between "remove old" and "rename new": the .tmp is the newest copy
    file = name .. ".tmp"
    if not love.filesystem.getInfo(file, "file") then return fallback end
  end
  local text = love.filesystem.read(file)
  local ok, data = pcall(json.decode, text or "")
  if ok and type(data) == "table" then return data end
  log.warn("save: " .. file .. " is unreadable, using defaults (" .. tostring(data) .. ")")
  return fallback
end

-- Write <name>.tmp, then rename it over <name>: a power cut leaves the old or the new file,
-- never half of one.
function save.write(name, data)
  local ok, text = pcall(json.encode, data, true)
  if not ok then
    log.error("save: encode failed: " .. tostring(text))
    return false
  end
  local tmp = name .. ".tmp"
  local wrote, err = love.filesystem.write(tmp, text)
  if not wrote then
    log.error("save: write failed: " .. tostring(err))
    return false
  end
  local renamed, rerr = os.rename(realPath(tmp), realPath(name))
  if not renamed then
    -- some filesystems refuse to rename over an existing file: remove it, then retry
    os.remove(realPath(name))
    renamed, rerr = os.rename(realPath(tmp), realPath(name))
  end
  if not renamed then
    log.error("save: rename failed: " .. tostring(rerr))
    return false
  end
  if love.system.getOS() == "Linux" then os.execute("sync") end  -- flush the SD card cache
  return true
end

return save
