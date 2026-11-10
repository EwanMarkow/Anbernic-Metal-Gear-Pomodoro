-- kit/json.lua — small JSON encode/decode for save files.
-- Supports objects (string keys), arrays, strings, numbers, booleans; null decodes to nil.
local json = {}

-- Encode ---------------------------------------------------------------------
local ESCAPES = {
  ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
  ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
}

local function encodeString(s)
  local body = s:gsub('[%c"\\]', function(ch)
    return ESCAPES[ch] or string.format("\\u%04x", ch:byte())
  end)
  return '"' .. body .. '"'
end

local function encodeNumber(n)
  if n ~= n or n == math.huge or n == -math.huge then
    error("json: can't encode " .. tostring(n), 0)
  end
  if n % 1 == 0 and n > -2 ^ 53 and n < 2 ^ 53 then return string.format("%d", n) end
  return string.format("%.14g", n)
end

local function arrayLength(t)
  local n = 0
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then return nil end
    n = n + 1
  end
  for i = 1, n do
    if t[i] == nil then return nil end
  end
  return n
end

local encodeValue

encodeValue = function(v, pretty, depth)
  local kind = type(v)
  if kind == "nil" then return "null" end
  if kind == "boolean" then return tostring(v) end
  if kind == "number" then return encodeNumber(v) end
  if kind == "string" then return encodeString(v) end
  if kind ~= "table" then error("json: can't encode a " .. kind, 0) end
  if depth > 32 then error("json: nesting too deep", 0) end

  local pad = pretty and ("\n" .. string.rep("  ", depth + 1)) or ""
  local close = pretty and ("\n" .. string.rep("  ", depth)) or ""
  local parts = {}

  local n = arrayLength(v)
  if n then
    for i = 1, n do parts[i] = pad .. encodeValue(v[i], pretty, depth + 1) end
    return "[" .. table.concat(parts, ",") .. (n > 0 and close or "") .. "]"
  end

  local keys = {}
  for k in pairs(v) do
    if type(k) ~= "string" then error("json: object keys must be strings", 0) end
    keys[#keys + 1] = k
  end
  table.sort(keys)
  for i, k in ipairs(keys) do
    parts[i] = pad .. encodeString(k) .. (pretty and ": " or ":") .. encodeValue(v[k], pretty, depth + 1)
  end
  return "{" .. table.concat(parts, ",") .. (#keys > 0 and close or "") .. "}"
end

-- json.encode(value, pretty) -> string
function json.encode(value, pretty)
  return encodeValue(value, pretty, 0)
end

-- Decode ---------------------------------------------------------------------
local UNESCAPE = {
  b = "\b", f = "\f", n = "\n", r = "\r", t = "\t",
  ['"'] = '"', ["\\"] = "\\", ["/"] = "/",
}

local function fail(pos, what)
  error(string.format("json: %s at position %d", what, pos), 0)
end

local function skipSpace(str, pos)
  return str:find("[^ \t\r\n]", pos) or #str + 1
end

local function utf8char(cp)
  local floor = math.floor
  if cp < 0x80 then return string.char(cp) end
  if cp < 0x800 then return string.char(0xC0 + floor(cp / 0x40), 0x80 + cp % 0x40) end
  if cp < 0x10000 then
    return string.char(0xE0 + floor(cp / 0x1000), 0x80 + floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
  end
  return string.char(0xF0 + floor(cp / 0x40000), 0x80 + floor(cp / 0x1000) % 0x40,
                     0x80 + floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
end

local function decodeString(str, pos)  -- pos is at the opening quote
  local buf, i = {}, pos + 1
  while true do
    local ch = str:sub(i, i)
    if ch == "" then fail(i, "unterminated string") end
    if ch == '"' then return table.concat(buf), i + 1 end
    if ch == "\\" then
      local e = str:sub(i + 1, i + 1)
      if UNESCAPE[e] then
        buf[#buf + 1] = UNESCAPE[e]
        i = i + 2
      elseif e == "u" then
        local cp = tonumber(str:sub(i + 2, i + 5), 16)
        if not cp or #str:sub(i + 2, i + 5) ~= 4 then fail(i, "bad \\u escape") end
        i = i + 6
        if cp >= 0xD800 and cp <= 0xDBFF and str:sub(i, i + 1) == "\\u" then
          local lo = tonumber(str:sub(i + 2, i + 5), 16)
          if lo and lo >= 0xDC00 and lo <= 0xDFFF then
            cp = 0x10000 + (cp - 0xD800) * 0x400 + (lo - 0xDC00)
            i = i + 6
          end
        end
        buf[#buf + 1] = utf8char(cp)
      else
        fail(i, "bad escape")
      end
    else
      local j = str:find('["\\]', i) or (#str + 1)
      buf[#buf + 1] = str:sub(i, j - 1)
      i = j
    end
  end
end

local function decodeNumber(str, pos)
  local text = str:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
  local n = text and tonumber(text)
  if not n then fail(pos, "bad number") end
  return n, pos + #text
end

local decodeValue

decodeValue = function(str, pos, depth)
  if depth > 64 then fail(pos, "nesting too deep") end
  pos = skipSpace(str, pos)
  local ch = str:sub(pos, pos)

  if ch == "{" then
    local obj = {}
    pos = skipSpace(str, pos + 1)
    if str:sub(pos, pos) == "}" then return obj, pos + 1 end
    while true do
      if str:sub(pos, pos) ~= '"' then fail(pos, "expected a key") end
      local key, value
      key, pos = decodeString(str, pos)
      pos = skipSpace(str, pos)
      if str:sub(pos, pos) ~= ":" then fail(pos, "expected ':'") end
      value, pos = decodeValue(str, pos + 1, depth + 1)
      obj[key] = value
      pos = skipSpace(str, pos)
      local sep = str:sub(pos, pos)
      if sep == "}" then return obj, pos + 1 end
      if sep ~= "," then fail(pos, "expected ',' or '}'") end
      pos = skipSpace(str, pos + 1)
    end
  elseif ch == "[" then
    local arr, n = {}, 0
    pos = skipSpace(str, pos + 1)
    if str:sub(pos, pos) == "]" then return arr, pos + 1 end
    while true do
      local value
      value, pos = decodeValue(str, pos, depth + 1)
      n = n + 1
      arr[n] = value
      pos = skipSpace(str, pos)
      local sep = str:sub(pos, pos)
      if sep == "]" then return arr, pos + 1 end
      if sep ~= "," then fail(pos, "expected ',' or ']'") end
      pos = pos + 1
    end
  elseif ch == '"' then
    return decodeString(str, pos)
  elseif ch == "-" or ch:match("%d") then
    return decodeNumber(str, pos)
  elseif str:sub(pos, pos + 3) == "true" then
    return true, pos + 4
  elseif str:sub(pos, pos + 4) == "false" then
    return false, pos + 5
  elseif str:sub(pos, pos + 3) == "null" then
    return nil, pos + 4
  end
  fail(pos, "unexpected '" .. ch .. "'")
end

-- json.decode(string) -> value (raises an error on bad input; wrap in pcall)
function json.decode(str)
  if type(str) ~= "string" then error("json: expected a string", 0) end
  local value, pos = decodeValue(str, 1, 0)
  pos = skipSpace(str, pos)
  if pos <= #str then fail(pos, "trailing characters") end
  return value
end

return json
