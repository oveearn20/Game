--[[
    JUST HUB — GameLoader (script 2)
    - Called by the key script after the key is validated
    - Detects the game by GameId OR PlaceId and loads that game's script
    - To add a game: add ONE line in the GAMES table below
]]

if not _G.JustHubAuth then
    return false, "RUNTIME"
end

local LS = loadstring or load

local BASE = "https://raw.githubusercontent.com/oveearn20/Game/main/Games/"

local function G(file)
    return BASE .. file
end

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
    -- ["2222222222"] = { G("GameC.lua"), "https://backup/GameC.lua" },
}

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
        if ok and type(res) == "string" and #res > 0 then
            return res
        end
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

local gid = tostring(game.GameId)
local pid = tostring(game.PlaceId)
print(">>> [GAMELOADER] GameId =", gid, "| PlaceId =", pid)

local urls = GAMES[gid]
local matchedBy = "GameId"
if not urls then
    urls = GAMES[pid]
    matchedBy = "PlaceId"
end

if not urls then
    warn(">>> [GAMELOADER] UNSUPPORTED GameId:", gid, "| PlaceId:", pid)
    return false, "UNSUPPORTED"
end
print(">>> [GAMELOADER] matched by", matchedBy)

if type(urls) == "string" then urls = { urls } end

local lastReason = "HTTP_FAIL"

for i, url in ipairs(urls) do
    print(">>> [GAMELOADER] try #" .. i, url)
    local src = httpGet(url)

    if src and isValidLua(src) then
        local fn, err = LS(src)
        if not fn then
            warn(">>> [GAMELOADER] SYNTAX:", tostring(err))
            lastReason = "SYNTAX"
        else
            local ok, runErr = pcall(fn)
            if ok then
                print(">>> [GAMELOADER] GAME SCRIPT EXECUTED")
                return true
            end
            warn(">>> [GAMELOADER] RUNTIME:", tostring(runErr))
            lastReason = "RUNTIME"
        end
    else
        lastReason = "HTTP_FAIL"
    end

    if i < #urls then task.wait(0.3) end
end

warn(">>> [GAMELOADER] All failed:", lastReason)
return false, lastReason
