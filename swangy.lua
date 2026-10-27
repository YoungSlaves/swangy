-- menu: swangy ui by aphalia (github.com/YoungSlaves/matchaUI)

if _G.__SWANGY and _G.__SWANGY.unload then pcall(_G.__SWANGY.unload) end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local lp         = Players.LocalPlayer
local mouse      = lp:GetMouse()

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

    names     = true,
    espRange  = 1000,

    sc        = true,
    scLead    = 2,
    scKey     = 32,
    scHum     = false,
    scHumMin  = 10,
    scHumMax  = 50,
    scReact   = 0,
    scDelay   = 0,
    scHz      = 240,
    scRescue  = true,
    scDry     = false,
    scMode    = nil,

}

local UI, uiWindow

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

for i = 1, CFG.genPool do genPool[i] = newSlot(CFG.genThick, CFG.genText) end

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
    if not ok then return nil end
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

    local parents = { okKids and kids or {} }
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
                if okSub and #sub > 0 then folder = ch break end
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
            if okp and type(prog) == "number" then t.prog = prog end
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
        if n >= #genPool then break end
        local t = genList[i]
        local d = (t.center - camPos).Magnitude
        if d <= CFG.genRange then
            n = n + 1
            local e = genPool[n]
            local colour = genColour(t.prog, t.state)

            local okBox, topY = pcall(drawBox, e, t.center, t.hx, t.hy, t.hz,
                t.right or R_AXIS, t.up or U_AXIS, t.back or B_AXIS,
                colour, CFG.genFill and CFG.genFillA or nil, CFG.genThick)
            if not okBox then topY = nil end

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
for i = 1, CFG.winPool do winPool[i] = newSlot(CFG.winThick, CFG.winText) end

-- windows
local function collectWindows()
    local out = {}
    local map = Workspace:FindFirstChild("Map")
    if not map then return out end
    local ok, desc = pcall(function() return map:GetDescendants() end)
    if not ok or type(desc) ~= "table" then return out end

    local candidates = {}
    for _, d in ipairs(desc) do
        if lower(d.Name):find("window", 1, true) then
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
        if n >= #winPool then break end
        local t = winList[i]
        if t.pos and t.size then
            local d = (t.pos - camPos).Magnitude
            if d <= CFG.winRange then
                n = n + 1
                local e = winPool[n]
                local topY = drawBox(e, t.pos,
                    t.size.X * 0.5, t.size.Y * 0.5, t.size.Z * 0.5,
                    t.right or R_AXIS, t.up or U_AXIS, t.back or B_AXIS,
                    CFG.winColour, CFG.winFill and CFG.winFillA or nil, CFG.winThick)
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
for i = 1, CFG.palPool do palPool[i] = newSlot(CFG.palThick, CFG.palText) end

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
    if last > #palPool then last = #palPool end

    for i = 1, last do
        local t = palList[i]
        local e = palPool[i]
        local d = (t.pos - camPos).Magnitude
        if d <= CFG.palRange and t.size and t.cf then

            local colour = t.dropped
                and lerpColor(CFG.palColour, CFG.palDownColour, 0.55)
                or CFG.palColour
            local topY = drawBox(e, t.pos, t.size.X * 0.5, t.size.Y * 0.5, t.size.Z * 0.5,
                t.right or R_AXIS, t.up or U_AXIS, t.back or B_AXIS,
                colour, CFG.palFill and CFG.palFillA or nil, CFG.palThick)
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
    local token = scPressToken
    task.delay(wait, function()
        if not CFG.sc then return end
        if token ~= scPressToken then return end
        if not scTrack.fired then return end
        scStats.fireAt = angle
        scDoPress(string.format("%s +%.0fms", why, wait * 1000))
    end)
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
                        task.delay(dt, function()
                            if not CFG.sc then return end
                            if scTrack.base == nil or scTrack.schedBase ~= scTrack.base then return end
                            if scTrack.fired or scTrack.missed then return end
                            local cur = scAngleRaw(scGui.line, scGui.off)
                            if cur then
                                local ph = cur - scTrack.base
                                if ph < lo or ph > good then return end
                                scStats.fireAt = cur
                            end
                            scTrack.fired = true
                            scDoPress("trap timed")
                        end)
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
        end
        scTrack.lr, scTrack.goal = lr, gr

        scTrackSample(lr, d)

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
    local stamp = map and (tostring(map.Address) .. ":" .. tostring(#map:GetChildren())) or "none"
    if stamp ~= genStamp then
        genStamp = stamp
        genGeo = {}
        winGeo = {}
        palGeo = {}
        palParts = {}
        winScanStamp = nil
    end

    if not CFG.gen then
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
        genList = kept
        if not kept[1] then genDiscoverAt = os.clock() + 1.5 end
    end

    if not CFG.win then
        winList = {}
    else
        local t = os.clock()
        if stamp ~= winScanStamp or t >= winScanAt then
            winScanStamp, winScanAt = stamp, t + 30
            winList = collectWindows()
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
    if ok and list then palList = list end
    palScanMs = palScanMs * 0.8 + (os.clock() - started) * 1000 * 0.2
end

connection = RunService.RenderStepped:Connect(function()
    if not running then return end
    local now = os.clock()
    if CFG.drawHz > 0 and now - (CFG.lastFrame or 0) < 1 / CFG.drawHz then return end
    CFG.lastFrame = now
    frameN = frameN + 1
    if now - fpsMark >= 1 then
        drawFps = frameN / (now - fpsMark)
        frameN, fpsMark = 0, now
    end

    if not camera then camera = Workspace.CurrentCamera end
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

    renderMs = renderMs * 0.9 + (os.clock() - now) * 1000 * 0.1
end)

task.spawn(function()
    while running do
        if os.clock() >= scBusyUntil then pcall(refreshWorld) end
        task.wait(1 / CFG.pollHz)
    end
end)

local genPollHz = 15
task.spawn(function()
    while running do
        if CFG.gen and genList[1] then pcall(updateGenStates, genList) end
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
function API.sc.Stats() return scStats end

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
        gen = CFG.gen, win = CFG.win, pal = CFG.pal, names = CFG.names,
        range = CFG.genRange,
        winColour = CFG.winColour, palColour = CFG.palColour,
        genIdleColour = CFG.genIdleColour, genDoneColour = CFG.genDoneColour,
        genBrokenColour = CFG.genBrokenColour,
        sc = CFG.sc, hum = CFG.scHum, humMin = CFG.scHumMin, humMax = CFG.scHumMax,
        react = CFG.scReact, delay = CFG.scDelay,
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
        scHz     = CFG.scHz,
        frameMs  = math.floor(1 / math.max(drawFps, 1) * 1000 + 0.5),
        err      = CFG.errGen or CFG.errWin or CFG.errPal,
    }
end

function API.unload()
    if not running then return end
    running = false
    scReleaseInput()
    if UI and UI.Unload then pcall(function() UI:Unload() end) end
    UI, uiWindow = nil, nil
    if connection then connection:Disconnect(); connection = nil end
    for i = 1, #genPool do removeSlot(genPool[i]) end
    for i = 1, #winPool do removeSlot(winPool[i]) end
    for i = 1, #palPool do removeSlot(palPool[i]) end
    genPool, winPool, palPool = {}, {}, {}
    if _G.__SWANGY == API then _G.__SWANGY = nil end
end
API.stop = API.unload

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
local fps, frameCount, fpsClock = 0, 0, clock()
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
    local cam = workspace.CurrentCamera
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
    local cam = workspace.CurrentCamera
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
    local cam = workspace.CurrentCamera
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
        text(o, x, y + (i - 1) * 18, ln, size, self.color or Theme.text, 0.85, false, false)
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
    local cam = workspace.CurrentCamera
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
function Groupbox:GetHeight(w)
    local h = 6 + 15 + (self.desc and self.desc ~= "" and 16 or 0) + 6
    local lw = w - 12
    for _, el in ipairs(self.elements) do
        if el.visible and not el.destroyed then h = h + el:GetHeight(lw) + 6 end
    end
    return h
end
function Groupbox:Render(x, y, w)
    local h = self:GetHeight(w)
    fill(self.bg, x, y, w, h, Theme.bg, 1, Library.CornerRadius)
    stroke(self.border, x, y, w, h, Theme.outline, 1, Library.CornerRadius, 1)
    text(self.title, x + 10, y + 6, clipText(self.name, 15, w - 20), 15, Theme.text, 1, false, false)
    if self.desc and self.desc ~= "" then
        text(self.descText, x + 10, y + 22, clipText(self.desc, 14, w - 20), 14, Theme.subtext, 1, false, false)
    else
        put(self.descText, "Visible", false)
    end
    local ey = y + 6 + 15 + (self.desc and self.desc ~= "" and 16 or 0) + 6
    for _, el in ipairs(self.elements) do
        if el.visible and not el.destroyed then
            local eh = el:GetHeight(w - 12)
            if el.row and el.RenderRow then
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
function Tab:Render(x, y, w)
    local colW = w / 2 - 3
    local ly, ry = y, y
    for _, g in ipairs(self.groups) do
        if g.visible then
            if g.side == "Left" then ly = ly + g:Render(x, ly, colW) + 6
            else ry = ry + g:Render(x + colW + 6, ry, colW) + 6 end
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
    local cam = workspace.CurrentCamera
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
function Window:Center()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    self:SetPos((vp.X - self.w) / 2, (vp.Y - self.h) / 2)
    return self
end
function Window:Render()
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
    local cw, ch = w - sideW - 8, h - titleH - 8
    if self.activeTab then
        self.activeTab:Render(cx, cy, cw)
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
    local win = Windows[1]
    return fmt("%s  |  %d fps", win and win.title or "Swangy", fps)
end

local function tickLoop(dt)
    if stopped then return end
    FRAME_DT = 1 / 60
    if type(dt) == "number" and dt > 0 then
        FRAME_DT = min(dt, 0.1)
    end
    local ok, err = pcall(function()
        poll()
        frameCount = frameCount + 1
        if clock() - fpsClock >= 0.5 then
            fps = floor(frameCount / (clock() - fpsClock) + 0.5)
            frameCount, fpsClock = 0, clock()
        end
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
            local cam = workspace.CurrentCamera
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
    local visTab = uiWindow:AddTab("Visuals", "eye")
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
            task.wait(0.25)
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

    espGroup:AddToggle("esp_names", {
        Text = "Nametags",
        Default = CFG.names,
        Callback = function(on) CFG.names = on and true or false end,
    })
    espGroup:AddLabel({
        Text = "Nametags off keeps the boxes. Generator progress always shows while generator ESP is on.",
        DoesWrap = true,
    })
    espGroup:AddSlider("esp_range", {
        Text = "Render distance", Default = CFG.espRange,
        Min = 0, Max = 10000, Rounding = 1, Suffix = " studs",
        Callback = function(v)
            CFG.espRange = v
            CFG.genRange, CFG.winRange, CFG.palRange = v, v, v
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

-- boot
local uiOk, uiErr = pcall(buildUI)
if not uiOk then
    if type(warn) == "function" then warn("[swangy] ui failed: " .. tostring(uiErr)) end
end
API.ui = UI

refreshWorld()
refreshPallets()
if type(notify) == "function" then
    notify("gen / window / pallet ESP + skillcheck", "Swangy", 4)
end

_G.__SWANGY = API

return API
