-- Arcane UI: theme the client's floating status and zone text without replacing its behavior.
-- Blizzard keeps ownership of message creation, filtering, scrolling, fade timing and visibility.
local C = Arcane

local AURA_TYPES = { "SPELL_CAST", "AURA_START", "AURA_END" }
local HEAL_TYPES = { "HEAL", "HEAL_CRIT", "PERIODIC_HEAL" }
local BANNER_HEIGHT, BANNER_CAP = 22, 22
local CRIMSON_DARK = { 0.10, 0.008, 0.018 }
local CRIMSON_LEFT = { 0.18, 0.012, 0.028 }
local CRIMSON_RIGHT = { 0.38, 0.025, 0.045 }

local zoneBanner, subZoneBanner
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

local function HideBanner(b)
	if not b or not b.shown then return end
	b.shown = false
	b.back:Hide()
	b.fill:Hide()
	b.gloss:Hide()
	b.left:Hide()
	b.middle:Hide()
	b.right:Hide()
end

local function NewBanner(parent, fs)
	if not parent or not fs then return nil end
	local b = { text = fs, shown = false }
	-- These are textures on the native fading frame, not a replacement message frame.
	-- The background and metal therefore inherit the game's exact fade and visibility.
	b.back = C.Tex(parent, "BACKGROUND", C.FLAT)
	b.fill = C.Tex(parent, "BORDER", C.ART .. "Fill")
	b.gloss = C.Tex(parent, "BORDER", C.FLAT)
	b.left = C.Tex(parent, "BORDER", C.ART .. "FrameL")
	b.middle = C.Tex(parent, "BORDER", C.ART .. "FrameM")
	b.right = C.Tex(parent, "BORDER", C.ART .. "FrameR")
	b.left:SetWidth(BANNER_CAP)
	b.left:SetHeight(BANNER_HEIGHT)
	b.middle:SetHeight(BANNER_HEIGHT)
	b.right:SetWidth(BANNER_CAP)
	b.right:SetHeight(BANNER_HEIGHT)
	b.back:Hide()
	b.fill:Hide()
	b.gloss:Hide()
	b.left:Hide()
	b.middle:Hide()
	b.right:Hide()
	return b
end

local function LayoutBanner(b)
	if not b then return end
	local value = b.text:GetText()
	if not value or value == "" then
		b.value = value
		HideBanner(b)
		return
	end

	local measured = b.text:GetStringWidth()
	if type(measured) ~= "number" or measured < 4 then return end
	local width = math.max(190, math.min(680, measured + 58))
	if b.value ~= value or b.width ~= width then
		b.value, b.width = value, width

		b.back:ClearAllPoints()
		b.back:SetPoint("CENTER", b.text, "CENTER", 0, 0)
		b.back:SetWidth(width - 34)
		b.back:SetHeight(17)

		b.fill:ClearAllPoints()
		b.fill:SetPoint("CENTER", b.text, "CENTER", 0, 0)
		b.fill:SetWidth(width - 48)
		b.fill:SetHeight(12)
		b.fill:SetGradientAlpha("HORIZONTAL",
			CRIMSON_LEFT[1], CRIMSON_LEFT[2], CRIMSON_LEFT[3], 0.96,
			CRIMSON_RIGHT[1], CRIMSON_RIGHT[2], CRIMSON_RIGHT[3], 0.96)

		b.gloss:ClearAllPoints()
		b.gloss:SetPoint("TOPLEFT", b.fill, "TOPLEFT", 0, 0)
		b.gloss:SetPoint("TOPRIGHT", b.fill, "TOPRIGHT", 0, 0)
		b.gloss:SetHeight(4)
		b.gloss:SetGradientAlpha("VERTICAL", 1, 0.82, 0.66, 0.18, 1, 0.82, 0.66, 0)

		b.left:ClearAllPoints()
		b.left:SetPoint("CENTER", b.back, "LEFT", 8, 0)
		b.right:ClearAllPoints()
		b.right:SetPoint("CENTER", b.back, "RIGHT", -8, 0)
		b.middle:ClearAllPoints()
		b.middle:SetPoint("LEFT", b.left, "RIGHT", -8, 0)
		b.middle:SetPoint("RIGHT", b.right, "LEFT", 8, 0)
	end

	if not b.shown then
		b.shown = true
		b.back:Show()
		b.fill:Show()
		b.gloss:Show()
		b.left:Show()
		b.middle:Show()
		b.right:Show()
	end
	b.back:SetVertexColor(CRIMSON_DARK[1], CRIMSON_DARK[2], CRIMSON_DARK[3], 0.94)
end

local function ColorZoneText(fs, color)
	if not fs or not color then return end
	-- SetZoneText writes its own PvP/default color, so invalidate the shared writer's cache.
	fs.mr, fs.mg, fs.mb = nil, nil, nil
	C.TextColor(fs, color[1], color[2], color[3])
end

local function ApplyZoneTheme(pal)
	local zone = getglobal("ZoneTextString")
	local sub = getglobal("SubZoneTextString")
	local pvp = getglobal("PVPInfoTextString")
	local arena = getglobal("PVPArenaTextString")

	ColorZoneText(zone, pal.title)
	ColorZoneText(sub, pal.title)
	-- Secondary territory labels keep their native meaning/color, but use Arcane typography.
	if pvp then SetFont(pvp, C.FONT) end
	if arena then SetFont(arena, C.FONT) end
	LayoutBanner(zoneBanner)
	LayoutBanner(subZoneBanner)
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

	-- Keep the client's categories and show/filter flags. Only retint the messages that
	-- Blizzard paints green by default; damage, harmful effects and resource colors remain theirs.
	for i = 1, table.getn(AURA_TYPES) do
		SetCombatColor(info, AURA_TYPES[i], pal.title)
	end
	for i = 1, table.getn(HEAL_TYPES) do
		SetCombatColor(info, HEAL_TYPES[i], pal.mc)
	end

	if not themedCombatFonts then
		for i = 1, 20 do
			local fs = getglobal("CombatText" .. i)
			if fs then SetFont(fs, C.FONT) end
		end
		themedCombatFonts = true
	end
	return true
end

local function ApplyBannerMetal(b, pal)
	if not b then return end
	local rim = pal.rim
	b.left:SetVertexColor(rim[1], rim[2], rim[3], 1)
	b.middle:SetVertexColor(rim[1], rim[2], rim[3], 1)
	b.right:SetVertexColor(rim[1], rim[2], rim[3], 1)
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

	ApplyZoneTheme(pal)
	ApplyBannerMetal(zoneBanner, pal)
	ApplyBannerMetal(subZoneBanner, pal)
	ApplyCombatText(pal)
end

local function RefreshZone()
	local zone = getglobal("ZoneTextString")
	local sub = getglobal("SubZoneTextString")
	local zoneText = zone and zone:GetText() or nil
	local subText = sub and sub:GetText() or nil
	if zoneText ~= lastZoneText or subText ~= lastSubZoneText then
		lastZoneText, lastSubZoneText = zoneText, subText
		ApplyZoneTheme(C.Pal())
	end
end

C.OnInit(function()
	local zoneFrame = getglobal("ZoneTextFrame")
	local subFrame = getglobal("SubZoneTextFrame")
	local zone = getglobal("ZoneTextString")
	local sub = getglobal("SubZoneTextString")

	if zone then
		SetFont(zone, C.TITLE_FONT)
		zoneBanner = NewBanner(zoneFrame, zone)
	end
	if sub then
		SetFont(sub, C.TITLE_FONT)
		subZoneBanner = NewBanner(subFrame, sub)
	end

	if type(SetZoneText) == "function" then
		nativeSetZoneText = SetZoneText
		SetZoneText = function(showPVPInfo)
			nativeSetZoneText(showPVPInfo)
			ApplyZoneTheme(C.Pal())
		end
	end

	local watch = CreateFrame("Frame", "ArcaneNativeTextTheme")
	watch:RegisterEvent("ADDON_LOADED")
	watch:RegisterEvent("PLAYER_ENTERING_WORLD")
	watch:RegisterEvent("ZONE_CHANGED")
	watch:RegisterEvent("ZONE_CHANGED_INDOORS")
	watch:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	watch:SetScript("OnEvent", function()
		if event == "ADDON_LOADED" then
			ApplyCombatText(C.Pal())
		end
		ApplyTheme()
		RefreshZone()
	end)
	watch:SetScript("OnUpdate", function()
		poll = poll + (arg1 or 0)
		if poll < 0.2 then return end
		poll = 0
		ApplyTheme()
		RefreshZone()
	end)

	ApplyTheme()
	ApplyZoneTheme(C.Pal())
	ApplyCombatText(C.Pal())
	RefreshZone()
end)
