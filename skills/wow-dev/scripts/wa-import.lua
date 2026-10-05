--[[
Build a WeakAuras import string from an aura definition table, offline.

Usage:
    lua wa-import.lua <aura-def.lua> [out.txt] [--remote] [--refresh]

The definition file must return the aura data table, for example:
    return { id = "MyAura", uid = "abc12345678", regionType = "icon", ... }

Sources, in order of preference:
  1. An installed WeakAuras, which is authoritative for what the user runs.
  2. GitHub, when WeakAuras is not installed. LibDeflate and LibSerialize are
     not vendored in the WeakAuras2 repo, so they come from the upstreams the
     WeakAuras2 .pkgmeta pins. Downloads are cached.

Flags:
    --remote   ignore any local install and use GitHub
    --refresh  redownload rather than reuse the cache

Requires a Lua interpreter, plus curl for the remote path. Lua 5.2 and newer
need no extra setup, the 5.1 globals WoW provides are shimmed below.
]]

-- Shim the Lua 5.1 globals WoW provides but newer Lua dropped
unpack = unpack or table.unpack
loadstring = loadstring or load

-- Pinned by the WeakAuras2 .pkgmeta, LibSerialize to a tag and LibDeflate to its default branch
local LIBDEFLATE_URL = "https://raw.githubusercontent.com/SafeteeWoW/LibDeflate/master/LibDeflate.lua"
local LIBSERIALIZE_URL = "https://raw.githubusercontent.com/rossnichols/LibSerialize/v1.0.0/LibSerialize.lua"
local TRANSMISSION_URL = "https://raw.githubusercontent.com/WeakAuras/WeakAuras2/main/WeakAuras/Transmission.lua"
local RELEASE_URL = "https://api.github.com/repos/WeakAuras/WeakAuras2/releases/latest"

local CACHE = (os.getenv("HOME") or ".") .. "/.cache/wowdev-weakauras"

local function fail(msg)
    io.stderr:write("error: " .. msg .. "\n")
    os.exit(1)
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("a")
    f:close()
    return s
end

local function shell(cmd)
    local p = io.popen(cmd)
    if not p then return nil end
    local out = p:read("a")
    p:close()
    return out
end

local args, flags = {}, {}

for _, a in ipairs(arg) do
    if a:sub(1, 2) == "--" then flags[a:sub(3)] = true else args[#args + 1] = a end
end

local defPath = args[1] or fail("usage: lua wa-import.lua <aura-def.lua> [out.txt] [--remote] [--refresh]")
local outPath = args[2]

-- Find an installed WeakAuras across every WoW flavor present
local function findLocalWeakAuras()
    if os.getenv("WA_PATH") then return os.getenv("WA_PATH") end
    local out = shell([[ls -d "/Applications/World of Warcraft/"*"/Interface/AddOns/WeakAuras" 2>/dev/null]])
    if not out then return nil end
    return out:match("([^\n]+)")
end

local function download(url, dest)
    if not flags.refresh then
        local cached = readFile(dest)
        if cached and #cached > 0 then return dest end
    end
    os.execute(string.format("mkdir -p %q", CACHE))
    os.execute(string.format("curl -fsSL %q -o %q", url, dest))
    local got = readFile(dest)
    if not got or #got == 0 then fail("could not download " .. url) end
    return dest
end

-- Resolve the two libraries and the version constants the import string needs
local function resolveSources()
    local wa = not flags.remote and findLocalWeakAuras() or nil

    if wa and readFile(wa .. "/Libs/LibDeflate/LibDeflate.lua") then
        local transmission = readFile(wa .. "/Transmission.lua") or fail("cannot read Transmission.lua")
        local init = readFile(wa .. "/Init.lua") or fail("cannot read Init.lua")
        local version = transmission:match("local version = (%d+)") or fail("no transmission version found")
        local versionString = init:match('local versionString = "([^"]+)"') or "Dev"

        return {
            origin = "local install at " .. wa,
            deflate = wa .. "/Libs/LibDeflate/LibDeflate.lua",
            serialize = wa .. "/Libs/LibSerialize/LibSerialize.lua",
            version = tonumber(version),
            versionString = versionString,
        }
    end

    if not shell("command -v curl 2>/dev/null") then
        fail("no local WeakAuras and no curl, cannot fetch the libraries")
    end

    local deflate = download(LIBDEFLATE_URL, CACHE .. "/LibDeflate.lua")
    local serialize = download(LIBSERIALIZE_URL, CACHE .. "/LibSerialize.lua")
    local transmission = readFile(download(TRANSMISSION_URL, CACHE .. "/Transmission.lua"))

    local version = transmission:match("local version = (%d+)") or fail("no transmission version found")

    -- Take the version string from the latest release, since the repo ships a packager placeholder
    local release = shell(string.format("curl -fsSL %q 2>/dev/null", RELEASE_URL)) or ""
    local versionString = release:match('"tag_name"%s*:%s*"([^"]+)"') or "Dev"

    return {
        origin = "github, cached in " .. CACHE,
        deflate = deflate,
        serialize = serialize,
        version = tonumber(version),
        versionString = versionString,
    }
end

local src = resolveSources()

local stub = { libs = {} }
function stub:NewLibrary(n) if self.libs[n] then return nil end self.libs[n] = {} return self.libs[n] end
function stub:GetLibrary(n) return self.libs[n] end
LibStub = setmetatable(stub, { __call = function(s, n) return s.libs[n] end })

local LibDeflate = dofile(src.deflate)
local LibSerialize = dofile(src.serialize)

local chunk = assert(loadfile(defPath))
local data = chunk()

if type(data) ~= "table" then fail("the definition file must return a table") end
if not data.id then fail("the aura table needs an id") end
if not data.regionType then fail("the aura table needs a regionType") end

local transmit = { m = "d", d = data, v = src.version, s = src.versionString }
local serialized = LibSerialize:SerializeEx({ errorOnUnserializableType = false }, transmit)
local compressed = LibDeflate:CompressDeflate(serialized, { level = 9 })
local encoded = "!WA:2!" .. LibDeflate:EncodeForPrint(compressed)

-- Decode the finished string so validation runs against what a user would paste
local roundTripped = LibDeflate:DecompressDeflate(LibDeflate:DecodeForPrint(encoded:sub(7)))
local ok, result = LibSerialize:Deserialize(roundTripped)

if not ok then fail("the string does not decode: " .. tostring(result)) end
if result.d.id ~= data.id then fail("the decoded aura id does not match") end

-- Compile each custom block exactly as WeakAuras wraps it, so syntax errors surface here
local problems, checked = {}, 0

local function compile(label, source)
    checked = checked + 1
    local fn, err = load(source, label)
    if not fn then problems[#problems + 1] = label .. ": " .. tostring(err) end
end

local function checkTrigger(t, label)
    if type(t.custom) == "string" and t.custom ~= "" then
        compile(label .. ".custom", "return " .. t.custom)
    end
    if type(t.customVariables) == "string" and t.customVariables ~= "" then
        compile(label .. ".customVariables", "return function() return \n" .. t.customVariables .. "\n end")
    end
    for _, key in ipairs({ "customDuration", "customName", "customIcon", "customTexture", "customStacks" }) do
        if type(t[key]) == "string" and t[key] ~= "" then
            compile(label .. "." .. key, "return " .. t[key])
        end
    end
end

local d = result.d

if d.triggers then
    for i, entry in ipairs(d.triggers) do
        if type(entry) == "table" then
            if entry.trigger then checkTrigger(entry.trigger, "trigger[" .. i .. "]") end
            if entry.untrigger then checkTrigger(entry.untrigger, "untrigger[" .. i .. "]") end
        end
    end
end

if d.actions then
    for _, when in ipairs({ "init", "start", "finish" }) do
        local a = d.actions[when]
        if type(a) == "table" then
            for _, key in ipairs({ "custom", "customOnLoad", "customOnUnload" }) do
                if type(a[key]) == "string" and a[key] ~= "" then
                    compile("actions." .. when .. "." .. key, "return function() " .. a[key] .. "\n end")
                end
            end
        end
    end
end

if #problems > 0 then
    io.stderr:write("custom code failed to compile:\n")
    for _, p in ipairs(problems) do io.stderr:write("  " .. p .. "\n") end
    os.exit(1)
end

io.stderr:write(string.format(
    "ok  aura=%s  region=%s  wa=%s  transmit=%d  codeBlocks=%d  length=%d\n  source: %s\n",
    d.id, d.regionType, src.versionString, src.version, checked, #encoded, src.origin))

if outPath then
    local f = assert(io.open(outPath, "w"))
    f:write(encoded)
    f:close()
end

print(encoded)
