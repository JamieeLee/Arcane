-- Arcane UI: theme native floating status text and decorate zone labels.
-- The client keeps ownership of the zone text itself and all message/animation behavior.
local C = Arcane

local AURA_TYPES = { "SPELL_CAST", "AURA_START", "AURA_END" }
local HEAL_TYPES = { "HEAL", "HEAL_CRIT", "PERIODIC_HEAL" }
local TRIM_SIZE, TRIM_GAP = 16, 10

local zoneTrim, subZoneTrim
local themedCombatFonts = false
local nativeSetZoneText
local lastPalette = {}
local lastZoneText, lastSubZoneText
local poll = 0

local function SetFont(fs, face)
	if not fs or type(fs.GetFont) ~= "function" then return end
	local _, size = fs:GetFont()
	if type(size) ~= "number" or size <= 0 then size = 20 end
	if fs.cface ~= face or fs.csize ~= size or fs.cflags ~= "OUTLINE" then
		C.SetFace(fs, face, size, "OUTLINE")
	end
	if type(fs.SetShadowColor) == "function" then fs:SetShadowColor(0, 0, 0, 1) end
	if type(fs.SetShadowOffset) == "function" then fs:SetShadowOffset(1, -1) end
end

-- Small ornamental end pieces only. The native zone/subzone text is never restyled:
-- its original font, size, color (including PvP colors), position and fade remain intact.
local function NewTrim(parent, fs)
	if not parent or not fs then return nil end
	local trim = { text = fs, shown = false }
	trim.left = C.Tex(parent, "OVERLAY", C.ART .. "FrameL")
	trim.right = C.Tex(parent, "OVERLAY", C.ART .. "FrameR")
	trim.left:SetWidth(TRIM_SIZE)
	trim.left:SetHeight(TRIM_SIZE)
	trim.right:SetWidth(TRIM_SIZE)
	trim.right:SetHeight(TRIM_SIZE)
	trim.left:Hide()
	trim.right:Hide()
	return trim
end

local function HideTrim(trim)
	if not trim or not trim.shown then return end
	trim.shown = false
	trim.left:Hide()
	trim.right:Hide()
end

local function LayoutTrim(trim)
	if not trim then return end
	local value = trim.text:GetText()
	if not value or value == "" then
		trim.value = value
		HideTrim(trim)
		return
	end

	local width = trim.text:GetStringWidth()
	if type(width) ~= "number" or width < 4 then return end
	local offset = width * 0.5 + TRIM_GAP
	if trim.value ~= value or trim.offset ~= offset then
		trim.value, trim.offset = value, offset
		trim.left:ClearAllPoints()
		trim.left:SetPoint("CENTER", trim.text, "CENTER", -offset, 0)
		trim.right:ClearAllPoints()
		trim.right:SetPoint("CENTER", trim.text, "CENTER", offset, 0)
	end
	if not trim.shown then
		trim.shown = true
		trim.left:Show()
		trim.right:Show()
	end
end

local function ApplyTrimColor(trim, pal)
	if not trim then return end
	local rim = pal.rim
	trim.left:SetVertexColor(rim[1], rim[2], rim[3], 1)
	trim.right:SetVertexColor(rim[1], rim[2], rim[3], 1)
end

local function RefreshZone()
	local zone = getglobal("ZoneTextString")
	local sub = getglobal("SubZoneTextString")
	local zoneText = zone and zone:GetText() or nil
	local subText = sub and sub:GetText() or nil
	if zoneText ~= lastZoneText or subText ~= lastSubZoneText then
		lastZoneText, lastSubZoneText = zoneText, subText
	end
	-- The trim follows the measured native string width; no native text region is modified.
	LayoutTrim(zoneTrim)
	LayoutTrim(subZoneTrim)
end

local function SetCombatColor(info, name, color)
	local entry = info[name]
	if type(entry) == "table" then
		entry.r, entry.g, entry.b = color[1], color[2], color[3]
	end
end

local function ApplyCombatText(pal)
	local info = COMBAT_TEXT_TYPE_INFO
	if type(info) ~= "table" then return false end

	-- Change only the colors of the native positive aura/cast and heal categories.
	-- All show flags, harmful categories and client message behavior remain untouched.
	for i = 1, table.getn(AURA_TYPES) do
		SetCombatColor(info, AURA_TYPES[i], pal.title)
	end
	for i = 1, table.getn(HEAL_TYPES) do
		SetCombatColor(info, HEAL_TYPES[i], pal.mc)
	end

	if not themedCombatFonts then
		local found = 0
		for i = 1, 20 do
			local fs = getglobal("CombatText" .. i)
			if fs then
				SetFont(fs, C.FONT)
				found = found + 1
			end
		end
		themedCombatFonts = found == 20
	end
	return true
end

local function ApplyTheme()
	local pal = C.Pal()
	local changed = pal.title[1] ~= lastPalette.titleR
		or pal.title[2] ~= lastPalette.titleG
		or pal.title[3] ~= lastPalette.titleB
		or pal.mc[1] ~= lastPalette.mcR
		or pal.mc[2] ~= lastPalette.mcG
		or pal.mc[3] ~= lastPalette.mcB
		or pal.rim[1] ~= lastPalette.rimR
		or pal.rim[2] ~= lastPalette.rimG
		or pal.rim[3] ~= lastPalette.rimB
	if not changed then return end

	lastPalette.titleR, lastPalette.titleG, lastPalette.titleB = pal.title[1], pal.title[2], pal.title[3]
	lastPalette.mcR, lastPalette.mcG, lastPalette.mcB = pal.mc[1], pal.mc[2], pal.mc[3]
	lastPalette.rimR, lastPalette.rimG, lastPalette.rimB = pal.rim[1], pal.rim[2], pal.rim[3]

	ApplyTrimColor(zoneTrim, pal)
	ApplyTrimColor(subZoneTrim, pal)
	ApplyCombatText(pal)
end

C.OnInit(function()
	local zoneFrame = getglobal("ZoneTextFrame")
	local subFrame = getglobal("SubZoneTextFrame")
	local zone = getglobal("ZoneTextString")
	local sub = getglobal("SubZoneTextString")

	if zone then zoneTrim = NewTrim(zoneFrame, zone) end
	if sub then subZoneTrim = NewTrim(subFrame, sub) end

	-- Keep the game's SetZoneText implementation and all its original colors. The wrapper
	-- only lays out our independent end trims after the native labels have been updated.
	if type(SetZoneText) == "function" then
		nativeSetZoneText = SetZoneText
		SetZoneText = function(showPVPInfo)
			nativeSetZoneText(showPVPInfo)
			RefreshZone()
		end
	end

	local watch = CreateFrame("Frame", "ArcaneNativeTextTheme")
	watch:RegisterEvent("ADDON_LOADED")
	watch:RegisterEvent("PLAYER_ENTERING_WORLD")
	watch:RegisterEvent("ZONE_CHANGED")
	watch:RegisterEvent("ZONE_CHANGED_INDOORS")
	watch:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	watch:SetScript("OnEvent", function()
		ApplyTheme()
		if not themedCombatFonts then ApplyCombatText(C.Pal()) end
		RefreshZone()
	end)
	watch:SetScript("OnUpdate", function()
		poll = poll + (arg1 or 0)
		if poll < 0.2 then return end
		poll = 0
		ApplyTheme()
		if not themedCombatFonts then ApplyCombatText(C.Pal()) end
		RefreshZone()
	end)

	ApplyTheme()
	ApplyCombatText(C.Pal())
	RefreshZone()
end)
