--[[
    JUST HUB — GameLoader (script 2) — SECURE + ENCRYPTED MAPS
    - รับ session (key + decKey) จากไฟล์ key ผ่าน getgenv().JustHubSession
    - validate key ซ้ำกับ PandaAuth (กัน bypass แบบตั้ง global เอง)
    - โหลดแมพตาม GameId/PlaceId แล้วถอดรหัส (XOR+Base64) ด้วย decKey
    - PREFETCH: โหลด blob ล่วงหน้าได้ (blob เข้ารหัสอยู่แล้ว ปลอดภัย)
]]

local LS = loadstring or load
_G.JustHubCache = _G.JustHubCache or {}

-- ═══════════════ CONFIG ═══════════════
-- TEST_MODE = true  -> ถ้าแมพยังเป็น Lua ธรรมดา (ยังไม่เข้ารหัส) ก็รันได้ (ไว้เทส)
-- TEST_MODE = false -> บังคับถอดรหัสเสมอ (ใช้ตอนปล่อยจริง หลังเข้ารหัสแมพแล้ว)
local TEST_MODE   = true

-- REQUIRE_KEY = true -> บังคับ validate key กับ PandaAuth (กัน bypass) — อย่าปิดตอนจริง
local REQUIRE_KEY = true
local SERVICE_ID  = "justhubkey"

local BASE = "https://raw.githubusercontent.com/oveearn20/Game/main/Games/"
local function G(file) return BASE .. file end
local TYPER_TOWN = "https://raw.githubusercontent.com/oveearn20/Game/main/Typer%20town"
local ANIME_DICE = "https://raw.githubusercontent.com/oveearn20/Game/main/Anime%20dice"

local GAMES = {
    -- Sometown (GameId)
    ["8835283017"] = {
        "https://raw.githubusercontent.com/oveearn20/Sometown/main/Sometown",
    },

    -- Hunting Together (PlaceId)
    ["117483759937632"] = {
        "https://raw.githubusercontent.com/oveearn20/Hunting/main/Hunting",
    },

    -- Typer town
    ["119554426329370"] = { TYPER_TOWN },
    ["73746968849439"]  = { TYPER_TOWN },

    -- Anime Dice
    ["10708913337"]     = { ANIME_DICE },
    ["113290951185459"] = { ANIME_DICE },

    -- ["1111111111"] = { G("GameB.lua") },
}

-- ═══════════════ SESSION (จากไฟล์ key) ═══════════════
local env     = (getgenv and getgenv()) or _G
local session = env.JustHubSession

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

-- blob ที่โหลดมาต้องไม่ใช่ HTML/404 (ใช้ได้ทั้ง Lua ธรรมดาและข้อความเข้ารหัส)
local function isValidBlob(src)
    if not src or #src < 20 then return false end
    local t = src:gsub("^%s+", "")
    if t:sub(1, 1) == "<" then return false end
    local l = t:lower()
    if l:find("404") and l:find("not found") then return false end
    if l:find("not found") and #src < 200 then return false end
    return true
end

local function fetchCached(url)
    local c = _G.JustHubCache[url]
    if c and isValidBlob(c) then return c end
    local src = httpGet(url)
    if src and isValidBlob(src) then
        _G.JustHubCache[url] = src
        return src
    end
    return nil
end

-- ═══════════════ DECRYPT (XOR + Base64) ═══════════════
local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function b64decode(data)
    data = tostring(data):gsub('[^'..B64..'=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', (B64:find(x) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2^(8 - i) or 0) end
        return string.char(c)
    end))
end

local function xorStr(data, key)
    local out = {}
    for i = 1, #data do
        local c = data:byte(i)
        local k = key:byte((i - 1) % #key + 1)
        out[i] = string.char(bit32.bxor(c, k))
    end
    return table.concat(out)
end

-- ถอดรหัส: base64 decode -> xor
local function decryptMap(blob, key)
    local ok, res = pcall(function() return xorStr(b64decode(blob), key) end)
    if ok then return res end
    return nil
end

-- ดูว่าข้อความดูเหมือน Lua ที่รันได้ไหม
local function looksLikeLua(src)
    if not src or #src < 10 then return false end
    return LS(src) ~= nil
end

-- คืนโค้ด Lua พร้อมรัน จาก blob (ถอดรหัส หรือ ธรรมดาในโหมดเทส)
local function resolveSource(blob, key)
    -- ลองถอดรหัสก่อน
    if key then
        local dec = decryptMap(blob, key)
        if dec and looksLikeLua(dec) then return dec end
    end
    -- โหมดเทส: ถ้า blob เป็น Lua ธรรมดาอยู่แล้ว ให้รันตรงๆ
    if TEST_MODE and looksLikeLua(blob) then
        return blob
    end
    return nil
end

-- ═══════════════ KEY RE-VALIDATION (กัน bypass) ═══════════════
local function keyValid(key)
    if not REQUIRE_KEY then return true end
    if not key or key == "" then return false end
    if _G.JustHubVerified == key then return true end  -- cache ต่อ session
    local ok, result = pcall(function()
        local src = httpGet("https://secure.pandauth.com/pv4/lib")
        if not src then error("no pusl") end
        local pusl = LS(src)()
        pcall(function() pusl.configure({ serviceId = SERVICE_ID }) end)
        return pusl.validate(key)
    end)
    if ok and result and result.success then
        _G.JustHubVerified = key
        return true
    end
    return false
end

-- ═══════════════ FIND GAME ═══════════════
local gid = tostring(game.GameId)
local pid = tostring(game.PlaceId)
local urls = GAMES[gid] or GAMES[pid]
if type(urls) == "string" then urls = { urls } end

-- ═══════════════ PHASE 1: PREFETCH ═══════════════
-- เรียกจากไฟล์ key ก่อนเช็ค key:
--   _G.JustHubPrefetchMode = true
--   task.spawn(function() loadstring(game:HttpGet("GAMELOADER_URL"))() end)
-- โหลด blob (เข้ารหัส) มา cache ไว้ล่วงหน้า — ไม่ต้องมี key เพราะ blob เข้ารหัสอยู่แล้ว
if _G.JustHubPrefetchMode and not session then
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
-- ต้องมี session จากไฟล์ key
if not session or not session.key then
    warn(">>> [GAMELOADER] NO_SESSION (เรียกตรงไม่ผ่านไฟล์ key)")
    return false, "NO_SESSION"
end

-- validate key ซ้ำกับ server (กัน bypass แบบตั้ง session ปลอม)
if not keyValid(session.key) then
    warn(">>> [GAMELOADER] INVALID_KEY")
    return false, "INVALID_KEY"
end

local decKey = session.decKey
if not decKey and not TEST_MODE then
    warn(">>> [GAMELOADER] NO_DECKEY")
    return false, "NO_DECKEY"
end

print(">>> [GAMELOADER] GameId =", gid, "| PlaceId =", pid)

if not urls then
    warn(">>> [GAMELOADER] UNSUPPORTED:", gid, pid)
    return false, "UNSUPPORTED"
end

local lastReason = "HTTP_FAIL"

for i, url in ipairs(urls) do
    local t0 = os.clock()
    local blob = fetchCached(url)
    print(">>> [GAMELOADER] get #" .. i, string.format("%.2fs", os.clock() - t0))

    if blob then
        local src = resolveSource(blob, decKey)
        if not src then
            warn(">>> [GAMELOADER] DECRYPT/SYNTAX fail #" .. i)
            lastReason = "SYNTAX"
        else
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
        end
    else
        lastReason = "HTTP_FAIL"
    end
end

warn(">>> [GAMELOADER] All failed:", lastReason)
return false, lastReason
