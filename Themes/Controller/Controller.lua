-- Arcane UI: Controller theme, a normal fourth visual layout.
-- Pure Lua. Uses Arcane's movers, parts, scale and reset facilities.
-- Does not intercept or detect controller inputs or alter keybindings.
-- The normal HUD and its canonical positions are restored on logout.
-- Artwork and implementation belong to this self-contained theme folder.
local C = Arcane
local ART = "Interface\\AddOns\\Arcane\\Themes\\Controller\\Art\\"
local active, initialized, dock = false, false, nil
local originalParents = {}
local hidden = CreateFrame("Frame", "ArcaneControllerHidden", UIParent)
hidden:Hide()
local driver = CreateFrame("Frame", "ArcaneControllerDriver")
local slots = {}
local colors = { title = {1, .84, .48}, rim = {.83, .66, .34}, fill = {.26, .60, .96} }
local refreshClock, themeClock, petClock = 0, 0, 0
local profiles, profileReady = nil, false
local petDock, petSlots = nil, {}
local storedLevels, bookClock = 0, 0
local BOOK_HALO_X, BOOK_HALO_Y = -1, 3
local controllerMover = nil
local controllerPart = nil
local current = { hp=1,hpm=1,sh=0,mana=0,manam=1,xp=0,xpn=1,lvl=1,power=-1 }
local Theme = {}
C.ControllerUX = Theme
local function Print(msg)
    local chat = DEFAULT_CHAT_FRAME
    if chat and chat.AddMessage then chat:AddMessage("|cffffd877Arcane Controller|r: " .. tostring(msg)) end
end
local function Call(fn, a)
    if type(fn) ~= "function" then return nil end
    local ok, one, two, three
    if a == nil then ok, one, two, three = pcall(fn)
    else ok, one, two, three = pcall(fn, a) end
    if ok then return one, two, three end
    return nil
end
local function Flat(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    t:SetVertexColor(r, g, b, a or 1)
    return t
end
local function Label(parent, size, value, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetText(value or "")
    return fs
end
local function ColorFromArcane()
    local C = getglobal("Arcane")
    if type(C) ~= "table" or type(C.Pal) ~= "function" then return end
    local pal = Call(C.Pal)
    if type(pal) ~= "table" then return end
    local title = pal.title or pal.rim
    local rim = pal.rim or title
    local fill = pal.fillM or pal.glow
    if type(title) == "table" then colors.title = title end
    if type(rim) == "table" then colors.rim = rim end
    if type(fill) == "table" then colors.fill = fill end
end
-- Use Arcane's OWN shared animated-bar renderer and palette. The compact frame
-- changes only placement, not the spring, shield, damage echo, or light effects.
local HP_COLORS = { { .04, .28, .07 }, { .14, .62, .18 }, { .58, .96, .36 } }
local LOW_COLORS = { { .36, .04, .02 }, { .80, .16, .06 }, { 1.00, .52, .20 } }
local XP_COLORS = { { .34, .22, .02 }, { .86, .64, .10 }, { 1, .92, .46 } }
local function Mix(a, b, t, out)
    out[1] = a[1] + (b[1] - a[1]) * t
    out[2] = a[2] + (b[2] - a[2]) * t
    out[3] = a[3] + (b[3] - a[3]) * t
    return out
end
local function Clamp01(v) return math.max(0, math.min(1, v or 0)) end
-- Use Arcane's nine existing class palettes, not a duplicate color table.
local function ClassAccent()
    local a = getglobal("Arcane")
    if type(a) ~= "table" then return colors.fill end
    local styles = a.BarStyles
    if type(styles) == "table" and type(styles.Mode) == "function" and
        type(styles.Palette) == "function" and styles.Mode() ~= styles.CLASSIC then
        local pal = Call(styles.Palette)
        if type(pal) == "table" and type(pal.gem) == "table" then return pal.gem end
    end
    local key
    if type(UnitClass) == "function" then
        local _, token = Call(UnitClass, "player")
        if type(token) == "string" then key = string.lower(token) end
    end
    local barDB = a.DB and Call(a.DB, "bar")
    if not key and type(barDB) == "table" and type(barDB.heroClass) == "string" then
        key = string.lower(barDB.heroClass)
    end
    local theme = type(a.BarStyleData) == "table" and a.BarStyleData[key or ""]
    if type(theme) == "table" and type(theme.gem) == "table" then return theme.gem end
    return colors.fill
end

local function ApplyTheme()
    if not dock then return end
    ColorFromArcane()
    local t, r, f = colors.title, colors.rim, colors.fill
    local classGem = ClassAccent()
    local pal = Call(C.Pal)
    if type(pal) ~= "table" then pal = C.DEFAULT_PAL or {} end
    if C.BarTheme then
        C.BarTheme(dock.hp, pal)
        C.BarTheme(dock.resource, pal)
        C.BarTheme(dock.xp, pal)
    end
    if C.BarColors then
        C.BarColors(dock.hp, HP_COLORS[1], HP_COLORS[2], HP_COLORS[3])
        C.BarColors(dock.xp, XP_COLORS[1], XP_COLORS[2], XP_COLORS[3])
    end
    -- The bronze base stays warm; the delicate shimmer adopts Arcane's palette.
    if dock.cradleL then dock.cradleL:SetAlpha(.98) end
    if dock.cradleR then dock.cradleR:SetAlpha(.98) end
    if dock.cradleAccentL then
        dock.cradleAccentL:SetVertexColor(f[1], f[2], f[3], .78)
        dock.cradleAccentR:SetVertexColor(f[1], f[2], f[3], .78)
    end
    dock.level:SetTextColor(t[1], t[2], t[3])
    dock.bookHint:SetTextColor(t[1], t[2], t[3])
    dock.bookCount:SetTextColor(t[1], t[2], t[3])
    -- Stone fill responds to class; metal rails and gold orbit remain bronze.
    if dock.bookWisp then dock.bookWisp:SetVertexColor(.36, .64, 1.00, .88) end
    if dock.bookGlow then dock.bookGlow:SetVertexColor(1, .76, .46, .86) end
    if dock.bookMotes then
        dock.bookMotes[1]:SetVertexColor(1, .88, .57, 1)
        dock.bookMotes[2]:SetVertexColor(classGem[1], classGem[2], classGem[3], 1)
        dock.bookMotes[3]:SetVertexColor(1, .95, .81, 1)
    end
    if petDock and petDock.accentL then
        petDock.accentL:SetVertexColor(classGem[1], classGem[2], classGem[3], .38)
        petDock.accentR:SetVertexColor(classGem[1], classGem[2], classGem[3], .38)
    end
end

-- A root is parked beneath an invisible parent instead of toggling any Arcane
-- settings. Arcane can keep updating it; the hide parent always wins.
local function Park(name)
    local f = getglobal(name)
    if not f or type(f.SetParent) ~= "function" then return end
    if originalParents[name] then return end
    local parent = f:GetParent()
    if not parent then return end
    local ok = pcall(f.SetParent, f, hidden)
    if ok then
        originalParents[name] = parent
    else
        Print("Could not temporarily hide " .. name .. "; the original frame was not changed.")
    end
end
local function Unpark(name)
    local parent = originalParents[name]
    if not parent then return end
    local f = getglobal(name)
    if not f or type(f.SetParent) ~= "function" then return end
    local ok = pcall(f.SetParent, f, parent)
    if not ok or f:GetParent() ~= parent then
        -- Keep the saved parent so our driver can retry rather than forgetting it.
        return
    end
    originalParents[name] = nil
    -- Arcane may have hidden its skill bar while parked, especially during
    -- the level-up-card transition. Restore it only if Arcane actually wants
    -- the bar enabled and the game is not currently displaying cards.
    if name == "ArcaneBar" then
        local C = getglobal("Arcane")
        local phase = Call(AZS_GetPhase)
        local enabled = C and C.barOn
        if enabled == nil and type(ArcaneDB) == "table" then
            enabled = type(ArcaneDB.bar) == "table" and ArcaneDB.bar.enabled ~= false
        end
        if enabled and phase ~= "choosing" then
            f:Show()
            if type(f.GetAlpha) == "function" and f:GetAlpha() == 0 then
                f:SetAlpha(1)
            end
        end
    elseif name == "ArcanePlayer" then
        -- Arcane's C.Vis caches the desired visibility in frame.mv. Parking
        -- under a hidden parent doesn't clear it, so a normal Tick may skip
        -- the Show() needed after restoring the original parent.
        -- Respect the user's own Your frame toggle while forcing a fresh write.
        local units = C.DB("units", {player = true})
        f.mv = nil
        C.Vis(f, units.player ~= false)
    end
end
local function ParkOriginals()
    -- Keep Arcane updating its own HUD in the background. Hide only the
    -- pieces whose presentation our controller preview replaces.
    Park("ArcaneBar")
    Park("ArcaneTally")
    Park("ArcanePlayer")
    Park("ArcaneLevelUps")
    Park("ArcanePetBar")
end
local function UnparkOriginals()
    Unpark("ArcaneBar")
    Unpark("ArcaneTally")
    Unpark("ArcanePlayer")
    Unpark("ArcaneLevelUps")
    Unpark("ArcanePetBar")
end


-- Controller and regular UI have separate saved positions/scales. Arcane's
-- normal Move frames and Reset positions operate on whichever style is active.
local function CopyPositions(src)
    local copy = {}
    if type(src) ~= "table" then return copy end
    for key, value in pairs(src) do
        if type(value) == "table" then
            local entry = {}
            for field, n in pairs(value) do entry[field] = n end
            copy[key] = entry
        else
            copy[key] = value
        end
    end
    return copy
end

local function ArcaneRoot()
    local a = getglobal("Arcane")
    if type(a) == "table" and type(a.Root) == "function" then
        local r = Call(a.Root)
        if type(r) == "table" then return r end
    end
    return type(ArcaneDB) == "table" and ArcaneDB or nil
end

local function ReadScales()
    local scales = {}
    local a = getglobal("Arcane")
    if type(a) ~= "table" or type(a.parts) ~= "table" then return scales end
    for _, part in pairs(a.parts) do
        if type(part) == "table" and type(part.key) == "string" and not part.profileIndependent and
            type(part.getScale) == "function" and type(part.setScale) == "function" then
            local v = tonumber(Call(part.getScale))
            if v and v > 0 then scales[part.key] = v end
        end
    end
    return scales
end

local function SaveFramePosition(frame)
    if not frame then return nil end
    local left, top = frame:GetLeft(), frame:GetTop()
    if not (left and top) then return nil end
    local scale = tonumber(frame:GetScale()) or 1
    return { x = math.floor(left * scale + .5), y = math.floor(top * scale + .5) }
end

local function PlaceFrame(frame, pos, defaultPoint, defaultRelative, defaultX, defaultY)
    if not frame then return end
    frame:ClearAllPoints()
    if type(pos) == "table" and tonumber(pos.x) and tonumber(pos.y) then
        local s = tonumber(frame:GetScale()) or 1
        if s <= 0 then s = 1 end
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x / s, pos.y / s)
    else
        frame:SetPoint(defaultPoint, UIParent, defaultRelative, defaultX, defaultY)
    end
end

local function EnsureProfiles()
    if profileReady then return end
    local root = ArcaneRoot()
    if not root then return end
    if type(root.controllerLayouts) ~= "table" then root.controllerLayouts = {} end
    profiles = root.controllerLayouts
    if type(profiles.keyboard) ~= "table" then profiles.keyboard = {} end
    if type(profiles.gamepad) ~= "table" then profiles.gamepad = {} end
    local kb = profiles.keyboard
    -- Canonical storage remains the regular layout on disk after logout.
    -- All three regular styles continue to share their existing mover locations.
    kb.pos = CopyPositions(root.pos)
    kb.scales = ReadScales()
    local gp = profiles.gamepad
    if type(gp.pos) ~= "table" then gp.pos = CopyPositions(kb.pos) end
    if type(gp.scales) ~= "table" then
        gp.scales = {}
        for key, value in pairs(kb.scales) do gp.scales[key] = value end
    end
    profileReady = true
end

local function CaptureProfile(which)
    if not (profileReady and profiles) then return end
    local root = ArcaneRoot()
    local selected = profiles[which]
    if not (root and selected) then return end
    selected.pos = CopyPositions(root.pos)
    selected.scales = ReadScales()

end

local function ApplyProfile(which)
    if not (profileReady and profiles) then return end
    local root, a = ArcaneRoot(), getglobal("Arcane")
    local chosen = profiles[which]
    if not (root and chosen) then return end
    -- The minimap has one global position across all four UI styles.
    local sharedMinimap = type(root.pos) == "table" and root.pos.minimap
    root.pos = CopyPositions(chosen.pos)
    if type(sharedMinimap) == "table" then
        root.pos.minimap = CopyPositions({ minimap = sharedMinimap }).minimap
    end
    -- Set scales before positions. Arcane setScale() calls ApplyPos() itself,
    -- so it must see the newly selected profile's positions.
    if type(a) == "table" and type(a.parts) == "table" then
        for _, part in pairs(a.parts) do
            local scale = part and chosen.scales and chosen.scales[part.key]
            if not part.profileIndependent and not (which == "gamepad" and part.key == "bar") and
                tonumber(scale) and type(part.setScale) == "function" then
                pcall(part.setScale, scale)
            end
        end
        if type(a.ApplyPos) == "function" and type(a.movers) == "table" then
            -- Some defaults are anchored relative to other movable frames.
            for pass = 1, 2 do
                for _, mover in pairs(a.movers) do
                    if mover and mover.frame then pcall(a.ApplyPos, mover) end
                end
            end
        end
    end

end

-- The game's Lua renderer does not expose modern texture masking. We can still
-- crop an action icon to a REAL circle: draw narrow horizontal texture strips
-- with appropriately narrowed source UVs. No square black icon corners remain.
-- This is static geometry; only textures or cooldown visibility change in a run.
local ROUND_STEPS, ROUND_D = 20, 44
local function RoundSlot(parent, size, clickable)
    local s = { parts = {}, shadeParts = {}, texture = false }
    local f = CreateFrame(clickable and "Button" or "Frame", nil, parent)
    s.frame = f
    f:SetWidth(size)
    f:SetHeight(size)
    local d = size * ROUND_D / 54
    local margin = (size - d) * .5
    local radius = d * .5
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(ART .. "SkillEmpty")
    bg:SetAllPoints(f)
    s.background = bg
    for i = 1, ROUND_STEPS do
        local h = d / ROUND_STEPS
        local y = (i - .5) * h
        local yy = (y - radius) / radius
        local dx = math.sqrt(math.max(0, 1 - yy * yy)) * radius
        local left = margin + radius - dx
        local width = math.max(.5, 2 * dx)
        local tx0 = .06 + .88 * (radius - dx) / d
        local tx1 = .06 + .88 * (radius + dx) / d
        local ty0 = .06 + .88 * (i - 1) / ROUND_STEPS
        local ty1 = .06 + .88 * i / ROUND_STEPS
        local p = f:CreateTexture(nil, "ARTWORK")
        p:SetWidth(width)
        p:SetHeight(h + .08)
        p:SetPoint("TOPLEFT", f, "TOPLEFT", left, -(margin + (i - 1) * h))
        p:SetTexCoord(tx0, tx1, ty0, ty1)
        p:Hide()
        s.parts[i] = p
        -- Readable visual cooldown: the spell art stays visible beneath the timer.
        local v = Flat(f, "OVERLAY", .020, .025, .042, .46)
        v:SetWidth(width)
        v:SetHeight(h + .08)
        v:SetPoint("TOPLEFT", f, "TOPLEFT", left, -(margin + (i - 1) * h))
        v:Hide()
        s.shadeParts[i] = v
    end
    s.rim = f:CreateTexture(nil, "OVERLAY")
    s.rim:SetTexture(ART .. "SkillRim")
    s.rim:SetAllPoints(f)
    s.rim:SetAlpha(.42)
    s.time = Label(f, size >= 48 and 14 or 10, "", 1, .94, .70)
    s.time:SetPoint("CENTER", f, "CENTER", 0, 0)
    return s
end
local function RoundTexture(s, texture)
    if s.texture == texture then return end
    s.texture = texture
    local occupied = texture and texture ~= "" and true or false
    for i = 1, ROUND_STEPS do
        local p = s.parts[i]
        if occupied then p:SetTexture(texture); p:Show() else p:Hide() end
    end
    s.rim:SetAlpha(occupied and 1 or .35)
    s.background:SetAlpha(occupied and .93 or .42)
    if not occupied then
        for i = 1, ROUND_STEPS do s.shadeParts[i]:Hide() end
        s.time:SetText("")
    end
end
local function RoundCooldown(s, left, duration)
    local frac = 0
    if s.texture and duration and duration > 0 and left and left > 0 then
        frac = Clamp01(left / duration)
    end
    -- A dark cooldown grows from the bottom, itself constrained to a circle.
    local cut = (1 - frac) * ROUND_STEPS
    for i = 1, ROUND_STEPS do
        if frac > 0 and i > cut then s.shadeParts[i]:Show()
        else s.shadeParts[i]:Hide() end
    end
    if frac > 0 then
        if left > 3 then s.time:SetText(tostring(math.ceil(left)))
        else s.time:SetText(string.format("%.1f", left)) end
    else s.time:SetText("") end
end

local function Build()
    if dock then return end
    dock = CreateFrame("Frame", "ArcaneControllerDock", UIParent)
    dock:SetWidth(550)
    dock:SetHeight(165)
    dock:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 18)
    dock:SetFrameStrata("MEDIUM")
    dock:EnableMouse(false)
    dock:SetMovable(true)
    dock:SetClampedToScreen(true)

    -- Same animated objects and gradients the player plate / Arcane XP use.
    dock.hp = C.NewBar(dock, 372, 11, true)
    dock.hp.frame:SetPoint("TOPLEFT", dock, "TOPLEFT", 46, -14)
    dock.healthText = Label(dock.hp.top, 10, "-- / --", 1, .98, .88)
    dock.healthText:SetWidth(210); dock.healthText:SetHeight(15)
    dock.healthText:SetJustifyH("CENTER")
    dock.healthText:SetPoint("CENTER", dock.hp.frame, "CENTER", 0, 0)
    dock.low = 0
    dock.colA, dock.colM, dock.colB = {0,0,0}, {0,0,0}, {0,0,0}

    dock.resource = C.NewBar(dock, 372, 7, true)
    dock.resource.frame:SetPoint("TOPLEFT", dock, "TOPLEFT", 46, -33)
    dock.resourceText = Label(dock.resource.top, 9, "", 1, .96, .92)
    dock.resourceText:SetWidth(210); dock.resourceText:SetHeight(14)
    dock.resourceText:SetJustifyH("CENTER")
    dock.resourceText:SetPoint("CENTER", dock.resource.frame, "CENTER", 0, 0)

    dock.xp = C.NewBar(dock, 372, 6, true)
    dock.xp.frame:SetPoint("TOPLEFT", dock, "TOPLEFT", 46, -47)
    dock.level = Label(dock.xp.top, 10, "L --", .97, .86, .55)
    dock.level:SetWidth(35); dock.level:SetHeight(15)
    dock.level:SetJustifyH("CENTER")
    dock.level:SetPoint("RIGHT", dock.xp.frame, "LEFT", -11, 0)
    dock.xpText = Label(dock.xp.top, 9, "", .80, .85, .94)
    dock.xpText:SetWidth(210); dock.xpText:SetHeight(14)
    dock.xpText:SetJustifyH("CENTER")
    dock.xpText:SetPoint("CENTER", dock.xp.frame, "CENTER", 0, 0)
    dock.xpFlash = 0
    dock.xpWrap = false

    local base = dock:GetFrameLevel()
    C.BarLevels(dock.hp, base + 1)
    C.BarLevels(dock.resource, base + 1)
    C.BarLevels(dock.xp, base + 1)

    -- An ornate but quiet cradle visually gathers the seven round abilities.
    -- Its gold/black base sits BEHIND the icons and curves beneath them;
    -- no line or backdrop crosses the icon faces. Separate accent art takes
    -- Arcane's existing class/theme color without recoloring the gold trim.
    -- Azeroth Survivors' renderer supports at most 512px textures. Split the
    -- ornamental cradle into two seam-matched 512x256 halves, same visual span.
    dock.cradleL = dock:CreateTexture(nil, "BACKGROUND")
    dock.cradleR = dock:CreateTexture(nil, "BACKGROUND")
    dock.cradleAccentL = dock:CreateTexture(nil, "BACKGROUND")
    dock.cradleAccentR = dock:CreateTexture(nil, "BACKGROUND")
    for _, piece in ipairs({
        {dock.cradleL, "SkillCradleL", 13},
        {dock.cradleR, "SkillCradleR", 232},
        {dock.cradleAccentL, "SkillCradleAccentL", 13},
        {dock.cradleAccentR, "SkillCradleAccentR", 232},
    }) do
        local tex, file, x = piece[1], piece[2], piece[3]
        tex:SetTexture(ART .. file)
        tex:SetWidth(219)
        tex:SetHeight(86)
        tex:SetPoint("TOPLEFT", dock, "TOPLEFT", x, -77)
    end
    dock.cradleAccentL:SetBlendMode("ADD")
    dock.cradleAccentR:SetBlendMode("ADD")
    -- The cradle already contains its own central jewel. Do not overlay a
    -- second tinted diamond: it looked offset beneath the original jewel.

    -- Register through Arcane's existing mover infrastructure.
    controllerMover = C.Movable(dock, "controllerHud", "Controller HUD", function(f)
        f:ClearAllPoints()
        f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 18)
    end)

    local actions = {1, 2, 3, 4, 5, 6, 12}
    for i = 1, 7 do
        local s = RoundSlot(dock, 54, false)
        s.action = actions[i]
        s.frame:SetPoint("TOPLEFT", dock, "TOPLEFT", 25 + (i-1)*60, -78)
        slots[i] = s
    end

    local book = CreateFrame("Button", "ArcaneControllerBook", dock)
    dock.book = book
    -- Reserve a compact right-hand lane: the 110px orbit now starts AFTER
    -- the final skill slot (x=439), rather than overlapping it.
    book:SetWidth(72); book:SetHeight(78)
    book:SetPoint("TOPLEFT", dock, "TOPLEFT", 461, -67)
    book:EnableMouse(true)
    -- Keep the glow centered on the *visible tome*, not the taller click area.
    -- All aura layers share this anchor, including their animated motes.
    dock.bookArt = book:CreateTexture(nil, "ARTWORK")
    dock.bookArt:SetTexture(ART .. "Tome")
    dock.bookArt:SetWidth(66); dock.bookArt:SetHeight(66)
    dock.bookArt:SetPoint("TOP", book, "TOP", 0, 1)
    -- Rich gold orbit + class-colored secondary magic, matching concept art.
    -- Separate layers allow pulse animation without texture rotation APIs.
    dock.bookGlow = book:CreateTexture(nil, "BACKGROUND")
    dock.bookGlow:SetTexture(ART .. "BookGoldOrbit")
    dock.bookGlow:SetBlendMode("ADD")
    dock.bookGlow:SetWidth(108); dock.bookGlow:SetHeight(108)
    dock.bookGlow:SetPoint("CENTER", dock.bookArt, "CENTER", BOOK_HALO_X, BOOK_HALO_Y)
    dock.bookGlow:Hide()
    dock.bookWisp = book:CreateTexture(nil, "BACKGROUND")
    dock.bookWisp:SetTexture(ART .. "BookClassOrbit")
    dock.bookWisp:SetBlendMode("ADD")
    dock.bookWisp:SetWidth(110); dock.bookWisp:SetHeight(110)
    dock.bookWisp:SetPoint("CENTER", dock.bookArt, "CENTER", BOOK_HALO_X, BOOK_HALO_Y)
    dock.bookWisp:Hide()
    dock.bookSparks = book:CreateTexture(nil, "BACKGROUND")
    dock.bookSparks:SetTexture(ART .. "BookSparks")
    dock.bookSparks:SetBlendMode("ADD")
    dock.bookSparks:SetWidth(104); dock.bookSparks:SetHeight(104)
    dock.bookSparks:SetPoint("CENTER", dock.bookArt, "CENTER", BOOK_HALO_X, BOOK_HALO_Y)
    dock.bookSparks:Hide()
    dock.bookMotes = {}
    for i = 1, 3 do
        local mote = book:CreateTexture(nil, "OVERLAY")
        mote:SetTexture(ART .. "BookSparks")
        mote:SetBlendMode("ADD")
        mote:SetWidth(15); mote:SetHeight(15)
        mote:SetPoint("CENTER", dock.bookArt, "CENTER", BOOK_HALO_X, BOOK_HALO_Y)
        mote:SetAlpha(0)
        mote:Hide()
        dock.bookMotes[i] = mote
    end
    dock.bookCount = Label(book, 10, "", 1, .85, .55)
    dock.bookCount:SetPoint("TOPRIGHT", book, "TOPRIGHT", 3, -4)
    dock.bookHint = Label(book, 10, "Y", .92, .80, .53)
    dock.bookHint:SetPoint("BOTTOM", book, "BOTTOM", 0, 1)
    book:SetScript("OnClick", function()
        local n = tonumber(Call(AZS_GetStoredLevels)) or 0
        if n > 0 and type(AZS_OpenStoredLevels) == "function" then Call(AZS_OpenStoredLevels) end
    end)
    book:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(book, "ANCHOR_TOP")
            GameTooltip:AddLine("Stored level-ups", 1, .84, .48)
            GameTooltip:AddLine("Press Y to choose upgrades, or click the book.", .83, .88, 1, true)
            GameTooltip:Show()
        end
    end)
    book:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    dock:Hide()
    ApplyTheme()
    if type(AZS_SetOnTopOfScreens) == "function" then pcall(AZS_SetOnTopOfScreens, dock, true) end
end

-- Small pet/summon HUD, same round slots as the main skill strip. The original
-- pet overlay is merely parked while controller UX is on. Pet actions remain
-- mouse-usable and autocast remains right-clickable, exactly as in Arcane.
local PET_FACES = {
    {"spirit wolf", "Spell_Nature_SpiritWolf"}, {"wolf", "Ability_Hunter_Pet_Wolf"},
    {"raptor", "Ability_Hunter_Pet_Raptor"}, {"water elemental", "Spell_Frost_SummonWaterElemental"},
    {"imp", "Spell_Shadow_SummonImp"}, {"voidwalker", "Spell_Shadow_SummonVoidWalker"},
    {"felguard", "Ability_Warrior_Cleave"}, {"infernal", "Spell_Shadow_SummonInfernal"},
    {"doomguard", "Spell_Shadow_AntiMagicShell"}, {"treant", "Spell_Nature_ProtectionformNature"},
    {"cat", "Ability_Hunter_Pet_Cat"}, {"bear", "Ability_Hunter_Pet_Bear"},
}
local function PetFace(group)
    local key = string.lower(tostring(group.key or "") .. " " .. tostring(group.name or ""))
    for i = 1, table.getn(PET_FACES) do
        if string.find(key, PET_FACES[i][1], 1, true) then
            return "Interface\\Icons\\" .. PET_FACES[i][2]
        end
    end
    return group.icon
end
local function BuildPetDock()
    if petDock then return end
    petDock = CreateFrame("Frame", "ArcaneControllerPetDock", dock)
    -- Portraits hang FROM the frame above health, not a floating second bar.
    -- The 10-place space stays centered when fewer summons are present.
    petDock:SetWidth(420); petDock:SetHeight(45)
    -- Anchor the pet assembly to the actual HEALTH bar, not to a separately
    -- positioned row on the outer HUD. The bronze supports, portraits, and
    -- health frame therefore share one center and move together.
    -- 84 is the existing vertical gap from the health-bar TOP to petDock TOP.
    petDock:SetPoint("TOP", dock.hp.frame, "TOP", 0, 84)
    petDock:EnableMouse(false)
    -- A matching pair of thin bronze filigree branches rises from the health
    -- bar shoulders into the pet row; no floating top jewel or outline loop.
    -- Each source art file is <=512 wide for legacy renderer compatibility.
    petDock.bridgeL = petDock:CreateTexture(nil, "BACKGROUND")
    petDock.bridgeR = petDock:CreateTexture(nil, "BACKGROUND")
    petDock.accentL = petDock:CreateTexture(nil, "BACKGROUND")
    petDock.accentR = petDock:CreateTexture(nil, "BACKGROUND")
    for _, piece in ipairs({
        {petDock.bridgeL, "PetBridgeL", 0},
        {petDock.bridgeR, "PetBridgeR", 210},
        {petDock.accentL, "PetBridgeFXL", 0},
        {petDock.accentR, "PetBridgeFXR", 210},
    }) do
        local t, file, x = piece[1], piece[2], piece[3]
        t:SetTexture(ART .. file)
        t:SetWidth(210); t:SetHeight(105)
        t:SetPoint("TOPLEFT", petDock, "TOPLEFT", x, 0)
    end
    petDock.accentL:SetBlendMode("ADD")
    petDock.accentR:SetBlendMode("ADD")
    for i = 1, 10 do
        local s = RoundSlot(petDock, 39, true)
        s.frame:SetPoint("TOPLEFT", petDock, "TOPLEFT", (i-1)*42, 0)
        s.count = Label(s.frame, 9, "", 1, .89, .58)
        s.count:SetPoint("BOTTOMRIGHT", s.frame, "BOTTOMRIGHT", -1, 1)
        s.hint = Label(s.frame, 8, "", .9, .9, .9)
        s.hint:SetPoint("TOP", s.frame, "BOTTOM", 0, -2)
        s.frame:EnableMouse(true)
        s.frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        s.frame:SetScript("OnClick", function()
            if s.kind ~= "action" then return end
            if arg1 == "RightButton" then
                if type(TogglePetAutocast) == "function" then Call(TogglePetAutocast, s.index) end
            elseif type(CastPetAction) == "function" then
                Call(CastPetAction, s.index)
            end
        end)
        s.frame:SetScript("OnEnter", function()
            if not GameTooltip or not s.kind then return end
            GameTooltip:SetOwner(s.frame, "ANCHOR_TOP")
            if s.kind == "action" and type(GameTooltip.SetPetAction) == "function" then
                GameTooltip:SetPetAction(s.index)
            else
                GameTooltip:AddLine(s.name or "Summon", 1, .85, .52)
            end
            GameTooltip:Show()
        end)
        s.frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        s.frame:Hide()
        petSlots[i] = s
    end
    petDock:Hide()
end
-- PetBridgeL/R draw two mirrored bronze arches, not a simple parabola.
-- These points sample the UPPER EDGE of that existing artwork at actual
-- rendered coordinates (two 210px halves, combined width 420px). The icons'
-- lower rim is kept 2px ABOVE this edge so pet portraits appear mounted into
-- the same sweep instead of hanging below it. No changes to the art/FX files.
-- Positive Y is downward from petDock TOP, so the art rises around +/-100px
-- from its center and bends back toward the health-bar shoulders at the ends.
local PET_SUPPORT_TOP = {
    {0,51}, {20,49}, {40,48}, {60,46}, {80,44},
    {100,42}, {120,42}, {140,44}, {150,46}, {160,48},
    {170,53}, {180,60}, {190,69}, {210,85},
}
local function PetSupportY(centerX)
    -- Sample the actual mirrored pet-support silhouette, rather than a
    -- separately invented arc. Each region interpolates continuously.
    local delta = math.abs(centerX - 210)
    for i=2, table.getn(PET_SUPPORT_TOP) do
        local a,b=PET_SUPPORT_TOP[i-1], PET_SUPPORT_TOP[i]
        if delta <= b[1] then
            local t=(delta-a[1])/(b[1]-a[1])
            return a[2]+(b[2]-a[2])*t
        end
    end
    return PET_SUPPORT_TOP[table.getn(PET_SUPPORT_TOP)][2]
end
local function PositionPetSlots(count)
    -- Keep portrait sizes, styling, and all art unchanged. The old 42px
    -- stride put the outside portraits at x~20/400: the steepest shoulders
    -- of the filigree, making them look as if they were falling off.
    -- A slightly tighter 40px stride puts them around x~30/390 instead,
    -- which follows the gentler part of the SAME art and preserves symmetry.
    local width, stride, face = 420, 40, 39
    local left = (width - (count-1)*stride - face)*.5
    for i=1,count do
        local f=petSlots[i].frame
        local x=left+(i-1)*stride
        local top=PetSupportY(x+face*.5)-face-2
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", petDock, "TOPLEFT", x, -top)
    end
end

local function RefreshPet()
    if not (active and petDock) then return end
    local db = ArcaneRoot()
    if db and type(db.pets) == "table" and db.pets.enabled == false then
        petDock:Hide();return
    end
    local shown = 0
    local hasBar = type(GetPetActionInfo) == "function" and
        (type(PetHasActionBar) ~= "function" or Call(PetHasActionBar))
    if hasBar then
        for i = 1, 10 do
            local name, _, texture, token, highlighted, autoAllowed, auto
            name, _, texture, token, highlighted, autoAllowed, auto = GetPetActionInfo(i)
            if name and shown < 10 then
                shown = shown + 1
                local s = petSlots[shown]
                if token and type(texture)=="string" then texture = getglobal(texture) or texture end
                s.kind, s.index, s.name = "action", i, name
                RoundTexture(s, texture)
                local start,duration,enabled = Call(GetPetActionCooldown,i)
                start,duration = tonumber(start) or 0,tonumber(duration) or 0
                local left = start + duration - GetTime()
                RoundCooldown(s,enabled==0 and 0 or left,duration)
                s.count:SetText("");s.hint:SetText("")
                s.frame:Show()
            end
        end
    elseif type(AZS_GetSummonGroups)=="function" then
        local groups = Call(AZS_GetSummonGroups)
        if type(groups)=="table" then
            local skills = C.petSkills or {}
            for j=1,math.min(table.getn(groups),4) do
                if shown >= 10 then break end
                local g = groups[j]
                shown=shown+1
                local s=petSlots[shown]
                s.kind,s.index,s.name = "summon",nil,g.name
                RoundTexture(s,PetFace(g))
                RoundCooldown(s,0,0)
                local count=tonumber(g.count) or 1
                s.count:SetText(count > 1 and tostring(count) or "")
                s.hint:SetText(tonumber(g.remaining) and tostring(math.ceil(tonumber(g.remaining))) or "")
                s.frame:Show()
                local seen = skills[g.key] or skills[g.name] or {}
                for k=1,math.min(table.getn(seen),4) do
                    if shown >= 10 then break end
                    local skill=seen[k]
                    if type(skill)=="table" and skill.icon then
                        shown=shown+1
                        local t=petSlots[shown]
                        t.kind,t.index,t.name="skill",nil,skill.name
                        RoundTexture(t,skill.icon)
                        RoundCooldown(t,0,0)
                        t.count:SetText("");t.hint:SetText("")
                        t.frame:Show()
                    end
                end
            end
        end
    end
    for i=shown+1,10 do
        petSlots[i].frame:Hide()
        petSlots[i].kind=nil
    end
    if shown>0 then
        if not dock.levelInBadge then
            dock.levelInBadge = true
            dock.level:ClearAllPoints()
            dock.level:SetPoint("CENTER", dock, "TOPLEFT", 23, -36)
        end
        -- Follow the existing support contours without changing artwork.
        -- Re-anchor only when the pet count changes.
        if petDock.lastCount ~= shown then
            petDock.lastCount = shown
            PositionPetSlots(shown)
        end
        petDock:Show()
    else
        petDock:Hide()
        if dock.levelInBadge then
            dock.levelInBadge = false
            dock.level:ClearAllPoints()
            dock.level:SetPoint("RIGHT", dock.xp.frame, "LEFT", -11, 0)
        end
    end
end

-- Game data is sampled at the HUD refresh interval; Arcane's own BarStep
-- advances the animation every rendered frame in AnimateVisuals below.
local current = { hp=0, hpm=1, sh=0, xp=0, xpn=1, lvl=1, mana=0, manam=0, power=-1 }
local function RefreshData()
    if not dock then return end
    local run = type(AZS_RUN) == "table" and AZS_RUN or {}
    local phase = Call(AZS_GetPhase)
    local inRun = phase and phase ~= "ready"
    local hp = tonumber(Call(UnitHealth, "player")) or 0
    local hpm = tonumber(Call(UnitHealthMax, "player")) or 1
    if inRun and tonumber(run.hpm) and run.hpm > 0 and (hpm <= 1 or math.abs(run.hpm - hpm) > 1) then
        hp, hpm = tonumber(run.hp) or hp, tonumber(run.hpm)
    end
    current.hp, current.hpm = hp, math.max(1, hpm)
    current.sh = inRun and (tonumber(run.sh) or 0) or 0
    dock.healthText:SetText(string.format("%d / %d", math.floor(hp+.5), math.floor(current.hpm+.5)))
    if current.sh > 0 then
        dock.healthText:SetText(string.format("%d / %d  +%d", math.floor(hp+.5), math.floor(current.hpm+.5), math.floor(current.sh+.5)))
    end

    local mp = tonumber(Call(UnitMana, "player")) or 0
    local mpm = tonumber(Call(UnitManaMax, "player")) or 0
    local power = tonumber(Call(UnitPowerType, "player")) or 0
    current.mana, current.manam = mp, mpm
    if current.power ~= power then
        current.power = power
        local uc = C.UnitFrames and C.UnitFrames.POWER_COLORS
        local cols = type(uc) == "table" and (uc[power] or uc[0])
        if cols then C.BarColors(dock.resource, cols[1], cols[2], cols[3]) end
    end
    if mpm > 0 then
        dock.resource.frame:Show()
        dock.resourceText:SetText(string.format("%d / %d", math.floor(mp+.5), math.floor(mpm+.5)))
    else
        dock.resource.frame:Hide()
    end

    local xp, xpn, lvl = tonumber(run.xp), tonumber(run.xpn), tonumber(run.lvl)
    if not (inRun and xpn and xpn > 0) then
        xp = tonumber(Call(UnitXP, "player")) or 0
        xpn = tonumber(Call(UnitXPMax, "player")) or 1
        lvl = tonumber(Call(UnitLevel, "player")) or 1
    end
    current.xp, current.xpn, current.lvl = xp or 0, math.max(1,xpn), lvl or 1
    if dock.lastLevel and current.lvl > dock.lastLevel then
        dock.xpWrap, dock.xpFlash = true, 1
    elseif dock.lastLevel and current.lvl < dock.lastLevel then
        dock.xp.snap, dock.xpWrap = true, false
    end
    dock.lastLevel = current.lvl
    dock.level:SetText("L" .. tostring(current.lvl))
    dock.xpText:SetText(string.format("%d / %d", math.floor(current.xp+.5), math.floor(current.xpn+.5)))

    storedLevels = math.max(0, tonumber(Call(AZS_GetStoredLevels)) or 0)
    if type(AZS_IsStoringLevels) == "function" and Call(AZS_IsStoringLevels) == false then storedLevels = 0 end
    if storedLevels > 0 then
        dock.bookGlow:Show()
        dock.bookWisp:Show()
        dock.bookSparks:Show()
        for i = 1, 3 do dock.bookMotes[i]:Show() end
        dock.bookArt:SetVertexColor(1,1,1,1)
        dock.bookCount:SetText("x" .. tostring(math.floor(storedLevels)))
    else
        dock.bookGlow:Hide()
        dock.bookWisp:Hide()
        dock.bookSparks:Hide()
        for i = 1, 3 do dock.bookMotes[i]:Hide() end
        dock.bookArt:SetVertexColor(.70,.74,.82,.70)
        dock.bookCount:SetText("")
    end

    local now = GetTime()
    for i = 1, 7 do
        local s = slots[i]
        local texture = Call(GetActionTexture, s.action)
        local has = texture and (type(HasAction) ~= "function" or Call(HasAction, s.action))
        -- Never draw a question-mark placeholder for an empty ability slot.
        RoundTexture(s, has and texture or nil)
        local start, duration, enabled = Call(GetActionCooldown, s.action)
        start, duration = tonumber(start) or 0, tonumber(duration) or 0
        local left = start + duration - now
        if not has or enabled == 0 then left = 0 end
        RoundCooldown(s, left, duration)
    end
end

local function AnimateVisuals(dt)
    if not (dock and C and C.BarStep) then return end
    local now = GetTime()
    dt = math.min(.1, math.max(0, dt or .016))
    local frac = Clamp01(current.hp / math.max(1,current.hpm))
    dock.hp.shield = Clamp01(current.sh / math.max(1,current.hpm))
    C.BarStep(dock.hp, frac, dt, now)
    local lowT = frac < .30 and 1 or 0
    dock.low = C.Toward(dock.low, lowT, 3, dt)
    if dock.low > .002 or not dock.hpColorInitialized then
        dock.hpColorInitialized = true
        local t = dock.low * (.8 + .2 * math.sin(now * 5))
        C.BarColors(dock.hp,
            Mix(HP_COLORS[1], LOW_COLORS[1], t, dock.colA),
            Mix(HP_COLORS[2], LOW_COLORS[2], t, dock.colM),
            Mix(HP_COLORS[3], LOW_COLORS[3], t, dock.colB))
    end
    if current.manam > 0 then
        C.BarStep(dock.resource, Clamp01(current.mana/current.manam), dt, now)
    end
    if dock.xpWrap then
        C.BarStep(dock.xp, 1, dt, now)
        if dock.xp.value > .995 then
            dock.xpWrap = false
            dock.xp.value, dock.xp.vel, dock.xp.echo, dock.xp.echoHold = 0, 0, 1, .3
        end
    else
        C.BarStep(dock.xp, Clamp01(current.xp / math.max(1,current.xpn)), dt, now)
    end
    dock.xpFlash = math.max(0, dock.xpFlash - dt * 1.4)
    local f = C.Smooth(dock.xpFlash)
    dock.xpText:SetTextColor(1, .95 + .05*f, .84 + .16*f)

    -- The compact spellbook now has actual moving wisps as well as breathing
    -- layered auras. Pure texture positioning; no input hooks or rotations.
    if storedLevels > 0 then
        bookClock = bookClock + dt
        dock.bookGlow:SetAlpha(.50 + .22 * (.5 + .5 * math.sin(bookClock * 2.20)))
        dock.bookWisp:SetAlpha(.43 + .29 * (.5 + .5 * math.sin(bookClock * 2.00 + 1.7)))
        dock.bookSparks:SetAlpha(.24 + .45 * (.5 + .5 * math.sin(bookClock * 3.05 + 1.2)))
        for i = 1, 3 do
            local mote = dock.bookMotes[i]
            local a = bookClock * (i == 2 and -.72 or .88) + (i-1)*2.0944
            -- Offset the three tiny sparks on an elliptical, flowing orbit.
            local r = (i == 2) and 36 or 41
            local mx = r * math.cos(a)
            local my = (r*.87) * math.sin(a)
            mote:ClearAllPoints()
            mote:SetPoint("CENTER", dock.bookArt, "CENTER", mx + BOOK_HALO_X, my + BOOK_HALO_Y)
            mote:SetAlpha(.44 + .34 * (.5 + .5 * math.sin(bookClock * 2.6 + i)))
        end
    else bookClock = 0 end
    -- A faint moving class-colored light travels along the new filigree.
    if dock.cradleAccentL then
        dock.cradleAccentL:SetAlpha(.68 + .26 * (.5 + .5 * math.sin(now * 1.45)))
        dock.cradleAccentR:SetAlpha(.68 + .26 * (.5 + .5 * math.sin(now * 1.45 + 1.2)))
    end
    if petDock and petDock.accentL and petDock:IsShown() then
        petDock.accentL:SetAlpha(.60 + .24 * (.5 + .5 * math.sin(now * 1.25)))
        petDock.accentR:SetAlpha(.60 + .24 * (.5 + .5 * math.sin(now * 1.25 + 1.10)))
    end
end

-- Profiles are captured BEFORE the style value changes and applied AFTER it
-- changes. This is an explicit theme selection, never automatic input detection.
function Theme.BeforeStyleChange(previous, nextMode)
    if not initialized then return end
    local entering = nextMode == C.BarStyles.CONTROLLER
    local leaving = previous == C.BarStyles.CONTROLLER
    if entering == leaving then return end
    CaptureProfile(leaving and "gamepad" or "keyboard")
end

function Theme.AfterStyleChange(previous, nextMode)
    if not initialized then return end
    local want = nextMode == C.BarStyles.CONTROLLER
    if want == active then return end
    -- Load the position/scale snapshot for the destination theme first.
    ApplyProfile(want and "gamepad" or "keyboard")
    active = want
    if active then
        ParkOriginals()
        ApplyTheme()
        dock:Show()
        RefreshData()
        RefreshPet()
    else
        dock:Hide()
        UnparkOriginals()
    end
end

local function Init()
    if initialized then return end
    if type(C.NewBar) ~= "function" or type(C.BarStep) ~= "function" then
        Print("Animated bar API unavailable; controller theme remains inactive.")
        return
    end
    Build()
    BuildPetDock()
    local scaleDB = C.DB("controllerUX", {scale = 1})
    dock:SetScale(C.Clamp(tonumber(scaleDB.scale) or 1, .5, 1.8))
    if controllerMover then C.ApplyPos(controllerMover) end
    EnsureProfiles()
    initialized = true
    -- Preserve the selected theme across relaunch; the canonical position
    -- table on disk is kept as the regular keyboard layout on logout.
    if C.BarStyles.Mode() == C.BarStyles.CONTROLLER then
        ApplyProfile("gamepad")
        active = true
        ParkOriginals()
        ApplyTheme()
        dock:Show()
        RefreshData()
        RefreshPet()
    end
end

-- The HUD Size row adjusts the selected style without toggling the style.
-- Classic/Hybrid/Full Class share one size; Controller keeps its own.
C.RegisterPart({
    key = "hudSize", name = "HUD Size", scaleOnly = true, profileIndependent = true,
    note = "Resize the selected HUD. The three regular styles share a size; Controller saves a separate size.",
    getScale = function()
        if C.BarStyles and C.BarStyles.Mode() == C.BarStyles.CONTROLLER then
            return C.DB("controllerUX", {scale = 1}).scale or 1
        end
        return C.DB("bar", {scale = 1}).scale or 1
    end,
    setScale = function(value)
        value = C.Clamp(tonumber(value) or 1, .5, 1.8)
        if C.BarStyles and C.BarStyles.Mode() == C.BarStyles.CONTROLLER then
            local cfg = C.DB("controllerUX", {scale = 1})
            cfg.scale = value
            if dock then
                dock:SetScale(value)
                if controllerMover then C.ApplyPos(controllerMover) end
            end
        else
            for _, part in pairs(C.parts) do
                if part.key == "bar" and type(part.setScale) == "function" then
                    part.setScale(value)
                    break
                end
            end
        end
    end,
})

C.OnInit(function()
    Init()
end)
C.OnWorld(function()
    if not initialized then Init() end
    if active then
        ParkOriginals()
        RefreshData()
        RefreshPet()
    end
end)
C.OnLogout(function()
    if not initialized then return end
    if active then
        CaptureProfile("gamepad")
        ApplyProfile("keyboard")
        -- Keep the selected style; only save canonical KBM mover positions.
        UnparkOriginals()
    else
        CaptureProfile("keyboard")
    end
end)

driver:SetScript("OnUpdate", function()
    if not initialized or not active then return end
    local dt = tonumber(arg1) or .016
    if not dock then return end
    refreshClock = refreshClock + dt
    themeClock = themeClock + dt
    if refreshClock >= .1 then
        refreshClock = 0
        local phase = Call(AZS_GetPhase)
        if phase == "choosing" then dock:Hide()
        else
            dock:Show()
            RefreshData()
        end
    end
    if dock:IsShown() then
        AnimateVisuals(dt)
        petClock = petClock + dt
        if petClock >= .18 then petClock = 0; RefreshPet() end
    end
    if themeClock >= 1 then
        themeClock = 0
        ParkOriginals() -- late-created Arcane frames
        ApplyTheme()
    end
end)
