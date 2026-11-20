local LS = loadstring or load
_G.JustHubCache = _G.JustHubCache or {}

local REQUIRE_KEY = true      -- validate key กับ PandaAuth (กัน bypass)
local ANTI_HOOK   = false     -- ปิด anti-hook (ไม่เตะใคร)
local TEST_MODE   = true      -- ยอมรับแมพที่ยังเป็น Lua ธรรมดา (ตอน migrate)
local SERVICE_ID  = "justhubkey"

local BASE = "https://raw.githubusercontent.com/oveearn20/Game/main/Games/"
local function G(file) return BASE .. file end
local TYPER_TOWN = "https://raw.githubusercontent.com/oveearn20/Game/main/Typer%20town"
local ANIME_DICE = "https://raw.githubusercontent.com/oveearn20/Game/main/Anime%20dice"

-- แต่ละเกม = ชื่อเดียว ใส่ ID ได้หลายตัว (GameId หรือ PlaceId)
local GAME_LIST = {
    {
        name = "Typer Town",
        ids  = { "119554426329370", "73746968849439" },
        url  = TYPER_TOWN,
    },
    {
        name = "Anime Dice",
        ids  = { "10708913337", "113290951185459" },
        url  = ANIME_DICE,
    },
    -- เพิ่มเกมใหม่:
    -- {
    --     name = "ชื่อเกม",
    --     ids  = { "GameId", "PlaceId" },
    --     url  = "https://raw.githubusercontent.com/oveearn20/Game/main/Games/ชื่อไฟล์",
    -- },
}

-- สร้างตารางค้นหาจาก GAME_LIST (ไม่ต้องแก้ส่วนนี้)
local GAMES = {}
for _, g in ipairs(GAME_LIST) do
    for _, id in ipairs(g.ids) do
        GAMES[id] = { g.url }
    end
end

-- AES-256-CTR decrypt (pure Luau) — matches server-side cryptography lib
-- usage: local plain = AESDecrypt(base64blob, "Justreally095")
local function AESDecrypt(b64, password)
    local bxor, floor = bit32.bxor, math.floor
    local schar, tconcat = string.char, table.concat
    local SBOX = {99,124,119,123,242,107,111,197,48,1,103,43,254,215,171,118,202,130,201,125,250,89,71,240,173,212,162,175,156,164,114,192,183,253,147,38,54,63,247,204,52,165,229,241,113,216,49,21,4,199,35,195,24,150,5,154,7,18,128,226,235,39,178,117,9,131,44,26,27,110,90,160,82,59,214,179,41,227,47,132,83,209,0,237,32,252,177,91,106,203,190,57,74,76,88,207,208,239,170,251,67,77,51,133,69,249,2,127,80,60,159,168,81,163,64,143,146,157,56,245,188,182,218,33,16,255,243,210,205,12,19,236,95,151,68,23,196,167,126,61,100,93,25,115,96,129,79,220,34,42,144,136,70,238,184,20,222,94,11,219,224,50,58,10,73,6,36,92,194,211,172,98,145,149,228,121,231,200,55,109,141,213,78,169,108,86,244,234,101,122,174,8,186,120,37,46,28,166,180,198,232,221,116,31,75,189,139,138,112,62,181,102,72,3,246,14,97,53,87,185,134,193,29,158,225,248,152,17,105,217,142,148,155,30,135,233,206,85,40,223,140,161,137,13,191,230,66,104,65,153,45,15,176,84,187,22}
    local RCON = {1,2,4,8,16,32,64,128,27,54,108,216,171,77}

    -- fast base64 decode (byte-lookup, flush per byte) — ทนไฟล์ใหญ่
    local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local DEC = {}
    for i = 0, 255 do DEC[i] = -1 end
    for i = 1, #B64 do DEC[B64:byte(i)] = i - 1 end
    local function b64decode(data)
        local out = {}
        local n = 0
        local bits, nbits = 0, 0
        for i = 1, #data do
            local v = DEC[data:byte(i)]
            if v >= 0 then
                bits = bits * 64 + v
                nbits = nbits + 6
                if nbits >= 8 then
                    nbits = nbits - 8
                    n = n + 1
                    out[n] = schar(floor(bits / (2 ^ nbits)) % 256)
                    bits = bits % (2 ^ nbits)
                end
            end
        end
        return tconcat(out)
    end

    -- derive 32-byte key
    local key = password
    while #key < 32 do key = key .. password end
    key = key:sub(1, 32)
    local kb = {}
    for i = 1, 32 do kb[i] = key:byte(i) end

    local function gmul(a, b)
        local r = 0
        for _ = 1, 8 do
            if b % 2 == 1 then r = bxor(r, a) end
            local hi = a >= 128
            a = (a * 2) % 256
            if hi then a = bxor(a, 0x1B) end
            b = floor(b / 2)
        end
        return r
    end

    local Nk, Nr = 8, 14
    local w = {}
    for i = 1, Nk do
        w[i] = { kb[4*(i-1)+1], kb[4*(i-1)+2], kb[4*(i-1)+3], kb[4*(i-1)+4] }
    end
    for p = Nk + 1, 4 * (Nr + 1) do
        local t = { w[p-1][1], w[p-1][2], w[p-1][3], w[p-1][4] }
        local m = (p - 1) % Nk
        if m == 0 then
            t = { t[2], t[3], t[4], t[1] }
            for j = 1, 4 do t[j] = SBOX[t[j] + 1] end
            t[1] = bxor(t[1], RCON[floor((p-1)/Nk)])
        elseif m == 4 then
            for j = 1, 4 do t[j] = SBOX[t[j] + 1] end
        end
        local a = w[p - Nk]
        w[p] = { bxor(a[1],t[1]), bxor(a[2],t[2]), bxor(a[3],t[3]), bxor(a[4],t[4]) }
    end
    local rk = {}
    local idx = 1
    for p = 1, 4 * (Nr + 1) do
        for j = 1, 4 do rk[idx] = w[p][j]; idx = idx + 1 end
    end

    local function encBlock(inp)
        local s = {}
        for i = 1, 16 do s[i] = inp[i] end
        for i = 1, 16 do s[i] = bxor(s[i], rk[i]) end
        for rnd = 1, Nr do
            for i = 1, 16 do s[i] = SBOX[s[i] + 1] end
            local o = {}
            for r = 0, 3 do
                for c = 0, 3 do
                    o[r + 4*c + 1] = s[r + 4*((c + r) % 4) + 1]
                end
            end
            s = o
            if rnd ~= Nr then
                local m = {}
                for c = 0, 3 do
                    local b0,b1,b2,b3 = s[4*c+1], s[4*c+2], s[4*c+3], s[4*c+4]
                    m[4*c+1] = bxor(bxor(gmul(b0,2), gmul(b1,3)), bxor(b2, b3))
                    m[4*c+2] = bxor(bxor(b0, gmul(b1,2)), bxor(gmul(b2,3), b3))
                    m[4*c+3] = bxor(bxor(b0, b1), bxor(gmul(b2,2), gmul(b3,3)))
                    m[4*c+4] = bxor(bxor(gmul(b0,3), b1), bxor(b2, gmul(b3,2)))
                end
                s = m
            end
            local base = 16 * rnd
            for i = 1, 16 do s[i] = bxor(s[i], rk[base + i]) end
        end
        return s
    end

    local blob = b64decode(b64)
    if #blob < 17 then return nil end
    local iv = {}
    for i = 1, 16 do iv[i] = blob:byte(i) end
    local ctLen = #blob - 16

    local function incCtr()
        for j = 16, 1, -1 do
            iv[j] = iv[j] + 1
            if iv[j] == 256 then iv[j] = 0 else break end
        end
    end

    local out = {}
    local oi = 0
    local pos = 17
    local n = 0
    while n < ctLen do
        local ks = encBlock(iv)
        local chunk = ctLen - n
        if chunk > 16 then chunk = 16 end
        for i = 1, chunk do
            oi = oi + 1
            out[oi] = schar(bxor(blob:byte(pos + i - 1), ks[i]))
        end
        pos = pos + chunk
        n = n + chunk
        incCtr()
    end
    return tconcat(out)
end

local env     = (getgenv and getgenv()) or _G
local session = env.JustHubSession

end

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

local function looksLikeLua(src)
    if not src or #src < 10 then return false end
    return LS(src) ~= nil
end

local function resolveSource(blob, pw)
    local ok, dec = pcall(AESDecrypt, blob, pw)
    if ok and dec and looksLikeLua(dec) then return dec end
    if TEST_MODE and looksLikeLua(blob) then return blob end
    return nil
end

local function envClean()
    return true
end

local function keyValid(key)
    if not REQUIRE_KEY then return true end
    if not key or key == "" then return false end
    if _G.JustHubVerified == key then return true end
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

local gid = tostring(game.GameId)
local pid = tostring(game.PlaceId)
local urls = GAMES[gid] or GAMES[pid]
if type(urls) == "string" then urls = { urls } end

-- PHASE 1: PREFETCH (blob เข้ารหัสอยู่แล้ว โหลดล่วงหน้าได้ ไม่ต้องมี key)
if _G.JustHubPrefetchMode and not session then
    _G.JustHubPrefetchMode = nil
    if urls then
        for _, url in ipairs(urls) do
            if fetchCached(url) then break end
        end
    end
    return true
end

-- PHASE 2: LOAD
if not session or not session.key then
    return false, "NO_SESSION"
end

if not keyValid(session.key) then
    return false, "INVALID_KEY"
end

local pw = session.decKey
if not pw and not TEST_MODE then
    return false, "NO_DECKEY"
end

if not urls then
    return false, "UNSUPPORTED"
end

local lastReason = "HTTP_FAIL"
for i, url in ipairs(urls) do
    local blob = fetchCached(url)
    if blob then
        local src = resolveSource(blob, pw)
        if not src then
            lastReason = "SYNTAX"
        else
            local fn, err = LS(src)
            if not fn then
                lastReason = "SYNTAX"
            else
                local ok, runErr = pcall(fn)
                if ok then return true end
                lastReason = "RUNTIME"
            end
        end
    else
        lastReason = "HTTP_FAIL"
    end
end

return false, lastReason
