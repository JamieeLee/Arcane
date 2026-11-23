-- Arcane UI: stored level-ups.
-- With the game's Store Level-Ups setting on, a level gained doesn't stop the fight: it waits.
-- While some wait, a gold-railed "Level Up!" button glows over the skill bar with how many there
-- are; a new one makes it pulse. Click it and the game offers them, one after another, as its own
-- button does. While this part is on, the game's button is hidden; off, it comes back.

local C = Arcane
local DEFAULTS = { enabled = true, scale = 1 }
local W, H = 82, 82
local ART = "Interface\\AddOns\\Arcane\\Themes\\Controller\\Art\\"
local HALO_X, HALO_Y = -1, 3

local db
local root
local S = { alpha = 0, n = 0, pop = nil, takeClock = 0, broken = false, stamp = -1, bookClock = 0 }

-- The Arcane switch controls the same preference as the game's own Options page.
-- nil means this client does not expose the setting API, so keep the saved fallback.
local function NativeStoring()
	if type(AZS_IsStoringLevels) ~= "function" then return nil end
	local value = C.Call(AZS_IsStoringLevels)
	if type(value) == "boolean" then return value end
	if type(value) == "number" then return value ~= 0 end
	return nil
end

local function Waiting()
	if type(AZS_GetStoredLevels) ~= "function" then return 0 end
	local n = tonumber(C.Call(AZS_GetStoredLevels)) or 0
	if n > 0 and NativeStoring() == false then n = 0 end
	return n
end

local function Open()
	if type(AZS_OpenStoredLevels) == "function" and S.n > 0 then
		C.Call(AZS_OpenStoredLevels)
		if GameTooltip then GameTooltip:Hide() end
	end
end

local function ShowTip()
	if not GameTooltip or C.unlocked then return end
	GameTooltip:SetOwner(root, "ANCHOR_TOP")
	GameTooltip:AddLine(C.L("Level Up!"), 0.98, 0.85, 0.52)
	GameTooltip:AddLine(C.F("{1} level-ups wait. Click to pick their cards.", S.n), 1, 1, 1, 1)
	C.ShowTip()
end

local function Theme(pal)
	-- Natural leather-and-gold book; the existing magic and motes stay unchanged.
	local classPal = C.BarStyles and C.BarStyles.Palette and C.BarStyles.Palette() or pal
	local glow = classPal.glow or pal.glow
	local title = pal.title
	root.classAura:SetVertexColor(glow[1], glow[2], glow[3], 1)
	root.goldAura:SetVertexColor(1, .76, .46, 1)
	root.sparks:SetVertexColor(glow[1], glow[2], glow[3], 1)
	root.count:SetTextColor(title[1], title[2], title[3])
	for i = 1, table.getn(root.motes) do
		root.motes[i]:SetVertexColor(glow[1], glow[2], glow[3], 1)
	end
end

local function Step(dt, now)
	local n = Waiting()
	if n > S.n then S.pop = now end -- one more: it pulses
	S.n = n
	local want = (n > 0) and (1 - C.cardsFade) or 0
	S.alpha = C.Toward(S.alpha, want, 8, dt)
	if S.alpha < 0.01 then
		C.Vis(root, false)
		return
	end
	C.Vis(root, true)
	C.Alpha(root, S.alpha)
	local pal = C.Pal()
	if S.stamp ~= C.palStamp then
		S.stamp = C.palStamp
		Theme(pal)
	end
	C.SetText(root.count, "x" .. tostring(n))
	-- a slow breath of light, and a bright pulse when one more comes
	local pop = 0
	if S.pop then
		local age = now - S.pop
		pop = C.Smooth(age / 0.08) * (1 - C.Smooth((age - 0.08) / 0.7))
		if age > 0.8 then S.pop = nil end
	end
	local breath = 0.5 + 0.5 * math.sin(now * 2.4)
	C.Alpha(root.goldAura, .45 + .25 * breath + .25 * pop)
	C.Alpha(root.classAura, .42 + .25 * (1 - breath) + .30 * pop)
	C.Alpha(root.sparks, .30 + .22 * breath + .35 * pop)
	S.bookClock = S.bookClock + dt
	for i = 1, table.getn(root.motes) do
		local mote = root.motes[i]
		local a = S.bookClock * (i == 2 and -.72 or .88) + (i - 1) * 2.0944
		mote:ClearAllPoints()
		mote:SetPoint("CENTER", root.book, "CENTER",
			(36 + i * 2) * math.cos(a) + HALO_X,
			(33 + i * 2) * math.sin(a) + HALO_Y)
		mote:SetAlpha(.4 + .4 * (.5 + .5 * math.sin(S.bookClock * 2.6 + i)))
	end
	S.takeClock = S.takeClock - dt
	if S.takeClock <= 0 then
		S.takeClock = 2
		C.TakeHud("levels")
	end
end

local function Apply()
	if db.enabled then
		C.TakeHud("levels")
	else
		C.ReleaseHud("levels")
		C.Vis(root, false)
		S.alpha = 0
	end
end

-- Keep the Arcane hub checkbox and the native Options checkbox in lockstep.
local function SyncStoring(refreshHub)
	if not db then return end
	local actual = NativeStoring()
	if actual == nil or actual == db.enabled then return end
	db.enabled = actual
	if actual then S.broken = false end
	Apply()
	if refreshHub and C.RefreshHub then C.RefreshHub() end
end

local function SetStoring(on)
	local requested = on and true or false
	if type(AZS_SetStoringLevels) == "function" then
		C.Call(AZS_SetStoringLevels, requested)
		local actual = NativeStoring()
		if actual ~= nil then requested = actual end
	end
	db.enabled = requested
	S.broken = false
	Apply()
end

C.OnInit(function()
	db = C.DB("levelups", DEFAULTS)
	local actual = NativeStoring()
	if actual ~= nil then db.enabled = actual end
	root = CreateFrame("Button", "ArcaneLevelUps", UIParent)
	root:SetWidth(W)
	root:SetHeight(H)
	root:SetFrameStrata("MEDIUM")
	root:SetScale(db.scale)
	root:EnableMouse(true)
	-- Existing Controller UX spellbook assets; level-up behavior stays here.
	root.book = C.Tex(root, "ARTWORK", ART .. "TomeNatural")
	root.book:SetWidth(66); root.book:SetHeight(66)
	root.book:SetPoint("CENTER", root, "CENTER", 0, 0)
	root.goldAura = C.Tex(root, "BACKGROUND", ART .. "BookGoldOrbit", "ADD")
	root.classAura = C.Tex(root, "BACKGROUND", ART .. "BookClassOrbit", "ADD")
	root.sparks = C.Tex(root, "BACKGROUND", ART .. "BookSparks", "ADD")
	for _, t in ipairs({root.goldAura, root.classAura, root.sparks}) do
		t:SetWidth(108); t:SetHeight(108)
		t:SetPoint("CENTER", root.book, "CENTER", HALO_X, HALO_Y)
	end
	root.motes = {}
	for i = 1, 3 do
		local mote = C.Tex(root, "OVERLAY", ART .. "BookSparks", "ADD")
		mote:SetWidth(15); mote:SetHeight(15)
		mote:SetPoint("CENTER", root.book, "CENTER", 0, 0)
		root.motes[i] = mote
	end
	local top = CreateFrame("Frame", nil, root)
	top:SetAllPoints(root)
	top:SetFrameLevel(root:GetFrameLevel() + 2)
	root.count = C.Text(top, C.FONT, 12, "OUTLINE", "CENTER", 38)
	root.count:SetPoint("TOPRIGHT", root, "TOPRIGHT", 3, -4)
	root:SetScript("OnClick", Open)
	root:SetScript("OnEnter", ShowTip)
	root:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	C.Vis(root, false)
	C.Movable(root, "levelups", "Stored level-ups", function(f)
		f:ClearAllPoints()
		f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 276) -- clear above the XP bar and HUD, at the tested height
	end)
	-- Native Options changes need a periodic sync, not an API read every
	-- rendered frame. The button's glow/animation stays frame-driven.
	C.Poll.Add("levelups.storing", 0.20, function() SyncStoring(true) end, true)
	local driver = CreateFrame("Frame", "ArcaneLevelUpsDriver")
	driver:SetScript("OnUpdate", function()
		if S.broken then return end
		if not db.enabled then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Step, dt, GetTime())
		if not ok then
			S.broken = true
			db.enabled = false
			Apply()
			db.enabled = true
			C.Print(C.L("the level-up button stopped after an error, so the game's own is back: ") .. tostring(err))
		end
	end)
	Apply()
end)

C.OnWorld(function()
	if db and db.enabled then C.TakeHud("levels") end
end)

C.OnLogout(function()
	if db then C.ReleaseHud("levels") end
end)

C.RegisterPart({
	key = "levelups", name = "Stored level-ups",
	note = "Turns the game's Store Level-Ups setting on or off. When on: a glowing Level Up! button over the skill bar shows how many wait. Click it to pick their cards. Replaces the game's button.",
	get = function()
		if not db then return false end
		SyncStoring()
		return db.enabled
	end,
	set = function(on)
		if db then SetStoring(on) end
	end,
	getScale = function() return db and db.scale or 1 end,
	setScale = function(v)
		if db then
			db.scale = v
			root:SetScale(v)
		end
	end,
})
