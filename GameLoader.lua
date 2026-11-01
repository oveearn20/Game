--[[
    JUST HUB — GameLoader (script 2) — fast version
    - Phase 1 (PREFETCH): called before key check, downloads the game script in the background
    - Phase 2 (LOAD): called after key is valid, runs the cached script instantly
    - Matches by GameId OR PlaceId
]]

local LS = loadstring or load
_G.JustHubCache = _G.JustHubCache or {}

-- ═══════════════ CONFIG ═══════════════
local BASE = "https://raw.githubusercontent.com/oveearn20/Game/main/Games/"
local function G(file) return BASE .. file end

local GAMES = {
    -- Sometown (GameId)
    ["8835283017"] = {
        "https://raw.githubusercontent.com/oveearn20/Sometown/main/Sometown",
    },

    -- Hunting Together (PlaceId)
    ["117483759937632"] = {
        "https://raw.githubusercontent.com/oveearn20/Hunting/main/Hunting",
    },

    -- ["1111111111"] = { G("GameB.lua") },
}

-- ═══════════════ HTTP ═══════════════
local function httpGet(url)
    local methods = {
        function() return game:HttpGet(url, true) end,
        function() return game:HttpGet(url) end,
        function() return game:HttpGetAsync(url) end,
        function()
            local req = request or http_request or (syn and syn.request)
            if not req then error("no request") end
            return req({Url = url, Method = "GET"}).Body
        end,
    }
    for _, m in ipairs(methods) do
        local ok, res = pcall(m)
        if ok and type(res) == "string" and #res > 0 then return res end
    end
    return nil
end

local function isValidLua(src)
    if not src or #src < 30 then return false end
    local t = src:gsub("^%s+", "")
    if t:sub(1, 1) == "<" then return false end
    local l = t:lower()
    if l:find("404") and l:find("not found") then return false end
    if l:find("not found") and #src < 200 then return false end
    return true
end

local function fetchCached(url)
    local c = _G.JustHubCache[url]
    if c and isValidLua(c) then return c end
    local src = httpGet(url)
    if src and isValidLua(src) then
        _G.JustHubCache[url] = src
        return src
    end
    return nil
end

-- ═══════════════ FIND GAME ═══════════════
local gid = tostring(game.GameId)
local pid = tostring(game.PlaceId)
local urls = GAMES[gid] or GAMES[pid]
if type(urls) == "string" then urls = { urls } end

-- ═══════════════ PHASE 1: PREFETCH ═══════════════
-- Use from the key script (before key check):
--   _G.JustHubPrefetchMode = true
--   task.spawn(function() loadstring(game:HttpGet("GAMELOADER_URL"))() end)
if _G.JustHubPrefetchMode and not _G.JustHubAuth then
    _G.JustHubPrefetchMode = nil
    if urls then
        for _, url in ipairs(urls) do
            if fetchCached(url) then break end
        end
        print(">>> [GAMELOADER] prefetched")
    end
    return true
end

-- ═══════════════ PHASE 2: LOAD ═══════════════
if not _G.JustHubAuth then
    return false, "RUNTIME"
end

print(">>> [GAMELOADER] GameId =", gid, "| PlaceId =", pid)

if not urls then
    warn(">>> [GAMELOADER] UNSUPPORTED:", gid, pid)
    return false, "UNSUPPORTED"
end

local lastReason = "HTTP_FAIL"

for i, url in ipairs(urls) do
    local t0 = os.clock()
    local src = fetchCached(url)
    print(">>> [GAMELOADER] get #" .. i, string.format("%.2fs", os.clock() - t0))

    if src then
        local fn, err = LS(src)
        if not fn then
            warn(">>> [GAMELOADER] SYNTAX:", tostring(err))
            lastReason = "SYNTAX"
        else
            local t1 = os.clock()
            local ok, runErr = pcall(fn)
            if ok then
                print(">>> [GAMELOADER] EXECUTED", string.format("%.2fs", os.clock() - t1))
                return true
            end
            warn(">>> [GAMELOADER] RUNTIME:", tostring(runErr))
            lastReason = "RUNTIME"
        end
    else
        lastReason = "HTTP_FAIL"
    end
end

warn(">>> [GAMELOADER] All failed:", lastReason)
return false, lastReason
