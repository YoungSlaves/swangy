-- swangy
-- esp: generators, windows, pallets, bear traps
-- skillcheck: generators and the butcher trap
-- aimbot: veil spear throw assist
-- hud: killer timers, generator column, survivor list
-- menu: swangy ui by aphalia (github.com/YoungSlaves/matchaUI)

if _G.__SWANGY and _G.__SWANGY.unload then pcall(_G.__SWANGY.unload) end

-- game:GetService can return nil in this VM - MEASURED 2026-10-29: all
-- three services nil in the same second that the global `workspace` was
-- fine. Every service is fetched with retries, Workspace falls back to the
-- global, and a missing one waits for the game instead of dying (that was
-- the Matcha:13 "LocalPlayer" error that needed a rejoin).
local function swangyService(name)
    for _ = 1, 6 do
        local ok, s = pcall(function() return game:GetService(name) end)
        if ok and s then return s end
    end
    local ok2, s2 = pcall(function() return game:FindFirstChild(name) end)
    if ok2 and s2 then return s2 end
    -- GetService also returns nil for RunService and Players in this VM, but
    -- the services are still children of the DataModel: game:GetChildren()
    -- lists Players and RunService. Match on ClassName because some names
    -- read as empty strings.
    local okK, kids = pcall(function() return game:GetChildren() end)
    if okK and type(kids) == "table" then
        for i = 1, #kids do
            local cls, nm = nil, nil
            pcall(function() cls = kids[i].ClassName end)
            pcall(function() nm = kids[i].Name end)
            if cls == name or nm == name then return kids[i] end
        end
    end
    return nil
end

local Players, RunService, Workspace = nil, nil, nil
local lp, mouse = nil, nil

-- every load takes a generation token, not just a load that waits: an older
-- waiter used to survive a reload, finish later and build a second hub
local loadToken = {}
_G.__SWANGY_LOAD = loadToken

local function resolveCore()
    Players = Players or swangyService("Players")
    RunService = RunService or swangyService("RunService")
    if not Workspace then
        pcall(function() Workspace = workspace end)
        if not Workspace then Workspace = swangyService("Workspace") end
    end
    if not lp then
        -- three routes: the cached service, a fresh one, and the datamodel
        -- property. A stale Players wrapper was one of the ways this ended
        -- in "index nil with LocalPlayer".
        if Players then pcall(function() lp = Players.LocalPlayer end) end
        if not lp then pcall(function() lp = game:GetService("Players").LocalPlayer end) end
        if not lp then pcall(function() lp = game.Players.LocalPlayer end) end
    end
    return Players ~= nil and RunService ~= nil and Workspace ~= nil and lp ~= nil
end

-- Measured: right after the game attaches this VM reports every service as
-- nil (and Players.LocalPlayer as nil) for a second or two. Returning here
-- was the "Matcha:13 attempt to index nil with 'LocalPlayer'" / "rejoin to
-- fix" path. Wait for the game instead; a newer load cancels the wait.
if not resolveCore() then
    -- a loaded chunk cannot yield at its top level in this VM, so blocking
    -- here dies silently and leaves you reloading by hand. Queue a retry
    -- instead; it re-runs the file once the game is readable.
    print("[swangy] game not attached yet - queued, it will start by itself")
    task.spawn(function()
        while _G.__SWANGY_LOAD == loadToken do
            if resolveCore() then
                local src
                if type(readfile) == "function" then
                    local okr, s = pcall(readfile, "swangy_matcha.lua")
                    if okr then src = s end
                end
                if type(src) == "string" and #src > 100 then
                    local fn, cerr = loadstring(src, "swangy.lua")
                    if fn then
                        local ok, rerr = pcall(fn)
                        if not ok then print("[swangy] deferred load failed: " .. tostring(rerr)) end
                    else
                        print("[swangy] deferred compile failed: " .. tostring(cerr))
                    end
                else
                    print("[swangy] deferred load: swangy_matcha.lua unreadable")
                end
                return
            end
            task.wait(0.5)
        end
    end)
    return
end
pcall(function() mouse = lp:GetMouse() end)

-- config
local CFG = {

    drawHz    = 0,
    pollHz    = 2,
    palHz     = 8,

    gen       = true,
    genRange  = 1000,
    genPool   = 16,
    genText   = 13,
    genState  = true,
    genFill   = true,
    genFillA  = 0.25,
    genThick  = 1.6,
    genIdleColour   = Color3.fromRGB(255, 150, 40),
    genDoneColour   = Color3.fromRGB(51, 255, 77),
    genBrokenColour = Color3.fromRGB(255, 120, 120),

    win       = true,
    winRange  = 1000,
    winPool   = 24,
    winText   = 12,
    winFill   = true,
    winFillA  = 0.20,
    winThick  = 1.6,
    winColour = Color3.fromRGB(255, 230, 0),

    pal       = true,
    palRange  = 1000,
    palPool   = 20,
    palText   = 12,
    palFill   = true,
    palFillA  = 0.20,
    palThick  = 1.6,
    palColour     = Color3.fromRGB(139, 90, 50),
    palDownColour = Color3.fromRGB(255, 140, 26),

    trap          = true,
    trapRange     = 1000,
    trapPool      = 12,
    trapText      = 12,
    trapFill      = true,
    trapFillA     = 0.20,
    trapThick     = 1.6,
    trapArmedColour  = Color3.fromRGB(80, 255, 120),
    trapSprungColour = Color3.fromRGB(255, 60, 60),

    pump          = true,
    pumpRange     = 1000,
    pumpPool      = 32,
    pumpText      = 12,
    pumpFill      = true,
    pumpFillA     = 0.20,
    pumpThick     = 1.6,
    pumpColour    = Color3.fromRGB(255, 150, 40),
    pumpScanHz    = 0.25,   -- GetDescendants on the map is expensive

    names     = true,
    namesOnly = false,   -- draw labels without the boxes
    espRange  = 1000,

    sc        = true,
    scLead    = 2,
    scKey     = 32,
    scHum     = false,
    scHumMin  = 10,
    scHumMax  = 50,
    scReact   = 0,
    scDelay   = 0,
    scHz      = 120,   -- 120 Hz still lands a skillcheck within 8 ms, half the wakeups
    scRescue  = true,
    scDry     = false,
    scMode    = nil,

    va        = false,
    vaFov     = 55,
    vaRange   = 260,
    vaSmooth  = 1,
    vaSticky  = true,
    vaLead    = true,
    vaLos     = true,
    vaHold    = true,
    vaAimHeight = 0,

    pp           = true,
    ppRange      = 14,
    ppMinRange   = 13,
    ppPing       = true,
    ppFacing     = true,
    ppAim        = true,
    ppHealth     = 50,
    ppInterval   = 0.45,
    ppEquip      = true,
    ppEquipRange = 45,
    ppWindup     = true,
    ppWindupHz   = 120,
    ppScanRange  = 70,
    ppHz         = 120,

    kbw       = true,

    hud          = true,
    hudAlpha     = 0,
    hudAbilities = true,
    hudPerks     = true,
    hudGens      = true,
    hudSurvivors = true,
    hudTraps     = true,
    hudState     = false,

}

local UI, uiWindow
local kbwDestroy
local HUD = {}

local COL = {
    genIdle  = Color3.fromRGB(26, 255, 51),
    genDone  = Color3.fromRGB(51, 255, 77),
    genPause = Color3.fromRGB(255, 210, 110),
    genBad   = Color3.fromRGB(255, 120, 120),
    win      = Color3.fromRGB(255, 230, 0),

    pal      = Color3.fromRGB(255, 26, 26),
    palDown  = Color3.fromRGB(255, 140, 26),
}

local FONT   = Drawing.Fonts.SystemBold or Drawing.Fonts.System
local EDGES  = {
    {1,2},{2,4},{4,3},{3,1},
    {5,6},{6,8},{8,7},{7,5},
    {1,5},{2,6},{3,7},{4,8},
}
local CORNER = {
    {-1,-1,-1},{ 1,-1,-1},{-1, 1,-1},{ 1, 1,-1},
    {-1,-1, 1},{ 1,-1, 1},{-1, 1, 1},{ 1, 1, 1},
}

-- esp
local function newSlot(thick, textSize)
    local lines = {}
    for i = 1, 12 do
        local ln = Drawing.new("Line")
        ln.Thickness = thick
        ln.Visible = false
        lines[i] = ln
    end
    local tris = {}
    for i = 1, 6 do
        local tr = Drawing.new("Triangle")
        tr.Thickness = 0
        pcall(function() tr.Filled = true end)
        tr.Visible = false
        tris[i] = tr
    end
    local top = Drawing.new("Text")
    top.Size, top.Outline, top.Center, top.Visible = textSize, true, true, false
    pcall(function() top.Font = FONT end)
    local sub = Drawing.new("Text")
    sub.Size, sub.Outline, sub.Center, sub.Visible = textSize - 2, true, true, false
    pcall(function() sub.Font = FONT end)
    return {
        lines = lines, tris = tris, top = top, sub = sub,

        px = {}, py = {},
        lf = {}, lt = {}, lth = {}, lcol = {}, lvis = {},
    }
end

local function removeSlot(e)
    if not e then return end
    for _, ln in ipairs(e.lines) do pcall(function() ln:Remove() end) end
    for _, tr in ipairs(e.tris) do pcall(function() tr:Remove() end) end
    pcall(function() e.top:Remove() end)
    pcall(function() e.sub:Remove() end)
end

local function hideSlot(e)
    if not e then return end
    for i = 1, 12 do
        e.lvis[i] = false
        if e.lines[i].Visible then e.lines[i].Visible = false end
    end
    for i = 1, 6 do
        if e.tris[i].Visible then e.tris[i].Visible = false end
    end
    if e.top.Visible then e.top.Visible = false end
    if e.sub.Visible then e.sub.Visible = false end
end

-- slots are built on first use: the old load created every pool up front
-- (104 slots = 2,080 Drawing objects) before a single target existed, which
-- is what made loading and reloading the executor heavy
local function ensureSlots(pool, count, thick, text)
    -- called from the collectors, never from the render callback: creating a
    -- Drawing while the renderer is running is what the executor docs warn about
    for i = 1, count do
        if not pool[i] then pool[i] = newSlot(thick, text) end
    end
end

-- names-only mode: keep the label, drop the box and its fill
local function hideBox(e)
    if not e then return end
    for i = 1, 12 do
        if e.lines[i].Visible then
            e.lvis[i] = false
            e.lines[i].Visible = false
        end
    end
    for i = 1, 6 do
        if e.tris[i].Visible then e.tris[i].Visible = false end
    end
end

local function convexHull(pts)
    local sorted = {}
    for _, p in ipairs(pts) do sorted[#sorted + 1] = p end
    if #sorted < 3 then return nil end
    table.sort(sorted, function(a, b)
        return a.x < b.x or (a.x == b.x and a.y < b.y)
    end)
    local cross = function(o, a, b)
        return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
    end
    local hull = {}
    for _, p in ipairs(sorted) do
        while #hull >= 2 and cross(hull[#hull - 1], hull[#hull], p) <= 0 do
            table.remove(hull)
        end
        hull[#hull + 1] = p
    end
    local lower = #hull + 1
    for i = #sorted - 1, 1, -1 do
        local p = sorted[i]
        while #hull >= lower and cross(hull[#hull - 1], hull[#hull], p) <= 0 do
            table.remove(hull)
        end
        hull[#hull + 1] = p
    end
    table.remove(hull)
    if #hull < 3 then return nil end
    return hull
end

local R_AXIS, U_AXIS, B_AXIS = Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1)

local function basisFromCFrame(cf)
    if cf then
        local okr, r = pcall(function() return cf.RightVector end)
        local oku, u = pcall(function() return cf.UpVector end)
        local okl, l = pcall(function() return cf.LookVector end)
        if okr and r and oku and u and okl and l then
            return r, u, -l
        end
    end
    return R_AXIS, U_AXIS, B_AXIS
end

local camNow, camVpW, camVpH = nil, 1920, 1080

local function drawBox(e, center, hx, hy, hz, right, up, back, colour, fillAlpha, thick)
    local px, py = e.px, e.py
    local cx, cy, cz = center.X, center.Y, center.Z
    local rX, rY, rZ = right.X, right.Y, right.Z
    local uX, uY, uZ = up.X, up.Y, up.Z
    local bX, bY, bZ = back.X, back.Y, back.Z
    local anyFront, frontN = false, 0
    local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
    for i = 1, 8 do
        local c = CORNER[i]
        local ax, ay, az = c[1] * hx, c[2] * hy, c[3] * hz
        local sp, onScreen = WorldToScreen(Vector3.new(
            cx + rX * ax + uX * ay + bX * az,
            cy + rY * ax + uY * ay + bY * az,
            cz + rZ * ax + uZ * ay + bZ * az))
        if onScreen and sp then
            local sx, sy = sp.X, sp.Y
            px[i], py[i] = sx, sy
            anyFront, frontN = true, frontN + 1
            if sx < minX then minX = sx end
            if sx > maxX then maxX = sx end
            if sy < minY then minY = sy end
            if sy > maxY then maxY = sy end
        else
            px[i] = nil
        end
    end
    if not anyFront then
        hideSlot(e)
        return nil
    end

    if camNow then
        local dx, dy, dz = camNow.X - cx, camNow.Y - cy, camNow.Z - cz
        local ox = math.max(math.abs(dx * rX + dy * rY + dz * rZ) - hx, 0)
        local oy = math.max(math.abs(dx * uX + dy * uY + dz * uZ) - hy, 0)
        local oz = math.max(math.abs(dx * bX + dy * bY + dz * bZ) - hz, 0)
        if ox * ox + oy * oy + oz * oz < 1.44
            or (maxX - minX) > camVpW * 4 or (maxY - minY) > camVpH * 4 then
            hideSlot(e)
            return nil
        end
    end

    local lf, lt, lth, lcol, lvis = e.lf, e.lt, e.lth, e.lcol, e.lvis
    local shown, topY, botY = 0, math.huge, -math.huge
    for i = 1, 8 do
        local y = py[i]
        if y then
            if y < topY then topY = y end
            if y > botY then botY = y end
        end
    end
    for i = 1, 12 do
        local ed = EDGES[i]
        local ia, ib = ed[1], ed[2]
        local x1, y1, x2, y2 = px[ia], py[ia], px[ib], py[ib]
        local ln = e.lines[i]
        if x1 and y1 and x2 and y2 then
            local f = lf[i]
            if not f or f[1] ~= x1 or f[2] ~= y1 then
                ln.From = Vector2.new(x1, y1)
                if f then f[1], f[2] = x1, y1 else lf[i] = { x1, y1 } end
            end
            local t = lt[i]
            if not t or t[1] ~= x2 or t[2] ~= y2 then
                ln.To = Vector2.new(x2, y2)
                if t then t[1], t[2] = x2, y2 else lt[i] = { x2, y2 } end
            end
            if lth[i] ~= thick then lth[i] = thick; ln.Thickness = thick end
            if lcol[i] ~= colour then
                lcol[i] = colour
                ln.Color = colour
                ln.Transparency = 1
            end
            if not lvis[i] then lvis[i] = true; ln.Visible = true end
            shown = shown + 1
        elseif lvis[i] then
            lvis[i] = false
            ln.Visible = false
        end
    end

    if fillAlpha and frontN == 8 and (botY - topY) >= 26 then
        local hullPts = {}
        for i = 1, 8 do
            local x, y = px[i], py[i]
            if x then hullPts[#hullPts + 1] = { x = x, y = y } end
        end
        local hull = convexHull(hullPts)
        local tri = 0
        if hull then
            for i = 2, #hull - 1 do
                if tri >= 6 then break end
                tri = tri + 1
                local t = e.tris[tri]
                t.PointA = Vector2.new(hull[1].x, hull[1].y)
                t.PointB = Vector2.new(hull[i].x, hull[i].y)
                t.PointC = Vector2.new(hull[i + 1].x, hull[i + 1].y)
                t.Color = colour
                t.Transparency = fillAlpha
                t.Visible = true
            end
        end
        for i = tri + 1, 6 do
            if e.tris[i].Visible then e.tris[i].Visible = false end
        end
    elseif e.tris[1].Visible then
        for i = 1, 6 do e.tris[i].Visible = false end
    end

    if shown == 0 then return nil end
    return topY
end

local function lerpColor(a, b, t)
    t = math.clamp(t, 0, 1)
    return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function isPart(inst)
    local c = inst.ClassName
    return c == "Part" or c == "MeshPart" or c == "UnionOperation" or c == "WedgePart"
        or c == "CornerWedgePart" or c == "TrussPart"
end

local function lower(s) return string.lower(tostring(s)) end

local genPool, genList, genGeo, genStamp = {}, {}, {}, nil
local genShown = 0



-- generators
local GEN_SKIP = { "hitbox", "point", "anchor", "handle", "invis" }

local function skippedName(name)
    local n = lower(name)
    for _, s in ipairs(GEN_SKIP) do
        if n:find(s, 1, true) then return true end
    end
    return false
end

local function attrNum(model, name)
    local ok, v = pcall(function() return model:GetAttribute(name) end)
    if ok and type(v) == "number" then return v end
end

local function attrBool(model, name)
    local ok, v = pcall(function() return model:GetAttribute(name) end)
    if ok and type(v) == "boolean" then return v end
end

local function genStateFrom(prog, crew, model)
    if prog >= 100 or attrBool(model, "Completed") == true then return "done" end
    if attrBool(model, "Regressing") == true then return "regress" end
    if attrBool(model, "ProgressPaused") == true then return "paused" end
    if crew > 0 then return "active" end
    return "idle"
end

local function genState(model)
    local prog = attrNum(model, "RepairProgress") or 0
    local crew = attrNum(model, "PlayersRepairingCount") or 0
    return prog, crew, genStateFrom(prog, crew, model)
end

local function firstPart(model)
    local ok, kids = pcall(function() return model:GetChildren() end)
    if not ok or type(kids) ~= "table" then return nil end
    for _, c in ipairs(kids) do
        if isPart(c) then return c end
    end
    for _, c in ipairs(kids) do
        local ok2, sub = pcall(function() return c:GetChildren() end)
        if ok2 then
            for _, s in ipairs(sub) do
                if isPart(s) then return s end
            end
        end
    end
    return nil
end

local function visibleBody(part)
    local ok, tr = pcall(function() return part.Transparency end)
    if ok and type(tr) == "number" and tr >= 0 and tr <= 1 and tr > 0.05 then return false end
    return true
end

local function measureModel(model)
    local ok, desc = pcall(function() return model:GetDescendants() end)
    if not ok or type(desc) ~= "table" then return nil end

    local mnX, mnY, mnZ = math.huge, math.huge, math.huge
    local mxX, mxY, mxZ = -math.huge, -math.huge, -math.huge
    local rotPart, any = nil, false

    for _, part in ipairs(desc) do
        if isPart(part) and not skippedName(part.Name) and visibleBody(part) then
            local okp, p = pcall(function() return part.Position end)
            local oks, s = pcall(function() return part.Size end)
            if okp and oks and p and s then
                local hx, hy, hz = s.X * 0.5, s.Y * 0.5, s.Z * 0.5
                if hx >= 0.02 and hx <= 100 then
                    if p.X - hx < mnX then mnX = p.X - hx end
                    if p.X + hx > mxX then mxX = p.X + hx end
                    if p.Y - hy < mnY then mnY = p.Y - hy end
                    if p.Y + hy > mxY then mxY = p.Y + hy end
                    if p.Z - hz < mnZ then mnZ = p.Z - hz end
                    if p.Z + hz > mxZ then mxZ = p.Z + hz end
                    any = true
                    if not rotPart then rotPart = part end
                end
            end
        end
    end
    if not any then return nil end

    local center = Vector3.new((mnX + mxX) * 0.5, (mnY + mxY) * 0.5, (mnZ + mxZ) * 0.5)
    local hx, hy, hz = (mxX - mnX) * 0.5, (mxY - mnY) * 0.5, (mxZ - mnZ) * 0.5
    if hx < 0.05 or hy < 0.05 then return nil end
    if hx > 7 or hy > 7 or hz > 7 then return nil end

    local okcf, cf = pcall(function() return rotPart.CFrame end)
    if not okcf then cf = nil end
    return center, hx, hy, hz, cf
end

local function collectGens()
    local out = {}
    local map = Workspace:FindFirstChild("Map")
    if not map then return out end

    local folder
    local okKids, kids = pcall(function() return map:GetChildren() end)
    if not okKids or type(kids) ~= "table" then okKids, kids = false, {} end

    local parents = { kids }
    local okRes, res = pcall(function() return map:FindFirstChild("resources") end)
    if okRes and res then
        local okSub, sub = pcall(function() return res:GetChildren() end)
        if okSub and type(sub) == "table" then parents[#parents + 1] = sub end
    end

    for _, list in ipairs(parents) do
        if folder then break end
        for _, ch in ipairs(list) do
            local n = lower(ch.Name)
            if ch.ClassName == "Folder"
                and (n:find("generator", 1, true) or n:find("gens", 1, true)) then
                local okSub, sub = pcall(function() return ch:GetChildren() end)
                if okSub and type(sub) == "table" and #sub > 0 then folder = ch break end
            end
        end
    end

    local function note(model)
        local part = model:FindFirstChild("HitBox")
            or model:FindFirstChild("RootPart")
            or model:FindFirstChild("GeneratorBody")
            or firstPart(model)
        if not part then return end
        local okp, pos = pcall(function() return part.Position end)
        if not okp or not pos then return end
        local prog, crew, state = genState(model)
        local okA, addr = pcall(function() return model.Address end)
        out[#out + 1] = {
            model = model, key = okA and addr or nil,
            pos = pos, prog = prog, crew = crew, state = state, stateAt = 0,
        }
    end

    if folder then
        local ok, items = pcall(function() return folder:GetChildren() end)
        if ok then
            for _, m in ipairs(items) do
                if attrNum(m, "RepairProgress") or attrNum(m, "PlayersRepairingCount")
                    or attrNum(m, "Progress") then
                    note(m)
                end
            end
        end
        return out
    end

    if not okKids then return out end
    for _, ch in ipairs(kids) do
        if attrNum(ch, "RepairProgress") or attrNum(ch, "PlayersRepairingCount") then
            note(ch)
        else
            local okSub, sub = pcall(function() return ch:GetChildren() end)
            if okSub then
                for _, s in ipairs(sub) do
                    if attrNum(s, "RepairProgress") then note(s) end
                end
            end
        end
    end
    return out
end

local genCursor = 1
local function updateGenStates(list)
    local n = #list
    if n == 0 then return end
    local now = os.clock()
    for _ = 1, n do
        genCursor = genCursor % n + 1
        local t = list[genCursor]
        if t and t.model then
            local okp, prog = pcall(function() return t.model:GetAttribute("RepairProgress") end)
            local okc, crew = pcall(function() return t.model:GetAttribute("PlayersRepairingCount") end)
            if okp and type(prog) == "number" then
                t.prog = prog
                if HUD.genRate then HUD.genRate(t, prog, now) end
            end
            if okc and type(crew) == "number" then t.crew = crew end
            if now >= (t.stateAt or 0) then
                t.stateAt = now + 1.5
                t.state = genStateFrom(t.prog or 0, t.crew or 0, t.model)
            end
            return
        end
    end
end

local function genColour(prog, state)
    if state == "regress" then return CFG.genBrokenColour end
    if state == "paused" then return COL.genPause end
    return lerpColor(CFG.genIdleColour, CFG.genDoneColour, (prog or 0) / 100)
end

local function drawGens(camPos, now)
    local n = 0
    for i = 1, #genList do
        if n >= CFG.genPool then break end
        local t = genList[i]
        local d = (t.center - camPos).Magnitude
        if d <= CFG.genRange then
            n = n + 1
            local e = genPool[n]
            if not e then n = n - 1 break end
            local colour = genColour(t.prog, t.state)

            local topY
            if CFG.namesOnly then
                hideBox(e)
            else
                local okBox
                okBox, topY = pcall(drawBox, e, t.center, t.hx, t.hy, t.hz,
                    t.right or R_AXIS, t.up or U_AXIS, t.back or B_AXIS,
                    colour, CFG.genFill and CFG.genFillA or nil, CFG.genThick)
                if not okBox then topY = nil end
            end

            local top, okT = WorldToScreen(t.center + Vector3.new(0, t.hy, 0))
            local bot, okB = WorldToScreen(t.center - Vector3.new(0, t.hy, 0))
            if okT and okB and top and bot then

                local pct, dm = math.floor(t.prog + 0.5), math.floor(d + 0.5)
                if e.lpct ~= pct or e.ldm ~= dm or e.lstate ~= t.state or e.lcrew ~= t.crew
                    or e.lnames ~= CFG.names then
                    e.lpct, e.ldm, e.lstate, e.lcrew, e.lnames = pct, dm, t.state, t.crew, CFG.names

                    local line1 = CFG.names and string.format("GEN %d%%   %dm", pct, dm)
                        or string.format("%d%%", pct)
                    local line2 = ""
                    if CFG.genState and CFG.names then
                        line2 = t.state
                        if t.crew > 0 then line2 = line2 .. "  x" .. t.crew end
                    end
                    if e.lastTop ~= line1 then e.lastTop = line1; e.top.Text = line1 end
                    if e.lastSub ~= line2 then e.lastSub = line2; e.sub.Text = line2 end
                end
                if e.col ~= colour then
                    e.col = colour
                    e.top.Color = colour
                    e.sub.Color = colour
                end
                e.top.Position = Vector2.new(top.X,
                    (topY and topY < 100000) and (topY - 18) or (top.Y - 18))
                e.top.Visible = true
                if e.lastSub and e.lastSub ~= "" then
                    e.sub.Position = Vector2.new(top.X, bot.Y + 2)
                    e.sub.Visible = true
                elseif e.sub.Visible then
                    e.sub.Visible = false
                end
            elseif e.top.Visible then
                e.top.Visible = false
                if e.sub.Visible then e.sub.Visible = false end
            end
        end
    end
    if genShown > n then
        for i = n + 1, genShown do hideSlot(genPool[i]) end
    end
    genShown = n
    return n
end

local winPool, winList, winGeo = {}, {}, {}


-- windows
local function collectWindows()
    local out = {}
    local map = Workspace:FindFirstChild("Map")
    -- nil means "could not scan" so the caller keeps what it already has;
    -- an empty table means the map genuinely has no windows
    if not map then return nil end
    local ok, desc = pcall(function() return map:GetDescendants() end)
    if not ok or type(desc) ~= "table" then return nil end

    local candidates = {}
    for _, d in ipairs(desc) do
        if lower(d.Name):find("window", 1, true) then
            -- a window that is itself a part has no descendants to collect,
            -- so take it directly instead of silently skipping it
            if isPart(d) then candidates[#candidates + 1] = d end
            local okKids, kids = pcall(function() return d:GetDescendants() end)
            if okKids and type(kids) == "table" then
                for _, k in ipairs(kids) do
                    if isPart(k) then candidates[#candidates + 1] = k end
                end
            end
        end
    end

    local anyBottom = false
    for _, k in ipairs(candidates) do
        if lower(k.Name) == "bottom" then anyBottom = true break end
    end

    local function entryFor(part)
        local okA, addr = pcall(function() return part.Address end)
        local key = (okA and type(addr) == "number" and addr ~= 0) and addr or nil
        local e = key and winGeo[key]
        if not e then
            e = { part = part }
            if key then winGeo[key] = e end
        end
        local okp, pos = pcall(function() return part.Position end)
        local oks, size = pcall(function() return part.Size end)
        local okc, cf = pcall(function() return part.CFrame end)
        if okp and pos then e.pos = pos end
        if oks and size then e.size = size end
        if okc and cf then
            e.cf = cf
            e.right, e.up, e.back = basisFromCFrame(cf)
        end
        if e.pos and e.size then
            e.anchor = e.pos + Vector3.new(0, e.size.Y * 0.5 + 1.5, 0)
        end
        return e
    end

    for _, k in ipairs(candidates) do
        if (not anyBottom) or lower(k.Name) == "bottom" then out[#out + 1] = entryFor(k) end
    end
    return out
end

local winShown = 0

local function drawWindows(camPos)
    local n = 0
    for i = 1, #winList do
        if n >= CFG.winPool then break end
        local t = winList[i]
        if t.pos and t.size then
            local d = (t.pos - camPos).Magnitude
            if d <= CFG.winRange then
                n = n + 1
                local e = winPool[n]
                if not e then n = n - 1 break end
                local topY
                if CFG.namesOnly then
                    hideBox(e)
                else
                    topY = drawBox(e, t.pos,
                        t.size.X * 0.5, t.size.Y * 0.5, t.size.Z * 0.5,
                        t.right or R_AXIS, t.up or U_AXIS, t.back or B_AXIS,
                        CFG.winColour, CFG.winFill and CFG.winFillA or nil, CFG.winThick)
                end
                local top, okTop = WorldToScreen(t.anchor or t.pos)
                if okTop and top and CFG.names then
                    local di = math.floor(d + 0.5)
                    if e.lastD ~= di then
                        e.lastD = di
                        e.top.Text = string.format("WINDOW   %dm", di)
                    end
                    if e.col ~= CFG.winColour then
                        e.col = CFG.winColour
                        e.top.Color = CFG.winColour
                    end
                    e.top.Position = Vector2.new(top.X,
                        (topY and topY < 100000) and (topY - 16) or (top.Y - 16))
                    e.top.Visible = true
                elseif e.top.Visible then
                    e.top.Visible = false
                end
            end
        end
    end
    if winShown > n then
        for i = n + 1, winShown do hideSlot(winPool[i]) end
    end
    winShown = n
    return n
end

local palPool, palList = {}, {}
local palShown = 0


local palIndex, palFolder, palFolderMap, palMisses = {}, nil, nil, 0

local palParts = {}

local palGeo = {}

-- pallets
local function palletPart(parent, name)
    if not parent then return nil end
    local okA, a = pcall(function() return parent:FindFirstChild(name) end)
    return okA and a or nil
end

local function palletAddress(inst)
    if not inst then return nil end
    local ok, a = pcall(function() return inst.Address end)
    return (ok and type(a) == "number" and a ~= 0) and a or nil
end

local function palletBin(map)
    if palFolder and palFolderMap == map then
        local ok, parent = pcall(function() return palFolder.Parent end)
        if ok and parent == map then return palFolder end
    end
    palFolder, palFolderMap = nil, map

    local parents = { map }
    local okRes, res = pcall(function() return map:FindFirstChild("resources") end)
    if okRes and res then parents[2] = res end

    for _, parent in ipairs(parents) do
        local ok, kids = pcall(function() return parent:GetChildren() end)
        if ok and type(kids) == "table" then
            for _, c in ipairs(kids) do
                local n = string.lower(tostring(c.Name))
                if n == "pallets" or n == "pallet" then palFolder = c return c end
            end
        end
    end
    for _, parent in ipairs(parents) do
        local ok, kids = pcall(function() return parent:GetChildren() end)
        if ok and type(kids) == "table" then
            for _, c in ipairs(kids) do
                if string.find(string.lower(tostring(c.Name)), "pallet", 1, true) then
                    palFolder = c
                    return c
                end
            end
        end
    end
    return nil
end

local function palGeometry(part)
    local addr = palletAddress(part)
    local cached = addr and palGeo[addr]
    if cached then return cached end
    local okp, pos = pcall(function() return part.Position end)
    local oks, size = pcall(function() return part.Size end)
    local okc, cf = pcall(function() return part.CFrame end)
    if not (okp and oks and okc) or not pos or not size or not cf then return nil end
    local g = { pos = pos, size = size, cf = cf }
    g.right, g.up, g.back = basisFromCFrame(cf)
    if addr then palGeo[addr] = g end
    return g
end

local function palletMissing()
    palMisses = palMisses + 1
    palFolder = nil
    if palMisses >= math.max(2, math.floor(CFG.palHz)) then
        palIndex, palMisses = {}, 0
        return true
    end
    return false
end

local function collectPallets()
    local map = Workspace:FindFirstChild("Map")
    if not map then return palletMissing() and {} or nil end

    local folder = palletBin(map)
    if not folder then return palletMissing() and {} or nil end
    palMisses = 0

    local ok, items = pcall(function() return folder:GetChildren() end)
    if not ok or type(items) ~= "table" then return nil end

    local list, newIndex = {}, {}
    local now = os.clock()
    for _, model in ipairs(items) do
        local modelKey = palletAddress(model)
        local parts = modelKey and palParts[modelKey]
        if not parts then
            parts = {
                intact = palletPart(palletPart(model, "Intact"), "Pallet"),
                broken = palletPart(palletPart(model, "Broken"), "Pallet_Broken"),
            }
            if modelKey and (parts.intact or parts.broken) then palParts[modelKey] = parts end
        end
        local intact, broken = parts and parts.intact, parts and parts.broken
        if intact and broken then
            local key = modelKey or palletAddress(intact)
            if key then
                local entry = palIndex[key]
                if not entry then entry = { dropped = false, pending = 0 } end

                local near = true
                if entry.pos and camNow then
                    local dx, dy, dz = entry.pos.X - camNow.X, entry.pos.Y - camNow.Y, entry.pos.Z - camNow.Z
                    near = (dx * dx + dy * dy + dz * dz) <= 22500
                end
                local okcc, cc = true, nil
                if near or now >= (entry.stateAt or 0) then
                    entry.stateAt = now + (near and 0 or 0.6)
                    okcc, cc = pcall(function() return intact.CanCollide end)
                end
                if okcc and type(cc) == "boolean" then
                    local want = not cc
                    if want == entry.dropped then
                        entry.pending = 0
                    else
                        entry.pending = (entry.pending or 0) + 1
                        if entry.pending >= 2 then
                            entry.dropped = want
                            entry.pending = 0
                        end
                    end
                end

                local geo = palGeometry(entry.dropped and broken or intact)
                if geo then
                    entry.pos, entry.size, entry.cf = geo.pos, geo.size, geo.cf
                    entry.right, entry.up, entry.back = geo.right, geo.up, geo.back
                end

                if entry.pos and entry.size then
                    entry.miss = 0
                    newIndex[key] = entry
                    list[#list + 1] = entry
                end
            end
        else

            local key = palletAddress(model)
            local prev = key and palIndex[key]
            if prev and (prev.miss or 0) < 1 then
                prev.miss = (prev.miss or 0) + 1
                newIndex[key] = prev
                list[#list + 1] = prev
            end
        end
    end

    palIndex = newIndex
    return list
end

local function drawPallets(camPos)
    local last = #palList
    if last > CFG.palPool then last = CFG.palPool end

    for i = 1, last do
        local t = palList[i]
        local e = palPool[i]
        if not e then break end
        local d = (t.pos - camPos).Magnitude
        if d <= CFG.palRange and t.size and t.cf then

            local colour = t.dropped
                and lerpColor(CFG.palColour, CFG.palDownColour, 0.55)
                or CFG.palColour
            local topY
            if CFG.namesOnly then
                hideBox(e)
            else
                topY = drawBox(e, t.pos, t.size.X * 0.5, t.size.Y * 0.5, t.size.Z * 0.5,
                    t.right or R_AXIS, t.up or U_AXIS, t.back or B_AXIS,
                    colour, CFG.palFill and CFG.palFillA or nil, CFG.palThick)
            end
            local top, okTop = WorldToScreen(t.pos + Vector3.new(0, t.size.Y * 0.5 + 1.2, 0))
            if okTop and top and CFG.names then
                local text = string.format("%s   %dm",
                    t.dropped and "PALLET DOWN" or "PALLET", math.floor(d + 0.5))
                if e.lastTop ~= text then e.lastTop = text; e.top.Text = text end
                if e.col ~= colour then e.col = colour; e.top.Color = colour end
                e.top.Position = Vector2.new(top.X,
                    (topY and topY < 100000) and (topY - 16) or (top.Y - 16))
                e.top.Visible = true
            elseif e.top.Visible then
                e.top.Visible = false
            end
        else
            hideSlot(e)
        end
    end
    if palShown > last then
        for i = last + 1, palShown do hideSlot(palPool[i]) end
    end
    palShown = last
    return last
end

local trapPool, trapList = {}, {}
local trapShown = 0


-- bear traps
local trapIndex, trapTrapped, trapVictimAt = {}, {}, 0

local TRAP_VICTIM_ATTRS = {
    "TrappedPlayer", "TrappedUser", "PlayerName", "Player", "Occupant", "User", "Caught",
}

local function trapArmed(inst)
    local ok, v = pcall(function() return inst:GetAttribute("Armed") end)
    if ok and type(v) == "boolean" then return v end
end

local function trapAddress(inst)
    local ok, a = pcall(function() return inst.Address end)
    return (ok and type(a) == "number" and a ~= 0) and a or nil
end

local function trapMeasure(inst)
    local mnX, mnY, mnZ = math.huge, math.huge, math.huge
    local mxX, mxY, mxZ = -math.huge, -math.huge, -math.huge
    local rot, any = nil, false

    local function note(part)
        local okp, p = pcall(function() return part.Position end)
        local oks, s = pcall(function() return part.Size end)
        if not okp or not oks or not p or not s then return end
        local hx, hy, hz = s.X * 0.5, s.Y * 0.5, s.Z * 0.5
        if hx <= 0 or hy <= 0 or hz <= 0 or hx > 8 or hy > 8 or hz > 8 then return end
        if p.X - hx < mnX then mnX = p.X - hx end
        if p.X + hx > mxX then mxX = p.X + hx end
        if p.Y - hy < mnY then mnY = p.Y - hy end
        if p.Y + hy > mxY then mxY = p.Y + hy end
        if p.Z - hz < mnZ then mnZ = p.Z - hz end
        if p.Z + hz > mxZ then mxZ = p.Z + hz end
        any = true
        if not rot then rot = part end
    end

    if isPart(inst) then note(inst) end
    local ok, desc = pcall(function() return inst:GetDescendants() end)
    if ok and type(desc) == "table" then
        for _, part in ipairs(desc) do
            if part ~= inst and isPart(part) then note(part) end
        end
    end
    if not any then return nil end

    local center = Vector3.new((mnX + mxX) * 0.5, (mnY + mxY) * 0.5, (mnZ + mxZ) * 0.5)
    local hx, hy, hz = (mxX - mnX) * 0.5, (mxY - mnY) * 0.5, (mxZ - mnZ) * 0.5
    if hx < 0.05 or hy < 0.02 or hz < 0.05 then return nil end

    local right, up, back = R_AXIS, U_AXIS, B_AXIS
    if rot then
        local okc, cf = pcall(function() return rot.CFrame end)
        if okc and cf then right, up, back = basisFromCFrame(cf) end
    end
    return center, hx, hy, hz, right, up, back
end

local function trapRoots(map)
    local out = {}
    local okKids, kids = pcall(function() return map:GetChildren() end)
    if not okKids or type(kids) ~= "table" then kids = {} end
    for _, ch in ipairs(kids) do
        local n = lower(ch.Name)
        if n == "beartrap" or n == "beartraps" then out[#out + 1] = ch end
    end
    if #out == 0 then
        local ok, found = pcall(function() return map:FindFirstChild("BearTrap", true) end)
        if ok and found then out[1] = found end
    end
    return out
end

local function collectTraps()
    local map = Workspace:FindFirstChild("Map")
    if not map then trapIndex = {} return {} end

    local out, nextIndex, now = {}, {}, os.clock()

    local function add(inst, armed)
        local id = trapAddress(inst)
        local entry = id and trapIndex[id] or nil
        if not entry then
            local center, hx, hy, hz, right, up, back = trapMeasure(inst)
            if not center then return end
            entry = { pos = center, hx = hx, hy = hy, hz = hz,
                      right = right, up = up, back = back }
        end
        entry.id, entry.model = id, inst
        if entry.armed ~= armed then
            entry.armed = armed
            if armed == false then
                entry.sprungAt = now
                if not entry.probed then
                    entry.probed = true
                    for i = 1, #TRAP_VICTIM_ATTRS do
                        local ok, v = pcall(function() return inst:GetAttribute(TRAP_VICTIM_ATTRS[i]) end)
                        if ok and type(v) == "string" and v ~= "" then
                            entry.attrVictim = v
                            break
                        end
                    end
                end
            end
        end
        if id then nextIndex[id] = entry end
        out[#out + 1] = entry
    end

    local function walk(inst, depth)
        if not inst or depth > 3 then return end
        local armed = trapArmed(inst)
        if armed ~= nil then
            add(inst, armed)
            return
        end
        local ok, kids = pcall(function() return inst:GetChildren() end)
        if not ok or type(kids) ~= "table" then return end
        for _, k in ipairs(kids) do walk(k, depth + 1) end
    end

    local roots = trapRoots(map)
    for _, r in ipairs(roots) do walk(r, 0) end
    trapIndex = nextIndex
    return out
end

local function trapScanTrapped(now)
    if now - trapVictimAt < 1.5 then return end
    trapVictimAt = now
    local out = {}
    local ok, list = pcall(function() return Players:GetPlayers() end)
    if not ok or type(list) ~= "table" then trapTrapped = out return end
    local myId
    pcall(function() myId = lp.UserId end)
    for _, plr in ipairs(list) do
        local char
        pcall(function() char = plr.Character end)
        if char then
            local okT, trapped = pcall(function() return char:GetAttribute("Trapped") end)
            if okT and trapped == true then
                local root
                pcall(function() root = char:FindFirstChild("HumanoidRootPart") end)
                local okp, pos = false, nil
                if root then okp, pos = pcall(function() return root.Position end) end
                if okp and pos then
                    out[#out + 1] = {
                        name = tostring(plr.Name), pos = pos,
                        self = (myId ~= nil and plr.UserId == myId),
                    }
                end
            end
        end
    end
    trapTrapped = out
end

local function trapVictim(t)
    if t.attrVictim then return t.attrVictim end
    local best, bestD2
    for i = 1, #trapTrapped do
        local v = trapTrapped[i]
        local dx, dy, dz = v.pos.X - t.pos.X, v.pos.Y - t.pos.Y, v.pos.Z - t.pos.Z
        local d2 = dx * dx + dy * dy + dz * dz
        if d2 <= 225 and (not bestD2 or d2 < bestD2) then best, bestD2 = v, d2 end
    end
    if not best then return nil end
    return best.self and "you" or best.name
end

local function trapLabel(t, dist)
    local text = string.format("bear trap %dm", dist)
    if t.armed == false then
        local who = trapVictim(t)
        text = text .. "  " .. (who and (who .. " trapped") or "trapped")
    end
    return text
end

local function drawTraps(camPos)
    local n = 0
    for i = 1, #trapList do
        if n >= CFG.trapPool then break end
        local t = trapList[i]
        local d = (t.pos - camPos).Magnitude
        if d <= CFG.trapRange then
            n = n + 1
            local e = trapPool[n]
            if not e then n = n - 1 break end
            local colour = (t.armed == false) and CFG.trapSprungColour or CFG.trapArmedColour
            local topY
            if CFG.namesOnly then
                hideBox(e)
            else
                topY = drawBox(e, t.pos, t.hx, t.hy, t.hz,
                    t.right or R_AXIS, t.up or U_AXIS, t.back or B_AXIS,
                    colour, CFG.trapFill and CFG.trapFillA or nil, CFG.trapThick)
            end
            local top, okTop = WorldToScreen(t.pos + Vector3.new(0, t.hy + 1.2, 0))
            if okTop and top and CFG.names then
                local text = string.format("BEAR TRAP  %dm", math.floor(d + 0.5))
                if t.armed == false then
                    text = text .. "  " .. (trapVictim(t) or "TRAPPED")
                end
                if e.lastTop ~= text then e.lastTop = text; e.top.Text = text end
                if e.col ~= colour then e.col = colour; e.top.Color = colour end
                e.top.Position = Vector2.new(top.X,
                    (topY and topY < 100000) and (topY - 16) or (top.Y - 16))
                e.top.Visible = true
            elseif e.top.Visible then
                e.top.Visible = false
            end
        end
        -- out of range: nothing is drawn for it, and the slots below n belong
        -- to other traps. The tail loop after this hides what is left over.
    end
    if trapShown > n then
        for i = n + 1, trapShown do hideSlot(trapPool[i]) end
    end
    trapShown = n
    return n
end

-- pumpkins
local pumpPool, pumpList = {}, {}
local pumpShown = 0

local pumpIndex = {}
local pumpDeepAt = 0
local pumpMapAddr = nil

local PUMP_WORDS = { "pumpkin", "jackolantern" }

local function pumpkinish(name)
    local n = lower(tostring(name)):gsub("[%s_%-]", "")
    for i = 1, #PUMP_WORDS do
        if n:find(PUMP_WORDS[i], 1, true) then return true end
    end
    return false
end

-- Name reads on a stale wrapper throw in this VM; one bad instance must not
-- abort the whole scan.
local function instName(inst)
    local n
    pcall(function() n = inst.Name end)
    return n
end

-- geometry: the model's `shell` is the visible pumpkin, `HB` is its
-- invisible hitbox, and older props are just a part. Fall back to the
-- largest part in the model, then to nested models, like the working
-- standalone did.
local function pumpkinPartOf(inst, depth)
    if not inst then return nil end
    if isPart(inst) then return inst end
    local shell, hb
    pcall(function() shell = inst:FindFirstChild("shell") end)
    if shell and isPart(shell) then return shell end
    pcall(function() hb = inst:FindFirstChild("HB") end)
    if hb and isPart(hb) then return hb end
    local ok, kids = pcall(function() return inst:GetChildren() end)
    if not ok or type(kids) ~= "table" then return nil end
    local best, bestVol = nil, -1
    for _, c in ipairs(kids) do
        if isPart(c) then
            local oks, s = pcall(function() return c.Size end)
            if oks and s then
                local vol = s.X * s.Y * s.Z
                if vol > bestVol then bestVol, best = vol, c end
            end
        end
    end
    if best then return best end
    depth = depth or 0
    if depth >= 2 then return nil end
    for _, c in ipairs(kids) do
        local cn = c.ClassName
        if cn == "Model" or cn == "Folder" then
            local p = pumpkinPartOf(c, depth + 1)
            if p then return p end
        end
    end
    return nil
end

local function pumpkinSubject(inst)
    if isPart(inst) then
        return pumpkinish(instName(inst)) and inst or nil
    end
    local shell, hb
    pcall(function() shell = inst:FindFirstChild("shell") end)
    pcall(function() hb = inst:FindFirstChild("HB") end)
    if shell and isPart(shell) then
        -- collected pumpkins go transparent; drop them
        local gone = false
        pcall(function()
            local tr = shell.Transparency
            if type(tr) == "number" and tr >= 0.9 then gone = true end
        end)
        if gone then return nil end
        return shell, hb
    end
    if hb and isPart(hb) then
        if pumpkinish(instName(inst)) then return pumpkinPartOf(inst) or hb, hb end
        return hb, hb
    end
    if pumpkinish(instName(inst)) then return pumpkinPartOf(inst) end
    return nil
end

local pumpChar
local function underCharacter(part)
    if not pumpChar and lp then pcall(function() pumpChar = lp.Character end) end
    if not pumpChar then return false end
    local ok, v = pcall(function() return part:IsDescendantOf(pumpChar) end)
    return ok and v == true
end

-- discovery order, from the working standalone: dedicated folders first,
-- then any pumpkin-named model/part two or three levels under Map and
-- Lobby, then a full Workspace sweep when that finds nothing.
local function collectPumpkins()
    -- carry over props the deep sweep found but the fast walk does not reach,
    -- so a deeply nested pumpkin does not blink out between sweeps
    local out, nextIndex, seen, seenIds = {}, {}, {}, {}
    for id, e in pairs(pumpIndex) do
        local alive = false
        if e.part and e.model then
            pcall(function()
                if e.part.Parent == nil or e.model.Parent == nil then return end
                if not e.part:IsDescendantOf(Workspace) then return end
                local tr = e.part.Transparency
                if type(tr) == "number" and tr >= 0.9 then return end
                alive = true
            end)
        end
        if alive then
            out[#out + 1] = e
            nextIndex[id] = e
            seenIds[id] = true
        end
    end

    local function add(inst)
        if not inst or seen[inst] then return end
        seen[inst] = true
        local subject, hb = pumpkinSubject(inst)
        if not subject or underCharacter(subject) then return end
        local okT, tr = pcall(function() return subject.Transparency end)
        if okT and type(tr) == "number" and tr >= 0.95 then return end
        local id = trapAddress(subject)
        if id and seenIds[id] then return end
        if id then seenIds[id] = true end
        local entry = id and pumpIndex[id] or nil
        if not entry then
            local center, hx, hy, hz, right, up, back = trapMeasure(subject)
            if not center then return end
            if hb and isPart(hb) then
                local okp, hp = pcall(function() return hb.Position end)
                if okp and hp then center = hp end
            end
            entry = { pos = center, hx = hx, hy = hy, hz = hz,
                      right = right, up = up, back = back }
        end
        entry.model, entry.part = inst, subject
        if id then nextIndex[id] = entry end
        out[#out + 1] = entry
    end

    local function fromFolder(folder)
        if not folder then return end
        local ok, kids = pcall(function() return folder:GetChildren() end)
        if not ok or type(kids) ~= "table" then return end
        for _, child in ipairs(kids) do add(child) end
    end

    local function walk(container, depth, maxDepth)
        if not container then return end
        local ok, kids = pcall(function() return container:GetChildren() end)
        if not ok or type(kids) ~= "table" then return end
        for _, inst in ipairs(kids) do
            local cls = inst.ClassName
            local named = pumpkinish(instName(inst))
            if isPart(inst) then
                if named then add(inst) end
            elseif cls == "Model" and named then
                add(inst)
            elseif (cls == "Model" or cls == "Folder") and depth < maxDepth then
                walk(inst, depth + 1, maxDepth)
            end
            if #out >= CFG.pumpPool then return end
        end
    end

    local map = Workspace:FindFirstChild("Map")
    local mapAddr
    if map then pcall(function() mapAddr = map.Address end) end
    if mapAddr and pumpMapAddr and mapAddr ~= pumpMapAddr then
        -- a different map instance means a new round; nothing cached applies
        pumpIndex = {}
        pumpDeepAt = 0
        out, nextIndex, seen, seenIds = {}, {}, {}, {}
    end
    if mapAddr then pumpMapAddr = mapAddr end
    fromFolder(map and map:FindFirstChild("Pumpkins"))
    fromFolder(Workspace:FindFirstChild("Pumpkins"))

    walk(map, 1, 2)
    walk(Workspace:FindFirstChild("Lobby"), 1, 2)

    if #out == 0 then
        -- the event folder is not always named; it holds shell/HB models
        fromFolder(Workspace:FindFirstChild("Interractables"))
    end

    -- the reference scanned the whole Workspace every 3 s; 12 s is enough for
    -- props that never move, and the first scan always sweeps.
    local now = os.clock()
    if now >= pumpDeepAt then
        -- an empty scan used to ignore pumpDeepAt entirely, so a map with no
        -- pumpkins ran a full Workspace:GetDescendants every 4 s. Retry sooner
        -- when nothing is found, but never on every collector tick.
        pumpDeepAt = now + (#out == 0 and 8 or 12)
        local ok, desc = pcall(function() return Workspace:GetDescendants() end)
        if ok and type(desc) == "table" then
            for _, inst in ipairs(desc) do
                if pumpkinish(instName(inst)) then
                    local cls = inst.ClassName
                    if isPart(inst) or cls == "Model" or cls == "Folder" then
                        add(inst)
                    end
                end
                if #out >= CFG.pumpPool then break end
            end
        end
    end

    pumpIndex = nextIndex
    return out
end

local function drawPumpkins(camPos)
    local n = 0
    for i = 1, #pumpList do
        if n >= CFG.pumpPool then break end
        local t = pumpList[i]
        local d = (t.pos - camPos).Magnitude
        if d <= CFG.pumpRange then
            n = n + 1
            local e = pumpPool[n]
            if not e then n = n - 1 break end
            local topY
            if CFG.namesOnly then
                hideBox(e)
            else
                topY = drawBox(e, t.pos, t.hx, t.hy, t.hz,
                    t.right or R_AXIS, t.up or U_AXIS, t.back or B_AXIS,
                    CFG.pumpColour, CFG.pumpFill and CFG.pumpFillA or nil, CFG.pumpThick)
            end
            local top, okTop = WorldToScreen(t.pos + Vector3.new(0, t.hy + 1.0, 0))
            if okTop and top and CFG.names then
                local text = string.format("PUMPKIN  %dm", math.floor(d + 0.5))
                if e.lastTop ~= text then e.lastTop = text; e.top.Text = text end
                if e.col ~= CFG.pumpColour then e.col = CFG.pumpColour; e.top.Color = CFG.pumpColour end
                e.top.Position = Vector2.new(top.X,
                    (topY and topY < 100000) and (topY - 16) or (top.Y - 16))
                e.top.Visible = true
            elseif e.top.Visible then
                e.top.Visible = false
            end
        end
    end
    if pumpShown > n then
        for i = n + 1, pumpShown do hideSlot(pumpPool[i]) end
    end
    pumpShown = n
    return n
end

-- skillcheck
local MEM_BASE = (type(getbase) == "function") and select(2, pcall(getbase)) or nil
local _memOk, _memChk = false, -1

local function unsafeOn()
    local now = tick()
    if now - _memChk > 1 then
        _memChk = now
        if MEM_BASE then
            local ok, b = pcall(memory_read, "byte", MEM_BASE)
            _memOk = ok and b == 77
        else
            _memOk = false
        end
    end
    return _memOk
end

local function rdf(a)
    local ok, v = pcall(memory_read, "float", a)
    if ok and type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then
        return v
    end
end

local function scFinite(v)
    return type(v) == "number" and v == v and math.abs(v) < 1000000
end

local function scAngleAt(inst, off)
    if not inst or not off then return nil end
    local a = inst.Address + off
    local angle, sn, cs = rdf(a), rdf(a + 4), rdf(a + 8)
    if not scFinite(angle) or not sn or not cs then return nil end
    if math.abs(sn * sn + cs * cs - 1) > 0.02 then return nil end
    local rad = math.rad(angle % 360)
    if math.abs(sn - math.sin(rad)) < 0.02 and math.abs(cs - math.cos(rad)) < 0.02 then
        return angle
    end

    if math.abs(sn - math.sin(angle)) < 0.02 and math.abs(cs - math.cos(angle)) < 0.02 then
        return math.deg(angle) % 360
    end
    return nil
end

local SC_OFF = 0xD0

local scTrack = { trace = {} }
local scGui = {
    refreshAt = 0, off = SC_OFF, verified = false, scanAt = 0, ids = "",
    line = nil, goal = nil, trapGoal = nil, trapPerfect = nil,
}
local scInput, scInputAt = nil, 0
local scStats = {
    checks = 0, hits = 0, misses = 0, rescues = 0, errors = 0,
    events = {},
    mode = "--", offset = "0xD0", status = "starting", hz = 0,
    line = nil, goal = nil, phase = nil, window = "--",
    samples = 0, peakStep = 0, fireAt = nil, trace = {},
}

local scPressToken = 0
local function scPlanDelay()
    local base = (tonumber(CFG.scReact) or 0) + (tonumber(CFG.scDelay) or 0)
    if CFG.scHum then
        local a = tonumber(CFG.scHumMin) or 10
        local b = tonumber(CFG.scHumMax) or 50
        if b < a then a, b = b, a end
        base = base + a + math.random() * (b - a)
    end
    return math.clamp(base, 0, 600) / 1000
end

local function scResetCheck()
    scTrack.fired, scTrack.rescued, scTrack.missed = false, false, false
    scTrack.pending = nil
    scTrack.trace = {}
    scTrack.delay = scPlanDelay()
    scTrack.scheduled = false
    scStats.delayMs = math.floor(scTrack.delay * 1000 + 0.5)
    scPressToken = scPressToken + 1
    scStats.trace = scTrack.trace
    scStats.samples, scStats.peakStep, scStats.fireAt = 0, 0, nil
end

local function scAngleRaw(inst, off)
    if not inst or not off then return nil end
    local v = rdf(inst.Address + off)
    if scFinite(v) and math.abs(v) < 100000 then return v end
    return nil
end

local function scTrapped()
    local ch = lp.Character
    if not ch then return false end
    local ok, v = pcall(function() return ch:GetAttribute("Trapped") end)
    return ok and v == true
end

local function scAlignBase(goalRot, needle)
    local v = goalRot - 168
    local k = math.floor((needle - v) / 360 + 0.5)
    return v + k * 360
end

local function scBind(now)
    if now < scGui.refreshAt then return end
    scGui.refreshAt = now + 0.2

    local pg = lp:FindFirstChild("PlayerGui")
    local check = nil

    local names = (lp:GetAttribute("platform") == "Console")
        and { "SkillCheckPromptGui-con", "SkillCheckPromptGui" }
        or { "SkillCheckPromptGui", "SkillCheckPromptGui-con" }
    for _, name in ipairs(names) do
        local g = pg and pg:FindFirstChild(name)
        local c = g and g:FindFirstChild("Check")
        if c and c:FindFirstChild("Line") then check = c; break end
    end

    local line = check and check:FindFirstChild("Line")
    local goal = check and check:FindFirstChild("Goal")
    local tg   = check and check:FindFirstChild("TrapGoal")
    local tp   = check and check:FindFirstChild("TrapPerfect")

    local ids = table.concat({
        tostring(line and line.Address), tostring(goal and goal.Address),
        tostring(tg and tg.Address), tostring(tp and tp.Address),
    }, ":")

    if ids ~= scGui.ids then
        scGui.ids = ids
        scTrack = { trace = {} }
    end
    scGui.line, scGui.goal, scGui.trapGoal, scGui.trapPerfect = line, goal, tg, tp
end

local function scEnsureOff(now)
    if scGui.verified then return scGui.off end
    if scGui.line and scGui.goal
        and scAngleAt(scGui.line, SC_OFF) and scAngleAt(scGui.goal, SC_OFF) then
        scGui.off, scGui.verified = SC_OFF, true
        scStats.offset = string.format("0x%X", SC_OFF)
        return SC_OFF
    end
    if now < scGui.scanAt then return nil end
    scGui.scanAt = now + 2
    for off = 0x40, 0x400, 4 do
        if off ~= SC_OFF and scGui.line and scGui.goal
            and scAngleAt(scGui.line, off) and scAngleAt(scGui.goal, off) then
            scGui.off, scGui.verified = off, true
            scStats.offset = string.format("0x%X", off)
            return off
        end
    end
    return nil
end

local SC_KEYS = {
    Space=32, Tab=9, Return=13, Enter=13, Escape=27, Backspace=8,
    Insert=45, Delete=46, Home=36, End=35, PageUp=33, PageDown=34,
    Left=37, Up=38, Right=39, Down=40, CapsLock=20,
    LeftShift=160, RightShift=161, LeftControl=162, RightControl=163,
    LeftAlt=164, RightAlt=165, Minus=189, Equals=187, LeftBracket=219,
    RightBracket=221, BackSlash=220, Semicolon=186, Quote=222,
    Comma=188, Period=190, Slash=191, Backquote=192,
    KeypadZero=96, KeypadOne=97, KeypadTwo=98, KeypadThree=99,
    KeypadFour=100, KeypadFive=101, KeypadSix=102, KeypadSeven=103,
    KeypadEight=104, KeypadNine=105, KeypadMultiply=106, KeypadPlus=107,
    KeypadMinus=109, KeypadPeriod=110, KeypadDivide=111, KeypadEnter=13,
}

local function scInputFor(name, fallback)
    if type(name) ~= "string" or name == "" then
        local code = tonumber(fallback) or 32
        return { code = code, name = code == 32 and "Space" or ("VK " .. tostring(code)) }
    end
    if name == "MouseButton1" or name == "MouseButton2" then
        return { mouse = name == "MouseButton1" and 1 or 2, name = name }
    end
    local code = SC_KEYS[name]
    if not code and #name == 1 and name:match("[%w]") then code = string.byte(name:upper()) end
    local f = tonumber(name:match("^F(%d+)$"))
    if not code and f and f >= 1 and f <= 24 then code = 111 + f end
    return code and { code = code, name = name } or nil
end

local scHeld = nil

local function scReleaseInput()
    local held = scHeld
    scHeld = nil
    if not held then return end
    if held.mouse == 1 then pcall(mouse1release)
    elseif held.mouse == 2 then pcall(mouse2release)
    else pcall(keyrelease, held.code) end
end

local function scPress(input)
    scHeld = input
    local ok, err
    if input.mouse == 1 then ok, err = pcall(mouse1press)
    elseif input.mouse == 2 then ok, err = pcall(mouse2press)
    else ok, err = pcall(keypress, input.code) end
    if ok then task.wait(0.02) end
    scReleaseInput()
    return ok, err
end

local scTick = { n = 0, t = os.clock() }
local scWasEnabled = false

local scBusyUntil = 0

local function scTrackSample(lr, d)
    scStats.line = lr
    if d and math.abs(d) > 0.0005 then
        scStats.samples = scStats.samples + 1
        if math.abs(d) > scStats.peakStep then scStats.peakStep = math.abs(d) end
        if #scTrack.trace < 300 then scTrack.trace[#scTrack.trace + 1] = lr end
    end
end

local function scSnapshot(base)
    local copy = {}
    local src = scTrack.trace or {}
    for i = 1, #src do copy[i] = src[i] end
    scStats.lastSweep = { base = base, n = #copy, samples = copy }
end

local scEventLog = {}
local function scEvent(text)
    scEventLog[#scEventLog + 1] = text
    if #scEventLog > 12 then table.remove(scEventLog, 1) end
    scStats.events = scEventLog
end

local function scDoPress(why)
    if CFG.scDry then
        scStats.hits = scStats.hits + 1
        scStats.status = "dry " .. why
        return
    end
    if not scInput then
        scStats.status = "unsupported bind"
        return
    end
    local ok, err = scPress(scInput)
    if ok then
        scStats.hits = scStats.hits + 1
        scStats.status = "pressed " .. scInput.name .. " (" .. why .. ")"
    else
        scStats.errors = scStats.errors + 1
        scStats.error = tostring(err)
        scStats.status = "press failed"
    end
end

local function scPressPlanned(why, angle)
    local wait = scTrack.delayUse or scTrack.delay or 0
    if wait <= 0.001 then
        scDoPress(why)
        return
    end
    -- Matcha's task.delay never fires (it is a deadline, not a scheduler), so a
    -- planned press is parked here and serviced by the scStep tick instead.
    scTrack.pending = {
        at = os.clock() + wait,
        token = scPressToken,
        angle = angle,
        why = string.format("%s +%.0fms", why, wait * 1000),
        check = function()
            local inst = scGui.line
            if not inst then return false end
            local cur = scAngleRaw(inst, scGui.off)
            if cur and scTrack.goal then
                if (cur - scTrack.goal) > 161 then return false end
                return true
            end
            -- no readable angle: press unless we can prove the prompt is gone
            local okp, parent = pcall(function() return inst.Parent end)
            return not (okp and parent == nil)
        end,
    }
end

local function scStep()
    scTick.n = scTick.n + 1
    local now = os.clock()
    if now - scTick.t >= 1 then
        scStats.hz = scTick.n / (now - scTick.t)
        scTick.n, scTick.t = 0, now
    end

    if not CFG.sc then
        scWasEnabled = false
        scStats.status = "disabled"
        scReleaseInput()
        return
    end
    if not unsafeOn() then
        scWasEnabled = false
        scStats.status = "unsafe lua off"
        scReleaseInput()
        return
    end
    if not scWasEnabled then
        scWasEnabled = true
        scTrack = { trace = {} }
        scGui.refreshAt, scInputAt = 0, 0
    end

    scBind(now)

    if now >= scInputAt then
        scInputAt = now + 0.5
        scInput = scInputFor(lp:GetAttribute("kb_skillcheck"), CFG.scKey)
        scStats.key = scInput and scInput.name or "--"
    end

    -- planned press: a deadline serviced here, because task.delay never fires
    local pending = scTrack.pending
    if pending and now >= pending.at then
        scTrack.pending = nil
        local keep = (pending.token == nil) or (pending.token == scPressToken)
        if keep and pending.check then keep = pending.check() end
        if keep then
            if pending.angle then scStats.fireAt = pending.angle end
            scDoPress(pending.why)
            now = os.clock()   -- the press holds the key for ~20ms
        end
    end

    if not scGui.line then
        scStats.status = "waiting for prompt"
        scStats.mode = "--"
        return
    end

    local off = scEnsureOff(now)
    if not off then
        scStats.status = "resolving gui"
        return
    end

    local trap = (CFG.scMode == "trap") or (CFG.scMode == nil and scTrapped())
    local mode = trap and "trap" or "gen"
    if scTrack.mode ~= mode then
        scTrack = { mode = mode, trace = {} }
        scStats.mode = mode
        scResetCheck()
    end

    local lr = scAngleRaw(scGui.line, off)
    if not lr then
        scStats.status = "read miss"
        return
    end

    local prev = scTrack.lr
    local d = nil
    if prev ~= nil then
        d = lr - prev
        d = ((d + 180) % 360) - 180
    end
    scStats.moving = (d ~= nil and math.abs(d) > 0.0005)

    local fired, why = false, nil

    if mode == "trap" then

        local tg = scAngleRaw(scGui.trapGoal, off)
        local tp = scAngleRaw(scGui.trapPerfect, off)

        local written = nil
        if tg and scTrack.tg and math.abs(tg - scTrack.tg) > 0.5 then written = tg end
        if tp and scTrack.tp and math.abs(tp - scTrack.tp) > 0.5 then written = tp end
        local started = false
        if written then
            scTrack.base = scAlignBase(written, lr)
            started = true
        end
        scTrack.tg, scTrack.tp = tg, tp

        local moving = (d ~= nil and math.abs(d) > 0.0005)
        local idle = (scTrack.lastMove == nil) or (now - scTrack.lastMove > 0.15)
        if not started then
            if scTrack.base ~= nil and lr < scTrack.base - 5 then
                scTrack.base = lr
                started = true
            elseif moving and idle then
                if scTrack.base == nil or (prev ~= nil and prev - scTrack.base > 290) then

                    scTrack.base = prev or lr
                    started = true
                end
            end
        end
        if moving then scTrack.lastMove = now end

        if started and scTrack.base then

            for _, g in ipairs({ tg, tp }) do
                if g then
                    local b = g - 168
                    b = b + 360 * math.floor((scTrack.base - b) / 360 + 0.5)
                    if math.abs(b - scTrack.base) <= 12 then scTrack.base = b; break end
                end
            end
        end

        if started then
            scStats.checks = scStats.checks + 1
            scResetCheck()
            scBusyUntil = math.max(scBusyUntil, now + 2.5)
            scTrack.speed, scTrack.sampleAt, scTrack.scheduled = nil, nil, false
            scEvent(string.format("start base=%.1f lr=%.1f prev=%s tg=%s tp=%s",
                scTrack.base, lr, tostring(prev), tostring(tg), tostring(tp)))
        end

        if moving and d ~= nil then
            local dt = now - (scTrack.sampleAt or (now - 0.016))
            if dt > 0.002 and dt < 0.3 then
                local sp = d / dt
                if sp > 20 then
                    scTrack.speed = scTrack.speed and (scTrack.speed * 0.6 + sp * 0.4) or sp
                end
            end
            scTrack.sampleAt = now
        end

        scTrackSample(lr, d)

        scStats.trapBase = scTrack.base
        if scTrack.base then
            local phase = lr - scTrack.base
            local lo, hi, good = 270, 286, 308
            local leadAdj = math.clamp(tonumber(CFG.scLead) or 0, 0, (hi - lo) - 1)

            local speed = scTrack.speed or 0
            local want = scTrack.delay or 0
            if speed > 20 then
                local cap = (lo + leadAdj - 2) / speed
                if cap > 0 and want > cap then want = cap end
            end
            scTrack.delayUse = want
            local early = (speed > 20) and (want * speed) or 0
            scStats.phase = phase
            scStats.window = string.format("%.0f..%.0f", lo, hi)
            if phase < 345 then scBusyUntil = now + 0.4 end
            if not scTrack.fired and not scTrack.missed then
                if phase >= lo + leadAdj - early and phase <= hi then
                    fired, why = true, "trap perfect"
                elseif CFG.scRescue and phase > hi and phase <= good then
                    fired, why = true, "trap good"
                    scStats.rescues = scStats.rescues + 1
                elseif phase > good + 2 then
                    scTrack.missed = true
                    scStats.misses = scStats.misses + 1
                    scSnapshot(scTrack.base)
                    scEvent(string.format("miss phase=%.1f base=%.1f lr=%.1f n=%d",
                        phase, scTrack.base, lr, #scTrack.trace))
                end

                if not fired and not scTrack.scheduled and scTrack.speed
                    and phase < lo and phase > -30 then
                    local dt = (lo + 6 - phase) / scTrack.speed - (scTrack.delayUse or 0)
                    if dt > 0.002 and dt <= 2 then
                        scTrack.scheduled, scTrack.schedBase = true, scTrack.base
                        scTrack.pending = {
                            at = os.clock() + dt, token = scPressToken,
                            why = "trap timed",
                            check = function()
                                if scTrack.base == nil or scTrack.schedBase ~= scTrack.base then return false end
                                if scTrack.fired or scTrack.missed then return false end
                                local cur = scAngleRaw(scGui.line, scGui.off)
                                if cur then
                                    local ph = cur - scTrack.base
                                    if ph < lo or ph > good then return false end
                                    scStats.fireAt = cur
                                end
                                scTrack.fired = true
                                return true
                            end,
                        }
                    end
                end
            end
        else
            scStats.status = "trap: waiting for check"
        end
    else

        local gr = scAngleRaw(scGui.goal, off)
        if not gr then
            scStats.status = "read miss"
            return
        end

        local first = (scTrack.goal == nil)
        local goalChanged = (not first) and (math.abs(gr - scTrack.goal) > 0.5)
        local jumped = (prev ~= nil) and (lr < prev - 30)
        if goalChanged or jumped then

            if gr ~= 0 then scStats.checks = scStats.checks + 1 end
            scResetCheck()
            scBusyUntil = math.max(scBusyUntil, now + 2.5)
            scTrack.speed, scTrack.sampleAt = nil, nil
        end
        scTrack.lr, scTrack.goal = lr, gr

        scTrackSample(lr, d)

        -- needle speed, so a humanized/planned delay can be taken off the trigger
        if d ~= nil and math.abs(d) > 0.0005 then
            local dt = now - (scTrack.sampleAt or (now - 0.016))
            if dt > 0.002 and dt < 0.3 then
                local sp = d / dt
                if sp > 20 then
                    scTrack.speed = scTrack.speed and (scTrack.speed * 0.6 + sp * 0.4) or sp
                end
            end
            scTrack.sampleAt = now
        end

        local lo, hi, neutral = gr + 102, gr + 116, gr + 159
        local leadAdj = math.clamp(tonumber(CFG.scLead) or 0, 0, (hi - lo) - 1)
        local speed = scTrack.speed or 0
        local want = scTrack.delay or 0
        if speed > 20 then
            local cap = (102 + leadAdj - 2) / speed
            if cap > 0 and want > cap then want = cap end
        end
        scTrack.delayUse = want
        local early = (speed > 20) and (want * speed) or 0
        scStats.goal = gr
        scStats.window = string.format("%.0f..%.0f", lo, hi)
        if not scTrack.fired and not scTrack.missed then
            if lr >= lo + leadAdj - early and lr <= hi then
                fired, why = true, "perfect"
            elseif CFG.scRescue and lr > hi and lr <= neutral then
                fired, why = true, "neutral"
                scStats.rescues = scStats.rescues + 1
            elseif lr > neutral + 2 then
                scTrack.missed = true
                scStats.misses = scStats.misses + 1
            end
        end
    end

    scTrack.lr = lr

    if fired then
        scStats.fireAt = lr
        if mode == "trap" and scTrack.base then
            scSnapshot(scTrack.base)
            scEvent(string.format("fire phase=%.1f base=%.1f lr=%.1f", lr - scTrack.base, scTrack.base, lr))
        end
        scTrack.fired = true
        scTrack.rescued = (why == "neutral" or why == "trap good")
        scPressPlanned(why, lr)
    elseif scTrack.missed then
        scStats.status = "window passed"
    elseif scStats.moving then
        scStats.status = "following"
    else
        scStats.status = "waiting for check"
    end
end

local running = true
local camera = Workspace.CurrentCamera
local connection
local renderMs, frameN, fpsMark, drawFps = 0, 0, os.clock(), 0

local winScanStamp, winScanAt = nil, 0
local genDiscoverStamp, genDiscoverAt = nil, 0
local worldMs, palScanMs = 0, 0

-- collectors
local function refreshWorld()

    local started = os.clock()
    local map = Workspace:FindFirstChild("Map")
    local stamp = "none"
    if map then
        -- Address/GetChildren can throw in this VM; a dead stamp would stop
        -- every world collector at once, so both reads are defensive
        local addr, count = nil, nil
        pcall(function() addr = map.Address end)
        pcall(function() count = #map:GetChildren() end)
        stamp = tostring(addr) .. ":" .. tostring(count)
    end
    if stamp ~= genStamp then
        genStamp = stamp
        genGeo = {}
        winGeo = {}
        palGeo = {}
        palParts = {}
        winScanStamp = nil
    end

    if not (CFG.gen or (CFG.hud and CFG.hudGens)) then
        genList = {}
    elseif genList[1] and stamp == genDiscoverStamp and os.clock() < genDiscoverAt then

    else
        genDiscoverStamp, genDiscoverAt = stamp, os.clock() + 30
        local found = collectGens()
        local kept = {}
        for _, t in ipairs(found) do
            local cached = t.key and genGeo[t.key] or nil
            if cached == nil and t.key then
                local center, hx, hy, hz, cf = measureModel(t.model)
                cached = { center = center, hx = hx, hy = hy, hz = hz, cf = cf }
                cached.right, cached.up, cached.back = basisFromCFrame(cf)
                genGeo[t.key] = cached
            end
            if cached then
                t.center, t.hx, t.hy, t.hz, t.cf = cached.center, cached.hx, cached.hy, cached.hz, cached.cf
                t.right, t.up, t.back = cached.right, cached.up, cached.back
                if t.center then kept[#kept + 1] = t end
            elseif not t.key then
                local center, hx, hy, hz, cf = measureModel(t.model)
                if center then
                    t.center, t.hx, t.hy, t.hz, t.cf = center, hx, hy, hz, cf
                    t.right, t.up, t.back = basisFromCFrame(cf)
                    kept[#kept + 1] = t
                end
            end
        end
        ensureSlots(genPool, math.min(#kept, CFG.genPool), CFG.genThick, CFG.genText)
        genList = kept
        if not kept[1] then genDiscoverAt = os.clock() + 1.5 end
    end

    if not CFG.win then
        winList = {}
    else
        local t = os.clock()
        if stamp ~= winScanStamp or t >= winScanAt then
            winScanStamp = stamp
            local found = collectWindows()
            if found then
                winScanAt = t + 30
                ensureSlots(winPool, math.min(#found, CFG.winPool), CFG.winThick, CFG.winText)
                winList = found
            else
                -- one failed read used to wipe every window for the next 30s
                winScanAt = t + 2
            end
        end
    end
    worldMs = worldMs * 0.8 + (os.clock() - started) * 1000 * 0.2
end

local function refreshPallets()
    if not CFG.pal then
        palList = {}
        return
    end
    local started = os.clock()
    local ok, list = pcall(collectPallets)
    if ok and list then
        ensureSlots(palPool, math.min(#list, CFG.palPool), CFG.palThick, CFG.palText)
        palList = list
    end
    palScanMs = palScanMs * 0.8 + (os.clock() - started) * 1000 * 0.2
end

connection = RunService.RenderStepped:Connect(function()
    -- a reload replaces __SWANGY_LOAD: a stale instance must stop drawing too
    if not running or _G.__SWANGY_LOAD ~= loadToken then return end
    local now = os.clock()
    if CFG.drawHz > 0 and now - (CFG.lastFrame or 0) < 1 / CFG.drawHz then return end
    CFG.lastFrame = now
    frameN = frameN + 1
    if now - fpsMark >= 1 then
        drawFps = frameN / (now - fpsMark)
        frameN, fpsMark = 0, now
    end

    -- CurrentCamera is replaced on respawn and on a map swap; keeping the first
    -- one left every box projecting through a dead camera until reload
    camera = Workspace.CurrentCamera or camera
    if not camera then return end
    local okc, ccf = pcall(function() return camera.CFrame end)
    if not okc or not ccf then return end
    local camPos = ccf.Position
    camNow = camPos
    local vp = camera.ViewportSize
    if vp then camVpW, camVpH = vp.X, vp.Y end

    if CFG.gen then
        local okg, errg = pcall(drawGens, camPos, now)
        CFG.errGen = (not okg) and tostring(errg) or nil
    elseif genShown > 0 then
        for i = 1, genShown do hideSlot(genPool[i]) end
        genShown = 0
    end
    if CFG.win then
        local okw, errw = pcall(drawWindows, camPos)
        CFG.errWin = (not okw) and tostring(errw) or nil
    elseif winShown > 0 then
        for i = 1, winShown do hideSlot(winPool[i]) end
        winShown = 0
    end
    if CFG.pal then
        local okp, errp = pcall(drawPallets, camPos)
        CFG.errPal = (not okp) and tostring(errp) or nil
    elseif palShown > 0 then
        for i = 1, palShown do hideSlot(palPool[i]) end
        palShown = 0
    end
    if CFG.trap then
        local okt, errt = pcall(drawTraps, camPos)
        CFG.errTrap = (not okt) and tostring(errt) or nil
    elseif trapShown > 0 then
        for i = 1, trapShown do hideSlot(trapPool[i]) end
        trapShown = 0
    end
    if CFG.pump then
        local okpk, errpk = pcall(drawPumpkins, camPos)
        CFG.errPump = (not okpk) and tostring(errpk) or nil
    elseif pumpShown > 0 then
        for i = 1, pumpShown do hideSlot(pumpPool[i]) end
        pumpShown = 0
    end

    renderMs = renderMs * 0.9 + (os.clock() - now) * 1000 * 0.1
end)

task.spawn(function()
    while running do
        if os.clock() >= scBusyUntil then pcall(refreshWorld) end
        task.wait(1 / CFG.pollHz)
    end
end)

local genPollHz = 10
task.spawn(function()
    while running do
        if (CFG.gen or (CFG.hud and CFG.hudGens)) and genList[1] then pcall(updateGenStates, genList) end
        task.wait(1 / genPollHz)
    end
end)

task.spawn(function()
    while running do
        if os.clock() >= scBusyUntil then pcall(refreshPallets) end
        task.wait(1 / CFG.palHz)
    end
end)

task.spawn(function()
    while running do
        if CFG.pump then
            local ok, list = pcall(collectPumpkins)
            if ok and list then
                ensureSlots(pumpPool, math.min(#list, CFG.pumpPool), CFG.pumpThick, CFG.pumpText)
                pumpList = list
            end
        elseif #pumpList > 0 then
            pumpList = {}
        end
        task.wait(1 / CFG.pumpScanHz)
    end
end)

task.spawn(function()
    while running do
        if CFG.trap or (CFG.hud and CFG.hudTraps) then
            local ok, list = pcall(collectTraps)
            if ok and list then
                ensureSlots(trapPool, math.min(#list, CFG.trapPool), CFG.trapThick, CFG.trapText)
                trapList = list
            end
            pcall(trapScanTrapped, os.clock())
        elseif #trapList > 0 then
            trapList = {}
        end
        task.wait(1)
    end
end)

task.spawn(function()
    while running do
        local ok, err = pcall(scStep)
        if not ok then
            scReleaseInput()
            scTrack = {}
            scStats.errors = scStats.errors + 1
            scStats.error, scStats.status = tostring(err), "read error, retrying"
        end
        task.wait(not ok and 0.1 or (CFG.sc and 1 / CFG.scHz or 0.1))
    end
    scReleaseInput()
end)

-- api
local API = {}
_G.__SWANGY = API

API.gen = {}
function API.gen.SetEnabled(on) CFG.gen = on and true or false; return CFG.gen end
function API.gen.Toggle() return API.gen.SetEnabled(not CFG.gen) end
function API.gen.SetRange(v) CFG.genRange = math.max(1, tonumber(v) or CFG.genRange) end
function API.gen.GetCount() return #genList end

API.win = {}
function API.win.SetEnabled(on)
    CFG.win = on and true or false

    if CFG.win then winScanStamp = nil else winList = {} end
    return CFG.win
end
function API.win.Toggle() return API.win.SetEnabled(not CFG.win) end
function API.win.SetRange(v) CFG.winRange = math.max(1, tonumber(v) or CFG.winRange) end
function API.win.GetCount() return #winList end

API.pal = {}
function API.pal.SetEnabled(on)
    CFG.pal = on and true or false
    if CFG.pal then pcall(refreshPallets) else palList = {} end
    return CFG.pal
end
function API.pal.Toggle() return API.pal.SetEnabled(not CFG.pal) end
function API.pal.SetRange(v) CFG.palRange = math.max(1, tonumber(v) or CFG.palRange) end
function API.pal.GetCount() return #palList end

API.trap = {}
function API.trap.SetEnabled(on)
    CFG.trap = on and true or false
    if not CFG.trap then trapShown = 0 end
    return CFG.trap
end
function API.trap.Toggle() return API.trap.SetEnabled(not CFG.trap) end
function API.trap.SetRange(v) CFG.trapRange = math.max(1, tonumber(v) or CFG.trapRange) end
function API.trap.GetCount() return #trapList end
API.pumpkin = {}
function API.pumpkin.SetEnabled(on)
    CFG.pump = on and true or false
    if not CFG.pump then pumpList = {} pumpShown = 0 end
    return CFG.pump
end
function API.pumpkin.Toggle() return API.pumpkin.SetEnabled(not CFG.pump) end
function API.pumpkin.SetRange(v) CFG.pumpRange = math.max(1, tonumber(v) or CFG.pumpRange) end
function API.pumpkin.GetCount() return #pumpList end

function API.trap.GetStates()
    local out = {}
    for i = 1, #trapList do
        local t = trapList[i]
        out[i] = { armed = t.armed, victim = trapVictim(t), pos = t.pos }
    end
    return out
end
function API.pal.GetStates()
    local out = {}
    for i = 1, #palList do out[i] = { dropped = palList[i].dropped, pos = palList[i].pos } end
    return out
end

API.sc = {}
function API.sc.SetEnabled(on)
    CFG.sc = on and true or false
    if not CFG.sc then scReleaseInput(); scTrack = {} end
    return CFG.sc
end
function API.sc.Toggle() return API.sc.SetEnabled(not CFG.sc) end
function API.sc.SetLead(v) CFG.scLead = math.clamp(tonumber(v) or CFG.scLead, 0, 12) end
function API.sc.SetRescue(on) CFG.scRescue = on and true or false; return CFG.scRescue end
function API.sc.SetDryRun(on) CFG.scDry = on and true or false; return CFG.scDry end
function API.sc.SetMode(mode)
    if mode == "gen" or mode == "trap" then CFG.scMode = mode else CFG.scMode = nil end
    return CFG.scMode
end
function API.sc.Stats()
    local p = scTrack.pending
    scStats.pending = p and string.format("+%.0fms", math.max(0, (p.at - os.clock()) * 1000)) or nil
    return scStats
end

function API.SetFill(gen, win, pal)
    if gen ~= nil then CFG.genFill = gen and true or false end
    if win ~= nil then CFG.winFill = win and true or false end
    if pal ~= nil then CFG.palFill = pal and true or false end
    return CFG.genFill, CFG.winFill, CFG.palFill
end

function API.SetDrawHz(hz)
    CFG.drawHz = math.max(0, tonumber(hz) or 0)
    return CFG.drawHz
end

function API.GetConfig()
    return {
        gen = CFG.gen, win = CFG.win, pal = CFG.pal, trap = CFG.trap, pump = CFG.pump,
        names = CFG.names, namesOnly = CFG.namesOnly, errPump = CFG.errPump,
        range = CFG.genRange,
        winColour = CFG.winColour, palColour = CFG.palColour,
        trapArmedColour = CFG.trapArmedColour, trapSprungColour = CFG.trapSprungColour,
        genIdleColour = CFG.genIdleColour, genDoneColour = CFG.genDoneColour,
        genBrokenColour = CFG.genBrokenColour,
        sc = CFG.sc, hum = CFG.scHum, humMin = CFG.scHumMin, humMax = CFG.scHumMax,
        react = CFG.scReact, delay = CFG.scDelay,
        va = CFG.va, vaFov = CFG.vaFov, vaRange = CFG.vaRange, vaSmooth = CFG.vaSmooth,
        vaSticky = CFG.vaSticky, vaLead = CFG.vaLead, vaLos = CFG.vaLos, vaHold = CFG.vaHold,
        vaAimHeight = CFG.vaAimHeight, kbw = CFG.kbw,
        hud = CFG.hud, hudAlpha = CFG.hudAlpha, hudGens = CFG.hudGens,
        hudTraps = CFG.hudTraps, hudSurvivors = CFG.hudSurvivors,
        ui = UI ~= nil,
    }
end

function API.Perf()
    return {
        drawHz   = CFG.drawHz,
        drawFps  = drawFps,
        renderMs = renderMs,
        worldMs  = worldMs,
        palScanMs = palScanMs,
        genPollHz = genPollHz,
        gen      = #genList,
        win      = #winList,
        pal      = #palList,
        trap     = #trapList,
        hud      = HUD.count,
        hudDrawMs = HUD.drawMs,
        hudPollMs = HUD.pollMs,
        scHz     = CFG.scHz,
        frameMs  = math.floor(1 / math.max(drawFps, 1) * 1000 + 0.5),
        err      = CFG.errGen or CFG.errWin or CFG.errPal or CFG.errTrap,
    }
end

function API.unload()
    if not running then return end
    running = false
    if kbwDestroy then pcall(kbwDestroy) end
    if API.matchaCleanup then pcall(API.matchaCleanup) end
    if HUD.destroy then pcall(HUD.destroy) end
    scReleaseInput()
    if UI and UI.Unload then pcall(function() UI:Unload() end) end
    UI, uiWindow = nil, nil
    if connection then connection:Disconnect(); connection = nil end
    for i = 1, #genPool do removeSlot(genPool[i]) end
    for i = 1, #winPool do removeSlot(winPool[i]) end
    for i = 1, #palPool do removeSlot(palPool[i]) end
    for i = 1, #trapPool do removeSlot(trapPool[i]) end
    for i = 1, #pumpPool do removeSlot(pumpPool[i]) end
    genPool, winPool, palPool, trapPool, pumpPool = {}, {}, {}, {}, {}
    if _G.__SWANGY == API then _G.__SWANGY = nil end
end
API.stop = API.unload

-- aimbot
local vaStat = {
    target = nil, dist = nil, speed = nil, flight = nil, hold = 0,
    solved = false, tier = nil, charging = false, addr = false,
    losOK = nil, error = nil, held = false, state = "Disabled",
}

local vaRot, vaRotFor, vaWarmAt = nil, nil, 0

local function vaRotAddr()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local okB, base = pcall(function() return cam.Address end)
    if not okB or not base then return nil end
    if vaRotFor == base and vaRot then return vaRot end

    local now = os.clock()
    if now < vaWarmAt then return nil end
    vaWarmAt = now + 0.1

    local ok, res = pcall(function()
        local cf = cam.CFrame
        if not cf then return nil end
        local lv, pos = cf.LookVector, cf.Position
        local function near(a, b, tol) return a and math.abs(a - b) <= tol end
        local cand = { 0xD8 }
        for o = 0x40, 0x400, 4 do cand[#cand + 1] = o end
        for _, o in ipairs(cand) do
            if near(rdf(base + o + 8), -lv.X, 0.01)
                and near(rdf(base + o + 20), -lv.Y, 0.01)
                and near(rdf(base + o + 32), -lv.Z, 0.01)
                and near(rdf(base + o + 36), pos.X, 0.05)
                and near(rdf(base + o + 40), pos.Y, 0.05)
                and near(rdf(base + o + 44), pos.Z, 0.05) then
                return o
            end
        end
        return nil
    end)
    if ok and res then
        vaRot, vaRotFor = base + res, base
        return vaRot
    end
end

local VA_UP = Vector3.new(0, 1, 0)

local function vaWriteLook(addr, f)
    if not addr or not f then return false end
    local zv = -f
    local xv = VA_UP:Cross(zv)
    if xv.Magnitude < 1e-4 then return false end
    xv = xv.Unit
    local yv = zv:Cross(xv)
    local ok = pcall(function()
        memory_write("float", addr, xv.X)
        memory_write("float", addr + 4, yv.X)
        memory_write("float", addr + 8, zv.X)
        memory_write("float", addr + 12, xv.Y)
        memory_write("float", addr + 16, yv.Y)
        memory_write("float", addr + 20, zv.Y)
        memory_write("float", addr + 24, xv.Z)
        memory_write("float", addr + 28, yv.Z)
        memory_write("float", addr + 32, zv.Z)
    end)
    return ok
end

local VA_DT = 1 / 60
local VA_MIN_HP = 25

local function vaAngle(ox, oy, oz, px, py, pz, s, g)
    local dx, dy, dz = px - ox, py - oy, pz - oz
    local flat = math.sqrt(dx * dx + dz * dz)
    if flat < 1e-3 then return nil end
    local s2 = s * s
    local disc = s2 * s2 - g * (g * flat * flat + 2 * dy * s2)
    if disc < 0 then return nil end
    local tan = (s2 - math.sqrt(disc)) / (g * flat)
    local ang = math.atan(tan)
    local ca, sa = math.cos(ang), math.sin(ang)
    if ca < 1e-4 then return nil end
    return Vector3.new(dx / flat * ca, sa, dz / flat * ca), flat / (s * ca)
end

local function vaIntercept(o, tp, tv, s, g)
    local dir, ft = vaAngle(o.X, o.Y, o.Z, tp.X, tp.Y, tp.Z, s, g)
    if not dir then return nil end
    if tv then
        for _ = 1, 6 do
            local d2, f2 = vaAngle(o.X, o.Y, o.Z,
                tp.X + tv.X * ft, tp.Y + tv.Y * ft, tp.Z + tv.Z * ft, s, g)
            if not d2 then break end
            local done = math.abs(f2 - ft) < 0.002
            dir, ft = d2, f2
            if done then break end
        end
    end
    return dir, ft
end

local function vaSpeedFor(hold)
    local charge = math.max(hold, 0.3)
    return math.clamp(charge * 180, 1, 180), charge >= 1 and "FULL" or "PARTIAL"
end

local function vaLaunchIntercept(camera, tp, tv, speed)
    local dir, ft = vaIntercept(camera, tp, tv, speed, 98.1)
    if not dir then return nil end
    for _ = 1, 8 do
        local origin = camera + dir * 3
        local nextDir, nextTime = vaIntercept(origin, tp, tv, speed, 98.1)
        if not nextDir then return nil end
        local delta = (nextDir - dir).Magnitude
        dir, ft = nextDir, nextTime
        if delta < 0.00001 then break end
    end
    local hit = camera + dir * (3 + speed * ft) + Vector3.new(0, -49.05 * ft * ft, 0)
    local target = tv and tp + tv * ft or tp
    if (hit - target).Magnitude > 0.25 then return nil end
    return dir, ft
end

local vaHist = {}

local function vaTrack(key, pos, now)
    local h = vaHist[key]
    if not h or now - h.t > 0.3 or (pos - h.p).Magnitude > 30 then
        vaHist[key] = { p = pos, t = now, v = Vector3.new(0, 0, 0) }
        return Vector3.new(0, 0, 0)
    end
    local dt = now - h.t
    if dt >= 0.02 then
        local inst = (pos - h.p) / dt
        if inst.Magnitude > 60 then inst = inst.Unit * 60 end
        h.v = h.v + (inst - h.v) * 0.35
        h.p, h.t = pos, now
    end
    return h.v
end

local vaRP
pcall(function()
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    vaRP = p
end)

local vaRayCap = nil
local function vaRayUsable(myChar)
    if vaRayCap ~= nil then return vaRayCap end
    local hrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not hrp then return true end
    local ok, hit = pcall(function()
        local from = hrp.CFrame.Position + Vector3.new(0, 6, 0)
        return Workspace:Raycast(from, Vector3.new(0, -12, 0))
    end)
    vaRayCap = (ok and hit ~= nil) and true or false
    vaStat.losOK = vaRayCap
    return vaRayCap
end

local function vaLineOfSight(o, p, myChar, theirChar)
    if not vaRP or not vaRayUsable(myChar) then return true end
    local d = p - o
    if d.Magnitude < 1 then return true end
    local ok, hit = pcall(function()
        vaRP.FilterDescendantsInstances = { myChar, theirChar }
        return Workspace:Raycast(o, d, vaRP)
    end)
    if not ok then return true end
    return hit == nil
end

local function vaPlayers()
    local ok, list = pcall(function() return Players:GetPlayers() end)
    if ok and type(list) == "table" and #list > 0 then return list end
    local ok2, kids = pcall(function() return Players:GetChildren() end)
    if not ok2 or type(kids) ~= "table" then return {} end
    local out = {}
    for _, p in ipairs(kids) do
        if p.ClassName == "Player" then out[#out + 1] = p end
    end
    return out
end

API.va = {}
function API.va.SetEnabled(on)
    CFG.va = on and true or false
    if not CFG.va then
        vaStat.target, vaStat.solved, vaStat.state = nil, false, "Disabled"
    end
    return CFG.va
end
function API.va.Toggle() return API.va.SetEnabled(not CFG.va) end
function API.va.SetFov(v) CFG.vaFov = math.clamp(tonumber(v) or CFG.vaFov, 5, 180) end
function API.va.SetRange(v) CFG.vaRange = math.clamp(tonumber(v) or CFG.vaRange, 20, 600) end
function API.va.SetSmoothing(v) CFG.vaSmooth = math.clamp(tonumber(v) or CFG.vaSmooth, 1, 20) end
function API.va.Stats() return vaStat end

task.spawn(function()
    local gateAt, isKiller, spearmode, myName = 0, false, false, nil
    local myChar = nil
    local pressT, wasDown, releaseArmed = nil, false, false
    local releaseUntil, releaseHold = 0, 0
    local lastT, lockName = nil, nil

    while running do
        local now = os.clock()
        local dt = (lastT and (now - lastT)) or VA_DT
        lastT = now
        if dt <= 0 then dt = VA_DT elseif dt > 0.25 then dt = 0.25 end

        if now >= gateAt then
            gateAt = now + 0.1
            local okg = pcall(function()
                myChar = lp.Character
                myName = lp.Name
                local team = lp.Team
                isKiller = (team and team.Name == "Killer") and true or false
                spearmode = myChar and myChar:GetAttribute("spearmode") == true
                if myChar then vaRayUsable(myChar) end
            end)
            if not okg then isKiller, spearmode = false, false end
        end

        local focused = false
        pcall(function() focused = isrbxactive() == true end)
        local menuOpen = uiWindow ~= nil and uiWindow.visible == true

        local down = false
        if not menuOpen and isKiller and spearmode and focused then
            local okm, v = pcall(ismouse1pressed)
            down = okm and v == true
        end
        if down and not wasDown then
            pressT, releaseArmed, releaseUntil = now, true, 0
        elseif (not down) and wasDown and releaseArmed then
            local held = pressT and (now - pressT) or 0
            releaseHold = math.max(held, 0.3)
            releaseUntil = now + math.max(0, 0.3 - held) + 0.01 + 1 / 60
            pressT, releaseArmed = nil, false
        end
        wasDown = down
        local releasing = now < releaseUntil
        local hold = pressT and (now - pressT) or (releasing and releaseHold or 0)
        vaStat.hold = hold
        vaStat.charging = pressT ~= nil or releasing

        local armed = CFG.va and isKiller and (spearmode or releasing) and unsafeOn()
            and not menuOpen and focused
        if armed and CFG.vaHold and not vaStat.charging then armed = false end

        if not CFG.va then vaStat.state = "Disabled"
        elseif not unsafeOn() then vaStat.state = "Enable Unsafe LuaU"
        elseif not isKiller then vaStat.state = "Killer only"
        elseif not spearmode and not releasing then vaStat.state = "Equip a spear"
        elseif not focused then vaStat.state = "Waiting for game focus"
        elseif menuOpen then vaStat.state = "Menu open"
        elseif CFG.vaHold and not vaStat.charging then vaStat.state = "Hold attack to charge"
        end

        if not armed then
            vaStat.target, vaStat.solved, vaStat.dist = nil, false, nil
            vaStat.speed, vaStat.flight, vaStat.tier = nil, nil, nil
            lockName, vaStat.held = nil, false
        else
            local addr = vaRotAddr()
            vaStat.addr = addr ~= nil
            local cam = Workspace.CurrentCamera
            local hrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if addr and cam and hrp then
                local okAim, aimError = pcall(function()
                    local look = cam.CFrame.LookVector
                    local origin = cam.CFrame.Position
                    local speed, tier = vaSpeedFor(hold)
                    local cosFov = math.cos(math.rad(CFG.vaFov))

                    local best, bestSol, bestFt, bestDist
                    local heldSol, heldFt, heldDist
                    for _, pl in ipairs(vaPlayers()) do
                        if pl.Name ~= myName then
                            local tm = pl.Team
                            if tm and tm.Name == "Survivors" then
                                local ch = pl.Character
                                local thr = ch and ch:FindFirstChild("HumanoidRootPart")
                                local hum = ch and ch:FindFirstChild("Humanoid")
                                local hp = hum and hum.Health
                                if thr and (type(hp) ~= "number" or hp >= VA_MIN_HP) then
                                    local tp = thr.Position + Vector3.new(0, CFG.vaAimHeight or 0, 0)
                                    local off = tp - origin
                                    local dist = off.Magnitude
                                    if dist > 1 and dist <= CFG.vaRange then
                                        local isHeld = CFG.vaSticky and lockName == pl.Name
                                        local dot = off.Unit:Dot(look)
                                        if dot >= cosFov
                                            and ((not best or dist < bestDist) or isHeld) then
                                            local tv = CFG.vaLead and vaTrack(pl.Name, thr.Position, now) or nil
                                            local dir, ft = vaLaunchIntercept(origin, tp, tv, speed)
                                            if dir and (not CFG.vaLos
                                                or vaLineOfSight(origin, tp, myChar, ch)) then
                                                if isHeld then
                                                    heldSol, heldFt, heldDist = dir, ft, dist
                                                end
                                                if not best or dist < bestDist then
                                                    best = pl.Name
                                                    bestSol, bestFt, bestDist = dir, ft, dist
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end

                    if heldSol then
                        best = lockName
                        bestSol, bestFt, bestDist = heldSol, heldFt, heldDist
                    end
                    lockName = best
                    vaStat.held = heldSol ~= nil

                    vaStat.target = best
                    vaStat.speed = speed
                    vaStat.tier = tier
                    vaStat.dist = bestDist
                    vaStat.flight = bestFt
                    vaStat.solved = bestSol ~= nil

                    if bestSol then
                        local want = bestSol
                        local sm = CFG.vaSmooth or 1
                        if sm > 1 then
                            local tau = (sm - 1) * 0.015
                            local a = 1 - math.exp(-dt / tau)
                            local blend = look + (want - look) * a
                            if blend.Magnitude > 1e-4 then want = blend.Unit end
                        end
                        vaWriteLook(addr, want)
                    end
                    vaStat.state = best and (bestSol and ("Locked " .. best) or "No clear solution")
                        or "No target in range"
                end)
                vaStat.error = not okAim and tostring(aimError) or nil
                if not okAim then vaStat.solved = false end
            else
                vaStat.solved = false
                vaStat.state = addr and "Waiting for character" or "Resolving camera"
            end
        end

        task.wait(1 / 144)
    end
end)

-- parry: replicated windup attributes -> simulated right click
--
-- Every value here was measured live in this game on 2026-10-29, and each
-- one replaced something that did not work:
--   * the swing is LowerBodyStabilize + AC_AllowedSpeed in 20..40. The band
--     appears a poll BEFORE the stab flag, so the band alone is the trigger.
--     ac=nil and ac=3.62 locks exist and are rejected by the band.
--   * Players:GetPlayers and Players:GetChildren return empty mid-round, so
--     killers are found in Workspace by attributes only a killer carries.
--   * LocalPlayer's wrapper goes stale and CameraSubject is often a
--     CameraBlock Part, so your character is found by attributes only the
--     local client writes.
--   * the client cooldown token caches stale addresses and blocked five real
--     presses in a row, so it is not consulted at all. A press with the
--     dagger down is refused by the game at no cost.
--   * the press is mouse2click. No remote is ever sent.
--   * the whole gate set is cached at 5 Hz: eleven GetAttribute reads on the
--     press path measured as the reason a press landed too late.
local PARRY = {
    state = "Disabled", reason = nil, error = nil, denied = nil,
    presses = 0, lands = 0, scans = 0,
    lastPress = -100, lastCollect = 0, lastWindup = 0,
    targets = {}, gate = { ok = false, reason = "starting", at = -1 },
    charCache = nil, charAt = -1, rootCache = nil, rootAt = -1,
}

-- Attributes only a KILLER character carries. Stalking is deliberately out:
-- a survivor was measured carrying Stalking=false.
local PP_KILLER_ATTRS = {
    "TerrorRadius", "ChaseTargetUserId", "BloodLust",
    "MorphedKiller", "Butcher", "Beartraps",
}
-- Attributes written by scripts on YOUR client only. Verified against the
-- killer and another survivor, whose lists contain none of them.
local PP_SELF_ATTRS = {
    "ParrySpent", "ParryLands", "Parry",
    "RoundScriptsActive", "overridelookscript", "nogui",
}

PARRY.actions = { "action", "isVaulting", "isSliding", "isDroppingPallet",
    "isRepairing", "isHealing", "isUnhooking", "isExiting" }
PARRY.blocked = { "Knocked", "IsHooked", "IsCarried", "IsDead", "Trapped" }

function PARRY.addr(inst)
    if not inst then return nil end
    local ok, a = pcall(function() return inst.Address end)
    if ok and type(a) == "number" and a ~= 0 then return tostring(a) end
    return tostring(inst)
end

function PARRY.same(a, b)
    if not a or not b then return false end
    local x, y = PARRY.addr(a), PARRY.addr(b)
    if x and y and x == y then return true end
    local n1, n2 = nil, nil
    pcall(function() n1 = a.Name end)
    pcall(function() n2 = b.Name end)
    return n1 ~= nil and n1 == n2
end

-- Your character, without Players and without trusting the camera subject.
function PARRY.myChar()
    local now = os.clock()
    if PARRY.charCache and now - PARRY.charAt < 0.5 and PARRY.charCache.Parent then
        return PARRY.charCache
    end
    PARRY.charAt = now
    local prev = PARRY.charCache
    PARRY.charCache = nil

    local cam = nil
    pcall(function() cam = Workspace.CurrentCamera end)
    if cam then
        local subj = nil
        pcall(function() subj = cam.CameraSubject end)
        if subj then
            local model = nil
            pcall(function()
                model = subj.Parent
                if model and model.ClassName ~= "Model" then model = model.Parent end
            end)
            if model and model.ClassName == "Model" then PARRY.charCache = model end
        end
    end

    if not PARRY.charCache and lp then
        local okP, ch = pcall(function() return lp.Character end)
        if okP and ch then PARRY.charCache = ch end
    end

    if not PARRY.charCache then
        local ok, kids = pcall(function() return Workspace:GetChildren() end)
        if ok and type(kids) == "table" then
            local camPos = nil
            pcall(function() camPos = Workspace.CurrentCamera.CFrame.Position end)
            local best, bestD = nil, nil
            for i = 1, #kids do
                local m = kids[i]
                if m.ClassName == "Model" then
                    local hum = nil
                    pcall(function() hum = m:FindFirstChildOfClass("Humanoid") end)
                    if hum then
                        local mine = false
                        for j = 1, #PP_SELF_ATTRS do
                            local v = nil
                            pcall(function() v = m:GetAttribute(PP_SELF_ATTRS[j]) end)
                            if v ~= nil then mine = true break end
                        end
                        if mine then
                            PARRY.charCache = m
                            break
                        end
                        local root = nil
                        pcall(function() root = m:FindFirstChild("HumanoidRootPart") end)
                        if root and camPos then
                            local d = nil
                            pcall(function() d = (root.Position - camPos).Magnitude end)
                            if d and d < 6 and (not bestD or d < bestD) then best, bestD = m, d end
                        end
                    end
                end
            end
            if not PARRY.charCache and best then PARRY.charCache = best end
        end
    end

    if not PARRY.charCache and prev then
        local alive = false
        pcall(function() alive = prev.Parent ~= nil end)
        if alive then PARRY.charCache = prev end
    end
    return PARRY.charCache
end

function PARRY.myRoot()
    local now = os.clock()
    if PARRY.rootCache and now - PARRY.rootAt < 0.25 and PARRY.rootCache.Parent then
        return PARRY.rootCache
    end
    PARRY.rootAt = now
    PARRY.rootCache = nil
    local ch = PARRY.myChar()
    if ch then
        local ok, root = pcall(function() return ch:FindFirstChild("HumanoidRootPart") end)
        if ok then PARRY.rootCache = root end
    end
    return PARRY.rootCache
end

function PARRY.distance(a, b)
    if not a or not b then return nil end
    local d = nil
    pcall(function() d = (a.Position - b.Position).Magnitude end)
    return d
end

function PARRY.ping()
    if type(GetPingValue) == "function" then
        local ok, v = pcall(GetPingValue)
        if ok and type(v) == "number" then return v end
    end
    return 0
end

function PARRY.range()
    local r = CFG.ppRange or 14
    if CFG.ppPing then r = r + PARRY.ping() * 0.015 end
    return math.max(r, CFG.ppMinRange or 13)
end

function PARRY.dagger()
    local ch = PARRY.myChar()
    local pack = nil
    if lp then pcall(function() pack = lp:FindFirstChildOfClass("Backpack") end) end
    for _, holder in ipairs({ ch, pack }) do
        if holder then
            for _, name in ipairs({ "Parrying Dagger", "Parry Dagger" }) do
                local t = nil
                pcall(function() t = holder:FindFirstChild(name) end)
                if t then return t end
            end
            local ok, kids = pcall(function() return holder:GetChildren() end)
            if ok and kids then
                for i = 1, #kids do
                    local n = string.lower(tostring(kids[i].Name))
                    if n:find("dagger", 1, true) or n:find("parry", 1, true) then
                        return kids[i]
                    end
                end
            end
        end
    end
end

function PARRY.equip()
    local ch = PARRY.myChar()
    local tool = PARRY.dagger()
    if not ch or not tool or PARRY.same(tool.Parent, ch) then return end
    local hum = nil
    pcall(function() hum = ch:FindFirstChildOfClass("Humanoid") end)
    pcall(function()
        tool.Parent = ch
        if hum then task.spawn(function() hum:EquipTool(tool) end) end
    end)
end

function PARRY.facing(kRoot, myRoot)
    local delta = PARRY.distance(kRoot, myRoot)
    if not delta or delta < 0.05 then return true end
    local dir = nil
    pcall(function() dir = (myRoot.Position - kRoot.Position).Unit end)
    if not dir then return true end
    local look = nil
    pcall(function() look = kRoot.CFrame.LookVector end)
    if look and look:Dot(dir) > -0.1 then return true end
    return false
end

-- Gates cached at 5 Hz. Each GetAttribute measured ~606us here.
function PARRY.refreshGates()
    local now = os.clock()
    if now - PARRY.gate.at < 0.2 then return end
    PARRY.gate.at = now
    local ch = PARRY.myChar()
    if not ch then PARRY.gate.ok = false PARRY.gate.reason = "no character" return end

    local hum = nil
    pcall(function() hum = ch:FindFirstChildOfClass("Humanoid") end)
    local hmax, hp = nil, nil
    pcall(function() hmax = hum and hum.MaxHealth end)
    pcall(function() hp = hum and hum.Health end)
    if type(hmax) == "number" and hmax > 0 and type(hp) == "number"
        and hp < hmax * ((CFG.ppHealth or 50) / 100) then
        PARRY.gate.ok = false PARRY.gate.reason = "health too low" return
    end

    for i = 1, #PARRY.blocked do
        local v = nil
        pcall(function() v = ch:GetAttribute(PARRY.blocked[i]) end)
        if v == true then
            PARRY.gate.ok = false
            PARRY.gate.reason = "unavailable (" .. PARRY.blocked[i] .. ")"
            return
        end
    end

    local interact = nil
    pcall(function() interact = ch:FindFirstChild("CheckInterractable") end)
    if interact then
        for i = 1, #PARRY.actions do
            local v = nil
            pcall(function() v = interact:GetAttribute(PARRY.actions[i]) end)
            if v == true then PARRY.gate.ok = false PARRY.gate.reason = "waiting for action" return end
        end
    end

    if not PARRY.dagger() then PARRY.gate.ok = false PARRY.gate.reason = "no dagger" return end

    PARRY.gate.ok = true
    PARRY.gate.reason = "ready"
end

function PARRY.press(reason, distance)
    if not running or not CFG.pp then return false end
    PARRY.refreshGates()
    if not PARRY.gate.ok then
        PARRY.state = PARRY.gate.reason
        PARRY.denied = PARRY.gate.reason
        return false
    end

    local now = os.clock()
    if now - PARRY.lastPress < (CFG.ppInterval or 0.45) then
        PARRY.denied = "press interval"
        return false
    end

    PARRY.lastPress = now
    PARRY.denied = nil
    PARRY.presses = PARRY.presses + 1
    PARRY.reason = reason
    PARRY.state = "pressed: " .. tostring(reason)

    -- Click first: the swing's lead is the budget, not a dagger re-equip.
    pcall(function() setrobloxinput(true) end)
    if type(mouse2click) == "function" then pcall(mouse2click) end

    if CFG.ppEquip then task.spawn(PARRY.equip) end

    -- The game's own "the parry connected" flag, 350 ms later.
    task.spawn(function()
        task.wait(0.35)
        local ch = PARRY.myChar()
        if not ch then return end
        local lands = nil
        pcall(function() lands = ch:GetAttribute("ParryLands") end)
        if lands == 1 or lands == true then
            PARRY.lands = PARRY.lands + 1
            PARRY.state = "parried"
        end
    end)
    return true
end

function PARRY.collect(now)
    local fresh = {}
    local mine = PARRY.myChar()
    local ok, kids = pcall(function() return Workspace:GetChildren() end)
    if ok and type(kids) == "table" then
        for i = 1, #kids do
            local model = kids[i]
            if model.ClassName == "Model" and not PARRY.same(model, mine) then
                local root = nil
                pcall(function() root = model:FindFirstChild("HumanoidRootPart") end)
                local hum = nil
                pcall(function() hum = model:FindFirstChildOfClass("Humanoid") end)
                if root and hum then
                    local killer = false
                    for j = 1, #PP_KILLER_ATTRS do
                        local v = nil
                        pcall(function() v = model:GetAttribute(PP_KILLER_ATTRS[j]) end)
                        if v ~= nil then killer = true break end
                    end
                    if killer then
                        local key = PARRY.addr(model)
                        local t = PARRY.targets[key]
                        if not t then
                            t = { char = model }
                            PARRY.targets[key] = t
                        end
                        t.char = model
                        t.root = root
                        t.interact = model:FindFirstChild("CheckInterractable")
                        fresh[key] = true
                    end
                end
            end
        end
    end
    for key, t in pairs(PARRY.targets) do
        local alive = false
        pcall(function() alive = t.char ~= nil and t.char.Parent ~= nil end)
        if not fresh[key] or not alive then PARRY.targets[key] = nil end
    end
end

-- The trigger. AC_AllowedSpeed in 20..40 is the swing; the stab flag follows
-- it by a poll and waiting for it only burns lead.
function PARRY.windup(t, distance, myRoot)
    local stab, allowed = nil, nil
    pcall(function() stab = t.char:GetAttribute("LowerBodyStabilize") end)
    pcall(function() allowed = t.char:GetAttribute("AC_AllowedSpeed") end)

    local active = type(allowed) == "number" and allowed >= 20 and allowed <= 40
    if not active then
        t.windupFired = false
        return
    end
    if t.windupFired then return end
    if distance > PARRY.range() then return end
    if CFG.ppFacing and t.root and myRoot and not PARRY.facing(t.root, myRoot) then return end

    t.windupFired = true
    if CFG.ppAim and t.root then
        task.spawn(function()
            local cam = nil
            pcall(function() cam = Workspace.CurrentCamera end)
            if not cam then return end
            local pos, target = nil, nil
            pcall(function() pos = cam.CFrame.Position end)
            pcall(function() target = t.root.Position end)
            if pos and target then pcall(function() cam.CFrame = CFrame.new(pos, target) end) end
        end)
    end
    PARRY.press("windup", distance)
end

function PARRY.step()
    if not CFG.pp then PARRY.state = "Disabled" return end
    local now = os.clock()
    if now >= PARRY.lastCollect + 1 then
        PARRY.lastCollect = now
        PARRY.collect(now)
    end

    -- keep the status honest even when no swing is happening
    pcall(PARRY.refreshGates)

    local windupDue = CFG.ppWindup and now >= PARRY.lastWindup + 1 / (CFG.ppWindupHz or 120)
    if windupDue then PARRY.lastWindup = now end

    local myRoot = PARRY.myRoot()
    local hadPress = PARRY.presses
    for _, t in pairs(PARRY.targets) do
        local live = false
        pcall(function() live = t.root ~= nil and t.root.Parent ~= nil end)
        if live and myRoot then
            local distance = PARRY.distance(t.root, myRoot)
            if distance and distance <= (CFG.ppScanRange or 70) then
                PARRY.scans = PARRY.scans + 1
                if windupDue then
                    local ok, err = pcall(PARRY.windup, t, distance, myRoot)
                    if not ok then PARRY.error = tostring(err) end
                end
            end
        end
    end

    if PARRY.presses == hadPress and PARRY.state ~= "parried" then
        if not myRoot then
            PARRY.state = "waiting for character"
        elseif PARRY.gate.ok or PARRY.denied == nil then
            PARRY.state = "watching"
        else
            PARRY.state = PARRY.denied or "watching"
        end
    end
end

task.spawn(function()
    while running do
        if CFG.pp then
            local ok, err = pcall(PARRY.step)
            if not ok then
                PARRY.state = "read error"
                PARRY.error = tostring(err)
            end
        end
        task.wait(1 / (CFG.ppHz or 120))
    end
end)

task.spawn(function()
    while running do
        if CFG.pp and CFG.ppEquip then
            local myRoot = PARRY.myRoot()
            if myRoot then
                for _, t in pairs(PARRY.targets) do
                    local d = PARRY.distance(t.root, myRoot)
                    if d and d <= (CFG.ppEquipRange or 45) then
                        PARRY.equip()
                        break
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)

function API.ParryStatus()
    local n = 0
    for _ in pairs(PARRY.targets) do n = n + 1 end
    return {
        enabled = CFG.pp, state = PARRY.state, presses = PARRY.presses,
        lands = PARRY.lands, scans = PARRY.scans, targets = n,
        denied = PARRY.denied, reason = PARRY.reason, error = PARRY.error,
        gate = PARRY.gate.reason,
    }
end
function API.SetParry(on)
    CFG.pp = on and true or false
    if not CFG.pp then PARRY.state = "Disabled" end
    return CFG.pp
end

-- measured content height per tab, plus the window height and how much of
-- the active tab is scrolled away. Used to check the layout fits.
function API.Layout()
    if not uiWindow then return {} end
    local w = uiWindow.w - uiWindow.sideW - 16
    local out = {}
    for _, tb in ipairs(uiWindow.tabs) do
        out[#out + 1] = { name = tb.name, h = tb:Measure(w) }
    end
    return out, uiWindow.h, uiWindow.scrollMax
end
-- hud: killer timers, generators, survivors
HUD.lines, HUD.rows, HUD.count = {}, {}, 0
HUD.k = { attrs = {} }
HUD.order, HUD.perkList, HUD.cat = {}, {}, nil
HUD.perkSlots, HUD.perkUnknown = 0, 0
HUD.surv = {}
HUD.seed = { chunk = 1, cursor = 0, live = nil, forChar = nil }
HUD.survLive = { "Knocked", "IsHooked", "IsCarried" }
HUD.x, HUD.y, HUD.w = nil, nil, 262
HUD.drag, HUD.wasDown, HUD.shown = nil, false, false
HUD.lastPoll, HUD.lastDraw, HUD.lastFind = 0, 0, 0
HUD.findAt, HUD.perkAt, HUD.scanAt, HUD.survPollAt = 0, 0, 0, 0
HUD.genNext, HUD.lastError = 0, nil
HUD.pollMs, HUD.drawMs = 0, 0
HUD.cReady = Color3.fromRGB(80, 255, 120)
HUD.cCool = Color3.fromRGB(255, 170, 60)
HUD.cWarn = Color3.fromRGB(255, 110, 110)
HUD.cDim = Color3.fromRGB(170, 170, 170)
HUD.cText = Color3.fromRGB(230, 230, 230)
HUD.cTitle = Color3.fromRGB(255, 255, 255)

HUD.abilities = {
    Slasher = {
        { attr = "LakeMist", label = "Invis", active = 13, cooldown = 60 },
        { attr = "Pursuit", label = "Rage", active = 20, cooldown = 80 },
    },
    Veil = {
        { attr = "Spears", label = "Spears", counter = true, recharge = 15 },
        { attr = "special", label = "Charge", readyFlag = true, cooldown = 30 },
    },
}

HUD.plain = {
    BloodLust = true, IsStunned = true, Immobile = true,
    IsCarrying = true, IsChasing = true, spearmode = true,
}

HUD.always = { BloodLust = true, TerrorRadius = true }

HUD.skip = {
    ChaseTargetUserId = true, CarriedSurvivorId = true, Chasemusic = true,
    Suspense = true, ITEMINDEX = true, SuspenseRadius = true,
    nostun = true, overridelookscript = true, speedboost = true,
    swift = true, breakspeed = true,
}

HUD.baseline = {
    HookCount = true, HookedProgress = true, Knocked = true,
    speedboost = true, skillcheckspeed = true, IsRunning = true,
    Iframes = true, repairboost = true, healboost = true,
    unhookspeed = true, healnerf = true, bleedboost = true,
    vaultspeed = true, skillcheckfrequency = true, Sprinting = true,
    IsChased = true, chasereward = true, ChaseCount = true,
    repairing = true, Parry = true, RemainingCarryTime = true,
    HookProgressDepleting = true, HealProgress = true, Crouching = true,
    Crouchingserver = true, HealingPaused = true, isvaulting = true,
    vaultending = true, Untargettable = true, anticamp = true,
    IsCarried = true, nogui = true, IsHooked = true,
    overridelookscript = true, __VaultFireCount = true,
}

HUD.engine = {
    MaterialSounds = true, cutscene = true, Sound = true,
    ["Camera resetter"] = true, Animate = true, Lookscript = true,
    R6RagdollClient = true, Health = true, ["Animations-new"] = true,
    CheckInterractable = true, ["Skillcheck-gen"] = true,
    ["Skillcheck-player"] = true, ["Highlight-forsurvivor"] = true,
    heartbeat = true, Audioinit = true, SmoothCamera = true,
    ProgressBar = true, Lock = true, Firstperson = true, VMscript = true,
    carriedtransparency = true, Animations = true, voicemanager = true,
    ["Left Arm"] = true, ["Left Leg"] = true, ["Right Arm"] = true,
    ["Right Leg"] = true, Instinct = true, Killerost = true,
}

HUD.seed.fallback = {
    "special", "Spears", "spearmode", "BloodLust",
    "IsStunned", "Immobile", "IsCarrying",
}

HUD.genRate = function(t, prog, now)
    local base, at = t.hudBase, t.hudBaseAt
    if base and prog < base then
        t.hudRate, t.hudEta, t.hudEtaAt = nil, nil, nil
        t.hudBase, t.hudBaseAt = prog, now
        return
    end
    if not at then
        t.hudBase, t.hudBaseAt = prog, now
        return
    end
    if now - at >= 3 then
        local gained = prog - base
        if gained > 0 then
            local r = gained / (now - at)
            t.hudRate = t.hudRate and (t.hudRate * 0.5 + r * 0.5) or r
        elseif gained == 0 then
            t.hudRate = nil
        end
        t.hudBase, t.hudBaseAt = prog, now
    end
end

HUD.eta = function(t, now)
    local r = t.hudRate
    if not r or r <= 0.01 then
        t.hudEta, t.hudEtaAt = nil, nil
        return nil
    end
    local measured = (100 - (t.prog or 0)) / r
    if measured < 0 then measured = 0 end
    local shown = t.hudEta and (t.hudEta - (now - (t.hudEtaAt or now))) or nil
    if not shown or shown < 0 or math.abs(shown - measured) > 4 then
        t.hudEta, t.hudEtaAt = measured, now
        shown = measured
    end
    if shown < 0 then shown = 0 end
    return shown
end

HUD.where = function()
    local ch = lp.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if hrp then
        local ok, p = pcall(function() return hrp.Position end)
        if ok and p then return p.X, p.Y, p.Z end
    end
    local cam = Workspace.CurrentCamera
    if cam then
        local ok, cf = pcall(function() return cam.CFrame end)
        if ok and cf then return cf.Position.X, cf.Position.Y, cf.Position.Z end
    end
    return 0, 0, 0
end

HUD.learned = function(rec)
    local n = #rec.durations
    if n == 0 then return nil end
    local sorted = {}
    for i = 1, n do sorted[i] = rec.durations[i] end
    table.sort(sorted)
    local median = sorted[math.floor((n + 1) / 2)]
    return median, sorted[1], sorted[n], n
end

HUD.trackAttr = function(name, value, now)
    local rec = HUD.k.attrs[name]
    if not rec then
        rec = { value = value, since = now, durations = {}, peak = nil }
        if type(value) == "number" then rec.peak = value end
        HUD.k.attrs[name] = rec
        HUD.order[#HUD.order + 1] = name
        return
    end
    if type(value) == "number" and (rec.peak == nil or value > rec.peak) then
        rec.peak = value
    end
    if rec.value == value then return end
    local prev = rec.value
    rec.value = value
    rec.since = now
    rec.changes = (rec.changes or 0) + 1
    if HUD.plain[name] then return end
    local spent = (prev == true and value == false)
        or (type(value) == "number" and type(prev) == "number" and value < prev)
    local restored = (prev == false and value == true)
        or (type(value) == "number" and type(prev) == "number" and value > prev)
    if spent then
        rec.downAt = now
    elseif restored and rec.downAt then
        local d = now - rec.downAt
        rec.downAt = nil
        if d > 0.2 and d < 300 then
            rec.durations[#rec.durations + 1] = d
            if #rec.durations > 12 then table.remove(rec.durations, 1) end
            rec.lastDuration = d
        end
    end
end

HUD.trackAbility = function(spec, value, now)
    local rec = HUD.k.attrs[spec.attr]
    if not rec then
        rec = { value = value, since = now, durations = {}, spec = spec }
        if type(value) == "number" then rec.peak = value end
        HUD.k.attrs[spec.attr] = rec
        HUD.order[#HUD.order + 1] = spec.attr
        return
    end
    rec.spec = spec
    if type(value) == "number" and (rec.peak == nil or value > rec.peak) then
        rec.peak = value
    end
    if rec.value == value then return end
    local prev = rec.value
    rec.value = value
    rec.since = now

    if spec.counter then
        if type(value) == "number" and type(prev) == "number" then
            if value < prev then
                rec.downAt = now
            elseif value > prev then
                if rec.downAt then
                    local d = now - rec.downAt
                    if d > 0.2 and d < 300 then
                        rec.durations[#rec.durations + 1] = d
                        if #rec.durations > 12 then table.remove(rec.durations, 1) end
                    end
                end
                if rec.peak and value < rec.peak then
                    rec.downAt = now
                else
                    rec.downAt = nil
                end
            end
        end
        return
    end

    if spec.readyFlag then
        if prev == true and value == false then
            rec.activeUntil = nil
            if spec.cooldown then
                rec.readyAt = now + spec.cooldown
            else
                rec.downAt = now
            end
        elseif prev == false and value == true then
            rec.readyAt = nil
            rec.downAt = nil
        end
        return
    end

    if prev == false and value == true then
        rec.activeUntil = spec.active and (now + spec.active) or nil
        rec.readyAt = nil
        rec.downAt = nil
    elseif prev == true and value == false then
        rec.activeUntil = nil
        if spec.cooldown then
            rec.readyAt = now + spec.cooldown
        else
            rec.downAt = now
        end
    end
end

HUD.seedNames = function(char, now)
    if HUD.seed.forChar == char and HUD.seed.live
            and (now or 0) - (HUD.seed.readAt or 0) < 10 then
        return HUD.seed.live
    end
    local previous = (HUD.seed.forChar == char) and HUD.seed.live or nil
    HUD.seed.readAt = now or 0
    HUD.seed.forChar = char
    local ok, names = pcall(function() return char:GetAttributes() end)
    local list = {}
    if ok and type(names) == "table" then
        for _, n in pairs(names) do
            if type(n) == "string" and not HUD.skip[n] then
                list[#list + 1] = n
            end
        end
        table.sort(list)
    end
    if #list == 0 then
        for i = 1, #HUD.seed.fallback do list[i] = HUD.seed.fallback[i] end
    end
    if previous then
        local have = {}
        for i = 1, #list do have[list[i]] = true end
        for i = 1, #previous do
            if not have[previous[i]] then list[#list + 1] = previous[i] end
        end
        table.sort(list)
    end
    HUD.seed.live = list
    return list
end

HUD.findKiller = function(now)
    local K = HUD.k
    local ch = K.char
    if ch then
        local ok, live = pcall(function() return ch.Parent ~= nil end)
        if ok and live then
            if now - (HUD.perkAt or 0) > 10 then
                HUD.perkAt = now
                pcall(HUD.readPerks, ch)
            end
            return ch
        end
    end
    if now - HUD.lastFind < 2 then return nil end
    HUD.lastFind = now
    K.player, K.char, K.type = nil, nil, nil
    local okP, players = pcall(function() return Players:GetPlayers() end)
    if not okP or type(players) ~= "table" then players = {} end
    for _, plr in ipairs(players) do
        local ok, team = pcall(function() return plr.Team and plr.Team.Name end)
        if ok and team == "Killer" then
            K.player = plr
            K.char = plr.Character
            local okK, k = pcall(function() return plr:GetAttribute("SelectedKiller") end)
            K.type = okK and k or nil
            HUD.readPerks(K.char)
            break
        end
    end
    return K.char
end

HUD.pollKiller = function(now)
    local K = HUD.k
    local char = K.char
    if not char or (now - (HUD.findAt or 0)) >= 1 then
        HUD.findAt = now
        char = HUD.findKiller(now)
    end
    if not char then
        if #HUD.order > 0 then K.attrs, HUD.order = {}, {} end
        return
    end

    local known = K.type and HUD.abilities[K.type]

    if known then
        HUD.specCursor = (HUD.specCursor or 0) % #known + 1
        local spec = known[HUD.specCursor]
        local ok, v = pcall(function() return char:GetAttribute(spec.attr) end)
        if ok and v ~= nil and type(v) ~= "table" then
            HUD.trackAbility(spec, v, now)
        end
    end

    if known and now - (HUD.seedAt or 0) < 0.5 then return end
    HUD.seedAt = now

    local specFor = nil
    if known then
        specFor = {}
        for i = 1, #known do specFor[known[i].attr] = known[i] end
    end

    local names = HUD.seedNames(char, now)
    local n = #names
    if n == 0 then return end
    HUD.seed.cursor = HUD.seed.cursor % n + 1
    local name = names[HUD.seed.cursor]
    local ok, v = pcall(function() return char:GetAttribute(name) end)
    if ok and v ~= nil and type(v) ~= "table" then
        local spec = specFor and specFor[name]
        if spec then
            HUD.trackAbility(spec, v, now)
        else
            HUD.trackAttr(name, v, now)
        end
    end
end

HUD.perkNameFor = function(attr)
    if not HUD.cat then
        HUD.cat = {}
        local okF, folder = pcall(function()
            return game:GetService("ReplicatedStorage"):FindFirstChild("Perks")
        end)
        if okF and folder then
            local ok, kids = pcall(function() return folder:GetChildren() end)
            if ok and type(kids) == "table" then
                for i = 1, #kids do
                    local display = kids[i].Name
                    HUD.cat[lower(display):gsub("[^%a]", "")] = display
                end
            end
        end
    end
    local key = lower(attr):gsub("[^%a]", "")
    if HUD.cat[key] then return HUD.cat[key] end
    for k, display in pairs(HUD.cat) do
        if #k >= 6 and key:sub(1, #k) == k then return display end
    end
    return nil
end

HUD.readPerks = function(char)
    HUD.perkList = {}
    HUD.perkSlots, HUD.perkUnknown = 0, 0
    if not char then return end
    local ok, kids = pcall(function() return char:GetChildren() end)
    if not ok then return end

    local slots = 0
    for i = 1, #kids do
        local c = kids[i]
        if c.ClassName == "Script" or c.ClassName == "LocalScript" then
            local named = string.match(tostring(c.Name), "^(.-)%s+%d+$")
            local tierOnly = tonumber(c.Name) ~= nil
            if named and named ~= "" then
                slots = slots + 1
                HUD.perkList[#HUD.perkList + 1] = named
            elseif tierOnly then
                slots = slots + 1
            end
        end
    end

    local okA, names = pcall(function() return char:GetAttributes() end)
    if okA and type(names) == "table" then
        local seen = {}
        for i = 1, #HUD.perkList do seen[HUD.perkList[i]] = true end
        for _, n in pairs(names) do
            if type(n) == "string" and not HUD.baseline[n] then
                local display = HUD.perkNameFor(n)
                if display and not seen[display] then
                    seen[display] = true
                    HUD.perkList[#HUD.perkList + 1] = display
                end
            end
        end
    end

    HUD.perkSlots = slots
    HUD.perkUnknown = slots - #HUD.perkList
    if HUD.perkUnknown < 0 then HUD.perkUnknown = 0 end
end

HUD.scanSurvivor = function(plr)
    local char = plr.Character
    if not char then return nil end
    local e = { player = plr, name = plr.Name, char = char, perks = {}, state = {} }

    local okI, item = pcall(function() return plr:GetAttribute("EquippedItem") end)
    e.item = (okI and item) and tostring(item) or nil

    local ok, kids = pcall(function() return char:GetChildren() end)
    if ok and type(kids) == "table" then
        for i = 1, #kids do
            local c = kids[i]
            if c.ClassName == "Model" and c.Name ~= "Weapon" then
                e.item = c.Name
                break
            end
        end
    end

    local okN, names = pcall(function() return char:GetAttributes() end)
    if okN and type(names) == "table" then
        local seen = {}
        for _, n in pairs(names) do
            if type(n) == "string" and not HUD.baseline[n] then
                local display = HUD.perkNameFor(n)
                if display and not seen[display] then
                    seen[display] = true
                    e.perks[#e.perks + 1] = display
                end
            end
        end
    end

    local scripts = 0
    if ok and type(kids) == "table" then
        for i = 1, #kids do
            local c = kids[i]
            if (c.ClassName == "Script" or c.ClassName == "LocalScript")
                    and not HUD.engine[c.Name] then
                scripts = scripts + 1
            end
        end
    end
    e.perkScripts = scripts
    e.unknownPerks = scripts - #e.perks
    if e.unknownPerks < 0 then e.unknownPerks = 0 end
    return e
end

HUD.rescanSurvivors = function()
    HUD.surv = {}
    local okP, players = pcall(function() return Players:GetPlayers() end)
    if not okP or type(players) ~= "table" then players = {} end
    for _, plr in ipairs(players) do
        local ok, team = pcall(function() return plr.Team and plr.Team.Name end)
        if ok and team == "Survivors" then
            local e = HUD.scanSurvivor(plr)
            if e then HUD.surv[#HUD.surv + 1] = e end
        end
    end
end

HUD.pollSurvivors = function(now)
    for i = 1, #HUD.surv do
        local e = HUD.surv[i]
        local char = e.char
        if char then
            local okLive, live = pcall(function() return char.Parent ~= nil end)
            if okLive and live then
                for j = 1, #HUD.survLive do
                    local key = HUD.survLive[j]
                    local ok, v = pcall(function() return char:GetAttribute(key) end)
                    if ok then e.state[key] = v end
                end
            end
        end
    end
end

HUD.isKillerCached, HUD.isKillerAt = false, -100

HUD.localIsKiller = function()
    local now = os.clock()
    if now - HUD.isKillerAt < 2 then return HUD.isKillerCached end
    HUD.isKillerAt = now
    local team = nil
    pcall(function() team = lp.Team and lp.Team.Name end)
    HUD.isKillerCached = team == "Killer"
    return HUD.isKillerCached
end

HUD.renderGens = function(put, now)
    put("GENERATORS", HUD.cTitle)
    if #genList == 0 then
        put("  none", HUD.cDim)
        return
    end
    local px, py, pz = HUD.where()
    local list = {}
    for i = 1, #genList do
        local t = genList[i]
        if not t.hudId then
            HUD.genNext = HUD.genNext + 1
            t.hudId = HUD.genNext
        end
        if t.pos then
            local dx, dy, dz = t.pos.X - px, t.pos.Y - py, t.pos.Z - pz
            t.hudDist = math.floor(math.sqrt(dx * dx + dy * dy + dz * dz) + 0.5)
        else
            t.hudDist = 0
        end
        list[i] = t
    end
    table.sort(list, function(a, b)
        local pa, pb = math.floor(a.prog or 0), math.floor(b.prog or 0)
        if pa ~= pb then return pa > pb end
        if (a.hudDist or 0) ~= (b.hudDist or 0) then return (a.hudDist or 0) < (b.hudDist or 0) end
        return (a.hudId or 0) < (b.hudId or 0)
    end)

    for i = 1, #list do
        local t = list[i]
        local prog = math.floor(t.prog or 0)
        local crew = t.crew or 0
        local txt = string.format("%3d%%  %4dm", prog, t.hudDist or 0)
        if crew > 0 then txt = txt .. "  x" .. crew end
        local colour = HUD.cDim
        if prog >= 100 then
            colour = HUD.cReady
            txt = txt .. "  done"
        elseif t.state == "paused" then
            colour = HUD.cCool
        elseif crew > 0 then
            colour = HUD.cCool
            local left = HUD.eta(t, now)
            if left then txt = txt .. string.format("  %ds", math.floor(left + 0.5)) end
        elseif t.state == "regress" then
            colour = HUD.cWarn
        end
        put("  " .. txt, colour)
    end
end

HUD.renderTraps = function(put)
    put("BEAR TRAPS", HUD.cTitle)
    if #trapList == 0 then
        put("  none", HUD.cDim)
        return
    end
    local px, py, pz = HUD.where()
    local list = {}
    for i = 1, #trapList do
        local t = trapList[i]
        local dx, dy, dz = t.pos.X - px, t.pos.Y - py, t.pos.Z - pz
        t.hudDist = math.floor(math.sqrt(dx * dx + dy * dy + dz * dz) + 0.5)
        list[i] = t
    end
    table.sort(list, function(a, b)
        if a.hudDist ~= b.hudDist then return a.hudDist < b.hudDist end
        return (a.id or 0) < (b.id or 0)
    end)
    for i = 1, #list do
        local t = list[i]
        put("  " .. trapLabel(t, t.hudDist),
            (t.armed == false) and HUD.cWarn or HUD.cReady)
    end
end

HUD.renderSurvivors = function(put)
    put("SURVIVORS", HUD.cTitle)
    if #HUD.surv == 0 then
        put("  none", HUD.cDim)
        return
    end
    for i = 1, #HUD.surv do
        local e = HUD.surv[i]
        local st = e.state
        local tag, colour
        if st.IsHooked == true then
            tag, colour = "hooked", HUD.cReady
        elseif st.IsCarried == true then
            tag, colour = "carried", HUD.cReady
        elseif st.Knocked == true then
            tag, colour = "downed", HUD.cWarn
        else
            tag, colour = nil, HUD.cText
        end
        local head = e.name
        if e.item then head = head .. "  " .. e.item end
        if tag then head = head .. "  [" .. tag .. "]" end
        put(head, colour)
        if CFG.hudPerks then
            for j = 1, #e.perks do put("  " .. e.perks[j], HUD.cDim) end
            if (e.unknownPerks or 0) > 0 then
                put("  +" .. e.unknownPerks .. " unidentified", HUD.cDim)
            end
        end
    end
end

-- `...Until` attributes are absolute deadlines, but the game does not put them
-- all on one clock: Veil writes epoch seconds (os.time) while AC_* writes
-- os.clock seconds. Take whichever clock puts the deadline inside a believable
-- window, and fall back to the raw number when neither does (a counter, a flag
-- or a clock this build has not met yet).
HUD.untilLeft = function(name, value, now)
    if type(name) ~= "string" or name:sub(-5) ~= "Until" then return nil end
    if type(value) ~= "number" or value ~= value or value == math.huge then return nil end
    if value <= 0 then return 0 end
    local epoch = os.time()
    -- epoch seconds (and milliseconds) are unmistakable, so a long cooldown still
    -- reads out; everything else must land near a clock we can actually read, so
    -- a plain counter is never mistaken for a deadline
    if value > 1e12 then return value / 1000 - epoch end
    if value > 1e9 then return value - epoch end
    local left = value - now
    if left >= -3600 and left <= 3600 then return left end
    left = value / 1000 - now
    if left >= -3600 and left <= 3600 then return left end
    return nil
end

HUD.build = function(now)
    local L = HUD.lines
    local n = 0
    local function put(t, c)
        if n >= 44 then return end
        n = n + 1
        local e = L[n]
        if not e then e = {} L[n] = e end
        local s = tostring(t)
        if #s > 34 then s = s:sub(1, 32) .. ".." end
        e.t, e.c = s, c or HUD.cText
    end

    local K = HUD.k
    if K.char then
        put("KILLER  " .. tostring(K.type or "?")
            .. (K.player and ("  " .. K.player.Name) or ""), HUD.cTitle)
    else
        put("KILLER  not found", HUD.cDim)
    end

    if CFG.hudAbilities then
        for i = 1, #HUD.order do
            local name = HUD.order[i]
            local rec = K.attrs[name]
            local worth = (rec and rec.changes and rec.changes > 0)
                or HUD.always[name] or (rec and rec.spec ~= nil)
            if rec and worth and (CFG.hudState or not HUD.plain[name]) then
                local label, colour
                if HUD.plain[name] then
                    local v = rec.value
                    if v == true then
                        label, colour = name .. ": yes", HUD.cWarn
                    elseif v == false then
                        label, colour = name .. ": no", HUD.cDim
                    else
                        label = name .. ": " .. tostring(v)
                        colour = (type(v) == "number" and v > 0) and HUD.cWarn or HUD.cDim
                    end
                elseif rec.spec and rec.spec.counter then
                    local shown = rec.spec.label or name
                    local count = tostring(rec.value)
                        .. (rec.peak and ("/" .. tostring(rec.peak)) or "")
                    if rec.downAt then
                        local elapsed = now - rec.downAt
                        local median = rec.spec.recharge or HUD.learned(rec)
                        if median then
                            local left = median - elapsed
                            if left < 0 then left = 0 end
                            label = string.format("%s   %s   %.0fs", shown, count, left)
                        else
                            label = string.format("%s   %s   %.0fs", shown, count, elapsed)
                        end
                        colour = HUD.cCool
                    else
                        label = string.format("%s   %s", shown, count)
                        colour = HUD.cReady
                    end
                elseif rec.activeUntil then
                    local left = rec.activeUntil - now
                    if left <= 0 then
                        rec.activeUntil = nil
                        label = (rec.spec and rec.spec.label or name) .. "   active"
                        colour = HUD.cWarn
                    else
                        label = string.format("%s   ACTIVE %.1fs",
                            rec.spec and rec.spec.label or name, left)
                        colour = HUD.cWarn
                    end
                elseif rec.readyAt then
                    local left = rec.readyAt - now
                    if left <= 0 then
                        rec.readyAt = nil
                        label = (rec.spec and rec.spec.label or name) .. "   ready"
                        colour = HUD.cReady
                    else
                        label = string.format("%s   %.0fs",
                            rec.spec and rec.spec.label or name, left)
                        colour = HUD.cCool
                    end
                elseif rec.downAt then
                    local elapsed = now - rec.downAt
                    local median = HUD.learned(rec)
                    local shown = rec.spec and rec.spec.label or name
                    if median then
                        local left = median - elapsed
                        if left < 0 then left = 0 end
                        label = string.format("%s   %.1fs", shown, left)
                        colour = HUD.cCool
                    else
                        label = string.format("%s   %s", shown, tostring(rec.value))
                        colour = HUD.cDim
                    end
                else
                    local shown = rec.spec and rec.spec.label or name
                    if rec.spec and rec.spec.readyFlag and rec.value == false then
                        label, colour = shown .. "   on cooldown", HUD.cCool
                    elseif type(rec.value) == "number" then
                        local left = HUD.untilLeft(name, rec.value, now)
                        if left then
                            if left <= 0 then
                                label, colour = shown .. "   ready", HUD.cReady
                            elseif left >= 10 then
                                label, colour = string.format("%s   %.0fs", shown, left), HUD.cCool
                            else
                                label, colour = string.format("%s   %.1fs", shown, left), HUD.cCool
                            end
                        else
                            local suffix = ""
                            if rec.peak and rec.peak ~= rec.value then
                                suffix = "/" .. tostring(rec.peak)
                            end
                            label = shown .. "   " .. tostring(rec.value) .. suffix
                            colour = HUD.cReady
                        end
                    else
                        label, colour = shown .. "   ready", HUD.cReady
                    end
                end
                put(label, colour)
            end
        end
    end

    if CFG.hudPerks and ((HUD.perkSlots or 0) > 0 or #HUD.perkList > 0) then
        put("PERKS", HUD.cTitle)
        for i = 1, #HUD.perkList do
            put("  " .. HUD.perkList[i], HUD.cDim)
        end
        if (HUD.perkUnknown or 0) > 0 then
            put("  +" .. HUD.perkUnknown .. " unnamed", HUD.cDim)
        end
    end

    if CFG.hudGens then
        put(" ", HUD.cDim)
        HUD.renderGens(put, now)
    end

    if CFG.hudTraps then
        put(" ", HUD.cDim)
        HUD.renderTraps(put)
    end

    if CFG.hudSurvivors and HUD.localIsKiller() then
        put(" ", HUD.cDim)
        HUD.renderSurvivors(put)
    end

    for i = n + 1, #L do L[i] = nil end
    HUD.lineCount = n
    -- keep every line inside the panel and the rows tall enough for the font
    local _, glyphH = HUD.measure("Ag")
    if glyphH > 0 then
        local pitch = math.max(16, math.ceil(glyphH) + 3)
        if pitch > 24 then pitch = 24 end
        if HUD.lineH ~= pitch then HUD.lineH = pitch end
    end
    local maxw = HUD.w - 20
    for i = 1, n do
        local e = L[i]
        if #e.t > 0 and HUD.measure(e.t) > maxw then
            e.t = HUD.fit(e.t, maxw)
        end
    end
end

HUD.obj = function(kind, z)
    local ok, d = pcall(Drawing.new, kind)
    if not ok or not d then return nil end
    pcall(function() d.Visible = false; d.ZIndex = z end)
    return d
end

-- measure HUD text with its real font so lines are clipped to the panel and
-- the row pitch matches the glyph height (16 px pitch on a 17 px glyph made
-- every line sit on top of the one below it)
HUD.measure = function(s)
    local m = HUD.meas
    if not m then
        m = HUD.obj("Text", 0)
        if not m then return 0, 0 end
        m.Size = 13
        pcall(function() m.Font = FONT end)
        HUD.meas = m
    end
    m.Text = tostring(s)
    local b = m.TextBounds
    return (b and b.X) or (#tostring(s) * 8), (b and b.Y) or 16
end

HUD.fit = function(s, maxw)
    s = tostring(s)
    if maxw <= 8 then return "" end
    local w = HUD.measure(s)
    if w <= maxw then return s end
    while #s > 1 do
        s = s:sub(1, #s - 1)
        local cand = s .. ".."
        if HUD.measure(cand) <= maxw then return cand end
    end
    return ""
end

HUD.hide = function()
    if not HUD.bg then return end
    HUD.bg.Visible = false
    HUD.border.Visible = false
    HUD.accent.Visible = false
    HUD.title.Visible = false
    if HUD.close then HUD.close.Visible = false end
    for _, r in ipairs(HUD.rows) do r.t.Visible = false end
    HUD.shown = false
end

HUD.destroy = function()
    if HUD.bg then pcall(function() HUD.bg:Remove() end) end
    if HUD.border then pcall(function() HUD.border:Remove() end) end
    if HUD.accent then pcall(function() HUD.accent:Remove() end) end
    if HUD.title then pcall(function() HUD.title:Remove() end) end
    if HUD.close then pcall(function() HUD.close:Remove() end) end
    for _, r in ipairs(HUD.rows) do pcall(function() r.t:Remove() end) end
    if HUD.meas then pcall(function() HUD.meas:Remove() end) HUD.meas = nil end
    HUD.bg, HUD.border, HUD.accent, HUD.title, HUD.close = nil, nil, nil, nil, nil
    HUD.rows, HUD.shown, HUD.count = {}, false, 0
    HUD.gx, HUD.gy, HUD.gw, HUD.gh = nil, nil, nil, nil
end

HUD.ensure = function()
    if HUD.bg then return true end
    local ok = pcall(function()
        HUD.bg = HUD.obj("Square", 45)
        HUD.bg.Filled = true
        HUD.bg.Corner = 4
        HUD.border = HUD.obj("Square", 46)
        HUD.border.Filled = false
        HUD.border.Thickness = 1
        HUD.border.Corner = 4
        HUD.accent = HUD.obj("Square", 47)
        HUD.accent.Filled = true
        HUD.title = HUD.obj("Text", 48)
        HUD.title.Text = "HUD"
        HUD.title.Size = 14
        HUD.title.Font = FONT
        HUD.title.Outline = false
        HUD.title.Transparency = 1
        HUD.close = HUD.obj("Text", 49)
        HUD.close.Text = "x"
        HUD.close.Size = 14
        HUD.close.Font = FONT
        HUD.close.Outline = false
        HUD.close.Transparency = 1
    end)
    if not ok or not HUD.bg then
        HUD.destroy()
        return false
    end
    return true
end

HUD.row = function(i)
    local r = HUD.rows[i]
    if r then return r end
    local t = HUD.obj("Text", 48)
    if not t then return nil end
    t.Size, t.Font, t.Outline = 13, FONT, false
    t.Transparency = 1
    r = { t = t }
    HUD.rows[i] = r
    return r
end

HUD.setEnabled = function(on)
    on = on and true or false
    local el = HUD.toggleEl
    if el then
        if el.value ~= on then el:SetValue(on) end
        for _, a in ipairs(el.addons or {}) do
            if a.kind == "KeyPicker" then a.state = on end
        end
    end
    CFG.hud = on
    if not on then HUD.hide() end
    return CFG.hud
end

HUD.render = function(now, moveOnly)
    if not CFG.hud or not running then
        if HUD.shown then HUD.hide() end
        return
    end
    if not moveOnly then HUD.build(now) end
    if not HUD.ensure() then return end

    local lines = HUD.lines
    local n = #lines
    if n == 0 then if HUD.shown then HUD.hide() end return end

    local w = HUD.w
    local pitch = HUD.lineH or 16
    local h = 26 + n * pitch + 6
    local cam = Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize
    local vw, vh = (vp and vp.X) or 1920, (vp and vp.Y) or 1080
    if not HUD.x then
        HUD.x, HUD.y = vw - w - 12, 44
    end

    local x, y = HUD.x, HUD.y
    local mx, my, down, rdown
    pcall(function() mx, my = mouse.X, mouse.Y end)
    pcall(function() down = ismouse1pressed() == true end)
    pcall(function() rdown = ismouse2pressed() == true end)

    local closeX, closeY = x + w - 20, y + 5
    local over = mx and mx >= x and mx <= x + w and my >= y and my <= y + h
    local overClose = mx and mx >= closeX and mx <= closeX + 14 and my >= closeY and my <= closeY + 14

    if mx and down and not HUD.wasDown then
        if overClose then
            HUD.wasDown = true
            HUD.setEnabled(false)
            return
        elseif over then
            HUD.drag = { mx - x, my - y }
        end
    end
    if not down then HUD.drag = nil end
    if HUD.drag and mx then
        x = math.clamp(mx - HUD.drag[1], 0, vw - w)
        y = math.clamp(my - HUD.drag[2], 0, vh - 40)
        HUD.x, HUD.y = x, y
    end
    HUD.wasDown = down == true

    if over and rdown and not HUD.wasRight then
        HUD.wasRight = true
        HUD.setEnabled(false)
        return
    end
    HUD.wasRight = rdown == true

    local bgAlpha = 1 - math.clamp(CFG.hudAlpha or 0, 0, 100) / 100

    local L = UI
    local theme = (L and L.Theme) or {}
    local cBg = theme.bg or Color3.fromRGB(15, 15, 15)
    local cLine = theme.outline or Color3.fromRGB(40, 40, 40)
    local cAcc = theme.accent or Color3.fromRGB(124, 92, 255)
    local cTxt = theme.text or Color3.fromRGB(255, 255, 255)

    if HUD.gx ~= x or HUD.gy ~= y or HUD.gw ~= w or HUD.gh ~= h then
        HUD.bg.Position = Vector2.new(x, y)
        HUD.bg.Size = Vector2.new(w, h)
        HUD.border.Position = Vector2.new(x, y)
        HUD.border.Size = Vector2.new(w, h)
        HUD.accent.Position = Vector2.new(x + 1, y + 24)
        HUD.accent.Size = Vector2.new(w - 2, 1)
        HUD.title.Position = Vector2.new(x + 10, y + 4)
        HUD.close.Position = Vector2.new(x + w - 18, y + 3)
        HUD.gx, HUD.gy, HUD.gw, HUD.gh = x, y, w, h
    end

    if HUD.cBg ~= cBg or HUD.aBg ~= bgAlpha then
        HUD.bg.Color = cBg
        HUD.bg.Transparency = bgAlpha * 0.96
        HUD.cBg, HUD.aBg = cBg, bgAlpha
    end
    if HUD.cLine ~= cLine then HUD.border.Color = cLine HUD.cLine = cLine end
    if HUD.cAcc ~= cAcc then HUD.accent.Color = cAcc HUD.cAcc = cAcc end
    if HUD.cTxt ~= cTxt then HUD.title.Color = cTxt HUD.cTxt = cTxt end
    if HUD.aChrome ~= bgAlpha then
        HUD.border.Transparency = bgAlpha
        HUD.accent.Transparency = bgAlpha
        HUD.aChrome = bgAlpha
    end

    local cClose = overClose and cAcc or cLine
    if HUD.cClose ~= cClose then HUD.close.Color = cClose HUD.cClose = cClose end

    if not HUD.shown then
        HUD.bg.Visible = true
        HUD.border.Visible = true
        HUD.accent.Visible = true
        HUD.title.Visible = true
        HUD.close.Visible = true
        HUD.shown = true
    end

    for i = 1, n do
        local r = HUD.row(i)
        local d = lines[i]
        if r and d then
            if r.text ~= d.t then
                r.t.Text = d.t
                r.text = d.t
            end
            if r.colour ~= d.c then
                r.t.Color = d.c
                r.colour = d.c
            end
            local rx, ry = x + 10, y + 28 + (i - 1) * pitch
            if r.rx ~= rx or r.ry ~= ry then
                r.t.Position = Vector2.new(rx, ry)
                r.rx, r.ry = rx, ry
            end
            if not r.t.Visible then r.t.Visible = true end
        end
    end
    for i = n + 1, #HUD.rows do
        local r = HUD.rows[i]
        if r.t.Visible then r.t.Visible = false end
    end
    HUD.count = n
end

HUD.tick = function()
    if not CFG.hud then
        if HUD.shown then HUD.hide() end
        return
    end
    local now = os.clock()
    local every = (HUD.k.type and HUD.abilities[HUD.k.type]) and 0.2 or 0.1
    if now - HUD.lastPoll >= every then
        HUD.lastPoll = now
        local t0 = os.clock()
        pcall(HUD.pollKiller, now)
        HUD.pollMs = HUD.pollMs * 0.9 + (os.clock() - t0) * 1000 * 0.1
    end
    if CFG.hudSurvivors and HUD.localIsKiller() then
        if now - HUD.scanAt >= 8 then
            HUD.scanAt = now
            local t0 = os.clock()
            pcall(HUD.rescanSurvivors)
            HUD.pollMs = HUD.pollMs * 0.9 + (os.clock() - t0) * 1000 * 0.1
        end
        if now - HUD.survPollAt >= 2 then
            HUD.survPollAt = now
            local t0 = os.clock()
            pcall(HUD.pollSurvivors, now)
            HUD.pollMs = HUD.pollMs * 0.9 + (os.clock() - t0) * 1000 * 0.1
        end
    end
    local moving = HUD.drag ~= nil
    if moving or now - HUD.lastDraw >= 1 / 8 then
        HUD.lastDraw = now
        local t0 = os.clock()
        pcall(HUD.render, now, moving)
        HUD.drawMs = HUD.drawMs * 0.9 + (os.clock() - t0) * 1000 * 0.1
    end
end

task.spawn(function()
    -- a reload replaces __SWANGY_LOAD: a stale instance must stop drawing so
    -- two panels can never stack their text on top of each other
    while running and _G.__SWANGY_LOAD == loadToken do
        local ok, err = pcall(HUD.tick)
        if not ok then HUD.lastError = tostring(err) end
        task.wait(ok and (HUD.drag and 1 / 60 or (CFG.hud and 0.08 or 0.25)) or 0.5)
    end
    pcall(HUD.destroy)
end)

API.hud = {}
function API.hud.SetEnabled(on)
    return HUD.setEnabled(on)
end
function API.hud.Toggle() return API.hud.SetEnabled(not CFG.hud) end
function API.hud.SetTransparency(v)
    CFG.hudAlpha = math.clamp(tonumber(v) or 0, 0, 100)
    return CFG.hudAlpha
end
function API.hud.Lines()
    local out = {}
    for i = 1, #HUD.lines do out[i] = HUD.lines[i].t end
    return out
end
function API.hud.Rows()
    local out = {}
    for i = 1, #HUD.rows do
        local r = HUD.rows[i]
        local t = r and r.t
        local p = t and t.Position
        out[i] = {
            text = t and t.Text or nil,
            x = p and math.floor(p.X + 0.5) or nil,
            y = p and math.floor(p.Y + 0.5) or nil,
            visible = t and t.Visible or false,
            size = t and t.Size or nil,
        }
    end
    return out, HUD.x, HUD.y, HUD.w
end
function API.hud.Panel()
    return {
        shown = HUD.shown, x = HUD.x, y = HUD.y, w = HUD.w,
        visible = HUD.bg and HUD.bg.Visible or false,
        rows = #HUD.rows,
        bg = HUD.bg and HUD.bg.Transparency or nil,
        title = HUD.title and HUD.title.Text or nil,
        textAlpha = HUD.rows[1] and HUD.rows[1].t.Transparency or nil,
    }
end
function API.hud.Stats()
    return {
        lines = HUD.count,
        killer = HUD.k and HUD.k.type or nil,
        gens = #genList,
        traps = #trapList,
        survivors = #HUD.surv,
        perkSlots = HUD.perkSlots,
        alpha = CFG.hudAlpha,
        drawMs = HUD.drawMs,
        pollMs = HUD.pollMs,
        error = HUD.lastError,
    }
end

-- keybind window
local kbw = {
    x = 12, y = 44, w = 230, h = 0,
    rows = {}, drag = nil, wasDown = false, shown = false,
}

local function kbwNew(kind, z)
    local ok, d = pcall(Drawing.new, kind)
    if not ok or not d then return nil end
    pcall(function() d.Visible = false; d.ZIndex = z end)
    return d
end

local function kbwHide()
    if not kbw.bg then return end
    kbw.bg.Visible = false
    kbw.border.Visible = false
    kbw.accent.Visible = false
    kbw.title.Visible = false
    for _, r in ipairs(kbw.rows) do
        r.name.Visible = false
        r.key.Visible = false
    end
    kbw.shown = false
end

kbwDestroy = function()
    if kbw.bg then pcall(function() kbw.bg:Remove() end) end
    if kbw.border then pcall(function() kbw.border:Remove() end) end
    if kbw.accent then pcall(function() kbw.accent:Remove() end) end
    if kbw.title then pcall(function() kbw.title:Remove() end) end
    for _, r in ipairs(kbw.rows) do
        pcall(function() r.name:Remove() end)
        pcall(function() r.key:Remove() end)
    end
    kbw.bg, kbw.border, kbw.accent, kbw.title = nil, nil, nil, nil
    kbw.rows, kbw.shown = {}, false
    kbw.gx, kbw.gy, kbw.gw, kbw.gh = nil, nil, nil, nil
end

local function kbwEnsure()
    if kbw.bg then return true end
    local ok = pcall(function()
        kbw.bg = kbwNew("Square", 55)
        kbw.bg.Filled = true
        kbw.bg.Corner = 4
        kbw.bg.Transparency = 1
        kbw.border = kbwNew("Square", 56)
        kbw.border.Filled = false
        kbw.border.Thickness = 1
        kbw.border.Corner = 4
        kbw.border.Transparency = 1
        kbw.accent = kbwNew("Square", 57)
        kbw.accent.Filled = true
        kbw.accent.Transparency = 0.85
        kbw.title = kbwNew("Text", 58)
        kbw.title.Text = "Keybinds"
        kbw.title.Size = 14
        kbw.title.Font = FONT
        kbw.title.Outline = false
        kbw.title.Transparency = 1
    end)
    if not ok or not kbw.bg then
        kbwDestroy()
        return false
    end
    return true
end

local function kbwRow(i)
    local r = kbw.rows[i]
    if r then return r end
    local name, key = kbwNew("Text", 58), kbwNew("Text", 58)
    if not name or not key then return nil end
    name.Size, name.Font, name.Outline = 13, FONT, false
    key.Size, key.Font, key.Outline = 12, FONT, false
    name.Transparency, key.Transparency = 1, 1
    r = { name = name, key = key }
    kbw.rows[i] = r
    return r
end

local function kbwRender()
    local L = UI
    if not L then return end
    if not CFG.kbw or not running then
        if kbw.shown then kbwHide() end
        return
    end
    if not kbwEnsure() then return end

    local list = {}
    for _, el in ipairs(L.__keybinds or {}) do
        if el.vk or el.mode == "Always" then
            local p = el.syncParent
            local on
            if el.mode == "Always" then on = true
            elseif p then on = p.value == true
            else on = el.state == true end
            list[#list + 1] = {
                name = tostring((p and p.text) or el.text or "Feature"),
                key = el.vk and ("[" .. tostring(L.__vkName and L.__vkName(el.vk) or el.vk) .. "]") or "[Always]",
                on = on,
            }
        end
    end
    if #list == 0 then
        list[1] = { name = "No keybinds set", key = "", on = false }
    end

    local rows = #list
    local w = kbw.w
    local h = 26 + rows * 18 + 6
    local x, y = kbw.x, kbw.y

    local mx, my, down
    pcall(function() mx, my = mouse.X, mouse.Y end)
    pcall(function() down = ismouse1pressed() == true end)
    if mx then
        if down and not kbw.wasDown and mx >= x and mx <= x + w and my >= y and my <= y + 24 then
            kbw.drag = { mx - x, my - y }
        end
        if not down then kbw.drag = nil end
        if kbw.drag then
            local cam = Workspace.CurrentCamera
            local vp = cam and cam.ViewportSize
            x = math.clamp(mx - kbw.drag[1], 0, (vp and vp.X or 1920) - w)
            y = math.clamp(my - kbw.drag[2], 0, (vp and vp.Y or 1080) - h)
            kbw.x, kbw.y = x, y
        end
    end
    kbw.wasDown = down == true

    local theme = L.Theme or {}
    local cBg = theme.bg or Color3.fromRGB(15, 15, 15)
    local cLine = theme.outline or Color3.fromRGB(40, 40, 40)
    local cAccent = theme.accent or Color3.fromRGB(125, 85, 255)
    local cOn = theme.text or Color3.fromRGB(255, 255, 255)
    local cOff = theme.subtext or Color3.fromRGB(130, 130, 130)

    if kbw.gx ~= x or kbw.gy ~= y or kbw.gw ~= w or kbw.gh ~= h then
        kbw.bg.Position = Vector2.new(x, y)
        kbw.bg.Size = Vector2.new(w, h)
        kbw.border.Position = Vector2.new(x, y)
        kbw.border.Size = Vector2.new(w, h)
        kbw.accent.Position = Vector2.new(x + 1, y + 24)
        kbw.accent.Size = Vector2.new(w - 2, 1)
        kbw.title.Position = Vector2.new(x + 10, y + 4)
        kbw.gx, kbw.gy, kbw.gw, kbw.gh = x, y, w, h
    end
    if kbw.cBg ~= cBg then kbw.bg.Color = cBg; kbw.cBg = cBg end
    if kbw.cLine ~= cLine then kbw.border.Color = cLine; kbw.cLine = cLine end
    if kbw.cAccent ~= cAccent then
        kbw.accent.Color = cAccent
        kbw.cAccent = cAccent
    end
    if kbw.cOn ~= cOn then
        kbw.title.Color = cOn
        kbw.cOn = cOn
    end
    if kbw.cRowOn ~= cOn or kbw.cRowOff ~= cOff then
        kbw.cRowOn, kbw.cRowOff = cOn, cOff
        for i = 1, #kbw.rows do kbw.rows[i].on = nil end
    end

    if not kbw.shown then
        kbw.bg.Visible = true
        kbw.border.Visible = true
        kbw.accent.Visible = true
        kbw.title.Visible = true
        kbw.shown = true
    end

    for i = 1, rows do
        local r = kbwRow(i)
        local d = list[i]
        if r and d then
            local nm = d.name
            if #nm > 17 then nm = nm:sub(1, 15) .. "..." end
            if r.n ~= nm then r.name.Text = nm; r.n = nm end
            if r.k ~= d.key then r.key.Text = d.key; r.k = d.key end
            local rx, ry = x + 10, y + 28 + (i - 1) * 18
            if r.x ~= rx or r.y ~= ry then
                r.name.Position = Vector2.new(rx, ry)
                r.key.Position = Vector2.new(x + 148, ry + 1)
                r.x, r.y = rx, ry
            end
            if r.on ~= d.on then
                local c = d.on and cOn or cOff
                r.name.Color = c
                r.key.Color = c
                r.on = d.on
            end
            if not r.name.Visible then
                r.name.Visible = true
                r.key.Visible = true
            end
        end
    end
    for i = rows + 1, #kbw.rows do
        local r = kbw.rows[i]
        if r.name.Visible then
            r.name.Visible = false
            r.key.Visible = false
        end
    end
end

task.spawn(function()
    while running do
        local ok = pcall(kbwRender)
        task.wait(ok and (kbw.drag and 1 / 60 or 1 / 20) or 0.5)
    end
    pcall(kbwDestroy)
end)

-- ui: swangy by aphalia
local UI_EMBEDDED = {
    ["Library.lua"] = [=====[
-- Swangy: a Drawing UI library for Matcha (Obsidian-compatible look and API).
-- Matcha has no Instance.new/ScreenGui, so this renders with Drawing + polling input.
-- Scheme/metrics are taken from Obsidian's Library.lua defaults.
--
-- Load (top-level returns are dropped in Matcha):
--   local _ = loadstring(readfile("Library.lua"))()
--   local Library = _G.Swangy

local Library = {
    Version = "1.3.2",
    Options = {},
    Toggles = {},
    Sliders = {},
    Buttons = {},
    Dropdowns = {},
    ColorPickers = {},
    KeyPickers = {},
    Labels = {},
    ForceCheckbox = false,
    NotifySide = "Right",
    NotificationOptions = {
        Enabled = true,
        Duration = 4,
        Fade = 0.35,
        Width = 260,
        MaxVisible = 6,
        OffsetY = 16,
        Spacing = 6,
        UseCallDuration = false,
    },
}
-- Tear down any previous Swangy instance and its raw watermark drawings so
-- reloading cannot leave an immovable duplicate box behind.
do
    for _, key in ipairs({ "Swangy", "Obsidian" }) do
        local L = _G[key]
        if L and L.__wm then
            pcall(function() L.__wm.bg:Remove() end)
            pcall(function() L.__wm.txt:Remove() end)
            L.__wm = nil
        end
    end
    local prev = _G.__swangy_instances
    if prev then
        for _, inst in ipairs(prev) do
            pcall(function() inst:Unload() end)
        end
    end
    if _G.__swangy_wms then
        for _, w in ipairs(_G.__swangy_wms) do
            pcall(function() w.bg:Remove() end)
            pcall(function() w.txt:Remove() end)
        end
    end
    _G.__swangy_wms = {}
    _G.__swangy_instances = {}
end

_G.Swangy = Library
_G.Obsidian = Library

Library.Animations = {
    Enabled = true,
    TabFade = 0.18,
    TabSlide = 18,
    Toggle = 16,
    Slider = 20,
}

-- ui: helpers
local FRAME_DT = 1 / 60
local function approach(cur, target, speed, dt)
    if not Library.Animations.Enabled then return target end
    dt = dt or FRAME_DT
    if dt <= 0 then dt = 1 / 60 end
    return cur + (target - cur) * (1 - math.exp(-(speed or 15) * dt))
end

local function hostGet(name)
    local v
    pcall(function() v = getfenv(1)[name] end)
    if v == nil then pcall(function() v = _G[name] end) end
    return v
end

local D = hostGet("Drawing") or Drawing
local RS = hostGet("RunService") or RunService

-- this VM drops the `workspace` global and `Workspace.CurrentCamera`
-- intermittently; one nil camera used to kill the whole window frame
-- (Matcha:2091). Resolve it defensively and never index a nil workspace.
local function uiCamera()
    local c
    pcall(function() c = workspace.CurrentCamera end)
    if c then return c end
    local ok, ws = pcall(function() return game:GetService("Workspace") end)
    if ok and ws then pcall(function() c = ws.CurrentCamera end) end
    if c then return c end
    pcall(function() c = game.Workspace.CurrentCamera end)
    return c
end
local UIS = hostGet("UserInputService") or UserInputService
local floor, abs, min, max, clamp = math.floor, math.abs, math.min, math.max, math.clamp
local clock, fmt = os.clock, string.format
local rgb = Color3.fromRGB

-- Obsidian scheme -----------------------------------------------------------
local Theme = {
    bg = rgb(15, 15, 15),
    main = rgb(25, 25, 25),
    accent = rgb(125, 85, 255),
    outline = rgb(40, 40, 40),
    text = rgb(255, 255, 255),
    subtext = rgb(130, 130, 130),
    dim = rgb(160, 160, 160),
    danger = rgb(255, 50, 50),
    destructive = rgb(220, 38, 38),
    white = rgb(255, 255, 255),
    dark = rgb(0, 0, 0),
    disabled = rgb(95, 95, 95),
}
Theme.panel, Theme.panel2, Theme.stroke, Theme.strokeLit = Theme.bg, Theme.main, Theme.outline, rgb(58, 58, 58)
Theme.track, Theme.sidebar = Theme.main, Theme.bg
Library.Theme = Theme
Library.CornerRadius = 4

local FONT = (D.Fonts and (D.Fonts.Monospace or D.Fonts.SystemBold)) or 5

local function rgbToHsv(c)
    local r, g, b = c.R, c.G, c.B
    local mx = max(r, g, b)
    local mn = min(r, g, b)
    local d = mx - mn
    local h
    if d == 0 then
        h = 0
    elseif mx == r then
        h = ((g - b) / d) % 6
    elseif mx == g then
        h = (b - r) / d + 2
    else
        h = (r - g) / d + 4
    end
    h = h / 6
    local s = (mx == 0) and 0 or (d / mx)
    return h, s, mx
end

local function u16(n)
    return string.char(n % 256, floor(n / 256) % 256)
end
local function u32(n)
    return string.char(n % 256, floor(n / 256) % 256, floor(n / 65536) % 256, floor(n / 16777216) % 256)
end
local GRID_W, GRID_H = 64, 48
local function buildSVBmp(hue)
    local rows = {}
    for y = GRID_H - 1, 0, -1 do
        local v = 1 - y / (GRID_H - 1)
        local row = {}
        for x = 0, GRID_W - 1 do
            local s = x / (GRID_W - 1)
            local c = Color3.fromHSV(hue, s, v)
            row[#row + 1] = string.char(floor(c.B * 255 + 0.5), floor(c.G * 255 + 0.5), floor(c.R * 255 + 0.5))
        end
        local pad = (4 - (GRID_W * 3) % 4) % 4
        rows[#rows + 1] = table.concat(row) .. string.rep("\0", pad)
    end
    local pixels = table.concat(rows)
    local dib = u32(40) .. u32(GRID_W) .. u32(GRID_H) .. u16(1) .. u16(24) .. u32(0)
        .. u32(#pixels) .. u32(2835) .. u32(2835) .. u32(0) .. u32(0)
    return "BM" .. u32(14 + 40 + #pixels) .. u32(0) .. u32(54) .. dib .. pixels
end

local LOGO_D =
    "M161.0 225.0 L129.5 191.0 L0.0 336.2 L62.2 336.0Z " ..
    "M51.0 139.5 L20.5 174.2 L67.8 226.8 L98.5 192.2Z " ..
    "M284.5 121.0 L253.5 155.5 L301.0 208.2 L331.8 173.5Z " ..
    "M0.0 11.2 L67.2 86.8 L98.5 52.8 L61.5 11.0Z " ..
    "M352.0 11.0 L290.8 11.0 L176.0 138.8 L145.0 103.8 L175.8 69.5 L192.5 87.2 " ..
    "L223.2 52.5 L175.8 0.0 L82.8 103.5 L207.2 243.2 L176.8 278.0 L159.8 260.5 " ..
    "L129.0 294.8 L175.8 347.8 L269.2 244.0 L207.5 173.2Z"

local LOGO_SUBS, LOGO_MINX, LOGO_MINY, LOGO_MAXX, LOGO_MAXY = {}, math.huge, math.huge, -math.huge, -math.huge
do
    local function numbers(s)
        local t = {}
        for n in s:gmatch("[-+]?%d*%.?%d+") do t[#t + 1] = tonumber(n) end
        return t
    end
    for cmd, body in LOGO_D:gmatch("([MLZ])([^MLZ]*)") do
        if cmd == "M" then
            local poly, ns = {}, numbers(body)
            for i = 1, #ns - 1, 2 do
                poly[#poly + 1] = { ns[i], ns[i + 1] }
            end
            LOGO_SUBS[#LOGO_SUBS + 1] = poly
        elseif cmd == "L" then
            local poly, ns = LOGO_SUBS[#LOGO_SUBS], numbers(body)
            for i = 1, #ns - 1, 2 do
                poly[#poly + 1] = { ns[i], ns[i + 1] }
            end
        end
    end
    for _, poly in ipairs(LOGO_SUBS) do
        for _, p in ipairs(poly) do
            if p[1] < LOGO_MINX then LOGO_MINX = p[1] end
            if p[2] < LOGO_MINY then LOGO_MINY = p[2] end
            if p[1] > LOGO_MAXX then LOGO_MAXX = p[1] end
            if p[2] > LOGO_MAXY then LOGO_MAXY = p[2] end
        end
    end
end

local function logoInside(sx, sy)
    local c = false
    for _, poly in ipairs(LOGO_SUBS) do
        local n = #poly
        for i = 1, n do
            local a, b = poly[i], poly[i % n + 1]
            if ((a[2] > sy) ~= (b[2] > sy)) then
                local xint = (b[1] - a[1]) * (sy - a[2]) / (b[2] - a[2]) + a[1]
                if sx < xint then c = not c end
            end
        end
    end
    return c
end

local function buildLogoBmp(size, bg, accent)
    local spanx = LOGO_MAXX - LOGO_MINX
    local spany = LOGO_MAXY - LOGO_MINY
    local rows = {}
    for py = 0, size - 1 do
        local row = {}
        local sy = LOGO_MINY + (py + 0.5) / size * spany
        for px = 0, size - 1 do
            local sx = LOGO_MINX + (px + 0.5) / size * spanx
            local r, g, b
            if logoInside(sx, sy) then
                local t = ((px + 0.5) + (py + 0.5)) / (2 * size)
                r = accent.R * t
                g = accent.G * t
                b = accent.B * t
            else
                r, g, b = bg.R, bg.G, bg.B
            end
            row[#row + 1] = string.char(floor(b * 255 + 0.5), floor(g * 255 + 0.5), floor(r * 255 + 0.5))
        end
        rows[size - py] = table.concat(row)
    end
    local pixels = table.concat(rows)
    local pad = (4 - (size * 3) % 4) % 4
    local padded = {}
    for i = 1, #rows do padded[i] = rows[i] .. string.rep("\0", pad) end
    pixels = table.concat(padded)
    local dib = u32(40) .. u32(size) .. u32(size) .. u16(1) .. u16(24) .. u32(0)
        .. u32(#pixels) .. u32(2835) .. u32(2835) .. u32(0) .. u32(0)
    return "BM" .. u32(14 + 40 + #pixels) .. u32(0) .. u32(54) .. dib .. pixels
end

local LogoImage, LogoKey

local function mix(a, b, t)
    return rgb(
        floor(a.R * 255 + (b.R * 255 - a.R * 255) * t + 0.5),
        floor(a.G * 255 + (b.G * 255 - a.G * 255) * t + 0.5),
        floor(a.B * 255 + (b.B * 255 - a.B * 255) * t + 0.5)
    )
end

-- Drawing helpers -----------------------------------------------------------
local ALL = {}
Library.__all = ALL
local function newObj(kind, z)
    local d = D.new(kind)
    if kind == "Text" then
        pcall(function() d.Font = FONT end)
    end
    if z then pcall(function() d.ZIndex = z end) end
    pcall(function() d.Visible = false end)
    local o = { d = d, sc = { Visible = false } }
    ALL[#ALL + 1] = o
    return o
end

local function zset(o, z)
    local d = o and (o.d or o)
    if d then pcall(function() d.ZIndex = z end) end
end

local function ensureLogo()
    if LogoImage then return LogoImage end
    LogoImage = newObj("Image", 9)
    Library.__logo = LogoImage
    return LogoImage
end

local function put(o, k, v)
    if o.sc[k] ~= v then
        o.sc[k] = v
        o.d[k] = v
    end
end
local function putV(o, k, x, y)
    local c = o.sc[k]
    if not c or c[1] ~= x or c[2] ~= y then
        o.sc[k] = { x, y }
        o.d[k] = Vector2.new(x, y)
    end
end
local function putC(o, k, col)
    local c = o.sc[k]
    local r, g, b = col.R, col.G, col.B
    if not c or c[1] ~= r or c[2] ~= g or c[3] ~= b then
        o.sc[k] = { r, g, b }
        o.d[k] = col
    end
end

local function fill(o, x, y, w, h, color, alpha, radius)
    if w <= 0 or h <= 0 then
        put(o, "Visible", false)
        return
    end
    putV(o, "Position", x, y)
    putV(o, "Size", w, h)
    putC(o, "Color", color or Theme.main)
    o.sc.alphaBase = alpha or 1
    put(o, "Transparency", alpha or 1)
    put(o, "Filled", true)
    put(o, "Corner", radius or 0)
    put(o, "Visible", true)
end
local function stroke(o, x, y, w, h, color, alpha, radius, thickness)
    if w <= 0 or h <= 0 then
        put(o, "Visible", false)
        return
    end
    putV(o, "Position", x, y)
    putV(o, "Size", w, h)
    putC(o, "Color", color or Theme.outline)
    o.sc.alphaBase = alpha or 1
    put(o, "Transparency", alpha or 1)
    put(o, "Filled", false)
    put(o, "Thickness", thickness or 1)
    put(o, "Corner", radius or 0)
    put(o, "Visible", true)
end
local function text(o, x, y, str, size, color, alpha, center, outline)
    put(o, "Text", tostring(str))
    put(o, "Size", size or 14)
    putV(o, "Position", x, y)
    putC(o, "Color", color or Theme.text)
    o.sc.alphaBase = alpha or 1
    put(o, "Transparency", alpha or 1)
    put(o, "Center", center == true)
    put(o, "Outline", outline == true)
    put(o, "Visible", true)
end
local function line(o, x1, y1, x2, y2, color, alpha, thickness)
    putV(o, "From", x1, y1)
    putV(o, "To", x2, y2)
    putC(o, "Color", color or Theme.outline)
    o.sc.alphaBase = alpha or 1
    put(o, "Transparency", alpha or 1)
    put(o, "Thickness", thickness or 1)
    put(o, "Visible", true)
end

local MEAS = D.new("Text")
MEAS.Visible = false
pcall(function() MEAS.Font = FONT end)
local wcache, wcount = {}, 0
local function textW(str, size)
    str, size = tostring(str), size or 14
    local key = size .. "|" .. str
    local v = wcache[key]
    if v then return v end
    MEAS.Text = str
    MEAS.Size = size
    local w = MEAS.TextBounds.X
    wcount = wcount + 1
    if wcount > 900 then wcache, wcount = {}, 0 end
    wcache[key] = w
    return w
end

local function insideRect(r, x, y)
    return x and y and x >= r[1] and x <= r[1] + r[3] and y >= r[2] and y <= r[2] + r[4]
end

local function vc(y, h, size)
    return y + floor((h - size) / 2 + 0.5)
end

local function clipText(str, size, maxW)
    str = tostring(str)
    if maxW <= 0 then return "" end
    if textW(str, size) <= maxW then return str end
    local ell = "..."
    while #str > 0 and textW(str, size) > maxW - textW(ell, size) do
        str = str:sub(1, #str - 1)
    end
    return str .. ell
end

local function textC(o, cx, y, str, size, color, alpha, outline)
    str = tostring(str)
    text(o, cx - textW(str, size) / 2, y, str, size, color, alpha, false, outline)
end

-- Input ---------------------------------------------------------------------
local Players = _G.__swangy_players
if not Players then pcall(function() Players = game:GetService("Players") end) end
local Mouse = _G.__swangy_mouse

local function mouseAlive(m)
    if not m then return false end
    local ok, x = pcall(function() return m.X end)
    return ok and type(x) == "number"
end

local function getMouse()
    if mouseAlive(Mouse) then return Mouse end
    Mouse = nil
    if not Players then Players = _G.__swangy_players end
    if not Players then
        pcall(function() Players = game:GetService("Players") end)
    end
    if Players then
        _G.__swangy_players = Players
        local lp
        pcall(function() lp = Players.LocalPlayer end)
        if not lp then lp = _G.__swangy_localplayer end
        if lp then
            _G.__swangy_localplayer = lp
            pcall(function() Mouse = lp:GetMouse() end)
        end
    end
    if mouseAlive(Mouse) then
        _G.__swangy_mouse = Mouse
        return Mouse
    end
    Mouse = nil
    return nil
end

local mx, my
local m1 = { down = false, pressed = false, released = false }
local m2 = { down = false, pressed = false }
local m1prev = false
local m2prev = false
local m1latched = false
local m1lastDown = 0
local function poll()
    local m = getMouse()
    if m then
        local okx, xx = pcall(function() return m.X end)
        local oky, yy = pcall(function() return m.Y end)
        if okx and oky then mx, my = xx, yy end
    end
    local down = ismouse1pressed() and true or false
    if down then m1lastDown = clock() end
    if not down and (clock() - m1lastDown) > 0.08 then m1latched = false end
    m1prev = m1.down
    m1.down = down
    m1.pressed = down and not m1latched
    if m1.pressed then m1latched = true end
    m1.released = (not down) and m1prev
    local down2 = ismouse2pressed() and true or false
    m2prev = m2.down
    m2.down = down2
    m2.pressed = down2 and not m2prev
    Library.__mouse = { x = mx, y = my, down = m1.down, pressed = m1.pressed }
end

local kstate = {}
local function keyDown(vk) return iskeypressed(vk) and true or false end
local function keyEdge(vk)
    local down = keyDown(vk)
    local was = kstate[vk]
    kstate[vk] = down
    return down and not was
end

local VK = {
    Backspace = 8, Tab = 9, Enter = 13, Shift = 16, Ctrl = 17, Alt = 18, CapsLock = 20, Escape = 27, Space = 32,
    PageUp = 33, PageDown = 34, End = 35, Home = 36, Left = 37, Up = 38, Right = 39, Down = 40,
    Insert = 45, Delete = 46,
    ["0"] = 48, ["1"] = 49, ["2"] = 50, ["3"] = 51, ["4"] = 52, ["5"] = 53, ["6"] = 54, ["7"] = 55, ["8"] = 56, ["9"] = 57,
    A = 65, B = 66, C = 67, D = 68, E = 69, F = 70, G = 71, H = 72, I = 73, J = 74, K = 75, L = 76, M = 77,
    N = 78, O = 79, P = 80, Q = 81, R = 82, S = 83, T = 84, U = 85, V = 86, W = 87, X = 88, Y = 89, Z = 90,
    F1 = 112, F2 = 113, F3 = 114, F4 = 115, F5 = 116, F6 = 117, F7 = 118, F8 = 119, F9 = 120, F10 = 121, F11 = 122, F12 = 123,
    LeftShift = 160, RightShift = 161, LeftCtrl = 162, RightCtrl = 163, LeftAlt = 164, RightAlt = 165,
    LeftControl = 162, RightControl = 163, Control = 17, Shift = 16, Alt = 18,
    NumLock = 144, ScrollLock = 145, CapsLockKey = 20, Menu = 93,
}
local VK_NAME = {}
for n, c in pairs(VK) do if not VK_NAME[c] then VK_NAME[c] = n end end
local function keyToVk(k)
    if type(k) == "number" then return k end
    if type(k) ~= "string" or k == "" then return nil end
    if VK[k] then return VK[k] end
    local up = k:upper()
    if VK[up] then return VK[up] end
    if #k == 1 then return VK[up] end
    local norm = up:gsub("[%s_%-]", "")
    for name, code in pairs(VK) do
        if name:upper() == norm then return code end
    end
    return nil
end
local function vkName(vk)
    if vk == nil or vk == 0 then return "None" end
    return VK_NAME[vk] or tostring(vk)
end
Library.__vkName = vkName

local capturing
local focusedInput

local function shiftDown()
    return iskeypressed(16) or iskeypressed(160) or iskeypressed(161)
end

local function codeToChar(code)
    local shift = shiftDown()
    if code >= 65 and code <= 90 then
        local ch = string.char(code)
        return shift and ch or ch:lower()
    elseif code >= 97 and code <= 122 then
        local ch = string.char(code)
        return shift and ch:upper() or ch
    elseif code >= 48 and code <= 57 then
        return string.char(code)
    elseif code >= 96 and code <= 105 then
        return tostring(code - 96)
    elseif code == 32 then
        return " "
    elseif code == 189 then
        return shift and "_" or "-"
    elseif code == 190 then
        return "."
    elseif code == 191 then
        return "/"
    end
    return nil
end

-- Key capture is polled with iskeypressed (Windows VK codes), because
-- UIS.InputBegan reports Roblox KeyCodes which don't match iskeypressed.

local INPUT_CODES = { 8, 13, 27, 32, 189, 190, 191 }
for i = 48, 57 do INPUT_CODES[#INPUT_CODES + 1] = i end
for i = 65, 90 do INPUT_CODES[#INPUT_CODES + 1] = i end
for i = 96, 105 do INPUT_CODES[#INPUT_CODES + 1] = i end

local ALL_KEYS = {}
local seenKey = {}
for _, v in pairs(VK) do
    if type(v) == "number" and not seenKey[v] then
        seenKey[v] = true
        ALL_KEYS[#ALL_KEYS + 1] = v
    end
end

-- ui: input
local hitList, activeDrag = {}, nil
local popupElements, openPopup = {}, nil

local function clearPopup(except)
    for _, el in ipairs(popupElements) do
        if el ~= except and el.popupOpen then el:ClosePopup() end
    end
end

local function newHit(x, y, w, h, hnd)
    hnd[1], hnd[2], hnd[3], hnd[4] = x, y, w, h
    hitList[#hitList + 1] = hnd
    return hnd
end

local function processInput()
    if not mx then activeDrag = nil return end
    local consumed = false
    if m1.pressed and openPopup then
        local r = openPopup:PopupRect()
        if r and not insideRect(r, mx, my) then
            openPopup:ClosePopup()
            consumed = true
            activeDrag = nil
        end
    end
    if m1.pressed and not consumed then
        local hit
        for i = #hitList, 1, -1 do
            local h = hitList[i]
            if insideRect(h, mx, my) then hit = h break end
        end
        activeDrag = hit
        if hit and hit.press then pcall(hit.press, mx, my) end
    end
    if activeDrag and activeDrag.drag and m1.down then pcall(activeDrag.drag, mx, my) end
    if m1.released then
        if activeDrag and activeDrag.release then pcall(activeDrag.release, mx, my) end
        activeDrag = nil
    end
end

local function hovered(x, y, w, h)
    return insideRect({ x, y, w, h }, mx, my)
end

local Windows = {}
local menuVk = VK.RightShift
local watermarkOn = true
local notifs = {}

local function hideAll()
    for _, o in ipairs(ALL) do
        pcall(function()
            o.sc.Visible = false
            o.d.Visible = false
        end)
    end
end

-- Library API ---------------------------------------------------------------

-- ui: library
function Library:SetMenuKey(k)
    local v = keyToVk(k)
    if v then menuVk = v end
    return self
end
function Library:SetAccent(c)
    Theme.accent = c
    return self
end
function Library:SetTheme(t)
    for k, v in pairs(t or {}) do if Theme[k] ~= nil then Theme[k] = v end end
    return self
end
function Library:SetWatermark(on)
    watermarkOn = on ~= false
    return self
end
function Library:GetWindow() return Windows[1] end

-- Notifications -------------------------------------------------------------
local function removeDrawings(list)
    for _, o in ipairs(list) do pcall(function() o.d:Remove() end) end
end

local function removeNotif(n)
    removeDrawings({ { d = n.bg }, { d = n.bar }, { d = n.tt }, { d = n.mt } })
end

function Library:ClearNotifications()
    for i = #notifs, 1, -1 do
        removeNotif(notifs[i])
        table.remove(notifs, i)
    end
end

function Library:PreviewNotification(msg, title)
    local opts = Library.NotificationOptions
    local was = opts.Enabled
    opts.Enabled = true
    local n = Library:Notify(msg or "Preview notification", nil, title or "Preview")
    opts.Enabled = was
    return n
end

function Library:Notify(msg, duration, title)
    local opts = Library.NotificationOptions
    if not opts.Enabled then
        return nil
    end
    local dur = opts.UseCallDuration and duration or opts.Duration
    local n = {
        msg = tostring(msg), title = tostring(title or "Notification"),
        t = clock(), dur = dur or 4,
        bg = D.new("Square"), bar = D.new("Square"), tt = D.new("Text"), mt = D.new("Text"),
    }
    n.bg.Filled, n.bg.Corner = true, Library.CornerRadius
    n.bar.Filled, n.bar.Corner = true, 2
    n.tt.Size, n.mt.Size = 14, 14
    n.bg.Visible, n.bar.Visible, n.tt.Visible, n.mt.Visible = false, false, false, false
    pcall(function() n.tt.Font = FONT; n.mt.Font = FONT end)
    zset(n.bg, 200); zset(n.bar, 201); zset(n.tt, 202); zset(n.mt, 202)
    table.insert(notifs, 1, n)
    while #notifs > (opts.MaxVisible or 6) do
        removeNotif(table.remove(notifs))
    end
    return n
end

local function renderNotifs()
    local opts = Library.NotificationOptions
    local right = Library.NotifySide ~= "Left"
    local cam = uiCamera()
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    local w = opts.Width or 260
    local x = right and (vp.X - w - 16) or 16
    local now = clock()
    for i = #notifs, 1, -1 do
        local n = notifs[i]
        local age = now - n.t
        if age > n.dur then
            removeNotif(n)
            table.remove(notifs, i)
        else
            local alpha = 1
            local fade = opts.Fade or 0
            if fade > 0 and (n.dur - age) < fade then
                alpha = (n.dur - age) / fade
            end
            local h = 56
            local yy = (opts.OffsetY or 16) + (i - 1) * (h + (opts.Spacing or 6))
            n.bg.Position, n.bg.Size = Vector2.new(x, yy), Vector2.new(w, h)
            n.bg.Color, n.bg.Transparency = Theme.main, alpha
            n.bg.Visible = true
            n.bar.Position, n.bar.Size = Vector2.new(x + 1, yy + 6), Vector2.new(3, h - 12)
            n.bar.Color, n.bar.Transparency = Theme.accent, alpha
            n.bar.Visible = true
            n.tt.Position, n.tt.Text, n.tt.Color, n.tt.Transparency = Vector2.new(x + 14, yy + 9), clipText(n.title, 14, w - 28), Theme.text, alpha
            n.tt.Visible = true
            n.mt.Position, n.mt.Text, n.mt.Color, n.mt.Transparency = Vector2.new(x + 14, yy + 30), clipText(n.msg, 14, w - 28), Theme.subtext, alpha
            n.mt.Visible = true
        end
    end
end

-- Element base --------------------------------------------------------------
local Element = {}
Element.__index = Element

-- ui: elements
function Element:OnChanged(fn) table.insert(self.changed, fn) return self end
function Element:Fire(...)
    for _, fn in ipairs(self.changed) do pcall(fn, ...) end
    return self
end
function Element:SetVisible(b) self.visible = b ~= false return self end
function Element:SetDisabled(b) self.disabled = b == true return self end
function Element:Destroy()
    self.destroyed = true
    for _, o in ipairs(self.objects) do pcall(function() o.d:Remove() end) end
end

local function newElement(cls, id, label)
    local el = setmetatable({}, Element)
    for k, v in pairs(cls) do if el[k] == nil then el[k] = v end end
    el.id, el.text = id, label or id
    el.changed, el.objects = {}, {}
    el.visible, el.disabled = true, false
    el.addons = {}
    el.kind = cls.__kind
    return el
end

local function mkText(el, size)
    local o = newObj("Text", 30)
    o.d.Size = size or 14
    o.d.Outline = false
    table.insert(el.objects, o)
    return o
end
local function mkSq(el, z)
    local o = newObj("Square", z or 20)
    table.insert(el.objects, o)
    return o
end
local function mkLine(el, z)
    local o = newObj("Line", z or 20)
    table.insert(el.objects, o)
    return o
end

local function beginCapture(el)
    capturing = el
    for _, code in ipairs(ALL_KEYS) do
        kstate[code] = keyDown(code)
    end
end

-- Inline addons: key picker + color picker --------------------------------
local KeyPicker = {}
KeyPicker.__index = KeyPicker
KeyPicker.__kind = "KeyPicker"
KeyPicker.TypeKey = true
function KeyPicker:GetHeight() return 21 end
function KeyPicker:GetState() return self.state end
function KeyPicker:SetValue(v)
    if type(v) == "table" then
        self.vk = keyToVk(v[1])
        if v[2] then self.mode = v[2] end
    else
        self.vk = keyToVk(v)
    end
    self.state = false
    self:Fire(self)
    return self
end
function KeyPicker:Capture(code)
    capturing = nil
    if code == VK.Escape then
        self.vk = nil
        self.state = false
        if self.changedCallback then pcall(self.changedCallback, self) end
        return
    end
    self.vk = code
    self.state = false
    if self.changedCallback then pcall(self.changedCallback, self) end
    self:Fire(self)
end
function KeyPicker:NotifyState(on)
    if self.syncParent and #(self.syncParent.changed or {}) > 0 then
        return
    end
    local label = (self.text and self.text ~= self.id) and self.text or vkName(self.vk)
    if Library and Library.Notify then
        Library:Notify(label .. (on and "  [ ON ]" or "  [ OFF ]"), 1.6, "Keybind")
    end
end
function KeyPicker:Evaluate()
    if capturing == self then return end
    if self.mode == "Always" then
        if not self.state then
            self.state = true
            self:Fire(self)
        end
        return
    end
    if not self.vk then return end
    local down = keyDown(self.vk)
    if self.mode == "Hold" then
        if down ~= self.state then
            self.state = down
            self:Fire(self)
            self:NotifyState(down)
        end
    elseif keyEdge(self.vk) then
        self.state = not self.state
        self:Fire(self)
        self:NotifyState(self.state)
    end
end
function KeyPicker:AddKeyPicker() return self end
function KeyPicker:CloseModePopup()
    self.modeOpen = false
    if openPopup == self then openPopup = nil end
    if self.modeBg then put(self.modeBg, "Visible", false) end
    if self.modeBorder then put(self.modeBorder, "Visible", false) end
    for _, o in ipairs(self.modeTexts or {}) do put(o, "Visible", false) end
    for _, o in ipairs(self.modeCells or {}) do put(o, "Visible", false) end
end
function KeyPicker:ClosePopup() return self:CloseModePopup() end
function KeyPicker:PopupRect() return { self.mpx, self.mpy, self.mpw, self.mph } end
function KeyPicker:OpenModePopup()
    clearPopup(self)
    self.modeOpen = true
    openPopup = self
end
function KeyPicker:RenderPopup()
    if not self.modeOpen then return end
    local modes = { "Hold", "Toggle", "Always" }
    local rowH = 20
    local pw, ph = 88, rowH * #modes + 6
    local cam = uiCamera()
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    local px, py = self.boxX or 0, (self.boxY or 0) + (self.boxH or 18) + 2
    if px + pw > vp.X - 8 then px = vp.X - pw - 8 end
    if py + ph > vp.Y - 8 then py = (self.boxY or 0) - ph - 2 end
    self.mpx, self.mpy, self.mpw, self.mph = px, py, pw, ph
    if not self.modeBg then
        self.modeBg, self.modeBorder = newObj("Square", 110), newObj("Square", 111)
        self.modeTexts, self.modeCells = {}, {}
        table.insert(self.objects, self.modeBg)
        table.insert(self.objects, self.modeBorder)
    end
    fill(self.modeBg, px, py, pw, ph, Theme.bg, 1, 4)
    stroke(self.modeBorder, px, py, pw, ph, Theme.outline, 1, 4, 1)
    put(self.modeBg, "Visible", true)
    put(self.modeBorder, "Visible", true)
    newHit(px, py, pw, ph, { press = function() end })
    for i, m in ipairs(modes) do
        local o = self.modeTexts[i]
        if not o then o = newObj("Text", 112) o.d.Size = 14 table.insert(self.objects, o) self.modeTexts[i] = o end
        local cell = self.modeCells[i]
        if not cell then cell = newObj("Square", 111) table.insert(self.objects, cell) self.modeCells[i] = cell end
        local ry = py + 3 + (i - 1) * rowH
        local hv = hovered(px + 3, ry, pw - 6, rowH)
        if hv then fill(cell, px + 3, ry, pw - 6, rowH, Theme.accent, 0.18, 2) else put(cell, "Visible", false) end
        text(o, px + 8, ry + 3, m, 14, self.mode == m and Theme.accent or Theme.text, 1, false, false)
        newHit(px + 3, ry, pw - 6, rowH, {
            press = function()
                self.mode = m
                self.state = false
                self:CloseModePopup()
                self:Fire(self)
            end,
        })
    end
end
function KeyPicker:RenderInline(x, y, h)
    local bw = 68
    local bx = x - bw
    self.boxX, self.boxY, self.boxW, self.boxH = bx, y, bw, h
    fill(self.bg, bx, y + (h - 15) / 2, bw, 15, Theme.main, 1, 2)
    stroke(self.border, bx, y + (h - 15) / 2, bw, 15, (capturing == self or self.modeOpen) and Theme.accent or Theme.outline, 1, 2, 1)
    local shown = capturing == self and "[...]" or vkName(self.vk)
    textC(self.keyText, bx + bw / 2, vc(y + (h - 15) / 2, 15, 14), clipText(shown, 14, bw - 6), 14, Theme.subtext, 1, false)
    if hovered(bx, y, bw, h) and m2.pressed then
        self:OpenModePopup()
    end
    newHit(bx, y, bw, h, {
        press = function()
            beginCapture(self)
            self:CloseModePopup()
        end,
    })
end

local Grid = { cells = {}, hue = {}, alpha = {}, hueKey = nil }
Library.__grid = Grid
local function ensureGrid()
    if Grid.cursor then return end
    -- above the popup panel (z 100): at equal ZIndex the background can win and
    -- the gradient is simply not there, which reads as "no colours"
    Grid.svImage = newObj("Image", 102)
    for i = 1, 32 do Grid.hue[i] = newObj("Square", 101) end
    for i = 1, 16 do Grid.alpha[i] = newObj("Square", 101) end
    Grid.cursor = newObj("Square", 106)
    Grid.cursorH = newObj("Square", 106)
end
local function hideGrid()
    if Grid.svImage then
        Grid.svImage.sc.Visible = false
        Grid.svImage.d.Visible = false
    end
    for _, o in ipairs(Grid.hue) do put(o, "Visible", false) end
    for _, o in ipairs(Grid.alpha) do put(o, "Visible", false) end
    if Grid.cursor then put(Grid.cursor, "Visible", false) end
    if Grid.cursorH then put(Grid.cursorH, "Visible", false) end
end

local ColorPicker = {}
ColorPicker.__index = ColorPicker
ColorPicker.__kind = "ColorPicker"
function ColorPicker:GetHeight() return 21 end
function ColorPicker:Color() return Color3.fromHSV(self.h or 0.72, self.s or 0.6, self.v or 1) end
function ColorPicker:SetValueRGB(c, t)
    self.value = c
    if t then self.alpha = 1 - t end
    self.h, self.s, self.v = rgbToHsv(c)
    self:Fire(self.value, self.alpha)
    return self
end
function ColorPicker:SetValue(hsv, t)
    if hsv then self.h, self.s, self.v = hsv.H or self.h, hsv.S or self.s, hsv.V or self.v end
    if t then self.alpha = 1 - t end
    self.value = self:Color()
    self:Fire(self.value, self.alpha)
    return self
end
function ColorPicker:Key(code)
    if not self.hexEditing then return end
    if code == 13 then
        local t = self.hexBuf or ""
        if #t == 6 then
            local ok, c = pcall(Color3.fromHex, t)
            if ok and c then
                self:SetValueRGB(c, 1 - (self.alpha or 1))
            end
        end
        self.hexEditing = false
        focusedInput = nil
    elseif code == 27 then
        self.hexEditing = false
        focusedInput = nil
    elseif code == 8 then
        self.hexBuf = (self.hexBuf or ""):sub(1, -2)
    else
        local ch
        if code >= 48 and code <= 57 then
            ch = string.char(code)
        elseif code >= 65 and code <= 70 then
            ch = string.char(code)
        elseif code >= 97 and code <= 102 then
            ch = string.char(code):upper()
        end
        if ch and #(self.hexBuf or "") < 6 then
            self.hexBuf = (self.hexBuf or "") .. ch
        end
    end
end
function ColorPicker:ClosePopup()
    self.popupOpen = false
    self.hexEditing = false
    if focusedInput == self then focusedInput = nil end
    if openPopup == self then openPopup = nil end
    put(self.popupBg, "Visible", false)
    put(self.popupBorder, "Visible", false)
    put(self.svBase, "Visible", false)
    hideGrid()
    for _, o in ipairs({ self.hexLabel, self.alphaBG, self.alphaSwatch, self.hexBg, self.hexBorder }) do put(o, "Visible", false) end
end
function ColorPicker:PopupRect() return { self.px, self.py, self.pw, self.ph } end
function ColorPicker:OpenPopup()
    clearPopup(self)
    self.popupOpen = true
    openPopup = self
end
function ColorPicker:RenderInline(x, y, h, anchorRight)
    local s = 18
    local sx = anchorRight and (x - s) or x
    fill(self.swatch, sx, y + (h - s) / 2, s, s, self:Color(), 1, 2)
    stroke(self.swatchBorder, sx, y + (h - s) / 2, s, s, Theme.outline, 1, 2, 1)
    newHit(sx, y, s, h, {
        press = function()
            if self.popupOpen then self:ClosePopup() else self:OpenPopup() end
        end,
    })
    self.hx, self.hy, self.hw = sx, y, s
end
function ColorPicker:RenderPopup()
    if not self.popupOpen then return end
    local pw, ph = 204, 168
    local cam = uiCamera()
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    local px, py = self.hx - pw + 20, self.hy + 24
    if px < 8 then px = 8 end
    if px + pw > vp.X - 8 then px = vp.X - pw - 8 end
    if py + ph > vp.Y - 8 then py = self.hy - ph - 8 end
    if py < 8 then py = 8 end
    self.px, self.py, self.pw, self.ph = px, py, pw, ph
    fill(self.popupBg, px, py, pw, ph, Theme.bg, 1, 4)
    stroke(self.popupBorder, px, py, pw, ph, Theme.outline, 1, 4, 1)
    newHit(px, py, pw, ph, { press = function() end })

    ensureGrid()
    local gx, gy, gw, gh = px + 8, py + 8, pw - 16, 108
    fill(self.svBase, gx, gy, gw, gh, Color3.fromHSV(self.h, 1, 1), 1, 0)
    local hk = floor(self.h * 100 + 0.5)
    if Grid.hueKey ~= hk then
        Grid.hueKey = hk
        Grid.svImage.d.Data = buildSVBmp(self.h)
    end
    Grid.svImage.d.Position = Vector2.new(gx, gy)
    Grid.svImage.d.Size = Vector2.new(gw, gh)
    put(Grid.svImage, "Visible", true)
    fill(Grid.cursor, gx + self.s * gw - 3, gy + (1 - self.v) * gh - 3, 6, 6, Theme.white, 1, 0)
    local function svSet(xx, yy)
        self.s = clamp((xx - gx) / gw, 0, 1)
        self.v = clamp(1 - (yy - gy) / gh, 0, 1)
        self.value = self:Color()
        self:Fire(self.value, self.alpha)
    end
    newHit(gx, gy, gw, gh, { press = svSet, drag = svSet })

    local hx, hy, hw2, hh2 = px + 8, py + 124, pw - 16, 10
    local segs = 32
    for i = 1, segs do
        local o = Grid.hue[i]
        fill(o, hx + (i - 1) / segs * hw2, hy, hw2 / segs + 0.6, hh2, Color3.fromHSV((i - 0.5) / segs, 1, 1), 1, 0)
        put(o, "Visible", true)
    end
    fill(Grid.cursorH, hx + self.h * hw2 - 1, hy - 1, 2, hh2 + 2, Theme.white, 1, 0)
    local function hueSet(xx)
        self.h = clamp((xx - hx) / hw2, 0, 0.999)
        self.value = self:Color()
        self:Fire(self.value, self.alpha)
    end
    newHit(hx, hy, hw2, hh2, { press = hueSet, drag = function(xx) hueSet(xx) end })

    -- no alpha strip: every colour here feeds an ESP that draws opaque, and the
    -- strip's left end sat right where the popup gets clicked, which silently set
    -- alpha 0 and made the row swatch look like it had lost its colour
    for i = 1, #Grid.alpha do put(Grid.alpha[i], "Visible", false) end

    local c = self:Color()
    local hex = fmt("#%02X%02X%02X", floor(c.R * 255 + 0.5), floor(c.G * 255 + 0.5), floor(c.B * 255 + 0.5))
    local hx, hy, hw, hh = px + 8, py + 140, 96, 20
    if self.hexEditing and m1.pressed and not hovered(hx, hy, hw, hh) then
        self.hexEditing = false
        if focusedInput == self then focusedInput = nil end
    end
    fill(self.hexBg, hx, hy, hw, hh, Theme.main, 1, 2)
    put(self.hexBg, "Visible", true)
    stroke(self.hexBorder, hx, hy, hw, hh, self.hexEditing and Theme.accent or Theme.outline, 1, 2, 1)
    put(self.hexBorder, "Visible", true)
    local shown = self.hexEditing and ("#" .. (self.hexBuf or "") .. ((clock() % 1) < 0.5 and "|" or "")) or hex
    text(self.hexLabel, hx + 6, vc(hy, hh, 14), shown, 14, self.hexEditing and Theme.text or Theme.subtext, 1, false, false)
    put(self.hexLabel, "Visible", true)
    newHit(hx, hy, hw, hh, {
        press = function()
            self.hexEditing = true
            self.hexBuf = ""
            focusedInput = self
        end,
    })
    -- the popup's own colour chip, always opaque so a pick never reads as blank
    fill(self.alphaBG, px + pw - 26, py + 142, 18, 18, Theme.main, 1, 2)
    fill(self.alphaSwatch, px + pw - 26, py + 142, 18, 18, c, 1, 2)
    stroke(self.alphaBG, px + pw - 26, py + 142, 18, 18, Theme.outline, 1, 2, 1)
    put(self.alphaBG, "Visible", true)
    put(self.alphaSwatch, "Visible", true)
end

local Input = {}
Input.__index = Input
Input.__kind = "Input"
function Input:GetHeight() return 39 end
function Input:SetValue(v)
    self.value = tostring(v or "")
    self:Fire(self.value)
    return self
end
function Input:SetText(t) self.text = t return self end
function Input:Focus() focusedInput = self return self end
function Input:SetPlaceholder(t) self.placeholder = t return self end
function Input:Key(code)
    if code == 13 or code == 27 then
        self:Fire(self.value)
        focusedInput = nil
        return
    end
    if code == 8 then
        self.value = self.value:sub(1, -2)
        self:Fire(self.value)
        return
    end
    local ch = codeToChar(code)
    if ch then
        self.value = self.value .. ch
        self:Fire(self.value)
    end
end
function Input:Render(x, y, w)
    text(self.label, x, y, clipText(self.text, 14, w), 14, Theme.text, 0.85, false, false)
    local by = y + 18
    fill(self.bg, x, by, w, 21, Theme.main, 1, 2)
    stroke(self.border, x, by, w, 21, focusedInput == self and Theme.accent or Theme.outline, 1, 2, 1)
    local shown = (self.value ~= "" and self.value) or (self.placeholder or "")
    text(self.valueText, x + 6, vc(by, 21, 14), clipText(shown, 14, w - 14), 14, self.value ~= "" and Theme.text or Theme.subtext, 1, false, false)
    if focusedInput == self and (clock() % 1) < 0.5 then
        local cxp = x + 6 + textW(self.value, 14) + 1
        line(self.caret, cxp, by + 4, cxp, by + 17, Theme.text, 1, 1)
    else
        put(self.caret, "Visible", false)
    end
    if m1.pressed and not hovered(x, by, w, 21) and focusedInput == self then
        focusedInput = nil
    end
    newHit(x, by, w, 21, {
        press = function()
            focusedInput = self
        end,
    })
end

-- ui: addons
local function attachKeyPicker(parent, id, cfg)
    cfg = cfg or {}
    local el = newElement(KeyPicker, id, cfg.Text or id)
    el.vk = keyToVk(cfg.Default)
    el.mode = cfg.Mode or "Toggle"
    el.state = false
    el.changedCallback = cfg.ChangedCallback
    el.captureOnly = cfg.CaptureOnly == true
    if cfg.Callback then table.insert(el.changed, cfg.Callback) end
    el.bg, el.border = mkSq(el, 21), mkSq(el, 22)
    el.keyText = mkText(el, 14)
    el.inline = true
    el.modeOpen = false
    el.parent = parent
    if parent and parent.kind == "Toggle" and cfg.SyncToggleState ~= false then
        el.syncParent = parent
        table.insert(el.changed, function(self)
            if self.state ~= nil then parent:SetValue(self.state) end
        end)
    end
    if not el.captureOnly then table.insert(Library.__keybinds, el) end
    table.insert(popupElements, el)
    Library.Options[id] = el
    Library.KeyPickers[id] = el
    table.insert(parent.addons, el)
    return el
end

local function attachColorPicker(parent, id, cfg)
    cfg = cfg or {}
    local el = newElement(ColorPicker, id, cfg.Title or id)
    local c = cfg.Default or Theme.accent
    el.value = c
    el.alpha = 1 - (cfg.Transparency or 0)
    el.h, el.s, el.v = 0.72, 0.6, 1
    el.h, el.s, el.v = rgbToHsv(c)
    if cfg.Callback then table.insert(el.changed, cfg.Callback) end
    el.swatch = mkSq(el, 21)
    el.swatchBorder = mkSq(el, 22)
    el.popupBg = mkSq(el, 100)
    el.popupBorder = mkSq(el, 101)
    el.svBase = mkSq(el, 101)   -- hue block behind the gradient, above the popup panel
    el.hexLabel = mkText(el, 14)
    el.hexBg, el.hexBorder = mkSq(el, 103), mkSq(el, 104)
    el.hexEditing = false
    el.alphaBG = mkSq(el, 103)
    el.alphaSwatch = mkSq(el, 104)
    zset(el.hexLabel, 107)
    el.inline = true
    el.parent = parent
    table.insert(popupElements, el)
    Library.Options[id] = el
    Library.ColorPickers[id] = el
    table.insert(parent.addons, el)
    el:Fire(el.value, el.alpha)
    return el
end

local function renderAddons(parent, x, y, w, h)
    local anchor = x + w
    for _, a in ipairs(parent.addons) do
        if a.TypeKey then
            a:RenderInline(anchor - 2, y, h)
            anchor = anchor - 72
        else
            a:RenderInline(anchor - 2, y, h, true)
            anchor = anchor - 24
        end
    end
    return anchor
end

-- Widgets -------------------------------------------------------------------
local Toggle = {}
Toggle.__index = Toggle
Toggle.__kind = "Toggle"
Toggle.TypeKey = true

-- ui: widgets
function Toggle:GetHeight() return 18 end
function Toggle:SetValue(v)
    v = v == true
    if self.value ~= v then self.value = v self:Fire(v) end
    return self
end
function Toggle:SetText(t) self.text = t return self end
function Toggle:AddKeyPicker(id, cfg) return attachKeyPicker(self, id, cfg) end
function Toggle:AddColorPicker(id, cfg) return attachColorPicker(self, id, cfg) end
function Toggle:Render(x, y, w)
    local h = 18
    if not self.disabled then
        newHit(x, y, w, h, { press = function() self:SetValue(not self.value) end })
    end
    local endX = w
    if #self.addons > 0 then
        endX = (renderAddons(self, x, y, w, h) - x)
    end
    local switchW = 32
    local labelW = endX - switchW - 8
    text(self.label, x, vc(y, h, 14), clipText(self.text, 14, labelW), 14, self.disabled and Theme.disabled or Theme.text, 0.85, false, false)
    local tx = x + endX - switchW
    local target = self.value and 1 or 0
    self.knobPos = approach(self.knobPos or target, target, Library.Animations.Toggle, FRAME_DT)
    local p = clamp(self.knobPos, 0, 1)
    fill(self.track, tx, y, switchW, h, mix(Theme.main, Theme.accent, p), 1, h / 2)
    stroke(self.border, tx, y, switchW, h, Theme.outline, 1, h / 2, 1)
    local ks = 14
    local kx = tx + 2 + p * (switchW - ks - 4)
    fill(self.knob, kx, y + 2, ks, ks, Theme.white, 1, ks / 2)
end

local Slider = {}
Slider.__index = Slider
Slider.__kind = "Slider"
function Slider:GetHeight() return 33 end
function Slider:Format(v)
    local step = self.rounding or 1
    local shown
    if step > 0 and step < 1 then
        shown = string.format("%.2f", v)
    else
        shown = tostring(floor(v + 0.5))
    end
    return (self.prefix or "") .. shown .. (self.suffix or "")
end
function Slider:SetValue(v)
    v = clamp(tonumber(v) or self.min, self.min, self.max)
    local step = self.rounding or 1
    if step > 0 then
        v = floor(v / step + 0.5) * step
        if step >= 1 then
            v = floor(v + 0.5)
        else
            v = floor(v * 100 + 0.5) / 100
        end
    end
    if math.abs((self.value or 0) - v) > 1e-6 then
        self.value = v
        self:Fire(v)
    end
    return self
end
function Slider:SetMin(v) self.min = v return self end
function Slider:SetMax(v) self.max = v return self end
function Slider:SetText(t) self.text = t return self end
function Slider:Render(x, y, w)
    local by, bh = y + 18, 15
    text(self.label, x, y, clipText(self.text, 14, w), 14, self.disabled and Theme.disabled or Theme.text, 0.85, false, false)
    local frac = (self.max > self.min) and ((self.value - self.min) / (self.max - self.min)) or 0
    self.animFrac = approach(self.animFrac or frac, frac, Library.Animations.Slider, FRAME_DT)
    local p = clamp(self.animFrac, 0, 1)
    fill(self.bg, x, by, w, bh, Theme.main, 1, 2)
    fill(self.fill, x, by, w * p, bh, self.disabled and Theme.disabled or Theme.accent, 1, 2)
    stroke(self.border, x, by, w, bh, Theme.outline, 1, 2, 1)
    local ts = 13
    local tpos = clamp(x + w * p - ts / 2, x - 1, x + w - ts + 1)
    fill(self.thumb, tpos, by + (bh - ts) / 2, ts, ts, Theme.white, 1, ts / 2)
    textC(self.valueText, x + w / 2, vc(by, bh, 14), self:Format(self.value), 14, Theme.white, 1, true)
    if not self.disabled then
        local function set(xx)
            local f = clamp((xx - x) / max(1, w), 0, 1)
            self:SetValue(self.min + f * (self.max - self.min))
        end
        newHit(x, by, w, bh, { press = set, drag = function(xx) set(xx) end })
    end
end

local Button = {}
Button.__index = Button
Button.__kind = "Button"
function Button:GetHeight() return 21 end
function Button:SetText(t) self.text = t return self end
function Button:Render(x, y, w)
    local hv = hovered(x, y, w, 21)
    fill(self.bg, x, y, w, 21, hv and mix(Theme.main, Theme.accent, 0.18) or Theme.main, 1, 2)
    stroke(self.border, x, y, w, 21, Theme.outline, 1, 2, 1)
    textC(self.label, x + w / 2, vc(y, 21, 14), clipText(self.text, 14, w - 10), 14, Theme.text, 1, false)
    newHit(x, y, w, 21, {
        press = function()
            if self.func then pcall(self.func) end
        end,
    })
end

local Label = {}
Label.__index = Label
Label.__kind = "Label"
Label.TypeKey = true
function Label:Lines(w)
    local size = self.size or 14
    if not self.wrap then return { self.text } end
    local out, cur = {}, ""
    for word in tostring(self.text):gmatch("%S+") do
        local cand = cur == "" and word or (cur .. " " .. word)
        if textW(cand, size) <= w or cur == "" then cur = cand
        else out[#out + 1] = cur cur = word end
    end
    if cur ~= "" then out[#out + 1] = cur end
    if #out == 0 then out[1] = "" end
    return out
end
function Label:GetHeight(w)
    if self.wrap then
        local used = 0
        for _, a in ipairs(self.addons or {}) do
            used = used + (a.kind == "KeyPicker" and 72 or 24)
        end
        return #self:Lines(w - used) * 18
    end
    return 18
end
function Label:SetText(t) self.text = t return self end
function Label:AddKeyPicker(id, cfg) return attachKeyPicker(self, id, cfg) end
function Label:AddColorPicker(id, cfg) return attachColorPicker(self, id, cfg) end
function Label:Render(x, y, w)
    local endX = w
    if #self.addons > 0 then endX = (renderAddons(self, x, y, w, 18) - x) end
    local size = self.size or 14
    local lines = self:Lines(endX)
    for i, ln in ipairs(lines) do
        local o = self.lines[i]
        if not o then o = mkText(self, size) self.lines[i] = o end
        -- a single word wider than the box cannot be wrapped, so clip the
        -- wrapped line too: labels must never draw past their section box
        text(o, x, y + (i - 1) * 18, clipText(ln, size, endX), size, self.color or Theme.text, 0.85, false, false)
    end
    for i = #lines + 1, #self.lines do put(self.lines[i], "Visible", false) end
end

local Divider = {}
Divider.__index = Divider
Divider.__kind = "Divider"
function Divider:GetHeight() return self.text and 30 or 6 end
function Divider:Render(x, y, w)
    if self.text and self.text ~= "" then
        textC(self.lbl, x + w / 2, vc(y, 24, 14), clipText(self.text, 14, w), 14, Theme.subtext, 1, false)
        line(self.ln, x, y + 24, x + w, y + 24, Theme.outline, 1, 1)
    else
        line(self.ln, x, y + 3, x + w, y + 3, Theme.outline, 1, 1)
        put(self.lbl, "Visible", false)
    end
end

local Dropdown = {}
Dropdown.__index = Dropdown
Dropdown.__kind = "Dropdown"
function Dropdown:GetHeight() return self.text and 39 or 21 end
function Dropdown:BuildOptions()
    local opts = {}
    local vals = self.values
    local isArray = true
    for k in pairs(vals) do
        if type(k) ~= "number" then isArray = false break end
    end
    if isArray then
        for _, v in ipairs(vals) do opts[#opts + 1] = { key = v, label = tostring(v) } end
    else
        local keys = {}
        for k in pairs(vals) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do opts[#opts + 1] = { key = k, label = tostring(vals[k]) } end
    end
    self.opts = opts
    if self.multi then
        if type(self.value) ~= "table" then self.value = {} end
    elseif self.value == nil and #opts > 0 then
        self.value = opts[1].key
    end
    return opts
end
function Dropdown:LabelFor(key)
    for _, o in ipairs(self.opts or {}) do if o.key == key then return o.label end end
    return tostring(key)
end
function Dropdown:Display()
    if self.multi then
        local parts = {}
        for k in pairs(self.value or {}) do parts[#parts + 1] = self:LabelFor(k) end
        table.sort(parts)
        if #parts == 0 then return self.placeholder or "..." end
        return table.concat(parts, ", ")
    end
    if self.value == nil then return self.placeholder or "..." end
    return self:LabelFor(self.value)
end
function Dropdown:SetValue(v) self.value = v self:Fire(self.value) return self end
function Dropdown:SetValues(t)
    self.values = t or {}
    self.optionArray = nil
    self:BuildOptions()
    if not self.multi and self.value ~= nil then
        local found = false
        for _, o in ipairs(self.opts or {}) do if o.key == self.value then found = true break end end
        if not found then self.value = self.opts and self.opts[1] and self.opts[1].key or nil end
    end
    return self
end
function Dropdown:AddValues(t)
    if type(t) ~= "table" then t = { t } end
    for k, v in pairs(t) do
        if type(k) == "number" then table.insert(self.values, v) else self.values[k] = v end
    end
    self.optionArray = nil
    self:BuildOptions()
    return self
end
function Dropdown:ClosePopup()
    self.popupOpen = false
    if openPopup == self then openPopup = nil end
    put(self.popupBg, "Visible", false)
    put(self.popupBorder, "Visible", false)
    if self.scrollTrack then put(self.scrollTrack, "Visible", false) end
    if self.scrollThumb then put(self.scrollThumb, "Visible", false) end
    for _, o in ipairs(self.optTexts) do put(o, "Visible", false) end
    for _, o in ipairs(self.selCells) do put(o, "Visible", false) end
end
function Dropdown:PopupRect() return { self.px, self.py, self.pw, self.ph } end
function Dropdown:OpenPopup() clearPopup(self) self.popupOpen = true openPopup = self end
function Dropdown:Render(x, y, w)
    local selY = y
    if self.text then
        text(self.label, x, y, clipText(self.text, 14, w - 24), 14, Theme.text, 0.65, false, false)
        selY = y + 18
    else
        put(self.label, "Visible", false)
    end
    local hv = hovered(x, selY, w, 21)
    fill(self.bg, x, selY, w, 21, Theme.main, 1, 2)
    stroke(self.border, x, selY, w, 21, self.popupOpen and Theme.accent or (hv and Theme.strokeLit or Theme.outline), 1, 2, 1)
    text(self.valueText, x + 6, vc(selY, 21, 14), clipText(self:Display(), 14, w - 26), 14, Theme.text, 1, false, false)
    local cx, cy = x + w - 12, selY + 9
    line(self.chev1, cx - 3, cy, cx, cy + 3, Theme.subtext, 1, 1)
    line(self.chev2, cx, cy + 3, cx + 3, cy, Theme.subtext, 1, 1)
    newHit(x, selY, w, 21, {
        press = function()
            if self.popupOpen then self:ClosePopup() else self:OpenPopup() end
        end,
    })
    self.hx, self.hy, self.hw = x, selY, w
end
function Dropdown:RenderPopup()
    if not self.popupOpen then return end
    local opts = self.opts or self:BuildOptions()
    local rowH = 21
    local total = #opts
    local vis = total
    if self.maxVisible and total > self.maxVisible then vis = self.maxVisible end
    local scrollMax = max(0, total - vis)
    self.scroll = clamp(self.scroll or 0, 0, scrollMax)
    local pw, ph = self.hw, rowH * vis + 8
    local cam = uiCamera()
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    local px, py = self.hx, self.hy + 21 + 3
    if py + ph > vp.Y - 8 then py = self.hy - ph - 3 end
    self.px, self.py, self.pw, self.ph = px, py, pw, ph
    fill(self.popupBg, px, py, pw, ph, Theme.bg, 1, 4)
    stroke(self.popupBorder, px, py, pw, ph, Theme.outline, 1, 4, 1)
    newHit(px, py, pw, ph, { press = function() end })
    local showBar = total > vis
    local listW = pw - (showBar and 12 or 0)
    local first = self.scroll + 1
    for idx = 1, vis do
        local i = first + idx - 1
        local opt = opts[i]
        if not opt then break end
        local o = self.optTexts[idx]
        if not o then o = newObj("Text", 102) o.d.Size = 14 table.insert(self.objects, o) self.optTexts[idx] = o end
        local ry = py + 4 + (idx - 1) * rowH
        local selected = (self.multi and self.value and self.value[opt.key]) or (self.value == opt.key)
        local hv = hovered(px + 4, ry, listW - 8, rowH)
        local cell = self.selCells[idx]
        if hv then
            if not cell then cell = newObj("Square", 101) table.insert(self.objects, cell) self.selCells[idx] = cell end
            fill(cell, px + 4, ry, listW - 8, rowH, Theme.accent, 0.18, 2)
        elseif cell then
            put(cell, "Visible", false)
        end
        text(o, px + 8, ry + 3, clipText(opt.label, 14, listW - 18), 14, selected and Theme.accent or Theme.text, 1, false, false)
        newHit(px + 4, ry, listW - 8, rowH, {
            press = function()
                if self.multi then
                    self.value = self.value or {}
                    if self.value[opt.key] then self.value[opt.key] = nil else self.value[opt.key] = true end
                    self:Fire(self.value)
                else
                    self.value = opt.key
                    self:Fire(opt.key)
                    self:ClosePopup()
                end
            end,
        })
    end
    for i = vis + 1, #self.optTexts do put(self.optTexts[i], "Visible", false) end
    for i = vis + 1, #self.selCells do put(self.selCells[i], "Visible", false) end

    if showBar then
        local tx, ty, tw, th = px + pw - 9, py + 4, 6, ph - 8
        fill(self.scrollTrack, tx, ty, tw, th, Theme.main, 1, 3)
        put(self.scrollTrack, "Visible", true)
        local thumbH = max(18, floor(th * vis / total + 0.5))
        local frac = scrollMax > 0 and (self.scroll / scrollMax) or 0
        local thumbY = ty + (th - thumbH) * frac
        fill(self.scrollThumb, tx, thumbY, tw, thumbH, Theme.accent, 1, 3)
        put(self.scrollThumb, "Visible", true)
        local function scrollTo(yy)
            local f = clamp((yy - ty - thumbH / 2) / max(1, th - thumbH), 0, 1)
            self.scroll = floor(f * scrollMax + 0.5)
        end
        newHit(tx - 2, ty, tw + 4, th, {
            press = function(_, yy) scrollTo(yy) end,
            drag = function(_, yy) scrollTo(yy) end,
        })
    else
        put(self.scrollTrack, "Visible", false)
        put(self.scrollThumb, "Visible", false)
    end
end

-- Groupbox ------------------------------------------------------------------
local Groupbox = {}
Groupbox.__index = Groupbox

local function register(id, el, cat)
    Library.Options[id] = el
    if cat then cat[id] = el end
end

function Groupbox:AddToggle(id, cfg)
    cfg = cfg or {}
    local el = newElement(Toggle, id, cfg.Text or id)
    if cfg.Callback then table.insert(el.changed, cfg.Callback) end
    el.value = cfg.Default == true
    el.bg = mkSq(el, 20) el.label = mkText(el, 14) el.track = mkSq(el, 21) el.border = mkSq(el, 22) el.knob = mkSq(el, 23)
    table.insert(self.elements, el)
    register(id, el, Library.Toggles)
    if el.value then el:Fire(true) end
    return el
end
function Groupbox:AddCheckbox(id, cfg) return self:AddToggle(id, cfg) end
function Groupbox:AddSlider(id, cfg)
    cfg = cfg or {}
    local el = newElement(Slider, id, cfg.Text or id)
    if cfg.Callback then table.insert(el.changed, cfg.Callback) end
    el.min, el.max = cfg.Min or 0, cfg.Max or 100
    el.rounding = cfg.Rounding or 1
    el.prefix, el.suffix = cfg.Prefix, cfg.Suffix
    el.value = clamp(cfg.Default or el.min, el.min, el.max)
    el.bg, el.fill, el.border = mkSq(el, 20), mkSq(el, 21), mkSq(el, 22)
    el.label, el.valueText = mkText(el, 14), mkText(el, 14)
    el.thumb = mkSq(el, 23)
    table.insert(self.elements, el)
    register(id, el, Library.Sliders)
    el:Fire(el.value)
    return el
end
function Groupbox:AddButton(a, b)
    local id, cfg
    if type(a) == "table" and b == nil then cfg = a id = cfg.Id or cfg.Text or "Button"
    else id, cfg = a, b or {} end
    local el = newElement(Button, id, cfg.Text or id)
    el.func = cfg.Func or cfg.Callback
    el.bg, el.border, el.label = mkSq(el, 20), mkSq(el, 22), mkText(el, 14)
    table.insert(self.elements, el)
    register(id, el, Library.Buttons)
    return el
end
function Groupbox:AddLabel(a, b)
    local cfg = type(a) == "table" and a or { Text = a }
    local el = newElement(Label, cfg.Id or ("Label" .. #self.elements + 1), cfg.Text or "")
    el.wrap, el.size, el.color = cfg.DoesWrap == true, cfg.Size or 14, cfg.Color
    el.lines = {}
    table.insert(self.elements, el)
    return el
end
function Groupbox:AddDivider(cfg)
    if type(cfg) == "string" then cfg = { Text = cfg } end
    cfg = cfg or {}
    local el = newElement(Divider, "Divider" .. #self.elements + 1, cfg.Text or "")
    el.ln, el.lbl = mkLine(el), mkText(el, 14)
    table.insert(self.elements, el)
    return el
end
function Groupbox:AddDropdown(id, cfg)
    cfg = cfg or {}
    local el = newElement(Dropdown, id, cfg.Text or id)
    el.values = cfg.Values or cfg.Options or {}
    el.multi = cfg.Multi == true
    el.placeholder = cfg.Placeholder or "..."
    el.value = cfg.Default
    if type(el.value) == "number" and el.values[el.value] ~= nil then
        local opts = el:BuildOptions()
        el.value = opts[el.value] and opts[el.value].key or el.value
    else
        el:BuildOptions()
    end
    if cfg.Callback then table.insert(el.changed, cfg.Callback) end
    el.bg, el.border = mkSq(el, 20), mkSq(el, 22)
    el.label, el.valueText = mkText(el, 14), mkText(el, 14)
    el.chev1, el.chev2 = mkLine(el, 25), mkLine(el, 25)
    el.popupBg, el.popupBorder = mkSq(el, 100), mkSq(el, 101)
    el.scrollTrack, el.scrollThumb = mkSq(el, 101), mkSq(el, 102)
    el.maxVisible = cfg.MaxVisible
    el.scroll = 0
    el.optTexts, el.selCells = {}, {}
    table.insert(self.elements, el)
    table.insert(popupElements, el)
    register(id, el, Library.Dropdowns)
    return el
end
function Groupbox:AddInput(id, cfg)
    cfg = cfg or {}
    local el = newElement(Input, id, cfg.Text or id)
    el.value = tostring(cfg.Default or "")
    el.placeholder = cfg.Placeholder
    if cfg.Callback then table.insert(el.changed, cfg.Callback) end
    el.bg, el.border = mkSq(el, 20), mkSq(el, 22)
    el.label, el.valueText = mkText(el, 14), mkText(el, 14)
    el.caret = mkLine(el, 25)
    table.insert(self.elements, el)
    register(id, el, nil)
    return el
end
function Groupbox:AddKeyPicker(id, cfg)
    cfg = cfg or {}
    local el = newElement(KeyPicker, id, cfg.Text or id)
    el.vk = keyToVk(cfg.Default)
    el.mode = cfg.Mode or "Toggle"
    el.state = false
    el.changedCallback = cfg.ChangedCallback
    el.captureOnly = cfg.CaptureOnly == true
    if cfg.Callback then table.insert(el.changed, cfg.Callback) end
    el.bg, el.border, el.keyText = mkSq(el, 21), mkSq(el, 22), mkText(el, 14)
    el.label = mkText(el, 14)
    el.row = true
    el.modeOpen = false
    table.insert(self.elements, el)
    table.insert(popupElements, el)
    if not el.captureOnly then table.insert(Library.__keybinds, el) end
    register(id, el, Library.KeyPickers)
    return el
end
function Groupbox:AddColorPicker(id, cfg)
    cfg = cfg or {}
    local el = newElement(ColorPicker, id, cfg.Title or id)
    local c = cfg.Default or Theme.accent
    el.alpha = 1 - (cfg.Transparency or 0)
    el.swatch, el.swatchBorder = mkSq(el, 23), mkSq(el, 24)
    el.bg, el.border = mkSq(el, 20), mkSq(el, 22)
    el.label, el.hex = mkText(el, 14), mkText(el, 14)
    el.popupBg, el.popupBorder = mkSq(el, 100), mkSq(el, 101)
    el.svBase = mkSq(el, 101)   -- hue block behind the gradient, above the popup panel
    el.hexLabel = mkText(el, 14)
    el.hexBg, el.hexBorder = mkSq(el, 103), mkSq(el, 104)
    el.hexEditing = false
    el.alphaBG, el.alphaSwatch = mkSq(el, 103), mkSq(el, 104)
    zset(el.hexLabel, 107)
    el.h, el.s, el.v = rgbToHsv(c)
    el.value = c
    el.row = true
    if cfg.Callback then table.insert(el.changed, cfg.Callback) end
    table.insert(self.elements, el)
    table.insert(popupElements, el)
    register(id, el, Library.ColorPickers)
    return el
end
-- scroll culling helpers: an element that is outside the visible content
-- rect is hidden rather than drawn above or below the window
local function hideItem(o)
    if not o then return end
    if o.sc then o.sc.Visible = false end
    if o.d then o.d.Visible = false end
end

local function hideElement(el)
    if not el then return end
    for _, o in ipairs(el.objects or {}) do hideItem(o) end
    for _, a in ipairs(el.addons or {}) do
        for _, o in ipairs(a.objects or {}) do hideItem(o) end
    end
end

local function hideGroup(g)
    hideItem(g.bg)
    hideItem(g.border)
    hideItem(g.title)
    hideItem(g.descText)
    for _, el in ipairs(g.elements) do hideElement(el) end
end

function Groupbox:GetHeight(w)
    local h = 6 + 15 + (self.desc and self.desc ~= "" and 16 or 0) + 6
    local lw = w - 12
    for _, el in ipairs(self.elements) do
        if el.visible and not el.destroyed then h = h + el:GetHeight(lw) + 6 end
    end
    return h
end
function Groupbox:Render(x, y, w, clip)
    local h = self:GetHeight(w)
    -- strict clip: a box or row that is not fully inside the window content
    -- rect must not draw at all. The old check only hid things once they were
    -- completely out, so partial rows and box edges hung past the border.
    local vTop, vBottom = y, y + h
    if clip then
        vTop = max(y, clip.top)
        vBottom = min(y + h, clip.bottom)
        if vBottom - vTop < 0.5 then
            hideGroup(self)
            return h
        end
    end
    local cut = clip and (vTop > y or vBottom < y + h)
    fill(self.bg, x, vTop, w, vBottom - vTop, Theme.bg, 1, cut and 0 or Library.CornerRadius)
    stroke(self.border, x, vTop, w, vBottom - vTop, Theme.outline, 1, cut and 0 or Library.CornerRadius, 1)
    if clip and (y < clip.top or y + 21 > clip.bottom) then
        put(self.title, "Visible", false)
    else
        text(self.title, x + 10, y + 6, clipText(self.name, 15, w - 20), 15, Theme.text, 1, false, false)
    end
    if self.desc and self.desc ~= "" then
        if clip and (y + 22 < clip.top or y + 38 > clip.bottom) then
            put(self.descText, "Visible", false)
        else
            text(self.descText, x + 10, y + 22, clipText(self.desc, 14, w - 20), 14, Theme.subtext, 1, false, false)
        end
    else
        put(self.descText, "Visible", false)
    end
    local ey = y + 6 + 15 + (self.desc and self.desc ~= "" and 16 or 0) + 6
    for _, el in ipairs(self.elements) do
        if el.visible and not el.destroyed then
            local eh = el:GetHeight(w - 12)
            if clip and (ey < clip.top - 0.01 or ey + eh > clip.bottom + 0.01) then
                hideElement(el)
            elseif el.row and el.RenderRow then
                el:RenderRow(x + 6, ey, w - 12, eh)
            else
                el:Render(x + 6, ey, w - 12)
            end
            ey = ey + eh + 6
        end
    end
    return h
end
function Groupbox:RenderPopups()
    for _, el in ipairs(self.elements) do
        if el.RenderPopup then el:RenderPopup() end
        for _, a in ipairs(el.addons or {}) do
            if a.RenderPopup then a:RenderPopup() end
        end
    end
end
function Groupbox:Show() self.visible = true return self end
function Groupbox:Hide() self.visible = false return self end
function Groupbox:SetVisible(b) self.visible = b ~= false return self end

-- row renderers for standalone KeyPicker/ColorPicker
function KeyPicker:RenderRow(x, y, w)
    local bx, bw = x + w - 74, 68
    self.boxX, self.boxY, self.boxW, self.boxH = bx, y + 3, bw, 15
    fill(self.bg, x, y, w, 21, Theme.main, 1, 2)
    stroke(self.border, x, y, w, 21, Theme.outline, 1, 2, 1)
    if self.label then
        text(self.label, x + 6, vc(y, 21, 14), clipText(self.text, 14, w - 90), 14, Theme.text, 0.85, false, false)
    end
    textC(self.keyText, bx + bw / 2, vc(y + 3, 15, 14), clipText(capturing == self and "[...]" or vkName(self.vk), 14, bw - 6), 14, Theme.subtext, 1, false)
    if not self.captureOnly and hovered(bx, y + 3, bw, 15) and m2.pressed then
        self:OpenModePopup()
    end
    newHit(x, y, w, 21, {
        press = function()
            beginCapture(self)
            self:CloseModePopup()
        end,
    })
end
function ColorPicker:RenderRow(x, y, w)
    fill(self.bg, x, y, w, 21, Theme.main, 1, 2)
    stroke(self.border, x, y, w, 21, Theme.outline, 1, 2, 1)
    local c = self:Color()
    local hex = fmt("#%02X%02X%02X", floor(c.R * 255 + 0.5), floor(c.G * 255 + 0.5), floor(c.B * 255 + 0.5))
    text(self.label, x + 6, vc(y, 21, 14), clipText(self.text, 14, w - 96), 14, Theme.text, 0.85, false, false)
    text(self.hex, x + w - 84, vc(y, 21, 14), hex, 14, Theme.subtext, 1, false, false)
    -- always opaque: the chip is the only place the chosen colour is visible
    fill(self.swatch, x + w - 24, y + 3, 18, 18, c, 1, 2)
    stroke(self.swatchBorder, x + w - 24, y + 3, 18, 18, Theme.outline, 1, 2, 1)
    newHit(x, y, w, 21, { press = function() if self.popupOpen then self:ClosePopup() else self:OpenPopup() end end })
    self.hx, self.hy, self.hw = x + w - 24, y + 3, 18
end
Toggle.RenderRow = nil
Slider.RenderRow = nil

-- ui: window
local Tab = {}
Tab.__index = Tab
function Tab:AddGroupbox(a, b)
    local cfg = type(a) == "table" and a or { Side = a, Name = b }
    local side = cfg.Side
    if side == nil then side = "Left" end
    if type(side) == "string" then side = side:lower() == "right" and "Right" or "Left" end
    if side == 2 then side = "Right" elseif side == 1 then side = "Left" end
    local gb = setmetatable({}, Groupbox)
    gb.name = cfg.Name or "Groupbox"
    gb.desc = cfg.Description
    gb.side = side
    gb.visible = cfg.Visible ~= false
    gb.elements = {}
    gb.bg = newObj("Square", 10)
    gb.border = newObj("Square", 11)
    gb.title = newObj("Text", 12)
    gb.title.d.Size = 15
    gb.descText = newObj("Text", 12)
    gb.descText.d.Size = 14
    table.insert(self.groups, gb)
    return gb
end
function Tab:AddLeftGroupbox(name, cfg)
    cfg = cfg or {} cfg.Name = name cfg.Side = "Left"
    return self:AddGroupbox(cfg)
end
function Tab:AddRightGroupbox(name, cfg)
    cfg = cfg or {} cfg.Name = name cfg.Side = "Right"
    return self:AddGroupbox(cfg)
end
function Tab:Measure(w)
    local colW = w / 2 - 3
    local lh, rh = 0, 0
    for _, g in ipairs(self.groups) do
        if g.visible then
            local gh = g:GetHeight(colW) + 6
            if g.side == "Left" then lh = lh + gh else rh = rh + gh end
        end
    end
    return math.max(lh, rh)
end

function Tab:Render(x, y, w, clip, scroll)
    local colW = w / 2 - 3
    local top = y - (scroll or 0)
    local ly, ry = top, top
    for _, g in ipairs(self.groups) do
        if g.visible then
            if g.side == "Left" then ly = ly + g:Render(x, ly, colW, clip) + 6
            else ry = ry + g:Render(x + colW + 6, ry, colW, clip) + 6 end
        end
    end
end
function Tab:Hide()
    local function hideObj(o)
        o.sc.Visible = false
        o.d.Visible = false
    end
    for _, g in ipairs(self.groups) do
        hideObj(g.bg)
        hideObj(g.border)
        hideObj(g.title)
        hideObj(g.descText)
        for _, el in ipairs(g.elements) do
            for _, o in ipairs(el.objects) do hideObj(o) end
            for _, a in ipairs(el.addons or {}) do
                for _, o in ipairs(a.objects) do hideObj(o) end
            end
        end
    end
end
function Tab:SetVisible(b) self.visible = b ~= false return self end
function Tab:SetName(n) self.name = n return self end

local function applyTabFade(tab, m)
    if not tab or m >= 0.999 then return end
    local function visit(o)
        if not o or not o.d then return end
        local base = o.sc.alphaBase
        if base then
            local v = base * m
            o.d.Transparency = v
            o.sc.Transparency = v
        end
    end
    for _, g in ipairs(tab.groups) do
        visit(g.bg)
        visit(g.border)
        visit(g.title)
        visit(g.descText)
        for _, el in ipairs(g.elements) do
            for _, o in ipairs(el.objects) do visit(o) end
            for _, a in ipairs(el.addons or {}) do
                for _, o in ipairs(a.objects) do visit(o) end
            end
        end
    end
end

-- Window --------------------------------------------------------------------
local Window = {}
Window.__index = Window
function Window:AddTab(a, icon, desc)
    local cfg = type(a) == "table" and a or { Name = a, Icon = icon, Description = desc }
    local tab = setmetatable({}, Tab)
    tab.window = self
    tab.name = cfg.Name or "Tab"
    tab.icon = cfg.Icon
    tab.description = cfg.Description
    tab.groups = {}
    tab.visible = true
    tab.sel = newObj("Square", 6)
    tab.indicator = newObj("Square", 7)
    tab.label = newObj("Text", 8)
    tab.label.d.Size = 16
    table.insert(self.tabs, tab)
    if not self.activeTab then self.activeTab = tab end
    return tab
end
function Window:SelectTab(tab)
    if type(tab) == "number" then tab = self.tabs[tab] end
    if not tab or tab.window ~= self then return self end
    if self.activeTab ~= tab then
        if self.activeTab then self.activeTab:Hide() end
        self.activeTab = tab
        clearPopup()
        focusedInput = nil
        capturing = nil
        self.tabFade = 0
        self.scroll = 0
    end
    return self
end
function Window:SetTitle(t) self.title = tostring(t) return self end
function Window:ChangeTitle(t) return self:SetTitle(t) end
function Window:SetFooter(t) self.footer = tostring(t) return self end
function Window:Toggle(force)
    local v = force
    if v == nil then v = not self.visible end
    self.visible = v and true or false
    if self.visible then
        self.tabFade = 0
    else
        hideAll()
        clearPopup()
        focusedInput = nil
        capturing = nil
    end
    pcall(setrobloxinput, true)
    return self
end
function Window:Open() return self:Toggle(true) end
function Window:Close() return self:Toggle(false) end
function Window:SetPos(px, py)
    local cam = uiCamera()
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    self.x = clamp(px, -self.w + 80, vp.X - 80)
    self.y = clamp(py, 0, vp.Y - 40)
    self.tabSelY, self.tabSelH = nil, nil
    return self
end
function Window:SetSize(w, h)
    self.w, self.h = w, h
    self.sideW = floor(w * 0.3 + 0.5)
    self.tabSelY, self.tabSelH = nil, nil
    return self
end

function Window:ScrollToY(py, barY, barH, thumbH)
    local span = math.max(1, barH - thumbH)
    local f = clamp((py - barY - thumbH * 0.5) / span, 0, 1)
    self.scroll = f * (self.scrollMax or 0)
    return self
end
function Window:Center()
    local cam = uiCamera()
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    self:SetPos((vp.X - self.w) / 2, (vp.Y - self.h) / 2)
    return self
end
function Window:Render()
    -- fit before drawing: sizing mid-frame leaves the chrome at the old rect.
    -- Grow once to the tallest tab, bounded by the viewport; a manual resize
    -- below the content hands over to the scrollbar.
    if self.activeTab and not self.autoSized and not self.userSized then
        local cw = self.w - self.sideW - 16
        local tallest = self.activeTab:Measure(cw)
        for _, tb in ipairs(self.tabs) do
            local m = tb:Measure(cw)
            if m > tallest then tallest = m end
        end
        local cam = uiCamera()
        local vpY = (cam and cam.ViewportSize and cam.ViewportSize.Y) or 1080
        local want = math.min(tallest + self.titleH + 30, vpY - 40)
        if want > self.h then
            self:SetSize(self.w, want)
            self:Center()
        end
        self.autoSized = true
    end

    local x, y, w, h = self.x, self.y, self.w, self.h
    local titleH = self.titleH
    local sideW = self.sideW
    fill(self.shadow, x - 3, y - 3, w + 6, h + 8, Theme.dark, 0.22, Library.CornerRadius + 4)
    fill(self.bg, x, y, w, h, Theme.bg, 1, Library.CornerRadius)
    stroke(self.border, x, y, w, h, Theme.outline, 1, Library.CornerRadius, 1)
    fill(self.hline, x + sideW, y + titleH, w - sideW, 1, Theme.outline, 1, 0)
    fill(self.vline, x + sideW, y + titleH, 1, h - titleH, Theme.outline, 1, 0)
    local lg = LogoImage or ensureLogo()
    local acc, bgc = Theme.accent, Theme.bg
    local lkey = floor(acc.R * 255) .. "," .. floor(acc.G * 255) .. "," .. floor(acc.B * 255)
        .. "|" .. floor(bgc.R * 255) .. "," .. floor(bgc.G * 255) .. "," .. floor(bgc.B * 255)
    if LogoKey ~= lkey then
        LogoKey = lkey
        lg.d.Data = buildLogoBmp(48, bgc, acc)
    end
    lg.d.Position = Vector2.new(x + 10, y + (titleH - 24) / 2)
    lg.d.Size = Vector2.new(24, 24)
    put(lg, "Visible", true)
    text(self.titleText, x + 40, vc(y, titleH, 15), clipText(self.title, 15, w - 88), 15, Theme.text, 1, false, false)
    put(self.footerText, "Visible", false)
    local cbx, cby = x + w - 20, vc(y, titleH, 8)
    local chv = hovered(cbx - 4, cby - 4, 20, 16)
    line(self.close1, cbx, cby, cbx + 8, cby + 8, chv and Theme.danger or Theme.subtext, 1, 1)
    line(self.close2, cbx + 8, cby, cbx, cby + 8, chv and Theme.danger or Theme.subtext, 1, 1)
    newHit(cbx - 6, cby - 6, 22, 20, { press = function() self:Toggle(false) end })

    local ty = y + titleH
    local selTargetY, selTargetH
    for _, tab in ipairs(self.tabs) do
        if tab.visible then
            local th = 40
            local active = (self.activeTab == tab)
            local hv = hovered(x, ty, sideW, th)
            if active then
                put(tab.sel, "Visible", false)
                put(tab.indicator, "Visible", false)
                selTargetY, selTargetH = ty, th
            elseif hv then
                fill(tab.sel, x, ty, sideW, th, Theme.main, 0.5, 0)
                put(tab.indicator, "Visible", false)
            else
                put(tab.sel, "Visible", false)
                put(tab.indicator, "Visible", false)
            end
            text(tab.label, x + 30, ty + 11, clipText(tab.name, 16, sideW - 38), 16, active and Theme.text or Theme.subtext, active and 1 or 0.55, false, false)
            newHit(x, ty, sideW, th, {
                press = function()
                    self:SelectTab(tab)
                end,
            })
            ty = ty + th
        end
    end
    if selTargetY then
        if self.tabSelY == nil or not Library.Animations.Enabled then
            self.tabSelY, self.tabSelH = selTargetY, selTargetH
        else
            self.tabSelY = approach(self.tabSelY, selTargetY, Library.Animations.TabSlide, FRAME_DT)
            self.tabSelH = approach(self.tabSelH, selTargetH, Library.Animations.TabSlide, FRAME_DT)
        end
        fill(self.tabSelFill, x, self.tabSelY, sideW, self.tabSelH, mix(Theme.bg, Theme.accent, 0.10), 1, 0)
        fill(self.tabSelBar, x, self.tabSelY, 2, self.tabSelH, Theme.accent, 1, 0)
    else
        put(self.tabSelFill, "Visible", false)
        put(self.tabSelBar, "Visible", false)
    end

    local cx, cy = x + sideW + 4, y + titleH + 4
    local cw, ch = w - sideW - 16, h - titleH - 8
    if self.activeTab then
        local contentH = self.activeTab:Measure(cw)

        local scrollMax = contentH - ch
        if scrollMax < 0 then scrollMax = 0 end
        self.scrollMax = scrollMax
        self.scroll = clamp(self.scroll or 0, 0, scrollMax)
        self.activeTab:Render(cx, cy, cw, { top = cy, bottom = cy + ch }, self.scroll)

        -- scrollbar: the moment anything is clipped, even by a pixel
        if scrollMax > 0.01 then
            local barX, barY, barW, barH = x + w - 12, cy, 5, ch
            fill(self.scrollTrack, barX, barY, barW, barH, Theme.main, 0.55, 3)
            put(self.scrollTrack, "Visible", true)
            local thumbH = math.max(28, barH * (ch / contentH))
            local span = barH - thumbH
            local frac = scrollMax > 0 and (self.scroll / scrollMax) or 0
            local thumbY = barY + span * frac
            fill(self.scrollThumb, barX, thumbY, barW, thumbH, Theme.accent, 1, 3)
            put(self.scrollThumb, "Visible", true)
            newHit(barX - 4, barY, barW + 8, barH, {
                press = function(_, py) self:ScrollToY(py, barY, barH, thumbH) end,
                drag = function(_, py) self:ScrollToY(py, barY, barH, thumbH) end,
            })
        else
            put(self.scrollTrack, "Visible", false)
            put(self.scrollThumb, "Visible", false)
        end
    end

    newHit(x, y, w - 28, titleH, {
        press = function(px, py) self.dragOff = { px - x, py - y } end,
        drag = function(px, py)
            if self.dragOff then self:SetPos(px - self.dragOff[1], py - self.dragOff[2]) end
        end,
        release = function() self.dragOff = nil end,
    })
    newHit(x + w - 16, y + h - 16, 16, 16, {
        press = function(px, py) self.sizeOff = { w - (px - x), h - (py - y) } end,
        drag = function(px, py)
            if self.sizeOff then
                self.userSized = true
                self:SetSize(max(480, px - x + self.sizeOff[1]), max(360, py - y + self.sizeOff[2]))
            end
        end,
        release = function() self.sizeOff = nil end,
    })
end

Library.__keybinds = {}

function Library:BuildNotificationSettings(Tab)
    local opts = Library.NotificationOptions
    local group = Tab:AddGroupbox({ Side = "Left", Name = "Notifications" })
    group:AddToggle("Notify_Enabled", {
        Text = "Enable notifications",
        Default = opts.Enabled,
        Callback = function(v)
            Library.NotificationOptions.Enabled = v
        end,
    })
    group:AddSlider("Notify_Duration", {
        Text = "Duration",
        Default = opts.Duration,
        Min = 1, Max = 20, Rounding = 0.5, Suffix = "s",
        Callback = function(v)
            Library.NotificationOptions.Duration = v
            for _, n in ipairs(notifs) do n.dur = v end
        end,
    })
    group:AddSlider("Notify_Fade", {
        Text = "Fade time",
        Default = opts.Fade,
        Min = 0, Max = 2, Rounding = 0.05, Suffix = "s",
        Callback = function(v) Library.NotificationOptions.Fade = v end,
    })
    group:AddSlider("Notify_Width", {
        Text = "Width",
        Default = opts.Width,
        Min = 180, Max = 420, Rounding = 1, Suffix = "px",
        Callback = function(v) Library.NotificationOptions.Width = v end,
    })
    group:AddSlider("Notify_Max", {
        Text = "Max visible",
        Default = opts.MaxVisible,
        Min = 1, Max = 10, Rounding = 1,
        Callback = function(v)
            Library.NotificationOptions.MaxVisible = v
            while #notifs > v do removeNotif(table.remove(notifs)) end
        end,
    })
    group:AddSlider("Notify_OffsetY", {
        Text = "Top offset",
        Default = opts.OffsetY,
        Min = 0, Max = 200, Rounding = 1, Suffix = "px",
        Callback = function(v) Library.NotificationOptions.OffsetY = v end,
    })
    group:AddDropdown("Notify_Side", {
        Text = "Side",
        Values = { "Right", "Left" },
        Default = Library.NotifySide,
        Callback = function(v) Library.NotifySide = v end,
    })
    group:AddToggle("Notify_UseCall", {
        Text = "Per-call duration",
        Default = opts.UseCallDuration,
        Callback = function(v) Library.NotificationOptions.UseCallDuration = v end,
    })
    group:AddButton({
        Text = "Test Notification",
        Func = function() Library:Notify("This is a test notification.", nil, "Test") end,
    })
    group:AddButton({
        Text = "Preview (ignores Enabled)",
        Func = function() Library:PreviewNotification() end,
    })
    group:AddButton({
        Text = "Clear Notifications",
        Func = function() Library:ClearNotifications() end,
    })
    group:AddButton({
        Text = "Reset Defaults",
        Func = function()
            local function set(id, v)
                local el = Library.Options[id]
                if el then el:SetValue(v) end
            end
            set("Notify_Enabled", true)
            set("Notify_Duration", 4)
            set("Notify_Fade", 0.35)
            set("Notify_Width", 260)
            set("Notify_Max", 6)
            set("Notify_OffsetY", 16)
            set("Notify_UseCall", false)
            local side = Library.Options.Notify_Side
            if side then side:SetValue("Right") end
            Library.NotifySide = "Right"
        end,
    })
    return group
end

function Library:CreateWindow(cfg)
    cfg = cfg or {}
    if cfg.Accent then Theme.accent = cfg.Accent end
    if cfg.CornerRadius then Library.CornerRadius = cfg.CornerRadius end
    local win = setmetatable({}, Window)
    win.title = cfg.Title or "No Title"
    win.footer = cfg.Footer or ""
    win.w = cfg.Width or 720
    win.h = cfg.Height or 600
    win.titleH = 36
    win.sideW = floor(win.w * 0.3 + 0.5)
    win.x, win.y = 100, 100
    win.tabs, win.activeTab = {}, nil
    win.tabFade = 0
    win.scroll, win.scrollMax = 0, 0
    win.scrollTrack = newObj("Square", 9)
    win.scrollThumb = newObj("Square", 10)
    win.visible = cfg.AutoShow ~= false
    win.bg = newObj("Square", 2)
    win.border = newObj("Square", 3)
    win.tabSelFill = newObj("Square", 6)
    win.tabSelBar = newObj("Square", 7)
    win.shadow = newObj("Square", 1)
    win.hline = newObj("Square", 4)
    win.vline = newObj("Square", 4)
    win.titleText = newObj("Text", 6)
    win.titleText.d.Size = 15
    win.footerText = newObj("Text", 6)
    win.footerText.d.Size = 14
    win.close1 = newObj("Line", 7)
    win.close2 = newObj("Line", 7)
    table.insert(Windows, win)
    if cfg.Center ~= false then win:Center() end
    if cfg.ToggleKeybind then
        local vk = keyToVk(cfg.ToggleKeybind)
        if vk then menuVk = vk end
    end
    Library.NotifySide = cfg.NotifySide or "Right"
    pcall(setrobloxinput, true)
    return win
end

-- Render loop ---------------------------------------------------------------
local stopped = false
local function resolveRS()
    local rs = hostGet("RunService") or RS
    if not rs then pcall(function() rs = game:GetService("RunService") end) end
    if not rs then pcall(function() rs = game.RunService end) end
    return rs
end
local function trySignal(sig, cb)
    if not sig then return nil end
    local ok, conn = pcall(function() return sig:Connect(cb) end)
    if ok and conn then return conn end
    local ok2, conn2 = pcall(function() return sig.Connect(sig, cb) end)
    if ok2 and conn2 then return conn2 end
    return nil
end
local function connectRender(cb)
    local rs = resolveRS()
    if rs then
        for _, name in ipairs({ "RenderStepped", "Heartbeat", "Stepped" }) do
            local sig
            pcall(function() sig = rs[name] end)
            local conn = trySignal(sig, cb)
            if conn then return conn, name end
        end
    end
    local alive = true
    local conn = { Disconnect = function() alive = false end }
    task.spawn(function()
        while alive and not stopped do cb(0) task.wait(1 / 60) end
    end)
    return conn, "poll"
end

local function win0Text()
    return "Swangy"
end

local function tickLoop(dt)
    if stopped then return end
    FRAME_DT = 1 / 60
    if type(dt) == "number" and dt > 0 then
        FRAME_DT = min(dt, 0.1)
    end
    local ok, err = pcall(function()
        poll()
        if capturing then
            for _, code in ipairs(ALL_KEYS) do
                if keyEdge(code) then
                    capturing:Capture(code)
                    break
                end
            end
        end
        if focusedInput == nil and not capturing and isrbxactive() and keyEdge(menuVk) then
            local win = Windows[1]
            if win then win:Toggle() end
        end
        for _, kb in ipairs(Library.__keybinds) do
            if not capturing and kb.visible and not kb.destroyed then kb:Evaluate() end
        end
        if focusedInput and not capturing then
            for _, code in ipairs(INPUT_CODES) do
                if keyEdge(code) then focusedInput:Key(code) end
            end
        end
        hitList = {}
        local anyVisible = false
        for _, win in ipairs(Windows) do
            if win.visible then anyVisible = true win:Render() end
        end
        if watermarkOn then
            local wm = Library.__wm
            if not wm then
                wm = { bg = D.new("Square"), txt = D.new("Text") }
                wm.bg.Filled, wm.bg.Corner = true, 2
                wm.txt.Size = 14
                pcall(function() wm.txt.Font = FONT wm.bg.ZIndex = 200 wm.txt.ZIndex = 201 end)
                Library.__wm = wm
                local reg = _G.__swangy_wms
                reg[#reg + 1] = wm
            end
            local cam = uiCamera()
            local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
            local pos = Library.__wmPos or { x = 10, y = 10 }
            local s = win0Text()
            local w, h = textW(s, 14) + 16, 22
            pos.x = clamp(pos.x, 0, max(0, vp.X - w))
            pos.y = clamp(pos.y, 0, max(0, vp.Y - h))
            Library.__wmPos = pos
            wm.bg.Position, wm.bg.Size = Vector2.new(pos.x, pos.y), Vector2.new(w, h)
            wm.bg.Color, wm.bg.Transparency, wm.bg.Visible = Theme.main, 0.9, true
            wm.txt.Position, wm.txt.Text, wm.txt.Color, wm.txt.Visible = Vector2.new(pos.x + 8, pos.y + 3), s, Theme.text, true
            newHit(pos.x, pos.y, w, h, {
                press = function(px, py) Library.__wmDrag = { dx = px - pos.x, dy = py - pos.y } end,
                drag = function(px, py)
                    local d = Library.__wmDrag
                    if d then
                        Library.__wmPos = {
                            x = clamp(px - d.dx, 0, max(0, vp.X - w)),
                            y = clamp(py - d.dy, 0, max(0, vp.Y - h)),
                        }
                    end
                end,
                release = function() Library.__wmDrag = nil end,
            })
        elseif Library.__wm then
            Library.__wm.bg.Visible, Library.__wm.txt.Visible = false, false
        end
        if anyVisible then
            local win = Windows[1]
            if win then
                local dur = Library.Animations.TabFade or 0
                if not Library.Animations.Enabled or dur <= 0 then
                    win.tabFade = 1
                elseif win.tabFade < 1 then
                    win.tabFade = min(1, win.tabFade + FRAME_DT / dur)
                end
                if win.activeTab and win.tabFade < 1 then
                    local e = 1 - (1 - win.tabFade) ^ 3
                    applyTabFade(win.activeTab, e)
                end
                if win.activeTab then
                    for _, g in ipairs(win.activeTab.groups) do g:RenderPopups() end
                end
            end
        end
        Library.__hits = hitList
        processInput()
        renderNotifs()
    end)
    if not ok then
        local msg = tostring(err)
        _G.__swangy_err = msg
        if _G.__swangy_lastwarn ~= msg then
            _G.__swangy_lastwarn = msg
            warn("[Swangy] frame error: " .. msg)
        end
    end
    _G.__swangy_frames = (_G.__swangy_frames or 0) + 1
end

local uiConn, uiSignal
local connOk, connRes, connName = pcall(connectRender, tickLoop)
if connOk then uiConn, uiSignal = connRes, connName
else uiConn = { Disconnect = function() end } end
Library.RenderSignal = uiSignal

function Library:Unload()
    stopped = true
    focusedInput = nil
    capturing = nil
    pcall(function() uiConn:Disconnect() end)
    for _, o in ipairs(ALL) do pcall(function() o.d:Remove() end) end
    for _, n in ipairs(notifs) do
        removeDrawings({ { d = n.bg }, { d = n.bar }, { d = n.tt }, { d = n.mt } })
    end
    notifs = {}
    if Library.__wm then
        pcall(function() Library.__wm.bg:Remove() end)
        pcall(function() Library.__wm.txt:Remove() end)
        Library.__wm = nil
    end
    pcall(function() MEAS:Remove() end)
end

do
    local reg = _G.__swangy_instances
    reg[#reg + 1] = Library
end

return Library
]=====],
    ["SwangyThemeManager.lua"] = [=====[
-- SwangyThemeManager for Swangy
-- Port of Obsidian's addons/ThemeManager.lua built-in themes + custom theme
-- storage, applied to the Drawing library's live Theme table.
--
--   local _ = loadstring(readfile("SwangyThemeManager.lua"))()
--   local ThemeManager = _G.SwangyThemeManager
--   ThemeManager:SetLibrary(_G.Swangy)
--   ThemeManager:BuildConfigSection(_G.Swangy:GetWindow().tabs[5])

local ThemeManager = {}
_G.SwangyThemeManager = ThemeManager
_G.ObsidianThemeManager = ThemeManager -- legacy alias

local Library
local Folder = "Swangy"
local SubFolder = "CustomThemes"

ThemeManager.BuiltInThemes = {
    ["Default"] = { 1, { FontColor = "ffffff", MainColor = "191919", AccentColor = "7d55ff", BackgroundColor = "0f0f0f", OutlineColor = "282828" } },
    ["BBot"] = { 2, { FontColor = "ffffff", MainColor = "1e1e1e", AccentColor = "7e48a3", BackgroundColor = "232323", OutlineColor = "141414" } },
    ["Fatality"] = { 3, { FontColor = "ffffff", MainColor = "1e1842", AccentColor = "c50754", BackgroundColor = "191335", OutlineColor = "3c355d" } },
    ["Jester"] = { 4, { FontColor = "ffffff", MainColor = "242424", AccentColor = "db4467", BackgroundColor = "1c1c1c", OutlineColor = "373737" } },
    ["Mint"] = { 5, { FontColor = "ffffff", MainColor = "242424", AccentColor = "3db488", BackgroundColor = "1c1c1c", OutlineColor = "373737" } },
    ["Tokyo Night"] = { 6, { FontColor = "ffffff", MainColor = "191925", AccentColor = "6759b3", BackgroundColor = "16161f", OutlineColor = "323232" } },
    ["Ubuntu"] = { 7, { FontColor = "ffffff", MainColor = "3e3e3e", AccentColor = "e2581e", BackgroundColor = "323232", OutlineColor = "191919" } },
    ["Quartz"] = { 8, { FontColor = "ffffff", MainColor = "232330", AccentColor = "426e87", BackgroundColor = "1d1b26", OutlineColor = "27232f" } },
    ["Nord"] = { 9, { FontColor = "eceff4", MainColor = "3b4252", AccentColor = "88c0d0", BackgroundColor = "2e3440", OutlineColor = "4c566a" } },
    ["Dracula"] = { 10, { FontColor = "f8f8f2", MainColor = "44475a", AccentColor = "ff79c6", BackgroundColor = "282a36", OutlineColor = "6272a4" } },
    ["Monokai"] = { 11, { FontColor = "f8f8f2", MainColor = "272822", AccentColor = "f92672", BackgroundColor = "1e1f1c", OutlineColor = "49483e" } },
    ["Gruvbox"] = { 12, { FontColor = "ebdbb2", MainColor = "3c3836", AccentColor = "fb4934", BackgroundColor = "282828", OutlineColor = "504945" } },
    ["Solarized"] = { 13, { FontColor = "839496", MainColor = "073642", AccentColor = "cb4b16", BackgroundColor = "002b36", OutlineColor = "586e75" } },
    ["Catppuccin"] = { 14, { FontColor = "d9e0ee", MainColor = "302d41", AccentColor = "f5c2e7", BackgroundColor = "1e1e2e", OutlineColor = "575268" } },
    ["One Dark"] = { 15, { FontColor = "abb2bf", MainColor = "282c34", AccentColor = "c678dd", BackgroundColor = "21252b", OutlineColor = "5c6370" } },
    ["Cyberpunk"] = { 16, { FontColor = "f9f9f9", MainColor = "262335", AccentColor = "00ff9f", BackgroundColor = "1a1a2e", OutlineColor = "413c5e" } },
    ["Oceanic Next"] = { 17, { FontColor = "d8dee9", MainColor = "1b2b34", AccentColor = "6699cc", BackgroundColor = "16232a", OutlineColor = "343d46" } },
    ["Material"] = { 18, { FontColor = "eeffff", MainColor = "212121", AccentColor = "82aaff", BackgroundColor = "151515", OutlineColor = "424242" } },
}

local function jsonEncode(t)
    local hs
    pcall(function() hs = game:GetService("HttpService") end)
    if hs then
        local ok, res = pcall(function() return hs:JSONEncode(t) end)
        if ok then return res end
    end
end
local function jsonDecode(s)
    local hs
    pcall(function() hs = game:GetService("HttpService") end)
    if hs then
        local ok, res = pcall(function() return hs:JSONDecode(s) end)
        if ok then return res end
    end
end

local function toColor(v)
    if typeof and typeof(v) == "Color3" then return v end
    if type(v) == "table" and v.R then return Color3.new(v.R, v.G, v.B) end
    if type(v) == "string" then
        local ok, c = pcall(function() return Color3.fromHex(v) end)
        if ok and c then return c end
    end
    return nil
end
local function toHex(c)
    local function p(x) return string.format("%02x", math.floor(x * 255 + 0.5)) end
    return p(c.R) .. p(c.G) .. p(c.B)
end
local function mix(a, b, t)
    return Color3.fromRGB(
        math.floor(a.R * 255 + (b.R * 255 - a.R * 255) * t + 0.5),
        math.floor(a.G * 255 + (b.G * 255 - a.G * 255) * t + 0.5),
        math.floor(a.B * 255 + (b.B * 255 - a.B * 255) * t + 0.5)
    )
end

local function base() return Folder .. "/" .. SubFolder end
local function ensureTree()
    if not isfolder(Folder) then pcall(makefolder, Folder) end
    if not isfolder(base()) then pcall(makefolder, base()) end
    return base()
end
local function safeName(n)
    n = tostring(n or "theme"):gsub("[^%w%-_ ]", "")
    if n == "" then n = "theme" end
    return n
end

function ThemeManager:SetLibrary(lib)
    Library = lib
    return self
end
function ThemeManager:SetFolder(f) Folder = tostring(f) return self end
function ThemeManager:SetSubFolder(f) SubFolder = tostring(f) return self end
function ThemeManager:GetPaths() return { ensureTree() } end
function ThemeManager:BuildFolderTree() ensureTree() return self end
function ThemeManager:CheckFolderTree() ensureTree() return self end
function ThemeManager:ThemeUpdate() return self end

function ThemeManager:ApplyThemeData(data)
    if not Library then return false, "library not set" end
    if type(data) == "table" and data[2] and type(data[2]) == "table" then data = data[2] end
    if type(data) ~= "table" then return false, "invalid theme data" end
    local T = Library.Theme
    local bg = toColor(data.BackgroundColor) or T.bg
    local main = toColor(data.MainColor) or T.main
    local accent = toColor(data.AccentColor) or T.accent
    local outline = toColor(data.OutlineColor) or T.outline
    local font = toColor(data.FontColor) or T.text
    T.bg, T.main, T.accent, T.outline, T.text = bg, main, accent, outline, font
    T.panel, T.panel2, T.stroke, T.track, T.sidebar = bg, main, outline, main, bg
    T.strokeLit = mix(outline, font, 0.15)
    T.subtext = mix(font, bg, 0.5)
    T.dim = mix(font, bg, 0.35)
    T.disabled = mix(font, bg, 0.6)
    T.white = font
    if data.CornerRadius then Library.CornerRadius = data.CornerRadius end
    return true
end

function ThemeManager:ApplyTheme(name)
    local data = self:GetCustomTheme(name) or self.BuiltInThemes[name]
    if not data then return false, "theme not found" end
    return self:ApplyThemeData(data)
end

function ThemeManager:CurrentThemeData()
    local T = Library and Library.Theme
    if not T then return nil end
    return {
        FontColor = toHex(T.text),
        MainColor = toHex(T.main),
        AccentColor = toHex(T.accent),
        BackgroundColor = toHex(T.bg),
        OutlineColor = toHex(T.outline),
    }
end

function ThemeManager:ReloadCustomThemes()
    ensureTree()
    local out = {}
    local ok, files = pcall(listfiles, base())
    if ok then
        for _, path in ipairs(files or {}) do
            local name = tostring(path):match("([^/\\]+)%.json$")
            if name then out[#out + 1] = name end
        end
    end
    table.sort(out)
    return out
end

function ThemeManager:GetCustomTheme(name)
    local path = base() .. "/" .. safeName(name) .. ".json"
    if not isfile(path) then return nil end
    local ok, content = pcall(readfile, path)
    if not ok then return nil end
    return jsonDecode(content)
end

function ThemeManager:SaveCustomTheme(name)
    ensureTree()
    local data = self:CurrentThemeData()
    local encoded = jsonEncode(data)
    if not encoded then return false, "JSONEncode unavailable" end
    local ok, err = pcall(writefile, base() .. "/" .. safeName(name) .. ".json", encoded)
    if not ok then return false, tostring(err) end
    return true
end

function ThemeManager:Delete(name)
    local path = base() .. "/" .. safeName(name) .. ".json"
    if not isfile(path) then return false, "theme not found" end
    pcall(delfile, path)
    return true
end

function ThemeManager:GetDefaultTheme()
    local path = Folder .. "/defaulttheme.txt"
    if not isfile(path) then return nil end
    local ok, content = pcall(readfile, path)
    if not ok then return nil end
    return (tostring(content):gsub("%s+$", ""))
end
function ThemeManager:SaveDefault(ThemeName)
    ensureTree()
    local ok, err = pcall(writefile, Folder .. "/defaulttheme.txt", safeName(ThemeName))
    if not ok then return false, tostring(err) end
    return true
end
function ThemeManager:LoadDefault()
    local name = self:GetDefaultTheme()
    if not name or name == "" then return false, "no default theme" end
    return self:ApplyTheme(name)
end
function ThemeManager:DeleteDefaultTheme()
    local path = Folder .. "/defaulttheme.txt"
    if not isfile(path) then return false, "no default theme" end
    pcall(delfile, path)
    return true
end

local function themeNames()
    local names = {}
    for name in pairs(ThemeManager.BuiltInThemes) do names[#names + 1] = name end
    for _, name in ipairs(ThemeManager:ReloadCustomThemes()) do
        if not ThemeManager.BuiltInThemes[name] then names[#names + 1] = name end
    end
    table.sort(names)
    for i, name in ipairs(names) do
        if name == "Default" then
            table.remove(names, i)
            table.insert(names, 1, "Default")
            break
        end
    end
    return names
end

function ThemeManager:GetThemes()
    return themeNames()
end

local function build(group)
    local savedDefault = ThemeManager:GetDefaultTheme()
    local dd = group:AddDropdown("ThemeManager_ThemeList", {
        Text = "Theme",
        Values = themeNames(),
        Default = savedDefault or "Default",
        MaxVisible = 8,
        Callback = function(name)
            if name then
                ThemeManager:ApplyTheme(name)
                if Library then Library:Notify("Theme: " .. tostring(name), 2, "Theme") end
            end
        end,
    })
    local function refresh()
        dd:SetValues(themeNames())
    end
    group:AddButton({
        Text = "Apply Theme",
        Func = function()
            if not dd.value then return end
            local ok, err = ThemeManager:ApplyTheme(dd.value)
            if Library then Library:Notify(ok and ("Theme: " .. dd.value) or ("Theme failed: " .. tostring(err)), 3, "Theme") end
        end,
    })
    group:AddButton({
        Text = "Save Current As New",
        Func = function()
            local name = "theme-" .. tostring(os.date and os.date("%Y%m%d-%H%M%S") or math.floor(tick()))
            local ok = ThemeManager:SaveCustomTheme(name)
            refresh()
            if ok then dd.value = name end
            if Library then Library:Notify(ok and ("Saved theme " .. name) or "Theme save failed", 3, "Theme") end
        end,
    })
    group:AddButton({
        Text = "Save As Default",
        Func = function()
            if not dd.value then return end
            ThemeManager:SaveDefault(dd.value)
            if Library then Library:Notify("Default theme: " .. dd.value, 3, "Theme") end
        end,
    })
    group:AddButton({
        Text = "Load Default",
        Func = function()
            local ok, err = ThemeManager:LoadDefault()
            if Library then Library:Notify(ok and "Loaded default theme" or tostring(err), 3, "Theme") end
        end,
    })
    group:AddButton({
        Text = "Delete Theme",
        Func = function()
            if not dd.value then return end
            local ok, err = ThemeManager:Delete(dd.value)
            refresh()
            if Library then Library:Notify(ok and ("Deleted " .. dd.value) or tostring(err), 3, "Theme") end
        end,
    })
    group:AddButton({ Text = "Refresh Themes", Func = refresh })
    return group
end

function ThemeManager:BuildConfigSection(Tab)
    local group = Tab:AddGroupbox({ Side = "Left", Name = "Themes" })
    build(group)
    local saved = self:GetDefaultTheme()
    if saved then
        pcall(function() self:ApplyTheme(saved) end)
    end
    return group
end

function ThemeManager:ApplyToTab(Tab)
    return self:BuildConfigSection(Tab)
end

function ThemeManager:ApplyToGroupbox(group)
    return build(group)
end

return ThemeManager
]=====],
    ["SwangySaveManager.lua"] = [=====[
-- SwangySaveManager for Swangy
-- Port of Obsidian's addons/SaveManager.lua core (JSON configs + config tab),
-- built on Matcha file APIs and the Drawing UI.
--
--   local _ = loadstring(readfile("SwangySaveManager.lua"))()
--   local SaveManager = _G.SwangySaveManager
--   SaveManager:SetLibrary(_G.Swangy)
--   SaveManager:BuildConfigSection(_G.Swangy:GetWindow().tabs[1], "settings")

local SaveManager = {}
_G.SwangySaveManager = SaveManager
_G.ObsidianSaveManager = SaveManager -- legacy alias

local Library
local Folder = "Swangy"
local SubFolder = "Configs"
local IgnoreIndexes = {}
local LoadingOrder = nil

local function jsonEncode(t)
    local hs
    pcall(function() hs = game:GetService("HttpService") end)
    if hs then
        local ok, res = pcall(function() return hs:JSONEncode(t) end)
        if ok then return res end
    end
    return nil, "JSONEncode unavailable"
end

local function jsonDecode(s)
    local hs
    pcall(function() hs = game:GetService("HttpService") end)
    if hs then
        local ok, res = pcall(function() return hs:JSONDecode(s) end)
        if ok then return res end
    end
    return nil, "JSONDecode unavailable"
end

local function base()
    return Folder .. "/" .. SubFolder
end

local function ensureTree()
    if not isfolder(Folder) then pcall(makefolder, Folder) end
    local p = base()
    if not isfolder(p) then pcall(makefolder, p) end
    return p
end

local function safeName(name)
    name = tostring(name or "default")
    name = name:gsub("[^%w%-_ ]", "")
    if name == "" then name = "default" end
    return name
end

function SaveManager:SetLibrary(lib)
    Library = lib
    return self
end
function SaveManager:SetFolder(f)
    Folder = tostring(f)
    return self
end
function SaveManager:SetSubFolder(f)
    SubFolder = tostring(f)
    return self
end
function SaveManager:GetPaths()
    return { ensureTree() }
end
function SaveManager:BuildFolderTree()
    ensureTree()
    return self
end
function SaveManager:CheckFolderTree()
    ensureTree()
    return self
end
function SaveManager:CheckSubFolder()
    ensureTree()
    return self
end
function SaveManager:SetIgnoreIndexes(list)
    IgnoreIndexes = {}
    for _, v in ipairs(list or {}) do IgnoreIndexes[v] = true end
    return self
end
function SaveManager:SetLoadingOrder(enabled, order)
    LoadingOrder = order
    return self
end
function SaveManager:IgnoreThemeSettings()
    return self
end

local function ignored(id)
    return IgnoreIndexes[id] == true
end

local function gather()
    local out = {}
    if not Library then return out end
    for id, el in pairs(Library.Options) do
        if not ignored(id) and el and not el.destroyed then
            local kind = el.kind
            if kind == "Toggle" then
                out[id] = { t = "Toggle", v = el.value == true }
            elseif kind == "Slider" then
                out[id] = { t = "Slider", v = el.value }
            elseif kind == "Dropdown" then
                out[id] = { t = "Dropdown", v = el.value }
            elseif kind == "KeyPicker" then
                out[id] = { t = "KeyPicker", v = el.vk, m = el.mode }
            elseif kind == "ColorPicker" then
                local c = el:Color()
                out[id] = { t = "Color", r = c.R, g = c.G, b = c.B, a = el.alpha or 1 }
            end
        end
    end
    return out
end

local function applyData(data)
    if not Library then return false end
    for id, d in pairs(data or {}) do
        local el = Library.Options[id]
        if el and not ignored(id) then
            local kind = d.t or el.kind
            if kind == "Toggle" then
                el:SetValue(d.v == true)
            elseif kind == "Slider" then
                el:SetValue(d.v)
            elseif kind == "Dropdown" then
                el:SetValue(d.v)
            elseif kind == "KeyPicker" then
                el.vk = d.v
                if d.m then el.mode = d.m end
                el.state = false
            elseif kind == "Color" then
                local c = Color3.new(d.r or 1, d.g or 1, d.b or 1)
                el:SetValueRGB(c, 1 - (d.a or 1))
            end
        end
    end
    return true
end

function SaveManager:RefreshConfigList()
    ensureTree()
    local out = {}
    local ok, files = pcall(listfiles, base())
    if ok then
        for _, path in ipairs(files or {}) do
            local name = tostring(path):match("([^/\\]+)%.json$")
            if name then out[#out + 1] = name end
        end
    end
    table.sort(out)
    return out
end

function SaveManager:Save(ConfigName)
    if not Library then return false, "library not set" end
    local name = safeName(ConfigName)
    local encoded, err = jsonEncode({ Options = gather() })
    if not encoded then return false, err end
    ensureTree()
    local ok, werr = pcall(writefile, base() .. "/" .. name .. ".json", encoded)
    if not ok then return false, tostring(werr) end
    return true
end

function SaveManager:Load(ConfigName)
    local name = safeName(ConfigName)
    local path = base() .. "/" .. name .. ".json"
    if not isfile(path) then return false, "config not found" end
    local ok, content = pcall(readfile, path)
    if not ok then return false, tostring(content) end
    local data, derr = jsonDecode(content)
    if not data then return false, derr end
    applyData(data.Options or data)
    return true
end

function SaveManager:Delete(ConfigName)
    local name = safeName(ConfigName)
    local path = base() .. "/" .. name .. ".json"
    if not isfile(path) then return false, "config not found" end
    local ok, err = pcall(delfile, path)
    if not ok then return false, tostring(err) end
    return true
end

function SaveManager:Rename(OldName, NewName)
    local old = base() .. "/" .. safeName(OldName) .. ".json"
    if not isfile(old) then return false, "config not found" end
    local newp = base() .. "/" .. safeName(NewName) .. ".json"
    if isfile(newp) then return false, "a config with that name exists" end
    local ok, content = pcall(readfile, old)
    if not ok then return false, tostring(content) end
    local wok, werr = pcall(writefile, newp, content)
    if not wok then return false, tostring(werr) end
    pcall(delfile, old)
    if self:GetAutoloadConfig() == safeName(OldName) then
        self:SaveAutoloadConfig(NewName)
    end
    return true
end

function SaveManager:GetAutoloadConfig()
    local path = base() .. "/autoload.txt"
    if not isfile(path) then return nil end
    local ok, content = pcall(readfile, path)
    if not ok then return nil end
    return (tostring(content):gsub("%s+$", ""))
end

function SaveManager:SaveAutoloadConfig(ConfigName)
    ensureTree()
    local ok, err = pcall(writefile, base() .. "/autoload.txt", safeName(ConfigName))
    if not ok then return false, tostring(err) end
    return true
end

function SaveManager:LoadAutoloadConfig()
    local name = self:GetAutoloadConfig()
    if not name or name == "" then return false, "no autoload config" end
    return self:Load(name)
end

function SaveManager:DeleteAutoLoadConfig()
    local path = base() .. "/autoload.txt"
    if not isfile(path) then return false, "no autoload config" end
    pcall(delfile, path)
    return true
end

function SaveManager:BuildConfigSection(Tab, IconName)
    local group = Tab:AddGroupbox({ Side = "Right", Name = "Configs" })
    local list = self:RefreshConfigList()
    local nameInput
    local dd = group:AddDropdown("SaveManager_ConfigList", {
        Text = "Config",
        Values = list,
        Default = list[1],
        MaxVisible = 6,
        Callback = function(v)
            if nameInput then nameInput:SetValue(v or "") end
        end,
    })
    nameInput = group:AddInput("SaveManager_ConfigName", {
        Text = "Config name",
        Default = list[1] or "",
        Placeholder = "type a name",
    })
    local autoloadLabel = group:AddLabel({ Text = "Autoload: none", DoesWrap = true })

    local function currentName()
        local n = nameInput.value
        if not n or n == "" then n = dd.value end
        return n
    end
    local function updateAutoload()
        local a = self:GetAutoloadConfig()
        autoloadLabel:SetText("Autoload: " .. ((a and a ~= "") and a or "none"))
    end
    local function refresh()
        local l = self:RefreshConfigList()
        dd:SetValues(l)
        if not dd.value and l[1] then dd.value = l[1] end
        updateAutoload()
        return l
    end
    local function notify(msg, ok)
        if Library then Library:Notify(msg, 3, ok and "Config" or "Config error") end
    end

    group:AddButton({
        Text = "Save / Overwrite",
        Func = function()
            local name = currentName()
            if not name or name == "" then return notify("Pick a config or type a name", false) end
            local ok, err = self:Save(name)
            refresh()
            if ok then dd:SetValue(name) end
            notify(ok and ("Saved " .. name) or ("Save failed: " .. tostring(err)), ok)
        end,
    })
    group:AddButton({
        Text = "Rename",
        Func = function()
            local old, new = dd.value, nameInput.value
            if not old then return notify("No config selected", false) end
            if not new or new == "" then return notify("Type the new name", false) end
            local ok, err = self:Rename(old, new)
            refresh()
            if ok then dd:SetValue(new) end
            notify(ok and ("Renamed to " .. new) or ("Rename failed: " .. tostring(err)), ok)
        end,
    })
    group:AddButton({
        Text = "Load",
        Func = function()
            if not dd.value then return notify("No config selected", false) end
            local ok, err = self:Load(dd.value)
            notify(ok and ("Loaded " .. dd.value) or ("Load failed: " .. tostring(err)), ok)
        end,
    })
    group:AddButton({
        Text = "Delete",
        Func = function()
            if not dd.value then return notify("No config selected", false) end
            local name = dd.value
            local ok, err = self:Delete(name)
            refresh()
            if ok and self:GetAutoloadConfig() == name then
                self:DeleteAutoLoadConfig()
                updateAutoload()
            end
            notify(ok and ("Deleted " .. name) or ("Delete failed: " .. tostring(err)), ok)
        end,
    })
    group:AddButton({
        Text = "Set Autoload",
        Func = function()
            local name = currentName() or dd.value
            if not name or name == "" then return notify("Select a config first", false) end
            if not isfile(base() .. "/" .. safeName(name) .. ".json") then
                return notify("Save the config before setting autoload", false)
            end
            self:SaveAutoloadConfig(name)
            updateAutoload()
            notify("Autoload set to " .. name, true)
        end,
    })
    group:AddButton({
        Text = "Clear Autoload",
        Func = function()
            self:DeleteAutoLoadConfig()
            updateAutoload()
            notify("Autoload cleared", true)
        end,
    })
    group:AddButton({ Text = "Refresh", Func = refresh })
    group:AddLabel({ Text = "Configs are stored as JSON in " .. base() .. ".", DoesWrap = true })

    updateAutoload()
    pcall(function() self:LoadAutoloadConfig() end)
    return group
end

return SaveManager
]=====],
}

local function uiSource(name)
    local embedded = UI_EMBEDDED[name]
    if embedded then return embedded end
    local ok, src = pcall(readfile, name)
    if ok and type(src) == "string" and #src > 100 then return src end
    return nil
end

local function uiRangeSlider(group, spec)
    local el = {
        kind = "RangeSlider", id = spec.Id, text = spec.Text or "Range",
        visible = true, destroyed = false, objects = {},
        min = spec.Min or 0, max = spec.Max or 500, step = spec.Step or 1,
        lo = spec.DefaultLo or 0, hi = spec.DefaultHi or 100,
        suffix = spec.Suffix or "", callback = spec.Callback, drag = nil,
    }
    local font = Drawing.Fonts.SystemBold or Drawing.Fonts.System

    local function register(o)
        table.insert(UI.__all, o)
        el.objects[#el.objects + 1] = o
        return o
    end

    local function mk(kind, z)
        local d
        if not pcall(function() d = Drawing.new(kind) end) or not d then return nil end
        d.Visible = false
        if kind == "Text" then pcall(function() d.Font = font end) end
        pcall(function() d.ZIndex = z or 24 end)
        return register({ d = d, sc = { Visible = false } })
    end

    local function mkKnob(z)
        local d
        if pcall(function() d = Drawing.new("Circle") end) and d then
            if pcall(function() d.Radius = 6; d.Filled = true; d.ZIndex = z end) then
                d.Visible = false
                return register({ d = d, sc = {}, circle = true })
            end
            pcall(function() d:Remove() end)
        end
        local s
        if not pcall(function() s = Drawing.new("Square") end) or not s then return nil end
        s.Visible = false
        pcall(function() s.ZIndex = z end)
        return register({ d = s, sc = {} })
    end

    el.track, el.trackFill = mk("Square", 24), mk("Square", 25)
    el.knobLo, el.knobHi = mkKnob(26), mkKnob(26)
    el.title, el.val = mk("Text", 30), mk("Text", 30)

    local function vis(o, on)
        if not o then return end
        if o.sc.Visible ~= on then
            o.sc.Visible = on
            o.d.Visible = on
        end
    end

    local function square(o, x, y, w, h, colour, alpha, corner)
        if not o or w <= 0 or h <= 0 then vis(o, false) return end
        o.d.Position = Vector2.new(x, y)
        o.d.Size = Vector2.new(w, h)
        o.d.Color = colour
        o.d.Transparency = alpha or 1
        o.d.Filled = true
        if corner then pcall(function() o.d.Corner = corner end) end
        vis(o, true)
    end

    local function label(o, x, y, str, size, colour, alpha)
        if not o then return end
        o.d.Text = str
        o.d.Size = size or 14
        o.d.Position = Vector2.new(x, y)
        o.d.Color = colour
        o.d.Transparency = alpha or 1
        o.d.Outline = false
        vis(o, true)
    end

    local function knob(o, x, y, r)
        if not o then return end
        if o.circle then
            o.d.Position = Vector2.new(x, y)
            if o.sc.r ~= r then o.sc.r = r; pcall(function() o.d.Radius = r end) end
        else
            o.d.Position = Vector2.new(x - r, y - r)
            o.d.Size = Vector2.new(r * 2, r * 2)
            pcall(function() o.d.Corner = r end)
        end
        o.d.Color = UI.Theme.white
        o.d.Transparency = 1
        vis(o, true)
    end

    function el:GetHeight() return 46 end
    function el:SetValue(lo, hi)
        self.lo = math.clamp(math.floor(lo / self.step + 0.5) * self.step, self.min, self.max - self.step)
        self.hi = math.clamp(math.floor(hi / self.step + 0.5) * self.step, self.lo + self.step, self.max)
        if self.callback then pcall(self.callback, self.lo, self.hi) end
        return self
    end
    function el:OnChanged(fn)
        local prev = self.callback
        self.callback = function(a, b)
            if prev then pcall(prev, a, b) end
            pcall(fn, a, b)
        end
        return self
    end

    function el:Render(x, y, w)
        local theme = UI.Theme
        local barH, ty = 6, y + 20
        local span = math.max(1, self.max - self.min)
        local x1 = x + (self.lo - self.min) / span * w
        local x2 = x + (self.hi - self.min) / span * w
        local val = string.format("%d - %d %s", self.lo, self.hi, self.suffix)
        local vx = x + w - #val * 7
        if vx < x + 80 then vx = x + 80 end
        label(self.title, x, y, self.text, 14, theme.text, 0.88)
        label(self.val, vx, y, val, 14, theme.subtext, 1)
        square(self.track, x, ty, w, barH, theme.main, 1, barH / 2)
        square(self.trackFill, x1, ty, x2 - x1, barH, theme.accent, 1, barH / 2)
        knob(self.knobLo, x1, ty + barH / 2, 6)
        knob(self.knobHi, x2, ty + barH / 2, 6)

        local m = UI.__mouse
        if not m or not m.x then return end
        local midY = ty + barH / 2
        if not m.down then
            self.drag = nil
        elseif m.pressed then
            local dLo, dHi = math.abs(m.x - x1), math.abs(m.x - x2)
            if dLo <= 9 or dHi <= 9 then
                self.drag = (dLo <= dHi) and "lo" or "hi"
            elseif m.x >= x - 4 and m.x <= x + w + 4 and math.abs(m.y - midY) <= 12 then
                self.drag = (dLo <= dHi) and "lo" or "hi"
            end
        end
        if self.drag and m.down then
            local f = math.clamp((m.x - x) / math.max(1, w), 0, 1)
            local v = math.floor((self.min + f * (self.max - self.min)) / self.step + 0.5) * self.step
            if self.drag == "lo" then
                v = math.clamp(v, self.min, self.hi - self.step)
                self.lo = v
            else
                v = math.clamp(v, self.lo + self.step, self.max)
                self.hi = v
            end
            if self.callback then pcall(self.callback, self.lo, self.hi) end
        end
    end

    table.insert(group.elements, el)
    if UI and UI.Options then UI.Options[el.id] = el end
    return el
end

-- menu
local function buildUI()
    local src = assert(uiSource("Library.lua"), "Swangy Library.lua not found")
    local chunk = assert(loadstring(src), "Swangy compile failed")
    local ran, runErr = pcall(chunk)
    if not ran then error("Swangy load: " .. tostring(runErr)) end
    UI = _G.Swangy
    assert(UI and UI.CreateWindow, "Swangy did not expose _G.Swangy")

    for _, addon in ipairs({ "SwangyThemeManager.lua", "SwangySaveManager.lua" }) do
        local s = uiSource(addon)
        if s then
            local fn = loadstring(s)
            if fn then pcall(fn) end
        end
    end

    uiWindow = UI:CreateWindow({
        Title = "Swangy",
        Width = 700,
        Height = 560,
        Center = true,
        ToggleKeybind = "RightShift",
        NotifySide = "Right",
        Accent = Color3.fromRGB(124, 92, 255),
    })

    local mainTab = uiWindow:AddTab("Main", "user")
    local aimTab = uiWindow:AddTab("Aim", "crosshair")
    local visTab = uiWindow:AddTab("Visuals", "eye")
    local hudTab = uiWindow:AddTab("HUD", "list")
    local setTab = uiWindow:AddTab("Settings", "settings")

    local scGroup = mainTab:AddGroupbox({ Side = "Left", Name = "Skillcheck", Description = "generators + butcher trap" })
    local scToggle = scGroup:AddToggle("sc_enabled", {
        Text = "Auto Skillcheck",
        Default = CFG.sc,
        Callback = function(on)
            CFG.sc = on and true or false
            if not CFG.sc then
                pcall(scReleaseInput)
                scTrack = { trace = {} }
            end
        end,
    })
    scToggle:AddKeyPicker("sc_enabled_key", { Text = "Toggle key", Mode = "Always" })

    scGroup:AddToggle("sc_humanize", {
        Text = "Humanize (random delay)",
        Default = CFG.scHum,
        Callback = function(on) CFG.scHum = on and true or false end,
    })
    uiRangeSlider(scGroup, {
        Id = "sc_hum_range", Text = "Humanize range",
        Min = 0, Max = 500, Step = 1, Suffix = "ms",
        DefaultLo = CFG.scHumMin, DefaultHi = CFG.scHumMax,
        Callback = function(lo, hi) CFG.scHumMin, CFG.scHumMax = lo, hi end,
    })
    scGroup:AddSlider("sc_react", {
        Text = "Reaction time", Default = CFG.scReact,
        Min = 0, Max = 300, Rounding = 1, Suffix = "ms",
        Callback = function(v) CFG.scReact = v end,
    })
    scGroup:AddSlider("sc_delay", {
        Text = "Delay before click", Default = CFG.scDelay,
        Min = 0, Max = 300, Rounding = 1, Suffix = "ms",
        Callback = function(v) CFG.scDelay = v end,
    })
    scGroup:AddLabel({
        Text = "They stack: 40ms delay with a 20-60ms humanize presses 60-100ms after the trigger.",
        DoesWrap = true,
    })

    local statusGroup = mainTab:AddGroupbox({ Side = "Right", Name = "Status" })
    local statusLabel = statusGroup:AddLabel({ Text = "starting...", DoesWrap = true })
    local statsLabel = statusGroup:AddLabel({ Text = "checks 0  hits 0  misses 0", DoesWrap = true })
    statusGroup:AddDivider("Parry")
    local ppStateLabel = statusGroup:AddLabel({ Text = "parry: --", DoesWrap = true })
    local ppStatsLabel = statusGroup:AddLabel({ Text = "presses 0", DoesWrap = true })
    statusGroup:AddDivider("Session")
    statusGroup:AddLabel({ Text = "Credit: UI is Swangy by aphalia (github.com/YoungSlaves/matchaUI).", DoesWrap = true })
    statusGroup:AddDivider("Keys")
    statusGroup:AddLabel({ Text = "RightShift menu  |  Insert skillcheck (rebindable above)", DoesWrap = true })

    task.spawn(function()
        while running and UI do
            if statusLabel then
                local mode = tostring(scStats.mode or "--")
                statusLabel:SetText(string.format("%s  [%s]  %sms", tostring(scStats.status), mode,
                    tostring(scStats.delayMs or 0)))
            end
            if statsLabel then
                statsLabel:SetText(string.format("checks %d  hits %d  misses %d  errors %d",
                    scStats.checks, scStats.hits, scStats.misses, scStats.errors))
            end
            if ppStateLabel then
                ppStateLabel:SetText("parry: " .. tostring(PARRY.state or "--"))
            end
            if ppStatsLabel then
                ppStatsLabel:SetText(string.format("presses %d  parried %d  %s",
                    PARRY.presses, PARRY.lands, tostring(PARRY.denied or PARRY.gate.reason or "--")))
            end
            task.wait(0.25)
        end
    end)

    local aimGroup = aimTab:AddGroupbox({ Side = "Left", Name = "Veil Spear", Description = "killer throw assist" })
    local aimToggle = aimGroup:AddToggle("va_enabled", {
        Text = "Auto aim",
        Default = CFG.va,
        Callback = function(on)
            CFG.va = on and true or false
            if not CFG.va then
                vaStat.target, vaStat.solved, vaStat.state = nil, false, "Disabled"
            end
            if UI then UI:Notify("Auto aim  [ " .. (CFG.va and "ON" or "OFF") .. " ]", 2, "Swangy") end
        end,
    })
    aimToggle:AddKeyPicker("va_key", { Text = "Aim key", Mode = "Toggle" })

    aimGroup:AddSlider("va_fov", {
        Text = "Field of view", Default = CFG.vaFov,
        Min = 5, Max = 180, Rounding = 1, Suffix = " deg",
        Callback = function(v) CFG.vaFov = v end,
    })
    aimGroup:AddSlider("va_range", {
        Text = "Range", Default = CFG.vaRange,
        Min = 20, Max = 600, Rounding = 1, Suffix = " studs",
        Callback = function(v) CFG.vaRange = v end,
    })
    aimGroup:AddSlider("va_smooth", {
        Text = "Smoothing", Default = CFG.vaSmooth,
        Min = 1, Max = 20, Rounding = 1,
        Callback = function(v) CFG.vaSmooth = v end,
    })
    aimGroup:AddSlider("va_height", {
        Text = "Aim height", Default = CFG.vaAimHeight,
        Min = -4, Max = 8, Rounding = 1, Suffix = " studs",
        Callback = function(v) CFG.vaAimHeight = v end,
    })

    aimGroup:AddToggle("va_sticky", {
        Text = "Sticky target", Default = CFG.vaSticky,
        Callback = function(on) CFG.vaSticky = on and true or false end,
    })
    aimGroup:AddToggle("va_lead", {
        Text = "Lead moving targets", Default = CFG.vaLead,
        Callback = function(on) CFG.vaLead = on and true or false end,
    })
    aimGroup:AddToggle("va_los", {
        Text = "Line of sight", Default = CFG.vaLos,
        Callback = function(on) CFG.vaLos = on and true or false end,
    })
    aimGroup:AddToggle("va_hold", {
        Text = "Only while charging", Default = CFG.vaHold,
        Callback = function(on) CFG.vaHold = on and true or false end,
    })
    aimGroup:AddLabel({
        Text = "Click the key box to bind. Right-click it for Hold / Toggle / Always. Escape clears it.",
        DoesWrap = true,
    })

    local ppGroup = mainTab:AddGroupbox({ Side = "Left", Name = "Auto Parry", Description = "windup-attribute parry, mouse2click" })
    local ppToggle = ppGroup:AddToggle("pp_enabled", {
        Text = "Auto parry",
        Default = CFG.pp,
        Callback = function(on)
            CFG.pp = on and true or false
            if not CFG.pp then PARRY.state = "Disabled" end
            if UI then UI:Notify("Auto parry  [ " .. (CFG.pp and "ON" or "OFF") .. " ]", 2, "Swangy") end
        end,
    })
    ppToggle:AddKeyPicker("pp_key", { Text = "Parry key", Mode = "Always" })
    ppGroup:AddSlider("pp_range", {
        Text = "Range", Default = CFG.ppRange,
        Min = 4, Max = 25, Rounding = 1, Suffix = " studs",
        Callback = function(v) CFG.ppRange = v end,
    })
    ppGroup:AddSlider("pp_health", {
        Text = "Minimum health", Default = CFG.ppHealth,
        Min = 10, Max = 100, Rounding = 5, Suffix = "%",
        Callback = function(v) CFG.ppHealth = v end,
    })
    ppGroup:AddToggle("pp_windup", {
        Text = "Windup fallback", Default = CFG.ppWindup,
        Callback = function(on) CFG.ppWindup = on and true or false end,
    })
    ppGroup:AddToggle("pp_equip", {
        Text = "Auto equip dagger", Default = CFG.ppEquip,
        Callback = function(on) CFG.ppEquip = on and true or false end,
    })
    ppGroup:AddLabel({
        Text = "Key box: click to bind, right-click for Hold / Toggle / Always, Escape clears.",
        DoesWrap = true,
    })

    local aimStatusGroup = aimTab:AddGroupbox({ Side = "Right", Name = "Status" })
    local aimStateLabel = aimStatusGroup:AddLabel({ Text = "Disabled", DoesWrap = true })
    local aimTargetLabel = aimStatusGroup:AddLabel({ Text = "target --", DoesWrap = true })
    local aimShotLabel = aimStatusGroup:AddLabel({ Text = "hold 0.00s", DoesWrap = true })
    aimStatusGroup:AddDivider("Aim")
    local aimLosLabel = aimStatusGroup:AddLabel({ Text = "line of sight: --", DoesWrap = true })
    aimStatusGroup:AddLabel({
        Text = "The aim only steers where the spear leaves. The throw itself is a normal client input.",
        DoesWrap = true,
    })

    task.spawn(function()
        while running and UI do
            if aimStateLabel then aimStateLabel:SetText(tostring(vaStat.state or "--")) end
            if aimTargetLabel then
                aimTargetLabel:SetText(vaStat.target
                    and string.format("%s  %.0f studs", tostring(vaStat.target), vaStat.dist or 0)
                    or "no target")
            end
            if aimShotLabel then
                if vaStat.solved then
                    aimShotLabel:SetText(string.format("%.0f u/s  flight %.2fs  hold %.2fs  %s",
                        vaStat.speed or 0, vaStat.flight or 0, vaStat.hold or 0, tostring(vaStat.tier or "--")))
                else
                    aimShotLabel:SetText(string.format("hold %.2fs  %s",
                        vaStat.hold or 0, tostring(vaStat.tier or "--")))
                end
            end
            if aimLosLabel then
                aimLosLabel:SetText(vaStat.losOK == false
                    and "line of sight: unavailable (raycast stub)"
                    or "line of sight: available")
            end
            task.wait(0.2)
        end
    end)

    local espGroup = visTab:AddGroupbox({ Side = "Left", Name = "ESP", Description = "boxes and nametags" })

    espGroup:AddToggle("esp_gen", {
        Text = "Generator ESP",
        Default = CFG.gen,
        Callback = function(on) API.gen.SetEnabled(on) end,
    })

    local winToggle = espGroup:AddToggle("esp_win", {
        Text = "Window ESP",
        Default = CFG.win,
        Callback = function(on) API.win.SetEnabled(on) end,
    })
    winToggle:AddColorPicker("esp_win_col", {
        Title = "Window colour", Default = CFG.winColour,
        Callback = function(c) CFG.winColour = c end,
    })

    local palToggle = espGroup:AddToggle("esp_pal", {
        Text = "Pallet ESP",
        Default = CFG.pal,
        Callback = function(on) API.pal.SetEnabled(on) end,
    })
    palToggle:AddColorPicker("esp_pal_col", {
        Title = "Pallet colour", Default = CFG.palColour,
        Callback = function(c) CFG.palColour = c end,
    })

    local trapToggle = espGroup:AddToggle("esp_trap", {
        Text = "Bear trap ESP",
        Default = CFG.trap,
        Callback = function(on) API.trap.SetEnabled(on) end,
    })
    trapToggle:AddColorPicker("esp_trap_armed", {
        Title = "Trap armed colour", Default = CFG.trapArmedColour,
        Callback = function(c) CFG.trapArmedColour = c end,
    })
    trapToggle:AddColorPicker("esp_trap_sprung", {
        Title = "Trap sprung colour", Default = CFG.trapSprungColour,
        Callback = function(c) CFG.trapSprungColour = c end,
    })

    local pumpToggle = espGroup:AddToggle("esp_pumpkin", {
        Text = "Pumpkin ESP",
        Default = CFG.pump,
        Callback = function(on) API.pumpkin.SetEnabled(on) end,
    })
    pumpToggle:AddColorPicker("esp_pumpkin_col", {
        Title = "Pumpkin colour", Default = CFG.pumpColour,
        Callback = function(c) CFG.pumpColour = c end,
    })

    espGroup:AddToggle("esp_names", {
        Text = "Nametags",
        Default = CFG.names,
        Callback = function(on) CFG.names = on and true or false end,
    })
    espGroup:AddToggle("esp_names_only", {
        Text = "Nametags only (no boxes)",
        Default = CFG.namesOnly,
        Callback = function(on)
            CFG.namesOnly = on and true or false
            if CFG.namesOnly then CFG.names = true end
        end,
    })
    espGroup:AddLabel({
        Text = "Nametags off keeps the boxes. Nametags only drops the boxes and keeps the labels.",
        DoesWrap = true,
    })
    espGroup:AddSlider("esp_range", {
        Text = "Render distance", Default = CFG.espRange,
        Min = 0, Max = 10000, Rounding = 1, Suffix = " studs",
        Callback = function(v)
            CFG.espRange = v
            CFG.genRange, CFG.winRange, CFG.palRange, CFG.trapRange, CFG.pumpRange = v, v, v, v, v
        end,
    })

    local colourGroup = visTab:AddGroupbox({ Side = "Right", Name = "Generator Colours" })

    colourGroup:AddColorPicker("gen_col_idle", {
        Title = "Idle", Default = CFG.genIdleColour,
        Callback = function(c) CFG.genIdleColour = c end,
    })
    colourGroup:AddColorPicker("gen_col_done", {
        Title = "Done", Default = CFG.genDoneColour,
        Callback = function(c) CFG.genDoneColour = c end,
    })
    colourGroup:AddColorPicker("gen_col_broken", {
        Title = "Broken", Default = CFG.genBrokenColour,
        Callback = function(c) CFG.genBrokenColour = c end,
    })
    colourGroup:AddLabel({
        Text = "Idle blends into Done as repair progress climbs; Broken is used while a generator regresses.",
        DoesWrap = true,
    })

    local hudGroup = hudTab:AddGroupbox({ Side = "Left", Name = "Killer HUD", Description = "attributes, gens, survivors" })
    local hudBoot = true
    local hudToggle = hudGroup:AddToggle("hud_enabled", {
        Text = "HUD window",
        Default = CFG.hud,
        Callback = function(on)
            CFG.hud = on and true or false
            if not CFG.hud then pcall(HUD.hide) end
            if not hudBoot and UI then UI:Notify("HUD  [ " .. (CFG.hud and "ON" or "OFF") .. " ]", 2, "Swangy") end
        end,
    })
    hudBoot = false
    HUD.toggleEl = hudToggle
    hudToggle:AddKeyPicker("hud_key", { Text = "HUD key", Mode = "Toggle" })

    hudGroup:AddToggle("hud_abilities", {
        Text = "Killer abilities", Default = CFG.hudAbilities,
        Callback = function(on) CFG.hudAbilities = on and true or false end,
    })
    hudGroup:AddToggle("hud_perks", {
        Text = "Killer perks", Default = CFG.hudPerks,
        Callback = function(on) CFG.hudPerks = on and true or false end,
    })
    hudGroup:AddToggle("hud_state", {
        Text = "Killer state lines", Default = CFG.hudState,
        Callback = function(on) CFG.hudState = on and true or false end,
    })
    hudGroup:AddToggle("hud_gens", {
        Text = "Generator column", Default = CFG.hudGens,
        Callback = function(on) CFG.hudGens = on and true or false end,
    })
    hudGroup:AddToggle("hud_survivors", {
        Text = "Survivor list", Default = CFG.hudSurvivors,
        Callback = function(on) CFG.hudSurvivors = on and true or false end,
    })
    hudGroup:AddToggle("hud_traps", {
        Text = "Bear trap list", Default = CFG.hudTraps,
        Callback = function(on) CFG.hudTraps = on and true or false end,
    })
    hudGroup:AddSlider("hud_alpha", {
        Text = "HUD transparency", Default = CFG.hudAlpha,
        Min = 0, Max = 100, Rounding = 1, Suffix = "%",
        Callback = function(v) CFG.hudAlpha = v end,
    })
    hudGroup:AddLabel({
        Text = "Transparency fades only the panel; the text stays. Drag anywhere, x or right-click closes.",
        DoesWrap = true,
    })

    local hudStatusGroup = hudTab:AddGroupbox({ Side = "Right", Name = "Status" })
    local hudKillerLabel = hudStatusGroup:AddLabel({ Text = "killer --", DoesWrap = true })
    local hudCountLabel = hudStatusGroup:AddLabel({ Text = "lines 0  gens 0  survivors 0", DoesWrap = true })
    hudStatusGroup:AddDivider("Window")
    hudStatusGroup:AddLabel({
        Text = "Survivors only lists while you are the killer. The panel is independent of this menu.",
        DoesWrap = true,
    })

    task.spawn(function()
        while running and UI do
            if hudKillerLabel then
                local K = HUD.k
                hudKillerLabel:SetText((K and K.char)
                    and ("killer " .. tostring(K.type or "?") .. "  " .. tostring(K.player and K.player.Name or ""))
                    or "killer --")
            end
            if hudCountLabel then
                hudCountLabel:SetText(string.format("lines %d  gens %d  traps %d  survivors %d",
                    HUD.count or 0, #genList, #trapList, #HUD.surv))
            end
            task.wait(0.4)
        end
    end)

    local menuGroup = setTab:AddGroupbox({ Side = "Left", Name = "Menu" })
    menuGroup:AddKeyPicker("menu_key", {
        Text = "Menu key", Default = "RightShift", CaptureOnly = true,
        ChangedCallback = function(el) UI:SetMenuKey(el.vk) end,
    })
    menuGroup:AddColorPicker("menu_accent", {
        Title = "Accent", Default = UI.Theme.accent,
        Callback = function(c) UI:SetAccent(c) end,
    })
    menuGroup:AddToggle("menu_watermark", {
        Text = "Watermark", Default = true,
        Callback = function(on) UI:SetWatermark(on) end,
    })
    menuGroup:AddToggle("kbw_show", {
        Text = "Keybind window", Default = CFG.kbw,
        Callback = function(on) CFG.kbw = on and true or false end,
    })
    menuGroup:AddButton({ Text = "Unload everything", Func = function() API.unload() end })
    menuGroup:AddDivider("Credits")
    menuGroup:AddLabel({ Text = "UI: Swangy, made by aphalia for Matcha.", DoesWrap = true })

    if _G.SwangyThemeManager then
        _G.SwangyThemeManager:SetLibrary(UI)
        pcall(function() _G.SwangyThemeManager:BuildConfigSection(setTab) end)
    end
    if _G.SwangySaveManager then
        _G.SwangySaveManager:SetLibrary(UI)
        pcall(function() _G.SwangySaveManager:BuildConfigSection(setTab) end)
    end

    UI:Notify("Loaded. RightShift opens the menu.", 4, "Swangy")
    return true
end

--============================================================== matcha menu
-- Second build: the settings live in Matcha's own menu instead of the embedded
-- Drawing window. The renderer, HUD, skillcheck, aim and parry are unchanged;
-- only the settings surface and its keybinds differ.
local function buildMatchaUI()
    local M = _G.UI
    if type(M) ~= "table" or type(M.AddTab) ~= "function" then return false end

    local D = {
        sw_all = (CFG.gen and CFG.win and CFG.pal and CFG.trap and CFG.pump) == true,
        sw_gen = CFG.gen, sw_win = CFG.win, sw_pal = CFG.pal, sw_trap = CFG.trap,
        sw_pump = CFG.pump, sw_names = CFG.names, sw_names_only = CFG.namesOnly,
        sw_range = CFG.espRange,
        sc_on = CFG.sc, sc_hum = CFG.scHum, sc_hum_min = CFG.scHumMin, sc_hum_max = CFG.scHumMax,
        sc_react = CFG.scReact, sc_delay = CFG.scDelay,
        pp_on = CFG.pp, pp_range = CFG.ppRange, pp_health = CFG.ppHealth,
        pp_windup = CFG.ppWindup, pp_equip = CFG.ppEquip,
        va_on = CFG.va, va_fov = CFG.vaFov, va_range = CFG.vaRange, va_smooth = CFG.vaSmooth,
        va_height = CFG.vaAimHeight, va_sticky = CFG.vaSticky, va_lead = CFG.vaLead,
        va_los = CFG.vaLos, va_hold = CFG.vaHold,
        hud_on = CFG.hud, hud_ab = CFG.hudAbilities, hud_perks = CFG.hudPerks,
        hud_state = CFG.hudState, hud_gens = CFG.hudGens, hud_surv = CFG.hudSurvivors,
        hud_traps = CFG.hudTraps, hud_alpha = CFG.hudAlpha,
    }

    -- shared state, declared up here because the clamp and mirror helpers below
    -- write back into it
    local lastUi = {}
    local KBWIDGETS = {}
    local KBHOT = {}
    local kbState = {}
    local kbTick = 0
    local KB_BY_TOGGLE = {
        sc_on = "sc_kb", pp_on = "pp_kb", va_on = "va_kb",
        hud_on = "hud_kb", sw_all = "sw_all_kb",
    }

    local APPLY = {
        sw_gen = function(v) API.gen.SetEnabled(v == true) end,
        sw_win = function(v) API.win.SetEnabled(v == true) end,
        sw_pal = function(v) API.pal.SetEnabled(v == true) end,
        sw_trap = function(v) API.trap.SetEnabled(v == true) end,
        sw_pump = function(v) API.pumpkin.SetEnabled(v == true) end,
        sw_names = function(v) CFG.names = v == true end,
        sw_names_only = function(v)
            CFG.namesOnly = v == true
            if CFG.namesOnly then CFG.names = true end
        end,
        sw_range = function(v)
            local n = math.clamp(tonumber(v) or CFG.espRange, 0, 10000)
            CFG.espRange = n
            CFG.genRange, CFG.winRange, CFG.palRange = n, n, n
            CFG.trapRange, CFG.pumpRange = n, n
        end,
        sc_on = function(v)
            CFG.sc = v == true
            if not CFG.sc then
                pcall(scReleaseInput)
                scTrack = { trace = {} }
            end
        end,
        sc_hum = function(v) CFG.scHum = v == true end,
        -- The slider is clamped, not carried: max can never sit below min, and min
        -- can never pass max. The corrected number is written back to the widget so
        -- the handle snaps instead of lying about the value.
        sc_hum_min = function(v)
            local n = math.clamp(tonumber(v) or CFG.scHumMin, 0, 500)
            if n > CFG.scHumMax then n = CFG.scHumMax end
            CFG.scHumMin = n
            if lastUi.sc_hum_min ~= n then
                lastUi.sc_hum_min = n
                pcall(M.SetValue, "sc_hum_min", n)
            end
        end,
        sc_hum_max = function(v)
            local n = math.clamp(tonumber(v) or CFG.scHumMax, 0, 500)
            if n < CFG.scHumMin then n = CFG.scHumMin end
            CFG.scHumMax = n
            if lastUi.sc_hum_max ~= n then
                lastUi.sc_hum_max = n
                pcall(M.SetValue, "sc_hum_max", n)
            end
        end,
        sc_react = function(v) CFG.scReact = math.clamp(tonumber(v) or 0, 0, 300) end,
        sc_delay = function(v) CFG.scDelay = math.clamp(tonumber(v) or 0, 0, 300) end,
        pp_on = function(v) API.SetParry(v == true) end,
        pp_range = function(v) CFG.ppRange = math.clamp(tonumber(v) or 14, 4, 25) end,
        pp_health = function(v) CFG.ppHealth = math.clamp(tonumber(v) or 50, 10, 100) end,
        pp_windup = function(v) CFG.ppWindup = v == true end,
        pp_equip = function(v) CFG.ppEquip = v == true end,
        va_on = function(v) API.va.SetEnabled(v == true) end,
        va_fov = function(v) CFG.vaFov = math.clamp(tonumber(v) or 55, 5, 180) end,
        va_range = function(v) CFG.vaRange = math.clamp(tonumber(v) or 260, 20, 600) end,
        va_smooth = function(v) CFG.vaSmooth = math.clamp(tonumber(v) or 1, 1, 20) end,
        va_height = function(v) CFG.vaAimHeight = math.clamp(tonumber(v) or 0, -4, 8) end,
        va_sticky = function(v) CFG.vaSticky = v == true end,
        va_lead = function(v) CFG.vaLead = v == true end,
        va_los = function(v) CFG.vaLos = v == true end,
        va_hold = function(v) CFG.vaHold = v == true end,
        hud_on = function(v)
            CFG.hud = v == true
            if not CFG.hud then pcall(HUD.hide) end
        end,
        hud_ab = function(v) CFG.hudAbilities = v == true end,
        hud_perks = function(v) CFG.hudPerks = v == true end,
        hud_state = function(v) CFG.hudState = v == true end,
        hud_gens = function(v) CFG.hudGens = v == true end,
        hud_surv = function(v) CFG.hudSurvivors = v == true end,
        hud_traps = function(v) CFG.hudTraps = v == true end,
        hud_alpha = function(v) CFG.hudAlpha = math.clamp(tonumber(v) or 0, 0, 100) end,
    }

    -- widgets persist across sessions, so stored colours are replayed once on load
    local COLOURS = {
        sw_gen_col = function(c) CFG.genIdleColour = c end,
        sw_gen_done = function(c) CFG.genDoneColour = c end,
        sw_win_col = function(c) CFG.winColour = c end,
        sw_pal_col = function(c) CFG.palColour = c end,
        sw_pal_down = function(c) CFG.palDownColour = c end,
        sw_trap_col = function(c) CFG.trapArmedColour = c end,
        sw_trap_sprung = function(c) CFG.trapSprungColour = c end,
        sw_pump_col = function(c) CFG.pumpColour = c end,
    }

    -- every widget call is pcall'd so one unsupported method cannot leave the
    -- whole tab half-built
    local function W(section, method, ...)
        if not section then return nil end
        local fn = section[method]
        if type(fn) ~= "function" then return nil end
        local ok, res = pcall(fn, section, ...)
        return ok and res or nil
    end

    -- ColorPicker has to sit directly after the toggle it belongs to, so this
    -- wrapper keeps that pairing explicit at every call site
    local function pick(section, id, colour, alpha, set)
        W(section, "ColorPicker", id, colour.R, colour.G, colour.B, alpha,
            function(c, a) if c then set(c, a) end end)
    end

    local function pick2(section, id1, colour1, id2, colour2, set)
        W(section, "ColorPicker2",
            id1, { colour1.R, colour1.G, colour1.B, 1 },
            id2, { colour2.R, colour2.G, colour2.B, 1 },
            function(c1, a1, c2, a2) set(c1, a1, c2, a2) end)
    end

    -- Keybind has to sit directly after the toggle it belongs to, and AddToHotkey
    -- lists it in Matcha's on-screen overlay while that toggle is on. Colours and
    -- keybinds cannot both follow the same toggle, so keys hang off the rows that
    -- have no picker: the master switches.
    local function kb(section, id, key, mode, label, toggleId)
        local w = W(section, "Keybind", id, key, mode)
        if w then
            KBWIDGETS[id] = w
            -- the tab callback runs every frame, so the overlay entry is added once
            -- rather than once per draw
            -- the first draw can run before the paired toggle is registered, which
            -- silently drops the overlay entry, so a few frames get a retry
            local tries = KBHOT[id] or 0
            if tries < 3 and type(w.AddToHotkey) == "function" then
                KBHOT[id] = tries + 1
                pcall(w.AddToHotkey, w, label, toggleId)
            end
        end
        return w
    end

    -- probe for the live bind: nil means the tab has not been drawn yet in this
    -- session, so that key does not exist. Handy after a reload.
    API.matchaKey = function(id)
        local w = KBWIDGETS[id]
        if not w then return nil end
        local out = {}
        local ok, v = pcall(function() return w:IsEnabled() end)
        if ok then out.enabled = v end
        local ok2, k = pcall(function() return w:GetKey() end)
        if ok2 then out.key = k end
        local ok3, t = pcall(function() return w:GetType() end)
        if ok3 then out.mode = t end
        out.seen = kbState[id]
        out.tick = kbTick
        return out
    end

    -- Matcha's stored picker value is not always a Color3: this build returns a
    -- number for at least one picker, and indexing that raises. Every branch here
    -- has to be total or the sync loop dies on the read.
    local function asColour(v)
        local t = type(v)
        if t == "table" then
            if type(v.R) == "number" then return Color3.new(v.R, v.G, v.B) end
            if type(v[1]) == "number" then return Color3.fromRGB(v[1], v[2], v[3]) end
            return nil
        end
        if t == "number" then
            -- a stored picker reads back as a bare number (measured: it is the red
            -- channel, 139/255 -> 0.545). One channel cannot rebuild a colour, and
            -- the picker itself keeps its own saved swatch, so skip it.
            return nil
        end
        if t == "userdata" then return v end
        return nil
    end

    local TABS = { "Swangy", "Swangy Aim", "Swangy HUD" }

    M.AddTab(TABS[1], function(tab)
        local s = tab:Section("ESP", "Left")
        W(s, "Toggle", "sw_all", "All ESP", D.sw_all)
        kb(s, "sw_all_kb", 0x73, "toggle", "VD ESP", "sw_all")
        W(s, "Toggle", "sw_gen", "Generator ESP", D.sw_gen)
        -- one colour widget per toggle, so idle -> done share the dual picker and
        -- the broken state keeps its default colour
        pick2(s, "sw_gen_col", CFG.genIdleColour, "sw_gen_done", CFG.genDoneColour,
            function(c1, a1, c2)
                if c1 then CFG.genIdleColour = c1 end
                if type(a1) == "number" then CFG.genFillA = a1 end
                if c2 then CFG.genDoneColour = c2 end
            end)
        W(s, "Toggle", "sw_win", "Window ESP", D.sw_win)
        pick(s, "sw_win_col", CFG.winColour, CFG.winFillA,
            function(c, a) CFG.winColour = c; if type(a) == "number" then CFG.winFillA = a end end)
        W(s, "Toggle", "sw_pal", "Pallet ESP", D.sw_pal)
        pick2(s, "sw_pal_col", CFG.palColour, "sw_pal_down", CFG.palDownColour,
            function(c1, a1, c2)
                if c1 then CFG.palColour = c1 end
                if type(a1) == "number" then CFG.palFillA = a1 end
                if c2 then CFG.palDownColour = c2 end
            end)
        W(s, "Toggle", "sw_trap", "Bear trap ESP", D.sw_trap)
        pick2(s, "sw_trap_col", CFG.trapArmedColour, "sw_trap_sprung", CFG.trapSprungColour,
            function(c1, a1, c2)
                if c1 then CFG.trapArmedColour = c1 end
                if type(a1) == "number" then CFG.trapFillA = a1 end
                if c2 then CFG.trapSprungColour = c2 end
            end)
        W(s, "Toggle", "sw_pump", "Pumpkin ESP", D.sw_pump)
        pick(s, "sw_pump_col", CFG.pumpColour, CFG.pumpFillA,
            function(c, a) CFG.pumpColour = c; if type(a) == "number" then CFG.pumpFillA = a end end)
        W(s, "Toggle", "sw_names", "Nametags", D.sw_names)
        W(s, "Toggle", "sw_names_only", "Nametags only", D.sw_names_only)
        W(s, "Tip", "Labels without boxes")
        W(s, "SliderInt", "sw_range", "Render distance", 0, 10000, D.sw_range)

        local k = tab:Section("Skillcheck", "Right")
        W(k, "Toggle", "sc_on", "Auto skillcheck", D.sc_on)
        kb(k, "sc_kb", 0x2D, "always", "Skillcheck", "sc_on")
        W(k, "Toggle", "sc_hum", "Humanize delay", D.sc_hum)
        W(k, "SliderInt", "sc_hum_min", "Humanize min ms", 0, 500, D.sc_hum_min)
        W(k, "SliderInt", "sc_hum_max", "Humanize max ms", 0, 500, D.sc_hum_max)
        W(k, "SliderInt", "sc_react", "Reaction ms", 0, 300, D.sc_react)
        W(k, "SliderInt", "sc_delay", "Delay before click ms", 0, 300, D.sc_delay)

        local p = tab:Section("Auto Parry", "Right")
        W(p, "Toggle", "pp_on", "Auto parry", D.pp_on)
        kb(p, "pp_kb", 0x70, "toggle", "Auto parry", "pp_on")
        W(p, "SliderInt", "pp_range", "Range", 4, 25, D.pp_range)
        W(p, "SliderInt", "pp_health", "Minimum health %", 10, 100, D.pp_health)
        W(p, "Toggle", "pp_windup", "Windup fallback", D.pp_windup)
        W(p, "Toggle", "pp_equip", "Auto equip dagger", D.pp_equip)

        local h = tab:Section("Hotkeys", "Right")
        W(h, "Text", "Rebind any key from the widget after its toggle.")
        W(h, "Text", "Right-click a key to change toggle / hold / always.")
        W(h, "Spacing")
        W(h, "Button", "Unload swangy", function() pcall(API.unload) end)
        W(h, "Text", "Menu: Matcha menu, no separate window")
    end)

    M.AddTab(TABS[2], function(tab)
        local a = tab:Section("Veil spear", "Left")
        W(a, "Toggle", "va_on", "Auto aim", D.va_on)
        kb(a, "va_kb", 0x71, "toggle", "Veil aim", "va_on")
        W(a, "SliderInt", "va_fov", "Field of view deg", 5, 180, D.va_fov)
        W(a, "SliderInt", "va_range", "Range studs", 20, 600, D.va_range)
        W(a, "SliderInt", "va_smooth", "Smoothing", 1, 20, D.va_smooth)
        W(a, "SliderInt", "va_height", "Aim height studs", -4, 8, D.va_height)
        W(a, "Toggle", "va_sticky", "Sticky target", D.va_sticky)
        W(a, "Toggle", "va_lead", "Lead moving targets", D.va_lead)
        W(a, "Toggle", "va_los", "Line of sight", D.va_los)
        W(a, "Toggle", "va_hold", "Only while charging", D.va_hold)

        local i = tab:Section("Info", "Right")
        W(i, "Text", "Killer only. Hold attack to charge, then release.")
        W(i, "Text", "The aim steers the throw; the input stays yours.")
    end)

    M.AddTab(TABS[3], function(tab)
        local h = tab:Section("Killer HUD", "Left")
        W(h, "Toggle", "hud_on", "HUD window", D.hud_on)
        kb(h, "hud_kb", 0x72, "toggle", "Killer HUD", "hud_on")
        W(h, "Toggle", "hud_ab", "Killer abilities", D.hud_ab)
        W(h, "Toggle", "hud_perks", "Killer perks", D.hud_perks)
        W(h, "Toggle", "hud_state", "Killer state lines", D.hud_state)
        W(h, "Toggle", "hud_gens", "Generator column", D.hud_gens)
        W(h, "Toggle", "hud_surv", "Survivor list", D.hud_surv)
        W(h, "Toggle", "hud_traps", "Bear trap list", D.hud_traps)
        W(h, "SliderInt", "hud_alpha", "Panel transparency %", 0, 100, D.hud_alpha)

        local i = tab:Section("Info", "Right")
        W(i, "Text", "Drag the panel anywhere; x or right-click closes it.")
        W(i, "Text", "Transparency fades the panel, never the text.")
        W(i, "Text", "Survivors only list while you are the killer.")
    end)

    -- Matcha keeps widget values across sessions; the first sync adopts them.
    -- Only CHANGES are applied, so a hotkey that cannot write a widget still
    -- keeps its effect instead of being reverted a tick later.

    -- writes a widget and applies it at once, so the menu switch and the running
    -- feature never disagree for a tick
    local function set(id, v)
        lastUi[id] = v
        local fn = APPLY[id]
        if fn then pcall(fn, v) end
        pcall(M.SetValue, id, v)
    end

    -- An "always" bind is permanently active, so its state carries no information:
    -- reading it back would switch the feature on over and over and fight a menu
    -- toggle-off. Those rows stay as a label and the toggle drives everything.
    local function kbAlways(id)
        local w = KBWIDGETS[id]
        if not w then return false end
        local ok, t = pcall(function() return w:GetType() end)
        return ok and t == "always"
    end

    -- Keeps the bind widget in step with its toggle, so the on-screen hotkey entry
    -- shows up whether the feature was switched from the key or from the menu.
    -- M.SetValue only touches the stored value and leaves the widget alone, so the
    -- widget itself is driven here and the store is kept in step afterwards.
    local function pushKey(toggleId, v)
        local kbId = KB_BY_TOGGLE[toggleId]
        if not kbId then return end
        local w = KBWIDGETS[kbId]
        if not w then return end   -- tab not drawn yet
        if kbAlways(kbId) then return end
        pcall(function() w.value = v end)
        pcall(function() w:SetValue(v) end)
        pcall(M.SetValue, kbId, v)
    end

    -- The master row is a command, not stored state: it writes the five rows below
    -- it and is only followed after its stored value has been adopted, so a saved
    -- master-off cannot wipe the individual choices on load.
    local function setAll(on)
        lastUi.sw_all = on
        pcall(M.SetValue, "sw_all", on)
        pushKey("sw_all", on)
        set("sw_gen", on)
        set("sw_win", on)
        set("sw_pal", on)
        set("sw_trap", on)
        set("sw_pump", on)
    end

    local function syncOne(id)
        local ok, v = pcall(M.GetValue, id)
        if not ok or v == nil then v = D[id] end
        if lastUi[id] ~= v then
            lastUi[id] = v
            local fn = APPLY[id]
            if fn then pcall(fn, v) end
            pushKey(id, v)
        end
    end

    local function syncMaster()
        local ok, v = pcall(M.GetValue, "sw_all")
        if not ok or type(v) ~= "boolean" then return end
        if lastUi.sw_all == nil then
            lastUi.sw_all = v
            return
        end
        if lastUi.sw_all ~= v then setAll(v) end
    end

    task.spawn(function()
        while running do
            for id in pairs(APPLY) do syncOne(id) end
            syncMaster()
            for id, fn in pairs(COLOURS) do
                local ok, v = pcall(M.GetValue, id)
                if ok and v ~= nil and lastUi[id] ~= v then
                    lastUi[id] = v
                    local okc, c = pcall(asColour, v)
                    if okc and c then pcall(fn, c) end
                end
            end
            task.wait(0.1)
        end
    end)

    -- The keys are real Keybind widgets now: the key is whatever the user bound and
    -- the mode is toggle / hold / always / click. Reading by id keeps this out of the
    -- per-frame tab callback, and every change is mirrored into the matching toggle
    -- so the switch in the menu always says what the key just did.
    local KEYS = {
        { kb = "sc_kb",     toggle = "sc_on"  },
        { kb = "pp_kb",     toggle = "pp_on"  },
        { kb = "va_kb",     toggle = "va_on"  },
        { kb = "hud_kb",    toggle = "hud_on" },
        { kb = "sw_all_kb", toggle = "sw_all" },
    }

    -- the live widget object is preferred once the tab has been drawn; GetValue is
    -- the fallback for builds that do not expose IsEnabled
    local function kbActive(id)
        if kbAlways(id) then return nil end
        local w = KBWIDGETS[id]
        if w then
            -- a handle stops answering once its tab is not drawn, and every read
            -- here has to be protected or the poller thread dies on the first one
            local ok, v = pcall(function() return w:IsEnabled() end)
            if ok and type(v) == "boolean" then return v end
            local okw, raw = pcall(function() return w.value end)
            if okw and type(raw) == "boolean" then return raw end
        end
        local ok, v = pcall(M.GetValue, id)
        if ok and type(v) == "boolean" then return v end
        return nil
    end

    -- Returns the toggle to write when the key just changed, else nil. First sight
    -- only adopts the key state, so a key that happens to sit at off cannot switch
    -- the feature off during load.
    local function applyKey(id, toggle, v)
        if v == nil then return nil end
        if kbState[id] == nil then
            kbState[id] = v
            return nil
        end
        if kbState[id] == v then return nil end
        kbState[id] = v
        return toggle
    end

    task.spawn(function()
        while running do
            task.wait(0.05)
            kbTick = kbTick + 1
            for i = 1, #KEYS do
                local e = KEYS[i]
                local v = kbActive(e.kb)
                local t = applyKey(e.kb, e.toggle, v)
                if t then
                    if t == "sw_all" then
                        setAll(v)
                        if type(notify) == "function" then
                            notify("ESP " .. (v and "on" or "off"), "Swangy", 2)
                        end
                    else
                        set(t, v)
                    end
                end
            end
        end
    end)

    API.matchaCleanup = function()
        for i = 1, #TABS do pcall(M.RemoveTab, TABS[i]) end
    end

    if type(notify) == "function" then
        notify("Settings are in the Matcha menu", "Swangy", 4)
    end
    return true
end

-- boot
local okM, resM = pcall(buildMatchaUI)
if not okM or resM == false then
    if not okM and type(warn) == "function" then
        warn("[swangy] matcha ui failed: " .. tostring(resM))
    end
    okM, resM = pcall(buildUI)
    if not okM and type(warn) == "function" then
        warn("[swangy] ui failed: " .. tostring(resM))
    end
end
API.ui = UI

refreshWorld()
refreshPallets()
if type(notify) == "function" then
    notify("esp + skillcheck + veil aim", "Swangy", 4)
end

_G.__SWANGY = API

return API
